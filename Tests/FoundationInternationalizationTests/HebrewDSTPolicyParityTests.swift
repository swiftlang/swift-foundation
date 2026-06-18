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

    struct DSTProbe: CustomTestStringConvertible, Sendable {
        let label: String
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int

        var testDescription: String { label }
    }

    static let utcDateProbes: [DSTProbe] = [
        // LA fall-back 2024-11-03: 02:00 PDT -> 01:00 PST (01:00-01:59 repeats)
        DSTProbe(label: "fall-back day, 00:30 (unambiguous PDT)", year: 2024, month: 11, day: 3, hour: 0, minute: 30),
        DSTProbe(label: "fall-back day, 01:00 (start of repeat)", year: 2024, month: 11, day: 3, hour: 1, minute: 0),
        DSTProbe(label: "fall-back day, 01:30 (mid repeat)", year: 2024, month: 11, day: 3, hour: 1, minute: 30),
        DSTProbe(label: "fall-back day, 01:59 (end of repeat)", year: 2024, month: 11, day: 3, hour: 1, minute: 59),
        DSTProbe(label: "fall-back day, 02:00 (post-transition)", year: 2024, month: 11, day: 3, hour: 2, minute: 0),
        DSTProbe(label: "fall-back day, 02:30 (unambiguous PST)", year: 2024, month: 11, day: 3, hour: 2, minute: 30),

        // LA spring-forward 2024-03-10: 02:00 PST -> 03:00 PDT (02:00-02:59 skipped)
        DSTProbe(label: "spring-forward, 01:30 (unambiguous PST)", year: 2024, month: 3, day: 10, hour: 1, minute: 30),
        DSTProbe(label: "spring-forward, 01:59 (last pre-skip)", year: 2024, month: 3, day: 10, hour: 1, minute: 59),
        DSTProbe(label: "spring-forward, 02:00 (start of skip)", year: 2024, month: 3, day: 10, hour: 2, minute: 0),
        DSTProbe(label: "spring-forward, 02:30 (mid skip)", year: 2024, month: 3, day: 10, hour: 2, minute: 30),
        DSTProbe(label: "spring-forward, 02:59 (end of skip)", year: 2024, month: 3, day: 10, hour: 2, minute: 59),
        DSTProbe(label: "spring-forward, 03:00 (post-transition)", year: 2024, month: 3, day: 10, hour: 3, minute: 0),
        DSTProbe(label: "spring-forward, 03:30 (unambiguous PDT)", year: 2024, month: 3, day: 10, hour: 3, minute: 30),

        // 2025 transitions
        DSTProbe(label: "LA 2025 fall-back, 01:30 (mid repeat)", year: 2025, month: 11, day: 2, hour: 1, minute: 30),
        DSTProbe(label: "LA 2025 spring-forward, 02:30 (skipped)", year: 2025, month: 3, day: 9, hour: 2, minute: 30),

        // Non-DST baseline (all 4 combinations agree, no policy effect)
        DSTProbe(label: "non-DST baseline, 12:00 mid-summer", year: 2024, month: 7, day: 15, hour: 12, minute: 0),
    ]

    static let dateFromProbes: [DSTProbe] = [
        DSTProbe(label: "fall-back 01:30 LA", year: 2024, month: 11, day: 3, hour: 1, minute: 30),
        DSTProbe(label: "fall-back 02:30 LA", year: 2024, month: 11, day: 3, hour: 2, minute: 30),
        DSTProbe(label: "spring-forward 02:30", year: 2024, month: 3, day: 10, hour: 2, minute: 30),
        DSTProbe(label: "spring-forward 03:00", year: 2024, month: 3, day: 10, hour: 3, minute: 0),
        DSTProbe(label: "LA 2025 fall 01:30", year: 2025, month: 11, day: 2, hour: 1, minute: 30),
        DSTProbe(label: "LA 2025 spring 02:30", year: 2025, month: 3, day: 9, hour: 2, minute: 30),
        DSTProbe(label: "non-DST midsummer", year: 2024, month: 7, day: 15, hour: 12, minute: 0),
    ]

    @Test(arguments: utcDateProbes)
    func utcDate_allPolicyCombinations_matchGregorian(probe: DSTProbe) throws {
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

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var dc = DateComponents()
        dc.year = probe.year; dc.month = probe.month; dc.day = probe.day; dc.timeZone = .gmt
        let date = try #require(cal.date(from: dc))
        let days = Int64(date.timeIntervalSinceReferenceDate / 86400)
        let rd = days + _CalendarHebrew.rataDieAtDateReference

        let secondsInDay = Double(probe.hour) * 3600 + Double(probe.minute) * 60

        var gregDC = DateComponents()
        gregDC.year = probe.year; gregDC.month = probe.month; gregDC.day = probe.day
        gregDC.hour = probe.hour; gregDC.minute = probe.minute; gregDC.second = 0
        gregDC.timeZone = la

        let policies: [TimeZone.DaylightSavingTimePolicy] = [.former, .latter]

        for repeated in policies {
            for skipped in policies {
                let hebrewDate = hebrew.utcDate(
                    fromRataDie: rd, secondsInDay: secondsInDay, in: la,
                    repeatedTimePolicy: repeated, skippedTimePolicy: skipped
                )

                let gregDate = try gregorian.date(
                    from: gregDC, inTimeZone: la,
                    dstRepeatedTimePolicy: repeated, dstSkippedTimePolicy: skipped
                )

                #expect(
                    hebrewDate == gregDate,
                    "[\(probe.label)] (rep=\(repeated), skip=\(skipped)): hebrew=\(hebrewDate) greg=\(gregDate) diff=\(hebrewDate.timeIntervalSince(gregDate))s"
                )
            }
        }
    }

    @Test(arguments: dateFromProbes)
    func date_from_hebrewVsGregorian_atDSTBoundaries(probe: DSTProbe) throws {
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

        var gregDC = DateComponents()
        gregDC.year = probe.year; gregDC.month = probe.month; gregDC.day = probe.day
        gregDC.hour = probe.hour; gregDC.minute = probe.minute
        gregDC.timeZone = la
        let gregDate = try #require(gregCal.date(from: gregDC), "Greg date(from:) returned nil")

        let hebComps = hebrewCal.dateComponents([.year, .month, .day], from: gregDate)
        var hebDC = DateComponents()
        hebDC.era = 0
        hebDC.year = hebComps.year
        hebDC.month = hebComps.month
        hebDC.day = hebComps.day
        hebDC.hour = probe.hour
        hebDC.minute = probe.minute
        hebDC.timeZone = la
        let hebDate = try #require(hebrewCal.date(from: hebDC), "Hebrew date(from:) returned nil")

        #expect(
            hebDate == gregDate,
            "[\(probe.label)] hebrew=\(hebDate) greg=\(gregDate) diff=\(hebDate.timeIntervalSince(gregDate))s"
        )
    }
}
