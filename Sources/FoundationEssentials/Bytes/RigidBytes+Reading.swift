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

extension RigidBytes {
    @inline(__always)
    var capacity: Int {
        _assumeNonNegative(self._capacity)
    }

    @inline(__always)
    var freeCapacity: Int {
        _assumeNonNegative(self._capacity &- count)
    }

    @inline(__always)
    var count: Int {
        _assumeNonNegative(self._count)
    }
    
    @inline(__always)
    var isEmpty: Bool {
        self.count == 0
    }

    @inline(__always)
    var isFull: Bool {
        count == capacity
    }
}

extension RigidBytes {
    var bytes: RawSpan {
        @_lifetime(borrow self)
        get {
            if let pointer = unsafe _pointer {
                let result = unsafe RawSpan(_unsafeStart: pointer, byteCount: count)
                return unsafe _overrideLifetime(result, borrowing: self)
            } else {
                return unsafe _overrideLifetime(RawSpan(), borrowing: self)
            }

        }
    }

    var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inline(always)
        get {
            unsafe bytes._unsafeView(as: UInt8.self)
        }
    }

    var mutableBytes: MutableRawSpan {
        @_lifetime(&self)
        mutating get {
            if let pointer = unsafe _pointer {
                let result = unsafe MutableRawSpan(_unsafeStart: pointer, byteCount: count)
                return unsafe _overrideLifetime(result, mutating: &self)
            } else {
                return unsafe _overrideLifetime(MutableRawSpan(), mutating: &self)
            }
        }
    }

    var mutableSpan: MutableSpan<UInt8> {
        @_lifetime(&self)
        mutating get {
            if let pointer = unsafe _pointer {
                let result = unsafe MutableSpan<UInt8>(_unsafeStart: pointer, byteCount: count)
                return unsafe _overrideLifetime(result, mutating: &self)
            } else {
                return unsafe _overrideLifetime(MutableSpan(), mutating: &self)
            }
        }
    }
}
