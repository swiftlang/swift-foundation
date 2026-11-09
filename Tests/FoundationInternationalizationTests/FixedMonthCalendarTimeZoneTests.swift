//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
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
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif

/// Tests that need a named time zone or the locale data, which the FoundationEssentials tests cannot load.
@Suite("Fixed Month Calendar Time Zones")
private struct FixedMonthCalendarTimeZoneTests {

    private static func date(rataDie: Int, hour: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + Double(hour) * 3600.0)
    }

    // The day in the era counts days, not seconds. At the start of each era New York used local mean time, which is 3362 seconds from the offset of July 2024.
    @Test(arguments: [(Calendar.Identifier.coptic, 103_605), (.ethiopicAmeteMihret, 2_796), (.ethiopicAmeteAlem, -2_006_079), (.persian, 226_895), (.indian, 28_570)])
    func dayInEraAcrossTimeZoneOffsets(_ identifier: Calendar.Identifier, _ firstDay: Int) throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: newYork, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let rataDie = _CalendarAstronomy.gregorianRataDie(2024, 7, 1)
        // New York is UTC-4 on this date, so 04:30 UTC is 00:30 local, and 03:30 UTC is 23:30 local on the day before.
        let earlyMorning = Self.date(rataDie: rataDie, hour: 4) + 1800
        let lateEvening = Self.date(rataDie: rataDie, hour: 3) + 1800
        #expect(calendar.ordinality(of: .day, in: .era, for: earlyMorning) == rataDie - firstDay + 1)
        #expect(calendar.ordinality(of: .day, in: .era, for: lateEvening) == rataDie - firstDay)
    }

    // The day in the quarter counts elapsed 24 hour blocks from its start, so a change of the Los Angeles offset inside the quarter moves it by one day. The values come from the system calendar.
    @Test(arguments: [(Calendar.Identifier.coptic, -1_427_474_467.0, 27), (.ethiopicAmeteMihret, -1_427_474_467.0, 27), (.indian, -1_185_207_389.0, 82), (.persian, -1_185_207_389.0, 83)])
    func dayInQuarterCountsElapsedDays(_ identifier: Calendar.Identifier, _ time: Double, _ expected: Int) throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: losAngeles, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        #expect(calendar.ordinality(of: .day, in: .quarter, for: Date(timeIntervalSinceReferenceDate: time)) == expected)
    }

    // Clocks skipped local midnight on the first day of these years, so a month starts inside a day. The ranges must still come out and must not crash.
    @Test(arguments: [
        (Calendar.Identifier.indian, "Asia/Tehran", 1977, 3, 22, 12, 63),
        (.indian, "Asia/Tehran", 1977, 3, 22, 0, 63),
        (.persian, "Asia/Macau", 1954, 3, 21, 12, 64),
        (.persian, "Asia/Macau", 1954, 3, 21, 1, 64),
        (.persian, "Europe/Moscow", 1921, 3, 21, 12, 63),
    ] as [(Calendar.Identifier, String, Int, Int, Int, Int, Int)])
    func rangesAcrossSkippedMidnight(_ identifier: Calendar.Identifier, _ zone: String, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ weeksOfMonthEnd: Int) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let date = try #require(gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        #expect(calendar.range(of: .weekOfMonth, in: .year, for: date) == 1..<weeksOfMonthEnd)
        #expect(calendar.range(of: .weekOfYear, in: .month, for: date) == 1..<6)
        #expect(calendar.range(of: .weekOfYear, in: .yearForWeekOfYear, for: date) == 1..<53)
    }

    // Adding a day keeps the wall clock time. When the new day skips that time, the result lands after the gap, as in the Gregorian calendar.
    @Test(arguments: [Calendar.Identifier.coptic, .chinese], [
        ("America/Sao_Paulo", 529_642_800.0, 529_729_200.0),
        ("America/New_York", 510_908_400.0, 510_994_800.0),
        ("Australia/Lord_Howe", 528_391_800.0, 528_478_200.0),
        ("Asia/Tehran", 511_734_600.0, 511_821_000.0),
        ("Europe/London", 512_096_400.0, 512_182_800.0),
    ] as [(String, Double, Double)])
    func addDayAcrossSkippedTime(_ identifier: Calendar.Identifier, _ row: (zone: String, start: Double, expected: Double)) throws {
        let timeZone = try #require(TimeZone(identifier: row.zone))
        let inner: any _CalendarProtocol = identifier == .coptic
            ? _CalendarFixedMonth(identifier: identifier, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
            : _CalendarChinese(identifier: identifier, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        let result = Calendar(inner: inner).date(byAdding: DateComponents(day: 1), to: Date(timeIntervalSinceReferenceDate: row.start))
        #expect(result == Date(timeIntervalSinceReferenceDate: row.expected), "\(row.zone)")
    }

    // Rolling the hour or the minute forward past its limit counts from the first instant of the day or the hour, so a change of the offset on the way does not move the result.
    @Test(arguments: [
        ("America/Sao_Paulo", 509_164_200.0, 0, 30, 509_158_800.0),
        ("America/New_York", 531_556_200.0, 0, 30, 531_550_800.0),
        ("Australia/Lord_Howe", 512_751_600.0, 0, 30, 512_748_000.0),
        ("Asia/Tehran", 527_716_800.0, 0, 30, 527_711_400.0),
        ("Europe/London", 530_933_400.0, 0, 30, 530_928_000.0),
        ("Asia/Tehran", 511_819_200.0, 1, 0, 511_736_400.0),
        ("America/New_York", 542_529_000.0, 1, 0, 542_532_600.0),
        ("America/New_York", 563_088_600.0, 1, 0, 563_092_200.0),
        ("Australia/Lord_Howe", 528_562_800.0, 5, 0, 528_580_800.0),
    ] as [(String, Double, Int, Int, Double)])
    func rollTimeAcrossOffsetChange(_ zone: String, _ start: Double, _ hours: Int, _ minutes: Int, _ expected: Double) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: .coptic, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        var amount = DateComponents()
        if hours != 0 { amount.hour = hours } else { amount.minute = minutes }
        let result = calendar.date(byAdding: amount, to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected), "\(zone)")
    }

    // Rolls of the day, the day of the year, the weekday and the weekday ordinal near a change of the offset.
    // The day keeps the wall clock time, and the others count elapsed days. A repeated time is the first one when moving forward.
    @Test(arguments: [
        ("America/New_York", 562_998_600.0, "day", -1, 562_912_200.0),
        ("America/New_York", 531_639_000.0, "day", -1, 531_549_000.0),
        ("Europe/London", 530_845_200.0, "dayOfYear", 1, 530_928_000.0),
        ("America/Sao_Paulo", 509_157_000.0, "dayOfYear", 1, 509_243_400.0),
        ("Asia/Tehran", 527_628_600.0, "weekday", 1, 527_711_400.0),
        ("America/New_York", 542_442_600.0, "weekday", -3, 542_788_200.0),
        ("Australia/Lord_Howe", 512_665_200.0, "dayOfYear", 1, 512_749_800.0),
        ("America/New_York", 563_009_400.0, "weekdayOrdinal", 1, 561_195_000.0),
        ("America/Sao_Paulo", 540_613_800.0, "weekdayOrdinal", 1, 541_218_600.0),
    ] as [(String, Double, String, Int, Double)])
    func rollDaysAcrossOffsetChange(_ zone: String, _ start: Double, _ field: String, _ amount: Int, _ expected: Double) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: .coptic, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        var components = DateComponents()
        switch field {
        case "day": components.day = amount
        case "dayOfYear": components.dayOfYear = amount
        case "weekday": components.weekday = amount
        default: components.weekdayOrdinal = amount
        }
        let result = calendar.date(byAdding: components, to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected), "\(zone) \(field)")
    }

    // Moving back by a year or a month into a repeated hour gives the later time. The cases are moves that landed on the wrong one of the two times.
    @Test(arguments: [
        ("America/New_York", 502_698_600.0, "month", -1, false, 500_106_600.0),
        ("America/New_York", 502_698_600.0, "month", -1, true, 500_106_600.0),
        ("America/New_York", 531_642_600.0, "year", -1, false, 500_106_600.0),
        ("America/New_York", 531_642_600.0, "month", -13, false, 500_106_600.0),
        ("America/New_York", 531_642_600.0, "year", -1, true, 500_106_600.0),
        ("Europe/London", 498_961_800.0, "year", -1, false, 467_429_400.0),
        ("Europe/London", 498_961_800.0, "month", -13, false, 467_429_400.0),
        ("Europe/London", 498_961_800.0, "year", -1, true, 467_429_400.0),
        ("America/Sao_Paulo", 509_250_600.0, "year", -1, false, 477_714_600.0),
    ] as [(String, Double, String, Int, Bool, Double)])
    func moveBackIntoRepeatedHour(_ zone: String, _ start: Double, _ field: String, _ amount: Int, _ wrapping: Bool, _ expected: Double) throws {
        let timeZone = try #require(TimeZone(identifier: zone))
        let calendar = Calendar(inner: _CalendarFixedMonth(identifier: .coptic, timeZone: timeZone, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        var components = DateComponents()
        if field == "year" { components.year = amount } else { components.month = amount }
        let result = calendar.date(byAdding: components, to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: wrapping)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected), "\(zone) \(field) \(amount)")
    }

    // Setting the first weekday and setting it back gives a calendar that equals one that never set it, and the two have the same hash.
    @Test(arguments: [Calendar.Identifier.coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .persian, .indian])
    func settingTheFirstWeekdayBackKeepsTheHash(_ identifier: Calendar.Identifier) {
        var changed = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: .gmt, locale: Locale(identifier: "en_US"), firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let untouched = changed
        changed.firstWeekday = 2
        changed.firstWeekday = 1
        #expect(changed == untouched)
        #expect(changed.hashValue == untouched.hashValue)
    }

    // The formatted text and the fields of a date name the same day. In the package, the formatter shows Gregorian text for Amete Alem and has no Vietnamese, so `Calendar` keeps the old path for them.
    @Test(arguments: [Calendar.Identifier.coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .persian, .indian, .dangi, .vietnamese])
    func textAndFieldsAgree(_ identifier: Calendar.Identifier) {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US")
        let date = Date(timeIntervalSinceReferenceDate: 682_898_558)
        let fields = calendar.dateComponents([.month, .day], from: date)
        let text = date.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: .gmt))
        #expect(text.hasPrefix("\(fields.month ?? 0)/\(fields.day ?? 0)/"), "\(identifier): fields \(fields.month ?? 0)/\(fields.day ?? 0), text \(text)")
    }
}
