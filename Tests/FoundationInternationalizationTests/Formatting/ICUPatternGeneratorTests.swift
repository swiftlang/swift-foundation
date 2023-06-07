// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

final class ICUPatternGeneratorTests: XCTestCase {

    typealias DateFieldCollection = Date.FormatStyle.DateFieldCollection
    func testConversationalDayPeriodsOverride() {

        var locale: Locale
        var calendar: Calendar
        func test(symbols: Date.FormatStyle.DateFieldCollection, expectedPattern: String, file: StaticString = #file, line: UInt = #line) {
            let pattern = ICUPatternGenerator.localizedPattern(symbols: symbols, locale: locale, calendar: calendar)
            XCTAssertEqual(pattern, expectedPattern, file: file, line: line)

            // We should not see any kind of day period designator ("a" or "B") when showing 24-hour hour ("H").
            if (expectedPattern.contains("H") || pattern.contains("H")) && (pattern.contains("a") || pattern.contains("B")) {
                XCTFail("Pattern should not contain day period", file: file, line: line)
            }
        }

        // We should get conversational day periods (pattern "B") when the symbol contains hour options instead of non-conversational day periods (pattern "a")
        do {
            locale = Locale(identifier: "zh_TW")
            calendar = Calendar(identifier: .gregorian)

            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsWithWideAMPM),
                 expectedPattern: "y/M/d BBBBh時")

            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bh:mm")
            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bh:mm:ss")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBh時")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM, minute: .defaultDigits),
                 expectedPattern: "BBBBBh:mm")

            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bhh:mm")
            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bhh:mm:ss")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBBhh:mm")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM),
                 expectedPattern: "BBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBhh:mm")

            // We would not get "B" if not showing AM/PM at all
            test(symbols: .init(hour: .twoDigitsNoAMPM), expectedPattern: "hh時")
            test(symbols: .init(hour: .defaultDigitsNoAMPM), expectedPattern: "h時")
            test(symbols: .init(year: .defaultDigits),
                 expectedPattern: "y年")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits),
                 expectedPattern: "y/M")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits),
                 expectedPattern: "y/M/d")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsNoAMPM),
                 expectedPattern: "y/M/d h時")
        }

        // This should also work with calendar besides gregorian
        do {
            locale = Locale(identifier: "zh_TW")
            calendar = Calendar(identifier: .republicOfChina)

            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsWithWideAMPM),
                 expectedPattern: "G y/M/d BBBBh時")

            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bh:mm")
            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bh:mm:ss")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBh時")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM, minute: .defaultDigits),
                 expectedPattern: "BBBBBh:mm")

            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bhh:mm")
            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bhh:mm:ss")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBBhh:mm")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM),
                 expectedPattern: "BBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBhh:mm")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            calendar = Calendar(identifier: .gregorian)

            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsWithWideAMPM),
                 expectedPattern: "y/M/d BBBBh時")

            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bh:mm")
            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bh:mm:ss")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBh時")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM, minute: .defaultDigits),
                 expectedPattern: "BBBBBh:mm")

            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "Bhh:mm")
            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "Bhh:mm:ss")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM),
                 expectedPattern: "BBBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBBhh:mm")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM),
                 expectedPattern: "BBBBhh時")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM, minute: .twoDigits),
                 expectedPattern: "BBBBhh:mm")

            // We would not get "B" if not showing AM/PM at all
            test(symbols: .init(hour: .twoDigitsNoAMPM), expectedPattern: "hh時")
            test(symbols: .init(hour: .defaultDigitsNoAMPM), expectedPattern: "h時")
            test(symbols: .init(year: .defaultDigits),
                 expectedPattern: "y年")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits),
                 expectedPattern: "y/M")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits),
                 expectedPattern: "y/M/d")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsNoAMPM),
                 expectedPattern: "y/M/d h時")
        }

        // We should not see any kind of day period designator ("a" or "B") when showing 24-hour hour ("H").
        do {
            var localeUsing24hour = Locale.Components(identifier: "zh_TW")
            localeUsing24hour.hourCycle = .zeroToTwentyThree
            locale = Locale(components: localeUsing24hour)

            calendar = Calendar(identifier: .gregorian)

            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsWithWideAMPM),
                 expectedPattern: "y/M/d H時")

            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "HH:mm")
            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "HH:mm:ss")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM),
                 expectedPattern: "H時")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM, minute: .defaultDigits),
                 expectedPattern: "HH:mm")

            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "HH:m")
            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "HH:mm:ss")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM),
                 expectedPattern: "HH時")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM, minute: .twoDigits),
                 expectedPattern: "HH:mm")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM),
                 expectedPattern: "HH時")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM, minute: .twoDigits),
                 expectedPattern: "HH:mm")

            // We would not get "B" if not showing AM/PM at all
            test(symbols: .init(hour: .twoDigitsNoAMPM), expectedPattern: "HH時")
            test(symbols: .init(hour: .defaultDigitsNoAMPM), expectedPattern: "H時")
            test(symbols: .init(year: .defaultDigits),
                 expectedPattern: "y年")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits),
                 expectedPattern: "y/M")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits),
                 expectedPattern: "y/M/d")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsNoAMPM),
                 expectedPattern: "y/M/d H時")
        }

        // We do not override locales other than those in TW
        do {
            locale = Locale(identifier: "zh_HK")
            calendar = Calendar(identifier: .gregorian)

            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits, hour: .defaultDigitsWithWideAMPM),
                 expectedPattern: "d/M/y aaaah時")

            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "ah:mm")
            test(symbols: .init(hour: .defaultDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "ah:mm:ss")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM),
                 expectedPattern: "aaaaah時")
            test(symbols: .init(hour: .defaultDigitsWithNarrowAMPM, minute: .defaultDigits),
                 expectedPattern: "aaaaah:mm")

            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits),
                 expectedPattern: "ahh:mm")
            test(symbols: .init(hour: .twoDigitsWithAbbreviatedAMPM, minute: .defaultDigits, second: .defaultDigits),
                 expectedPattern: "ahh:mm:ss")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM),
                 expectedPattern: "aaaaahh時")
            test(symbols: .init(hour: .twoDigitsWithNarrowAMPM, minute: .twoDigits),
                 expectedPattern: "aaaaahh:mm")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM),
                 expectedPattern: "aaaahh時")
            test(symbols: .init(hour: .twoDigitsWithWideAMPM, minute: .twoDigits),
                 expectedPattern: "aaaahh:mm")

            // We would not get "B" if not showing AM/PM at all
            test(symbols: .init(hour: .twoDigitsNoAMPM), expectedPattern: "hh時")
            test(symbols: .init(hour: .defaultDigitsNoAMPM), expectedPattern: "h時")
            test(symbols: .init(year: .defaultDigits),
                 expectedPattern: "y年")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits),
                 expectedPattern: "M/y")
            test(symbols: .init(year: .defaultDigits, month: .defaultDigits, day: .defaultDigits),
                 expectedPattern: "d/M/y")
        }
    }

}
