//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


// MARK: - ParseEventFilter protocol

/// A filter that restricts the events emitted by a `ParseEventSource`.
/// This filter design mimicks the filtering capability provided by CFPropertyList, where key paths are combined into requested keys or indexes at each collection depth level.
/// The `IterativeParsingDriver` will hand a `FilterView` for the appropriate depth level to the source whenever it is decoding a container's contents. The source is obligated to refer to the `FilterView` to discover what events it is allowed to emit from its source data.
protocol ParseEventFilter: ~Copyable {
    associatedtype View: FilterView & ~Copyable & ~Escapable

    /// The root filter level (typically 0), or `nil` when nothing is filtered at any depth.
    var rootLevel: Int? { get }

    /// The next-level index for a child of a frame at `parentLevel`, or `nil` if past filter depth.
    borrowing func nextLevel(after parentLevel: Int?) -> Int?

    /// Hand the source a scoped view of the filter at `level`, bound to `matchedCount` and the container kind (`isKeyed`). If `level == nil`, then the filter view must report a state of `.matchesAll`.
    borrowing func withFilterView<R: ~Copyable, E>(atLevel level: Int?, matchedCount: Int, isKeyed: Bool, _ body: (borrowing View) throws(E) -> R) throws(E) -> R

    /// Called by the driver after `advanceTopFrame` returns true, to bump the top frame's match count. Default increments; `NullFilter` overrides to a no-op so specialization elides the write.
    borrowing func recordMatch(into count: inout Int)
}

extension ParseEventFilter where Self: ~Copyable {
    @inline(__always)
    borrowing func recordMatch(into count: inout Int) {
        count &+= 1
    }
}

// MARK: - FilterKeyEncoding

enum FilterKeyEncoding {
    // Currently limited to just the encodings that we care about during our deserialization implementations.
    case ascii
    case utf8
    case utf16BE
}

// MARK: - FilterState

/// What the source should do next in the container currently at the top.
enum FilterState {
    /// Every key/index at this level matches. Process the next child in source order.
    case matchesAll
    /// Every accepted key/index has been emitted for this container. Advance to the end of the collection, if necessary.
    case satisfied
    /// Active, unsatisfied filter. Source must consult `matchesKey` (dicts) or `nextArrayIndex` (arrays) to process the next result, or until it reaches the end of the container.
    case unsatisfied
}

// MARK: - FilterView protocol

/// `ParseEventSource` types interact with this filter to identify the next value that should be processed.
protocol FilterView: ~Copyable, ~Escapable {
    /// Read the source loop's dispatch discriminator. Sources switch on this before doing anything else.
    var state: FilterState { get }

    /// Only meaningful when `state == .unsatisfied` for dictionary containers.
    /// Returns true when the source should emit the value paired with these key bytes; false means skip the key and its associated value.
    borrowing func matchesKey(_ bytes: borrowing Span<UInt8>, encoding: FilterKeyEncoding) -> Bool

    /// Only meaningful when `state == .unsatisfied` for array containers.
    /// Returns the next array index the filter wants. The source should seek to and process the value for that index.
    borrowing func nextArrayIndex() -> Int
}

// MARK: - NullFilter

// A non-filtering filter.
struct NullFilterView: FilterView, ~Copyable, ~Escapable {
    @inline(__always) var state: FilterState { .matchesAll }
    @inline(__always) borrowing func matchesKey(_ bytes: borrowing Span<UInt8>, encoding: FilterKeyEncoding) -> Bool { true }
    @inline(__always) borrowing func nextArrayIndex() -> Int { -1 }
}

struct NullFilter: ParseEventFilter, ~Copyable {
    typealias View = NullFilterView
    @inline(__always) var rootLevel: Int? { nil }
    @inline(__always) borrowing func nextLevel(after parentLevel: Int?) -> Int? { nil }

    @inline(__always)
    borrowing func withFilterView<R: ~Copyable, E>(atLevel level: Int?, matchedCount: Int, isKeyed: Bool, _ body: (borrowing NullFilterView) throws(E) -> R) throws(E) -> R {
        let view = NullFilterView()
        return try body(view)
    }

    @inline(__always)
    borrowing func recordMatch(into count: inout Int) {
        // no-op
    }
}

// MARK: - MapRecordStorage

/// Random-access integer storage for a structural parse map's record buffer. Allows generalization over `[Int]` and `UniqueArray<Int>` storage.
protocol MapRecordStorage: ~Copyable {
    subscript(position: Int) -> Int { get }
}

#if FOUNDATION_FRAMEWORK || !os(macOS)
@available(anyAppleOS 27.0, *)
struct UniqueMapRecords: MapRecordStorage, ~Copyable {
    var storage: UniqueArray<Int>

    init(_ storage: consuming UniqueArray<Int>) {
        self.storage = storage
    }

    @inline(__always)
    subscript(position: Int) -> Int { storage[position] }
}
#endif // FOUNDATION_FRAMEWORK || !os(macOS)

struct ArrayMapRecords: MapRecordStorage {
    var storage: [Int]

    init(_ storage: consuming [Int]) {
        self.storage = storage
    }

    @inline(__always)
    subscript(position: Int) -> Int { storage[position] }
}
