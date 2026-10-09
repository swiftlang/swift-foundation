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

extension RigidBytes {
    mutating func reallocate(capacity newCapacity: Int) {
        precondition(newCapacity >= count, "RigidBytes capacity overflow")
        guard newCapacity != capacity else { return }
        
        if newCapacity > 0 {
            if var pointer = unsafe _pointer {
                unsafe RigidBytes._reallocate(&pointer, newCapacity: newCapacity, initializedCount: count)
                unsafe _pointer = pointer
            } else {
                unsafe _pointer = RigidBytes._allocate(size: newCapacity)
            }
        } else {
            // The newCapacity != capacity precondition and newCapacity == 0 check
            // guarantee that _pointer is not nil here
            unsafe RigidBytes._deallocate(_pointer.unsafelyUnwrapped)
            unsafe _pointer = nil
        }
        _capacity = newCapacity
    }
    
    mutating func reserveCapacity(_ n: Int) {
        guard capacity < n else { return }
        reallocate(capacity: n)
    }
}

// MARK: - Append

extension RigidBytes {
    mutating func append(_ byte: UInt8) {
        precondition(count < capacity, "RigidBytes capacity overflow")
        unsafe _freePointer.unsafelyUnwrapped.storeBytes(of: byte, as: UInt8.self)
        _count &+= 1
    }

    mutating func pushLast(_ byte: UInt8) {
        guard !isFull else { return }
        self.append(byte)
    }

    mutating func append(copying bytes: RawSpan) {
        let newBytes = bytes.byteCount
        guard newBytes > 0 else { return }
        
        precondition(newBytes <= freeCapacity, "RigidBytes capacity overflow")
        bytes.withUnsafeBytes { buffer in
            unsafe _freePointer.unsafelyUnwrapped.copyMemory(
                    from: buffer.baseAddress.unsafelyUnwrapped,
                    byteCount: newBytes
                )
        }
        _count &+= newBytes
    }
    
    mutating func append<E, R: ~Copyable>(
        addingCount count: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        precondition(count >= 0, "Negative count")
        precondition(count <= freeCapacity, "RigidBytes capacity overflow")
        let freeBuffer = unsafe UnsafeMutableRawBufferPointer(
            start: _freePointer,
            count: count
        )
        var outputSpan = unsafe OutputRawSpan(
            buffer: freeBuffer,
            initializedCount: 0
        )
        defer {
            _count &+= unsafe outputSpan.finalize(for: freeBuffer)
            outputSpan = OutputRawSpan()
        }
        return try body(&outputSpan)
    }
}

// MARK: - Edit

extension RigidBytes {
    mutating func edit<E, R: ~Copyable>(
        _ body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: _pointer, count: _capacity)
        var span = unsafe OutputRawSpan(buffer: buffer, initializedCount: count)
        defer {
            _count = unsafe span.finalize(for: buffer)
            span = OutputRawSpan()
        }
        return try body(&span)
    }
}

// MARK: - Insert

extension RigidBytes {
    mutating func insert(_ byte: UInt8, at index: Int) {
        precondition(index >= 0 && index <= count, "Index out of bounds")
        precondition(!isFull, "RigidBytes capacity overflow")
        _adjustGap(unsafe Range(uncheckedBounds: (index, index)), to: 1)
        unsafe _pointer(at: index).storeBytes(of: byte, as: UInt8.self)
    }

    mutating func insert(copying bytes: RawSpan, at index: Int) {
        precondition(index >= 0 && index <= count, "Index out of bounds")
        let newBytes = bytes.byteCount
        guard newBytes > 0 else { return }

        precondition(newBytes <= freeCapacity, "RigidBytes capacity overflow")
        _adjustGap(unsafe Range(uncheckedBounds: (index, index)), to: newBytes)
        bytes.withUnsafeBytes { buffer in
            unsafe _pointer(at: index).copyMemory(
                    from: buffer.baseAddress.unsafelyUnwrapped,
                    byteCount: newBytes
                )
        }
    }

    mutating func insert<E, R: ~Copyable>(
        addingCount count: Int,
        at index: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> R
    ) throws(E) -> R {
        precondition(index >= 0 && index <= self.count, "Index out of bounds")
        precondition(count >= 0, "Negative count")
        precondition(count <= freeCapacity, "RigidBytes capacity overflow")
        _adjustGap(unsafe Range(uncheckedBounds: (index, index)), to: count)
        let insertionBuffer = unsafe UnsafeMutableRawBufferPointer(
            start: _pointer?.advanced(by: index),
            count: count
        )
        var outputSpan = unsafe OutputRawSpan(
            buffer: insertionBuffer,
            initializedCount: 0
        )
        defer {
            let initialized = unsafe outputSpan.finalize(for: insertionBuffer)
            precondition(initialized == count, "Inserted fewer bytes than expected")
            outputSpan = OutputRawSpan()
        }
        return try body(&outputSpan)
    }
}

// MARK: - Removal

extension RigidBytes {
    @discardableResult
    mutating func remove(at index: Int) -> UInt8 {
        precondition(index >= 0 && index < self.count, "Index out of bounds")
        defer {
            _adjustGap(unsafe Range(uncheckedBounds: (index, index &+ 1)), to: 0)
        }
        return unsafe _pointer(at: index).load(as: UInt8.self)
    }

    mutating func removeAll() {
        _count = 0
    }

    @discardableResult
    mutating func removeLast() -> UInt8 {
        precondition(!isEmpty, "Index out of bounds")
        _count &-= 1
        return unsafe _pointer(at: count).load(as: UInt8.self)
    }

    mutating func removeLast(_ n: Int) {
        precondition(n >= 0 && n <= count, "Index out of bounds")
        _count &-= n
    }

    mutating func popLast() -> UInt8? {
        if isEmpty { return nil }
        return removeLast()
    }

    mutating func removeSubrange(_ range: some RangeExpression<Int>) {
        let _range = range.relative(to: unsafe Range(uncheckedBounds: (0, count)))
        precondition(_range.startIndex >= 0 && _range.endIndex <= count, "Index out of bounds")
        _adjustGap(_range, to: 0)
    }
}

// MARK: - Replace Subrange

extension RigidBytes {
    mutating func replaceSubrange<E>(
        _ subrange: Range<Int>,
        addingCount count: Int,
        initializingWith body: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) -> Void {
        precondition(count >= 0, "Cannot add a negative number of bytes")
        _adjustGap(subrange, to: count)
        let buffer = unsafe UnsafeMutableRawBufferPointer(start: _pointer?.advanced(by: subrange.lowerBound), count: count)
        var outputSpan = unsafe OutputRawSpan(buffer: buffer, initializedCount: 0)
        defer {
            let initializedCount = unsafe outputSpan.finalize(for: buffer)
            outputSpan = OutputRawSpan()
            let shift = buffer.count &- initializedCount
            if shift > 0 {
                let initializedEnd = subrange.lowerBound &+ initializedCount
                let uninitializedRange = unsafe Range(uncheckedBounds: (
                    initializedEnd,
                    initializedEnd &+ shift
                ))
                _adjustGap(uninitializedRange, to: 0)
            }
        }
        try body(&outputSpan)
    }

    mutating func replaceSubrange(
        _ range: Range<Int>, copying span: RawSpan
    ) {
        let byteCount = span.byteCount
        _adjustGap(range, to: byteCount)

        if byteCount > 0 {
            unsafe span.withUnsafeBytes { buffer in
                unsafe _pointer(at: range.lowerBound)
                    .copyMemory(from: buffer.baseAddress.unsafelyUnwrapped, byteCount: byteCount)
            }
        }
    }
}

extension RigidBytes {
    internal mutating func _adjustGap(
        _ range: Range<Int>, to newCount: Int
    ) {
        assert(newCount >= 0)
        precondition(range.lowerBound >= 0 && range.upperBound <= count,
                                  "Index out of bounds")
        
        let shift = newCount - range.count
        precondition(shift <= freeCapacity, "RigidBytes capacity overflow")
        if shift != 0 && range.upperBound < count {
            let source = unsafe _pointer(at: range.upperBound)
            let dest = unsafe source.advanced(by: shift)
            unsafe dest.copyMemory(from: source, byteCount: count &- range.upperBound)
        }
        _count &+= shift
    }
}

// MARK: - Resetting

extension RigidBytes {
    mutating func resetBytes(in range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "Index out of bounds")
        guard !range.isEmpty else { return }
        unsafe _pointer(at: range.lowerBound)
            .initializeMemory(as: UInt8.self, repeating: 0, count: range.count)
    }
}
