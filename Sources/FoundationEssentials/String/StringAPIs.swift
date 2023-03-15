//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(_ForSwiftFoundation)
@_implementationOnly import _ForSwiftFoundation
#endif

#if !FOUNDATION_FRAMEWORK
fileprivate func _foundation_essentials_feature_enabled() -> Bool { return true }
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension StringProtocol {
    // - (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //
    // - (NSRange)
    //     rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //     options:(StringCompareOptions)mask
    //
    // - (NSRange)
    //     rangeOfCharacterFromSet:(NSCharacterSet *)aSet
    //     options:(StringCompareOptions)mask
    //     range:(NSRange)aRange

    /// Finds and returns the range in the `String` of the first
    /// character from a given character set found in a given range with
    /// given options.
    public func rangeOfCharacter(from aSet: CharacterSet, options mask: String.CompareOptions = [], range aRange: Range<Index>? = nil) -> Range<Index>? {
        if _foundation_essentials_feature_enabled() {
            var subStr = Substring(self)
            if let aRange {
                subStr = subStr[aRange]
            }
            return subStr._rangeOfCharacter(from: aSet, options: mask)
        }

#if FOUNDATION_FRAMEWORK
        return aSet.withUnsafeImmutableStorage {
            return _optionalRange(_ns._rangeOfCharacter(from: $0, options: mask, range: _toRelativeNSRange(aRange ?? startIndex..<endIndex)))
        }
#else
        return nil
#endif // FOUNDATION_FRAMEWORK
    }

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
    public var capitalized: String {
#if FOUNDATION_FRAMEWORK // TODO: Implement `capitalized` in Swift
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized()
        }

        return _ns.capitalized
#else
        return String(self)
#endif
    }

    // - (NSData *)dataUsingEncoding:(NSStringEncoding)encoding
    //
    // - (NSData *)
    //     dataUsingEncoding:(NSStringEncoding)encoding
    //     allowLossyConversion:(BOOL)flag

    /// Returns a `Data` containing a representation of
    /// the `String` encoded using a given encoding.
    public func data(using encoding: String.Encoding, allowLossyConversion: Bool = false) -> Data? {
        switch encoding {
        case .utf8:
            return Data(self.utf8)
        default:
#if FOUNDATION_FRAMEWORK // TODO: Implement data(using:allowLossyConversion:) in Swift
            return _ns.data(
                using: encoding.rawValue,
                allowLossyConversion: allowLossyConversion)
#else
            return nil
#endif
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
    //===--- Initializers that can fail -------------------------------------===//
    // - (instancetype)
    //     initWithBytes:(const void *)bytes
    //     length:(NSUInteger)length
    //     encoding:(NSStringEncoding)encoding

    /// Creates a new string equivalent to the given bytes interpreted in the
    /// specified encoding.
    ///
    /// - Parameters:
    ///   - bytes: A sequence of bytes to interpret using `encoding`.
    ///   - encoding: The ecoding to use to interpret `bytes`.
    public init?<S: Sequence>(bytes: __shared S, encoding: Encoding)
        where S.Iterator.Element == UInt8
    {
#if FOUNDATION_FRAMEWORK // TODO: Move init?(bytes:encoding) to Swift
        func makeString(bytes: UnsafeBufferPointer<UInt8>) -> String? {
            if encoding == .utf8 || encoding == .ascii,
               let str = String._tryFromUTF8(bytes) {
                if encoding == .utf8 || (encoding == .ascii && str._guts._isContiguousASCII) {
                    return str
                }
            }

            if let ns = NSString(
                bytes: bytes.baseAddress.unsafelyUnwrapped, length: bytes.count, encoding: encoding.rawValue) {
                return String._unconditionallyBridgeFromObjectiveC(ns)
            } else {
                return nil
            }
        }
        if let string = (bytes.withContiguousStorageIfAvailable(makeString) ??
                         Array(bytes).withUnsafeBufferPointer(makeString)) {
            self = string
        } else {
            return nil
        }
#else
        guard encoding == .utf8 || encoding == .ascii else {
            return nil
        }
        func makeString(buffer: UnsafeBufferPointer<UInt8>) -> String? {
            if let string = String._tryFromUTF8(buffer),
               (encoding == .utf8 || (encoding == .ascii && string._guts._isContiguousASCII)) {
                return string
            }

            return buffer.withMemoryRebound(to: CChar.self) { ptr in
                guard let address = ptr.baseAddress else {
                    return nil
                }
                return String(validatingUTF8: address)
            }
        }

        if let string = bytes.withContiguousStorageIfAvailable(makeString) ??
            Array(bytes).withUnsafeBufferPointer(makeString) {
            self = string
        } else {
            return nil
        }
#endif // FOUNDATION_FRAMEWORK
    }

    // - (instancetype)
    //     initWithData:(NSData *)data
    //     encoding:(NSStringEncoding)encoding

    /// Returns a `String` initialized by converting given `data` into
    /// Unicode characters using a given `encoding`.
    public init?(data: __shared Data, encoding: Encoding) {
        if encoding == .utf8 || encoding == .ascii,
        let str = data.withUnsafeBytes({
            String._tryFromUTF8($0.bindMemory(to: UInt8.self))
        }) {
            if encoding == .utf8 || (encoding == .ascii && str._guts._isContiguousASCII) {
                self = str
                return
            }
        }
#if FOUNDATION_FRAMEWORK
        guard let s = NSString(data: data, encoding: encoding.rawValue) else { return nil }
        self = String._unconditionallyBridgeFromObjectiveC(s)
#else
        return nil
#endif // FOUNDATION_FRAMEWORK
    }
}

// MARK: - Stubbed Methods
extension StringProtocol {
#if !FOUNDATION_FRAMEWORK
    // - (NSComparisonResult)
    //     compare:(NSString *)aString
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(StringCompareOptions)mask
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(StringCompareOptions)mask
    //     range:(NSRange)range
    //
    // - (NSComparisonResult)
    //     compare:(NSString *)aString options:(StringCompareOptions)mask
    //     range:(NSRange)range locale:(id)locale

    /// Compares the string using the specified options and
    /// returns the lexical ordering for the range.
    internal func compare<T : StringProtocol>(_ aString: T, options mask: String.CompareOptions = [], range: Range<Index>? = nil) -> ComparisonResult {
        // TODO: This method is modified from `public func compare<T : StringProtocol>(_ aString: T, options mask: String.CompareOptions = [], range: Range<Index>? = nil, locale: Locale? = nil) -> ComparisonResult`. Move that method here once `Locale` can be staged in `FoundationEssentials`.
        var substr = Substring(self)
        if let range {
            substr = substr[range]
        }
        return substr._unlocalizedCompare(other: Substring(aString), options: mask)
    }
#endif
}


extension Substring.UnicodeScalarView {
    func _rangeOfCharacter(from set: CharacterSet, anchored: Bool, backwards: Bool) -> Range<Index>? {
        guard !isEmpty else { return nil }

        let fromLoc: String.Index
        let toLoc: String.Index
        let step: Int
        if backwards {
            fromLoc = index(before: endIndex)
            toLoc = anchored ? fromLoc : startIndex
            step = -1
        } else {
            fromLoc = startIndex
            toLoc = anchored ? fromLoc : index(before: endIndex)
            step = 1
        }

        var done = false
        var found = false

        var idx = fromLoc
        while !done {
            let ch = self[idx]
            if set.contains(ch) {
                done = true
                found = true
            } else if idx == toLoc {
                done = true
            } else {
                formIndex(&idx, offsetBy: step)
            }
        }

        guard found else { return nil }
        return idx..<index(after: idx)
    }
}
