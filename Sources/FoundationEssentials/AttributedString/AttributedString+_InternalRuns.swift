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

extension AttributedString {
    /// An internal convenience wrapper around `Rope<_InternalRun>`, giving it functionality
    /// that's specific to attributed strings.
    struct _InternalRuns: Sendable {
        typealias _InternalRun = AttributedString._InternalRun
        typealias Storage = Rope<_InternalRun>

        var _rope: Rope<_InternalRun>

        init() {
            self._rope = Rope()
        }

        init(_ rope: Storage) {
            self._rope = rope
        }

        init(_ runs: some Sequence<_InternalRun>) {
            self._rope = Rope(runs)
        }
    }
}

extension AttributedString._InternalRuns {
    /// A metric that assigns each run a size of 1; i.e., the metric corresponding to run offsets.
    ///
    /// Runs are not divisable under this metric.
    struct RunMetric: RopeMetric {
        typealias Element = AttributedString._InternalRun
        typealias Summary = Element.Summary

        @inline(__always) init() {}

        func size(of summary: Summary) -> Int {
            summary.count
        }

        func index(at offset: Int, in element: Element) -> Int {
            precondition(offset >= 0 && offset <= 1)
            return offset
        }
    }

    /// A metric where the size of each run is the number of UTF-8 code units it is covering.
    /// I.e., the metric corresponding to UTF-8 offsets.
    ///
    /// This enables to quickly find the run that corresponds to a particular UTF-8 position, or
    /// to find the UTF-8 offset range of a specific run.
    ///
    /// Runs are subdivided into UTF-8 positions under this metric, so that e.g. we can split a run
    /// between an arbitrary pair of UTF-8 code units.
    ///
    /// Note that runs do not have direct access to the underlying text data -- they only remember
    /// positional information.
    struct UTF8Metric: RopeMetric {
        typealias Element = AttributedString._InternalRun
        typealias Summary = Element.Summary

        @inline(__always) init() {}

        func size(of summary: Summary) -> Int {
            summary.utf8Length
        }

        func index(at offset: Int, in element: Element) -> Int {
            precondition(offset >= 0 && offset <= element.length)
            return offset
        }
    }
}

extension AttributedString._InternalRuns {
    struct Index {
        /// The underlying index in the rope.
        var base: Storage.Index

        /// The offset of this run from the start of the attributed string.
        var offset: Int

        /// The UTF-8 offset in the string of the start of this run.
        var utf8Offset: Int

        init(_ base: Storage.Index, offset: Int, utf8Offset: Int) {
            self.base = base
            self.offset = offset
            self.utf8Offset = utf8Offset
        }
    }
}

extension AttributedString._InternalRuns.Index: Equatable {
    static func ==(left: Self, right: Self) -> Bool {
        left.utf8Offset == right.utf8Offset
    }
}
extension AttributedString._InternalRuns.Index: Comparable {
    static func <(left: Self, right: Self) -> Bool {
        left.utf8Offset < right.utf8Offset
    }
}

extension AttributedString._InternalRuns: BidirectionalCollection {
    typealias Element = _InternalRun
    typealias SubSequence = Slice<Self>
    typealias _AttributeStorage = AttributedString._AttributeStorage

    var startIndex: Index { Index(_rope.startIndex, offset: 0, utf8Offset: 0) }
    var endIndex: Index { Index(_rope.endIndex, offset: self.count, utf8Offset: utf8Count) }

    var count: Int {
        _rope.count(in: RunMetric())
    }

    func distance(from start: Index, to end: Index) -> Int {
        _rope.distance(from: start.base, to: end.base, in: RunMetric())
    }

    func index(after index: Index) -> Index {
        var i = index
        formIndex(after: &i)
        return i
    }

    func formIndex(after i: inout Index) {
        i.offset += 1
        i.utf8Offset += _rope[i.base].length
        _rope.formIndex(after: &i.base)
    }

    func index(before index: Index) -> Index {
        var i = index
        formIndex(before: &i)
        return i
    }

    func formIndex(before i: inout Index) {
        i.offset -= 1
        _rope.formIndex(before: &i.base)
        i.utf8Offset -= _rope[i.base].length
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        let r = _rope.index(i.base, offsetBy: distance, in: RunMetric(), preferEnd: false)
        assert(r.remaining == 0)
        let utf8Distance = _rope.distance(from: i.base, to: r.index, in: UTF8Metric())
        return Index(r.index, offset: i.offset + distance, utf8Offset: i.utf8Offset + utf8Distance)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        // FIXME: Do we need a direct implementation?
        if distance >= 0 {
            if limit >= i {
                let d = self.distance(from: i, to: limit)
                if d < distance { return nil }
            }
        } else {
            if limit <= i {
                let d = self.distance(from: i, to: limit)
                if d > distance { return nil }
            }
        }
        return self.index(i, offsetBy: distance)
    }

    subscript(position: Index) -> _InternalRun {
        _rope[position.base]
    }
}

extension Slice<AttributedString._InternalRuns> {
    var utf8Count: Int {
        self.base.distance(from: self.startIndex, to: self.endIndex)
    }
}

extension AttributedString._InternalRuns {
    func index(atRunOffset runOffset: Int) -> Index {
        let r = _rope.find(at: runOffset, in: RunMetric(), preferEnd: false)
        assert(r.remaining == 0)
        let utf8Offset = _rope.offset(of: r.index, in: UTF8Metric())
        return Index(r.index, offset: runOffset, utf8Offset: utf8Offset)
    }

    func index(atUTF8Offset utf8Offset: Int, preferEnd: Bool = false) -> (index: Index, remaining: Int) {
        let r = _rope.find(at: utf8Offset, in: UTF8Metric(), preferEnd: preferEnd)
        let offset = _rope.offset(of: r.index, in: RunMetric())
        return (Index(r.index, offset: offset, utf8Offset: utf8Offset - r.remaining), r.remaining)
    }

    func _exactIndex(atUTF8Offset utf8Offset: Int) -> Index {
        let r = index(atUTF8Offset: utf8Offset)
        precondition(r.remaining == 0)
        return r.index
    }

    func index(containing i: AttributedString.Index) -> (index: Index, utf8Offset: Int) {
        let r = index(atUTF8Offset: i._value.utf8Offset)
        return (r.index, r.remaining)
    }
}

extension AttributedString._InternalRuns {
    var utf8Count: Int {
        _rope.count(in: UTF8Metric())
    }

    @_transparent
    mutating func _update<R>(
        at index: inout Index,
        by body: (inout Element) -> R
    ) -> R {
        _rope.update(at: &index.base, by: body)
    }

    @discardableResult
    mutating func _remove(at index: Index) -> _InternalRun {
        _rope.remove(at: index.base)
    }

    mutating func _removeRuns(_ runOffsets: Range<Int>) {
        _rope.removeSubrange(runOffsets, in: RunMetric())
    }

    // FIXME: Don't return a standalone rope.
    func extract(utf8Offsets: Range<Int>) -> Self {
        Self(_rope.extract(utf8Offsets, in: UTF8Metric()))
    }
}

extension AttributedString._InternalRuns {
    /// Update the run at `index` with the provided `run` and coalesce it with its
    /// neighbors if necessary. `index` is updated to a valid index addressing the
    /// run in the new collection that includes the UTF-8 range of the original run.
    mutating func updateAndCoalesce(
        at index: inout Index,
        with body: (inout _AttributeStorage) -> Void
    ) {
        var offset = index.offset
        var utf8Offset = index.utf8Offset
        var i = index.base
        let attributes = _rope.update(at: &i, by: {
            body(&$0.attributes)
            return $0.attributes
        })

        let next = _rope.index(after: i)
        if next < _rope.endIndex, _rope[next].attributes == attributes {
            // Coalesce with next run, preserving position.
            let utf8Length = _rope.remove(at: &i).length
            _rope.update(at: &i) { $0.length += utf8Length }
        }
        if i > _rope.startIndex {
            let prev = _rope.index(before: i)
            if _rope[prev].attributes == attributes {
                // Coalesce with previous run, preserving position.
                let utf8Length = _rope.remove(at: &i).length
                _rope.formIndex(before: &i)
                _rope.update(at: &i) {
                    utf8Offset -= $0.length
                    $0.length += utf8Length
                }
                offset -= 1
            }
        }
        index = Index(i, offset: offset, utf8Offset: utf8Offset)
    }

    /// Replaces the runs within specified UTF-8 offset range with the supplied collection, which
    /// must be properly coalesced. This method takes care of coalescing the edges if necessary.
    ///
    /// Note: This has no way to access string data, so it does not try to enforce run
    /// constraints on paragraph/character boundaries. (You can call
    /// `Guts.enforceAttributeConstraintsAfterMutation` to do that, after this call.)
    mutating func replaceUTF8Subrange(
        _ range: Range<Int>, with newElements: some Sequence<_InternalRun>
    ) {
        let origUTF8Length = _rope.summary.utf8Length
        _rope.replaceSubrange(range, in: UTF8Metric(), with: newElements)
        let newUTF8Length = _rope.summary.utf8Length
        let upperBound = range.upperBound + (newUTF8Length - origUTF8Length)
        if upperBound > 0, upperBound < newUTF8Length {
            var index = _exactIndex(atUTF8Offset: upperBound).base
            let attrs = _rope[index].attributes
            _rope.formIndex(before: &index)
            if _rope[index].attributes == attrs {
                // Coalesce with first item after replacement.
                let utf8Length = _rope.remove(at: &index).length
                _rope.update(at: &index) { $0.length += utf8Length }
            }
        }
        if range.lowerBound > 0, upperBound > range.lowerBound {
            var index = _exactIndex(atUTF8Offset: range.lowerBound).base
            let run = _rope[index]
            _rope.formIndex(before: &index)
            if _rope[index].attributes == run.attributes {
                // Coalesce with last item before replacement.
                _rope.update(at: &index) { $0.length += run.length }
                _rope.formIndex(after: &index)
                _rope.remove(at: index)
            }
        }
    }
}
