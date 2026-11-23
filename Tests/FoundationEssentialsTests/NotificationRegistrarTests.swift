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
@testable import Foundation
#else
@testable import FoundationEssentials
#endif

import Testing
import Synchronization

fileprivate func makeNotification(_ name: String) -> NotificationType {
#if FOUNDATION_FRAMEWORK
    NSNotification(name: Notification.Name(name), object: nil)
#else
    Notification(name: Notification.Name(name))
#endif
}

@Suite("NotificationRegistrar")
private struct NotificationRegistrarTests {
    @Test func nameHashCollisionDisambiguation() {
        let registrar = NotificationRegistrar()
        
        nonisolated(unsafe) var aFired = 0
        nonisolated(unsafe) var bFired = 0
        let h = 0x5EED   // one artifical hash used by two different names
        
        let a = registrar.addObserver(nameHash: h, name: "A", object: nil, queue: nil) { _ in aFired += 1 }
        let b = registrar.addObserver(nameHash: h, name: "B", object: nil, queue: nil) { _ in bFired += 1 }
        
        // Same hash, different names should not cross-deliver
        registrar.post(nameHash: h, name: "A", object: nil) { makeNotification("A") }
        #expect(aFired == 1)
        #expect(bFired == 0)
        
        registrar.post(nameHash: h, name: "B", object: nil) { makeNotification("B") }
        #expect(aFired == 1)
        #expect(bFired == 1)
        
        registrar.removeObserver(a, name: nil, object: nil)
        
        registrar.post(nameHash: h, name: "A", object: nil) { makeNotification("A") }
        registrar.post(nameHash: h, name: "B", object: nil) { makeNotification("B") }
        
        #expect(aFired == 1)
        #expect(bFired == 2) // B should still fire
        
        registrar.removeObserver(b, name: nil, object: nil)
    }
    
    private func makeReentrantBlock(_ registrar: NotificationRegistrar, onDeinit: @escaping @Sendable () -> Void) -> ObserverBlock {
        final class Sentinel: Sendable {
            let registrar: NotificationRegistrar
            let onDeinit: @Sendable () -> Void
            
            init(_ r: NotificationRegistrar, _ d: @escaping @Sendable () -> Void) {
                registrar = r
                onDeinit = d
            }
            
            deinit {
                onDeinit()
                _ = registrar.isEmpty() // isEmpty enters the registrar lock
            }
        }
        
        let sentinel = Sentinel(registrar, onDeinit)
        
        // The block strongly captures `sentinel` and will be its only owner
        return { _ in _ = sentinel }
    }
    
    @Test func tokenRemovalReleasesBlockOutsideLock() {
        nonisolated(unsafe) var deinitRan = false
        
        let registrar = NotificationRegistrar()
        
        let token = registrar.addObserver(nameHash: 1, name: "n", object: nil, using: makeReentrantBlock(registrar) { deinitRan = true })
        
        #expect(!deinitRan)
        registrar.removeObserver(token)
        #expect(deinitRan)
    }
    
    @Test func observerRemovalReleasesBlockOutsideLock() {
        nonisolated(unsafe) var deinitRan = false

        let registrar = NotificationRegistrar()

        let obs = registrar.addObserver(nameHash: 1, name: "n", object: nil, queue: nil, using: makeReentrantBlock(registrar) { deinitRan = true })

        #expect(!deinitRan)
        registrar.removeObserver(obs, name: nil, object: nil)
        #expect(deinitRan)
    }
    
    @Test func postDispatchesInRegistrationOrder() {
        for count in [4, 5, 16, 17, 40] {
            nonisolated(unsafe) var order: [Int] = []
            
            let registrar = NotificationRegistrar()
            
            let tokens = (0..<count).map { i in registrar.addObserver(nameHash: 1, name: "n", object: nil) { _ in order.append(i) } }
            post(registrar, object: nil)

            #expect(order == Array(0..<count), "\(count) observers")

            for token in tokens { registrar.removeObserver(token) }
            #expect(registrar.isEmpty())
        }
    }
    
    final class Captured: Sendable {}
    
    @Test func postReleasesDispatchedBlocks() {
        weak var weakCaptured: Captured?
        
        let registrar = NotificationRegistrar()
        
        do {
            let captured = Captured()
            
            weakCaptured = captured
            
            let tokens = (0..<20).map { _ in registrar.addObserver(nameHash: 1, name: "n", object: nil) { _ in _ = captured } }
            post(registrar, object: nil)
            for token in tokens { registrar.removeObserver(token) }
        }
        
        #expect(weakCaptured == nil)
    }
    
#if FOUNDATION_FRAMEWORK
    final class SweepObs: NSObject {
        nonisolated(unsafe) static var deinitCount = 0
        
        @objc func handle(_ n: NSNotification) {}
        
        deinit {
            SweepObs.deinitCount += 1
        }
    }
    
    @Test func sweepReclaimsDeadWeakObservers() {
        let registrar = NotificationRegistrar()
        let sel = #selector(SweepObs.handle(_:))
        
        do {
            var deadObservers = (0..<20).map { _ in SweepObs() }
            
            for o in deadObservers {
                _ = registrar.addObserver(o, selector: sel, weak: true, nameHash: 1, name: "unposted", object: nil)
            }
            
            deadObservers.removeAll()
        }
        
        #expect(SweepObs.deinitCount == 20)
        #expect(registrar._observerCount == 20)
        
        registrar._forceSweepExpiredWeak()
        
        #expect(registrar._observerCount == 0)
    }
    
    final class CountingObs: NSObject {
        var count = 0
        
        @objc func handle(_ n: NSNotification) {
            count += 1
        }
    }
    
    final class ReleasedObs: NSObject {
        nonisolated(unsafe) static var deinitCount = 0
        
        @objc func handle(_ n: NSNotification) {}
        
        deinit {
            ReleasedObs.deinitCount += 1
        }
    }
    
    @Test func postReleasesDispatchedWeakObservers() {
        ReleasedObs.deinitCount = 0
        
        let registrar = NotificationRegistrar()
        
        do {
            let observers = (0..<20).map { _ in ReleasedObs() }
            for o in observers { _ = registrar.addObserver(o, selector: #selector(ReleasedObs.handle(_:)), weak: true, nameHash: 1, name: "n", object: nil) }
            post(registrar, object: nil)
        }
        
        #expect(ReleasedObs.deinitCount == 20)
        registrar._forceSweepExpiredWeak()
        #expect(registrar.isEmpty())
    }
    
    @Test func reusedObserverEntryStartsClean() {
        let registrar = NotificationRegistrar()
        let sel = #selector(CountingObs.handle(_:))
        let removed = CountingObs(), kept = CountingObs(), reusing = CountingObs()
        
        _ = registrar.addObserver(removed, selector: sel, weak: true, nameHash: 1, name: "n", object: nil)
        _ = registrar.addObserver(kept, selector: sel, weak: true, nameHash: 1, name: "n", object: nil)
        registrar.removeObserver(removed, name: nil, object: nil) // frees its entry
        _ = registrar.addObserver(reusing, selector: sel, weak: true, nameHash: 1, name: "n", object: nil) // takes the freed entry
        
        post(registrar, object: nil)
        #expect(removed.count == 0)
        #expect(kept.count == 1)
        #expect(reusing.count == 1)
        
        registrar.removeObserver(reusing, name: nil, object: nil)
        post(registrar, object: nil)
        #expect(kept.count == 2)
        #expect(reusing.count == 1)
        
        registrar.removeObserver(kept, name: nil, object: nil)
        #expect(registrar.isEmpty())
    }
    
    @Test func blockObserverRegisteredAsItsOwnObserver() {
        weak var weakHandle: BlockObserver?
        
        let registrar = NotificationRegistrar()
        
        do {
            let handle = registrar.addObserver(nameHash: 1, name: "n", object: nil, queue: nil) { _ in }
            weakHandle = handle
            _ = registrar.addObserver(handle, selector: #selector(CountingObs.handle(_:)), weak: true, nameHash: 2, name: "unposted", object: nil)
            registrar.removeObserver(handle, name: "n", object: nil)
        }
        
        #expect(weakHandle == nil)
        #expect(registrar._observerCount == 1)
        registrar._forceSweepExpiredWeak()
        #expect(registrar.isEmpty())
    }

    @Test func observerAtReusedAddressCanBeRemoved() {
        let callback: CFNotificationCallback = { _, _, _, _, _ in }
        let address = UnsafeRawPointer(bitPattern: 0x1234)!
        
        let registrar = NotificationRegistrar()
        
        func add(weakObserver: AnyObject?) {
            _ = registrar.addObserver(address, callbackObserver: address, weakObserver: weakObserver, callback: callback, center: address, nameHash: 1, name: "n", object: nil)
        }
        
        add(weakObserver: CountingObs())       // weak observer deallocates without being removed
        add(weakObserver: nil)                 // new observer is added at the same address
        #expect(registrar._observerCount == 2)
        registrar._forceSweepExpiredWeak()
        #expect(registrar._observerCount == 1) // the sweep removed only the dead observer's registration
        
        registrar.removeObserver(address, name: nil, object: nil)
        #expect(registrar.isEmpty())
    }
#endif

    @Test func blockObserverRetainedUntilRemoved() {
        weak var weakHandle: BlockObserver?
        
        let registrar = NotificationRegistrar()
        
        do {
            weakHandle = registrar.addObserver(nameHash: 1, name: "n", object: nil, queue: nil) { _ in }
        }
        
        #expect(weakHandle != nil)
        registrar.removeObserver(weakHandle!, name: nil, object: nil)
        #expect(weakHandle == nil)
        
        #expect(registrar.isEmpty())
    }
    
    // Converting a handle to a token stops retaining the handle but keeps the registration
    @Test func convertToTokenReleasesHandleAndKeepsRegistration() {
        nonisolated(unsafe) var fired = 0
        weak var weakHandle: BlockObserver?
        let token: Token
        
        let registrar = NotificationRegistrar()
        
        do {
            let handle = registrar.addObserver(nameHash: 1, name: "n", object: nil, queue: nil) { _ in fired += 1 }
            weakHandle = handle
            token = registrar.convertToToken(handle)
        }
        
        #expect(weakHandle == nil)
        registrar.post(nameHash: 1, name: "n", object: nil) { makeNotification("n") }
        #expect(fired == 1)
        
        registrar.removeObserver(token)
        registrar.post(nameHash: 1, name: "n", object: nil) { makeNotification("n") }
        #expect(fired == 1)
        #expect(registrar.isEmpty())
    }
    
    @Test func registrarDeinitReleasesBlockObservers() {
        weak var weakHandle: BlockObserver?
        
        do {
            let registrar = NotificationRegistrar()
            
            weakHandle = registrar.addObserver(nameHash: 1, name: "n", object: nil, queue: nil) { _ in }
            #expect(weakHandle != nil)
        }
        
        #expect(weakHandle == nil)
    }
    
    private func post(_ registrar: NotificationRegistrar, object: UnsafeRawPointer?) {
        registrar.post(nameHash: 1, name: "n", object: object.map(PostedObject.pointer)) { makeNotification("n") }
    }
    
    @Test func nilNameObserverReceivesUnobservedNames() {
        nonisolated(unsafe) var fired = 0
        
        let registrar = NotificationRegistrar()
        
        let observed = UnsafeRawPointer(bitPattern: 0x1234)!
        
        let token = registrar.addObserver(nameHash: nil, name: nil, object: observed) { _ in fired += 1 }
        
        post(registrar, object: observed)
        #expect(fired == 1)
        
        post(registrar, object: UnsafeRawPointer(bitPattern: 0x2000)!)
        post(registrar, object: nil)
        #expect(fired == 1)
        
        registrar.removeObserver(token)
        post(registrar, object: observed)
        #expect(fired == 1)
        
        #expect(registrar.isEmpty())
    }
    
    // Removing a nil-name, nil-object observer leaves nil-name observers of an object receiving
    @Test func wildcardRemovalKeepsNilNameObjectObservers() {
        nonisolated(unsafe) var objectFired = 0
        nonisolated(unsafe) var wildcardFired = 0
        
        let registrar = NotificationRegistrar()
        
        let observed = UnsafeRawPointer(bitPattern: 0x1234)!
        
        let objectToken = registrar.addObserver(nameHash: nil, name: nil, object: observed) { _ in objectFired += 1 }
        let wildcardToken = registrar.addObserver(nameHash: nil, name: nil, object: nil) { _ in wildcardFired += 1 }
        post(registrar, object: observed)
        post(registrar, object: nil)
        #expect(objectFired == 1)
        #expect(wildcardFired == 2)
        
        registrar.removeObserver(wildcardToken)
        post(registrar, object: observed)
        post(registrar, object: nil)
        #expect(objectFired == 2)
        #expect(wildcardFired == 2)
        
        registrar.removeObserver(objectToken)
        
        #expect(registrar.isEmpty())
    }
    
    @Test func filterRebuildKeepsLiveRegistrations() {
        nonisolated(unsafe) var objectFired = 0, nameFired = 0
        let removedObject = UnsafeRawPointer(bitPattern: 0x1234)!,
            liveObject = UnsafeRawPointer(bitPattern: 0x2000)!
        
        let registrar = NotificationRegistrar()
        
        let removed = registrar.addObserver(nameHash: nil, name: nil, object: removedObject) { _ in }
        let live = registrar.addObserver(nameHash: nil, name: nil, object: liveObject) { _ in objectFired += 1 }
        let named = registrar.addObserver(nameHash: 7, name: "named", object: nil) { _ in nameFired += 1 }
        registrar.removeObserver(removed)
        
        registrar._forceFilterRebuild()
        
        post(registrar, object: liveObject)
        registrar.post(nameHash: 7, name: "named", object: nil) {
            makeNotification("named")
        }
        
        #expect(objectFired == 1)
        #expect(nameFired == 1)
        
        registrar.removeObserver(live)
        registrar.removeObserver(named)
        
        #expect(registrar.isEmpty())
    }
}

@Suite("IntrusiveHashTable")
private struct IntrusiveHashTableTests {
    @Test func basicUsage() {
        struct Person: IntrusiveHashEntry {
            var name: String
            var age: Int
            
            struct Index: RawRepresentable, Equatable { let rawValue: UInt32 }
            var next = Index(rawValue: .max)
            static func hash(_ key: String) -> UInt64 { UInt64(UInt(bitPattern: key.hashValue)) }
        }
        
        struct People: IntrusiveHashTable<Person> {
            var people: [Person] = []
            var heads: ContiguousArray<Person.Index> = []
            var count = 0
            static var maxLoad: Int { 1 }
            
            subscript(_ i: Person.Index) -> Person {
                get { people[Int(i.rawValue)] }
                set { people[Int(i.rawValue)] = newValue }
            }
            
            func key(at i: Person.Index) -> String { people[Int(i.rawValue)].name }
            subscript(next i: Person.Index) -> Person.Index {
                get { people[Int(i.rawValue)].next }
                set { people[Int(i.rawValue)].next = newValue }
            }
            
            mutating func add(_ name: String, _ age: Int) {
                let i = Person.Index(rawValue: UInt32(people.count))
                people.append(Person(name: name, age: age))
                link(i)
            }
        }
        
        var people = People()
        people.add("Person1", 41)
        people.add("Person2", 39)
        
        var i = people.find("Person1")
        #expect(i != nil)
        #expect(people[i!].age == 41)
        
        i = people.find("Person2")
        #expect(i != nil)
        #expect(people[i!].age == 39)
        
        people.unlink(i!)

        i = people.find("Person2")
        #expect(i == nil)
    }
}

@Suite("SlotMap")
private struct SlotMapTests {
    @Test func insertGetRemove() {
        var map = SlotMap(vacant: "")
        
        let a = map.insert("a")
        let b = map.insert("b")
        
        #expect(map.count == 2)
        #expect(map.contains(a))
        #expect(map.contains(b) && map[index: b.index] == "b")
        
        #expect(map.remove(a) == "a")
        #expect(!map.contains(a))
        #expect(map.remove(a) == nil)
        #expect(map.count == 1)
    }
    
    @Test func reusedSlotGetsANewToken() {
        var map = SlotMap(vacant: 0)
        
        let old = map.insert(1)
        map.remove(old)
        let new = map.insert(2)
        
        #expect(new.index == old.index) // the freed slot is reused
        #expect(new != old)
        #expect(!map.contains(old)) // the stale token should not match
        #expect(map.contains(new) && map[index: new.index] == 2)
    }
    
    @Test func forEachVisitsOccupiedSlots() {
        var map = SlotMap(vacant: 0)
        
        let tokens = (1...5).map { map.insert($0) }
        
        map.remove(tokens[1])
        map.remove(tokens[3])
        
        var seen: [Int] = []
        map.forEach { _, value in seen.append(value) }
        
        #expect(seen == [1, 3, 5])
    }
}

@Suite("SlotList")
private struct SlotListTests {
    struct Item {
        var value: Int
        var links = SlotListLinkPair()
        
        enum ByLinks: SlotListLinkage {
            static var linkPair: WritableKeyPath<Item, SlotListLinkPair> { \.links }
        }
    }
    
    func values(_ list: SlotMapList<Item.ByLinks>, _ map: SlotMap<Item>) -> [Int] {
        var result: [Int] = []
        
        var index = list.head
        while index != .noIndex {
            result.append(map[index: index].value)
            index = map.next(after: index, in: list)
        }
        
        return result
    }
    
    @Test func linkAndUnlink() {
        var map = SlotMap(vacant: Item(value: 0))
        var list = SlotMapList<Item.ByLinks>()
        
        #expect(list.isEmpty)
        
        let tokens = (1...4).map {
            map.insert(Item(value: $0))
        }
        for token in tokens {
            map.link(token.index, into: &list)
        }
        
        #expect(values(list, map) == [4, 3, 2, 1]) // link adds at the head
        
        // Unlink from middle, head, and tail
        for (token, expected) in [(tokens[1], [4, 3, 1]), (tokens[3], [3, 1]), (tokens[0], [3])] {
            let removed = map.remove(token)!
            map.unlink(removed, from: &list)
            
            #expect(values(list, map) == expected)
        }
        
        map.unlink(map.remove(tokens[2])!, from: &list)
        #expect(list.isEmpty)
    }
}

@Suite("StableStorage")
private struct StableStorageTests {
    final class Box {}
    
    @Test func pointersStayValidAsStorageGrows() {
        var storage = StableStorage(vacant: 0)
        
        let first = storage.allocate()
        let pointer = storage.pointer(first)
        pointer.pointee = 42
        
        // Allocate past several chunks. The first element should not move.
        for _ in 0..<200 { _ = storage.allocate() }
        
        #expect(storage.pointer(first) == pointer)
        #expect(pointer.pointee == 42)
        #expect(storage.initializedCount == 201)
    }
    
    @Test func freedIndexIsReused() {
        var storage = StableStorage(vacant: 0)
        
        let a = storage.allocate()
        let b = storage.allocate()
        storage.free(a)
        
        #expect(storage.allocate() == a)
        
        let c = storage.allocate()
        
        #expect(c != a && c != b) // nothing else is free, so expect a new index
    }
    
    @Test func deinitDestroysElements() {
        weak var weakBox: Box?
        
        do {
            var storage = StableStorage<Box?>(vacant: nil)
            
            let box = Box()
            weakBox = box
            
            storage.pointer(storage.allocate()).pointee = box
        }
        
        #expect(weakBox == nil)
    }
}

@Suite("InlineBloomFilter")
private struct InlineBloomFilterTests {
    let hashes = (0..<50).map { Int(truncatingIfNeeded: fibonacciHash(UInt64($0))) }
    
    @Test func insertedHashesAreFound() {
        let filter = InlineBloomFilter<4>()
        
        let foundBeforeInsert = filter.mightContain(hash: hashes[0])
        #expect(!foundBeforeInsert)
        
        for hash in hashes { filter.insert(hash: hash) }
        let allFound = hashes.allSatisfy { filter.mightContain(hash: $0) }
        #expect(allFound) // never a false negative
        
        let insertCount = filter.insertCount.load(ordering: .relaxed)
        #expect(insertCount == 50)
    }
    
    @Test func rebuildKeepsTheGivenHashes() {
        let filter = InlineBloomFilter<4>()
        
        for hash in hashes { filter.insert(hash: hash) }
        
        let kept = Array(hashes[..<10])
        filter.rebuild(fromHashes: kept)
        
        let allKeptFound = kept.allSatisfy { filter.mightContain(hash: $0) }
        #expect(allKeptFound)
        
        let insertCount = filter.insertCount.load(ordering: .relaxed)
        #expect(insertCount == 10)
    }
}

#if FOUNDATION_FRAMEWORK
@Suite("ImmortalNameCache")
private struct ImmortalNameCacheTests {
    let a = UnsafeRawPointer(bitPattern: 0x1000)!
    let b = UnsafeRawPointer(bitPattern: 0x2000)!
    
    @Test func insertAndLookup() {
        let cache = ImmortalNameCache<8>()
        
        let beforeInsert = cache.lookup(a)
        #expect(beforeInsert == nil)
        
        cache.insert(a, hash: 111)
        
        let hitA = cache.lookup(a)
        let missB = cache.lookup(b)
        
        #expect(hitA == 111)
        #expect(missB == nil)
    }
    
    @Test func collidingPointerEvicts() {
        let cache = ImmortalNameCache<1>() // one slot so every pointer collides
        
        cache.insert(a, hash: 111)
        cache.insert(b, hash: 222)
        
        let lookupA = cache.lookup(a)
        let lookupB = cache.lookup(b)
        
        #expect(lookupA == nil) // should have been evicted
        #expect(lookupB == 222)
    }
    
    // NSString subclass that is neither a constant nor a tagged pointer string
    final class ImpostorString: NSString {
        override var length: Int { 1 }
        override func character(at index: Int) -> unichar { unichar(UInt8(ascii: "x")) }
    }
    
    // Hashes `name` through a fresh cache and reports whether it was cached
    func isCached(_ name: NSString) -> Bool {
        let cache = ImmortalNameCache<8>()
        let hash = cache.nameHash(for: name)
        #expect(hash == name.hash)
        return cache.lookup(UnsafeRawPointer(Unmanaged.passUnretained(name).toOpaque())) != nil
    }
    
    @Test func onlyImmortalStringsAreCached() {
        let sharedCacheConstant = UserDefaults.didChangeNotification.rawValue as NSString
        let tagged: NSString = "abc"
        let heap = NSString(format: "%@-%d", "NotificationRegistrarTestsHeapName", 1)
        
        #expect(isCached(sharedCacheConstant))
        #expect(isCached(tagged))
        #expect(!isCached(heap))
        #expect(!isCached(ImpostorString()))
    }
    
    @Test func cachedHashIsReturnedOnAHit() {
        let cache = ImmortalNameCache<8>()
        let constant = UserDefaults.didChangeNotification.rawValue as NSString
        
        let first = cache.nameHash(for: constant)
        let second = cache.nameHash(for: constant)
        
        #expect(first == constant.hash)
        #expect(second == constant.hash)
    }
}
#endif
