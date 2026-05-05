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
package import Synchronization

extension Mutex where Value : Sendable {
    private struct LockResult<T: ~Copyable, V: ~Copyable>: ~Copyable {
        let bodyResult: T
        let extendedValue: V
    }

    package func withLockExtendingLifetimeOfState<Result: ~Copyable, E>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        let result = try self.withLock { value throws(E) in
            let copyToExtend = value
            return LockResult(
                bodyResult: try body(&value),
                extendedValue: copyToExtend
            )
        }
        // Ensure that the original state value outlives the lifetime of the locked closure
        // This guarantees that any contents no longer retained by the state will be deallocated while the lock is not held
        // Holding the value beyond the scope of the lock requires that the value is Copyable and Sendable (since a copy must be held while the caller mutates the state and the copy must be accessed - to potentially deallocate it - outside of the lock scope)
        _fixLifetime(result.extendedValue)
        return result.bodyResult
    }
}
