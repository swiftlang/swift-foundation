//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@Suite("SortComparator")
private struct SortComparatorTests {
    @Test func comparableDescriptors() {
        let intDesc: ComparableComparator<Int> = ComparableComparator<Int>()
        #expect(intDesc.compare(0, 1) == .orderedAscending)
        let result = intDesc.compare(1000, -10)
        #expect(result == .orderedDescending)
    }
    
    
    @Test func order() {
        var intDesc: ComparableComparator<Int> = ComparableComparator<Int>(order: .reverse)
        #expect(intDesc.compare(0, 1) == .orderedDescending)
        #expect(intDesc.compare(1000, -10) == .orderedAscending)
        #expect(intDesc.compare(100, 100) == .orderedSame)
        
        intDesc.order = .forward
        #expect(intDesc.compare(0, 1) == .orderedAscending)
        #expect(intDesc.compare(1000, -10) == .orderedDescending)
        #expect(intDesc.compare(100, 100) == .orderedSame)
    }
    
    @Test func anySortComparatorEquality() {
        let a: ComparableComparator<Int> = ComparableComparator<Int>()
        let b: ComparableComparator<Int> = ComparableComparator<Int>(order: .reverse)
        let c: ComparableComparator<Double> = ComparableComparator<Double>()
        #expect(AnySortComparator(a) == AnySortComparator(a))
        #expect(AnySortComparator(b) == AnySortComparator(b))
        #expect(AnySortComparator(c) == AnySortComparator(c))
        #expect(AnySortComparator(a) != AnySortComparator(b))
        #expect(AnySortComparator(b) != AnySortComparator(c))
        #expect(AnySortComparator(a) != AnySortComparator(c))
    }
}
