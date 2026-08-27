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

/// RecurrenceRule parity probe: compares date sequences from `recurrences(of:)` between the ICU backed Japanese calendar and `_CalendarGregorian`. Includes era transition tests.
@Suite("Japanese RecurrenceRule Parity Probe")
private struct JapaneseRecurrenceRuleParityProbe {

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        let icuInner = _CalendarICU(
            identifier: .japanese, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let oursInner = _CalendarGregorian(
            identifier: .japanese, timeZone: .gmt, locale: nil,
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
        ("Heisei 2015-03-01", gregorianDate(2015, 3, 1)),
        ("Heisei→Reiwa 2018-11-15", gregorianDate(2018, 11, 15)),
        ("Reiwa 2020-01-01", gregorianDate(2020, 1, 1)),
        ("Reiwa 2024-06-15", gregorianDate(2024, 6, 15)),
        ("Reiwa 2025-09-23", gregorianDate(2025, 9, 23)),
        ("Reiwa 2026-06-11", gregorianDate(2026, 6, 11)),
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
    @Test func yearly_constitutionDay() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [5]; icuRule.daysOfTheMonth = [3]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [5]; ourRule.daysOfTheMonth = [3]
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
    @Test func monthly_acrossHeiseiReiwaBoundary() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        let anchor = Self.gregorianDate(2018, 3, 1)
        var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(24))
        icuRule.daysOfTheMonth = [1]
        var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(24))
        ourRule.daysOfTheMonth = [1]
        let icuDates = Self.collect(rule: icuRule, from: anchor, count: 24)
        let ourDates = Self.collect(rule: ourRule, from: anchor, count: 24)
        for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
            failures.append("[2018-03-01][\(idx)]")
        }
        #expect(failures.isEmpty, "\(failures.count) divergences across Heisei→Reiwa boundary")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_mayFirst_acrossEraBoundaries() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for anchor in [Self.gregorianDate(2017, 1, 1), Self.gregorianDate(2018, 6, 15), Self.gregorianDate(2019, 4, 1)] {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [5]; icuRule.daysOfTheMonth = [1]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [5]; ourRule.daysOfTheMonth = [1]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
                failures.append("[\(anchor)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func daily_acrossHeiseiReiwaBoundary() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        let anchor = Self.gregorianDate(2019, 4, 15)
        let icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .daily, end: .afterOccurrences(60))
        let ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .daily, end: .afterOccurrences(60))
        let icuDates = Self.collect(rule: icuRule, from: anchor, count: 60)
        let ourDates = Self.collect(rule: ourRule, from: anchor, count: 60)
        for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
            failures.append("[2019-04-15][\(idx)]")
        }
        #expect(failures.isEmpty, "\(failures.count) divergences across era boundary")
    }
}
