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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif

private enum WeekYearCalendarBackend: String, CaseIterable, Sendable {
    case publicAPI, gregorian, icu

    func calendar(timeZone: TimeZone, firstWeekday: Int = 2, minimumDaysInFirstWeek: Int = 4) -> Calendar {
        switch self {
        case .gregorian:
            return Calendar(inner: _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil))
        case .icu:
            return Calendar(inner: _CalendarICU(identifier: .gregorian, timeZone: timeZone, locale: nil, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil))
        case .publicAPI:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            calendar.firstWeekday = firstWeekday
            calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
            return calendar
        }
    }
}

@Suite("Calendar week-year matching", .tags(.calendar))
private struct CalendarWeekYearTests {
    @Test(arguments: WeekYearCalendarBackend.allCases, ["GMT", "Europe/Berlin"])
    func matchingCivilDate(backend: WeekYearCalendarBackend, timeZoneIdentifier: String) throws {
        let timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        let calendar = backend.calendar(timeZone: timeZone)
        // Each row specifies a civil date at 09:00, its ISO week-year, and the expected GMT and Berlin instants.
        let cases: [(year: Int, month: Int, day: Int, weekYear: Int, gmt: Double, berlin: Double)] = [
            (2025, 5, 2, 2025, 1746176400.0, 1746169200.0),
            (2026, 5, 2, 2026, 1777712400.0, 1777705200.0),
            (2027, 5, 2, 2027, 1809248400.0, 1809241200.0),
            (2027, 5, 3, 2027, 1809334800.0, 1809327600.0),
            (2028, 12, 10, 2028, 1860051600.0, 1860048000.0),
            (2027, 1, 3, 2026, 1798966800.0, 1798963200.0),
            (2027, 1, 4, 2027, 1799053200.0, 1799049600.0),
            (2028, 1, 1, 2027, 1830330000.0, 1830326400.0),
            (2028, 1, 3, 2028, 1830502800.0, 1830499200.0),
            (2027, 3, 28, 2027, 1806224400.0, 1806217200.0),
            (2027, 10, 31, 2027, 1824973200.0, 1824969600.0),
        ]
        for (year, month, day, weekYear, utc, berlin) in cases {
            let expected = Date(timeIntervalSince1970: timeZoneIdentifier == "GMT" ? utc : berlin)
            for includeWeekYear in [false, true] {
                let components = DateComponents(year: year, month: month, day: day, hour: 9, minute: 0, second: 0, yearForWeekOfYear: includeWeekYear ? weekYear : nil)
                #expect(calendar.date(expected, matchesComponents: components))
                for direction in [Calendar.SearchDirection.forward, .backward] {
                    let start = try #require(calendar.date(from: DateComponents(year: direction == .forward ? year - 1 : year + 1, month: 10, day: 9)))
                    for policy in [Calendar.MatchingPolicy.strict, .nextTime, .nextTimePreservingSmallerComponents, .previousTimePreservingSmallerComponents] {
                        let result = calendar.nextDate(after: start, matching: components, matchingPolicy: policy, direction: direction)
                        #expect(result == expected, "year: \(year), month: \(month), day: \(day), weekYear: \(includeWeekYear), direction: \(direction), policy: \(policy)")
                    }
                }
            }
        }
    }

    @Test(arguments: WeekYearCalendarBackend.allCases, ["GMT", "Europe/Berlin"])
    func matchingWeekDate(backend: WeekYearCalendarBackend, timeZoneIdentifier: String) throws {
        let timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
        let calendar = backend.calendar(timeZone: timeZone)
        let cases: [(weekYear: Int, week: Int, weekday: Int, gmt: Double, berlin: Double)] = [
            (2027, 1, 2, 1799053200.0, 1799049600.0), // 2027-01-04 at 09:00
            (2027, 52, 1, 1830416400.0, 1830412800.0), // 2028-01-02 at 09:00
            (2028, 1, 2, 1830502800.0, 1830499200.0), // 2028-01-03 at 09:00
        ]
        for (weekYear, week, weekday, gmt, berlin) in cases {
            let expected = Date(timeIntervalSince1970: timeZoneIdentifier == "GMT" ? gmt : berlin)
            let components = DateComponents(hour: 9, minute: 0, second: 0, weekday: weekday, weekOfYear: week, yearForWeekOfYear: weekYear)
            #expect(calendar.date(expected, matchesComponents: components))
            for direction in [Calendar.SearchDirection.forward, .backward] {
                let start = try #require(calendar.date(from: DateComponents(year: direction == .forward ? weekYear - 1 : weekYear + 2, month: 10, day: 9)))
                for policy in [Calendar.MatchingPolicy.strict, .nextTime, .nextTimePreservingSmallerComponents, .previousTimePreservingSmallerComponents] {
                    #expect(calendar.nextDate(after: start, matching: components, matchingPolicy: policy, direction: direction) == expected, "weekYear: \(weekYear), week: \(week), direction: \(direction), policy: \(policy)")
                }
            }
        }
    }

    @Test(arguments: 1...7, 1...7)
    func matchingWithWeekSettings(firstWeekday: Int, minimumDaysInFirstWeek: Int) throws {
        let expected = Date(timeIntervalSince1970: 1809248400) // 2027-05-02T09:00:00Z
        let components = DateComponents(year: 2027, month: 5, day: 2, hour: 9, minute: 0, second: 0, yearForWeekOfYear: 2027)
        for backend in WeekYearCalendarBackend.allCases {
            let calendar = backend.calendar(timeZone: .gmt, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
            for direction in [Calendar.SearchDirection.forward, .backward] {
                let start = try #require(calendar.date(from: DateComponents(year: direction == .forward ? 2026 : 2028, month: 10, day: 9)))
                #expect(calendar.nextDate(after: start, matching: components, matchingPolicy: .strict, direction: direction) == expected, "backend: \(backend), direction: \(direction)")
            }
        }
    }

    @Test(arguments: WeekYearCalendarBackend.allCases)
    func conflictingWeekYear(backend: WeekYearCalendarBackend) throws {
        let calendar = backend.calendar(timeZone: .gmt)
        // May 2, 2027 belongs to week-year 2027, so week-year 2026 cannot also match.
        let components = DateComponents(year: 2027, month: 5, day: 2, yearForWeekOfYear: 2026)
        for direction in [Calendar.SearchDirection.forward, .backward] {
            let start = try #require(calendar.date(from: DateComponents(year: direction == .forward ? 2026 : 2028, month: 10, day: 9)))
            #expect(calendar.nextDate(after: start, matching: components, matchingPolicy: .strict, direction: direction) == nil)
        }
    }
}
