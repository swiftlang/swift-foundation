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
    public struct Runs: Sendable {
        internal typealias _InternalRun = AttributedString._InternalRun
        internal typealias _AttributeStorage = AttributedString._AttributeStorage
        internal typealias AttributeRunBoundaries = AttributedString.AttributeRunBoundaries
        
        internal var _guts: Guts
        internal var _range: Range<AttributedString.Index>
        internal var _runRange: Range<AttributedString.Runs.Index>

        internal init(_ guts: Guts, _ range: Range<AttributedString.Index>) {
            _guts = guts
            _range = range
            let startRun = _guts.indexOfRun(at: _range.lowerBound)
            let endRun: AttributedString.Runs.Index
            if _range.upperBound == _guts.endIndex {
                endRun = .init(rangeIndex: _guts.runs.count)
            } else if _range.upperBound == _guts.startIndex {
                endRun = .init(rangeIndex: 0)
            } else {
                let prev = _guts.utf8Index(before: _range.upperBound)
                endRun = .init(rangeIndex: _guts.indexOfRun(at: prev).rangeIndex + 1)
            }
            self._runRange = startRun ..< endRun
        }
    }

    public var runs: Runs {
        Runs(_guts, _guts.startIndex ..< _guts.endIndex)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Note: Unlike AttributedString itself, this is comparing run lengths without normalizing
        // the underlying characters.
        //
        // I.e., the runs of two equal attribute strings may or may not compare equal.

        let lhsSlice = lhs._guts.runs[lhs._runRange._offsetRange]
        let rhsSlice = rhs._guts.runs[rhs._runRange._offsetRange]

        // If there are different numbers of runs, they aren't equal
        guard lhsSlice.count == rhsSlice.count else {
            return false
        }
        
        let runCount = lhsSlice.count
        
        // Empty slices are always equal
        guard runCount > 0 else {
            return true
        }
        
        // Compare the first run (clamping their ranges) since we know each has at least one run
        let first1 = lhs._guts.run(at: lhs.startIndex, clampedBy: lhs._range)
        let first2 = rhs._guts.run(at: rhs.startIndex, clampedBy: rhs._range)
        if first1 != first2 {
            return false
        }
        
        // Compare all inner runs if they exist without needing to clamp ranges
        if runCount > 2 {
            let slice1 = lhsSlice[lhsSlice.startIndex + 1 ..< lhsSlice.endIndex - 1]
            let slice2 = rhsSlice[rhsSlice.startIndex + 1 ..< rhsSlice.endIndex - 1]
            if !slice1.elementsEqual(slice2) {
                return false
            }
        }
        
        // If there are more than one run (so we didn't already check this as the first run), check the last run (clamping its range)
        if runCount > 1 {
            let i1 = Index(rangeIndex: lhs._runRange.upperBound.rangeIndex - 1)
            let i2 = Index(rangeIndex: rhs._runRange.upperBound.rangeIndex - 1)
            let last1 = lhs._guts.run(at: i1, clampedBy: lhs._range)
            let last2 = rhs._guts.run(at: i2, clampedBy: rhs._range)
            if last1 != last2 {
                return false
            }
        }
        
        return true
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: CustomStringConvertible {
    public var description: String {
        AttributedSubstring(_guts, in: _range).description
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs: BidirectionalCollection {
    public struct Index: Comparable, Strideable, Sendable {
        internal let rangeIndex: Int
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rangeIndex < rhs.rangeIndex
        }
        
        public func distance(to other: Self) -> Int {
            other.rangeIndex - rangeIndex
        }
        
        public func advanced(by n: Int) -> Self {
            Index(rangeIndex: rangeIndex + n)
        }
    }
    
    public typealias Element = Run
    
    public func index(before i: Index) -> Index {
        Index(rangeIndex: i.rangeIndex - 1)
    }
    
    public func index(after i: Index) -> Index {
        Index(rangeIndex: i.rangeIndex + 1)
    }
    
    public var startIndex: Index {
        _runRange.lowerBound
    }
    
    public var endIndex: Index {
        _runRange.upperBound
    }
    
    public subscript(position: Index) -> Run {
        return _guts.run(at: position, clampedBy: _range)
    }
    
    internal subscript(internal position: Index) -> _InternalRun {
        return _guts.runs[position.rangeIndex]
    }
    
    public subscript(position: AttributedString.Index) -> Run {
        let (internalRun, range) = _guts.run(at: position, clampedBy: _range)
        return Run(_internal: internalRun, range, _guts)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    // ???: public?
    internal func indexOfRun(at position: AttributedString.Index) -> Index {
        return _guts.indexOfRun(at: position)
    }

    internal func _firstOfMatchingRuns(
        with i: Index,
        comparing attributeNames: [String]
    ) -> Index {
        precondition(!attributeNames.isEmpty)
        let attributes = self[internal: i].attributes
        var j = i
        while j > startIndex {
            let prev = index(before: j)
            let run = self[internal: prev]
            if !attributes.isEqual(to: run.attributes, comparing: attributeNames) {
                return j
            }
            j = prev
        }
        return j
    }

    internal func _lastOfMatchingRuns(
        with i: Index,
        comparing attributeNames: [String]
    ) -> Index {
        precondition(!attributeNames.isEmpty)
        precondition(i < endIndex)
        let attributes = self[internal: i].attributes
        var j = i
        while true {
            let next = index(after: j)
            if next == endIndex { break }
            let run = self[internal: next]
            if !attributes.isEqual(to: run.attributes, comparing: attributeNames) {
                return j
            }
            j = next
        }
        return j
    }

    private func firstConstraintBreak(
        in range: Range<AttributedString.Index>,
        with constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        guard !constraints.isEmpty, !range.isEmpty else { return range.upperBound }

        var r = range._bstringRange
        if
            constraints.contains(.paragraph),
            let firstBreak = _guts.string.findFirstParagraphBoundary(in: r)
        {
            r = r.lowerBound ..< firstBreak
        }

        if constraints._containsCharacterConstraint {
            // Note: we need to slice runs on matching characters even if they don't carry
            // the attributes we're looking for.
            let characters: [Character] = constraints.compactMap { $0._constrainedCharacter }
            if let firstBreak = _guts.string[r].findFirstCharacterBoundary(for: characters) {
                r = r.lowerBound ..< firstBreak
            }
        }

        return .init(r.upperBound)
    }

    private func lastConstraintBreak(
        in range: Range<AttributedString.Index>,
        with constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        guard !constraints.isEmpty, !range.isEmpty else { return range.lowerBound }

        var r = range._bstringRange
        if
            constraints.contains(.paragraph),
            let lastBreak = _guts.string.findLastParagraphBoundary(in: r)
        {
            r = lastBreak ..< r.upperBound
        }

        if constraints._containsCharacterConstraint {
            // Note: we need to slice runs on matching characters even if they don't carry
            // the attributes we're looking for.
            let characters: [Character] = constraints.compactMap { $0._constrainedCharacter }
            if let lastBreak = _guts.string[r].findLastCharacterBoundary(for: characters) {
                r = lastBreak ..< r.upperBound
            }
        }

        return .init(r.lowerBound)
    }

    internal func _slicedRunBoundary(
        after i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        precondition(
            _guts.utf8Offset(of: i) >= _guts.utf8Offset(of: self._range.lowerBound)
            && _guts.utf8Offset(of: i) < _guts.utf8Offset(of: self._range.upperBound),
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let runIndex = indexOfRun(at: i)
        let endRun = _lastOfMatchingRuns(with: runIndex, comparing: attributeNames)
        let end = self[endRun].range.upperBound
        return firstConstraintBreak(in: i ..< end, with: constraints)
    }

    internal func _slicedRunBoundary(
        before i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> AttributedString.Index {
        precondition(
            _guts.utf8Offset(of: i) > _guts.utf8Offset(of: self._range.lowerBound)
            && _guts.utf8Offset(of: i) <= _guts.utf8Offset(of: self._range.upperBound),
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let runIndex = indexOfRun(at: _guts.utf8Index(before: i))
        let startRun = _firstOfMatchingRuns(with: runIndex, comparing: attributeNames)
        let start = self[startRun].range.lowerBound
        return lastConstraintBreak(in: start ..< i, with: constraints)
    }

    internal func _slicedRunBoundary(
        roundingDown i: AttributedString.Index,
        attributeNames: [String],
        constraints: [AttributeRunBoundaries]
    ) -> (index: AttributedString.Index, runIndex: AttributedString.Runs.Index) {
        precondition(
            _guts.utf8Offset(of: i) >= _guts.utf8Offset(of: self._range.lowerBound)
            && _guts.utf8Offset(of: i) <= _guts.utf8Offset(of: self._range.upperBound),
            "AttributedString index is out of bounds")
        precondition(!attributeNames.isEmpty)
        let runIndex = indexOfRun(at: i)
        if runIndex == endIndex {
            return (i, runIndex)
        }
        let startRun = _firstOfMatchingRuns(with: runIndex, comparing: attributeNames)
        let start = self[startRun].range.lowerBound
        let j = _guts.characterIndex(after: i)
        return (lastConstraintBreak(in: start ..< j, with: constraints), runIndex)
    }
}

extension BigString {
    func findFirstParagraphBoundary(in range: Range<Index>) -> Index? {
        self.utf8[range]._getBlock(for: [.findEnd], in: range.lowerBound ..< range.lowerBound).end
    }

    func findLastParagraphBoundary(in range: Range<Index>) -> Index? {
        guard range.upperBound > startIndex else { return nil }
        let lower = self.utf8.index(before: range.upperBound)
        return self.utf8[range]._getBlock(for: [.findStart], in: lower ..< range.upperBound).start
    }
}

extension BigSubstring {
    func findFirstCharacterBoundary(for characters: [Character]) -> Index? {
        var i = self.startIndex
        guard i < self.endIndex else { return nil }
        if characters.contains(self[i]) {
            return self.index(after: i)
        }
        while true {
            self.formIndex(after: &i)
            guard i < self.endIndex else { break }
            if characters.contains(self[i]) {
                return i
            }
        }
        return nil
    }

    func findLastCharacterBoundary(for characters: [Character]) -> Index? {
        guard !isEmpty else { return nil }
        var i = self.index(before: self.endIndex)
        if characters.contains(self[i]) {
            return i
        }
        while i > self.startIndex {
            let j = self.index(before: i)
            if characters.contains(self[j]) {
                return i
            }
            i = j
        }
        return nil
    }
}
