//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 - 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// MARK: - Reallocation

extension Bytes {
    @inline(__always)
    mutating func reserveCapacity(_ n: Int) {
        _storage.reserveCapacity(n)
    }

    @inline(__always)
    internal mutating func _ensureFreeCapacity(_ requiredSpace: Int) {
        guard _storage.freeCapacity < requiredSpace else { return }
        self._grow(ensuringFreeCapacity: requiredSpace)
    }

    internal static var _minimumGrowthCapacity: Int { 16 }

    @inline(never) // Prevent register spill cost on fast path
    internal mutating func _grow(ensuringFreeCapacity freeCapacity: Int) {
        // Grow by a factor of 1.5
        let newCapacity = Swift.max(
            self.count + freeCapacity,
            (3 &* self.capacity &+ 1) / 2,
            Self._minimumGrowthCapacity
        )
        self._storage.reallocate(capacity: newCapacity)
    }
}

// MARK: - Append

extension Bytes {
    mutating func append(_ byte: UInt8) {
        self._ensureFreeCapacity(1)
        self._storage.append(byte)
    }
    
    mutating func append(copying bytes: RawSpan) {
        self._ensureFreeCapacity(bytes.byteCount)
        self._storage.append(copying: bytes)
    }

    mutating func append<E, R: ~Copyable>(
        addingCount count: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        self._ensureFreeCapacity(count)
        return try _storage.append(addingCount: count, initializingWith: body)
    }
}

// MARK: - Insert

extension Bytes {
    mutating func insert(_ byte: UInt8, at index: Int) {
        self._ensureFreeCapacity(1)
        _storage.insert(byte, at: index)
    }

    mutating func insert(copying bytes: RawSpan, at index: Int) {
        self._ensureFreeCapacity(bytes.byteCount)
        _storage.insert(copying: bytes, at: index)
    }

    mutating func insert<E, R: ~Copyable>(
        addingCount count: Int,
        at index: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        self._ensureFreeCapacity(count)
        return try _storage.insert(addingCount: count, at: index, initializingWith: body)
    }
}

// MARK: - Edit

extension Bytes {
    @inline(__always)
    mutating func edit<E, R: ~Copyable>(
        _ body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        try _storage.edit(body)
    }
}

// MARK: - Removal

extension Bytes {
    @inline(__always)
    @discardableResult
    mutating func remove(at index: Int) -> UInt8 {
        _storage.remove(at: index)
    }

    @inline(__always)
    mutating func removeAll(keepingCapacity: Bool = false) {
        if keepingCapacity {
            _storage.removeAll()
        } else {
            _storage = RigidBytes()
        }
    }

    @inline(__always)
    @discardableResult
    mutating func removeLast() -> UInt8 {
        _storage.removeLast()
    }

    @inline(__always)
    mutating func removeLast(_ n: Int) {
        _storage.removeLast(n)
    }

    @inline(__always)
    mutating func popLast() -> UInt8? {
        _storage.popLast()
    }

    @inline(__always)
    mutating func removeSubrange(_ range: some RangeExpression<Int>) {
        _storage.removeSubrange(range)
    }
}

// MARK: - Replace Subrange

extension Bytes {
    mutating func replaceSubrange<E>(
        _ subrange: Range<Int>,
        addingCount newItemCount: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) -> Void {
        self._ensureFreeCapacity(newItemCount - subrange.count)
        try self._storage.replaceSubrange(subrange, addingCount: newItemCount, initializingWith: body)
    }

    mutating func replaceSubrange(
        _ range: Range<Int>, copying span: RawSpan
    ) {
        self._ensureFreeCapacity(span.byteCount - range.count)
        self._storage.replaceSubrange(range, copying: span)
    }
}

// MARK: - Resetting

extension Bytes {
    @inline(__always)
    mutating func resetBytes(in range: Range<Int>) {
        self._storage.resetBytes(in: range)
    }
}
