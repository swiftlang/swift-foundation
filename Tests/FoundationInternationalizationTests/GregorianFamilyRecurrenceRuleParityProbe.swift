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

/// Compares `recurrences(of:)` sequences between the ICU-backed calendar and `_CalendarGregorian` for the three Gregorian-family calendars. Covers each one's era transition where it has one.
@Suite("Gregorian Family RecurrenceRule Parity Probe")
private struct GregorianFamilyRecurrenceRuleParityProbe {

    private enum Family: String, Sendable, CaseIterable, CustomTestStringConvertible {
        case buddhist, japanese, roc

        var identifier: Calendar.Identifier {
            switch self {
            case .buddhist: return .buddhist
            case .japanese: return .japanese
            case .roc: return .republicOfChina
            }
        }

        var pair: (icu: Calendar, ours: Calendar) {
            let icuInner = _CalendarICU(
                identifier: identifier, timeZone: .gmt, locale: nil,
                firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
            )
            let oursInner = _CalendarGregorian(
                identifier: identifier, timeZone: .gmt, locale: nil,
                firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
            )
            return (Calendar(inner: icuInner), Calendar(inner: oursInner))
        }

        /// Anchors inside this calendar's own eras, plus era-transition anchors where the calendar has more than one era in the modern range.
        var anchors: [(label: String, date: Date)] {
            let modern: [(label: String, date: Date)] = [
                ("2020-01-01", gregorianDate(2020, 1, 1)),
                ("2024-06-15", gregorianDate(2024, 6, 15)),
                ("2025-09-23", gregorianDate(2025, 9, 23)),
                ("2026-06-11", gregorianDate(2026, 6, 11)),
            ]
            switch self {
            case .buddhist:
                return modern
            case .japanese:
                return [
                    ("Heisei 2015-03-01", gregorianDate(2015, 3, 1)),
                    ("Heisei→Reiwa 2018-11-15", gregorianDate(2018, 11, 15)),
                ] + modern.map { ("Reiwa \($0.label)", $0.date) }
            case .roc:
                return [
                    ("Before Minguo 1911-06-15", gregorianDate(1911, 6, 15)),
                    ("Before Minguo→Minguo 1911-11-15", gregorianDate(1911, 11, 15)),
                ] + modern.map { ("Minguo \($0.label)", $0.date) }
            }
        }

        var testDescription: String { rawValue }
    }

    /// One family's era-boundary probe. Buddhist has no boundary in the modern range, so it does not appear here.
    private struct BoundaryCase: Sendable, CustomTestStringConvertible {
        let family: Family
        let boundaryLabel: String
        let monthlyAnchor: (year: Int, month: Int, day: Int)
        let yearlyAnchors: [(year: Int, month: Int, day: Int)]
        let dailyAnchor: (year: Int, month: Int, day: Int)
        var testDescription: String { family.rawValue }
    }

    private static let boundaryCases: [BoundaryCase] = [
        BoundaryCase(
            family: .japanese, boundaryLabel: "Heisei→Reiwa",
            monthlyAnchor: (2018, 3, 1),
            yearlyAnchors: [(2017, 1, 1), (2018, 6, 15), (2019, 4, 1)],
            dailyAnchor: (2019, 4, 15)
        ),
        BoundaryCase(
            family: .roc, boundaryLabel: "Before-Minguo to Minguo",
            monthlyAnchor: (1911, 8, 1),
            yearlyAnchors: [(1909, 1, 1), (1911, 6, 15), (1912, 3, 1)],
            dailyAnchor: (1911, 12, 15)
        ),
    ]

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

    private static func divergences(icu icuDates: [Date], ours ourDates: [Date], label: (Int) -> String) -> [String] {
        var failures: [String] = []
        for idx in 0..<max(icuDates.count, ourDates.count) where idx >= icuDates.count || idx >= ourDates.count || icuDates[idx] != ourDates[idx] {
            failures.append(label(idx))
        }
        return failures
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: Family.allCases)
    private func yearly_christmas(_ family: Family) {
        let (icu, ours) = family.pair
        var failures: [String] = []
        for (label, anchor) in family.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [12]; icuRule.daysOfTheMonth = [25]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [12]; ourRule.daysOfTheMonth = [25]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(label)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: Family.allCases)
    private func monthly_firstOfMonth(_ family: Family) {
        let (icu, ours) = family.pair
        var failures: [String] = []
        for (label, anchor) in family.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(12))
            icuRule.daysOfTheMonth = [1]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(12))
            ourRule.daysOfTheMonth = [1]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 12)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 12)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(label)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    /// Only Buddhist and ROC carry this test. The original Japanese probe never had a weekly case.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: [Family.buddhist, .roc])
    private func weekly_mondays(_ family: Family) {
        let (icu, ours) = family.pair
        var failures: [String] = []
        for (label, anchor) in family.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .weekly, end: .afterOccurrences(8))
            icuRule.weekdays = [.every(.monday)]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .weekly, end: .afterOccurrences(8))
            ourRule.weekdays = [.every(.monday)]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 8)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 8)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(label)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    /// Only the Buddhist probe carried this shape.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_thanksgivingShape_buddhist() {
        let (icu, ours) = Family.buddhist.pair
        var failures: [String] = []
        for (label, anchor) in Family.buddhist.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [11]; icuRule.weekdays = [.nth(4, .thursday)]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [11]; ourRule.weekdays = [.nth(4, .thursday)]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(label)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    /// Only the Japanese probe carried this shape.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_constitutionDay_japanese() {
        let (icu, ours) = Family.japanese.pair
        var failures: [String] = []
        for (label, anchor) in Family.japanese.anchors {
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [5]; icuRule.daysOfTheMonth = [3]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [5]; ourRule.daysOfTheMonth = [3]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(label)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: boundaryCases)
    private func monthly_acrossEraBoundary(_ boundary: BoundaryCase) {
        let (icu, ours) = boundary.family.pair
        let anchor = Self.gregorianDate(boundary.monthlyAnchor.year, boundary.monthlyAnchor.month, boundary.monthlyAnchor.day)
        var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .monthly, end: .afterOccurrences(24))
        icuRule.daysOfTheMonth = [1]
        var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .monthly, end: .afterOccurrences(24))
        ourRule.daysOfTheMonth = [1]
        let icuDates = Self.collect(rule: icuRule, from: anchor, count: 24)
        let ourDates = Self.collect(rule: ourRule, from: anchor, count: 24)
        let failures = Self.divergences(icu: icuDates, ours: ourDates) { "[\($0)]" }
        #expect(failures.isEmpty, "\(failures.count) divergences across the \(boundary.boundaryLabel) boundary")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: boundaryCases)
    private func yearly_acrossEraBoundary(_ boundary: BoundaryCase) {
        let (icu, ours) = boundary.family.pair
        var failures: [String] = []
        for anchorComponents in boundary.yearlyAnchors {
            let anchor = Self.gregorianDate(anchorComponents.year, anchorComponents.month, anchorComponents.day)
            var icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .yearly, end: .afterOccurrences(5))
            icuRule.months = [1]; icuRule.daysOfTheMonth = [1]
            var ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .yearly, end: .afterOccurrences(5))
            ourRule.months = [1]; ourRule.daysOfTheMonth = [1]
            let icuDates = Self.collect(rule: icuRule, from: anchor, count: 5)
            let ourDates = Self.collect(rule: ourRule, from: anchor, count: 5)
            failures += Self.divergences(icu: icuDates, ours: ourDates) { "[\(anchor)][\($0)]" }
        }
        #expect(failures.isEmpty, "\(failures.count) divergences")
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test(arguments: boundaryCases)
    private func daily_acrossEraBoundary(_ boundary: BoundaryCase) {
        let (icu, ours) = boundary.family.pair
        let anchor = Self.gregorianDate(boundary.dailyAnchor.year, boundary.dailyAnchor.month, boundary.dailyAnchor.day)
        let icuRule = Calendar.RecurrenceRule(calendar: icu, frequency: .daily, end: .afterOccurrences(60))
        let ourRule = Calendar.RecurrenceRule(calendar: ours, frequency: .daily, end: .afterOccurrences(60))
        let icuDates = Self.collect(rule: icuRule, from: anchor, count: 60)
        let ourDates = Self.collect(rule: ourRule, from: anchor, count: 60)
        let failures = Self.divergences(icu: icuDates, ours: ourDates) { "[\($0)]" }
        #expect(failures.isEmpty, "\(failures.count) divergences across the \(boundary.boundaryLabel) boundary")
    }
}
