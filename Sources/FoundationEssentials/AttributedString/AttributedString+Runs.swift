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
    public struct Runs: Sendable {
        internal typealias _InternalRun = AttributedString._InternalRun
        internal typealias _AttributeStorage = AttributedString._AttributeStorage
        internal typealias _InternalRuns = AttributedString._InternalRuns
        internal typealias AttributeRunBoundaries = AttributedString.AttributeRunBoundaries

        internal var _guts: Guts
        internal var _bounds: Range<Index>
        internal var _strBounds: Range<BigString.Index>

        internal init(_ guts: Guts, in bounds: Range<BigString.Index>) {
            _guts = guts

            let stringLowerBound = _guts.string.unicodeScalars.index(roundingDown: bounds.lowerBound)
            let stringUpperBound = _guts.string.unicodeScalars.index(roundingDown: bounds.upperBound)
            _strBounds = stringLowerBound ..< stringUpperBound

            let lower = _guts.findRun(at: _strBounds.lowerBound)
            let start = Index(_runIndex: lower.runIndex, stringIndex: lower.start)

            let end: Index

            if _strBounds.upperBound == _guts.string.endIndex {
                end = Index(
                    _runOffset: _guts.runs.count,
                    runIndex: _guts.runs.endIndex.base,
                    stringIndex: _strBounds.upperBound)
            } else if _strBounds.upperBound == _guts.string.startIndex {
                assert(stringLowerBound == stringUpperBound)
                end = start
            } else {
                let last = _guts.runs.index(atUTF8Offset: _strBounds.upperBound.utf8Offset - 1).index
                let next = _guts.runs.index(after: last)

                let stringEnd = _guts.string.utf8.index(
                    _strBounds.upperBound,
                    offsetBy: next.utf8Offset - _strBounds.upperBound.utf8Offset)
                end = Index(_runIndex: next, stringIndex: stringEnd)
            }
            assert(start._runIndex != nil && start._stringIndex != nil)
            assert(end._runIndex != nil && end._stringIndex != nil)
            assert(start._stringIndex!.utf8Offset <= _strBounds.lowerBound.utf8Offset)
            assert(end._stringIndex!.utf8Offset >= _strBounds.upperBound.utf8Offset)
            self._bounds = start ..< end
        }
    }

    public var runs: Runs {
        Runs(_guts, in: _guts.string.startIndex ..< _guts.string.endIndex)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Note: Unlike AttributedString itself, this is comparing run lengths without normalizing
        // the underlying characters.
        //
        // I.e., the runs of two equal attribute strings may or may not compare equal.

        // Shortcut: compare overall UTF-8 counts.
        let leftUTF8Count = lhs._strBounds._utf8OffsetRange.count
        let rightUTF8Count = rhs._strBounds._utf8OffsetRange.count
        guard leftUTF8Count == rightUTF8Count else { return false }

        // Shortcut: compare run counts.
        let leftRunCount = lhs._bounds.upperBound._runOffset - lhs._bounds.lowerBound._runOffset
        let rightRunCount = rhs._bounds.upperBound._runOffset - rhs._bounds.lowerBound._runOffset
        guard leftRunCount == rightRunCount else { return false }

        return lhs.elementsEqual(rhs)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: CustomStringConvertible {
    public var description: String {
        _guts.description(in: _strBounds)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    public struct Index: Sendable {
        /// The offset of this run from the start of the attributed string.
        /// This is always set to a valid value.
        internal var _runOffset: Int

        /// The underlying index in the rope.
        ///
        /// This may be nil if the index was advanced without going through the Collection APIs;
        /// in that case, the index can be restored using the offset, although
        /// at a log(count) cost.
        internal var _runIndex: _InternalRuns.Storage.Index?

        /// The position in string storage corresponding to the start of this run.
        /// This may be outside of the bounds of the `Runs` if this is addressing the first run.
        /// (I.e., this is the unsliced, global start of the run.)
        ///
        /// This may be nil if the index was advanced without going through the Collection APIs;
        /// in that case, the index can be restored using the offset, although
        /// at a log(count) cost.
        internal var _stringIndex: BigString.Index?

        internal init(_runOffset: Int) {
            self._runOffset = _runOffset
            self._runIndex = nil
            self._stringIndex = nil
        }

        internal init(_runOffset: Int, runIndex: _InternalRuns.Storage.Index, stringIndex: BigString.Index) {
            self._runOffset = _runOffset
            self._runIndex = runIndex
            self._stringIndex = stringIndex
        }

        internal init(_runIndex: _InternalRuns.Index, stringIndex: BigString.Index) {
            self._runOffset = _runIndex.offset
            self._runIndex = _runIndex.base
            self._stringIndex = stringIndex
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Index: Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._runOffset == rhs._runOffset
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs._runOffset < rhs._runOffset
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Index: Strideable {
    // FIXME: `Index` conforming to `Strideable` was an unfortunate choice.
    // It means we lose direct rope indices whenever someone advances a standalone index,
    // slowing down subsequent access.

    public func distance(to other: Self) -> Int {
        other._runOffset - self._runOffset
    }
        
    public func advanced(by n: Int) -> Self {
        Self(_runOffset: self._runOffset + n)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Range<AttributedString.Runs.Index> {
    var _runOffsetRange: Range<Int> {
        Range<Int>(uncheckedBounds: (lowerBound._runOffset, upperBound._runOffset))
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: BidirectionalCollection {
    public typealias Element = Run

    internal func _resolveRun(_ i: Index) -> _InternalRuns.Index {
        precondition(i >= _bounds.lowerBound && i <= _bounds.upperBound, "Index out of bounds")
        guard let ri = i._runIndex, _guts.runs._rope.isValid(ri) else {
            return _guts.runs.index(atRunOffset: i._runOffset)
        }
        let utf8Offset = (
            i._stringIndex.map { $0.utf8Offset }
            ?? _guts.runs._rope.offset(of: ri, in: _InternalRuns.UTF8Metric()))
        return _InternalRuns.Index(ri, offset: i._runOffset, utf8Offset: utf8Offset)
    }

    internal func _resolve(_ i: Index) -> (runIndex: _InternalRuns.Index, start: BigString.Index) {
        let runIndex = _resolveRun(i)
        var start: BigString.Index
        if let si = i._stringIndex, si.utf8Offset == runIndex.utf8Offset {
            // Don't trust that the string index is still valid. Let BigString resolve it.
            start = _guts.string.utf8.index(roundingDown: si)
        } else {
            start = _guts.utf8Index(at: runIndex.utf8Offset)
        }
        return (runIndex, start)
    }

    public var startIndex: Index {
        _bounds.lowerBound
    }

    public var endIndex: Index {
        _bounds.upperBound
    }

    public func index(after i: Index) -> Index {
        precondition(i >= _bounds.lowerBound, "AttributedString.Runs index out of bounds")
        precondition(i < _bounds.upperBound, "Can't advance AttributedString.Runs index beyond end")
        let next = _guts.runs.index(after: _resolveRun(i))
        let stringIndex = (
            i._stringIndex.map { _guts.string.utf8.index($0, offsetBy: next.utf8Offset - $0.utf8Offset) }
            ?? _guts.utf8Index(at: next.utf8Offset))
        return Index(_runIndex: next, stringIndex: stringIndex)
    }

    public func index(before i: Index) -> Index {
        precondition(i > _bounds.lowerBound, "Can't step AttributedString.Runs index below start")
        let prev = _guts.runs.index(before: _resolveRun(i))
        let stringIndex = (
            i._stringIndex.map { _guts.string.utf8.index($0, offsetBy: prev.utf8Offset - $0.utf8Offset) }
            ?? _guts.utf8Index(at: prev.utf8Offset))
        return Index(_runIndex: prev, stringIndex: stringIndex)
    }
    
    @_alwaysEmitIntoClient
    public func distance(from start: Index, to end: Index) -> Int {
        start.distance(to: end)
    }

    @_alwaysEmitIntoClient
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
    #if FOUNDATION_FRAMEWORK
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return _index(i, offsetBy: distance)
        }
    #endif
        return i.advanced(by: distance)
    }

    @available(FoundationPreview 0.1, *)
    @usableFromInline
    internal func _index(_ index: Index, offsetBy distance: Int) -> Index {
        let i = _guts.runs.index(_resolveRun(index), offsetBy: distance)
        // Note: bounds checking of result is delayed until subscript.
        let stringIndex = (
            index._stringIndex.map { _guts.string.utf8.index($0, offsetBy: i.utf8Offset - $0.utf8Offset) }
            ?? _guts.utf8Index(at: i.utf8Offset))
        return Index(_runIndex: i, stringIndex: stringIndex)
    }

    @_alwaysEmitIntoClient
    public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        // This is the stdlib's default implementation for RandomAccessCollection types.
        // (It's _far_ more efficient than the O(n) algorithm that used to apply here by default,
        // in both the original and the tree-based representation.)
        let l = self.distance(from: i, to: limit)
        if distance > 0 ? l >= 0 && l < distance : l <= 0 && distance < l {
            return nil
        }
        return index(i, offsetBy: distance)
    }

    public subscript(position: Index) -> Run {
        precondition(_bounds.contains(position), "AttributedString.Runs index is out of bounds")
        return self[_unchecked: _resolve(position)]
    }

    public subscript(position: AttributedString.Index) -> Run {
        precondition(
            _strBounds.contains(position._value),
            "AttributedString index is out of bounds")
        let r = _guts.findRun(at: position._value)
        return self[_unchecked: r]
    }

    internal subscript(_unchecked i: (runIndex: _InternalRuns.Index, start: BigString.Index)) -> Run {
        let run = _guts.runs[i.runIndex]
        // Clamp the run into the bounds of self, using relative calculations.
        let lowerBound = Swift.max(i.start, _strBounds.lowerBound)
        let upperUTF8 = Swift.min(i.start.utf8Offset + run.length, _strBounds.upperBound.utf8Offset)
        let upperBound = _guts.string.utf8.index(lowerBound, offsetBy: upperUTF8 - lowerBound.utf8Offset)
        return Run(_attributes: run.attributes, lowerBound ..< upperBound, _guts)
    }

    internal subscript(internal position: Index) -> _InternalRun {
        let i = _resolveRun(position)
        return _guts.runs[i]
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    // FIXME: Make public, with a better name. (Probably no need to state "run" -- `index(containing:)`?)
    internal func indexOfRun(at position: AttributedString.Index) -> Index {
        precondition(
            position._value >= _strBounds.lowerBound && position._value <= _strBounds.upperBound,
            "AttributedString index is out of bounds")
        let r = _guts.findRun(at: position._value)
        return Index(_runIndex: r.runIndex, stringIndex: r.start)
    }
    
    internal func _firstOfMatchingRuns(
        with i: _InternalRuns.Index,
        comparing attributeNames: [String]
    ) -> _InternalRuns.Index {
        precondition(!attributeNames.isEmpty)
        let attributes = _guts.runs[i].attributes
        var j = i
        while j.offset > startIndex._runOffset {
            let prev = _guts.runs.index(before: j)
            let a = _guts.runs[prev].attributes
            if !attributes.isEqual(to: a, comparing: attributeNames) {
                return j
            }
            j = prev
        }
        return j
    }
    
    internal func _lastOfMatchingRuns(
        with i: _InternalRuns.Index,
        comparing attributeNames: [String]
    ) -> _InternalRuns.Index {
        precondition(!attributeNames.isEmpty)
        precondition(i.offset < endIndex._runOffset)
        let attributes = _guts.runs[i].attributes
        var j = i
        while true {
            let next = _guts.runs.index(after: j)
            if next.offset == endIndex._runOffset { break }
            let a = _guts.runs[next].attributes
            if !attributes.isEqual(to: a, comparing: attributeNames) {
                return j
            }
            j = next
        }
        return j
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    internal func _slicedRunBoundary(
        after i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        precondition(
            self._strBounds.contains(i._value),
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let r = _guts.findRun(at: i._value)
        let endRun = _lastOfMatchingRuns(with: r.runIndex, comparing: attributeNames)
        let utf8End = endRun.utf8Offset + _guts.runs[endRun].length
        let stringEnd = Swift.min(
            _guts.string.utf8.index(r.start, offsetBy: utf8End - r.start.utf8Offset),
            _strBounds.upperBound)
        return .init(_guts.string._firstConstraintBreak(in: i._value ..< stringEnd, with: constraints))
    }

    internal func _slicedRunBoundary(
        before i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        precondition(
            i._value > self._strBounds.lowerBound && i._value <= self._strBounds.upperBound,
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let r = _guts.runs.index(atUTF8Offset: i._value.utf8Offset - 1)
        let startRun = _firstOfMatchingRuns(with: r.index, comparing: attributeNames)
        let stringStart = Swift.max(
            _guts.string.utf8.index(i._value, offsetBy: startRun.utf8Offset - i._value.utf8Offset),
            _strBounds.lowerBound)
        return .init(_guts.string._lastConstraintBreak(in: stringStart ..< i._value, with: constraints))
    }

    internal func _slicedRunBoundary(
        roundingDown i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> (index: AttributedString.Index, runIndex: AttributedString._InternalRuns.Index) {
        precondition(
            i._value >= self._strBounds.lowerBound && i._value <= self._strBounds.upperBound,
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let r = _guts.findRun(at: i._value)
        if r.runIndex.offset == endIndex._runOffset {
            return (i, r.runIndex)
        }
        let startRun = _firstOfMatchingRuns(with: r.runIndex, comparing: attributeNames)
        let stringStart = Swift.max(
            _guts.string.utf8.index(r.start, offsetBy: startRun.utf8Offset - r.start.utf8Offset),
            _strBounds.lowerBound)

        let j = _guts.string.unicodeScalars.index(after: i._value)
        let last = _guts.string._lastConstraintBreak(in: stringStart ..< j, with: constraints)
        return (.init(last), r.runIndex)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension BigString {
    internal func _firstConstraintBreak(
        in range: Range<Index>,
        with constraints: [AttributedString.AttributeRunBoundaries]
    ) -> Index {
        guard !constraints.isEmpty, !range.isEmpty else { return range.upperBound }

        var r = range
        if
            constraints.contains(.paragraph),
            let firstBreak = self._findFirstParagraphBoundary(in: r)
        {
            r = r.lowerBound ..< firstBreak
        }

        if constraints._containsScalarConstraint {
            // Note: we need to slice runs on matching scalars even if they don't carry
            // the attributes we're looking for.
            let scalars: [UnicodeScalar] = constraints.compactMap { $0._constrainedScalar }
            if let firstBreak = self.unicodeScalars[r]._findFirstScalarBoundary(for: scalars) {
                r = r.lowerBound ..< firstBreak
            }
        }

        return r.upperBound
    }

    internal func _lastConstraintBreak(
        in range: Range<Index>,
        with constraints: [AttributedString.AttributeRunBoundaries]
    ) -> Index {
        guard !constraints.isEmpty, !range.isEmpty else { return range.lowerBound }

        var r = range
        if
            constraints.contains(.paragraph),
            let lastBreak = self._findLastParagraphBoundary(in: r)
        {
            r = lastBreak ..< r.upperBound
        }

        if constraints._containsScalarConstraint {
            // Note: we need to slice runs on matching scalars even if they don't carry
            // the attributes we're looking for.
            let scalars: [UnicodeScalar] = constraints.compactMap { $0._constrainedScalar }
            if let lastBreak = self.unicodeScalars[r]._findLastScalarBoundary(for: scalars) {
                r = lastBreak ..< r.upperBound
            }
        }

        return r.lowerBound
    }

    internal func _findFirstParagraphBoundary(in range: Range<Index>) -> Index? {
        self.utf8[range]._getBlock(for: [.findEnd], in: range.lowerBound ..< range.lowerBound).end
    }

    internal func _findLastParagraphBoundary(in range: Range<Index>) -> Index? {
        guard range.upperBound > startIndex else { return nil }
        let lower = self.utf8.index(before: range.upperBound)
        return self.utf8[range]._getBlock(for: [.findStart], in: lower ..< range.upperBound).start
    }
}

extension BigSubstring.UnicodeScalarView {
    internal func _findFirstScalarBoundary(for scalars: [UnicodeScalar]) -> Index? {
        var i = self.startIndex
        guard i < self.endIndex else { return nil }
        if scalars.contains(self[i]) {
            return self.index(after: i)
        }
        while true {
            self.formIndex(after: &i)
            guard i < self.endIndex else { break }
            if scalars.contains(self[i]) {
                return i
            }
        }
        return nil
    }

    internal func _findLastScalarBoundary(for scalars: [UnicodeScalar]) -> Index? {
        guard !isEmpty else { return nil }
        var i = self.index(before: self.endIndex)
        if scalars.contains(self[i]) {
            return i
        }
        while i > self.startIndex {
            let j = self.index(before: i)
            if scalars.contains(self[j]) {
                return i
            }
            i = j
        }
        return nil
    }
}
