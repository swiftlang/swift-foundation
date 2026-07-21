//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

#if FOUNDATION_FRAMEWORK
// FOUNDATION_FRAMEWORK has a scheme per benchmark file, so only include one benchmark here.
let benchmarks: @Sendable () -> Void = {
    sortComparatorBenchmarks()
}
#endif

/// Number of elements sorted per benchmark iteration.
private let elementCount = 100_000

// MARK: - Fixtures

/// A representative record with a mix of field types, standing in for a typical
/// row a caller might sort. Field names are uniform; only the types matter for
/// exercising the different comparator code paths.
fileprivate struct Entry {
    let int0: Int
    let int1: Int
    let int2: Int
    let optionalInt: Int?
    let str0: String
    let str1: String
    let str2: String
    // Backing store for the computed property; `fileprivate` so the synthesized
    // memberwise initializer is reachable from the generator below.
    fileprivate let _computedProperty: Double?
    /// Computed property: exercises the key-path getter (no stored-field offset).
    var computedProperty: Double? { _computedProperty }
    let id: UUID
}

/// The same fields as `Entry`, but a `final class`, so the element is a
/// reference: sort reordering copies an 8-byte reference (one retain) instead of
/// the whole struct, and `MemoryLayout.offset(of:)` is `nil` for its fields.
fileprivate final class EntryObject: Sendable {
    let int0: Int
    let int1: Int
    let int2: Int
    let optionalInt: Int?
    let str0: String
    let str1: String
    let str2: String
    private let _computedProperty: Double?
    var computedProperty: Double? { _computedProperty }
    let id: UUID

    init(_ e: Entry) {
        int0 = e.int0
        int1 = e.int1
        int2 = e.int2
        optionalInt = e.optionalInt
        str0 = e.str0
        str1 = e.str1
        str2 = e.str2
        _computedProperty = e.computedProperty
        id = e.id
    }
}

/// A custom `SortComparator` backed by a user-supplied comparison closure, used
/// to benchmark sorting through an arbitrary caller-defined comparator.
fileprivate struct ClosureComparator<Compared>: SortComparator {
    let compareClosure: @Sendable (Compared, Compared) -> ComparisonResult
    var order: SortOrder

    init(order: SortOrder = .forward, _ compareClosure: @escaping @Sendable (Compared, Compared) -> ComparisonResult) {
        self.compareClosure = compareClosure
        self.order = order
    }

    func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult {
        let result = compareClosure(lhs, rhs)
        switch order {
        case .forward:
            return result
        case .reverse:
            switch result {
            case .orderedAscending: return .orderedDescending
            case .orderedDescending: return .orderedAscending
            case .orderedSame: return .orderedSame
            }
        }
    }

    // `SortComparator` refines `Hashable`; the closure is not itself hashable, so
    // identity is defined by `order` alone (sufficient for the benchmark).
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.order == rhs.order }
    func hash(into hasher: inout Hasher) { hasher.combine(order) }
}

/// Builds a `ClosureComparator` behind an opaque boundary so the comparison
/// closure is not inlined/specialized into the sort at the call site — modeling
/// a comparator obtained from elsewhere rather than constructed in place.
@inline(never)
fileprivate func makeClosureComparator<Compared>(
    _ compare: @escaping @Sendable (Compared, Compared) -> ComparisonResult
) -> ClosureComparator<Compared> {
    ClosureComparator(compare)
}

// MARK: - Comparison helpers

private func compareValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
    if lhs < rhs { return .orderedAscending }
    if lhs > rhs { return .orderedDescending }
    return .orderedSame
}

private func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
    switch (lhs, rhs) {
    case (nil, nil): return .orderedSame
    case (nil, _): return .orderedAscending   // nil orders first, matching OptionalComparator
    case (_, nil): return .orderedDescending
    case let (l?, r?): return compareValues(l, r)
    }
}

/// `<` for optionals with `nil` ordered first — the ordering `OptionalComparator`
/// produces in `forward` order. Used by the plain-closure floor benchmarks.
private func optionalLess<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): return false
    case (nil, _): return true
    case (_, nil): return false
    case let (l?, r?): return l < r
    }
}

// MARK: - Deterministic data generation

/// SplitMix64, so the generated collection is identical across runs.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

/// A string of deterministic-but-random length. The length straddles the 15-UTF-8
/// byte small-string boundary (4...27) so ~50% of the strings are stored inline
/// and ~50% require a heap allocation.
private func randomString(using rng: inout SeededGenerator) -> String {
    let length = Int(rng.next() % 24) + 4 // 4...27
    var s = ""
    s.reserveCapacity(length)
    for _ in 0..<length {
        s.append(alphabet[Int(rng.next() % UInt64(alphabet.count))])
    }
    return s
}

private func makeEntries(count: Int) -> [Entry] {
    var rng = SeededGenerator(seed: 0x1234_5678_9ABC_DEF0)
    // A small pool of repeated strings so string sorts see realistic ties, which
    // is what forces the secondary comparator to run in the multi-key benchmarks.
    let stringPool = (0..<64).map { _ in randomString(using: &rng) }
    var entries = [Entry]()
    entries.reserveCapacity(count)
    for _ in 0..<count {
        // ~10% of optional values are absent (nil), which the comparator orders first.
        let optionalInt: Int? = (rng.next() % 10 == 0) ? nil : Int(rng.next() % 1_000_000_000)
        let computed: Double? = (rng.next() % 10 == 0) ? nil : Double(rng.next() % 50) / 10.0
        entries.append(Entry(
            int0: Int(rng.next() % 100_000),           // many ties (primary multi-int key)
            int1: Int(rng.next() % 2_000_000_000),
            int2: Int(rng.next() % 1_000_000_000),     // mostly unique (single-int key)
            optionalInt: optionalInt,
            str0: randomString(using: &rng),
            str1: stringPool[Int(rng.next() % UInt64(stringPool.count))],
            str2: randomString(using: &rng),
            _computedProperty: computed,
            id: UUID.random(using: &rng)))
    }
    return entries
}

// MARK: - Benchmarks

private func benchmarkSort<Element: Sendable, Comparator: SortComparator>(
    _ name: String, _ data: [Element], _ comparator: Comparator
) where Comparator.Compared == Element {
    Benchmark(name) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(data.sorted(using: comparator))
        }
    }
}

private func benchmarkSort<Element: Sendable, Comparator: SortComparator>(
    _ name: String, _ data: [Element], _ comparators: [Comparator]
) where Comparator.Compared == Element {
    Benchmark(name) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(data.sorted(using: comparators))
        }
    }
}

/// Lower-bound ("floor") sort: the stdlib `sorted(by:)` with a plain closure,
/// bypassing SortComparator entirely. The closure is fully visible to the
/// optimizer, so the sort specializes for `Element` and the comparison inlines —
/// the fastest a comparison-based sort of this data can be. The gap between a
/// comparator benchmark and its matching floor is the comparator overhead.
///
/// `@inline(__always)` so the closure is inlined into the sort call site for the
/// best possible (truest lower-bound) performance.
@inline(__always)
private func benchmarkClosureSort<Element: Sendable>(
    _ name: String, _ data: [Element], by areInIncreasingOrder: @escaping (Element, Element) -> Bool
) {
    Benchmark(name) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(data.sorted(by: areInIncreasingOrder))
        }
    }
}

func sortComparatorBenchmarks() {
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.scalingFactor = .one
    Benchmark.defaultConfiguration.maxDuration = .seconds(5)
    Benchmark.defaultConfiguration.maxIterations = 1_000

    let entries = makeEntries(count: elementCount)
    let entryObjects = entries.map(EntryObject.init)

    // KeyPathComparator, value-type element (`Entry`).
    benchmarkSort("SortComparator/single-int", entries, KeyPathComparator(\.int2))
    benchmarkSort("SortComparator/two-int", entries, [KeyPathComparator(\.int0), KeyPathComparator(\.int1)])
    benchmarkSort("SortComparator/single-optional", entries, KeyPathComparator(\.optionalInt))
    benchmarkSort("SortComparator/single-string", entries, KeyPathComparator(\.str1))
    benchmarkSort("SortComparator/two-string", entries, [KeyPathComparator(\.str1), KeyPathComparator(\.str0)])
    benchmarkSort("SortComparator/single-computed", entries, KeyPathComparator(\.computedProperty))

    // KeyPathComparator, reference-type element (`EntryObject`).
    benchmarkSort("SortComparator/single-int-object", entryObjects, KeyPathComparator(\.int2))
    benchmarkSort("SortComparator/two-int-object", entryObjects, [KeyPathComparator(\.int0), KeyPathComparator(\.int1)])
    benchmarkSort("SortComparator/single-optional-object", entryObjects, KeyPathComparator(\.optionalInt))
    benchmarkSort("SortComparator/single-string-object", entryObjects, KeyPathComparator(\.str1))
    benchmarkSort("SortComparator/two-string-object", entryObjects, [KeyPathComparator(\.str1), KeyPathComparator(\.str0)])
    benchmarkSort("SortComparator/single-computed-object", entryObjects, KeyPathComparator(\.computedProperty))

    // ComparableComparator, used directly on a collection of `Comparable` elements.
    let ints = entries.map(\.int2)
    let strings = entries.map(\.str1)
    benchmarkSort("SortComparator/comparable-int", ints, ComparableComparator<Int>())
    benchmarkSort("SortComparator/comparable-string", strings, ComparableComparator<String>())

    // ClosureComparator (custom SortComparator), value-type element (`Entry`).
    benchmarkSort("SortComparator/closure-single-int", entries,
                  makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.int2, b.int2) })
    benchmarkSort("SortComparator/closure-two-int", entries, [
        makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.int0, b.int0) },
        makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.int1, b.int1) },
    ])
    benchmarkSort("SortComparator/closure-single-optional", entries,
                  makeClosureComparator { (a: Entry, b: Entry) in compareOptional(a.optionalInt, b.optionalInt) })
    benchmarkSort("SortComparator/closure-single-string", entries,
                  makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.str1, b.str1) })
    benchmarkSort("SortComparator/closure-two-string", entries, [
        makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.str1, b.str1) },
        makeClosureComparator { (a: Entry, b: Entry) in compareValues(a.str0, b.str0) },
    ])
    benchmarkSort("SortComparator/closure-single-computed", entries,
                  makeClosureComparator { (a: Entry, b: Entry) in compareOptional(a.computedProperty, b.computedProperty) })

    // ClosureComparator (custom SortComparator), reference-type element (`EntryObject`).
    benchmarkSort("SortComparator/closure-single-int-object", entryObjects,
                  makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.int2, b.int2) })
    benchmarkSort("SortComparator/closure-two-int-object", entryObjects, [
        makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.int0, b.int0) },
        makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.int1, b.int1) },
    ])
    benchmarkSort("SortComparator/closure-single-optional-object", entryObjects,
                  makeClosureComparator { (a: EntryObject, b: EntryObject) in compareOptional(a.optionalInt, b.optionalInt) })
    benchmarkSort("SortComparator/closure-single-string-object", entryObjects,
                  makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.str1, b.str1) })
    benchmarkSort("SortComparator/closure-two-string-object", entryObjects, [
        makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.str1, b.str1) },
        makeClosureComparator { (a: EntryObject, b: EntryObject) in compareValues(a.str0, b.str0) },
    ])
    benchmarkSort("SortComparator/closure-single-computed-object", entryObjects,
                  makeClosureComparator { (a: EntryObject, b: EntryObject) in compareOptional(a.computedProperty, b.computedProperty) })

    // Lower-bound floor: plain `sorted(by:)`, no SortComparator. Fastest possible
    // comparison-based sort of this data; the reference to measure overhead against.
    // Value-type element (`Entry`).
    benchmarkClosureSort("SortComparator/floor-single-int", entries) { $0.int2 < $1.int2 }
    benchmarkClosureSort("SortComparator/floor-two-int", entries) {
        $0.int0 != $1.int0 ? $0.int0 < $1.int0 : $0.int1 < $1.int1
    }
    benchmarkClosureSort("SortComparator/floor-single-optional", entries) { optionalLess($0.optionalInt, $1.optionalInt) }
    benchmarkClosureSort("SortComparator/floor-single-string", entries) { $0.str1 < $1.str1 }
    benchmarkClosureSort("SortComparator/floor-two-string", entries) {
        $0.str1 != $1.str1 ? $0.str1 < $1.str1 : $0.str0 < $1.str0
    }
    benchmarkClosureSort("SortComparator/floor-single-computed", entries) { optionalLess($0.computedProperty, $1.computedProperty) }

    // Lower-bound floor, reference-type element (`EntryObject`).
    benchmarkClosureSort("SortComparator/floor-single-int-object", entryObjects) { $0.int2 < $1.int2 }
    benchmarkClosureSort("SortComparator/floor-two-int-object", entryObjects) {
        $0.int0 != $1.int0 ? $0.int0 < $1.int0 : $0.int1 < $1.int1
    }
    benchmarkClosureSort("SortComparator/floor-single-optional-object", entryObjects) { optionalLess($0.optionalInt, $1.optionalInt) }
    benchmarkClosureSort("SortComparator/floor-single-string-object", entryObjects) { $0.str1 < $1.str1 }
    benchmarkClosureSort("SortComparator/floor-two-string-object", entryObjects) {
        $0.str1 != $1.str1 ? $0.str1 < $1.str1 : $0.str0 < $1.str0
    }
    benchmarkClosureSort("SortComparator/floor-single-computed-object", entryObjects) { optionalLess($0.computedProperty, $1.computedProperty) }
}
