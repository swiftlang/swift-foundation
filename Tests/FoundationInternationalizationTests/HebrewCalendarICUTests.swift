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

// Tests that exercise Calendar(identifier: .hebrew) and therefore require the
// ICU-backed calendar provided by FoundationInternationalization.
@Suite("Hebrew Calendar")
private struct HebrewCalendarICUTests {

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

    // Verify Calendar(.hebrew).enumerateDates works with the system timezone.
    @Test func hanukkahEnumerateFires_systemTZ() {
        let cal = Calendar(identifier: .hebrew)
        let start = Date(timeIntervalSinceReferenceDate: 496359355.795410)

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
        #expect(matches.count > 0, "system-TZ enumerateDates didn't produce any matches")
    }

    // Verify Calendar(.hebrew).enumerateDates works with an explicit GMT timezone.
    @Test func hanukkahEnumerateFires() {
        var cal = Calendar(identifier: .hebrew)
        cal.timeZone = .gmt
        let start = Date(timeIntervalSinceReferenceDate: 496359355.795410)

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
        #expect(matches.count > 0, "enumerateDates didn't produce any Hanukkah matches")
    }

    // Compare _CalendarHebrew vs the ICU implementation for a range of dates.
    // Once the router is flipped, this becomes a regression oracle against itself.
    @Test func crossCheck_againstICU() {
        let hebrewICU = Calendar(identifier: .hebrew)
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
}
