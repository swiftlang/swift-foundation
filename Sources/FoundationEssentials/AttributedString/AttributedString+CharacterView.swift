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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString {
    @_nonSendable
    public struct CharacterView {
        /// The guts of the base attributed string.
        internal var _guts: Guts

        /// The boundary range of this character view.
        ///
        /// The bounds are always rounded down to the nearest grapheme break in the original
        /// string -- otherwise the character view of a substring may contain different graphemes
        /// than the original string. (This is how the standard `String` works, but emulating the
        /// same behavior would cause significant trouble for attributed strings, as the data
        /// structure caches the precise positions of grapheme breaks within the string. Allowing
        /// slices to diverge from that would make slicing an O(n) operation.)
        internal var _range: Range<Index>

        internal var _identity: Int = 0

        internal init(_ g: Guts) {
            _guts = g
            // The bounds of a whole attributed string are alread character-aligned.
            _range = Range(uncheckedBounds: (g.startIndex, g.endIndex))
        }

        internal init(_ g: Guts, _ r: Range<Index>) {
            _guts = g
            // Forcibly round bounds down to nearest character boundary, to prevent grapheme breaks
            // in a substring from diverging from the base string.
            let lower = _guts.characterIndex(roundingDown: r.lowerBound)
            let upper = _guts.characterIndex(roundingDown: r.upperBound)
            _range = Range(uncheckedBounds: (lower, upper))
        }
        
        public init() {
            _guts = Guts(string: "", runs: [])
            _range = _guts.startIndex ..< _guts.endIndex
        }
    }

    public var characters: CharacterView {
        get {
            return CharacterView(_guts)
        }
        _modify {
            ensureUniqueReference()
            var cv = CharacterView(_guts)
            let ident = Self._nextModifyIdentity
            cv._identity = ident
            _guts = Guts(string: "", runs: []) // Dummy guts so the CharacterView has (hopefully) the sole reference
            defer {
                if cv._identity != ident {
                    fatalError("Mutating a CharacterView by replacing it with another from a different source is unsupported")
                }
                _guts = cv._guts
            }
            yield &cv
        }
        set {
            self.characters.replaceSubrange(startIndex ..< endIndex, with: newValue)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.CharacterView: BidirectionalCollection, RangeReplaceableCollection {
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
        _guts.characterDistance(from: _range.lowerBound, to: _range.upperBound)
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = _guts.characterIndex(before: i)
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = _guts.characterIndex(after: i)
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
        let j = Index(_guts.string.characterIndex(i._value, offsetBy: distance))
        precondition(j >= startIndex && j <= endIndex, "AttributedString index out of bounds")
        return j
    }

    // FIXME: Implement index(_:offsetBy:limitedBy:)

    @_alwaysEmitIntoClient
    public func distance(from start: AttributedString.Index, to end: AttributedString.Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        if #available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *) {
            return _distance(from: start, to: end)
        }
        return _defaultDistance(from: start, to: end)
    }

    @available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
    @usableFromInline
    internal func _distance(from start: AttributedString.Index, to end: AttributedString.Index) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _guts.characterDistance(from: start, to: end)
    }

    internal mutating func ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }

    public subscript(index: AttributedString.Index) -> Character {
        get {
            _guts.string[character: index._value]
        }
        set {
            let j = _guts.characterIndex(after: index)
            self.replaceSubrange(index ..< j, with: CollectionOfOne(newValue))
        }
    }

    public subscript(bounds: Range<AttributedString.Index>) -> Slice<AttributedString.CharacterView> {
        get {
            Slice(base: self, bounds: bounds)
        }
        set {
            ensureUniqueReference()
            let newAttributedString = AttributedString(String(newValue))
            if newAttributedString._guts.runs.count > 0 {
                var run = newAttributedString._guts.runs[0]
                let attributes = _guts.run(
                    at: bounds.lowerBound, clampedBy: _range
                ).run.attributes
                run.attributes = attributes.attributesForAddedText(
                    includingCharacterDependentAttributes: newValue.elementsEqual(self[bounds])) // ???: Is this right?
                newAttributedString._guts.updateAndCoalesce(run: run, at: 0)
            }
            _guts.replaceSubrange(bounds, with: newAttributedString)
        }
    }

    public mutating func replaceSubrange<C : Collection>(
        _ subrange: Range<Index>, with newElements: C
    ) where C.Element == Character {
        precondition(
            subrange.lowerBound >= self.startIndex && subrange.upperBound <= self.endIndex,
            "AttributedString index range out of bounds")

        ensureUniqueReference()

        let replacement = AttributedString._bstring(from: newElements)
        let sameText = _BString.characterIsEqual(
            replacement, in: replacement.startIndex ..< replacement.endIndex,
            to: _guts.string, in: subrange._bstringRange)

        let attributes = _guts.attributesToUseForTextReplacement(
            in: subrange,
            includingCharacterDependentAttributes: sameText)

        let new = AttributedString(replacement, attributes: attributes)
        let startOffset = _guts.utf8Offset(of: self.startIndex)
        let endOffset = _guts.utf8Offset(of: self.endIndex)

        let oldCount = _guts.string.utf8Count
        _guts.replaceSubrange(subrange, with: new)
        let newCount = _guts.string.utf8Count

        _range = _guts.utf8IndexRange(from: startOffset ..< endOffset + (newCount - oldCount))
    }
}
