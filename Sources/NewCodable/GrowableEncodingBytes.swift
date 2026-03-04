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


// MARK: - GrowableEncodingBytes

@safe
internal struct GrowableEncodingBytes: ~Copyable {
    @usableFromInline
    internal var _pointer: UnsafeMutableRawPointer?
    
    @usableFromInline
    internal var _capacity: Int
    
    @usableFromInline
    internal var _count: Int
    
//    @export(implementation)
    deinit {
        if let pointer = unsafe _pointer {
            unsafe Self._deallocate(pointer)
        }
    }
}

// MARK: - Initializers

extension GrowableEncodingBytes {
    public init() {
        unsafe self._pointer = nil
        self._capacity = 0
        self._count = 0
    }
    
    @export(implementation)
    public init(capacity: Int) {
        precondition(capacity >= 0, "GrowableEncodingBytes capacity must be nonnegative")
        if capacity > 0 {
            unsafe self._pointer = Self._allocate(size: capacity)
        } else {
            unsafe self._pointer = nil
        }
        self._count = 0
        self._capacity = capacity
    }
}

// MARK: - Deconstruction

extension GrowableEncodingBytes {
    @export(implementation)
    public consuming func deconstruct() -> (
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

extension GrowableEncodingBytes {
    @export(implementation)
    @inline(__always)
    internal func _pointer(at offset: Int) -> UnsafeMutableRawPointer {
        assert(unsafe _pointer != nil && offset < capacity && offset >= 0)
        return unsafe _pointer.unsafelyUnwrapped.advanced(by: offset)
    }
    
    @export(implementation)
    @inline(__always)
    internal var _startPointer: UnsafeMutableRawPointer {
        unsafe _pointer(at: 0)
    }
    
    @export(implementation)
    @inline(__always)
    internal var _freePointer: UnsafeMutableRawPointer {
        unsafe _pointer(at: count)
    }
    
    @usableFromInline
    internal static func _allocate(size: Int) -> UnsafeMutableRawPointer {
        assert(size > 0)
        // Mirror malloc behavior of allocating with an alignment large enough for all primitive integers
        return UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<UInt128>.alignment)
    }
    
    @usableFromInline
    internal static func _reallocate(
        _ pointer: inout UnsafeMutableRawPointer,
        newCapacity: Int,
        initializedCount: Int
    ) {
        assert(newCapacity > 0)
        assert(initializedCount <= newCapacity)
        // TODO: Can we use realloc-like behavior?
        let newPointer = unsafe Self._allocate(size: newCapacity)
        unsafe newPointer.copyMemory(from: pointer, byteCount: initializedCount)
        unsafe Self._deallocate(pointer)
        unsafe pointer = newPointer
    }
    
    @usableFromInline
    internal static func _deallocate(_ pointer: UnsafeMutableRawPointer) {
        unsafe pointer.deallocate()
    }
    
    @usableFromInline
    internal mutating func _grow(ensuringCapacity capacity: Int) {
        // TODO: Round/scale up to good value
        let newCapacity = capacity * 3 / 2
        self.reallocate(capacity: newCapacity)
    }
}

extension GrowableEncodingBytes: @unchecked Sendable {}

extension GrowableEncodingBytes {
    @export(implementation)
    @inline(__always)
    internal var capacity: Int {
        _assumeNonNegative(self._capacity)
    }
    
    @export(implementation)
    @inline(__always)
    internal var freeCapacity: Int {
        _assumeNonNegative(self._capacity &- count)
    }
}

extension GrowableEncodingBytes {
    @export(implementation)
    public func copy() -> GrowableEncodingBytes {
        copy(capacity: count)
    }
    
    @export(implementation)
    public func copy(capacity: Int) -> Self {
        precondition(capacity >= count, "GrowableEncodingBytes capacity overflow")
        var copy = Self(capacity: capacity)
        if count > 0 {
            unsafe copy._startPointer
                .copyMemory(from: _startPointer, byteCount: count)
        }
        copy._count = count
        return copy
    }
}

extension GrowableEncodingBytes {
    public var bytes: RawSpan {
        @_lifetime(borrow self)
        @export(implementation)
        @inline(__always)
        get {
            if let pointer = unsafe _pointer {
                let result = unsafe RawSpan(_unsafeStart: pointer, byteCount: count)
                return unsafe _overrideLifetime(result, borrowing: self)
            } else {
                return unsafe _overrideLifetime(RawSpan(), borrowing: self)
            }
        }
    }
    
    public var mutableBytes: MutableRawSpan {
        @_lifetime(&self)
        @export(implementation)
        mutating get {
            if let pointer = unsafe _pointer {
                let result = unsafe MutableRawSpan(_unsafeStart: pointer, byteCount: count)
                return unsafe _overrideLifetime(result, mutating: &self)
            } else {
                return unsafe _overrideLifetime(MutableRawSpan(), mutating: &self)
            }
        }
    }
}

extension GrowableEncodingBytes {
    @export(implementation)
    @inline(__always)
    public var count: Int {
        _assumeNonNegative(self._count)
    }
    
    @export(implementation)
    @inline(__always)
    public var isEmpty: Bool {
        self.count == 0
    }
}


// MARK: - Reallocation
extension GrowableEncodingBytes {
    @export(implementation)
    public mutating func reallocate(capacity newCapacity: Int) {
        precondition(newCapacity >= count, "GrowableEncodingBytesGrowableEncodingBytes capacity overflow")
        guard newCapacity != capacity else { return }
        
        if newCapacity > 0 {
            if var pointer = unsafe _pointer {
                unsafe Self._reallocate(&pointer, newCapacity: newCapacity, initializedCount: count)
                unsafe _pointer = pointer
            } else {
                unsafe _pointer = Self._allocate(size: newCapacity)
            }
        } else {
            // The newCapacity != capacity precondition and newCapacity == 0 check
            // guarantee that _pointer is not nil here
            unsafe Self._deallocate(_pointer.unsafelyUnwrapped)
            unsafe _pointer = nil
        }
        _capacity = newCapacity
    }
    
    @export(implementation)
    @inline(__always)
    public mutating func reserveCapacity(_ n: Int) {
        guard capacity < n else { return }
        self._grow(ensuringCapacity: n)
    }
}

// MARK: - Append

extension GrowableEncodingBytes {
    @export(implementation)
    public mutating func append(_ byte: UInt8) {
        self.reserveCapacity(self.count + 1)
        unsafe _freePointer.storeBytes(of: byte, as: UInt8.self)
        _count += 1
    }
    
    @export(implementation)
    public mutating func append(_ bytes: borrowing RawSpan) {
        let newBytes = bytes.byteCount
        guard newBytes > 0 else { return }
        
        self.reserveCapacity(self.count + bytes.byteCount)
        
        unsafe bytes.withUnsafeBytes { buffer in
            unsafe _freePointer.copyMemory(
                from: buffer.baseAddress.unsafelyUnwrapped,
                byteCount: newBytes
            )
        }
        _count += newBytes
    }
}
