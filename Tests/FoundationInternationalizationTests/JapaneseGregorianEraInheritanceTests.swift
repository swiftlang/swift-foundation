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

/// Golden-value tests for the Japanese calendar's Gregorian era inheritance before Meiji (unicode-org/icu#4019, ICU-23341): pre-Meiji dates report the Gregorian era (0 = BCE, 1 = CE) rather than a pre-Meiji Japanese era. These are ICU-independent because the behavior only exists in unreleased ICU; the bundled ICU still has the old 237-era data.
@Suite("Japanese Gregorian Era Inheritance")
private struct JapaneseGregorianEraInheritanceTests {

    // Era index constants (ICU numbering).
    static let bce = 0, ce = 1, meiji = 232, taisho = 233, showa = 234, heisei = 235, reiwa = 236

    private static func japanese() -> Calendar {
        Calendar(inner: _CalendarJapanese(identifier: .japanese, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil))
    }

    private static func gregorianDate(era: Int, _ y: Int, _ m: Int, _ d: Int) throws -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var dc = DateComponents()
        dc.era = era; dc.year = y; dc.month = m; dc.day = d; dc.hour = 12; dc.timeZone = .gmt
        return try #require(cal.date(from: dc))
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
    func eraAndYear(_ c: EraCase) throws {
        let cal = Self.japanese()
        let date = try Self.gregorianDate(era: c.sourceEra, c.year, c.month, c.day)
        let dc = cal.dateComponents([.era, .year], from: date)
        #expect(dc.era == c.expectedEra)
        #expect(dc.year == c.expectedYear)
    }

    @Test func prolepticEraYearRollsIntoGregorian() throws {
        // ICU JapaneseTest.Test5345: setting Meiji year 1, Jan 1 resolves to CE, because Meiji 1 Jan 1 = Gregorian 1868-01-01, before Meiji's Sept 8 start.
        let cal = Self.japanese()
        var dc = DateComponents()
        dc.era = Self.meiji; dc.year = 1; dc.month = 1; dc.day = 1; dc.hour = 12
        let date = try #require(cal.date(from: dc))
        let c = cal.dateComponents([.era, .year, .month, .day], from: date)
        #expect(c.era == Self.ce)
        #expect(c.year == 1868)
        #expect(c.month == 1)
        #expect(c.day == 1)
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
    func roundTripAcrossMeijiBoundary(_ c: RoundTrip) throws {
        let cal = Self.japanese()
        var dc = DateComponents()
        dc.era = c.era; dc.year = c.year; dc.month = c.month; dc.day = c.day; dc.hour = 12
        let date = try #require(cal.date(from: dc))
        let back = cal.dateComponents([.era, .year, .month, .day], from: date)
        #expect(back.era == c.era)
        #expect(back.year == c.year)
        #expect(back.month == c.month)
        #expect(back.day == c.day)
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
    func addAcrossMeijiLowerEdge(_ c: AddCase) throws {
        let cal = Self.japanese()
        var dc = DateComponents()
        dc.era = c.fromEra; dc.year = c.fromYear; dc.month = c.fromMonth; dc.day = c.fromDay; dc.hour = 12
        let from = try #require(cal.date(from: dc))
        let result = try #require(cal.date(byAdding: c.component, value: c.amount, to: from))
        let back = cal.dateComponents([.era, .year, .month, .day], from: result)
        #expect(back.era == c.expectedEra)
        #expect(back.year == c.expectedYear)
        #expect(back.month == c.expectedMonth)
        #expect(back.day == c.expectedDay)
    }

    @Test func eraRangeSpansBceToReiwa() {
        let cal = Self.japanese()
        #expect(cal.maximumRange(of: .era) == 0..<237)
        #expect(cal.minimumRange(of: .era) == 0..<237)
    }
}
