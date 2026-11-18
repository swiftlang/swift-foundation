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

#if FOUNDATION_FRAMEWORK

internal import Synchronization
internal import _ForSwiftFoundation

/// Shared among all registrars in a process
fileprivate let immortalNameCache = ImmortalNameCache<1024>()

/// Lock-free cache of hashes for immortal names.
/// 
/// Saves time by avoiding a full string hash and ObjC message send.
/// No collision handling for reasons of performance. This matters in less than 5% of cases in a realistic sample.
///
/// Uses Atomic<WordPair> to avoid locking.
internal struct ImmortalNameCache<let capacity: Int>: ~Copyable, Sendable {
    private let slots: InlineArray<capacity, Atomic<WordPair>> // WordPair is (pointer, hash)
    
    init() {
        assert(capacity > 0 && capacity & (capacity - 1) == 0, "capacity must be a power of two") // required for Fibonacci hashing
        slots = InlineArray { _ in
            Atomic(WordPair(first: 0, second: 0))
        }
    }
    
    @inline(__always)
    private func slot(_ p: UnsafeRawPointer) -> Int {
        fibonacciIndex(UInt64(UInt(bitPattern: p)), count: capacity)
    }
    
    func lookup(_ p: UnsafeRawPointer) -> Int? {
        let e = slots[slot(p)].load(ordering: .relaxed)
        return e.first == UInt(bitPattern: p) ? Int(bitPattern: e.second) : nil
    }
    
    func insert(_ p: UnsafeRawPointer, hash: Int) {
        slots[slot(p)].store(WordPair(first: UInt(bitPattern: p), second: UInt(bitPattern: hash)), ordering: .relaxed)
    }
}

extension ImmortalNameCache {
    // Returns name hash from the cache if any, and inserts missing immortal strings.
    // Note: Swift string literals can hit too in certain cases such as a short ASCII literal (NSTaggedPointerString) or an ASCII string with 16 bytes or more (NSIndirectTaggedPointerString).
    @inline(__always)
    func nameHash(for name: NSString) -> Int {
        let ptr = UnsafeRawPointer(Unmanaged.passUnretained(name).toOpaque())
        if let h = lookup(ptr) { return h }
        let h = name.hash
        if _isImmortalString(ptr) { insert(ptr, hash: h) }
        return h
    }
}

@inline(__always)
internal func _notificationNameHashFor(_ name: NSString) -> Int {
    immortalNameCache.nameHash(for: name)
}

@inline(__always)
internal func _notificationNameHashFor(_ name: NSString?) -> Int? {
    guard let name else { return nil }
    return _notificationNameHashFor(name) as Int
}

#endif
