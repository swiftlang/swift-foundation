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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

struct SortComparatorTests {
    @Test func test_comparable_descriptors() {
        let intDesc = ComparableComparator<Int>()
        #expect(intDesc.compare(0, 1) == .orderedAscending)
        #expect(intDesc.compare(1000, -10) == .orderedDescending)
    }
    
    
    @Test func test_order() {
        var intDesc = ComparableComparator<Int>(order: .reverse)
        #expect(intDesc.compare(0, 1) == .orderedDescending)
        #expect(intDesc.compare(1000, -10) == .orderedAscending)
        #expect(intDesc.compare(100, 100) == .orderedSame)
        
        intDesc.order = .forward
        #expect(intDesc.compare(0, 1) == .orderedAscending)
        #expect(intDesc.compare(1000, -10) == .orderedDescending)
        #expect(intDesc.compare(100, 100) == .orderedSame)
    }
    
    @Test func test_compare_options_descriptor() {
        let compareOptions = String.Comparator(options: [.numeric])
        #expect(compareOptions.compare("ttestest005", "test2") == "test005".compare("test2", options: [.numeric]))
        #expect(compareOptions.compare("test2", "test005") == "test2".compare("test005", options: [.numeric]))
    }
    
    @Test func testAnySortComparatorEquality() {
        let a = ComparableComparator<Int>()
        let b = ComparableComparator<Int>(order: .reverse)
        let c = ComparableComparator<Double>()
        #expect(AnySortComparator(a) == AnySortComparator(a))
        #expect(AnySortComparator(b) == AnySortComparator(b))
        #expect(AnySortComparator(c) == AnySortComparator(c))
        #expect(AnySortComparator(a) != AnySortComparator(b))
        #expect(AnySortComparator(b) != AnySortComparator(c))
        #expect(AnySortComparator(a) != AnySortComparator(c))
    }
}
