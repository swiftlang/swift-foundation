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

@Suite("Chinese RecurrenceRule Parity Probe")
private struct ChineseRecurrenceRuleParityProbe {

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        let icuInner = _CalendarICU(
            identifier: .chinese, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let oursInner = _CalendarChinese(
            identifier: .chinese, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        return (Calendar(inner: icuInner), Calendar(inner: oursInner))
    }

    private static func g(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d; dc.hour = 12
        dc.timeZone = .gmt
        guard let date = cal.date(from: dc) else {
            preconditionFailure("invalid Gregorian probe date \(y)-\(m)-\(d)")
        }
        return date
    }

    private static func compare(_ rule: String, _ start: String, _ icu: [Date], _ ours: [Date], failures: inout [String]) {
        if icu.count != ours.count {
            failures.append("[\(rule) from \(start)] count mismatch: ICU=\(icu.count) ours=\(ours.count)")
            return
        }
        for i in 0..<icu.count where icu[i] != ours[i] {
            failures.append("[\(rule) from \(start)][\(i)] ICU=\(icu[i]) ours=\(ours[i])")
        }
    }

    private static func collect(rule: Calendar.RecurrenceRule, from start: Date, count: Int) -> [Date] {
        var result: [Date] = []
        for date in rule.recurrences(of: start) {
            result.append(date)
            if result.count >= count { break }
        }
        return result
    }

    private static let anchors: [(label: String, date: Date)] = [
        ("2020-01-01", g(2020, 1, 1)),   // before leap-4 2020
        ("2023-02-15", g(2023, 2, 15)),  // before leap-2 2023
        ("2025-06-20", g(2025, 6, 20)),  // before leap-6 2025
        ("2026-06-11", g(2026, 6, 11)),
    ]

    @Test func chineseYearly_newYear() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
        ruleIcu.months = [1]
        ruleIcu.daysOfTheMonth = [1]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
        ruleOurs.months = [1]
        ruleOurs.daysOfTheMonth = [1]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 5)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 5)
            Self.compare("chineseYearly_newYear", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }

    @Test func chineseYearly_midAutumn() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
        ruleIcu.months = [8]
        ruleIcu.daysOfTheMonth = [15]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
        ruleOurs.months = [8]
        ruleOurs.daysOfTheMonth = [15]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 5)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 5)
            Self.compare("chineseYearly_midAutumn", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }

    @Test func chineseMonthly_firstOfMonth() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(12))
        ruleIcu.daysOfTheMonth = [1]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(12))
        ruleOurs.daysOfTheMonth = [1]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 12)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 12)
            Self.compare("chineseMonthly_firstOfMonth", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }

    @Test func chineseWeekly_mondays() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .weekly, end: .afterOccurrences(8))
        ruleIcu.weekdays = [.every(.monday)]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .weekly, end: .afterOccurrences(8))
        ruleOurs.weekdays = [.every(.monday)]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 8)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 8)
            Self.compare("chineseWeekly_mondays", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }

    @Test func chineseYearly_nthWeekdayShape() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
        ruleIcu.months = [8]
        ruleIcu.weekdays = [.nth(2, .friday)]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
        ruleOurs.months = [8]
        ruleOurs.weekdays = [.nth(2, .friday)]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 5)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 5)
            Self.compare("chineseYearly_nthWeekdayShape", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }

    @Test func chineseDaily_withTimes() {
        let (icu, ours) = Self.makePair()
        var failures: [String] = []
        var ruleIcu = Calendar.RecurrenceRule(calendar: icu, frequency: .daily, end: .afterOccurrences(10))
        ruleIcu.hours = [9]
        ruleIcu.minutes = [30]
        var ruleOurs = Calendar.RecurrenceRule(calendar: ours, frequency: .daily, end: .afterOccurrences(10))
        ruleOurs.hours = [9]
        ruleOurs.minutes = [30]
        for (label, anchor) in Self.anchors {
            let i = Self.collect(rule: ruleIcu, from: anchor, count: 10)
            let o = Self.collect(rule: ruleOurs, from: anchor, count: 10)
            Self.compare("chineseDaily_withTimes", label, i, o, failures: &failures)
        }
        #expect(failures.isEmpty, "\(failures.count) failures: \(failures.prefix(10))")
    }
}
