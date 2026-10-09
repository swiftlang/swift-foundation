//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension _CharacterSet {
    struct CompactBitmapBacked {
        internal var data: Data
        
        init(data: Data) {
            self.data = data
        }
        
        internal var span: Span<UInt8> {
            return data.span
        }
        
        internal var mutableSpan: MutableSpan<UInt8> {
            mutating get {
                return data.mutableSpan
            }
        }
        
        internal var isEmpty: Bool {
            let currentSpan = span
            if currentSpan.isEmpty {
                return true
            }
            
            let headerCount = min(_CharacterSet.__kCFCompactBitmapNumPages, currentSpan.count)
            for i in 0..<headerCount {
                if currentSpan[i] != 0 {
                    return false
                }
            }
            return true
        }

        internal func isSuperset(of subset: CompactBitmapBacked) -> Bool {
            let numPages = _CharacterSet.__kCFCompactBitmapNumPages
            let pageSize = _CharacterSet.__kCFCompactBitmapPageSize
            let wordStride = MemoryLayout<UInt>.stride
            let selfBytes = self.data.span.bytes
            let subBytes = subset.data.span.bytes
            var selfBodyOffset = numPages
            var subBodyOffset = numPages
            for p in 0..<numPages {
                let selfHeader = selfBytes.load(fromByteOffset: p, as: UInt8.self, .littleEndian)
                let subHeader = subBytes.load(fromByteOffset: p, as: UInt8.self, .littleEndian)
                let selfPartial = (selfHeader != 0 && selfHeader != UInt8.max)
                let subPartial = (subHeader != 0 && subHeader != UInt8.max)

                if subHeader != 0 {
                    if selfHeader == UInt8.max {
                        // self's page is fully populated (0xFF), guaranteed to be a superset of subset
                    } else if selfHeader == 0 || subHeader == UInt8.max {
                        return false
                    } else {
                        var w = 0
                        while w < pageSize {
                            let subWord = subBytes.load(fromByteOffset: subBodyOffset + w, as: UInt.self, .littleEndian)
                            let selfWord = selfBytes.load(fromByteOffset: selfBodyOffset + w, as: UInt.self, .littleEndian)
                            if (subWord & ~selfWord) != 0 {
                                return false
                            }
                            w += wordStride
                        }
                    }
                }
                if selfPartial {
                    selfBodyOffset += pageSize
                }
                if subPartial {
                    subBodyOffset += pageSize
                }
            }
            return true
        }
        
        internal func isSubset(of superset: RawSpan) -> Bool {
            let wordStride = MemoryLayout<UInt>.stride
            let numPages = _CharacterSet.__kCFCompactBitmapNumPages
            let pageSize = _CharacterSet.__kCFCompactBitmapPageSize
            let subsetBytes = span.bytes
            
            var bodyOffset = numPages
            for p in 0..<numPages {
                let header = subsetBytes.load(fromByteOffset: p, as: UInt8.self, .littleEndian)
                if header == 0 { continue }
                let pageOffset = p * pageSize
                if header == UInt8.max {
                    var w = 0
                    while w < pageSize {
                        if superset.load(fromByteOffset: pageOffset + w, as: UInt.self, .littleEndian) != UInt.max {
                            return false
                        }
                        w += wordStride
                    }
                } else {
                    var w = 0
                    while w < pageSize {
                        let subsetWord = subsetBytes.load(fromByteOffset: bodyOffset + w, as: UInt.self, .littleEndian)
                        let supersetWord = superset.load(fromByteOffset: pageOffset + w, as: UInt.self, .littleEndian)
                        if (subsetWord & ~supersetWord) != 0 {
                            return false
                        }
                        w += wordStride
                    }
                    bodyOffset += pageSize
                }
            }
            return true
        }
        
        // __CFCSetIsMemberInCompactBitmap
        internal func contains(_ member: Unicode.Scalar) -> Bool {
            return _contains(codepoint: Int(member.value))
        }
        
        // Surrogate code units (0xD800-0xDFFF) are not representable as Unicode.Scalar,
        // so callers pass the raw value here.
        internal func contains(surrogate codepoint: UInt16) -> Bool {
            return _contains(codepoint: Int(codepoint))
        }
        
        private func _contains(codepoint: Int) -> Bool {
            let value = span[codepoint >> 8]
            
            if value == 0 {
                return false
            } else if value == 255 {
                return true
            } else {
                // Navigate to the page data
                let pageDataOffset = _CharacterSet.__kCFCompactBitmapNumPages + (_CharacterSet.__kCFCompactBitmapPageSize * Int(value - 1))
                
                // Test the specific bit
                let charInPage = codepoint & 0xFF
                let byteIndex = charInPage / BITSPERBYTE
                let bitPosition = charInPage % BITSPERBYTE
                let bitMask = UInt8(1 << bitPosition)
                
                return (span[pageDataOffset + byteIndex] & bitMask) != 0
            }
        }
        
        internal mutating func invert() {
            // First pass: invert header bytes and track page data size
            var mutableSpan = data.mutableSpan
            var pageDataSize = 0
            for i in 0..<_CharacterSet.__kCFCompactBitmapNumPages {
                let value = mutableSpan[i]
                
                if value == 0 {
                    mutableSpan[i] = UInt8(255)
                } else if value == UInt8(255) {
                    mutableSpan[i] = 0
                } else {
                    // This page has actual data, so count its size
                    pageDataSize += _CharacterSet.__kCFCompactBitmapPageSize
                }
            }
            
            // Second pass: invert the actual page data bytes
            // Page data starts after the header at offset __kCFCompactBitmapNumPages
            let pageDataStart = _CharacterSet.__kCFCompactBitmapNumPages
            for i in 0..<pageDataSize {
                mutableSpan[pageDataStart + i] = ~mutableSpan[pageDataStart + i]
            }
        }
        
        // __CFExpandCompactBitmap
        internal func expand(to output: inout OutputSpan<UInt8>) {
            let currentSpan = span
            let count = min(output.freeCapacity, _CharacterSet.__kCFBitmapSize)
            let numPages = _CharacterSet.__kCFCompactBitmapNumPages
            let pageSize = _CharacterSet.__kCFCompactBitmapPageSize
            var srcBodyOffset = numPages
            var dstOffset = 0
            var page = 0

            while page < numPages && dstOffset < count {
                let value = currentSpan[page]

                if value == 0 || value == UInt8.max {
                    var runEnd = page + 1
                    while runEnd < numPages && currentSpan[runEnd] == value {
                        runEnd += 1
                    }
                    let runLen = min((runEnd - page) * pageSize, count - dstOffset)
                    output.append(repeating: value, count: runLen)
                    dstOffset += runLen
                    page = runEnd
                } else {
                    let pageLen = min(pageSize, count - dstOffset)
                    output._append(copying: currentSpan.extracting(srcBodyOffset..<(srcBodyOffset + pageLen)))
                    srcBodyOffset += pageSize
                    dstOffset += pageLen
                    page += 1
                }
            }
        }

        internal func hasMemberInBMPPlane() -> Bool {
            return !isEmpty
        }

        /// Returns a copy with the characters in `string` removed, or `nil` when the result cannot stay compact.
        internal func removing(charactersIn string: String) -> CompactBitmapBacked? {
            let numPages = _CharacterSet.__kCFCompactBitmapNumPages
            let pageSize = _CharacterSet.__kCFCompactBitmapPageSize

            var scalars = string.unicodeScalars.makeIterator()
            var firstHit: Unicode.Scalar?
            let readSpan = span
            while let scalar = scalars.next() {
                if scalar.value > 0xFFFF { return nil }
                let header = readSpan[Int(scalar.value >> 8)]
                if header == 0 { continue }
                if header == 0xFF { return nil }
                firstHit = scalar
                break
            }
            guard let firstHit else { return self }

            var result = self
            var pagesWithZeroedByte = InlineArray<4, UInt64>(repeating: 0)
            var s = result.mutableSpan
            var next: Unicode.Scalar? = firstHit
            while let scalar = next {
                next = scalars.next()
                if scalar.value > 0xFFFF { return nil }
                let page = Int(scalar.value >> 8)
                let header = Int(s[page])
                if header == 0 { continue }
                if header == 0xFF { return nil }
                let charInPage = Int(scalar.value & 0xFF)
                let byteIndex = numPages + pageSize * (header - 1) + charInPage / 8
                s[byteIndex] &= ~(UInt8(1) << (charInPage % 8))
                if s[byteIndex] == 0 {
                    pagesWithZeroedByte[page / 64] |= UInt64(1) << (page % 64)
                }
            }

            for word in 0..<4 {
                var bits = pagesWithZeroedByte[word]
                while bits != 0 {
                    let page = word * 64 + bits.trailingZeroBitCount
                    bits &= bits - 1
                    let bodyOffset = numPages + pageSize * (Int(s[page]) - 1)
                    var remaining: UInt8 = 0
                    for i in 0..<pageSize {
                        remaining |= s[bodyOffset + i]
                    }
                    if remaining == 0 { return nil }
                }
            }
            return result
        }
    }

    // CompactBitmap Example: [256-byte header] [Page 0 data: 32 bytes] [Page 50 data: 32 bytes]
    internal static func createCompactBitmapFast(from otherSpan: Span<UInt8>) -> Data? {
        let otherSpanCount = otherSpan.count

        // Build the 256-byte header to avoid resizing `Data`.
        var header = InlineArray<256, UInt8>(repeating: 0)
        var numPages = 0

        for i in 0..<Self.__kCFCompactBitmapNumPages {
            let pageOffset = i * Self.__kCFCompactBitmapPageSize
            guard pageOffset < otherSpanCount else { break }

            header[i] = Self.getHeaderValueFast(from: otherSpan, startingAt: pageOffset, numPages: &numPages)

            if numPages > Self.__kCFCompactBitmapMaxPages {
                // Abort creating compact bitmap because it is not going to be performant
                return nil
            }
        }

        // Allocate compactData exactly once at the final size, then fill it.
        let totalSize = Self.__kCFCompactBitmapNumPages + (Self.__kCFCompactBitmapPageSize * numPages)
        var compactData = _CharacterSet.allZeros(count: totalSize)
        var compactMutableSpan = compactData.mutableSpan

        // Copy header
        var headerSpan = compactMutableSpan._mutatingExtracting(first: Self.__kCFCompactBitmapNumPages)
        for i in headerSpan.indices {
            headerSpan[i] = header[i]
        }

        // Copy page data using bulk operation (32 bytes per page)
        if numPages > 0 {
            var currentDataPageIndex = 0

            compactMutableSpan.withUnsafeMutableBufferPointer { destBuffer in
                otherSpan.withUnsafeBufferPointer { sourceBuffer in
                    for i in 0..<Self.__kCFCompactBitmapNumPages {
                        let headerValue = destBuffer[i]

                        if headerValue != 0 && headerValue != UInt8.max {
                            let pageOffset = i * Self.__kCFCompactBitmapPageSize
                            let pageEndOffset = min(pageOffset + Self.__kCFCompactBitmapPageSize, otherSpanCount)

                            if pageOffset < otherSpanCount {
                                let destStartIndex = Self.__kCFCompactBitmapNumPages + (currentDataPageIndex * Self.__kCFCompactBitmapPageSize)
                                let pageCount = pageEndOffset - pageOffset

                                UnsafeMutableRawPointer(destBuffer.baseAddress!.advanced(by: destStartIndex)).copyMemory(from: sourceBuffer.baseAddress!.advanced(by: pageOffset), byteCount: pageCount)

                                // Zero-pad the remainder of the page if source was short
                                if pageCount < Self.__kCFCompactBitmapPageSize {
                                    (destBuffer.baseAddress! + (destStartIndex + pageCount)).update(
                                        repeating: 0,
                                        count: Self.__kCFCompactBitmapPageSize - pageCount
                                    )
                                }
                                currentDataPageIndex += 1
                            }
                        }
                    }
                }
            }
        }

        return compactData
    }
    
    // Get the header value starting at the page offset.
    // Callsite guarantees offset < span.count.
    private static func getHeaderValueFast(from span: Span<UInt8>, startingAt offset: Int, numPages: inout Int) -> UInt8 {
        let value = span[unchecked: offset]

        if value == 0 || value == UInt8.max {
            // How many bytes of the page are actually available in the span
            let available = min(Self.__kCFCompactBitmapPageSize, span.count - offset)

            // Use bulk operation to check the entire page in one call
            if available == Self.__kCFCompactBitmapPageSize {
                if Self.bytes(of: span.extracting(offset..<(offset + available)), equalTo: value) {
                    return value
                }
            }
        }

        numPages += 1
        return UInt8(numPages)
    }

}
