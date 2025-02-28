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

        internal let _guts: Guts
        internal let _bounds: Range<Index>
        internal let _strBounds: RangeSet<BigString.Index>
        internal let _isDiscontiguous: Bool
        
        internal init(_ guts: Guts, in bounds: Range<BigString.Index>) {
            self.init(guts, in: RangeSet(bounds))
        }

        internal init(_ guts: Guts, in bounds: RangeSet<BigString.Index>) {
            _guts = guts

            var roundedBounds = RangeSet<BigString.Index>()
            for range in bounds.ranges {
                let stringLowerBound = _guts.string.unicodeScalars.index(roundingDown: range.lowerBound)
                let stringUpperBound = _guts.string.unicodeScalars.index(roundingDown: range.upperBound)
                roundedBounds.insert(contentsOf: Range(uncheckedBounds: (stringLowerBound, stringUpperBound)))
            }
            _strBounds = roundedBounds
            _isDiscontiguous = _strBounds.ranges.count > 1
            
            guard let first = _strBounds.ranges.first, let last = _strBounds.ranges.last else {
                _bounds = Range(uncheckedBounds: (
                    Index(_runIndex: _guts.runs.startIndex, startStringIndex: _guts.string.startIndex, stringIndex: _guts.string.startIndex, rangeOffset: -1, withinDiscontiguous: false),
                    Index(_runIndex: _guts.runs.startIndex, startStringIndex: _guts.string.startIndex, stringIndex: _guts.string.startIndex, rangeOffset: -1, withinDiscontiguous: false)
                ))
                return
            }

            let lower = _guts.findRun(at: first.lowerBound)
            let start = Index(_runIndex: lower.runIndex, startStringIndex: lower.start, stringIndex: first.lowerBound, rangeOffset: 0, withinDiscontiguous: _isDiscontiguous)

            let end: Index

            if last.upperBound == _guts.string.endIndex {
                end = Index(
                    _runOffset: _guts.runs.count,
                    runIndex: _guts.runs.endIndex.base,
                    startStringIndex: last.upperBound,
                    stringIndex: last.upperBound,
                    rangeOffset: _strBounds.ranges.count,
                    withinDiscontiguous: _isDiscontiguous)
            } else {
                let (run, runStartIdx) = _guts.findRun(at: last.upperBound)
                end = Index(_runIndex: run, startStringIndex: runStartIdx, stringIndex: last.upperBound, rangeOffset: _strBounds.ranges.count, withinDiscontiguous: _isDiscontiguous)
            }
            assert(start._runIndex != nil && start._stringIndex != nil)
            assert(end._runIndex != nil && end._stringIndex != nil)
            assert(start._stringIndex!.utf8Offset <= first.lowerBound.utf8Offset)
            assert(end == start || end._stringIndex!.utf8Offset >= last.upperBound.utf8Offset)
            self._bounds = Range(uncheckedBounds: (start, end))
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
        let leftUTF8Count = lhs._strBounds.ranges.map(\._utf8OffsetRange.count).reduce(0, +)
        let rightUTF8Count = rhs._strBounds.ranges.map(\._utf8OffsetRange.count).reduce(0, +)
        guard leftUTF8Count == rightUTF8Count else { return false }

        // Shortcut: compare run counts.
        if !lhs._isDiscontiguous && !rhs._isDiscontiguous {
            let leftRunCount = lhs._bounds.upperBound._runOffset - lhs._bounds.lowerBound._runOffset + (lhs._bounds.upperBound._isSliced ? 1 : 0)
            let rightRunCount = rhs._bounds.upperBound._runOffset - rhs._bounds.lowerBound._runOffset + (rhs._bounds.upperBound._isSliced ? 1 : 0)
            guard leftRunCount == rightRunCount else { return false }
        }

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
        internal var _startStringIndex: BigString.Index?
        
        internal var _stringIndex: BigString.Index?
        
        internal var _rangesOffset: Int?
        
        internal var _withinDiscontiguous: Bool
        
        internal var _isSliced: Bool { _stringIndex != _startStringIndex }

        internal init(_runOffset: Int, withinDiscontiguous: Bool) {
            self._runOffset = _runOffset
            self._runIndex = nil
            self._stringIndex = nil
            self._rangesOffset = nil
            self._withinDiscontiguous = withinDiscontiguous
        }

        internal init(_runOffset: Int, runIndex: _InternalRuns.Storage.Index, startStringIndex: BigString.Index, stringIndex: BigString.Index, rangeOffset: Int, withinDiscontiguous: Bool) {
            self._runOffset = _runOffset
            self._runIndex = runIndex
            self._stringIndex = stringIndex
            self._startStringIndex = startStringIndex
            self._rangesOffset = rangeOffset
            self._withinDiscontiguous = withinDiscontiguous
        }

        internal init(_runIndex: _InternalRuns.Index, startStringIndex: BigString.Index, stringIndex: BigString.Index, rangeOffset: Int, withinDiscontiguous: Bool) {
            self._runOffset = _runIndex.offset
            self._runIndex = _runIndex.base
            self._stringIndex = stringIndex
            self._startStringIndex = startStringIndex
            self._rangesOffset = rangeOffset
            self._withinDiscontiguous = withinDiscontiguous
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs.Index: Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._runOffset == rhs._runOffset && lhs._stringIndex == rhs._stringIndex
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs._runOffset < rhs._runOffset {
            return true
        } else if lhs._runOffset > rhs._runOffset {
            return false
        } else {
            switch(lhs._stringIndex, rhs._stringIndex) {
            case let (.some(lhsIdx), .some(rhsIdx)):
                return lhsIdx < rhsIdx
            case (.none, .some):
                return true
            case (_, .none):
                return false
            }
        }
    }
}

#if !FOUNDATION_FRAMEWORK
@available(macOS, deprecated: 10000, introduced: 12, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(iOS, deprecated: 10000, introduced: 15, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(tvOS, deprecated: 10000, introduced: 15, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(watchOS, deprecated: 10000, introduced: 8, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(visionOS, deprecated: 10000, introduced: 1, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
@available(*, deprecated, message: "AttributedString.Runs.Index should not be used as a Strideable and should instead be offset using the API provided by AttributedString.Runs")
extension AttributedString.Runs.Index: Strideable {
    public func distance(to other: Self) -> Int {
        // This isn't perfect (since two non-sliced indices might have other sliced runs between them) but checking is better than nothing
        precondition(!self._withinDiscontiguous && !other._withinDiscontiguous, "AttributedString.Runs.Index's Strideable conformance may not be used with discontiguous sliced runs")
        return other._runOffset - self._runOffset
    }
        
    public func advanced(by n: Int) -> Self {
        precondition(!self._withinDiscontiguous, "AttributedString.Runs.Index's Strideable conformance may not be used with discontiguous sliced runs")
        return Self(_runOffset: self._runOffset + n, withinDiscontiguous: false)
    }
}
#endif

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
            precondition(!_isDiscontiguous, "Index created via Strideable conformance may not be used with discontiguous runs")
            return _guts.runs.index(atRunOffset: i._runOffset)
        }
        let utf8Offset = (
            i._startStringIndex.map { $0.utf8Offset }
            ?? _guts.runs._rope.offset(of: ri, in: _InternalRuns.UTF8Metric()))
        return _InternalRuns.Index(ri, offset: i._runOffset, utf8Offset: utf8Offset)
    }

    internal func _resolve(_ i: Index) -> (runIndex: _InternalRuns.Index, start: BigString.Index) {
        let runIndex = _resolveRun(i)
        var start: BigString.Index
        if let si = i._startStringIndex, si.utf8Offset == runIndex.utf8Offset {
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
        let (resolvedIdx, runStartIdx) = _resolve(i)
        let next = _guts.runs.index(after: resolvedIdx)
        let currentRangeIdx = i._rangesOffset ?? _strBounds.rangeIdx(containing: i._stringIndex ?? runStartIdx)
        let currentRange = _strBounds.ranges[currentRangeIdx]
        if currentRange.upperBound.utf8Offset <= next.utf8Offset {
            let nextRangeIdx = currentRangeIdx + 1
            if nextRangeIdx == _strBounds.ranges.count {
                return endIndex
            } else {
                let strIdx = _strBounds.ranges[nextRangeIdx].lowerBound
                let (runIdx, startStringIdx) = _guts.findRun(at: strIdx)
                return Index(_runIndex: runIdx, startStringIndex: startStringIdx, stringIndex: strIdx, rangeOffset: nextRangeIdx, withinDiscontiguous: _isDiscontiguous)
            }
        } else {
            let stringIndex = (
                i._startStringIndex.map { _guts.string.utf8.index($0, offsetBy: next.utf8Offset - $0.utf8Offset) }
                ?? _guts.utf8Index(at: next.utf8Offset))
            return Index(_runIndex: next, startStringIndex: stringIndex, stringIndex: stringIndex, rangeOffset: currentRangeIdx, withinDiscontiguous: _isDiscontiguous)
        }
    }

    public func index(before i: Index) -> Index {
        precondition(i > _bounds.lowerBound, "Can't step AttributedString.Runs index below start")
        let (resolvedIdx, runStartIdx) = _resolve(i)
        let currentRangeIdx = i._rangesOffset ?? _strBounds.rangeIdx(containing: i._stringIndex ?? runStartIdx)
        if i == endIndex || runStartIdx.utf8Offset <= _strBounds.ranges[currentRangeIdx].lowerBound.utf8Offset {
            // The current run starts on or before our current range, look up the next range
            let previousRange = _strBounds.ranges[currentRangeIdx - 1]
            let justInsideRangeIdx = _guts.string.utf8.index(before: previousRange.upperBound)
            if justInsideRangeIdx < runStartIdx {
                // We're outside the current logical run, so lookup the new one
                let (previousRunIdx, runStartIdx) = _guts.findRun(at: justInsideRangeIdx)
                let stringIndex = Swift.max(runStartIdx, previousRange.lowerBound)
                return Index(_runIndex: previousRunIdx, startStringIndex: runStartIdx, stringIndex: stringIndex, rangeOffset: currentRangeIdx - 1, withinDiscontiguous: _isDiscontiguous)
            } else {
                // We're still inside the current logical run
                let stringIndex = Swift.max(runStartIdx, previousRange.lowerBound)
                return Index(_runIndex: resolvedIdx, startStringIndex: runStartIdx, stringIndex: stringIndex, rangeOffset: currentRangeIdx - 1, withinDiscontiguous: _isDiscontiguous)
            }
        } else {
            // The current run stops within our range, lookup the prior run
            let prev = _guts.runs.index(before: resolvedIdx)
            let prevStartStringIdx = (
                i._startStringIndex.map { _guts.string.utf8.index($0, offsetBy: prev.utf8Offset - $0.utf8Offset) }
                ?? _guts.utf8Index(at: prev.utf8Offset))
            let stringIndex = Swift.max(prevStartStringIdx, _strBounds.ranges[currentRangeIdx].lowerBound)
            return Index(_runIndex: prev, startStringIndex: prevStartStringIdx, stringIndex: stringIndex, rangeOffset: currentRangeIdx, withinDiscontiguous: _isDiscontiguous)
        }
    }
    
    #if !FOUNDATION_FRAMEWORK
    @_alwaysEmitIntoClient
    public func distance(from start: Index, to end: Index) -> Int {
        _distance(from: start, to: end)
    }
    #endif
    
    @available(FoundationPreview 6.2, *)
    @usableFromInline
    internal func _distance(from start: Index, to end: Index) -> Int {
        guard _isDiscontiguous else {
            return end._runOffset - start._runOffset + (end._isSliced ? 1 : 0)
        }
        var dist = 0
        var current = start
        while current < end {
            formIndex(after: &current)
            dist += 1
        }
        return dist
    }

    @_alwaysEmitIntoClient
    public func index(_ i: Index, offsetBy distance: Int) -> Index {
    #if FOUNDATION_FRAMEWORK
        if #available(macOS 14, iOS 17, tvOS 17, watchOS 10, *) {
            return _index(i, offsetBy: distance)
        }
        return i.advanced(by: distance)
    #else
        return _index(i, offsetBy: distance)
    #endif
    }

    @available(FoundationPreview 0.1, *)
    @usableFromInline
    internal func _index(_ index: Index, offsetBy distance: Int) -> Index {
        guard _isDiscontiguous else {
            // Fast path, we can just increment the run offset since we know there are no "gaps"
            let i = _guts.runs.index(_resolveRun(index), offsetBy: distance)
            // Note: bounds checking of result is delayed until subscript.
            let stringIndex = (
                index._startStringIndex.map { _guts.string.utf8.index($0, offsetBy: i.utf8Offset - $0.utf8Offset) }
                ?? _guts.utf8Index(at: i.utf8Offset))
            return Index(_runIndex: i, startStringIndex: stringIndex, stringIndex: stringIndex, rangeOffset: 0, withinDiscontiguous: false)
        }
        let op = distance < 0 ? self.formIndex(before:) : self.formIndex(after:)
        var idx = index
        for _ in 0 ..< Swift.abs(distance) {
            op(&idx)
        }
        return idx
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
        if let strIdx = position._stringIndex {
            precondition(_strBounds.contains(strIdx), "AttributedString.Runs index is out of bounds")
        }
        let resolved = _resolve(position)
        return self[_unchecked: resolved.runIndex, stringStartIdx: position._startStringIndex ?? resolved.start, stringIdx: position._stringIndex ?? resolved.start, rangeOffset: position._rangesOffset]
    }

    public subscript(position: AttributedString.Index) -> Run {
        precondition(
            _strBounds.contains(position._value),
            "AttributedString index is out of bounds")
        let r = _guts.findRun(at: position._value)
        return self[_unchecked: r.runIndex, stringStartIdx: r.start, stringIdx: position._value]
    }

    internal subscript(_unchecked i: _InternalRuns.Index, stringStartIdx stringStartIdx: BigString.Index, stringIdx stringIdx: BigString.Index, rangeOffset rangeOffset: Int? = nil) -> Run {
        let run = _guts.runs[i]
        // Clamp the run into the bounds of self, using relative calculations.
        let range = _strBounds.ranges[rangeOffset ?? _strBounds.rangeIdx(containing: stringIdx)]
        let lowerBound = Swift.max(stringStartIdx, range.lowerBound)
        let upperUTF8 = Swift.min(stringStartIdx.utf8Offset + run.length, range.upperBound.utf8Offset)
        let upperBound = _guts.string.utf8.index(stringIdx, offsetBy: upperUTF8 - stringIdx.utf8Offset)
        return Run(_attributes: run.attributes, Range(uncheckedBounds: (lowerBound, upperBound)), _guts)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    // FIXME: Make public, with a better name. (Probably no need to state "run" -- `index(containing:)`?)
    internal func indexOfRun(at position: AttributedString.Index) -> Index {
        precondition(
            _strBounds.contains(position._value),
            "AttributedString index is out of bounds")
        let r = _guts.findRun(at: position._value)
        let rangeIdx = _strBounds.rangeIdx(containing: position._value)
        let range = _strBounds.ranges[rangeIdx]
        let strIdx = Swift.max(range.lowerBound, r.start)
        return Index(_runIndex: r.runIndex, startStringIndex: r.start, stringIndex: strIdx, rangeOffset: rangeIdx, withinDiscontiguous: _isDiscontiguous)
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
        if i.offset == endIndex._runOffset && endIndex._isSliced {
            return i
        }
        precondition(i.offset < endIndex._runOffset)
        let attributes = _guts.runs[i].attributes
        var j = i
        while true {
            let next = _guts.runs.index(after: j)
            if next.offset > endIndex._runOffset || (next.offset == endIndex._runOffset && !endIndex._isSliced) { break }
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
        constraints: [AttributeRunBoundaries],
        endOfCurrent: Bool
    ) -> AttributedString.Index {
        precondition(
            self._strBounds.contains(i._value),
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let r = _guts.findRun(at: i._value)
        let endRun = _lastOfMatchingRuns(with: r.runIndex, comparing: attributeNames)
        let utf8End = endRun.utf8Offset + _guts.runs[endRun].length
        let strIndexEnd = _guts.string.utf8.index(r.start, offsetBy: utf8End - r.start.utf8Offset)
        let currentRangeIdx = _strBounds.rangeIdx(containing: i._value)
        let currentRange = _strBounds.ranges[currentRangeIdx]
        if strIndexEnd < currentRange.upperBound {
            // The coalesced run ends within the current range, so just look for the next break in the coalesced run
            return .init(_guts.string._firstConstraintBreak(in: i._value ..< strIndexEnd, with: constraints), version: _guts.version)
        } else {
            // The coalesced run extends beyond our range
            // First determine if there's a constraint break to handle
            let constraintBreak = _guts.string._firstConstraintBreak(in: i._value ..< currentRange.upperBound, with: constraints)
            if constraintBreak == currentRange.upperBound {
                if endOfCurrent { return .init(currentRange.upperBound, version: _guts.version) }
                // No constraint break, return the next subrange start or the end index
                if currentRangeIdx == _strBounds.ranges.count - 1 {
                    return .init(currentRange.upperBound, version: _guts.version)
                } else {
                    return .init(_strBounds.ranges[currentRangeIdx + 1].lowerBound, version: _guts.version)
                }
            } else {
                // There is a constraint break before the end of the subrange, so return that break
                return .init(constraintBreak, version: _guts.version)
            }
        }
        
    }

    internal func _slicedRunBoundary(
        before i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries],
        endOfPrevious: Bool
    ) -> AttributedString.Index {
        precondition(
            _strBounds.contains(i._value) || i._value == endIndex._stringIndex,
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        var currentRangeIdx: Int
        var currentRange: Range<BigString.Index>
        if i._value == endIndex._stringIndex {
            currentRangeIdx = _strBounds.ranges.count
            currentRange = Range(uncheckedBounds: (endIndex._stringIndex!, endIndex._stringIndex!))
        } else {
            currentRangeIdx = _strBounds.rangeIdx(containing: i._value)
            currentRange = _strBounds.ranges[currentRangeIdx]
        }
        var currentStringIdx = i._value
        if currentRange.lowerBound == i._value {
            // We're at the beginning of a subrange, so look to the previous one
            precondition(currentRangeIdx > 0, "Cannot move index before startIndex")
            currentRangeIdx -= 1
            currentRange = _strBounds.ranges[currentRangeIdx]
            currentStringIdx = currentRange.upperBound
            if endOfPrevious { return .init(currentStringIdx, version: _guts.version) }
        }
        let beforeStringIdx = _guts.string.utf8.index(before: currentStringIdx)
        let r = _guts.runs.index(atUTF8Offset: beforeStringIdx.utf8Offset)
        let startRun = _firstOfMatchingRuns(with: r.index, comparing: attributeNames)
        if startRun.utf8Offset >= currentRange.lowerBound.utf8Offset {
            // The coalesced run begins within the current range, so just look for the next break in the coalesced run
            let runStartStringIdx = _guts.string.utf8.index(beforeStringIdx, offsetBy: startRun.utf8Offset - beforeStringIdx.utf8Offset)
            return .init(_guts.string._lastConstraintBreak(in: runStartStringIdx ..< currentStringIdx, with: constraints), version: _guts.version)
        } else {
            // The coalesced run starts before the current range, and we've already looked back once so we shouldn't look back again
            return .init(_guts.string._lastConstraintBreak(in: currentRange.lowerBound ..< currentStringIdx, with: constraints), version: _guts.version)
        }
    }

    internal func _slicedRunBoundary(
        roundingDown i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> (index: AttributedString.Index, runIndex: AttributedString._InternalRuns.Index) {
        precondition(
            _strBounds.contains(i._value) || i._value == endIndex._stringIndex,
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let r = _guts.findRun(at: i._value)
        if r.runIndex.offset == endIndex._runOffset {
            return (i, r.runIndex)
        }
        let startRun = _firstOfMatchingRuns(with: r.runIndex, comparing: attributeNames)
        let currentRange = _strBounds.ranges[_strBounds.rangeIdx(containing: i._value)]
        let stringStart = Swift.max(
            _guts.string.utf8.index(r.start, offsetBy: startRun.utf8Offset - r.start.utf8Offset),
            currentRange.lowerBound)

        let j = _guts.string.unicodeScalars.index(after: i._value)
        let last = _guts.string._lastConstraintBreak(in: stringStart ..< j, with: constraints)
        return (.init(last, version: _guts.version), r.runIndex)
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

extension RangeSet {
    fileprivate func rangeIdx(containing index: Bound) -> Int {
        var start = 0
        var end = self.ranges.count
        while start < end {
            let middle = (start + end) / 2
            let value = self.ranges[middle]
            if value.contains(index) {
                return middle
            } else if index < value.lowerBound {
                end = middle
            } else {
                start = middle + 1
            }
        }
        preconditionFailure("Internal Inconsistency: Provided index \(index) is out of bounds")
    }
}
