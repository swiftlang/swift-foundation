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

    private static func chineseCalendar() -> _CalendarChinese {
        _CalendarChinese(identifier: .chinese, timeZone: .gmt, locale: nil,
                         firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
    }

    private static func date(rataDie: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(rataDie - 730_486) * 86400.0 + 43_200.0)
    }

    @Test func knownDates() {
        let c = Self.chineseCalendar()
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
        let c = Self.chineseCalendar()
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
            #expect(_CalendarChinese.year(relatedISOYear: iso).newYearRataDie
                    == _CalendarAstronomy.gregorianRataDie(gy, gm, gd), "CNY \(iso)")
        }
        let leaps: [(Int, UInt8)] = [(1775, 10), (1776, 0), (1900, 8), (2147, 11), (2148, 0)]
        for (iso, want) in leaps {
            #expect(_CalendarChinese.year(relatedISOYear: iso).leapMonthNumber == want, "leap \(iso)")
        }
    }

    @Test func yearStructureInvariants() {
        var failures: [String] = []
        var prev = _CalendarChinese.year(relatedISOYear: 1800)
        for iso in 1801...2300 {
            let y = _CalendarChinese.year(relatedISOYear: iso)
            if prev.endRataDie != y.newYearRataDie { failures.append("\(iso): tiling") }
            let n = Int(y.monthCount)
            if n != 12 && n != 13 { failures.append("\(iso): months \(n)") }
            if (n == 13) != (y.leapMonthNumber != 0) { failures.append("\(iso): leap flag") }
            var sum = 0
            for o in 1...n { sum += y.monthLength(ordinal: o) }
            if sum != y.endRataDie - y.newYearRataDie { failures.append("\(iso): bits sum") }
            prev = y
        }
        #expect(failures.isEmpty, "\(failures.prefix(5))")
    }

    @Test func rangeLimits() {
        let c = Self.chineseCalendar()
        #expect(c.minimumRange(of: .era) == 1..<83334)
        #expect(c.maximumRange(of: .year) == 1..<61)
        #expect(c.maximumRange(of: .month) == 1..<13)
        #expect(c.minimumRange(of: .day) == 1..<30)
        #expect(c.maximumRange(of: .day) == 1..<31)
        #expect(c.minimumRange(of: .dayOfYear) == 1..<354)
        #expect(c.maximumRange(of: .dayOfYear) == 1..<386)
        #expect(c.maximumRange(of: .weekOfYear) == 1..<56)
    }

    // Deliberate divergence from ICU, guarded: ICU's chinese calendar returns nil for the yearForWeekOfYear interval and no-ops an add of it, so we implement Gregorian-family week-year semantics instead (precedent: the Japanese calendar's .era interval). ICU is asymmetric here, it does resolve the week-year form in date(from:), which dateFromWeekYearComponents pins against ICU's own answers. If this test is changed to expect nil/no-op, that reversion must be an explicit decision.
    @Test func weekYearSemantics() {
        let c = Self.chineseCalendar()
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
        let c = Self.chineseCalendar()
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
        let c = Self.chineseCalendar()
        for (gy, gm, gd) in [(2057, 9, 28), (2057, 10, 5), (2097, 8, 7), (2097, 8, 20)] {
            let dc = c.dateComponents([.day], from: Self.date(rataDie: _CalendarAstronomy.gregorianRataDie(gy, gm, gd)), in: .gmt)
            #expect((dc.day ?? 0) >= 1, "\(gy)-\(gm)-\(gd)")
        }
    }

    // A roll wraps the month inside its own year and never carries into the year, and it wraps around this year's own month count, 12 or 13 when there is a leap month. Regression: the wrapping path had a branch for .day but none for .month, so a roll fell through to the month walk a plain add uses, and that walk crosses year boundaries.
    @Test func rollMonthWrapsWithinYear() {
        let c = Self.chineseCalendar()
        // (relatedISOYear, expected month count, roll amount, expected month afterwards)
        let cases: [(Int, UInt8, Int, Int)] = [
            (2024, 12, 11, 2), (2024, 12, 12, 3), (2024, 12, -1, 2), (2024, 12, -11, 4),
            (2025, 13, 11, 1), (2025, 13, 13, 3), (2025, 13, -1, 2), (2025, 13, -11, 5),
        ]
        for (iso, monthCount, amount, wantMonth) in cases {
            let y = _CalendarChinese.year(relatedISOYear: iso)
            #expect(y.monthCount == monthCount, "fixture \(iso): month count is \(y.monthCount)")
            let from = Self.date(rataDie: y.monthStartRataDie(ordinal: 3) + 4)   // ordinal month 3, day 5
            let before = c.dateComponents([.year, .month, .day], from: from, in: .gmt)
            var dc = DateComponents()
            dc.month = amount
            guard let rolled = c.date(byAdding: dc, to: from, wrappingComponents: true) else {
                #expect(Bool(false), "\(iso) roll by \(amount) returned nil")
                continue
            }
            let after = c.dateComponents([.year, .month, .day], from: rolled, in: .gmt)
            #expect(after.year == before.year, "\(iso) roll by \(amount) changed the year, \(before.year ?? -1) to \(after.year ?? -1)")
            #expect(after.month == wantMonth, "\(iso) roll by \(amount): month \(after.month ?? -1), wanted \(wantMonth)")
            #expect(after.day == 5, "\(iso) roll by \(amount): day \(after.day ?? -1)")
        }
        // The same amount as a plain add does carry into the next year. That difference is the whole point of the wrapping branch, so pin it too.
        let y = _CalendarChinese.year(relatedISOYear: 2024)
        let from = Self.date(rataDie: y.monthStartRataDie(ordinal: 3) + 4)
        var dc = DateComponents()
        dc.month = 11
        let added = c.date(byAdding: dc, to: from, wrappingComponents: false)
        let before = c.dateComponents([.year], from: from, in: .gmt)
        let after = added.map { c.dateComponents([.year, .month], from: $0, in: .gmt) }
        #expect(after?.year == (before.year ?? 0) + 1 && after?.month == 2,
                "add of 11 months: y\(after?.year ?? -1)/m\(after?.month ?? -1)")
    }

    // range(of: .day, in: .weekOfMonth) reports the day-of-month values the week covers, clipped to the month at both ends because a week can start before the month or run past its end. Regression: the (.day, .weekOfMonth) pair was missing from ordinality, so the generic range fallback gave up on the first lookup and returned nil.
    @Test func dayRangeInWeekOfMonth() {
        let c = Self.chineseCalendar()
        let y = _CalendarChinese.year(relatedISOYear: 2024)   // 12 months, new year Feb 10; firstWeekday is Sunday here
        // (ordinal month, day of month, expected range)
        let cases: [(Int, Int, Range<Int>)] = [
            (1, 1, 1..<2),      // the month starts on a Saturday, so its first week holds a single day
            (1, 15, 9..<16),    // a whole week, clipped at neither end
            (3, 1, 1..<6),      // first week, clipped by the month start
            (2, 30, 29..<31),   // last week, clipped by the month end
            (3, 29, 27..<30),   // last week, clipped by the month end
        ]
        for (ordinal, day, want) in cases {
            let d = Self.date(rataDie: y.monthStartRataDie(ordinal: ordinal) + day - 1)
            let got = c.range(of: .day, in: .weekOfMonth, for: d)
            #expect(got == want, "ordinal \(ordinal) day \(day): \(got.map { "\($0)" } ?? "nil"), wanted \(want)")
        }
        // The invariant behind those pins: never nil, always inside the month, always covering the day itself. Three decades is enough to hit every weekday alignment, both month lengths and a dozen leap months.
        var failures: [String] = []
        for iso in 2000...2030 {
            let year = _CalendarChinese.year(relatedISOYear: iso)
            for ordinal in 1...Int(year.monthCount) {
                let length = year.monthLength(ordinal: ordinal)
                let start = year.monthStartRataDie(ordinal: ordinal)
                for day in 1...length {
                    let d = Self.date(rataDie: start + day - 1)
                    guard let r = c.range(of: .day, in: .weekOfMonth, for: d) else {
                        failures.append("\(iso)/o\(ordinal)/d\(day): nil range")
                        continue
                    }
                    if r.isEmpty || r.lowerBound < 1 || r.upperBound > length + 1 || !r.contains(day) {
                        failures.append("\(iso)/o\(ordinal)/d\(day): \(r) in a \(length) day month")
                    }
                    guard let o = c.ordinality(of: .day, in: .weekOfMonth, for: d) else {
                        failures.append("\(iso)/o\(ordinal)/d\(day): nil ordinality")
                        continue
                    }
                    if o < 1 || o > 7 { failures.append("\(iso)/o\(ordinal)/d\(day): ordinality \(o)") }
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first few: \(failures.prefix(5))")
    }

    // A date can be named by yearForWeekOfYear + weekOfYear + weekday instead of era + year + month + day, and `date(from:)` has to accept that form. It used to require `.year` and returned nil for anything else. Note that yearForWeekOfYear is an extended year here, not a cycle year, so it is used directly and `era` is ignored on this path; ICU does the same. Expected values below were checked against the ICU-backed calendar and agree with it exactly.
    @Test func dateFromWeekYearComponents() {
        let c = Self.chineseCalendar()
        // (yearForWeekOfYear, weekOfYear, weekday, expected era, year, month, day)
        let cases: [(Int, Int, Int, Int, Int, Int, Int)] = [
            (5779, 16, 2, 97, 19, 4, 15),
            (5779, 1, 1, 97, 18, 12, 28),   // week 1 begins in the previous calendar year
            (5779, 30, 7, 97, 19, 8, 1),
            (5780, 52, 4, 97, 21, 1, 7),    // a week past the end of the week-year runs on, it is not clamped
            (4656, 10, 6, 78, 36, 3, 8),
            (4651, 38, 5, 78, 31, 9, 23),
        ]
        for (weekYear, weekOfYear, weekday, wantEra, wantYear, wantMonth, wantDay) in cases {
            var dc = DateComponents()
            dc.yearForWeekOfYear = weekYear
            dc.weekOfYear = weekOfYear
            dc.weekday = weekday
            dc.hour = 12
            dc.timeZone = .gmt

            guard let date = c.date(from: dc) else {
                #expect(Bool(false), "date(from:) returned nil for yWoY \(weekYear) woY \(weekOfYear) weekday \(weekday)")
                continue
            }
            let back = c.dateComponents([.era, .year, .month, .day, .weekday, .hour], from: date, in: .gmt)
            #expect(back.era == wantEra && back.year == wantYear && back.month == wantMonth
                    && back.day == wantDay && back.weekday == weekday && back.hour == 12,
                    "yWoY \(weekYear) woY \(weekOfYear) weekday \(weekday): got e\(back.era ?? -1)/y\(back.year ?? -1)/m\(back.month ?? -1)/d\(back.day ?? -1) wd\(back.weekday ?? -1), wanted e\(wantEra)/y\(wantYear)/m\(wantMonth)/d\(wantDay) wd\(weekday)")
        }
    }

    // The invariant behind those pins: whatever week fields we report for a date, handing them back has to return that same date. Runs over 20 years of consecutive days, and over non-default firstWeekday and minimumDaysInFirstWeek, because the week-year anchor depends on both.
    @Test func weekYearComponentsRoundTrip() {
        var failures: [String] = []
        for (firstWeekday, minimumDays) in [(nil, nil), (2, 4), (7, 1), (4, 7)] as [(Int?, Int?)] {
            let c = _CalendarChinese(identifier: .chinese, timeZone: .gmt, locale: nil,
                                     firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDays,
                                     gregorianStartDate: nil)
            let config = "fw \(firstWeekday.map(String.init) ?? "default")/md \(minimumDays.map(String.init) ?? "default")"
            var rataDie = _CalendarAstronomy.gregorianRataDie(2000, 1, 1)
            let end = _CalendarAstronomy.gregorianRataDie(2019, 12, 31)
            while rataDie <= end {
                let date = Self.date(rataDie: rataDie)
                let read = c.dateComponents([.era, .yearForWeekOfYear, .weekOfYear, .weekday, .hour], from: date, in: .gmt)
                var dc = DateComponents()
                dc.era = read.era
                dc.yearForWeekOfYear = read.yearForWeekOfYear
                dc.weekOfYear = read.weekOfYear
                dc.weekday = read.weekday
                dc.hour = read.hour
                dc.timeZone = .gmt
                if let back = c.date(from: dc) {
                    if back != date { failures.append("\(config) rd \(rataDie): off by \(back.timeIntervalSince(date) / 86400) days") }
                } else {
                    failures.append("\(config) rd \(rataDie): nil")
                }
                rataDie += 1
            }
        }
        #expect(failures.isEmpty, "\(failures.count) failures, first few: \(failures.prefix(5))")
    }
}
