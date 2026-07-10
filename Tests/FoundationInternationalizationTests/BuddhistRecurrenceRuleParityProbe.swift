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

/// RecurrenceRule parity probe: compares date sequences from `recurrences(of:)` between the ICU backed Buddhist calendar and `_CalendarBuddhist`.
@Suite("Buddhist RecurrenceRule Parity Probe")
private struct BuddhistRecurrenceRuleParityProbe {

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        var icu = Calendar(identifier: .buddhist)
        icu.timeZone = .gmt
        let oursInner = _CalendarBuddhist(identifier: .buddhist, timeZone: .gmt, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
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
        ("2020-01-01", g(2020, 1, 1)),
        ("2024-06-15", g(2024, 6, 15)),
        ("2025-09-23", g(2025, 9, 23)),
        ("2026-06-11", g(2026, 6, 11)),
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
    @Test func weekly_mondays() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        for (label, anchor) in Self.anchors {
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .weekly, end: .afterOccurrences(8))
            rI.weekdays = [.every(.monday)]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .weekly, end: .afterOccurrences(8))
            rO.weekdays = [.every(.monday)]
            let i = Self.collect(rule: rI, from: anchor, count: 8)
            let o = Self.collect(rule: rO, from: anchor, count: 8)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
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
            var rI = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            rI.months = [11]; rI.weekdays = [.nth(4, .thursday)]
            var rO = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            rO.months = [11]; rO.weekdays = [.nth(4, .thursday)]
            let i = Self.collect(rule: rI, from: anchor, count: 5)
            let o = Self.collect(rule: rO, from: anchor, count: 5)
            for idx in 0..<max(i.count, o.count) where idx >= i.count || idx >= o.count || i[idx] != o[idx] {
                failures.append("[\(label)][\(idx)]")
            }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }
}
