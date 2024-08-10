//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(os)
internal import os
#if FOUNDATION_FRAMEWORK && canImport(C.os.lock)
internal import C.os.lock
#endif
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

package struct LockedState<State> {

    // Internal implementation for a cheap lock to aid sharing code across platforms
    private struct _Lock {
#if canImport(os)
        typealias Primitive = os_unfair_lock
#elseif canImport(Bionic) || canImport(Glibc) || canImport(Musl)
        typealias Primitive = pthread_mutex_t
#elseif canImport(WinSDK)
        typealias Primitive = SRWLOCK
#elseif os(WASI)
        // WASI is single-threaded, so we don't need a lock.
        typealias Primitive = Void
#endif

        typealias PlatformLock = UnsafeMutablePointer<Primitive>
        var _platformLock: PlatformLock

        fileprivate static func initialize(_ platformLock: PlatformLock) {
#if canImport(os)
            platformLock.initialize(to: os_unfair_lock())
#elseif canImport(Bionic) || canImport(Glibc)
            pthread_mutex_init(platformLock, nil)
#elseif canImport(WinSDK)
            InitializeSRWLock(platformLock)
#elseif os(WASI)
            // no-op
#endif
        }

        fileprivate static func deinitialize(_ platformLock: PlatformLock) {
#if canImport(Bionic) || canImport(Glibc)
            pthread_mutex_destroy(platformLock)
#endif
            platformLock.deinitialize(count: 1)
        }

        static fileprivate func lock(_ platformLock: PlatformLock) {
#if canImport(os)
            os_unfair_lock_lock(platformLock)
#elseif canImport(Bionic) || canImport(Glibc)
            pthread_mutex_lock(platformLock)
#elseif canImport(WinSDK)
            AcquireSRWLockExclusive(platformLock)
#elseif os(WASI)
            // no-op
#endif
        }

        static fileprivate func unlock(_ platformLock: PlatformLock) {
#if canImport(os)
            os_unfair_lock_unlock(platformLock)
#elseif canImport(Bionic) || canImport(Glibc)
            pthread_mutex_unlock(platformLock)
#elseif canImport(WinSDK)
            ReleaseSRWLockExclusive(platformLock)
#elseif os(WASI)
            // no-op
#endif
        }
    }

    private class _Buffer: ManagedBuffer<State, _Lock.Primitive> {
        deinit {
            withUnsafeMutablePointerToElements {
                _Lock.deinitialize($0)
            }
        }
    }

    private let _buffer: ManagedBuffer<State, _Lock.Primitive>

    package init(initialState: State) {
        _buffer = _Buffer.create(minimumCapacity: 1, makingHeaderWith: { buf in
            buf.withUnsafeMutablePointerToElements {
                _Lock.initialize($0)
            }
            return initialState
        })
    }

    package func withLock<T>(_ body: @Sendable (inout State) throws -> T) rethrows -> T {
        try withLockUnchecked(body)
    }
    
    package func withLockUnchecked<T>(_ body: (inout State) throws -> T) rethrows -> T {
        try _buffer.withUnsafeMutablePointers { state, lock in
            _Lock.lock(lock)
            defer { _Lock.unlock(lock) }
            return try body(&state.pointee)
        }
    }

    // Ensures the managed state outlives the locked scope.
    package func withLockExtendingLifetimeOfState<T>(_ body: @Sendable (inout State) throws -> T) rethrows -> T {
        try _buffer.withUnsafeMutablePointers { state, lock in
            _Lock.lock(lock)
            return try withExtendedLifetime(state.pointee) {
                defer { _Lock.unlock(lock) }
                return try body(&state.pointee)
            }
        }
    }
}

extension LockedState where State == Void {
    package init() {
        self.init(initialState: ())
    }

    package func withLock<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R {
        return try withLock { _ in
            try body()
        }
    }

    package func lock() {
        _buffer.withUnsafeMutablePointerToElements { lock in
            _Lock.lock(lock)
        }
    }

    package func unlock() {
        _buffer.withUnsafeMutablePointerToElements { lock in
            _Lock.unlock(lock)
        }
    }
}

extension LockedState: @unchecked Sendable where State: Sendable {}
