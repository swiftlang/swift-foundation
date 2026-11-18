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

// MARK: - SlotMap

/// SlotMap is a contiguous block of memory storing E.
/// 
/// Each stored E is represented by a Token given to the caller. This token can be used to quickly remove E from memory as well as validate that E is still present.
/// 
/// A `vacant` value is required to avoid the use of Optional, which costs memory and isn't necessary.
internal struct SlotMap<E> {
    private var elements: ContiguousArray<E> = []
    // `generations` is split from `elements` so a token can be validated loading elements
    // A value of zero for `generation` indicates an empty slot
    private var generations: ContiguousArray<Token.Generation> = []
    private var freeList: ContiguousArray<Token.Index> = []
    private var nextGeneration: Token.Generation = 1 // 0 is the empty sentinel
    private var occupiedCount: Int = 0
    private let vacant: E // we need some value to set for an empty slot to avoid Optional
    
    subscript(index index: Token.Index) -> E {
        _read { yield elements[Int(index.rawValue)] }
        _modify { yield &elements[Int(index.rawValue)] }
    }
    
    init(vacant: E) {
        self.vacant = vacant
    }
    
    // Token value that will be provided by the next insert() call
    var nextToken: Token {
        Token(index: freeList.last ?? Token.Index(rawValue: UInt32(generations.count)), generation: nextGeneration)
    }
    
    mutating func insert(_ element: E) -> Token {
        let generation = nextGeneration
        
        nextGeneration &+= 1
        
        if nextGeneration == 0 { nextGeneration = 1 } // do not hand out the empty sentinel
        
        let index: Token.Index
        if let reused = freeList.popLast() {
            index = reused
            generations[Int(index.rawValue)] = generation
            elements[Int(index.rawValue)] = element
        } else {
            index = Token.Index(rawValue: UInt32(generations.count))
            
            if elements.count == elements.capacity {
                let newCapacity = SlotMap<E>.nextCapacity(after: elements.capacity)
                generations.reserveCapacity(newCapacity)
                elements.reserveCapacity(newCapacity)
            }
            
            generations.append(generation)
            elements.append(element)
        }
        
        occupiedCount += 1
        
        return Token(index: index, generation: generation)
    }
    
    @discardableResult
    mutating func remove(_ token: Token) -> E? {
        let i = Int(token.index.rawValue)
        guard i < generations.count, generations[i] == token.generation else { return nil }
        
        var removed = vacant
        swap(&removed, &elements[i])
        generations[i] = 0
        freeList.append(token.index)
        occupiedCount -= 1
        
        return removed
    }
    
    func forEach(_ body: (Token, borrowing E) -> Void) {
        for i in generations.indices where generations[i] != 0 {
            body(Token(index: Token.Index(rawValue: UInt32(i)), generation: generations[i]), elements[i])
        }
    }
    
    func contains(_ token: Token) -> Bool {
        let i = Int(token.index.rawValue)
        return i < generations.count && generations[i] == token.generation
    }
    
    func token(at index: Token.Index) -> Token {
        Token(index: index, generation: generations[Int(index.rawValue)])
    }
    
    private static func nextCapacity(after capacity: Int) -> Int {
        Swift.max(16, capacity + capacity / 16) // grow by 1/16th instead of Swift's 2x
    }
    
    var isEmpty: Bool { occupiedCount == 0 }
    var count: Int { occupiedCount }
    var capacity: Int { elements.capacity }
}

internal struct Token: RawRepresentable, Equatable, Sendable {
    typealias Generation = UInt32
    
    let rawValue: UInt64
    
    // Lower 32 bits of rawValue
    var index: Index { Index(rawValue: UInt32(truncatingIfNeeded: rawValue)) }
    // Upper 32 bits of rawValue
    var generation: Generation { UInt32(rawValue >> 32) }

    static var empty: Self { Token(.max) }
    
    init(index: Index, generation: Generation) {
        self.rawValue = (UInt64(generation) << 32) | UInt64(index.rawValue)
    }
    
    init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    init?(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    struct Index: Equatable {
        let rawValue: UInt32
        static var noIndex: Index { Index(rawValue: .max) }
    }
}

// MARK: - SlotMapList

// A single pair of links for an intrusive linked list through a SlotMap. A SlotMap's `Element` can have multiple pairs for multiple lists.
internal struct SlotListLinkPair {
    var previous: Token.Index = .noIndex
    var next: Token.Index = .noIndex
}

// Describes where in `Element` a SlotListLinkPair lives
internal protocol SlotListLinkage {
    associatedtype Element
    
    static var linkPair: WritableKeyPath<Element, SlotListLinkPair> { get }
}

// A doubly-linked list through a SlotMap's elements, with prev/next described by SlotListLinkage
internal struct SlotMapList<Linkage: SlotListLinkage> {
    fileprivate(set) var head: Token.Index = .noIndex
    
    var isEmpty: Bool { head == .noIndex }
}

extension SlotMap {
    func next<Linkage>(after index: Token.Index, in list: SlotMapList<Linkage>) -> Token.Index where Linkage.Element == E {
        self[index: index][keyPath: Linkage.linkPair].next
    }
    
    // Puts an element at the head of the list
    mutating func link<Linkage>(_ index: Token.Index, into list: inout SlotMapList<Linkage>) where Linkage.Element == E {
        self[index: index][keyPath: Linkage.linkPair] = SlotListLinkPair(previous: .noIndex, next: list.head)
        
        if list.head != .noIndex {
            self[index: list.head][keyPath: Linkage.linkPair].previous = index
        }
        
        list.head = index
    }
    
    // `removed` is assumed to still have valid links
    mutating func unlink<Linkage>(_ removed: E, from list: inout SlotMapList<Linkage>) where Linkage.Element == E {
        let links = removed[keyPath: Linkage.linkPair]
        
        if links.previous != .noIndex {
            self[index: links.previous][keyPath: Linkage.linkPair].next = links.next
        } else {
            list.head = links.next
        }
        
        if links.next != .noIndex {
            self[index: links.next][keyPath: Linkage.linkPair].previous = links.previous
        }
    }
}

#endif
