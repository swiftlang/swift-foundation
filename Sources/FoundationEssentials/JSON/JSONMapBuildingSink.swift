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



// MARK: - JSONMapBuildingSink

/// `ParseEventSink` that builds a `JSONMap`: the flat-`Int` array record buffer format that describes the structure of a JSON document.
struct JSONMapBuildingSink: ParseEventSink, ~Copyable {
    typealias Vocabulary = JSONVocabulary
    typealias Fragment = Void
    typealias Output = JSONMap<UniqueMapRecords>

    /// The flat record buffer, handed off to the produced `JSONMap` at `takeResult`.
    var mapData: UniqueArray<Int>
    /// Back-patch stack of `nextSiblingOffset` slot indices, one per open container.
    var openHeaderSlots: UniqueArray<Int>
    /// Per-open-container value-record count, parallel to `openHeaderSlots`. Dicts store `2 × count` on finalize; keys don't bump, the paired value's event does.
    var openChildCounts: UniqueArray<Int>

    init(sourceBytes: borrowing Span<UInt8>) {
        self.mapData = UniqueArray()
        // Heuristic capacity estimate: roughly one map entry per 4 source bytes.
        self.mapData.reserveCapacity(Swift.max(64, sourceBytes.count / 4))
        self.openHeaderSlots = UniqueArray()
        self.openHeaderSlots.reserveCapacity(32)
        self.openChildCounts = UniqueArray()
        self.openChildCounts.reserveCapacity(32)
    }

    @inline(__always)
    mutating func beginUnkeyedContainer(cacheKey: Int?) throws {
        appendContainerOpen(marker: JSONMapTypeDescriptor.array.mapMarker)
    }

    @inline(__always)
    mutating func beginKeyedContainer(cacheKey: Int?) throws {
        appendContainerOpen(marker: JSONMapTypeDescriptor.object.mapMarker)
    }

    @inline(__always)
    private mutating func appendContainerOpen(marker: Int) {
        let slotIdx = mapData.count &+ 1
        // Append placeholders for nextSiblingOffset and child count, neither of which are known at present. Both values will be filled in when the container closes.
        mapData.append(copyingInline: [marker, 0, 0])
        openHeaderSlots.append(slotIdx)
        openChildCounts.append(0)
    }

    @inline(__always)
    private mutating func bumpChildValue() {
        let top = openChildCounts.count &- 1
        // Empty at top level (no open container).
        guard top >= 0 else { return }
        openChildCounts[top] &+= 1
    }

    @inline(__always)
    mutating func acceptScalar(_ scalar: borrowing JSONScalar, cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Void>) throws {
        appendLeafRecord(scalar)
        bumpChildValue()
    }

    @inline(__always)
    mutating func acceptKey(_ keyView: borrowing JSONKeyView, into accumulator: inout ParseEventAccumulator<Void>) throws {
        let marker = keyView.hasEscapes ? JSONMapTypeDescriptor.string.mapMarker : JSONMapTypeDescriptor.simpleString.mapMarker
        appendScalarRecord(marker: marker, bytes: keyView.bytes, source: keyView.source)
        // Keys don't count as child values. Don't call bumpChildValue() until the corresponding value.
    }

    @inline(__always)
    mutating func acceptNull(cacheKey: Int?, into accumulator: inout ParseEventAccumulator<Void>) throws {
        mapData.append(JSONMapTypeDescriptor.null.mapMarker)
        bumpChildValue()
    }

    @inline(__always)
    mutating func acceptContainer(_ fragment: consuming Void, into accumulator: inout ParseEventAccumulator<Void>) throws {
        // Nested container's records + back-patched header are already in mapData; just count the child.
        bumpChildValue()
    }

    @inline(__always)
    private mutating func appendLeafRecord(_ scalar: borrowing JSONScalar) {
        switch scalar {
        case .bool(let b):
            mapData.append(b ? JSONMapTypeDescriptor.true.mapMarker : JSONMapTypeDescriptor.false.mapMarker)
        case .string(let bytes, let hasEscapes, let source):
            let marker = hasEscapes ? JSONMapTypeDescriptor.string.mapMarker : JSONMapTypeDescriptor.simpleString.mapMarker
            appendScalarRecord(marker: marker, bytes: bytes, source: source)
        case .number(let bytes, let containsExponent, let source):
            let marker = containsExponent ? JSONMapTypeDescriptor.numberContainingExponent.mapMarker : JSONMapTypeDescriptor.number.mapMarker
            appendScalarRecord(marker: marker, bytes: bytes, source: source)
        }
    }

    @inline(__always)
    private mutating func appendScalarRecord(marker: Int, bytes: borrowing Span<UInt8>, source: borrowing Span<UInt8>) {
        mapData.append(copyingInline: [marker, bytes.count, source.sourceByteOffset(of: bytes)])
    }

    mutating func finalizeUnkeyedContainer(values: borrowing Span<Void>, cacheKey: Int?) throws -> Void {
        let childCount = openChildCounts.popLast()!
        finalizeContainer(count: childCount)
    }

    mutating func finalizeKeyedContainer(keys: borrowing Span<Void>, values: borrowing Span<Void>, cacheKey: Int?) throws -> Void {
        let pairCount = openChildCounts.popLast()!
        finalizeContainer(count: pairCount &* 2)
    }

    private mutating func finalizeContainer(count: Int) {
        mapData.append(JSONMapTypeDescriptor.collectionEnd.mapMarker)
        let slotIdx = openHeaderSlots.popLast()!
        let nextSiblingOffset = mapData.count
        // Back-patch [nextSiblingOffset, count].
        var span = mapData.mutableSpan
        span[slotIdx] = nextSiblingOffset
        span[slotIdx &+ 1] = count
        // Child count against the parent is bumped in `acceptContainer`, which the driver calls after `finalize*` returns.
    }

    consuming func takeResult() throws -> JSONMap<UniqueMapRecords> {
        precondition(openHeaderSlots.count == 0, "JSONMapBuildingSink.takeResult: \(openHeaderSlots.count) container(s) still open")
        return JSONMap(records: UniqueMapRecords(mapData))
    }

    func releaseFragment(_ fragment: consuming Void) {
        // Fragment == Void; nothing to release.
    }
}

extension UniqueArray {
    @inline(__always)
    mutating func append<let count: Int>(copyingInline array: [count of Element]) {
        self.append(copying: array.span)
    }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
