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

#if FOUNDATION_FRAMEWORK || !os(macOS)


// MARK: - Frame

/// Per-container source state stored on the driver's frame stack. The driver's `isKeyed` distinguishes keyed containers from unkeyed ones; among unkeyed frames, `kind` records array vs. set. Bplist-specific fields (ref cursor, object index, in-flight bookkeeping) live here.
internal struct BPlistSourceFrame {
    let objectIndex: ValidatedBPlistObjectIndex
    let elementRefsStartOffset: Int
    let refSize: Int
    /// For arrays/sets: total children. For dicts: pair count.
    let sourceElementCount: Int
    /// Unkeyed frames only: which container type the source is walking.
    let kind: BPlistUnkeyedContainerKind
    /// Cursor into the ref block:
    /// * arrays/sets: source-side position for the matchesAll walk. In the filtered-array case `filter.nextArrayIndex()` is authoritative and this cursor is unused.
    /// * dicts: advances by 1 per pair inspected (including filter-rejected pairs). Values live at `keySlot + sourceElementCount`.
    var nextRefIdx: Int = 0
}

// MARK: - BPlistPrimitiveSource

/// Event source the encapsulates and walks through the contents of a `BPlistPrimitive`, emitting events in depth-first-search order.
struct BPlistPrimitiveSource<Filter: ParseEventFilter & ~Copyable>: ParseEventSource<Filter>, ~Copyable, ~Escapable {
    typealias Vocabulary = BPlistVocabulary
    typealias Frame = BPlistSourceFrame

    let topPrimitive: BPlistPrimitive
    /// Cycle-detection set.
    var inFlight: Set<Int>

    @_lifetime(copy top)
    init(top: BPlistPrimitive) {
        self.topPrimitive = top
        self.inFlight = Set()
    }

    // MARK: ParseEventSource

    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        try beginObject(prim: topPrimitive, into: &channel)
    }

    // MARK: Begin object

    private mutating func beginObject<Sink: ParseEventSink & ~Copyable>(prim: borrowing BPlistPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        
        // Cycle detection: if this object is already on the frame stack, the graph is malformed. Container refs never legitimately form a cycle.
        let idx = prim.objectIndex.val
        if inFlight.contains(idx) {
            throw BPlistError.corruptTopLevelInfo
        }
        
        // Dedup: ask the sink whether it's already cached this key. On hit the sink emits into the value accumulator; source skips the whole subtree.
        if try channel.tryEmitCachedForKey(idx) {
            return
        }

        switch prim.type {
        case .null:
            try channel.emitNull(cacheKey: idx)
        case .true:
            try channel.emitScalar(BPlistScalar.bool(true), cacheKey: idx)
        case .false:
            try channel.emitScalar(BPlistScalar.bool(false), cacheKey: idx)
        case .int:
            try emitIntScalar(prim, cacheKey: idx, into: &channel)
        case .real:
            let d = try decodeReal(prim)
            try channel.emitScalar(BPlistScalar.real(d), cacheKey: idx)
        case .date:
            let d = try prim.dateValue
            try channel.emitScalar(BPlistScalar.date(d), cacheKey: idx)
        case .uid:
            let u = try prim.uidValue
            try channel.emitScalar(BPlistScalar.uid(u), cacheKey: idx)
        case .data:
            try emitDataScalar(prim, cacheKey: idx, into: &channel)
        case .asciiString:
            try emitAsciiStringScalar(prim, cacheKey: idx, into: &channel)
        case .utf16String:
            try emitUTF16StringScalar(prim, cacheKey: idx, into: &channel)
        case .array:
            try pushArrayLikeFrame(prim: prim, kind: .array, into: &channel)
        case .set:
            try pushArrayLikeFrame(prim: prim, kind: .set, into: &channel)
        case .dict:
            try pushDictFrame(prim: prim, into: &channel)
        case .none:
            throw BPlistError.invalidMarker
        }
    }

    // MARK: Leaf emit + memoize

    private mutating func emitIntScalar<Sink: ParseEventSink & ~Copyable>(_ prim: borrowing BPlistPrimitive, cacheKey: Int, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let enc = try prim.encodedInteger
        if enc.isUnsigned {
            let u: UInt64 = try enc.intValue(UInt64.self)
            try channel.emitScalar(BPlistScalar.uint(u), cacheKey: cacheKey)
        } else {
            let n: Int64 = try enc.intValue(Int64.self)
            try channel.emitScalar(BPlistScalar.int(n), cacheKey: cacheKey)
        }
    }

    private func decodeReal(_ prim: borrowing BPlistPrimitive) throws -> Double {
        let span = try prim.realSpan
        switch span.byteCount {
        case 4:
            let bits = UInt32(bigEndian: span.unsafeLoadUnaligned(as: UInt32.self))
            return Double(Float(bitPattern: bits))
        case 8:
            let bits = UInt64(bigEndian: span.unsafeLoadUnaligned(as: UInt64.self))
            return Double(bitPattern: bits)
        default:
            throw BPlistError.corruptedValue("real")
        }
    }

    private mutating func emitDataScalar<Sink: ParseEventSink & ~Copyable>(_ prim: borrowing BPlistPrimitive, cacheKey: Int, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let span = try prim.dataSpan
        try channel.emitScalar(BPlistScalar.data(span), cacheKey: cacheKey)
    }

    private mutating func emitAsciiStringScalar<Sink: ParseEventSink & ~Copyable>(_ prim: borrowing BPlistPrimitive, cacheKey: Int, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let span = try prim.asciiStringSpan
        try channel.emitScalar(BPlistScalar.asciiString(bytes: span, objectOffset: prim.objectOffset), cacheKey: cacheKey)
    }

    private mutating func emitUTF16StringScalar<Sink: ParseEventSink & ~Copyable>(_ prim: borrowing BPlistPrimitive, cacheKey: Int, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let enc = try prim.encodedString
        let bytes = Span<UInt8>(viewing: enc.span)
        try channel.emitScalar(BPlistScalar.utf16String(bytes: bytes, objectOffset: prim.objectOffset), cacheKey: cacheKey)
    }

    // MARK: Container push

    private mutating func pushArrayLikeFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing BPlistPrimitive, kind: BPlistUnkeyedContainerKind, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let refsRange = try prim.arraySetRange
        let refSize = prim.metadata.objectRefSize
        let sourceCount = refsRange.count / refSize
        inFlight.insert(prim.objectIndex.val)
        try channel.beginUnkeyedContainer(cacheKey: prim.objectIndex.val, sourceState: BPlistSourceFrame(objectIndex: prim.objectIndex, elementRefsStartOffset: refsRange.lowerBound, refSize: refSize, sourceElementCount: sourceCount, kind: kind))
    }

    private mutating func pushDictFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing BPlistPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let refsRange = try prim.dictionarySpanRange
        let refSize = prim.metadata.objectRefSize
        let refCount = refsRange.count / refSize
        let pairCount = refCount &>> 1
        inFlight.insert(prim.objectIndex.val)
        try channel.beginKeyedContainer(cacheKey: prim.objectIndex.val, sourceState: BPlistSourceFrame(objectIndex: prim.objectIndex, elementRefsStartOffset: refsRange.lowerBound, refSize: refSize, sourceElementCount: pairCount, kind: .array))
    }

    // MARK: Advance

    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == BPlistVocabulary {
        switch filter.state {
        case .satisfied:
            // Random-access source; nothing to skip through.
            return false
        case .matchesAll:
            if channel.isTopKeyed {
                return try advanceDictMatchesAll(into: &channel)
            } else {
                return try advanceArrayMatchesAll(into: &channel)
            }
        case .unsatisfied:
            if channel.isTopKeyed {
                return try advanceDictFiltered(into: &channel, filter: filter)
            } else {
                return try advanceArrayFiltered(into: &channel, filter: filter)
            }
        }
    }

    // MARK: Array advance

    private mutating func advanceArrayMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == BPlistVocabulary {
        var f = channel.topSourceState
        let cursor = f.nextRefIdx
        guard cursor < f.sourceElementCount else { return false }
        f.nextRefIdx = cursor &+ 1
        channel.topSourceState = f
        let child = try readChild(at: cursor, source: topPrimitive, frame: f)
        try beginObject(prim: child, into: &channel)
        return true
    }

    private mutating func advanceArrayFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == BPlistVocabulary {
        let f = channel.topSourceState
        let refIdx = filter.nextArrayIndex()
        // Filter's index set is sorted ascending; a first out-of-range index means all later ones are also out of range. Stop iterating.
        guard refIdx >= 0 && refIdx < f.sourceElementCount else { return false }
        let child = try readChild(at: refIdx, source: topPrimitive, frame: f)
        try beginObject(prim: child, into: &channel)
        return true
    }

    // MARK: Dict advance

    private mutating func advanceDictMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == BPlistVocabulary {
        var f = channel.topSourceState
        let keySlot = f.nextRefIdx
        guard keySlot < f.sourceElementCount else { return false }
        f.nextRefIdx = keySlot &+ 1
        channel.topSourceState = f

        let key = try readChild(at: keySlot, source: topPrimitive, frame: f)
        let keyView: BPlistKeyView
        switch key.type {
        case .asciiString:
            keyView = BPlistKeyView.asciiString(try key.asciiStringSpan)
        case .utf16String:
            keyView = BPlistKeyView.utf16String(Span<UInt8>(viewing: try key.encodedString.span))
        default:
            throw BPlistError.corruptedValue("dictionary")
        }
        try channel.parkKey(keyView)

        let valueSlot = keySlot &+ f.sourceElementCount
        let value = try readChild(at: valueSlot, source: topPrimitive, frame: f)
        try beginObject(prim: value, into: &channel)
        return true
    }

    private mutating func advanceDictFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == BPlistVocabulary {
        // Loop inside the source: skip filter-rejected key/value pairs without returning until we either find a match or run out of pairs. Only emits (and thus returns true) on match.
        while true {
            var f = channel.topSourceState
            let keySlot = f.nextRefIdx
            guard keySlot < f.sourceElementCount else { return false }
            f.nextRefIdx = keySlot &+ 1
            channel.topSourceState = f

            let key = try readChild(at: keySlot, source: topPrimitive, frame: f)
            let keyView: BPlistKeyView
            let accepted: Bool
            switch key.type {
            case .asciiString:
                let span = try key.asciiStringSpan
                accepted = filter.matchesKey(span, encoding: .ascii)
                keyView = BPlistKeyView.asciiString(span)
            case .utf16String:
                let span = try key.encodedString.span
                let byteSpan = Span<UInt8>(viewing: span)
                accepted = filter.matchesKey(byteSpan, encoding: .utf16BE)
                keyView = BPlistKeyView.utf16String(byteSpan)
            default:
                // Unreachable: `isStringType` above filtered non-strings.
                throw BPlistError.corruptedValue("dictionary")
            }
            if !accepted { continue }

            try channel.parkKey(keyView)

            let valueSlot = keySlot &+ f.sourceElementCount
            let value = try readChild(at: valueSlot, source: topPrimitive, frame: f)
            try beginObject(prim: value, into: &channel)
            return true
        }
    }

    // MARK: Finalize

    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == BPlistVocabulary {
        let f = channel.topSourceState
        if channel.isTopKeyed {
            try channel.endKeyedContainer()
        } else {
            try channel.endUnkeyedContainer(kind: f.kind)
        }
        // Dedup population happens inside sink.finalize* via the cacheKey we passed at beginUnkeyedContainer/beginKeyedContainer. Source just clears the in-flight marker so future references get routed through the sink's cache lookup instead of tripping cycle detection.
        inFlight.remove(f.objectIndex.val)
    }

    // MARK: Ref reader

    @_lifetime(copy source)
    private func readChild(at slot: Int, source: borrowing BPlistPrimitive, frame: BPlistSourceFrame) throws -> BPlistPrimitive {
        let byteOffset = frame.elementRefsStartOffset &+ slot &* frame.refSize
        let childIdx = try source.validatedChildObjectIndex(atByteOffset: byteOffset, refSize: frame.refSize)
        return source.child(at: childIdx)
    }
}
#endif // FOUNDATION_FRAMEWORK || !os(macOS)
