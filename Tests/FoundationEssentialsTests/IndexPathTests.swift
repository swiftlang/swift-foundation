// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("IndexPath")
private struct TestIndexPath {
    @Test func empty() {
        let ip = IndexPath()
        #expect(ip.count == 0)
        
#if FOUNDATION_FRAMEWORK
        // Darwin allows nil if length is 0
        let nsip = NSIndexPath(indexes: nil, length: 0)
        #expect(nsip.length == 0)
        let newIp = nsip.adding(1)
        #expect(newIp.count == 1)
#endif
    }
    
    @Test func singleIndex() {
        let ip = IndexPath(index: 1)
        #expect(ip.count == 1)
        #expect(ip[0] == 1)
        
        let highValueIp = IndexPath(index: .max)
        #expect(highValueIp.count == 1)
        #expect(highValueIp[0] == .max)
        
        let lowValueIp = IndexPath(index: .min)
        #expect(lowValueIp.count == 1)
        #expect(lowValueIp[0] == .min)
    }
    
    @Test func twoIndexes() {
        let ip = IndexPath(indexes: [0, 1])
        #expect(ip.count == 2)
        #expect(ip[0] == 0)
        #expect(ip[1] == 1)
    }
    
    @Test func manyIndexes() {
        let ip = IndexPath(indexes: [0, 1, 2, 3, 4])
        #expect(ip.count == 5)
        #expect(ip[0] == 0)
        #expect(ip[1] == 1)
        #expect(ip[2] == 2)
        #expect(ip[3] == 3)
        #expect(ip[4] == 4)
    }
    
    @Test func createFromSequence() {
        let seq = repeatElement(5, count: 3)
        let ip = IndexPath(indexes: seq)
        #expect(ip.count == 3)
        #expect(ip[0] == 5)
        #expect(ip[1] == 5)
        #expect(ip[2] == 5)
    }
    
    @Test func createFromLiteral() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.count == 4)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
        #expect(ip[3] == 4)
    }
    
    @Test func dropLast() {
        let ip: IndexPath = [1, 2, 3, 4]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 3)
        #expect(ip2[0] == 1)
        #expect(ip2[1] == 2)
        #expect(ip2[2] == 3)
    }
    
    @Test func dropLastFromEmpty() {
        let ip: IndexPath = []
        let ip2 = ip.dropLast()
        #expect(ip2.count == 0)
    }
    
    @Test func dropLastFromSingle() {
        let ip: IndexPath = [1]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 0)
    }
    
    @Test func dropLastFromPair() {
        let ip: IndexPath = [1, 2]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 1)
        #expect(ip2[0] == 1)
    }
    
    @Test func dropLastFromTriple() {
        let ip: IndexPath = [1, 2, 3]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 2)
        #expect(ip2[0] == 1)
        #expect(ip2[1] == 2)
    }
    
    @Test func startEndIndex() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.startIndex == 0)
        #expect(ip.endIndex == ip.count)
    }
    
    @Test func iterator() {
        let ip: IndexPath = [1, 2, 3, 4]
        var iter = ip.makeIterator()
        var sum = 0
        while let index = iter.next() {
            sum += index
        }
        #expect(sum == 1 + 2 + 3 + 4)
    }
    
    @Test func indexing() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.index(before: 1) == 0)
        #expect(ip.index(before: 0) == -1) // beyond range!
        #expect(ip.index(after: 1) == 2)
        #expect(ip.index(after: 4) == 5) // beyond range!
    }
    
    @Test func compare() {
        let ip1: IndexPath = [1, 2]
        let ip2: IndexPath = [3, 4]
        let ip3: IndexPath = [5, 1]
        let ip4: IndexPath = [1, 1, 1]
        let ip5: IndexPath = [1, 1, 9]
        
        #expect(ip1.compare(ip1) == .orderedSame)
        #expect(!(ip1 < ip1))
        #expect(ip1 <= ip1)
        #expect(ip1 == ip1)
        #expect(ip1 >= ip1)
        #expect(!(ip1 > ip1))
        
        #expect(ip1.compare(ip2) == .orderedAscending)
        #expect(ip1 < ip2)
        #expect(ip1 <= ip2)
        #expect(!(ip1 == ip2))
        #expect(!(ip1 >= ip2))
        #expect(!(ip1 > ip2))
        
        #expect(ip1.compare(ip3) == .orderedAscending)
        #expect(ip1 < ip3)
        #expect(ip1 <= ip3)
        #expect(!(ip1 == ip3))
        #expect(!(ip1 >= ip3))
        #expect(!(ip1 > ip3))
        
        #expect(ip1.compare(ip4) == .orderedDescending)
        #expect(!(ip1 < ip4))
        #expect(!(ip1 <= ip4))
        #expect(!(ip1 == ip4))
        #expect(ip1 >= ip4)
        #expect(ip1 > ip4)
        
        #expect(ip1.compare(ip5) == .orderedDescending)
        #expect(!(ip1 < ip5))
        #expect(!(ip1 <= ip5))
        #expect(!(ip1 == ip5))
        #expect(ip1 >= ip5)
        #expect(ip1 > ip5)
        
        #expect(ip2.compare(ip1) == .orderedDescending)
        #expect(!(ip2 < ip1))
        #expect(!(ip2 <= ip1))
        #expect(!(ip2 == ip1))
        #expect(ip2 >= ip1)
        #expect(ip2 > ip1)
        
        #expect(ip2.compare(ip2) == .orderedSame)
        #expect(!(ip2 < ip2))
        #expect(ip2 <= ip2)
        #expect(ip2 == ip2)
        #expect(ip2 >= ip2)
        #expect(!(ip2 > ip2))
        
        #expect(ip2.compare(ip3) == .orderedAscending)
        #expect(ip2 < ip3)
        #expect(ip2 <= ip3)
        #expect(!(ip2 == ip3))
        #expect(!(ip2 >= ip3))
        #expect(!(ip2 > ip3))
        
        #expect(ip2.compare(ip4) == .orderedDescending)
        #expect(ip2.compare(ip5) == .orderedDescending)
        #expect(ip3.compare(ip1) == .orderedDescending)
        #expect(ip3.compare(ip2) == .orderedDescending)
        #expect(ip3.compare(ip3) == .orderedSame)
        #expect(ip3.compare(ip4) == .orderedDescending)
        #expect(ip3.compare(ip5) == .orderedDescending)
        #expect(ip4.compare(ip1) == .orderedAscending)
        #expect(ip4.compare(ip2) == .orderedAscending)
        #expect(ip4.compare(ip3) == .orderedAscending)
        #expect(ip4.compare(ip4) == .orderedSame)
        #expect(ip4.compare(ip5) == .orderedAscending)
        #expect(ip5.compare(ip1) == .orderedAscending)
        #expect(ip5.compare(ip2) == .orderedAscending)
        #expect(ip5.compare(ip3) == .orderedAscending)
        #expect(ip5.compare(ip4) == .orderedDescending)
        #expect(ip5.compare(ip5) == .orderedSame)
        
        let ip6: IndexPath = [1, 1]
        #expect(ip6.compare(ip5) == .orderedAscending)
        #expect(ip5.compare(ip6) == .orderedDescending)
    }
    
    @Test func hashing() {
        let samples: [IndexPath] = [
            [],
            [1],
            [2],
            [Int.max],
            [1, 1],
            [2, 1],
            [1, 2],
            [1, 1, 1],
            [2, 1, 1],
            [1, 2, 1],
            [1, 1, 2],
            [Int.max, Int.max, Int.max],
        ]
        checkHashable(samples, equalityOracle: { $0 == $1 })

        // this should not cause an overflow crash
        _ = IndexPath(indexes: [Int.max >> 8, 2, Int.max >> 36]).hashValue 
    }
    
    @Test func equality() {
        let ip1: IndexPath = [1, 1]
        let ip2: IndexPath = [1, 1]
        let ip3: IndexPath = [1, 1, 1]
        let ip4: IndexPath = []
        let ip5: IndexPath = [1]
        
        #expect(ip1 == ip2)
        #expect(ip1 != ip3)
        #expect(ip1 != ip4)
        #expect(ip4 != ip1)
        #expect(ip5 != ip1)
        #expect(ip5 != ip4)
        #expect(ip4 == ip4)
        #expect(ip5 == ip5)
    }
    
    @Test func subscripting() {
        var ip1: IndexPath = [1]
        var ip2: IndexPath = [1, 2]
        var ip3: IndexPath = [1, 2, 3]
        
        #expect(ip1[0] == 1)
        
        #expect(ip2[0] == 1)
        #expect(ip2[1] == 2)
        
        #expect(ip3[0] == 1)
        #expect(ip3[1] == 2)
        #expect(ip3[2] == 3)
        
        ip1[0] = 2
        #expect(ip1[0] == 2)
        
        ip2[0] = 2
        ip2[1] = 3
        #expect(ip2[0] == 2)
        #expect(ip2[1] == 3)
        
        ip3[0] = 2
        ip3[1] = 3
        ip3[2] = 4
        #expect(ip3[0] == 2)
        #expect(ip3[1] == 3)
        #expect(ip3[2] == 4)
        
        let ip4 = ip3[0..<2]
        #expect(ip4.count == 2)
        #expect(ip4[0] == 2)
        #expect(ip4[1] == 3)
        
        let ip5 = ip3[1...]
        #expect(ip5.count == 2)
        #expect(ip5[0] == 3)
        #expect(ip5[1] == 4)

        let ip6 = ip3[2...]
        #expect(ip6.count == 1)
        #expect(ip6[0] == 4)
    }
    
    @Test func appending() {
        var ip : IndexPath = [1, 2, 3, 4]
        let ip2 = IndexPath(indexes: [5, 6, 7])
        
        ip.append(ip2)
        
        #expect(ip.count == 7)
        #expect(ip[0] == 1)
        #expect(ip[6] == 7)
        
        let ip3 = ip.appending(IndexPath(indexes: [8, 9]))
        #expect(ip3.count == 9)
        #expect(ip3[7] == 8)
        #expect(ip3[8] == 9)
        
        let ip4 = ip3.appending([10, 11])
        #expect(ip4.count == 11)
        #expect(ip4[9] == 10)
        #expect(ip4[10] == 11)
        
        let ip5 = ip.appending(8)
        #expect(ip5.count == 8)
        #expect(ip5[7] == 8)
    }
    
    @Test func appendEmpty() {
        var ip: IndexPath = []
        ip.append(1)
        
        #expect(ip.count == 1)
        #expect(ip[0] == 1)
        
        ip.append(2)
        #expect(ip.count == 2)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        
        ip.append(3)
        #expect(ip.count == 3)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
        
        ip.append(4)
        #expect(ip.count == 4)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
        #expect(ip[3] == 4)
    }
    
    @Test func appendEmptyIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: []))
        
        #expect(ip.count == 0)
    }
    
    @Test func appendManyIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2, 3]))
        
        #expect(ip.count == 3)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
    }
    
    @Test func appendEmptyIndexPathToSingle() {
        var ip: IndexPath = [1]
        ip.append(IndexPath(indexes: []))
        
        #expect(ip.count == 1)
        #expect(ip[0] == 1)
    }
    
    @Test func appendSingleIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1]))
        
        #expect(ip.count == 1)
        #expect(ip[0] == 1)
    }
    
    @Test func appendSingleIndexPathToSingle() {
        var ip: IndexPath = [1]
        ip.append(IndexPath(indexes: [1]))
        
        #expect(ip.count == 2)
        #expect(ip[0] == 1)
        #expect(ip[1] == 1)
    }
    
    @Test func appendPairIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2]))
        
        #expect(ip.count == 2)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
    }
    
    @Test func appendManyIndexPathToEmpty() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2, 3]))
        
        #expect(ip.count == 3)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
    }
    
    @Test func appendByOperator() {
        let ip1: IndexPath = []
        let ip2: IndexPath = []
        
        let ip3 = ip1 + ip2
        #expect(ip3.count == 0)
        
        let ip4: IndexPath = [1]
        let ip5: IndexPath = [2]
        
        let ip6 = ip4 + ip5
        #expect(ip6.count == 2)
        #expect(ip6[0] == 1)
        #expect(ip6[1] == 2)
        
        var ip7: IndexPath = []
        ip7 += ip6
        #expect(ip7.count == 2)
        #expect(ip7[0] == 1)
        #expect(ip7[1] == 2)
    }
    
    @Test func appendArray() {
        var ip: IndexPath = [1, 2, 3, 4]
        let indexes = [5, 6, 7]
        
        ip.append(indexes)
        
        #expect(ip.count == 7)
        #expect(ip[0] == 1)
        #expect(ip[6] == 7)
    }
    
    @Test func ranges() {
        let ip1 = IndexPath(indexes: [1, 2, 3])
        let ip2 = IndexPath(indexes: [6, 7, 8])
        
        // Replace the whole range
        var mutateMe = ip1
        mutateMe[0..<3] = ip2
        #expect(mutateMe == ip2)
        
        // Insert at the beginning
        mutateMe = ip1
        mutateMe[0..<0] = ip2
        #expect(mutateMe == IndexPath(indexes: [6, 7, 8, 1, 2, 3]))
        
        // Insert at the end
        mutateMe = ip1
        mutateMe[3..<3] = ip2
        #expect(mutateMe == IndexPath(indexes: [1, 2, 3, 6, 7, 8]))
        
        // Insert in middle
        mutateMe = ip1
        mutateMe[2..<2] = ip2
        #expect(mutateMe == IndexPath(indexes: [1, 2, 6, 7, 8, 3]))
    }
    
    @Test func rangeFromEmpty() {
        let ip1 = IndexPath()
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
    }
    
    @Test func rangeFromSingle() {
        let ip1 = IndexPath(indexes: [1])
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
        let ip3 = ip1[0..<1]
        #expect(ip3.count == 1)
        #expect(ip3[0] == 1)
    }
    
    @Test func rangeFromPair() {
        let ip1 = IndexPath(indexes: [1, 2])
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
        let ip3 = ip1[0..<1]
        #expect(ip3.count == 1)
        #expect(ip3[0] == 1)
        let ip4 = ip1[1..<1]
        #expect(ip4.count == 0)
        let ip5 = ip1[0..<2]
        #expect(ip5.count == 2)
        #expect(ip5[0] == 1)
        #expect(ip5[1] == 2)
        let ip6 = ip1[1..<2]
        #expect(ip6.count == 1)
        #expect(ip6[0] == 2)
        let ip7 = ip1[2..<2]
        #expect(ip7.count == 0)
    }
    
    @Test func rangeFromMany() {
        let ip1 = IndexPath(indexes: [1, 2, 3])
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
        let ip3 = ip1[0..<1]
        #expect(ip3.count == 1)
        let ip4 = ip1[0..<2]
        #expect(ip4.count == 2)
        let ip5 = ip1[0..<3]
        #expect(ip5.count == 3)
    }
    
    @Test func rangeReplacementSingle() {
        var ip1 = IndexPath(indexes: [1])
        ip1[0..<1] = IndexPath(indexes: [2])
        #expect(ip1[0] == 2)
        
        ip1[0..<1] = IndexPath(indexes: [])
        #expect(ip1.count == 0)
    }
    
    @Test func rangeReplacementPair() {
        var ip1 = IndexPath(indexes: [1, 2])
        ip1[0..<1] = IndexPath(indexes: [2, 3])
        #expect(ip1.count == 3)
        #expect(ip1[0] == 2)
        #expect(ip1[1] == 3)
        #expect(ip1[2] == 2)
        
        ip1[0..<1] = IndexPath(indexes: [])
        #expect(ip1.count == 2)
    }
    
    @Test func moreRanges() {
        var ip = IndexPath(indexes: [1, 2, 3])
        let ip2 = IndexPath(indexes: [5, 6, 7, 8, 9, 10])
        
        ip[1..<2] = ip2
        #expect(ip == IndexPath(indexes: [1, 5, 6, 7, 8, 9, 10, 3]))
    }
    
    @Test func iteration() {
        let ip = IndexPath(indexes: [1, 2, 3])
        
        var count = 0
        for _ in ip {
            count += 1
        }
        
        #expect(3 == count)
    }
    
    @Test func description() {
        let ip1: IndexPath = []
        let ip2: IndexPath = [1]
        let ip3: IndexPath = [1, 2]
        let ip4: IndexPath = [1, 2, 3]
        
        #expect(ip1.description == "[]")
        #expect(ip2.description == "[1]")
        #expect(ip3.description == "[1, 2]")
        #expect(ip4.description == "[1, 2, 3]")
        
        #expect(ip1.debugDescription == ip1.description)
        #expect(ip2.debugDescription == ip2.description)
        #expect(ip3.debugDescription == ip3.description)
        #expect(ip4.debugDescription == ip4.description)
    }
        
    @Test func anyHashableContainingIndexPath() {
        let values: [IndexPath] = [
            IndexPath(indexes: [1, 2]),
            IndexPath(indexes: [1, 2, 3]),
            IndexPath(indexes: [1, 2, 3]),
            ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(IndexPath.self == type(of: anyHashables[0].base))
        #expect(IndexPath.self == type(of: anyHashables[1].base))
        #expect(IndexPath.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func slice_1ary() {
        let indexPath: IndexPath = [0]
        let res = indexPath.dropFirst()
        #expect(0 == res.count)

        let slice = indexPath[1..<1]
        #expect(0 == slice.count)
    }

    @Test func dropFirst() {
        var pth = IndexPath(indexes:[1,2,3,4])
        while !pth.isEmpty {
            // this should not crash 
            pth = pth.dropFirst()
        }
    }
}

#if FOUNDATION_FRAMEWORK

@Suite("IndexPath Bridging")
private struct IndexPathBridgingTests {
    @Test func bridgeToObjC() {
        let ip1: IndexPath = []
        let ip2: IndexPath = [1]
        let ip3: IndexPath = [1, 2]
        let ip4: IndexPath = [1, 2, 3]
        
        let nsip1 = ip1 as NSIndexPath
        let nsip2 = ip2 as NSIndexPath
        let nsip3 = ip3 as NSIndexPath
        let nsip4 = ip4 as NSIndexPath
        
        #expect(nsip1.length == 0)
        #expect(nsip2.length == 1)
        #expect(nsip3.length == 2)
        #expect(nsip4.length == 3)
    }
    
    @Test func forceBridgeFromObjC() {
        let nsip1 = NSIndexPath()
        let nsip2 = NSIndexPath(index: 1)
        let nsip3 = [1, 2].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        let nsip4 = [1, 2, 3].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        
        var ip1: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip1, result: &ip1)
        #expect(ip1?.count == 0)
        
        var ip2: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip2, result: &ip2)
        #expect(ip2?.count == 1)
        #expect(ip2?[0] == 1)
        
        var ip3: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip3, result: &ip3)
        #expect(ip3?.count == 2)
        #expect(ip3?[0] == 1)
        #expect(ip3?[1] == 2)
        
        var ip4: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip4, result: &ip4)
        #expect(ip4?.count == 3)
        #expect(ip4?[0] == 1)
        #expect(ip4?[1] == 2)
        #expect(ip4?[2] == 3)
    }
    
    @Test func conditionalBridgeFromObjC() {
        let nsip1 = NSIndexPath()
        let nsip2 = NSIndexPath(index: 1)
        let nsip3 = [1, 2].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        let nsip4 = [1, 2, 3].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        
        var ip1: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip1, result: &ip1))
        #expect(ip1?.count == 0)
        
        var ip2: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip2, result: &ip2))
        #expect(ip2?.count == 1)
        #expect(ip2?[0] == 1)
        
        var ip3: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip3, result: &ip3))
        #expect(ip3?.count == 2)
        #expect(ip3?[0] == 1)
        #expect(ip3?[1] == 2)
        
        var ip4: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip4, result: &ip4))
        #expect(ip4?.count == 3)
        #expect(ip4?[0] == 1)
        #expect(ip4?[1] == 2)
        #expect(ip4?[2] == 3)
    }
    
    @Test func unconditionalBridgeFromObjC() {
        let nsip1 = NSIndexPath()
        let nsip2 = NSIndexPath(index: 1)
        let nsip3 = [1, 2].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        let nsip4 = [1, 2, 3].withUnsafeBufferPointer { (buffer: UnsafeBufferPointer<Int>) -> NSIndexPath in
            return NSIndexPath(indexes: buffer.baseAddress, length: buffer.count)
        }
        
        let ip1: IndexPath = IndexPath._unconditionallyBridgeFromObjectiveC(nsip1)
        #expect(ip1.count == 0)
        
        let ip2: IndexPath = IndexPath._unconditionallyBridgeFromObjectiveC(nsip2)
        #expect(ip2.count == 1)
        #expect(ip2[0] == 1)
        
        let ip3: IndexPath = IndexPath._unconditionallyBridgeFromObjectiveC(nsip3)
        #expect(ip3.count == 2)
        #expect(ip3[0] == 1)
        #expect(ip3[1] == 2)
        
        let ip4: IndexPath = IndexPath._unconditionallyBridgeFromObjectiveC(nsip4)
        #expect(ip4.count == 3)
        #expect(ip4[0] == 1)
        #expect(ip4[1] == 2)
        #expect(ip4[2] == 3)
    }
    
    @Test func objcBridgeType() {
        let typeIsExpected = IndexPath._getObjectiveCType() == NSIndexPath.self
        #expect(typeIsExpected)
    }
    
    @Test func anyHashableCreatedFromNSIndexPath() {
        let values: [NSIndexPath] = [
            NSIndexPath(index: 1),
            NSIndexPath(index: 2),
            NSIndexPath(index: 2),
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(IndexPath.self == type(of: anyHashables[0].base))
        #expect(IndexPath.self == type(of: anyHashables[1].base))
        #expect(IndexPath.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func unconditionallyBridgeFromObjectiveC() {
        #expect(IndexPath() == IndexPath._unconditionallyBridgeFromObjectiveC(nil))
    }
}

#endif // FOUNDATION_FRAMEWORK

