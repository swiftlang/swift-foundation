//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    /// A type that defines the behavior when merging attributes.
    public enum AttributeMergePolicy : Sendable {
        /// The new value for this attribute takes precedence.
        case keepNew
        /// The existing value for this attribute takes precedence.
        case keepCurrent
        
        internal var combinerClosure: (_AttributeValue, _AttributeValue) -> _AttributeValue {
            switch self {
            case .keepNew: return { _, new in new }
            case .keepCurrent: return { current, _ in current }
            }
        }
    }
}

/// A protocol that defines in-place mutations for attributes in an attributed string.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringAttributeMutation {
    /// Sets the attributed string's attributes to those in a specified attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The attribute container with the attributes to apply.
    mutating func setAttributes(_ attributes: AttributeContainer)
    /// Merges the attributed string's attributes with those in a specified attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The attribute container with the attributes to merge.
    ///   - mergePolicy: A policy to use when resolving conflicts between this string's attributes and those in `attributes`.
    mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy)
    /// Replaces the attributed string's attributes with those in a specified attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The existing attributes to replace.
    ///   - others: The new attributes to apply.
    mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer)
}

/// A protocol that provides common functionality to attributed strings and attributed substrings.
///
/// Don't declare new conformances to ``AttributedStringProtocol``. Only the ``AttributedString`` and ``AttributedSubstring`` types in the standard library are valid conforming types.
@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol AttributedStringProtocol
    : AttributedStringAttributeMutation, Hashable, CustomStringConvertible, Sendable
{
    /// The position of the first character in a nonempty attributed string.
    var startIndex : AttributedString.Index { get }
    /// A string's past-the-end position — the position one greater than the last valid subscript argument.
    var endIndex : AttributedString.Index { get }

    /// The attributed runs of the attributed string, as a view into the underlying string.
    ///
    /// Runs begin and end when the attributes for the characters change. Use this property to iterate over the runs with `for`-`in` syntax.
    var runs : AttributedString.Runs { get }
    /// The characters of the attributed string, as a view into the underlying string.
    ///
    /// Use the ``AttributedStringProtocol/characters`` view when you want to look for specific string content. You can then use the resulting ranges to set attributes for specific parts of the ``AttributedString`` or ``AttributedSubstring``.
    var characters : AttributedString.CharacterView { get }
    /// The Unicode scalars of the attributed string, as a view into the underlying string.
    ///
    /// Use this property when you want to split the attributed string by Unicode scalar instead of grapheme cluster. This is useful when you need to carefully control insertion points or render the content.
    var unicodeScalars : AttributedString.UnicodeScalarView { get }
    
    @available(FoundationPreview 6.2, *)
    var utf8 : AttributedString.UTF8View { get }
    
    @available(FoundationPreview 6.2, *)
    var utf16 : AttributedString.UTF16View { get }

    /// Returns an attribute value that corresponds to an attributed string key.
    ///
    /// This subscript returns `nil` unless the specified attribute exists, and is present and identical for the entire attributed string or substring. To find portions of an attributed string with consistent attributes, use the ``AttributedString/runs`` property.
    @preconcurrency subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable { get set }
    /// Returns an attribute value that a key path indicates.
    ///
    /// This subscript returns `nil` unless the specified attribute exists, and is present and identical for the entire attributed string or substring. To find portions of an attributed string with consistent attributes, use the ``AttributedStringProtocol/runs`` property.
    @preconcurrency subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value : Sendable { get set }
    /// Returns a scoped attribute container that a key path indicates.
    ///
    /// Use this subscript when you need to work with an explicit attribute scope. For example, the SwiftUI ``AttributeScopes/SwiftUIAttributes/foregroundColor`` attribute overrides the attribute in the AppKit and UIKit scopes with the same name. If you work with both the SwiftUI and UIKit scopes, you can use the syntax `myAttributedString.uiKit.foregroundColor` to disambiguate and explicitly use the UIKit attribute.
    subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> { get set }

    /// Returns a substring of the attributed string using a range to indicate the substring bounds.
    subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == AttributedString.Index { get }
}


@available(FoundationPreview 6.2, *)
extension AttributedStringProtocol {
    var utf8 : AttributedString.UTF8View {
        AttributedString.UTF8View(__guts, in: Range(uncheckedBounds: (startIndex._value, endIndex._value)))
    }
    
    var utf16 : AttributedString.UTF16View {
        AttributedString.UTF16View(__guts, in: Range(uncheckedBounds: (startIndex._value, endIndex._value)))
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    /// Returns an attributed string by setting the attributed string's attributes to those in a specified attribute container.
    ///
    /// - Parameter attributes: The attribute container with the attributes to apply.
    /// - Returns: An attributed string from setting the attributed string's attributes to those in a specified attribute container.
    public func settingAttributes(_ attributes: AttributeContainer) -> AttributedString {
        var new = AttributedString(self)
        new.setAttributes(attributes)
        return new
    }

    /// Returns an attributed string by merging the attributed string's attributes with those in a specified attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The attribute container with the attributes to merge.
    ///   - mergePolicy: A policy to use when resolving conflicts between this string's attributes and those in `attributes`.
    public func mergingAttributes(
        _ attributes: AttributeContainer,
        mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew
    ) -> AttributedString {
        var new = AttributedString(self)
        new.mergeAttributes(attributes, mergePolicy:  mergePolicy)
        return new
    }

    /// Returns an attributed string by replacing occurrences of attributes in one attribute container with those in another attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The existing attributes to replace.
    ///   - others: The new attributes to apply.
    public func replacingAttributes(
        _ attributes: AttributeContainer, with others: AttributeContainer
    ) -> AttributedString {
        var new = AttributedString(self)
        new.replaceAttributes(attributes, with: others)
        return new
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    internal var __guts: AttributedString.Guts {
        if let s = _specializingCast(self, to: AttributedString.self) {
            return s._guts
        } else if let s = _specializingCast(self, to: AttributedSubstring.self) {
            return s._guts
        } else {
            return self.characters._guts
        }
    }
    
    internal var _baseString: BigString {
        __guts.string
    }

    internal var _bounds: Range<AttributedString.Index> {
        Range(uncheckedBounds: (startIndex, endIndex))
    }

    internal var _stringBounds: Range<BigString.Index> {
        Range(uncheckedBounds: (startIndex._value, endIndex._value))
    }

    internal var _characters: BigSubstring {
        _baseString[_stringBounds]
    }
}

extension AttributedString {
    internal var _baseString: BigString {
        _guts.string
    }
    
    internal var _bounds: Range<AttributedString.Index> {
        Range(uncheckedBounds: (startIndex, endIndex))
    }

    internal var _stringBounds: Range<BigString.Index> {
        Range(uncheckedBounds: (_guts.string.startIndex, _guts.string.endIndex))
    }
}

extension AttributedSubstring {
    internal var _baseString: BigString {
        _guts.string
    }
    
    internal var _bounds: Range<AttributedString.Index> {
        let lower = AttributedString.Index(_range.lowerBound, version: _guts.version)
        let upper = AttributedString.Index(_range.upperBound, version: _guts.version)
        return Range(uncheckedBounds: (lower, upper))
    }

    internal var _stringBounds: Range<BigString.Index> {
        _range
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol { // CustomStringConvertible
    public var description: String {
        AttributedString.Guts._description(in: runs)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol { // Equatable, Hashable
    @_specialize(where Self == AttributedString, RHS == AttributedString)
    @_specialize(where Self == AttributedString, RHS == AttributedSubstring)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedString)
    @_specialize(where Self == AttributedSubstring, RHS == AttributedSubstring)
    public static func == <RHS: AttributedStringProtocol>(lhs: Self, rhs: RHS) -> Bool {
        AttributedString.Guts._characterwiseIsEqual(lhs.runs, to: rhs.runs)
    }

    public func hash(into hasher: inout Hasher) {
        AttributedString.Guts.characterwiseHash(runs: runs, into: &hasher)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    /// Returns the position of the character immediately after another charcter indicated by an index.
    ///
    /// - Parameter i: The index of a character in the attributed string.
    /// - Returns: The position of the character immediately after the character at index `i`.
    public func index(afterCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(after: i)
    }
    /// Returns the position of the character immediately before another charcter indicated by an index.
    ///
    /// - Parameter i: The index of a character in the attributed string.
    /// - Returns: The position of the character immediately before the character at index `i`.
    public func index(beforeCharacter i: AttributedString.Index) -> AttributedString.Index {
        self.characters.index(before: i)
    }
    /// Returns the position of the character offset a given distance, measured in characters, from a given string index.
    ///
    /// - Parameters:
    ///   - i: The index of a position in the string.
    ///   - distance: The number of charcters to advance by.
    public func index(_ i: AttributedString.Index, offsetByCharacters distance: Int) -> AttributedString.Index {
        self.characters.index(i, offsetBy: distance)
    }

    /// Returns the position of the Unicode scalar immediately after a Unicode scalar indicated by an index.
    ///
    /// - Parameter i: The index of a Unicode scalar in the attributed string.
    /// - Returns: The position of the Unicode scalar immediately after the Unicode scalar at index `i`.
    public func index(afterUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(after: i)
    }
    /// Returns the position of the Unicode scalar immediately before a Unicode scalar indicated by an index.
    ///
    /// - Parameter i: The index of a Unicode scalar in the attributed string.
    /// - Returns: The position of the Unicode scalar immediately before the Unicode scalar at index `i`.
    public func index(beforeUnicodeScalar i: AttributedString.Index) -> AttributedString.Index {
        self.unicodeScalars.index(before: i)
    }
    /// Returns the position of the Unicode scalar offset a given distance, measured in Unicode scalars, from a given string index.
    ///
    /// - Parameters:
    ///   - i: The index of a position in the string.
    ///   - distance: The number of Unicode scalars to advance by.
    public func index(_ i: AttributedString.Index, offsetByUnicodeScalars distance: Int) -> AttributedString.Index {
        self.unicodeScalars.index(i, offsetBy: distance)
    }

    /// Returns the position of the run immediately after a run indicated by an index.
    ///
    /// - Parameter i: The index of a run in the attributed string.
    /// - Returns: The position of first run immediately after the end of `i`-th run.
    public func index(afterRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: Result is the end of the run that contains `i`.
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(i._value >= bounds.lowerBound, "Invalid attributed string index")
        precondition(i._value < bounds.upperBound, "Can't advance beyond end index")
        let next = guts.index(afterRun: i._value)
        assert(next > i._value)
        return AttributedString.Index(Swift.min(next, bounds.upperBound), version: guts.version)
    }

    /// Returns the position of the run immediately before a run indicated by an index.
    ///
    /// - Parameter i: The index of a run in the attributed string.
    /// - Returns: The position of the first run immediately before the beginning of the `i`-th run.
    public func index(beforeRun i: AttributedString.Index) -> AttributedString.Index {
        // Expected semantics: result is the start of the run preceding the one that contains `i`.
        // (I.e., `i` needs to get implicitly rounded down to the nearest run boundary before we
        // step back.)
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(i._value > bounds.lowerBound, "Can't advance below start index")
        precondition(i._value <= bounds.upperBound, "Invalid attributed string index")
        let prev = guts.index(beforeRun: i._value)
        assert(prev < i._value)
        return AttributedString.Index(Swift.max(prev, bounds.lowerBound), version: guts.version)
    }

    /// Returns the position of the run offset a given number of runs from a given string index.
    ///
    /// - Parameters:
    ///   - i: The index of a position in the string.
    ///   - distance: The number of runs to advance by.
    public func index(_ i: AttributedString.Index, offsetByRuns distance: Int) -> AttributedString.Index {
        let guts = self.__guts
        let bounds = self._stringBounds
        precondition(
            i._value >= bounds.lowerBound && i._value <= bounds.upperBound,
            "Invalid attributed string index")
        let startRun = guts.runs.index(atUTF8Offset: i._value.utf8Offset).index
        let run = guts.runs.index(startRun, offsetBy: distance)
        let length = (run == guts.runs.endIndex ? 0 : guts.runs[run].length)

        precondition(
            bounds.lowerBound.utf8Offset <= run.utf8Offset + length,
            "Attributed string index out of bounds")
        if bounds.upperBound.utf8Offset <= run.utf8Offset {
            let end = guts.runs.index(atUTF8Offset: bounds.upperBound.utf8Offset)
            let endRunOffset = end.index.offset + (end.remainingUTF8 == 0 ? 0 : 1)
            precondition(run.offset <= endRunOffset, "Attributed string index out of bounds")
        }

        let result = guts.string.utf8.index(i._value, offsetBy: run.utf8Offset - i._value.utf8Offset)
        let clamped = Swift.min(Swift.max(result, bounds.lowerBound), bounds.upperBound)
        return AttributedString.Index(clamped, version: guts.version)
    }

    internal func _utf8Index(at utf8Offset: Int) -> AttributedString.Index {
        let startOffset = self.startIndex._value.utf8Offset
        return AttributedString.Index(self.__guts.utf8Index(at: startOffset + utf8Offset), version: self.__guts.version)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedStringProtocol {
    internal func _range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = []) -> Range<AttributedString.Index>? {

        // TODO: Implement this on BigString to avoid O(n) iteration
        let substring = Substring(String(_characters: self.characters))
        guard let range = try? substring._range(of: Substring(stringToFind), options: options) else {
            return nil
        }

        let startOffset = substring.utf8.distance(from: substring.startIndex, to: range.lowerBound) // O(1)
        let endOffset = substring.utf8.distance(from: substring.startIndex, to: range.upperBound) // O(1)

        return self._utf8Index(at: startOffset) ..< self._utf8Index(at: endOffset) // O(log(n))
    }

    /// Returns the range of a substring in the attributed string, if it exists.
    ///
    /// - Parameters:
    ///   - stringToFind: The string to find.
    ///   - options: Options that affect the search behavior, such as case-insensivity, search direction, and regular expression matching.
    ///   - locale: The locale to use when searching, or `nil` to use the current locale. The default is `nil`.
    public func range<T: StringProtocol>(of stringToFind: T, options: String.CompareOptions = [], locale: Locale? = nil) -> Range<AttributedString.Index>? {
        if locale == nil {
            return _range(of: stringToFind, options: options)
        }
#if FOUNDATION_FRAMEWORK
        // TODO: Implement localized AttributedStringProtocol.range(of:) for FoundationPreview
        // Since we have secret access to the String property, go ahead and use the full implementation given by Foundation rather than the limited reimplementation we needed for CharacterView.
        // FIXME: There is no longer a `String` property. This is going to be terribly slow.
        let bstring = self.__guts.string
        let bounds = self._stringBounds
        let string = String(bstring[bounds])
        guard let range = string.range(of: stringToFind, options: options, locale: locale) else {
            return nil
        }
        // Restore original index range.
        let utf8Start = string.utf8.distance(from: string.startIndex, to: range.lowerBound)
        let utf8End = string.utf8.distance(from: string.startIndex, to: range.upperBound)

        let start = bstring.utf8.index(bounds.lowerBound, offsetBy: utf8Start)
        let end = bstring.utf8.index(bounds.lowerBound, offsetBy: utf8End)

        return AttributedString.Index(start, version: self.__guts.version) ..< AttributedString.Index(end, version: self.__guts.version)
#else
        // TODO: Implement localized AttributedStringProtocol.range(of:) for FoundationPreview
        return _range(of: stringToFind, options: options)
#endif // FOUNDATION_FRAMEWORK
    }
}

