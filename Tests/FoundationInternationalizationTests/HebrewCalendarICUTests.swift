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

    @Test func nextDateOnSameWeekdayLaterInDay() throws {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let start = Date(timeIntervalSince1970: 1_765_537_200) // 2025-12-12 12:00 in Paris
        let components = DateComponents(hour: 20, minute: 31, second: 41, weekday: 6)

        let result = try #require(calendar.nextDate(after: start, matching: components, matchingPolicy: .nextTime))

        #expect(result == Date(timeIntervalSince1970: 1_765_567_901)) // 2025-12-12 20:31:41 in Paris
    }

    @Test func nextDateInRepeatedHourAfterStart() throws {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let start = Date(timeIntervalSince1970: 1_729_990_800) // 2024-10-27 01:00 UTC
        let components = DateComponents(hour: 2, minute: 30, second: 0)

        let result = try #require(calendar.nextDate(after: start, matching: components, matchingPolicy: .nextTime))

        #expect(result == Date(timeIntervalSince1970: 1_729_992_600)) // 2024-10-27 01:30 UTC
    }

    @Test func nextDateInSkippedHourUsesTransition() throws {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let start = Date(timeIntervalSince1970: 1_837_594_800) // 2028-03-25 12:00 in Paris
        let components = DateComponents(hour: 2, minute: 26, second: 0)

        let result = try #require(calendar.nextDate(after: start, matching: components, matchingPolicy: .nextTime))

        #expect(result == Date(timeIntervalSince1970: 1_837_645_200)) // 2028-03-26 03:00 in Paris
    }

    @Test func nextDateForDayMissingFromRequestedMonth() throws {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let start = Date(timeIntervalSince1970: 1_697_407_200) // 5784 Heshvan 1 at midnight in Paris
        let components = DateComponents(month: 3, day: 30)

        let result = try #require(calendar.nextDate(after: start, matching: components, matchingPolicy: .nextTime))

        #expect(result == Date(timeIntervalSince1970: 1_702_422_000)) // 5784 Tevet 1 at midnight in Paris
    }

    @Test func nextDateWithNegativeDayDoesNotTrap() {
        let calendar = Calendar(identifier: .hebrew)
        let start = Date(timeIntervalSince1970: 1_765_537_200)

        let result = calendar.nextDate(after: start, matching: DateComponents(day: -3), matchingPolicy: .nextTime)

        #expect(result == nil)
    }
}
