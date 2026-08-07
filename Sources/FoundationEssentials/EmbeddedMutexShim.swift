//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

// Embedded Swift does not (yet) provide `Mutex` from the Synchronization module
// (only `Atomic` is available). Embedded Swift is also single-threaded, so a real
// lock is unnecessary. This shim provides a source-compatible `Mutex` with the
// same API surface used across FoundationEssentials (`init`, `withLock`,
// `withLockIfAvailable`, and — via Mutex+ExtendedLifetime.swift —
// `withLockExtendingLifetimeOfState`) backed by plain interior-mutable storage.
//
// Keeping this as a drop-in replacement means the numerous `Mutex`-based caches
// and helpers compile unchanged under Embedded, avoiding `#if` fracturing at
// every call site.
#if $Embedded

package struct Mutex<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
    // Class box provides the interior mutability that the real `Mutex` offers
    // through its lock; safe here because Embedded Swift is single-threaded.
    private final class _Box {
        var value: Value
        init(_ value: consuming Value) { self.value = value }
    }

    private let _box: _Box

    package init(_ initialValue: consuming sending Value) {
        _box = _Box(initialValue)
    }

    package borrowing func withLock<Result: ~Copyable, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        try body(&_box.value)
    }

    package borrowing func withLockIfAvailable<Result: ~Copyable, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result? {
        try body(&_box.value)
    }
}

#endif // $Embedded
