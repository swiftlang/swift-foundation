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

/// RecurrenceRule parity probe: compares date sequences from `recurrences(of:)` between the ICU backed Buddhist calendar and `_CalendarGregorian`.
@Suite("Buddhist RecurrenceRule Parity Probe")
private struct BuddhistRecurrenceRuleParityProbe {

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        let icuInner = _CalendarICU(
            identifier: .buddhist, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let oursInner = _CalendarGregorian(
            identifier: .buddhist, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        return (Calendar(inner: icuInner), Calendar(inner: oursInner))
    }

    private static func gregorianDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = 12; components.timeZone = .gmt
        guard let date = cal.date(from: components) else {
            preconditionFailure("invalid Gregorian probe date \(year)-\(month)-\(day)")
        }
        return date
    }

    private static func collect(rule: Calendar.RecurrenceRule, from start: Date, count: Int) -> [Date] {
        Array(rule.recurrences(of: start).prefix(count))
    }

    private static let anchors: [(label: String, date: Date)] = [
        ("2020-01-01", gregorianDate(2020, 1, 1)),
        ("2024-06-15", gregorianDate(2024, 6, 15)),
        ("2025-09-23", gregorianDate(2025, 9, 23)),
        ("2026-06-11", gregorianDate(2026, 6, 11)),
    ]

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_christmas() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [12]; icuRule.daysOfTheMonth = [25]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [12]; ourRule.daysOfTheMonth = [25]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func monthly_firstOfMonth() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(12))
            icuRule.daysOfTheMonth = [1]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(12))
            ourRule.daysOfTheMonth = [1]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 12)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 12)
            for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func weekly_mondays() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .weekly, end: .afterOccurrences(8))
            icuRule.weekdays = [.every(.monday)]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .weekly, end: .afterOccurrences(8))
            ourRule.weekdays = [.every(.monday)]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 8)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 8)
            for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_thanksgivingShape() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [11]; icuRule.weekdays = [.nth(4, .thursday)]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [11]; ourRule.weekdays = [.nth(4, .thursday)]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }
}
