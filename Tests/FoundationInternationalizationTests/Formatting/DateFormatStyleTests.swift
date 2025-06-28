// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

@Suite("Date.FormatStyle")
private struct DateFormatStyleTests {
    let referenceDate = Date(timeIntervalSinceReferenceDate: 0)

    @Test func constructorSyntax() {
        let style = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .year(.defaultDigits)
            .month(.abbreviated)
            .day(.twoDigits)
            .hour(.twoDigits(amPM: .omitted))
            .minute(.defaultDigits)
        #expect(referenceDate.formatted(style) == "Dec 31, 2000 at 04:00")
    }

    @Test func era() {
        let abbreviatedStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.abbreviated)
        #expect(referenceDate.formatted(abbreviatedStyle) == "AD")

        let narrowStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.narrow)
        #expect(referenceDate.formatted(narrowStyle) == "A")

        let wideStyle = Date.FormatStyle(locale: .init(identifier: "en_US"), calendar: .init(identifier: .gregorian), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
            .era(.wide)
        #expect(referenceDate.formatted(wideStyle) == "Anno Domini")
    }

    @Test func dateFormatString() {
        // dateFormatter.date(from: "2021-04-12 15:04:32")!
        let date = Date(timeIntervalSinceReferenceDate: 639932672.0)

        func _verify(_ format: Date.FormatString, rawExpectation: String, formattedExpectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(format.rawFormat == rawExpectation, "raw expectation failed", sourceLocation: sourceLocation)
            #expect(
                Date.VerbatimFormatStyle(format: format, timeZone: .gmt, calendar: .init(identifier: .gregorian))
                    .locale(.init(identifier: "en_US"))
                    .format(date) ==
                formattedExpectation,
                "formatted expectation failed",
                sourceLocation: sourceLocation
            )
        }

        _verify("", rawExpectation: "", formattedExpectation: "\(date)")
        _verify("some latin characters", rawExpectation: "'some latin characters'", formattedExpectation: "some latin characters")
        _verify(" ", rawExpectation: "' '", formattedExpectation: " ")
        _verify("😀😀", rawExpectation: "'😀😀'", formattedExpectation: "😀😀")
        _verify("'", rawExpectation: "''", formattedExpectation: "'")
        _verify(" ' ", rawExpectation: "' '' '", formattedExpectation: " ' ")
        _verify("' ", rawExpectation: "''' '", formattedExpectation: "' ")
        _verify(" '", rawExpectation: "' '''", formattedExpectation: " '")
        _verify("''", rawExpectation: "''''", formattedExpectation: "''")
        _verify("'some strings in single quotes'", rawExpectation: "'''some strings in single quotes'''", formattedExpectation: "'some strings in single quotes'")

        _verify("\(day: .twoDigits)\(month: .twoDigits)", rawExpectation: "ddMM", formattedExpectation: "1204")
        _verify("\(day: .twoDigits)/\(month: .twoDigits)", rawExpectation: "dd'/'MM", formattedExpectation: "12/04")
        _verify("\(day: .twoDigits)-\(month: .twoDigits)", rawExpectation: "dd'-'MM", formattedExpectation: "12-04")
        _verify("\(day: .twoDigits)'\(month: .twoDigits)", rawExpectation: "dd''MM", formattedExpectation: "12'04")
        _verify(" \(day: .twoDigits) \(month: .twoDigits) ", rawExpectation: "' 'dd' 'MM' '", formattedExpectation: " 12 04 ")

        _verify("\(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)) o'clock", rawExpectation: "h' o''clock'", formattedExpectation: "3 o'clock")

        _verify("Day:\(day: .defaultDigits) Month:\(month: .abbreviated) Year:\(year: .padded(4))", rawExpectation: "'Day:'d' Month:'MMM' Year:'yyyy", formattedExpectation: "Day:12 Month:Apr Year:2021")
    }

    @Test(arguments: [
        ("ddMMyy", "010599"),
        ("dd/MM/yy", "01/05/99"),
        ("d/MMM/yyyy", "1/Sep/1999"),
    ])
    func parsingThrows(format: Date.FormatString, dateString: String) {
        // Literal symbols are treated as literals, so they won't parse when parsing strictly
        let locale = Locale(identifier: "en_US")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        let parseStrategy = Date.ParseStrategy(format: format, locale: locale, timeZone: timeZone, isLenient: false)
        #expect(throws: (any Error).self) {
            try parseStrategy.parse(dateString)
        }
    }

    @Test func codable() throws {
        let style = Date.FormatStyle(date: .long, time: .complete, locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian), timeZone: .gmt, capitalizationContext: .unknown)
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
        let encodedStyle = try jsonEncoder.encode(style)
        let jsonDecoder = JSONDecoder()
        let decodedStyle = try jsonDecoder.decode(Date.FormatStyle.self, from: encodedStyle)

        #expect(referenceDate.formatted(decodedStyle) == referenceDate.formatted(style), "\(referenceDate.formatted(decodedStyle)) should be \(referenceDate.formatted(style))")

    }

    @Test(.timeLimit(.minutes(2)))
    func createFormatStyleMultithread() async throws {
        let testLocales: [String] = [ "en_US", "en_US", "en_GB", "es_SP", "zh_TW", "fr_FR", "en_US", "en_GB", "fr_FR"]
        let expectations: [String : String] = [
            "en_US": "Dec 31, 1969",
            "en_GB": "31 Dec 1969",
            "es_SP": "31 dic 1969",
            "zh_TW": "1969年12月31日",
            "fr_FR": "31 déc. 1969",
        ]
        let date = Date(timeIntervalSince1970: 0)

        try await withThrowingDiscardingTaskGroup { group in
            for localeIdentifier in testLocales {
                group.addTask {
                    let locale = Locale(identifier: localeIdentifier)
                    let timeZone = try #require(TimeZone(secondsFromGMT: -3600))
                    
                    let formatStyle = Date.FormatStyle(date: .abbreviated, locale: locale, timeZone: timeZone)
                    let formatterFromCache = try #require(ICUDateFormatter.cachedFormatter(for: formatStyle))
                    
                    let expected = try #require(expectations[localeIdentifier])
                    let result = formatterFromCache.format(date)
                    #expect(result == expected)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func createPatternMultithread() async {
        let testLocales = [ "en_US", "en_US", "en_GB", "es_SP", "zh_TW", "fr_FR", "en_US", "en_GB", "fr_FR"].map { Locale(identifier: $0) }
        let expectations: [String : String] = [
            "en_US": "MMM d, y",
            "en_GB": "d MMM y",
            "es_SP": "d MMM y",
            "zh_TW": "y年M月d日",
            "fr_FR": "d MMM y",
        ]

        let gregorian = Calendar(identifier: .gregorian)
        let symbols = Date.FormatStyle.DateFieldCollection(year: .defaultDigits, month: .abbreviated, day: .defaultDigits)
        await withDiscardingTaskGroup { group in
            for testLocale in testLocales {
                group.addTask {
                    let pattern = ICUPatternGenerator.localizedPattern(symbols: symbols, locale: testLocale, calendar: gregorian)
                    
                    let expected = expectations[testLocale.identifier]
                    #expect(pattern == expected)
                }
            }
        }
    }

    @Test func roundtrip() throws {
        let date = Date.now
        let style = Date.FormatStyle(date: .numeric, time: .shortened, locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian), timeZone: .gmt)
        let format = date.formatted(style)
        let parsed = try Date(format, strategy: style.parseStrategy)
        #expect(parsed.formatted(style) == format)
    }

    @Test func leadingDotSyntax() async {
        await usingCurrentInternationalizationPreferences {
            let date = Date.now
            #expect(date.formatted(date: .long, time: .complete) == date.formatted(Date.FormatStyle(date: .long, time: .complete)))
            #expect(
                date.formatted(
                    .dateTime
                        .day()
                        .month()
                        .year()
                ) ==
                date.formatted(
                    Date.FormatStyle()
                        .day()
                        .month()
                        .year()
                )
            )
        }
    }

    @Test func dateFormatStyleIndividualFields() {
        let date = Date(timeIntervalSince1970: 0)

        let style = Date.FormatStyle(date: nil, time: nil, locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "UTC")!, capitalizationContext: .unknown)

        #expect(date.formatted(style.era(.abbreviated)) == "AD")
        #expect(date.formatted(style.era(.wide)) == "Anno Domini")
        #expect(date.formatted(style.era(.narrow)) == "A")

        #expect(date.formatted(style.year(.defaultDigits)) == "1970")
        #expect(date.formatted(style.year(.twoDigits)) == "70")
        #expect(date.formatted(style.year(.padded(0))) == "1970")
        #expect(date.formatted(style.year(.padded(1))) == "1970")
        #expect(date.formatted(style.year(.padded(2))) == "70")
        #expect(date.formatted(style.year(.padded(3))) == "1970")
        #expect(date.formatted(style.year(.padded(999))) == "0000001970")

        #expect(date.formatted(style.year(.relatedGregorian(minimumLength: 0))) == "1970")
        #expect(date.formatted(style.year(.relatedGregorian(minimumLength: 999))) == "0000001970")

        #expect(date.formatted(style.year(.extended(minimumLength: 0))) == "1970")
        #expect(date.formatted(style.year(.extended(minimumLength: 999))) == "0000001970")

        #expect(date.formatted(style.quarter(.oneDigit)) == "1")
        #expect(date.formatted(style.quarter(.twoDigits)) == "01")
        #expect(date.formatted(style.quarter(.abbreviated)) == "Q1")
        #expect(date.formatted(style.quarter(.wide)) == "1st quarter")
        #expect(date.formatted(style.quarter(.narrow)) == "1")

        #expect(date.formatted(style.month(.defaultDigits)) == "1")
        #expect(date.formatted(style.month(.twoDigits)) == "01")
        #expect(date.formatted(style.month(.abbreviated)) == "Jan")
        #expect(date.formatted(style.month(.wide)) == "January")
        #expect(date.formatted(style.month(.narrow)) == "J")

        #expect(date.formatted(style.week(.defaultDigits)) == "1")
        #expect(date.formatted(style.week(.twoDigits)) == "01")
        #expect(date.formatted(style.week(.weekOfMonth)) == "1")

        #expect(date.formatted(style.day(.defaultDigits)) == "1")
        #expect(date.formatted(style.day(.twoDigits)) == "01")
        #expect(date.formatted(style.day(.ordinalOfDayInMonth)) == "1")

        #expect(date.formatted(style.day(.julianModified(minimumLength: 0))) == "2440588")
        #expect(date.formatted(style.day(.julianModified(minimumLength: 999))) == "0002440588")

        #expect(date.formatted(style.dayOfYear(.defaultDigits)) == "1")
        #expect(date.formatted(style.dayOfYear(.twoDigits)) == "01")
        #expect(date.formatted(style.dayOfYear(.threeDigits)) == "001")

        #expect(date.formatted(style.weekday(.oneDigit)) == "5")
        #expect(date.formatted(style.weekday(.twoDigits)) == "5") // This is an ICU bug
        #expect(date.formatted(style.weekday(.abbreviated)) == "Thu")
        #expect(date.formatted(style.weekday(.wide)) == "Thursday")
        #expect(date.formatted(style.weekday(.narrow)) == "T")
        #expect(date.formatted(style.weekday(.short)) == "Th")

        #expect(date.formatted(style.hour(.defaultDigits(amPM: .omitted))) == "12")
        #expect(date.formatted(style.hour(.defaultDigits(amPM: .narrow))) == "12 a")
        #expect(date.formatted(style.hour(.defaultDigits(amPM: .abbreviated))) == "12 AM")
        #expect(date.formatted(style.hour(.defaultDigits(amPM: .wide))) == "12 AM")

        #expect(date.formatted(style.hour(.twoDigits(amPM: .omitted))) == "12")
        #expect(date.formatted(style.hour(.twoDigits(amPM: .narrow))) == "12 a")
        #expect(date.formatted(style.hour(.twoDigits(amPM: .abbreviated))) == "12 AM")
        #expect(date.formatted(style.hour(.twoDigits(amPM: .wide))) == "12 AM")
    }

    @Test func formattingWithHourCycleOverrides() throws {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"
        let esES = "es_ES"

        let style = Date.FormatStyle(date: .omitted, time: .standard, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init()))) == "4:00:00 PM")
        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init(force12Hour: true)))) == "4:00:00 PM")
        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: enUS, overrides: .init(force24Hour: true)))) == "16:00:00")

        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init()))) == "16:00:00")
        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init(force12Hour: true)))) == "4:00:00 p. m.")
        #expect(date.formatted(style.locale(Locale.localeAsIfCurrent(name: esES, overrides: .init(force24Hour: true)))) == "16:00:00")
    }
    
#if !os(watchOS) // 99504292
    @Test func nsICUDateFormatterCache() async throws {
        await usingCurrentInternationalizationPreferences {
            // This test can only be run with the system set to the en_US language
            var prefs = LocalePreferences()
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            
            let fixedTimeZone = TimeZone(identifier: TimeZone.current.identifier)!
            let fixedCalendar = Calendar(identifier: Calendar.current.identifier)
            
            let dateStyle = Date.FormatStyle.DateStyle.complete
            let timeStyle = Date.FormatStyle.TimeStyle.standard
            
            let style = Date.FormatStyle(date: dateStyle, time: timeStyle)
            let styleUsingFixedTimeZone = Date.FormatStyle(date: dateStyle, time: timeStyle, timeZone: fixedTimeZone)
            let styleUsingFixedCalendar = Date.FormatStyle(date: dateStyle, time: timeStyle, calendar: fixedCalendar)
            
            #expect(ICUDateFormatter.cachedFormatter(for: style) === ICUDateFormatter.cachedFormatter(for: styleUsingFixedTimeZone))
            #expect(ICUDateFormatter.cachedFormatter(for: style) === ICUDateFormatter.cachedFormatter(for: styleUsingFixedCalendar))
        }
    }
#endif

// Only Foundation framework supports the DateStyle override
#if FOUNDATION_FRAMEWORK
    @Test func formattingWithPrefsOverride() throws {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"

        func test(dateStyle: Date.FormatStyle.DateStyle, timeStyle: Date.FormatStyle.TimeStyle, dateFormatOverride: [Date.FormatStyle.DateStyle: String], expected: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let locale = Locale.localeAsIfCurrent(name: enUS, overrides: .init(dateFormats: dateFormatOverride))
            let style = Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
            let formatted = style.format(date)
            #expect(formatted == expected, sourceLocation: sourceLocation)

            let parsed = try Date(formatted, strategy: style)
            let parsedStr = style.format(parsed)
            #expect(parsedStr == expected, "round trip formatting failed", sourceLocation: sourceLocation)
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

        try test(dateStyle: .omitted, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "12/31/1969, \(expectedShortTimeString)") // Ignoring override since there's no match for the specific style
        try test(dateStyle: .abbreviated, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<short> 1969-Dec-31")
        try test(dateStyle: .numeric, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<numeric> 1969-Dec-31")
        try test(dateStyle: .long, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<long> 1969-Dec-31")
        try test(dateStyle: .complete, timeStyle: .omitted, dateFormatOverride: dateFormatOverride, expected: "<complete> 1969-Dec-31")

        try test(dateStyle: .omitted, timeStyle: .standard, dateFormatOverride: dateFormatOverride, expected: expectTimeString)
        try test(dateStyle: .abbreviated, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<short> 1969-Dec-31 at \(expectTimeString) PST")
        try test(dateStyle: .numeric, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<numeric> 1969-Dec-31, \(expectTimeString) PST")
        try test(dateStyle: .long, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<long> 1969-Dec-31 at \(expectTimeString) PST")
        try test(dateStyle: .complete, timeStyle: .complete, dateFormatOverride: dateFormatOverride, expected: "<complete> 1969-Dec-31 at \(expectTimeString) PST")

    }
#endif

    @Test func formattingWithPrefsOverride_firstweekday() {
        let date = Date(timeIntervalSince1970: 0)
        let locale = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(firstWeekday: [.gregorian : 5]))
        let style = Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone).week()
        #expect(style.format(date) == "Wednesday, December 31, 1969 (week: 53)") // First day is Thursday, so `date`, which is Wednesday, falls into the 53th week of the previous year.
    }

#if FOUNDATION_FRAMEWORK
    @Test func encodingDecodingWithPrefsOverride() throws {
        let date = Date(timeIntervalSince1970: 0)
        let dateFormatOverride: [Date.FormatStyle.DateStyle: String] = [
            .complete: "'<complete>' yyyy-MMM-dd"
        ]

        let localeWithOverride = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(dateFormats: dateFormatOverride))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "PST")!
        let style = Date.FormatStyle(date: .complete, time: .omitted, locale: localeWithOverride, calendar: calendar, timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone)
        #expect(style.format(date) == "<complete> 1969-Dec-31")

        let encoded = try JSONEncoder().encode(style)
        var decoded = try JSONDecoder().decode(Date.FormatStyle.self, from: encoded)

        #expect(decoded._dateStyle == .complete)

        decoded.locale = localeWithOverride
        #expect(decoded.format(date) == "<complete> 1969-Dec-31")
    }
#endif

    @Test func conversationalDayPeriodsOverride() throws {
        let middleOfNight = try Date("2001-01-01T03:50:00Z", strategy: .iso8601)
        let earlyMorning = try Date("2001-01-01T06:50:00Z", strategy: .iso8601)
        let morning = try Date("2001-01-01T09:50:00Z", strategy: .iso8601)
        let noon = try Date("2001-01-01T12:50:00Z", strategy: .iso8601)
        let afternoon = try Date("2001-01-01T15:50:00Z", strategy: .iso8601)
        let evening = try Date("2001-01-01T21:50:00Z", strategy: .iso8601)

        var locale: Locale
        var format: Date.FormatStyle
        func verifyWithFormat(_ date: Date, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let fmt = format.locale(locale)
            let formatted = fmt.format(date)
            #expect(formatted == expected, sourceLocation: sourceLocation)
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour()
            verifyWithFormat(middleOfNight, expected: "凌晨3時")
            verifyWithFormat(earlyMorning, expected: "清晨6時")
            verifyWithFormat(morning, expected: "上午9時")
            verifyWithFormat(noon, expected: "中午12時")
            verifyWithFormat(afternoon, expected: "下午3時")
            verifyWithFormat(evening, expected: "晚上9時")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.defaultDigits(amPM: .abbreviated))
            verifyWithFormat(middleOfNight, expected: "凌晨3時")
            verifyWithFormat(earlyMorning, expected: "清晨6時")
            verifyWithFormat(morning, expected: "上午9時")
            verifyWithFormat(noon, expected: "中午12時")
            verifyWithFormat(afternoon, expected: "下午3時")
            verifyWithFormat(evening, expected: "晚上9時")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.twoDigits(amPM: .abbreviated))
            verifyWithFormat(middleOfNight, expected: "凌晨03時")
            verifyWithFormat(earlyMorning, expected: "清晨06時")
            verifyWithFormat(morning, expected: "上午09時")
            verifyWithFormat(noon, expected: "中午12時")
            verifyWithFormat(afternoon, expected: "下午03時")
            verifyWithFormat(evening, expected: "晚上09時")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour().minute()
            verifyWithFormat(middleOfNight, expected: "凌晨3:50")
            verifyWithFormat(earlyMorning, expected: "清晨6:50")
            verifyWithFormat(morning, expected: "上午9:50")
            verifyWithFormat(noon, expected: "中午12:50")
            verifyWithFormat(afternoon, expected: "下午3:50")
            verifyWithFormat(evening, expected: "晚上9:50")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.defaultDigits(amPM: .wide)).minute()
            verifyWithFormat(middleOfNight, expected: "凌晨3:50")
            verifyWithFormat(earlyMorning, expected: "清晨6:50")
            verifyWithFormat(morning, expected: "上午9:50")
            verifyWithFormat(noon, expected: "中午12:50")
            verifyWithFormat(afternoon, expected: "下午3:50")
            verifyWithFormat(evening, expected: "晚上9:50")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.twoDigits(amPM: .wide)).minute()
            verifyWithFormat(middleOfNight, expected: "凌晨03:50")
            verifyWithFormat(earlyMorning, expected: "清晨06:50")
            verifyWithFormat(morning, expected: "上午09:50")
            verifyWithFormat(noon, expected: "中午12:50")
            verifyWithFormat(afternoon, expected: "下午03:50")
            verifyWithFormat(evening, expected: "晚上09:50")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour().minute().second()
            verifyWithFormat(middleOfNight, expected: "凌晨3:50:00")
            verifyWithFormat(earlyMorning, expected: "清晨6:50:00")
            verifyWithFormat(morning, expected: "上午9:50:00")
            verifyWithFormat(noon, expected: "中午12:50:00")
            verifyWithFormat(afternoon, expected: "下午3:50:00")
            verifyWithFormat(evening, expected: "晚上9:50:00")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.defaultDigits(amPM: .wide)).minute().second()
            verifyWithFormat(middleOfNight, expected: "凌晨3:50:00")
            verifyWithFormat(earlyMorning, expected: "清晨6:50:00")
            verifyWithFormat(morning, expected: "上午9:50:00")
            verifyWithFormat(noon, expected: "中午12:50:00")
            verifyWithFormat(afternoon, expected: "下午3:50:00")
            verifyWithFormat(evening, expected: "晚上9:50:00")
        }

        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.twoDigits(amPM: .wide)).minute().second()
            verifyWithFormat(middleOfNight, expected: "凌晨03:50:00")
            verifyWithFormat(earlyMorning, expected: "清晨06:50:00")
            verifyWithFormat(morning, expected: "上午09:50:00")
            verifyWithFormat(noon, expected: "中午12:50:00")
            verifyWithFormat(afternoon, expected: "下午03:50:00")
            verifyWithFormat(evening, expected: "晚上09:50:00")
        }

        // Test for not showing day period
        do {
            locale = Locale(identifier: "zh_TW")
            format = .init(timeZone: .gmt).hour(.defaultDigits(amPM: .omitted))
            verifyWithFormat(middleOfNight, expected: "3時")
            verifyWithFormat(earlyMorning, expected: "6時")
            verifyWithFormat(morning, expected: "9時")
            verifyWithFormat(noon, expected: "12時")
            verifyWithFormat(afternoon, expected: "3時")
            verifyWithFormat(evening, expected: "9時")
        }

        do {
            locale = Locale(identifier: "zh_TW@hours=h24") // using 24-hour time
            format = .init(timeZone: .gmt).hour()
            verifyWithFormat(middleOfNight, expected: "3時")
            verifyWithFormat(earlyMorning, expected: "6時")
            verifyWithFormat(morning, expected: "9時")
            verifyWithFormat(noon, expected: "12時")
            verifyWithFormat(afternoon, expected: "15時")
            verifyWithFormat(evening, expected: "21時")
        }

        do {
            var custom24HourLocale = Locale.Components(identifier: "zh_TW")
            custom24HourLocale.hourCycle = .zeroToTwentyThree // using 24-hour time
            locale = Locale(components: custom24HourLocale)
            format = .init(timeZone: .gmt).hour()
            verifyWithFormat(middleOfNight, expected: "3時")
            verifyWithFormat(earlyMorning, expected: "6時")
            verifyWithFormat(morning, expected: "9時")
            verifyWithFormat(noon, expected: "12時")
            verifyWithFormat(afternoon, expected: "15時")
            verifyWithFormat(evening, expected: "21時")
        }

        do {
            locale = Locale.localeAsIfCurrent(name: "zh_TW", overrides: .init(force24Hour: true))
            format = .init(timeZone: .gmt).hour()
            verifyWithFormat(middleOfNight, expected: "3時")
            verifyWithFormat(earlyMorning, expected: "6時")
            verifyWithFormat(morning, expected: "9時")
            verifyWithFormat(noon, expected: "12時")
            verifyWithFormat(afternoon, expected: "15時")
            verifyWithFormat(evening, expected: "21時")
        }

        // Tests for when region matches the special case but language doesn't
        do {
            locale = Locale(identifier: "en_TW")
            format = .init(timeZone: .gmt).hour(.twoDigits(amPM: .wide)).minute().second()
            verifyWithFormat(middleOfNight, expected: "03:50:00 AM")
            verifyWithFormat(earlyMorning, expected: "06:50:00 AM")
            verifyWithFormat(morning, expected: "09:50:00 AM")
            verifyWithFormat(noon, expected: "12:50:00 PM")
            verifyWithFormat(afternoon, expected: "03:50:00 PM")
            verifyWithFormat(evening, expected: "09:50:00 PM")
        }
    }

    @Test func removingFields() {
        var format: Date.FormatStyle = .init(calendar: .init(identifier: .gregorian), timeZone: .gmt).locale(Locale(identifier: "en_US"))
        func verifyWithFormat(_ date: Date, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let formatted = format.format(date)
            #expect(formatted == expected, sourceLocation: sourceLocation)
        }

        let date = Date(timeIntervalSince1970: 0)

        verifyWithFormat(date, expected: "1/1/1970, 12:00 AM")
        format = format.day(.omitted)
        verifyWithFormat(date, expected: "1/1970, 12:00 AM")
        format = format.day(.defaultDigits)
        verifyWithFormat(date, expected: "1/1/1970, 12:00 AM")
        format = format.minute()
        verifyWithFormat(date, expected: "1/1/1970, 12:00 AM")
        format = format.minute(.omitted)
        verifyWithFormat(date, expected: "1/1/1970, 12 AM")
        format = format.day(.omitted)
        verifyWithFormat(date, expected: "1/1970, 12 AM")

        format = .init(calendar: .init(identifier: .gregorian), timeZone: .gmt).locale(Locale(identifier: "en_US"))
        format = format.day()
        format = format.day(.omitted)
        verifyWithFormat(date, expected: "")
    }
}

extension Sequence where Element == (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?) {
    var attributedString: AttributedString {
        self.map { pair in
            return pair.1 == nil ? AttributedString(pair.0) : AttributedString(pair.0, attributes: .init().dateField(pair.1!))
        }.reduce(AttributedString(), +)
    }
}

@Suite("Attributed Date.FormatStyle")
private struct DateAttributedFormatStyleTests {
    var enUSLocale = Locale(identifier: "en_US")
    var gmtTimeZone = TimeZone(secondsFromGMT: 0)!

    typealias Segment = (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?)
    @Test func attributedFormatStyle() throws {
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
                                                      (" ", nil),
                                                      ("PM", .amPM)],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributedStyle.format(date)
            #expect(formatted == expectation.attributedString)
        }
    }
    
    @Test func individualFields() throws {
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
            baseStyle.hour(): [ ("3", .hour), (" ", nil), ("PM", .amPM) ],
            baseStyle.minute(): [ ("4", .minute) ],
            baseStyle.second(): [ ("32", .second) ],
            baseStyle.timeZone(): [ ("GMT", .timeZone) ],
        ]

        for (style, expectation) in expectations {
            let formatted = style.attributedStyle.format(date)
            #expect(formatted == expectation.attributedString)
        }
    }

    @Test func codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let fields: [AttributeScopes.FoundationAttributes.DateFieldAttribute.Field] = [.era, .year, .relatedGregorianYear, .quarter, .month, .weekOfYear, .weekOfMonth, .weekday, .weekdayOrdinal, .day, .dayOfYear, .amPM, .hour, .minute, .second, .secondFraction, .timeZone]
        for field in fields {
            let encoded = try encoder.encode(field)

            let decoded = try decoder.decode(AttributeScopes.FoundationAttributes.DateFieldAttribute.Field.self, from: encoded)
            #expect(decoded == field)
        }
    }

    @Test func settingLocale() throws {
        // dateFormatter.date(from: "2021-04-12 15:04:32")!
        let date = Date(timeIntervalSinceReferenceDate: 639932672.0)
        let zhTW = Locale(identifier: "zh_TW")

        func test(_ attributedResult: AttributedString, _ expected: [Segment], sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(attributedResult == expected.attributedString, sourceLocation: sourceLocation)
        }

        var format = Date.FormatStyle.dateTime
        format.timeZone = .gmt

        test(date.formatted(format.weekday().locale(enUSLocale).attributedStyle), [("Mon", .weekday)])
        test(date.formatted(format.weekday().locale(zhTW).attributedStyle), [("週一", .weekday)])

        test(date.formatted(format.weekday().attributedStyle.locale(enUSLocale)), [("Mon", .weekday)])
        test(date.formatted(format.weekday().attributedStyle.locale(zhTW)),  [("週一", .weekday)])
    }

#if FOUNDATION_FRAMEWORK
    @Test func formattingWithPrefsOverride() {
        let date = Date(timeIntervalSince1970: 0)
        let enUS = "en_US"

        func test(dateStyle: Date.FormatStyle.DateStyle, timeStyle: Date.FormatStyle.TimeStyle, dateFormatOverride: [Date.FormatStyle.DateStyle: String], expected: [Segment], sourceLocation: SourceLocation = #_sourceLocation) {
            let locale = Locale.localeAsIfCurrent(name: enUS, overrides: .init(dateFormats: dateFormatOverride))
            let style = Date.FormatStyle(date: dateStyle, time: timeStyle, locale: locale, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "PST")!, capitalizationContext: .standalone).attributedStyle
            #expect(style.format(date) == expected.attributedString, sourceLocation: sourceLocation)
        }

        let dateFormatOverride: [Date.FormatStyle.DateStyle: String] = [
            .abbreviated: "'<short>' yyyy-MMM-dd",
            .numeric: "'<numeric>' yyyy-MMM-dd",
            .long: "'<long>' yyyy-MMM-dd",
            .complete: "'<complete>' yyyy-MMM-dd"
        ]

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
            (" ", nil),
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
            (" ", nil),
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
            (" ", nil),
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
            (" ", nil),
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
            (" ", nil),
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
            (" ", nil),
            ("PM", .amPM),
            (" ", nil),
            ("PST", .timeZone),
        ])
    }
#endif
}

@Suite("Verbatim Date.FormatStyle")
private struct DateVerbatimFormatStyleTests {
    var utcTimeZone = TimeZone(identifier: "UTC")!

    @Test func formats() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)

        func verify(_ f: Date.FormatString, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian)))
            #expect(s == expected, sourceLocation: sourceLocation)
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

    @Test func parseable() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ f: Date.FormatString, expectedString: String, expectedDate: Date, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let style = Date.VerbatimFormatStyle.verbatim(f, timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian))
            let s = date.formatted(style)
            #expect(s == expectedString, sourceLocation: sourceLocation)

            let d = try Date(s, strategy: style.parseStrategy)
            #expect(d == expectedDate, sourceLocation: sourceLocation)
        }

        // dateFormatter.date(from: "2021-01-23 00:00:00")!
        try verify("\(year: .twoDigits)_\(month: .defaultDigits)_\(day: .defaultDigits)", expectedString: "21_1_23", expectedDate: Date(timeIntervalSinceReferenceDate: 633052800.0))
        // dateFormatter.date(from: "2021-01-23 02:00:00")!
        try verify("\(year: .defaultDigits)_\(month: .defaultDigits)_\(day: .defaultDigits) at \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .zeroBased)) o'clock", expectedString: "2021_1_23 at 2 o'clock", expectedDate: Date(timeIntervalSinceReferenceDate: 633060000.0))
        // dateFormatter.date(from: "2021-01-23 14:00:00")!
        try verify("\(year: .defaultDigits)_\(month: .defaultDigits)_\(day: .defaultDigits) at \(hour: .defaultDigits(clock: .twentyFourHour, hourCycle: .zeroBased))", expectedString: "2021_1_23 at 14", expectedDate: Date(timeIntervalSinceReferenceDate: 633103200.0))
    }

    // Test parsing strings containing `abbreviated` names
    @Test func nonLenientParsingAbbreviatedNames() throws {

        // dateFormatter.date(from: "1970-01-01 00:00:00")!
        let date = Date(timeIntervalSinceReferenceDate: -978307200.0)
        func verify(_ f: Date.FormatString, localeID: String, calendarID: Calendar.Identifier, expectedString: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let style = Date.VerbatimFormatStyle.verbatim(f, locale: Locale(identifier: localeID), timeZone: .gmt, calendar: Calendar(identifier: calendarID))

            let s = date.formatted(style)
            #expect(s == expectedString, sourceLocation: sourceLocation)

            var strategy = style.parseStrategy
            strategy.isLenient = false
            let parsed = try? Date(s, strategy: strategy)
            #expect(parsed == date, sourceLocation: sourceLocation)
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
#if FIXED_ICU_74_DAYPERIOD
        verify("\(hour: .twoDigits(clock: .twelveHour, hourCycle: .zeroBased)) \(dayPeriod: .standard(.abbreviated))", localeID: "en_GB", calendarID: .gregorian, expectedString: "00 AM")
#endif // FIXED_ICU_74_DAYPERIOD
    }

    @Test func issue95845290() throws {
        let formatString: Date.FormatString = "\(weekday: .abbreviated) \(month: .abbreviated) \(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits) \(timeZone: .iso8601(.short)) \(year: .defaultDigits)"
        let enGB = Locale(identifier: "en_GB")
        let verbatim = Date.VerbatimFormatStyle(format: formatString, locale: enGB, timeZone: .init(secondsFromGMT: .zero)!, calendar: Calendar(identifier: .gregorian))

        do {
            let date = try Date("Sat Jun 18 16:10:00 +0000 2022", strategy: verbatim.parseStrategy)
            // dateFormatter.date(from: "2022-06-18 16:10:00")!
            #expect(date == Date(timeIntervalSinceReferenceDate: 677261400.0))
        }

        do {
            let date = try Date("Sat Jun 18 16:10:00 +0000 2022", strategy: .fixed(format: formatString, timeZone: .gmt,  locale: enGB))
            // dateFormatter.date(from: "2022-06-18 16:10:00")!
            #expect(date == Date(timeIntervalSinceReferenceDate: 677261400.0))
        }
    }

    typealias Segment = (String, AttributeScopes.FoundationAttributes.DateFieldAttribute.Field?)

    @Test func attributedString() throws {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ f: Date.FormatString, expected: [Segment], file: StaticString = #filePath, sourceLocation: SourceLocation = #_sourceLocation) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, locale:Locale(identifier: "en_US"), timeZone: utcTimeZone, calendar: Calendar(identifier: .gregorian)).attributedStyle)
            #expect(s == expected.attributedString, sourceLocation: sourceLocation)
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

    @Test func storedVar() {
        _ = Date.FormatStyle.dateTime
        _ = Date.ISO8601FormatStyle.iso8601
    }

    @Test func allIndividualFields() {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)

        let gregorian = Calendar(identifier: .gregorian)
        let enUS = Locale(identifier: "en_US")

        func _verify(_ f: Date.FormatString, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let s = date.formatted(Date.VerbatimFormatStyle.verbatim(f, locale: enUS, timeZone: utcTimeZone, calendar: gregorian))
            #expect(s == expected, sourceLocation: sourceLocation)
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

@Suite("Match Consumer and Searcher")
private struct MatchConsumerAndSearcherTests {

    let enUS = Locale(identifier: "en_US")
    let utcTimeZone = TimeZone(identifier: "UTC")!
    let gregorian = Calendar(identifier: .gregorian)

    func _verifyUTF16String(_ string: String, matches format: Date.FormatString, in range: Range<Int>, expectedUpperBound: Int?, expectedDate: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
        let lower = string.index(string.startIndex, offsetBy: range.lowerBound)
        let upper = string.index(string.startIndex, offsetBy: range.upperBound)

        _verifyString(string, matches: format, start: lower, in: lower..<upper, expectedUpperBound: (expectedUpperBound != nil) ? string.index(string.startIndex, offsetBy: expectedUpperBound!) : nil, expectedDate: expectedDate, sourceLocation: sourceLocation)
    }

    func _verifyString(_ string: String, matches format: Date.FormatString, start: String.Index, in range: Range<String.Index>, expectedUpperBound: String.Index?, expectedDate: Date?, sourceLocation: SourceLocation = #_sourceLocation) {
        let style = Date.VerbatimFormatStyle(format: format, locale: enUS, timeZone: utcTimeZone, calendar: gregorian)

        let m = try? style.consuming(string, startingAt: start, in: range)
        let matchedUpper = m?.upperBound
        let match = m?.output

        let upperBoundDescription = matchedUpper?.utf16Offset(in: string)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: string)
        #expect(matchedUpper == expectedUpperBound, "matched upperBound: \(String(describing: upperBoundDescription)), expected: \(String(describing: expectedUpperBoundDescription))", sourceLocation: sourceLocation)
        #expect(match == expectedDate, sourceLocation: sourceLocation)
    }

    @Test func matchFullRanges() {
        func verify(_ string: String, matches format: Date.FormatString, expectedDate: TimeInterval?, sourceLocation: SourceLocation = #_sourceLocation) {
            let targetDate: Date? = (expectedDate != nil) ? Date(timeIntervalSinceReferenceDate: expectedDate!) : nil
            _verifyString(string, matches: format, start: string.startIndex, in: string.startIndex..<string.endIndex, expectedUpperBound: (expectedDate != nil) ? string.endIndex: nil, expectedDate: targetDate, sourceLocation: sourceLocation)
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

#if FOUNDATION_FRAMEWORK
    // Disabled in package because _range is imported twice, once from Essentials, once from Internationalization
    @Test func matchPartialRangesFromBeginning() {
        func verify(_ string: String, matches format: Date.FormatString, expectedMatch: String, expectedDate: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) {
            let occurrenceRange = string._range(of: expectedMatch, anchored: false, backwards: false)!
            _verifyString(string, matches: format, start: string.startIndex, in: string.startIndex..<string.endIndex, expectedUpperBound: occurrenceRange.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), sourceLocation: sourceLocation)
        }

        verify("2022/2/28(some_other_texts)", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00"
        verify("2022/2/28/2023/3/13/2024/4/14", matches: "\(year: .defaultDigits)/\(month: .defaultDigits)/\(day: .defaultDigits)", expectedMatch: "2022/2/28", expectedDate: 667699200.0) // "2022-02-28 00:00:00", returns the first found date
        verify("2223", matches: "\(year: .defaultDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "222", expectedDate: -63079776000.0) // "0002-02-02 00:00:00"
        verify("2223", matches: "\(year: .twoDigits)\(month: .defaultDigits)\(day: .defaultDigits)", expectedMatch: "2223", expectedDate: 665539200.0) // "2022-02-03 00:00:00"

        verify("Feb_28Mar_30Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0) // "1970-02-28 00:00:00"
        verify("Feb_28_Mar_30_Apr_2", matches: "\(month: .abbreviated)_\(day: .defaultDigits)", expectedMatch: "Feb_28", expectedDate: -973296000.0)
    }
#endif

    @Test func matchPartialRangesWithinLegitimateString() {
        func verify(_ string: String, in range: Range<Int>,  matches format: Date.FormatString, expectedDate: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) {
            _verifyUTF16String(string, matches: format, in: range, expectedUpperBound: range.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), sourceLocation: sourceLocation)
        }

        // Match only up to "2022-2-1" though "2022-2-12" is also a legitimate date
        verify("2022-2-12", in: 0..<8, matches: "\(year: .defaultDigits)-\(month: .defaultDigits)-\(day: .defaultDigits)", expectedDate: 665366400.0) // "2022-02-01 00:00:00"
        // Match only up to "202021" though "2020218" is also a legitimate date
        verify("2020218", in: 0..<6, matches: "\(year: .padded(4))\(month: .defaultDigits)\(day: .defaultDigits)", expectedDate: 602208000.0) // "2020-02-01 00:00:00"
    }

    @Test func dateFormatStyleMatchRoundtrip() {
        // dateFormatter.date(from: "2021-01-23 14:51:20")!
        let date = Date(timeIntervalSinceReferenceDate: 633106280.0)
        func verify(_ formatStyle: Date.FormatStyle, sourceLocation: SourceLocation = #_sourceLocation) {
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
                let expectedUpperBound = embeddedDate.firstRange(of: formattedDate)?.upperBound
                #expect(foundUpperBound == expectedUpperBound, "cannot find match in: <\(embeddedDate)>", sourceLocation: sourceLocation)
                #expect(match == date, "cannot find match in: <\(embeddedDate)>", sourceLocation: sourceLocation)
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
                let expectedUpperBound = embeddedDate.firstRange(of: formattedDate)?.upperBound
                #expect(foundUpperBound == expectedUpperBound, "cannot find match in: <\(embeddedDate)>", sourceLocation: sourceLocation)
                #expect(match == date, "cannot find match in: <\(embeddedDate)>", sourceLocation: sourceLocation)
            }
        }

        verify(Date.FormatStyle(date: .complete, time: .standard, locale: Locale(identifier: "zh_TW")))
        verify(Date.FormatStyle(date: .complete, time: .complete, locale: Locale(identifier: "zh_TW")))
        verify(Date.FormatStyle(date: .omitted, time: .complete, locale: enUS).year().month(.abbreviated).day(.twoDigits))
        verify(Date.FormatStyle(date: .omitted, time: .complete).year().month(.wide).day(.twoDigits).locale(Locale(identifier: "zh_TW")))
    }

    @Test func matchPartialRangesFromMiddle() {
        func verify(_ string: String, matches format: Date.FormatString, expectedMatch: String, expectedDate: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) {
            let occurrenceRange = string.firstRange(of: expectedMatch)!
            _verifyString(string, matches: format, start: occurrenceRange.lowerBound, in: string.startIndex..<string.endIndex, expectedUpperBound: occurrenceRange.upperBound, expectedDate: Date(timeIntervalSinceReferenceDate: expectedDate), sourceLocation: sourceLocation)
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
    @Test func dateFormatPresets() {
        let locale = Locale(identifier: "en_US")
        let timezone = TimeZone(identifier: "America/Los_Angeles")!
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timezone
        dateFormatter.setLocalizedDateFormatFromTemplate("yMd")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMd")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMMd")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMMMMEEEEd")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmm")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmmss")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("jmmssz")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .omitted, time: .complete, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yMdjmm")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .numeric, time: .shortened, locale: locale, timeZone: timezone)) == dateFormatter.string(from: referenceDate))
    }

    @Test func customParsing() throws {
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
            let parsed = try Date(dateString, strategy: parseStrategy)
            if let oldParsed = dateFormatter.date(from: dateString) {
                #expect(parsed == oldParsed, "Format: \(format); Raw format: \(format.rawFormat); Date string: \(dateString)")
            }
        }
    }

    @Test func presetModifierCombination() {
        let locale = Locale(identifier: "en_US")
        let timezone = TimeZone(identifier: "America/Los_Angeles")!
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timezone
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMddjmm")
        #expect(referenceDate.formatted(Date.FormatStyle(time: .shortened, locale: locale, timeZone: timezone)
                                                .year(.padded(4))
                                                .month(.abbreviated)
                                                .day(.twoDigits)) ==
                       dateFormatter.string(from: referenceDate))

        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyyyMMMMd")
        #expect(referenceDate.formatted(Date.FormatStyle(date: .numeric, locale: locale, timeZone: timezone)
                                                .year(.padded(6))
                                                .month(.wide)) ==
                       dateFormatter.string(from: referenceDate))


    }

    func _verify(_ style: Date.FormatStyle, expectedFormat: String, locale: Locale, sourceLocation: SourceLocation = #_sourceLocation) {
        var style = style
        let timeZone = TimeZone(secondsFromGMT: -3600)!
        style.timeZone = timeZone
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = expectedFormat
        #expect(referenceDate.formatted(style.locale(locale)) == dateFormatter.string(from: referenceDate), sourceLocation: sourceLocation)
    }

    @Test func hourSymbols() {

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

// MARK: DiscreteFormatStyle conformance test

@Suite("Date Style Discrete Conformance")
private struct TestDateStyleDiscreteConformance {
    let enUSLocale = Locale(identifier: "en_US")
    var calendar = Calendar(identifier: .gregorian)

    init() {
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
    }

    func date(_ string: String) -> Date {
        try! Date.ISO8601FormatStyle(dateSeparator: .dash, dateTimeSeparator: .space, timeZoneSeparator: .omitted, timeZone: .gmt).locale(enUSLocale).parse(string)
    }

    @Test func basics() throws {
        let style = Date.FormatStyle(date: .complete, time: .complete)
        let date = date("2021-05-05 16:00:00Z")

        #expect(style.discreteInput(after: date + 1) == (date + 2))
        #expect(style.discreteInput(before: date + 1) == (date + 1).nextDown)
        #expect(style.discreteInput(after: date + 0.5) == (date + 1))
        #expect(style.discreteInput(before: date + 0.5) == (date + 0).nextDown)
        #expect(style.discreteInput(after: date + 0) == (date + 1))
        #expect(style.discreteInput(before: date + 0) == (date + 0).nextDown)
        #expect(style.discreteInput(after: date + -0.5) == (date + 0))
        #expect(style.discreteInput(before: date + -0.5) == (date + -1).nextDown)
        #expect(style.discreteInput(after: date + -1) == (date + 0))
        #expect(style.discreteInput(before: date + -1) == (date + -1).nextDown)
    }

    @Test func evaluation() {
        func assertEvaluation(of style: Date.FormatStyle,
                              in range: ClosedRange<Date>,
                              includes expectedExcerpts: [String]...,
                              sourceLocation: SourceLocation = #_sourceLocation) {
            var style = style.locale(Locale(identifier: "en_US"))
            style.calendar = calendar
            style.timeZone = calendar.timeZone

            verify(
                sequence: style.evaluate(from: range.lowerBound, to: range.upperBound) { prev, bound in
                    if style.format(prev) == style.format(bound) {
                        return bound + 0.00001
                    } else {
                        return bound
                    }
                }.lazy.map(\.output),
                contains: expectedExcerpts,
                "(lowerbound to upperbound)",
                sourceLocation: sourceLocation)

            verify(
                sequence: style.evaluate(from: range.upperBound, to: range.lowerBound) { prev, bound in
                    if style.format(prev) == style.format(bound) {
                        return bound - 0.00001
                    } else {
                        return bound
                    }
                }.lazy.map(\.output),
                contains: expectedExcerpts
                    .reversed()
                    .map { $0.reversed() },
                "(upperbound to lowerbound)",
                sourceLocation: sourceLocation)
        }

        let now = date("2023-05-15 08:47:20Z")

        assertEvaluation(
            of: .init(date: .complete, time: .complete).secondFraction(.fractional(2)),
            in: (now - 0.1)...(now + 0.1),
            includes: [
                "Monday, May 15, 2023 at 8:47:19.90 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.91 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.92 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.93 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.94 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.95 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.96 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.97 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.98 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.99 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.00 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.01 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.02 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.03 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.04 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.05 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.06 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.07 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.08 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.09 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.10 AM GMT",
            ])

        assertEvaluation(
            of: .init(date: .complete, time: .complete),
            in: (now - 3)...(now + 3),
            includes: [
                "Monday, May 15, 2023 at 8:47:17 AM GMT",
                "Monday, May 15, 2023 at 8:47:18 AM GMT",
                "Monday, May 15, 2023 at 8:47:19 AM GMT",
                "Monday, May 15, 2023 at 8:47:20 AM GMT",
                "Monday, May 15, 2023 at 8:47:21 AM GMT",
                "Monday, May 15, 2023 at 8:47:22 AM GMT",
                "Monday, May 15, 2023 at 8:47:23 AM GMT",
            ])

        assertEvaluation(
            of: .init().hour(.twoDigits(amPM: .abbreviated)).minute(),
            in: (now - 180)...(now + 180),
            includes: [
                "08:44 AM",
                "08:45 AM",
                "08:46 AM",
                "08:47 AM",
                "08:48 AM",
                "08:49 AM",
                "08:50 AM",
            ])

        assertEvaluation(
            of: .init(date: .omitted, time: .omitted).year().month(),
            in: (now - 8 * 31 * 24 * 3600)...(now + 8 * 31 * 24 * 3600),
            includes: [
                "Sep 2022",
                "Oct 2022",
                "Nov 2022",
                "Dec 2022",
                "Jan 2023",
                "Feb 2023",
                "Mar 2023",
                "Apr 2023",
                "May 2023",
                "Jun 2023",
                "Jul 2023",
                "Aug 2023",
                "Sep 2023",
                "Oct 2023",
                "Nov 2023",
                "Dec 2023",
                "Jan 2024",
            ])

        assertEvaluation(
            of: .init(date: .omitted, time: .omitted).year().month().week(),
            in: (now - 8 * 31 * 24 * 3600)...(now - 4 * 31 * 24 * 3600),
            includes: [
                "Sep 2022 (week: 37)",
                "Sep 2022 (week: 38)",
                "Sep 2022 (week: 39)",
                "Sep 2022 (week: 40)",
                "Oct 2022 (week: 40)",
                "Oct 2022 (week: 41)",
                "Oct 2022 (week: 42)",
                "Oct 2022 (week: 43)",
                "Oct 2022 (week: 44)",
                "Oct 2022 (week: 45)",
                "Nov 2022 (week: 45)",
                "Nov 2022 (week: 46)",
                "Nov 2022 (week: 47)",
                "Nov 2022 (week: 48)",
                "Nov 2022 (week: 49)",
                "Dec 2022 (week: 49)",
                "Dec 2022 (week: 50)",
                "Dec 2022 (week: 51)",
                "Dec 2022 (week: 52)",
                "Dec 2022 (week: 53)",
                "Jan 2023 (week: 1)",
                "Jan 2023 (week: 2)",
            ])

        assertEvaluation(
            of: .init(date: .omitted, time: .omitted).year().month().week().era(),
            in: (now - 8 * 31 * 24 * 3600)...(now - 4 * 31 * 24 * 3600),
            includes: [
                "Sep 2022 AD (week: 37)",
                "Sep 2022 AD (week: 38)",
                "Sep 2022 AD (week: 39)",
                "Sep 2022 AD (week: 40)",
                "Oct 2022 AD (week: 40)",
                "Oct 2022 AD (week: 41)",
                "Oct 2022 AD (week: 42)",
                "Oct 2022 AD (week: 43)",
                "Oct 2022 AD (week: 44)",
                "Oct 2022 AD (week: 45)",
                "Nov 2022 AD (week: 45)",
                "Nov 2022 AD (week: 46)",
                "Nov 2022 AD (week: 47)",
                "Nov 2022 AD (week: 48)",
                "Nov 2022 AD (week: 49)",
                "Dec 2022 AD (week: 49)",
                "Dec 2022 AD (week: 50)",
                "Dec 2022 AD (week: 51)",
                "Dec 2022 AD (week: 52)",
                "Dec 2022 AD (week: 53)",
                "Jan 2023 AD (week: 1)",
                "Jan 2023 AD (week: 2)",
            ])
    }

    @Test func regressions() throws {
        var style: Date.FormatStyle

        style = .init(date: .complete, time: .complete).secondFraction(.fractional(2))
        style.timeZone = .gmt
        #expect(try #require(style.discreteInput(before: Date(timeIntervalSinceReferenceDate: 15538915.899999967))) < Date(timeIntervalSinceReferenceDate: 15538915.899999967))

        style = .init(date: .complete, time: .complete).secondFraction(.fractional(2))
        style.timeZone = .gmt
        #expect(style.input(after: Date(timeIntervalSinceReferenceDate: 1205656112.7299998)) != nil)
    }

    @Test(arguments: [
        Date.FormatStyle(date: .complete, time: .complete).secondFraction(.fractional(3)),
        Date.FormatStyle(date: .complete, time: .complete).secondFraction(.fractional(2)),
        Date.FormatStyle(date: .complete, time: .complete),
        Date.FormatStyle().hour(.twoDigits(amPM: .abbreviated)).minute(),
        Date.FormatStyle(date: .omitted, time: .omitted).year().month(),
        Date.FormatStyle(date: .omitted, time: .omitted).year().month().era()
    ])
    func randomSamples(style: Date.FormatStyle) throws {
        var style = style
        style.locale = Locale(identifier: "en_US")
        style.calendar = Calendar(identifier: .gregorian)
        style.timeZone = .gmt
        try verifyDiscreteFormatStyleConformance(style, samples: 100)
    }
}

@Suite("Verbatime Date.FormatStyle Discrete Conformance")
private struct TestDateVerbatimStyleDiscreteConformance {
    let enUSLocale = Locale(identifier: "en_US")
    var calendar = Calendar(identifier: .gregorian)

    init() {
        calendar.timeZone = TimeZone(abbreviation: "GMT")!
    }

    func date(_ string: String) -> Date {
        try! Date.ISO8601FormatStyle(dateSeparator: .dash, dateTimeSeparator: .space, timeZoneSeparator: .omitted, timeZone: .gmt).locale(enUSLocale).parse(string)
    }

    @Test func examples() throws {
        let style = Date.VerbatimFormatStyle(
            format: "\(year: .extended())-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .oneBased)):\(minute: .twoDigits):\(second: .twoDigits)",
            timeZone: Calendar.current.timeZone, calendar: .current)
        let date = date("2021-05-05 16:00:00Z")

        #expect(style.discreteInput(after: date.addingTimeInterval(1)) == date.addingTimeInterval(2))
        #expect(style.discreteInput(before: date.addingTimeInterval(1)) == date.addingTimeInterval(1).nextDown)
        #expect(style.discreteInput(after: date.addingTimeInterval(0.5)) == date.addingTimeInterval(1))
        #expect(style.discreteInput(before: date.addingTimeInterval(0.5)) == date.addingTimeInterval(0).nextDown)
        #expect(style.discreteInput(after: date.addingTimeInterval(0)) == date.addingTimeInterval(1))
        #expect(style.discreteInput(before: date.addingTimeInterval(0)) == date.addingTimeInterval(0).nextDown)
        #expect(style.discreteInput(after: date.addingTimeInterval(-0.5)) == date.addingTimeInterval(0))
        #expect(style.discreteInput(before: date.addingTimeInterval(-0.5)) == date.addingTimeInterval(-1).nextDown)
        #expect(style.discreteInput(after: date.addingTimeInterval(-1)) == date.addingTimeInterval(0))
        #expect(style.discreteInput(before: date.addingTimeInterval(-1)) == date.addingTimeInterval(-1).nextDown)
    }

    @Test func counting() {
        func assertEvaluation(of style: Date.VerbatimFormatStyle,
                              in range: ClosedRange<Date>,
                              includes expectedExcerpts: [String]...,
                              sourceLocation: SourceLocation = #_sourceLocation) {
            var style = style.locale(enUSLocale)
            style.calendar = calendar
            style.timeZone = calendar.timeZone

            verify(
                sequence: style.evaluate(from: range.lowerBound, to: range.upperBound) { prev, bound in
                    if style.format(prev) == style.format(bound) {
                        return bound + 0.00001
                    } else {
                        return bound
                    }
                }.lazy.map(\.output),
                contains: expectedExcerpts,
                "(lowerbound to upperbound)",
                sourceLocation: sourceLocation)

            verify(
                sequence: style.evaluate(from: range.upperBound, to: range.lowerBound) { prev, bound in
                    if style.format(prev) == style.format(bound) {
                        return bound - 0.00001
                    } else {
                        return bound
                    }
                }.lazy.map(\.output),
                contains: expectedExcerpts
                    .reversed()
                    .map { $0.reversed() },
                "(upperbound to lowerbound)",
                sourceLocation: sourceLocation)
        }

        let now = date("2023-05-15 08:47:20Z")

        assertEvaluation(
            of: .init(format: "\(weekday: .wide), \(month: .wide) \(day: .defaultDigits), \(year: .extended()) at \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(2)) \(dayPeriod: .standard(.abbreviated)) \(timeZone: .genericName(.short))", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-0.1)...now.addingTimeInterval(0.1),
            includes: [
                "Monday, May 15, 2023 at 8:47:19.90 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.91 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.92 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.93 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.94 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.95 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.96 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.97 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.98 AM GMT",
                "Monday, May 15, 2023 at 8:47:19.99 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.00 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.01 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.02 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.03 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.04 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.05 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.06 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.07 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.08 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.09 AM GMT",
                "Monday, May 15, 2023 at 8:47:20.10 AM GMT",
            ])

        assertEvaluation(
            of: .init(format: "'\(weekday: .wide),' '\(month: .wide)'' ss\(day: .defaultDigits), \(year: .extended()) at \(hour: .defaultDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits):\(second: .twoDigits) \(dayPeriod: .standard(.abbreviated)) \(timeZone: .genericName(.short))", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-3)...now.addingTimeInterval(3),
            includes: [
                "'Monday,' 'May'' ss15, 2023 at 8:47:17 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:18 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:19 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:20 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:21 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:22 AM GMT",
                "'Monday,' 'May'' ss15, 2023 at 8:47:23 AM GMT",
            ])

        assertEvaluation(
            of: .init(format: "'\(hour: .twoDigits(clock: .twelveHour, hourCycle: .oneBased)):\(minute: .twoDigits) ss \(dayPeriod: .standard(.abbreviated))", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-180)...now.addingTimeInterval(180),
            includes: [
                "'08:44 ss AM",
                "'08:45 ss AM",
                "'08:46 ss AM",
                "'08:47 ss AM",
                "'08:48 ss AM",
                "'08:49 ss AM",
                "'08:50 ss AM",
            ])

        assertEvaluation(
            of: .init(format: "\(month: .abbreviated)''''\(year: .extended())", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(8 * 31 * 24 * 3600),
            includes: [
                "Sep''''2022",
                "Oct''''2022",
                "Nov''''2022",
                "Dec''''2022",
                "Jan''''2023",
                "Feb''''2023",
                "Mar''''2023",
                "Apr''''2023",
                "May''''2023",
                "Jun''''2023",
                "Jul''''2023",
                "Aug''''2023",
                "Sep''''2023",
                "Oct''''2023",
                "Nov''''2023",
                "Dec''''2023",
                "Jan''''2024",
            ])

        assertEvaluation(
            of: .init(format: "\(month: .abbreviated) \(year: .extended())'ss'(week: \(week: .defaultDigits))", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(-4 * 31 * 24 * 3600),
            includes: [
                "Sep 2022'ss'(week: 37)",
                "Sep 2022'ss'(week: 38)",
                "Sep 2022'ss'(week: 39)",
                "Sep 2022'ss'(week: 40)",
                "Oct 2022'ss'(week: 40)",
                "Oct 2022'ss'(week: 41)",
                "Oct 2022'ss'(week: 42)",
                "Oct 2022'ss'(week: 43)",
                "Oct 2022'ss'(week: 44)",
                "Oct 2022'ss'(week: 45)",
                "Nov 2022'ss'(week: 45)",
                "Nov 2022'ss'(week: 46)",
                "Nov 2022'ss'(week: 47)",
                "Nov 2022'ss'(week: 48)",
                "Nov 2022'ss'(week: 49)",
                "Dec 2022'ss'(week: 49)",
                "Dec 2022'ss'(week: 50)",
                "Dec 2022'ss'(week: 51)",
                "Dec 2022'ss'(week: 52)",
                "Dec 2022'ss'(week: 53)",
                "Jan 2023'ss'(week: 1)",
                "Jan 2023'ss'(week: 2)",
            ])

        assertEvaluation(
            of: Date.VerbatimFormatStyle(format: "\(month: .abbreviated)''ss''' \(year: .extended()) \(era: .abbreviated) (week: \(week: .defaultDigits))", timeZone: calendar.timeZone, calendar: calendar),
            in: now.addingTimeInterval(-8 * 31 * 24 * 3600)...now.addingTimeInterval(-4 * 31 * 24 * 3600),
            includes: [
                "Sep''ss''' 2022 AD (week: 37)",
                "Sep''ss''' 2022 AD (week: 38)",
                "Sep''ss''' 2022 AD (week: 39)",
                "Sep''ss''' 2022 AD (week: 40)",
                "Oct''ss''' 2022 AD (week: 40)",
                "Oct''ss''' 2022 AD (week: 41)",
                "Oct''ss''' 2022 AD (week: 42)",
                "Oct''ss''' 2022 AD (week: 43)",
                "Oct''ss''' 2022 AD (week: 44)",
                "Oct''ss''' 2022 AD (week: 45)",
                "Nov''ss''' 2022 AD (week: 45)",
                "Nov''ss''' 2022 AD (week: 46)",
                "Nov''ss''' 2022 AD (week: 47)",
                "Nov''ss''' 2022 AD (week: 48)",
                "Nov''ss''' 2022 AD (week: 49)",
                "Dec''ss''' 2022 AD (week: 49)",
                "Dec''ss''' 2022 AD (week: 50)",
                "Dec''ss''' 2022 AD (week: 51)",
                "Dec''ss''' 2022 AD (week: 52)",
                "Dec''ss''' 2022 AD (week: 53)",
                "Jan''ss''' 2023 AD (week: 1)",
                "Jan''ss''' 2023 AD (week: 2)",
            ])
    }
}
