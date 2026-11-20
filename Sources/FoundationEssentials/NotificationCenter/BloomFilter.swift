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

internal import Synchronization

// A bloom filter is a probabilistic data structure designed to quickly check for element existence.
//
// The filter can indicate whether an element *might be present* or is *definitely not present*. As the filter fills up, the false positive rate increases but the filter never delivers false negatives. Bloom filters are useful in avoiding expensive operations by quickly determining if an element is not present.
//
// The filter operates by:
//   1. Maintaining a contiguous bit field of a user-supplied size. For a given storage size (e.g. 4096 bits), the number of bits required to represent any bit position is calculated as `chunkSize` (e.g. 12 bits for a 4096 bit storage; 2^12 = 4096).
//   2. When an element is inserted, it is divided into chunks of size `chunkSize` (e.g. for a 64-bit input value with a 4096 bit storage, 5 chunks would be available, plus extra). Each chunk is interpreted as a number representing a bit in the filter's storage and is turned on.
//   3. When the filter is asked whether it might contain an element, it checks whether all the necessary bits in its storage are on. This indicates that the element might have been inserted but may give a false positive due to bit collisions. However, if any of the necessary bits are not on, the filter can definitively say the element was not inserted.
//
// Bloom filters do not support removal and must be rebuilt if necessary, e.g. false positive rate goes too high.
//
// InlineBloomFilter uses Atomic to avoid needing a lock for reading.
//
// wordCount is the size of the filter expressed in words
internal struct InlineBloomFilter<let wordCount: Int>: ~Copyable, Sendable {
    // Storage for the filter
    private let storage: InlineArray<wordCount, Atomic<UInt>>
    // Number of inserts since the last rebuild
    let insertCount = Atomic<Int>(0)

    // Size of each chunk equals the number of bits needed to address any bit position in the filter
    private static var chunkSize: Int { (wordCount * UInt.bitWidth).trailingZeroBitCount }
    // Number of chunks used for each input value
    private static var chunksPerInsert: Int { Int.bitWidth / chunkSize }

    init() {
        assert(wordCount > 0 && (wordCount & (wordCount - 1) == 0), "wordCount must be a power of two")
        storage = InlineArray { _ in Atomic(0) }
    }

    /// Provides the location of a bit in `storage` for the given `hash` and `chunkIndex`
    /// - Parameters:
    ///   - hash: the input hash
    ///   - chunkIndex: the desired chunk
    /// - Returns: index into `storage` containing the given bit and `bitMask` to access it
    @inline(__always)
    private static func location(_ hash: Int, chunkIndex: Int) -> (storageIndex: Int, bitMask: UInt) {
        let chunk = Int(truncatingIfNeeded: UInt(bitPattern: hash) &>> UInt(chunkIndex * chunkSize)) & (wordCount * UInt.bitWidth - 1)
        return (chunk &>> UInt.bitWidth.trailingZeroBitCount, 1 &<< UInt(chunk & (UInt.bitWidth - 1)))
    }

    /// Inserts `hash` into the filter by setting the appropriate bits. Caller is responsible for ensuring `rebuild` is not running.
    func insert(hash: Int) {
        for chunkIdx in 0..<Self.chunksPerInsert {
            let (storageIdx, bitMask) = Self.location(hash, chunkIndex: chunkIdx)
            storage[storageIdx].bitwiseOr(bitMask, ordering: .relaxed)
        }
        insertCount.wrappingAdd(1, ordering: .relaxed)
    }

    /// Returns `true` if `hash` might be in the filter or `false` if it definitely is not.
    func mightContain(hash: Int) -> Bool {
        for chunkIdx in 0..<Self.chunksPerInsert {
            let (storageIdx, bitMask) = Self.location(hash, chunkIndex: chunkIdx)
            if storage[storageIdx].load(ordering: .relaxed) & bitMask == 0 { return false }
        }
        return true
    }

    /// Rebuild the filter using `hashes`. Must not run concurrently with `insert`.
    func rebuild(fromHashes hashes: some Sequence<Int>) {
        var newStorage = InlineArray<wordCount, UInt>(repeating: 0)
        var newInsertCount = 0
        
        // Compute the new filter storage and count
        for hash in hashes {
            for chunkIdx in 0..<Self.chunksPerInsert {
                let (storageIdx, bitMask) = Self.location(hash, chunkIndex: chunkIdx)
                newStorage[storageIdx] |= bitMask
            }
            newInsertCount += 1
        }
        
        // Store the new state
        for word in 0..<wordCount {
            storage[word].store(newStorage[word], ordering: .relaxed)
        }
        insertCount.store(newInsertCount, ordering: .relaxed)
    }
}
