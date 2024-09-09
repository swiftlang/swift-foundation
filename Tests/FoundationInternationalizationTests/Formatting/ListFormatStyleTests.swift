// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct ListFormatStyleTests {
    @Test func test_orList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .or, width: .standard)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one or two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, or three")
    }

    @Test func test_andList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .standard)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one and two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, and three")
    }

    @Test func test_narrowList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .narrow)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one, two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, three")
    }

    @Test func test_shortList() {
        var style: ListFormatStyle<StringStyle, [String]> = .list(type: .and, width: .short)
        style.locale = Locale(identifier: "en_US")

        #expect(["one", "two"].formatted(style) == "one & two")
        #expect(["one", "two", "three"].formatted(style) == "one, two, & three")
    }
    
#if FOUNDATION_FRAMEWORK // FIXME: rdar://104091257
    @Test func test_leadingDotSyntax() {
        let _ = ["one", "two"].formatted(.list(type: .and))
        let _ = ["one", "two"].formatted()
        let _ = [1, 2].formatted(.list(memberStyle: .number, type: .or, width: .standard))
    }
#endif
}

extension CurrentLocaleTimeZoneCalendarDependentTests {
    struct ListFormatStyleTests {
        @Test func testAutoupdatingCurrentChangesFormatResults() {
            let locale = Locale.autoupdatingCurrent
            let list = ["one", "two", "three", "four"]
            
            // Get a formatted result from es-ES
            var prefs = LocalePreferences()
            prefs.languages = ["es-ES"]
            prefs.locale = "es_ES"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedSpanish = list.formatted(.list(type: .and).locale(locale))
            
            // Get a formatted result from en-US
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedEnglish = list.formatted(.list(type: .and).locale(locale))
            
            // Reset to current preferences before any possibility of failing this test
            LocaleCache.cache.reset()
            
            // No matter what 'current' was before this test was run, formattedSpanish and formattedEnglish should be different.
            #expect(formattedSpanish != formattedEnglish)
        }
    }
}
