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

extension Bytes {
    @inline(__always)
    package var capacity: Int {
        self._storage.capacity
    }

    @inline(__always)
    package var freeCapacity: Int {
        self._storage.freeCapacity
    }

    @inline(__always)
    package var count: Int {
        self._storage.count
    }

    @inline(__always)
    package var isEmpty: Bool {
        self._storage.isEmpty
    }
}

extension Bytes {
    package var bytes: RawSpan {
        @_lifetime(borrow self)
        @inline(__always)
        get {
            self._storage.bytes
        }
    }

    package var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inline(__always)
        get {
            self._storage.span
        }
    }

    // Unlike the other variables, use a function to workaround the problem of vending a mutable computed property when library evolution is enabled.
    @_lifetime(&self)
    @inline(__always)
    package mutating func mutableBytes() -> MutableRawSpan {
        self._storage.mutableBytes
    }

    // Unlike the other variables, use a function to workaround the problem of vending a mutable computed property when library evolution is enabled.
    @_lifetime(&self)
    @inline(__always)
    package mutating func mutableSpan() -> MutableSpan<UInt8> {
        self._storage.mutableSpan
    }
}
