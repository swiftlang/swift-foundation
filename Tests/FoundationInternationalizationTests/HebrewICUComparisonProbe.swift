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

/// Side-by-side probe: `_CalendarICU(.hebrew)` (the pre-port behavior) vs
/// `_CalendarHebrew` (our port). One-shot diagnostic, not a pass/fail test.
@Suite("Hebrew ICU Comparison Probe")
private struct HebrewICUComparisonProbe {

    // Simple fixed-width padding (no String(format:) since that's Darwin Foundation only).
    private static func pad(_ s: String, _ width: Int) -> String {
        s + String(repeating: " ", count: max(0, width - s.count))
    }

    // MARK: - Helpers (used by topic-specific tests below)

    private static func makePair() -> (icu: _CalendarICU, ours: _CalendarHebrew) {
        let icu = _CalendarICU(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let ours = _CalendarHebrew(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        return (icu, ours)
    }

    /// Construct a Date from Gregorian y/m/d/h/m/s at GMT.
    private static func g(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .gmt
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d
        dc.hour = hour; dc.minute = minute; dc.second = second
        dc.timeZone = .gmt
        return cal.date(from: dc)!
    }

    /// Construct a Date from Hebrew y/m/d (civil month ordering, noon GMT) using ICU.
    /// Returns nil if the date isn't representable (e.g., Adar I 30 in a common year).
    private static func h(_ y: Int, _ m: Int, _ d: Int, icu: _CalendarICU) -> Date? {
        let cal = Calendar(inner: icu)
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d; dc.hour = 12
        dc.timeZone = .gmt
        guard let date = cal.date(from: dc) else { return nil }
        let check = cal.dateComponents([.year, .month, .day], from: date)
        return (check.year == y && check.month == m && check.day == d) ? date : nil
    }

    /// Hebrew year length in days, via ICU.
    private static func hebrewYearLength(_ year: Int, icu: _CalendarICU) -> Int? {
        guard let s = h(year, 1, 1, icu: icu),
              let e = h(year + 1, 1, 1, icu: icu) else { return nil }
        return Int((e.timeIntervalSince(s) / 86400.0).rounded())
    }

    /// Run every protocol-level surface check for one date; append divergences.
    private static func compareAt(
        label: String, date: Date,
        icu: _CalendarICU, ours: _CalendarHebrew,
        divergences: inout [String]
    ) {
        func cmp(_ field: String, _ a: Any?, _ b: Any?) {
            let aa = "\(a ?? "nil")"
            let bb = "\(b ?? "nil")"
            if aa != bb {
                divergences.append("[\(label)] \(field): ICU=\(aa) ours=\(bb)")
            }
        }

        let fields: Calendar.ComponentSet = [
            .era, .year, .month, .day, .hour, .minute, .second,
            .weekday, .weekdayOrdinal, .quarter,
            .weekOfMonth, .weekOfYear, .yearForWeekOfYear,
            .dayOfYear, .isLeapMonth
        ]
        let ic = icu.dateComponents(fields, from: date, in: .gmt)
        let oc = ours.dateComponents(fields, from: date, in: .gmt)
        cmp("dc.era",               ic.era,               oc.era)
        cmp("dc.year",              ic.year,              oc.year)
        cmp("dc.month",             ic.month,             oc.month)
        cmp("dc.day",               ic.day,               oc.day)
        cmp("dc.hour",              ic.hour,              oc.hour)
        cmp("dc.minute",            ic.minute,            oc.minute)
        cmp("dc.second",            ic.second,            oc.second)
        cmp("dc.weekday",           ic.weekday,           oc.weekday)
        cmp("dc.weekdayOrdinal",    ic.weekdayOrdinal,    oc.weekdayOrdinal)
        cmp("dc.quarter",           ic.quarter,           oc.quarter)
        cmp("dc.weekOfMonth",       ic.weekOfMonth,       oc.weekOfMonth)
        cmp("dc.weekOfYear",        ic.weekOfYear,        oc.weekOfYear)
        cmp("dc.yearForWeekOfYear", ic.yearForWeekOfYear, oc.yearForWeekOfYear)
        cmp("dc.dayOfYear",         ic.dayOfYear,         oc.dayOfYear)
        cmp("dc.isLeapMonth",       ic.isLeapMonth,       oc.isLeapMonth)

        for c in [Calendar.Component.era, .year, .month, .day, .hour, .quarter,
                  .weekOfYear, .weekOfMonth, .yearForWeekOfYear] {
            let iv = icu.dateInterval(of: c, for: date)
            let ov = ours.dateInterval(of: c, for: date)
            cmp("dateInterval(\(c)).duration",
                iv.map { Int($0.duration) },
                ov.map { Int($0.duration) })
        }

        let ordPairs: [(Calendar.Component, Calendar.Component)] = [
            (.day, .year), (.day, .month), (.month, .year), (.hour, .day),
            (.month, .quarter), (.weekOfYear, .year), (.weekOfMonth, .month),
            (.weekday, .year), (.weekday, .month), (.weekday, .weekOfYear),
            (.weekdayOrdinal, .month), (.quarter, .year)
        ]
        for (s, l) in ordPairs {
            cmp("ordinality(\(s),\(l))",
                icu.ordinality(of: s, in: l, for: date),
                ours.ordinality(of: s, in: l, for: date))
        }

        let rangePairs: [(Calendar.Component, Calendar.Component)] = [
            (.day, .year), (.day, .month), (.month, .year),
            (.weekOfYear, .year), (.weekOfMonth, .month)
        ]
        for (s, l) in rangePairs {
            cmp("range(\(s),\(l))",
                icu.range(of: s, in: l, for: date).map { "\($0.lowerBound)..<\($0.upperBound)" },
                ours.range(of: s, in: l, for: date).map { "\($0.lowerBound)..<\($0.upperBound)" })
        }

        for c in [Calendar.Component.day, .weekOfYear, .weekOfMonth, .weekdayOrdinal,
                  .month, .year, .quarter, .yearForWeekOfYear, .hour] {
            var dc = DateComponents()
            dc.setValue(1, for: c)
            cmp("date(byAdding:.\(c))",
                icu.date(byAdding: dc, to: date, wrappingComponents: false).map { "\($0)" },
                ours.date(byAdding: dc, to: date, wrappingComponents: false).map { "\($0)" })
        }

        cmp("isDateInWeekend", icu.isDateInWeekend(date), ours.isDateInWeekend(date))
    }

    private static func reportAndAssert(_ topic: String, _ divergences: [String], dateCount: Int) {
        print("\n=== \(topic): \(dateCount) dates ===")
        if divergences.isEmpty {
            print("  ✓ zero divergences")
        } else {
            print("  ✘ \(divergences.count) divergences:")
            for d in divergences.prefix(50) { print("    \(d)") }
            if divergences.count > 50 {
                print("    … (truncated at 50; total \(divergences.count))")
            }
        }
        #expect(divergences.isEmpty, "[\(topic)] \(divergences.count) divergences")
    }

    @Test func compareFieldsSideBySide() {
        let icu = _CalendarICU(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )
        let ours = _CalendarHebrew(
            identifier: .hebrew, timeZone: .gmt, locale: nil,
            firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil
        )

        let d = Date(timeIntervalSinceReferenceDate: 496359355.795410)
        print("\n=== Hebrew calendar: _CalendarICU vs _CalendarHebrew ===")
        print("Probe date: \(d)\n")
        print("Defaults: ICU firstWeekday=\(icu.firstWeekday) minDays=\(icu.minimumDaysInFirstWeek)")
        print("          ours firstWeekday=\(ours.firstWeekday) minDays=\(ours.minimumDaysInFirstWeek)\n")

        // --- dateComponents query ---
        let fields: Calendar.ComponentSet = [
            .era, .year, .month, .day, .hour, .minute, .second,
            .weekday, .weekdayOrdinal, .quarter,
            .weekOfMonth, .weekOfYear, .yearForWeekOfYear,
            .dayOfYear, .isLeapMonth
        ]
        let icuComps = icu.dateComponents(fields, from: d, in: .gmt)
        let ourComps = ours.dateComponents(fields, from: d, in: .gmt)

        print("dateComponents(…, from: d):")
        print("  " + Self.pad("field", 22) + Self.pad("ICU", 14) + "ours")
        func row(_ name: String, _ a: Int?, _ b: Int?) {
            print("  " + Self.pad(name, 22) + Self.pad(a.map(String.init) ?? "nil", 14) + (b.map(String.init) ?? "nil"))
        }
        func rowBool(_ name: String, _ a: Bool?, _ b: Bool?) {
            print("  " + Self.pad(name, 22) + Self.pad(a.map { $0 ? "true" : "false" } ?? "nil", 14) + (b.map { $0 ? "true" : "false" } ?? "nil"))
        }
        row(".era",               icuComps.era,               ourComps.era)
        row(".year",              icuComps.year,              ourComps.year)
        row(".month",             icuComps.month,             ourComps.month)
        row(".day",               icuComps.day,               ourComps.day)
        row(".hour",              icuComps.hour,              ourComps.hour)
        row(".minute",            icuComps.minute,            ourComps.minute)
        row(".second",            icuComps.second,            ourComps.second)
        row(".weekday",           icuComps.weekday,           ourComps.weekday)
        row(".weekdayOrdinal",    icuComps.weekdayOrdinal,    ourComps.weekdayOrdinal)
        row(".quarter",           icuComps.quarter,           ourComps.quarter)
        row(".weekOfMonth",       icuComps.weekOfMonth,       ourComps.weekOfMonth)
        row(".weekOfYear",        icuComps.weekOfYear,        ourComps.weekOfYear)
        row(".yearForWeekOfYear", icuComps.yearForWeekOfYear, ourComps.yearForWeekOfYear)
        row(".dayOfYear",         icuComps.dayOfYear,         ourComps.dayOfYear)
        rowBool(".isLeapMonth",   icuComps.isLeapMonth,       ourComps.isLeapMonth)

        // --- dateInterval ---
        print("\ndateInterval(of: X, for: d):")
        print("  " + Self.pad("component", 22) + Self.pad("ICU duration (s)", 24) + "ours duration (s)")
        func intervalRow(_ name: String, _ a: DateInterval?, _ b: DateInterval?) {
            let af = a.map { "\(Int($0.duration))" } ?? "nil"
            let bf = b.map { "\(Int($0.duration))" } ?? "nil"
            print("  " + Self.pad(name, 22) + Self.pad(af, 24) + bf)
        }
        intervalRow(".era",               icu.dateInterval(of: .era,               for: d), ours.dateInterval(of: .era,               for: d))
        intervalRow(".year",              icu.dateInterval(of: .year,              for: d), ours.dateInterval(of: .year,              for: d))
        intervalRow(".month",             icu.dateInterval(of: .month,             for: d), ours.dateInterval(of: .month,             for: d))
        intervalRow(".day",               icu.dateInterval(of: .day,               for: d), ours.dateInterval(of: .day,               for: d))
        intervalRow(".hour",              icu.dateInterval(of: .hour,              for: d), ours.dateInterval(of: .hour,              for: d))
        intervalRow(".quarter",           icu.dateInterval(of: .quarter,           for: d), ours.dateInterval(of: .quarter,           for: d))
        intervalRow(".weekOfYear",        icu.dateInterval(of: .weekOfYear,        for: d), ours.dateInterval(of: .weekOfYear,        for: d))
        intervalRow(".weekOfMonth",       icu.dateInterval(of: .weekOfMonth,       for: d), ours.dateInterval(of: .weekOfMonth,       for: d))
        intervalRow(".yearForWeekOfYear", icu.dateInterval(of: .yearForWeekOfYear, for: d), ours.dateInterval(of: .yearForWeekOfYear, for: d))

        // --- ordinality ---
        print("\nordinality(of: smaller, in: larger, for: d):")
        print("  " + Self.pad("(smaller, larger)", 28) + Self.pad("ICU", 10) + "ours")
        func ordRow(_ small: Calendar.Component, _ large: Calendar.Component) {
            let a = icu.ordinality(of: small, in: large, for: d)
            let b = ours.ordinality(of: small, in: large, for: d)
            print("  " + Self.pad("(.\(small), .\(large))", 28) + Self.pad(a.map(String.init) ?? "nil", 10) + (b.map(String.init) ?? "nil"))
        }
        ordRow(.day, .year)
        ordRow(.day, .month)
        ordRow(.month, .year)
        ordRow(.month, .quarter)
        ordRow(.weekOfYear, .year)
        ordRow(.weekOfMonth, .month)
        ordRow(.weekday, .year)
        ordRow(.weekday, .month)
        ordRow(.weekday, .weekOfYear)
        ordRow(.weekdayOrdinal, .month)
        ordRow(.quarter, .year)
        ordRow(.hour, .day)

        // --- range(of:in:for:) ---
        print("\nrange(of: smaller, in: larger, for: d):")
        print("  " + Self.pad("(smaller, larger)", 28) + Self.pad("ICU", 14) + "ours")
        func rangeRow(_ small: Calendar.Component, _ large: Calendar.Component) {
            let a = icu.range(of: small, in: large, for: d)
            let b = ours.range(of: small, in: large, for: d)
            print("  " + Self.pad("(.\(small), .\(large))", 28) +
                  Self.pad(a.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil", 14) +
                  (b.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil"))
        }
        rangeRow(.day, .year)
        rangeRow(.day, .month)
        rangeRow(.month, .year)
        rangeRow(.weekOfYear, .year)
        rangeRow(.weekOfMonth, .month)

        // --- date(byAdding:) — show date +1 of each component ---
        print("\ndate(byAdding: <c>, value: 1, to: d):")
        print("  " + Self.pad("component", 22) + Self.pad("ICU", 36) + "ours")
        func addRow(_ comp: Calendar.Component) {
            var dc = DateComponents()
            dc.setValue(1, for: comp)
            let a = icu.date(byAdding: dc, to: d, wrappingComponents: false)
            let b = ours.date(byAdding: dc, to: d, wrappingComponents: false)
            print("  " + Self.pad(".\(comp)", 22) +
                  Self.pad(a.map { "\($0)" } ?? "nil", 36) +
                  (b.map { "\($0)" } ?? "nil"))
        }
        addRow(.day)
        addRow(.weekOfYear)
        addRow(.weekOfMonth)
        addRow(.weekdayOrdinal)
        addRow(.month)
        addRow(.year)
        addRow(.quarter)
        addRow(.yearForWeekOfYear)
        addRow(.hour)

        // --- minimumRange / maximumRange ---
        print("\nminimumRange / maximumRange:")
        print("  " + Self.pad("component", 22) + Self.pad("ICU min", 14) + Self.pad("ours min", 14) + Self.pad("ICU max", 14) + "ours max")
        func rangeComp(_ c: Calendar.Component) {
            let s = { (r: Range<Int>?) in r.map { "\($0.lowerBound)..<\($0.upperBound)" } ?? "nil" }
            print("  " + Self.pad(".\(c)", 22) +
                  Self.pad(s(icu.minimumRange(of: c)), 14) +
                  Self.pad(s(ours.minimumRange(of: c)), 14) +
                  Self.pad(s(icu.maximumRange(of: c)), 14) +
                  s(ours.maximumRange(of: c)))
        }
        rangeComp(.era)
        rangeComp(.year)
        rangeComp(.month)
        rangeComp(.day)
        rangeComp(.hour)
        rangeComp(.weekday)
        rangeComp(.weekdayOrdinal)
        rangeComp(.quarter)
        rangeComp(.weekOfMonth)
        rangeComp(.weekOfYear)
        rangeComp(.yearForWeekOfYear)
        rangeComp(.dayOfYear)
        rangeComp(.isLeapMonth)

        print("\n=== end probe ===\n")
    }

    // Sweep across multiple dates covering every tricky Hebrew edge case.
    // Compares ICU vs ours on every date-dependent surface; reports only divergences.
    @Test func sweepMultipleDates() {
        let (icu, ours) = Self.makePair()

        // Edge-case probe dates.
        // 5776 = leap year, 385 days. Rosh Hashanah 5776 = 2015-09-14.
        // 5785 = common year, 355 days. Rosh Hashanah 5785 = 2024-10-03.
        // 5786 = common year. Rosh Hashanah 5786 = 2025-09-23.
        let probeDates: [(label: String, date: Date)] = [
            ("leap-year mid (Elul 20, 5776)",       Self.g(2016, 9, 23)),
            ("common-year mid (Adar 1, 5785)",      Self.g(2025, 3, 1)),
            ("leap year first day (Tishri 1, 5776)", Self.g(2015, 9, 14)),
            ("common year first day (Tishri 1, 5786)", Self.g(2025, 9, 23)),
            ("leap year Adar I (Adar I 1, 5776)",   Self.g(2016, 2, 10)),
            ("leap year Adar II (Adar II 1, 5776)", Self.g(2016, 3, 11)),
            ("Cheshvan 30, 5776 (long Marheshvan)", Self.g(2015, 11, 12)),
            ("Kislev 25, 5777 (Hanukkah common year)", Self.g(2016, 12, 25)),
            ("Passover 15 Nisan 5776",              Self.g(2016, 4, 23)),
            ("mid-5778 common year",                Self.g(2017, 12, 15)),
        ]

        var divergences: [String] = []
        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Multi-date sweep (10 hand-picked edge cases)", divergences, dateCount: probeDates.count)
    }

    // MARK: - Topic-specific edge-case probes

    /// Topic 1: All 6 Hebrew year-length regimes
    /// (common deficient/regular/complete = 353/354/355; leap = 383/384/385).
    @Test func yearLengthVariants_allSixRegimes() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var found: [Int: Int] = [:]
        for y in 5750...5810 {
            guard let len = Self.hebrewYearLength(y, icu: icu) else { continue }
            if found[len] == nil { found[len] = y }
            if found.count >= 6 { break }
        }

        var probeDates: [(String, Date)] = []
        for (length, year) in found.sorted(by: { $0.key < $1.key }) {
            for (offset, where_) in [(1, "day-2"), (length / 2, "mid"), (length - 2, "near-end")] {
                if let yearStart = Self.h(year, 1, 1, icu: icu) {
                    let date = yearStart.addingTimeInterval(86400.0 * Double(offset))
                    probeDates.append(("\(year) (\(length)d) \(where_)", date))
                }
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 1: yearLengthVariants (6 regimes × 3 sample points)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 2: Cheshvan and Kislev length boundaries.
    /// Cheshvan = 30 only in complete years; Kislev = 30 in regular/complete.
    @Test func cheshvanKislev_lengthBoundaries() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var found: [Int: Int] = [:]
        for y in 5750...5810 {
            guard let len = Self.hebrewYearLength(y, icu: icu) else { continue }
            if found[len] == nil { found[len] = y }
            if found.count >= 6 { break }
        }

        var probeDates: [(String, Date)] = []
        for (length, year) in found.sorted(by: { $0.key < $1.key }) {
            for (m, d, name) in [
                (2, 29, "Cheshvan29"), (2, 30, "Cheshvan30"),
                (3, 1,  "Kislev1"),   (3, 29, "Kislev29"),
                (3, 30, "Kislev30"),  (4, 1,  "Tevet1"),
            ] {
                if let date = Self.h(year, m, d, icu: icu) {
                    probeDates.append(("\(year)(\(length)d) \(name)", date))
                }
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 2: cheshvanKislev_lengthBoundaries",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 3: A complete 19-year Metonic cycle (Hebrew years 5763–5781).
    @Test func metonicCycle_nineteenYears() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var probeDates: [(String, Date)] = []
        for year in 5763...5781 {
            if let rh = Self.h(year, 1, 1, icu: icu) {
                probeDates.append(("\(year) RH", rh))
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 3: metonicCycle (19 consecutive years)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 4: Rosh Hashanah postponement (dehiyot) — RH may only fall on Mon/Tue/Thu/Sat.
    /// Find one year landing RH on each allowed weekday, probe RH and the boundary days.
    @Test func roshHashanahPostponement_allFourAllowedDays() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []
        let cal = Calendar(inner: icu)

        var found: [Int: Int] = [:]
        for y in 5750...5800 {
            guard let rh = Self.h(y, 1, 1, icu: icu) else { continue }
            let wd = cal.component(.weekday, from: rh)
            if found[wd] == nil { found[wd] = y }
            if found.count == 4 { break }
        }

        var probeDates: [(String, Date)] = []
        for (wd, year) in found.sorted(by: { $0.key < $1.key }) {
            guard let rh = Self.h(year, 1, 1, icu: icu) else { continue }
            probeDates.append(("\(year) RH (wd=\(wd))", rh))
            probeDates.append(("\(year-1) day before RH", rh.addingTimeInterval(-86400)))
            probeDates.append(("\(year) Tishrei 2", rh.addingTimeInterval(86400)))
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 4: roshHashanahPostponement (4 weekdays × 3 boundary days)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 5: Adar I → Adar II mid-leap-year transition.
    /// Adar I (m=6) is 30 days, Adar II (m=7) is 29 days. Common years skip Adar I.
    @Test func adarTransition_leapYearMidYearBoundary() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        let leapYears = [5779, 5782, 5784]
        var probeDates: [(String, Date)] = []
        for year in leapYears {
            for (m, d, name) in [
                (6, 1,  "AdarI 1"),
                (6, 15, "AdarI 15"),
                (6, 30, "AdarI 30 (last)"),
                (7, 1,  "AdarII 1"),
                (7, 14, "AdarII 14 (Purim)"),
                (7, 29, "AdarII 29 (last)"),
                (8, 1,  "Nisan 1"),
            ] {
                if let date = Self.h(year, m, d, icu: icu) {
                    probeDates.append(("\(year) \(name)", date))
                }
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 5: adarTransition (3 leap years × 7 boundary days)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 6: Year boundaries — last days of Elul + first 2 days of next year.
    /// Mix of common-year-end and leap-year-end transitions.
    @Test func yearBoundaries_commonAndLeap() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var probeDates: [(String, Date)] = []
        for year in [5777, 5778, 5779, 5780, 5781, 5782, 5783, 5784, 5785, 5786] {
            guard let nextRh = Self.h(year + 1, 1, 1, icu: icu) else { continue }
            let elulLast = nextRh.addingTimeInterval(-86400)
            let elulPenultimate = nextRh.addingTimeInterval(-2 * 86400)
            let tishreiTwo = nextRh.addingTimeInterval(86400)
            probeDates.append(("\(year)→\(year+1) Elul-1", elulPenultimate))
            probeDates.append(("\(year)→\(year+1) Elul last", elulLast))
            probeDates.append(("\(year+1) Tishrei 1", nextRh))
            probeDates.append(("\(year+1) Tishrei 2", tishreiTwo))
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 6: yearBoundaries (10 transitions × 4 days)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 7: Last day of every valid month (29 or 30) across mixed years.
    @Test func monthBoundaries_unusualLengths() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var probeDates: [(String, Date)] = []
        for year in [5778, 5779, 5780, 5781] {
            for m in 1...13 {
                for d in [29, 30] {
                    if let date = Self.h(year, m, d, icu: icu) {
                        probeDates.append(("\(year) M\(m) D\(d)", date))
                    }
                }
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 7: monthBoundaries (4 years × valid 29/30 days)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 8: Major Jewish holidays in both common and leap years.
    @Test func majorHolidays_commonAndLeap() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        // (m, d, name) — civil month ordering
        let common: [(Int, Int, String)] = [
            (1, 1,  "RoshHashanah"),  (1, 10, "YomKippur"),
            (1, 15, "Sukkot"),        (1, 22, "SheminiAtzeret"),
            (3, 25, "Hanukkah"),
            (6, 14, "Purim (Adar 14)"), (6, 15, "ShushanPurim"),
            (7, 15, "Passover (Nisan 15)"),
            (9, 6,  "Shavuot (Sivan 6)"),
        ]
        let leap: [(Int, Int, String)] = [
            (1, 1,  "RoshHashanah"),  (1, 10, "YomKippur"),
            (1, 15, "Sukkot"),        (1, 22, "SheminiAtzeret"),
            (3, 25, "Hanukkah"),
            (7, 14, "Purim (AdarII 14)"), (7, 15, "ShushanPurim"),
            (8, 15, "Passover (Nisan 15)"),
            (10, 6, "Shavuot (Sivan 6)"),
        ]

        var probeDates: [(String, Date)] = []
        for year in [5778, 5780, 5781] {
            for (m, d, name) in common {
                if let date = Self.h(year, m, d, icu: icu) {
                    probeDates.append(("\(year) \(name)", date))
                }
            }
        }
        for year in [5779, 5782, 5784] {
            for (m, d, name) in leap {
                if let date = Self.h(year, m, d, icu: icu) {
                    probeDates.append(("\(year) \(name)", date))
                }
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 8: majorHolidays (3 common + 3 leap × ~9 holidays)",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 9: Time-of-day edge cases (midnight, noon, end-of-day, sub-second).
    @Test func timeOfDay_edgeCases() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        let baseDay = Self.g(2024, 6, 15, hour: 0)
        let probeDates: [(String, Date)] = [
            ("00:00:00.000",            baseDay),
            ("00:00:00.001",            baseDay.addingTimeInterval(0.001)),
            ("00:00:01.000",            baseDay.addingTimeInterval(1)),
            ("06:00:00",                baseDay.addingTimeInterval(6 * 3600)),
            ("11:59:59",                baseDay.addingTimeInterval(11 * 3600 + 59 * 60 + 59)),
            ("12:00:00 (ICU noon)",     baseDay.addingTimeInterval(12 * 3600)),
            ("12:00:00.001",            baseDay.addingTimeInterval(12 * 3600 + 0.001)),
            ("18:00:00",                baseDay.addingTimeInterval(18 * 3600)),
            ("23:59:58",                baseDay.addingTimeInterval(23 * 3600 + 59 * 60 + 58)),
            ("23:59:59",                baseDay.addingTimeInterval(23 * 3600 + 59 * 60 + 59)),
            ("23:59:59.500",            baseDay.addingTimeInterval(23 * 3600 + 59 * 60 + 59.5)),
            ("23:59:59.999",            baseDay.addingTimeInterval(23 * 3600 + 59 * 60 + 59.999)),
            ("next-day 00:00:00",       baseDay.addingTimeInterval(86400)),
        ]

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 9: timeOfDay_edgeCases",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 11: Far past and far future Gregorian dates.
    /// Spans roughly 600 CE → 2300 CE, well beyond Hebcal regression (1900–2100).
    @Test func farPastAndFarFuture() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        let probeDates: [(String, Date)] = [
            ("0600-06-15", Self.g(600, 6, 15)),
            ("0900-06-15", Self.g(900, 6, 15)),
            ("1200-06-15", Self.g(1200, 6, 15)),
            ("1500-06-15", Self.g(1500, 6, 15)),
            ("1700-06-15", Self.g(1700, 6, 15)),
            ("1850-06-15", Self.g(1850, 6, 15)),
            ("2150-06-15", Self.g(2150, 6, 15)),
            ("2200-06-15", Self.g(2200, 6, 15)),
            ("2300-06-15", Self.g(2300, 6, 15)),
        ]

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 11: farPastAndFarFuture",
                             divergences, dateCount: probeDates.count)
    }

    /// Topic 13: Week-of-year edge cases at year wrap (15 days centered on RH).
    @Test func weekOfYear_yearWrap() {
        let (icu, ours) = Self.makePair()
        var divergences: [String] = []

        var probeDates: [(String, Date)] = []
        for year in [5777, 5778, 5779, 5780, 5781, 5782] {
            guard let nextRh = Self.h(year + 1, 1, 1, icu: icu) else { continue }
            for off in -7...7 {
                let date = nextRh.addingTimeInterval(86400.0 * Double(off))
                probeDates.append(("\(year)→\(year+1) day\(off >= 0 ? "+" : "")\(off)", date))
            }
        }

        for (label, d) in probeDates {
            Self.compareAt(label: label, date: d, icu: icu, ours: ours, divergences: &divergences)
        }
        Self.reportAndAssert("Topic 13: weekOfYear_yearWrap (6 transitions × 15 days)",
                             divergences, dateCount: probeDates.count)
    }
}
