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
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

class StringSortComparatorTests: XCTestCase {
#if FOUNDATION_FRAMEWORK
    // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, only support unlocalized comparisons
    // https://github.com/apple/swift-foundation/issues/284
    func test_locale() {
        let swedishComparator = String.Comparator(options: [], locale: Locale(identifier: "sv"))
        XCTAssertEqual(swedishComparator.compare("ă", "ã"), .orderedAscending)
        XCTAssertEqual(swedishComparator.locale, Locale(identifier: "sv"))
    }
#endif    
}
