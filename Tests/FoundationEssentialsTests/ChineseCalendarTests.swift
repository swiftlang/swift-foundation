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

@Suite("Chinese Calendar")
private struct ChineseCalendarTests {

    private static func cal() -> _CalendarChinese {
        _CalendarChinese(identifier: .chinese, timeZone: .gmt, locale: nil,
                         firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
    }

    private static func date(rataDie: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + 43_200.0)
    }

    @Test func knownDates() {
        let c = Self.cal()
        // (gregorian y-m-d, era, year, month, isLeap, day)
        let cases: [(Int, Int, Int, Int, Int, Int, Bool, Int)] = [
            (1901, 2, 19, 76, 38, 1, false, 1),    // CNY 1901
            (1906, 5, 23, 76, 43, 4, true, 1),     // leap-4 first day
            (1906, 6, 21, 76, 43, 4, true, 30),    // leap-4 last day
            (2000, 2, 5, 78, 17, 1, false, 1),     // CNY 2000
            (2020, 6, 20, 78, 37, 4, true, 29),    // leap-4 2020
            (2024, 2, 10, 78, 41, 1, false, 1),    // CNY 2024
            (2033, 12, 22, 78, 50, 11, true, 1),   // rare leap-11
            (2100, 12, 31, 79, 57, 12, false, 1),  // last day of table range
            (1900, 9, 24, 76, 37, 8, true, 1),     // fallback year at seam (leap-8)
        ]
        for (gy, gm, gd, era, year, month, leap, day) in cases {
            let d = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(gy, gm, gd))
            let dc = c.dateComponents([.era, .year, .month, .day, .isLeapMonth], from: d, in: .gmt)
            #expect(dc.era == era && dc.year == year && dc.month == month
                    && dc.isLeapMonth == leap && dc.day == day,
                    "\(gy)-\(gm)-\(gd): got e\(dc.era ?? -1)/y\(dc.year ?? -1)/m\(dc.month ?? -1)\((dc.isLeapMonth ?? false) ? "L" : "")/d\(dc.day ?? -1)")
        }
    }

    @Test func roundTrips() {
        let c = Self.cal()
        var failures = 0
        var rataDie = _CalendarAstronomy.gregorianRataDie(1899, 1, 1)
        let end = _CalendarAstronomy.gregorianRataDie(2102, 12, 31)
        while rataDie <= end {
            let d = Self.date(rataDie: rataDie)
            let dc = c.dateComponents([.era, .year, .month, .day, .isLeapMonth], from: d, in: .gmt)
            var comps = DateComponents()
            comps.era = dc.era; comps.year = dc.year; comps.month = dc.month
            comps.day = dc.day; comps.isLeapMonth = dc.isLeapMonth; comps.hour = 12
            if c.date(from: comps) != d { failures += 1 }
            rataDie += 13
        }
        #expect(failures == 0)
    }

    // Adjudicated against the promulgated historical record. ICU disagrees at 1795/1814/1890/2148 (its astronomy invents nonexistent leap months); the divergence is intentional, do not adjust these to match ICU.
    @Test func historicalPins() {
        let pins: [(Int, Int, Int, Int)] = [
            (1776, 1776, 2, 19), (1795, 1795, 1, 21), (1814, 1814, 1, 21),
            (1871, 1871, 2, 19), (1890, 1890, 1, 21), (2148, 2148, 2, 20),
        ]
        for (iso, gy, gm, gd) in pins {
            #expect(_ChineseCalendarEngine.year(relatedISOYear: iso).newYearRataDie
                    == _CalendarAstronomy.gregorianRataDie(gy, gm, gd), "CNY \(iso)")
        }
        let leaps: [(Int, UInt8)] = [(1775, 10), (1776, 0), (1900, 8), (2147, 11), (2148, 0)]
        for (iso, want) in leaps {
            #expect(_ChineseCalendarEngine.year(relatedISOYear: iso).leapDisplay == want, "leap \(iso)")
        }
    }

    @Test func yearStructureInvariants() {
        var failures: [String] = []
        var prev = _ChineseCalendarEngine.year(relatedISOYear: 1800)
        for iso in 1801...2300 {
            let y = _ChineseCalendarEngine.year(relatedISOYear: iso)
            if prev.endRataDie != y.newYearRataDie { failures.append("\(iso): tiling") }
            let n = Int(y.monthCount)
            if n != 12 && n != 13 { failures.append("\(iso): months \(n)") }
            if (n == 13) != (y.leapDisplay != 0) { failures.append("\(iso): leap flag") }
            var sum = 0
            for o in 1...n { sum += y.monthLength(ordinal: o) }
            if sum != y.endRataDie - y.newYearRataDie { failures.append("\(iso): bits sum") }
            prev = y
        }
        #expect(failures.isEmpty, "\(failures.prefix(5))")
    }

    @Test func rangeLimits() {
        let c = Self.cal()
        #expect(c.minimumRange(of: .era) == 1..<83334)
        #expect(c.maximumRange(of: .year) == 1..<61)
        #expect(c.maximumRange(of: .month) == 1..<13)
        #expect(c.minimumRange(of: .day) == 1..<30)
        #expect(c.maximumRange(of: .day) == 1..<31)
        #expect(c.minimumRange(of: .dayOfYear) == 1..<354)
        #expect(c.maximumRange(of: .dayOfYear) == 1..<386)
        #expect(c.maximumRange(of: .weekOfYear) == 1..<56)
    }

    // Deliberate divergence from ICU, guarded: ICU's chinese calendar cannot use YEAR_WOY on the fields-to-time side (chnsecal handleGetExtendedYear ignores it), yielding a nil interval and a no-op add; we implement Gregorian-family week-year semantics instead (precedent: the Japanese calendar's .era interval). If this test is changed to expect nil/no-op, that reversion must be an explicit decision.
    @Test func weekYearSemantics() {
        let c = Self.cal()
        let d = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(2025, 7, 4))
        guard let interval = c.dateInterval(of: .yearForWeekOfYear, for: d) else {
            #expect(Bool(false), "week-year interval must not be nil")
            return
        }
        #expect(interval.start <= d && d < interval.end)
        let next = c.dateInterval(of: .yearForWeekOfYear, for: interval.end + 43_200)
        #expect(next?.start == interval.end)
        var dc = DateComponents()
        dc.yearForWeekOfYear = 1
        let added = c.date(byAdding: dc, to: d, wrappingComponents: false)
        #expect((added ?? d) > d)
    }

    // Deliberately identical to ICU, quirks included: a leap month is not absorbed, so a date can fall outside its own quarter interval and range(.month,.quarter) shrinks. Changing these expectations diverges from ICU, that must be an explicit decision.
    @Test func quarterSurfaces() {
        let c = Self.cal()
        // Chinese 2025 is a leap-6 year; CNY Jan 29, Q2 starts Apr 28.
        let normal = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(2025, 3, 5))
        #expect(c.ordinality(of: .quarter, in: .year, for: normal) == 1)
        #expect(c.ordinality(of: .month, in: .quarter, for: normal) == 2)
        #expect(c.ordinality(of: .day, in: .quarter, for: normal) == 36)
        #expect(c.range(of: .month, in: .quarter, for: normal) == 1..<4)
        let q1 = c.dateInterval(of: .quarter, for: normal)
        #expect(q1?.start == Date(timeIntervalSinceReferenceDate:
            Double(_CalendarAstronomy.gregorianRataDie(2025, 1, 29) - 730_486) * 86400.0))
        #expect(q1.map { $0.contains(normal) } == true)

        let inLeap = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(2025, 8, 1))
        #expect(c.ordinality(of: .quarter, in: .year, for: inLeap) == 2)
        #expect(c.ordinality(of: .day, in: .quarter, for: inLeap) == 96)
        let q2 = c.dateInterval(of: .quarter, for: inLeap)
        #expect(q2?.duration == 88 * 86400.0)
        #expect(q2.map { $0.contains(inLeap) } == false)   // the documented quirk

        // Leap-4 1906: the leap month consumes a Q2 slot, shrinking the range.
        let leapQuarter = Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(1906, 6, 25))
        #expect(c.range(of: .month, in: .quarter, for: leapQuarter) == 4..<6)
    }

    @Test func validDaysEverywhere() {
        // ICU emits day=0 artifacts in two 2057/2097 months; ours must not.
        let c = Self.cal()
        for (gy, gm, gd) in [(2057, 9, 28), (2057, 10, 5), (2097, 8, 7), (2097, 8, 20)] {
            let dc = c.dateComponents([.day], from: Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(gy, gm, gd)), in: .gmt)
            #expect((dc.day ?? 0) >= 1, "\(gy)-\(gm)-\(gd)")
        }
    }
}
