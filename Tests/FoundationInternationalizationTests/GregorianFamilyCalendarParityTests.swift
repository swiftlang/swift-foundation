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

/// The three calendars that share the era-table engine over `_CalendarGregorian`.
private enum GregorianCalendarFamily: String, Sendable, CaseIterable, CustomTestStringConvertible {
    case buddhist, japanese, roc

    var identifier: Calendar.Identifier {
        switch self {
        case .buddhist: return .buddhist
        case .japanese: return .japanese
        case .roc: return .republicOfChina
        }
    }

    var ours: Calendar {
        let inner: any _CalendarProtocol
        switch self {
        case .buddhist: inner = _CalendarGregorian(identifier: .buddhist, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        case .japanese: inner = _CalendarGregorian(identifier: .japanese, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        case .roc: inner = _CalendarGregorian(identifier: .republicOfChina, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        }
        return Calendar(inner: inner)
    }

    func calendar(firstWeekday: Int?, minimumDaysInFirstWeek: Int?) -> Calendar {
        let inner: any _CalendarProtocol
        switch self {
        case .buddhist: inner = _CalendarGregorian(identifier: .buddhist, timeZone: .gmt, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        case .japanese: inner = _CalendarGregorian(identifier: .japanese, timeZone: .gmt, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        case .roc: inner = _CalendarGregorian(identifier: .republicOfChina, timeZone: .gmt, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
        }
        return Calendar(inner: inner)
    }

    var icu: Calendar {
        Calendar(inner: _CalendarICU(identifier: identifier, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
    }

    var testDescription: String { rawValue }
}

/// A Gregorian date to probe, given as an era plus an era-relative year so dates before the Common Era are reachable.
private struct GregorianFamilyProbe: Sendable, CustomTestStringConvertible {
    let label: String
    let era, year, month, day: Int
    /// True for dates the Japanese calendar deliberately labels differently from the bundled ICU.
    let isPreMeiji: Bool
    /// True where our Japanese era ends at the next era's real start rather than where ICU's era-field arithmetic lands.
    let endsInsideABoundedJapaneseEra: Bool

    init(_ label: String, era: Int, year: Int, month: Int, day: Int, isPreMeiji: Bool = false, endsInsideABoundedJapaneseEra: Bool = false) {
        self.label = label
        self.era = era; self.year = year; self.month = month; self.day = day
        self.isPreMeiji = isPreMeiji
        self.endsInsideABoundedJapaneseEra = endsInsideABoundedJapaneseEra
    }

    var testDescription: String { label }

    var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.era = era; components.year = year; components.month = month; components.day = day
        components.hour = 12; components.timeZone = .gmt
        guard let date = calendar.date(from: components) else {
            preconditionFailure("invalid Gregorian probe date \(label)")
        }
        return date
    }
}

private let gregorianFamilyProbes: [GregorianFamilyProbe] = [
    GregorianFamilyProbe("2025-08-20", era: 1, year: 2025, month: 8, day: 20),
    GregorianFamilyProbe("2019-05-01 Reiwa start", era: 1, year: 2019, month: 5, day: 1),
    GregorianFamilyProbe("2019-04-30 Heisei end", era: 1, year: 2019, month: 4, day: 30, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1989-01-08 Heisei start", era: 1, year: 1989, month: 1, day: 8, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1926-12-25 Showa start", era: 1, year: 1926, month: 12, day: 25, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1912-07-30 Taisho start", era: 1, year: 1912, month: 7, day: 30, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1912-01-01 Minguo 1", era: 1, year: 1912, month: 1, day: 1, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1911-12-31 before Minguo", era: 1, year: 1911, month: 12, day: 31, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1868-09-08 Meiji start", era: 1, year: 1868, month: 9, day: 8, endsInsideABoundedJapaneseEra: true),
    GregorianFamilyProbe("1868-09-07 before Meiji", era: 1, year: 1868, month: 9, day: 7, isPreMeiji: true),
    GregorianFamilyProbe("1600-01-15", era: 1, year: 1600, month: 1, day: 15, isPreMeiji: true),
    GregorianFamilyProbe("0900-06-15", era: 1, year: 900, month: 6, day: 15, isPreMeiji: true),
    GregorianFamilyProbe("0001-01-01", era: 1, year: 1, month: 1, day: 1, isPreMeiji: true),
    GregorianFamilyProbe("1 BCE", era: 0, year: 1, month: 6, day: 15, isPreMeiji: true),
    GregorianFamilyProbe("15 BCE", era: 0, year: 15, month: 7, day: 10, isPreMeiji: true),
    GregorianFamilyProbe("543 BCE", era: 0, year: 543, month: 3, day: 1, isPreMeiji: true),
    GregorianFamilyProbe("544 BCE", era: 0, year: 544, month: 3, day: 1, isPreMeiji: true),
    GregorianFamilyProbe("1000 BCE", era: 0, year: 1000, month: 5, day: 5, isPreMeiji: true),
]

/// Parity tests for the three Gregorian-family calendars against ICU. They share one era-table engine, so a divergence in any one of them usually means the engine is wrong rather than the calendar.
///
/// The Japanese calendar labels two sets of dates differently on purpose, so those dates are skipped here and pinned by golden values in `JapaneseGregorianEraInheritanceTests` instead.
///
/// It drops the pre-Meiji eras (unicode-org/icu#4019, ICU-23341), and it ends an era where the next era really starts.
@Suite("Gregorian Family Calendar Parity")
private struct GregorianFamilyCalendarParityTests {

    /// Reading the era and year off a date must match ICU, including dates before the Common Era. The Buddhist year is an offset from the extended Gregorian year, not from the year counted inside the era.
    @Test(arguments: GregorianCalendarFamily.allCases, gregorianFamilyProbes)
    func eraAndYearMatchICU(_ family: GregorianCalendarFamily, _ probe: GregorianFamilyProbe) {
        guard !(family == .japanese && probe.isPreMeiji) else { return }
        let ours = family.ours.dateComponents([.era, .year, .month, .day], from: probe.date)
        let icu = family.icu.dateComponents([.era, .year, .month, .day], from: probe.date)
        #expect(ours.era == icu.era)
        #expect(ours.year == icu.year)
        #expect(ours.month == icu.month)
        #expect(ours.day == icu.day)
    }

    /// Building a date from this calendar's own era and year must match ICU.
    @Test(arguments: GregorianCalendarFamily.allCases, gregorianFamilyProbes)
    func dateFromComponentsMatchesICU(_ family: GregorianCalendarFamily, _ probe: GregorianFamilyProbe) {
        guard !(family == .japanese && probe.isPreMeiji) else { return }
        // Read the native era and year off ICU, then ask both calendars to rebuild the date from them.
        let native = family.icu.dateComponents([.era, .year, .month, .day], from: probe.date)
        var components = DateComponents()
        components.era = native.era; components.year = native.year
        components.month = native.month; components.day = native.day; components.hour = 12
        #expect(family.ours.date(from: components) == family.icu.date(from: components))
    }

    @Test(arguments: GregorianCalendarFamily.allCases, gregorianFamilyProbes)
    func eraIntervalMatchesICU(_ family: GregorianCalendarFamily, _ probe: GregorianFamilyProbe) {
        guard !(family == .japanese && (probe.isPreMeiji || probe.endsInsideABoundedJapaneseEra)) else { return }
        #expect(family.ours.dateInterval(of: .era, for: probe.date) == family.icu.dateInterval(of: .era, for: probe.date))
    }

    @Test(arguments: GregorianCalendarFamily.allCases, [Calendar.Component.era, .year, .month, .day, .weekday, .quarter, .weekOfMonth, .weekOfYear, .dayOfYear])
    func componentRangesMatchICU(_ family: GregorianCalendarFamily, _ component: Calendar.Component) {
        #expect(family.ours.minimumRange(of: component) == family.icu.minimumRange(of: component))
        #expect(family.ours.maximumRange(of: component) == family.icu.maximumRange(of: component))
    }

    /// Adding to `.era` does not move the date, because the Gregorian engine ignores the era field for compatibility.
    @Test(arguments: GregorianCalendarFamily.allCases, gregorianFamilyProbes)
    func addingEraDoesNotMoveTheDate(_ family: GregorianCalendarFamily, _ probe: GregorianFamilyProbe) {
        let calendar = family.ours
        #expect(calendar.date(byAdding: .era, value: 1, to: probe.date) == probe.date)
        #expect(calendar.date(byAdding: .era, value: -1, to: probe.date) == probe.date)
    }
}

/// Golden values for the ROC calendar's backward-counting Before-Minguo era, which no other calendar in the family exercises.
@Suite("ROC Backward Era")
private struct ROCBackwardEraTests {

    static let beforeMinguo = 0, minguo = 1

    private static func roc() -> Calendar {
        Calendar(inner: _CalendarGregorian(identifier: .republicOfChina, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
    }

    struct EraCase: Sendable, CustomTestStringConvertible {
        let label: String
        let gregorianEra, gregorianYear, month, day: Int
        let expectedEra, expectedYear: Int
        var testDescription: String { label }

        var date: Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            var components = DateComponents()
            components.era = gregorianEra; components.year = gregorianYear
            components.month = month; components.day = day
            components.hour = 12; components.timeZone = .gmt
            guard let date = calendar.date(from: components) else {
                preconditionFailure("invalid Gregorian date for \(label)")
            }
            return date
        }
    }

    static let eraCases: [EraCase] = [
        EraCase(label: "2025 is Minguo 114", gregorianEra: 1, gregorianYear: 2025, month: 8, day: 20, expectedEra: minguo, expectedYear: 114),
        EraCase(label: "1912-01-01 is Minguo 1", gregorianEra: 1, gregorianYear: 1912, month: 1, day: 1, expectedEra: minguo, expectedYear: 1),
        EraCase(label: "1911-12-31 is Before-Minguo 1", gregorianEra: 1, gregorianYear: 1911, month: 12, day: 31, expectedEra: beforeMinguo, expectedYear: 1),
        EraCase(label: "1911-01-01 is Before-Minguo 1", gregorianEra: 1, gregorianYear: 1911, month: 1, day: 1, expectedEra: beforeMinguo, expectedYear: 1),
        EraCase(label: "1812 is Before-Minguo 100", gregorianEra: 1, gregorianYear: 1812, month: 5, day: 5, expectedEra: beforeMinguo, expectedYear: 100),
        EraCase(label: "1 CE is Before-Minguo 1911", gregorianEra: 1, gregorianYear: 1, month: 1, day: 1, expectedEra: beforeMinguo, expectedYear: 1911),
        EraCase(label: "1 BCE is Before-Minguo 1912", gregorianEra: 0, gregorianYear: 1, month: 6, day: 15, expectedEra: beforeMinguo, expectedYear: 1912),
    ]

    @Test(arguments: eraCases)
    func eraAndYear(_ eraCase: EraCase) {
        let components = Self.roc().dateComponents([.era, .year], from: eraCase.date)
        #expect(components.era == eraCase.expectedEra)
        #expect(components.year == eraCase.expectedYear)
    }

    @Test(arguments: eraCases)
    func roundTrip(_ eraCase: EraCase) {
        var components = DateComponents()
        components.era = eraCase.expectedEra; components.year = eraCase.expectedYear
        components.month = eraCase.month; components.day = eraCase.day; components.hour = 12
        #expect(Self.roc().date(from: components) == eraCase.date)
    }

    /// Crossing the 1912 boundary downward moves into the backward-counting era, so the year goes from 1 to 1 rather than from 1 to 0.
    @Test func subtractingAcrossTheMinguoBoundary() throws {
        let calendar = Self.roc()
        var components = DateComponents()
        components.era = Self.minguo; components.year = 1; components.month = 1; components.day = 1; components.hour = 12
        let minguoDayOne = try #require(calendar.date(from: components))
        let dayBefore = try #require(calendar.date(byAdding: .day, value: -1, to: minguoDayOne))
        let back = calendar.dateComponents([.era, .year, .month, .day], from: dayBefore)
        #expect(back.era == Self.beforeMinguo)
        #expect(back.year == 1)
        #expect(back.month == 12)
        #expect(back.day == 31)
    }
}

/// Parity for the `DateComponents` forms that PR #2165 found broken in the Hebrew and Chinese calendars.
///
/// Those forms are the week-year one, `range(of: .day, in: .weekOfMonth)`, a month roll past the end of the year, the year-anchored forms, and a missing year.
///
/// These three calendars hand all of that to `_CalendarGregorian`, so most of it works by delegation. A missing year did not: see `dateFromWithNoYearUsesEraYearOne`.
@Suite("Gregorian Family Component Form Parity")
private struct GregorianFamilyComponentFormParityTests {

    /// Dates chosen to sit in different eras of each calendar, including two era boundaries.
    static let dates: [(label: String, date: Date)] = [
        ("2025-08-20", gregorianDate(2025, 8, 20)),
        ("2025-12-15", gregorianDate(2025, 12, 15)),
        ("2019-05-01 Reiwa start", gregorianDate(2019, 5, 1)),
        ("1912-01-01 Minguo 1", gregorianDate(1912, 1, 1)),
        ("1911-06-30 before Minguo", gregorianDate(1911, 6, 30)),
    ]

    private static func gregorianDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(timeZone: .gmt, year: year, month: month, day: day, hour: 12)) else {
            preconditionFailure("invalid Gregorian probe date \(year)-\(month)-\(day)")
        }
        return date
    }

    /// ICU leaves `.yearForWeekOfYear` as the Gregorian year even where it relabels `.year`, so a Buddhist date reports year 2568 next to yearForWeekOfYear 2025. Odd, but it is what ICU does.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func weekYearFieldsMatchICU(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        let ours = family.ours.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: probe.date)
        let icu = family.icu.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: probe.date)
        #expect(ours.yearForWeekOfYear == icu.yearForWeekOfYear)
        #expect(ours.weekOfYear == icu.weekOfYear)
        #expect(ours.weekday == icu.weekday)
    }

    /// The week-year form of `date(from:)`, which #2165 fixed for Hebrew and Chinese.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func dateFromWeekYearFormMatchesICU(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        let native = family.icu.dateComponents([.era, .yearForWeekOfYear, .weekOfYear, .weekday], from: probe.date)
        var components = DateComponents()
        components.era = native.era; components.yearForWeekOfYear = native.yearForWeekOfYear
        components.weekOfYear = native.weekOfYear; components.weekday = native.weekday; components.hour = 12
        #expect(family.ours.date(from: components) == family.icu.date(from: components))
    }

    /// `range(of: .day, in: .weekOfMonth)` returned nil for Chinese before #2165.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func rangeOfDayInWeekOfMonthMatchesICU(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        let ours = family.ours.range(of: .day, in: .weekOfMonth, for: probe.date)
        #expect(ours == family.icu.range(of: .day, in: .weekOfMonth, for: probe.date))
        #expect(ours != nil)
    }

    /// Rolling `.month` past December carried into the year for Chinese before #2165. A roll must stay inside the year.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func rollingMonthMatchesICU(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        for amount in [1, -1, 5] {
            let ours = family.ours.date(byAdding: .month, value: amount, to: probe.date, wrappingComponents: true)
            #expect(ours == family.icu.date(byAdding: .month, value: amount, to: probe.date, wrappingComponents: true), "\(probe.label) roll \(amount)")
        }
    }

    /// The year-anchored forms, never checked in Hebrew or Chinese and flagged as a likely repeat of the week-year gap.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func yearAnchoredFormsMatchICU(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        let native = family.icu.dateComponents([.era, .year, .month, .weekday, .weekdayOrdinal, .dayOfYear], from: probe.date)

        var weekdayOrdinalForm = DateComponents()
        weekdayOrdinalForm.era = native.era; weekdayOrdinalForm.year = native.year; weekdayOrdinalForm.month = native.month
        weekdayOrdinalForm.weekday = native.weekday; weekdayOrdinalForm.weekdayOrdinal = native.weekdayOrdinal; weekdayOrdinalForm.hour = 12
        #expect(family.ours.date(from: weekdayOrdinalForm) == family.icu.date(from: weekdayOrdinalForm), "\(probe.label) weekdayOrdinal form")

        var dayOfYearForm = DateComponents()
        dayOfYearForm.era = native.era; dayOfYearForm.year = native.year
        dayOfYearForm.dayOfYear = native.dayOfYear; dayOfYearForm.hour = 12
        #expect(family.ours.date(from: dayOfYearForm) == family.icu.date(from: dayOfYearForm), "\(probe.label) dayOfYear form")
    }

    /// A `DateComponents` with no year must fall back to year 1 of this calendar's own era, not to Gregorian year 1. Buddhist lands in 543 BCE, Japanese in Reiwa 1, ROC in Minguo 1.
    @Test(arguments: GregorianCalendarFamily.allCases)
    func dateFromWithNoYearUsesEraYearOne(_ family: GregorianCalendarFamily) {
        var components = DateComponents()
        components.month = 6; components.day = 15; components.hour = 12
        #expect(family.ours.date(from: components) == family.icu.date(from: components))
    }
}

/// Parity for units counted inside an era. The engine counts these from this calendar's era start, where delegating to `_CalendarGregorian` would count from the Gregorian one.
@Suite("Gregorian Family Era Ordinality Parity")
private struct GregorianFamilyEraOrdinalityParityTests {

    /// The week-based units are left out on purpose. ICU's week count inside an era is not a function of the day count inside that era.
    ///
    /// Two Buddhist dates with the same weekday and the same day-in-era remainder get answers one apart, so there is no formula to match. `weekInEraAdvancesOneWeekAtATime` pins what we do instead.
    static let units: [Calendar.Component] = [.year, .yearForWeekOfYear, .quarter, .month, .day, .hour, .minute, .second]

    /// Dates inside each calendar's own eras, including two era boundaries and a mid-year era start.
    static let dates: [(label: String, date: Date)] = [
        ("2025-08-20", gregorianDate(2025, 8, 20)),
        ("2019-05-01 Reiwa start", gregorianDate(2019, 5, 1)),
        ("1990-03-01 Heisei", gregorianDate(1990, 3, 1)),
        ("1930-06-01 Showa", gregorianDate(1930, 6, 1)),
        ("1912-01-01 Minguo 1", gregorianDate(1912, 1, 1)),
        ("1911-06-30 Meiji 44", gregorianDate(1911, 6, 30)),
        ("1868-09-08 Meiji start", gregorianDate(1868, 9, 8)),
    ]

    private static func gregorianDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(timeZone: .gmt, year: year, month: month, day: day, hour: 12, minute: 34, second: 56)) else {
            preconditionFailure("invalid Gregorian probe date \(year)-\(month)-\(day)")
        }
        return date
    }

    @Test(arguments: GregorianCalendarFamily.allCases, units)
    func ordinalityInEraMatchesICU(_ family: GregorianCalendarFamily, _ unit: Calendar.Component) {
        let ours = family.ours, icu = family.icu
        for probe in Self.dates {
            #expect(ours.ordinality(of: unit, in: .era, for: probe.date) == icu.ordinality(of: unit, in: .era, for: probe.date), "\(unit) in .era at \(probe.label)")
        }
    }

    /// Our week count inside an era rises by exactly one per week, never repeating or skipping.
    ///
    /// ICU's differs by one in some cases. We do not follow it, because a self-consistent count is more useful than an inconsistent match.
    ///
    @Test(arguments: GregorianCalendarFamily.allCases)
    func weekInEraAdvancesOneWeekAtATime(_ family: GregorianCalendarFamily) throws {
        let calendar = family.ours
        let start = try #require(calendar.date(from: DateComponents(timeZone: .gmt, year: 2024, month: 1, day: 7, hour: 12)))
        var previous = try #require(calendar.ordinality(of: .weekOfYear, in: .era, for: start))
        for week in 1...20 {
            let next = try #require(calendar.date(byAdding: .weekOfYear, value: week, to: start))
            let ordinal = try #require(calendar.ordinality(of: .weekOfYear, in: .era, for: next))
            #expect(ordinal == previous + 1, "week \(week)")
            previous = ordinal
        }
    }

    /// The year counted inside an era is the same number the calendar reports as its `.year` component.
    @Test(arguments: GregorianCalendarFamily.allCases, dates)
    func yearInEraMatchesTheYearComponent(_ family: GregorianCalendarFamily, _ probe: (label: String, date: Date)) {
        let calendar = family.ours
        #expect(calendar.ordinality(of: .year, in: .era, for: probe.date) == calendar.dateComponents([.year], from: probe.date).year, "at \(probe.label)")
    }
}

/// The three calendars share one `hash(into:)` from `_CalendarProtocol`, so they must honour the Hashable contract: calendars that compare equal have to hash equally.
@Suite("Gregorian Family Hash Contract")
private struct GregorianFamilyHashContractTests {

    private static func hashValue(_ calendar: Calendar) -> Int {
        var hasher = Hasher()
        calendar.hash(into: &hasher)
        return hasher.finalize()
    }

    /// An unset `firstWeekday` and one set explicitly to the value it would resolve to are equal, so they must hash the same. Hashing the stored value instead of the resolved one breaks this.
    @Test(arguments: GregorianCalendarFamily.allCases)
    func resolvedAndExplicitSettingsHashAlike(_ family: GregorianCalendarFamily) {
        let unset = family.calendar(firstWeekday: nil, minimumDaysInFirstWeek: nil)
        let explicit = family.calendar(firstWeekday: unset.firstWeekday, minimumDaysInFirstWeek: unset.minimumDaysInFirstWeek)
        #expect(unset == explicit)
        #expect(Self.hashValue(unset) == Self.hashValue(explicit))
    }

    @Test(arguments: GregorianCalendarFamily.allCases)
    func differentTimeZonesHashApart(_ family: GregorianCalendarFamily) {
        let gmt = family.calendar(firstWeekday: nil, minimumDaysInFirstWeek: nil)
        var tokyo = gmt
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(gmt != tokyo)
        #expect(Self.hashValue(gmt) != Self.hashValue(tokyo))
    }
}
