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

/// IntrusiveHashTable provides a hash table which handles collisions using a linked list that is stored (intrudes) on user-supplied storage.

#if FOUNDATION_FRAMEWORK

// Hash table which handles collisions using a linked list stored (intruding) inside the elements themselves.
internal protocol IntrusiveHashTable<Entry>: ~Copyable {
    associatedtype Entry: IntrusiveHashEntry
    associatedtype Index: RawRepresentable<UInt32>, Equatable
    
    static var maxLoad: Int { get } // load factor which determines growth
    var heads: ContiguousArray<Index> { get set }
    var count: Int { get set }

    func key(at index: Index) -> Entry.Key
    subscript(next index: Index) -> Index { get set }
}

extension IntrusiveHashTable where Self: ~Copyable {
    @inline(__always) private func head(_ hash: UInt64) -> Int { fibonacciIndex(hash, count: heads.count) }
    @inline(__always) private func head(at index: Index) -> Int { head(Entry.hash(key(at: index))) }
    @inline(__always) static var end: Index { Index(rawValue: .max)! }
    
    @inline(__always) func find(_ key: Entry.Key) -> Index? {
        guard !heads.isEmpty else { return nil }
        
        var index = heads[head(Entry.hash(key))]
        while index != Self.end {
            if self.key(at: index) == key { return index }
            index = self[next: index]
        }
        
        return nil
    }
    
    mutating func link(_ index: Index) {
        assert(index.rawValue != .max, ".max is reserved to indicate the end of a chain")
        
        count += 1
        if count > Self.maxLoad * heads.count { grow() }
        chain(index)
    }
    
    mutating func unlink(_ index: Index) {
        let h = head(at: index)
        let next = self[next: index]
        
        if heads[h] == index {
            heads[h] = next
        } else {
            var previous = heads[h]
            while self[next: previous] != index {
                previous = self[next: previous]
            }
            self[next: previous] = next
        }
        
        count -= 1
    }
    
    private mutating func chain(_ index: Index) {
        let h = head(at: index)
        self[next: index] = heads[h]
        heads[h] = index
    }
    
    // Grows hash table `heads` and rehashes all elements accordingly
    private mutating func grow() {
        let old = heads
        heads = ContiguousArray(repeating: Self.end, count: Swift.max(old.count * 2, 8))

        // Walk each chain and rehash into the new `heads`
        for first in old {
            var index = first
            while index != Self.end {
                let next = self[next: index]
                chain(index)
                index = next
            }
        }
    }
}

internal protocol IntrusiveHashEntry {
    associatedtype Key: Equatable
    
    static func hash(_ key: Key) -> UInt64
}

#endif
