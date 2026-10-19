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

// MARK: - Bytes

struct Bytes: ~Copyable {
    internal var _storage: RigidBytes
}

// MARK: - Initializers

extension Bytes {
    @inline(__always)
    init() {
        self._storage = RigidBytes()
    }
    
    init(capacity: Int) {
        precondition(capacity >= 0, "Bytes capacity must be nonnegative")
        self._storage = RigidBytes(capacity: capacity)
    }

    @inline(__always)
    init<E>(capacity: Int, initializingWith body: (inout OutputRawSpan) throws(E) -> Void) throws(E) {
        self._storage = try RigidBytes(capacity: capacity, initializingWith: body)
    }

    @inline(__always)
    init(count: Int) {
        self.init(repeating: 0, count: count)
    }
    
    init(repeating byte: UInt8, count: Int) {
        precondition(count >= 0, "Bytes count must be nonnegative")
        self._storage = RigidBytes(repeating: byte, count: count)
    }

    @inline(__always)
    init(capacity: Int? = nil, copying bytes: RawSpan) {
        self._storage = RigidBytes(capacity: capacity, copying: bytes)
    }

    @inline(__always)
    init(consuming rigid: consuming RigidBytes) {
        self._storage = rigid
    }
}

// MARK: - Deconstruction

extension Bytes {
    @inline(__always)
    consuming func deconstruct() -> (
        storage: UnsafeMutableRawBufferPointer, count: Int
    ) {
        unsafe _storage.deconstruct()
    }
}

// MARK: - Helpers

extension Bytes: Sendable {}

extension Bytes {
    @inline(__always)
    func clone() -> Bytes {
        Bytes(consuming: _storage.clone())
    }
    
    func clone(capacity: Int) -> Bytes {
        precondition(capacity >= count, "Bytes capacity overflow")
        return Bytes(consuming: _storage.clone(capacity: capacity))
    }
}

extension RigidBytes {
    @inline(__always)
    init(consuming unique: consuming Bytes) {
        self = unique._storage
    }
}
