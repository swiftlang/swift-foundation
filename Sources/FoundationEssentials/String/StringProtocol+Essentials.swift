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
@_implementationOnly import _ForSwiftFoundation
#else
internal func _foundation_essentials_feature_enabled() -> Bool { return true }
#endif

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
#if FOUNDATION_FRAMEWORK
        if _foundation_essentials_feature_enabled() {
            return String(self)._capitalized()
        }

        return _ns.capitalized
#else
        return String(self)._capitalized()
#endif
    }

#if FOUNDATION_FRAMEWORK
    /// Finds and returns the range in the `String` of the first
    /// character from a given character set found in a given range with
    /// given options.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func rangeOfCharacter(from aSet: CharacterSet, options mask: String.CompareOptions = [], range aRange: Range<Index>? = nil) -> Range<Index>? {
        if _foundation_essentials_feature_enabled() {
            var subStr = Substring(self)
            if let aRange {
                subStr = subStr[aRange]
            }
            return subStr._rangeOfCharacter(from: aSet, options: mask)
        }

        return aSet.withUnsafeImmutableStorage {
            return _optionalRange(_ns._rangeOfCharacter(from: $0, options: mask, range: _toRelativeNSRange(aRange ?? startIndex..<endIndex)))
        }
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
#if FOUNDATION_FRAMEWORK // TODO: Implement data(using:allowLossyConversion:) in Swift
            return _ns.data(
                using: encoding.rawValue,
                allowLossyConversion: allowLossyConversion)
#else
            return nil
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
        if _foundation_essentials_feature_enabled() {
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
