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
#elseif canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

@Suite("Locale.Language.Components")
private struct LocaleLanguageComponentsTests {

    func verifyComponents(_ identifier: String,
                          expectedLanguageCode: String?,
                          expectedScriptCode: String?,
                          expectedRegionCode: String?,
                          sourceLocation: SourceLocation = #_sourceLocation) {
        let comp = Locale.Language.Components(identifier: identifier)
        #expect(comp.languageCode?.identifier == expectedLanguageCode, sourceLocation: sourceLocation)
        #expect(comp.script?.identifier == expectedScriptCode, sourceLocation: sourceLocation)
        #expect(comp.region?.identifier == expectedRegionCode, sourceLocation: sourceLocation)
    }

    @Test func createFromIdentifier() {
        verifyComponents("en-US", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("en_US", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("en_US@rg=GBzzzz", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("zh-Hans-CN", expectedLanguageCode: "zh", expectedScriptCode: "Hans", expectedRegionCode: "CN")
        verifyComponents("zh-hans-cn", expectedLanguageCode: "zh", expectedScriptCode: "Hans", expectedRegionCode: "CN")
        verifyComponents("hans-cn", expectedLanguageCode: "hans", expectedScriptCode: nil, expectedRegionCode: "CN")
    }

    @Test func createFromInvalidIdentifier() {
        verifyComponents("HANS", expectedLanguageCode: "hans", expectedScriptCode: nil, expectedRegionCode: nil)
        verifyComponents("zh-CN-Hant", expectedLanguageCode: "zh", expectedScriptCode: nil, expectedRegionCode: "CN")
        verifyComponents("bleh", expectedLanguageCode: "bleh", expectedScriptCode: nil, expectedRegionCode: nil)
    }

    // The internal identifier uses the ICU-style identifier
    @Test func internalIdentifier() {
        #expect(Locale.Language.Components(languageCode: "en", script: "Hant", region: "US").identifier == "en-Hant_US")
        #expect(Locale.Language.Components(languageCode: "en", script: nil, region: "US").identifier == "en_US")
        #expect(Locale.Language.Components(languageCode: "EN", script: nil, region: "us").identifier == "en_US")
        #expect(Locale.Language.Components(languageCode: "EN", script: "Latn").identifier == "en-Latn")
    }
}

@Suite("Locale.Language")
private struct LocaleLanguageTests {

    func verify(_ identifier: String, expectedParent: Locale.Language, minBCP47: String, maxBCP47: String, langCode: Locale.LanguageCode?, script: Locale.Script?, region: Locale.Region?, lineDirection: Locale.LanguageDirection, characterDirection: Locale.LanguageDirection, sourceLocation: SourceLocation = #_sourceLocation) {
        let lan = Locale.Language(identifier: identifier)
        #expect(lan.parent == expectedParent, "Parents should be equal", sourceLocation: sourceLocation)
        #expect(lan.minimalIdentifier == minBCP47, "minimalIdentifiers should be equal", sourceLocation: sourceLocation)
        #expect(lan.maximalIdentifier == maxBCP47, "maximalIdentifiers should be equal", sourceLocation: sourceLocation)
        #expect(lan.languageCode == langCode, "languageCodes should be equal", sourceLocation: sourceLocation)
        #expect(lan.script == script, "languageCodes should be equal", sourceLocation: sourceLocation)
        #expect(lan.region == region, "regions should be equal", sourceLocation: sourceLocation)
        #expect(lan.lineLayoutDirection == lineDirection, "lineDirection should be equal", sourceLocation: sourceLocation)
        #expect(lan.characterDirection == characterDirection, "characterDirection should be equal", sourceLocation: sourceLocation)
    }

    @Test func properties() {
        verify("en-US", expectedParent: .init(identifier: "en"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("de-DE", expectedParent: .init(identifier: "de"), minBCP47: "de", maxBCP47: "de-Latn-DE", langCode: "de", script: "Latn", region: "DE", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("en-Kore-US", expectedParent: .init(identifier: "en-Kore"), minBCP47: "en-Kore", maxBCP47: "en-Kore-US", langCode: "en", script: "Kore", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("zh-TW", expectedParent: .init(identifier: "root"), minBCP47: "zh-TW", maxBCP47: "zh-Hant-TW", langCode: "zh", script: "Hant", region: "TW", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("en-Latn-US", expectedParent: .init(identifier: "en-Latn"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("ar-Arab", expectedParent: .init(identifier: "ar"), minBCP47: "ar", maxBCP47: "ar-Arab-EG", langCode: "ar", script: "Arab", region: nil, lineDirection: .topToBottom, characterDirection: .rightToLeft)

        verify("en", expectedParent: .init(identifier: "root"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: nil, lineDirection: .topToBottom, characterDirection: .leftToRight)

        verify("root", expectedParent: .init(identifier: "root"), minBCP47: "root", maxBCP47: "root", langCode: "root", script: nil, region: nil, lineDirection: .topToBottom, characterDirection: .leftToRight)
    }

    @Test func equivalent() {
        func verify(lang1: String, lang2: String, isEqual: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
            let language1 = Locale.Language(identifier: lang1)
            let language2 = Locale.Language(identifier: lang2)

            #expect(language1.isEquivalent(to: language2) == isEqual, sourceLocation: sourceLocation)
            #expect(language2.isEquivalent(to: language1) == isEqual, sourceLocation: sourceLocation)
        }

        verify(lang1: "en", lang2: "en-Latn", isEqual: true)
        verify(lang1: "en-US", lang2: "en-Latn-US", isEqual: true)
        verify(lang1: "und-US", lang2: "en-US", isEqual: true)

        verify(lang1: "zh-Hant-TW", lang2: "zh-TW", isEqual: true)
        verify(lang1: "zh-Hans", lang2: "zh-Hans-CN", isEqual: true)
        verify(lang1: "zh", lang2: "zh-Hans-CN", isEqual: true)
        verify(lang1: "zh", lang2: "zh-Hans", isEqual: true)
        verify(lang1: "zh-Hans", lang2: "zh-Hant", isEqual: false)

        verify(lang1: "und-PL", lang2: "pl-PL", isEqual: true)
        verify(lang1: "und-PL", lang2: "pl-Latn-PL", isEqual: true)
    }
}
