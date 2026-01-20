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

#if FOUNDATION_FRAMEWORK || FOUNDATION_ICU_STRING_COMPARE

@Test func caseInsensitiveComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "Hello".compare("hello", options: .caseInsensitive, locale: locale)
    #expect(result1 == .orderedSame)

    let turkishLocale = Locale(identifier: "tr_TR")
    let result2 = "i".compare("I", options: .caseInsensitive, locale: turkishLocale)
    #expect(result2 == .orderedDescending)
}

@Test func diacriticInsensitiveComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "café".compare("cafe", options: .diacriticInsensitive, locale: locale)
    #expect(result1 == .orderedSame)

    let result2 = "Café".compare("cafe", options: .diacriticInsensitive, locale: locale)
    #expect(result2 == .orderedDescending)
}

@Test func caseAndDiacriticInsensitive() {
    let locale = Locale(identifier: "en_US")

    let result = "Café".compare("cafe", options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    #expect(result == .orderedSame)
}

@Test func caseInsensitivePreservesDiacritics() {
    let locale = Locale(identifier: "en_US")

    let result1 = "Café".compare("Cafe", options: .caseInsensitive, locale: locale)
    #expect(result1 == .orderedDescending)

    let result2 = "Hello".compare("hello", options: .caseInsensitive, locale: locale)
    #expect(result2 == .orderedSame)
}

@Test func numericComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "file2".compare("file10", options: .numeric, locale: locale)
    #expect(result1 == .orderedAscending)

    let result2 = "file001".compare("file1", options: .numeric, locale: locale)
    #expect(result2 == .orderedSame)

    let result3 = "file007".compare("file010", options: .numeric, locale: locale)
    #expect(result3 == .orderedAscending)
}

@Test func literalComparison() {
    let locale = Locale(identifier: "en_US")

    let result1 = "café".compare("cafe", options: .literal, locale: locale)
    #expect(result1 == .orderedDescending)

    let result2 = "Test".compare("test", options: .literal, locale: locale)
    #expect(result2 == .orderedAscending)

    let result3 = "café".compare("cafe", options: .literal, locale: Locale(identifier: "fr_FR"))
    #expect(result3 == result1)
}

@Test func swedishCollation() {
    let locale = Locale(identifier: "sv_SE")

    let result1 = "å".compare("z", locale: locale)
    #expect(result1 == .orderedDescending)

    let result2 = "ä".compare("z", locale: locale)
    #expect(result2 == .orderedDescending)

    let result3 = "ö".compare("z", locale: locale)
    #expect(result3 == .orderedDescending)
}

@Test func spanishCollation() {
    let locale = Locale(identifier: "es_ES")

    let result = "ñ".compare("n", locale: locale)
    #expect(result == .orderedDescending)
}

@Test func germanCollation() {
    let locale = Locale(identifier: "de_DE")

    let result = "über".compare("uber", locale: locale)
    #expect(result == .orderedDescending)
}

@Test func frenchCollation() {
    let locale = Locale(identifier: "fr_FR")

    let result = "Café".compare("Cafe", options: .caseInsensitive, locale: locale)
    #expect(result == .orderedDescending)
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

@Test func longStrings() {
    let locale = Locale(identifier: "en_US")

    let longString1 = String(repeating: "a", count: 10000)
    let longString2 = String(repeating: "a", count: 10000)
    let longString3 = String(repeating: "a", count: 9999) + "b"

    let result1 = longString1.compare(longString2, locale: locale)
    #expect(result1 == .orderedSame)

    let result2 = longString1.compare(longString3, locale: locale)
    #expect(result2 == .orderedAscending)
}

@Test func invalidLocale() {
    let invalidLocale = Locale(identifier: "xx_YY")

    let result1 = "hello".compare("world", locale: invalidLocale)
    #expect(result1 == .orderedAscending)

    let result2 = "test".compare("test", locale: invalidLocale)
    #expect(result2 == .orderedSame)
}

@Test func comparisonWithoutLocale() {
    let result = "test".compare("test", options: [], range: nil, locale: nil)
    #expect(result == .orderedSame)
}

@Test func caseInsensitiveWithNumeric() {
    let locale = Locale(identifier: "en_US")

    let result = "File2".compare("file10", options: [.caseInsensitive, .numeric], locale: locale)
    #expect(result == .orderedAscending)
}

@Test func diacriticInsensitiveWithNumeric() {
    let locale = Locale(identifier: "fr_FR")

    let result = "café2".compare("cafe10", options: [.diacriticInsensitive, .numeric], locale: locale)
    #expect(result == .orderedAscending)
}

@Test func allThreeOptions() {
    let locale = Locale(identifier: "en_US")

    let result = "Café2".compare("cafe10", options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: locale)
    #expect(result == .orderedAscending)
}

#endif // FOUNDATION_FRAMEWORK || FOUNDATION_ICU_STRING_COMPARE
