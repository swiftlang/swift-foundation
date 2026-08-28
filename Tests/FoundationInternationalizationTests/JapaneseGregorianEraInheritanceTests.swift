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

/// Golden-value tests for the era the Japanese calendar reports before Meiji (unicode-org/icu#4019, ICU-23341). A pre-Meiji date reports the Gregorian era instead of a pre-Meiji Japanese era.
///
/// These values are not compared against ICU, because only unreleased ICU behaves this way. The bundled ICU still carries the old 237-era data.
@Suite("Japanese Gregorian Era Inheritance")
private struct JapaneseGregorianEraInheritanceTests {

    // Era index constants (ICU numbering).
    static let bce = 0, ce = 1, meiji = 232, taisho = 233, showa = 234, heisei = 235, reiwa = 236

    private static func japanese() -> Calendar {
        Calendar(inner: _CalendarGregorian(identifier: .japanese, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
    }

    private static func gregorianDate(era: Int, _ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.era = era; components.year = year; components.month = month; components.day = day
        components.hour = 12; components.timeZone = .gmt
        return try #require(calendar.date(from: components))
    }

    struct EraCase: Sendable, CustomTestStringConvertible {
        let label: String
        let sourceEra, year, month, day: Int
        let expectedEra, expectedYear: Int
        var testDescription: String { label }
    }

    static let eraCases: [EraCase] = [
        // Modern eras keep ICU numbering 232…236.
        EraCase(label: "Reiwa 2020", sourceEra: ce, year: 2020, month: 6, day: 15, expectedEra: reiwa, expectedYear: 2),
        EraCase(label: "Heisei start 1989-01-08", sourceEra: ce, year: 1989, month: 1, day: 8, expectedEra: heisei, expectedYear: 1),
        EraCase(label: "Meiji start 1868-09-08", sourceEra: ce, year: 1868, month: 9, day: 8, expectedEra: meiji, expectedYear: 1),
        // Day before Meiji, and earlier CE dates, inherit Gregorian CE (era 1) with the Gregorian year.
        EraCase(label: "day before Meiji 1868-09-07", sourceEra: ce, year: 1868, month: 9, day: 7, expectedEra: ce, expectedYear: 1868),
        EraCase(label: "early 1868-01-01", sourceEra: ce, year: 1868, month: 1, day: 1, expectedEra: ce, expectedYear: 1868),
        EraCase(label: "1776-07-04", sourceEra: ce, year: 1776, month: 7, day: 4, expectedEra: ce, expectedYear: 1776),
        EraCase(label: "0900-06-15", sourceEra: ce, year: 900, month: 6, day: 15, expectedEra: ce, expectedYear: 900),
        // Before the Common Era inherits Gregorian BCE (era 0).
        EraCase(label: "15 BCE", sourceEra: bce, year: 15, month: 7, day: 10, expectedEra: bce, expectedYear: 15),
    ]

    @Test(arguments: eraCases)
    func eraAndYear(_ eraCase: EraCase) throws {
        let date = try Self.gregorianDate(era: eraCase.sourceEra, eraCase.year, eraCase.month, eraCase.day)
        let components = Self.japanese().dateComponents([.era, .year], from: date)
        #expect(components.era == eraCase.expectedEra)
        #expect(components.year == eraCase.expectedYear)
    }

    @Test func prolepticEraYearRollsIntoGregorian() throws {
        // ICU JapaneseTest.Test5345: setting Meiji year 1, Jan 1 resolves to CE, because Meiji 1 Jan 1 = Gregorian 1868-01-01, before Meiji's Sept 8 start.
        let calendar = Self.japanese()
        var components = DateComponents()
        components.era = Self.meiji; components.year = 1; components.month = 1; components.day = 1; components.hour = 12
        let date = try #require(calendar.date(from: components))
        let back = calendar.dateComponents([.era, .year, .month, .day], from: date)
        #expect(back.era == Self.ce)
        #expect(back.year == 1868)
        #expect(back.month == 1)
        #expect(back.day == 1)
    }

    struct RoundTrip: Sendable, CustomTestStringConvertible {
        let era, year, month, day: Int
        var testDescription: String { "era=\(era) year=\(year) \(month)/\(day)" }
    }

    static let roundTrips: [RoundTrip] = [
        RoundTrip(era: reiwa, year: 2, month: 6, day: 15),
        RoundTrip(era: heisei, year: 1, month: 1, day: 8),
        RoundTrip(era: meiji, year: 1, month: 9, day: 8),
        RoundTrip(era: ce, year: 1867, month: 6, day: 1),
        RoundTrip(era: ce, year: 1500, month: 3, day: 20),
        RoundTrip(era: bce, year: 15, month: 7, day: 10),
    ]

    @Test(arguments: roundTrips)
    func roundTripAcrossMeijiBoundary(_ roundTrip: RoundTrip) throws {
        let calendar = Self.japanese()
        var components = DateComponents()
        components.era = roundTrip.era; components.year = roundTrip.year
        components.month = roundTrip.month; components.day = roundTrip.day; components.hour = 12
        let date = try #require(calendar.date(from: components))
        let back = calendar.dateComponents([.era, .year, .month, .day], from: date)
        #expect(back.era == roundTrip.era)
        #expect(back.year == roundTrip.year)
        #expect(back.month == roundTrip.month)
        #expect(back.day == roundTrip.day)
    }

    struct AddCase: Sendable, CustomTestStringConvertible {
        let label: String
        let fromEra, fromYear, fromMonth, fromDay: Int
        let component: Calendar.Component
        let amount: Int
        let expectedEra, expectedYear, expectedMonth, expectedDay: Int
        var testDescription: String { label }
    }

    // date(byAdding:) works in Gregorian year-space and only relabels the era on read-back, so crossing the Meiji lower edge downward lands on the inherited Gregorian era (CE, then BCE).
    static let addAcrossMeijiCases: [AddCase] = [
        AddCase(label: "Meiji 1 + day(-1) -> CE 1868", fromEra: meiji, fromYear: 1, fromMonth: 9, fromDay: 8, component: .day, amount: -1, expectedEra: ce, expectedYear: 1868, expectedMonth: 9, expectedDay: 7),
        AddCase(label: "Meiji 1 + month(-1) -> CE 1868", fromEra: meiji, fromYear: 1, fromMonth: 9, fromDay: 8, component: .month, amount: -1, expectedEra: ce, expectedYear: 1868, expectedMonth: 8, expectedDay: 8),
        AddCase(label: "Meiji 1 + year(-1) -> CE 1867", fromEra: meiji, fromYear: 1, fromMonth: 9, fromDay: 8, component: .year, amount: -1, expectedEra: ce, expectedYear: 1867, expectedMonth: 9, expectedDay: 8),
        AddCase(label: "Meiji 1 + year(-1867) -> CE 1", fromEra: meiji, fromYear: 1, fromMonth: 9, fromDay: 8, component: .year, amount: -1867, expectedEra: ce, expectedYear: 1, expectedMonth: 9, expectedDay: 8),
        AddCase(label: "Meiji 1 + year(-1868) -> BCE 1", fromEra: meiji, fromYear: 1, fromMonth: 9, fromDay: 8, component: .year, amount: -1868, expectedEra: bce, expectedYear: 1, expectedMonth: 9, expectedDay: 8),
        AddCase(label: "Meiji 1 Dec + month(-4) -> CE 1868", fromEra: meiji, fromYear: 1, fromMonth: 12, fromDay: 1, component: .month, amount: -4, expectedEra: ce, expectedYear: 1868, expectedMonth: 8, expectedDay: 1),
    ]

    @Test(arguments: addAcrossMeijiCases)
    func addAcrossMeijiLowerEdge(_ addCase: AddCase) throws {
        let calendar = Self.japanese()
        var components = DateComponents()
        components.era = addCase.fromEra; components.year = addCase.fromYear
        components.month = addCase.fromMonth; components.day = addCase.fromDay; components.hour = 12
        let from = try #require(calendar.date(from: components))
        let result = try #require(calendar.date(byAdding: addCase.component, value: addCase.amount, to: from))
        let back = calendar.dateComponents([.era, .year, .month, .day], from: result)
        #expect(back.era == addCase.expectedEra)
        #expect(back.year == addCase.expectedYear)
        #expect(back.month == addCase.expectedMonth)
        #expect(back.day == addCase.expectedDay)
    }

    @Test func eraRangeSpansBceToReiwa() {
        let calendar = Self.japanese()
        #expect(calendar.maximumRange(of: .era) == 0..<237)
        #expect(calendar.minimumRange(of: .era) == 0..<237)
    }

    /// An era ends where the next one starts, so successive eras meet exactly and never overlap.
    @Test func eraIntervalEndsWhereTheNextEraStarts() throws {
        let calendar = Self.japanese()
        let showaStart = try Self.gregorianDate(era: Self.ce, 1926, 12, 25)
        let heiseiStart = try Self.gregorianDate(era: Self.ce, 1989, 1, 8)
        let reiwaStart = try Self.gregorianDate(era: Self.ce, 2019, 5, 1)

        let showa = try #require(calendar.dateInterval(of: .era, for: showaStart))
        #expect(showa.start == calendar.startOfDay(for: showaStart))
        #expect(showa.end == calendar.startOfDay(for: heiseiStart))

        let heisei = try #require(calendar.dateInterval(of: .era, for: heiseiStart))
        #expect(heisei.start == calendar.startOfDay(for: heiseiStart))
        #expect(heisei.end == calendar.startOfDay(for: reiwaStart))

        // Each era ends exactly where the next begins, so the intervals neither overlap nor leave a gap.
        #expect(showa.end == heisei.start)

        // Reiwa is the newest era, so it has no end.
        let reiwa = try #require(calendar.dateInterval(of: .era, for: reiwaStart))
        #expect(reiwa.start == calendar.startOfDay(for: reiwaStart))
        #expect(reiwa.duration == Calendar._maxDateIntervalDuration)
    }

    /// A pre-Meiji CE date sits in the inherited Gregorian CE era, so its era interval must stop where Meiji takes over instead of running on through it.
    @Test func inheritedCeEraIsClippedAtMeiji() throws {
        let calendar = Self.japanese()
        let preMeiji = try Self.gregorianDate(era: Self.ce, 1600, 1, 15)
        let meijiStart = try Self.gregorianDate(era: Self.ce, 1868, 9, 8)

        let inherited = try #require(calendar.dateInterval(of: .era, for: preMeiji))
        #expect(inherited.end == calendar.startOfDay(for: meijiStart))
        #expect(inherited.start < preMeiji)
    }
}
