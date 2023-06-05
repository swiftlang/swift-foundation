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
package import _RopeModule
#endif

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    public struct CharacterView : Sendable {
        /// The guts of the base attributed string.
        internal var _guts: Guts

        /// The boundary range of this character view.
        ///
        /// The bounds are always rounded down to the nearest grapheme break in the original
        /// string -- otherwise the character view of a substring may contain different graphemes
        /// than the original string. (This isn't how the standard `String` works, but emulating the
        /// same behavior would cause significant trouble for attributed strings, as the data
        /// structure caches the precise positions of grapheme breaks within the string. Allowing
        /// slices to diverge from that would make slicing an O(n) operation.)
        internal var _range: Range<Index>

        internal var _identity: Int = 0

        internal init(_ guts: Guts) {
            _guts = guts
            // The bounds of a whole attributed string are already character-aligned.
            _range = Range(uncheckedBounds: (guts.startIndex, guts.endIndex))
        }

        internal init(_ guts: Guts, in range: Range<Index>) {
            _guts = guts
            // Forcibly round bounds down to nearest character boundary, to prevent grapheme breaks
            // in a substring from diverging from the base string.
            let substring = _guts.string[range._bstringRange]
            _range = Range(uncheckedBounds: (Index(substring.startIndex), Index(substring.endIndex)))
        }
        
        public init() {
            self.init(Guts())
        }
    }

    public var characters: CharacterView {
        get {
            return CharacterView(_guts)
        }
        _modify {
            ensureUniqueReference()
            var view = CharacterView(_guts)
            let ident = Self._nextModifyIdentity
            view._identity = ident
            _guts = Guts() // Preserve uniqueness of view
            defer {
                if view._identity != ident {
                    fatalError("Mutating a CharacterView by replacing it with another from a different source is unsupported")
                }
                _guts = view._guts
            }
            yield &view
        }
        set {
            // FIXME: Why is this allowed if _modify traps on replacement?
            self.characters.replaceSubrange(startIndex ..< endIndex, with: newValue)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.CharacterView {
    internal var _characters: BigSubstring {
        BigSubstring(_unchecked: _guts.string, in: _range._bstringRange)
    }
}

extension Slice<AttributedString.CharacterView> {
    internal var _rebased: AttributedString.CharacterView {
        let bounds = Range(uncheckedBounds: (self.startIndex, self.endIndex))
        return AttributedString.CharacterView(base._guts, in: bounds)
    }

    internal var _characters: BigSubstring {
        _rebased._characters
    }
}

// FIXME: AttributedString.CharacterView needs to publicly conform to Equatable & Hashable.

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.CharacterView: BidirectionalCollection {
    public typealias Element = Character
    public typealias Index = AttributedString.Index

    public var startIndex: AttributedString.Index {
        _range.lowerBound
    }

    public var endIndex: AttributedString.Index {
        _range.upperBound
    }

    @_alwaysEmitIntoClient
    public var count: Int {
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            return _count
        }
        return _defaultCount
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal var _count: Int {
        _characters.count
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.index(before: i._value))
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.index(after: i._value))
        precondition(j <= endIndex, "Can't advance AttributedString index after end index")
        return j
    }

    @_alwaysEmitIntoClient
    public func index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            return _index(i, offsetBy: distance)
        }
        return _defaultIndex(i, offsetBy: distance)
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal func _index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.index(i._value, offsetBy: distance))
        precondition(j >= startIndex && j <= endIndex, "AttributedString index out of bounds")
        return j
    }

    @_alwaysEmitIntoClient
    public func index(
        _ i: AttributedString.Index,
        offsetBy distance: Int,
        limitedBy limit: AttributedString.Index
    ) -> AttributedString.Index? {
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            return _index(i, offsetBy: distance, limitedBy: limit)
        }
        return _defaultIndex(i, offsetBy: distance, limitedBy: limit)
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal func _index(
        _ i: AttributedString.Index,
        offsetBy distance: Int,
        limitedBy limit: AttributedString.Index
    ) -> AttributedString.Index? {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        precondition(limit >= startIndex && limit <= endIndex, "AttributedString index out of bounds")
        guard let j = _guts.string.index(
            i._value, offsetBy: distance, limitedBy: limit._value
        ) else {
            return nil
        }
        precondition(j >= startIndex._value && j <= endIndex._value,
                     "AttributedString index out of bounds")
        return Index(j)
    }

    @_alwaysEmitIntoClient
    public func distance(from start: AttributedString.Index, to end: AttributedString.Index) -> Int {
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            return _distance(from: start, to: end)
        }
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _defaultDistance(from: start, to: end)
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal func _distance(from start: AttributedString.Index, to end: AttributedString.Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _characters.distance(from: start._value, to: end._value)
    }

    public subscript(index: AttributedString.Index) -> Character {
        get {
            precondition(index >= startIndex && index < endIndex, "AttributedString index out of bounds")
            return _guts.string[index._value]
        }
        set {
            precondition(index >= startIndex && index < endIndex, "AttributedString index out of bounds")
            let i = _guts.characterIndex(roundingDown: index)
            let j = _guts.characterIndex(after: i)
            self.replaceSubrange(i ..< j, with: String(newValue))
        }
    }
    
    // Note: This subscript returning a Slice is a bug; unfortunately, this is ABI.
    public subscript(bounds: Range<AttributedString.Index>) -> Slice<AttributedString.CharacterView> {
        get {
            precondition(
                bounds.lowerBound >= startIndex && bounds.upperBound <= endIndex,
                "AttributedString index range out of bounds")
            let view = Self(_guts, in: bounds)
            return Slice(base: view, bounds: view._range)
        }
        set {
            self.replaceSubrange(bounds, with: newValue)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.CharacterView: RangeReplaceableCollection {
    internal mutating func _ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }

    internal mutating func _mutateStringContents(
        in range: Range<Index>,
        attributes: AttributedString._AttributeStorage,
        with body: (inout BigSubstring, Range<BigString.Index>) -> Void
    ) {
        // Invalidate attributes surrounding the affected range. (Phase 1)
        let state = _guts._prepareStringMutation(in: range)

        // Update string contents.
        //
        // This is "fun". CharacterView (inconsistently) implements self-slicing, and so
        // mutations of it need to update its bounds to reflect the newly updated content.
        // We do this by extracting the new bounds from BigSubstring, which already does the
        // right thing.
        var characters = _characters
        _guts.string = BigString() // Preserve uniqueness

        body(&characters, range._bstringRange)

        self._guts.string = characters.base
        let lower = AttributedString.Index(characters.startIndex)
        let upper = AttributedString.Index(characters.endIndex)
        self._range = Range(uncheckedBounds: (lower, upper))

        // Set attributes for the mutated range.
        let utf8Range = range._utf8OffsetRange
        let utf8Delta = _guts.string.utf8.count - state.oldUTF8Count
        let runLength = utf8Range.count + utf8Delta
        let run = AttributedString._InternalRun(length: runLength, attributes: attributes)
        _guts.replaceRunsSubrange(locations: utf8Range, with: CollectionOfOne(run))

        // Invalidate attributes surrounding the affected range. (Phase 2)
        _guts._finalizeStringMutation(state)
    }

    internal mutating func _setAttributes(
        in range: Range<Index>,
        to attributes: AttributedString._AttributeStorage
    ) {
        let utf8Range = range._utf8OffsetRange
        let run = AttributedString._InternalRun(length: utf8Range.count, attributes: attributes)
        _guts.replaceRunsSubrange(locations: utf8Range, with: CollectionOfOne(run))
    }

    public mutating func replaceSubrange(
        _ subrange: Range<Index>, with newElements: some Collection<Character>
    ) {
        precondition(
            subrange.lowerBound >= self.startIndex && subrange.upperBound <= self.endIndex,
            "AttributedString index range out of bounds")
        
        let subrange = _guts.characterRange(roundingDown: subrange)
        
        // Prevent the BigString mutation below from falling back to Character-by-Character loops.
        if let newElements = _specializingCast(newElements, to: Self.self) {
            _replaceSubrange(subrange, with: newElements._characters)
        } else if let newElements = _specializingCast(newElements, to: Slice<Self>.self) {
            _replaceSubrange(subrange, with: newElements._rebased._characters)
        } else {
            _replaceSubrange(subrange, with: newElements)
        }
    }

    internal mutating func _replaceSubrange(
        _ subrange: Range<Index>, with newElements: some Collection<Character>
    ) {
        _ensureUniqueReference()

        var hasStringChanges = true
        if let newElements = _specializingCast(newElements, to: BigSubstring.self) {
            // Determine if this replacement is going to actively change character data, or if this
            // is purely an attributes update, by seeing if the replacement string slice is
            // identical to our own storage. (If it is identical, then we need to update attributes
            // surrounding the affected bounds in a different way.)
            //
            // Note: this is intentionally not comparing actual string data.
            if newElements.isIdentical(to: _characters[subrange._bstringRange]) {
                hasStringChanges = false
            }
        }

        let attributes = _guts.attributesToUseForTextReplacement(
            in: subrange,
            includingCharacterDependentAttributes: !hasStringChanges)

        if hasStringChanges {
            self._mutateStringContents(in: subrange, attributes: attributes) { string, range in
                string.replaceSubrange(range, with: newElements)
            }
        } else {
            self._setAttributes(in: subrange, to: attributes)
        }
    }

    // FIXME: Add individual overrides for other RangeReplaceableCollection mutations.
    // (Letting everything go through `replaceSubrange` can be extremely costly -- e.g.,
    // `append(contentsOf:)` calls `replaceSubrange` once for each character!)
}
