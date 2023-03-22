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

#if canImport(Darwin)
@_implementationOnly import os
#elseif canImport(Glibc)
import Glibc
#endif

internal struct LockedState<State> {

    // Internal implementation for a cheap lock to aid sharing code across platforms
    private struct _Lock {
#if canImport(Darwin)
        typealias Primitive = os_unfair_lock
#elseif canImport(Glibc)
        typealias Primitive = pthread_mutex_t
#endif

        typealias PlatformLock = UnsafeMutablePointer<Primitive>
        var _platformLock: PlatformLock

        fileprivate static func initialize(_ platformLock: PlatformLock) {
#if canImport(Darwin)
            platformLock.initialize(to: os_unfair_lock())
#elseif canImport(Glibc)
            pthread_mutex_init(platformLock, nil)
#endif
        }

        fileprivate static func deinitialize(_ platformLock: PlatformLock) {
#if canImport(Glibc)
            pthread_mutex_destroy(platformLock)
#endif
            platformLock.deinitialize(count: 1)
        }

        static fileprivate func lock(_ platformLock: PlatformLock) {
#if canImport(Darwin)
            os_unfair_lock_lock(platformLock)
#elseif canImport(Glibc)
            pthread_mutex_lock(platformLock)
#endif
        }

        static fileprivate func unlock(_ platformLock: PlatformLock) {
#if canImport(Darwin)
            os_unfair_lock_unlock(platformLock)
#elseif canImport(Glibc)
            pthread_mutex_unlock(platformLock)
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

    init(initialState: State) {
        _buffer = _Buffer.create(minimumCapacity: 1, makingHeaderWith: { buf in
            buf.withUnsafeMutablePointerToElements {
                _Lock.initialize($0)
            }
            return initialState
        })
    }

    func withLock<T>(_ body: @Sendable (inout State) throws -> T) rethrows -> T {
        try withLockUnchecked(body)
    }
    
    func withLockUnchecked<T>(_ body: (inout State) throws -> T) rethrows -> T {
        try _buffer.withUnsafeMutablePointers { state, lock in
            _Lock.lock(lock)
            defer { _Lock.unlock(lock) }
            return try body(&state.pointee)
        }
    }

    // Ensures the managed state outlives the locked `body`.
    func withLockExtendingLifetimeOfState<T>(_ body: @Sendable (inout State) throws -> T) rethrows -> T {
        try _buffer.withUnsafeMutablePointers { state, lock in
            _Lock.lock(lock)
            return try withExtendedLifetime(state.pointee) {
                let result = try body(&state.pointee)
                _Lock.unlock(lock)
                return result
            }
        }
    }
}

extension LockedState where State == Void {
    init() {
        self.init(initialState: ())
    }

    func withLock<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R {
        return try withLock { _ in
            try body()
        }
    }

    func lock() {
        _buffer.withUnsafeMutablePointerToElements { lock in
            _Lock.lock(lock)
        }
    }

    func unlock() {
        _buffer.withUnsafeMutablePointerToElements { lock in
            _Lock.unlock(lock)
        }
    }
}

extension LockedState: @unchecked Sendable where State: Sendable {}
