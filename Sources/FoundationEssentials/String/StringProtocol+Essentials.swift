//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#endif

internal import _FoundationCShims

extension UInt8 {
    private typealias UTF8Representation = (UInt8, UInt8, UInt8)
    private static func withMacRomanMap<R>(_ body: (UnsafeBufferPointer<UTF8Representation>) -> R) -> R {
        withUnsafePointer(to: _stringshims_macroman_mapping) {
            $0.withMemoryRebound(to: UTF8Representation.self, capacity: Int(_STRINGSHIMS_MACROMAN_MAP_SIZE)) {
                body(UnsafeBufferPointer(start: $0, count: Int(_STRINGSHIMS_MACROMAN_MAP_SIZE)))
            }
        }
    }
    
    var macRomanNonASCIIAsUTF8: some Collection<UInt8> {
        assert(!Unicode.ASCII.isASCII(self))
        return Self.withMacRomanMap { map in
            let utf8Rep = map[Int(self) - 128]
            if utf8Rep.2 == 0 {
                return [utf8Rep.0, utf8Rep.1]
            } else {
                return [utf8Rep.0, utf8Rep.1, utf8Rep.2]
            }
        }
    }
    
    init?(macRomanFor scalar: UnicodeScalar) {
        guard !scalar.isASCII else {
            self.init(scalar.value)
            return
        }
        
        let utf8 = Array(scalar.utf8)
        guard utf8.count <= 3 else {
            return nil
        }
        let tuple = (utf8[0], utf8[1], utf8.count == 2 ? 0 : utf8[2])
        
        let value: UInt8? = Self.withMacRomanMap { map in
            if let found = map.firstIndex(where: { $0 == tuple }) {
                return UInt8(found) + 128
            } else {
                return nil
            }
        }
        
        guard let value else { return nil }
        self = value
    }
}

extension UInt16 {
    init(nextStep codepoint: UInt8) {
        if codepoint < 128 {
            self = Self(codepoint)
        } else {
            let tableOffset = Int(codepoint - 128)
            self = withUnsafePointer(to: _stringshims_nextstep_mapping) {
                $0.withMemoryRebound(to: Self.self, capacity: Int(_STRINGSHIMS_NEXTSTEP_MAP_SIZE)) {
                    $0.advanced(by: tableOffset).pointee
                }
            }
        }
    }
}

// These provides concrete implementations for String and Substring, enhancing performance over generic StringProtocol.

#if !FOUNDATION_FRAMEWORK
@_spi(SwiftCorelibsFoundation)
dynamic public func _cfStringEncodingConvert(string: String, using encoding: UInt, allowLossyConversion: Bool) -> Data? {
    // Dynamically replaced by swift-corelibs-foundation to implement encodings that we do not have Swift replacements for, yet
    return nil
}
#endif

@available(FoundationPreview 0.4, *)
extension String {
    public func data(using encoding: String.Encoding, allowLossyConversion: Bool = false) -> Data? {
        // allowLossyConversion is a no-op for UTF8 and UTF16. For UTF32, we fall back to NSString when lossy conversion is requested on Darwin platforms.
        switch encoding {
        case .utf8:
            return Data(self.utf8)
        case .ascii, .nonLossyASCII:
            if allowLossyConversion {
                let lossyReplacement = (encoding == .ascii) ? 0xFF : UInt8(ascii: "?")
                return Data(capacity: self.utf8.count) {
                    for scalar in self.unicodeScalars {
                        if scalar.isASCII {
                            $0.append(fromContentsOf: scalar.utf8)
                        } else {
                            $0.appendElement(lossyReplacement)
                        }
                    }
                }
            } else {
                let earlyCheckAllASCII = self.utf8.withContiguousStorageIfAvailable {
                    _allASCII($0)
                }
                if let earlyCheckAllASCII, !earlyCheckAllASCII {
                    return nil
                }
                var data = Data(count: self.utf8.count)
                let allASCII = data.withUnsafeMutableBytes {
                    $0.withMemoryRebound(to: UInt8.self) { buffer in
                        _ = buffer.initialize(fromContentsOf: self.utf8)
                        if let earlyCheckAllASCII {
                            return earlyCheckAllASCII
                        } else {
                            return _allASCII(UnsafeBufferPointer(buffer))
                        }
                    }
                }
                return allASCII ? data : nil
            }
        case .utf16BigEndian, .utf16LittleEndian, .utf16:
            let bom: UInt16?
            let swap: Bool
            
            if encoding == .utf16 {
                swap = false
                bom = 0xFEFF
            } else if encoding == .utf16BigEndian {
#if _endian(little)
                swap = true
#else
                swap = false
#endif
                bom = nil
            } else if encoding == .utf16LittleEndian {
#if _endian(little)
                swap = false
#else
                swap = true
#endif
                bom = nil
            } else {
                fatalError("Unreachable")
            }
            
            // Grab this value once, as it requires doing a calculation over String's UTF8 storage
            let inputCount = self.utf16.count
            
            // The output may have 1 additional UTF16 character, if it has a BOM
            let outputCount = bom == nil ? inputCount : inputCount + 1
            
            // Allocate enough memory to hold the UTF16 bytes after conversion. We will pass this off to Data.
            let utf16Pointer = calloc(outputCount, MemoryLayout<UInt16>.size)!.assumingMemoryBound(to: UInt16.self)
            let utf16Buffer = UnsafeMutableBufferPointer<UInt16>(start: utf16Pointer, count: outputCount)
            
            if let bom {
                // Put the BOM in, then copy the UTF16 bytes to the buffer after it.
                utf16Buffer[0] = bom
                let afterBOMBuffer = UnsafeMutableBufferPointer(rebasing: utf16Buffer[1..<utf16Buffer.endIndex])
                if self.isContiguousUTF8 {
                    self._copyUTF16CodeUnits(into: afterBOMBuffer, range: 0..<inputCount)
                } else {
                    _ = afterBOMBuffer.initialize(fromContentsOf: self.utf16)
                }
            } else {
                if self.isContiguousUTF8 {
                    self._copyUTF16CodeUnits(into: utf16Buffer, range: 0..<inputCount)
                } else {
                    _ = utf16Buffer.initialize(fromContentsOf: self.utf16)
                }
            }            
            
            // If we need to swap endianness, we do it as a second pass over the data
            if swap {
#if _endian(little)
                // Swap, including the BOM if it is there
                for u in utf16Buffer.enumerated() {
                    utf16Buffer[u.0] = u.1.bigEndian
                }
#else
                for u in utf16Buffer.enumerated() {
                    utf16Buffer[u.0] = u.1.littleEndian
                }
#endif
            }
            
            return Data(bytesNoCopy: utf16Buffer.baseAddress!, count: utf16Buffer.count * 2, deallocator: .free)

        case .utf32BigEndian, .utf32LittleEndian:
            // This creates a contiguous storage for Data to simply memcpy.
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: self.unicodeScalars.count * 4) { utf32Buffer in
                _ = utf32Buffer.initialize(from: UnicodeScalarToDataAdaptor(self.unicodeScalars, endianness: Endianness(encoding)!))
                defer { utf32Buffer.deinitialize() }
                return Data(utf32Buffer)
            }
        case .utf32:
#if FOUNDATION_FRAMEWORK
            // Only the CoreFoundation code currently handles the rare case of allowing lossy conversion for UTF32
            if allowLossyConversion {
                return _ns.data(
                    using: encoding.rawValue,
                    allowLossyConversion: allowLossyConversion)
            }
#endif
#if _endian(little)
            let data = Data([0xFF, 0xFE, 0x00, 0x00])
            let hostEncoding : String.Encoding = .utf32LittleEndian
#else
            let data = Data([0x00, 0x00, 0xFE, 0xFF])
            let hostEncoding : String.Encoding = .utf32BigEndian
#endif
            guard let swapped = self.data(using: hostEncoding, allowLossyConversion: allowLossyConversion) else {
                return nil
            }
            
            return data + swapped
#if !FOUNDATION_FRAMEWORK
        case .isoLatin1:
            // ISO Latin 1 encodes code points 0x0 through 0xFF (a maximum of 2 UTF-8 scalars per ISO Latin 1 Scalar)
            // The UTF-8 count is a cheap, reasonable starting capacity as it is precise for the all-ASCII case and it will only over estimate by 1 byte per non-ASCII character
            return try? Data(capacity: self.utf8.count) { buffer in
                for scalar in self.unicodeScalars {
                    guard let valid = UInt8(exactly: scalar.value) else {
                        throw CocoaError(.fileWriteInapplicableStringEncoding)
                    }
                    buffer.appendElement(valid)
                }
            }
        case .macOSRoman:
            return try? Data(capacity: self.unicodeScalars.count) { buffer in
                for scalar in self.unicodeScalars {
                    guard let value = UInt8(macRomanFor: scalar) else {
                        throw CocoaError(.fileWriteInapplicableStringEncoding)
                    }
                    buffer.appendElement(value)
                }
            }
#endif
        default:
#if FOUNDATION_FRAMEWORK
            // Other encodings, defer to the CoreFoundation implementation
            return _ns.data(using: encoding.rawValue, allowLossyConversion: allowLossyConversion)
#else
            // Attempt an up-call into swift-corelibs-foundation, which can defer to the CoreFoundation implementation
            return _cfStringEncodingConvert(string: self, using: encoding.rawValue, allowLossyConversion: allowLossyConversion)
#endif
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension StringProtocol {
    /// A copy of the string with each word changed to its corresponding
    /// capitalized spelling.
    ///
    /// This property performs the canonical (non-localized) mapping. It is
    /// suitable for programming operations that require stable results not
    /// depending on the current locale.
    ///
    /// A capitalized string is a string with the first character in each word
    /// changed to its corresponding uppercase value, and all remaining
    /// characters set to their corresponding lowercase values. A "word" is any
    /// sequence of characters delimited by spaces, tabs, or line terminators.
    /// Some common word delimiting punctuation isn't considered, so this
    /// property may not generally produce the desired results for multiword
    /// strings. See the `getLineStart(_:end:contentsEnd:for:)` method for
    /// additional information.
    ///
    /// Case transformations aren’t guaranteed to be symmetrical or to produce
    /// strings of the same lengths as the originals.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var capitalized: String {
        String(self)._capitalized()
    }

#if FOUNDATION_FRAMEWORK
    /// Finds and returns the range in the `String` of the first
    /// character from a given character set found in a given range with
    /// given options.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func rangeOfCharacter(from aSet: CharacterSet, options mask: String.CompareOptions = [], range aRange: Range<Index>? = nil) -> Range<Index>? {
        var subStr = Substring(self)
        if let aRange {
            subStr = subStr[aRange]
        }
        return subStr._rangeOfCharacter(from: aSet, options: mask)
    }
#endif // FOUNDATION_FRAMEWORK

    /// Returns a `Data` containing a representation of
    /// the `String` encoded using a given encoding.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func data(using encoding: String.Encoding, allowLossyConversion: Bool = false) -> Data? {
        switch encoding {
        case .utf8:
            return Data(self.utf8)
        default:
#if FOUNDATION_FRAMEWORK
            // TODO: Implement data(using:allowLossyConversion:) in Swift
            return _ns.data(
                using: encoding.rawValue,
                allowLossyConversion: allowLossyConversion)
#else
            // Get a String, use the concrete implementation there
            return String(self).data(using: encoding, allowLossyConversion: allowLossyConversion)
#endif
        }
    }

    /// Returns an array containing substrings from the string that have been
    /// divided by the given separator.
    ///
    /// The substrings in the resulting array appear in the same order as the
    /// original string. Adjacent occurrences of the separator string produce
    /// empty strings in the result. Similarly, if the string begins or ends
    /// with the separator, the first or last substring, respectively, is empty.
    /// The following example shows this behavior:
    ///
    ///     let list1 = "Karin, Carrie, David"
    ///     let items1 = list1.components(separatedBy: ", ")
    ///     // ["Karin", "Carrie", "David"]
    ///
    ///     // Beginning with the separator:
    ///     let list2 = ", Norman, Stanley, Fletcher"
    ///     let items2 = list2.components(separatedBy: ", ")
    ///     // ["", "Norman", "Stanley", "Fletcher"
    ///
    /// If the list has no separators, the array contains only the original
    /// string itself.
    ///
    ///     let name = "Karin"
    ///     let list = name.components(separatedBy: ", ")
    ///     // ["Karin"]
    ///
    /// - Parameter separator: The separator string.
    /// - Returns: An array containing substrings that have been divided from the
    ///   string using `separator`.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func components<T : StringProtocol>(separatedBy separator: T) -> [String] {
#if FOUNDATION_FRAMEWORK
        if let contiguousSubstring = _asContiguousUTF8Substring(from: startIndex..<endIndex) {
            let options: String.CompareOptions
            if separator == "\n" {
                // 106365366: Some clients intend to separate strings whose line separator is "\r\n" with "\n".
                // Maintain compatibility with `.literal` so that "\n" can match that in "\r\n" on the unicode scalar level.
                options = [.literal]
            } else {
                options = []
            }

            do {
                return try contiguousSubstring._components(separatedBy: Substring(separator), options: options)
            } catch {
                // Otherwise, inputs were unsupported - fallthrough to NSString implementation for compatibility
            }
        }

        return _ns.components(separatedBy: separator._ephemeralString)
#else
        do {
            return try Substring(self)._components(separatedBy: Substring(separator), options: [])
        } catch {
            return [String(self)]
        }
#endif
    }

    /// Returns the range of characters representing the line or lines
    /// containing a given range.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func lineRange(for range: some RangeExpression<Index>) -> Range<Index> {
        let r = _lineBounds(around: range)
        return r.start ..< r.end
    }

    /// Returns the range of characters representing the
    /// paragraph or paragraphs containing a given range.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func paragraphRange(for range: some RangeExpression<Index>) -> Range<Index> {
        let r = _paragraphBounds(around: range)
        return r.start ..< r.end
    }
}

extension StringProtocol {
    @inline(never)
    internal func _lineBounds(
        around range: some RangeExpression<Index>
    ) -> (start: Index, end: Index, contentsEnd: Index) {
        // Avoid generic paths in the common case by manually specializing on `String` and
        // `Substring`. Note that we're only ever calling `_lineBounds` on a `Substring`; this is
        // to reduce the code size overhead of having to specialize it multiple times (at a slight
        // cost to runtime performance).
        if let s = _specializingCast(self, to: String.self) {
            let range = s.unicodeScalars._boundaryAlignedRange(range)
            return s[...].utf8._lineBounds(around: range)
        } else if let s = _specializingCast(self, to: Substring.self) {
            let range = s.unicodeScalars._boundaryAlignedRange(range)
            return s.utf8._lineBounds(around: range)
        } else {
            // Unexpected case. `StringProtocol`'s UTF-8 view is not properly constrained, so we
            // need to convert `self` to a Substring and carefully convert indices between the two
            // collections before & after the _lineBounds call.
            let range = self.unicodeScalars._boundaryAlignedRange(range)

            let startUTF8Offset = self.utf8.distance(from: self.startIndex, to: range.lowerBound)
            let utf8Count = self.utf8.distance(from: range.lowerBound, to: range.upperBound)

            let s = Substring(self)
            let start = s.utf8.index(s.startIndex, offsetBy: startUTF8Offset)
            let end = s.utf8.index(start, offsetBy: utf8Count)
            let r = s.utf8._lineBounds(around: start ..< end)

            let resultUTF8Offsets = (
                start: s.utf8.distance(from: s.startIndex, to: r.start),
                end: s.utf8.distance(from: s.startIndex, to: r.end),
                contentsEnd: s.utf8.distance(from: s.startIndex, to: r.contentsEnd))
            return (
                start: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.start),
                end: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.end),
                contentsEnd: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.contentsEnd))
        }
    }

    @inline(never)
    internal func _paragraphBounds(
        around range: some RangeExpression<Index>
    ) -> (start: Index, end: Index, contentsEnd: Index) {
        // Avoid generic paths in the common case by manually specializing on `String` and
        // `Substring`. Note that we're only ever calling `_paragraphBounds` on a `Substring`; this is
        // to reduce the code size overhead of having to specialize it multiple times (at a slight
        // cost to runtime performance).
        if let s = _specializingCast(self, to: String.self) {
            let range = s.unicodeScalars._boundaryAlignedRange(range)
            return s[...].utf8._paragraphBounds(around: range) // Note: We use [...] to get a Substring
        } else if let s = _specializingCast(self, to: Substring.self) {
            let range = s.unicodeScalars._boundaryAlignedRange(range)
            return s.utf8._paragraphBounds(around: range)
        } else {
            // Unexpected case. `StringProtocol`'s UTF-8 view is not properly constrained, so we
            // need to convert `self` to a Substring and carefully convert indices between the two
            // collections before & after the _lineBounds call.
            let range = self.unicodeScalars._boundaryAlignedRange(range)

            let startUTF8Offset = self.utf8.distance(from: self.startIndex, to: range.lowerBound)
            let utf8Count = self.utf8.distance(from: range.lowerBound, to: range.upperBound)

            let s = Substring(self)
            let start = s.utf8.index(s.startIndex, offsetBy: startUTF8Offset)
            let end = s.utf8.index(start, offsetBy: utf8Count)
            let r = s.utf8._paragraphBounds(around: start ..< end)

            let resultUTF8Offsets = (
                start: s.utf8.distance(from: s.startIndex, to: r.start),
                end: s.utf8.distance(from: s.startIndex, to: r.end),
                contentsEnd: s.utf8.distance(from: s.startIndex, to: r.contentsEnd))
            return (
                start: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.start),
                end: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.end),
                contentsEnd: self.utf8.index(self.startIndex, offsetBy: resultUTF8Offsets.contentsEnd))
        }
    }
}

