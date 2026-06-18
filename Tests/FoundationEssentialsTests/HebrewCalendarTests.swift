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
        #expect(HebrewArithmetic.monthsInYear(5786) == 12) // common
        #expect(HebrewArithmetic.monthsInYear(5787) == 13) // leap
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
            (5786, 1, 1), // Tishrei 1
            (5786, 3, 25), // Kislev 25 (Hanukkah start)
            (5786, 7, 1), // Adar 1 (common year)
            (5786, 8, 15), // Nisan 15 (Passover)
            (5786, 13, 29), // Elul 29 (last day of common year)
            // Leap year 5787
            (5787, 6, 1), // Adar I 1 (leap only)
            (5787, 7, 1), // Adar II 1 (leap)
            (5787, 8, 15), // Nisan 15 (leap — Nisan still month 8)
            (5787, 13, 29), // Elul 29 (last day of leap year)
            // Extreme values
            (1, 1, 1), // Year 1 AM
            (4000, 7, 29), // Late Adar in common year 4000
        ]
        for (y, m, d) in cases {
            var dc = DateComponents()
            dc.era = 0 // Hebrew AM era (ICU convention: 0-based)
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

}
