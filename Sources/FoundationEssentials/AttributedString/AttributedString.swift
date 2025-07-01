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

@dynamicMemberLookup
@available(FoundationAttributedString 5.5, *)
public struct AttributedString : Sendable {
    internal var _guts: Guts

    internal init(_ guts: Guts) {
        _guts = guts
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    internal static let currentIdentity = LockedState(initialState: 0)
    internal static var _nextModifyIdentity : Int {
        currentIdentity.withLock { identity in
            identity += 1
            return identity
        }
    }
}

// MARK: Initialization
@available(FoundationAttributedString 5.5, *)
extension AttributedString {
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
    public init(_ string: String, attributes: AttributeContainer = .init()) {
        self.init(BigString(string), attributes: attributes.storage)
    }

    /// Creates a new attributed string with the given `Substring` value associated with the given
    /// attributes.
    public init(_ substring: Substring, attributes: AttributeContainer = .init()) {
        self.init(BigString(substring), attributes: attributes.storage)
    }

    public init<S : Sequence>(
        _ elements: S,
        attributes: AttributeContainer = .init()
    ) where S.Element == Character {
        let str = Self._bstring(from: elements)
        self.init(str, attributes: attributes.storage)
    }

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
    public init<S : AttributeScope, T : AttributedStringProtocol>(_ other: T, including scope: KeyPath<AttributeScopes, S.Type>) {
        self.init(other, including: S.self)
    }

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

@available(FoundationAttributedString 5.5, *)
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

@available(FoundationAttributedString 5.5, *)
extension AttributedString { // Equatable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        AttributedString.Guts.characterwiseIsEqual(lhs._guts, to: rhs._guts)
    }
}

// Note: The Hashable implementation is inherited from AttributedStringProtocol.

@available(FoundationAttributedString 5.5, *)
extension AttributedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

@available(FoundationAttributedString 5.5, *)
extension AttributedString { // AttributedStringAttributeMutation
    public mutating func setAttributes(_ attributes: AttributeContainer) {
        ensureUniqueReference()
        _guts.setAttributes(attributes.storage, in: _stringBounds)
    }

    public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy:  AttributeMergePolicy = .keepNew) {
        ensureUniqueReference()
        _guts.mergeAttributes(attributes, in: _stringBounds, mergePolicy:  mergePolicy)
    }

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

@available(FoundationAttributedString 5.5, *)
extension AttributedString: AttributedStringProtocol {
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
    
    public var startIndex : Index {
        Index(_guts.string.startIndex, version: _guts.version)
    }
    
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
    
    @preconcurrency
    @inlinable // Trivial implementation, allows callers to optimize away the keypath allocation
    public subscript<K: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>
    ) -> K.Value? where K.Value: Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
    
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
@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    internal mutating func ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
        _guts.incrementVersion()
    }

    public mutating func append(_ s: some AttributedStringProtocol) {
        replaceSubrange(endIndex ..< endIndex, with: s)
    }

    public mutating func insert(_ s: some AttributedStringProtocol, at index: AttributedString.Index) {
        replaceSubrange(index ..< index, with: s)
    }

    public mutating func removeSubrange(_ range: some RangeExpression<Index>) {
        replaceSubrange(range, with: AttributedString())
    }

    public mutating func replaceSubrange(_ range: some RangeExpression<Index>, with s: some AttributedStringProtocol) {
        ensureUniqueReference()
        // Note: slicing generally allows sub-Character ranges, but we need to resolve range
        // expressions using the characters view, to remain consistent with the stdlib.
        let subrange = range.relative(to: characters)._bstringRange
        _guts.replaceSubrange(subrange, with: s)
    }
}

// MARK: Concatenation operators
@available(FoundationAttributedString 5.5, *)
extension AttributedString {
    public static func +(lhs: AttributedString, rhs: some AttributedStringProtocol) -> AttributedString {
        var result = lhs
        result.append(rhs)
        return result
    }
    
    public static func +=(lhs: inout AttributedString, rhs: some AttributedStringProtocol) {
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
@available(FoundationAttributedString 5.5, *)
extension AttributedString {
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

@available(FoundationAttributedString 5.5, *)
extension Range where Bound == AttributedString.Index {
    internal var _bstringRange: Range<BigString.Index> {
        Range<BigString.Index>(uncheckedBounds: (lowerBound._value, upperBound._value))
    }

    internal var _utf8OffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound._value.utf8Offset, upperBound._value.utf8Offset))
    }
}

@available(FoundationAttributedString 5.5, *)
extension RangeSet where Bound == AttributedString.Index {
    internal var _bstringIndices: RangeSet<BigString.Index> {
        RangeSet<BigString.Index>(self.ranges.map(\._bstringRange))
    }
}

@available(FoundationAttributedString 5.5, *)
extension RangeSet where Bound == BigString.Index {
    internal func _attributedStringIndices(version: AttributedString.Guts.Version) -> RangeSet<AttributedString.Index> {
        RangeSet<AttributedString.Index>(self.ranges.lazy.map {
            $0._attributedStringRange(version: version)
        })
    }
}

@available(FoundationAttributedString 5.5, *)
extension Range where Bound == BigString.Index {
    internal var _utf8OffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound.utf8Offset, upperBound.utf8Offset))
    }
    
    internal func _attributedStringRange(version: AttributedString.Guts.Version) -> Range<AttributedString.Index> {
        Range<AttributedString.Index>(uncheckedBounds: (AttributedString.Index(lowerBound, version: version), AttributedString.Index(upperBound, version: version)))
    }
}
