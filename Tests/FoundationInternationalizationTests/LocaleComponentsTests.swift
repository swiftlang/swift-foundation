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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

struct LocaleComponentsTests {

    @Test func testRegions() {
        let region = Locale.Region("US")
        #expect(region.isISORegion)
        #expect(region.identifier == "US")
        #expect(region.continent == Locale.Region("019"))
        #expect(region.containingRegion == Locale.Region("021"))
        #expect(region.subRegions.count == 0)
        #expect(Locale.Region.isoRegions.count > 0)

        let world = Locale.Region("001")
        #expect(world.subRegions.count == 5)

        let predefinedRegions: [Locale.Region] = [ .aruba, .belize, .chad, .côteDIvoire, .frenchSouthernTerritories, .heardMcdonaldIslands, .réunion ]
        for predefinedRegion in predefinedRegions {
            #expect(predefinedRegion.isISORegion)
        }
    }

    @Test func testCurrency() {
        let usd = Locale.Currency("usd")
        #expect(usd.isISOCurrency)
        #expect(Locale.Currency.isoCurrencies.count > 0)
    }

    @Test func testLanguageCode() {
        let isoLanguageCodes = Locale.LanguageCode.isoLanguageCodes
        #expect(isoLanguageCodes.count > 0)

        let isoCodes: [Locale.LanguageCode] = [ "de", "ar", "en", "es", "ja", "und", "DE", "AR" ]
        for isoCode in isoCodes {
            #expect(isoCode.isISOLanguage, "\(isoCode.identifier)")
            #expect(isoLanguageCodes.contains(isoCode), "\(isoCode.identifier)")
        }

        let invalidCodes: [Locale.LanguageCode] = [ "unk", "bogus", "foo", "root", "jp" ]
        for invalidCode in invalidCodes {
            #expect(!invalidCode.isISOLanguage, "\(invalidCode.identifier)")
            #expect(invalidCode.identifier(.alpha2) == nil)
            #expect(invalidCode.identifier(.alpha3) == nil)
            #expect(!isoLanguageCodes.contains(invalidCode))
        }

        let isoCodes3: [Locale.LanguageCode] = [ "deu", "ara", "eng", "spa", "jpn", "und", "deu", "ara" ]
        for (alpha2, alpha3) in zip(isoCodes, isoCodes3) {
            let actualAlpha2 = alpha3.identifier(.alpha2)
            let actualAlpha3 = alpha2.identifier(.alpha3)
            #expect(actualAlpha2 == alpha2.identifier.lowercased())
            #expect(actualAlpha3 == alpha3.identifier.lowercased())
        }

        let reservedCodes: [Locale.LanguageCode] = [ .unidentified, .uncoded, .multiple, .unavailable ]
        for reservedCode in reservedCodes {
            #expect(reservedCode.isISOLanguage, "\(reservedCode.identifier)")
            #expect(reservedCode.identifier(.alpha2) == reservedCode.identifier)
            #expect(reservedCode.identifier(.alpha3) == reservedCode.identifier)
            #expect(isoLanguageCodes.contains(reservedCode))
        }

        let predefinedCodes: [Locale.LanguageCode] = [ .arabic, .norwegianBokmål, .bulgarian, .māori, .norwegianNynorsk, .lithuanian ]
        for predefinedCode in predefinedCodes {
            #expect(predefinedCode.isISOLanguage)
        }
    }

    @Test func testScript() {
        let someISOScripts: [Locale.Script] = [ "Latn", "Hani", "Hira", "Egyh", "Hans", "Arab", "Cyrl", "Deva", "Zzzz" ]
        for script in someISOScripts {
            #expect(script.isISOScript)
        }

        let notISOScripts: [Locale.Script] = [ "Wave", "Zombie", "Head", "Heart" ]
        for script in notISOScripts {
            #expect(!script.isISOScript)
        }

        let predefinedScripts: [Locale.Script] = [ .latin, .hanSimplified, .hanifiRohingya, .hiragana, .arabic, .cyrillic, .devanagari, .unknown, .hanTraditional, .kannada ]
        for script in predefinedScripts {
            #expect(script.isISOScript)
        }
    }

    @Test func testMisc() {
        #expect(Locale.Collation.availableCollations.count > 0)

        #expect(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"en"))) == [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor") ])

        #expect(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"de"))) == [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor"), Locale.Collation("phonebook") ])
        #expect(Set(Locale.Collation.availableCollations(for: Locale.Language(identifier:"bogus"))) == [ .standard, .searchRules, Locale.Collation("emoji"), Locale.Collation("eor") ])

        #expect(Locale.NumberingSystem.availableNumberingSystems.count > 0)
        #expect(Locale.NumberingSystem.availableNumberingSystems.contains(Locale.NumberingSystem("java")))
    }

    // The internal identifier getter would ignore invalid keywords and returns ICU-style identifier
    @Test func testInternalIdentifier() {
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
            #expect(comps.icuIdentifier == value, "locale identifier: \(key)")
        }
    }

    @Test func testCreation_identifier() {
        func verify(_ identifier: String, sourceLocation: SourceLocation = #_sourceLocation, expected components: () -> Locale.Components ) {
            let comps = Locale.Components(identifier: identifier)
            let expected = components()
            #expect(comps == expected, "expect: \"\(expected.icuIdentifier)\", actual: \"\(comps.icuIdentifier)\"", sourceLocation: sourceLocation)
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

    @Test func testCreation_roundTripLocale() {
        func verify(_ identifier: String, sourceLocation: SourceLocation = #_sourceLocation) {

            let locale = Locale(identifier: identifier)

            let canonicalizedIdentifier = locale.identifier(.cldr)
            let comps = Locale.Components(identifier: canonicalizedIdentifier)

            let compsFromLocale = Locale.Components(locale: locale)
            let compsFromLocaleIdentifier = Locale.Components(identifier: locale.identifier)

            #expect(compsFromLocale == comps, sourceLocation: sourceLocation)
            #expect(compsFromLocale == compsFromLocaleIdentifier, sourceLocation: sourceLocation)
        }

        verify("en_GB")
        verify("zh-Hant_TW")
        verify("en-Latn_GB")
    }

    @Test func testLocaleComponentInitNoCrash() {
        // Test that parsing invalid identifiers does not crash
        func test(_ identifier: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let comp = Locale.Components(identifier: identifier)
            #expect(comp != nil, sourceLocation: sourceLocation)
        }

        test("en_US@calendar=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        test("en_US@=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        test("en_US@aaaaaaaaaaaaaaaaaaaaaaaaaaaa=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    @Test func test_userPreferenceOverride() {

        func verifyHourCycle(_ localeID: String, _ expectDefault: Locale.HourCycle?, shouldRespectUserPref: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
            let loc = Locale(identifier: localeID)
            let nonCurrentDefault = Locale.Components(locale: loc)
            #expect(nonCurrentDefault.hourCycle == expectDefault,  "default did not match", sourceLocation: sourceLocation)

            let defaultLoc = Locale.localeAsIfCurrent(name: localeID, overrides: .init())
            let defaultComp = Locale.Components(locale: defaultLoc)
            #expect(defaultComp.hourCycle == expectDefault, "explicit no override did not match", sourceLocation: sourceLocation)

            let force24 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force24Hour: true))
            let force24Comp = Locale.Components(locale: force24)
            #expect(force24Comp.hourCycle == (shouldRespectUserPref ? .zeroToTwentyThree : expectDefault), "force 24-hr did not match", sourceLocation: sourceLocation)

            let force12 = Locale.localeAsIfCurrent(name: localeID, overrides: .init(force12Hour: true))
            let force12Comp = Locale.Components(locale: force12)
            #expect(force12Comp.hourCycle == (shouldRespectUserPref ? .oneToTwelve : expectDefault), "force 12-hr did not match", sourceLocation: sourceLocation)
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

    @Test func test_userPreferenceOverrideRoundtrip() {
        let customLocale = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(metricUnits: true, firstWeekday: [.gregorian: Locale.Weekday.wednesday.icuIndex], measurementUnits: .centimeters, force24Hour: true))
        #expect(customLocale.identifier == "en_US")
        #expect(customLocale.hourCycle == .zeroToTwentyThree)
        #expect(customLocale.firstDayOfWeek == .wednesday)
        #expect(customLocale.measurementSystem == .metric)

        let components = Locale.Components(locale: customLocale)
        #expect(components.icuIdentifier == "en_US@fw=wed;hours=h23;measure=metric")
        #expect(components.hourCycle == .zeroToTwentyThree)
        #expect(components.firstDayOfWeek == .wednesday)
        #expect(components.measurementSystem == .metric)

        let locFromComp = Locale(components: components)
        #expect(locFromComp.identifier == "en_US@fw=wed;hours=h23;measure=metric")
        #expect(locFromComp.hourCycle == .zeroToTwentyThree)
        #expect(locFromComp.firstDayOfWeek == .wednesday)
        #expect(locFromComp.measurementSystem == .metric)

        var updatedComponents = components
        updatedComponents.firstDayOfWeek = .friday

        let locFromUpdatedComponents = Locale(components: updatedComponents)
        #expect(locFromUpdatedComponents.identifier == "en_US@fw=fri;hours=h23;measure=metric")
        #expect(locFromUpdatedComponents.hourCycle == .zeroToTwentyThree)
        #expect(locFromUpdatedComponents.firstDayOfWeek == .friday)
        #expect(locFromUpdatedComponents.measurementSystem == .metric)
    }
}

struct LocaleCodableTests {

    // Test types that used to encode both `identifier` and `normalizdIdentifier` now only encodes `identifier`
    func _testRoundtripCoding<T: Codable>(_ obj: T, identifier: String, normalizedIdentifier: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> T? {
        let previousEncoded = "{\"_identifier\":\"\(identifier)\",\"_normalizedIdentifier\":\"\(normalizedIdentifier)\"}"
        let previousEncodedData = previousEncoded.data(using: String._Encoding.utf8)!
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(T.self, from: previousEncodedData)

        let encoder = JSONEncoder()
        let newEncoded = try encoder.encode(decoded)
        #expect(String(data: newEncoded, encoding: .utf8)! == "\"\(identifier)\"")

        return decoded
    }

    @Test func test_compatibilityCoding() throws {

        do {
            let codableObj = Locale.LanguageCode("HELLO")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.LanguageCode.armenian
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.LanguageCode("")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region("My home")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region.uganda
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Region("")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Script("BOGUS")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Script.hebrew
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Collation("BOGUS")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Collation.searchRules
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Currency("EXAMPLE")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Currency.unknown
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.NumberingSystem("UNKNOWN")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.NumberingSystem.latn
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.MeasurementSystem.metric
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.MeasurementSystem("EXAMPLE")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Subdivision("usca")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Variant("EXAMPLE")
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

        do {
            let codableObj = Locale.Variant.posix
            let decoded = try _testRoundtripCoding(codableObj, identifier: codableObj.identifier, normalizedIdentifier: codableObj._normalizedIdentifier)
            #expect(decoded?.identifier == codableObj.identifier)
            #expect(decoded?._normalizedIdentifier == codableObj._normalizedIdentifier)
        }

    }

    @Test func test_decode_compatible_localeComponents() throws {
        func expectDecode(_ encoded: String, _ expected: Locale.Components, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Components.self, from: data)
            #expect(decoded == expected, sourceLocation: sourceLocation)
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

            try expectDecode("""
            {"region":{"_identifier":"HK","_normalizedIdentifier":"HK"},"firstDayOfWeek":"mon","languageComponents":{"region":{"_identifier":"TW","_normalizedIdentifier":"TW"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"}},"hourCycle":"h12","timeZone":{"identifier":"GMT"},"calendar":{"buddhist":{}},"currency":{"_identifier":"GBP","_normalizedIdentifier":"gbp"},"measurementSystem":{"_identifier":"ussystem","_normalizedIdentifier":"ussystem"}}
            """, expected)
        }

        do {
            try expectDecode("""
            {"languageComponents":{}}
            """, Locale.Components(identifier: ""))
        }
    }

    @Test func test_decode_compatible_language() throws {

        func expectDecode(_ encoded: String, _ expected: Locale.Language, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Language.self, from: data)
            #expect(decoded == expected, sourceLocation: sourceLocation)
        }

        try expectDecode("""
            {"components":{"script":{"_identifier":"Hans","_normalizedIdentifier":"Hans"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"},"region":{"_identifier":"HK","_normalizedIdentifier":"HK"}}}
            """, Locale.Language(identifier: "zh-Hans-HK"))

        try expectDecode("""
            {"components":{}}
            """, Locale.Language(identifier: ""))
    }

    @Test func test_decode_compatible_languageComponents() throws {
        func expectDecode(_ encoded: String, _ expected: Locale.Language.Components, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Language.Components.self, from: data)
            #expect(decoded == expected, sourceLocation: sourceLocation)
        }

        try expectDecode("""
            {"script":{"_identifier":"Hans","_normalizedIdentifier":"Hans"},"languageCode":{"_identifier":"zh","_normalizedIdentifier":"zh"},"region":{"_identifier":"HK","_normalizedIdentifier":"HK"}}
            """, Locale.Language.Components(identifier: "zh-Hans-HK"))

        try expectDecode("{}", Locale.Language.Components(identifier: ""))
    }

    // Locale components are considered equal regardless of the identifier's case
    @Test func testCaseInsensitiveEquality() {
        #expect(Locale.Collation("search") == Locale.Collation("SEARCH"))
        #expect(Locale.NumberingSystem("latn") == Locale.NumberingSystem("Latn"))
        #expect(
            [ Locale.NumberingSystem("latn"), Locale.NumberingSystem("ARAB") ] ==
            [ Locale.NumberingSystem("Latn"), Locale.NumberingSystem("arab") ])
        #expect(
            Set([ Locale.NumberingSystem("latn"), Locale.NumberingSystem("ARAB") ]) ==
            Set([ Locale.NumberingSystem("arab"), Locale.NumberingSystem("Latn") ]))
        #expect(Locale.Region("US") == Locale.Region("us"))
        #expect(Locale.Script("Hant") == Locale.Script("hant"))
        #expect(Locale.LanguageCode("EN") == Locale.LanguageCode("en"))
    }
    
    func _encodeAsJSON<T: Codable>(_ t: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .sortedKeys ]
        let encoded = try encoder.encode(t)
        return try #require(String(data: encoded, encoding: .utf8))
    }

    @Test func test_encode_language() throws {
        func expectEncode(_ lang: Locale.Language, _ expectedEncoded: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let encoded = try _encodeAsJSON(lang)

            #expect(encoded == expectedEncoded, sourceLocation: sourceLocation)

            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Language.self, from: data)

            #expect(lang == decoded, sourceLocation: sourceLocation)
        }

        try expectEncode(Locale.Language(identifier: "zh-Hans-hk"), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        try expectEncode(Locale.Language(languageCode: .chinese, script: .hanSimplified, region: .hongKong), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        let langComp = Locale.Language.Components(identifier: "zh-Hans-hk")
        try expectEncode(Locale.Language(components: langComp), """
        {"components":{"languageCode":"zh","region":"HK","script":"Hans"}}
        """)

        try expectEncode(Locale.Language(identifier: ""), """
        {"components":{}}
        """)

        try expectEncode(Locale.Language(languageCode: nil), """
        {"components":{}}
        """)

        let empty = Locale.Language.Components(identifier: "")
        try expectEncode(Locale.Language(components: empty), """
        {"components":{}}
        """)
    }

    @Test func test_encode_languageComponents() throws {
        func expectEncode(_ lang: Locale.Language.Components, _ expectedEncoded: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let encoded = try _encodeAsJSON(lang)

            #expect(encoded == expectedEncoded, sourceLocation: sourceLocation)

            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Language.Components.self, from: data)

            #expect(lang == decoded, sourceLocation: sourceLocation)
        }


        try expectEncode(Locale.Language.Components(identifier: "zh-Hans-hk"), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        try expectEncode(Locale.Language.Components(languageCode: .chinese, script: .hanSimplified, region: .hongKong), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        let lang = Locale.Language(identifier: "zh-Hans-hk")
        try expectEncode(Locale.Language.Components(language: lang), """
        {"languageCode":"zh","region":"HK","script":"Hans"}
        """)

        try expectEncode(Locale.Language.Components(identifier: ""), """
        {}
        """)

        try expectEncode(Locale.Language.Components(languageCode: nil), "{}")
    }

    @Test func test_encode_localeComponents() throws {

        func expectEncode(_ lang: Locale.Components, _ expectedEncoded: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let encoded = try _encodeAsJSON(lang)

            #expect(encoded == expectedEncoded, sourceLocation: sourceLocation)

            let data = try #require(encoded.data(using: String._Encoding.utf8))
            let decoded = try JSONDecoder().decode(Locale.Components.self, from: data)

            #expect(lang == decoded, sourceLocation: sourceLocation)
        }

        var comp = Locale.Components(languageCode: .chinese, languageRegion: .taiwan)
        comp.calendar = .buddhist
        comp.currency = "GBP"
        comp.region = .hongKong
        comp.firstDayOfWeek = .monday
        comp.hourCycle = .oneToTwelve
        comp.measurementSystem = .us
        comp.timeZone = .gmt

        try expectEncode(comp, """
        {"calendar":{"buddhist":{}},"currency":"GBP","firstDayOfWeek":"mon","hourCycle":"h12","languageComponents":{"languageCode":"zh","region":"TW"},"measurementSystem":"ussystem","region":"HK","timeZone":{"identifier":"GMT"}}
        """)

        try expectEncode(Locale.Components(languageCode: nil), """
        {"languageComponents":{}}
        """)

        try expectEncode(Locale.Components(identifier: ""), """
        {"languageComponents":{}}
        """)
    }
}
