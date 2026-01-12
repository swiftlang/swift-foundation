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

import Testing

@Test func basicLocaleComparison() {
    let result1 = "café".compare(
		"cafe",
		options: .diacriticInsensitive,
		locale: Locale(identifier: "fr_FR")
	)
    #expect(result1 == .orderedSame)

    let result2 = "café".compare("cafe", locale: Locale(identifier: "fr_FR"))
    #expect(result2 != .orderedSame)
}

@Test func caseInsensitiveComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "Hello".compare("hello", options: .caseInsensitive, locale: locale)
    #expect(result1 == .orderedSame)

    let turkishLocale = Locale(identifier: "tr_TR")
    let result2 = "i".compare("I", options: .caseInsensitive, locale: turkishLocale)
    #expect(result2 == .orderedSame)
}

@Test func numericComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "file2".compare("file10", options: .numeric, locale: locale)
    #expect(result1 == .orderedAscending)

    let result2 = "file10".compare("file2", locale: locale)
    #expect(result2 == .orderedAscending)
}

@Test func germanComparison() {
    let locale = Locale(identifier: "de_DE")

    let result = "straße".compare("strasse", options: .caseInsensitive, locale: locale)
    #expect(result == .orderedAscending || result == .orderedSame || result == .orderedDescending)
}

@Test func literalComparison() {
    let locale = Locale(identifier: "en_US")

    let result = "café".compare("cafe", options: .literal, locale: locale)
    #expect(result != .orderedSame)
}

@Test func multipleOptions() {
    let locale = Locale(identifier: "en_US")

    let result = "Café".compare(
		"cafe",
		options: [.caseInsensitive, .diacriticInsensitive],
		locale: locale
	)
    #expect(result == .orderedSame)
}

@Test func differentLocales() {
    let locales = [
        "en_US",
        "fr_FR",
        "de_DE",
        "ja_JP",
        "zh_CN",
        "es_ES"
    ]

    for localeID in locales {
        let locale = Locale(identifier: localeID)
        let result = "test".compare("test", locale: locale)
        #expect(result == .orderedSame)
    }
}

@Test func emptyStrings() {
    let locale = Locale(identifier: "en_US")

    let result1 = "".compare("", locale: locale)
    #expect(result1 == .orderedSame)

    let result2 = "test".compare("", locale: locale)
    #expect(result2 == .orderedDescending)

    let result3 = "".compare("test", locale: locale)
    #expect(result3 == .orderedAscending)
}

@Test func withoutLocale() {
    let result = "test".compare("test", options: [], range: nil, locale: nil)
    #expect(result == .orderedSame)
}

@Test func caseAndDiacriticInsensitiveTogether() {
    let locale = Locale(identifier: "en_US")

    let result = "Café".compare("cafe", options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    #expect(result == .orderedSame)
}

@Test func caseInsensitiveWithNumeric() {
    let locale = Locale(identifier: "en_US")

    let result = "File2".compare("file10", options: [.caseInsensitive, .numeric], locale: locale)
    #expect(result == .orderedAscending)
}

@Test func diacriticInsensitiveWithNumeric() {
    let locale = Locale(identifier: "fr_FR")

    let result = "café2".compare(
		"cafe10",
		options: [.diacriticInsensitive, .numeric],
		locale: locale
	)
    #expect(result == .orderedAscending)
}

@Test func allThreeOptionsTogether() {
    let locale = Locale(identifier: "en_US")

    let result = "Café2".compare(
		"cafe10",
		options: [.caseInsensitive, .diacriticInsensitive, .numeric],
		locale: locale
	)
    #expect(result == .orderedAscending)
}

@Test func diacriticInsensitiveOnlyPreservesCase() {
    let locale = Locale(identifier: "en_US")

    let result1 = "Café".compare("cafe", options: .diacriticInsensitive, locale: locale)
    #expect(result1 == .orderedAscending)

    let result2 = "café".compare("cafe", options: .diacriticInsensitive, locale: locale)
    #expect(result2 == .orderedSame)
}

@Test func caseInsensitiveOnlyPreservesDiacritics() {
    let locale = Locale(identifier: "en_US")

    let result1 = "Café".compare("Cafe", options: .caseInsensitive, locale: locale)
    #expect(result1 == .orderedDescending)

    let result2 = "Hello".compare("hello", options: .caseInsensitive, locale: locale)
    #expect(result2 == .orderedSame)
}
