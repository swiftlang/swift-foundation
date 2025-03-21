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

        func verify(cldr: String, bcp47: String, icu: String, file: StaticString = #filePath, line: UInt = #line, _ components: () -> Locale.Components) {
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

        verify(cldr: "root", bcp47: "und", icu: "") {
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

    func verify(_ locID: String, cldr: String, bcp47: String, icu: String, file: StaticString = #filePath, line: UInt = #line) {
        let loc = Locale(identifier: locID)
        let types: [Locale.IdentifierType] = [.cldr, .bcp47, .icu]
        let expected = [cldr, bcp47, icu]
        for (idx, type) in types.enumerated() {
            XCTAssertEqual(loc.identifier(type), expected[idx], "type: \(type)", file: file, line: line)
        }
    }
    
    func comps(language: String? = nil, script: String? = nil, country: String? = nil, variant: String? = nil) -> [String: String] {
        var result: [String: String] = [:]
        if let language { result["kCFLocaleLanguageCodeKey"] = language }
        if let script { result["kCFLocaleScriptCodeKey"] = script }
        if let country { result["kCFLocaleCountryCodeKey"] = country }
        if let variant { result["kCFLocaleVariantCodeKey"] = variant }
        return result
    }

    func test_identifierFromComponents() {
        var c: [String: String] = [:]
        
        c = comps(language: "zh", script: "Hans", country: "TW")
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW")
        
        // Set some keywords
        c["CuRrEnCy"] = "qqq"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@currency=qqq")

        // Set some more keywords, check order
        c["d"] = "d"
        c["0"] = "0"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d")
        
        // Add some non-ASCII keywords
        c["ê"] = "ê"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d")
        
        // And some non-ASCII values
        c["n"] = "ñ"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d")
        
        // And some values with other letters
        c["z"] = "Ab09_-+/"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d;z=Ab09_-+/")

        // And some really short keys
        c[""] = "hi"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d;z=Ab09_-+/")

        // And some really short values
        c["q"] = ""
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;currency=qqq;d=d;z=Ab09_-+/")
        
        // All the valid stuff
        c["abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-+/"
        XCTAssertEqual(Locale.identifier(fromComponents: c), "zh_Hans_TW@0=0;abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz0123456789=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-+/;currency=qqq;d=d;z=Ab09_-+/")
        
        // POSIX
        let p = comps(language: "en", script: nil, country: "US", variant: "POSIX")
        XCTAssertEqual(Locale.identifier(fromComponents: p), "en_US_POSIX")
        
        // Odd combos
        XCTAssertEqual(Locale.identifier(fromComponents: comps(language: "en", variant: "POSIX")), "en__POSIX")

        XCTAssertEqual(Locale.identifier(fromComponents: comps(variant: "POSIX")), "__POSIX")

        XCTAssertEqual(Locale.identifier(fromComponents: comps(language: "en", script: "Hans", country: "US", variant: "POSIX")), "en_Hans_US_POSIX")

        XCTAssertEqual(Locale.identifier(fromComponents: comps(language: "en")), "en")
        XCTAssertEqual(Locale.identifier(fromComponents: comps(country: "US", variant: "POSIX")), "_US_POSIX")
    }
    
    #if FOUNDATION_FRAMEWORK
    func test_identifierFromAnyComponents() {
        // This internal Foundation-specific version allows for a Calendar entry
        let comps = comps(language: "zh", script: "Hans", country: "TW")
        XCTAssertEqual(Locale.identifier(fromComponents: comps), "zh_Hans_TW")

        var anyComps : [String : Any] = [:]
        anyComps.merge(comps) { a, b in a }
        
        anyComps["kCFLocaleCalendarKey"] = Calendar(identifier: .gregorian)
        XCTAssertEqual(Locale.identifier(fromAnyComponents: anyComps), "zh_Hans_TW@calendar=gregorian")

        // Verify what happens if we have the key in here under two different (but equivalent) names
        anyComps["calendar"] = "buddhist"
        XCTAssertEqual(Locale.identifier(fromAnyComponents: anyComps), "zh_Hans_TW@calendar=gregorian")

        anyComps["currency"] = "xyz"
        XCTAssertEqual(Locale.identifier(fromAnyComponents: anyComps), "zh_Hans_TW@calendar=gregorian;currency=xyz")
        
        anyComps["AaA"] = "bBb"
        XCTAssertEqual(Locale.identifier(fromAnyComponents: anyComps), "zh_Hans_TW@aaa=bBb;calendar=gregorian;currency=xyz")
    }
    #endif

    func test_identifierCapturingPreferences() {
        func expectIdentifier(_ localeIdentifier: String, preferences: LocalePreferences, expectedFullIdentifier: String, file: StaticString = #filePath, line: UInt = #line) {
            let locale = Locale.localeAsIfCurrent(name: localeIdentifier, overrides: preferences)
            XCTAssertEqual(locale.identifier, localeIdentifier, file: file, line: line)
            XCTAssertEqual(locale.identifierCapturingPreferences, expectedFullIdentifier, file: file, line: line)
        }

        expectIdentifier("en_US", preferences: .init(metricUnits: true, measurementUnits: .centimeters), expectedFullIdentifier: "en_US@measure=metric")
        expectIdentifier("en_US", preferences: .init(metricUnits: true, measurementUnits: .inches), expectedFullIdentifier: "en_US@measure=uksystem")
        expectIdentifier("en_US", preferences: .init(metricUnits: false, measurementUnits: .inches), expectedFullIdentifier: "en_US@measure=ussystem")
        // We treat it as US system as long as `metricUnits` is false
        expectIdentifier("en_US", preferences: .init(metricUnits: false, measurementUnits: .centimeters), expectedFullIdentifier: "en_US@measure=ussystem")

        // 112778892: Country pref is intentionally ignored
        expectIdentifier("en_US", preferences: .init(country: "GB"), expectedFullIdentifier: "en_US")
        expectIdentifier("en_US", preferences: .init(country: "US"), expectedFullIdentifier: "en_US")

        expectIdentifier("en_US", preferences: .init(firstWeekday: [.gregorian : 3]), expectedFullIdentifier: "en_US@fw=tue")
        // en_US locale doesn't use islamic calendar; preference is ignored
        expectIdentifier("en_US", preferences: .init(firstWeekday: [.islamic : 3]), expectedFullIdentifier: "en_US")

        expectIdentifier("en_US", preferences: .init(force24Hour: true), expectedFullIdentifier: "en_US@hours=h23")
        expectIdentifier("en_US", preferences: .init(force12Hour: true), expectedFullIdentifier: "en_US@hours=h12")

        // Preferences not representable by locale identifier are ignored
        expectIdentifier("en_US", preferences: .init(minDaysInFirstWeek: [.gregorian: 7]), expectedFullIdentifier: "en_US")
#if FOUNDATION_FRAMEWORK
        expectIdentifier("en_US", preferences: .init(dateFormats: [.abbreviated: "custom style"]), expectedFullIdentifier: "en_US")
#endif
    }
    
    func test_badWindowsLocaleID() {
        // Negative values are invalid
        let result = Locale.identifier(fromWindowsLocaleCode: -1)
        XCTAssertNil(result)
    }
}

final class LocalePropertiesTests : XCTestCase {

    func _verify(locale: Locale, expectedLanguage language: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil, region: Locale.Region? = nil, subdivision: Locale.Subdivision? = nil, measurementSystem: Locale.MeasurementSystem? = nil, calendar: Calendar.Identifier? = nil, hourCycle: Locale.HourCycle? = nil, currency: Locale.Currency? = nil, numberingSystem: Locale.NumberingSystem? = nil, numberingSystems: Set<Locale.NumberingSystem> = [], firstDayOfWeek: Locale.Weekday? = nil, collation: Locale.Collation? = nil, variant: Locale.Variant? = nil, file: StaticString = #filePath, line: UInt = #line) {
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

    func verify(_ identifier: String, expectedLanguage language: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil, region: Locale.Region? = nil, subdivision: Locale.Subdivision? = nil, measurementSystem: Locale.MeasurementSystem? = nil, calendar: Calendar.Identifier? = nil, hourCycle: Locale.HourCycle? = nil, currency: Locale.Currency? = nil, numberingSystem: Locale.NumberingSystem? = nil, numberingSystems: Set<Locale.NumberingSystem> = [], firstDayOfWeek: Locale.Weekday? = nil, collation: Locale.Collation? = nil, variant: Locale.Variant? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let loc = Locale(identifier: identifier)
        _verify(locale: loc, expectedLanguage: language, script: script, languageRegion: languageRegion, region: region, subdivision: subdivision, measurementSystem: measurementSystem, calendar: calendar, hourCycle: hourCycle, currency: currency, numberingSystem: numberingSystem, numberingSystems: numberingSystems, firstDayOfWeek: firstDayOfWeek, collation: collation, variant: variant, file: file, line: line)
    }

    func test_localeComponentsAndLocale() {
        func verify(components: Locale.Components, identifier: String, file: StaticString = #filePath, line: UInt = #line) {
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
        func verifyHourCycle(_ localeID: String, _ expectDefault: Locale.HourCycle, shouldRespectUserPref: Bool, file: StaticString = #filePath, line: UInt = #line) {
            let loc = Locale(identifier: localeID)
            XCTAssertEqual(loc.hourCycle, expectDefault,  "default did not match", file: file, line: line)

            let defaultLoc = Locale.localeAsIfCurrent(name: localeID, overrides: .init())
            XCTAssertEqual(defaultLoc.hourCycle, expectDefault, "explicit no override did not match", file: file, line: line)

            let force24 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force24Hour: true))
            XCTAssertEqual(force24.hourCycle, shouldRespectUserPref ? .zeroToTwentyThree : expectDefault, "force 24-hr did not match", file: file, line: line)

            let force12 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force12Hour: true))
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
        func verify(_ localeID: String, _ expected: Locale.MeasurementSystem, shouldRespectUserPref: Bool, file: StaticString = #filePath, line: UInt = #line) {
            let localeNoPref = Locale.localeAsIfCurrent(name: localeID, overrides: .init())
            XCTAssertEqual(localeNoPref.measurementSystem, expected, file: file, line: line)

            let fakeCurrentMetric = Locale.localeAsIfCurrent(name: localeID, overrides: .init(metricUnits: true, measurementUnits: .centimeters))
            XCTAssertEqual(fakeCurrentMetric.measurementSystem, shouldRespectUserPref ? .metric : expected, file: file, line: line)

            let fakeCurrentUS = Locale.localeAsIfCurrent(name: localeID, overrides: .init(metricUnits: false, measurementUnits: .inches))
            XCTAssertEqual(fakeCurrentUS.measurementSystem, shouldRespectUserPref ? .us : expected, file: file, line: line)

            let fakeCurrentUK = Locale.localeAsIfCurrent(name: localeID, overrides: .init(metricUnits: true, measurementUnits: .inches))
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
#if FOUNDATION_FRAMEWORK
        XCTAssertTrue(locale.exemplarCharacterSet != nil)
#endif
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
    
    func test_customizedProperties() {
        let localePrefs = LocalePreferences(numberSymbols: [0 : "*", 1: "-"])
        let customizedLocale = Locale.localeAsIfCurrent(name: "en_US", overrides: localePrefs)
        XCTAssertEqual(customizedLocale.decimalSeparator, "*")
        XCTAssertEqual(customizedLocale.groupingSeparator, "-")
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

    func test_longLocaleKeywordValues() {
        let x = Locale.keywordValue(identifier: "ar_EG@vt=kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk", key: "vt")
        XCTAssertEqual(x, "kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk")
    }
}

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK

final class LocaleBridgingTests : XCTestCase {
    
    @available(macOS, deprecated: 13)
    @available(iOS, deprecated: 16)
    @available(tvOS, deprecated: 16)
    @available(watchOS, deprecated: 9)
    func test_getACustomLocale() {
        let loc = getACustomLocale("en_US")
        let objCLoc = loc as! CustomNSLocaleSubclass

        // Verify that accessing the properties of `l` calls back into ObjC
        XCTAssertEqual(loc.identifier, "en_US")
        XCTAssertEqual(objCLoc.last, "localeIdentifier")

        XCTAssertEqual(loc.currencyCode, "USD")
        XCTAssertEqual(objCLoc.last, "objectForKey:") // Everything funnels through the primitives

        XCTAssertEqual(loc.regionCode, "US")
        XCTAssertEqual(objCLoc.countryCode, "US")
    }

    @available(macOS, deprecated: 13)
    @available(iOS, deprecated: 16)
    @available(tvOS, deprecated: 16)
    @available(watchOS, deprecated: 9)
    func test_customLocaleCountryCode() {
        let loc = getACustomLocale("en_US@rg=gbzzzz")
        let objCLoc = loc as! CustomNSLocaleSubclass

        XCTAssertEqual(loc.identifier, "en_US@rg=gbzzzz")
        XCTAssertEqual(objCLoc.last, "localeIdentifier")

        XCTAssertEqual(loc.currencyCode, "GBP")
        XCTAssertEqual(objCLoc.last, "objectForKey:") // Everything funnels through the primitives

        XCTAssertEqual(loc.regionCode, "GB")
        XCTAssertEqual(objCLoc.countryCode, "GB")
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
    
    func test_autoupdatingBridge() {
        let s1 = Locale.autoupdatingCurrent
        let s2 = Locale.autoupdatingCurrent
        let ns1 = s1 as NSLocale
        let ns2 = s2 as NSLocale
        // Verify that we don't create a new instance each time this is converted to NSLocale
        XCTAssertTrue(ns1 === ns2)
    }
    
    func test_bridgingTwice() {
        let s1 = NSLocale.system
        let l1 = s1 as Locale
        let s2 = NSLocale.system
        let l2 = s2 as Locale
        XCTAssertTrue(l1 as NSLocale === l2 as NSLocale)
    }
    
    func test_bridgingFixedTwice() {
        let s1 = Locale(identifier: "en_US")
        let ns1 = s1 as NSLocale
        let s2 = Locale(identifier: "en_US")
        let ns2 = s2 as NSLocale
        XCTAssertTrue(ns1 === ns2)
    }
    
    func test_bridgingCurrentWithPrefs() {
        // Verify that 'current with prefs' locales (which have identical identifiers but differing prefs) are correctly cached
        let s1 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(metricUnits: true), disableBundleMatching: false)
        let ns1 = s1 as NSLocale
        let s2 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(metricUnits: true), disableBundleMatching: false)
        let ns2 = s2 as NSLocale
        let s3 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(measurementUnits: .centimeters), disableBundleMatching: false)
        let ns3 = s3 as NSLocale
        
        XCTAssertTrue(ns1 === ns2)
        XCTAssertTrue(ns1 !== ns3)
        XCTAssertTrue(ns2 !== ns3)
    }
}

#endif // FOUNDATION_FRAMEWORK

// MARK: - FoundationPreview Disabled Tests
#if FOUNDATION_FRAMEWORK
extension LocaleTests {
    func test_userPreferenceOverride_firstWeekday() {
        func verify(_ localeID: String, _ expected: Locale.Weekday, shouldRespectUserPrefForGregorian: Bool, shouldRespectUserPrefForIslamic: Bool, file: StaticString = #filePath, line: UInt = #line) {
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

    // TODO: Reenable once (Locale.canonicalIdentifier) is implemented
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

    // TODO: Reenable once (Locale.canonicalIdentifier) is implemented
    func test_identifierTypesFromBCP47Identifier() throws {

        verify("fr-FR-1606nict-u-ca-gregory-x-test", cldr: "fr_FR_1606nict_u_ca_gregory_x_test", bcp47: "fr-FR-1606nict-u-ca-gregory-x-test", icu: "fr_FR_1606NICT@calendar=gregorian;x=test")

        // Canonicalize: case
        verify("en-us", cldr: "en_US", bcp47: "en-US", icu: "en_US")
        verify("und-us", cldr: "und_US", bcp47: "und-US", icu: "und_US")
        verify("und-latn", cldr: "und_Latn", bcp47: "und-Latn", icu: "und_Latn")

        // Canonicalize: alias mapping
        verify("zh-cmn-CH-u-co-pinyin", cldr: "zh_CH_u_co_pinyin", bcp47: "zh-CH-u-co-pinyin", icu: "zh_CH@collation=pinyin")
    }

    // TODO: Reenable once (Locale.canonicalIdentifier) is implemented
    func test_identifierTypesFromSpecialIdentifier() throws {
        verify("", cldr: "root", bcp47: "und", icu: "")
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
        verify("😀123", cldr: "root", bcp47: "und", icu: "")

        // The "_" prefix marks the start of the region
        verify("_ZZ", cldr: "und_ZZ", bcp47: "und-ZZ", icu: "_ZZ")
        verify("_123", cldr: "und_123", bcp47: "und-123", icu: "_123")
        verify("_😀123", cldr: "root", bcp47: "und", icu: "")

        // Starting an ID with script code is an acceptable special case
        verify("Hant", cldr: "hant", bcp47: "hant", icu: "hant")
    }

    func test_asIfCurrentWithBundleLocalizations() {
        let currentLanguage = Locale.current.language.languageCode!
        var localizations = Set([ "zh", "fr", "en" ])
        localizations.insert(currentLanguage.identifier) // We're not sure what the current locale is when test runs. Ensure that it's always in the list of available localizations
        // Foundation framework-only test
        let fakeCurrent = Locale.localeAsIfCurrentWithBundleLocalizations(Array(localizations), allowsMixedLocalizations: false)
        XCTAssertEqual(fakeCurrent?.language.languageCode, currentLanguage)
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
