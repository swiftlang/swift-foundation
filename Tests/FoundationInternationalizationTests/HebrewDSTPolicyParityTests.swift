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

// DST policy parity between `_CalendarHebrew` and `_CalendarGregorian`.
//
// Lives in FoundationInternationalizationTests because it needs
// `TimeZone(identifier: "America/Los_Angeles")`, which requires the ICU-backed
// TimeZone implementation only linked when FoundationInternationalization is
// part of the test target's dependency graph.
@Suite("Hebrew DST Policy Parity")
private struct HebrewDSTPolicyParityTests {

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
