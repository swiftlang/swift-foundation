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
    public struct UnicodeScalarView {
        internal var _guts : Guts
        internal var _range : Range<Index>
        internal var _identity : Int = 0
        internal init(_ g: Guts, _ r: Range<Index>) {
            _guts = g
            _range = r
        }
        
        public init() {
            _guts = Guts(string: "", runs: [])
            _range = _guts.startIndex ..< _guts.endIndex
        }
    }

    public var unicodeScalars: UnicodeScalarView {
        get {
            UnicodeScalarView(_guts, startIndex ..< endIndex)
        }
        _modify {
            ensureUniqueReference()
            var usv = UnicodeScalarView(_guts, startIndex ..< endIndex)
            let ident = Self._nextModifyIdentity
            usv._identity = ident
            _guts = Guts(string: "", runs: []) // Dummy guts so the UnicodeScalarView has (hopefully) the sole reference
            defer {
                if usv._identity != ident {
                    fatalError("Mutating a UnicodeScalarView by replacing it with another from a different source is unsupported")
                }
                _guts = usv._guts
            }
            yield &usv
        } set {
            self.unicodeScalars.replaceSubrange(startIndex ..< endIndex, with: newValue)
        }
    }
}

extension AttributedString.UnicodeScalarView {
    // FIXME: AttributedString.UnicodeScalarView needs to publicly conform to Hashable.
    internal func _isEqual(to other: Self) -> Bool {
        // FIXME: Just compare the raw UTF-8 data.
        let c1 = self._guts.unicodeScalarDistance(from: self.startIndex, to: self.endIndex)
        let c2 = other._guts.unicodeScalarDistance(from: other.startIndex, to: other.endIndex)
        guard c1 == c2 else { return false }

        var i1 = self.startIndex._value
        var i2 = other.startIndex._value
        for _ in 0 ..< c1 {
            let x = self._guts.string[unicodeScalar: i1]
            let y = other._guts.string[unicodeScalar: i2]
            guard x == y else { return false }
            i1 = self._guts.string.unicodeScalarIndex(after: i1)
            i2 = other._guts.string.unicodeScalarIndex(after: i2)
        }
        return true
    }

    internal func _hash(into hasher: inout Hasher) {
        let start = self._guts.string.unicodeScalarIndex(roundingDown: self.startIndex._value)
        let end = self._guts.string.unicodeScalarIndex(roundingDown: self.endIndex._value)
        self._guts.string.hashUTF8(into: &hasher, from: start, to: end)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.UnicodeScalarView: BidirectionalCollection, RangeReplaceableCollection {
    public typealias Element = UnicodeScalar
    public typealias Index = AttributedString.Index

    public var startIndex: AttributedString.Index {
        return _range.lowerBound
    }

    public var endIndex: AttributedString.Index {
        return _range.upperBound
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
        _guts.unicodeScalarDistance(from: _range.lowerBound, to: _range.upperBound)
    }

    public func index(before i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalarIndex(before: i._value))
        precondition(j >= startIndex, "Can't advance AttributedString index before start index")
        return j
    }

    public func index(after i: AttributedString.Index) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalarIndex(after: i._value))
        precondition(j <= endIndex, "Can't advance AttributedString index after end index")
        return j
    }

    public func index(_ i: AttributedString.Index, offsetBy distance: Int) -> AttributedString.Index {
        precondition(i >= startIndex && i <= endIndex, "AttributedString index out of bounds")
        let j = Index(_guts.string.unicodeScalarIndex(i._value, offsetBy: distance))
        precondition(j >= startIndex && j <= endIndex, "AttributedString index out of bounds")
        return j
    }

    // FIXME: Implement index(_:offsetBy:limitedBy:)

    @_alwaysEmitIntoClient
    public func distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
            return _distance(from: start, to: end)
        }
        return _defaultDistance(from: start, to: end)
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    @usableFromInline
    internal func _distance(
        from start: AttributedString.Index,
        to end: AttributedString.Index
    ) -> Int {
        precondition(start >= startIndex && start <= endIndex, "AttributedString index out of bounds")
        precondition(end >= startIndex && end <= endIndex, "AttributedString index out of bounds")
        return _guts.string.unicodeScalarDistance(from: start._value, to: end._value)
    }

    public subscript(index: AttributedString.Index) -> UnicodeScalar {
        _guts.string[unicodeScalar: index._value]
    }

    public subscript(bounds: Range<AttributedString.Index>) -> Slice<AttributedString.UnicodeScalarView> {
        Slice(base: self, bounds: bounds)
    }

    internal mutating func ensureUniqueReference() {
        if !isKnownUniquelyReferenced(&_guts) {
            _guts = _guts.copy()
        }
    }

    public mutating func replaceSubrange<C : Collection>(
        _ subrange: Range<Index>,
        with newElements: C
    ) where C.Element == UnicodeScalar {
        precondition(
            subrange.lowerBound >= self.startIndex && subrange.upperBound <= self.endIndex,
            "AttributedString index range out of bounds")

        ensureUniqueReference()
        let unicodeScalarView = String.UnicodeScalarView(newElements)
        let newElementsString = String(unicodeScalarView)
        let newAttributedString = AttributedString(newElementsString)
        if newAttributedString._guts.runs.count > 0 {
            var run = newAttributedString._guts.runs[0]
            run.attributes = _guts.attributesToUseForTextReplacement(in: subrange, includingCharacterDependentAttributes: newElements.elementsEqual(self[subrange]))
            newAttributedString._guts.updateAndCoalesce(run: run, at: 0)
        }

        let startOffset = _guts.utf8Offset(of: self.startIndex)
        let endOffset = _guts.utf8Offset(of: self.endIndex)

        let oldCount = _guts.string.utf8Count
        _guts.replaceSubrange(subrange, with: newAttributedString)
        let newCount = _guts.string.utf8Count

        _range = _guts.utf8IndexRange(from: startOffset ..< endOffset + (newCount - oldCount))
    }
}
