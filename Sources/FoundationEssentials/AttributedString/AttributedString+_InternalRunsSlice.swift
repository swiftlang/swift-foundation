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
    /// A mutable rope of `_InternalRun` values, sliced on an arbitrary UTF-8 offset range.
    /// Boundary runs may be sliced into two parts; this collection transparently constructs
    /// virtual (sub-)runs representing the parts that are logically inside it.
    ///
    /// Mutating one of these virtual runs effectively splits the underlying run, creating new runs
    /// as needed. The usual run coalescing rules continue to apply, as if the underlying rope was
    /// not sliced at all -- e.g., run coalescing will merge runs across the slice boundary.
    struct _InternalRunsSlice {
        typealias _AttributeStorage = AttributedString._AttributeStorage
        typealias _InternalRun = AttributedString._InternalRun
        typealias _InternalRuns = AttributedString._InternalRuns
        typealias Storage = Rope<_InternalRun>

        /// The guts of the underlying attributed string.
        var _guts: Guts

        /// The UTF-8 offset range of this slice.
        ///
        /// We cannot (easily) store actual indices for the bounds -- mutations via `update`
        /// would invalidate them, and keeping them updated would be too much trouble.
        var _utf8Bounds: Range<Int>

        init(_ guts: Guts, utf8Bounds: Range<Int>) {
            assert(utf8Bounds.lowerBound >= 0 && utf8Bounds.upperBound <= guts.string.utf8.count)
            self._guts = guts
            self._utf8Bounds = utf8Bounds
        }
    }
}

extension AttributedString._InternalRunsSlice: BidirectionalCollection {
    // Note: This is a true bidirectional collection, only supporting step-by-step access.
    // (It would be possible to implement `index(_:offsetBy:)` in logarithmic time, but we have
    // no use case for it -- this type is really just used to enumerate/mutate runs one by one
    // within a certain range.

    typealias Element = _InternalRun

    /// Runs slices share index values with their base collection -- even for indices that address
    /// partial runs on the edges of the slice.
    typealias Index = _InternalRuns.Index

    var isEmpty: Bool {
        _utf8Bounds.isEmpty
    }

    var startIndex: Index {
        _guts.runs.index(atUTF8Offset: _utf8Bounds.lowerBound).index
    }

    /// For non-empty slices, we reuse the base collection's endIndex as the slice's end.
    /// This is O(1) and avoids having to find an index representing the actual end position,
    /// which would be annoying to do when the bounds slice the last run in two halves.
    ///
    /// For empty slices, we need to return the start index to avoid breaking Collection
    /// expectations.
    var endIndex: Index {
        isEmpty ? startIndex : _guts.runs.endIndex
    }

    subscript(index: Index) -> Element {
        let (attributes, fullRange) = _guts.run(at: index)
        let clampedRange = fullRange.clamped(to: _utf8Bounds)
        precondition(!clampedRange.isEmpty, "Index out of bounds")
        return _InternalRun(length: clampedRange.count, attributes: attributes)
    }

    func index(after i: Index) -> Index {
        // Note: this does not check that `i` is within the bounds of the slice.
        let j = _guts.runs.index(after: i)
        if j.utf8Offset >= _utf8Bounds.upperBound { return endIndex }
        return j
    }

    func index(before i: Index) -> Index {
        // Note: this does not check that `i` is within the bounds of the slice.
        if i == _guts.runs.endIndex {
            return _guts.runs.index(atUTF8Offset: _utf8Bounds.upperBound, preferEnd: true).index
        }
        return _guts.runs.index(before: i)
    }
}

extension AttributedString._InternalRunsSlice {
    func update(
        at index: inout _InternalRuns.Index,
        with body: (
            _ attributes: inout _AttributeStorage,
            _ utf8Range: Range<Int>,
            _ mutated: inout Bool
        ) -> Void
    ) {
        _guts.updateRun(at: &index, within: _utf8Bounds, with: body)
    }

    func updateEach(
        with body: (
            _ attributes: inout _AttributeStorage,
            _ utf8Range: Range<Int>,
            _ mutated: inout Bool
        ) -> Void
    ) {
        var i = self.startIndex
        while i < self.endIndex {
            self.update(at: &i, with: body)
            self.formIndex(after: &i)
        }
    }

    func updateEach(
        when predicate: (_AttributeStorage) -> Bool,
        with body: (
            _ attributes: inout _AttributeStorage,
            _ utf8Range: Range<Int>
        ) -> Void
    ) {
        var i = self.startIndex
        while i < self.endIndex {
            if predicate(self._guts.runs[i].attributes) {
                self.update(at: &i) { attributes, range, _ in body(&attributes, range) }
            }
            self.formIndex(after: &i)
        }
    }
}
