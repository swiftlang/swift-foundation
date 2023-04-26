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

final class LocaleLanguageComponentsTests : XCTestCase {

    func verifyComponents(_ identifier: String,
                          expectedLanguageCode: String?,
                          expectedScriptCode: String?,
                          expectedRegionCode: String?,
                          file: StaticString = #file, line: UInt = #line) {
        let comp = Locale.Language.Components(identifier: identifier)
        XCTAssertEqual(comp.languageCode?.identifier, expectedLanguageCode, file: file, line: line)
        XCTAssertEqual(comp.script?.identifier, expectedScriptCode, file: file, line: line)
        XCTAssertEqual(comp.region?.identifier, expectedRegionCode, file: file, line: line)
    }

    func testCreateFromIdentifier() {
        verifyComponents("en-US", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("en_US", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("en_US@rg=GBzzzz", expectedLanguageCode: "en", expectedScriptCode: nil, expectedRegionCode: "US")
        verifyComponents("zh-Hans-CN", expectedLanguageCode: "zh", expectedScriptCode: "Hans", expectedRegionCode: "CN")
        verifyComponents("zh-hans-cn", expectedLanguageCode: "zh", expectedScriptCode: "Hans", expectedRegionCode: "CN")
        verifyComponents("hans-cn", expectedLanguageCode: "hans", expectedScriptCode: nil, expectedRegionCode: "CN")
    }

    func testCreateFromInvalidIdentifier() {
        verifyComponents("HANS", expectedLanguageCode: "hans", expectedScriptCode: nil, expectedRegionCode: nil)
        verifyComponents("zh-CN-Hant", expectedLanguageCode: "zh", expectedScriptCode: nil, expectedRegionCode: "CN")
        verifyComponents("bleh", expectedLanguageCode: "bleh", expectedScriptCode: nil, expectedRegionCode: nil)
    }

    // The internal identifier uses the ICU-style identifier
    func testInternalIdentifier() {
        XCTAssertEqual(Locale.Language.Components(languageCode: "en", script: "Hant", region: "US").identifier, "en-Hant_US")
        XCTAssertEqual(Locale.Language.Components(languageCode: "en", script: nil, region: "US").identifier, "en_US")
        XCTAssertEqual(Locale.Language.Components(languageCode: "EN", script: nil, region: "us").identifier, "en_US")
        XCTAssertEqual(Locale.Language.Components(languageCode: "EN", script: "Latn").identifier, "en-Latn")
    }
}

class LocaleLanguageTests: XCTestCase {

    func verify(_ identifier: String, expectedParent: Locale.Language, minBCP47: String, maxBCP47: String, langCode: Locale.LanguageCode?, script: Locale.Script?, region: Locale.Region?, lineDirection: Locale.LanguageDirection, characterDirection: Locale.LanguageDirection, file: StaticString = #file, line: UInt = #line) {
        let lan = Locale.Language(identifier: identifier)
        XCTAssertEqual(lan.parent, expectedParent, "Parents should be equal", file: file, line: line)
        XCTAssertEqual(lan.minimalIdentifier, minBCP47, "minimalIdentifiers should be equal", file: file, line: line)
        XCTAssertEqual(lan.maximalIdentifier, maxBCP47, "maximalIdentifiers should be equal", file: file, line: line)
        XCTAssertEqual(lan.languageCode, langCode, "languageCodes should be equal", file: file, line: line)
        XCTAssertEqual(lan.script, script, "languageCodes should be equal", file: file, line: line)
        XCTAssertEqual(lan.region, region, "regions should be equal", file: file, line: line)
        XCTAssertEqual(lan.lineLayoutDirection, lineDirection, "lineDirection should be equal", file: file, line: line)
        XCTAssertEqual(lan.characterDirection, characterDirection, "characterDirection should be equal", file: file, line: line)
    }

    func testProperties() {
        verify("en-US", expectedParent: .init(identifier: "en"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("de-DE", expectedParent: .init(identifier: "de"), minBCP47: "de", maxBCP47: "de-Latn-DE", langCode: "de", script: "Latn", region: "DE", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("en-Kore-US", expectedParent: .init(identifier: "en-Kore"), minBCP47: "en-Kore", maxBCP47: "en-Kore-US", langCode: "en", script: "Kore", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("zh-TW", expectedParent: .init(identifier: "root"), minBCP47: "zh-TW", maxBCP47: "zh-Hant-TW", langCode: "zh", script: "Hant", region: "TW", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("en-Latn-US", expectedParent: .init(identifier: "en-Latn"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: "US", lineDirection: .topToBottom, characterDirection: .leftToRight)
        verify("ar-Arab", expectedParent: .init(identifier: "ar"), minBCP47: "ar", maxBCP47: "ar-Arab-EG", langCode: "ar", script: "Arab", region: nil, lineDirection: .topToBottom, characterDirection: .rightToLeft)

        verify("en", expectedParent: .init(identifier: "root"), minBCP47: "en", maxBCP47: "en-Latn-US", langCode: "en", script: "Latn", region: nil, lineDirection: .topToBottom, characterDirection: .leftToRight)

        verify("root", expectedParent: .init(identifier: "root"), minBCP47: "root", maxBCP47: "root", langCode: "root", script: nil, region: nil, lineDirection: .topToBottom, characterDirection: .leftToRight)
    }

    func testEquivalent() {
        func verify(lang1: String, lang2: String, isEqual: Bool, file: StaticString = #file, line: UInt = #line) {
            let language1 = Locale.Language(identifier: lang1)
            let language2 = Locale.Language(identifier: lang2)

            XCTAssert(language1.isEquivalent(to: language2) == isEqual, file: file, line: line)
            XCTAssert(language2.isEquivalent(to: language1) == isEqual, file: file, line: line)
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
