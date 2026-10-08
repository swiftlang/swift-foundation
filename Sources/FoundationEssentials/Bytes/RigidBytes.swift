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

// MARK: - RigidBytes

@safe
struct RigidBytes: ~Copyable {
    internal var _pointer: UnsafeMutableRawPointer?

    internal var _capacity: Int

    internal var _count: Int

    deinit {
        if let pointer = unsafe _pointer {
            unsafe RigidBytes._deallocate(pointer)
        }
    }
}

// MARK: - Initializers

extension RigidBytes {
    @inline(always)
    init() {
        unsafe self._pointer = nil
        self._capacity = 0
        self._count = 0
    }

    init(capacity: Int) {
        precondition(capacity >= 0, "RigidBytes capacity must be nonnegative")
        if capacity > 0 {
            unsafe self._pointer = RigidBytes._allocate(size: capacity)
        } else {
            unsafe self._pointer = nil
        }
        self._count = 0
        self._capacity = capacity
    }

    init<E>(capacity: Int, initializingWith body: (inout OutputRawSpan) throws(E) -> Void) throws(E) {
        self.init(capacity: capacity)
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: _pointer, count: capacity)
        var outputSpan = unsafe OutputRawSpan(buffer: buffer, initializedCount: 0)
        defer {
            _count = unsafe outputSpan.finalize(for: buffer)
            outputSpan = OutputRawSpan()
        }
        try body(&outputSpan)
    }

    @inline(always)
    init(count: Int) {
        self.init(repeating: 0, count: count)
    }

    init(repeating byte: UInt8, count: Int) {
        self.init(capacity: count)
        unsafe _pointer?.initializeMemory(as: UInt8.self, repeating: byte, count: count)
        self._count = count
    }

    init(capacity: Int? = nil, copying bytes: RawSpan) {
        self.init(capacity: capacity ?? bytes.byteCount)
        self.append(copying: bytes)
    }
}

// MARK: - Deconstruction

extension RigidBytes {
    consuming func deconstruct() -> (
        storage: UnsafeMutableRawBufferPointer, count: Int
    ) {
        let result = unsafe (
            UnsafeMutableRawBufferPointer(start: _pointer, count: capacity),
            count
        )
        discard self
        return unsafe result
    }
}

// MARK: - Helpers

extension RigidBytes {
    @inline(__always)
    internal func _pointer(at offset: Int) -> UnsafeMutableRawPointer {
        assert(unsafe _pointer != nil && offset < capacity && offset >= 0)
        return unsafe _pointer.unsafelyUnwrapped.advanced(by: offset)
    }

    @inline(__always)
    internal var _freePointer: UnsafeMutableRawPointer? {
        unsafe _pointer?.advanced(by: count)
    }
    
    internal static func _allocate(size: Int) -> UnsafeMutableRawPointer {
        assert(size > 0)
        guard let pointer = unsafe __DataStorage.allocate(size, false) else {
            fatalError("Unable to allocate \(size) bytes")
        }
        return unsafe pointer
    }
        
    internal static func _reallocate(
        _ pointer: inout UnsafeMutableRawPointer,
        newCapacity: Int,
        initializedCount: Int
    ) {
        assert(newCapacity > 0)
        assert(initializedCount <= newCapacity)
        guard let newPointer = unsafe __DataStorage.reallocate(pointer, newCapacity) else {
            fatalError("Unable to reallocate \(newCapacity) bytes")
        }
        unsafe pointer = newPointer
    }
    
    static func _deallocate(_ pointer: UnsafeMutableRawPointer) {
        unsafe __DataStorage.deallocate(pointer)
    }
}

extension RigidBytes: @unchecked Sendable {}

extension RigidBytes {
    @inline(__always)
    func clone() -> RigidBytes {
            clone(capacity: count)
    }
    
    func clone(capacity: Int) -> Self {
        precondition(capacity >= count, "RigidBytes capacity overflow")
        var copy = RigidBytes(capacity: capacity)
        if count > 0 {
            unsafe copy._pointer(at: 0).copyMemory(from: _pointer(at: 0), byteCount: count)
        }
        copy._count = count
        return copy
    }
}
