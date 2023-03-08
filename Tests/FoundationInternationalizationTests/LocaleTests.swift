//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %empty-directory(%t)
//
// RUN: %target-clang %S/Inputs/FoundationBridge/FoundationBridge.m -c -o %t/FoundationBridgeObjC.o -g
// RUN: %target-build-swift %s -I %S/Inputs/FoundationBridge/ -Xlinker %t/FoundationBridgeObjC.o -o %t/TestLocale
// RUN: %target-codesign %t/TestLocale

// RUN: %target-run %t/TestLocale > %t.txt
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

#if canImport(TestSupport)
import TestSupport
#endif

final class LocaleTests : XCTestCase {

    func test_equality() {
        let autoupdating = Locale.autoupdatingCurrent
        let autoupdating2 = Locale.autoupdatingCurrent

        XCTAssertEqual(autoupdating, autoupdating2)

        let current = Locale.current

        XCTAssertNotEqual(autoupdating, current)
    }

    func test_localizedStringFunctions() {
        let locale = Locale(identifier: "en")

        XCTAssertEqual("English", locale.localizedString(forIdentifier: "en"))
        XCTAssertEqual("France", locale.localizedString(forRegionCode: "fr"))
        XCTAssertEqual("Spanish", locale.localizedString(forLanguageCode: "es"))
        XCTAssertEqual("Simplified Han", locale.localizedString(forScriptCode: "Hans"))
        XCTAssertEqual("Computer", locale.localizedString(forVariantCode: "POSIX"))
        XCTAssertEqual("Buddhist Calendar", locale.localizedString(for: .buddhist))
        XCTAssertEqual("US Dollar", locale.localizedString(forCurrencyCode: "USD"))
        XCTAssertEqual("Phonebook Sort Order", locale.localizedString(forCollationIdentifier: "phonebook"))
        // Need to find a good test case for collator identifier
        // XCTAssertEqual("something", locale.localizedString(forCollatorIdentifier: "en"))
    }

    @available(macOS, deprecated: 13)
    @available(iOS, deprecated: 16)
    @available(tvOS, deprecated: 16)
    @available(watchOS, deprecated: 9)
    func test_properties_complexIdentifiers() {
        struct S {
            var identifier: String
            var countryCode: String?
            var languageCode: String?
            var script: String?
            var calendar: Calendar.Identifier?
            var currency: Locale.Currency?
            var collation: Locale.Collation?
        }

        let tests = [
            S(identifier: "zh-Hant_JP@calendar=japanese;currency=EUR;collation=stroke", countryCode: "JP", languageCode: "zh", script: "Hant", calendar: .japanese, currency: .init("EUR"), collation: .init("stroke")),
            S(identifier: "en_US@calendar=hebrew", countryCode: "US", languageCode: "en", script: nil, calendar: .hebrew, currency: .init("USD"), collation: .standard),
            S(identifier: "hi_AU@collation=standard;currency=CHF;calendar=islamic", countryCode: "AU", languageCode: "hi", script: nil, calendar: .islamic, currency: .init("CHF"), collation: .init("standard")),
            S(identifier: "yue-Hans@collation=phonebook", countryCode: nil, languageCode: "yue", script: "Hans", calendar: .gregorian, currency: nil, collation: Locale.Collation("phonebook")),
            S(identifier: "en_GB@numbers=hanidec", countryCode: "GB", languageCode: "en", script: nil, calendar: .gregorian, currency: .init("GBP"), collation: .standard)]

        for t in tests {
            let l = Locale(identifier: t.identifier)
            XCTAssertEqual(t.countryCode, l.regionCode, "Failure for id \(t.identifier)")
            XCTAssertEqual(t.languageCode, l.languageCode, "Failure for id \(t.identifier)")
            XCTAssertEqual(t.script, l.scriptCode, "Failure for id \(t.identifier)")
            XCTAssertEqual(t.calendar, l.calendar.identifier, "Failure for id \(t.identifier)")
            XCTAssertEqual(t.currency, l.currency, "Failure for id \(t.identifier)")
            XCTAssertEqual(t.collation, l.collation, "Failure for id \(t.identifier)")
        }
    }

    func test_AnyHashableContainingLocale() {
        let values: [Locale] = [
            Locale(identifier: "en"),
            Locale(identifier: "uk"),
            Locale(identifier: "uk"),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Locale.self, type(of: anyHashables[0].base))
        expectEqual(Locale.self, type(of: anyHashables[1].base))
        expectEqual(Locale.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func decodeHelper(_ l: Locale) -> Locale {
        let je = JSONEncoder()
        let data = try! je.encode(l)
        let jd = JSONDecoder()
        return try! jd.decode(Locale.self, from: data)
    }

    func test_serializationOfCurrent() {
        let current = Locale.current
        let decodedCurrent = decodeHelper(current)
        XCTAssertEqual(decodedCurrent, current)

        let autoupdatingCurrent = Locale.autoupdatingCurrent
        let decodedAutoupdatingCurrent = decodeHelper(autoupdatingCurrent)
        XCTAssertEqual(decodedAutoupdatingCurrent, autoupdatingCurrent)

        XCTAssertNotEqual(decodedCurrent, decodedAutoupdatingCurrent)
        XCTAssertNotEqual(current, autoupdatingCurrent)
        XCTAssertNotEqual(decodedCurrent, autoupdatingCurrent)
        XCTAssertNotEqual(current, decodedAutoupdatingCurrent)
    }

    func test_identifierWithCalendar() throws {
        XCTAssertEqual(Calendar.localeIdentifierWithCalendar(localeIdentifier: "en_US", calendarIdentifier: .islamicTabular), "en_US@calendar=islamic-tbla")
        XCTAssertEqual(Calendar.localeIdentifierWithCalendar(localeIdentifier: "zh-Hant-TW@calendar=japanese;collation=pinyin;numbers=arab", calendarIdentifier: .islamicTabular), "zh-Hant_TW@calendar=islamic-tbla;collation=pinyin;numbers=arab")
    }

    func test_identifierTypesFromComponents() throws {

        func verify(cldr: String, bcp47: String, icu: String, file: StaticString = #file, line: UInt = #line, _ components: () -> Locale.Components) {
            let loc = Locale(components: components())
            let types: [Locale.IdentifierType] = [.cldr, .bcp47, .icu]
            let expected = [cldr, bcp47, icu]
            for (idx, type) in types.enumerated() {
                XCTAssertEqual(loc.identifier(type), expected[idx], "type: \(type)", file: file, line: line)
            }
        }

        verify(cldr: "en_US", bcp47: "en-US", icu: "en_US") {
            Locale.Components(locale: Locale(identifier: "en_US"))
        }

        verify(cldr: "en_US", bcp47: "en-US", icu: "en_US") {
            var localeComponents = Locale.Components(identifier: "")
            localeComponents.languageComponents = Locale.Language.Components(languageCode: .english, region: .unitedStates)
            return localeComponents
        }

        verify(cldr: "de_DE_u_co_phonebk", bcp47: "de-DE-u-co-phonebk", icu: "de_DE@collation=phonebook") {
            var localeComponents = Locale.Components(identifier: "")
            localeComponents.languageComponents = Locale.Language.Components(languageCode: .german, region: .germany)
            localeComponents.collation = .init("phonebook")
            return localeComponents
        }

        verify(cldr: "root", bcp47: "und", icu: "en_US_POSIX") {
            return Locale.Components(identifier: "")
        }

        verify(cldr: "und_US", bcp47: "und-US", icu: "_US") {
            return Locale.Components(languageRegion: .unitedStates)
        }

        verify(cldr: "und_US", bcp47: "und-US", icu: "und_US") {
            return Locale.Components(languageCode: .unidentified ,languageRegion: .unitedStates)
        }

        verify(cldr: "und_Latn_DE", bcp47: "und-Latn-DE", icu: "_Latn_DE") {
            return Locale.Components(script: .latin, languageRegion: .germany)
        }

        verify(cldr: "und_Latn_DE", bcp47: "und-Latn-DE", icu: "und_Latn_DE") {
            return Locale.Components(languageCode: .unidentified, script: .latin, languageRegion: .germany)
        }

        verify(cldr: "en_u_ca_gregory", bcp47: "en-u-ca-gregory", icu: "en@calendar=gregorian") {
            var localeComponents = Locale.Components(languageCode: .english)
            localeComponents.calendar = .gregorian
            return localeComponents
        }

        verify(cldr: "fr_u_cu_eur_nu_latn", bcp47: "fr-u-cu-eur-nu-latn", icu: "fr@currency=eur;numbers=latn") {
            var localeComponents = Locale.Components(languageCode: .french)
            localeComponents.currency = "eur"
            localeComponents.numberingSystem = .latn
            return localeComponents
        }

        verify(cldr: "en_u_va_posix", bcp47: "en-u-va-posix", icu: "en@va=posix") {
            var localeComponents = Locale.Components(languageCode: .english)
            localeComponents.variant = .posix
            return localeComponents
        }

        verify(cldr: "und_u_ca_islamic_civil", bcp47: "und-u-ca-islamic-civil", icu: "@calendar=islamic-civil") {
            var localeComponents = Locale.Components(identifier: "")
            localeComponents.calendar = .islamicCivil
            return localeComponents
        }

        // Unrecognized components

        verify(cldr: "root", bcp47: "und", icu: "123") {
            return Locale.Components(languageCode: "123")
        }

        verify(cldr: "und_123", bcp47: "und-123", icu: "_123") {
            return Locale.Components(languageRegion: "123")
        }

        verify(cldr: "hello_123", bcp47: "hello-123", icu: "hello_123") {
            Locale.Components(languageCode: "hello", languageRegion: "123")
        }

        verify(cldr: "de_123", bcp47: "de-123", icu: "de_123") {
            Locale.Components(languageCode: .german, languageRegion: "123")
        }

        verify(cldr: "de_123_u_va_5678", bcp47: "de-123-u-va-5678", icu: "de_123@va=5678") {
            var c = Locale.Components(languageCode: .german, languageRegion: "123")
            c.variant = "5678"
            return c
        }

        verify(cldr: "und_u_co_foo_nu_blah", bcp47: "und-u-co-foo-nu-blah", icu: "@collation=foo;numbers=blah") {
            var localeComponents = Locale.Components(identifier: "")
            localeComponents.numberingSystem = "BLAH"
            localeComponents.collation = "FOO"
            return localeComponents
        }
    }

    func verify(_ locID: String, cldr: String, bcp47: String, icu: String, file: StaticString = #file, line: UInt = #line) {
        let loc = Locale(identifier: locID)
        let types: [Locale.IdentifierType] = [.cldr, .bcp47, .icu]
        let expected = [cldr, bcp47, icu]
        for (idx, type) in types.enumerated() {
            XCTAssertEqual(loc.identifier(type), expected[idx], "type: \(type)", file: file, line: line)
        }
    }
}

final class LocalePropertiesTests : XCTestCase {

    func _verify(locale: Locale, expectedLanguage language: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil, region: Locale.Region? = nil, subdivision: Locale.Subdivision? = nil, measurementSystem: Locale.MeasurementSystem? = nil, calendar: Calendar.Identifier? = nil, hourCycle: Locale.HourCycle? = nil, currency: Locale.Currency? = nil, numberingSystem: Locale.NumberingSystem? = nil, numberingSystems: Set<Locale.NumberingSystem> = [], firstDayOfWeek: Locale.Weekday? = nil, collation: Locale.Collation? = nil, variant: Locale.Variant? = nil, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(locale.language.languageCode, language, "languageCode should be equal", file: file, line: line)
        XCTAssertEqual(locale.language.script, script, "script should be equal", file: file, line: line)
        XCTAssertEqual(locale.language.region, languageRegion, "language region should be equal", file: file, line: line)
        XCTAssertEqual(locale.region, region, "region should be equal", file: file, line: line)
        XCTAssertEqual(locale.subdivision, subdivision, "subdivision should be equal", file: file, line: line)
        XCTAssertEqual(locale.measurementSystem, measurementSystem, "measurementSystem should be equal", file: file, line: line)
        XCTAssertEqual(locale.calendar.identifier, calendar, "calendar.identifier should be equal", file: file, line: line)
        XCTAssertEqual(locale.hourCycle, hourCycle, "hourCycle should be equal", file: file, line: line)
        XCTAssertEqual(locale.currency, currency, "currency should be equal", file: file, line: line)
        XCTAssertEqual(locale.numberingSystem, numberingSystem, "numberingSystem should be equal", file: file, line: line)
        XCTAssertEqual(Set(locale.availableNumberingSystems), numberingSystems, "availableNumberingSystems should be equal", file: file, line: line)
        XCTAssertEqual(locale.firstDayOfWeek, firstDayOfWeek, "firstDayOfWeek should be equal", file: file, line: line)
        XCTAssertEqual(locale.collation, collation, "collation should be equal", file: file, line: line)
        XCTAssertEqual(locale.variant, variant, "variant should be equal", file: file, line: line)
    }

    func verify(_ identifier: String, expectedLanguage language: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil, region: Locale.Region? = nil, subdivision: Locale.Subdivision? = nil, measurementSystem: Locale.MeasurementSystem? = nil, calendar: Calendar.Identifier? = nil, hourCycle: Locale.HourCycle? = nil, currency: Locale.Currency? = nil, numberingSystem: Locale.NumberingSystem? = nil, numberingSystems: Set<Locale.NumberingSystem> = [], firstDayOfWeek: Locale.Weekday? = nil, collation: Locale.Collation? = nil, variant: Locale.Variant? = nil, file: StaticString = #file, line: UInt = #line) {
        let loc = Locale(identifier: identifier)
        _verify(locale: loc, expectedLanguage: language, script: script, languageRegion: languageRegion, region: region, subdivision: subdivision, measurementSystem: measurementSystem, calendar: calendar, hourCycle: hourCycle, currency: currency, numberingSystem: numberingSystem, numberingSystems: numberingSystems, firstDayOfWeek: firstDayOfWeek, collation: collation, variant: variant, file: file, line: line)
    }

    func test_defaultValue() {
        verify("en_US", expectedLanguage: "en", script: "Latn", languageRegion: "US", region: "US", measurementSystem: .us, calendar: .gregorian, hourCycle: .oneToTwelve, currency: "USD", numberingSystem: "latn", numberingSystems: [ "latn" ], firstDayOfWeek: .sunday, collation: .standard, variant: nil)

        verify("en_GB", expectedLanguage: "en", script: "Latn", languageRegion: "GB", region: "GB", measurementSystem: .uk, calendar: .gregorian, hourCycle: .zeroToTwentyThree, currency: "GBP", numberingSystem: "latn", numberingSystems: [ "latn" ], firstDayOfWeek: .monday, collation: .standard, variant: nil)

        verify("zh_TW", expectedLanguage: "zh", script: "Hant", languageRegion: "TW", region: "TW", measurementSystem: .metric, calendar: .gregorian, hourCycle: .oneToTwelve, currency: "TWD", numberingSystem: "latn", numberingSystems: [ "latn", "hantfin", "hanidec", "hant" ], firstDayOfWeek: .sunday, collation: .standard, variant: nil)

        verify("ar_EG", expectedLanguage: "ar", script: "arab", languageRegion: "EG", region: "EG", measurementSystem: .metric, calendar: .gregorian, hourCycle: .oneToTwelve, currency: "EGP", numberingSystem: "arab", numberingSystems: [ "latn", "arab" ], firstDayOfWeek: .saturday, collation: .standard, variant: nil)
    }

    func test_keywordOverrides() {

        verify("ar_EG@calendar=ethioaa;collation=dict;currency=frf;fw=fri;hours=h11;measure=uksystem;numbers=traditio;rg=uszzzz", expectedLanguage: "ar", script: "arab", languageRegion: "EG", region: "us", subdivision: nil, measurementSystem: .uk, calendar: .ethiopicAmeteAlem, hourCycle: .zeroToEleven, currency: "FRF", numberingSystem: "traditio", numberingSystems: [ "traditio", "latn", "arab" ], firstDayOfWeek: .friday, collation: "dict")

        // With legacy values
        verify("ar_EG@calendar=ethiopic-amete-alem;collation=dictionary;measure=imperial;numbers=traditional", expectedLanguage: "ar", script: "arab", languageRegion: "EG", region: "EG", measurementSystem: .uk, calendar: .ethiopicAmeteAlem, hourCycle: .oneToTwelve, currency: "EGP", numberingSystem: "traditional", numberingSystems: [ "traditional", "latn", "arab" ], firstDayOfWeek: .saturday, collation: "dictionary", variant: nil)

        verify("ar-EG-u-ca-ethioaa-co-dict-cu-frf-fw-fri-hc-h11-ms-uksystem-nu-traditio-rg-uszzzz",expectedLanguage: "ar", script: "arab", languageRegion: "EG", region: "us", subdivision: nil, measurementSystem: .uk, calendar: .ethiopicAmeteAlem, hourCycle: .zeroToEleven, currency: "FRF", numberingSystem: "traditional", numberingSystems: [ "traditional", "latn", "arab" ], firstDayOfWeek: .friday, collation: "dictionary")
        
        verify("ar_EG@calendar=ethioaa;collation=dict;currency=frf;fw=fri;hours=h11;measure=uksystem;numbers=traditio;rg=uszzzz;sd=usca", expectedLanguage: "ar", script: "arab", languageRegion: "EG", region: "us", subdivision: "usca", measurementSystem: .uk, calendar: .ethiopicAmeteAlem, hourCycle: .zeroToEleven, currency: "FRF", numberingSystem: "traditio", numberingSystems: [ "traditio", "latn", "arab" ], firstDayOfWeek: .friday, collation: "dict")
    }

    func test_localeComponentsAndLocale() {
        func verify(components: Locale.Components, identifier: String, file: StaticString = #file, line: UInt = #line) {
            let locFromComponents = Locale(components: components)
            let locFromIdentifier = Locale(identifier: identifier)
            _verify(locale: locFromComponents, expectedLanguage: locFromIdentifier.language.languageCode, script: locFromIdentifier.language.script, languageRegion: locFromIdentifier.language.region, region: locFromIdentifier.region, measurementSystem: locFromIdentifier.measurementSystem, calendar: locFromIdentifier.calendar.identifier, hourCycle: locFromIdentifier.hourCycle, currency: locFromIdentifier.currency, numberingSystem: locFromIdentifier.numberingSystem, numberingSystems: Set(locFromIdentifier.availableNumberingSystems), firstDayOfWeek: locFromIdentifier.firstDayOfWeek, collation: locFromIdentifier.collation, variant: locFromIdentifier.variant, file: file, line: line)
        }


        verify(components: Locale.Components(languageCode: "en", languageRegion: "US"), identifier: "en_US")
        verify(components: Locale.Components(languageCode: "en", languageRegion: "GB"), identifier: "en_GB")
        verify(components: Locale.Components(languageCode: "en", languageRegion: "JP"), identifier: "en_JP")

        verify(components: Locale.Components(languageCode: "zh"), identifier: "zh")
        verify(components: Locale.Components(languageCode: "zh", languageRegion: "CN"), identifier: "zh_CN")
        verify(components: Locale.Components(languageCode: "zh", script: "Hans", languageRegion: "CN"), identifier: "zh_CN")

        verify(components: Locale.Components(languageCode: "zh", languageRegion: "TW"), identifier: "zh_TW")
        verify(components: Locale.Components(languageCode: "zh", script: "Hant", languageRegion: "TW"), identifier: "zh-Hant_TW")
        verify(components: Locale.Components(languageCode: "zh", script: "Hant", languageRegion: "TW"), identifier: "zh_TW")
        verify(components: Locale.Components(languageCode: "zh", script: "Hans", languageRegion: "TW"), identifier: "zh-Hans_TW")

        var custom = Locale.Components(languageCode: "en", languageRegion: "US")
        custom.measurementSystem = .metric
        custom.currency = "GBP"
        custom.calendar = .japanese
        custom.region = "HK"
        custom.timeZone = TimeZone(identifier: "America/Rio_Branco")
        custom.numberingSystem = "Arab"
        custom.firstDayOfWeek = .tuesday
        custom.collation = "Phonebook"
        custom.hourCycle = .zeroToEleven
        let customLoc = Locale(components: custom)
        _verify(locale: customLoc, expectedLanguage: "en", script: "Latn", languageRegion: "US", region: "HK", measurementSystem: .metric, calendar: .japanese, hourCycle: .zeroToEleven, currency: "GBP", numberingSystem: "Arab", numberingSystems: [ "Arab", "Latn" ], firstDayOfWeek: .tuesday, collation: "Phonebook", variant: nil)
    }

    // Test retrieving user's preference values as set in the system settings
    func test_userPreferenceOverride_hourCycle() {
        func verifyHourCycle(_ localeID: String, _ expectDefault: Locale.HourCycle, shouldRespectUserPref: Bool, file: StaticString = #file, line: UInt = #line) {
            let loc = Locale(identifier: localeID)
            XCTAssertEqual(loc.hourCycle, expectDefault,  "default did not match", file: file, line: line)

            let defaultLoc = Locale.likeCurrent(identifier: localeID, preferences: .init())
            XCTAssertEqual(defaultLoc.hourCycle, expectDefault, "explicit no override did not match", file: file, line: line)

            let force24 = Locale.likeCurrent(identifier: localeID, preferences: .init(force24Hour: true))
            XCTAssertEqual(force24.hourCycle, shouldRespectUserPref ? .zeroToTwentyThree : expectDefault, "force 24-hr did not match", file: file, line: line)

            let force12 = Locale.likeCurrent(identifier: localeID, preferences: .init(force12Hour: true))
            XCTAssertEqual(force12.hourCycle, shouldRespectUserPref ? .oneToTwelve : expectDefault, "force 12-hr did not match", file: file, line: line)
        }


        verifyHourCycle("en_US", .oneToTwelve, shouldRespectUserPref: true)
        verifyHourCycle("en_GB", .zeroToTwentyThree, shouldRespectUserPref: true)
        verifyHourCycle("zh_TW", .oneToTwelve, shouldRespectUserPref: true)
        verifyHourCycle("en_US@rg=GBZZZZ", .zeroToTwentyThree, shouldRespectUserPref: true)
        verifyHourCycle("en_GB@rg=uszzzz", .oneToTwelve, shouldRespectUserPref: true)

        // Both ICU locale ID and BCP 47 keywords are recognized
        verifyHourCycle("en_US@hours=h23", .zeroToTwentyThree, shouldRespectUserPref: false)
        verifyHourCycle("en_GB@hours=h12", .oneToTwelve, shouldRespectUserPref: false)
        verifyHourCycle("en-US-u-hc-h23", .zeroToTwentyThree, shouldRespectUserPref: false)
        verifyHourCycle("en-GB-u-hc-h12", .oneToTwelve, shouldRespectUserPref: false)

        verifyHourCycle("en_GB@rg=x", .zeroToTwentyThree, shouldRespectUserPref: true) // invalid region code is ignored
        verifyHourCycle("en_US@hc=h23", .oneToTwelve, shouldRespectUserPref: true) // Incorrect keyword key is ignored; ICU uses "hours", not the BCP-47 version "hc"
        verifyHourCycle("en_US@hours=h25", .oneToTwelve, shouldRespectUserPref: true) // Incorrect keyword value for "hour cycle" is ignored; correct is "hours=h23"
    }

    func test_userPreferenceOverride_measurementSystem() {
        func verify(_ localeID: String, _ expected: Locale.MeasurementSystem, shouldRespectUserPref: Bool, file: StaticString = #file, line: UInt = #line) {
            let localeNoPref = Locale.likeCurrent(identifier: localeID, preferences: .init())
            XCTAssertEqual(localeNoPref.measurementSystem, expected, file: file, line: line)

            let fakeCurrentMetric = Locale.likeCurrent(identifier: localeID, preferences: .init(measurementSystem: .metric))
            XCTAssertEqual(fakeCurrentMetric.measurementSystem, shouldRespectUserPref ? .metric : expected, file: file, line: line)

            let fakeCurrentUS = Locale.likeCurrent(identifier: localeID, preferences: .init(measurementSystem: .us))
            XCTAssertEqual(fakeCurrentUS.measurementSystem, shouldRespectUserPref ? .us : expected, file: file, line: line)

            let fakeCurrentUK = Locale.likeCurrent(identifier: localeID, preferences: .init(measurementSystem: .uk))
            XCTAssertEqual(fakeCurrentUK.measurementSystem, shouldRespectUserPref ? .uk : expected, file: file, line: line)
        }

        verify("en_US", .us, shouldRespectUserPref: true)
        verify("en_GB", .uk, shouldRespectUserPref: true)
        verify("en_NZ", .metric, shouldRespectUserPref: true)
        verify("en_US@measure=uksystem", .uk, shouldRespectUserPref: false) // `ms` keyword always takes precedence
        verify("en_GB@measure=metric", .metric, shouldRespectUserPref: false) // `ms` keyword always takes precedence
        verify("en_GB@rg=uszzzz", .us, shouldRespectUserPref: true) // use the one preferred by `rg`
        verify("en_US@rg=x", .us, shouldRespectUserPref: true) // invalid `rg` keyword value
        verify("en_US@ms=uksystem", .us, shouldRespectUserPref: true) // invalid keyword key; ICU uses "measure", not "ms"

        // BCP-47 identifier also works
        verify("en-US-u-ms-uksystem", .uk, shouldRespectUserPref: false)
        verify("en-GB-u-ms-metric", .metric, shouldRespectUserPref: false)
        verify("en-GB-u-rg-uszzzz", .us, shouldRespectUserPref: true)
    }

    @available(macOS, deprecated: 13)
    @available(iOS, deprecated: 16)
    @available(tvOS, deprecated: 16)
    @available(watchOS, deprecated: 9)
    func test_properties() {
        let locale = Locale(identifier: "zh-Hant-HK")

        XCTAssertEqual("zh-Hant-HK", locale.identifier)
        XCTAssertEqual("zh", locale.languageCode)
        XCTAssertEqual("HK", locale.regionCode)
        XCTAssertEqual("Hant", locale.scriptCode)
        XCTAssertEqual("POSIX", Locale(identifier: "en_POSIX").variantCode)
        XCTAssertTrue(locale.exemplarCharacterSet != nil)
        // The calendar we get back from Locale has the locale set, but not the one we create with Calendar(identifier:). So we configure our comparison calendar first.
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US")
        XCTAssertEqual(c, Locale(identifier: "en_US").calendar)
        let localeCalendar = Locale(identifier: "en_US").calendar
        XCTAssertEqual(c, localeCalendar)
        XCTAssertEqual(c.identifier, localeCalendar.identifier)
        XCTAssertEqual(c.locale, localeCalendar.locale)
        XCTAssertEqual(c.timeZone, localeCalendar.timeZone)
        XCTAssertEqual(c.firstWeekday, localeCalendar.firstWeekday)
        XCTAssertEqual(c.minimumDaysInFirstWeek, localeCalendar.minimumDaysInFirstWeek)

        XCTAssertEqual("「", locale.quotationBeginDelimiter)
        XCTAssertEqual("」", locale.quotationEndDelimiter)
        XCTAssertEqual("『", locale.alternateQuotationBeginDelimiter)
        XCTAssertEqual("』", locale.alternateQuotationEndDelimiter)
        XCTAssertEqual("phonebook", Locale(identifier: "en_US@collation=phonebook").collationIdentifier)
        XCTAssertEqual(".", locale.decimalSeparator)


        XCTAssertEqual(".", locale.decimalSeparator)
        XCTAssertEqual(",", locale.groupingSeparator)
        XCTAssertEqual("HK$", locale.currencySymbol)
        XCTAssertEqual("HKD", locale.currencyCode)

        XCTAssertTrue(Locale.availableIdentifiers.count > 0)
        XCTAssertTrue(Locale.LanguageCode._isoLanguageCodeStrings.count > 0)
        XCTAssertTrue(Locale.Region.isoCountries.count > 0)
        XCTAssertTrue(Locale.Currency.isoCurrencies.map { $0.identifier }.count > 0)
        XCTAssertTrue(Locale.commonISOCurrencyCodes.count > 0)

        XCTAssertTrue(Locale.preferredLanguages.count > 0)

        // Need to find a good test case for collator identifier
        // XCTAssertEqual("something", locale.collatorIdentifier)
    }
}

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK

extension NSLocale {
    fileprivate static var fakeCurrentLocale: NSLocale = NSLocale.current as NSLocale
    @objc public class var _swizzledCurrentLocale: NSLocale {
        return NSLocale.fakeCurrentLocale
    }
}

final class LocalBridgingTests : XCTestCase {
    
    @available(macOS, deprecated: 13)
    @available(iOS, deprecated: 16)
    @available(tvOS, deprecated: 16)
    @available(watchOS, deprecated: 9)
    func test_getACustomLocale() {
        let loc = getACustomLocale()
        let objCLoc = loc as! CustomNSLocaleSubclass

        // Verify that accessing the properties of `l` calls back into ObjC
        XCTAssertEqual(loc.identifier, "en_US")
        XCTAssertEqual(objCLoc.last, "localeIdentifier")

        XCTAssertEqual(loc.currencyCode, "USD")
        XCTAssertEqual(objCLoc.last, "objectForKey:") // Everything funnels through the primitives
    }

    func test_AnyHashableCreatedFromNSLocale() {
        let values: [NSLocale] = [
            NSLocale(localeIdentifier: "en"),
            NSLocale(localeIdentifier: "uk"),
            NSLocale(localeIdentifier: "uk"),
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(Locale.self, type(of: anyHashables[0].base))
        expectEqual(Locale.self, type(of: anyHashables[1].base))
        expectEqual(Locale.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
}
#endif // FOUNDATION_FRAMEWORK

// MARK: - FoundationPreview Disabled Tests
#if FOUNDATION_FRAMEWORK
extension LocaleTests {
    func test_userPreferenceOverride_firstWeekday() {
        func verify(_ localeID: String, _ expected: Locale.Weekday, shouldRespectUserPrefForGregorian: Bool, shouldRespectUserPrefForIslamic: Bool, file: StaticString = #file, line: UInt = #line) {
            let localeNoPref = Locale.localeAsIfCurrent(name: localeID, overrides: .init(firstWeekday: [:]))
            XCTAssertEqual(localeNoPref.firstDayOfWeek, expected, file: file, line: line)

            let wed = Locale.localeAsIfCurrent(name: localeID, overrides: .init(firstWeekday: [.gregorian : 4]))
            XCTAssertEqual(wed.firstDayOfWeek, shouldRespectUserPrefForGregorian ? .wednesday : expected, file: file, line: line)

            let fri_islamic = Locale.localeAsIfCurrent(name: localeID, overrides: .init(firstWeekday: [.islamic : 6]))
            XCTAssertEqual(fri_islamic.firstDayOfWeek, shouldRespectUserPrefForIslamic ? .friday : expected, file: file, line: line)
        }

        verify("en_US", .sunday, shouldRespectUserPrefForGregorian: true, shouldRespectUserPrefForIslamic: false)
        verify("en_US@calendar=islamic", .sunday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: true)
        verify("en_US@fw=tue", .tuesday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: false)
        verify("en_US@rg=gbzzzz", .monday, shouldRespectUserPrefForGregorian: true, shouldRespectUserPrefForIslamic: false) // monday because rg=gb
        verify("en_US@fw=tue;rg=gbzzzz", .tuesday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: false)

        verify("en_GB", .monday, shouldRespectUserPrefForGregorian: true, shouldRespectUserPrefForIslamic: false)
        verify("en_GB@fw=sat", .saturday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: false)
        verify("en_GB@fw=thu;rg=uszzzz", .thursday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: false) // thursday because fw=thu
        verify("en_GB@rg=uszzzz", .sunday, shouldRespectUserPrefForGregorian: true, shouldRespectUserPrefForIslamic: false) // sunday because rg=us
        verify("en_GB@rg=uszzzz;calendar=islamic", .sunday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: true) // sunday because rg=us

        // BCP-47 identifier also works
        verify("en-GB-u-fw-sat", .saturday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: false)
        verify("en-GB-u-rg-uszzzz", .sunday, shouldRespectUserPrefForGregorian: true, shouldRespectUserPrefForIslamic: false)
        verify("en-GB-u-ca-islamic-rg-uszzzz", .sunday, shouldRespectUserPrefForGregorian: false, shouldRespectUserPrefForIslamic: true)
    }

    // Reenable once (Locale.canonicalIdentifier) is implemented
    func test_identifierTypesFromICUIdentifier() throws {
        verify("und_ZZ", cldr: "und_ZZ", bcp47: "und-ZZ", icu: "und_ZZ")

        verify("@calendar=gregorian", cldr: "und_u_ca_gregory", bcp47: "und-u-ca-gregory", icu: "@calendar=gregorian")

        // Canonicalize: case
        verify("en_us", cldr: "en_US", bcp47: "en-US", icu: "en_US")
        verify("und_us", cldr: "und_US", bcp47: "und-US", icu: "und_US")

        // Canonicalize: unncessary script + case
        verify("EN_latn_us", cldr: "en_US", bcp47: "en-US", icu: "en_US")

        // Canonicalized: keyword-value pairs are sorted by key
        verify("de@collation=phonebook;calendar=gregorian", cldr: "de_u_ca_gregory_co_phonebk", bcp47: "de-u-ca-gregory-co-phonebk", icu: "de@calendar=gregorian;collation=phonebook")
        verify("de@collation=yes", cldr: "de_u_co", bcp47: "de-u-co", icu: "de@collation=yes")
        verify("@x=elmer;a=exta", cldr: "und_a_exta_x_elmer", bcp47: "und-a-exta-x-elmer", icu: "@a=exta;x=elmer")
        verify("th@numbers=thai;z=extz;x=priv-use;a=exta", cldr: "th_a_exta_u_nu_thai_z_extz_x_priv_use", bcp47: "th-a-exta-u-nu-thai-z-extz-x-priv-use", icu: "th@a=exta;numbers=thai;x=priv-use;z=extz")

        verify("en_Hant_IL_FOO_BAR@ currency = EUR; calendar = Japanese ;", cldr: "en_Hant_IL_u_ca_japanese_cu_eur_x_lvariant_foo_bar", bcp47: "en-Hant-IL-u-ca-japanese-cu-eur-x-lvariant-foo-bar", icu: "en_Hant_IL_BAR_FOO@calendar=Japanese;currency=EUR")
    }

    // Reimplement once (Locale.canonicalIdentifier) is implemented
    func test_identifierTypesFromBCP47Identifier() throws {

        verify("fr-FR-1606nict-u-ca-gregory-x-test", cldr: "fr_FR_1606nict_u_ca_gregory_x_test", bcp47: "fr-FR-1606nict-u-ca-gregory-x-test", icu: "fr_FR_1606NICT@calendar=gregorian;x=test")

        // Canonicalize: case
        verify("en-us", cldr: "en_US", bcp47: "en-US", icu: "en_US")
        verify("und-us", cldr: "und_US", bcp47: "und-US", icu: "und_US")
        verify("und-latn", cldr: "und_Latn", bcp47: "und-Latn", icu: "und_Latn")

        // Canonicalize: alias mapping
        verify("zh-cmn-CH-u-co-pinyin", cldr: "zh_CH_u_co_pinyin", bcp47: "zh-CH-u-co-pinyin", icu: "zh_CH@collation=pinyin")
    }

    // Reimplemented once (Locale.canonicalIdentifier) is implemented
    func test_identifierTypesFromSpecialIdentifier() throws {
        verify("", cldr: "root", bcp47: "und", icu: "en_US_POSIX")
        verify("root", cldr: "root", bcp47: "root", icu: "root")
        verify("und", cldr: "root", bcp47: "und", icu: "und")

        // alias and deprecated codes are mapped
        verify("zh-cmn", cldr: "zh", bcp47: "zh", icu: "zh")
        verify("de-DD", cldr: "de_DE", bcp47: "de-DE", icu: "de_DE") // deprecated
        verify("de_DD", cldr: "de_DE", bcp47: "de-DE", icu: "de_DE") // deprecated
        verify("arb-AR", cldr: "ar_AR", bcp47: "ar-AR", icu: "ar_AR")
        verify("arb_AR", cldr: "ar_AR", bcp47: "ar-AR", icu: "ar_AR")
        verify("iw-IL", cldr: "he_IL", bcp47: "he-IL", icu: "he_IL")
        verify("iw_IL", cldr: "he_IL", bcp47: "he-IL", icu: "he_IL")

        // The script is stripped if it's the default of the language, but is kept otherwise
        verify("ks-Aran-IN", cldr: "ks_IN", bcp47: "ks-IN", icu: "ks_IN")
        verify("ks-Arab-IN", cldr: "ks_Arab_IN", bcp47: "ks-Arab-IN", icu: "ks_Arab_IN")

        // If there's only one component, it is treated as the language code
        verify("123", cldr: "root", bcp47: "und", icu: "123")
        verify("😀123", cldr: "root", bcp47: "und", icu: "en_US_POSIX")

        // The "_" prefix marks the start of the region
        verify("_ZZ", cldr: "und_ZZ", bcp47: "und-ZZ", icu: "_ZZ")
        verify("_123", cldr: "und_123", bcp47: "und-123", icu: "_123")
        verify("_😀123", cldr: "root", bcp47: "und", icu: "en_US_POSIX")

        // Starting an ID with script code is an acceptable special case
        verify("Hant", cldr: "hant", bcp47: "hant", icu: "hant")
    }
}
#endif // FOUNDATION_FRAMEWORK

// MARK: - Disabled Tests
extension LocaleTests {
    // TODO: Below can use @testable export of _Locale.localeIdentifierForCanonicalizedLocalizations(localizations, preferredLanguages, preferredLocaleID)
    /*
#if FIXED_37256779 // The tests here depend on `_CFLocaleCreateLocaleIdentifierForAvailableLocalizations` being exposed for unit testing; however, that is not currently possible.
- (void)testLocaleBundleMatching_modernLproj
{
    CFArrayRef localizations = (CFArrayRef)@[ @"fr", @"en", @"de" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"en-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"en_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since `pa` is not in `localizations`, the locale should be an `en` locale based on `en` being in `localizations`.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_en_US
{
    CFArrayRef localizations = (CFArrayRef)@[ @"de", @"en", @"es", @"fr", @"zh-Hans" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"en-US" ];
    CFStringRef preferredLocaleID = CFSTR("en_US");

    NSString *expected = (NSString *)preferredLocaleID;
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"`actual` should be same as `preferredLocaleID`, since the preferred language has a localization.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_zh_CN
{
    CFArrayRef localizations = (CFArrayRef)@[ @"de", @"en", @"es", @"fr", @"zh-Hans", @"zh-Hant" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"zh-Hans-CN" ];
    CFStringRef preferredLocaleID = CFSTR("zh_CN");

    NSString *expected = (NSString *)preferredLocaleID;
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"`actual` should be same as `preferredLocaleID`, since the preferred language has a localization.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_zh_MO
{
    CFArrayRef localizations = (CFArrayRef)@[ @"de", @"en", @"es", @"fr", @"zh-Hans", @"zh-Hant" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"zh-Hant-MO" ];
    CFStringRef preferredLocaleID = CFSTR("zh_MO");

    NSString *expected = (NSString *)preferredLocaleID;
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"`actual` should be same as `preferredLocaleID`, since the preferred language has a localization.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_zh_MO_2
{
    CFArrayRef localizations = (CFArrayRef)@[ @"de", @"en", @"es", @"fr", @"zh_CN", @"zh_TW" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"zh-Hant-MO" ];
    CFStringRef preferredLocaleID = CFSTR("zh_MO");

    NSString *expected = (NSString *)preferredLocaleID;
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"`actual` should be same as `preferredLocaleID`, since the preferred language has a localization.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_th_TH
{
    CFArrayRef localizations = (CFArrayRef)@[ @"de", @"en", @"es", @"fr", @"zh_CN", @"zh_TW" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"th-TH" ];
    CFStringRef preferredLocaleID = CFSTR("th_TH");

    NSString *expected = @"en_TH";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since `th` is not in `localizations`, the locale should be an `en` locale based on `en` being in `localizations` and being hard-coded as a default for such cases.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_modernLproj_noOverlap
{
    CFArrayRef localizations = (CFArrayRef)@[ @"fr", @"en", @"de" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"hi-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"en_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since neither `pa` nor `hi` are in `localizations`, the locale should be an `en` locale based on `en` being in `localizations` and being hard-coded as a default for such cases.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_modernLproj_noOverlap_noEnglish
{
    CFArrayRef localizations = (CFArrayRef)@[ @"fr", @"de" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"hi-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"fr_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since neither `pa` nor `hi` are in `localizations`, the locale should be an `fr` locale based on `fr` being #1 in `localizations` and `en` (the hard-coded default) not being present.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_legacyLproj
{
    CFArrayRef localizations = (CFArrayRef)@[ @"French", @"English", @"German" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"en-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"en_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since `pa` is not in `localizations`, the locale should be an `en` locale based on `English` being in `localizations`.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_legacyLproj_noOverlap
{
    CFArrayRef localizations = (CFArrayRef)@[ @"French", @"English", @"German" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"hi-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"en_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since `pa` is not in `localizations`, the locale should be an `en` locale based on `English` being in `localizations` and being hard-coded as a default for such cases.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_legacyLproj_noOverlap_noEnglish
{
    CFArrayRef localizations = (CFArrayRef)@[ @"German", @"French" ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"hi-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    NSString *expected = @"de_IN";
    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertEqualObjects((NSString *)actual, expected, @"Since neither `pa` nor `hi` are in `localizations`, the locale should be a `de` locale based on `German` being #1 in `localizations` and `en` (the hard-coded default) not being present.");
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_nullOrEmptyArguments_1
{
    CFArrayRef localizations = (CFArrayRef)@[ ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ @"pa-IN", @"en-IN" ];
    CFStringRef preferredLocaleID = CFSTR("pa_IN");

    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertNil((NSString *)actual);
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_nullOrEmptyArguments_2
{
    CFArrayRef localizations = (CFArrayRef)@[ ];
    CFArrayRef preferredLanguages = (CFArrayRef)@[ ];
    CFStringRef preferredLocaleID = CFSTR("");

    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertNil((NSString *)actual);
    if (actual) { CFRelease(actual); }
}

- (void)testLocaleBundleMatching_nullOrEmptyArguments_3
{
    CFArrayRef localizations = NULL;
    CFArrayRef preferredLanguages = NULL;
    CFStringRef preferredLocaleID = NULL;

    CFStringRef actual = _CFLocaleCreateLocaleIdentifierForAvailableLocalizations(localizations, preferredLanguages, preferredLocaleID);
    XCTAssertNil((NSString *)actual);
    if (actual) { CFRelease(actual); }
}

#endif
     */
}
