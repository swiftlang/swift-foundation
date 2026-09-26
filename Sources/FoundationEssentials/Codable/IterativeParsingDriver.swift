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

#if FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))


// MARK: - ParseEventVocabulary

/// The event alphabet a `ParseEventSource` emits and a `ParseEventSink` consumes. Format-specific: `JSONVocabulary`, `BPlistVocabulary`, `XMLPlistVocabulary` each pair their scalar enum with their key-view type. A `Source` and `Sink` are compatible when their `Vocabulary` associated types match.
protocol ParseEventVocabulary {
    associatedtype Scalar: ~Copyable, ~Escapable
    associatedtype KeyView: ~Copyable, ~Escapable
    associatedtype UnkeyedContainerKind = Void
    associatedtype KeyedContainerKind = Void
}

// MARK: - IterativeParsingDriver

/// Drives an iterative parse: routes events from a `ParseEventSource` to a `ParseEventSink`, owns the frame stack, and dispatches to a `ParseEventFilter`.
struct IterativeParsingDriver<Source: ParseEventSource & ~Copyable & ~Escapable, Sink: ParseEventSink & ~Copyable>: ~Copyable where Source.Filter: ~Copyable {
    var sink: Sink
    var keysArena: UniqueArray<Sink.Fragment>
    var valuesArena: UniqueArray<Sink.Fragment>
    var frames: UniqueArray<_Frame>
    /// Set by the driver before every source call; read by `beginUnkeyedContainer`/`beginKeyedContainer` to stamp the pushed child frame's `filterLevel`. `nil` = no filter at this frame.
    var pendingChildFilterLevel: Int?

    /// Driver-internal frame descriptor. Generic over the source's per-container state.
    internal struct _Frame {
        var isKeyed: Bool
        var keyStart: Int
        var valueStart: Int
        var hasPendingKey: Bool
        // `nil` past the filter's max depth, or when no filter is active.
        var filterLevel: Int?
        // Stable reference identity for this container, or nil if the source doesn't participate in dedup.
        var cacheKey: Int?
        // Source-specific state.
        var sourceState: Source.Frame
        /// Number of children the source has emitted into this container. Consulted by the per-call `FilterView`; bumped by `Filter.recordMatch` after each accepted event.
        var matchedCount: Int = 0
    }

    init(sink: consuming Sink) {
        self.sink = sink
        self.keysArena = UniqueArray()
        self.valuesArena = UniqueArray()
        self.frames = UniqueArray()
    }

    mutating func releaseArenaContents() {
        for i in 0..<keysArena.count { sink.releaseFragment(keysArena[i]) }
        for i in 0..<valuesArena.count { sink.releaseFragment(valuesArena[i]) }
        if keysArena.count > 0 { keysArena.removeSubrange(0..<keysArena.count) }
        if valuesArena.count > 0 { valuesArena.removeSubrange(0..<valuesArena.count) }
    }
}

extension IterativeParsingDriver where Source: ~Copyable & ~Escapable, Sink: ~Copyable, Source.Vocabulary == Sink.Vocabulary, Source.Filter: ~Copyable {

    consuming func runReturningSink<Filter: ParseEventFilter & ~Copyable>(source: consuming Source, filter: consuming Filter) throws -> Sink where Source.Filter == Filter {
        do {
            pendingChildFilterLevel = filter.rootLevel
            try source.emitTopLevelValue(into: &self)
            while !isStackEmpty {
                try advanceOrFinalizeTopFrame(source: &source, filter: filter)
            }
            try source.finish()
            try deliverTopLevelFragment()
        } catch {
            releaseArenaContents()
            throw error
        }
        assertRunCompleted()
        return sink
    }

    /// One step of the outer loop: ask the source to emit the next child of the top frame (respecting `filter`); if the source declines, close the frame.
    private mutating func advanceOrFinalizeTopFrame<Filter: ParseEventFilter & ~Copyable>(source: inout Source, filter: borrowing Filter) throws where Source.Filter == Filter {
        let topIdx = frames.count &- 1
        let atLevel = frames[topIdx].filterLevel
        let matched = frames[topIdx].matchedCount
        let isKeyed = frames[topIdx].isKeyed
        pendingChildFilterLevel = filter.nextLevel(after: atLevel)
        let emitted = try filter.withFilterView(atLevel: atLevel, matchedCount: matched, isKeyed: isKeyed) { view in
            try source.advanceTopFrame(into: &self, filter: view)
        }
        if emitted {
            // Guard against a source popping its own frame during accept (e.g. an empty-container emit that never pushed).
            if topIdx < frames.count {
                filter.recordMatch(into: &frames[topIdx].matchedCount)
            }
        } else {
            try source.finalizeTopFrame(into: &self)
        }
    }

    /// Hand the sink the one fragment (if any) the root event pushed into `valuesArena`. Void-fragment sinks that never appended see no callback; tree sinks get their root here.
    private mutating func deliverTopLevelFragment() throws {
        guard valuesArena.count > 0 else { return }
        precondition(valuesArena.count == 1, "runParser: top-level values arena has \(valuesArena.count) entries; expected 0 or 1")
        let fragment = valuesArena.popLast()!
        try sink.acceptTopLevel(fragment)
    }

    /// End-of-run invariants: no open frames and both arenas drained.
    private func assertRunCompleted() {
        precondition(frames.isEmpty, "runParser: source finished with \(frames.count) open frames")
        precondition(keysArena.count == 0, "runParser: keys arena leftover")
        precondition(valuesArena.count == 0, "runParser: values arena leftover")
    }

    consuming func run<Filter: ParseEventFilter & ~Copyable>(source: consuming Source, filter: consuming Filter) throws -> Sink.Output where Source.Filter == Filter {
        return try runReturningSink(source: source, filter: filter).takeResult()
    }
}

extension IterativeParsingDriver where Source: ~Copyable & ~Escapable, Sink: ~Copyable, Source.Vocabulary == Sink.Vocabulary, Source.Filter == NullFilter {
    consuming func runReturningSink(source: consuming Source) throws -> Sink {
        try self.runReturningSink(source: source, filter: NullFilter())
    }

    consuming func run(source: consuming Source) throws -> Sink.Output {
        try self.run(source: source, filter: NullFilter())
    }
}

extension IterativeParsingDriver where Source: ~Copyable & ~Escapable, Sink: ~Copyable, Source.Filter: ~Copyable {
    typealias Scalar = Sink.Vocabulary.Scalar
    typealias KeyView = Sink.Vocabulary.KeyView

    // MARK: Container open / close

    mutating func beginUnkeyedContainer(cacheKey: Int?, sourceState: Source.Frame) throws {
        let level = pendingChildFilterLevel
        try sink.beginUnkeyedContainer(cacheKey: cacheKey)
        frames.append(_Frame(isKeyed: false, keyStart: keysArena.count, valueStart: valuesArena.count, hasPendingKey: false, filterLevel: level, cacheKey: cacheKey, sourceState: sourceState))
    }

    mutating func endUnkeyedContainer(kind: Sink.Vocabulary.UnkeyedContainerKind) throws {
        precondition(!frames.isEmpty, "endUnkeyedContainer: frame stack empty")
        let topIdx = frames.count &- 1
        let isKeyed = frames[topIdx].isKeyed
        let valueStart = frames[topIdx].valueStart
        let cacheKey = frames[topIdx].cacheKey
        precondition(!isKeyed, "endUnkeyedContainer: top frame is keyed")
        frames.removeLast()
        try finalizeUnkeyedContainerFields(valueStart: valueStart, cacheKey: cacheKey, kind: kind)
    }

    mutating func beginKeyedContainer(cacheKey: Int?, sourceState: Source.Frame) throws {
        let level = pendingChildFilterLevel
        try sink.beginKeyedContainer(cacheKey: cacheKey)
        frames.append(_Frame(isKeyed: true, keyStart: keysArena.count, valueStart: valuesArena.count, hasPendingKey: false, filterLevel: level, cacheKey: cacheKey, sourceState: sourceState))
    }

    mutating func endKeyedContainer(kind: Sink.Vocabulary.KeyedContainerKind) throws {
        precondition(!frames.isEmpty, "endKeyedContainer: frame stack empty")
        let topIdx = frames.count &- 1
        let isKeyed = frames[topIdx].isKeyed
        let hasPendingKey = frames[topIdx].hasPendingKey
        let keyStart = frames[topIdx].keyStart
        let valueStart = frames[topIdx].valueStart
        let cacheKey = frames[topIdx].cacheKey
        precondition(isKeyed, "endKeyedContainer: top frame is unkeyed")
        precondition(!hasPendingKey, "endKeyedContainer: unpaired key")
        frames.removeLast()
        try finalizeKeyedContainerFields(keyStart: keyStart, valueStart: valueStart, cacheKey: cacheKey, kind: kind)
    }

    // MARK: Leaf / key events

    mutating func parkKey(_ key: borrowing KeyView) throws {
        precondition(!frames.isEmpty, "parkKey: no open dict")
        let topIdx = frames.count &- 1
        precondition(frames[topIdx].isKeyed, "parkKey: top frame is an array")
        precondition(!frames[topIdx].hasPendingKey, "parkKey: previous key not paired")

        var acc = ParseEventAccumulator<Sink.Fragment>(storage: MutableRef(&keysArena))
        try sink.acceptKey(key, into: &acc)

        frames[topIdx].hasPendingKey = true
    }

    mutating func emitScalar(_ scalar: borrowing Scalar, cacheKey: Int? = nil) throws {
        var acc = ParseEventAccumulator<Sink.Fragment>(storage: MutableRef(&valuesArena))
        try sink.acceptScalar(scalar, cacheKey: cacheKey, into: &acc)
        markPendingKeyConsumed()
    }

    mutating func emitNull(cacheKey: Int? = nil) throws {
        var acc = ParseEventAccumulator<Sink.Fragment>(storage: MutableRef(&valuesArena))
        try sink.acceptNull(cacheKey: cacheKey, into: &acc)
        markPendingKeyConsumed()
    }

    mutating func tryEmitCachedForKey(_ key: Int) throws -> Bool {
        // Roots are never dedup targets; sink cache is empty at parse start.
        if frames.isEmpty { return false }
        var acc = ParseEventAccumulator<Sink.Fragment>(storage: MutableRef(&valuesArena))
        let hit = try sink.tryEmitCachedForKey(key, into: &acc)
        if hit {
            markPendingKeyConsumed()
        }
        return hit
    }

    // MARK: Frame stack queries

    var stackDepth: Int { frames.count }
    
    var isStackEmpty: Bool { frames.isEmpty }
    
    var isTopKeyed: Bool {
        precondition(!frames.isEmpty, "isTopKeyed: stack empty")
        return frames[frames.count &- 1].isKeyed
    }

    var topSourceState: Source.Frame {
        get {
            precondition(!frames.isEmpty, "topSourceState: stack empty")
            return frames[frames.count &- 1].sourceState
        }
        set {
            precondition(!frames.isEmpty, "topSourceState: stack empty")
            frames[frames.count &- 1].sourceState = newValue
        }
    }

    // MARK: Private helpers

    @inline(__always)
    private mutating func markPendingKeyConsumed() {
        if frames.isEmpty { return }
        let topIdx = frames.count &- 1
        if frames[topIdx].isKeyed {
            precondition(frames[topIdx].hasPendingKey, "value emitted into dict frame with no pending key")
            frames[topIdx].hasPendingKey = false
        }
    }

    private mutating func finalizeUnkeyedContainerFields(valueStart: Int, cacheKey: Int?, kind: Sink.Vocabulary.UnkeyedContainerKind) throws {
        let count = valuesArena.count &- valueStart
        let fragment: Sink.Fragment
        if count == 0 {
            // Zero-count Span needs a valid non-nil base pointer; the stub is never read.
            fragment = try withUnsafeTemporaryAllocation(of: Sink.Fragment.self, capacity: 1) { stub -> Sink.Fragment in
                let span = unsafe Span<Sink.Fragment>(_unsafeStart: stub.baseAddress!, count: 0)
                return try sink.finalizeUnkeyedContainer(values: span, cacheKey: cacheKey, kind: kind)
            }
        } else {
            fragment = try valuesArena.span.withUnsafeBufferPointer { buf -> Sink.Fragment in
                let base = unsafe buf.baseAddress!.advanced(by: valueStart)
                let span = unsafe Span<Sink.Fragment>(_unsafeStart: base, count: count)
                return try sink.finalizeUnkeyedContainer(values: span, cacheKey: cacheKey, kind: kind)
            }
        }
        valuesArena.removeSubrange(valueStart..<valuesArena.count)
        try placeFinalizedContainerFragment(fragment)
    }

    private mutating func finalizeKeyedContainerFields(keyStart: Int, valueStart: Int, cacheKey: Int?, kind: Sink.Vocabulary.KeyedContainerKind) throws {
        let keyCount = keysArena.count &- keyStart
        let valueCount = valuesArena.count &- valueStart
        let fragment: Sink.Fragment
        if keyCount == 0 && valueCount == 0 {
            fragment = try withUnsafeTemporaryAllocation(of: Sink.Fragment.self, capacity: 1) { stub -> Sink.Fragment in
                let empty = unsafe Span<Sink.Fragment>(_unsafeStart: stub.baseAddress!, count: 0)
                return try sink.finalizeKeyedContainer(keys: empty, values: empty, cacheKey: cacheKey, kind: kind)
            }
        } else {
            fragment = try keysArena.span.withUnsafeBufferPointer { kBuf -> Sink.Fragment in
                let kBase = unsafe kBuf.baseAddress!.advanced(by: keyStart)
                let kSpan = unsafe Span<Sink.Fragment>(_unsafeStart: kBase, count: keyCount)
                return try valuesArena.span.withUnsafeBufferPointer { vBuf -> Sink.Fragment in
                    let vBase = unsafe vBuf.baseAddress!.advanced(by: valueStart)
                    let vSpan = unsafe Span<Sink.Fragment>(_unsafeStart: vBase, count: valueCount)
                    return try sink.finalizeKeyedContainer(keys: kSpan, values: vSpan, cacheKey: cacheKey, kind: kind)
                }
            }
        }
        keysArena.removeSubrange(keyStart..<keysArena.count)
        valuesArena.removeSubrange(valueStart..<valuesArena.count)
        try placeFinalizedContainerFragment(fragment)
    }

    /// Route a just-finalized container fragment to the current frame's values arena. The root container's fragment lands in `valuesArena` and is delivered to `sink.acceptTopLevel` after the run loop returns.
    private mutating func placeFinalizedContainerFragment(_ fragment: consuming Sink.Fragment) throws {
        var acc = ParseEventAccumulator<Sink.Fragment>(storage: MutableRef(&valuesArena))
        try sink.acceptContainer(fragment, into: &acc)
        markPendingKeyConsumed()
    }
}

extension IterativeParsingDriver where Sink: ~Copyable, Source.Frame == Void {
    /// Convenience for sources with no per-frame state.
    mutating func beginUnkeyedContainer(cacheKey: Int?) throws { try beginUnkeyedContainer(cacheKey: cacheKey, sourceState: ()) }
    mutating func beginKeyedContainer(cacheKey: Int?) throws { try beginKeyedContainer(cacheKey: cacheKey, sourceState: ()) }}

extension IterativeParsingDriver where Source: ~Copyable & ~Escapable, Sink: ~Copyable, Source.Filter: ~Copyable, Sink.Vocabulary.UnkeyedContainerKind == Void {
    mutating func endUnkeyedContainer() throws { try endUnkeyedContainer(kind: ()) }

    mutating func emitEmptyUnkeyedContainer() throws {
        try sink.beginUnkeyedContainer(cacheKey: nil)
        try finalizeUnkeyedContainerFields(valueStart: valuesArena.count, cacheKey: nil, kind: ())
    }
}

extension IterativeParsingDriver where Source: ~Copyable & ~Escapable, Sink: ~Copyable, Source.Filter: ~Copyable, Sink.Vocabulary.KeyedContainerKind == Void {
    mutating func endKeyedContainer() throws { try endKeyedContainer(kind: ()) }

    mutating func emitEmptyKeyedContainer() throws {
        try sink.beginKeyedContainer(cacheKey: nil)
        try finalizeKeyedContainerFields(keyStart: keysArena.count, valueStart: valuesArena.count, cacheKey: nil, kind: ())
    }
}

// MARK: - ParseEventSource

/// Emits parse events into an `IterativeParsingDriver`. Every source is a tree walker: emits one top-level value, then advances frame-by-frame until the tree is exhausted.
protocol ParseEventSource<Filter>: ~Copyable, ~Escapable {
    associatedtype Filter: ParseEventFilter & ~Copyable = NullFilter
    associatedtype Vocabulary: ParseEventVocabulary
    /// Per-container state the source maintains for its walk. The driver stores it; the source reads/mutates via `channel.topSourceState`. Default `Void`.
    associatedtype Frame = Void

    /// Emit the single top-level value. If it's a leaf, call `emitScalar` / `emitNull` and return. If a container, call `beginUnkeyedContainer` / `beginKeyedContainer` (pushing a frame that `advanceTopFrame` will walk).
    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == Self.Vocabulary

    /// Advance the top open container by one child. The driver passes a per-container `FilterView` scoped to the current top frame's filter level + matched count. The source switches on `filter.state`:
    ///
    ///   * `.matchesAll`: no filtering; emit the next child in source order.
    ///   * `.satisfied`: the filter has all it wants from this container; skip to end and return false.
    ///   * `.unsatisfied`: dicts ask `filter.matchesKey(...)` before emitting each pair; arrays use `filter.nextArrayIndex()` for random access (or a linear walk).
    ///
    /// Returns true when a child was emitted (driver bumps top frame's `matchedCount`); false when the container is exhausted or the filter is satisfied (driver calls `finalizeTopFrame`).
    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing Filter.View) throws -> Bool where Sink.Vocabulary == Self.Vocabulary

    /// Close the top frame; calls `endUnkeyedContainer` / `endKeyedContainer` and does any source-specific cleanup.
    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == Self.Vocabulary

    /// Called after every frame has been popped. Byte scanners check for junk after the root value here; sources without a post-parse hook get a no-op default.
    mutating func finish() throws
}

extension ParseEventSource where Self: ~Copyable & ~Escapable, Filter: ~Copyable {
    mutating func finish() throws {}
}

// MARK: - ParseEventSink

/// Materializes parse output. The driver owns two shared fragment arenas (keys and values) plus a frame stack; the sink is handed append-only accumulators over those arenas and read-only spans at finalize time.
///
/// `Fragment` is the sink's per-child accumulator element type, if any.
protocol ParseEventSink: ~Copyable {
    associatedtype Vocabulary: ParseEventVocabulary
    associatedtype Fragment
    associatedtype Output: ~Copyable

    // Leaf events. Sink decides whether to compute and append.
    mutating func acceptScalar(_ scalar: borrowing Vocabulary.Scalar, cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Fragment>) throws
    mutating func acceptKey(_ keyView: borrowing Vocabulary.KeyView, into accumulator: inout ParseEventAccumulator<Fragment>) throws
    mutating func acceptNull(cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Fragment>) throws
    /// Container fragment built by `finalizeUnkeyedContainer`/`finalizeKeyedContainer`; sink decides whether to append to the parent's accumulator.
    mutating func acceptContainer(_ fragment: consuming Fragment, into accumulator: inout ParseEventAccumulator<Fragment>) throws

    /// Container open hint. Fired before the driver pushes its frame. Map-builders back-patching `[marker, nextSibling, count]` use this to reserve the header slot. Default no-op.
    mutating func beginUnkeyedContainer(cacheKey: Int?) throws
    mutating func beginKeyedContainer(cacheKey: Int?) throws

    /// Container assembly. Driver hands the sink read-only spans of the accumulated fragments; sink materializes and returns the fragment representing the finalized container. Return-value shape avoids overlapping-access hazards.
    ///
    /// `cacheKey`: stable identity if the source provided one at begin time. Sinks that dedup cache the produced fragment for later `tryEmitCachedForKey`.
    mutating func finalizeUnkeyedContainer(values: borrowing Span<Fragment>, cacheKey: Int?) throws -> Fragment
    mutating func finalizeKeyedContainer(keys: borrowing Span<Fragment>, values: borrowing Span<Fragment>, cacheKey: Int?) throws -> Fragment
    mutating func finalizeUnkeyedContainer(values: borrowing Span<Fragment>, cacheKey: Int?, kind: Vocabulary.UnkeyedContainerKind) throws -> Fragment
    mutating func finalizeKeyedContainer(keys: borrowing Span<Fragment>, values: borrowing Span<Fragment>, cacheKey: Int?, kind: Vocabulary.KeyedContainerKind) throws -> Fragment

    /// Called exactly once after the source finishes with the root value's fragment.
    mutating func acceptTopLevel(_ fragment: consuming Fragment) throws

    consuming func takeResult() throws -> Output

    /// Release any resources associated with `fragment`. Called on abnormal exit for fragments still live in the driver's arenas.
    func releaseFragment(_ fragment: consuming Fragment)

    /// Optional dedup lookup. Sink returns true iff it recognized `key` and emitted the cached value into `accumulator`. Default returns false (opt out).
    mutating func tryEmitCachedForKey(_ key: Int, into accumulator: inout ParseEventAccumulator<Fragment>) throws -> Bool
}

extension ParseEventSink where Self: ~Copyable {
    mutating func tryEmitCachedForKey(_ key: Int, into accumulator: inout ParseEventAccumulator<Fragment>) throws -> Bool { false }
    mutating func beginUnkeyedContainer(cacheKey: Int?) throws {}
    mutating func beginKeyedContainer(cacheKey: Int?) throws {}
    mutating func finalizeUnkeyedContainer(values: borrowing Span<Fragment>, cacheKey: Int?, kind: Vocabulary.UnkeyedContainerKind) throws -> Fragment {
        try finalizeUnkeyedContainer(values: values, cacheKey: cacheKey)
    }
    mutating func finalizeKeyedContainer(keys: borrowing Span<Fragment>, values: borrowing Span<Fragment>, cacheKey: Int?, kind: Vocabulary.KeyedContainerKind) throws -> Fragment {
        try finalizeKeyedContainer(keys: keys, values: values, cacheKey: cacheKey)
    }
}

extension ParseEventSink where Self: ~Copyable, Fragment == Void {
    /// Void-fragment sinks (map builders, NullSink) already have their output as a side effect of the events; the root callback is a no-op.
    mutating func acceptTopLevel(_ fragment: consuming Void) throws {}
}

// MARK: - ParseEventAccumulator

/// Append-only handle over one of the driver's fragment arenas. Handed to the sink during a leaf/key/finalize call so it can push (or not) without seeing the underlying storage.
struct ParseEventAccumulator<Fragment>: ~Copyable, ~Escapable {
    var storage: MutableRef<UniqueArray<Fragment>>

    @_lifetime(copy storage)
    init(storage: consuming MutableRef<UniqueArray<Fragment>>) {
        self.storage = storage
    }

    mutating func append(_ fragment: consuming Fragment) {
        storage.value.append(fragment)
    }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
