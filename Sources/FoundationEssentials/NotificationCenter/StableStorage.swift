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

// This type supports `NotificationRegistrar`, which is not yet available in embedded mode.
#if !hasFeature(Embedded)

/// Provides storage for `Element` that does not move when growing.
///
/// `StableStorage` uses fixed chunks of storage as needed. Free space in an existing chunk is used when available instead of making a new allocation.
/// 
/// Useful for storing elements which are expensive to move, e.g. Objective-C weak references.
internal struct StableStorage<Element>: ~Copyable {
    private var chunks: ContiguousArray<UnsafeMutablePointer<Element>> = []
    
    // Number of elements per chunk (power of two recommended)
    private static var chunkSize: Int { 64 }
    private(set) var initializedCount: UInt32 = 0
    private var freeIndices: ContiguousArray<Index> = []
    private let vacant: Element

    struct Index: RawRepresentable, Equatable {
        let rawValue: UInt32
        
        // Element's location in the chunks
        var location: (chunk: Int, offset: Int) {
            let (chunk, offset) = Int(rawValue).quotientAndRemainder(dividingBy: StableStorage.chunkSize)
            return (chunk, offset)
        }
    }
    
    init(vacant: Element) {
        self.vacant = vacant
    }
    
    deinit {
        for i in 0..<initializedCount {
            pointer(Index(rawValue: i)).deinitialize(count: 1)
        }

        for chunk in chunks { chunk.deallocate() }
    }
    
    func pointer(_ index: Index) -> UnsafeMutablePointer<Element> {
        let (chunk, offset) = index.location
        return chunks[chunk] + offset
    }
    
    // Uses a freed index, unused chunk space, or allocates a new chunk
    // Caller needs to set fields appropriately as memory may hold a previously freed element's values
    mutating func allocate() -> Index {
        if let reused = freeIndices.popLast() { return reused }
        
        let index = Index(rawValue: initializedCount)
        
        if Int(initializedCount) % Self.chunkSize == 0 {
            chunks.append(.allocate(capacity: Self.chunkSize))
        }
        
        pointer(index).initialize(to: vacant)
        initializedCount += 1
        
        return index
    }
    
    mutating func free(_ index: Index) {
        freeIndices.append(index)
    }
}

#endif
