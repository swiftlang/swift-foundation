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
import Foundation
#else
import FoundationEssentials
import FoundationInternationalization
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
    
    func test_nil_locale() {
        let swedishComparator = String.Comparator(options: [], locale: nil)
        XCTAssertEqual(swedishComparator.compare("ă", "ã"), .orderedDescending)
    }
    
    func test_standard_localized() throws {
        // This test is only verified to work with en
        guard Locale.current.language.languageCode == .english else {
            throw XCTSkip("Test only verified to work with English as current language")
        }
        
        let localizedStandard = String.StandardComparator.localizedStandard
        XCTAssertEqual(localizedStandard.compare("ă", "ã"), .orderedAscending)
        
        let unlocalizedStandard = String.StandardComparator.lexical
        XCTAssertEqual(unlocalizedStandard.compare("ă", "ã"), .orderedDescending)
    }
#endif
}
