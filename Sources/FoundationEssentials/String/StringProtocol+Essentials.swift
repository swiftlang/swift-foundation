//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
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
    public func lineRange<R : RangeExpression>(for aRange: R) -> Range<Index> where R.Bound == Index {
        String(self).lineRange(for: aRange)
    }

    /// Returns the range of characters representing the
    /// paragraph or paragraphs containing a given range.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func paragraphRange<R : RangeExpression>(for aRange: R) -> Range<Index> where R.Bound == Index {
        String(self).paragraphRange(for: aRange)
    }
}

extension String {
    internal func lineRange<R : RangeExpression>(for aRange: R) -> Range<Index> where R.Bound == Index {

        // It's possible that passed-in indices are not on unicode scalar boundaries, such as when they're UTF-16 indices.
        // Expand the bounds to ensure they are so we can meaningfully iterate their UTF8 views.
        let r = unicodeScalars._boundaryAlignedRange(aRange)
        let result = utf8._getBlock(for: [.findStart, .findEnd, .stopAtLineSeparators], in: r)

        guard let start = result.start else {
            guard let end = result.end else {
                return startIndex ..< endIndex
            }
            return startIndex ..< end
        }

        guard let upper = result.end else {
            return start ..< endIndex
        }

        return start..<upper
    }

    internal func paragraphRange<R : RangeExpression>(for aRange: R) -> Range<Index> where R.Bound == Index {
        let r = unicodeScalars._boundaryAlignedRange(aRange)
        let result = utf8._getBlock(for: [.findStart, .findEnd], in: r)
        guard let start = result.start else {
            guard let end = result.end else {
                return startIndex ..< endIndex
            }
            return startIndex ..< end
        }

        guard let upper = result.end else {
            return start ..< endIndex
        }

        return start..<upper
    }
}
