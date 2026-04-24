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

/// Suite B — the public `Calendar` API parity probe, per `backup/PARITY_PROTOCOL.md`.
///
/// Wraps both `_CalendarICU(.hebrew)` and `_CalendarHebrew(.hebrew)` in `Calendar`
/// structs (via the internal `Calendar.init(inner:)`) and exercises every public
/// method whose output depends on the underlying calendar. Reports only divergences.
///
/// This is non-negotiable for the Hebrew port: `Calendar` layers calendar-specific
/// logic above `_CalendarProtocol` (weekend queries, `compare(...)`, `date(bySetting:)`,
/// enumerate variants), so protocol-only parity is insufficient to guarantee a
/// drop-in replacement.
@Suite("Hebrew Calendar Public API Probe")
private struct HebrewPublicAPIComparisonProbe {

    // MARK: - Setup

    private static func makePair() -> (icu: Calendar, ours: Calendar) {
        let icuInner = _CalendarICU(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let oursInner = _CalendarHebrew(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        return (Calendar(inner: icuInner), Calendar(inner: oursInner))
    }

    private static func probeDates() -> [(label: String, date: Date)] {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = .gmt
        func d(_ y: Int, _ m: Int, _ day: Int, hour: Int = 12) -> Date {
            var dc = DateComponents()
            dc.year = y; dc.month = m; dc.day = day; dc.hour = hour; dc.timeZone = .gmt
            return g.date(from: dc)!
        }
        return [
            ("leap-year mid (Elul 20, 5776)",       d(2016, 9, 23)),
            ("common-year mid (Adar 1, 5785)",      d(2025, 3, 1)),
            ("leap year first day (Tishri 1, 5776)", d(2015, 9, 14)),
            ("common year first day (Tishri 1, 5786)", d(2025, 9, 23)),
            ("leap year Adar I (Adar I 1, 5776)",   d(2016, 2, 10)),
            ("leap year Adar II (Adar II 1, 5776)", d(2016, 3, 11)),
            ("Cheshvan 30, 5776 (long Marheshvan)", d(2015, 11, 12)),
            ("Kislev 25, 5777 (Hanukkah common year)", d(2016, 12, 25)),
            ("Passover 15 Nisan 5776",              d(2016, 4, 23)),
            ("mid-5778 common year",                d(2017, 12, 15)),
        ]
    }

    // Collects divergences; one test asserts divergences.isEmpty at the end.
    private final class Divergences {
        var list: [String] = []
        func compare(_ label: String, _ field: String, _ icu: Any?, _ ours: Any?) {
            let a = "\(icu ?? "nil")"
            let b = "\(ours ?? "nil")"
            if a != b {
                list.append("[\(label)] \(field): ICU=\(a) ours=\(b)")
            }
        }
        func compareSet(_ label: String, _ field: String, _ icu: DateComponents, _ ours: DateComponents) {
            // Compare every field we care about that was set on either side.
            let comps: [(String, Int?, Int?)] = [
                ("era", icu.era, ours.era),
                ("year", icu.year, ours.year),
                ("month", icu.month, ours.month),
                ("day", icu.day, ours.day),
                ("hour", icu.hour, ours.hour),
                ("minute", icu.minute, ours.minute),
                ("second", icu.second, ours.second),
                ("nanosecond", icu.nanosecond, ours.nanosecond),
                ("weekday", icu.weekday, ours.weekday),
                ("weekdayOrdinal", icu.weekdayOrdinal, ours.weekdayOrdinal),
                ("quarter", icu.quarter, ours.quarter),
                ("weekOfMonth", icu.weekOfMonth, ours.weekOfMonth),
                ("weekOfYear", icu.weekOfYear, ours.weekOfYear),
                ("yearForWeekOfYear", icu.yearForWeekOfYear, ours.yearForWeekOfYear),
                ("dayOfYear", icu.dayOfYear, ours.dayOfYear),
            ]
            for (name, a, b) in comps where a != b {
                list.append("[\(label)] \(field).\(name): ICU=\(a.map(String.init) ?? "nil") ours=\(b.map(String.init) ?? "nil")")
            }
            let icuLM = icu.isLeapMonth.map { $0 ? "true" : "false" } ?? "nil"
            let ourLM = ours.isLeapMonth.map { $0 ? "true" : "false" } ?? "nil"
            if icuLM != ourLM {
                list.append("[\(label)] \(field).isLeapMonth: ICU=\(icuLM) ours=\(ourLM)")
            }
        }
    }

    // MARK: - The probe

    @Test func publicAPI_sweepAllMethods() {
        let div = Divergences()

        for (label, d) in Self.probeDates() {
            let (icu, ours) = Self.makePair()

            // === component(_:from:) — every Calendar.Component ===
            let allComps: [Calendar.Component] = [
                .era, .year, .month, .day, .hour, .minute, .second, .nanosecond,
                .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear,
                .yearForWeekOfYear, .dayOfYear
            ]
            for c in allComps {
                div.compare(label, "component(\(c))", icu.component(c, from: d), ours.component(c, from: d))
            }

            // === dateComponents(_:from:) — all fields at once ===
            let allSet: Set<Calendar.Component> = Set(allComps + [.isLeapMonth, .calendar, .timeZone])
            div.compareSet(label, "dateComponents([.all], from:)",
                           icu.dateComponents(allSet, from: d),
                           ours.dateComponents(allSet, from: d))

            // === dateComponents(in:from:) ===
            div.compareSet(label, "dateComponents(in: .gmt, from:)",
                           icu.dateComponents(in: .gmt, from: d),
                           ours.dateComponents(in: .gmt, from: d))

            // === startOfDay(for:) ===
            div.compare(label, "startOfDay(for:)",
                        "\(icu.startOfDay(for: d))",
                        "\(ours.startOfDay(for: d))")

            // === dateInterval(of:for:) — all components ===
            for c in allComps where c != .nanosecond {
                let a = icu.dateInterval(of: c, for: d)
                let b = ours.dateInterval(of: c, for: d)
                div.compare(label, "dateInterval(\(c)).start",
                            a.map { "\($0.start)" },
                            b.map { "\($0.start)" })
                div.compare(label, "dateInterval(\(c)).duration",
                            a.map { Int($0.duration) },
                            b.map { Int($0.duration) })
            }

            // === range(of:in:for:) ===
            let rangePairs: [(Calendar.Component, Calendar.Component)] = [
                (.day, .year), (.day, .month), (.month, .year),
                (.weekOfYear, .year), (.weekOfMonth, .month),
                (.hour, .day), (.minute, .hour), (.second, .minute),
                (.weekdayOrdinal, .month), (.weekday, .month), (.weekday, .year)
            ]
            for (s, l) in rangePairs {
                div.compare(label, "range(\(s),\(l))",
                            icu.range(of: s, in: l, for: d).map { "\($0.lowerBound)..<\($0.upperBound)" },
                            ours.range(of: s, in: l, for: d).map { "\($0.lowerBound)..<\($0.upperBound)" })
            }

            // === ordinality(of:in:for:) ===
            let ordPairs: [(Calendar.Component, Calendar.Component)] = [
                (.day, .year), (.day, .month), (.month, .year), (.hour, .day),
                (.month, .quarter), (.weekOfYear, .year), (.weekOfMonth, .month),
                (.weekday, .year), (.weekday, .month), (.weekday, .weekOfYear),
                (.weekdayOrdinal, .month), (.quarter, .year),
                (.minute, .hour), (.second, .minute)
            ]
            for (s, l) in ordPairs {
                div.compare(label, "ordinality(\(s),\(l))",
                            icu.ordinality(of: s, in: l, for: d),
                            ours.ordinality(of: s, in: l, for: d))
            }

            // === date(from:) — round-trip via components ===
            let ymdH = icu.dateComponents([.era, .year, .month, .day, .hour], from: d)
            div.compare(label, "date(from: dc).roundTrip",
                        "\(icu.date(from: ymdH) ?? Date.distantPast)",
                        "\(ours.date(from: ymdH) ?? Date.distantPast)")

            // === date(byAdding: Component, value: n) — a battery of adds ===
            let adds: [(Calendar.Component, Int)] = [
                (.day, 1), (.day, -1), (.day, 30), (.day, 365),
                (.month, 1), (.month, -1), (.month, 6), (.month, 12),
                (.year, 1), (.year, -1), (.year, 5),
                (.hour, 1), (.hour, 24), (.minute, 1), (.second, 1),
                (.weekOfYear, 1), (.weekOfMonth, 1), (.weekdayOrdinal, 1),
                (.yearForWeekOfYear, 1),
                (.quarter, 1),   // ICU no-ops this for Hebrew
            ]
            for (c, v) in adds {
                div.compare(label, "date(byAdding:\(c), value:\(v))",
                            icu.date(byAdding: c, value: v, to: d).map { "\($0)" },
                            ours.date(byAdding: c, value: v, to: d).map { "\($0)" })
            }

            // === date(byAdding: DateComponents — multi-field) ===
            var multi = DateComponents()
            multi.year = 1; multi.month = 2; multi.day = 3; multi.hour = 4
            div.compare(label, "date(byAdding: multi)",
                        icu.date(byAdding: multi, to: d).map { "\($0)" },
                        ours.date(byAdding: multi, to: d).map { "\($0)" })

            // === date(byAdding:, wrappingComponents: true) ===
            div.compare(label, "date(byAdding:.day, value:1, wrapping:true)",
                        icu.date(byAdding: .day, value: 1, to: d, wrappingComponents: true).map { "\($0)" },
                        ours.date(byAdding: .day, value: 1, to: d, wrappingComponents: true).map { "\($0)" })

            // === date(bySetting:value:of:) ===
            for (c, v) in [(Calendar.Component.hour, 18),
                           (.minute, 30),
                           (.day, 15)] {
                div.compare(label, "date(bySetting:\(c), value:\(v))",
                            icu.date(bySetting: c, value: v, of: d).map { "\($0)" },
                            ours.date(bySetting: c, value: v, of: d).map { "\($0)" })
            }

            // === date(bySettingHour:minute:second:of:) ===
            div.compare(label, "date(bySettingHour:6, minute:15, second:30)",
                        icu.date(bySettingHour: 6, minute: 15, second: 30, of: d).map { "\($0)" },
                        ours.date(bySettingHour: 6, minute: 15, second: 30, of: d).map { "\($0)" })

            // === compare(_:to:toGranularity:) — every granularity ===
            let d2 = d.addingTimeInterval(86400 * 3)   // 3 days later
            for c in allComps where c != .nanosecond {
                div.compare(label, "compare(d, d+3d, .\(c))",
                            "\(icu.compare(d, to: d2, toGranularity: c).rawValue)",
                            "\(ours.compare(d, to: d2, toGranularity: c).rawValue)")
            }
            let d3 = d.addingTimeInterval(86400 * 60)  // 60 days later (crosses month)
            for c in [Calendar.Component.day, .month, .year, .weekOfYear, .weekOfMonth, .quarter] {
                div.compare(label, "compare(d, d+60d, .\(c))",
                            "\(icu.compare(d, to: d3, toGranularity: c).rawValue)",
                            "\(ours.compare(d, to: d3, toGranularity: c).rawValue)")
            }

            // === isDate(_:equalTo:toGranularity:) — every granularity ===
            for c in allComps where c != .nanosecond {
                div.compare(label, "isDate(equalTo: d+3d, .\(c))",
                            icu.isDate(d, equalTo: d2, toGranularity: c),
                            ours.isDate(d, equalTo: d2, toGranularity: c))
            }

            // === isDate(_:inSameDayAs:) ===
            div.compare(label, "isDate(d, inSameDayAs: d)",
                        icu.isDate(d, inSameDayAs: d),
                        ours.isDate(d, inSameDayAs: d))
            div.compare(label, "isDate(d, inSameDayAs: d+3d)",
                        icu.isDate(d, inSameDayAs: d2),
                        ours.isDate(d, inSameDayAs: d2))

            // === date(_:matchesComponents:) ===
            let matchingDC = icu.dateComponents([.year, .month, .day], from: d)
            div.compare(label, "date(d, matchesComponents: y/m/d)",
                        icu.date(d, matchesComponents: matchingDC),
                        ours.date(d, matchesComponents: matchingDC))
            var wrong = matchingDC
            wrong.day = (wrong.day ?? 1) + 1
            div.compare(label, "date(d, matchesComponents: y/m/d+1)",
                        icu.date(d, matchesComponents: wrong),
                        ours.date(d, matchesComponents: wrong))

            // === Weekend queries — highest-risk category ===
            div.compare(label, "isDateInWeekend(d)",
                        icu.isDateInWeekend(d),
                        ours.isDateInWeekend(d))
            let d_sat = d.addingTimeInterval(86400.0 * Double((7 - icu.component(.weekday, from: d)) % 7))  // next Saturday
            div.compare(label, "isDateInWeekend(nextSaturday)",
                        icu.isDateInWeekend(d_sat),
                        ours.isDateInWeekend(d_sat))

            let icuWknd = icu.dateIntervalOfWeekend(containing: d)
            let ourWknd = ours.dateIntervalOfWeekend(containing: d)
            div.compare(label, "dateIntervalOfWeekend(d).start",
                        icuWknd.map { "\($0.start)" },
                        ourWknd.map { "\($0.start)" })
            div.compare(label, "dateIntervalOfWeekend(d).duration",
                        icuWknd.map { Int($0.duration) },
                        ourWknd.map { Int($0.duration) })

            let icuWkndSat = icu.dateIntervalOfWeekend(containing: d_sat)
            let ourWkndSat = ours.dateIntervalOfWeekend(containing: d_sat)
            div.compare(label, "dateIntervalOfWeekend(saturday).start",
                        icuWkndSat.map { "\($0.start)" },
                        ourWkndSat.map { "\($0.start)" })
            div.compare(label, "dateIntervalOfWeekend(saturday).duration",
                        icuWkndSat.map { Int($0.duration) },
                        ourWkndSat.map { Int($0.duration) })

            for direction in [Calendar.SearchDirection.forward, .backward] {
                let icuNext = icu.nextWeekend(startingAfter: d, direction: direction)
                let ourNext = ours.nextWeekend(startingAfter: d, direction: direction)
                div.compare(label, "nextWeekend(d, \(direction)).start",
                            icuNext.map { "\($0.start)" },
                            ourNext.map { "\($0.start)" })
                div.compare(label, "nextWeekend(d, \(direction)).duration",
                            icuNext.map { Int($0.duration) },
                            ourNext.map { Int($0.duration) })
            }

            // === enumerateDates(...) — pattern match a few known Hebrew dates ===
            // Pattern 1: every Hanukkah (Kislev 25 = civil month 3, day 25)
            func collect(_ cal: Calendar, start: Date, dc: DateComponents, count: Int) -> [Date] {
                var result: [Date] = []
                cal.enumerateDates(startingAfter: start, matching: dc, matchingPolicy: .nextTime) { date, _, stop in
                    if let date = date { result.append(date) }
                    if result.count >= count { stop = true }
                }
                return result
            }
            let hanukkahDC = DateComponents(month: 3, day: 25)
            let icuHanukkahs = collect(icu, start: d, dc: hanukkahDC, count: 3)
            let ourHanukkahs = collect(ours, start: d, dc: hanukkahDC, count: 3)
            div.compare(label, "enumerateDates(Hanukkahs).count",
                        icuHanukkahs.count, ourHanukkahs.count)
            for i in 0..<min(icuHanukkahs.count, ourHanukkahs.count) {
                div.compare(label, "enumerateDates(Hanukkahs)[\(i)]",
                            "\(icuHanukkahs[i])", "\(ourHanukkahs[i])")
            }

            // Pattern 2: every Passover start (Nisan 15 = civil month 8, day 15)
            let passoverDC = DateComponents(month: 8, day: 15)
            let icuPassovers = collect(icu, start: d, dc: passoverDC, count: 3)
            let ourPassovers = collect(ours, start: d, dc: passoverDC, count: 3)
            div.compare(label, "enumerateDates(Passovers).count",
                        icuPassovers.count, ourPassovers.count)
            for i in 0..<min(icuPassovers.count, ourPassovers.count) {
                div.compare(label, "enumerateDates(Passovers)[\(i)]",
                            "\(icuPassovers[i])", "\(ourPassovers[i])")
            }

            // === nextDate(after:matching:) — wraps enumerate ===
            div.compare(label, "nextDate(after: d, matching: Hanukkah)",
                        icu.nextDate(after: d, matching: hanukkahDC, matchingPolicy: .nextTime).map { "\($0)" },
                        ours.nextDate(after: d, matching: hanukkahDC, matchingPolicy: .nextTime).map { "\($0)" })

            // === dateComponents(_:from:to:) — multi-unit diff ===
            // Crude Suite B check: 60-day span. May diverge due to our crude impl.
            let diffIcu = icu.dateComponents([.year, .month, .day], from: d, to: d3)
            let diffOur = ours.dateComponents([.year, .month, .day], from: d, to: d3)
            div.compareSet(label, "dateComponents([y,m,d], from:d, to:d+60)", diffIcu, diffOur)
        }

        // === Print + assert ===
        print("\n=== Hebrew public-API probe: \(Self.probeDates().count) dates × many methods ===")
        if div.list.isEmpty {
            print("  ✓ zero divergences across the public Calendar API")
        } else {
            print("  ✘ \(div.list.count) divergences:")
            for msg in div.list.prefix(80) { print("    \(msg)") }
            if div.list.count > 80 {
                print("    … (truncated at 80; total \(div.list.count))")
            }
        }
        #expect(div.list.isEmpty, "\(div.list.count) public-API divergences from ICU")
    }
}
