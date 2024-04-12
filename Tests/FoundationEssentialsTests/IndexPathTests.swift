// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

struct IndexPathTests {
    @Test func testEmpty() {
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
    
    @Test func testSingleIndex() {
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
    
    @Test func testTwoIndexes() {
        let ip = IndexPath(indexes: [0, 1])
        #expect(ip.count == 2)
        #expect(ip[0] == 0)
        #expect(ip[1] == 1)
    }
    
    @Test func testManyIndexes() {
        let ip = IndexPath(indexes: [0, 1, 2, 3, 4])
        #expect(ip.count == 5)
        #expect(ip[0] == 0)
        #expect(ip[1] == 1)
        #expect(ip[2] == 2)
        #expect(ip[3] == 3)
        #expect(ip[4] == 4)
    }
    
    @Test func testCreateFromSequence() {
        let seq = repeatElement(5, count: 3)
        let ip = IndexPath(indexes: seq)
        #expect(ip.count == 3)
        #expect(ip[0] == 5)
        #expect(ip[1] == 5)
        #expect(ip[2] == 5)
    }
    
    @Test func testCreateFromLiteral() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.count == 4)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
        #expect(ip[3] == 4)
    }
    
    @Test func testDropLast() {
        let ip: IndexPath = [1, 2, 3, 4]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 3)
        #expect(ip2[0] == 1)
        #expect(ip2[1] == 2)
        #expect(ip2[2] == 3)
    }
    
    @Test func testDropLastFromEmpty() {
        let ip: IndexPath = []
        let ip2 = ip.dropLast()
        #expect(ip2.count == 0)
    }
    
    @Test func testDropLastFromSingle() {
        let ip: IndexPath = [1]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 0)
    }
    
    @Test func testDropLastFromPair() {
        let ip: IndexPath = [1, 2]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 1)
        #expect(ip2[0] == 1)
    }
    
    @Test func testDropLastFromTriple() {
        let ip: IndexPath = [1, 2, 3]
        let ip2 = ip.dropLast()
        #expect(ip2.count == 2)
        #expect(ip2[0] == 1)
        #expect(ip2[1] == 2)
    }
    
    @Test func testStartEndIndex() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.startIndex == 0)
        #expect(ip.endIndex == ip.count)
    }
    
    @Test func testIterator() {
        let ip: IndexPath = [1, 2, 3, 4]
        var iter = ip.makeIterator()
        var sum = 0
        while let index = iter.next() {
            sum += index
        }
        #expect(sum == 1 + 2 + 3 + 4)
    }
    
    @Test func testIndexing() {
        let ip: IndexPath = [1, 2, 3, 4]
        #expect(ip.index(before: 1) == 0)
        #expect(ip.index(before: 0) == -1) // beyond range!
        #expect(ip.index(after: 1) == 2)
        #expect(ip.index(after: 4) == 5) // beyond range!
    }
    
    @Test func testCompare() {
        let ip1: IndexPath = [1, 2]
        let ip2: IndexPath = [3, 4]
        let ip3: IndexPath = [5, 1]
        let ip4: IndexPath = [1, 1, 1]
        let ip5: IndexPath = [1, 1, 9]
        
        #expect(ip1.compare(ip1) == ComparisonResult.orderedSame)
        #expect((ip1 < ip1) == false)
        #expect((ip1 <= ip1) == true)
        #expect((ip1 == ip1) == true)
        #expect((ip1 >= ip1) == true)
        #expect((ip1 > ip1) == false)

        #expect(ip1.compare(ip2) == ComparisonResult.orderedAscending)
        #expect((ip1 < ip2) == true)
        #expect((ip1 <= ip2) == true)
        #expect((ip1 == ip2) == false)
        #expect((ip1 >= ip2) == false)
        #expect((ip1 > ip2) == false)

        #expect(ip1.compare(ip3) == ComparisonResult.orderedAscending)
        #expect((ip1 < ip3) == true)
        #expect((ip1 <= ip3) == true)
        #expect((ip1 == ip3) == false)
        #expect((ip1 >= ip3) == false)
        #expect((ip1 > ip3) == false)

        #expect(ip1.compare(ip4) == ComparisonResult.orderedDescending)
        #expect((ip1 < ip4) == false)
        #expect((ip1 <= ip4) == false)
        #expect((ip1 == ip4) == false)
        #expect((ip1 >= ip4) == true)
        #expect((ip1 > ip4) == true)

        #expect(ip1.compare(ip5) == ComparisonResult.orderedDescending)
        #expect((ip1 < ip5) == false)
        #expect((ip1 <= ip5) == false)
        #expect((ip1 == ip5) == false)
        #expect((ip1 >= ip5) == true)
        #expect((ip1 > ip5) == true)

        #expect(ip2.compare(ip1) == ComparisonResult.orderedDescending)
        #expect((ip2 < ip1) == false)
        #expect((ip2 <= ip1) == false)
        #expect((ip2 == ip1) == false)
        #expect((ip2 >= ip1) == true)
        #expect((ip2 > ip1) == true)

        #expect(ip2.compare(ip2) == ComparisonResult.orderedSame)
        #expect((ip2 < ip2) == false)
        #expect((ip2 <= ip2) == true)
        #expect((ip2 == ip2) == true)
        #expect((ip2 >= ip2) == true)
        #expect((ip2 > ip2) == false)

        #expect(ip2.compare(ip3) == ComparisonResult.orderedAscending)
        #expect((ip2 < ip3) == true)
        #expect((ip2 <= ip3) == true)
        #expect((ip2 == ip3) == false)
        #expect((ip2 >= ip3) == false)
        #expect((ip2 > ip3) == false)

        #expect(ip2.compare(ip4) == ComparisonResult.orderedDescending)
        #expect(ip2.compare(ip5) == ComparisonResult.orderedDescending)
        #expect(ip3.compare(ip1) == ComparisonResult.orderedDescending)
        #expect(ip3.compare(ip2) == ComparisonResult.orderedDescending)
        #expect(ip3.compare(ip3) == ComparisonResult.orderedSame)
        #expect(ip3.compare(ip4) == ComparisonResult.orderedDescending)
        #expect(ip3.compare(ip5) == ComparisonResult.orderedDescending)
        #expect(ip4.compare(ip1) == ComparisonResult.orderedAscending)
        #expect(ip4.compare(ip2) == ComparisonResult.orderedAscending)
        #expect(ip4.compare(ip3) == ComparisonResult.orderedAscending)
        #expect(ip4.compare(ip4) == ComparisonResult.orderedSame)
        #expect(ip4.compare(ip5) == ComparisonResult.orderedAscending)
        #expect(ip5.compare(ip1) == ComparisonResult.orderedAscending)
        #expect(ip5.compare(ip2) == ComparisonResult.orderedAscending)
        #expect(ip5.compare(ip3) == ComparisonResult.orderedAscending)
        #expect(ip5.compare(ip4) == ComparisonResult.orderedDescending)
        #expect(ip5.compare(ip5) == ComparisonResult.orderedSame)

        let ip6: IndexPath = [1, 1]
        #expect(ip6.compare(ip5) == ComparisonResult.orderedAscending)
        #expect(ip5.compare(ip6) == ComparisonResult.orderedDescending)
    }
    
    @Test func testHashing() {
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
    
    @Test func testEquality() {
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
    
    @Test func testSubscripting() {
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
    
    @Test func testAppending() {
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
    
    @Test func testAppendEmpty() {
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

    @Test func testAppendEmptyIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: []))

        #expect(ip.count == 0)
    }

    @Test func testAppendManyIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2, 3]))

        #expect(ip.count == 3)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
    }

    @Test func testAppendEmptyIndexPathToSingle() {
        var ip: IndexPath = [1]
        ip.append(IndexPath(indexes: []))

        #expect(ip.count == 1)
        #expect(ip[0] == 1)
    }
    
    @Test func testAppendSingleIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1]))

        #expect(ip.count == 1)
        #expect(ip[0] == 1)
    }
    
    @Test func testAppendSingleIndexPathToSingle() {
        var ip: IndexPath = [1]
        ip.append(IndexPath(indexes: [1]))
        
        #expect(ip.count == 2)
        #expect(ip[0] == 1)
        #expect(ip[1] == 1)
    }
    
    @Test func testAppendPairIndexPath() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2]))
        
        #expect(ip.count == 2)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
    }
    
    @Test func testAppendManyIndexPathToEmpty() {
        var ip: IndexPath = []
        ip.append(IndexPath(indexes: [1, 2, 3]))
        
        #expect(ip.count == 3)
        #expect(ip[0] == 1)
        #expect(ip[1] == 2)
        #expect(ip[2] == 3)
    }
    
    @Test func testAppendByOperator() {
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
    
    @Test func testAppendArray() {
        var ip: IndexPath = [1, 2, 3, 4]
        let indexes = [5, 6, 7]

        ip.append(indexes)

        #expect(ip.count == 7)
        #expect(ip[0] == 1)
        #expect(ip[6] == 7)
    }
    
    @Test func testRanges() {
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

    @Test func testRangeFromEmpty() {
        let ip1 = IndexPath()
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
    }

    @Test func testRangeFromSingle() {
        let ip1 = IndexPath(indexes: [1])
        let ip2 = ip1[0..<0]
        #expect(ip2.count == 0)
        let ip3 = ip1[0..<1]
        #expect(ip3.count == 1)
        #expect(ip3[0] == 1)
    }

    @Test func testRangeFromPair() {
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

    @Test func testRangeFromMany() {
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

    @Test func testRangeReplacementSingle() {
        var ip1 = IndexPath(indexes: [1])
        ip1[0..<1] = IndexPath(indexes: [2])
        #expect(ip1[0] == 2)

        ip1[0..<1] = IndexPath(indexes: [])
        #expect(ip1.count == 0)
    }
    
    @Test func testRangeReplacementPair() {
        var ip1 = IndexPath(indexes: [1, 2])
        ip1[0..<1] = IndexPath(indexes: [2, 3])
        #expect(ip1.count == 3)
        #expect(ip1[0] == 2)
        #expect(ip1[1] == 3)
        #expect(ip1[2] == 2)

        ip1[0..<1] = IndexPath(indexes: [])
        #expect(ip1.count == 2)
    }
    
    @Test func testMoreRanges() {
        var ip = IndexPath(indexes: [1, 2, 3])
        let ip2 = IndexPath(indexes: [5, 6, 7, 8, 9, 10])
        
        ip[1..<2] = ip2
        #expect(ip == IndexPath(indexes: [1, 5, 6, 7, 8, 9, 10, 3]))
    }
    
    @Test func testIteration() {
        let ip = IndexPath(indexes: [1, 2, 3])
        
        var count = 0
        for _ in ip {
            count += 1
        }
        
        #expect(3 == count)
    }

    @Test func testDescription() {
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
        
    @Test func test_AnyHashableContainingIndexPath() {
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

    @Test func test_slice_1ary() {
        let indexPath: IndexPath = [0]
        let res = indexPath.dropFirst()
        #expect(0 == res.count)

        let slice = indexPath[1..<1]
        #expect(0 == slice.count)
    }

    @Test func test_dropFirst() {
        var pth = IndexPath(indexes:[1,2,3,4])
        while !pth.isEmpty {
            // this should not crash 
            pth = pth.dropFirst()
        }
    }
}

#if FOUNDATION_FRAMEWORK

struct IndexPathBridgingTests {
    @Test func testBridgeToObjC() {
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

    @Test func testForceBridgeFromObjC() {
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
        #expect(ip1 != nil)
        #expect(ip1!.count == 0)

        var ip2: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip2, result: &ip2)
        #expect(ip2 != nil)
        #expect(ip2!.count == 1)
        #expect(ip2![0] == 1)

        var ip3: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip3, result: &ip3)
        #expect(ip3 != nil)
        #expect(ip3!.count == 2)
        #expect(ip3![0] == 1)
        #expect(ip3![1] == 2)

        var ip4: IndexPath? = IndexPath()
        IndexPath._forceBridgeFromObjectiveC(nsip4, result: &ip4)
        #expect(ip4 != nil)
        #expect(ip4!.count == 3)
        #expect(ip4![0] == 1)
        #expect(ip4![1] == 2)
        #expect(ip4![2] == 3)
    }

    @Test func testConditionalBridgeFromObjC() {
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
        #expect(ip1 != nil)
        #expect(ip1!.count == 0)

        var ip2: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip2, result: &ip2))
        #expect(ip2 != nil)
        #expect(ip2!.count == 1)
        #expect(ip2![0] == 1)

        var ip3: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip3, result: &ip3))
        #expect(ip3 != nil)
        #expect(ip3!.count == 2)
        #expect(ip3![0] == 1)
        #expect(ip3![1] == 2)

        var ip4: IndexPath? = IndexPath()
        #expect(IndexPath._conditionallyBridgeFromObjectiveC(nsip4, result: &ip4))
        #expect(ip4 != nil)
        #expect(ip4!.count == 3)
        #expect(ip4![0] == 1)
        #expect(ip4![1] == 2)
        #expect(ip4![2] == 3)
    }
    
    @Test func testUnconditionalBridgeFromObjC() {
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
    
    @Test func testObjcBridgeType() {
        #expect(IndexPath._getObjectiveCType() == NSIndexPath.self)
    }
    
    @Test func test_AnyHashableCreatedFromNSIndexPath() {
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

    @Test func test_unconditionallyBridgeFromObjectiveC() {
        #expect(IndexPath() == IndexPath._unconditionallyBridgeFromObjectiveC(nil))
    }
}

#endif // FOUNDATION_FRAMEWORK

