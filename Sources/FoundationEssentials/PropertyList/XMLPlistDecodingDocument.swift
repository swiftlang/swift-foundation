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

// MARK: - Document

/// Class-shaped adapter that plugs an `XMLPlistMap` + source-byte pointer into the generic `_PlistDecoder<Format>` machinery via `PlistDecodingDocument`. Uses `XMLPlistPrimitive`/`XMLPlistPrimitiveScope` to walk the record buffer at decode time.
///
/// Holds `bytes` unowned at init; `copyInBuffer()` allocates a fresh copy the class owns and switches `bytes` over. `deinit` deallocates the owned copy.
@available(anyAppleOS 26.0, *)
final class XMLPlistDecodingDocument: PlistDecodingDocument {

    typealias Value = XMLPlistPrimitiveScope
    typealias ContainedValueReference = XMLPlistPrimitiveScope

    /// The source bytes. Points into the caller's buffer at init; once `copyInBuffer()` fires, points into `ownedAllocation` instead.
    var bytes: UnsafeRawBufferPointer

    /// Non-nil iff `bytes` points into a copy this class allocated. `deinit` deallocates it.
    private var ownedAllocation: UnsafeMutableRawBufferPointer?

    /// The parsed structural map. `~Copyable`; owned inline.
    var map: XMLPlistMap<UniqueMapRecords>

    init(bytes: UnsafeRawBufferPointer, map: consuming XMLPlistMap<UniqueMapRecords>) {
        self.bytes = bytes
        self.ownedAllocation = nil
        self.map = map
    }

    deinit {
        if let owned = ownedAllocation {
            owned.deallocate()
        }
    }

    /// Copy the source bytes into a fresh owned allocation (plus a trailing NUL for `strtod`), and switch `bytes` to point at that copy. Idempotent.
    func copyInBuffer() {
        guard ownedAllocation == nil else { return }
        let count = bytes.count
        let copy = UnsafeMutableRawBufferPointer.allocate(byteCount: count + 1, alignment: 1)
        copy.copyMemory(from: bytes)
        copy[count] = 0
        self.ownedAllocation = copy
        self.bytes = UnsafeRawBufferPointer(start: copy.baseAddress, count: count + 1)
    }

    var topObject: XMLPlistPrimitiveScope {
        get throws {
            XMLPlistPrimitiveScope(mapOffset: 0)
        }
    }

    @inline(__always)
    func value(from reference: XMLPlistPrimitiveScope) throws -> XMLPlistPrimitiveScope {
        reference
    }

    /// Reconstitute the primitive for the given scope. Opens the class's raw buffer as a `RawSpan` and calls `scope.withReconstituted(in:bytes:)`.
    @inline(__always)
    func withPrimitive<R: ~Copyable, E: Error>(
        for scope: XMLPlistPrimitiveScope,
        _ body: (borrowing XMLPlistPrimitive) throws(E) -> R
    ) throws(E) -> R {
        let span = unsafe RawSpan(_unsafeStart: bytes.baseAddress!, byteCount: bytes.count)
        return try scope.withReconstituted(in: map, bytes: span, body)
    }

    // MARK: - Iterators

    /// Iterator returned by `XMLPlistDecodingFormat.unkeyedContainer(for:)`. Walks the map's inline child records by offset arithmetic. Holding the document keeps the map alive, letting this stay `Escapable` where `XMLPlistPrimitive.ArrayIterator` cannot.
    struct ArrayIterator: PlistArrayIterator {
        let document: XMLPlistDecodingDocument
        var nextChildOffset: XMLPlistMapOffset
        var elementsRemaining: Int

        @inline(__always)
        mutating func next() -> XMLPlistPrimitiveScope? {
            guard elementsRemaining > 0 else { return nil }
            let scope = XMLPlistPrimitiveScope(mapOffset: nextChildOffset)
            nextChildOffset = _nextMapOffset(after: nextChildOffset, in: document.map)
            elementsRemaining -= 1
            return scope
        }
    }

    /// Iterator returned by `XMLPlistDecodingFormat.container(keyedBy:)`.
    /// All KeyedDecodingContainers enumerate all dictionary entries to "stringify" keys and resolve duplicates. Hence, this iterator can be ~Escapable and wrap an `XMLPlistPrimitive.DictionaryIterator` directly.
    struct DictionaryIterator: PlistDictionaryIterator, ~Copyable, ~Escapable {
        var iterator: XMLPlistPrimitive.DictionaryIterator

        @_lifetime(copy primitiveIterator)
        init(_ primitiveIterator: XMLPlistPrimitive.DictionaryIterator) {
            self.iterator = primitiveIterator
        }

        @inline(__always)
        mutating func next() throws -> (key: XMLPlistPrimitiveScope, value: XMLPlistPrimitiveScope)? {
            guard let pair = iterator.next() else {
                return nil
            }
            return (.init(mapOffset: pair.keyOffset), .init(mapOffset: pair.valueOffset))
        }
    }
}

#endif  // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
