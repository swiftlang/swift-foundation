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

// MARK: - XMLPlistMapBuildingSink

// `ParseEventSink` that builds an `XMLPlistMap`.
struct XMLPlistMapBuildingSink: ParseEventSink, ~Copyable {
    typealias Vocabulary = XMLPlistVocabulary
    typealias Fragment = Void
    typealias Output = XMLPlistMap<UniqueMapRecords>

    /// Bookkeeping for a container that's been opened but not yet finalized.
    private struct OpenContainer {
        
        /// First slot the container occupies, holding its type marker.
        let markerSlot: Int
        
        /// Slot holding `nextSiblingOffset`. Map value at this offset will be back-patched with the offset after the container when finalized.
        var nextSiblingOffsetSlot: Int { markerSlot &+ 1 }
        
        /// How many value records have been emitted into this container. For a dictionary, a key-value pair counts as one child.
        var childValueCount = 0
        
        private var firstKeyIsCFUIDName = false
        
        /// True when the records match `{"CF$UID": …}`, so `finalizeKeyedContainer` should try collapsing to a `.uid`.
        var isCFUIDCandidate: Bool { childValueCount == 1 && firstKeyIsCFUIDName }

        init(markerSlot: Int) {
            self.markerSlot = markerSlot
        }

        mutating func recordValue() {
            childValueCount &+= 1
        }

        mutating func recordKey(_ keyView: borrowing XMLPlistKeyView) {
            guard childValueCount == 0 else {
                return
            }
            firstKeyIsCFUIDName = keyView.isCFUIDKey
        }
    }

    /// The flat record buffer, handed off to the produced `XMLPlistMap` at `takeResult`.
    var mapData: UniqueArray<Int>
    private var openContainers: UniqueArray<OpenContainer>

    init(sourceBytes: borrowing Span<UInt8>) {
        self.mapData = UniqueArray()
        // Heuristic capacity estimate: with the noise of XML tags, allocate roughly one map entry per 8 source bytes.
        self.mapData.reserveCapacity(Swift.max(64, sourceBytes.count / 8))
        self.openContainers = UniqueArray()
        self.openContainers.reserveCapacity(32)
    }

    /// Applies `body` to the innermost open container, if any. Top-level values have no enclosing container.
    @inline(__always)
    private mutating func updateEnclosingContainer(_ body: (inout OpenContainer) -> Void) {
        guard !openContainers.isEmpty else {
            return
        }
        body(&openContainers[openContainers.count &- 1])
    }

    // MARK: Container open

    @inline(__always)
    mutating func beginUnkeyedContainer(cacheKey: Int?) throws {
        appendContainerOpen(marker: XMLPlistMapTypeDescriptor.array.mapMarker)
    }

    @inline(__always)
    mutating func beginKeyedContainer(cacheKey: Int?) throws {
        appendContainerOpen(marker: XMLPlistMapTypeDescriptor.dict.mapMarker)
    }

    @inline(__always)
    private mutating func appendContainerOpen(marker: Int) {
        openContainers.append(OpenContainer(markerSlot: mapData.count))
        mapData.append(copyingInline: [marker, 0, 0])
    }

    @inline(__always)
    private mutating func bumpChildValue() {
        updateEnclosingContainer { $0.recordValue() }
    }

    // MARK: Leaf events

    @inline(__always)
    mutating func acceptScalar(_ scalar: borrowing XMLPlistScalar, cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Void>) throws {
        appendLeafRecord(scalar)
        bumpChildValue()
    }

    @inline(__always)
    mutating func acceptKey(_ keyView: borrowing XMLPlistKeyView, into accumulator: inout ParseEventAccumulator<Void>) throws {
        // Keys get their own `.key` / `.simpleKey` markers, distinct from `.string` / `.simpleString` used for value strings.
        let marker = keyView.hasEscapes ? XMLPlistMapTypeDescriptor.key.mapMarker : XMLPlistMapTypeDescriptor.simpleKey.mapMarker
        appendScalarRecord(marker: marker, bytes: keyView.bytes, source: keyView.source)
        updateEnclosingContainer { $0.recordKey(keyView) }
    }

    @inline(__always)
    mutating func acceptNull(cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Void>) throws {
        mapData.append(XMLPlistMapTypeDescriptor.nullSentinel.mapMarker)
        bumpChildValue()
    }

    @inline(__always)
    mutating func acceptContainer(_ fragment: consuming Void, into accumulator: inout ParseEventAccumulator<Void>) throws {
        // Nested container's records + back-patched header are already in mapData; just count it against the parent.
        bumpChildValue()
    }

    @inline(__always)
    private mutating func appendLeafRecord(_ scalar: borrowing XMLPlistScalar) {
        switch scalar {
        case .bool(let b):
            mapData.append(b ? XMLPlistMapTypeDescriptor.`true`.mapMarker : XMLPlistMapTypeDescriptor.`false`.mapMarker)
        case .string(let bytes, let hasEscapes, let source):
            // A simple `$null` string is Codable's `encodeNil` representation; collapse to the native null marker so downstream `isNull` checks are a single-byte compare.
            if !hasEscapes, Self._bytesMatchNullSentinel(bytes) {
                mapData.append(XMLPlistMapTypeDescriptor.nullSentinel.mapMarker)
                return
            }
            let marker = hasEscapes ? XMLPlistMapTypeDescriptor.string.mapMarker : XMLPlistMapTypeDescriptor.simpleString.mapMarker
            appendScalarRecord(marker: marker, bytes: bytes, source: source)
        case .integer(let bytes, let source):
            appendScalarRecord(marker: XMLPlistMapTypeDescriptor.integer.mapMarker, bytes: bytes, source: source)
        case .real(let bytes, let source):
            appendScalarRecord(marker: XMLPlistMapTypeDescriptor.real.mapMarker, bytes: bytes, source: source)
        case .date(let bytes, let source):
            appendScalarRecord(marker: XMLPlistMapTypeDescriptor.date.mapMarker, bytes: bytes, source: source)
        case .data(let bytes, let source):
            appendScalarRecord(marker: XMLPlistMapTypeDescriptor.data.mapMarker, bytes: bytes, source: source)
        case .uid(let bytes, let source):
            appendScalarRecord(marker: XMLPlistMapTypeDescriptor.uid.mapMarker, bytes: bytes, source: source)
        }
    }

    @inline(__always)
    private mutating func appendScalarRecord(marker: Int, bytes: borrowing Span<UInt8>, source: borrowing Span<UInt8>) {
        mapData.append(copyingInline: [marker, bytes.count, source.sourceByteOffset(of: bytes)])
    }

    /// True iff `bytes` is exactly the 5-byte ASCII sequence `"$null"`.
    @inline(__always)
    private static func _bytesMatchNullSentinel(_ bytes: borrowing Span<UInt8>) -> Bool {
        guard bytes.count == 5 else { return false }
        return bytes[0] == UInt8(ascii: "$")
            && bytes[1] == UInt8(ascii: "n")
            && bytes[2] == UInt8(ascii: "u")
            && bytes[3] == UInt8(ascii: "l")
            && bytes[4] == UInt8(ascii: "l")
    }

    // MARK: Container finalize

    mutating func finalizeUnkeyedContainer(values: borrowing Span<Void>, cacheKey: Int?) throws -> Void {
        let container = openContainers.popLast()!
        finalizeContainer(container, count: container.childValueCount)
    }

    mutating func finalizeKeyedContainer(keys: borrowing Span<Void>, values: borrowing Span<Void>, cacheKey: Int?) throws -> Void {
        let container = openContainers.popLast()!
        if detectAndCollapseCFUID(container) {
            // We're not going to record this as a dictionary after all.
            return
        }
        finalizeContainer(container, count: container.childValueCount &* 2)
    }

    /// Number of slots a `{"CF$UID": <integer>}` dict occupies at finalize time: 3 each for the opening of the dictionary, the key, and the integer.
    private static var cfuidDictSlotCount: Int { 9 }
    /// Offset from a CFUID's dictionary marker slot to its single value record, past the header and key.
    private static var cfuidValueSlotOffset: Int { 6 }

    /// Rewrite a just-completed `{"CF$UID": <integer>}` dict as a single native `.uid` record, and report whether it did.
    private mutating func detectAndCollapseCFUID(_ container: OpenContainer) -> Bool {
        guard container.isCFUIDCandidate else {
            return false
        }
        
        let markerSlot = container.markerSlot
        guard mapData.count &- markerSlot == Self.cfuidDictSlotCount else {
            return false
        }
        
        let valueSlot = markerSlot &+ Self.cfuidValueSlotOffset
        guard mapData[valueSlot] == XMLPlistMapTypeDescriptor.integer.mapMarker else {
            return false
        }
        
        // The container's map records are the tail of `mapData`, so truncating them disturbs nothing already written.
        let byteCount = mapData[valueSlot &+ 1]
        let byteOffset = mapData[valueSlot &+ 2]
        mapData.removeSubrange(markerSlot ..< mapData.count)
        mapData.append(copyingInline: [XMLPlistMapTypeDescriptor.uid.mapMarker, byteCount, byteOffset])
        
        return true
    }

    private mutating func finalizeContainer(_ container: OpenContainer, count: Int) {
        mapData.append(XMLPlistMapTypeDescriptor.collectionEnd.mapMarker)
        let nextSiblingOffsetSlot = container.nextSiblingOffsetSlot
        let nextSiblingOffset = mapData.count
        
        var mutableSpan = mapData.mutableSpan
        mutableSpan[nextSiblingOffsetSlot] = nextSiblingOffset
        mutableSpan[nextSiblingOffsetSlot &+ 1] = count

        // Driver calls `sink.acceptContainer` after this returns; that's where we count the finalized container against its parent. Bumping here would double-count.
    }

    // MARK: Result

    consuming func takeResult() throws -> XMLPlistMap<UniqueMapRecords> {
        precondition(openContainers.count == 0, "XMLPlistMapBuildingSink.takeResult: \(openContainers.count) container(s) still open")
        return XMLPlistMap<UniqueMapRecords>(records: UniqueMapRecords(mapData))
    }

    func releaseFragment(_ fragment: consuming Void) {}
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
