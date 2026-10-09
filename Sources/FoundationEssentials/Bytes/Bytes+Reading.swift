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
    var capacity: Int {
        self._storage.capacity
    }

    @inline(__always)
    var freeCapacity: Int {
        self._storage.freeCapacity
    }

    @inline(__always)
    var count: Int {
        self._storage.count
    }

    @inline(__always)
    var isEmpty: Bool {
        self._storage.isEmpty
    }
}

extension Bytes {
    var bytes: RawSpan {
        @_lifetime(borrow self)
        @inline(__always)
        get {
            self._storage.bytes
        }
    }

    var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inline(__always)
        get {
            self._storage.span
        }
    }

    var mutableBytes: MutableRawSpan {
        @_lifetime(&self)
        @inline(__always)
        mutating get {
            self._storage.mutableBytes
        }
    }

    var mutableSpan: MutableSpan<UInt8> {
        @_lifetime(&self)
        @inline(__always)
        mutating get {
            self._storage.mutableSpan
        }
    }
}
