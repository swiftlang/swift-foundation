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
    public struct UnicodeScalarView: Sendable {
        internal var _guts: Guts

        /// The boundary range of this character view.
        ///
        /// The bounds are always rounded down to the nearest Unicode scalar boundary in the
        /// original string.
        internal var _range: Range<BigString.Index>

        internal var _identity: Int = 0

        internal init(_ guts: AttributedString.Guts) {
            // The bounds of a whole attributed string are already scalar-aligned.
            self.init(guts, in: guts.stringBounds)
        }

        internal init(_ guts: Guts, in range: Range<BigString.Index>) {
            _guts = guts
            // Forcibly resolve bounds and round them down to nearest scalar boundary.
            let slice = _guts.string.unicodeScalars[range]
            _range = Range(uncheckedBounds: (slice.startIndex, slice.endIndex))
        }

        public init() {
            self.init(Guts())
        }
    }

    public var unicodeScalars: UnicodeScalarView {
        get {
            UnicodeScalarView(_guts)
        }
        _modify {
            ensureUniqueReference()
            var view = UnicodeScalarView(_guts)
            let ident = Self._nextModifyIdentity
            view._identity = ident
            _guts = Guts() // Preserve uniqueness of view
            defer {
                if view._identity != ident {
                    fatalError("Mutating a UnicodeScalarView by replacing it with another from a different source is unsupported")
                }
                _guts = view._guts
            }
            yield &view
        }
        set {
            // FIXME: Why is this allowed if _modify traps on replacement?
            self.unicodeScalars.replaceSubrange(_bounds, with: newValue)
        }
    }
}

extension AttributedString.UnicodeScalarView {
    var _unicodeScalars: BigSubstring.UnicodeScalarView {
        BigSubstring.UnicodeScalarView(_unchecked: _guts.string, in: _range)
    }
}

extension Slice<AttributedString.UnicodeScalarView> {
    internal var _rebased: AttributedString.UnicodeScalarView {
        let bounds = Range(uncheckedBounds: (self.startIndex._value, self.endIndex._value))
        return AttributedString.UnicodeScalarView(base._guts, in: bounds)
    }

    internal var _unicodeScalars: BigSubstring.UnicodeScalarView {
        _rebased._unicodeScalars
    }
}

extension AttributedString.UnicodeScalarView {
    // FIXME: AttributedString.UnicodeScalarView needs to publicly conform to Hashable.
    internal func _isEqual(to other: Self) -> Bool {
        self._unicodeScalars == other._unicodeScalars
    }

    internal func _hash(into hasher: inout Hasher) {
        self._unicodeScalars.hash(into: &hasher)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.UnicodeScalarView: BidirectionalCollection {
    public typealias Element = UnicodeScalar
    public typealias Index = AttributedString.Index

    public var startIndex: AttributedString.Index {
        .init(_range.lowerBound)
    }

    public var endIndex: AttributedString.Index {
        .init(_range.upperBound)
    }

    @_alwaysEmitIntoClient
    public var count: Int {
    #if FOUNDATION_FRAMEWORK
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return _count
        }
    #endif
        return _defaultCount
    }

    @available(FoundationPreview 0.1, *)
    @usableFromInline
    internal var _count: Int {
        _unicodeScalars.count
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalars.index(before: i._value))
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalars.index(after: i._value))
        precondition(j <= endIndex, "Can't advance AttributedString index after end index")
        return j
    }

    public func index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalars.index(i._value, offsetBy: distance))
        precondition(j >= startIndex && j <= endIndex, "AttributedString index out of bounds")
        return j
    }

    @_alwaysEmitIntoClient
    public func index(
        _ i: AttributedString.Index,
        offsetBy distance: Int,
        limitedBy limit: AttributedString.Index
    ) -> AttributedString.Index? {
    #if FOUNDATION_FRAMEWORK
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return _index(i, offsetBy: distance, limitedBy: limit)
        }
    #endif
        return _defaultIndex(i, offsetBy: distance, limitedBy: limit)
    }

    @available(FoundationPreview 0.1, *)
    @usableFromInline
    internal func _index(
        _ i: AttributedString.Index,
        offsetBy distance: Int,
        limitedBy limit: AttributedString.Index
    ) -> AttributedString.Index? {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        precondition(limit >= startIndex && limit <= endIndex, "AttributedString index out of bounds")
        guard let j = _guts.string.unicodeScalars.index(
            i._value, offsetBy: distance, limitedBy: limit._value
        ) else {
            return nil
        }
        precondition(j >= startIndex._value && j <= endIndex._value,
                     "AttributedString index out of bounds")
        return Index(j)
    }

    @_alwaysEmitIntoClient
    public func distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return _distance(from: start, to: end)
        }
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _defaultDistance(from: start, to: end)
    }

    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    @usableFromInline
    internal func _distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _guts.string.unicodeScalars.distance(from: start._value, to: end._value)
    }
    
    // FIXME: Why isn't this mutable if CharacterView's equivalent subscript has a setter?
    public subscript(index: AttributedString.Index) -> UnicodeScalar {
        precondition(index >= startIndex && index < endIndex, "AttributedString index out of bounds")
        return _guts.string.unicodeScalars[index._value]
    }
    
    // FIXME: This should return `Self`.
    // FIXME: Why isn't this mutable if CharacterView's equivalent subscript has a setter?
    public subscript(bounds: Range<AttributedString.Index>) -> Slice<AttributedString.UnicodeScalarView> {
        let bounds = bounds._bstringRange
        precondition(
            bounds.lowerBound >= _range.lowerBound && bounds.upperBound <= _range.upperBound,
            "AttributedString index range out of bounds")
        let view = Self(_guts, in: bounds)
        return Slice(base: view, bounds: Range(uncheckedBounds: (view.startIndex, view.endIndex)))
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.UnicodeScalarView: RangeReplaceableCollection {
    internal mutating func _ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }
    
    internal mutating func _mutateStringContents(
        in range: Range<BigString.Index>,
        attributes: AttributedString._AttributeStorage,
        with body: (inout BigSubstring.UnicodeScalarView, Range<BigString.Index>) -> Void
    ) {
        // Invalidate attributes surrounding the affected range. (Phase 1)
        let state = _guts._prepareStringMutation(in: range)
        
        // Update string contents.
        //
        // This is "fun". CharacterView (inconsistently) implements self-slicing, and so
        // mutations of it need to update its bounds to reflect the newly updated content.
        // We do this by extracting the new bounds from BigSubstring, which already does the
        // right thing.
        var scalars = _unicodeScalars
        _guts.string = BigString() // Preserve uniqueness
        
        body(&scalars, range)
        
        self._guts.string = BigString(scalars.base)
        self._range = Range(uncheckedBounds: (scalars.startIndex, scalars.endIndex))

        // Set attributes for the mutated range.
        let utf8Range = range._utf8OffsetRange
        let utf8Delta = _guts.string.utf8.count - state.oldUTF8Count
        let runLength = utf8Range.count + utf8Delta
        let run = AttributedString._InternalRun(length: runLength, attributes: attributes)
        _guts.runs.replaceUTF8Subrange(utf8Range, with: CollectionOfOne(run))

        // Invalidate attributes surrounding the affected range. (Phase 2)
        _guts._finalizeStringMutation(state)
    }
    
    public mutating func replaceSubrange(
        _ subrange: Range<Index>, with newElements: some Collection<UnicodeScalar>
    ) {
        precondition(
            subrange.lowerBound >= self.startIndex && subrange.upperBound <= self.endIndex,
            "AttributedString index range out of bounds")
        
        let subrange = _guts.unicodeScalarRange(roundingDown: subrange._bstringRange)

        // Prevent the BigString mutation below from falling back to Character-by-Character loops.
        if let newElements = _specializingCast(newElements, to: Self.self) {
            _replaceSubrange(subrange, with: newElements._unicodeScalars)
        } else if let newElements = _specializingCast(newElements, to: Slice<Self>.self) {
            _replaceSubrange(subrange, with: newElements._rebased._unicodeScalars)
        } else {
            _replaceSubrange(subrange, with: newElements)
        }
    }
    
    internal mutating func _replaceSubrange(
        _ subrange: Range<BigString.Index>, with newElements: some Collection<UnicodeScalar>
    ) {
        _ensureUniqueReference()

        // Determine if this replacement is going to actively change character data by seeing if the
        // replacement string slice is identical to our own storage. If it is identical, then we
        // don't need to touch string storage, but we still want to update attributes as if it was
        // a full edit.
        var hasStringChanges = true
        if let newElements = _specializingCast(newElements, to: BigSubstring.UnicodeScalarView.self),
           newElements.isIdentical(to: _unicodeScalars[subrange]) {
            hasStringChanges = false
        }

        let attributes = _guts.attributesToUseForTextReplacement(in: subrange)
        self._mutateStringContents(in: subrange, attributes: attributes) { string, range in
            if hasStringChanges {
                string.replaceSubrange(range, with: newElements)
            }
        }
    }

    // FIXME: Add individual overrides for other RangeReplaceableCollection mutations.
    // (Letting everything go through `replaceSubrange` can be extremely costly -- e.g.,
    // `append(contentsOf:)` calls `replaceSubrange` once for each character!)
}
