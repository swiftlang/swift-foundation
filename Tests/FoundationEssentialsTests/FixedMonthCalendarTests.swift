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

// Every expected value in this file is a fixed value, so the tests do not depend on another calendar implementation.
@Suite("Fixed Month Calendar")
private struct FixedMonthCalendarTests {

    private static let identifiers: [Calendar.Identifier] = [.coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .persian, .indian]

    private static func calendar(_ identifier: Calendar.Identifier, timeZone: TimeZone = .gmt, firstWeekday: Int = 1, minimumDays: Int = 1) -> _CalendarFixedMonth {
        _CalendarFixedMonth(identifier: identifier, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDays, gregorianStartDate: nil)
    }

    private static func date(rataDie: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + Double(hour) * 3600.0)
    }

    private static func date(_ gregorian: (Int, Int, Int), hour: Int = 12) -> Date {
        date(rataDie: _CalendarAstronomy.gregorianRataDie(gregorian.0, gregorian.1, gregorian.2), hour: hour)
    }

    private static func gregorian(_ date: Date) -> (Int, Int, Int) {
        let days = Int((date.timeIntervalSinceReferenceDate / 86400.0).rounded(.down)) + 730_486
        let year = _CalendarAstronomy.gregorianYear(ofRataDie: days)
        var month = 1
        while month < 12, _CalendarAstronomy.gregorianRataDie(year, month + 1, 1) <= days { month += 1 }
        return (year, month, days - _CalendarAstronomy.gregorianRataDie(year, month, 1) + 1)
    }

    private static func fields(_ calendar: _CalendarFixedMonth, _ date: Date?) -> [Int]? {
        guard let date else { return nil }
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return [components.era, components.year, components.month, components.day].compactMap { $0 }
    }

    // MARK: Known dates

    @Test(arguments: knownDates)
    func knownDate(_ known: KnownDate) {
        let calendar = Self.calendar(known.identifier, firstWeekday: known.firstWeekday, minimumDays: known.minimumDays)
        let date = Self.date((known.gregorianYear, known.gregorianMonth, known.gregorianDay), hour: known.hour)
        let components = calendar.dateComponents([.era, .year, .month, .day, .dayOfYear, .weekday, .weekOfYear, .yearForWeekOfYear, .weekOfMonth, .weekdayOrdinal, .hour], from: date)
        #expect(components.era == known.era)
        #expect(components.year == known.year)
        #expect(components.month == known.month)
        #expect(components.day == known.day)
        #expect(components.dayOfYear == known.dayOfYear)
        #expect(components.weekday == known.weekday)
        #expect(components.weekOfYear == known.weekOfYear)
        #expect(components.yearForWeekOfYear == known.yearForWeekOfYear)
        #expect(components.weekOfMonth == known.weekOfMonth)
        #expect(components.weekdayOrdinal == known.weekdayOrdinal)
        #expect(components.hour == known.hour)
        // The fields name the same instant again.
        #expect(calendar.date(from: DateComponents(era: known.era, year: known.year, month: known.month, day: known.day, hour: known.hour)) == date)
    }

    @Test(arguments: yearStarts)
    func yearStart(_ start: YearStart) {
        let calendar = Self.calendar(start.identifier)
        let date = calendar.date(from: DateComponents(era: start.era, year: start.year, month: 1, day: 1, hour: 12))
        #expect(date.map { Self.gregorian($0) }.map { [$0.0, $0.1, $0.2] } == [start.gregorian.0, start.gregorian.1, start.gregorian.2], "\(start)")
    }

    @Test(arguments: monthLengths)
    func monthLength(_ lengths: MonthLengths) throws {
        let calendar = Self.calendar(lengths.identifier)
        for (index, expected) in lengths.lengths.enumerated() {
            let date = try #require(calendar.date(from: DateComponents(era: lengths.era, year: lengths.year, month: index + 1, day: 1, hour: 12)))
            #expect(calendar.range(of: .day, in: .month, for: date) == 1..<expected + 1, "month \(index + 1)")
        }
        let first = try #require(calendar.date(from: DateComponents(era: lengths.era, year: lengths.year, month: 1, day: 1, hour: 12)))
        #expect(calendar.range(of: .day, in: .year, for: first) == 1..<lengths.yearLength + 1)
        #expect(calendar.range(of: .month, in: .year, for: first) == 1..<lengths.lengths.count + 1)
    }

    @Test(arguments: rangeCases)
    func ranges(_ ranges: RangeCase) {
        let calendar = Self.calendar(ranges.identifier)
        for (component, minimum, maximum) in ranges.ranges {
            #expect(calendar.minimumRange(of: component) == minimum, "minimum of \(component)")
            #expect(calendar.maximumRange(of: component) == maximum, "maximum of \(component)")
        }
    }

    // In the Persian years 1300 to 3100, the leap years differ from the 33 year rule only in pairs of years (Y, Y + 1). These are the years Y.
    private static let persianShiftedLeapYears = [
        1502, 1601, 1634, 1667, 1700, 1733, 1766, 1799, 1832, 1865, 1898, 1931, 1964, 1997, 2030, 2059,
        2063, 2096, 2129, 2158, 2162, 2191, 2195, 2224, 2228, 2257, 2261, 2290, 2294, 2323, 2327, 2356,
        2360, 2389, 2393, 2422, 2426, 2455, 2459, 2488, 2492, 2521, 2525, 2554, 2558, 2587, 2591, 2620,
        2624, 2653, 2657, 2686, 2690, 2719, 2723, 2748, 2752, 2756, 2781, 2785, 2789, 2818, 2822, 2847,
        2851, 2855, 2880, 2884, 2888, 2913, 2917, 2921, 2946, 2950, 2954, 2979, 2983, 2987,
    ]

    // One sweep over 1,801 years compares every year with the list. A missing or an extra entry in the correction table changes the list.
    @Test func persianLeapYearsFollowTheCorrectionTable() throws {
        let calendar = Self.calendar(.persian)
        var shifted: [Int] = []
        for year in 1300...3100 {
            let date = try #require(calendar.date(from: DateComponents(year: year, month: 12, day: 1, hour: 12)))
            let length = try #require(calendar.range(of: .day, in: .month, for: date)).count
            #expect(length == 29 || length == 30, "Persian \(year)")
            let leapByRule = _CalendarUtility.floorDiv(8 * (year + 1) + 21, 33) - _CalendarUtility.floorDiv(8 * year + 21, 33) == 1
            if (length == 30) != leapByRule { shifted.append(year) }
        }
        #expect(shifted == Self.persianShiftedLeapYears.flatMap { [$0, $0 + 1] })
    }

    // Persian 1635-01-01 is Gregorian 2256-03-20, and Persian 1451-01-01 is Gregorian 2072-03-20.
    @Test(arguments: [(1635, 2256), (1451, 2072)])
    func persianYearStart(_ persianYear: Int, _ gregorianYear: Int) throws {
        let date = try #require(Self.calendar(.persian).date(from: DateComponents(year: persianYear, month: 1, day: 1)))
        #expect(date == Self.date((gregorianYear, 3, 20), hour: 0))
    }

    // MARK: Building a date

    @Test(arguments: lenientCases)
    func lenientDateFromComponents(_ lenient: LenientCase) {
        let calendar = Self.calendar(lenient.identifier)
        #expect(Self.fields(calendar, calendar.date(from: lenient.components)) == lenient.expected.map { [$0.0, $0.1, $0.2, $0.3] }, "\(lenient)")
    }

    @Test(arguments: formCases)
    func dateFromComponentForms(_ form: FormCase) {
        let calendar = Self.calendar(form.identifier)
        #expect(Self.fields(calendar, calendar.date(from: form.components)) == form.expected.map { [$0.0, $0.1, $0.2, $0.3] }, "\(form)")
    }

    // MARK: Adding and rolling

    @Test(arguments: addCases)
    func addAndRoll(_ add: AddCase) throws {
        let calendar = Self.calendar(add.identifier)
        let start = try #require(calendar.date(from: DateComponents(era: add.start.0, year: add.start.1, month: add.start.2, day: add.start.3, hour: 12)))
        var amount = DateComponents()
        amount.setValue(add.value, for: add.component)
        let result = calendar.date(byAdding: amount, to: start, wrappingComponents: add.wrapping)
        let components = try #require(result.map { calendar.dateComponents([.era, .year, .month, .day, .hour], from: $0) })
        #expect([components.era, components.year, components.month, components.day, components.hour] == [add.expected.0, add.expected.1, add.expected.2, add.expected.3, add.expected.4], "\(add)")
    }

    // MARK: Intervals, ranges and ordinality

    @Test(arguments: intervalCases)
    func dateIntervals(_ interval: IntervalCase) {
        let calendar = Self.calendar(interval.identifier)
        let result = calendar.dateInterval(of: interval.component, for: Self.date(interval.date))
        #expect(result?.start == Self.date(interval.start, hour: 0), "\(interval)")
        #expect(result?.end == Self.date(interval.end, hour: 0), "\(interval)")
    }

    @Test(arguments: ordinalityCases)
    func rangeAndOrdinality(_ ordinality: OrdinalityCase) {
        let calendar = Self.calendar(ordinality.identifier)
        let date = Self.date(ordinality.date)
        #expect(calendar.range(of: ordinality.smaller, in: ordinality.larger, for: date) == ordinality.range, "\(ordinality)")
        #expect(calendar.ordinality(of: ordinality.smaller, in: ordinality.larger, for: date) == ordinality.ordinality, "\(ordinality)")
    }

    // An era runs for the longest interval that Foundation allows. The era before the first one ends where the first one starts. Years before year 1 of a calendar that has one era are in no interval.
    @Test func eraIntervals() throws {
        let maximum = Calendar._maxDateIntervalDuration
        let today = Self.date((2026, 10, 7))

        let coptic = Self.calendar(.coptic)
        let copticStart = Self.date(rataDie: 103_605, hour: 0)
        #expect(coptic.dateInterval(of: .era, for: today) == DateInterval(start: copticStart, duration: maximum))
        #expect(coptic.dateInterval(of: .era, for: Self.date(rataDie: 100_000)) == DateInterval(start: copticStart - maximum, end: copticStart))

        let ethiopic = Self.calendar(.ethiopicAmeteMihret)
        let ethiopicStart = Self.date(rataDie: 2_796, hour: 0)
        #expect(ethiopic.dateInterval(of: .era, for: today) == DateInterval(start: ethiopicStart, duration: maximum))
        #expect(ethiopic.dateInterval(of: .era, for: Self.date(rataDie: 1)) == DateInterval(start: Self.date(rataDie: -2_006_079, hour: 0), end: ethiopicStart))

        let ameteAlem = Self.calendar(.ethiopicAmeteAlem)
        #expect(ameteAlem.dateInterval(of: .era, for: today) == DateInterval(start: Self.date(rataDie: -2_006_079, hour: 0), duration: maximum))

        let persian = Self.calendar(.persian)
        #expect(persian.dateInterval(of: .era, for: today) == DateInterval(start: Self.date(rataDie: 226_895, hour: 0), duration: maximum))
        #expect(persian.dateInterval(of: .era, for: Self.date(rataDie: 100_000)) == nil)
        #expect(persian.ordinality(of: .day, in: .era, for: Self.date(rataDie: 100_000)) == nil)

        let indian = Self.calendar(.indian)
        #expect(indian.dateInterval(of: .era, for: today) == DateInterval(start: Self.date((79, 3, 22), hour: 0), duration: maximum))
        #expect(indian.dateInterval(of: .era, for: Self.date(rataDie: 1)) == nil)
    }

    // MARK: Differences

    @Test(arguments: differenceCases)
    func differences(_ difference: DifferenceCase) {
        let calendar = Self.calendar(difference.identifier)
        let result = calendar.dateComponents(Calendar.ComponentSet(difference.units), from: Self.date((difference.start.0, difference.start.1, difference.start.2), hour: difference.start.3), to: Self.date((difference.end.0, difference.end.1, difference.end.2), hour: difference.end.3))
        var expected = DateComponents()
        for (component, value) in difference.expected { expected.setValue(value, for: component) }
        #expect(result == expected, "\(difference)")
    }

    // MARK: Searches

    @Test(arguments: searchCases)
    func nextDate(_ search: SearchCase) {
        let calendar = Calendar(inner: Self.calendar(search.identifier))
        let result = calendar.nextDate(after: Self.date((2026, 10, 7)), matching: search.components, matchingPolicy: search.policy, direction: search.direction)
        #expect(result.map { date -> [Int] in
            let day = Self.gregorian(date)
            return [day.0, day.1, day.2, Int(date.timeIntervalSinceReferenceDate / 3600).quotientAndRemainder(dividingBy: 24).remainder]
        } == search.expected.map { [$0.0, $0.1, $0.2, $0.3] }, "\(search)")
    }

    // Searches in a time zone with an offset: the results are seconds since the reference date.
    @Test(arguments: [
        TimeZoneSearch("every day at 2pm", .ethiopicAmeteMihret, secondsFromGMT: 10_800, start: 399787429, DateComponents(hour: 14), .nextTime, expected: [399_812_400, 399_898_800, 399_985_200, 400_071_600, 400_158_000, 400_244_400, 400_330_800, 400_417_200, 400_503_600, 400_590_000, 400_676_400, 400_762_800, 400_849_200, 400_935_600, 401_022_000, 401_108_400]),
        TimeZoneSearch("every day at 9pm", .ethiopicAmeteAlem, secondsFromGMT: 10_800, start: 399787429, DateComponents(hour: 21), .previousTimePreservingSmallerComponents, expected: [399_837_600, 399_924_000, 400_010_400, 400_096_800, 400_183_200, 400_269_600, 400_356_000, 400_442_400, 400_528_800, 400_615_200, 400_701_600, 400_788_000, 400_874_400, 400_960_800, 401_047_200, 401_133_600]),
        TimeZoneSearch("month 13 day 6 in a leap year", .ethiopicAmeteMihret, secondsFromGMT: 10_800, start: -978206171, DateComponents(month: 13, day: 6), .strict, expected: [-924_922_800, -798_692_400, -672_462_000, -546_231_600, -420_001_200, -293_770_800, -167_540_400, -41_310_000, 84_920_400, 211_150_800, 337_381_200, 463_611_600, 589_842_000, 716_072_400, 842_302_800, 968_533_200]),
        TimeZoneSearch("first week of the year", .ethiopicAmeteAlem, secondsFromGMT: 10_800, start: 63173029, DateComponents(weekOfYear: 1), .strict, expected: [84_574_800, 116_024_400, 148_078_800, 179_528_400, 210_978_000, 242_427_600, 273_877_200, 305_326_800, 337_381_200, 368_830_800, 400_280_400, 431_730_000, 463_179_600, 495_234_000, 526_683_600, 558_133_200]),
    ])
    func searchInTimeZone(_ search: TimeZoneSearch) throws {
        let timeZone = try #require(TimeZone(secondsFromGMT: search.secondsFromGMT))
        let calendar = Calendar(inner: Self.calendar(search.identifier, timeZone: timeZone))
        var results: [Int] = []
        calendar.enumerateDates(startingAfter: Date(timeIntervalSinceReferenceDate: Double(search.start)), matching: search.components, matchingPolicy: search.policy) { date, _, stop in
            if let date { results.append(Int(date.timeIntervalSinceReferenceDate)) }
            if results.count == search.expected.count { stop = true }
        }
        #expect(results == search.expected, "\(search)")
    }

    // MARK: Dates before the limit of the public calendar API

    @Test(arguments: ancientCases)
    func dateBeforeTheFoundationLimit(_ ancient: AncientCase) {
        let calendar = Self.calendar(ancient.identifier)
        let date = Self.date(rataDie: ancient.rataDie)
        #expect(Self.fields(calendar, date) == [ancient.expected.0, ancient.expected.1, ancient.expected.2, ancient.expected.3], "\(ancient)")
        #expect(calendar.date(from: DateComponents(era: ancient.expected.0, year: ancient.expected.1, month: ancient.expected.2, day: ancient.expected.3, hour: 12)) == date, "\(ancient)")
    }

    // MARK: Extreme field values

    // A week or an ordinal of Int.min gives nil, and a weekday of Int.min counts like the same weekday modulo 7. None of them traps.
    @Test(arguments: identifiers)
    func extremeWeekFields(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        #expect(calendar.date(from: DateComponents(year: 1, month: 1, weekday: 1, weekdayOrdinal: .min)) == nil)
        #expect(calendar.date(from: DateComponents(year: 1, month: 1, weekday: 1, weekOfMonth: .min)) == nil)
        #expect(calendar.date(from: DateComponents(year: 1, weekday: 1, weekOfYear: .min)) == nil)
        let equivalentWeekday = Int.min % 7 + 7
        #expect(calendar.date(from: DateComponents(year: 1, weekday: .min, weekOfYear: 1)) == calendar.date(from: DateComponents(year: 1, weekday: equivalentWeekday, weekOfYear: 1)))
        #expect(calendar.date(from: DateComponents(year: 1, month: 1, weekday: .min, weekdayOrdinal: 1)) == calendar.date(from: DateComponents(year: 1, month: 1, weekday: equivalentWeekday, weekdayOrdinal: 1)))
    }

    // Rolling a year by Int.min does not trap. In Coptic era 0 the years count backward, so the result is out of range and gives nil. In era 1 the roll stops at year 1.
    @Test func extremeYearRoll() throws {
        let calendar = Self.calendar(.coptic)
        var amount = DateComponents()
        amount.year = .min
        let eraZero = Self.date(rataDie: 100_000)
        #expect(calendar.date(byAdding: amount, to: eraZero, wrappingComponents: true) == nil)
        let eraOne = Self.date((2026, 10, 7))
        let rolled = try #require(calendar.date(byAdding: amount, to: eraOne, wrappingComponents: true))
        #expect(calendar.dateComponents([.era, .year], from: rolled).year == 1)
    }

    // A count of days that overflows gives nil. The first value times 7 wraps to 1, so the test needs a 64 bit Int. No field uses Int.max, because DateComponents reads it as no value.
    @Test(.enabled(if: Int.bitWidth == 64), arguments: identifiers)
    func overflowingAdd(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let date = Self.date((2026, 10, 7))
        let wrapsToOne = Int(truncatingIfNeeded: Int64(7_905_747_460_161_236_407))
        #expect(calendar.date(byAdding: DateComponents(weekOfYear: wrapsToOne), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(weekOfMonth: wrapsToOne), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(weekdayOrdinal: wrapsToOne), to: date, wrappingComponents: false) == nil)
        #expect(calendar.date(byAdding: DateComponents(day: .max - 1, weekday: 2), to: date, wrappingComponents: false) == nil)
        var negative = DateComponents(day: .min)
        negative.dayOfYear = -1
        #expect(calendar.date(byAdding: negative, to: date, wrappingComponents: false) == nil)
    }

    private static let extremeFields: [Calendar.Component] = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear]
    private static let extremeValues = [Int.min, Int.min + 1, Int.min / 2, -(1 << 40), 1 << 40, Int.max / 2, Int.max - 1]
    private static let extremeInputs = extremeFields.flatMap { field in extremeValues.map { (field: field, value: $0) } }

    // Every field with a value near the limits of Int goes through date(from:), add and roll. The test checks only that none of them traps. Each pair of field and value is its own case.
    @Test(arguments: identifiers, extremeInputs)
    func extremeValuesDoNotTrap(_ identifier: Calendar.Identifier, _ input: (field: Calendar.Component, value: Int)) {
        let calendar = Self.calendar(identifier)
        let starts = [Self.date((2026, 10, 7)), Self.date(rataDie: 100_000)]
        var dayOfYearBase = DateComponents(year: 1743)
        dayOfYearBase.dayOfYear = 1
        let bases = [
            DateComponents(year: 1743, month: 1, day: 1),
            DateComponents(year: 1743, month: 1, weekday: 1, weekdayOrdinal: 1),
            DateComponents(year: 1743, weekday: 1, weekOfYear: 1),
            DateComponents(year: 1743, month: 1, weekday: 1, weekOfMonth: 1),
            DateComponents(weekday: 1, weekOfYear: 1, yearForWeekOfYear: 1743),
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

    // MARK: Day of year

    // The date is 2022-08-22 22:02:38 in GMT. The day of the year counts like the day, and the hour, minute and second count inside that day.
    @Test(arguments: [(Calendar.Identifier.coptic, 346), (.ethiopicAmeteMihret, 346), (.ethiopicAmeteAlem, 346), (.persian, 155), (.indian, 154)])
    func dayOfYearOrdinality(_ identifier: Calendar.Identifier, _ dayOfYear: Int) {
        let calendar = Self.calendar(identifier)
        let date = Self.date((2022, 8, 22), hour: 22) + 158
        #expect(calendar.ordinality(of: .dayOfYear, in: .year, for: date) == dayOfYear)
        #expect(calendar.ordinality(of: .hour, in: .dayOfYear, for: date) == 23)
        #expect(calendar.ordinality(of: .minute, in: .dayOfYear, for: date) == 1323)
        #expect(calendar.ordinality(of: .second, in: .dayOfYear, for: date) == 79359)
    }

    // Coptic 1738 has 365 days and Coptic 1739 is a leap year with 366 days.
    @Test func dayOfYearRange() {
        let calendar = Self.calendar(.coptic)
        #expect(calendar.range(of: .dayOfYear, in: .year, for: Self.date((2022, 8, 22))) == 1..<366)
        #expect(calendar.range(of: .dayOfYear, in: .year, for: Self.date((2023, 3, 1))) == 1..<367)
    }

    // MARK: Ordinality and range of one unit in another

    // The date is 2022-08-22 22:02:38 in GMT, with Sunday as the first weekday and one day as the first week.
    @Test(arguments: [
        (.coptic, .minute, .day, 1323),
        (.coptic, .second, .day, 79359),
        (.coptic, .nanosecond, .day, Int(exactly: Int64(79_358_000_000_001))),
        (.coptic, .hour, .month, 383),
        (.coptic, .day, .weekOfYear, 2),
        (.coptic, .weekOfYear, .yearForWeekOfYear, 51),
        (.coptic, .weekOfYear, .quarter, 12),
        (.coptic, .weekOfMonth, .quarter, 12),
        (.coptic, .weekdayOrdinal, .year, 50),
        (.coptic, .weekdayOrdinal, .yearForWeekOfYear, 51),
        (.coptic, .weekday, .quarter, 11),
        (.coptic, .quarter, .era, 6952),
        (.coptic, .yearForWeekOfYear, .era, 1738),
        (.persian, .minute, .day, 1323),
        (.persian, .hour, .month, 743),
        (.persian, .weekOfYear, .quarter, 10),
        (.persian, .month, .era, 16805),
        (.indian, .hour, .month, 743),
        (.indian, .weekOfYear, .quarter, 10),
        (.indian, .month, .era, 23321),
    ] as [(Calendar.Identifier, Calendar.Component, Calendar.Component, Int?)])
    func ordinalityOfUnits(_ identifier: Calendar.Identifier, _ smaller: Calendar.Component, _ larger: Calendar.Component, _ expected: Int?) {
        let date = Self.date((2022, 8, 22), hour: 22) + 158
        #expect(Self.calendar(identifier).ordinality(of: smaller, in: larger, for: date) == expected, "\(smaller) in \(larger)")
    }

    @Test(arguments: [
        (.coptic, .month, .era, 1..<14),
        (.coptic, .quarter, .era, 1..<5),
        (.coptic, .day, .era, 1..<31),
        (.coptic, .weekOfYear, .month, 49..<54),
        (.coptic, .weekOfYear, .quarter, 40..<54),
        (.coptic, .weekOfMonth, .year, 1..<64),
        (.coptic, .weekOfMonth, .quarter, 1..<17),
        (.coptic, .weekdayOrdinal, .quarter, 1..<17),
        (.coptic, .weekdayOrdinal, .yearForWeekOfYear, 1..<68),
        (.coptic, .weekOfYear, .yearForWeekOfYear, 1..<54),
        (.coptic, .weekOfMonth, .era, 1..<7),
        (.coptic, .weekday, .weekdayOrdinal, nil),
        (.coptic, .hour, .day, 0..<24),
        (.coptic, .minute, .hour, 0..<60),
        (.coptic, .second, .minute, 0..<60),
        (.coptic, .nanosecond, .second, 0..<1_000_000_000),
        (.coptic, .weekday, .year, 1..<8),
        (.coptic, .month, .day, nil),
        (.persian, .weekOfYear, .month, 18..<24),
        (.persian, .weekdayOrdinal, .year, 1..<61),
        (.persian, .day, .yearForWeekOfYear, 1..<395),
        (.indian, .weekOfYear, .month, 18..<24),
        (.indian, .weekdayOrdinal, .year, 1..<61),
        (.indian, .day, .yearForWeekOfYear, 1..<396),
    ] as [(Calendar.Identifier, Calendar.Component, Calendar.Component, Range<Int>?)])
    func rangeOfUnits(_ identifier: Calendar.Identifier, _ smaller: Calendar.Component, _ larger: Calendar.Component, _ expected: Range<Int>?) {
        let date = Self.date((2022, 8, 22), hour: 22) + 158
        #expect(Self.calendar(identifier).range(of: smaller, in: larger, for: date) == expected, "\(smaller) in \(larger)")
    }

    // A week of the month can be week 0 when the first week needs more than one day, and the limits follow the shortest and the longest month.
    @Test(arguments: [
        (Calendar.Identifier.coptic, 1, 1..<2, 1..<7),
        (.coptic, 4, 1..<2, 0..<6),
        (.coptic, 7, 1..<1, 0..<6),
        (.persian, 1, 1..<6, 1..<7),
        (.persian, 4, 1..<5, 0..<6),
        (.indian, 7, 1..<5, 0..<6),
    ])
    func weekOfMonthLimits(_ identifier: Calendar.Identifier, _ minimumDays: Int, _ minimum: Range<Int>, _ maximum: Range<Int>) {
        let calendar = Self.calendar(identifier, minimumDays: minimumDays)
        #expect(calendar.minimumRange(of: .weekOfMonth) == minimum)
        #expect(calendar.maximumRange(of: .weekOfMonth) == maximum)
    }

    // The month of 5 days has no week to roll over when its only week does not count. Rolling then gives nil and does not divide by zero.
    @Test(arguments: [
        (1, 5, 1), (1, 6, nil), (1, 7, nil), (2, 6, 1), (2, 7, nil), (4, 6, 5),
    ] as [(Int, Int, Int?)])
    func rollWeekOfMonthInShortMonth(_ firstWeekday: Int, _ minimumDays: Int, _ expectedDay: Int?) throws {
        let calendar = Self.calendar(.coptic, firstWeekday: firstWeekday, minimumDays: minimumDays)
        let start = try #require(calendar.date(from: DateComponents(year: 1732, month: 13, day: 1, hour: 12)))
        var amount = DateComponents()
        amount.weekOfMonth = 1
        let result = calendar.date(byAdding: amount, to: start, wrappingComponents: true)
        #expect(result.flatMap { calendar.dateComponents([.day], from: $0).day } == expectedDay)
    }

    // The week in the era, checked against a count of the days from the first day of the era.
    @Test(arguments: [(Calendar.Identifier.coptic, 103_605), (.persian, 226_895), (.indian, 28_570)], [(1, 1), (2, 4), (7, 1), (4, 7)])
    func weekInEra(_ calendarAndFirstDay: (Calendar.Identifier, Int), _ week: (firstWeekday: Int, minimumDays: Int)) {
        let (identifier, firstDay) = calendarAndFirstDay
        let calendar = Self.calendar(identifier, firstWeekday: week.firstWeekday, minimumDays: week.minimumDays)
        let weekdayOfFirstDay = (firstDay % 7 + 7) % 7 + 1
        let daysBeforeFirstWeek = (week.firstWeekday - weekdayOfFirstDay + 7) % 7
        let firstWeekCounts = daysBeforeFirstWeek == 0 || daysBeforeFirstWeek >= week.minimumDays
        var failures: [Int] = []
        for rataDie in firstDay..<firstDay + 1_000 {
            var expected = firstWeekCounts ? 1 : 0
            for day in firstDay + 1..<rataDie + 1 where (day % 7 + 7) % 7 + 1 == week.firstWeekday { expected += 1 }
            let date = Self.date(rataDie: rataDie)
            if calendar.ordinality(of: .weekOfYear, in: .era, for: date) != expected || calendar.ordinality(of: .weekOfMonth, in: .era, for: date) != expected { failures.append(rataDie) }
        }
        #expect(failures.isEmpty, "first failures: \(failures.prefix(3))")
    }

    // Years come first, then the year of `.yearForWeekOfYear`, then the months.
    @Test(arguments: [
        (682_898_558.0, 1, 0, 1, 0, 716_162_558.0),
        (682_898_558.0, 1, 0, 7, 0, 731_023_358.0),
        (682_898_558.0, -2, 0, 5, 3, 631_058_558.0),
        (740_000_000.0, -2, 0, 5, 3, 687_555_200.0),
        (682_898_558.0, 1, 1, 0, 0, 745_884_158.0),
        (700_000_000.0, 1, 1, 0, 0, 763_072_000.0),
    ] as [(Double, Int, Int, Int, Int, Double)])
    func addWeekYearWithOtherFields(_ start: Double, _ weekYears: Int, _ years: Int, _ months: Int, _ days: Int, _ expected: Double) {
        var amount = DateComponents()
        amount.yearForWeekOfYear = weekYears
        amount.year = years
        amount.month = months
        amount.day = days
        let result = Self.calendar(.coptic).date(byAdding: amount, to: Date(timeIntervalSinceReferenceDate: start), wrappingComponents: false)
        #expect(result == Date(timeIntervalSinceReferenceDate: expected))
    }

    // Changing a setting of the calendar makes a copy that keeps the identifier and the other settings.
    @Test(arguments: identifiers)
    func changingSettingsKeepsTheCalendar(_ identifier: Calendar.Identifier) throws {
        var calendar = Calendar(inner: Self.calendar(identifier))
        calendar.firstWeekday = 3
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 3600))
        #expect(calendar.identifier == identifier)
        #expect(calendar.firstWeekday == 3)
        #expect(calendar.minimumDaysInFirstWeek == 4)
        #expect(calendar.timeZone.secondsFromGMT() == 3600)
    }

    // Two calendars that are equal have the same hash, also when one has no stored first weekday and the other stores the default.
    @Test(arguments: identifiers)
    func equalCalendarsHashAlike(_ identifier: Calendar.Identifier) {
        let first = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
        let second = Calendar(inner: _CalendarFixedMonth(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: 1, minimumDaysInFirstWeek: 1, gregorianStartDate: nil))
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    // Coptic era 0 has no first day. The units in the era count from the start of its interval. The date is 0100-01-01 12:00 in GMT.
    @Test(arguments: [
        (Calendar.Component.day, 50835872),
        (Calendar.Component.hour, 1220060917),
        (Calendar.Component.minute, 73203654961),
        (Calendar.Component.second, 4392219297601),
        (Calendar.Component.weekOfYear, 7262268),
        (Calendar.Component.weekOfMonth, 7262268),
    ] as [(Calendar.Component, Int64)])
    func unitsInCopticEraZero(_ smaller: Calendar.Component, _ expected: Int64) {
        let date = Date(timeIntervalSinceReferenceDate: -59989723200.0)
        #expect(Self.calendar(.coptic).ordinality(of: smaller, in: .era, for: date) == Int(exactly: expected))
    }

    // The months in Coptic era 0 count whole months from the start of the era interval, which is not at the start of a month. The days are rata dies at noon in GMT.
    @Test(arguments: [
        (-1_715_749, 1_746_999), (-1_715_000, 1_747_026), (-1_700_000, 1_747_561), (-1_500_000, 1_754_679),
        (-1_000_000, 1_772_475), (-500_000, 1_790_271), (-100_000, 1_804_507), (50_000, 1_809_847),
    ])
    func monthsInCopticEraZero(_ rataDie: Int, _ expected: Int) {
        let date = Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + 43200)
        #expect(Self.calendar(.coptic).ordinality(of: .month, in: .era, for: date) == expected)
    }

    @Test(arguments: [Calendar.Component.month, .weekday, .weekdayOrdinal])
    func otherUnitsInCopticEraZeroHaveAValue(_ smaller: Calendar.Component) {
        let date = Date(timeIntervalSinceReferenceDate: -59989723200.0)
        #expect(Self.calendar(.coptic).ordinality(of: smaller, in: .era, for: date) != nil)
    }

    // MARK: Large differences

    // A count of nanoseconds that does not fit in an Int32 gives the limit, as in the Gregorian calendar.
    @Test(arguments: identifiers)
    func nanosecondDifferenceLimit(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        let start = Self.date((2000, 1, 1))
        let end = Self.date((2400, 1, 1))
        #expect(calendar.dateComponents([.nanosecond], from: start, to: end).nanosecond == Int(Int32.max))
        #expect(calendar.dateComponents([.nanosecond], from: end, to: start).nanosecond == Int(Int32.min))
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

    // MARK: Time units

    // The time units do not depend on the calendar. The date is 2026-03-05 12:34:56 in GMT.
    @Test(arguments: identifiers)
    func timeUnits(_ identifier: Calendar.Identifier) throws {
        let calendar = Self.calendar(identifier)
        let date = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(2026, 3, 5), hour: 12) + 34 * 60 + 56
        #expect(try #require(calendar.dateInterval(of: .minute, for: date)) == DateInterval(start: date - 56, duration: 60))
        #expect(try #require(calendar.dateInterval(of: .second, for: date)) == DateInterval(start: date, duration: 1))
        #expect(try #require(calendar.dateInterval(of: .nanosecond, for: date)) == DateInterval(start: date, duration: 1e-9))
        #expect(calendar.ordinality(of: .hour, in: .day, for: date) == 13)
        #expect(calendar.ordinality(of: .minute, in: .hour, for: date) == 35)
        #expect(calendar.ordinality(of: .second, in: .minute, for: date) == 57)
        #expect(calendar.ordinality(of: .nanosecond, in: .second, for: date) == 1)
        var minutes = DateComponents()
        minutes.minute = 30
        #expect(calendar.date(byAdding: minutes, to: date, wrappingComponents: true) == date - 30 * 60)
        var seconds = DateComponents()
        seconds.second = 10
        #expect(calendar.date(byAdding: seconds, to: date, wrappingComponents: true) == date - 50)
        let later = date + 6 * 60
        #expect(calendar.dateComponents(Calendar.ComponentSet([.minute]), from: date, to: later).minute == 6)
        #expect(calendar.dateComponents(Calendar.ComponentSet([.second]), from: date, to: later).second == 360)
        #expect(calendar.dateComponents(Calendar.ComponentSet([.nanosecond]), from: date, to: date + 2).nanosecond == 2_000_000_000)
    }

    // MARK: Round trips

    // Every day in a span of years: the fields of the day name the day again.
    @Test(arguments: identifiers)
    func fieldsRoundTrip(_ identifier: Calendar.Identifier) {
        let calendar = Self.calendar(identifier)
        var failures: [Int] = []
        for rataDie in _CalendarAstronomy.gregorianRataDie(2020, 1, 1)...(_CalendarAstronomy.gregorianRataDie(2031, 12, 31)) {
            let date = Self.date(rataDie: rataDie)
            let components = calendar.dateComponents([.era, .year, .month, .day, .hour], from: date)
            if calendar.date(from: components) != date { failures.append(rataDie) }
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first: \(failures.prefix(3))")
    }

    // The week fields of a day name the day again, for several settings of the first week.
    @Test(arguments: identifiers, [(1, 1), (2, 4), (7, 1), (4, 7)])
    func weekFieldsRoundTrip(_ identifier: Calendar.Identifier, _ week: (firstWeekday: Int, minimumDays: Int)) {
        let calendar = Self.calendar(identifier, firstWeekday: week.firstWeekday, minimumDays: week.minimumDays)
        var failures: [Int] = []
        for rataDie in _CalendarAstronomy.gregorianRataDie(2020, 1, 1)...(_CalendarAstronomy.gregorianRataDie(2031, 12, 31)) {
            let date = Self.date(rataDie: rataDie)
            let components = calendar.dateComponents([.era, .yearForWeekOfYear, .weekOfYear, .weekday, .hour], from: date)
            if calendar.date(from: components) != date { failures.append(rataDie) }
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first: \(failures.prefix(3))")
    }

    // The days of each year of `.yearForWeekOfYear` tile the time line, so the end of one is the start of the next.
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

    #if FOUNDATION_EXIT_TESTS
    @Test func unsupportedIdentifierStopsTheProgram() async {
        await #expect(processExitsWith: .failure) {
            _ = _CalendarFixedMonth(identifier: .gregorian, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        }
    }
    #endif
}

// MARK: - Cases

private struct KnownDate: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let gregorianYear, gregorianMonth, gregorianDay, hour: Int
    let firstWeekday, minimumDays: Int
    let era, year, month, day, dayOfYear, weekday, weekOfYear, yearForWeekOfYear, weekOfMonth, weekdayOrdinal: Int

    init(_ identifier: Calendar.Identifier, _ gregorianYear: Int, _ gregorianMonth: Int, _ gregorianDay: Int, _ hour: Int, firstWeekday: Int, minimumDays: Int, era: Int, year: Int, month: Int, day: Int, dayOfYear: Int, weekday: Int, weekOfYear: Int, yearForWeekOfYear: Int, weekOfMonth: Int, weekdayOrdinal: Int) {
        self.identifier = identifier
        self.gregorianYear = gregorianYear; self.gregorianMonth = gregorianMonth; self.gregorianDay = gregorianDay; self.hour = hour
        self.firstWeekday = firstWeekday; self.minimumDays = minimumDays
        self.era = era; self.year = year; self.month = month; self.day = day; self.dayOfYear = dayOfYear
        self.weekday = weekday; self.weekOfYear = weekOfYear; self.yearForWeekOfYear = yearForWeekOfYear
        self.weekOfMonth = weekOfMonth; self.weekdayOrdinal = weekdayOrdinal
    }

    var testDescription: String { "\(identifier) \(gregorianYear)-\(gregorianMonth)-\(gregorianDay) \(hour)h, first weekday \(firstWeekday), \(minimumDays) days" }
}

private struct YearStart: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let era, year: Int
    let gregorian: (Int, Int, Int)

    init(_ identifier: Calendar.Identifier, era: Int, year: Int, gregorian: (Int, Int, Int)) {
        self.identifier = identifier; self.era = era; self.year = year; self.gregorian = gregorian
    }

    var testDescription: String { "\(identifier) era \(era) year \(year)" }
}

private struct MonthLengths: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let era, year: Int
    let lengths: [Int]
    let yearLength: Int

    init(_ identifier: Calendar.Identifier, era: Int, year: Int, lengths: [Int], yearLength: Int) {
        self.identifier = identifier; self.era = era; self.year = year; self.lengths = lengths; self.yearLength = yearLength
    }

    var testDescription: String { "\(identifier) era \(era) year \(year)" }
}

private struct RangeCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let ranges: [(Calendar.Component, Range<Int>, Range<Int>)]

    init(_ identifier: Calendar.Identifier, _ ranges: [(Calendar.Component, Range<Int>, Range<Int>)]) {
        self.identifier = identifier; self.ranges = ranges
    }

    var testDescription: String { "\(identifier)" }
}

private struct LenientCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let components: DateComponents
    let expected: (Int, Int, Int, Int)?

    init(_ identifier: Calendar.Identifier, era: Int?, year: Int?, month: Int?, day: Int?, expected: (Int, Int, Int, Int)?) {
        self.identifier = identifier
        self.components = DateComponents(era: era, year: year, month: month, day: day, hour: 12)
        self.expected = expected
    }

    var testDescription: String { "\(identifier) era \(components.era.map(String.init) ?? "nil") year \(components.year.map(String.init) ?? "nil") month \(components.month.map(String.init) ?? "nil") day \(components.day.map(String.init) ?? "nil")" }
}

private struct FormCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let components: DateComponents
    let expected: (Int, Int, Int, Int)?

    init(_ identifier: Calendar.Identifier, era: Int? = nil, year: Int? = nil, month: Int? = nil, hour: Int, weekday: Int? = nil, weekdayOrdinal: Int? = nil, weekOfMonth: Int? = nil, weekOfYear: Int? = nil, yearForWeekOfYear: Int? = nil, dayOfYear: Int? = nil, expected: (Int, Int, Int, Int)?) {
        self.identifier = identifier
        var components = DateComponents(era: era, year: year, month: month, hour: hour, weekday: weekday, weekdayOrdinal: weekdayOrdinal, weekOfMonth: weekOfMonth, weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeekOfYear)
        components.dayOfYear = dayOfYear
        self.components = components
        self.expected = expected
    }

    var testDescription: String { "\(identifier) \(components)" }
}

private struct AddCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let start: (Int, Int, Int, Int)
    let component: Calendar.Component
    let value: Int
    let wrapping: Bool
    let expected: (Int, Int, Int, Int, Int)

    init(_ identifier: Calendar.Identifier, _ start: (Int, Int, Int, Int), _ component: Calendar.Component, _ value: Int, wrapping: Bool, expected: (Int, Int, Int, Int, Int)) {
        self.identifier = identifier; self.start = start; self.component = component; self.value = value; self.wrapping = wrapping; self.expected = expected
    }

    var testDescription: String { "\(identifier) \(start) \(wrapping ? "roll" : "add") \(component) \(value)" }
}

private struct IntervalCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let date: (Int, Int, Int)
    let component: Calendar.Component
    let start, end: (Int, Int, Int)

    init(_ identifier: Calendar.Identifier, _ date: (Int, Int, Int), _ component: Calendar.Component, start: (Int, Int, Int), end: (Int, Int, Int)) {
        self.identifier = identifier; self.date = date; self.component = component; self.start = start; self.end = end
    }

    var testDescription: String { "\(identifier) \(date) \(component)" }
}

private struct OrdinalityCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let date: (Int, Int, Int)
    let smaller, larger: Calendar.Component
    let range: Range<Int>?
    let ordinality: Int?

    init(_ identifier: Calendar.Identifier, _ date: (Int, Int, Int), _ smaller: Calendar.Component, in larger: Calendar.Component, range: Range<Int>?, ordinality: Int?) {
        self.identifier = identifier; self.date = date; self.smaller = smaller; self.larger = larger; self.range = range; self.ordinality = ordinality
    }

    var testDescription: String { "\(identifier) \(date) \(smaller) in \(larger)" }
}

private struct DifferenceCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let start, end: (Int, Int, Int, Int)
    let units: Set<Calendar.Component>
    let expected: [(Calendar.Component, Int)]

    init(_ identifier: Calendar.Identifier, _ start: (Int, Int, Int, Int), _ end: (Int, Int, Int, Int), _ units: Set<Calendar.Component>, expected: [(Calendar.Component, Int)]) {
        self.identifier = identifier; self.start = start; self.end = end; self.units = units; self.expected = expected
    }

    var testDescription: String { "\(identifier) \(start) to \(end)" }
}

private struct SearchCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let components: DateComponents
    let policy: Calendar.MatchingPolicy
    let direction: Calendar.SearchDirection
    let expected: (Int, Int, Int, Int)?

    init(_ identifier: Calendar.Identifier, _ components: DateComponents, _ policy: Calendar.MatchingPolicy, _ direction: Calendar.SearchDirection, expected: (Int, Int, Int, Int)?) {
        self.identifier = identifier; self.components = components; self.policy = policy; self.direction = direction; self.expected = expected
    }

    var testDescription: String { "\(identifier) \(components) \(policy) \(direction)" }
}

private struct TimeZoneSearch: Sendable, CustomTestStringConvertible {
    let name: String
    let identifier: Calendar.Identifier
    let secondsFromGMT: Int
    let start: Int
    let components: DateComponents
    let policy: Calendar.MatchingPolicy
    let expected: [Int]

    init(_ name: String, _ identifier: Calendar.Identifier, secondsFromGMT: Int, start: Int, _ components: DateComponents, _ policy: Calendar.MatchingPolicy, expected: [Int]) {
        self.name = name; self.identifier = identifier; self.secondsFromGMT = secondsFromGMT; self.start = start; self.components = components; self.policy = policy; self.expected = expected
    }

    var testDescription: String { name }
}

private struct AncientCase: Sendable, CustomTestStringConvertible {
    let identifier: Calendar.Identifier
    let rataDie: Int
    let expected: (Int, Int, Int, Int)

    init(_ identifier: Calendar.Identifier, rataDie: Int, expected: (Int, Int, Int, Int)) {
        self.identifier = identifier; self.rataDie = rataDie; self.expected = expected
    }

    var testDescription: String { "\(identifier) rata die \(rataDie)" }
}

// MARK: - Data

// Dates at several hours, read with two settings of the first week.
private let knownDates: [KnownDate] = [
        KnownDate(.coptic, 1600, 12, 31, 0, firstWeekday: 1, minimumDays: 1, era: 1, year: 1317, month: 4, day: 25, dayOfYear: 115, weekday: 1, weekOfYear: 18, yearForWeekOfYear: 1317, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.coptic, 1700, 2, 28, 23, firstWeekday: 1, minimumDays: 1, era: 1, year: 1416, month: 6, day: 23, dayOfYear: 173, weekday: 1, weekOfYear: 26, yearForWeekOfYear: 1416, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.coptic, 2026, 10, 7, 12, firstWeekday: 1, minimumDays: 1, era: 1, year: 1743, month: 1, day: 27, dayOfYear: 27, weekday: 4, weekOfYear: 5, yearForWeekOfYear: 1743, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.coptic, 2124, 3, 20, 12, firstWeekday: 1, minimumDays: 1, era: 1, year: 1840, month: 7, day: 10, dayOfYear: 190, weekday: 2, weekOfYear: 28, yearForWeekOfYear: 1840, weekOfMonth: 3, weekdayOrdinal: 2),
        KnownDate(.coptic, 2000, 2, 29, 12, firstWeekday: 2, minimumDays: 4, era: 1, year: 1716, month: 6, day: 21, dayOfYear: 171, weekday: 3, weekOfYear: 25, yearForWeekOfYear: 1716, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.ethiopicAmeteMihret, 1600, 12, 31, 0, firstWeekday: 1, minimumDays: 1, era: 1, year: 1593, month: 4, day: 25, dayOfYear: 115, weekday: 1, weekOfYear: 18, yearForWeekOfYear: 1593, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.ethiopicAmeteMihret, 1800, 1, 1, 12, firstWeekday: 1, minimumDays: 1, era: 1, year: 1792, month: 4, day: 24, dayOfYear: 114, weekday: 4, weekOfYear: 17, yearForWeekOfYear: 1792, weekOfMonth: 4, weekdayOrdinal: 4),
        KnownDate(.ethiopicAmeteMihret, 1900, 9, 12, 6, firstWeekday: 1, minimumDays: 1, era: 1, year: 1893, month: 1, day: 2, dayOfYear: 2, weekday: 4, weekOfYear: 1, yearForWeekOfYear: 1893, weekOfMonth: 1, weekdayOrdinal: 1),
        KnownDate(.ethiopicAmeteMihret, 2124, 3, 20, 12, firstWeekday: 1, minimumDays: 1, era: 1, year: 2116, month: 7, day: 10, dayOfYear: 190, weekday: 2, weekOfYear: 28, yearForWeekOfYear: 2116, weekOfMonth: 3, weekdayOrdinal: 2),
        KnownDate(.ethiopicAmeteMihret, 2000, 2, 29, 12, firstWeekday: 2, minimumDays: 4, era: 1, year: 1992, month: 6, day: 21, dayOfYear: 171, weekday: 3, weekOfYear: 25, yearForWeekOfYear: 1992, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.ethiopicAmeteAlem, 1600, 12, 31, 0, firstWeekday: 1, minimumDays: 1, era: 0, year: 7093, month: 4, day: 25, dayOfYear: 115, weekday: 1, weekOfYear: 18, yearForWeekOfYear: 7093, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.ethiopicAmeteAlem, 1700, 2, 28, 23, firstWeekday: 1, minimumDays: 1, era: 0, year: 7192, month: 6, day: 23, dayOfYear: 173, weekday: 1, weekOfYear: 26, yearForWeekOfYear: 7192, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.ethiopicAmeteAlem, 2026, 10, 7, 12, firstWeekday: 1, minimumDays: 1, era: 0, year: 7519, month: 1, day: 27, dayOfYear: 27, weekday: 4, weekOfYear: 5, yearForWeekOfYear: 7519, weekOfMonth: 5, weekdayOrdinal: 4),
        KnownDate(.ethiopicAmeteAlem, 2124, 3, 20, 12, firstWeekday: 1, minimumDays: 1, era: 0, year: 7616, month: 7, day: 10, dayOfYear: 190, weekday: 2, weekOfYear: 28, yearForWeekOfYear: 7616, weekOfMonth: 3, weekdayOrdinal: 2),
        KnownDate(.ethiopicAmeteAlem, 2000, 2, 29, 12, firstWeekday: 2, minimumDays: 4, era: 0, year: 7492, month: 6, day: 21, dayOfYear: 171, weekday: 3, weekOfYear: 25, yearForWeekOfYear: 7492, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.persian, 1600, 12, 31, 0, firstWeekday: 1, minimumDays: 1, era: 0, year: 979, month: 10, day: 11, dayOfYear: 287, weekday: 1, weekOfYear: 42, yearForWeekOfYear: 979, weekOfMonth: 3, weekdayOrdinal: 2),
        KnownDate(.persian, 1700, 2, 28, 23, firstWeekday: 1, minimumDays: 1, era: 0, year: 1078, month: 12, day: 10, dayOfYear: 346, weekday: 1, weekOfYear: 51, yearForWeekOfYear: 1078, weekOfMonth: 3, weekdayOrdinal: 2),
        KnownDate(.persian, 1900, 9, 12, 6, firstWeekday: 1, minimumDays: 1, era: 0, year: 1279, month: 6, day: 21, dayOfYear: 176, weekday: 4, weekOfYear: 26, yearForWeekOfYear: 1279, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.persian, 2000, 2, 29, 12, firstWeekday: 1, minimumDays: 1, era: 0, year: 1378, month: 12, day: 10, dayOfYear: 346, weekday: 3, weekOfYear: 50, yearForWeekOfYear: 1378, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.persian, 2124, 3, 20, 12, firstWeekday: 1, minimumDays: 1, era: 0, year: 1503, month: 1, day: 1, dayOfYear: 1, weekday: 2, weekOfYear: 1, yearForWeekOfYear: 1503, weekOfMonth: 1, weekdayOrdinal: 1),
        KnownDate(.persian, 1600, 12, 31, 0, firstWeekday: 2, minimumDays: 4, era: 0, year: 979, month: 10, day: 11, dayOfYear: 287, weekday: 1, weekOfYear: 41, yearForWeekOfYear: 979, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.persian, 1900, 9, 12, 6, firstWeekday: 2, minimumDays: 4, era: 0, year: 1279, month: 6, day: 21, dayOfYear: 176, weekday: 4, weekOfYear: 26, yearForWeekOfYear: 1279, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.persian, 2100, 3, 1, 12, firstWeekday: 2, minimumDays: 4, era: 0, year: 1478, month: 12, day: 11, dayOfYear: 347, weekday: 2, weekOfYear: 50, yearForWeekOfYear: 1478, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.persian, 2124, 3, 20, 12, firstWeekday: 2, minimumDays: 4, era: 0, year: 1503, month: 1, day: 1, dayOfYear: 1, weekday: 2, weekOfYear: 1, yearForWeekOfYear: 1503, weekOfMonth: 1, weekdayOrdinal: 1),
        KnownDate(.indian, 1900, 9, 12, 6, firstWeekday: 1, minimumDays: 1, era: 0, year: 1822, month: 6, day: 21, dayOfYear: 175, weekday: 4, weekOfYear: 26, yearForWeekOfYear: 1822, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.indian, 2024, 2, 29, 18, firstWeekday: 1, minimumDays: 1, era: 0, year: 1945, month: 12, day: 10, dayOfYear: 345, weekday: 5, weekOfYear: 50, yearForWeekOfYear: 1945, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.indian, 2250, 12, 31, 23, firstWeekday: 1, minimumDays: 1, era: 0, year: 2172, month: 10, day: 10, dayOfYear: 285, weekday: 3, weekOfYear: 42, yearForWeekOfYear: 2172, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.indian, 1800, 1, 1, 12, firstWeekday: 2, minimumDays: 4, era: 0, year: 1721, month: 10, day: 11, dayOfYear: 286, weekday: 4, weekOfYear: 41, yearForWeekOfYear: 1721, weekOfMonth: 2, weekdayOrdinal: 2),
        KnownDate(.indian, 1900, 9, 12, 6, firstWeekday: 2, minimumDays: 4, era: 0, year: 1822, month: 6, day: 21, dayOfYear: 175, weekday: 4, weekOfYear: 26, yearForWeekOfYear: 1822, weekOfMonth: 4, weekdayOrdinal: 3),
        KnownDate(.indian, 2124, 3, 20, 12, firstWeekday: 2, minimumDays: 4, era: 0, year: 2045, month: 12, day: 30, dayOfYear: 365, weekday: 2, weekOfYear: 1, yearForWeekOfYear: 2046, weekOfMonth: 5, weekdayOrdinal: 5),
]

private let yearStarts: [YearStart] = [
        YearStart(.coptic, era: 1, year: 1743, gregorian: (2026, 9, 11)),
        YearStart(.coptic, era: 1, year: 1742, gregorian: (2025, 9, 11)),
        YearStart(.coptic, era: 1, year: 1741, gregorian: (2024, 9, 11)),
        YearStart(.ethiopicAmeteMihret, era: 1, year: 2019, gregorian: (2026, 9, 11)),
        YearStart(.ethiopicAmeteMihret, era: 1, year: 2018, gregorian: (2025, 9, 11)),
        YearStart(.ethiopicAmeteMihret, era: 1, year: 2000, gregorian: (2007, 9, 12)),
        YearStart(.ethiopicAmeteAlem, era: 0, year: 7519, gregorian: (2026, 9, 11)),
        YearStart(.ethiopicAmeteAlem, era: 0, year: 7518, gregorian: (2025, 9, 11)),
        YearStart(.persian, era: 0, year: 1405, gregorian: (2026, 3, 21)),
        YearStart(.persian, era: 0, year: 1501, gregorian: (2122, 3, 21)),
        YearStart(.persian, era: 0, year: 1700, gregorian: (2321, 3, 21)),
        YearStart(.persian, era: 0, year: 2064, gregorian: (2685, 3, 20)),
        YearStart(.persian, era: 0, year: 2987, gregorian: (3608, 3, 20)),
        YearStart(.indian, era: 0, year: 1948, gregorian: (2026, 3, 22)),
        YearStart(.indian, era: 0, year: 1947, gregorian: (2025, 3, 22)),
]

private let monthLengths: [MonthLengths] = [
        MonthLengths(.coptic, era: 1, year: 1742, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 5], yearLength: 365),
        MonthLengths(.coptic, era: 1, year: 1743, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 6], yearLength: 366),
        MonthLengths(.ethiopicAmeteMihret, era: 1, year: 2018, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 5], yearLength: 365),
        MonthLengths(.ethiopicAmeteMihret, era: 1, year: 2019, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 6], yearLength: 366),
        MonthLengths(.ethiopicAmeteAlem, era: 0, year: 7518, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 5], yearLength: 365),
        MonthLengths(.ethiopicAmeteAlem, era: 0, year: 7519, lengths: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 6], yearLength: 366),
        MonthLengths(.persian, era: 0, year: 1403, lengths: [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30], yearLength: 366),
        MonthLengths(.persian, era: 0, year: 1502, lengths: [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29], yearLength: 365),
        MonthLengths(.indian, era: 0, year: 1948, lengths: [30, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30], yearLength: 365),
        MonthLengths(.indian, era: 0, year: 1946, lengths: [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30], yearLength: 366),
        MonthLengths(.indian, era: 0, year: 1947, lengths: [30, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30], yearLength: 365),
]

private let rangeCases: [RangeCase] = [
        RangeCase(.coptic, [(.era, 0..<2, 0..<2), (.year, 1..<5000001, 1..<5000001), (.month, 1..<14, 1..<14), (.day, 1..<6, 1..<31), (.weekday, 1..<8, 1..<8), (.weekdayOrdinal, -1..<2, -1..<6), (.quarter, 1..<5, 1..<5), (.weekOfMonth, 1..<2, 1..<7), (.weekOfYear, 1..<53, 1..<54), (.yearForWeekOfYear, -5000000..<5000001, -5000000..<5000001), (.dayOfYear, 1..<366, 1..<367), (.hour, 0..<24, 0..<24), (.minute, 0..<60, 0..<60), (.second, 0..<60, 0..<60), (.nanosecond, 0..<1000000000, 0..<1000000000), (.isLeapMonth, 0..<1, 0..<1)]),
        RangeCase(.ethiopicAmeteMihret, [(.era, 0..<2, 0..<2), (.year, 1..<5000001, 1..<5000001), (.month, 1..<14, 1..<14), (.day, 1..<6, 1..<31), (.weekday, 1..<8, 1..<8), (.weekdayOrdinal, -1..<2, -1..<6), (.quarter, 1..<5, 1..<5), (.weekOfMonth, 1..<2, 1..<7), (.weekOfYear, 1..<53, 1..<54), (.yearForWeekOfYear, -5000000..<5000001, -5000000..<5000001), (.dayOfYear, 1..<366, 1..<367), (.hour, 0..<24, 0..<24), (.minute, 0..<60, 0..<60), (.second, 0..<60, 0..<60), (.nanosecond, 0..<1000000000, 0..<1000000000), (.isLeapMonth, 0..<1, 0..<1)]),
        RangeCase(.ethiopicAmeteAlem, [(.era, 0..<1, 0..<1), (.year, 1..<5000001, 1..<5000001), (.month, 1..<14, 1..<14), (.day, 1..<6, 1..<31), (.weekday, 1..<8, 1..<8), (.weekdayOrdinal, -1..<2, -1..<6), (.quarter, 1..<5, 1..<5), (.weekOfMonth, 1..<2, 1..<7), (.weekOfYear, 1..<53, 1..<54), (.yearForWeekOfYear, -5000000..<5000001, -5000000..<5000001), (.dayOfYear, 1..<366, 1..<367), (.hour, 0..<24, 0..<24), (.minute, 0..<60, 0..<60), (.second, 0..<60, 0..<60), (.nanosecond, 0..<1000000000, 0..<1000000000), (.isLeapMonth, 0..<1, 0..<1)]),
        RangeCase(.persian, [(.era, 0..<1, 0..<1), (.year, -5000000..<5000001, -5000000..<5000001), (.month, 1..<13, 1..<13), (.day, 1..<30, 1..<32), (.weekday, 1..<8, 1..<8), (.weekdayOrdinal, 1..<6, 1..<6), (.quarter, 1..<5, 1..<5), (.weekOfMonth, 1..<6, 1..<7), (.weekOfYear, 1..<53, 1..<54), (.yearForWeekOfYear, -5000000..<5000001, -5000000..<5000001), (.dayOfYear, 1..<366, 1..<367), (.hour, 0..<24, 0..<24), (.minute, 0..<60, 0..<60), (.second, 0..<60, 0..<60), (.nanosecond, 0..<1000000000, 0..<1000000000), (.isLeapMonth, 0..<1, 0..<1)]),
        RangeCase(.indian, [(.era, 0..<1, 0..<1), (.year, -5000000..<5000001, -5000000..<5000001), (.month, 1..<13, 1..<13), (.day, 1..<31, 1..<32), (.weekday, 1..<8, 1..<8), (.weekdayOrdinal, -1..<6, -1..<6), (.quarter, 1..<5, 1..<5), (.weekOfMonth, 1..<6, 1..<7), (.weekOfYear, 1..<53, 1..<54), (.yearForWeekOfYear, -5000000..<5000001, -5000000..<5000001), (.dayOfYear, 1..<366, 1..<367), (.hour, 0..<24, 0..<24), (.minute, 0..<60, 0..<60), (.second, 0..<60, 0..<60), (.nanosecond, 0..<1000000000, 0..<1000000000), (.isLeapMonth, 0..<1, 0..<1)]),
]

// A month or a day out of range carries into the next or the previous one. A missing field takes the first value.
private let lenientCases: [LenientCase] = [
        LenientCase(.coptic, era: 1, year: 1742, month: 0, day: 1, expected: (1, 1741, 13, 1)),
        LenientCase(.coptic, era: 1, year: 1742, month: 1, day: 30, expected: (1, 1742, 1, 30)),
        LenientCase(.coptic, era: 1, year: 1743, month: 13, day: 6, expected: (1, 1743, 13, 6)),
        LenientCase(.coptic, era: 1, year: 1742, month: 13, day: 31, expected: (1, 1743, 1, 26)),
        LenientCase(.coptic, era: 1, year: nil, month: 3, day: 4, expected: (1, 1, 3, 4)),
        LenientCase(.coptic, era: nil, year: 0, month: 1, day: 1, expected: (0, 1, 1, 1)),
        LenientCase(.coptic, era: 5, year: 5, month: 3, day: 4, expected: nil),
        LenientCase(.coptic, era: 0, year: 1, month: 13, day: 5, expected: (0, 1, 13, 5)),
        LenientCase(.ethiopicAmeteMihret, era: 1, year: 2018, month: 0, day: 1, expected: (1, 2017, 13, 1)),
        LenientCase(.ethiopicAmeteMihret, era: 1, year: 2018, month: 1, day: 30, expected: (1, 2018, 1, 30)),
        LenientCase(.ethiopicAmeteMihret, era: 1, year: 2019, month: 13, day: 6, expected: (1, 2019, 13, 6)),
        LenientCase(.ethiopicAmeteMihret, era: 1, year: 2018, month: 13, day: 31, expected: (1, 2019, 1, 26)),
        LenientCase(.ethiopicAmeteMihret, era: 1, year: nil, month: 3, day: 4, expected: (1, 1, 3, 4)),
        LenientCase(.ethiopicAmeteMihret, era: nil, year: 0, month: 1, day: 1, expected: (0, 5500, 1, 1)),
        LenientCase(.ethiopicAmeteMihret, era: 0, year: 5500, month: 1, day: 1, expected: (0, 5500, 1, 1)),
        LenientCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 0, day: 1, expected: (0, 7517, 13, 1)),
        LenientCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 13, day: 1, expected: (0, 7518, 13, 1)),
        LenientCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 1, day: 32, expected: (0, 7518, 2, 2)),
        LenientCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 13, day: 5, expected: (0, 7518, 13, 5)),
        LenientCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 1, day: 30, expected: (0, 7518, 1, 30)),
        LenientCase(.persian, era: 0, year: 1404, month: 0, day: 1, expected: (0, 1403, 12, 1)),
        LenientCase(.persian, era: 0, year: 1404, month: 1, day: 0, expected: (0, 1403, 12, 30)),
        LenientCase(.persian, era: 0, year: 1404, month: 1, day: -5, expected: (0, 1403, 12, 25)),
        LenientCase(.persian, era: 0, year: 1404, month: 1, day: 99, expected: (0, 1404, 4, 6)),
        LenientCase(.persian, era: 0, year: 1404, month: 1, day: 400, expected: (0, 1405, 2, 4)),
        LenientCase(.persian, era: 0, year: 1403, month: 12, day: 366, expected: (0, 1404, 11, 30)),
        LenientCase(.persian, era: 0, year: 1404, month: 6, day: 31, expected: (0, 1404, 6, 31)),
        LenientCase(.persian, era: 0, year: 1403, month: 6, day: 31, expected: (0, 1403, 6, 31)),
        LenientCase(.persian, era: 0, year: 1404, month: 7, day: 31, expected: (0, 1404, 8, 1)),
        LenientCase(.persian, era: 0, year: 1403, month: 7, day: 31, expected: (0, 1403, 8, 1)),
        LenientCase(.persian, era: nil, year: -1, month: 1, day: 1, expected: (0, -1, 1, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 0, day: 1, expected: (0, 1947, 12, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: -1, day: 1, expected: (0, 1947, 11, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 13, day: 1, expected: (0, 1949, 1, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 14, day: 1, expected: (0, 1949, 2, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 25, day: 1, expected: (0, 1950, 1, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 26, day: 1, expected: (0, 1950, 2, 1)),
        LenientCase(.indian, era: 0, year: 1948, month: 1, day: 30, expected: (0, 1948, 1, 30)),
        LenientCase(.indian, era: 0, year: 1946, month: 12, day: 30, expected: (0, 1946, 12, 30)),
        LenientCase(.indian, era: 0, year: 1946, month: 7, day: 31, expected: (0, 1946, 8, 1)),
]

// The ways to name a day other than year, month and day.
private let formCases: [FormCase] = [
        FormCase(.coptic, era: 1, year: 1743, hour: 12, dayOfYear: 366, expected: (1, 1743, 13, 6)),
        FormCase(.coptic, era: 1, year: 1742, hour: 12, dayOfYear: 366, expected: (1, 1743, 1, 1)),
        FormCase(.coptic, era: 1, year: 1742, month: 13, hour: 12, weekday: 3, weekdayOrdinal: 2, expected: (1, 1743, 1, 5)),
        FormCase(.ethiopicAmeteMihret, era: 1, year: 2019, hour: 12, dayOfYear: 366, expected: (1, 2019, 13, 6)),
        FormCase(.ethiopicAmeteMihret, era: 1, year: 2018, month: 4, hour: 12, weekday: 3, weekOfMonth: 2, expected: (1, 2018, 4, 7)),
        FormCase(.ethiopicAmeteMihret, era: 1, year: 2018, month: 4, hour: 12, weekday: 5, weekOfMonth: 5, expected: (1, 2018, 4, 30)),
        FormCase(.ethiopicAmeteAlem, era: 0, year: 7519, hour: 12, dayOfYear: 366, expected: (0, 7519, 13, 6)),
        FormCase(.ethiopicAmeteAlem, era: 0, year: 7518, month: 4, hour: 12, weekday: 3, weekdayOrdinal: -1, expected: (0, 7518, 4, 28)),
        FormCase(.persian, era: 0, year: 1403, hour: 12, dayOfYear: 366, expected: (0, 1403, 12, 30)),
        FormCase(.persian, era: 0, year: 1404, hour: 12, dayOfYear: 366, expected: (0, 1405, 1, 1)),
        FormCase(.persian, era: 0, year: 1404, month: 4, hour: 12, weekday: 3, weekdayOrdinal: 2, expected: (0, 1404, 4, 10)),
        FormCase(.persian, era: 0, year: 1404, month: 4, hour: 12, weekday: 3, weekdayOrdinal: -1, expected: (0, 1404, 4, 31)),
        FormCase(.persian, hour: 12, weekday: 4, weekOfYear: 5, yearForWeekOfYear: 1404, expected: (0, 1404, 1, 27)),
        FormCase(.persian, hour: 12, weekday: 4, weekOfYear: 0, yearForWeekOfYear: 1404, expected: (0, 1403, 12, 22)),
        FormCase(.indian, era: 0, year: 1946, hour: 12, dayOfYear: 366, expected: (0, 1946, 12, 30)),
        FormCase(.indian, era: 0, year: 1948, hour: 12, dayOfYear: 366, expected: (0, 1949, 1, 1)),
        FormCase(.indian, era: 0, year: 1948, month: 4, hour: 12, weekday: 3, weekdayOrdinal: 2, expected: (0, 1948, 4, 9)),
        FormCase(.indian, era: 0, year: 1948, month: 4, hour: 12, weekday: 3, weekdayOrdinal: -1, expected: (0, 1948, 4, 30)),
        FormCase(.indian, era: 0, year: 1948, hour: 12, weekday: 1, weekOfYear: 53, expected: (0, 1948, 12, 30)),
        FormCase(.indian, hour: 12, weekday: 7, weekOfYear: 1, yearForWeekOfYear: 1946, expected: (0, 1946, 1, 3)),
]

private let addCases: [AddCase] = [
        AddCase(.coptic, (1, 1743, 13, 6), .year, 1, wrapping: false, expected: (1, 1744, 13, 5, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .weekOfYear, 1, wrapping: false, expected: (1, 1744, 1, 7, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .weekOfYear, -2, wrapping: true, expected: (1, 1743, 12, 22, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .weekday, 1, wrapping: true, expected: (1, 1743, 12, 30, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .weekdayOrdinal, 1, wrapping: false, expected: (1, 1744, 1, 7, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .weekdayOrdinal, -2, wrapping: false, expected: (1, 1743, 12, 22, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .dayOfYear, 1, wrapping: true, expected: (1, 1743, 1, 1, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .yearForWeekOfYear, 1, wrapping: false, expected: (1, 1745, 1, 6, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .yearForWeekOfYear, 1, wrapping: true, expected: (1, 1745, 1, 6, 12)),
        AddCase(.coptic, (1, 1743, 13, 6), .hour, 1, wrapping: false, expected: (1, 1743, 13, 6, 13)),
        AddCase(.coptic, (1, 1742, 1, 30), .day, -2, wrapping: true, expected: (1, 1742, 1, 28, 12)),
        AddCase(.coptic, (1, 1742, 1, 30), .weekdayOrdinal, 1, wrapping: true, expected: (1, 1742, 1, 2, 12)),
        AddCase(.coptic, (1, 1742, 1, 30), .weekdayOrdinal, -2, wrapping: true, expected: (1, 1742, 1, 16, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .year, 1, wrapping: true, expected: (1, 2020, 13, 5, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .weekOfYear, 1, wrapping: true, expected: (1, 2019, 1, 2, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .weekOfMonth, 1, wrapping: true, expected: (1, 2019, 13, 6, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .dayOfYear, 1, wrapping: true, expected: (1, 2019, 1, 1, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .yearForWeekOfYear, 1, wrapping: true, expected: (1, 2021, 1, 6, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2019, 13, 6), .hour, 1, wrapping: false, expected: (1, 2019, 13, 6, 13)),
        AddCase(.ethiopicAmeteMihret, (1, 2018, 1, 30), .day, 1, wrapping: true, expected: (1, 2018, 1, 1, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2018, 1, 30), .weekdayOrdinal, 1, wrapping: false, expected: (1, 2018, 2, 7, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2018, 1, 30), .weekdayOrdinal, 1, wrapping: true, expected: (1, 2018, 1, 2, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 2018, 1, 30), .hour, -2, wrapping: true, expected: (1, 2018, 1, 30, 10)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .month, 1, wrapping: false, expected: (0, 7520, 1, 6, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .weekOfYear, -2, wrapping: true, expected: (0, 7519, 12, 22, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .weekOfMonth, 1, wrapping: false, expected: (0, 7520, 1, 7, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .weekOfMonth, 1, wrapping: true, expected: (0, 7519, 13, 6, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .weekday, 1, wrapping: false, expected: (0, 7520, 1, 1, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .dayOfYear, 1, wrapping: false, expected: (0, 7520, 1, 1, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .yearForWeekOfYear, -2, wrapping: false, expected: (0, 7518, 1, 3, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7519, 13, 6), .hour, 1, wrapping: true, expected: (0, 7519, 13, 6, 13)),
        AddCase(.ethiopicAmeteAlem, (0, 7518, 1, 30), .day, -2, wrapping: false, expected: (0, 7518, 1, 28, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7518, 1, 30), .weekdayOrdinal, 1, wrapping: false, expected: (0, 7518, 2, 7, 12)),
        AddCase(.ethiopicAmeteAlem, (0, 7518, 1, 30), .hour, -2, wrapping: true, expected: (0, 7518, 1, 30, 10)),
        AddCase(.persian, (0, 1403, 12, 30), .year, 1, wrapping: false, expected: (0, 1404, 12, 29, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .day, 1, wrapping: false, expected: (0, 1404, 1, 1, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .day, 1, wrapping: true, expected: (0, 1403, 12, 1, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .weekOfYear, 1, wrapping: false, expected: (0, 1404, 1, 7, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .weekOfMonth, -2, wrapping: false, expected: (0, 1403, 12, 16, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .weekday, 1, wrapping: true, expected: (0, 1404, 1, 1, 12)),
        AddCase(.persian, (0, 1403, 12, 30), .yearForWeekOfYear, -2, wrapping: false, expected: (0, 1402, 1, 3, 12)),
        AddCase(.persian, (0, 1404, 1, 30), .day, 1, wrapping: true, expected: (0, 1404, 1, 31, 12)),
        AddCase(.persian, (0, 1404, 1, 30), .weekday, 1, wrapping: true, expected: (0, 1404, 1, 24, 12)),
        AddCase(.persian, (0, 1404, 1, 30), .weekdayOrdinal, 1, wrapping: false, expected: (0, 1404, 2, 6, 12)),
        AddCase(.persian, (0, 1404, 1, 30), .hour, -2, wrapping: true, expected: (0, 1404, 1, 30, 10)),
        AddCase(.indian, (0, 1946, 12, 30), .year, 1, wrapping: false, expected: (0, 1947, 12, 30, 12)),
        AddCase(.indian, (0, 1946, 12, 30), .weekOfYear, 1, wrapping: true, expected: (0, 1946, 1, 2, 12)),
        AddCase(.indian, (0, 1946, 12, 30), .weekOfMonth, 1, wrapping: false, expected: (0, 1947, 1, 7, 12)),
        AddCase(.indian, (0, 1946, 12, 30), .dayOfYear, -2, wrapping: true, expected: (0, 1946, 12, 28, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .month, 1, wrapping: true, expected: (0, 1948, 2, 30, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .month, -2, wrapping: false, expected: (0, 1947, 11, 30, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .month, -2, wrapping: true, expected: (0, 1948, 11, 30, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .day, 1, wrapping: false, expected: (0, 1948, 2, 1, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .weekday, -2, wrapping: true, expected: (0, 1948, 2, 5, 12)),
        AddCase(.indian, (0, 1948, 1, 30), .hour, -2, wrapping: false, expected: (0, 1948, 1, 30, 10)),
        AddCase(.coptic, (0, 1, 13, 5), .year, 1, wrapping: true, expected: (0, 1, 13, 5, 12)),
        AddCase(.coptic, (0, 1, 13, 5), .year, 10, wrapping: true, expected: (0, 1, 13, 5, 12)),
        AddCase(.coptic, (0, 1, 13, 5), .year, -10, wrapping: true, expected: (0, 11, 13, 5, 12)),
        AddCase(.ethiopicAmeteMihret, (1, 1, 1, 1), .year, -1, wrapping: false, expected: (0, 5500, 1, 1, 12)),
        AddCase(.ethiopicAmeteMihret, (0, 5500, 13, 5), .day, 1, wrapping: true, expected: (0, 5500, 13, 1, 12)),
]

private let intervalCases: [IntervalCase] = [
        IntervalCase(.coptic, (2026, 10, 7), .year, start: (2026, 9, 11), end: (2027, 9, 12)),
        IntervalCase(.coptic, (2026, 10, 7), .weekOfYear, start: (2026, 10, 4), end: (2026, 10, 11)),
        IntervalCase(.coptic, (2026, 10, 7), .weekOfMonth, start: (2026, 10, 4), end: (2026, 10, 11)),
        IntervalCase(.coptic, (2026, 10, 7), .yearForWeekOfYear, start: (2026, 9, 6), end: (2027, 9, 12)),
        IntervalCase(.coptic, (2027, 9, 9), .yearForWeekOfYear, start: (2026, 9, 6), end: (2027, 9, 12)),
        IntervalCase(.ethiopicAmeteMihret, (2026, 10, 7), .year, start: (2026, 9, 11), end: (2027, 9, 12)),
        IntervalCase(.ethiopicAmeteMihret, (2026, 10, 7), .weekOfMonth, start: (2026, 10, 4), end: (2026, 10, 11)),
        IntervalCase(.ethiopicAmeteMihret, (2026, 10, 7), .day, start: (2026, 10, 7), end: (2026, 10, 8)),
        IntervalCase(.ethiopicAmeteAlem, (2026, 10, 7), .year, start: (2026, 9, 11), end: (2027, 9, 12)),
        IntervalCase(.ethiopicAmeteAlem, (2026, 10, 7), .weekOfMonth, start: (2026, 10, 4), end: (2026, 10, 11)),
        IntervalCase(.ethiopicAmeteAlem, (2027, 9, 9), .year, start: (2026, 9, 11), end: (2027, 9, 12)),
        IntervalCase(.persian, (2026, 10, 7), .year, start: (2026, 3, 21), end: (2027, 3, 21)),
        IntervalCase(.persian, (2026, 10, 7), .month, start: (2026, 9, 23), end: (2026, 10, 23)),
        IntervalCase(.persian, (2027, 9, 9), .quarter, start: (2027, 6, 22), end: (2027, 9, 23)),
        IntervalCase(.persian, (2027, 9, 9), .month, start: (2027, 8, 23), end: (2027, 9, 23)),
        IntervalCase(.persian, (2027, 9, 9), .weekOfYear, start: (2027, 9, 5), end: (2027, 9, 12)),
        IntervalCase(.indian, (2026, 10, 7), .quarter, start: (2026, 9, 23), end: (2026, 12, 22)),
        IntervalCase(.indian, (2026, 10, 7), .month, start: (2026, 9, 23), end: (2026, 10, 23)),
        IntervalCase(.indian, (2027, 9, 9), .quarter, start: (2027, 6, 22), end: (2027, 9, 23)),
        IntervalCase(.indian, (2027, 9, 9), .month, start: (2027, 8, 23), end: (2027, 9, 23)),
]

private let ordinalityCases: [OrdinalityCase] = [
        OrdinalityCase(.coptic, (2026, 10, 7), .day, in: .month, range: 1..<31, ordinality: 27),
        OrdinalityCase(.coptic, (2026, 10, 7), .day, in: .year, range: 1..<367, ordinality: 27),
        OrdinalityCase(.coptic, (2026, 10, 7), .quarter, in: .year, range: 1..<5, ordinality: 1),
        OrdinalityCase(.coptic, (2026, 10, 7), .weekOfYear, in: .year, range: 1..<54, ordinality: 5),
        OrdinalityCase(.coptic, (2027, 9, 8), .day, in: .month, range: 1..<7, ordinality: 3),
        OrdinalityCase(.coptic, (2027, 9, 8), .day, in: .weekOfMonth, range: 1..<7, ordinality: 4),
        OrdinalityCase(.coptic, (2025, 9, 12), .day, in: .year, range: 1..<366, ordinality: 2),
        OrdinalityCase(.coptic, (2025, 9, 12), .weekOfYear, in: .year, range: 1..<54, ordinality: 1),
        OrdinalityCase(.ethiopicAmeteMihret, (2026, 10, 7), .month, in: .year, range: 1..<14, ordinality: 1),
        OrdinalityCase(.ethiopicAmeteMihret, (2026, 10, 7), .weekOfYear, in: .year, range: 1..<54, ordinality: 5),
        OrdinalityCase(.ethiopicAmeteMihret, (2026, 10, 7), .day, in: .quarter, range: 1..<91, ordinality: 27),
        OrdinalityCase(.ethiopicAmeteMihret, (2026, 9, 8), .day, in: .year, range: 1..<366, ordinality: 363),
        OrdinalityCase(.ethiopicAmeteMihret, (2025, 9, 12), .weekOfYear, in: .year, range: 1..<54, ordinality: 1),
        OrdinalityCase(.ethiopicAmeteAlem, (2026, 10, 7), .day, in: .year, range: 1..<367, ordinality: 27),
        OrdinalityCase(.ethiopicAmeteAlem, (2026, 10, 7), .year, in: .era, range: 1..<5000001, ordinality: 7519),
        OrdinalityCase(.ethiopicAmeteAlem, (2027, 9, 8), .day, in: .year, range: 1..<367, ordinality: 363),
        OrdinalityCase(.ethiopicAmeteAlem, (2026, 9, 8), .quarter, in: .year, range: 1..<5, ordinality: 4),
        OrdinalityCase(.ethiopicAmeteAlem, (2025, 9, 12), .day, in: .quarter, range: 1..<91, ordinality: 2),
        OrdinalityCase(.persian, (2026, 10, 7), .day, in: .month, range: 1..<31, ordinality: 15),
        OrdinalityCase(.persian, (2026, 10, 7), .weekOfMonth, in: .month, range: 1..<6, ordinality: 3),
        OrdinalityCase(.persian, (2025, 2, 21), .day, in: .month, range: 1..<31, ordinality: 3),
        OrdinalityCase(.persian, (2025, 2, 21), .weekOfYear, in: .year, range: 1..<54, ordinality: 49),
        OrdinalityCase(.persian, (2026, 2, 22), .day, in: .month, range: 1..<30, ordinality: 3),
        OrdinalityCase(.persian, (2026, 2, 22), .year, in: .era, range: -5000000..<5000001, ordinality: 1404),
        OrdinalityCase(.persian, (2025, 3, 22), .day, in: .weekOfMonth, range: 1..<3, ordinality: 7),
        OrdinalityCase(.persian, (2025, 3, 22), .day, in: .quarter, range: 1..<94, ordinality: 2),
        OrdinalityCase(.indian, (2026, 10, 7), .weekOfYear, in: .year, range: 1..<54, ordinality: 29),
        OrdinalityCase(.indian, (2026, 10, 7), .day, in: .weekOfMonth, range: 12..<19, ordinality: 4),
        OrdinalityCase(.indian, (2026, 10, 7), .day, in: .quarter, range: 1..<91, ordinality: 15),
        OrdinalityCase(.indian, (2025, 2, 22), .day, in: .month, range: 1..<31, ordinality: 3),
        OrdinalityCase(.indian, (2025, 2, 22), .month, in: .quarter, range: 10..<13, ordinality: 3),
        OrdinalityCase(.indian, (2027, 2, 22), .month, in: .quarter, range: 10..<13, ordinality: 3),
        OrdinalityCase(.indian, (2027, 2, 22), .day, in: .quarter, range: 1..<91, ordinality: 63),
        OrdinalityCase(.indian, (2026, 3, 23), .day, in: .month, range: 1..<31, ordinality: 2),
        OrdinalityCase(.indian, (2026, 3, 23), .month, in: .quarter, range: 1..<4, ordinality: 1),
]

private let differenceCases: [DifferenceCase] = [
        DifferenceCase(.coptic, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 3), (.month, 1), (.weekOfMonth, 0), (.day, 0), (.hour, 17)]),
        DifferenceCase(.coptic, (2024, 9, 1, 12), (2027, 9, 12, 5), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, 3), (.weekOfYear, 1), (.weekday, 6)]),
        DifferenceCase(.coptic, (2024, 9, 1, 12), (2027, 9, 12, 5), [.dayOfYear, .month, .quarter, .weekdayOrdinal], expected: [(.quarter, 0), (.month, 40), (.dayOfYear, 0), (.weekdayOrdinal, 0)]),
        DifferenceCase(.coptic, (2026, 3, 20, 0), (2026, 3, 22, 23), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 0), (.month, 0), (.weekOfMonth, 0), (.day, 2), (.hour, 23)]),
        DifferenceCase(.coptic, (1900, 1, 1, 1), (2026, 10, 7, 12), [.day, .year], expected: [(.year, 126), (.day, 279)]),
        DifferenceCase(.ethiopicAmeteMihret, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 3), (.month, 1), (.weekOfMonth, 0), (.day, 0), (.hour, 17)]),
        DifferenceCase(.ethiopicAmeteMihret, (2024, 9, 1, 12), (2027, 9, 12, 5), [.dayOfYear, .month, .quarter, .weekdayOrdinal], expected: [(.quarter, 0), (.month, 40), (.dayOfYear, 0), (.weekdayOrdinal, 0)]),
        DifferenceCase(.ethiopicAmeteMihret, (2027, 9, 12, 5), (2024, 9, 1, 12), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, -3), (.month, -1), (.weekOfMonth, 0), (.day, -4), (.hour, -17)]),
        DifferenceCase(.ethiopicAmeteMihret, (2026, 3, 20, 0), (2026, 3, 22, 23), [.day, .year], expected: [(.year, 0), (.day, 2)]),
        DifferenceCase(.ethiopicAmeteMihret, (2026, 10, 7, 12), (1900, 1, 1, 1), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, -126), (.weekOfYear, -40), (.weekday, -2)]),
        DifferenceCase(.ethiopicAmeteAlem, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 3), (.month, 1), (.weekOfMonth, 0), (.day, 0), (.hour, 17)]),
        DifferenceCase(.ethiopicAmeteAlem, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .year], expected: [(.year, 3), (.day, 10)]),
        DifferenceCase(.ethiopicAmeteAlem, (2027, 9, 12, 5), (2024, 9, 1, 12), [.dayOfYear, .month, .quarter, .weekdayOrdinal], expected: [(.quarter, 0), (.month, -40), (.dayOfYear, -4), (.weekdayOrdinal, 0)]),
        DifferenceCase(.ethiopicAmeteAlem, (1900, 1, 1, 1), (2026, 10, 7, 12), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, 126), (.weekOfYear, 40), (.weekday, 2)]),
        DifferenceCase(.persian, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 3), (.month, 0), (.weekOfMonth, 1), (.day, 2), (.hour, 17)]),
        DifferenceCase(.persian, (2027, 9, 12, 5), (2024, 9, 1, 12), [.dayOfYear, .month, .quarter, .weekdayOrdinal], expected: [(.quarter, 0), (.month, -36), (.dayOfYear, -9), (.weekdayOrdinal, 0)]),
        DifferenceCase(.persian, (1900, 1, 1, 1), (2026, 10, 7, 12), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, 126), (.weekOfYear, 40), (.weekday, 2)]),
        DifferenceCase(.persian, (2026, 10, 7, 12), (1900, 1, 1, 1), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, -126), (.month, -9), (.weekOfMonth, 0), (.day, -4), (.hour, -11)]),
        DifferenceCase(.persian, (2026, 10, 7, 12), (1900, 1, 1, 1), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, -126), (.weekOfYear, -40), (.weekday, -2)]),
        DifferenceCase(.indian, (2024, 9, 1, 12), (2027, 9, 12, 5), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 3), (.month, 0), (.weekOfMonth, 1), (.day, 3), (.hour, 17)]),
        DifferenceCase(.indian, (2024, 9, 1, 12), (2027, 9, 12, 5), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, 3), (.weekOfYear, 0), (.weekday, 6)]),
        DifferenceCase(.indian, (2027, 9, 12, 5), (2024, 9, 1, 12), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, -3), (.month, 0), (.weekOfMonth, -1), (.day, -3), (.hour, -17)]),
        DifferenceCase(.indian, (2026, 3, 20, 0), (2026, 3, 22, 23), [.day, .year], expected: [(.year, 0), (.day, 2)]),
        DifferenceCase(.indian, (1900, 1, 1, 1), (2026, 10, 7, 12), [.day, .era, .hour, .month, .weekOfMonth, .year], expected: [(.era, 0), (.year, 126), (.month, 9), (.weekOfMonth, 0), (.day, 4), (.hour, 11)]),
        DifferenceCase(.indian, (1900, 1, 1, 1), (2026, 10, 7, 12), [.weekOfYear, .weekday, .yearForWeekOfYear], expected: [(.yearForWeekOfYear, 126), (.weekOfYear, 40), (.weekday, 2)]),
]

private let searchCases: [SearchCase] = [
        SearchCase(.coptic, DateComponents(month: 13, day: 1), .strict, .forward, expected: (2027, 9, 6, 0)),
        SearchCase(.coptic, DateComponents(month: 13, day: 6), .strict, .forward, expected: (2027, 9, 11, 0)),
        SearchCase(.coptic, DateComponents(month: 13, day: 6), .nextTime, .forward, expected: (2027, 9, 11, 0)),
        SearchCase(.ethiopicAmeteMihret, DateComponents(month: 13, day: 1), .strict, .backward, expected: (2026, 9, 6, 0)),
        SearchCase(.ethiopicAmeteMihret, DateComponents(month: 13, day: 1), .nextTime, .backward, expected: (2026, 9, 6, 0)),
        SearchCase(.ethiopicAmeteMihret, DateComponents(day: 30), .strict, .forward, expected: (2026, 10, 10, 0)),
        SearchCase(.ethiopicAmeteAlem, DateComponents(month: 13, day: 1), .strict, .forward, expected: (2027, 9, 6, 0)),
        SearchCase(.ethiopicAmeteAlem, DateComponents(day: 30), .strict, .backward, expected: nil),
        SearchCase(.ethiopicAmeteAlem, DateComponents(day: 30), .nextTime, .forward, expected: (2026, 10, 10, 0)),
        SearchCase(.persian, DateComponents(month: 12, day: 1), .strict, .forward, expected: (2027, 2, 20, 0)),
        SearchCase(.persian, DateComponents(month: 12, day: 1), .nextTime, .forward, expected: (2027, 2, 20, 0)),
        SearchCase(.persian, DateComponents(day: 30), .strict, .backward, expected: (2026, 9, 21, 0)),
        SearchCase(.persian, DateComponents(day: 30), .nextTime, .backward, expected: (2026, 9, 21, 0)),
        SearchCase(.persian, DateComponents(month: 2, day: 30), .nextTime, .forward, expected: (2027, 5, 20, 0)),
        SearchCase(.indian, DateComponents(month: 12, day: 1), .strict, .backward, expected: (2026, 2, 20, 0)),
        SearchCase(.indian, DateComponents(month: 12, day: 1), .nextTime, .backward, expected: (2026, 2, 20, 0)),
        SearchCase(.indian, DateComponents(day: 30), .strict, .backward, expected: (2026, 9, 21, 0)),
        SearchCase(.indian, DateComponents(day: 30), .nextTime, .backward, expected: (2026, 9, 21, 0)),
        SearchCase(.indian, DateComponents(month: 2, day: 30), .strict, .forward, expected: (2027, 5, 20, 0)),
        SearchCase(.indian, DateComponents(month: 2, day: 30), .nextTime, .forward, expected: (2027, 5, 20, 0)),
]

private let ancientCases: [AncientCase] = [
        AncientCase(.coptic, rataDie: -2100000, expected: (0, 6034, 11, 15)),
        AncientCase(.coptic, rataDie: -1800000, expected: (0, 5212, 3, 19)),
        AncientCase(.coptic, rataDie: -1000000, expected: (0, 3022, 7, 2)),
        AncientCase(.ethiopicAmeteMihret, rataDie: -2100000, expected: (0, -257, 11, 15)),
        AncientCase(.ethiopicAmeteMihret, rataDie: -200000, expected: (0, 4945, 10, 14)),
        AncientCase(.ethiopicAmeteMihret, rataDie: 100000, expected: (1, 267, 2, 19)),
        AncientCase(.ethiopicAmeteAlem, rataDie: -2100000, expected: (0, -257, 11, 15)),
        AncientCase(.ethiopicAmeteAlem, rataDie: -1000000, expected: (0, 2755, 7, 2)),
        AncientCase(.persian, rataDie: -2100000, expected: (0, -6370, 3, 3)),
        AncientCase(.persian, rataDie: -1800000, expected: (0, -5549, 7, 15)),
        AncientCase(.persian, rataDie: -1000000, expected: (0, -3359, 11, 14)),
        AncientCase(.indian, rataDie: -2100000, expected: (0, -5827, 3, 4)),
        AncientCase(.indian, rataDie: -1800000, expected: (0, -5006, 7, 15)),
        AncientCase(.indian, rataDie: -200000, expected: (0, -625, 3, 12)),
        AncientCase(.indian, rataDie: 100000, expected: (0, 196, 7, 24)),
]
