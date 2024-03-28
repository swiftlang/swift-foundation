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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

@available(FoundationPreview 0.1, *)
class SortComparatorTests: XCTestCase {
    func test_comparable_descriptors() {
        let intDesc: ComparableComparator<Int> = ComparableComparator<Int>()
        XCTAssertEqual(intDesc.compare(0, 1), .orderedAscending)
        let result = intDesc.compare(1000, -10)
        XCTAssertEqual(result, .orderedDescending)
    }
    
    
    func test_order() {
        var intDesc: ComparableComparator<Int> = ComparableComparator<Int>(order: .reverse)
        XCTAssertEqual(intDesc.compare(0, 1), .orderedDescending)
        XCTAssertEqual(intDesc.compare(1000, -10), .orderedAscending)
        XCTAssertEqual(intDesc.compare(100, 100), .orderedSame)
        
        intDesc.order = .forward
        XCTAssertEqual(intDesc.compare(0, 1), .orderedAscending)
        XCTAssertEqual(intDesc.compare(1000, -10), .orderedDescending)
        XCTAssertEqual(intDesc.compare(100, 100), .orderedSame)
    }
    
    func test_compare_options_descriptor() {
        let compareOptions = String.Comparator(options: [.numeric])
        XCTAssertEqual(
            compareOptions.compare("ttestest005", "test2"),
            "test005".compare("test2", options: [.numeric]))
        XCTAssertEqual(
            compareOptions.compare("test2", "test005"),
            "test2".compare("test005", options: [.numeric]))
    }    
}
