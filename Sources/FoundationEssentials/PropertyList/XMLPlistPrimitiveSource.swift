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

// MARK: - XMLPlistPrimitiveSource

/// Event source wrapping a pre-scanned `XMLPlistPrimitive`.
struct XMLPlistPrimitiveSource<Filter: ParseEventFilter & ~Copyable>: ParseEventSource<Filter>, ~Copyable, ~Escapable {
    
    /// Per-container walk cursor and child count.
    internal struct Frame {
        var nextChildMapOffset: XMLPlistMapOffset
        let sourceElementCount: Int
        var placedCount: Int = 0
    }
    
    typealias Vocabulary = XMLPlistVocabulary

    let top: XMLPlistPrimitive

    @_lifetime(copy top)
    init(top: XMLPlistPrimitive) {
        self.top = top
    }

    /// The whole document, as handed to scalars and key views so sinks can locate byte ranges within it.
    private var sourceBytes: Span<UInt8> {
        @_lifetime(copy self)
        get { Span(viewing: top.sourceBytes) }
    }

    // MARK: ParseEventSource

    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        try beginObject(prim: top, into: &channel)
    }

    // MARK: Begin object

    private mutating func beginObject<Sink: ParseEventSink & ~Copyable>(prim: borrowing XMLPlistPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        switch prim.type {
        case .null:
            try channel.emitNull()
        case .true:
            try channel.emitScalar(XMLPlistScalar.bool(true))
        case .false:
            try channel.emitScalar(XMLPlistScalar.bool(false))
        case .integer:
            try channel.emitScalar(XMLPlistScalar.integer(bytes: try prim.integerBytes, source: sourceBytes))
        case .real:
            try channel.emitScalar(XMLPlistScalar.real(bytes: try prim.realBytes, source: sourceBytes))
        case .date:
            try channel.emitScalar(XMLPlistScalar.date(bytes: try prim.dateBytes, source: sourceBytes))
        case .data:
            try channel.emitScalar(XMLPlistScalar.data(bytes: try prim.dataBytes, source: sourceBytes))
        case .string:
            let sb = try prim.stringBytes
            try channel.emitScalar(XMLPlistScalar.string(bytes: sb.bytes, hasEscapes: !sb.isSimple, source: sourceBytes))
        case .array:
            try pushArrayFrame(prim: prim, into: &channel)
        case .dict:
            try pushDictFrame(prim: prim, into: &channel)
        case .uid:
            try channel.emitScalar(XMLPlistScalar.uid(bytes: try prim.uidBytes, source: sourceBytes))
        case .none:
            throw XMLPlistError.other("Invalid XML plist value type")
        }
    }

    private mutating func pushArrayFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing XMLPlistPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        let iterator = try prim.arrayIterator
        try channel.beginUnkeyedContainer(cacheKey: nil, sourceState: Frame(nextChildMapOffset: iterator.currentOffset, sourceElementCount: iterator.count))
    }

    private mutating func pushDictFrame<Sink: ParseEventSink & ~Copyable>(prim: borrowing XMLPlistPrimitive, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        let iterator = try prim.dictionaryIterator
        try channel.beginKeyedContainer(cacheKey: nil, sourceState: Frame(nextChildMapOffset: iterator.currentOffset, sourceElementCount: iterator.count))
    }

    // MARK: Advance

    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        switch filter.state {
        case .satisfied:
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

    private mutating func advanceArrayMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        var f = channel.topSourceState
        guard f.placedCount < f.sourceElementCount else { return false }
        let childOffset = f.nextChildMapOffset
        let child = top.sibling(atMapOffset: childOffset)
        f.nextChildMapOffset = _nextMapOffset(after: childOffset, in: top.map.value)
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: child, into: &channel)
        return true
    }

    private mutating func advanceArrayFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        var f = channel.topSourceState
        let target = filter.nextArrayIndex()
        guard target >= 0 && target < f.sourceElementCount else { return false }
        while f.placedCount < target {
            f.nextChildMapOffset = _nextMapOffset(after: f.nextChildMapOffset, in: top.map.value)
            f.placedCount &+= 1
        }
        let childOffset = f.nextChildMapOffset
        let child = top.sibling(atMapOffset: childOffset)
        f.nextChildMapOffset = _nextMapOffset(after: childOffset, in: top.map.value)
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: child, into: &channel)
        return true
    }

    private mutating func advanceDictMatchesAll<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        var f = channel.topSourceState
        guard f.placedCount < f.sourceElementCount else { return false }
        let keyOffset = f.nextChildMapOffset
        let valueOffset = _nextMapOffset(after: keyOffset, in: top.map.value)
        let nextPairOffset = _nextMapOffset(after: valueOffset, in: top.map.value)
        let keyPrim = top.sibling(atMapOffset: keyOffset)
        guard keyPrim.isStringType else {
            throw XMLPlistError.other("Found non-key inside <dict>")
        }
        let sb = try keyPrim.stringBytes
        let keyView = XMLPlistKeyView(bytes: sb.bytes, hasEscapes: !sb.isSimple, source: sourceBytes)
        try channel.parkKey(keyView)
        let valuePrim = top.sibling(atMapOffset: valueOffset)
        f.nextChildMapOffset = nextPairOffset
        f.placedCount &+= 1
        channel.topSourceState = f
        try beginObject(prim: valuePrim, into: &channel)
        return true
    }

    private mutating func advanceDictFiltered<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        var f = channel.topSourceState
        while f.placedCount < f.sourceElementCount {
            let keyOffset = f.nextChildMapOffset
            let valueOffset = _nextMapOffset(after: keyOffset, in: top.map.value)
            let nextPairOffset = _nextMapOffset(after: valueOffset, in: top.map.value)
            let keyPrim = top.sibling(atMapOffset: keyOffset)
            guard keyPrim.isStringType else {
                throw XMLPlistError.other("Found non-key inside <dict>")
            }
            let sb = try keyPrim.stringBytes
            if !filter.matchesKey(sb.bytes, encoding: .utf8) {
                f.nextChildMapOffset = nextPairOffset
                f.placedCount &+= 1
                continue
            }
            let keyView = XMLPlistKeyView(bytes: sb.bytes, hasEscapes: !sb.isSimple, source: sourceBytes)
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

    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        if channel.isTopKeyed {
            try channel.endKeyedContainer()
        } else {
            try channel.endUnkeyedContainer()
        }
    }
}
#endif // FOUNDATION_FRAMEWORK || !os(macOS)
