//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WinSDK)
import WinSDK
#elseif canImport(threads_h)
internal import threads_h
#elseif canImport(threads)
internal import threads
#endif

struct _ThreadLocal {
#if canImport(Darwin) || canImport(Glibc)
    fileprivate typealias PlatformKey = pthread_key_t
#elseif USE_TSS
    fileprivate typealias PlatformKey = tss_t
#elseif canImport(WinSDK)
    fileprivate typealias PlatformKey = DWORD
#endif
    
    struct Key<Value> {
        fileprivate let key: PlatformKey
        
        init() {
#if canImport(Darwin) || canImport(Glibc)
            var key = PlatformKey()
            pthread_key_create(&key, nil)
            self.key = key
#elseif USE_TSS
            var key = PlatformKey()
            tss_create(&key, nil)
            self.key = key
#elseif canImport(WinSDK)
            key = FlsAlloc(nil)
#endif
        }
    }
    
    private static subscript(_ key: PlatformKey) -> UnsafeMutableRawPointer? {
        get {
#if canImport(Darwin) || canImport(Glibc)
            pthread_getspecific(key)
#elseif USE_TSS
            tss_get(key)
#elseif canImport(WinSDK)
            FlsGetValue(key)
#endif
        }
        
        set {
#if canImport(Darwin) || canImport(Glibc)
            pthread_setspecific(key, newValue)
#elseif USE_TSS
            tss_set(key, newValue)
#elseif canImport(WinSDK)
            FlsSetValue(key, newValue)
#endif
        }
    }
    
    static subscript<Value>(_ key: Key<Value>) -> Value? {
        self[key.key]?.load(as: Value.self)
    }
    
    static func withValue<Value, R>(_ value: inout Value, for key: Key<Value>, _ block: () throws -> R) rethrows -> R {
        precondition(Self[key.key] == nil, "Not allowed to set the value for a key within the subscope of that key")
        return try withUnsafeMutablePointer(to: &value) {
            Self[key.key] = UnsafeMutableRawPointer($0)
            defer { Self[key.key] = nil }
            return try block()
        }
    }
}
