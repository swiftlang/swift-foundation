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

internal import Synchronization

/// A value type for a string with associated attributes for portions of its text.
///
/// Attributed strings are character strings that have attributes for individual characters or
/// ranges of characters. Attributes provide traits like visual styles for display, accessibility
/// for guided access, and hyperlink data for linking between data sources. Attribute keys provide
/// the name and value type of each attribute. System frameworks like Foundation and SwiftUI define
/// common keys, and you can define your own in custom extensions.
///
/// ## String Attributes
///
/// You can apply an attribute to an entire string, or to a range within the string. The string
/// represents each range with consistent attributes as a *run*. ``AttributedString`` uses
/// subscripts and dynamic member lookup to simplify working with attributes from your call points.
///
/// In its most verbose form, you set an attribute by creating an ``AttributeContainer`` and
/// merging it into an existing attributed string, like this:
///
/// ```swift
/// var attributedString = AttributedString("This is a string with empty attributes.")
/// var container = AttributeContainer()
/// container[AttributeScopes.AppKitAttributes.ForegroundColorAttribute.self] = .red
/// attributedString.mergeAttributes(container, mergePolicy: .keepNew)
/// ```
///
/// Using the attributed string's ``subscript(_:)-6gvcp`` method, you can omit the explicit use of
/// an ``AttributeContainer`` and just set the attribute by its type:
///
/// ```swift
/// attributedString[AttributeScopes.AppKitAttributes.ForegroundColorAttribute.self] = .yellow
/// ```
///
/// Because an ``AttributedString`` supports dynamic member lookup — as described under
/// [Attributes](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes)
/// in *The Swift Programming Language* — you can access its subscripts with dot syntax instead.
/// When combined with properties like `foregroundColor` that return the attribute key type, this
/// final form offers a natural way to set an attribute that applies to an entire string:
///
/// ```swift
/// attributedString.foregroundColor = .green
/// ```
///
/// You can also set an attribute to apply only to part of an attributed string, by applying the
/// attribute to a range, as seen here:
///
/// ```swift
/// var attributedString = AttributedString("The first month of your subscription is free.")
/// guard let range = attributedString.range(of: "free") else { return }
/// attributedString[range].foregroundColor = .green
/// ```
///
/// You can access portions of the string with unique combinations of attributes by iterating over
/// the string's ``runs`` property.
///
/// You can define your own custom attributes by creating types that conform to
/// ``AttributedStringKey``, and collecting them in an ``AttributeScope``. Custom keys should also
/// extend ``AttributeDynamicLookup``, so callers can use dot-syntax to access the attribute.
///
/// ## Creating Attributed Strings with Markdown
///
/// You can create an attributed string by passing a standard `String` or `Data` instance that
/// contains Markdown to initializers like ``init(markdown:options:baseURL:)-52n3u``. The attributed
/// string creates attributes by parsing the markup in the string.
///
/// ```swift
/// do {
///     let thankYouString = try AttributedString(
///         markdown: "**Thank you!** Please visit our [website](https://example.com)")
/// } catch {
///     print("Couldn't parse the string. \(error.localizedDescription)")
/// }
/// ```
///
/// Localized strings that you load from strings files with initializers like
/// ``init(localized:options:table:bundle:locale:comment:)-8dlnl`` can also contain Markdown to add
/// styling. In addition, these localized attributed string initializers can apply the
/// ``AttributeScopes/FoundationAttributes/ReplacementIndexAttribute`` attribute, which allows you
/// to determine the range of replacement strings, whose order may vary between languages.
///
/// By declaring new attributes that conform to ``MarkdownDecodableAttributedStringKey``, you can
/// add attributes that you invoke by using Apple's Markdown extension syntax:
/// `^[text](name: value, name: value, …)`.
///
/// Localized attributed strings can also use the extension syntax to indicate parts of the string
/// where the system can apply automatic grammar agreement. See the initializers that take a
/// `localized:` parameter for examples of this extension syntax, as used with automatic grammar
/// agreement.
///
/// ## Attribute Scopes
///
/// The ``AttributedString`` API defines keys for common uses, such as text styling, semantically
/// marking up formattable types like dates and numbers, and hyperlinking. You can find these in the
/// ``AttributeScopes`` enumeration, which contains attributes for AppKit, Foundation, SwiftUI, and
/// UIKit.
///
/// You can define your own attributes by implementing ``AttributedStringKey``, and reference them
/// by name by collecting them in an ``AttributeScope``.
@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributedString : Sendable {
    internal var _guts: Guts

    internal init(_ guts: Guts) {
        _guts = guts
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal static let currentIdentity = Atomic(0)
    internal static var _nextModifyIdentity : Int {
        currentIdentity.wrappingAdd(1, ordering: .relaxed).newValue
    }
}

// MARK: Initialization
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    /// Creates an empty attributed string.
    public init() {
        self._guts = Guts()
    }

    internal init(_ s: some AttributedStringProtocol) {
        if let s = _specializingCast(s, to: AttributedString.self) {
            self = s
        } else if let s = _specializingCast(s, to: AttributedSubstring.self) {
            self = AttributedString(s)
        } else {
            // !!!: We don't expect or want this to happen.
            let substring = AttributedSubstring(s.__guts, in: s._stringBounds)
            self = AttributedString(substring)
        }
    }

    internal init(_ string: BigString, attributes: _AttributeStorage) {
        guard !string.isEmpty else {
            self.init()
            return
        }
        var runs = _InternalRuns.Storage()
        runs.append(_InternalRun(length: string.utf8.count, attributes: attributes))
        self.init(Guts(string: string, runs: _InternalRuns(runs)))
        // Only scalar-bound attributes can be incorrect if only one run exists
        if attributes.containsScalarConstraint {
            _guts.fixScalarConstrainedAttributes(in: string.startIndex ..< string.endIndex)
        }
    }

    /// Creates a new attributed string with the given `String` value associated with the given
    /// attributes.
    ///
    /// - Parameters:
    ///   - string: A string to add attributes to.
    ///   - attributes: Attributes to apply to `string`.
    public init(_ string: String, attributes: AttributeContainer = .init()) {
        self.init(BigString(string), attributes: attributes.storage)
    }

    /// Creates a new attributed string with the given `Substring` value associated with the given
    /// attributes.
    ///
    /// - Parameters:
    ///   - substring: A substring to add attributes to.
    ///   - attributes: Attributes to apply to `substring`.
    public init(_ substring: Substring, attributes: AttributeContainer = .init()) {
        self.init(BigString(substring), attributes: attributes.storage)
    }

    /// Creates an attributed string from a character sequence and an attribute container.
    ///
    /// - Parameters:
    ///   - elements: A character sequence that provides the textual content for the attributed string.
    ///   - attributes: Attributes to apply to the textual content.
    public init<S : Sequence>(
        _ elements: S,
        attributes: AttributeContainer = .init()
    ) where S.Element == Character {
        let str = Self._bstring(from: elements)
        self.init(str, attributes: attributes.storage)
    }

    /// Creates an attributed string from an attributed substring.
    ///
    /// - Parameter substring: An attributed substring to create the new attributed string from.
    public init(_ substring: AttributedSubstring) {
        let str = BigString(substring._unicodeScalars)
        let runs = substring._guts.runs.extract(utf8Offsets: substring._range._utf8OffsetRange)
        assert(str.utf8.count == runs.utf8Count)
        _guts = Guts(string: str, runs: runs)
        // FIXME: Extracting a slice should invalidate .textChanged attribute runs on the edges
        // (Compare with the `copy(in:)` call in the scope filtering initializer below -- that
        // one does too much, this one does too little.)
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Support scope-specific initialization in FoundationPreview
    /// Creates an attributed string from another attributed string, including an attribute scope that a key path identifies.
    ///
    /// - Parameters:
    ///   - other: An attributed string or attributed substring.
    ///   - scope: An ``AttributeScopes`` key path that identifies an attribute scope to associate with the attributed string.
    public init<S : AttributeScope, T : AttributedStringProtocol>(_ other: T, including scope: KeyPath<AttributeScopes, S.Type>) {
        self.init(other, including: S.self)
    }

    /// Creates an attributed string from another attributed string, including an attribute scope.
    ///
    /// - Parameters:
    ///   - other: An attributed string or attributed substring.
    ///   - scope: An attribute scope to associate with the attributed string.
    public init<S : AttributeScope, T : AttributedStringProtocol>(_ other: T, including scope: S.Type) {
        // FIXME: This `copy(in:)` call does too much work, potentially unexpectedly removing attributes.
        self.init(other.__guts.copy(in: other._stringBounds))
        let attributeTypes = scope.attributeKeyTypes()

        _guts.runs(in: _guts.utf8OffsetRange).updateEach { attributes, utf8Range, modified in
            modified = false
            for key in attributes.keys {
                if !attributeTypes.keys.contains(key) {
                    attributes[key] = nil
                    modified = true
                }
            }
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal static func _bstring<S: Sequence<Character>>(from elements: S) -> BigString {
        if let elements = _specializingCast(elements, to: String.self) {
            return BigString(elements)
        }
        if let elements = _specializingCast(elements, to: Substring.self) {
            return BigString(elements)
        }
        if let elements = _specializingCast(elements, to: AttributedString.CharacterView.self) {
            return BigString(elements._characters)
        }
        if let elements = _specializingCast(
            elements, to: Slice<AttributedString.CharacterView>.self
        ) {
            return BigString(elements._characters)
        }
        return BigString(elements)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString { // Equatable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs._guts === rhs._guts {
            return true
        }
        return AttributedString.Guts.characterwiseIsEqual(lhs._guts, to: rhs._guts)
    }
}

// Note: The Hashable implementation is inherited from AttributedStringProtocol.

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString: ExpressibleByStringLiteral {
    /// Creates an attributed string from the specified string literal, with no attributes.
    ///
    /// - Parameter value: The string literal that provides the attributed string's initial content.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString { // AttributedStringAttributeMutation
    /// Sets the attributed string's attributes to those in a specified attribute container.
    ///
    /// - Parameter attributes: The attribute container with the attributes to apply.
    public mutating func setAttributes(_ attributes: AttributeContainer) {
        ensureUniqueReference()
        _guts.setAttributes(attributes.storage, in: _stringBounds)
    }

    /// Merges the attributed string's attributes with those in a specified attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The attribute container with the attributes to merge.
    ///   - mergePolicy: A policy to use when resolving conflicts between this string's attributes and those in `attributes`.
    public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy:  AttributeMergePolicy = .keepNew) {
        ensureUniqueReference()
        _guts.mergeAttributes(attributes, in: _stringBounds, mergePolicy:  mergePolicy)
    }

    /// Replaces occurrences of attributes in one attribute container with those in another attribute container.
    ///
    /// - Parameters:
    ///   - attributes: The existing attributes to replace.
    ///   - others: The new attributes to apply.
    public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
        guard attributes != others else { return }
        ensureUniqueReference()
        let hasConstrainedAttributes = attributes._hasConstrainedAttributes || others._hasConstrainedAttributes
        var fixupRanges: [Range<Int>] = []

        _guts.runs(in: _guts.utf8OffsetRange).updateEach(
            when: { $0.matches(attributes.storage) },
            with: { runAttributes, utf8Range in
                for key in attributes.storage.keys {
                    runAttributes[key] = nil
                }
                runAttributes.mergeIn(others)
                if hasConstrainedAttributes {
                    fixupRanges._extend(with: utf8Range)
                }
            })
        for range in fixupRanges {
            // FIXME: Collect boundary constraints.
            _guts.enforceAttributeConstraintsAfterMutation(in: range, type: .attributes)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString: AttributedStringProtocol {
    /// A type that represents the position of a character or code unit within an attributed string.
    public struct Index : Comparable, Sendable {
        internal var _value: BigString.Index
        internal var _version: AttributedString.Guts.Version

        internal init(_ value: BigString.Index, version: AttributedString.Guts.Version) {
            self._value = value
            self._version = version
        }

        public static func == (left: Self, right: Self) -> Bool {
            left._value == right._value
        }

        public static func < (left: Self, right: Self) -> Bool {
            left._value < right._value
        }
    }
    
    /// The position of the first character in a nonempty attributed string.
    ///
    /// In an empty string, `startIndex` is equal to `endIndex`.
    public var startIndex : Index {
        Index(_guts.string.startIndex, version: _guts.version)
    }
    
    /// The string's past-the-end position — the position one greater than the last valid subscript argument.
    ///
    /// In an empty string, `endIndex` is equal to `startIndex`.
    public var endIndex : Index {
        Index(_guts.string.endIndex, version: _guts.version)
    }
    
    @preconcurrency
    public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable {
        get {
            _guts.getUniformValue(in: _stringBounds, key: K.self)?.rawValue(as: K.self)
        }
        set {
            ensureUniqueReference()
            if let v = newValue {
                _guts.setAttributeValue(v, forKey: K.self, in: _stringBounds)
            } else {
                _guts.removeAttributeValue(forKey: K.self, in: _stringBounds)
            }
        }
    }
    
    /// Returns an attribute value that a key path indicates.
    ///
    /// This subscript returns `nil` unless the specified attribute exists, and is present and
    /// identical for the entire attributed string or substring. To find portions of the string
    /// with consistent attributes, use the ``AttributedString/runs`` property.
    ///
    /// Getting or setting stringwide attributes with this subscript has `O(n)` behavior in
    /// the worst case, where `n` is the number of runs.
    @preconcurrency
    @inlinable // Trivial implementation, allows callers to optimize away the keypath allocation
    public subscript<K: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>
    ) -> K.Value? where K.Value: Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
    
    /// Returns a scoped attribute container that a key path indicates.
    ///
    /// Use this subscript when you need to work with an explicit attribute scope. For example,
    /// the SwiftUI `foregroundColor` attribute overrides the attribute in the AppKit and UIKit
    /// scopes with the same name. If you work with both the SwiftUI and UIKit scopes, you can
    /// use the syntax `myAttributedString.uiKit.foregroundColor` to disambiguate and explicitly
    /// use the UIKit attribute.
    ///
    /// The attribute container that this method returns contains only attributes that exist,
    /// and are present and identical for the entire attributed string. To find portions of the
    /// string with consistent attributes, use the ``AttributedString/runs`` property.
    ///
    /// Getting or setting stringwide attributes with this subscript has `O(n)` behavior in
    /// the worst case, where `n` is the number of runs.
    public subscript<S: AttributeScope>(
        dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>
    ) -> ScopedAttributeContainer<S> {
        get {
            return ScopedAttributeContainer(_guts.getUniformValues(in: _stringBounds))
        }
        _modify {
            ensureUniqueReference()
            var container = ScopedAttributeContainer<S>()
            defer {
                if let removedKey = container.removedKey {
                    _guts.removeAttributeValue(forKey: removedKey, in: _stringBounds)
                } else {
                    _guts.mergeAttributes(AttributeContainer(container.storage), in: _stringBounds)
                }
            }
            yield &container
        }
    }
}

// MARK: Mutating operations
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal mutating func ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
        _guts.incrementVersion()
    }

    /// Appends a string to the attributed string.
    ///
    /// - Parameter s: The string to append.
    public mutating func append(_ s: some AttributedStringProtocol) {
        replaceSubrange(endIndex ..< endIndex, with: s)
    }

    /// Inserts the specified string at a specific index in the attributed string.
    ///
    /// - Parameters:
    ///   - s: The string to insert.
    ///   - index: The index that indicates where to insert the string.
    public mutating func insert(_ s: some AttributedStringProtocol, at index: AttributedString.Index) {
        replaceSubrange(index ..< index, with: s)
    }

    /// Removes a range of characters from the attributed string.
    ///
    /// - Parameter range: The range to remove.
    public mutating func removeSubrange(_ range: some RangeExpression<Index>) {
        replaceSubrange(range, with: AttributedString())
    }

    /// Replaces the contents in a range of the attributed string.
    ///
    /// - Parameters:
    ///   - range: The range of the attributed string to replace.
    ///   - s: The string to insert in place of the replaced range.
    public mutating func replaceSubrange(_ range: some RangeExpression<Index>, with s: some AttributedStringProtocol) {
        ensureUniqueReference()
        // Note: slicing generally allows sub-Character ranges, but we need to resolve range
        // expressions using the characters view, to remain consistent with the stdlib.
        let subrange = range.relative(to: characters)._bstringRange
        _guts.replaceSubrange(subrange, with: s)
    }
}

// MARK: Concatenation operators
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    /// Concatenates two attributed strings or substrings.
    ///
    /// - Parameters:
    ///   - lhs: An attributed string or substring to concatenate.
    ///   - rhs: Another attributed string or substring to concatenate.
    /// - Returns: The result of concatenating `rhs` to the end of `lhs`.
    public static func +(lhs: AttributedString, rhs: some AttributedStringProtocol) -> AttributedString {
        var result = lhs
        result.append(rhs)
        return result
    }

    /// Appends an attributed string or substring to another attributed string.
    ///
    /// - Parameters:
    ///   - lhs: An attributed string. After the operation, the value of this string is the original `lhs` string with `rhs` appended to it.
    ///   - rhs: An attributed string or substring to append to `lhs`.
    public static func +=(lhs: inout AttributedString, rhs: some AttributedStringProtocol) {
        lhs.append(rhs)
    }

    /// Concatenates two attributed strings.
    ///
    /// - Parameters:
    ///   - lhs: An attributed string to concatenate.
    ///   - rhs: Another attributed string to concatenate.
    /// - Returns: The result of concatenating `rhs` to the end of `lhs`.
    public static func + (lhs: AttributedString, rhs: AttributedString) -> AttributedString {
        var result = lhs
        result.append(rhs)
        return result
    }

    /// Appends an attributed string to another attributed string.
    ///
    /// - Parameters:
    ///   - lhs: An attributed string. After the operation, the value of this string is the original `lhs` string with `rhs` appended to it.
    ///   - rhs: An attributed string to append to `lhs`.
    public static func += (lhs: inout Self, rhs: AttributedString) {
        lhs.append(rhs)
    }
}

// MARK: Substring access
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    /// Returns a substring of the attributed string using a range to indicate the substring bounds.
    public subscript(bounds: some RangeExpression<Index>) -> AttributedSubstring {
        get {
            // Note: slicing generally allows sub-Character ranges, but we need to resolve range
            // expressions using the characters view, to remain consistent with the stdlib.
            let bounds = bounds.relative(to: characters)
            return AttributedSubstring(_guts, in: bounds._bstringRange)
        }
        _modify {
            ensureUniqueReference()
            // Note: slicing generally allows sub-Character ranges, but we need to resolve range
            // expressions using the characters view, to remain consistent with the stdlib.
            let bounds = bounds.relative(to: characters)
            var substr = AttributedSubstring(_guts, in: bounds._bstringRange)
            let ident = Self._nextModifyIdentity
            substr._identity = ident
            _guts = Guts() // Dummy guts to allow in-place mutations
            defer {
                if substr._identity != ident {
                    fatalError("Mutating an AttributedSubstring by replacing it with another from a different source is unsupported")
                }
                _guts = substr._guts
            }
            yield &substr
        }
        set {
            // Note: slicing generally allows sub-Character ranges, but we need to resolve range
            // expressions using the characters view, to remain consistent with the stdlib.
            let bounds = bounds.relative(to: characters)

            // FIXME: Why is this allowed if _modify traps on replacement?
            self.replaceSubrange(bounds, with: newValue)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == AttributedString.Index {
    internal var _bstringRange: Range<BigString.Index> {
        Range<BigString.Index>(uncheckedBounds: (lowerBound._value, upperBound._value))
    }

    internal var _utf8OffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound._value.utf8Offset, upperBound._value.utf8Offset))
    }
}

extension RangeSet where Bound == AttributedString.Index {
    internal var _bstringIndices: RangeSet<BigString.Index> {
        RangeSet<BigString.Index>(self.ranges.map(\._bstringRange))
    }
}

extension RangeSet where Bound == BigString.Index {
    internal func _attributedStringIndices(version: AttributedString.Guts.Version) -> RangeSet<AttributedString.Index> {
        RangeSet<AttributedString.Index>(self.ranges.lazy.map {
            $0._attributedStringRange(version: version)
        })
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == BigString.Index {
    internal var _utf8OffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound.utf8Offset, upperBound.utf8Offset))
    }
    
    internal func _attributedStringRange(version: AttributedString.Guts.Version) -> Range<AttributedString.Index> {
        Range<AttributedString.Index>(uncheckedBounds: (AttributedString.Index(lowerBound, version: version), AttributedString.Index(upperBound, version: version)))
    }
}

extension AttributedString {
  /// Returns a boolean value indicating whether this string is identical to
  /// `other`.
  ///
  /// Two string values are identical if there is no way to distinguish between
  /// them.
  ///
  /// Comparing strings this way includes comparing (normally) hidden
  /// implementation details such as the memory location of any underlying
  /// string storage object. Therefore, identical strings are guaranteed to
  /// compare equal with `==`, but not all equal strings are considered
  /// identical.
  ///
  /// - Performance: O(1)
  public func isIdentical(to other: Self) -> Bool {
    self._guts === other._guts
  }
}
