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

// MARK: Storage Conversion Helpers
// Converts the backing storage between representations: materializing any
// storage to a raw BMP bitmap (+ annex planes), and compacting / expanding
// the compact-bitmap form.
extension _CharacterSet {
    
    // __CFCSetMakeBitmap
    // Converts backing storage from String, Range, ClosedRange, CompactBitmap to Bitmap & add Annex if necessary
    internal func makeBitmap() {
        switch storage {
        case .empty:
            let bmpBitmap = isInverted ? _CharacterSet.allOnes() : _CharacterSet.allZeros()
            self.storage = .bitmap(BitmapBacked(data: bmpBitmap))
        case .builtIn(let predefined):
            let bmpBitmap = bitmap()
            self.storage = .bitmap(BitmapBacked(data: bmpBitmap))
            // Add non-BMP planes to Annex
            addBuiltInAnnexPlanes(predefined: predefined)
        case .string, .compactBitmap:
            let bmpBitmap = bitmap()
            self.storage = .bitmap(BitmapBacked(data: bmpBitmap))
        case .range(let rangeBacked):
            let bmpBitmap = bitmap()
            self.storage = .bitmap(BitmapBacked(data: bmpBitmap))
            // Add non-BMP planes to Annex
            addRangeAnnexPlanes(rangeBacked: rangeBacked)
        case .bitmap(_):
            return
        }
        self.isInverted = false
    }
    
    private func addBuiltInAnnexPlanes(predefined: BuiltInUnicodeScalarSet) {
        let numPlanes = predefined._numberOfPlanes
        if numPlanes > 1 {
            for i in 1..<numPlanes {
                if predefined.bitmapResult(forPlane: i, isInverted: false) == .bitmapEmpty { continue }
                
                let annexSet = getAnnexPlaneCharacterSet(i)
                annexSet.storage = .bitmap(BitmapBacked(data: predefined.bitmap(forPlane: i, isInverted: false)))
                annexSet.isInverted = false
                self.annex.setCharacterSet(annexSet, forPlane: i)
            }
        }
    }
    
    private func addRangeAnnexPlanes(rangeBacked: RangeBacked) {
        addNonBMPPlanes(inRange: rangeBacked.closedRange)
        // Check whether we need to invert Annex
        if !hasNonBMPPlane && isInverted {
            self.annex.isInverted = true
        }
    }

    // _CFCharacterSetCompact
    internal func makeCharacterSetCompact() {
        switch storage {
        case .bitmap(let bitmapBacked):
            if let cBitmapData = Self.createCompactBitmapFast(from: bitmapBacked.span) {
                self.storage = .compactBitmap(CompactBitmapBacked(data: cBitmapData))
            }
        default:
            break
        }
        if hasNonBMPPlane {
            for planeNum in 1...Self.MAX_ANNEX_PLANE {
                if let annex = getAnnexPlaneCharacterSetNoAlloc(planeNum) {
                    switch annex.storage {
                    case .bitmap(let bitmapBacked):
                        if let compactAnnexData = Self.createCompactBitmapFast(from: bitmapBacked.span) {
                            annex.storage = .compactBitmap(CompactBitmapBacked(data: compactAnnexData))
                        }
                    default:
                        continue
                    }
                }
            }
        }
    }
    
    // _CFCharacterSetFast
    internal func makeCharacterSetFast() {
        switch storage {
        case .compactBitmap:
            self.makeBitmap()
        default:
            break
        }
        if hasNonBMPPlane {
            for planeNum in 1...Self.MAX_ANNEX_PLANE {
                if let annex = getAnnexPlaneCharacterSetNoAlloc(planeNum) {
                    switch annex.storage {
                    case .compactBitmap:
                        annex.makeBitmap()
                    default:
                        continue
                    }
                }
            }
        }
    }

    internal func bitmap() -> Data {
        switch storage {
        case .empty:
            if isInverted {
                return _CharacterSet.allOnes()
            } else {
                return _CharacterSet.allZeros()
            }
        case .bitmap(let bitmapStorage):
            if bitmapStorage.isEmpty {
                return _CharacterSet.allZeros()
            }
            return bitmapStorage.data
        case .builtIn, .compactBitmap, .range, .string:
            return Data(capacity: Self.__kCFBitmapSize) { output in
                appendBitmap(to: &output)
            }
        }
    }

    internal func appendBitmap(ofPlane plane: Int = 0, to output: inout OutputRawSpan) {
        output.withOutputSpan(of: UInt8.self) { typedOutput in
            appendBitmap(ofPlane: plane, to: &typedOutput)
        }
    }

    // __CFCSetGetBitmap
    internal func appendBitmap(ofPlane plane: Int = 0, to output: inout OutputSpan<UInt8>) {
        let byteCount = min(output.freeCapacity, Self.__kCFBitmapSize)
        precondition(byteCount > 0)

        if plane > 0 {
            switch storage {
            case .empty, .string, .bitmap, .compactBitmap:
                guard let annexPlane = getAnnexPlaneCharacterSetNoAlloc(plane) else {
                    output.append(repeating: annexIsInverted ? 0xFF : 0x00, count: byteCount)
                    return
                }
                annexPlane.appendBitmap(to: &output)
                if annexIsInverted {
                    var mutableSpan = output.mutableSpan
                    var appended = mutableSpan._mutatingExtracting(last: byteCount)
                    for i in appended.indices {
                        appended[i] = ~appended[i]
                    }
                }
                return
                
            case .builtIn, .range:
                // These two cases carry implicit non-BMP membership derived directly from the storage, so they are handled by the plane-aware cases below.
                break
            }
        }

        switch storage {
        // empty, bitmap, compactBitmap and string cases handle plane 0 only because planes 1...16 are handled above. 
        case .empty:
            output.append(repeating: isInverted ? 0xFF : 0x00, count: byteCount)

        case .bitmap(let bitmapStorage):
            if bitmapStorage.isEmpty {
                output.append(repeating: 0x00, count: byteCount)
            } else {
                output._append(copying: bitmapStorage.span.extracting(0..<byteCount))
            }
            
        case .compactBitmap(let cBitmapStorage):
            cBitmapStorage.expand(to: &output)

        case .string(let stringStorage):
            output.append(repeating: isInverted ? 0xFF : 0x00, count: byteCount)
            var mutableSpan = output.mutableSpan
            var appended = mutableSpan._mutatingExtracting(last: byteCount)
            applyStringEdits(stringStorage, to: &appended)

        // range and builtIn cases handle planes 0...16.
        case .range(let rangeStorage):
            output.append(repeating: isInverted ? 0xFF : 0x00, count: byteCount)
            var mutableSpan = output.mutableSpan
            var appended = mutableSpan._mutatingExtracting(last: byteCount)
            applyRangeEdits(rangeStorage, plane: plane, to: &appended)
            
        case .builtIn(let predefinedStorage):
            predefinedStorage.appendBitmap(forPlane: plane, isInverted: isInverted, to: &output)
        }
    }

    private func applyRangeEdits(_ rangeStorage: RangeBacked, plane: Int, to mutableSpan: inout MutableSpan<UInt8>) {
        let maxChar = UInt32(mutableSpan.count * Self.BITSPERBYTE - 1)
        let lowerBound = rangeStorage.closedRange.lowerBound.value
        let upperBound = rangeStorage.closedRange.upperBound.value
        let startPlane = Int(lowerBound >> 16)
        let endPlane = Int(upperBound >> 16)
        guard plane >= startPlane, plane <= endPlane else { return }
        let firstChar: UInt32 = (plane == startPlane) ? (lowerBound & 0xFFFF) : 0
        let lastChar: UInt32 = min((plane == endPlane) ? (upperBound & 0xFFFF) : 0xFFFF, maxChar)
        guard firstChar <= lastChar else { return }
        if isInverted {
            Self.removeCharacters(from: &mutableSpan, firstChar: firstChar, lastChar: lastChar)
        } else {
            Self.addCharacters(to: &mutableSpan, firstChar: firstChar, lastChar: lastChar)
        }
    }

    private func applyStringEdits(_ stringStorage: StringBacked, to mutableSpan: inout MutableSpan<UInt8>) {
        let operation: Operation = isInverted ? .remove : .add
        for scalar in stringStorage.guts {
            guard scalar.value <= 0xFFFF else { continue }
            Self.modifyBitmap(operation, char: UInt16(scalar.value), mutableSpan: &mutableSpan)
        }
    }

    internal var asciiAllowedMask: UInt128 {
        let buffer = InlineArray<16, UInt8> { output in
            appendBitmap(to: &output)
        }
        return Self._asciiMask(fromBitmap: buffer.span)
    }
}
