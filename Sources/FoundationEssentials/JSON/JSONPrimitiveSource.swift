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

// `ParseEventSource` walker over a pre-scanned `JSONPrimitive` tree.
// Emits raw byte views for strings/numbers; the sink materializes.


// MARK: - Frame

/// Per-container walk cursor and child count.
internal struct JSONSourceFrame {
    var nextChildMapOffset: Int
    let sourceElementCount: Int
    var placedCount: Int = 0
}

// MARK: - JSONPrimitiveSource

struct JSONPrimitiveSource: ParseEventSource, ~Copyable, ~Escapable {
    typealias Vocabulary = JSONVocabulary
    typealias Frame = JSONSourceFrame

    let top: JSONPrimitive

    @_lifetime(copy top)
    init(top: JSONPrimitive) {
        self.top = top
    }

    /// The whole document, as handed to scalars and key views so sinks can locate byte ranges within it.
    private var sourceBytes: Span<UInt8> {
        @_lifetime(copy self)
        get { Span(viewing: top.jsonBytes) }
    }

    // MARK: ParseEventSource

    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        try beginObject(prim: top, into: &channel)
    }

    // MARK: Begin object

    private mutating func beginObject<Sink: ParseEventSink & ~Copyable>(prim: borrowing JSONPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        switch prim.type {
        case .null:
            try channel.emitNull()
        case .true:
            try channel.emitScalar(JSONScalar.bool(true))
        case .false:
            try channel.emitScalar(JSONScalar.bool(false))
        case .string:
            let sb = try prim.stringBytes
            try channel.emitScalar(JSONScalar.string(bytes: sb.bytes, hasEscapes: sb.hasEscapes, source: sourceBytes))
        case .number:
            let nb = try prim.numberBytes
            try channel.emitScalar(JSONScalar.number(bytes: nb.bytes, containsExponent: nb.containsExponent, source: sourceBytes))
        case .array:
            try pushArrayFrame(prim: prim, into: &channel)
        case .object:
            try pushDictFrame(prim: prim, into: &channel)
        case .none:
            throw JSONPrimitiveError.invalidMarker
        }
    }

    private mutating func pushArrayFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing JSONPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let iterator = try prim.arrayIterator
        try channel.beginUnkeyedContainer(cacheKey: nil, sourceState: JSONSourceFrame(nextChildMapOffset: iterator.currentOffset, sourceElementCount: iterator.count))
    }

    private mutating func pushDictFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing JSONPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let iterator = try prim.dictionaryIterator
        try channel.beginKeyedContainer(cacheKey: nil, sourceState: JSONSourceFrame(nextChildMapOffset: iterator.currentOffset, sourceElementCount: iterator.count))
    }

    // MARK: Advance

    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        switch filter.state {
        case .satisfied:
            // Map source: mark exhausted so `finalizeTopFrame` closes cleanly without further walk.
            var f = channel.topSourceState
            f.placedCount = f.sourceElementCount
            channel.topSourceState = f
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

    private mutating func advanceArrayMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        var f = channel.topSourceState
        guard f.placedCount < f.sourceElementCount else { return false }
        let childOffset = f.nextChildMapOffset
        let child = top.sibling(atMapOffset: childOffset)
        f.nextChildMapOffset = top.map.value.offset(after: childOffset)
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: child, into: &channel)
        return true
    }

    private mutating func advanceArrayFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        var f = channel.topSourceState
        let target = filter.nextArrayIndex()
        // `arrayIndices` is sorted ascending, so a first out-of-range target means the rest are too.
        guard target >= 0 && target < f.sourceElementCount else { return false }
        // Sequential source: walk the map from placedCount to target, skipping intermediates.
        while f.placedCount < target {
            f.nextChildMapOffset = top.map.value.offset(after: f.nextChildMapOffset)
            f.placedCount &+= 1
        }
        let childOffset = f.nextChildMapOffset
        let child = top.sibling(atMapOffset: childOffset)
        f.nextChildMapOffset = top.map.value.offset(after: childOffset)
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: child, into: &channel)
        return true
    }

    private mutating func advanceDictMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        var f = channel.topSourceState
        guard f.placedCount < f.sourceElementCount else { return false }
        let keyOffset = f.nextChildMapOffset
        let valueOffset = top.map.value.offset(after: keyOffset)
        let nextPairOffset = top.map.value.offset(after: valueOffset)
        let keyPrim = top.sibling(atMapOffset: keyOffset)
        let sb = try keyPrim.stringBytes
        let keyView = JSONKeyView(bytes: sb.bytes, hasEscapes: sb.hasEscapes, source: sourceBytes)
        try channel.parkKey(keyView)
        let valuePrim = top.sibling(atMapOffset: valueOffset)
        f.nextChildMapOffset = nextPairOffset
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: valuePrim, into: &channel)
        return true
    }

    private mutating func advanceDictFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        var f = channel.topSourceState
        // Loop within source: skip filter-rejected pairs without returning until a match or end.
        while f.placedCount < f.sourceElementCount {
            let keyOffset = f.nextChildMapOffset
            let valueOffset = top.map.value.offset(after: keyOffset)
            let nextPairOffset = top.map.value.offset(after: valueOffset)
            let keyPrim = top.sibling(atMapOffset: keyOffset)
            let sb = try keyPrim.stringBytes
            if !filter.matchesKey(sb.bytes, encoding: .utf8) {
                f.nextChildMapOffset = nextPairOffset
                f.placedCount &+= 1
                continue
            }
            let keyView = JSONKeyView(bytes: sb.bytes, hasEscapes: sb.hasEscapes, source: sourceBytes)
            try channel.parkKey(keyView)
            let valuePrim = top.sibling(atMapOffset: valueOffset)
            f.nextChildMapOffset = nextPairOffset
            f.placedCount &+= 1
            channel.topSourceState = f
            try beginObject(prim: valuePrim, into: &channel)
            return true
        }
        channel.topSourceState = f
        return false
    }

    // MARK: Finalize

    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        if channel.isTopKeyed {
            try channel.endKeyedContainer()
        } else {
            try channel.endUnkeyedContainer()
        }
    }
}
#endif // FOUNDATION_FRAMEWORK || !os(macOS)
