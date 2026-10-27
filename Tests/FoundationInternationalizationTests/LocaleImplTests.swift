//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

@Suite("_LocaleImpl", .tags(.locale))
private struct LocaleImplTests {
    typealias Codes = (language: String?, script: String?, region: String?, variant: String?)

    @Test(arguments: [
        (identifier: "en", identifierOut: "en", codes: (language: "en", script: nil, region: nil, variant: nil) as Codes),
        (identifier: "en_US", identifierOut: "en_US", codes: (language: "en", script: nil, region: "US", variant: nil) as Codes),
        (identifier: "en-us", identifierOut: "en-US", codes: (language: "en", script: nil, region: "US", variant: nil) as Codes),
        (identifier: "es_419", identifierOut: "es_419", codes: (language: "es", script: nil, region: "419", variant: nil) as Codes),
        (identifier: "sr_Latn_RS", identifierOut: "sr-Latn_RS", codes: (language: "sr", script: "Latn", region: "RS", variant: nil) as Codes),
        (identifier: "zh-Hans_CN", identifierOut: "zh_CN", codes: (language: "zh", script: nil, region: "CN", variant: nil) as Codes),
        (identifier: "eng_US", identifierOut: "en_US", codes: (language: "en", script: nil, region: "US", variant: nil) as Codes),
        (identifier: "en_US_POSIX", identifierOut: "en_US_POSIX", codes: (language: "en", script: nil, region: "US", variant: "POSIX") as Codes),
        (identifier: "ca_ES_VALENCIA", identifierOut: "ca_ES_VALENCIA", codes: (language: "ca", script: nil, region: "ES", variant: "VALENCIA") as Codes),
    ])
    func identifierAndCodes(testCase: (identifier: String, identifierOut: String, codes: Codes)) {
        let locale = _LocaleImpl(identifier: testCase.identifier)
        #expect(locale.identifier == testCase.identifierOut, "identifier of \"\(testCase.identifier)\"")
        #expect(locale.languageCode == testCase.codes.language, "language of \"\(testCase.identifier)\"")
        #expect(locale.scriptCode == testCase.codes.script, "script of \"\(testCase.identifier)\"")
        #expect(locale.regionCode == testCase.codes.region, "region of \"\(testCase.identifier)\"")
        #expect(locale.variantCode == testCase.codes.variant, "variant of \"\(testCase.identifier)\"")
    }

    @Test func keywordValues() {
        let locale = _LocaleImpl(identifier: "en_US@calendar=japanese;numbers=thai;rg=gbzzzz")
        #expect(locale.calendarIdentifier == .japanese)
        #expect(locale.numberingSystem == Locale.NumberingSystem("thai"))
        #expect(locale.region?.identifier == "GB")

        let withoutKeywords = _LocaleImpl(identifier: "en_US")
        #expect(withoutKeywords.region?.identifier == "US")
    }

    // The region code uses the region of the "rg" keyword if there is one.
    @Test(arguments: [
        (identifier: "en_US", regionCode: "US" as String?),
        (identifier: "en_US@rg=gbzzzz", regionCode: "GB"),
        (identifier: "en@rg=thzzzz", regionCode: "TH"),
        (identifier: "en", regionCode: nil),
    ])
    func regionCode(testCase: (identifier: String, regionCode: String?)) {
        #expect(_LocaleImpl(identifier: testCase.identifier).regionCode == testCase.regionCode, "region code of \"\(testCase.identifier)\"")
    }

    @Test func fromComponents() {
        var components = Locale.Components(languageCode: "zh", script: "Hant", languageRegion: "TW")
        components.calendar = .gregorian
        components.numberingSystem = Locale.NumberingSystem("arab")

        let locale = _LocaleImpl(components: components)
        #expect(locale.languageCode == "zh")
        #expect(locale.scriptCode == "Hant")
        #expect(locale.regionCode == "TW")
        #expect(locale.variantCode == nil)
        #expect(locale.calendarIdentifier == .gregorian)
        #expect(locale.numberingSystem == Locale.NumberingSystem("arab"))
    }

    // The identifier has the variant of the components as the "va" keyword, but the locale still has the variant.
    @Test(arguments: ["POSIX", "valencia"])
    func fromComponentsWithVariant(variant: String) {
        var components = Locale.Components(languageCode: "en", languageRegion: "US")
        components.variant = Locale.Variant(variant)

        let locale = _LocaleImpl(components: components)
        #expect(locale.variantCode == variant)
        #expect(locale.variant == Locale.Variant(variant))
    }

    @Test(arguments: [
        (identifier: "en", icu: "en"),
        (identifier: "en_US", icu: "en_US"),
        (identifier: "en-US", icu: "en_US"),
        (identifier: "zh-Hans_CN", icu: "zh_CN"),
        (identifier: "zh_Hant_TW", icu: "zh_TW"),
        (identifier: "sr_Latn_RS", icu: "sr_Latn_RS"),
        (identifier: "eng_US", icu: "en_US"),
        (identifier: "es_419", icu: "es_419"),
        (identifier: "en_US_POSIX", icu: "en_US_POSIX"),
        (identifier: "de-1996", icu: "de__1996"),
        (identifier: "ca_ES_VALENCIA", icu: "ca_ES_VALENCIA"),
        (identifier: "ja_JP@calendar=japanese;collation=phonebook", icu: "ja_JP@calendar=japanese;collation=phonebook"),
        (identifier: "th_TH@calendar=buddhist;numbers=thai", icu: "th_TH@calendar=buddhist;numbers=thai"),
        (identifier: "en_US@rg=gbzzzz;fw=mon;hours=h23", icu: "en_US@fw=mon;hours=h23;rg=gbzzzz"),
        (identifier: "und", icu: "und"),
        (identifier: "iw_IL", icu: "he_IL"),
        (identifier: "no_NO", icu: "nb_NO"),
        (identifier: "en_001", icu: "en_001"),
        (identifier: "zh_Hans", icu: "zh_Hans"),
        (identifier: "ar_SA@numbers=arab", icu: "ar_SA@numbers=arab"),
        (identifier: "en_US@timezone=America/New_York", icu: "en_US@timezone=America/New_York"),
        (identifier: "en_US@currency=EUR", icu: "en_US@currency=EUR"),
    ])
    func icuIdentifier(testCase: (identifier: String, icu: String)) {
        #expect(_LocaleImpl(identifier: testCase.identifier).identifier(.icu) == testCase.icu, "icu identifier of \"\(testCase.identifier)\"")
    }

    @Test(arguments: [
        (identifier: "en_US@nu=latn;ca=gregory", expected: "en_US@ca=gregory;nu=latn"),
        (identifier: "en_US@numbers=latn;calendar=gregorian", expected: "en_US@calendar=gregorian;numbers=latn"),
        (identifier: "en_US@timezone=America/New_York", expected: "en_US@timezone=America/New_York"),
    ])
    func icuIdentifierNormalizesKeywords(testCase: (identifier: String, expected: String)) {
        #expect(_LocaleImpl(identifier: testCase.identifier).identifier(.icu) == testCase.expected, "input \"\(testCase.identifier)\"")
    }

    // A leading "i-" is part of the language.
    @Test(arguments: [
        (identifier: "i-klingon", language: "i-klingon", region: nil as String?, variant: nil as String?),
        (identifier: "I_Klingon", language: "I_Klingon", region: nil, variant: nil),
    ])
    func languagePrefix(testCase: (identifier: String, language: String, region: String?, variant: String?)) {
        var identifier = testCase.identifier
        identifier.withUTF8 { buffer in
            let span = buffer.span
            let ranges = Locale.CanonicalizedIdentifier.componentRanges(of: span)
            #expect(ranges.language.map { Locale.CanonicalizedIdentifier.string(from: span.extracting($0)) } == testCase.language, "language of \"\(testCase.identifier)\"")
            #expect(ranges.region.map { Locale.CanonicalizedIdentifier.string(from: span.extracting($0)) } == testCase.region, "region of \"\(testCase.identifier)\"")
            #expect(ranges.variant.map { Locale.CanonicalizedIdentifier.string(from: span.extracting($0)) } == testCase.variant, "variant of \"\(testCase.identifier)\"")
        }
    }

    @Test(arguments: [
        (language: "en", script: "", region: "US", expected: "latn"),
        (language: "ar", script: "", region: "EG", expected: "arab"),
        (language: "ar", script: "", region: "MA", expected: "latn"),
        (language: "ckb", script: "", region: "", expected: "arab"),
        (language: "fa", script: "", region: "IR", expected: "arabext"),
        (language: "uz", script: "Arab", region: "", expected: "arabext"),
        (language: "uz", script: "Latn", region: "", expected: "latn"),
        (language: "ff", script: "Adlm", region: "", expected: "adlm"),
        (language: "ff", script: "", region: "", expected: "latn"),
        (language: "mni", script: "Mtei", region: "", expected: "mtei"),
        (language: "mni", script: "", region: "", expected: "beng"),
        (language: "sat", script: "Deva", region: "", expected: "deva"),
        (language: "sat", script: "", region: "", expected: "olck"),
        (language: "ne", script: "", region: "NP", expected: "deva"),
        (language: "my", script: "", region: "", expected: "mymr"),
        (language: "dz", script: "", region: "", expected: "tibt"),
        (language: "sd", script: "", region: "", expected: "arab"),
        (language: "sd", script: "Deva", region: "IN", expected: "latn"),
        (language: "ks", script: "", region: "", expected: "arabext"),
        (language: "ks", script: "Deva", region: "IN", expected: "latn"),
        (language: "pa", script: "Guru", region: "IN", expected: "latn"),
        (language: "pa", script: "Arab", region: "PK", expected: "arabext"),
        (language: "pa", script: "Aran", region: "PK", expected: "arabext"),
        (language: "az", script: "Arab", region: "", expected: "latn"),
    ])
    func defaultNumberingSystem(testCase: (language: String, script: String, region: String, expected: String)) {
        let numberingSystem = _LocaleImpl.defaultNumberingSystem(forLanguage: testCase.language.utf8Span.span, script: testCase.script.utf8Span.span, region: testCase.region.utf8Span.span)
        #expect(numberingSystem == testCase.expected)
    }

    @Test(arguments: [
        (region: "", expected: Calendar.Identifier.gregorian),
        (region: "US", expected: .gregorian),
        (region: "419", expected: .gregorian),
        (region: "AF", expected: .persian),
        (region: "IR", expected: .persian),
        (region: "ir", expected: .persian),
        (region: "SA", expected: .islamicUmmAlQura),
        (region: "TH", expected: .buddhist),
    ])
    func defaultCalendar(testCase: (region: String, expected: Calendar.Identifier)) {
        #expect(_LocaleImpl.defaultCalendar(forRegion: testCase.region.utf8Span.span) == testCase.expected)
    }

    @Test(arguments: [
        (identifier: "th", calendar: Calendar.Identifier.buddhist, region: nil as String?),
        (identifier: "fa", calendar: .persian, region: nil),
        (identifier: "ps", calendar: .persian, region: nil),
        (identifier: "en", calendar: .gregorian, region: nil),
        (identifier: "th_US", calendar: .gregorian, region: "US"),
        (identifier: "en@rg=thzzzz", calendar: .buddhist, region: "TH"),
        (identifier: "en_GB@rg=uszzzz", calendar: .gregorian, region: "US"),
    ])
    func calendarAndRegion(testCase: (identifier: String, calendar: Calendar.Identifier, region: String?)) {
        let locale = _LocaleImpl(identifier: testCase.identifier)
        #expect(locale.calendarIdentifier == testCase.calendar, "calendar of \"\(testCase.identifier)\"")
        #expect(locale.region?.identifier == testCase.region, "region of \"\(testCase.identifier)\"")
    }

    @Test(arguments: ["de_DD", "de-DD"])
    func deprecatedRegionIsNotReplacedYet(identifier: String) {
        withKnownIssue("Deprecated codes are not replaced by their current codes yet, so DD is not replaced by DE") {
            #expect(_LocaleImpl(identifier: identifier).identifier(.icu) == "de_DE")
        }
    }

}
