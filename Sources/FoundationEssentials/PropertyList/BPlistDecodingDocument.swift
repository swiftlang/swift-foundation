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

// MARK: - Document

/// A class-shaped adapter that plugs an `UnsafeRawBufferPointer` (over the source bytes) + parsed `BPlistMetadata` into the generic `_PlistDecoder<Format>` machinery via `PlistDecodingDocument`.
///
/// Holds `bytes` unowned at init; `copyInBuffer()` allocates a fresh copy the class owns and switches `bytes` over. `deinit` deallocates the owned copy. `withPrimitive(for:)` opens `bytes` as a `RawSpan` per-call.
@available(anyAppleOS 26.0, *)
final class BPlistDecodingDocument: PlistDecodingDocument {

    typealias Value = BPlistPrimitiveScope
    typealias ContainedValueReference = BPlistPrimitiveScope

    /// The source bytes. Points into the caller's buffer at init; once `copyInBuffer()` fires, points into `ownedAllocation` instead.
    var bytes: UnsafeRawBufferPointer

    /// Non-nil iff `bytes` points into a copy this class allocated. `deinit` deallocates it.
    private var ownedAllocation: UnsafeMutableRawBufferPointer?

    /// Parsed top-level trailer + object-table metadata. Immutable.
    let metadata: BPlistMetadata

    init(bytes: UnsafeRawBufferPointer, metadata: BPlistMetadata) {
        self.bytes = bytes
        self.ownedAllocation = nil
        self.metadata = metadata
    }

    deinit {
        if let owned = ownedAllocation {
            owned.deallocate()
        }
    }

    /// Copy the source bytes into a fresh owned allocation, and switch `bytes` to point at that copy. Idempotent. Binary plists don't need a trailing NUL byte the way text-format decoders do.
    func copyInBuffer() {
        guard ownedAllocation == nil else { return }
        let count = bytes.count
        let copy = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        copy.copyMemory(from: bytes)
        self.ownedAllocation = copy
        self.bytes = UnsafeRawBufferPointer(start: copy.baseAddress, count: count)
    }

    var topObject: BPlistPrimitiveScope {
        get throws {
            BPlistPrimitiveScope(metadata: metadata, objectIndex: metadata.topObjectIndex)
        }
    }

    @inline(__always)
    func value(from reference: BPlistPrimitiveScope) throws -> BPlistPrimitiveScope {
        reference
    }

    /// Reconstitute the primitive for the given scope by opening `bytes` as a `RawSpan` and calling `scope.withReconstituted(in:)`. Used by `BPlistDecodingFormat` for every leaf / container read.
    @inline(__always)
    func withPrimitive<R: ~Copyable, E: Error>(
        for scope: BPlistPrimitiveScope,
        _ body: (borrowing BPlistPrimitive) throws(E) -> R
    ) throws(E) -> R {
        let span = unsafe RawSpan(_unsafeStart: bytes.baseAddress!, byteCount: bytes.count)
        return try scope.withReconstituted(in: span, body)
    }

    // MARK: - Iterators

    /// Iterator returned by `BPlistDecodingFormat.unkeyedContainer(for:)`. Indexes the container's object-ref table directly, so no per-element storage is needed. Holding the document (a class) keeps `bytes` alive, letting this stay `Escapable` where `BPlistPrimitive.ArraySetIterator` cannot.
    struct ArrayIterator: PlistArrayIterator {
        let document: BPlistDecodingDocument
        let containerScope: BPlistPrimitiveScope
        /// Byte range of the array's object ref list.
        let range: Range<Int>
        /// Byte offset of the next object ref to read.
        var position: Int

        @inline(__always)
        mutating func next() throws -> BPlistPrimitiveScope? {
            guard position < range.upperBound else {
                return nil
            }

            let refSize = document.metadata.objectRefSize
            let childIndex = try document.withPrimitive(for: containerScope) { primitive in
                try primitive.validatedChildObjectIndex(atByteOffset: position, refSize: refSize)
            }
            position &+= refSize
            return containerScope.child(at: childIndex)
        }
    }

    /// Iterator returned by `BPlistDecodingFormat.container(keyedBy:)`.
    /// All KeyedDecodingContainers enumerate all dictionary entries to "stringify" keys and resolve duplicates. Hence, this iterator can be ~Escapable and wrap a `BPlistPrimitive.DictionaryIterator` directly.
    struct DictionaryIterator: PlistDictionaryIterator, ~Copyable, ~Escapable {
        var iterator: BPlistPrimitive.DictionaryIterator
        
        @_lifetime(copy primitiveIterator)
        init(_ primitiveIterator: BPlistPrimitive.DictionaryIterator) {
            self.iterator = primitiveIterator
        }

        @inline(__always)
        mutating func next() throws -> (key: BPlistPrimitiveScope, value: BPlistPrimitiveScope)? {
            guard let pair = try iterator.next() else {
                return nil
            }
            return (.init(pair.key), .init(pair.value))
        }
    }
}

#endif  // FOUNDATION_FRAMEWORK || !os(macOS)
