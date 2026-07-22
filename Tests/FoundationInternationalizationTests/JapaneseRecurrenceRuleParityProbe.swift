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

/// RecurrenceRule parity probe: compares date sequences from `recurrences(of:)` between the ICU backed Japanese calendar and `_CalendarJapanese`. Includes era transition tests.
@Suite("Japanese RecurrenceRule Parity Probe")
private struct JapaneseRecurrenceRuleParityProbe {

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        var icu = Calendar(identifier: .japanese)
        icu.timeZone = .gmt
        let oursInner = _CalendarJapanese(identifier: .japanese, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        return (icu, Calendar(inner: oursInner))
    }

    private static func g(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d; dc.hour = 12; dc.timeZone = .gmt
        return cal.date(from: dc)!
    }

    private static func collect(rule: Calendar.RecurrenceRule, from start: Date, count: Int) -> [Date] {
        Array(rule.recurrences(of: start).prefix(count))
    }

    private static let anchors: [(label: String, date: Date)] = [
        ("Heisei 2015-03-01", g(2015, 3, 1)),
        ("Heisei→Reiwa 2018-11-15", g(2018, 11, 15)),
        ("Reiwa 2020-01-01", g(2020, 1, 1)),
        ("Reiwa 2024-06-15", g(2024, 6, 15)),
        ("Reiwa 2025-09-23", g(2025, 9, 23)),
        ("Reiwa 2026-06-11", g(2026, 6, 11)),
    ]

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_christmas() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            rI.months = [12]; rI.daysOfTheMonth = [25]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            rO.months = [12]; rO.daysOfTheMonth = [25]
            let i = Self.collect(rule: rI, from: anchor, count: 5)
            let o = Self.collect(rule: rO, from: anchor, count: 5)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
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
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            rI.months = [5]; rI.daysOfTheMonth = [3]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            rO.months = [5]; rO.daysOfTheMonth = [3]
            let i = Self.collect(rule: rI, from: anchor, count: 5)
            let o = Self.collect(rule: rO, from: anchor, count: 5)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
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
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(12))
            rI.daysOfTheMonth = [1]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(12))
            rO.daysOfTheMonth = [1]
            let i = Self.collect(rule: rI, from: anchor, count: 12)
            let o = Self.collect(rule: rO, from: anchor, count: 12)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func monthly_acrossHeiseiReiwaBoundary() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        let anchor = Self.g(2018, 3, 1)
        var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(24))
        rI.daysOfTheMonth = [1]
        var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(24))
        rO.daysOfTheMonth = [1]
        let i = Self.collect(rule: rI, from: anchor, count: 24)
        let o = Self.collect(rule: rO, from: anchor, count: 24)
        for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
            failures.append("[2018-03-01][\(idx)]")
        }
        #expect(failures.isEmpty, "\(failures.count) divergences across Heisei→Reiwa boundary")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_mayFirst_acrossEraBoundaries() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for anchor in [Self.g(2017, 1, 1), Self.g(2018, 6, 15), Self.g(2019, 4, 1)] {
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            rI.months = [5]; rI.daysOfTheMonth = [1]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            rO.months = [5]; rO.daysOfTheMonth = [1]
            let i = Self.collect(rule: rI, from: anchor, count: 5)
            let o = Self.collect(rule: rO, from: anchor, count: 5)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
                failures.append("[\(anchor)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func daily_acrossHeiseiReiwaBoundary() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        let anchor = Self.g(2019, 4, 15)
        let rI = Calendar.RecurrenceRule(calendar: icu, frequency: .daily, end: .afterOccurrences(60))
        let rO = Calendar.RecurrenceRule(calendar: ours, frequency: .daily, end: .afterOccurrences(60))
        let i = Self.collect(rule: rI, from: anchor, count: 60)
        let o = Self.collect(rule: rO, from: anchor, count: 60)
        for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
            failures.append("[2019-04-15][\(idx)]")
        }
        #expect(failures.isEmpty, "\(failures.count) divergences across era boundary")
    }
}
