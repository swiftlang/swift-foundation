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

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

// Dangi and Vietnamese use the Chinese rules with another day boundary. Every expected value is a fixed value.
@Suite("Chinese Family Calendars")
private struct ChineseFamilyCalendarTests {

    private static let identifiers: [Calendar.Identifier] = [.chinese, .dangi, .vietnamese]

    private static func calendar(_ identifier: Calendar.Identifier, firstWeekday: Int = 1, minimumDays: Int = 1) -> _CalendarChinese {
        _CalendarChinese(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDays, gregorianStartDate: nil)
    }

    private static func variant(_ identifier: Calendar.Identifier) throws -> ChineseCalendarVariant {
        try #require(ChineseCalendarVariant(identifier: identifier))
    }

    private static func date(rataDie: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + Double(hour) * 3600.0)
    }

    private static func date(_ gregorian: (Int, Int, Int), hour: Int = 12) -> Date {
        date(rataDie: _CalendarAstronomy.gregorianRataDie(gregorian.0, gregorian.1, gregorian.2), hour: hour)
    }

    // MARK: Dates

    @Test(arguments: lunarDates)
    func knownDate(_ lunar: LunarDate) {
        let calendar = Self.calendar(lunar.identifier)
        let date = Self.date(lunar.gregorian)
        let components = calendar.dateComponents([.era, .year, .month, .day, .isLeapMonth, .dayOfYear, .weekOfYear, .yearForWeekOfYear], from: date)
        #expect(components.era == lunar.era, "\(lunar)")
        #expect(components.year == lunar.year, "\(lunar)")
        #expect(components.month == lunar.month, "\(lunar)")
        #expect(components.isLeapMonth == lunar.isLeapMonth, "\(lunar)")
        #expect(components.day == lunar.day, "\(lunar)")
        #expect(components.dayOfYear == lunar.dayOfYear, "\(lunar)")
        #expect(components.weekOfYear == lunar.weekOfYear, "\(lunar)")
        #expect(components.yearForWeekOfYear == lunar.yearForWeekOfYear, "\(lunar)")
        // The fields name the same instant again, in the field form and in the week form.
        var fields = DateComponents(era: lunar.era, year: lunar.year, month: lunar.month, day: lunar.day, hour: 12)
        fields.isLeapMonth = lunar.isLeapMonth
        #expect(calendar.date(from: fields) == date, "\(lunar)")
        let week = DateComponents(era: lunar.era, hour: 12, weekday: calendar.dateComponents([.weekday], from: date).weekday, weekOfYear: lunar.weekOfYear, yearForWeekOfYear: lunar.yearForWeekOfYear)
        #expect(calendar.date(from: week) == date, "\(lunar)")
    }

    // The first day of each month, including the months where the three calendars give different dates.
    @Test(arguments: monthStarts)
    func monthStart(_ start: MonthStart) {
        let calendar = Self.calendar(start.identifier)
        var fields = DateComponents(era: start.era, year: start.year, month: start.month, day: 1, hour: 12)
        fields.isLeapMonth = start.isLeapMonth
        #expect(calendar.date(from: fields) == Self.date(start.gregorian), "\(start)")
        // The day before is the last day of the month before, which has 29 or 30 days.
        let dayBefore = calendar.dateComponents([.day], from: Self.date(start.gregorian).addingTimeInterval(-86400)).day
        #expect(dayBefore == 29 || dayBefore == 30, "\(start)")
    }

    // Every day in a span of years: the fields of the day name the day again.
    @Test(arguments: identifiers)
    func fieldsRoundTrip(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        var failures: [Int] = []
        for rataDie in _CalendarAstronomy.gregorianRataDie(1990, 1, 1)...(_CalendarAstronomy.gregorianRataDie(2031, 12, 31)) {
            let date = Self.date(rataDie: rataDie)
            let components = calendar.dateComponents([.era, .year, .month, .day, .isLeapMonth, .hour], from: date)
            if calendar.date(from: components) != date { failures.append(rataDie) }
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first: \(failures.prefix(3))")
    }

    // MARK: Year numbers of the week form

    // The Chinese and Vietnamese calendars add 2637 to the related Gregorian year, the Dangi calendar adds 2333.
    @Test(arguments: [(Calendar.Identifier.chinese, 4663), (.dangi, 4359), (.vietnamese, 4663)])
    func weekYearNumber(_ identifier: Calendar.Identifier, _ expected: Int) {
        let calendar = Self.calendar(identifier)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: Self.date((2026, 10, 7)))
        #expect(components.yearForWeekOfYear == expected)
        #expect(calendar.date(from: DateComponents(hour: 12, weekday: components.weekday, weekOfYear: components.weekOfYear, yearForWeekOfYear: expected)) == Self.date((2026, 10, 7)))
    }

    // The days of each year of `.yearForWeekOfYear` follow each other with no gap and no overlap, so the end of one is the start of the next.
    @Test(arguments: identifiers)
    func weekYearsTile(_ identifier: Calendar.Identifier) throws {
        let calendar = Self.calendar(identifier)
        var date = Self.date((2020, 1, 1))
        for _ in 0..<12 {
            let interval = try #require(calendar.dateInterval(of: .yearForWeekOfYear, for: date))
            #expect(interval.start <= date && date < interval.end)
            let next = try #require(calendar.dateInterval(of: .yearForWeekOfYear, for: interval.end + 43_200))
            #expect(next.start == interval.end)
            date = interval.end + 43_200
        }
    }

    // MARK: Ranges

    @Test(arguments: identifiers)
    func ranges(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        #expect(calendar.minimumRange(of: .era) == 1..<83334)
        #expect(calendar.maximumRange(of: .year) == 1..<61)
        #expect(calendar.maximumRange(of: .month) == 1..<13)
        #expect(calendar.minimumRange(of: .day) == 1..<30)
        #expect(calendar.maximumRange(of: .day) == 1..<31)
        #expect(calendar.minimumRange(of: .dayOfYear) == 1..<354)
        #expect(calendar.maximumRange(of: .dayOfYear) == 1..<386)
        #expect(calendar.maximumRange(of: .isLeapMonth) == 0..<2)
    }

    // The ranges of .yearForWeekOfYear are the same for the three calendars. The guards of date from components and of add use the first number past the supported years (49,637 for the extended year).
    @Test(arguments: [(Calendar.Identifier.chinese, 0), (.vietnamese, 0), (.dangi, -304)])
    func weekYearLimits(_ identifier: Calendar.Identifier, _ shift: Int) throws {
        let calendar = Self.calendar(identifier)
        #expect(calendar.minimumRange(of: .yearForWeekOfYear) == -5_000_000..<5_000_001)
        #expect(calendar.maximumRange(of: .yearForWeekOfYear) == -5_000_000..<5_000_001)
        var components = DateComponents()
        components.yearForWeekOfYear = 49_637 + shift
        #expect(calendar.date(from: components) == nil)
        let start = Self.date((2026, 1, 1))
        let weekYear = try #require(calendar.dateComponents([.yearForWeekOfYear], from: start).yearForWeekOfYear)
        var amount = DateComponents()
        amount.yearForWeekOfYear = 49_637 + shift - weekYear
        #expect(calendar.date(byAdding: amount, to: start, wrappingComponents: false) == nil)
    }

    // A count of nanoseconds that does not fit in an Int32 gives the limit, as in the Gregorian calendar.
    @Test(arguments: identifiers)
    func nanosecondDifferenceLimit(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let start = Self.date((2000, 1, 1))
        let end = Self.date((2400, 1, 1))
        #expect(calendar.dateComponents([.nanosecond], from: start, to: end).nanosecond == Int(Int32.max))
        #expect(calendar.dateComponents([.nanosecond], from: end, to: start).nanosecond == Int(Int32.min))
    }

    // A count of days that overflows gives nil. The first value times 7 wraps to 1, so the test needs a 64 bit Int. No field uses Int.max, because DateComponents reads it as no value.
    @Test(.enabled(if: Int.bitWidth == 64), arguments: identifiers)
    func overflowingAdd(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let date = Self.date((2026, 10, 7))
        let wrapsToOne = Int(truncatingIfNeeded: Int64(7_905_747_460_161_236_407))
        #expect(calendar.date(byAdding: DateComponents(weekOfYear: wrapsToOne), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(weekOfMonth: Int.max / 2), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(weekdayOrdinal: wrapsToOne), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(day: .max - 1, weekday: 2), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(day: .max - 1, yearForWeekOfYear: 1), to: date, wrappingComponents: false) == nil)
    }

    private static let extremeFields: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear]
    private static let extremeValues = [Int.min, Int.min + 1, Int.min / 2, -(1 << 40), 1 << 40, Int.max / 2, Int.max - 1]
    private static let extremeInputs = extremeFields.flatMap { field in extremeValues.map { (field: field, value: $0) } }

    // Every field with a value near the limits of Int goes through date(from:), add and roll. The test checks only that none of them traps. Each pair of field and value is its own case.
    @Test(arguments: identifiers, extremeInputs)
    func extremeValuesDoNotTrap(_ identifier: Calendar.Identifier, _ input: (field: Calendar.Component, value: Int)) {
        let calendar = Self.calendar(identifier)
        let starts = [Self.date((2026, 10, 7)), Self.date((1938, 5, 1))]
        var dayOfYearBase = DateComponents(year: 40, month: 1)
        dayOfYearBase.dayOfYear = 1
        let bases = [
            DateComponents(era: 78, year: 40, month: 1, day: 1),
            DateComponents(era: 78, year: 40, month: 1, weekday: 1, weekdayOrdinal: 1),
            DateComponents(year: 40, weekday: 1, weekOfYear: 1),
            DateComponents(year: 40, month: 1, weekday: 1, weekOfMonth: 1),
            DateComponents(weekday: 1, weekOfYear: 1, yearForWeekOfYear: 4700),
            dayOfYearBase,
        ]
        for base in bases {
            var components = base
            components.setValue(input.value, for: input.field)
            _ = calendar.date(from: components)
        }
        var amount = DateComponents()
        amount.setValue(input.value, for: input.field)
        for start in starts {
            _ = calendar.date(byAdding: amount, to: start, wrappingComponents: false)
            _ = calendar.date(byAdding: amount, to: start, wrappingComponents: true)
        }
        // The unchanged form must still give a date, so the test cannot pass by returning nil everywhere.
        #expect(calendar.date(from: bases[0]) != nil)
    }

    // A difference of seconds and nanoseconds rounds the nanoseconds to the nearest one. The truncated value of 0.19999999999999996 seconds would be 199,999,999.
    @Test(arguments: identifiers)
    func secondAndNanosecondDifference(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let first = calendar.dateComponents([.second, .nanosecond], from: start, to: Date(timeIntervalSinceReferenceDate: 1.2))
        #expect(first.second == 1 && first.nanosecond == 200_000_000)
        let second = calendar.dateComponents([.second, .nanosecond], from: start, to: Date(timeIntervalSinceReferenceDate: 10.1))
        #expect(second.second == 10 && second.nanosecond == 100_000_000)
    }

    // A week of the month can be week 0 when the first week needs more than one day, and the limits follow the shortest and the longest month.
    @Test(arguments: identifiers, [(1, 1..<6, 1..<7), (4, 1..<5, 0..<6), (7, 1..<5, 0..<6)])
    func weekOfMonthLimits(_ identifier: Calendar.Identifier, _ expected: (minimumDays: Int, minimum: Range<Int>, maximum: Range<Int>)) {
        let calendar = Self.calendar(identifier, minimumDays: expected.minimumDays)
        #expect(calendar.minimumRange(of: .weekOfMonth) == expected.minimum)
        #expect(calendar.maximumRange(of: .weekOfMonth) == expected.maximum)
    }

    // The week numbers of the year that the days of the month fall in. The date is 2022-08-22 22:02:38 in GMT.
    @Test func weekOfYearInMonthRange() {
        let date = Self.date((2022, 8, 22), hour: 22) + 158
        #expect(Self.calendar(.chinese).range(of: .weekOfYear, in: .month, for: date) == 26..<31)
    }

    // A difference of more than a million days gives the exact count of days.
    @Test(arguments: identifiers)
    func differenceOfManyDays(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let days = _CalendarAstronomy.gregorianRataDie(5000, 1, 1) - _CalendarAstronomy.gregorianRataDie(1000, 1, 1)
        let result = calendar.dateComponents([.day], from: Self.date((1000, 1, 1)), to: Self.date((5000, 1, 1)))
        #expect(days > 1_000_001)
        #expect(result.day == days)
    }

    // Rolling a field wraps it inside the larger field. The date is 2022-08-22 22:02:38 in GMT.
    @Test(arguments: [
        ("hour", 5, 682_830_158.0), ("minute", 45, 682_901_258.0), ("second", 50, 682_898_548.0), ("weekday", 4, 683_244_158.0),
        ("weekdayOrdinal", 2, 681_688_958.0), ("dayOfYear", 100, 691_538_558.0), ("weekOfMonth", 2, 681_084_158.0), ("weekOfYear", 20, 694_994_558.0),
    ] as [(String, Int, Double)])
    func rollWraps(_ field: String, _ amount: Int, _ expected: Double) {
        var components = DateComponents()
        switch field {
        case "hour": components.hour = amount
        case "minute": components.minute = amount
        case "second": components.second = amount
        case "weekday": components.weekday = amount
        case "weekdayOrdinal": components.weekdayOrdinal = amount
        case "dayOfYear": components.dayOfYear = amount
        case "weekOfMonth": components.weekOfMonth = amount
        default: components.weekOfYear = amount
        }
        let result = Self.calendar(.chinese).date(byAdding: components, to: Date(timeIntervalSinceReferenceDate: 682_898_558), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected), "\(field)")
    }

    // Rolling the week of the month counts the first week only when it has the minimum days. The date is 2022-08-22 in GMT.
    @Test(arguments: [(1, 1, 1, 18), (1, 2, 1, 18), (2, 3, 1, 18), (7, 1, 1, 18), (3, 5, 29, 18), (4, 4, 29, 18)])
    func rollWeekOfMonthWithShortFirstWeek(_ firstWeekday: Int, _ minimumDays: Int, _ dayAfterForward: Int, _ dayAfterBackward: Int) {
        let calendar = Self.calendar(.chinese, firstWeekday: firstWeekday, minimumDays: minimumDays)
        let start = Self.date((2022, 8, 22))
        let forward = DateComponents(weekOfMonth: 1)
        let backward = DateComponents(weekOfMonth: -1)
        #expect(calendar.date(byAdding: forward, to: start, wrappingComponents: true).flatMap { calendar.dateComponents([.day], from: $0).day } == dayAfterForward)
        #expect(calendar.date(byAdding: backward, to: start, wrappingComponents: true).flatMap { calendar.dateComponents([.day], from: $0).day } == dayAfterBackward)
    }

    // Each unit of a difference is the largest count that does not pass the end date, so the last step of the search matters. The three calendars give the same values.
    @Test(arguments: identifiers, [
        ((2000, 1, 1), (2026, 10, 12), 26, 9, 7, 331),
        ((2022, 8, 22), (2022, 12, 31), 0, 4, 13, 4),
        ((2011, 2, 3), (2023, 11, 30), 12, 10, 17, 158),
    ] as [((Int, Int, Int), (Int, Int, Int), Int, Int, Int, Int)])
    func differenceInYearsMonthsAndDays(_ identifier: Calendar.Identifier, _ expected: (start: (Int, Int, Int), end: (Int, Int, Int), years: Int, months: Int, days: Int, totalMonths: Int)) {
        let calendar = Self.calendar(identifier)
        let result = calendar.dateComponents([.year, .month, .day], from: Self.date(expected.start), to: Self.date(expected.end))
        #expect(result.year == expected.years)
        #expect(result.month == expected.months)
        #expect(result.day == expected.days)
        #expect(calendar.dateComponents([.month], from: Self.date(expected.start), to: Self.date(expected.end)).month == expected.totalMonths)
    }

    // Dates by weekday and by week. Cycle 78, year 39, GMT.
    @Test(arguments: [
        (1, nil, nil, 2, 3, nil, 665_971_200.0), (7, nil, nil, 5, 2, nil, 682_819_200.0),
        (1, 2, 4, nil, nil, nil, 666_057_600.0), (1, -1, 6, nil, nil, nil, 667_440_000.0), (12, 4, 2, nil, nil, nil, 695_520_000.0),
        (nil, nil, nil, nil, nil, 100, 673_920_000.0), (nil, nil, nil, nil, nil, 354, 695_865_600.0),
    ] as [(Int?, Int?, Int?, Int?, Int?, Int?, Double)])
    func dateFromWeekForms(_ month: Int?, _ ordinal: Int?, _ ordinalWeekday: Int?, _ weekOfMonth: Int?, _ weekday: Int?, _ dayOfYear: Int?, _ expected: Double) {
        var components = DateComponents(era: 78, year: 39, month: month, weekday: ordinalWeekday ?? weekday, weekdayOrdinal: ordinal, weekOfMonth: weekOfMonth)
        components.dayOfYear = dayOfYear
        #expect(Self.calendar(.chinese).date(from: components) == Date(timeIntervalSinceReferenceDate: expected))
    }

    // The forms by day of the year and by week of the year ignore the month, even a month far outside 1...12. Cycle 78, year 40, GMT.
    @Test(arguments: identifiers, [-11, 0, 1, 12, 13, 14, 25, 1_000_001, 100_000_000])
    func monthDoesNotMoveTheYearInYearForms(_ identifier: Calendar.Identifier, _ month: Int) {
        let calendar = Self.calendar(identifier)
        var firstDay = DateComponents(era: 78, year: 40, month: month)
        firstDay.dayOfYear = 1
        var hundredthDay = DateComponents(era: 78, year: 40, month: month)
        hundredthDay.dayOfYear = 100
        let week = DateComponents(era: 78, year: 40, month: month, weekday: 1, weekOfYear: 5)
        #expect(calendar.date(from: firstDay) == Date(timeIntervalSinceReferenceDate: 696_038_400))
        #expect(calendar.date(from: hundredthDay) == Date(timeIntervalSinceReferenceDate: 704_592_000))
        #expect(calendar.date(from: week) == Date(timeIntervalSinceReferenceDate: 698_457_600))
    }

    // The ordinality of a time unit inside a larger time unit. The date is 700,000,000.25 seconds after the reference date, in GMT.
    @Test(arguments: identifiers, [
        (Calendar.Component.second, Calendar.Component.hour, Int(exactly: Int64(1_601))),
        (.nanosecond, .hour, Int(exactly: Int64(1_600_250_000_001))),
        (.nanosecond, .minute, Int(exactly: Int64(40_250_000_001))),
        (.nanosecond, .day, Int(exactly: Int64(73_600_250_000_001))),
    ])
    func timeUnitOrdinality(_ identifier: Calendar.Identifier, _ expected: (smaller: Calendar.Component, larger: Calendar.Component, ordinality: Int?)) {
        let date = Date(timeIntervalSinceReferenceDate: 700_000_000.25)
        #expect(Self.calendar(identifier).ordinality(of: expected.smaller, in: expected.larger, for: date) == expected.ordinality, "\(expected.smaller) in \(expected.larger)")
    }

    // A missing year means year 1. Cycle 78, GMT.
    @Test(arguments: identifiers, [
        (DateComponents(era: 78), -533_779_200.0), (DateComponents(era: 78, month: 3, day: 5), -528_336_000.0), (DateComponents(era: 78, day: 5), -533_433_600.0),
        (DateComponents(era: 78, hour: 7), -533_754_000.0), (DateComponents(era: 78, weekday: 2), -533_779_200.0),
    ])
    func dateFromWithoutYear(_ identifier: Calendar.Identifier, _ row: (components: DateComponents, expected: Double)) {
        #expect(Self.calendar(identifier).date(from: row.components) == Date(timeIntervalSinceReferenceDate: row.expected))
    }

    // A nanosecond has no range inside a nanosecond.
    @Test(arguments: identifiers)
    func nanosecondHasNoRangeInNanosecond(_ identifier: Calendar.Identifier) {
        #expect(Self.calendar(identifier).range(of: .nanosecond, in: .nanosecond, for: Date(timeIntervalSinceReferenceDate: 0)) == nil)
    }

    // Ordinality in the era and in `.yearForWeekOfYear`. The date is -2,471,334,945 seconds from the reference date, in GMT. The values come from the system calendar.
    @Test(arguments: identifiers, [
        (Calendar.Component.day, Calendar.Component.weekOfYear, 7), (.year, .era, 59), (.month, .era, 725), (.day, .era, 21_398),
        (.weekdayOrdinal, .year, 33), (.weekOfYear, .yearForWeekOfYear, 33), (.day, .yearForWeekOfYear, 231),
    ])
    func ordinalityInEraAndWeekYear(_ identifier: Calendar.Identifier, _ row: (smaller: Calendar.Component, larger: Calendar.Component, expected: Int)) {
        let date = Date(timeIntervalSinceReferenceDate: -2_471_334_945)
        #expect(Self.calendar(identifier).ordinality(of: row.smaller, in: row.larger, for: date) == row.expected, "\(row.smaller) in \(row.larger)")
    }

    // Ranges in the era and in the year. The date and the source of the values are as above.
    @Test(arguments: identifiers, [
        (Calendar.Component.year, Calendar.Component.era, 1..<61), (.month, .era, 1..<13), (.day, .era, 1..<31), (.weekOfMonth, .year, 1..<67), (.weekdayOrdinal, .year, 1..<66),
    ])
    func rangeInEraAndYear(_ identifier: Calendar.Identifier, _ row: (smaller: Calendar.Component, larger: Calendar.Component, expected: Range<Int>)) {
        let date = Date(timeIntervalSinceReferenceDate: -2_471_334_945)
        #expect(Self.calendar(identifier).range(of: row.smaller, in: row.larger, for: date) == row.expected, "\(row.smaller) in \(row.larger)")
    }

    // A time unit counts from the start of any larger unit. The date is 2024-05-20 13:25:07 in GMT. The values come from the system calendar.
    @Test(arguments: identifiers, [
        (Calendar.Component.hour, Calendar.Component.month, 302), (.hour, .year, 2_414), (.hour, .weekOfYear, 38), (.hour, .weekOfMonth, 38), (.hour, .weekday, 14), (.hour, .era, 353_246),
        (.hour, .quarter, 302), (.minute, .month, 18_086), (.minute, .weekday, 806), (.second, .year, 8_688_308), (.nanosecond, .weekday, Int(exactly: Int64(48_307_000_000_001))),
    ] as [(Calendar.Component, Calendar.Component, Int?)])
    func timeUnitInLargerUnit(_ identifier: Calendar.Identifier, _ row: (smaller: Calendar.Component, larger: Calendar.Component, expected: Int?)) {
        let date = Date(timeIntervalSinceReferenceDate: 737_904_307)
        #expect(Self.calendar(identifier).ordinality(of: row.smaller, in: row.larger, for: date) == row.expected, "\(row.smaller) in \(row.larger)")
    }

    // The tables of Dangi and Vietnamese. Dangi month 2 of 1950 starts on 1950-03-19, a day after the Chinese month 2. The Vietnamese leap month 6 of 1979 starts on 1979-07-24 and month 7 on 1979-08-23.
    @Test(arguments: [
        (Calendar.Identifier.dangi, -1_602_849_600.0, 1, 30, false), (.dangi, -1_602_763_200.0, 2, 1, false),
        (.vietnamese, -676_641_600.0, 6, 1, true), (.vietnamese, -674_049_600.0, 7, 1, false),
    ])
    func tableMonthStarts(_ identifier: Calendar.Identifier, _ time: Double, _ month: Int, _ day: Int, _ isLeapMonth: Bool) {
        let components = Self.calendar(identifier).dateComponents([.month, .day, .isLeapMonth], from: Date(timeIntervalSinceReferenceDate: time))
        #expect([components.month, components.day] == [month, day])
        #expect(components.isLeapMonth == isLeapMonth)
    }

    // Adding a negative number of months. The starts are noon in GMT.
    @Test(arguments: [
        (Calendar.Identifier.chinese, 706_708_800.0, -1, 704_203_200.0), (.chinese, 706_708_800.0, -3, 699_105_600.0), (.chinese, 732_196_800.0, -14, 696_513_600.0),
        (.dangi, 706_708_800.0, -1, 704_116_800.0), (.vietnamese, 813_067_200.0, -1, 810_561_600.0),
    ])
    func addNegativeMonths(_ identifier: Calendar.Identifier, _ start: Double, _ months: Int, _ expected: Double) {
        let result = Self.calendar(identifier).date(byAdding: DateComponents(month: months), to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: false)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected))
    }

    // Ordinality of a day and of time units, and the range of the day in the quarter. The date is 781,538,730.25 seconds from the reference date, in GMT.
    @Test(arguments: identifiers, [
        (Calendar.Component.hour, Calendar.Component.day, 15), (.minute, .day, 846), (.second, .day, 50_731), (.day, .year, 252), (.weekday, .year, 36), (.second, .minute, 31),
    ])
    func ordinalityOfDaysAndTimeUnits(_ identifier: Calendar.Identifier, _ row: (smaller: Calendar.Component, larger: Calendar.Component, expected: Int)) {
        let date = Date(timeIntervalSinceReferenceDate: 781_538_730.25)
        #expect(Self.calendar(identifier).ordinality(of: row.smaller, in: row.larger, for: date) == row.expected, "\(row.smaller) in \(row.larger)")
    }

    @Test(arguments: identifiers)
    func dayRangeInQuarter(_ identifier: Calendar.Identifier) {
        #expect(Self.calendar(identifier).range(of: .day, in: .quarter, for: Date(timeIntervalSinceReferenceDate: 781_538_730.25)) == 1..<90)
    }

    // An add that mixes a month or a day with time units. The start is 2026-10-07 12:00 in GMT.
    @Test(arguments: [
        (DateComponents(day: 2, hour: 5, minute: 7, second: 9), 813_258_429.0), (DateComponents(month: 1, hour: 3), 815_583_600.0),
    ])
    func addMonthsAndDaysWithTimeUnits(_ components: DateComponents, _ expected: Double) {
        let result = Self.calendar(.chinese).date(byAdding: components, to: Date(timeIntervalSinceReferenceDate: 813_067_200), wrappingComponents: false)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected))
    }

    // A roll of a field that starts on the first weekday. The start is Sunday 2026-10-04 12:00 in GMT, and the first weekday is Sunday.
    @Test(arguments: identifiers, [
        (Calendar.Component.weekday, 812_894_400.0), (.weekOfYear, 813_412_800.0), (.dayOfYear, 812_894_400.0), (.weekOfMonth, 810_820_800.0),
    ])
    func rollFromTheFirstWeekday(_ identifier: Calendar.Identifier, _ row: (field: Calendar.Component, expected: Double)) {
        var amount = DateComponents()
        amount.setValue(1, for: row.field)
        let result = Self.calendar(identifier).date(byAdding: amount, to: Date(timeIntervalSinceReferenceDate: 812_808_000), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: row.expected), "\(row.field)")
    }

    // The `.yearForWeekOfYear` that holds 2026-10-07 runs from Sunday 2026-02-15 to Sunday 2027-01-31. The New Years are 2026-02-17 and 2027-02-06.
    @Test func weekYearInterval() {
        let interval = Self.calendar(.chinese).dateInterval(of: .yearForWeekOfYear, for: Date(timeIntervalSinceReferenceDate: 813_067_200))
        #expect(interval?.start == Date(timeIntervalSinceReferenceDate: 792_806_400))
        #expect(interval?.end == Date(timeIntervalSinceReferenceDate: 823_046_400))
    }

    // Adding one `.yearForWeekOfYear` keeps the week and the weekday. Number 4663 starts on 2026-02-15 and 4664 on 2027-01-31, so 2026-10-07 moves 350 days to 2027-09-22.
    @Test func addOneWeekYear() {
        let result = Self.calendar(.chinese).date(byAdding: DateComponents(yearForWeekOfYear: 1), to: Date(timeIntervalSinceReferenceDate: 813_067_200), wrappingComponents: false)
        #expect(result == Date(timeIntervalSinceReferenceDate: 843_307_200))
    }

    // A week of the month with a day of the year and no weekday, and a weekday ordinal of 0. Cycle 78, year 43, month 3, noon in GMT.
    @Test(arguments: identifiers, [
        (DateComponents(era: 78, year: 43, month: 3, hour: 12, weekOfMonth: 2), 100, 801_576_000.0),
        (DateComponents(era: 78, year: 43, month: 3, hour: 12, weekday: 3, weekdayOrdinal: 0), nil, 797_860_800.0),
    ] as [(DateComponents, Int?, Double)])
    func dateFromWeekOfMonthAndOrdinalZero(_ identifier: Calendar.Identifier, _ row: (components: DateComponents, dayOfYear: Int?, expected: Double)) {
        var components = row.components
        components.dayOfYear = row.dayOfYear
        #expect(Self.calendar(identifier).date(from: components) == Date(timeIntervalSinceReferenceDate: row.expected))
    }

    // Rolls of the weekday ordinal from the 7th and from the 14th day of a month. Noon in GMT.
    @Test(arguments: [(811_339_200.0, 1, 811_944_000.0), (811_944_000.0, -1, 811_339_200.0)])
    func rollWeekdayOrdinal(_ start: Double, _ amount: Int, _ expected: Double) {
        let result = Self.calendar(.chinese).date(byAdding: DateComponents(weekdayOrdinal: amount), to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected))
    }

#if !FOUNDATION_FRAMEWORK
    // For Dangi, Calendar(identifier:) uses this class in the package build. The framework build leaves the routing off for now.
    @Test func dangiUsesTheChineseClass() throws {
        let type = try #require(_calendarClass(identifier: .dangi))
        #expect(ObjectIdentifier(type) == ObjectIdentifier(_CalendarChinese.self))
    }
#endif

    // Years outside the tables: a year with 13 months has one leap month, and each year ends on the day the next one starts.
    @Test(arguments: identifiers, Array(stride(from: -46_999, through: 46_999, by: 467)))
    func computedYearsAreWellFormed(_ identifier: Calendar.Identifier, _ relatedISOYear: Int) throws {
        let variant = try Self.variant(identifier)
        let year = _CalendarChinese.year(relatedISOYear: relatedISOYear, variant)
        let next = _CalendarChinese.year(relatedISOYear: relatedISOYear + 1, variant)
        #expect(year.monthCount == 12 || year.monthCount == 13)
        #expect((year.monthCount == 13) == (year.leapMonthNumber != 0))
        #expect(next.newYearRataDie == year.endRataDie)
    }

    // The winter solstice falls in month 11, which is a rule of the calendar. The test finds the solstice day from the solar longitude at Chinese midnight (UTC+8).
    @Test(arguments: [1_700, 2_300] + Array(stride(from: 13_000, through: 46_000, by: 1_100)) + Array(stride(from: -46_000, through: -18_000, by: 1_100)))
    func winterSolsticeIsInMonth11(_ gregorianYear: Int) {
        func reachesSolstice(_ rataDie: Int) -> Bool {
            let longitude = _CalendarAstronomy.solarLongitude(at: Double(rataDie) + 16.0 / 24.0)
            return longitude >= 270.0 && longitude < 350.0
        }
        var day = _CalendarAstronomy.gregorianRataDie(gregorianYear, 12, 21)
        // Far from the present the solstice is weeks from 21 December, so move by the distance in longitude first, at about one degree a day.
        var degreesPast = _CalendarAstronomy.solarLongitude(at: Double(day) + 16.0 / 24.0) - 270.0
        if degreesPast >= 180.0 { degreesPast -= 360.0 } else if degreesPast < -180.0 { degreesPast += 360.0 }
        day -= Int(degreesPast)
        while reachesSolstice(day - 1) { day -= 1 }
        while !reachesSolstice(day) { day += 1 }
        #expect(Self.calendar(.chinese).dateComponents([.month], from: Self.date(rataDie: day)).month == 11)
    }

    // The class supports the Gregorian years from -46,999 to 46,999. A date past them has no fields and no range, ordinality, interval or add.
    @Test(arguments: identifiers, [3e12, -3e12, 2e12, -2e12])
    func datesPastTheLimitHaveNoAnswer(_ identifier: Calendar.Identifier, _ seconds: Double) {
        let calendar = Self.calendar(identifier)
        let date = Date(timeIntervalSinceReferenceDate: seconds)
        let fields = calendar.dateComponents([.era, .year, .month, .day, .weekOfYear], from: date)
        #expect(fields.era == nil && fields.year == nil && fields.month == nil && fields.day == nil && fields.weekOfYear == nil)
        #expect(calendar.range(of: .day, in: .year, for: date) == nil)
        #expect(calendar.ordinality(of: .day, in: .year, for: date) == nil)
        #expect(calendar.dateInterval(of: .month, for: date) == nil)
        #expect(calendar.date(byAdding: DateComponents(day: 1), to: date, wrappingComponents: false) == nil)
        #expect(calendar.dateComponents([.day], from: date, to: date + 86400).day == nil)
    }

    @Test(arguments: identifiers, [1.3e12, -1.4e12])
    func datesInsideTheLimitHaveFields(_ identifier: Calendar.Identifier, _ seconds: Double) {
        let calendar = Self.calendar(identifier)
        let date = Date(timeIntervalSinceReferenceDate: seconds)
        let fields = calendar.dateComponents([.era, .year, .month, .day], from: date)
        #expect(fields.era != nil && fields.year != nil && fields.month != nil && fields.day != nil)
        #expect(calendar.range(of: .day, in: .year, for: date) != nil)
        #expect(calendar.date(byAdding: DateComponents(day: 1), to: date, wrappingComponents: false) != nil)
    }

    // The years past the limit have no date. The last year is cycle 828 year 16. The first is cycle -739 year 39, because year 38 starts 40 days before the limit.
    @Test(arguments: identifiers, [(828, 16, true), (828, 17, false), (-739, 39, true), (-739, 38, false)])
    func yearsPastTheLimitHaveNoDate(_ identifier: Calendar.Identifier, _ row: (era: Int, year: Int, exists: Bool)) {
        let components = DateComponents(era: row.era, year: row.year, month: 1, day: 1)
        #expect((Self.calendar(identifier).date(from: components) != nil) == row.exists)
    }

    #if FOUNDATION_EXIT_TESTS
    @Test(arguments: [Calendar.Identifier.dangi, .vietnamese])
    func rangeFarInTheFutureDoesNotStop(identifier: Calendar.Identifier) async {
        await #expect(processExitsWith: .success) { [identifier] in
            _ = Self.calendar(identifier).range(of: .day, in: .year, for: Date(timeIntervalSinceReferenceDate: 3e12))
        }
    }
    #endif

    // An hourly rule for the last day of the year needs the range of the day of the year. The rule must give 5 dates, and each date must be on the last day.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: identifiers)
    func hourlyRuleForTheLastDayOfTheYear(_ identifier: Calendar.Identifier) {
        let calendar = Calendar(inner: Self.calendar(identifier))
        var rule = Calendar.RecurrenceRule(calendar: calendar, frequency: .hourly, end: .afterOccurrences(5))
        rule.daysOfTheYear = [-1]
        let dates = Array(rule.recurrences(of: Date(timeIntervalSinceReferenceDate: 599_616_000)).prefix(5))
        #expect(dates.count == 5)
        for date in dates {
            let lastDay = calendar.range(of: .dayOfYear, in: .year, for: date).map { $0.upperBound - 1 }
            #expect(calendar.component(.dayOfYear, from: date) == lastDay)
        }
    }

    // Two calendars that are equal have the same hash, also when one has no stored first weekday and the other stores the default.
    @Test(arguments: identifiers)
    func equalCalendarsHashAlike(_ identifier: Calendar.Identifier) {
        let first = Calendar(inner: _CalendarChinese(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let second = Calendar(inner: _CalendarChinese(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil))
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    // The weekend comes from the protocol default and the locale. 2022-08-20 is a Saturday and 2022-08-22 is a Monday.
    @Test(arguments: identifiers)
    func weekend(_ identifier: Calendar.Identifier) {
        let calendar = Calendar(inner: _CalendarChinese(identifier: identifier, timeZone: .gmt, locale: Locale(identifier: "en_US"), firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        #expect(calendar.isDateInWeekend(Self.date((2022, 8, 20))))
        #expect(!calendar.isDateInWeekend(Self.date((2022, 8, 22))))
    }

    // Rolling the year wraps inside the 60 year cycle.
    @Test(arguments: [
        (.chinese, -1514376000.0, 10, -1200571200.0),
        (.chinese, -183816000.0, -30, 762868800.0),
        (.chinese, 1051704000.0, 61, 1082289600.0),
        (.chinese, 1051704000.0, 100, 418910400.0),
        (.chinese, -183816000.0, 1, -150638400.0),
        (.dangi, -183816000.0, -30, 762868800.0),
        (.dangi, 1051704000.0, 61, 1082289600.0),
        (.dangi, 1241784000.0, -1, 1208692800.0),
    ] as [(Calendar.Identifier, Double, Int, Double)])
    func rollYearWrapsInTheCycle(_ identifier: Calendar.Identifier, _ start: Double, _ amount: Int, _ expected: Double) {
        let result = Self.calendar(identifier).date(byAdding: DateComponents(year: amount), to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: true)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected))
    }

    // A month or a day outside its range moves into the next month or year. Cycle 78, year 43, GMT.
    @Test(arguments: [
        (.chinese, 13, 1, 823564800.0),
        (.chinese, 0, 1, 790473600.0),
        (.chinese, 1, 31, 795571200.0),
        (.chinese, 1, 0, 792892800.0),
        (.chinese, 99, 1, 1050710400.0),
        (.chinese, 2, 30, 798076800.0),
        (.chinese, 8, -10, 809827200.0),
        (.dangi, 2, 30, 798076800.0),
        (.dangi, 3, 30, 800582400.0),
        (.dangi, 7, 30, 810777600.0),
        (.vietnamese, 7, 30, 810777600.0),
    ] as [(Calendar.Identifier, Int, Int, Double)])
    func dateFromOutOfRangeMonthAndDay(_ identifier: Calendar.Identifier, _ month: Int, _ day: Int, _ expected: Double) {
        let components = DateComponents(era: 78, year: 43, month: month, day: day)
        #expect(Self.calendar(identifier).date(from: components) == Date(timeIntervalSinceReferenceDate: expected))
    }

    // A month starts on day 1, and the day before it is the last day of the month before.
    @Test(arguments: [(Calendar.Identifier.dangi, 2097, 1, 13), (.vietnamese, 2054, 5, 7), (.vietnamese, 2077, 11, 15), (.vietnamese, 2085, 10, 18)])
    func firstDayOfAMonthIsDayOne(_ identifier: Calendar.Identifier, _ year: Int, _ month: Int, _ day: Int) {
        let calendar = Self.calendar(identifier)
        let first = calendar.dateComponents([.day], from: Self.date((year, month, day)), in: .gmt)
        let before = calendar.dateComponents([.day], from: Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(year, month, day) - 1), in: .gmt)
        #expect(first.day == 1)
        #expect(before.day == 29 || before.day == 30)
    }

    // Every day from 1901 to 2100 has a day number from 1 to 30, and the next day is the next number or the first day of a month.
    @Test(arguments: identifiers)
    func everyDayHasAValidDayNumber(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        var failures: [Int] = []
        var previous = 0
        for rataDie in _CalendarAstronomy.gregorianRataDie(1901, 3, 1)...(_CalendarAstronomy.gregorianRataDie(2100, 12, 31)) {
            guard let day = calendar.dateComponents([.day], from: Self.date(rataDie: rataDie), in: .gmt).day else { failures.append(rataDie); continue }
            if !(1...30).contains(day) || (previous != 0 && day != previous + 1 && day != 1) { failures.append(rataDie) }
            previous = day
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first: \(failures.prefix(3))")
    }

    // MARK: The day boundary

    @Test(arguments: [1800, 2026, 2300])
    func chineseDayBoundaryIsEight(_ year: Int) {
        #expect(ChineseCalendarVariant.chinese.utcOffsetHours(atMoment: Double(_CalendarAstronomy.gregorianRataDie(year, 1, 1))) == 8.0)
    }

    @Test func dayBoundaryOffsets() {
        func rataDie(_ year: Int, _ month: Int, _ day: Int) -> Double { Double(_CalendarAstronomy.gregorianRataDie(year, month, day)) }
        // The Dangi calendar: UTC+8, then UTC+7 for 1897, UTC+8 until 1911, UTC+9 from 1912.
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(1896, 6, 1)) == 8.0)
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(1897, 6, 1)) == 7.0)
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(1898, 6, 1)) == 8.0)
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(1911, 6, 1)) == 8.0)
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(1912, 6, 1)) == 9.0)
        #expect(ChineseCalendarVariant.dangi.utcOffsetHours(atMoment: rataDie(2026, 1, 1)) == 9.0)
        // The Vietnamese calendar: UTC+8, then UTC+7 from 1968.
        #expect(ChineseCalendarVariant.vietnamese.utcOffsetHours(atMoment: rataDie(1967, 6, 1)) == 8.0)
        #expect(ChineseCalendarVariant.vietnamese.utcOffsetHours(atMoment: rataDie(1968, 6, 1)) == 7.0)
        #expect(ChineseCalendarVariant.vietnamese.utcOffsetHours(atMoment: rataDie(2026, 1, 1)) == 7.0)
    }

    // MARK: The baked tables

    // The months of a year add up to the distance to the next New Year, a year has 12 or 13 months, and the New Years fall in the right weeks.
    @Test(arguments: identifiers)
    func tablesAreConsistent(_ identifier: Calendar.Identifier) throws {
        let variant = try Self.variant(identifier)
        var leapYears = 0
        for year in 1901...2100 {
            let current = _CalendarChinese.year(relatedISOYear: year, variant)
            let next = _CalendarChinese.year(relatedISOYear: year + 1, variant)
            #expect(current.endRataDie == next.newYearRataDie, "\(identifier) \(year)")
            #expect(current.monthCount == 12 || current.monthCount == 13, "\(identifier) \(year)")
            #expect(current.daysInYear == 354 || current.daysInYear == 355 || current.daysInYear == 353 || (383...385).contains(current.daysInYear), "\(identifier) \(year)")
            let newYear = current.newYearRataDie - _CalendarAstronomy.gregorianRataDie(year, 1, 1)
            #expect((20...51).contains(newYear), "\(identifier) \(year)")
            #expect((current.monthCount == 13) == (current.leapMonthNumber != 0), "\(identifier) \(year)")
            if current.leapMonthNumber != 0 { leapYears += 1 }
        }
        // 7 leap years in every 19 years.
        #expect((70...80).contains(leapYears), "\(identifier) \(leapYears)")
    }

    // The years just outside a table come from the astronomy, and they join the table without a gap or an overlap.
    @Test(arguments: identifiers, [1899, 1900, 2100, 2101])
    func tablesJoinTheComputedYears(_ identifier: Calendar.Identifier, _ year: Int) throws {
        let variant = try Self.variant(identifier)
        let current = _CalendarChinese.year(relatedISOYear: year, variant)
        let next = _CalendarChinese.year(relatedISOYear: year + 1, variant)
        #expect(current.endRataDie == next.newYearRataDie, "\(identifier) \(year)")
    }

    // The day boundary of the Vietnamese calendar makes 1984 have two months 11. The class flags the second one as the leap month.
    @Test func vietnameseLeapMonthOf1984() {
        let calendar = Self.calendar(.vietnamese)
        let first = calendar.dateComponents([.month, .isLeapMonth, .day], from: Self.date((1984, 11, 23)))
        let second = calendar.dateComponents([.month, .isLeapMonth, .day], from: Self.date((1984, 12, 22)))
        #expect(first.month == 11 && first.isLeapMonth == false && first.day == 1)
        #expect(second.month == 11 && second.isLeapMonth == true && second.day == 1)
    }

    #if FOUNDATION_EXIT_TESTS
    @Test func unsupportedIdentifierStopsTheProgram() async {
        await #expect(processExitsWith: .failure) {
            _ = _CalendarChinese(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        }
    }
    #endif
}

// MARK: - Cases

private struct LunarDate: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let gregorian: (Int, Int, Int)
    let era, year, month: Int
    let isLeapMonth: Bool
    let day, dayOfYear, weekOfYear, yearForWeekOfYear: Int

    init(_ identifier: Calendar.Identifier, _ gregorian: (Int, Int, Int), era: Int, year: Int, month: Int, isLeapMonth: Bool, day: Int, dayOfYear: Int, weekOfYear: Int, yearForWeekOfYear: Int) {
        self.identifier = identifier; self.gregorian = gregorian
        self.era = era; self.year = year; self.month = month; self.isLeapMonth = isLeapMonth
        self.day = day; self.dayOfYear = dayOfYear; self.weekOfYear = weekOfYear; self.yearForWeekOfYear = yearForWeekOfYear
    }

    var testDescription: String { "\(identifier) \(gregorian.0)-\(gregorian.1)-\(gregorian.2)" }
}

private struct MonthStart: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let gregorian: (Int, Int, Int)
    let era, year, month: Int
    let isLeapMonth: Bool

    init(_ identifier: Calendar.Identifier, _ gregorian: (Int, Int, Int), era: Int, year: Int, month: Int, isLeapMonth: Bool) {
        self.identifier = identifier; self.gregorian = gregorian; self.era = era; self.year = year; self.month = month; self.isLeapMonth = isLeapMonth
    }

    var testDescription: String { "\(identifier) \(gregorian.0)-\(gregorian.1)-\(gregorian.2)" }
}

// MARK: - Data

// Dates in the years of the tables, with the `.yearForWeekOfYear` of each calendar. It is the related Gregorian year plus 2637, or plus 2333 for the Dangi calendar.
private let lunarDates: [LunarDate] = [
        LunarDate(.chinese, (1902, 6, 19), era: 76, year: 39, month: 5, isLeapMonth: false, day: 14, dayOfYear: 132, weekOfYear: 20, yearForWeekOfYear: 4539),
        LunarDate(.chinese, (1907, 12, 4), era: 76, year: 44, month: 10, isLeapMonth: false, day: 29, dayOfYear: 295, weekOfYear: 43, yearForWeekOfYear: 4544),
        LunarDate(.chinese, (1916, 2, 11), era: 76, year: 53, month: 1, isLeapMonth: false, day: 8, dayOfYear: 8, weekOfYear: 2, yearForWeekOfYear: 4553),
        LunarDate(.chinese, (1924, 4, 20), era: 77, year: 1, month: 3, isLeapMonth: false, day: 17, dayOfYear: 76, weekOfYear: 12, yearForWeekOfYear: 4561),
        LunarDate(.chinese, (1929, 10, 5), era: 77, year: 6, month: 9, isLeapMonth: false, day: 3, dayOfYear: 238, weekOfYear: 34, yearForWeekOfYear: 4566),
        LunarDate(.chinese, (1935, 3, 22), era: 77, year: 12, month: 2, isLeapMonth: false, day: 18, dayOfYear: 47, weekOfYear: 7, yearForWeekOfYear: 4572),
        LunarDate(.chinese, (1943, 5, 30), era: 77, year: 20, month: 4, isLeapMonth: false, day: 27, dayOfYear: 115, weekOfYear: 18, yearForWeekOfYear: 4580),
        LunarDate(.chinese, (1951, 8, 7), era: 77, year: 28, month: 7, isLeapMonth: false, day: 5, dayOfYear: 183, weekOfYear: 27, yearForWeekOfYear: 4588),
        LunarDate(.chinese, (1959, 10, 15), era: 77, year: 36, month: 9, isLeapMonth: false, day: 14, dayOfYear: 250, weekOfYear: 36, yearForWeekOfYear: 4596),
        LunarDate(.chinese, (1967, 12, 23), era: 77, year: 44, month: 11, isLeapMonth: false, day: 22, dayOfYear: 318, weekOfYear: 46, yearForWeekOfYear: 4604),
        LunarDate(.chinese, (1976, 3, 1), era: 77, year: 53, month: 2, isLeapMonth: false, day: 1, dayOfYear: 31, weekOfYear: 6, yearForWeekOfYear: 4613),
        LunarDate(.chinese, (1984, 5, 9), era: 78, year: 1, month: 4, isLeapMonth: false, day: 9, dayOfYear: 98, weekOfYear: 15, yearForWeekOfYear: 4621),
        LunarDate(.chinese, (1989, 10, 24), era: 78, year: 6, month: 9, isLeapMonth: false, day: 25, dayOfYear: 261, weekOfYear: 38, yearForWeekOfYear: 4626),
        LunarDate(.chinese, (1998, 1, 1), era: 78, year: 14, month: 12, isLeapMonth: false, day: 3, dayOfYear: 329, weekOfYear: 48, yearForWeekOfYear: 4634),
        LunarDate(.chinese, (2006, 3, 11), era: 78, year: 23, month: 2, isLeapMonth: false, day: 12, dayOfYear: 42, weekOfYear: 6, yearForWeekOfYear: 4643),
        LunarDate(.chinese, (2014, 5, 19), era: 78, year: 31, month: 4, isLeapMonth: false, day: 21, dayOfYear: 109, weekOfYear: 17, yearForWeekOfYear: 4651),
        LunarDate(.chinese, (2022, 7, 27), era: 78, year: 39, month: 6, isLeapMonth: false, day: 29, dayOfYear: 177, weekOfYear: 26, yearForWeekOfYear: 4659),
        LunarDate(.chinese, (2025, 4, 19), era: 78, year: 42, month: 3, isLeapMonth: false, day: 22, dayOfYear: 81, weekOfYear: 12, yearForWeekOfYear: 4662),
        LunarDate(.chinese, (2033, 6, 27), era: 78, year: 50, month: 6, isLeapMonth: false, day: 1, dayOfYear: 148, weekOfYear: 22, yearForWeekOfYear: 4670),
        LunarDate(.chinese, (2041, 9, 4), era: 78, year: 58, month: 8, isLeapMonth: false, day: 9, dayOfYear: 216, weekOfYear: 32, yearForWeekOfYear: 4678),
        LunarDate(.chinese, (2049, 11, 12), era: 79, year: 6, month: 10, isLeapMonth: false, day: 17, dayOfYear: 284, weekOfYear: 41, yearForWeekOfYear: 4686),
        LunarDate(.chinese, (2058, 1, 20), era: 79, year: 14, month: 12, isLeapMonth: false, day: 26, dayOfYear: 351, weekOfYear: 1, yearForWeekOfYear: 4695),
        LunarDate(.chinese, (2060, 10, 13), era: 79, year: 17, month: 9, isLeapMonth: false, day: 20, dayOfYear: 255, weekOfYear: 37, yearForWeekOfYear: 4697),
        LunarDate(.chinese, (2068, 12, 21), era: 79, year: 25, month: 11, isLeapMonth: false, day: 27, dayOfYear: 323, weekOfYear: 47, yearForWeekOfYear: 4705),
        LunarDate(.chinese, (2074, 6, 7), era: 79, year: 31, month: 5, isLeapMonth: false, day: 13, dayOfYear: 132, weekOfYear: 20, yearForWeekOfYear: 4711),
        LunarDate(.chinese, (2082, 8, 15), era: 79, year: 39, month: 7, isLeapMonth: false, day: 22, dayOfYear: 199, weekOfYear: 29, yearForWeekOfYear: 4719),
        LunarDate(.chinese, (2090, 10, 23), era: 79, year: 47, month: 9, isLeapMonth: false, day: 1, dayOfYear: 267, weekOfYear: 39, yearForWeekOfYear: 4727),
        LunarDate(.chinese, (2098, 12, 31), era: 79, year: 55, month: 12, isLeapMonth: false, day: 10, dayOfYear: 334, weekOfYear: 49, yearForWeekOfYear: 4735),
        LunarDate(.dangi, (1902, 6, 19), era: 76, year: 39, month: 5, isLeapMonth: false, day: 14, dayOfYear: 132, weekOfYear: 20, yearForWeekOfYear: 4235),
        LunarDate(.dangi, (1910, 8, 27), era: 76, year: 47, month: 7, isLeapMonth: false, day: 23, dayOfYear: 199, weekOfYear: 29, yearForWeekOfYear: 4243),
        LunarDate(.dangi, (1918, 11, 4), era: 76, year: 55, month: 10, isLeapMonth: false, day: 1, dayOfYear: 267, weekOfYear: 39, yearForWeekOfYear: 4251),
        LunarDate(.dangi, (1927, 1, 12), era: 77, year: 3, month: 12, isLeapMonth: false, day: 9, dayOfYear: 334, weekOfYear: 49, yearForWeekOfYear: 4259),
        LunarDate(.dangi, (1935, 3, 22), era: 77, year: 12, month: 2, isLeapMonth: false, day: 18, dayOfYear: 47, weekOfYear: 7, yearForWeekOfYear: 4268),
        LunarDate(.dangi, (1943, 5, 30), era: 77, year: 20, month: 4, isLeapMonth: false, day: 27, dayOfYear: 115, weekOfYear: 18, yearForWeekOfYear: 4276),
        LunarDate(.dangi, (1951, 8, 7), era: 77, year: 28, month: 7, isLeapMonth: false, day: 5, dayOfYear: 183, weekOfYear: 27, yearForWeekOfYear: 4284),
        LunarDate(.dangi, (1959, 10, 15), era: 77, year: 36, month: 9, isLeapMonth: false, day: 14, dayOfYear: 250, weekOfYear: 36, yearForWeekOfYear: 4292),
        LunarDate(.dangi, (1965, 3, 31), era: 77, year: 42, month: 2, isLeapMonth: false, day: 29, dayOfYear: 58, weekOfYear: 9, yearForWeekOfYear: 4298),
        LunarDate(.dangi, (1973, 6, 8), era: 77, year: 50, month: 5, isLeapMonth: false, day: 8, dayOfYear: 126, weekOfYear: 19, yearForWeekOfYear: 4306),
        LunarDate(.dangi, (1981, 8, 16), era: 77, year: 58, month: 7, isLeapMonth: false, day: 17, dayOfYear: 193, weekOfYear: 29, yearForWeekOfYear: 4314),
        LunarDate(.dangi, (1989, 10, 24), era: 78, year: 6, month: 9, isLeapMonth: false, day: 25, dayOfYear: 261, weekOfYear: 38, yearForWeekOfYear: 4322),
        LunarDate(.dangi, (1998, 1, 1), era: 78, year: 14, month: 12, isLeapMonth: false, day: 3, dayOfYear: 328, weekOfYear: 48, yearForWeekOfYear: 4330),
        LunarDate(.dangi, (2006, 3, 11), era: 78, year: 23, month: 2, isLeapMonth: false, day: 12, dayOfYear: 42, weekOfYear: 6, yearForWeekOfYear: 4339),
        LunarDate(.dangi, (2014, 5, 19), era: 78, year: 31, month: 4, isLeapMonth: false, day: 21, dayOfYear: 109, weekOfYear: 17, yearForWeekOfYear: 4347),
        LunarDate(.dangi, (2022, 7, 27), era: 78, year: 39, month: 6, isLeapMonth: false, day: 29, dayOfYear: 177, weekOfYear: 26, yearForWeekOfYear: 4355),
        LunarDate(.dangi, (2030, 10, 4), era: 78, year: 47, month: 9, isLeapMonth: false, day: 8, dayOfYear: 244, weekOfYear: 35, yearForWeekOfYear: 4363),
        LunarDate(.dangi, (2038, 12, 12), era: 78, year: 55, month: 11, isLeapMonth: false, day: 17, dayOfYear: 312, weekOfYear: 46, yearForWeekOfYear: 4371),
        LunarDate(.dangi, (2044, 5, 28), era: 79, year: 1, month: 5, isLeapMonth: false, day: 2, dayOfYear: 120, weekOfYear: 18, yearForWeekOfYear: 4377),
        LunarDate(.dangi, (2052, 8, 5), era: 79, year: 9, month: 7, isLeapMonth: false, day: 11, dayOfYear: 187, weekOfYear: 28, yearForWeekOfYear: 4385),
        LunarDate(.dangi, (2058, 1, 20), era: 79, year: 14, month: 12, isLeapMonth: false, day: 26, dayOfYear: 351, weekOfYear: 1, yearForWeekOfYear: 4391),
        LunarDate(.dangi, (2063, 7, 7), era: 79, year: 20, month: 6, isLeapMonth: false, day: 12, dayOfYear: 160, weekOfYear: 23, yearForWeekOfYear: 4396),
        LunarDate(.dangi, (2071, 9, 14), era: 79, year: 28, month: 8, isLeapMonth: false, day: 21, dayOfYear: 227, weekOfYear: 34, yearForWeekOfYear: 4404),
        LunarDate(.dangi, (2079, 11, 22), era: 79, year: 36, month: 10, isLeapMonth: false, day: 29, dayOfYear: 294, weekOfYear: 43, yearForWeekOfYear: 4412),
        LunarDate(.dangi, (2088, 1, 30), era: 79, year: 45, month: 1, isLeapMonth: false, day: 7, dayOfYear: 7, weekOfYear: 2, yearForWeekOfYear: 4421),
        LunarDate(.dangi, (2096, 4, 8), era: 79, year: 53, month: 3, isLeapMonth: false, day: 16, dayOfYear: 75, weekOfYear: 12, yearForWeekOfYear: 4429),
        LunarDate(.vietnamese, (1902, 6, 19), era: 76, year: 39, month: 5, isLeapMonth: false, day: 14, dayOfYear: 132, weekOfYear: 20, yearForWeekOfYear: 4539),
        LunarDate(.vietnamese, (1907, 12, 4), era: 76, year: 44, month: 10, isLeapMonth: false, day: 29, dayOfYear: 295, weekOfYear: 43, yearForWeekOfYear: 4544),
        LunarDate(.vietnamese, (1916, 2, 11), era: 76, year: 53, month: 1, isLeapMonth: false, day: 8, dayOfYear: 8, weekOfYear: 2, yearForWeekOfYear: 4553),
        LunarDate(.vietnamese, (1924, 4, 20), era: 77, year: 1, month: 3, isLeapMonth: false, day: 17, dayOfYear: 76, weekOfYear: 12, yearForWeekOfYear: 4561),
        LunarDate(.vietnamese, (1932, 6, 28), era: 77, year: 9, month: 5, isLeapMonth: false, day: 25, dayOfYear: 144, weekOfYear: 22, yearForWeekOfYear: 4569),
        LunarDate(.vietnamese, (1937, 12, 13), era: 77, year: 14, month: 11, isLeapMonth: false, day: 11, dayOfYear: 306, weekOfYear: 45, yearForWeekOfYear: 4574),
        LunarDate(.vietnamese, (1946, 2, 20), era: 77, year: 23, month: 1, isLeapMonth: false, day: 19, dayOfYear: 19, weekOfYear: 4, yearForWeekOfYear: 4583),
        LunarDate(.vietnamese, (1954, 4, 30), era: 77, year: 31, month: 3, isLeapMonth: false, day: 28, dayOfYear: 87, weekOfYear: 13, yearForWeekOfYear: 4591),
        LunarDate(.vietnamese, (1962, 7, 8), era: 77, year: 39, month: 6, isLeapMonth: false, day: 7, dayOfYear: 154, weekOfYear: 23, yearForWeekOfYear: 4599),
        LunarDate(.vietnamese, (1967, 12, 23), era: 77, year: 44, month: 11, isLeapMonth: false, day: 22, dayOfYear: 318, weekOfYear: 46, yearForWeekOfYear: 4604),
        LunarDate(.vietnamese, (1973, 6, 8), era: 77, year: 50, month: 5, isLeapMonth: false, day: 8, dayOfYear: 126, weekOfYear: 19, yearForWeekOfYear: 4610),
        LunarDate(.vietnamese, (1981, 8, 16), era: 77, year: 58, month: 7, isLeapMonth: false, day: 17, dayOfYear: 193, weekOfYear: 29, yearForWeekOfYear: 4618),
        LunarDate(.vietnamese, (1989, 10, 24), era: 78, year: 6, month: 9, isLeapMonth: false, day: 25, dayOfYear: 261, weekOfYear: 38, yearForWeekOfYear: 4626),
        LunarDate(.vietnamese, (1998, 1, 1), era: 78, year: 14, month: 12, isLeapMonth: false, day: 4, dayOfYear: 329, weekOfYear: 48, yearForWeekOfYear: 4634),
        LunarDate(.vietnamese, (2006, 3, 11), era: 78, year: 23, month: 2, isLeapMonth: false, day: 12, dayOfYear: 42, weekOfYear: 6, yearForWeekOfYear: 4643),
        LunarDate(.vietnamese, (2014, 5, 19), era: 78, year: 31, month: 4, isLeapMonth: false, day: 21, dayOfYear: 109, weekOfYear: 17, yearForWeekOfYear: 4651),
        LunarDate(.vietnamese, (2019, 11, 3), era: 78, year: 36, month: 10, isLeapMonth: false, day: 7, dayOfYear: 272, weekOfYear: 40, yearForWeekOfYear: 4656),
        LunarDate(.vietnamese, (2028, 1, 11), era: 78, year: 44, month: 12, isLeapMonth: false, day: 15, dayOfYear: 340, weekOfYear: 50, yearForWeekOfYear: 4664),
        LunarDate(.vietnamese, (2036, 3, 20), era: 78, year: 53, month: 2, isLeapMonth: false, day: 23, dayOfYear: 53, weekOfYear: 8, yearForWeekOfYear: 4673),
        LunarDate(.vietnamese, (2044, 5, 28), era: 79, year: 1, month: 5, isLeapMonth: false, day: 2, dayOfYear: 120, weekOfYear: 18, yearForWeekOfYear: 4681),
        LunarDate(.vietnamese, (2052, 8, 5), era: 79, year: 9, month: 7, isLeapMonth: false, day: 11, dayOfYear: 187, weekOfYear: 28, yearForWeekOfYear: 4689),
        LunarDate(.vietnamese, (2060, 10, 13), era: 79, year: 17, month: 9, isLeapMonth: false, day: 20, dayOfYear: 255, weekOfYear: 37, yearForWeekOfYear: 4697),
        LunarDate(.vietnamese, (2068, 12, 21), era: 79, year: 25, month: 11, isLeapMonth: false, day: 27, dayOfYear: 323, weekOfYear: 47, yearForWeekOfYear: 4705),
        LunarDate(.vietnamese, (2077, 2, 28), era: 79, year: 34, month: 2, isLeapMonth: false, day: 6, dayOfYear: 36, weekOfYear: 6, yearForWeekOfYear: 4714),
        LunarDate(.vietnamese, (2085, 5, 8), era: 79, year: 42, month: 4, isLeapMonth: false, day: 15, dayOfYear: 103, weekOfYear: 16, yearForWeekOfYear: 4722),
        LunarDate(.vietnamese, (2093, 7, 16), era: 79, year: 50, month: 6, isLeapMonth: false, day: 23, dayOfYear: 171, weekOfYear: 25, yearForWeekOfYear: 4730),
]

// The first day of each month in years where Dangi or Vietnamese differs from Chinese, and just outside the tables.
private let monthStarts: [MonthStart] = [
        MonthStart(.dangi, (1912, 1, 19), era: 76, year: 48, month: 12, isLeapMonth: false),
        MonthStart(.dangi, (1912, 3, 19), era: 76, year: 49, month: 2, isLeapMonth: false),
        MonthStart(.dangi, (1912, 6, 15), era: 76, year: 49, month: 5, isLeapMonth: false),
        MonthStart(.dangi, (1912, 9, 11), era: 76, year: 49, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (1912, 12, 9), era: 76, year: 49, month: 11, isLeapMonth: false),
        MonthStart(.dangi, (1914, 3, 27), era: 76, year: 51, month: 3, isLeapMonth: false),
        MonthStart(.dangi, (1914, 6, 24), era: 76, year: 51, month: 5, isLeapMonth: true),
        MonthStart(.dangi, (1914, 9, 20), era: 76, year: 51, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (1914, 12, 17), era: 76, year: 51, month: 11, isLeapMonth: false),
        MonthStart(.dangi, (1918, 3, 13), era: 76, year: 55, month: 2, isLeapMonth: false),
        MonthStart(.dangi, (1918, 6, 9), era: 76, year: 55, month: 5, isLeapMonth: false),
        MonthStart(.dangi, (1918, 9, 5), era: 76, year: 55, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (1918, 12, 4), era: 76, year: 55, month: 11, isLeapMonth: false),
        MonthStart(.dangi, (2012, 3, 22), era: 78, year: 29, month: 3, isLeapMonth: false),
        MonthStart(.dangi, (2012, 6, 20), era: 78, year: 29, month: 5, isLeapMonth: false),
        MonthStart(.dangi, (2012, 9, 16), era: 78, year: 29, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (2012, 12, 13), era: 78, year: 29, month: 11, isLeapMonth: false),
        MonthStart(.dangi, (2017, 3, 28), era: 78, year: 34, month: 3, isLeapMonth: false),
        MonthStart(.dangi, (2017, 6, 24), era: 78, year: 34, month: 5, isLeapMonth: true),
        MonthStart(.dangi, (2017, 9, 20), era: 78, year: 34, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (2017, 12, 18), era: 78, year: 34, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (1967, 1, 11), era: 77, year: 43, month: 12, isLeapMonth: false),
        MonthStart(.vietnamese, (1967, 4, 10), era: 77, year: 44, month: 3, isLeapMonth: false),
        MonthStart(.vietnamese, (1967, 7, 8), era: 77, year: 44, month: 6, isLeapMonth: false),
        MonthStart(.vietnamese, (1967, 10, 4), era: 77, year: 44, month: 9, isLeapMonth: false),
        MonthStart(.vietnamese, (1967, 12, 31), era: 77, year: 44, month: 12, isLeapMonth: false),
        MonthStart(.vietnamese, (1968, 3, 29), era: 77, year: 45, month: 3, isLeapMonth: false),
        MonthStart(.vietnamese, (1968, 6, 26), era: 77, year: 45, month: 6, isLeapMonth: false),
        MonthStart(.vietnamese, (1968, 9, 22), era: 77, year: 45, month: 8, isLeapMonth: false),
        MonthStart(.vietnamese, (1968, 12, 20), era: 77, year: 45, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (1969, 3, 18), era: 77, year: 46, month: 2, isLeapMonth: false),
        MonthStart(.vietnamese, (1969, 6, 15), era: 77, year: 46, month: 5, isLeapMonth: false),
        MonthStart(.vietnamese, (1969, 9, 12), era: 77, year: 46, month: 8, isLeapMonth: false),
        MonthStart(.vietnamese, (1969, 12, 9), era: 77, year: 46, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (1984, 3, 3), era: 78, year: 1, month: 2, isLeapMonth: false),
        MonthStart(.vietnamese, (1984, 5, 30), era: 78, year: 1, month: 5, isLeapMonth: false),
        MonthStart(.vietnamese, (1984, 8, 27), era: 78, year: 1, month: 8, isLeapMonth: false),
        MonthStart(.vietnamese, (1984, 11, 23), era: 78, year: 1, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (1987, 2, 28), era: 78, year: 4, month: 2, isLeapMonth: false),
        MonthStart(.vietnamese, (1987, 5, 27), era: 78, year: 4, month: 5, isLeapMonth: false),
        MonthStart(.vietnamese, (1987, 8, 24), era: 78, year: 4, month: 7, isLeapMonth: true),
        MonthStart(.vietnamese, (1987, 11, 21), era: 78, year: 4, month: 10, isLeapMonth: false),
        MonthStart(.vietnamese, (2018, 2, 16), era: 78, year: 35, month: 1, isLeapMonth: false),
        MonthStart(.vietnamese, (2018, 5, 15), era: 78, year: 35, month: 4, isLeapMonth: false),
        MonthStart(.vietnamese, (2018, 8, 11), era: 78, year: 35, month: 7, isLeapMonth: false),
        MonthStart(.vietnamese, (2018, 11, 7), era: 78, year: 35, month: 10, isLeapMonth: false),
        MonthStart(.dangi, (1897, 2, 2), era: 76, year: 34, month: 1, isLeapMonth: false),
        MonthStart(.dangi, (1897, 5, 2), era: 76, year: 34, month: 4, isLeapMonth: false),
        MonthStart(.dangi, (1897, 7, 29), era: 76, year: 34, month: 7, isLeapMonth: false),
        MonthStart(.dangi, (1897, 10, 26), era: 76, year: 34, month: 10, isLeapMonth: false),
        MonthStart(.dangi, (1898, 1, 22), era: 76, year: 35, month: 1, isLeapMonth: false),
        MonthStart(.dangi, (1898, 2, 21), era: 76, year: 35, month: 2, isLeapMonth: false),
        MonthStart(.dangi, (1898, 3, 22), era: 76, year: 35, month: 3, isLeapMonth: false),
        MonthStart(.dangi, (1898, 4, 21), era: 76, year: 35, month: 3, isLeapMonth: true),
        MonthStart(.dangi, (1898, 7, 19), era: 76, year: 35, month: 6, isLeapMonth: false),
        MonthStart(.dangi, (1898, 10, 15), era: 76, year: 35, month: 9, isLeapMonth: false),
        MonthStart(.dangi, (2102, 1, 19), era: 79, year: 58, month: 12, isLeapMonth: false),
        MonthStart(.dangi, (2102, 2, 17), era: 79, year: 59, month: 1, isLeapMonth: false),
        MonthStart(.dangi, (2102, 3, 19), era: 79, year: 59, month: 2, isLeapMonth: false),
        MonthStart(.dangi, (2102, 6, 16), era: 79, year: 59, month: 5, isLeapMonth: false),
        MonthStart(.dangi, (2102, 9, 12), era: 79, year: 59, month: 8, isLeapMonth: false),
        MonthStart(.dangi, (2102, 12, 10), era: 79, year: 59, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (1899, 3, 12), era: 76, year: 36, month: 2, isLeapMonth: false),
        MonthStart(.vietnamese, (1899, 6, 8), era: 76, year: 36, month: 5, isLeapMonth: false),
        MonthStart(.vietnamese, (1899, 9, 5), era: 76, year: 36, month: 8, isLeapMonth: false),
        MonthStart(.vietnamese, (1899, 12, 3), era: 76, year: 36, month: 11, isLeapMonth: false),
        MonthStart(.vietnamese, (2102, 1, 19), era: 79, year: 58, month: 12, isLeapMonth: false),
        MonthStart(.vietnamese, (2102, 4, 17), era: 79, year: 59, month: 3, isLeapMonth: false),
        MonthStart(.vietnamese, (2102, 7, 15), era: 79, year: 59, month: 6, isLeapMonth: false),
        MonthStart(.vietnamese, (2102, 10, 12), era: 79, year: 59, month: 9, isLeapMonth: false),
]
