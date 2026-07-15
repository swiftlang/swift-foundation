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

/// RecurrenceRule parity probe: compares date sequences from `recurrences(of:)`
/// between the ICU backed Hebrew calendar and `_CalendarHebrew`. Verifies that
/// the fast path short circuits in `_unadjustedDates` / `_dates` produce
/// identical results to the generic enumerate framework.
@Suite("Hebrew RecurrenceRule Parity Probe")
private struct HebrewRecurrenceRuleParityProbe {

    // MARK: - Setup

    private static func makePair(timeZone: TimeZone = .gmt) -> (icu: Calendar, ours: Calendar) {
        var icu = Calendar(identifier: .hebrew)
        icu.timeZone = timeZone
        let oursInner = _CalendarHebrew(
            identifier: .hebrew, timeZone: timeZone, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        return (icu, Calendar(inner: oursInner))
    }

    /// Anchor dates spanning leap/common years, year boundaries, and Adar I transitions.
    private static func probeStarts(in timeZone: TimeZone = .gmt) -> [(label: String, date: Date)] {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = timeZone
        func d(_ y: Int, _ m: Int, _ day: Int, hour: Int = 12) -> Date {
            var dc = DateComponents()
            dc.year = y; dc.month = m; dc.day = day; dc.hour = hour; dc.timeZone = timeZone
            return g.date(from: dc)!
        }
        return [
            ("2016-09-23 14:35 (benchmark anchor)",   d(2016, 9, 23, hour: 14)),
            ("2016-02-10 (Adar I, leap)",             d(2016, 2, 10)),
            ("2016-03-11 (Adar II, leap)",            d(2016, 3, 11)),
            ("2017-12-15 (mid common year)",          d(2017, 12, 15)),
            ("2025-09-23 (Tishri 1 common)",          d(2025, 9, 23)),
            ("2015-09-14 (Tishri 1 leap)",            d(2015, 9, 14)),
            ("2025-03-01 (Adar common)",              d(2025, 3, 1)),
            ("2016-12-25 (Hanukkah common)",          d(2016, 12, 25)),
        ]
    }

    private final class Divergences {
        var list: [String] = []
        var compared: Int = 0
        var rulesRun: Int = 0

        func compare(_ rule: String, _ start: String, _ icu: [Date], _ ours: [Date]) {
            rulesRun += 1
            let n = max(icu.count, ours.count)
            for i in 0..<n {
                compared += 1
                let a = i < icu.count ? icu[i] : nil
                let b = i < ours.count ? ours[i] : nil
                if a != b {
                    if list.count < 25 {
                        list.append("[\(rule)] start=\(start) idx=\(i): ICU=\(describe(a)) ours=\(describe(b))")
                    } else if list.count == 25 {
                        list.append("... (more divergences truncated)")
                    }
                }
            }
        }

        private func describe(_ d: Date?) -> String {
            d.map { "\($0)" } ?? "nil"
        }
    }

    /// Drive a single `RecurrenceRule` shape across all probe starts and
    /// compare the date streams between ICU Hebrew and native Hebrew.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    private static func runProbe(name: String,
                                 configure: (Calendar) -> Calendar.RecurrenceRule,
                                 starts: [(String, Date)],
                                 limit: Int,
                                 div: Divergences,
                                 icuCal: Calendar,
                                 oursCal: Calendar) {
        let icuRule = configure(icuCal)
        let ourRule = configure(oursCal)
        for (lbl, start) in starts {
            let icuDates = Array(icuRule.recurrences(of: start).prefix(limit))
            let ourDates = Array(ourRule.recurrences(of: start).prefix(limit))
            div.compare(name, lbl, icuDates, ourDates)
        }
    }

    private static func report(_ name: String, _ div: Divergences) {
        print("[\(name)] rules=\(div.rulesRun) compared=\(div.compared) divergences=\(div.list.count)")
        for d in div.list.prefix(10) { print("  \(d)") }
    }

    // MARK: - Tests

    /// Single combination yearly (Thanksgiving style).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_singleMonth_nthWeekday() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Self.probeStarts()
        let div = Divergences()
        // Civil months: 1=Tishri, 3=Kislev, 7=Adar/AdarII, 11=Tammuz.
        for m in [1, 3, 7, 11] {
            for wd in [Locale.Weekday.sunday, .thursday, .saturday] {
                for n in [1, 2, 4] {
                    Self.runProbe(
                        name: "yearly m=\(m) wd=\(wd) n=\(n)",
                        configure: { cal in
                            var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(5))
                            r.months = [.init(m)]
                            r.weekdays = [.nth(n, wd)]
                            r.matchingPolicy = .nextTime
                            return r
                        },
                        starts: starts, limit: 5, div: div,
                        icuCal: icuCal, oursCal: oursCal
                    )
                }
            }
        }
        Self.report("yearly_singleMonth_nthWeekday", div)
        #expect(div.list.isEmpty, "RecurrenceRule diverges between ICU and our Hebrew on \(div.list.count) date(s)")
    }

    /// Single combination monthly.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func monthly_nthWeekday() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        for wd in [Locale.Weekday.monday, .wednesday, .friday] {
            for n in [1, 2, 4] {
                Self.runProbe(
                    name: "monthly wd=\(wd) n=\(n)",
                    configure: { cal in
                        var r = Calendar.RecurrenceRule(calendar: cal, frequency: .monthly, end: .afterOccurrences(5))
                        r.weekdays = [.nth(n, wd)]
                        r.matchingPolicy = .nextTime
                        return r
                    },
                    starts: starts, limit: 5, div: div,
                    icuCal: icuCal, oursCal: oursCal
                )
            }
        }
        Self.report("monthly_nthWeekday", div)
        #expect(div.list.isEmpty)
    }

    /// Multi combination: hours expansion (ThanksgivingMeals shape).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func yearly_multipleHours() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Self.probeStarts()
        let div = Divergences()
        Self.runProbe(
            name: "yearly m=11 wd=5 n=4 h=[14,18]",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(8))
                r.months = [11]
                r.weekdays = [.nth(4, .thursday)]
                r.hours = [14, 18]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 8, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("yearly_multipleHours", div)
        #expect(div.list.isEmpty)
    }

    /// Multi weekday with positive AND negative ordinals (BikeParties shape).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func monthly_multipleNthWeekdays() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        Self.runProbe(
            name: "monthly [.nth(1, fri), .nth(-1, fri)]",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .monthly, end: .afterOccurrences(10))
                r.weekdays = [.nth(1, .friday), .nth(-1, .friday)]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 10, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("monthly_multipleNthWeekdays", div)
        #expect(div.list.isEmpty)
    }

    /// Daily recurrence with multiple times (DailyWithTimes shape).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func daily_withTimes() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(2))
        let div = Divergences()
        Self.runProbe(
            name: "daily wd=[mon,tue,wed] h=[9,10] mi=[0,30]",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .daily, end: .afterOccurrences(20))
                r.weekdays = [.every(.monday), .every(.tuesday), .every(.wednesday)]
                r.hours = [9, 10]
                r.minutes = [0, 30]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 20, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("daily_withTimes", div)
        #expect(div.list.isEmpty)
    }

    /// Negative ordinals (last X of month).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func negativeOrdinals() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        for wd in [Locale.Weekday.sunday, .friday] {
            for n in [-1, -2] {
                Self.runProbe(
                    name: "monthly wd=\(wd) n=\(n)",
                    configure: { cal in
                        var r = Calendar.RecurrenceRule(calendar: cal, frequency: .monthly, end: .afterOccurrences(5))
                        r.weekdays = [.nth(n, wd)]
                        r.matchingPolicy = .nextTime
                        return r
                    },
                    starts: starts, limit: 5, div: div,
                    icuCal: icuCal, oursCal: oursCal
                )
            }
        }
        Self.report("negativeOrdinals", div)
        #expect(div.list.isEmpty)
    }

    /// Multiple months (quarterly style).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func multipleMonths() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        Self.runProbe(
            name: "yearly months=[1,4,7,10] wd=.nth(1,sun)",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(8))
                r.months = [.init(1), .init(4), .init(7), .init(10)]
                r.weekdays = [.nth(1, .sunday)]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 8, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("multipleMonths", div)
        #expect(div.list.isEmpty)
    }

    /// Adar I (civil month 6, leap year only).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func adarI_leapOnly() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        Self.runProbe(
            name: "yearly m=6 (Adar I) .nth(1,mon)",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(5))
                r.months = [.init(6)]   // Adar I — only exists in leap years
                r.weekdays = [.nth(1, .monday)]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 5, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("adarI_leapOnly", div)
        #expect(div.list.isEmpty)
    }

    /// Single combination yearly with explicit time of day.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func timeOfDay() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(4))
        let div = Divergences()
        for hour in [6, 14, 22] {
            Self.runProbe(
                name: "yearly m=11 wd=5 n=4 h=\(hour)",
                configure: { cal in
                    var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(5))
                    r.months = [11]
                    r.weekdays = [.nth(4, .thursday)]
                    r.hours = [hour]
                    r.matchingPolicy = .nextTime
                    return r
                },
                starts: starts, limit: 5, div: div,
                icuCal: icuCal, oursCal: oursCal
            )
        }
        Self.report("timeOfDay", div)
        #expect(div.list.isEmpty)
    }

    /// Default `matchingPolicy` (not `.nextTime`). Fast path only fires
    /// for `.nextTime`, so this exercises the generic path.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func defaultMatchingPolicy() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(3))
        let div = Divergences()
        Self.runProbe(
            name: "default-policy yearly m=11 wd=.nth(4,thu)",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, end: .afterOccurrences(5))
                r.months = [11]
                r.weekdays = [.nth(4, .thursday)]
                // matchingPolicy left at default (.nextTimePreservingSmallerComponents)
                return r
            },
            starts: starts, limit: 5, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("defaultMatchingPolicy", div)
        #expect(div.list.isEmpty)
    }

    /// `interval > 1`.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func intervalGreaterThanOne() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(3))
        let div = Divergences()
        Self.runProbe(
            name: "yearly interval=2 m=11 wd=.nth(4,thu)",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .yearly, interval: 2, end: .afterOccurrences(5))
                r.months = [11]
                r.weekdays = [.nth(4, .thursday)]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 5, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("intervalGreaterThanOne", div)
        #expect(div.list.isEmpty)
    }

    /// Day of month patterns (no weekday).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func dayOfMonth() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(3))
        let div = Divergences()
        for day in [1, 15, 25] {
            Self.runProbe(
                name: "monthly day=\(day)",
                configure: { cal in
                    var r = Calendar.RecurrenceRule(calendar: cal, frequency: .monthly, end: .afterOccurrences(8))
                    r.daysOfTheMonth = [day]
                    r.matchingPolicy = .nextTime
                    return r
                },
                starts: starts, limit: 8, div: div,
                icuCal: icuCal, oursCal: oursCal
            )
        }
        Self.report("dayOfMonth", div)
        #expect(div.list.isEmpty)
    }

    /// `.every(weekday)` pattern (no ordinal).
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    @Test func everyWeekday() {
        let (icuCal, oursCal) = Self.makePair()
        let starts = Array(Self.probeStarts().prefix(3))
        let div = Divergences()
        Self.runProbe(
            name: "weekly .every(.thursday)",
            configure: { cal in
                var r = Calendar.RecurrenceRule(calendar: cal, frequency: .weekly, end: .afterOccurrences(10))
                r.weekdays = [.every(.thursday)]
                r.matchingPolicy = .nextTime
                return r
            },
            starts: starts, limit: 10, div: div,
            icuCal: icuCal, oursCal: oursCal
        )
        Self.report("everyWeekday", div)
        #expect(div.list.isEmpty)
    }
}
