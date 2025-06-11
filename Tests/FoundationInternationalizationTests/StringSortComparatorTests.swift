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
@testable import FoundationInternationalization
#else
@testable import Foundation
#endif

@Suite("String SortComparator")
private struct StringSortComparatorTests {
    @Test func compareOptionsDescriptor() {
        let compareOptions = String.Comparator(options: [.numeric])
        #expect(
            compareOptions.compare("ttestest005", "test2") ==
            "test005".compare("test2", options: [.numeric]))
        #expect(
            compareOptions.compare("test2", "test005") ==
            "test2".compare("test005", options: [.numeric]))
    }
    
#if FOUNDATION_FRAMEWORK
    // TODO: Until we support String.compare(_:options:locale:) in FoundationInternationalization, only support unlocalized comparisons
    // https://github.com/apple/swift-foundation/issues/284
    @Test func locale() {
        let swedishComparator = String.Comparator(options: [], locale: Locale(identifier: "sv"))
        #expect(swedishComparator.compare("ă", "ã") == .orderedAscending)
        #expect(swedishComparator.locale, Locale(identifier: "sv"))
    }
    
    @Test func nilLocale() {
        let swedishComparator = String.Comparator(options: [], locale: nil)
        #expect(swedishComparator.compare("ă", "ã") == .orderedDescending)
    }
    
    @Test(.enabled(if: Locale.current.language.languageCode == .english, "Test only verified to work with English as current language"))
    func standardLocalized() throws {
        let localizedStandard = String.StandardComparator.localizedStandard
        #expect(localizedStandard.compare("ă", "ã") == .orderedAscending)
        
        let unlocalizedStandard = String.StandardComparator.lexical
        #expect(unlocalizedStandard.compare("ă", "ã") == .orderedDescending)
    }
#endif
}
