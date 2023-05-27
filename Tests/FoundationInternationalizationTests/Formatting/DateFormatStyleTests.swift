// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
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

#if canImport(FoundationEssentials)
import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class DateFormatStyleTests : XCTestCase {
    let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
#if FOUNDATION_FRAMEWORK
    let expectedSeparator = "\u{202f}"
#else
    let expectedSeparator = " "
#endif

    func test_constructorSyntax() {
        let style = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .year(.defaultDigits)
            .month(.abbreviated)
            .day(.twoDigits)
            .hour(.twoDigits(amPM: .omitted))
            .minute(.defaultDigits)
        XCTAssertEqual(referenceDate.formatted(style), "Dec 31, 2000 at 04:00")
    }

    func test_era() {
        let abbreviatedStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.abbreviated)
        XCTAssertEqual(referenceDate.formatted(abbreviatedStyle), "AD")

        let narrowStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.narrow)
        XCTAssertEqual(referenceDate.formatted(narrowStyle), "A")

        let wideStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.wide)
        XCTAssertEqual(referenceDate.formatted(wideStyle), "Anno Domini")
    }

    func test_dateFormatString() {
        let expectedFormats: [Date.FormatString: String] = [
            "": "",
            "some latin characters": "'some latin characters'",
            " ": "' '",
            "😀😀": "'😀😀'",
            "'": "''",
            "'some strings in single quotes'": "''some strings in single quotes''",

            "\(day: .twoDigits)\(month: .twoDigits)": "ddMM",
            "\(day: .twoDigits)/\(month: .twoDigits)": "dd'/'MM",
            "\(day: .twoDigits)-\(month: .twoDigits)": "dd'-'MM",
            "\(day: .twoDigits)'\(month: .twoDigits)": "dd''MM",
            " \(day: .twoDigits) \(month: .twoDigits) ": "' 'dd' 'MM' '",

            "\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)) o'clock": "h' o''clock'",

            "Day:\(day: .defaultDigits) Month:\(month: .abbreviated) Year:\(year: .padded(4))": "'Day:'d' Month:'MMM' Year:'yyyy",
        ]

        for (format, expected) in expectedFormats {
            XCTAssertEqual(format.rawFormat, expected)
        }
    }

    func test_parsingThrows() {
        // Literal symbols are treated as literals, so they won't parse when parsing strictly
        let invalidFormats: [(Date.FormatString, String)] = [
            ("ddMMyy", "010599"),
            ("dd/MM/yy", "01/05/99"),
            ("d/MMM/yyyy", "1/Sep/1999"),
        ]

        let locale = Locale(identifier: "en_US")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        for (format, dateString) in invalidFormats {
            let parseStrategy = Date.ParseStrategy(format: format, locale: locale, timeZone: timeZone, isLenient: false)
            XCTAssertThrowsError(try parseStrategy.parse(dateString), "Date string: \(dateString); Format: \(format.rawFormat)")
        }
    }

    func test_codable() {
        let style = Date.FormatStyle(date: .long, time: .complete, capitalizationContext: .unknown)
            .era()
            .year()
            .quarter()
            .month()
            .week()
            .day()
            .dayOfYear()
            .weekday()
            .hour()
            .minute()
            .second()
            .secondFraction(.milliseconds(2))
            .timeZone()
        let jsonEncoder = JSONEncoder()
        let encodedStyle = try? jsonEncoder.encode(style)
        XCTAssertNotNil(encodedStyle)
        let jsonDecoder = JSONDecoder()
        let decodedStyle = try? jsonDecoder.decode(Date.FormatStyle.self, from: encodedStyle!)
        XCTAssertNotNil(decodedStyle)

        XCTAssert(referenceDate.formatted(decodedStyle!) == referenceDate.formatted(style), "\(referenceDate.formatted(decodedStyle!)) should be \(referenceDate.formatted(style))")

    }

    func test_createFormatStyleMultithread() {
        let group = DispatchGroup()
        let testLocales: [String] = [ "en_US", "en_US", "en_GB", "es_SP", "zh_TW", "fr_FR", "en_US", "en_GB", "fr_FR"]
        let expectations: [String : String] = [
            "en_US": "Dec 31, 1969",
            "en_GB": "31 Dec 1969",
            "es_SP": "31 dic 1969",
            "zh_TW": "1969年12月31日",
            "fr_FR": "31 déc. 1969",
        ]
        let date = Date(timeIntervalSince1970: 0)

        for localeIdentifier in testLocales {
            DispatchQueue.global(qos: .userInitiated).async(group:group) {
                let locale = Locale(identifier: localeIdentifier)
                XCTAssertNotNil(locale)
                let timeZone = TimeZone(secondsFromGMT: -3600)!

                let formatStyle = Date.FormatStyle(date: .abbreviated, locale: locale, timeZone: timeZone)
                let formatterFromCache = ICUDateFormatter.cachedFormatter(for: formatStyle)

                let expected = expectations[localeIdentifier]!
                let result = formatterFromCache.format(date)
                XCTAssertEqual(result, expected)
            }
        }

        let result = group.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(105))
        XCTAssertEqual(result, .success)
    }

    func test_createPatternMultithread() {
        let group = DispatchGroup()
        let testLocales: [String] = [ "en_US", "en_US", "en_GB", "es_SP", "zh_TW", "fr_FR", "en_US", "en_GB", "fr_FR"]
        let expectations: [String : String] = [
            "en_US": "MMM d, y",
            "en_GB": "d MMM y",
            "es_SP": "d MMM y",
            "zh_TW": "y年M月d日",
            "fr_FR": "d MMM y",
        ]

        for localeIdentifier in testLocales {
            DispatchQueue.global(qos: .userInitiated).async(group:group) {
                let locale = Locale(identifier: localeIdentifier)
                XCTAssertNotNil(locale)

                let pattern = ICUPatternGenerator.localizedPatternForSkeleton(localeIdentifier: localeIdentifier, calendarIdentifier: .gregorian, skeleton: "yMMMd", hourCycleOption: .default)

                let expected = expectations[localeIdentifier]
                XCTAssertEqual(pattern, expected)
            }
        }

        let result = group.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(105))
        XCTAssertEqual(result, .success)
    }

    func test_roundtrip() {
        let date = Date.now
        let style = Date.FormatStyle(date: .numeric, time: .shortened)
        let format = date.formatted(style)
        let parsed = try! Date(format, strategy: style.parseStrategy)
        XCTAssertEqual(parsed.formatted(style), format)
    }

    func testLeadingDotSyntax() {
        let date = Date.now
        XCTAssertEqual(date.formatted(date: .long, time: .complete), date.formatted(Date.FormatStyle(date: .long, time: .complete)))
        XCTAssertEqual(
            date.formatted(
                .dateTime
                    .day()
                    .month()
                    .year()
            ),
            date.formatted(
                Date.FormatStyle()
                    .day()
                    .month()
                    .year()
            )
        )
    }

    func testDateFormatStyleIndividualFields() {
        let date = Date(timeIntervalSince1970: 0)

        let style = Date.FormatStyle(date: nil, time: nil, locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "UTC")!, capitalizationContext: .unknown)

        XCTAssertEqual(date.formatted(style.era(.abbreviated)), "AD")
        XCTAssertEqual(date.formatted(style.era(.wide)), "Anno Domini")
        XCTAssertEqual(date.formatted(style.era(.narrow)), "A")

        XCTAssertEqual(date.formatted(style.year(.defaultDigits)), "1970")
        XCTAssertEqual(date.formatted(style.year(.twoDigits)), "70")
        XCTAssertEqual(date.formatted(style.year(.padded(0))), "1970")
        XCTAssertEqual(date.formatted(style.year(.padded(1))), "1970")
        XCTAssertEqual(date.formatted(style.year(.padded(2))), "70")
        XCTAssertEqual(date.formatted(style.year(.padded(3))), "1970")
        XCTAssertEqual(date.formatted(style.year(.padded(999))), "0000001970")

        XCTAssertEqual(date.formatted(style.year(.relatedGregorian(minimumLength: 0))), "1970")
        XCTAssertEqual(date.formatted(style.year(.relatedGregorian(minimumLength: 999))), "0000001970")

        XCTAssertEqual(date.formatted(style.year(.extended(minimumLength: 0))), "1970")
        XCTAssertEqual(date.formatted(style.year(.extended(minimumLength: 999))), "0000001970")

        XCTAssertEqual(date.formatted(style.quarter(.oneDigit)), "1")
        XCTAssertEqual(date.formatted(style.quarter(.twoDigits)), "01")
        XCTAssertEqual(date.formatted(style.quarter(.abbreviated)), "Q1")
        XCTAssertEqual(date.formatted(style.quarter(.wide)), "1st quarter")
        XCTAssertEqual(date.formatted(style.quarter(.narrow)), "1")

        XCTAssertEqual(date.formatted(style.month(.defaultDigits)), "1")
        XCTAssertEqual(date.formatted(style.month(.twoDigits)), "01")
        XCTAssertEqual(date.formatted(style.month(.abbreviated)), "Jan")
        XCTAssertEqual(date.formatted(style.month(.wide)), "January")
        XCTAssertEqual(date.formatted(style.month(.narrow)), "J")

        XCTAssertEqual(date.formatted(style.week(.defaultDigits)), "1")
        XCTAssertEqual(date.formatted(style.week(.twoDigits)), "01")
        XCTAssertEqual(date.formatted(style.week(.weekOfMonth)), "1")

        XCTAssertEqual(date.formatted(style.day(.defaultDigits)), "1")
        XCTAssertEqual(date.formatted(style.day(.twoDigits)), "01")
        XCTAssertEqual(date.formatted(style.day(.ordinalOfDayInMonth)), "1")

        XCTAssertEqual(date.formatted(style.day(.julianModified(minimumLength: 0))), "2440588")
        XCTAssertEqual(date.formatted(style.day(.julianModified(minimumLength: 999))), "0002440588")

        XCTAssertEqual(date.formatted(style.dayOfYear(.defaultDigits)), "1")
        XCTAssertEqual(date.formatted(style.dayOfYear(.twoDigits)), "01")
        XCTAssertEqual(date.formatted(style.dayOfYear(.threeDigits)), "001")

        XCTAssertEqual(date.formatted(style.weekday(.oneDigit)), "5")
        XCTAssertEqual(date.formatted(style.weekday(.twoDigits)), "5") // This is an ICU bug
        XCTAssertEqual(date.formatted(style.weekday(.abbreviated)), "Thu")
        XCTAssertEqual(date.formatted(style.weekday(.wide)), "Thursday")
        XCTAssertEqual(date.formatted(style.weekday(.narrow)), "T")
        XCTAssertEqual(date.formatted(style.weekday(.short)), "Th")

        XCTAssertEqual(date.formatted(style.hour(.defaultDigits(amPM: .omitted))), "12")
        XCTAssertEqual(date.formatted(style.hour(.defaultDigits(amPM: .narrow))), "12\(expectedSeparator)a")
        XCTAssertEqual(date.formatted(style.hour(.defaultDigits(amPM: .abbreviated))), "12\(expectedSeparator)AM")
        XCTAssertEqual(date.formatted(style.hour(.defaultDigits(amPM: .wide))), "12\(expectedSeparator)AM")

        XCTAssertEqual(date.formatted(style.hour(.twoDigits(amPM: .omitted))), "12")
        XCTAssertEqual(date.formatted(style.hour(.twoDigits(amPM: .narrow))), "12\(expectedSeparator)a")
        XCTAssertEqual(date.formatted(style.hour(.twoDigits(amPM: .abbreviated))), "12\(expectedSeparator)AM")
        XCTAssertEqual(date.formatted(style.hour(.twoDigits(amPM: .wide))), "12\(expectedSeparator)AM")
    }

    func testFormattingWithHourCycleOverrides() throws {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"
        let esES = "es_ES"

        let style = Date.FormatStyle(date: .omitted, time: .standard, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init()))), "4:00:00\(expectedSeparator)PM")
        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init(force12Hour: true)))), "4:00:00\(expectedSeparator)PM")
        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init(force24Hour: true)))), "16:00:00")

        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init()))), "16:00:00")
        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init(force12Hour: true)))), "4:00:00\(expectedSeparator)p.\u{202f}m.")
        XCTAssertEqual(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init(force24Hour: true)))), "16:00:00")
    }

#if !os(watchOS) // 99504292
    func testNSICUDateFormatterCache() throws {
        guard Locale.autoupdatingCurrent.language.isEquivalent(to: Locale.Language(identifier: "en_US")) else {
            throw XCTSkip("This test can only be run with the system set to the en_US language")
        }

        let fixedTimeZone = TimeZone(identifier: TimeZone.current.identifier)!
        let fixedCalendar = Calendar(identifier: Calendar.current.identifier)

        let dateStyle = Date.FormatStyle.DateStyle.complete
        let timeStyle = Date.FormatStyle.TimeStyle.standard

        let style = Date.FormatStyle(date: dateStyle, time: timeStyle)
        let styleUsingFixedTimeZone = Date.FormatStyle(date: dateStyle, time: timeStyle, timeZone: fixedTimeZone)
        let styleUsingFixedCalendar = Date.FormatStyle(date: dateStyle, time: timeStyle, calendar: fixedCalendar)

        XCTAssertTrue(ICUDateFormatter.cachedFormatter(for: style) === ICUDateFormatter.cachedFormatter(for: styleUsingFixedTimeZone))
        XCTAssertTrue(ICUDateFormatter.cachedFormatter(for: style) === ICUDateFormatter.cachedFormatter(for: styleUsingFixedCalendar))
    }
#endif

    func testFormattingWithPrefsOverride() {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"

        func test(dateStyle: Date.FormatStyle.DateStyle, timeStyle: Date.FormatStyle.TimeStyle, dateFormatOverride: [Date.FormatStyle.DateStyle: String], expected: String, file: StaticString = #file, line: UInt = #line) {
            let locale = Locale.localeAsIfCurrent(name: enUS, overrides: .init(dateFormats: dateFormatOverride))
            let style = Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
            let formatted = style.format(date)
            XCTAssertEqual(formatted, expected, file: file, line: line)

            guard let parsed = try? Date(formatted, strategy: style) else {
                XCTFail("Parsing failed", file: file, line: line)
                return
            }
            let parsedStr = style.format(parsed)
            XCTAssertEqual(parsedStr, expected, "round trip formatting failed", file: file, line: line)
        }

        let dateFormatOverride: [Date.FormatStyle.DateStyle: String] = [
            .abbreviated: "'<short>' yyyy-MMM-dd",
            .numeric: "'<numeric>' yyyy-MMM-dd",
            .long: "'<long>' yyyy-MMM-dd",
            .complete: "'<complete>' yyyy-MMM-dd"
        ]

#if FOUNDATION_FRAMEWORK
        let expectTimeString = "4:00:00\u{202F}PM"
        let expectedShortTimeString = "4:00\u{202F}PM"
#else
        let expectTimeString = "4:00:00 PM"
        let expectedShortTimeString = "4:00 PM"
#endif

        test(dateStyle: .omitted, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "12/31/1969, \(expectedShortTimeString)") // Ignoring override since there's no match for the specific style
        test(dateStyle: .abbreviated, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<short> 1969-Dec-31")
        test(dateStyle: .numeric, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<numeric> 1969-Dec-31")
        test(dateStyle: .long, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<long> 1969-Dec-31")
        test(dateStyle: .complete, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<complete> 1969-Dec-31")

        test(dateStyle: .omitted, timeStyle: .standard, dateFormatOverride: dateFormatOverride, expected: expectTimeString)
        test(dateStyle: .abbreviated, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<short> 1969-Dec-31 at \(expectTimeString) PST")
        test(dateStyle: .numeric, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<numeric> 1969-Dec-31, \(expectTimeString) PST")
        test(dateStyle: .long, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<long> 1969-Dec-31 at \(expectTimeString) PST")
        test(dateStyle: .complete, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<complete> 1969-Dec-31 at \(expectTimeString) PST")

    }

    func testFormattingWithPrefsOverride_firstweekday() {
        let date = Date(timeIntervalSince1970: 0)
        let locale = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(firstWeekday: [.gregorian : 5]))
        let style = Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone).week()
        XCTAssertEqual(style.format(date), "Wednesday, December 31, 1969 (week: 53)") // First day is Thursday, so `date`, which is Wednesday, falls into the 53th week of the previous year.
    }

    func testEncodingDecodingWithPrefsOverride() {
        let date = Date(timeIntervalSince1970: 0)
        let dateFormatOverride: [Date.FormatStyle.DateStyle: String] = [
            .complete: "'<complete>' yyyy-MMM-dd"
        ]

        let localeWithOverride = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(dateFormats: dateFormatOverride))
        let style = Date.FormatStyle(date: .complete, time: .omitted, locale: localeWithOverride, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
        XCTAssertEqual(style.format(date), "<complete> 1969-Dec-31")

        guard let encoded = try? JSONEncoder().encode(style) else {
            XCTFail("Encoding Date.FormatStyle failed")
            return
        }

        guard var decoded = try? JSONDecoder().decode(Date.FormatStyle.self, from: encoded) else {
            XCTFail("Decoding failed")
            return
        }

        XCTAssertEqual(decoded._dateStyle, .complete)

        decoded.locale = localeWithOverride
        XCTAssertEqual(decoded.format(date), "<complete> 1969-Dec-31")
    }
}

extension Sequence where Element == (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?) {
    var attributedString: AttributedString {
        self.map { pair in
            return pair.1 == nil ? AttributedString(pair.0) : AttributedString(pair.0, attributes: .init().dateField(pair.1!))
        }.reduce(AttributedString(), +)
    }
}

final class DateAttributedFormatStyleTests : XCTestCase {
    var enUSLocale = Locale(identifier: "en_US")
    var gmtTimeZone = TimeZone(secondsFromGMT: 0)!

#if FOUNDATION_FRAMEWORK
    let expectedSeparator = "\u{202f}"
#else
    let expectedSeparator = " "
#endif
    
    typealias Segment = (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?)
    func testAttributedFormatStyle() throws {
        let baseStyle = Date.FormatStyle(locale: enUSLocale, timeZone: gmtTimeZone)
        // dateFormatter.date(from: "2021-04-12 15:04:32")!
        let date = Date(timeIntervalSinceReferenceDate: 639932672.0)

        let expectations: [Date.FormatStyle : [Segment]] = [
            baseStyle.month().day().hour().minute(): [("Apr", .month),
                                                      (" ", nil),
                                                      ("12", .day),
                                                      (" at ", nil),
                                                      ("3", .hour),
                                                      (":", nil),
                                                      ("04", .minute),
                                                      (expectedSeparator, nil),
                                                      ("PM", .amPM)],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributed.format(date)
            XCTAssertEqual(formatted, expectation.attributedString)
        }
    }
    func testIndividualFields() throws {
        let baseStyle = Date.FormatStyle(locale: enUSLocale, timeZone: gmtTimeZone)
        // dateFormatter.date(from: "2021-04-12 15:04:32")!
        let date = Date(timeIntervalSinceReferenceDate: 639932672.0)
        let expectations: [Date.FormatStyle : [Segment]] = [
            baseStyle.era(): [ ("AD", .era) ],
            baseStyle.year(.defaultDigits): [ ("2021", .year) ],
            baseStyle.quarter(): [ ("Q2", .quarter) ],
            baseStyle.month(.defaultDigits): [ ("4", .month) ],
            baseStyle.week(): [ ("16", .weekOfYear) ],
            baseStyle.week(.weekOfMonth): [ ("3", .weekOfMonth) ],
            baseStyle.day(): [ ("12", .day) ],
            baseStyle.dayOfYear(): [ ("102", .dayOfYear) ],
            baseStyle.weekday(): [ ("Mon", .weekday) ],
            baseStyle.hour(): [ ("3", .hour), (expectedSeparator, nil), ("PM", .amPM) ],
            baseStyle.minute(): [ ("4", .minute) ],
            baseStyle.second(): [ ("32", .second) ],
            baseStyle.timeZone(): [ ("GMT", .timeZone) ],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributed.format(date)
            XCTAssertEqual(formatted, expectation.attributedString)
        }
    }

    func testCodable() throws  {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let fields: [AttributeScopes.FoundationAttributes.DateFieldAttribute.Field] = [.era, .year, .relatedGregorianYear, .quarter, .month, .weekOfYear, .weekOfMonth, .weekday, .weekdayOrdinal, .day, .dayOfYear, .amPM, .hour, .minute, .second, .secondFraction, .timeZone]
        for field in fields {
            let encoded = try? encoder.encode(field)
            XCTAssertNotNil(encoded)

            let decoded = try? decoder.decode(AttributeScopes.FoundationAttributes.DateFieldAttribute.Field.self, from: encoded!)
            XCTAssertEqual(decoded, field)
        }
    }

    func testSettingLocale() throws {
        // dateFormatter.date(from: "2021-04-12 15:04:32")!
        let date = Date(timeIntervalSinceReferenceDate: 639932672.0)
        let zhTW = Locale(identifier: "zh_TW")

        func test(_ attributedResult: AttributedString, _ expected: [Segment], file: StaticString = #file, line: UInt = #line) {
            XCTAssertEqual(attributedResult, expected.attributedString, file: file, line: line)
        }

        test(date.formatted(.dateTime.weekday().locale(enUSLocale).attributed), [("Mon", .weekday)])
        test(date.formatted(.dateTime.weekday().locale(zhTW).attributed), [("週一", .weekday)])

        test(date.formatted(.dateTime.weekday().attributed.locale(enUSLocale)), [("Mon", .weekday)])
        test(date.formatted(.dateTime.weekday().attributed.locale(zhTW)),  [("週一", .weekday)])
    }

    func testFormattingWithPrefsOverride() {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"

        func test(dateStyle: Date.FormatStyle.DateStyle, timeStyle: Date.FormatStyle.TimeStyle, dateFormatOverride: [Date.FormatStyle.DateStyle: String], expected: [Segment], file: StaticString = #file, line: UInt = #line) {
            let locale = Locale.localeAsIfCurrent(name: enUS, overrides: .init(dateFormats: dateFormatOverride))
            let style = Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone).attributed
            XCTAssertEqual(style.format(date), expected.attributedString, file: file, line: line)
        }

        let dateFormatOverride: [Date.FormatStyle.DateStyle: String] = [
            .abbreviated: "'<short>' yyyy-MMM-dd",
            .numeric: "'<numeric>' yyyy-MMM-dd",
            .long: "'<long>' yyyy-MMM-dd",
            .complete: "'<complete>' yyyy-MMM-dd"
        ]

#if FOUNDATION_FRAMEWORK
        let expectSeparator = "\u{202F}"
#else
        let expectSeparator = " "
#endif

        test(dateStyle: .omitted, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: [
            ("12", .month),
            ("/", nil),
            ("31", .day),
            ("/", nil),
            ("1969", .year),
            (", ", nil),
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (expectSeparator, nil),
            ("PM", .amPM),
        ]) // Ignoring override since there's no match for the specific style

        test(dateStyle: .abbreviated, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: [
            ("<short> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
        ])

        test(dateStyle: .numeric, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: [
            ("<numeric> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
        ])

        test(dateStyle: .long, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: [
            ("<long> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
        ])

        test(dateStyle: .complete, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: [
            ("<complete> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
        ])

        test(dateStyle: .omitted, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: [
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (":", nil),
            ("00", .second),
            (expectSeparator, nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])

        test(dateStyle: .abbreviated, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: [
            ("<short> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
            (" at ", nil),
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (":", nil),
            ("00", .second),
            (expectSeparator, nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])

        test(dateStyle: .numeric, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: [
            ("<numeric> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
            (", ", nil),
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (":", nil),
            ("00", .second),
            (expectSeparator, nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])

        test(dateStyle: .long, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: [
            ("<long> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
            (" at ", nil),
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (":", nil),
            ("00", .second),
            (expectSeparator, nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])

        test(dateStyle: .complete, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: [
            ("<complete> ", nil),
            ("1969", .year),
            ("-", nil),
            ("Dec", .month),
            ("-", nil),
            ("31", .day),
            (" at ", nil),
            ("4", .hour),
            (":", nil),
            ("00", .minute),
            (":", nil),
            ("00", .second),
            (expectSeparator, nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])
    }
}

final class DateVerbatimFormatStyleTests : XCTestCase {
    var utcTimeZone = TimeZone(identifier: "UTC")!

    func testFormats() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)

        func verify(_ f: Date.FormatString, expected: String, file: StaticString = #file, line: UInt = #line) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian)))
            XCTAssertEqual(s, expected, file: file, line: line)
        }
        verify("\(month: .wide)", expected: "M01")
        verify("\(month: .narrow)", expected: "1")

        verify("\(weekday: .abbreviated)", expected: "Sat")
        verify("\(weekday: .wide)", expected: "Sat")
        verify("\(weekday: .narrow)", expected: "S")

        verify("\(standaloneMonth: .wide)", expected: "M01")
        verify("\(standaloneQuarter: .abbreviated)", expected: "Q1")

        verify("\(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased)) heures et \(minute: .twoDigits) minutes", expected: "14 heures et 51 minutes")
        verify("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)) heures et \(minute: .twoDigits) minutes", expected: "2 heures et 51 minutes")
    }

    func testParseable() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ f: Date.FormatString, expectedString: String, expectedDate: Date, file: StaticString = #file, line: UInt = #line) {
            let style = Date.VerbatimFormatStyle.verbatim(f, timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian))
            let s = date.formatted(style)
            XCTAssertEqual(s, expectedString)

            let d = try! Date(s, strategy: style.parseStrategy)
            XCTAssertEqual(d, expectedDate)
        }

        // dateFormatter.date(from: "2021-01-23 00:00:00")!
        verify("\(year: .twoDigits)_\(month: .defaultDigits)_\(day: .defaultDigits)", expectedString: "21_1_23", expectedDate: Date(timeIntervalSinceReferenceDate: 633052800.0))
        // dateFormatter.date(from: "2021-01-23 02:00:00")!
        verify("\(year: .defaultDigits)_\(month: .defaultDigits)_\(day: .defaultDigits) at \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)) o'clock", expectedString: "2021_1_23 at 2 o'clock", expectedDate: Date(timeIntervalSinceReferenceDate: 633060000.0))
        // dateFormatter.date(from: "2021-01-23 14:00:00")!
        verify("\(year: .defaultDigits)_\(month: .defaultDigits)_\(day: .defaultDigits) at \(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased))", expectedString: "2021_1_23 at 14", expectedDate: Date(timeIntervalSinceReferenceDate: 633103200.0))
    }

    // Test parsing strings containing `abbreviated` names
    func testNonLenientParsingAbbreviatedNames() throws {

        // dateFormatter.date(from: "1970-01-01 00:00:00")!
        let date = Date(timeIntervalSinceReferenceDate: -978307200.0)
        func verify(_ f: Date.FormatString, localeID: String, calendarID: Calendar.Identifier, expectedString: String, file: StaticString = #file, line: UInt = #line) {
            let style = Date.VerbatimFormatStyle.verbatim(f, locale: Locale(identifier: localeID), timeZone: .gmt, calendar: Calendar(identifier: calendarID))

            let s = date.formatted(style)
            XCTAssertEqual(s, expectedString, file: file, line: line)

            var strategy = style.parseStrategy
            strategy.isLenient = false
            let parsed = try? Date(s, strategy: strategy)
            XCTAssertEqual(parsed, date, file: file, line: line)
        }

        // Era: formatting
        verify("\(era: .abbreviated) \(month: .twoDigits) \(day: .twoDigits) \(year: .defaultDigits)", localeID: "en_GB", calendarID: .gregorian, expectedString: "AD 01 01 1970")

        // Quarter: formatting
        verify("\(quarter: .abbreviated) \(month: .twoDigits) \(day: .twoDigits) \(year: .defaultDigits)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Q1 01 01 1970")

        // Quarter: standalone
        verify("\(quarter: .abbreviated)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Q1")

        // Month: formatting
        verify("\(month: .abbreviated) \(day: .twoDigits) \(year: .defaultDigits)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Jan 01 1970")

        // Month: standalone
        verify("\(month: .abbreviated)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Jan")

        // Weekday: formatting
        verify("\(weekday: .abbreviated) \(month: .twoDigits) \(day: .twoDigits) \(year: .defaultDigits)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Thu 01 01 1970")

        // Weekday: standalone
        verify("\(weekday: .abbreviated)", localeID: "en_GB", calendarID: .gregorian, expectedString: "Thu")

        // Day period: formatting
        verify("\(hour: .twoDigits(clock: .twelveHour, hourCycle: .zeroBased)) \(dayPeriod: .standard(.abbreviated))", localeID: "en_GB", calendarID: .gregorian, expectedString: "00 am")
    }

    func test_95845290() throws {
        let formatString: Date.FormatString = "\(weekday: .abbreviated) \(month: .abbreviated) \(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(timeZone: .iso8601(.short)) \(year: .defaultDigits)"
        let enGB = Locale(identifier: "en_GB")
        let verbatim = Date.VerbatimFormatStyle(format: formatString, locale: enGB, timeZone: .init(secondsFromGMT: .zero)!, calendar: Calendar(identifier: .gregorian))

        do {
            let date = try Date("Sat Jun 18 16:10:00 +0000 2022", strategy: verbatim.parseStrategy)
            // dateFormatter.date(from: "2022-06-18 16:10:00")!
            XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 677261400.0))
        }

        do {
            let date = try Date("Sat Jun 18 16:10:00 +0000 2022", strategy: .fixed(format: formatString, timeZone: .gmt,  locale: enGB))
            // dateFormatter.date(from: "2022-06-18 16:10:00")!
            XCTAssertEqual(date, Date(timeIntervalSinceReferenceDate: 677261400.0))
        }
    }

    typealias Segment = (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?)

    func testAttributedString() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ f: Date.FormatString, expected: [Segment], file: StaticString = #file, line: UInt = #line) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, locale:Locale(identifier: "en_US"), timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian)).attributed)
            XCTAssertEqual(s, expected.attributedString, file: file, line: line)
        }
        verify("\(year: .twoDigits)_\(month: .defaultDigits)_\(day: .defaultDigits)", expected:
                [("21", .year),
                 ("_", nil),
                 ("1", .month),
                 ("_", nil),
                 ("23", .day)])
        verify("\(weekday: .wide) at \(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased))😜\(minute: .twoDigits)🏄🏽‍♂️\(second: .defaultDigits)", expected:
                [("Saturday", .weekday),
                 (" at ", nil),
                 ("14", .hour),
                 ("😜", nil),
                 ("51", .minute),
                 ("🏄🏽‍♂️", nil),
                 ("20", .second)])
    }

    func test_storedVar() {
        _ = Date.FormatStyle.dateTime
        _ = Date.ISO8601FormatStyle.iso8601
    }

    func testAllIndividualFields() {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)

        let gregorian = Calendar(identifier: .gregorian)
        let enUS = Locale(identifier: "en_US")

        func _verify(_ f: Date.FormatString, expected: String, file: StaticString = #file, line: UInt = #line) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, locale: enUS, timeZone: utcTimeZone, calendar: gregorian))
            XCTAssertEqual(s, expected, file: file, line: line)
        }

        _verify("\(era: .abbreviated)", expected: "AD")
        _verify("\(era: .wide)", expected: "Anno Domini")
        _verify("\(era: .narrow)", expected: "A")
        _verify("\(year: .defaultDigits)", expected: "2021")
        _verify("\(year: .twoDigits)", expected: "21")
        _verify("\(year: .padded(0))", expected: "2021")
        _verify("\(year: .padded(1))", expected: "2021")
        _verify("\(year: .padded(2))", expected: "21")
        _verify("\(year: .padded(999))", expected: "0000002021") // We cap at 10 digits
        _verify("\(year: .relatedGregorian(minimumLength: 0))", expected: "2021")
        _verify("\(year: .relatedGregorian(minimumLength: 999))", expected: "0000002021")
        _verify("\(year: .extended(minimumLength: 0))", expected: "2021")
        _verify("\(year: .extended(minimumLength: 999))", expected: "0000002021")
        _verify("\(quarter: .oneDigit)", expected: "1")
        _verify("\(quarter: .twoDigits)", expected: "01")
        _verify("\(quarter: .abbreviated)", expected: "Q1")
        _verify("\(quarter: .wide)", expected: "1st quarter")
        _verify("\(quarter: .narrow)", expected: "1")
        _verify("\(month: .defaultDigits)", expected: "1")
        _verify("\(month: .twoDigits)", expected: "01")
        _verify("\(month: .abbreviated)", expected: "Jan")
        _verify("\(month: .wide)", expected: "January")
        _verify("\(month: .narrow)", expected: "J")
        _verify("\(week: .defaultDigits)", expected: "4")
        _verify("\(week: .twoDigits)", expected: "04")
        _verify("\(week: .weekOfMonth)", expected: "4")
        _verify("\(day: .defaultDigits)", expected: "23")
        _verify("\(day: .twoDigits)", expected: "23")
        _verify("\(day: .ordinalOfDayInMonth)", expected: "4")
        _verify("\(day: .julianModified(minimumLength: 0))", expected: "2459238")
        _verify("\(day: .julianModified(minimumLength: 999))", expected: "0002459238")
        _verify("\(dayOfYear: .defaultDigits)", expected: "23")
        _verify("\(dayOfYear: .twoDigits)", expected: "23")
        _verify("\(dayOfYear: .threeDigits)", expected: "023")
        _verify("\(weekday: .oneDigit)", expected: "7")
        _verify("\(weekday: .twoDigits)", expected: "07")
        _verify("\(weekday: .abbreviated)", expected: "Sat")
        _verify("\(weekday: .wide)", expected: "Saturday")
        _verify("\(weekday: .narrow)", expected: "S")
        _verify("\(weekday: .short)", expected: "Sa")
        _verify("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased))", expected: "2")
        _verify("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased))", expected: "2")
        _verify("\(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased))", expected: "14")
        _verify("\(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .oneBased))", expected: "14")

        _verify("\(hour: .twoDigits(clock: .twelveHour, hourCycle: .zeroBased))", expected: "02")
        _verify("\(hour: .twoDigits(clock: .twelveHour, hourCycle: .oneBased))", expected: "02")
        _verify("\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))", expected: "14")
        _verify("\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .oneBased))", expected: "14")
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class MatchConsumerAndSearcherTests : XCTestCase {

    let enUS = Locale(identifier: "en_US")
    let utcTimeZone = TimeZone(identifier: "UTC")!
    let gregorian = Calendar(identifier: .gregorian)

    func _verifyUTF16String(_ string: String, matches format: Date.FormatString, in range: Range<Int>, expectedUpperBound: Int?, expectedDate: Date?, file: StaticString = #file, line: UInt = #line) {
        let lower = string.index(string.startIndex, offsetBy: range.lowerBound)
        let upper = string.index(string.startIndex, offsetBy: range.upperBound)

        _verifyString(string, matches: format, start: lower, in: lower..<upper, expectedUpperBound: (expectedUpperBound != nil) ? string.index(string.startIndex, offsetBy: expectedUpperBound!) : nil, expectedDate: expectedDate, file: file, line: line)
    }

    func _verifyString(_ string: String, matches format: Date.FormatString, start: String.Index, in range: Range<String.Index>, expectedUpperBound: String.Index?, expectedDate: Date?, file: StaticString = #file, line: UInt = #line) {
        let style = Date.VerbatimFormatStyle(format: format, locale: enUS, timeZone: utcTimeZone, calendar: gregorian)

        let m = try? style.consuming(string, startingAt: start, in: range)
        let matchedUpper = m?.upperBound
        let match = m?.output

        let upperBoundDescription = matchedUpper?.utf16Offset(in: string)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: string)
        XCTAssertEqual(matchedUpper, expectedUpperBound, "matched upperBound: \(String(describing: upperBoundDescription)), expected: \(String(describing: expectedUpperBoundDescription))", file: file, line: line)
        XCTAssertEqual(match, expectedDate, file: file, line: line)
    }

    func testMatchFullRanges() {
        func verify(_ string: String, matches format: Date.FormatString, expectedDate: TimeInterval?, file: StaticString = #file, line: UInt = #line) {
            let targetDate: Date? = (expectedDate != nil) ? Date(timeIntervalSinceReferenceDate: expectedDate!) : nil
            _verifyString(string, matches: format, start: string.startIndex, in: string.startIndex..<string.endIndex, expectedUpperBound: (expectedDate != nil) ? string.endIndex: nil, expectedDate: targetDate, file: file, line: line)
        }


        // Year: default digits
        verify("2022-02-12", matches: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)",  expectedDate: 666316800.0) // "2022-02-12 00:00:00"
        verify("2022-2-12", matches: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)",  expectedDate: 666316800.0) // "2022-02-12 00:00:00"
        verify("2022-2-1", matches: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)",  expectedDate: 665366400.0) // "2022-02-01 00:00:00"
        verify("2022-02-30", matches: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",  expectedDate: nil)
        verify("2020-02-29", matches: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",  expectedDate: 604627200.0) // "2020-02-29 00:00:00"
        verify("2022👩‍🦳2👨‍🦲28", matches: "\(year: .defaultDigits)👩‍🦳\(month: .defaultDigits)👨‍🦲\(day: .defaultDigits)", expectedDate: 667699200.0) // "2022-02-28 00:00:00"
        verify("2022/2/2", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: 665452800.0) // "2022-02-02 00:00:00"
        verify("22/2/2", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: 665452800.0) // "2022-02-02 00:00:00"
        verify("22/2/23", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: 667267200.0) // "2022-02-23 00:00:00"
        verify("22/2/00", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: nil)
        verify("22/0/2", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: nil)

        // Year: specified length
        verify("2022-02-12", matches: "\(year: .padded(4))-\(month: .twoDigits)-\(day: .twoDigits)", expectedDate: 666316800.0) // "2022-02-12 00:00:00"
        verify("0225-02-12", matches: "\(year: .padded(4))-\(month: .twoDigits)-\(day: .twoDigits)", expectedDate: -56041545600.0) // "0225-02-12 00:00:00"
        verify("22/2/2", matches: "\(year: .twoDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: 665452800.0) // "2022-02-02 00:00:00"
        verify("22/2/22", matches: "\(year: .twoDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: 667180800.0) // "2022-02-22 00:00:00"
        verify("22222", matches: "\(year: .twoDigits)\(month: .defaultDigits)\(day: .twoDigits)", expectedDate: 667180800.0) // "2022-02-22 00:00:00"

        // Month
        verify("2/28", matches: "\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("23/39", matches: "\(month: .defaultDigits)/\(day: .defaultDigits)", expectedDate: nil)
        verify("Feb_28", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("FEB_28", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("fEb_28", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("Feb_30", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: nil)
        verify("Feb_29", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: nil)
        verify("Nan_48", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedDate: nil)

        // Time
        verify("10:48", matches: "\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)):\(minute: .defaultDigits)", expectedDate:  -978268320.0) // "1970-01-01 10:48:00"
        verify("10:61", matches: "\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)):\(minute: .defaultDigits)", expectedDate: nil)
        verify("15:35", matches: "\(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .defaultDigits)", expectedDate: -978251100.0) // "1970-01-01 15:35:00"
        verify("15:35", matches: "\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)):\(minute: .defaultDigits)", expectedDate: nil)
    }

    func testMatchPartialRangesFromBeginning() {
        func verify(_ string: String, matches format: Date.FormatString, expectedMatch: String, expectedDate: TimeInterval, file: StaticString = #file, line: UInt = #line) {
            let occurrenceRange = string._range(of: expectedMatch)!
            _verifyString(string, matches: format, start: string.startIndex, in: string.startIndex..<string.endIndex, expectedUpperBound: occurrenceRange.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), file: file, line: line)
        }

        verify("2022/2/28(some_other_texts)", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00"
        verify("2022/2/28/2023/3/13/2024/4/14", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00", returns the first found date
        verify("2223", matches: "\(year: .defaultDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "222", expectedDate: -63079776000.0) // "0002-02-02 00:00:00"
        verify("2223", matches: "\(year: .twoDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "2223", expectedDate: 665539200.0) // "2022-02-03 00:00:00"

        verify("Feb_28Mar_30Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("Feb_28_Mar_30_Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0)
    }

    func testMatchPartialRangesWithinLegitimateString() {
        func verify(_ string: String, in range: Range<Int>,  matches format: Date.FormatString, expectedDate: TimeInterval, file: StaticString = #file, line: UInt = #line) {
            _verifyUTF16String(string, matches: format, in: range, expectedUpperBound: range.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), file: file, line: line)
        }

        // Match only up to "2022-2-1" though "2022-2-12" is also a legitimate date
        verify("2022-2-12", in: 0..<8, matches: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)", expectedDate: 665366400.0) // "2022-02-01 00:00:00"
        // Match only up to "202021" though "2020218" is also a legitimate date
        verify("2020218", in: 0..<6, matches: "\(year: .padded(4))\(month: .defaultDigits)\(day: .defaultDigits)", expectedDate: 602208000.0) // "2020-02-01 00:00:00"
    }

    func testDateFormatStyleMatchRoundtrip() {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ formatStyle: Date.FormatStyle, file: StaticString = #file, line: UInt = #line) {
            var format = formatStyle
            format.calendar = gregorian
            format.timeZone = utcTimeZone
            let formattedDate = format.format(date)
            let embeddedDates = [
                "\(formattedDate)",
                "\(formattedDate)trailing_text",
                "\(formattedDate)   trailing text with space",
                "\(formattedDate);\(formattedDate)",
            ]

            for embeddedDate in embeddedDates {
                let m = try? format.consuming(embeddedDate, startingAt: embeddedDate.startIndex, in: embeddedDate.startIndex..<embeddedDate.endIndex)
                let foundUpperBound = m?.upperBound
                let match = m?.output
                let expectedUpperBound = embeddedDate.range(of: formattedDate)?.upperBound
                XCTAssertEqual(foundUpperBound, expectedUpperBound, "cannot find match in: <\(embeddedDate)>", file: file, line: line)
                XCTAssertEqual(match, date, "cannot find match in: <\(embeddedDate)>", file: file, line: line)
            }


            let embeddedMiddleDates = [
                " \(formattedDate)" : 1,
                "__\(formattedDate)trailing_text" : 2,
                "🥹💩\(formattedDate)   🥹💩trailing text with space": 2,
            ]

            for (embeddedDate, startOffset) in embeddedMiddleDates {
                let start = embeddedDate.index(embeddedDate.startIndex, offsetBy: startOffset)
                let m = try? format.consuming(embeddedDate, startingAt: start, in: embeddedDate.startIndex..<embeddedDate.endIndex)
                let foundUpperBound = m?.upperBound
                let match = m?.output
                let expectedUpperBound = embeddedDate.range(of: formattedDate)?.upperBound
                XCTAssertEqual(foundUpperBound, expectedUpperBound, "cannot find match in: <\(embeddedDate)>", file: file, line: line)
                XCTAssertEqual(match, date, "cannot find match in: <\(embeddedDate)>", file: file, line: line)
            }
        }

        verify(Date.FormatStyle(date: .complete, time: .standard))
        verify(Date.FormatStyle(date: .complete, time: .complete))
        verify(Date.FormatStyle(date: .complete, time: .complete, locale: Locale(identifier: "zh_TW")))
        verify(Date.FormatStyle(date: .omitted, time: .complete, locale: enUS).year().month(.abbreviated).day(.twoDigits))
        verify(Date.FormatStyle(date: .omitted, time: .complete).year().month(.wide).day(.twoDigits).locale(Locale(identifier: "zh_TW")))
    }

    func testMatchPartialRangesFromMiddle() {
        func verify(_ string: String, matches format: Date.FormatString, expectedMatch: String, expectedDate: TimeInterval, file: StaticString = #file, line: UInt = #line) {
            let occurrenceRange = string.range(of: expectedMatch)!
            _verifyString(string, matches: format, start: occurrenceRange.lowerBound, in: string.startIndex..<string.endIndex, expectedUpperBound: occurrenceRange.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), file: file, line: line)
        }

        verify("(some_other_texts)2022/2/28(some_other_texts)", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00"
        verify("(some_other_texts)2022/2/28/2023/3/13/2024/4/14", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00", returns the first found date
        verify("(some_other_texts)2223", matches: "\(year: .defaultDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "222", expectedDate:  -63079776000.0) // "0002-02-02 00:00:00"
        verify("(some_other_texts)2223", matches: "\(year: .twoDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "2223", expectedDate: 665539200.0) // "2022-02-03 00:00:00"

        verify("(some_other_texts)Feb_28Mar_30Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("(some_other_texts)Feb_28_Mar_30_Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
    }
}

// MARK: - FoundationPreview Disabled Tests
#if FOUNDATION_FRAMEWORK
extension DateFormatStyleTests {
    func test_dateFormatPresets() {
        let locale = Locale(identifier: "en_US")
        let timezone = TimeZone(identifier: "America/Los_Angeles")!
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timezone
        dateFormatter.setLocalizedDateFormatFromTemplate("yMd")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMd")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMMEEEEd")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmm")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmmss")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmmssz")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .complete, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMdjmm")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .numeric, time: .shortened, locale: locale, timeZone: timezone)), dateFormatter.string(from: referenceDate))
    }

    func test_customParsing() {
        let expectedFormats: [(Date.FormatString, String, String)] = [
            ("\(day: .twoDigits)/\(month: .twoDigits)/\(year: .twoDigits)", "dd/MM/yy", "01/05/99"),
            ("\(day: .twoDigits)-\(month: .twoDigits)-\(year: .twoDigits)", "dd-MM-yy", "01-05-99"),
            ("\(day: .twoDigits)'\(month: .twoDigits)'\(year: .twoDigits)", "dd''MM''yy", "01'05'99"),
            ("\(day: .defaultDigits)/\(month: .abbreviated)/\(year: .padded(4))", "d/MMM/yyyy", "1/Sep/1999"),
            ("Day:\(day: .defaultDigits) Month:\(month: .abbreviated) Year:\(year: .padded(4))", "'Day:'d 'Month:'MMM 'Year:'yyyy", "Day:1 Month:Sep Year:1999"),
            ("😀:\(day: .defaultDigits) 😡:\(month: .abbreviated) 😍:\(year: .padded(4))", "'😀:'d '😡:'MMM '😡:'yyyy", "😀:1 😡:Sep 😍:1999"),

            // ICU offers to skip spaces, so we'll also allow this.
            ("\(day: .twoDigits)-\(month: .twoDigits)-\(year: .twoDigits)", "dd-MM-yy", "01 - 05 - 99"),

            // ICU can parse a 4-digit year with the 2-digit year template ("yy"), so let's also allow this.
            ("\(day: .twoDigits)-\(month: .twoDigits)-\(year: .twoDigits)", "dd-MM-yy", "01-05-1999"),

            // ICU allows this so we can't stop them from using this.
            ("\(day: .twoDigits)/\(month: .twoDigits)/\(year: .twoDigits)", "dd'/'MM'/'yy", "01-05-99"),
        ]

        let locale = Locale(identifier: "en_US")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone

        for (format, dfFormat, dateString) in expectedFormats {
            let parseStrategy = Date.ParseStrategy(format: format, locale: locale, timeZone: timeZone)
            dateFormatter.dateFormat = dfFormat
            let parsed = try? Date(dateString, strategy: parseStrategy)
            XCTAssertNotNil(parsed)
            if let oldParsed = dateFormatter.date(from: dateString) {
                XCTAssertEqual(parsed!, oldParsed, "Format: \(format); Raw format: \(format.rawFormat); Date string: \(dateString)")
            }
        }
    }

    func test_presetModifierCombination() {
        let locale = Locale(identifier: "en_US")
        let timezone = TimeZone(identifier: "America/Los_Angeles")!
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timezone
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMddjmm")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(time: .shortened, locale: locale, timeZone: timezone)
                                                .year(.padded(4))
                                                .month(.abbreviated)
                                                .day(.twoDigits)),
                       dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyyyMMMMd")
        XCTAssertEqual(referenceDate.formatted(Date.FormatStyle(date: .numeric, locale: locale, timeZone: timezone)
                                                .year(.padded(6))
                                                .month(.wide)),
                       dateFormatter.string(from: referenceDate))


    }

    func _verify(_ style: Date.FormatStyle, expectedFormat: String, locale: Locale, file: StaticString = #file, line: UInt = #line) {
        var style = style
        let timeZone = TimeZone(secondsFromGMT: -3600)!
        style.timeZone = timeZone
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = expectedFormat
        XCTAssertEqual(referenceDate.formatted(style.locale(locale)), dateFormatter.string(from: referenceDate), file: file, line: line)
    }

    func test_hourSymbols() {

        let enUS = Locale(identifier: "en_US")
        _verify(.dateTime.hour(.defaultDigits(amPM: .abbreviated)), expectedFormat: "h\u{202f}a", locale: enUS)
        _verify(.dateTime.hour(.defaultDigits(amPM: .omitted)), expectedFormat: "hh", locale: enUS)
        _verify(.dateTime.hour(.twoDigits(amPM: .omitted)), expectedFormat: "hh", locale: enUS)
        _verify(.dateTime.hour(.conversationalDefaultDigits(amPM: .omitted)), expectedFormat: "hh", locale: enUS)
        _verify(.dateTime.hour(.conversationalTwoDigits(amPM: .omitted)), expectedFormat: "hh", locale: enUS)

        let enGB = Locale(identifier: "en_GB")
        _verify(.dateTime.hour(.defaultDigits(amPM: .abbreviated)), expectedFormat: "H", locale: enGB)
        _verify(.dateTime.hour(.defaultDigits(amPM: .omitted)), expectedFormat: "H", locale: enGB)
        _verify(.dateTime.hour(.twoDigits(amPM: .omitted)), expectedFormat: "HH", locale: enGB)
        _verify(.dateTime.hour(.conversationalDefaultDigits(amPM: .omitted)), expectedFormat: "H", locale: enGB)
        _verify(.dateTime.hour(.conversationalTwoDigits(amPM: .omitted)), expectedFormat: "HH", locale: enGB)
    }
}
#endif
