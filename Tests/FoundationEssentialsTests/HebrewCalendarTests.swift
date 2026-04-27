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
@testable import FoundationEssentials
#endif

// Direct unit tests for `_CalendarHebrew` (bypassing `Calendar` / router).
// Exercises the core algorithm before we flip the router in `_calendarClass`.
@Suite("Hebrew Calendar")
private struct HebrewCalendarTests {

    private func makeCalendar() -> _CalendarHebrew {
        _CalendarHebrew(
            identifier: .hebrew,
            timeZone: .gmt,
            locale: nil,
            firstWeekday: nil,
            minimumDaysInFirstWeek: nil,
            gregorianStartDate: nil
        )
    }

    // MARK: - Arithmetic primitives

    @Test func leapYears_metonicCycle() {
        // Metonic cycle: leap at positions 3, 6, 8, 11, 14, 17, 19.
        // Year 5785 ended Sep 22, 2025 (AM), so 5786 began Sep 23, 2025.
        // Leap years in the current 19-year cycle (5777-5795):
        //   5779 = pos 3,  5782 = pos 6,  5784 = pos 8,
        //   5787 = pos 11, 5790 = pos 14, 5793 = pos 17, 5795 = pos 19.
        for leap in [5779, 5782, 5784, 5787, 5790, 5793, 5795] {
            #expect(HebrewArithmetic.isLeapYear(Int32(leap)), "expected \(leap) to be leap")
        }
        for common in [5777, 5778, 5780, 5781, 5783, 5785, 5786, 5788, 5789, 5791, 5792, 5794] {
            #expect(!HebrewArithmetic.isLeapYear(Int32(common)), "expected \(common) to be common")
        }
    }

    @Test func monthsInYear() {
        #expect(HebrewArithmetic.monthsInYear(5786) == 12)   // common
        #expect(HebrewArithmetic.monthsInYear(5787) == 13)   // leap
    }

    @Test func daysInYear_bounds() {
        // Every Hebrew year has 353, 354, 355, 383, 384, or 385 days.
        let valid: Set<UInt16> = [353, 354, 355, 383, 384, 385]
        for y: Int32 in 5780...5800 {
            let d = HebrewArithmetic.daysInYear(y)
            #expect(valid.contains(d), "year \(y) has \(d) days — out of range")
        }
    }

    // MARK: - Round-trip via _CalendarHebrew

    // Verify (y, m, d) → Date → (y, m, d) preserves the original triple.
    // Uses Foundation's stable / ICU-style month numbering:
    //   1=Tishrei, 2=Cheshvan, 3=Kislev, 4=Tevet, 5=Shevat,
    //   6=Adar I (leap only), 7=Adar (common) / Adar II (leap),
    //   8=Nisan, 9=Iyyar, 10=Sivan, 11=Tammuz, 12=Av, 13=Elul
    @Test func roundTrip_civilComponents() {
        let cal = makeCalendar()
        let cases: [(year: Int, month: Int, day: Int)] = [
            // Common year 5786
            (5786, 1, 1),    // Tishrei 1
            (5786, 3, 25),   // Kislev 25 (Hanukkah start)
            (5786, 7, 1),    // Adar 1 (common year)
            (5786, 8, 15),   // Nisan 15 (Passover)
            (5786, 13, 29),  // Elul 29 (last day of common year)
            // Leap year 5787
            (5787, 6, 1),    // Adar I 1 (leap only)
            (5787, 7, 1),    // Adar II 1 (leap)
            (5787, 8, 15),   // Nisan 15 (leap — Nisan still month 8)
            (5787, 13, 29),  // Elul 29 (last day of leap year)
            // Extreme values
            (1, 1, 1),       // Year 1 AM
            (4000, 7, 29),   // Late Adar in common year 4000
        ]
        for (y, m, d) in cases {
            var dc = DateComponents()
            dc.era = 0   // Hebrew AM era (ICU convention: 0-based)
            dc.year = y
            dc.month = m
            dc.day = d
            dc.hour = 12
            dc.timeZone = .gmt

            guard let date = cal.date(from: dc) else {
                Issue.record("date(from:) returned nil for (\(y),\(m),\(d))")
                continue
            }
            let back = cal.dateComponents([.year, .month, .day, .hour], from: date, in: .gmt)
            #expect(back.year == y, "year mismatch for (\(y),\(m),\(d)): got \(String(describing: back.year))")
            #expect(back.month == m, "month mismatch for (\(y),\(m),\(d)): got \(String(describing: back.month))")
            #expect(back.day == d, "day mismatch for (\(y),\(m),\(d)): got \(String(describing: back.day))")
            #expect(back.hour == 12, "hour mismatch for (\(y),\(m),\(d)): got \(String(describing: back.hour))")
        }
    }

    // MARK: - Cross-check against Foundation's ICU-backed .hebrew

    // Debugging: does `Calendar(.hebrew).enumerateDates` actually work
    // WITHOUT an explicit timezone override (i.e., system default — matches perf test).
    @Test func debug_hanukkahEnumerateFires_systemTZ() {
        let cal = Calendar(identifier: .hebrew)
        print("DEBUG TZ: \(cal.timeZone.identifier)")
        let start = Date(timeIntervalSinceReferenceDate: 496359355.795410)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        print("DEBUG start in \(cal.timeZone.identifier): year=\(comps.year!) month=\(comps.month!) day=\(comps.day!)")

        var matches: [(Date, DateComponents)] = []
        cal.enumerateDates(
            startingAfter: start,
            matching: DateComponents(month: 3, day: 25),
            matchingPolicy: .nextTime
        ) { result, _, stop in
            if let d = result {
                matches.append((d, cal.dateComponents([.year, .month, .day], from: d)))
            }
            if matches.count >= 3 { stop = true }
        }
        print("DEBUG system-TZ matches count: \(matches.count)")
        for (d, c) in matches {
            print("  → \(d)  heb=\(c.year!)/\(c.month!)/\(c.day!)")
        }
        #expect(matches.count > 0, "system-TZ enumerateDates didn't produce any matches")
    }

    // Debugging: does `Calendar(.hebrew).enumerateDates` actually work?
    @Test func debug_hanukkahEnumerateFires() {
        var cal = Calendar(identifier: .hebrew)
        cal.timeZone = .gmt
        let start = Date(timeIntervalSinceReferenceDate: 496359355.795410)
        // Check that basic dateComponents is going through our class.
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        print("DEBUG start \(start) → year=\(comps.year!) month=\(comps.month!) day=\(comps.day!)")

        // Try enumerateDates for Hanukkah (25 Kislev).
        var matches: [(Date, DateComponents)] = []
        cal.enumerateDates(
            startingAfter: start,
            matching: DateComponents(month: 3, day: 25),
            matchingPolicy: .nextTime
        ) { result, exactMatch, stop in
            if let d = result {
                matches.append((d, cal.dateComponents([.year, .month, .day], from: d)))
            }
            if matches.count >= 3 { stop = true }
        }
        print("DEBUG matches count: \(matches.count)")
        for (d, c) in matches {
            print("  → \(d)  heb=\(c.year!)/\(c.month!)/\(c.day!)")
        }
        #expect(matches.count > 0, "enumerateDates didn't produce any Hanukkah matches")
    }

    // Compare _CalendarHebrew vs the current ICU implementation for a range of dates.
    // Once the router is flipped, this test becomes a regression oracle against itself.
    @Test func crossCheck_againstICU() {
        let hebrewICU = Calendar(identifier: .hebrew)
        // Make sure the comparison is apples-to-apples on timeZone.
        let utcHebrewICU = {
            var c = hebrewICU
            c.timeZone = .gmt
            return c
        }()
        let ours = makeCalendar()

        // Step one day at a time for a year around ~2025.
        var date = Date(timeIntervalSinceReferenceDate: 750000000) // 2024-09-10T04:20:00Z
        let oneDay: TimeInterval = 86400

        var divergences = 0
        var total = 0
        for _ in 0..<400 {
            let icuComps = utcHebrewICU.dateComponents([.year, .month, .day], from: date)
            let ourComps = ours.dateComponents([.year, .month, .day], from: date, in: .gmt)
            total += 1
            if icuComps.year != ourComps.year || icuComps.month != ourComps.month || icuComps.day != ourComps.day {
                divergences += 1
                if divergences <= 3 {
                    Issue.record("Hebrew divergence at \(date): ICU=\(icuComps.year!)/\(icuComps.month!)/\(icuComps.day!) vs ours=\(ourComps.year ?? -1)/\(ourComps.month ?? -1)/\(ourComps.day ?? -1)")
                }
            }
            date += oneDay
        }
        #expect(divergences == 0, "\(divergences)/\(total) Hebrew dates diverged from ICU")
    }

    // MARK: - DST policy parity vs _CalendarGregorian

    /// Verifies that `_CalendarHebrew.utcDate(fromRataDie:secondsInDay:in:repeatedTimePolicy:skippedTimePolicy:)`
    /// produces the same Date as `_CalendarGregorian.date(from:inTimeZone:dstRepeatedTimePolicy:dstSkippedTimePolicy:)`
    /// across **all four (.former/.latter) × (.former/.latter) policy combinations** at DST boundaries.
    ///
    /// Both calendars boil down to the same wall-clock → UTC mapping via
    /// `TimeZone.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:skippedTimePolicy:)`.
    /// If our utcDate is correct, it must agree with Gregorian's reference for
    /// every policy combination — at repeated wall-clocks (fall-back), skipped
    /// wall-clocks (spring-forward), and unambiguous neighbors of both.
    @Test func utcDate_allPolicyCombinations_matchGregorian() throws {
        guard let la = TimeZone(identifier: "America/Los_Angeles") else {
            Issue.record("America/Los_Angeles timezone unavailable")
            return
        }

        let hebrew = _CalendarHebrew(
            identifier: .hebrew, timeZone: la, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let gregorian = _CalendarGregorian(
            identifier: .gregorian, timeZone: la, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )

        // Compute the RD (proleptic Gregorian fixed-day number) of midnight UTC for a given Greg date.
        // Independent of any calendar's internals — uses Foundation's Date arithmetic.
        func rdAtMidnightUTC(_ y: Int, _ m: Int, _ d: Int) -> Int64 {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .gmt
            var dc = DateComponents()
            dc.year = y; dc.month = m; dc.day = d; dc.timeZone = .gmt
            let date = cal.date(from: dc)!
            let days = Int64(date.timeIntervalSinceReferenceDate / 86400)
            return days + _CalendarHebrew.rataDieAtDateReference
        }

        // (label, year, month, day, hour, minute) — wall-clocks at and around DST transitions.
        let probes: [(String, Int, Int, Int, Int, Int)] = [
            // LA fall-back 2024-11-03: 02:00 PDT → 01:00 PST (01:00–01:59 repeats)
            ("fall-back day, 00:30 (unambiguous PDT)",   2024, 11,  3,  0, 30),
            ("fall-back day, 01:00 (start of repeat)",   2024, 11,  3,  1,  0),
            ("fall-back day, 01:30 (mid repeat)",        2024, 11,  3,  1, 30),
            ("fall-back day, 01:59 (end of repeat)",     2024, 11,  3,  1, 59),
            ("fall-back day, 02:00 (post-transition)",   2024, 11,  3,  2,  0),
            ("fall-back day, 02:30 (unambiguous PST)",   2024, 11,  3,  2, 30),

            // LA spring-forward 2024-03-10: 02:00 PST → 03:00 PDT (02:00–02:59 skipped)
            ("spring-forward, 01:30 (unambiguous PST)",  2024,  3, 10,  1, 30),
            ("spring-forward, 01:59 (last pre-skip)",    2024,  3, 10,  1, 59),
            ("spring-forward, 02:00 (start of skip)",    2024,  3, 10,  2,  0),
            ("spring-forward, 02:30 (mid skip)",         2024,  3, 10,  2, 30),
            ("spring-forward, 02:59 (end of skip)",      2024,  3, 10,  2, 59),
            ("spring-forward, 03:00 (post-transition)",  2024,  3, 10,  3,  0),
            ("spring-forward, 03:30 (unambiguous PDT)",  2024,  3, 10,  3, 30),

            // 2025 transitions
            ("LA 2025 fall-back, 01:30 (mid repeat)",    2025, 11,  2,  1, 30),
            ("LA 2025 spring-forward, 02:30 (skipped)",  2025,  3,  9,  2, 30),

            // Non-DST baseline (sanity check — all 4 combinations agree, no policy effect)
            ("non-DST baseline, 12:00 mid-summer",       2024,  7, 15, 12,  0),
        ]

        let policies: [TimeZone.DaylightSavingTimePolicy] = [.former, .latter]
        var divergences: [String] = []

        for (label, y, mo, d, h, mi) in probes {
            let rd = rdAtMidnightUTC(y, mo, d)
            let secondsInDay = Double(h) * 3600 + Double(mi) * 60

            var gregDC = DateComponents()
            gregDC.year = y; gregDC.month = mo; gregDC.day = d
            gregDC.hour = h; gregDC.minute = mi; gregDC.second = 0
            gregDC.timeZone = la

            for repeated in policies {
                for skipped in policies {
                    // Hebrew side
                    let hebrewDate = hebrew.utcDate(
                        fromRataDie: rd, secondsInDay: secondsInDay, in: la,
                        repeatedTimePolicy: repeated, skippedTimePolicy: skipped
                    )

                    // Gregorian reference (canonical TZ-aware wall-clock → UTC)
                    let gregDate = try gregorian.date(
                        from: gregDC, inTimeZone: la,
                        dstRepeatedTimePolicy: repeated, dstSkippedTimePolicy: skipped
                    )

                    if hebrewDate != gregDate {
                        divergences.append(
                            "[\(label)] (rep=\(repeated), skip=\(skipped)): hebrew=\(hebrewDate) greg=\(gregDate) diff=\(hebrewDate.timeIntervalSince(gregDate))s"
                        )
                    }
                }
            }
        }

        if !divergences.isEmpty {
            print("\nDST policy parity divergences (\(divergences.count)):")
            for d in divergences.prefix(40) { print("  \(d)") }
            if divergences.count > 40 {
                print("  … (truncated at 40; total \(divergences.count))")
            }
        }
        #expect(
            divergences.isEmpty,
            "\(divergences.count) Hebrew/Gregorian utcDate divergences across DST policy combinations"
        )
    }

    /// End-to-end check: for each of the 4 policy combinations, verify that
    /// converting Hebrew (year, civilMonth, day, hour, minute) to a Date via
    /// `Calendar(.hebrew).date(from:)` produces the same answer as the equivalent
    /// Gregorian `Calendar(.gregorian).date(from:)` at the same Gregorian wall-clock.
    /// This goes through the public `Calendar` wrapper and therefore exercises
    /// the default `.former, .former` policies that `_CalendarHebrew.date(from:)`
    /// applies internally.
    @Test func date_from_hebrewVsGregorian_atDSTBoundaries() {
        guard let la = TimeZone(identifier: "America/Los_Angeles") else {
            Issue.record("America/Los_Angeles timezone unavailable")
            return
        }

        let hebrewInner = _CalendarHebrew(
            identifier: .hebrew, timeZone: la, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let hebrewCal = Calendar(inner: hebrewInner)
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = la

        // For each Greg wall-clock at a DST boundary, build the same wall-clock
        // via the Hebrew calendar (using its civil-month decomposition of the
        // corresponding Greg date) and compare resulting Dates.
        let probes: [(String, Int, Int, Int, Int, Int)] = [
            ("fall-back 01:30 LA",     2024, 11,  3,  1, 30),
            ("fall-back 02:30 LA",     2024, 11,  3,  2, 30),
            ("spring-forward 02:30",   2024,  3, 10,  2, 30),
            ("spring-forward 03:00",   2024,  3, 10,  3,  0),
            ("LA 2025 fall 01:30",     2025, 11,  2,  1, 30),
            ("LA 2025 spring 02:30",   2025,  3,  9,  2, 30),
            ("non-DST midsummer",      2024,  7, 15, 12,  0),
        ]

        for (label, y, mo, d, h, mi) in probes {
            // Greg side: build the wall-clock directly.
            var gregDC = DateComponents()
            gregDC.year = y; gregDC.month = mo; gregDC.day = d
            gregDC.hour = h; gregDC.minute = mi
            gregDC.timeZone = la
            guard let gregDate = gregCal.date(from: gregDC) else {
                Issue.record("[\(label)] Greg date(from:) returned nil")
                continue
            }

            // Hebrew side: get Hebrew y/m/d for the Greg date, build via Hebrew calendar.
            let hebComps = hebrewCal.dateComponents([.year, .month, .day], from: gregDate)
            var hebDC = DateComponents()
            hebDC.era = 0
            hebDC.year = hebComps.year
            hebDC.month = hebComps.month
            hebDC.day = hebComps.day
            hebDC.hour = h
            hebDC.minute = mi
            hebDC.timeZone = la
            guard let hebDate = hebrewCal.date(from: hebDC) else {
                Issue.record("[\(label)] Hebrew date(from:) returned nil")
                continue
            }

            #expect(
                hebDate == gregDate,
                "[\(label)] hebrew=\(hebDate) greg=\(gregDate) diff=\(hebDate.timeIntervalSince(gregDate))s"
            )
        }
    }
}
