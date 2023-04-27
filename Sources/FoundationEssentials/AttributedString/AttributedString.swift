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
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
#endif

@dynamicMemberLookup
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributedString: Sendable {
    internal var _guts: Guts

    internal init(_ guts: Guts) {
        _guts = guts
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal static let currentIdentity = LockedState(initialState: 0)
    internal static var _nextModifyIdentity: Int {
        currentIdentity.withLock { identity in
            identity += 1
            return identity
        }
    }
}

// MARK: Initialization
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public init() {
        self._guts = Guts()
    }

    internal init(_ s: some AttributedStringProtocol) {
        if let s = s as? AttributedString {
            self = s
        } else if let s = s as? AttributedSubstring {
            self = AttributedString(s)
        } else {
            // !!!: We don't expect or want this to happen.
            // FIXME: Handle slicing.
            self = AttributedString(s.characters._guts)
        }
    }

    internal init(_ string: BigString, attributes: _AttributeStorage) {
        guard !string.isEmpty else {
            self.init()
            return
        }
        let run = _InternalRun(length: string.utf8.count, attributes: attributes)
        self.init(Guts(string: string, runs: [run]))
        // Only character-bound attributes can be incorrect if only one run exists
        if run.attributes.containsCharacterConstraint {
            _guts.fixCharacterConstrainedAttributes(in: _guts.startIndex ..< _guts.endIndex)
        }
    }

    /// Creates a new attributed string with the given `String` value associated with the given
    /// attributes.
    public init(_ string: String, attributes: AttributeContainer = .init()) {
        self.init(BigString(string), attributes: attributes.storage)
    }

    /// Creates a new attributed string with the given `Substring` value associated with the given
    /// attributes.
    public init(_ substring: Substring, attributes: AttributeContainer = .init()) {
        self.init(BigString(substring), attributes: attributes.storage)
    }

    public init<S: Sequence>(
        _ elements: S,
        attributes: AttributeContainer = .init()
    ) where S.Element == Character {
        let str = Self._bstring(from: elements)
        self.init(str, attributes: attributes.storage)
    }

    public init(_ substring: AttributedSubstring) {
        let str = BigString(substring._unicodeScalars)
        let runs = substring._guts.runs(in: substring._range)
        assert(str.utf8.count == runs.reduce(into: 0) { $0 += $1.length })
        _guts = Guts(string: str, runs: runs)
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Support scope-specific initialization in FoundationPreview
    public init<S: AttributeScope, T: AttributedStringProtocol>(_ other: T, including scope: KeyPath<AttributeScopes, S.Type>) {
        self.init(other, including: S.self)
    }

    public init<S: AttributeScope, T: AttributedStringProtocol>(_ other: T, including scope: S.Type) {
        self.init(other.__guts.copy(in: other.startIndex ..< other.endIndex))
        var attributeCache = [String : Bool]()
        _guts.enumerateRuns { run, _, _, modification in
            modification = .guaranteedNotModified
            for key in run.attributes.keys {
                var inScope: Bool
                if let cachedInScope = attributeCache[key] {
                    inScope = cachedInScope
                } else {
                    inScope = scope.attributeKeyType(matching: key) != nil
                    attributeCache[key] = inScope
                }

                if !inScope {
                    run.attributes[key] = nil
                    modification = .guaranteedModified
                }
            }
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    internal static func _bstring<S: Sequence<Character>>(from elements: S) -> BigString {
        if S.self == String.self {
            return BigString(_identityCast(elements, to: String.self))
        }
        if S.self == Substring.self {
            return BigString(_identityCast(elements, to: Substring.self))
        }
        if S.self == AttributedString.CharacterView.self {
            let view = _identityCast(elements, to: AttributedString.CharacterView.self)
            return BigString(view._characters)
        }
        if S.self == Slice<AttributedString.CharacterView>.self {
            let view = _identityCast(elements, to: Slice<AttributedString.CharacterView>.self)
            return BigString(view._characters)
        }
        return BigString(elements)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString { // Equatable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        AttributedString.Guts.characterwiseIsEqual(lhs._guts, to: rhs._guts)
    }
}

// Note: The Hashable implementation is inherited from AttributedStringProtocol.

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString { // AttributedStringAttributeMutation
    public mutating func setAttributes(_ attributes: AttributeContainer) {
        ensureUniqueReference()
        _guts.set(attributes: attributes, in: startIndex ..< endIndex)
    }

    public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributeMergePolicy = .keepNew) {
        ensureUniqueReference()
        _guts.add(attributes: attributes, in: startIndex ..< endIndex, mergePolicy: mergePolicy)
    }

    public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
        guard attributes != others else { return }
        ensureUniqueReference()
        let hasConstrainedAttributes = attributes._hasConstrainedAttributes || others._hasConstrainedAttributes
        var fixupRanges: [Range<Int>] = []
        _guts.enumerateRuns { run, location, _, modified in
            guard run.matches(attributes) else {
                modified = .guaranteedNotModified
                return
            }
            modified = .guaranteedModified
            for key in attributes.storage.keys {
                run.attributes[key] = nil
            }
            run.attributes.mergeIn(others)
            if hasConstrainedAttributes {
                fixupRanges._extend(with: location ..< location + run.length)
            }
        }

        for range in fixupRanges {
            // FIXME: Collect boundary constraints.
            _guts.enforceAttributeConstraintsAfterMutation(in: range, type: .attributes)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString: AttributedStringProtocol {
    public struct Index: Comparable, Sendable {
        internal var _value: BigString.Index

        internal init(_ value: BigString.Index) {
            self._value = value
        }

        public static func == (left: Self, right: Self) -> Bool {
            left._value == right._value
        }

        public static func < (left: Self, right: Self) -> Bool {
            left._value < right._value
        }
    }

    public var startIndex: Index {
        return _guts.startIndex
    }

    public var endIndex: Index {
        return _guts.endIndex
    }

    @preconcurrency
    public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value: Sendable {
        get { _guts.getValue(in: startIndex ..< endIndex, key: K.self)?.rawValue(as: K.self) }
        set {
            ensureUniqueReference()
            if let v = newValue {
                _guts.add(value: v, in: startIndex ..< endIndex, key: K.self)
            } else {
                _guts.remove(attribute: K.self, in: startIndex ..< endIndex)
            }
        }
    }

    @preconcurrency
    public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? where K.Value: Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
        get {
            return ScopedAttributeContainer(_guts.getValues(in: startIndex ..< endIndex))
        }
        _modify {
            ensureUniqueReference()
            var container = ScopedAttributeContainer<S>()
            defer {
                if let removedKey = container.removedKey {
                    _guts.remove(key: removedKey, in: startIndex ..< endIndex)
                } else {
                    _guts.add(attributes: AttributeContainer(container.storage), in: startIndex ..< endIndex)
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
    }

    public mutating func append<S: AttributedStringProtocol>(_ s: S) {
        replaceSubrange(endIndex ..< endIndex, with: s)
    }

    public mutating func insert<S: AttributedStringProtocol>(_ s: S, at index: AttributedString.Index) {
        replaceSubrange(index ..< index, with: s)
    }

    public mutating func removeSubrange<R: RangeExpression>(_ range: R) where R.Bound == Index {
        replaceSubrange(range, with: AttributedString())
    }

    public mutating func replaceSubrange<R: RangeExpression, S: AttributedStringProtocol>(_ range: R, with s: S) where R.Bound == Index {
        ensureUniqueReference()
        _guts.replaceSubrange(range.relative(to: characters), with: s)
    }
}

// MARK: Concatenation operators
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public static func + <T: AttributedStringProtocol> (lhs: AttributedString, rhs: T) -> AttributedString {
        var result = lhs
        result.append(rhs)
        return result
    }

    public static func += <T: AttributedStringProtocol> (lhs: inout AttributedString, rhs: T) {
        lhs.append(rhs)
    }

    public static func + (lhs: AttributedString, rhs: AttributedString) -> AttributedString {
        var result = lhs
        result.append(rhs)
        return result
    }

    public static func += (lhs: inout Self, rhs: AttributedString) {
        lhs.append(rhs)
    }
}

// MARK: Substring access
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public subscript<R: RangeExpression>(bounds: R) -> AttributedSubstring where R.Bound == Index {
        get {
            return AttributedSubstring(_guts, bounds.relative(to: unicodeScalars))
        }
        _modify {
            ensureUniqueReference()
            var substr = AttributedSubstring(_guts, bounds.relative(to: unicodeScalars))
            let ident = Self._nextModifyIdentity
            substr._identity = ident
            _guts = Guts(string: "", runs: []) // Dummy guts so the substr has (hopefully) the sole reference
            defer {
                if substr._identity != ident {
                    fatalError("Mutating an AttributedSubstring by replacing it with another from a different source is unsupported")
                }
                _guts = substr._guts
            }
            yield &substr
        }
        set {
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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range where Bound == BigString.Index {
    internal var _utf8OffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound.utf8Offset, upperBound.utf8Offset))
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range<AttributedString.Runs.Index> {
    var _offsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound.rangeIndex, upperBound.rangeIndex))
    }
}
