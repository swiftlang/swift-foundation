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
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributedSubstring: Sendable {
    /// The guts of the base attributed string.
    internal var _guts: AttributedString.Guts

    /// The boundary range of this substring.
    ///
    /// This addresses an arbitrary range of Unicode scalars -- substrings don't necessarily
    /// start and end on `Character` boundaries in the base string. The precise boundaries are
    /// maintained and exposed via the `unicodeScalars` view, but not via `characters`: when
    /// accessing characters, the end points are unconditionally and implicitly rounded down
    /// to character boundaries. (This is to prevent having to resync grapheme breaks on slicing
    /// operations -- otherwise substring slicing would be an O(n) operation.)
    internal var _range: Range<BigString.Index>

    internal var _identity: Int = 0

    internal init(_ guts: AttributedString.Guts, in range: Range<BigString.Index>) {
        self._guts = guts
        // Forcibly resolve bounds and round them down to nearest scalar boundary.
        let slice = _guts.string.unicodeScalars[range]
        self._range = Range(uncheckedBounds: (slice.startIndex, slice.endIndex))
    }

    public init() {
        let str = AttributedString()
        self.init(str._guts, in: str._stringBounds)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedSubstring {
    public var base: AttributedString {
        return AttributedString(_guts)
    }

    internal var _unicodeScalars: BigSubstring.UnicodeScalarView {
        _guts.string.unicodeScalars[_range]
    }

    internal var _characters: BigSubstring {
        _guts.string[_range]
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedSubstring { // CustomStringConvertible
    public var description: String {
        // FIXME: Why have a custom definition for this if AttributedString falls back
        // on the default implementation in AttributedStringProtocol?
        _guts.description(in: _range)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedSubstring { // Equatable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs._guts === rhs._guts && lhs._range == rhs._range {
            return true
        }
        return AttributedString.Guts.characterwiseIsEqual(
            lhs._guts, in: lhs._stringBounds,
            to: rhs._guts, in: rhs._stringBounds)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedSubstring : AttributedStringProtocol {
    public var startIndex: AttributedString.Index {
        .init(_range.lowerBound)
    }

    public var endIndex: AttributedString.Index {
        .init(_range.upperBound)
    }

    internal mutating func ensureUniqueReference() {
        // Note: slices should never discard the data outside their bounds, so we must make a
        // copy of the entire base string here.
        //
        // (Discarding out-of-range data would change index values, interfere with "in-place"
        // mutations of slices via the subscript accessors, and it would confuse the semantics of
        // the `base` property.)
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }

    public mutating func setAttributes(_ attributes: AttributeContainer) {
        ensureUniqueReference()
        _guts.setAttributes(attributes.storage, in: _range)
    }

    public mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy:  AttributedString.AttributeMergePolicy = .keepNew) {
        ensureUniqueReference()
        _guts.mergeAttributes(attributes, in: _range, mergePolicy:  mergePolicy)
    }

    public mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) {
        guard attributes != others else {
            return
        }
        ensureUniqueReference()
        let hasConstrainedAttributes = attributes.storage.hasConstrainedAttributes || others.storage.hasConstrainedAttributes
        var fixupRanges = [Range<Int>]()
        _guts.runs(in: _range._utf8OffsetRange).updateEach(
            when: { $0.matches(attributes.storage) },
            with: { runAttributes, utf8Range in
                for key in attributes.storage.keys {
                    runAttributes[key] = nil
                }
                runAttributes.mergeIn(others)
                if hasConstrainedAttributes {
                    fixupRanges.append(utf8Range)
                }
            })
        for range in fixupRanges {
            // FIXME: Collect boundary constraints.
            _guts.enforceAttributeConstraintsAfterMutation(in: range, type: .attributes)
        }
    }

    public var runs: AttributedString.Runs {
        get { .init(_guts, in: _range) }
    }

    public var characters: AttributedString.CharacterView {
        return AttributedString.CharacterView(_guts, in: _range)
    }

    public var unicodeScalars: AttributedString.UnicodeScalarView {
        return AttributedString.UnicodeScalarView(_guts, in: _range)
    }

    public subscript(bounds: some RangeExpression<AttributedString.Index>) -> AttributedSubstring {
        let bounds = bounds.relative(to: characters)
        return AttributedSubstring(_guts, in: bounds._bstringRange)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedSubstring {
    @preconcurrency
    public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? where K.Value : Sendable {
        get {
            _guts.getUniformValue(in: _range, key: K.self)?.rawValue(as: K.self)
        }
        set {
            ensureUniqueReference()
            if let v = newValue {
                _guts.setAttributeValue(v, forKey: K.self, in: _range)
            } else {
                _guts.removeAttributeValue(forKey: K.self, in: _range)
            }
        }
    }

    @preconcurrency
    public subscript<K: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>
    ) -> K.Value? where K.Value : Sendable {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    public subscript<S: AttributeScope>(
        dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>
    ) -> ScopedAttributeContainer<S> {
        get {
            return ScopedAttributeContainer(_guts.getUniformValues(in: _range))
        }
        _modify {
            ensureUniqueReference()
            var container = ScopedAttributeContainer<S>()
            defer {
                if let removedKey = container.removedKey {
                    _guts.removeAttributeValue(forKey: removedKey, in: _range)
                } else {
                    _guts.mergeAttributes(AttributeContainer(container.storage), in: _range)
                }
            }
            yield &container
        }
    }
}
