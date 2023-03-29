//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
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
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

final class LocaleComponentsTests: XCTestCase {

    func testRegions() {
        let region = Locale.Region("US")
        XCTAssertTrue(region.isISORegion)
        XCTAssertEqual(region.identifier, "US")
        XCTAssertEqual(region.continent, Locale.Region("019"))
        XCTAssertEqual(region.containingRegion, Locale.Region("021"))
        XCTAssertEqual(region.subRegions.count, 0)
        XCTAssert(Locale.Region.isoRegions.count > 0)

        let world = Locale.Region("001")
        XCTAssertEqual(world.subRegions.count, 5)

        let predefinedRegions: [Locale.Region] = [ .aruba, .belize, .chad, .côteDIvoire, .frenchSouthernTerritories, .heardMcdonaldIslands, .réunion ]
        for predefinedRegion in predefinedRegions {
            XCTAssertTrue(predefinedRegion.isISORegion)
        }
    }

    func testCurrency() {
        let usd = Locale.Currency("usd")
        XCTAssertTrue(usd.isISOCurrency)
        XCTAssertTrue(Locale.Currency.isoCurrencies.count > 0)
    }

    func testLanguageCode() {
        let isoLanguageCodes = Locale.LanguageCode.isoLanguageCodes
        XCTAssertTrue(isoLanguageCodes.count > 0)

        let isoCodes: [Locale.LanguageCode] = [ "de", "ar", "en", "es", "ja", "und", "DE", "AR" ]
        for isoCode in isoCodes {
            XCTAssertTrue(isoCode.isISOLanguage, "\(isoCode.identifier)")
            XCTAssertTrue(isoLanguageCodes.contains(isoCode), "\(isoCode.identifier)")
        }

        let invalidCodes: [Locale.LanguageCode] = [ "unk", "bogus", "foo", "root", "jp" ]
        for invalidCode in invalidCodes {
            XCTAssertFalse(invalidCode.isISOLanguage, "\(invalidCode.identifier)")
            XCTAssertNil(invalidCode.identifier(.alpha2))
            XCTAssertNil(invalidCode.identifier(.alpha3))
            XCTAssertFalse(isoLanguageCodes.contains(invalidCode))
        }

        let isoCodes3: [Locale.LanguageCode] = [ "deu", "ara", "eng", "spa", "jpn", "und", "deu", "ara" ]
        for (alpha2, alpha3) in zip(isoCodes, isoCodes3) {
            let actualAlpha2 = alpha3.identifier(.alpha2)
            let actualAlpha3 = alpha2.identifier(.alpha3)
            XCTAssertEqual(actualAlpha2, alpha2.identifier.lowercased())
            XCTAssertEqual(actualAlpha3, alpha3.identifier.lowercased())
        }

        let reservedCodes: [Locale.LanguageCode] = [ .unidentified, .uncoded, .multiple, .unavailable ]
        for reservedCode in reservedCodes {
            XCTAssertTrue(reservedCode.isISOLanguage, "\(reservedCode.identifier)")
            XCTAssertEqual(reservedCode.identifier(.alpha2), reservedCode.identifier)
            XCTAssertEqual(reservedCode.identifier(.alpha3), reservedCode.identifier)
            XCTAssertTrue(isoLanguageCodes.contains(reservedCode))
        }

        let predefinedCodes: [Locale.LanguageCode] = [ .arabic, .norwegianBokmål, .bulgarian, .māori, .norwegianNynorsk, .lithuanian ]
        for predefinedCode in predefinedCodes {
            XCTAssertTrue(predefinedCode.isISOLanguage)
        }
    }

    func testScript() {
        let someISOScripts: [Locale.Script] = [ "Latn", "Hani", "Hira", "Egyh", "Hans", "Arab", "Cyrl", "Deva", "Zzzz" ]
        for script in someISOScripts {
            XCTAssertTrue(script.isISOScript)
        }

        let notISOScripts: [Locale.Script] = [ "Wave", "Zombie", "Head", "Heart" ]
        for script in notISOScripts {
            XCTAssertFalse(script.isISOScript)
        }

        let predefinedScripts: [Locale.Script] = [ .latin, .hanSimplified, .hanifiRohingya, .hiragana, .arabic, .cyrillic, .devanagari, .unknown, .hanTraditional, .kannada ]
        for script in predefinedScripts {
            XCTAssertTrue(script.isISOScript)
        }
    }

    func testMisc() {
        XCTAssertTrue(Locale.Collation.availableCollations.count > 0)

        XCTAssertEqual(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"en"))), [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor") ])

        XCTAssertEqual(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"de"))), [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor"), Locale.Collation("phonebook") ])
        XCTAssertEqual(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"bogus"))), [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor") ])

        XCTAssertTrue(Locale.NumberingSystem.availableNumberingSystems.count > 0)
        XCTAssertTrue(Locale.NumberingSystem.availableNumberingSystems.contains(Locale.NumberingSystem("java")))
    }

    // Locale components are considered equal regardless of the identifier's case
    func testCaseInsensitiveEquality() {
        XCTAssertEqual(Locale.Collation("search"), Locale.Collation("SEARCH"))
        XCTAssertEqual(Locale.NumberingSystem("latn"), Locale.NumberingSystem("Latn"))
        XCTAssertEqual(
            [ Locale.NumberingSystem("latn"), Locale.NumberingSystem("ARAB") ],
            [ Locale.NumberingSystem("Latn"), Locale.NumberingSystem("arab") ])
        XCTAssertEqual(
            Set([ Locale.NumberingSystem("latn"), Locale.NumberingSystem("ARAB") ]),
            Set([ Locale.NumberingSystem("arab"), Locale.NumberingSystem("Latn") ]))
        XCTAssertEqual(Locale.Region("US"), Locale.Region("us"))
        XCTAssertEqual(Locale.Script("Hant"), Locale.Script("hant"))
        XCTAssertEqual(Locale.LanguageCode("EN"), Locale.LanguageCode("en"))
    }

    // The internal identifier getter would ignore invalid keywords and returns ICU-style identifier
    func testInternalIdentifier() {
        // In previous versions Locale.Components(identifier:) would not include @va=posix and en_US_POSIX would result in simply en_US_POSIX. We now return the @va=posix for compatibility with CFLocale.
        let expectations = [
            "en_GB" : "en_GB",
            "en-GB" : "en_GB",
            "en_US_POSIX" : "en_US@va=posix",
            "zh_TW" : "zh_TW",
            "zh-Hant_TW" : "zh-Hant_TW",
            "en_US@calendar=chinese;numbers=thai": "en_US@calendar=chinese;numbers=thai",
            "en-US-u-ca-chinese-nu-thai": "en_US@calendar=chinese;numbers=thai",
            "bogus" : "bogus",
            "en-US-u-attr1-attr2-ca-chinese" : "en_US@calendar=chinese",
            "en-US-u-ca-chinese" : "en_US@calendar=chinese",
        ]
        for (key, value) in expectations {
            let comps = Locale.Components(identifier: key)
            XCTAssertEqual(comps.identifier, value, "locale identifier: \(key)")
        }
    }

    func testCreation_identifier() {
        func verify(_ identifier: String, file: StaticString = #file, line: UInt = #line, expected components: () -> Locale.Components ) {
            let comps = Locale.Components(identifier: identifier)
            let expected = components()
            XCTAssertEqual(comps, expected, "expect: \"\(expected.identifier)\", actual: \"\(comps.identifier)\"", file: file, line: line)
        }

        // keywords
        verify("en_US@calendar=islamic;fw=mon;rg=GBzzzz") {
            var comps = Locale.Components(languageCode: "en", languageRegion: "US")
            comps.calendar = .islamic
            comps.firstDayOfWeek = .monday
            comps.region = Locale.Region("GB")
            return comps
        }

        verify("en-Latn@calendar=japanese;collation=phonebook;currency=CHF") {
            var comps = Locale.Components(languageCode: "en", script: "Latn")
            comps.calendar = .japanese
            comps.collation = Locale.Collation("phonebook")
            comps.currency = Locale.Currency("CHF")
            return comps
        }

        // "phonebook" is the modern keyword value for the `phonebk` collation
        verify("de-u-ca-gregory-co-phonebk-hc-h11-nu-thai") {
            var comps = Locale.Components(languageCode: "de")
            comps.calendar = .gregorian
            comps.collation = Locale.Collation("phonebook")
            comps.hourCycle = .zeroToEleven
            comps.numberingSystem = Locale.NumberingSystem("thai")
            return comps
        }

        verify("en-US-u-ca-japanese-cu-eur-va-posix-tz-brrbr-ms-metric") {
            var comps = Locale.Components(languageCode: "en", languageRegion: "US")
            comps.calendar = .japanese
            comps.currency = Locale.Currency("EUR")
            comps.variant = .posix
            comps.timeZone = TimeZone(identifier: "America/Rio_Branco")
            comps.measurementSystem = .metric
            return comps
        }

        verify("de-DE-u-co-phonebk") {
            var comps = Locale.Components(languageCode: .german, languageRegion: .germany)
            comps.collation = .init("phonebook")
            return comps
        }

        verify("bogus@") { Locale.Components(languageCode: "bogus") }
        verify("foo@attr=abc") { Locale.Components(languageCode: "foo") }
        verify("foo@calendar=abc") { Locale.Components(languageCode: "foo") }
        
        verify("foo@rg=u") { Locale.Components(languageCode: "foo") }
        verify("foo@rg=us") { Locale.Components(languageCode: "foo") }
        verify("foo@rg=bogussss") {
            var comp = Locale.Components(languageCode: "foo")
            comp.region = "bo"
            return comp
        }

        // case insensitive
        verify("en_GB") { Locale.Components(languageCode: "en", languageRegion: "GB") }
        verify("en-GB") { Locale.Components(languageCode: "en", languageRegion: "GB") }
        verify("EN-gb") { Locale.Components(languageCode: "en", languageRegion: "GB") }
        verify("en-gb") { Locale.Components(languageCode: "en", languageRegion: "GB") }

        // missing pieces
        verify("und-u-ca-japanese") {
            var comps = Locale.Components(languageCode: .unidentified)
            comps.calendar = .japanese
            return comps
        }

        verify("") {
            return Locale.Components(languageCode: nil)
        }

        verify("und-Latn-DE") {
            return Locale.Components(languageCode: .unidentified, script: .latin, languageRegion: .germany)
        }
        
        verify("en_GB@rg=USzzzz") {
            var comp = Locale.Components(identifier: "en_GB")
            comp.region = .unitedStates
            return comp
        }
        
        verify("en_GB@rg=USzzzz;sd=gbsct") {
            var comp = Locale.Components(identifier: "en_GB")
            comp.region = .unitedStates
            comp.subdivision = "gbsct" 
            return comp
        }
    }

    func testCreation_roundTripLocale() {
        func verify(_ identifier: String, file: StaticString = #file, line: UInt = #line) {

            let locale = Locale(identifier: identifier)

            let canonicalizedIdentifier = locale.identifier(.cldr)
            let comps = Locale.Components(identifier: canonicalizedIdentifier)

            let compsFromLocale = Locale.Components(locale: locale)
            let compsFromLocaleIdentifier = Locale.Components(identifier: locale.identifier)

            XCTAssertEqual(compsFromLocale, comps, file: file, line: line)
            XCTAssertEqual(compsFromLocale, compsFromLocaleIdentifier, file: file, line: line)
        }

        verify("en_GB")
        verify("zh-Hant_TW")
        verify("en-Latn_GB")
    }

    func testLocaleComponentInitNoCrash() {
        // Test that parsing invalid identifiers does not crash
        func test(_ identifier: String, file: StaticString = #file, line: UInt = #line) {
            let comp = Locale.Components(identifier: identifier)
            XCTAssertNotNil(comp, file: file, line: line)
        }

        test("en_US@calendar=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        test("en_US@=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        test("en_US@aaaaaaaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    func test_userPreferenceOverride() {

        func verifyHourCycle(_ localeID: String, _ expectDefault: Locale.HourCycle?, shouldRespectUserPref: Bool, file: StaticString = #file, line: UInt = #line) {
            let loc = Locale(identifier: localeID)
            let nonCurrentDefault = Locale.Components(locale: loc)
            XCTAssertEqual(nonCurrentDefault.hourCycle, expectDefault,  "default did not match", file: file, line: line)

            let defaultLoc = Locale.localeAsIfCurrent(name: localeID, overrides: .init())
            let defaultComp = Locale.Components(locale: defaultLoc)
            XCTAssertEqual(defaultComp.hourCycle, expectDefault, "explicit no override did not match", file: file, line: line)

            let force24 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force24Hour: true))
            let force24Comp = Locale.Components(locale: force24)
            XCTAssertEqual(force24Comp.hourCycle, shouldRespectUserPref ? .zeroToTwentyThree : expectDefault, "force 24-hr did not match", file: file, line: line)

            let force12 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force12Hour: true))
            let force12Comp = Locale.Components(locale: force12)
            XCTAssertEqual(force12Comp.hourCycle, shouldRespectUserPref ? .oneToTwelve : expectDefault, "force 12-hr did not match", file: file, line: line)
        }

        // expecting "nil" for hourCycle because no such information in the identifier
        verifyHourCycle("en_US", nil, shouldRespectUserPref: true)
        verifyHourCycle("en_GB", nil, shouldRespectUserPref: true)
        verifyHourCycle("zh_TW", nil, shouldRespectUserPref: true)

        // expecting non-nil hour cycle
        verifyHourCycle("en_US@hours=h23", .zeroToTwentyThree, shouldRespectUserPref: false)
        verifyHourCycle("en_GB@hours=h12", .oneToTwelve, shouldRespectUserPref: false)

        verifyHourCycle("en_GB@hours=x", nil, shouldRespectUserPref: true) // invalid hour cycle is ignored
    }

    func test_userPreferenceOverrideRoundtrip() {
        let customLocale = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(metricUnits: true, firstWeekday: [.gregorian: Locale.Weekday.wednesday.icuIndex], measurementUnits: .centimeters, force24Hour: true))
        XCTAssertEqual(customLocale.identifier, "en_US")
        XCTAssertEqual(customLocale.hourCycle, .zeroToTwentyThree)
        XCTAssertEqual(customLocale.firstDayOfWeek, .wednesday)
        XCTAssertEqual(customLocale.measurementSystem, .metric)

        let components = Locale.Components(locale: customLocale)
        XCTAssertEqual(components.identifier, "en_US@fw=wed;hours=h23;measure=metric")
        XCTAssertEqual(components.hourCycle, .zeroToTwentyThree)
        XCTAssertEqual(components.firstDayOfWeek, .wednesday)
        XCTAssertEqual(components.measurementSystem, .metric)

        let locFromComp = Locale(components: components)
        XCTAssertEqual(locFromComp.identifier, "en_US@fw=wed;hours=h23;measure=metric")
        XCTAssertEqual(locFromComp.hourCycle, .zeroToTwentyThree)
        XCTAssertEqual(locFromComp.firstDayOfWeek, .wednesday)
        XCTAssertEqual(locFromComp.measurementSystem, .metric)

        var updatedComponents = components
        updatedComponents.firstDayOfWeek = .friday

        let locFromUpdatedComponents = Locale(components: updatedComponents)
        XCTAssertEqual(locFromUpdatedComponents.identifier, "en_US@fw=fri;hours=h23;measure=metric")
        XCTAssertEqual(locFromUpdatedComponents.hourCycle, .zeroToTwentyThree)
        XCTAssertEqual(locFromUpdatedComponents.firstDayOfWeek, .friday)
        XCTAssertEqual(locFromUpdatedComponents.measurementSystem, .metric)
    }
}

final class LocaleCodableTests: XCTestCase {

    // Test types that used to encode both `identifier` and `normalizdIdentifier` now only encodes `identifier`
    func _testRoundtripCoding<T: Codable>(_ obj: T, identifier: String, normalizedIdentifier: String, file: StaticString = #file, line: UInt = #line) -> T? {
        let previousEncoded = "{\"_identifier\":\"\(identifier)\",\"_normalizedIdentifier\":\"\(normalizedIdentifier)\"}"
        let previousEncodedData = previousEncoded.data(using: .utf8)!
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(T.self, from: previousEncodedData) else {
            XCTFail("Decoding \(obj) failed", file: file, line: line)
            return nil
        }

        let encoder = JSONEncoder()
        guard let newEncoded = try? encoder.encode(decoded) else {
            XCTFail("Encoding \(obj) failed", file: file, line: line)
            return nil
        }
        XCTAssertEqual(String(data: newEncoded, encoding: .utf8)!, "\"\(identifier)\"")

        return decoded
    }

    func test_compatibilityCoding() {

        do {
            let codableObj = Locale.LanguageCode("HELLO")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.LanguageCode.armenian
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.LanguageCode("")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region("My home")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region.uganda
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region("")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Script("BOGUS")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Script.hebrew
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Collation("BOGUS")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Collation.searchRules
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Currency("EXAMPLE")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Currency.unknown
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.NumberingSystem("UNKNOWN")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.NumberingSystem.latn
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.MeasurementSystem.metric
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.MeasurementSystem("EXAMPLE")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Subdivision("usca")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Variant("EXAMPLE")
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Variant.posix
            let decoded = _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            XCTAssertEqual(decoded?.identifier, codableObj.identifier)
            XCTAssertEqual(decoded?._normalizedIdentifier, codableObj._normalizedIdentifier)
        }

    }

    func _encodeAsJSON<T: Codable>(_ t: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .sortedKeys ]
        guard let encoded = try? encoder.encode(t) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }

    func test_encode_language() {
        func expectEncode(_ lang: Locale.Language, _ expectedEncoded: String, file: StaticString = #file, line: UInt = #line) {
            guard let encoded = _encodeAsJSON(lang) else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(encoded, expectedEncoded, file: file, line: line)

            let data = encoded.data(using: .utf8)
            guard let data, let decoded = try? JSONDecoder().decode(Locale.Language.self, from: data)  else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(lang, decoded, file: file, line: line)
        }

        expectEncode(Locale.Language(identifier: "zh-Hans-hk"), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        expectEncode(Locale.Language(languageCode: .chinese, script: .hanSimplified, region: .hongKong), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        let langComp = Locale.Language.Components(identifier: "zh-Hans-hk")
        expectEncode(Locale.Language(components: langComp), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        expectEncode(Locale.Language(identifier: ""), """
        {"components":{}}
        """)

        expectEncode(Locale.Language(languageCode: nil), """
        {"components":{}}
        """)

        let empty = Locale.Language.Components(identifier: "")
        expectEncode(Locale.Language(components: empty), """
        {"components":{}}
        """)
    }

    func test_encode_languageComponents() {
        func expectEncode(_ lang: Locale.Language.Components, _ expectedEncoded: String, file: StaticString = #file, line: UInt = #line) {
            guard let encoded = _encodeAsJSON(lang) else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(encoded, expectedEncoded, file: file, line: line)

            let data = encoded.data(using: .utf8)
            guard let data, let decoded = try? JSONDecoder().decode(Locale.Language.Components.self, from: data)  else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(lang, decoded, file: file, line: line)
        }


        expectEncode(Locale.Language.Components(identifier: "zh-Hans-hk"), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        expectEncode(Locale.Language.Components(languageCode: .chinese, script: .hanSimplified, region: .hongKong), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        let lang = Locale.Language(identifier: "zh-Hans-hk")
        expectEncode(Locale.Language.Components(language: lang), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        expectEncode(Locale.Language.Components(identifier: ""), """
        {}
        """)

        expectEncode(Locale.Language.Components(languageCode: nil), "{}")
    }

    func test_encode_localeComponents() {

        func expectEncode(_ lang: Locale.Components, _ expectedEncoded: String, file: StaticString = #file, line: UInt = #line) {
            guard let encoded = _encodeAsJSON(lang) else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(encoded, expectedEncoded, file: file, line: line)

            let data = encoded.data(using: .utf8)
            guard let data, let decoded = try? JSONDecoder().decode(Locale.Components.self, from: data)  else {
                XCTFail(file: file, line: line)
                return
            }

            XCTAssertEqual(lang, decoded, file: file, line: line)
        }

        var comp = Locale.Components(languageCode: .chinese, languageRegion: .taiwan)
        comp.calendar = .buddhist
        comp.currency = "GBP"
        comp.region = .hongKong
        comp.firstDayOfWeek = .monday
        comp.hourCycle = .oneToTwelve
        comp.measurementSystem = .us
        comp.timeZone = .gmt

        expectEncode(comp, """
        {"calendar":{"buddhist":{}},"currency":"GBP","firstDayOfWeek":"mon","hourCycle":"h12","languageComponents":{"languageCode":"zh","region":"TW"},"measurementSystem":"ussystem","region":"HK","timeZone":{"identifier":"GMT"}}
        """)

        expectEncode(Locale.Components(languageCode: nil), """
        {"languageComponents":{}}
        """)

        expectEncode(Locale.Components(identifier: ""), """
        {"languageComponents":{}}
        """)
    }


    func test_decode_compatible_localeComponents() {
        func expectDecode(_ encoded: String, _ expected: Locale.Components, file: StaticString = #file, line: UInt = #line) {
            guard let data = encoded.data(using: .utf8), let decoded = try? JSONDecoder().decode(Locale.Components.self, from: data) else {
                XCTFail(file: file, line: line)
                return
            }
            XCTAssertEqual(decoded, expected, file: file, line: line)
        }

        do {
            var expected = Locale.Components(identifier: "")
            expected.region = "HK"
            expected.firstDayOfWeek = .monday
            expected.languageComponents.region = "TW"
            expected.languageComponents.languageCode = "zh"
            expected.hourCycle = .oneToTwelve
            expected.timeZone = .gmt
            expected.calendar = .buddhist
            expected.currency = "GBP"
            expected.measurementSystem = .us

            expectDecode("""
            {"region":{"_identifier":"HK","_normalizedIdentifier":"HK"},"firstDayOfWeek":"mon","languageComponents":{"region":{"_identifier":"TW","_normalizedIdentifier":"TW"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"}},"hourCycle":"h12","timeZone":{"identifier":"GMT"},"calendar":{"buddhist":{}},"currency":{"_identifier":"GBP","_normalizedIdentifier":"gbp"},"measurementSystem":{"_identifier":"ussystem","_normalizedIdentifier":"ussystem"}}
            """, expected)
        }

        do {
            expectDecode("""
            {"languageComponents":{}}
            """, Locale.Components(identifier: ""))
        }
    }

    func test_decode_compatible_language() {

        func expectDecode(_ encoded: String, _ expected: Locale.Language, file: StaticString = #file, line: UInt = #line) {
            guard let data = encoded.data(using: .utf8), let decoded = try? JSONDecoder().decode(Locale.Language.self, from: data) else {
                XCTFail(file: file, line: line)
                return
            }
            XCTAssertEqual(decoded, expected, file: file, line: line)
        }

        expectDecode("""
            {"components":{"script":{"_identifier":"Hans","_normalizedIdentifier":"Hans"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"},"region":{"_identifier":"HK","_normalizedIdentifier":"HK"}}}
            """, Locale.Language(identifier: "zh-Hans-HK"))

        expectDecode("""
            {"components":{}}
            """, Locale.Language(identifier: ""))
    }

    func test_decode_compatible_languageComponents() {
        func expectDecode(_ encoded: String, _ expected: Locale.Language.Components, file: StaticString = #file, line: UInt = #line) {
            guard let data = encoded.data(using: .utf8), let decoded = try? JSONDecoder().decode(Locale.Language.Components.self, from: data) else {
                XCTFail(file: file, line: line)
                return
            }
            XCTAssertEqual(decoded, expected, file: file, line: line)
        }

        expectDecode("""
            {"script":{"_identifier":"Hans","_normalizedIdentifier":"Hans"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"},"region":{"_identifier":"HK","_normalizedIdentifier":"HK"}}
            """, Locale.Language.Components(identifier: "zh-Hans-HK"))

        expectDecode("{}", Locale.Language.Components(identifier: ""))
    }

}
