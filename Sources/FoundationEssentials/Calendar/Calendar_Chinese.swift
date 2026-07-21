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

#if canImport(os)
internal import os
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(CRT)
import CRT
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

internal import Synchronization

// Chinese lunisolar calendar engine. Years 1901-2100 come from a baked table generated from ICU (parity by construction); outside that range, month structure is computed with ICU's chnsecal rules over _CalendarAstronomy at UTC+8.

// Bounded memoization caches: over the capacity, evict one arbitrary entry (hash order). LRU is deliberately not attempted, a miss only recomputes.
private func evictIfNeeded<V>(_ cache: inout [Int: V], capacity: Int) {
    if cache.count > capacity, let victim = cache.keys.first {
        cache.removeValue(forKey: victim)
    }
}

// MARK: - chnsecal rules over the astronomy (flat UTC+8, matching ICU)

internal struct _ChineseRules {
    static let synodicGap = 25
    var winterSolsticeCache: [Int: Int] = [:]
    var newYearCache: [Int: Int] = [:]

    // Local UTC+8 midnight of an RD day, as a universal moment.
    private func midnight(_ rataDie: Int) -> Double {
        Double(rataDie) - 1.0 + 16.0 / 24.0
    }

    private func toLocalDay(_ moment: Double) -> Int {
        Int((moment + 8.0 / 24.0).rounded(.down))
    }

    // Winter solstice day on or after Dec 1 (chnsecal winterSolstice).
    mutating func winterSolstice(_ gregorianYear: Int) -> Int {
        if let cached = winterSolsticeCache[gregorianYear] { return cached }
        var day = _CalendarAstronomy.gregorianRataDie(gregorianYear, 12, 10)
        while true {
            let lon = _CalendarAstronomy.solarLongitude(at: midnight(day + 1))
            if lon >= 270.0 && lon < 350.0 { break }
            day += 1
        }
        evictIfNeeded(&winterSolsticeCache, capacity: 32)
        winterSolsticeCache[gregorianYear] = day
        return day
    }

    func newMoonNear(_ days: Int, _ after: Bool) -> Int {
        let m = midnight(days)
        let nm = after ? _CalendarAstronomy.newMoonAtOrAfter(m) : _CalendarAstronomy.newMoonBefore(m)
        return toLocalDay(nm)
    }

    static func synodicMonthsBetween(_ day1: Int, _ day2: Int) -> Int {
        let r = Double(day2 - day1) / _CalendarAstronomy.meanSynodicMonth
        return Int(r + (r >= 0 ? 0.5 : -0.5))
    }

    func majorSolarTerm(_ days: Int) -> Int {
        let lon = _CalendarAstronomy.solarLongitude(at: midnight(days))
        var term = (Int(lon / 30.0) + 2) % 12
        if term < 1 { term += 12 }
        return term
    }

    func hasNoMajorSolarTerm(_ newMoon: Int) -> Bool {
        majorSolarTerm(newMoon) == majorSolarTerm(newMoonNear(newMoon + Self.synodicGap, true))
    }

    func isLeapMonthBetween(_ newMoon1: Int, _ newMoon2: Int) -> Bool {
        var m2 = newMoon2
        while m2 >= newMoon1 {
            if hasNoMajorSolarTerm(m2) { return true }
            m2 = newMoonNear(m2 - Self.synodicGap, false)
        }
        return false
    }

    mutating func newYear(_ gregorianYear: Int) -> Int {
        if let cached = newYearCache[gregorianYear] { return cached }
        let solsticeBefore = winterSolstice(gregorianYear - 1)
        let solsticeAfter = winterSolstice(gregorianYear)
        let newMoon1 = newMoonNear(solsticeBefore + 1, true)
        let newMoon2 = newMoonNear(newMoon1 + Self.synodicGap, true)
        let newMoon11 = newMoonNear(solsticeAfter + 1, false)
        let value: Int
        if Self.synodicMonthsBetween(newMoon1, newMoon11) == 12 &&
            (hasNoMajorSolarTerm(newMoon1) || hasNoMajorSolarTerm(newMoon2)) {
            value = newMoonNear(newMoon2 + Self.synodicGap, true)
        } else {
            value = newMoon2
        }
        evictIfNeeded(&newYearCache, capacity: 32)
        newYearCache[gregorianYear] = value
        return value
    }

    // (month, isLeapMonth) label for the month starting at new moon `start`.
    mutating func monthLabel(startingAt start: Int, gregorianYear: Int) -> (month: Int, isLeap: Bool) {
        var solsticeBefore: Int
        var solsticeAfter = winterSolstice(gregorianYear)
        if start < solsticeAfter {
            solsticeBefore = winterSolstice(gregorianYear - 1)
        } else {
            solsticeBefore = solsticeAfter
            solsticeAfter = winterSolstice(gregorianYear + 1)
        }
        let firstMoon = newMoonNear(solsticeBefore + 1, true)
        let lastMoon = newMoonNear(solsticeAfter + 1, false)
        let hasLeap = Self.synodicMonthsBetween(firstMoon, lastMoon) == 12
        var month = Self.synodicMonthsBetween(firstMoon, start)
        if hasLeap && isLeapMonthBetween(firstMoon, start) {
            month -= 1
        }
        if month < 1 { month += 12 }
        let isLeap = hasLeap && hasNoMajorSolarTerm(start) &&
            !isLeapMonthBetween(firstMoon, newMoonNear(start - Self.synodicGap, false))
        return (month, isLeap)
    }
}

// MARK: - Year structure

internal struct _ChineseYear: Sendable {
    let relatedISOYear: Int
    let newYearRataDie: Int
    let monthLengthBits: UInt16    // bit i set = ordinal month i+1 has 30 days
    let monthCount: UInt8          // 12 or 13
    let leapDisplay: UInt8         // 0 = none; else leap month repeats this number

    // Ordinal position (1-based) of the leap month, if any.
    var leapOrdinal: Int? { leapDisplay == 0 ? nil : Int(leapDisplay) + 1 }

    func monthLength(ordinal: Int) -> Int {
        (monthLengthBits >> (ordinal - 1)) & 1 == 1 ? 30 : 29
    }

    func monthStartRataDie(ordinal: Int) -> Int {
        var rataDie = newYearRataDie
        for i in 1..<ordinal { rataDie += monthLength(ordinal: i) }
        return rataDie
    }

    var daysInYear: Int {
        var days = 0
        for i in 1...Int(monthCount) { days += monthLength(ordinal: i) }
        return days
    }

    var endRataDie: Int { newYearRataDie + daysInYear }

    func label(ordinal: Int) -> (month: Int, isLeap: Bool) {
        guard let lo = leapOrdinal else { return (ordinal, false) }
        if ordinal == lo { return (Int(leapDisplay), true) }
        if ordinal > lo { return (ordinal - 1, false) }
        return (ordinal, false)
    }

    func ordinal(month: Int, isLeap: Bool) -> Int? {
        guard month >= 1 && month <= 12 else { return nil }
        guard let lo = leapOrdinal else { return isLeap ? nil : month }
        if isLeap {
            return month == Int(leapDisplay) ? lo : nil
        }
        return month < lo ? month : month + 1
    }

    // (ordinal, dayOfMonth) for an RD inside this year.
    func ordinalAndDay(rataDie: Int) -> (ordinal: Int, day: Int)? {
        guard rataDie >= newYearRataDie && rataDie < endRataDie else { return nil }
        var start = newYearRataDie
        for ordinal in 1...Int(monthCount) {
            let len = monthLength(ordinal: ordinal)
            if rataDie < start + len { return (ordinal, rataDie - start + 1) }
            start += len
        }
        return nil
    }
}

// MARK: - Engine: baked table + computed fallback

internal enum _ChineseCalendarEngine {
    // One entry per Chinese year, indexed by the Gregorian year in which that Chinese year begins.
    // Packing: bits 0-12 month lengths (1=30d), 13-16 leap display number (0=none), 17-22 new-year offset from Jan 19 of that Gregorian year.
    static let tableStart = 1901
    static let table: [UInt32] = [
    0x003E0752, 0x00280EA5, 0x0014B64A, 0x0038064B, // 1901-1904
    0x00200A9B, 0x000C9556, 0x0032056A, 0x001C0B59, // 1905-1908
    0x00065752, 0x002C0752, 0x0016DB25, 0x003C0B25, // 1909-1912
    0x00240A4B, 0x000EB2AB, 0x00340AAD, 0x0020056A, // 1913-1916
    0x00084B69, 0x002E0DA9, 0x001AFD92, 0x00400D92, // 1917-1920
    0x00280D25, 0x0012BA4D, 0x00380A56, 0x002202B6, // 1921-1924
    0x000A95B5, 0x003206D4, 0x001C0EA9, 0x00085E92, // 1925-1928
    0x002C0E92, 0x0016CD26, 0x003A052B, 0x00240A57, // 1929-1932
    0x000EB2B6, 0x00340B5A, 0x002006D4, 0x000A6EC9, // 1933-1936
    0x002E0749, 0x0018F693, 0x003E0A93, 0x0028052B, // 1937-1940
    0x0010CA5B, 0x00360AAD, 0x0022056A, 0x000C9B55, // 1941-1944
    0x00320BA4, 0x001C0B49, 0x00065A93, 0x002C0A95, // 1945-1948
    0x0014F52D, 0x003A0536, 0x00240AAD, 0x0010B5AA, // 1949-1952
    0x003405B2, 0x001E0DA5, 0x000A7D4A, 0x00300D4A, // 1953-1956
    0x00190A95, 0x003C0A97, 0x00280556, 0x0012CAB5, // 1957-1960
    0x00360AD5, 0x002206D2, 0x000C8EA5, 0x00320EA5, // 1961-1964
    0x001C064A, 0x00046C97, 0x002A0A9B, 0x0016F55A, // 1965-1968
    0x003A056A, 0x00240B69, 0x0010B752, 0x00360B52, // 1969-1972
    0x001E0B25, 0x0008964B, 0x002E0A4B, 0x001914AB, // 1973-1976
    0x003C02AD, 0x0026056D, 0x0012CB69, 0x00380DA9, // 1977-1980
    0x00220D92, 0x000C9D25, 0x00320D25, 0x001D5A4D, // 1981-1984
    0x00400A56, 0x002A02B6, 0x0014C5B5, 0x003A06D5, // 1985-1988
    0x00240EA9, 0x0010BE92, 0x00360E92, 0x00200D26, // 1989-1992
    0x00086A56, 0x002C0A57, 0x001914D6, 0x003E035A, // 1993-1996
    0x002606D5, 0x0012B6C9, 0x00380749, 0x00220693, // 1997-2000
    0x000A952B, 0x0030052B, 0x001A0A5B, 0x0006555A, // 2001-2004
    0x002A056A, 0x0014FB55, 0x003C0BA4, 0x00260B49, // 2005-2008
    0x000EBA93, 0x00340A95, 0x001E052D, 0x00088AAD, // 2009-2012
    0x002C0AB5, 0x001935AA, 0x003E05D2, 0x00280DA5, // 2013-2016
    0x0012DD4A, 0x00380D4A, 0x00220C95, 0x000C952E, // 2017-2020
    0x00300556, 0x001A0AB5, 0x000655B2, 0x002C06D2, // 2021-2024
    0x0014CEA5, 0x003A0725, 0x0024064B, 0x000EAC97, // 2025-2028
    0x00320CAB, 0x001E055A, 0x00086AD6, 0x002E0B69, // 2029-2032
    0x00197752, 0x003E0B52, 0x00280B25, 0x0012DA4B, // 2033-2036
    0x00360A4B, 0x002004AB, 0x000AA55B, 0x003005AD, // 2037-2040
    0x001A0B6A, 0x00065B52, 0x002C0D92, 0x0016FD25, // 2041-2044
    0x003A0D25, 0x00240A55, 0x000EB4AD, 0x003404B6, // 2045-2048
    0x001C05B5, 0x00086DAA, 0x002E0EC9, 0x001B1E92, // 2049-2052
    0x003E0E92, 0x00280D26, 0x0012CA56, 0x00360A57, // 2053-2056
    0x00200556, 0x000A86D5, 0x00300755, 0x001C0749, // 2057-2060
    0x00046E93, 0x002A0693, 0x0014F52B, 0x003A052B, // 2061-2064
    0x00220A5B, 0x000EB55A, 0x0034056A, 0x001E0B65, // 2065-2068
    0x0008974A, 0x002E0B4A, 0x00191A95, 0x003E0A95, // 2069-2072
    0x0026052D, 0x0010CAAD, 0x00360AB5, 0x002205AA, // 2073-2076
    0x000A8BA5, 0x00300DA5, 0x001C0D4A, 0x00067C95, // 2077-2080
    0x002A0C96, 0x0014F94E, 0x003A0556, 0x00240AB5, // 2081-2084
    0x000EB5B2, 0x003406D2, 0x001E0EA5, 0x000A8E4A, // 2085-2088
    0x002C068B, 0x00170C97, 0x003C04AB, 0x0026055B, // 2089-2092
    0x0010CAD6, 0x00360B6A, 0x00220752, 0x000C9725, // 2093-2096
    0x00300B45, 0x001A0A8B, 0x0004549B, 0x002A04AB, // 2097-2100
    ]

    // Cross-instance memoization of computed out-of-range years only (pre-1901 / post-2100); in-range dates read the baked table and never touch this. Bounded to 16 entries, so it never needs clearing.
    static let fallbackCache = Mutex<[Int: _ChineseYear]>([:])

    private static func decodeTableYear(relatedISOYear: Int) -> _ChineseYear {
        let v = table[relatedISOYear - tableStart]
        let leap = UInt8((v >> 13) & 0xF)
        return _ChineseYear(relatedISOYear: relatedISOYear, newYearRataDie: _CalendarAstronomy.gregorianRataDie(relatedISOYear, 1, 19) + Int((v >> 17) & 0x3F), monthLengthBits: UInt16(v & 0x1FFF), monthCount: leap == 0 ? 12 : 13, leapDisplay: leap)
    }

    /// Month structure for the Chinese year whose New Year falls in Gregorian `relatedISOYear`.
    ///
    /// In the baked range (1901...2100) this is a direct table decode. Outside it the structure is computed from astronomy and memoized: locate this year's New Year and the next year's, walk the new moons between them to get each month's first day, record 29- vs 30-day lengths as bits, and mark the leap month (the month carrying no major solar term). The seam years at the table edges reuse the table's own New Year so the computed and baked spans tile exactly.
    static func year(relatedISOYear: Int) -> _ChineseYear {
        let idx = relatedISOYear - tableStart
        if idx >= 0 && idx < table.count {
            return decodeTableYear(relatedISOYear: relatedISOYear)
        }
        if let cached = fallbackCache.withLock({ $0[relatedISOYear] }) {
            return cached
        }
        // Compute outside the lock with a local rules instance; the shared cache is only touched under the minimal critical section below.
        var rules = _ChineseRules()
        // Tile exactly with the baked table at the seams.
        let ny: Int
        if relatedISOYear == tableStart + table.count {
            ny = decodeTableYear(relatedISOYear: relatedISOYear - 1).endRataDie
        } else {
            ny = rules.newYear(relatedISOYear)
        }
        let nyNext: Int
        if relatedISOYear + 1 == tableStart {
            nyNext = decodeTableYear(relatedISOYear: tableStart).newYearRataDie
        } else {
            nyNext = rules.newYear(relatedISOYear + 1)
        }
        // Collect each month's first day: successive new moons from this New Year up to (but not including) the next year's New Year.
        var starts = [ny]
        var cur = ny
        while true {
            let nxt = rules.newMoonNear(cur + _ChineseRules.synodicGap, true)
            if nxt >= nyNext { break }
            starts.append(nxt)
            cur = nxt
        }
        // Pack month lengths (30-day months set a bit) and record the leap month, if any.
        var bits: UInt16 = 0
        var leapDisplay: UInt8 = 0
        for (i, s) in starts.enumerated() {
            let next = (i + 1 < starts.count) ? starts[i + 1] : nyNext
            assert(next - s == 29 || next - s == 30, "non-lunation month length \(next - s) in fallback year \(relatedISOYear)")
            if next - s == 30 { bits |= UInt16(1) << i }
            let label = rules.monthLabel(startingAt: s, gregorianYear: _CalendarAstronomy.gregorianYear(ofRataDie: s))
            if label.isLeap { leapDisplay = UInt8(label.month) }
        }
        let year = _ChineseYear(relatedISOYear: relatedISOYear, newYearRataDie: ny, monthLengthBits: bits, monthCount: UInt8(starts.count), leapDisplay: leapDisplay)
        fallbackCache.withLock {
            evictIfNeeded(&$0, capacity: 16)
            $0[relatedISOYear] = year
        }
        return year
    }

    static func year(containingRataDie rataDie: Int) -> _ChineseYear {
        // CNY falls Jan 19 + [2, 61]; estimate by Gregorian year and adjust.
        var iso = _CalendarAstronomy.gregorianYear(ofRataDie: rataDie)
        var y = year(relatedISOYear: iso)
        while rataDie < y.newYearRataDie {
            iso -= 1
            y = year(relatedISOYear: iso)
        }
        while rataDie >= y.endRataDie {
            iso += 1
            y = year(relatedISOYear: iso)
        }
        return y
    }
}


// MARK: - _CalendarChinese

/// Swift implementation of the Chinese lunisolar calendar.
///
/// Field conventions match ICU: era = 60-year cycle number since the 2637 BCE epoch, year = 1...60 within the cycle, month = 1...12 with `isLeapMonth` distinguishing the repeated month, extended year (used by `yearForWeekOfYear`) = related Gregorian year + 2637.
// @unchecked Sendable: mutable state is confined to copy-on-write via copy(), matching the other Swift calendar classes.
internal final class _CalendarChinese: _CalendarProtocol, @unchecked Sendable {

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .chinese, "_CalendarChinese only handles .chinese")
        self.identifier = identifier
        self.timeZone = timeZone ?? .default
        self.locale = locale
        if let firstWeekday, (firstWeekday >= 1 && firstWeekday <= 7) {
            _firstWeekday = firstWeekday
        }
        if var minimumDaysInFirstWeek {
            if minimumDaysInFirstWeek < 1 { minimumDaysInFirstWeek = 1 }
            else if minimumDaysInFirstWeek > 7 { minimumDaysInFirstWeek = 7 }
            _minimumDaysInFirstWeek = minimumDaysInFirstWeek
        }
    }

    let identifier: Calendar.Identifier
    var locale: Locale?
    var timeZone: TimeZone

    var _firstWeekday: Int?
    var firstWeekday: Int {
        set { _firstWeekday = _CalendarUtility.validatedFirstWeekday(newValue) }
        get { _CalendarUtility.resolveFirstWeekday(stored: _firstWeekday, locale: locale) }
    }

    var _minimumDaysInFirstWeek: Int?
    var minimumDaysInFirstWeek: Int {
        set { _minimumDaysInFirstWeek = _CalendarUtility.clampedMinimumDaysInFirstWeek(newValue) }
        get { _CalendarUtility.resolveMinimumDaysInFirstWeek(stored: _minimumDaysInFirstWeek, locale: locale) }
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> _CalendarProtocol {
        let args = _CalendarUtility.resolvedCopyArgs(
            currentTimeZone: timeZone, changingTimeZone: changingTimeZone,
            currentLocale: locale, changingLocale: changingLocale,
            currentFirstWeekday: _firstWeekday, changingFirstWeekday: changingFirstWeekday,
            currentMinimumDaysInFirstWeek: _minimumDaysInFirstWeek, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek
        )
        return _CalendarChinese(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(timeZone)
        hasher.combine(locale?.identifier)
        hasher.combine(_firstWeekday)
        hasher.combine(_minimumDaysInFirstWeek)
    }

    // No fast paths in phase 1, leap months complicate the matching patterns.
    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool { false }

    // MARK: Extended year model

    // extended year = related Gregorian year + 2637; era = 60-year cycle.
    static let extendedYearOffset = 2637

    // Supported extended-year domain (same convention as Hebrew's icuYearLowerBound/icuYearUpperBound).
    private static let extendedYearLowerBound = -5_000_000
    private static let extendedYearUpperBound = 5_000_000

    private static func yearData(extendedYear: Int) -> _ChineseYear {
        _ChineseCalendarEngine.year(relatedISOYear: extendedYear - extendedYearOffset)
    }

    private static func rataDie(extendedYear: Int, ordinal: Int, day: Int) -> Int {
        yearData(extendedYear: extendedYear).monthStartRataDie(ordinal: ordinal) + day - 1
    }

    // Foundation weekday numbering (1 = Sunday); no offset is needed because rata die day 1 (Jan 1, 1 CE) was a Monday.
    private static func weekday(ofRataDie rataDie: Int) -> Int {
        var r = rataDie % 7
        if r < 0 { r += 7 }
        return r + 1
    }

    private static func eraAndYear(extendedYear: Int) -> (era: Int, year: Int) {
        let e = _CalendarUtility.floorDiv(extendedYear - 1, 60)
        return (e + 1, extendedYear - 1 - e * 60 + 1)
    }

    private static func extendedYear(era: Int, year: Int) -> Int? {
        let (em1, sub) = era.subtractingReportingOverflow(1)
        if sub { return nil }
        let (eraYears, mul) = em1.multipliedReportingOverflow(by: 60)
        if mul { return nil }
        let (v, add) = eraYears.addingReportingOverflow(year)
        return add ? nil : v
    }

    // MARK: Range

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return 1..<83334          // ICU chnsecal LIMITS
        case .year: return 1..<61
        case .month: return 1..<13
        case .day: return 1..<30
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return -1..<6
        case .quarter: return 1..<5
        case .weekOfMonth: return 1..<6
        case .weekOfYear: return 1..<51
        case .yearForWeekOfYear: return Self.extendedYearLowerBound..<(Self.extendedYearUpperBound + 1)
        case .nanosecond: return 0..<1_000_000_000
        case .isLeapMonth: return 0..<2
        case .isRepeatedDay: return 0..<1
        case .dayOfYear: return 1..<354
        case .calendar, .timeZone:
            return nil
        }
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return 1..<83334
        case .year: return 1..<61
        case .month: return 1..<13
        case .day: return 1..<31
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return -1..<6
        case .quarter: return 1..<5
        case .weekOfMonth: return 1..<7
        case .weekOfYear: return 1..<56
        case .yearForWeekOfYear: return Self.extendedYearLowerBound..<(Self.extendedYearUpperBound + 1)
        case .nanosecond: return 0..<1_000_000_000
        case .isLeapMonth: return 0..<2
        case .isRepeatedDay: return 0..<1
        case .dayOfYear: return 1..<386
        case .calendar, .timeZone:
            return nil
        }
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        switch smaller {
        case .weekday:
            switch larger {
            case .second, .minute, .hour, .day, .weekday: return nil
            default: return maximumRange(of: smaller)
            }
        case .hour:
            switch larger {
            case .second, .minute, .hour: return nil
            default: return maximumRange(of: smaller)
            }
        case .minute:
            switch larger {
            case .second, .minute: return nil
            default: return maximumRange(of: smaller)
            }
        case .second:
            switch larger {
            case .second: return nil
            default: return maximumRange(of: smaller)
            }
        case .nanosecond:
            return maximumRange(of: smaller)
        default:
            break
        }
        switch (smaller, larger) {
        case (.month, .year):
            // Number of display months is always 12 (the leap repeats a number).
            return 1..<13
        case (.month, .quarter):
            // ICU reports display month numbers spanned by the quarter; the span can shrink (see quarterSpan).
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            guard let span = Self.quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            return span.firstDisplay..<(span.lastDisplay + 1)
        case (.day, .quarter):
            // ICU counts calendar days here, not 86400 s chunks, the generic interval+ordinality fallback overcounts by one in DST fall-back quarters.
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            guard let span = Self.quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            let startRataDie = Self.rataDie(extendedYear: extendedYear, ordinal: span.startOrdinal, day: 1)
            let endRataDie = Self.rataDie(extendedYear: span.endExtendedYear, ordinal: span.endOrdinal, day: 1)
            return 1..<(endRataDie - startRataDie + 1)
        default:
            break
        }
        guard let interval = dateInterval(of: larger, for: date) else { return nil }
        guard let ord1 = ordinality(of: smaller, in: larger, for: interval.start + 0.1) else { return nil }
        guard let ord2 = ordinality(of: smaller, in: larger, for: interval.start + interval.duration - 0.1) else { return nil }
        if ord2 < ord1 { return ord1..<ord1 }
        return ord1..<(ord2 + 1)
    }

    // MARK: Ordinality

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        let timeZone = self.timeZone
        switch (smaller, larger) {
        case (.day, .year):
            return dateComponents([.dayOfYear], from: date, in: timeZone).dayOfYear
        case (.day, .month):
            return dateComponents([.day], from: date, in: timeZone).day
        case (.month, .year):
            // ICU returns the display month number, not the ordinal position.
            return dateComponents([.month], from: date, in: timeZone).month
        case (.quarter, .year):
            // ICU's mquarter mapping on the display month; a leap month is in the quarter of its base number.
            guard let m = dateComponents([.month], from: date, in: timeZone).month else { return nil }
            return (m + 2) / 3
        case (.month, .quarter):
            // ICU's mcount mapping, position of the display number in its quarter.
            guard let m = dateComponents([.month], from: date, in: timeZone).month else { return nil }
            return (m - 1) % 3 + 1
        case (.day, .quarter):
            // ICU: floor of absolute seconds since the quarter start, no timeZone round trip.
            guard let interval = dateInterval(of: .quarter, for: date) else { return nil }
            return Int((date.timeIntervalSince(interval.start) / 86400.0).rounded(.down)) + 1
        case (.weekOfYear, .year):
            let comps = dateComponents([.weekday, .dayOfYear], from: date, in: timeZone)
            guard let weekday = comps.weekday, let dayOfYear = comps.dayOfYear else { return nil }
            return weekOfYearNumber(dayOfYear: dayOfYear, weekday: weekday)
        case (.weekOfMonth, .month):
            return dateComponents([.weekOfMonth], from: date, in: timeZone).weekOfMonth
        case (.weekday, .year):
            guard let dayOfYear = dateComponents([.dayOfYear], from: date, in: timeZone).dayOfYear else { return nil }
            return (dayOfYear - 1) / 7 + 1
        case (.weekday, .month), (.weekdayOrdinal, .month):
            guard let day = dateComponents([.day], from: date, in: timeZone).day else { return nil }
            return (day - 1) / 7 + 1
        case (.weekday, .weekOfYear):
            guard let weekday = dateComponents([.weekday], from: date, in: timeZone).weekday else { return nil }
            return ((weekday - firstWeekday + 7) % 7) + 1
        case (.hour, .day):
            guard let hour = dateComponents([.hour], from: date, in: timeZone).hour else { return nil }
            return hour + 1
        case (.minute, .hour):
            guard let minute = dateComponents([.minute], from: date, in: timeZone).minute else { return nil }
            return minute + 1
        case (.second, .minute):
            guard let second = dateComponents([.second], from: date, in: timeZone).second else { return nil }
            return second + 1
        case (.nanosecond, .second):
            guard let nanosecond = dateComponents([.nanosecond], from: date, in: timeZone).nanosecond else { return nil }
            return nanosecond + 1
        default:
            return nil
        }
    }

    // Week-of-year before the previous/next-year wrap adjustments.
    private func weekOfYearNumber(dayOfYear: Int, weekday: Int) -> Int {
        let relativeWeekdayForYearStart = (weekday - dayOfYear + 7001 - firstWeekday) % 7
        var weekOfYear = (dayOfYear - 1 + relativeWeekdayForYearStart) / 7
        if (7 - relativeWeekdayForYearStart) >= minimumDaysInFirstWeek { weekOfYear += 1 }
        return weekOfYear
    }

    // MARK: Internal field extraction

    /// (extended year, month ordinal, day) for a date in the given timezone.
    private func fields(for date: Date, in timeZone: TimeZone) -> (extendedYear: Int, ordinal: Int, day: Int) {
        let (extendedYear, ordinal, day, _) = fieldsAndTime(for: date, in: timeZone)
        return (extendedYear, ordinal, day)
    }

    /// `fields` plus local seconds-in-day, from a single timezone-offset lookup.
    private func fieldsAndTime(for date: Date, in timeZone: TimeZone) -> (extendedYear: Int, ordinal: Int, day: Int, secondsInDay: Double) {
        let totalOffset = timeZone.secondsFromGMT(for: date)
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(totalOffset)
        let (rataDie, secondsInDay): (Int, Double) = _CalendarUtility.rataDieAndSecondsInDay(localSeconds: localSeconds)
        let y = _ChineseCalendarEngine.year(containingRataDie: rataDie)
        guard let (ordinal, day) = y.ordinalAndDay(rataDie: rataDie) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(rataDie)")
        }
        return (y.relatedISOYear + Self.extendedYearOffset, ordinal, day, secondsInDay)
    }

    // MARK: Date intervals

    // Like ICU, a leap month is not absorbed into its quarter: dates in it can fall outside their own quarter interval and the month range shrinks.
    private static func quarterSpan(extendedYear: Int, ordinal: Int) -> (firstDisplay: Int, startOrdinal: Int, lastDisplay: Int, endExtendedYear: Int, endOrdinal: Int)? {
        let y = yearData(extendedYear: extendedYear)
        let q = (y.label(ordinal: ordinal).month + 2) / 3
        let firstDisplay = 3 * (q - 1) + 1
        guard let startOrdinal = y.ordinal(month: firstDisplay, isLeap: false) else { return nil }
        var (ey, eo) = (extendedYear, startOrdinal)
        for _ in 0..<2 { (ey, eo) = nextOrdinalMonth(extendedYear: ey, ordinal: eo) }
        let lastDisplay = yearData(extendedYear: ey).label(ordinal: eo).month
        let (endExtendedYear, endOrdinal) = nextOrdinalMonth(extendedYear: ey, ordinal: eo)
        return (firstDisplay, startOrdinal, lastDisplay, endExtendedYear, endOrdinal)
    }

    private static func nextOrdinalMonth(extendedYear: Int, ordinal: Int) -> (Int, Int) {
        let y = yearData(extendedYear: extendedYear)
        if ordinal < Int(y.monthCount) { return (extendedYear, ordinal + 1) }
        return (extendedYear + 1, 1)
    }

    private static func prevOrdinalMonth(extendedYear: Int, ordinal: Int) -> (Int, Int) {
        if ordinal > 1 { return (extendedYear, ordinal - 1) }
        let py = yearData(extendedYear: extendedYear - 1)
        return (extendedYear - 1, Int(py.monthCount))
    }

    private func firstDayOfWeekYear(_ extendedYear: Int) -> Int {
        let rdNY = Self.yearData(extendedYear: extendedYear).newYearRataDie
        let nyWeekday = Self.weekday(ofRataDie: rdNY)
        let rel = (nyWeekday - firstWeekday + 7) % 7
        let offset: Int
        if (7 - rel) >= minimumDaysInFirstWeek {
            offset = -rel
        } else {
            offset = 7 - rel
        }
        return rdNY + offset
    }

    /// Date at local midnight of (extendedYear, ordinal, day).
    private func localMidnight(extendedYear: Int, ordinal: Int, day: Int, in timeZone: TimeZone) -> Date {
        _CalendarUtility.utcDate(fromRataDie: Self.rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day), secondsInDay: 0, in: timeZone,
                repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        let timeZone = self.timeZone
        let (extendedYear, ordinal, day) = fields(for: date, in: timeZone)

        switch component {
        case .era:
            // One era = one 60-year cycle.
            let (era, _) = Self.eraAndYear(extendedYear: extendedYear)
            guard let startExt = Self.extendedYear(era: era, year: 1) else { return nil }
            let start = localMidnight(extendedYear: startExt, ordinal: 1, day: 1, in: timeZone)
            let end = localMidnight(extendedYear: startExt + 60, ordinal: 1, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .year:
            let start = localMidnight(extendedYear: extendedYear, ordinal: 1, day: 1, in: timeZone)
            let end = localMidnight(extendedYear: extendedYear + 1, ordinal: 1, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .yearForWeekOfYear:
            // Deliberate divergence from ICU: ICU's chinese calendar cannot use YEAR_WOY on the fields-to-time side (chnsecal handleGetExtendedYear never reads it), so its interval degenerates to nil and its add is a no-op. We implement the Gregorian-family week-year semantics instead, like Hebrew (precedent: Japanese .era interval). If behavior identical to ICU is ever required: return nil here and delete the yearForWeekOfYear block in date(byAdding:).
            let weekYearComps = dateComponents([.yearForWeekOfYear], from: date, in: timeZone)
            guard let weekYear = weekYearComps.yearForWeekOfYear else { return nil }
            let rdStart = firstDayOfWeekYear(weekYear)
            let rdEnd = firstDayOfWeekYear(weekYear + 1)
            let start = _CalendarUtility.utcDate(fromRataDie: rdStart, secondsInDay: 0, in: timeZone,
                                repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let end = _CalendarUtility.utcDate(fromRataDie: rdEnd, secondsInDay: 0, in: timeZone,
                              repeatedTimePolicy: .former, skippedTimePolicy: .former)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .month:
            let start = localMidnight(extendedYear: extendedYear, ordinal: ordinal, day: 1, in: timeZone)
            let (ny, nm) = Self.nextOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
            let end = localMidnight(extendedYear: ny, ordinal: nm, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .weekOfYear, .weekOfMonth:
            let rdHere = Self.rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day)
            let weekday = Self.weekday(ofRataDie: rdHere)
            var daysBack = weekday - firstWeekday
            if daysBack < 0 { daysBack += 7 }
            let rdStart = rdHere - daysBack
            let start = _CalendarUtility.utcDate(fromRataDie: rdStart, secondsInDay: 0, in: timeZone,
                                repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let end = _CalendarUtility.utcDate(fromRataDie: rdStart + 7, secondsInDay: 0, in: timeZone,
                              repeatedTimePolicy: .former, skippedTimePolicy: .former)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .quarter:
            // See quarterSpan for the quarter model and its leap-month containment quirk.
            guard let span = Self.quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            let start = localMidnight(extendedYear: extendedYear, ordinal: span.startOrdinal, day: 1, in: timeZone)
            let end = localMidnight(extendedYear: span.endExtendedYear, ordinal: span.endOrdinal, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .day, .weekday, .weekdayOrdinal, .dayOfYear:
            let rdHere = Self.rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day)
            let start = _CalendarUtility.utcDate(fromRataDie: rdHere, secondsInDay: 0, in: timeZone,
                                repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let end = _CalendarUtility.utcDate(fromRataDie: rdHere + 1, secondsInDay: 0, in: timeZone,
                              repeatedTimePolicy: .former, skippedTimePolicy: .former)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .hour:
            let ti = Double(timeZone.secondsFromGMT(for: date))
            let time = date.timeIntervalSinceReferenceDate
            var fixedTime = time + ti
            fixedTime = (fixedTime / 3600.0).rounded(.down) * 3600.0
            fixedTime = fixedTime - ti
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: fixedTime), duration: 3600.0)
        case .minute:
            let time = date.timeIntervalSinceReferenceDate
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: (time / 60.0).rounded(.down) * 60.0), duration: 60.0)
        case .second:
            let time = date.timeIntervalSinceReferenceDate
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: time.rounded(.down)), duration: 1.0)
        case .nanosecond:
            return DateInterval(start: date, duration: 1e-9)
        case .isLeapMonth, .isRepeatedDay, .calendar, .timeZone:
            return nil
        }
    }

    // MARK: Weekend

    func isDateInWeekend(_ date: Date) -> Bool {
        let weekendRange = locale?.weekendRange ?? _CalendarUtility.defaultWeekendRange
        let comps = dateComponents([.weekday, .hour, .minute, .second], from: date, in: self.timeZone)
        guard let dayOfWeek = comps.weekday else { return false }
        let secondsInDay = (comps.hour ?? 0) * Calendar._secondsInHour
            + (comps.minute ?? 0) * 60
            + (comps.second ?? 0)
        let timeInDay = TimeInterval(secondsInDay)
        return _CalendarUtility.isDateInWeekend(weekday: dayOfWeek, timeInDay: timeInDay, weekendRange: weekendRange)
    }

    // MARK: Date ↔ DateComponents

    func date(from components: DateComponents) -> Date? {
        // Missing era defaults to the CURRENT date's era (ICU fields default from now).
        let era: Int
        if let e = components.era {
            era = e
        } else {
            let (nowExt, _, _) = fields(for: Date.now, in: components.timeZone ?? timeZone)
            era = Self.eraAndYear(extendedYear: nowExt).era
        }
        guard let yearValue = components.year else { return nil }
        guard let extendedYear = Self.extendedYear(era: era, year: yearValue),
              extendedYear > Self.extendedYearLowerBound && extendedYear < Self.extendedYearUpperBound else { return nil }

        let month = components.month ?? 1
        let isLeap = components.isLeapMonth ?? false
        let day = components.day ?? 1

        let y = Self.yearData(extendedYear: extendedYear)
        guard month >= 1 && month <= 12 else { return nil }
        // A leap month that doesn't exist in this year falls back to the regular month.
        let ordinal: Int
        if let o = y.ordinal(month: month, isLeap: isLeap) {
            ordinal = o
        } else if isLeap, let o = y.ordinal(month: month, isLeap: false) {
            ordinal = o
        } else {
            return nil
        }
        let daysInMonth = y.monthLength(ordinal: ordinal)
        guard day >= 1 && day <= daysInMonth else { return nil }

        let rataDie = y.monthStartRataDie(ordinal: ordinal) + day - 1

        var secondsInDay: Double = 0
        if let hour = components.hour { secondsInDay += Double(hour) * 3600 }
        if let minute = components.minute { secondsInDay += Double(minute) * 60 }
        if let second = components.second { secondsInDay += Double(second) }
        if let nanosecond = components.nanosecond { secondsInDay += Double(nanosecond) / 1e9 }

        let timeZone = components.timeZone ?? timeZone
        return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        let totalOffset = timeZone.secondsFromGMT(for: date)
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(totalOffset)
        let (rataDie, secondsInDay): (Int, Double) = _CalendarUtility.rataDieAndSecondsInDay(localSeconds: localSeconds)

        let y = _ChineseCalendarEngine.year(containingRataDie: rataDie)
        guard let (ordinal, day) = y.ordinalAndDay(rataDie: rataDie) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(rataDie)")
        }
        let label = y.label(ordinal: ordinal)
        let extendedYear = y.relatedISOYear + Self.extendedYearOffset
        let (era, yearInCycle) = Self.eraAndYear(extendedYear: extendedYear)

        var result = DateComponents()

        if components.contains(.era) { result.era = era }
        if components.contains(.year) { result.year = yearInCycle }
        if components.contains(.month) { result.month = label.month }
        if components.contains(.day) { result.day = day }
        // ICU populates isLeapMonth iff .month or .isLeapMonth was requested.
        if components.contains(.month) || components.contains(.isLeapMonth) {
            result.isLeapMonth = label.isLeap
        }

        if components.contains(.hour) || components.contains(.minute)
            || components.contains(.second) || components.contains(.nanosecond) {
            let h = Int(secondsInDay / 3600)
            let remAfterH = secondsInDay - Double(h) * 3600
            let m = Int(remAfterH / 60)
            let remAfterM = remAfterH - Double(m) * 60
            let s = Int(remAfterM)
            let ns = Int((localSeconds - localSeconds.rounded(.down)) * 1_000_000_000)
            if components.contains(.hour) { result.hour = h }
            if components.contains(.minute) { result.minute = m }
            if components.contains(.second) { result.second = s }
            if components.contains(.nanosecond) { result.nanosecond = ns }
        }

        if components.contains(.weekday) {
            result.weekday = Self.weekday(ofRataDie: rataDie)
        }

        if components.contains(.dayOfYear) {
            result.dayOfYear = rataDie - y.newYearRataDie + 1
        }

        if components.contains(.timeZone) {
            result.timeZone = timeZone
        }

        let needsWeekFields = components.contains(.weekdayOrdinal) ||
                              components.contains(.weekOfMonth) ||
                              components.contains(.weekOfYear) ||
                              components.contains(.yearForWeekOfYear)
        if needsWeekFields {
            let weekday = Self.weekday(ofRataDie: rataDie)
            let dayOfYear = rataDie - y.newYearRataDie + 1
            let yearLength = y.daysInYear
            let relativeWeekday = (weekday + 7 - firstWeekday) % 7

            var weekOfYear = weekOfYearNumber(dayOfYear: dayOfYear, weekday: weekday)
            var yearForWeekOfYear = extendedYear
            if weekOfYear == 0 {
                let previousYearLength = Self.yearData(extendedYear: extendedYear - 1).daysInYear
                let previousDayOfYear = dayOfYear + previousYearLength
                weekOfYear = _CalendarUtility.weekNumber(
                    desiredDay: previousDayOfYear, dayOfPeriod: previousDayOfYear, weekday: weekday,
                    firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
                yearForWeekOfYear -= 1
            } else if dayOfYear >= yearLength - 5 {
                var lastRelativeDayOfWeek = (relativeWeekday + yearLength - dayOfYear) % 7
                if lastRelativeDayOfWeek < 0 { lastRelativeDayOfWeek += 7 }
                if ((6 - lastRelativeDayOfWeek) >= minimumDaysInFirstWeek)
                    && ((dayOfYear + 7 - relativeWeekday) > yearLength) {
                    weekOfYear = 1
                    yearForWeekOfYear += 1
                }
            }

            let weekOfMonth = _CalendarUtility.weekNumber(
                desiredDay: day, dayOfPeriod: day, weekday: weekday,
                firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
            let weekdayOrdinal = (day - 1) / 7 + 1

            if components.contains(.weekdayOrdinal)    { result.weekdayOrdinal = weekdayOrdinal }
            if components.contains(.weekOfMonth)       { result.weekOfMonth = weekOfMonth }
            if components.contains(.weekOfYear)        { result.weekOfYear = weekOfYear }
            if components.contains(.yearForWeekOfYear) { result.yearForWeekOfYear = yearForWeekOfYear }
        }

        // TODO: Support quarter; currently unsupported, every backend returns 0.
        if components.contains(.quarter) {
            result.quarter = 0
        }

        return result
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        dateComponents(components, from: date, in: self.timeZone)
    }

    // MARK: ICU month resolution (chnsecal handleComputeMonthStart semantics)

    /// chnsecal month resolution: estimate CNY + (display-1)*29 days, advance to the next month start, bump once on display/leap mismatch.
    private static func resolvedMonthStart(extendedYear: Int, display: Int, leap: Bool) -> Int {
        let ny = yearData(extendedYear: extendedYear).newYearRataDie
        let target = ny + (display - 1) * 29
        var y = _ChineseCalendarEngine.year(containingRataDie: target)
        guard let od = y.ordinalAndDay(rataDie: target) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(target)")
        }
        var ordinal = od.ordinal
        var est = y.monthStartRataDie(ordinal: ordinal)
        if est < target {   // target mid-month: next month start
            (est, y, ordinal) = Self.nextMonthStart(after: y, ordinal: ordinal)
        }
        let lbl = y.label(ordinal: ordinal)
        if lbl.month != display || lbl.isLeap != leap {
            (est, y, ordinal) = Self.nextMonthStart(after: y, ordinal: ordinal)
        }
        return est
    }

    private static func nextMonthStart(after y: _ChineseYear, ordinal: Int) -> (Int, _ChineseYear, Int) {
        if ordinal < Int(y.monthCount) {
            return (y.monthStartRataDie(ordinal: ordinal + 1), y, ordinal + 1)
        }
        let ny = _ChineseCalendarEngine.year(relatedISOYear: y.relatedISOYear + 1)
        return (ny.newYearRataDie, ny, 1)
    }

    // MARK: Adding

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        var result = date

        // Wrap-day single-component fast path.
        if wrappingComponents,
           let d = components.day, d != 0,
           (components.era ?? 0) == 0, (components.year ?? 0) == 0, (components.month ?? 0) == 0,
           (components.weekOfYear ?? 0) == 0, (components.weekOfMonth ?? 0) == 0,
           (components.weekdayOrdinal ?? 0) == 0, (components.weekday ?? 0) == 0,
           (components.dayOfYear ?? 0) == 0, (components.yearForWeekOfYear ?? 0) == 0,
           (components.hour ?? 0) == 0, (components.minute ?? 0) == 0,
           (components.second ?? 0) == 0, (components.nanosecond ?? 0) == 0 {
            let timeZone = self.timeZone
            let (extendedYear, ordinal, curDay, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
            let y = Self.yearData(extendedYear: extendedYear)
            let monthLen = y.monthLength(ordinal: ordinal)
            let newDay = ((curDay - 1 + d) % monthLen + monthLen) % monthLen + 1
            let rataDie = y.monthStartRataDie(ordinal: ordinal) + newDay - 1
            return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                           repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        var yearsToAdd = components.year ?? 0
        if let era = components.era, era != 0 {
            let (eraYears, mul) = era.multipliedReportingOverflow(by: 60)
            if mul { return nil }
            let (sum, add) = yearsToAdd.addingReportingOverflow(eraYears)
            if add { return nil }
            yearsToAdd = sum
        }
        let monthsToAdd = components.month ?? 0

        if yearsToAdd != 0 {
            let timeZone = self.timeZone
            let (extendedYear, ordinal, d, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
            let y = Self.yearData(extendedYear: extendedYear)
            let label = y.label(ordinal: ordinal)
            let (newExt, ovf) = extendedYear.addingReportingOverflow(yearsToAdd)
            guard !ovf, newExt > Self.extendedYearLowerBound, newExt < Self.extendedYearUpperBound else { return nil }
            // ICU's add-year pin: resolve the month by single-bump, pin the day via a second resolution that keeps the source leap flag, then spill leniently (Calendar::add + getActualMaximum semantics).
            let start0 = Self.resolvedMonthStart(extendedYear: newExt, display: label.month, leap: label.isLeap)
            let y1 = _ChineseCalendarEngine.year(containingRataDie: start0)
            guard let od1 = y1.ordinalAndDay(rataDie: start0) else {
                fatalError("year(containingRataDie:) returned a year not containing rataDie \(start0)")
            }
            let ord1 = od1.ordinal
            let display1 = y1.label(ordinal: ord1).month
            let start2 = Self.resolvedMonthStart(extendedYear: newExt, display: display1, leap: label.isLeap)
            let y2 = _ChineseCalendarEngine.year(containingRataDie: start2)
            guard let od2 = y2.ordinalAndDay(rataDie: start2) else {
                fatalError("year(containingRataDie:) returned a year not containing rataDie \(start2)")
            }
            let ord2 = od2.ordinal
            let maxDom = y2.monthLength(ordinal: ord2)
            let pinnedDay = min(d, maxDom)
            let rataDie = start0 + pinnedDay - 1
            result = _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                             repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        if monthsToAdd != 0 {
            let timeZone = self.timeZone
            var (extendedYear, ordinal, d, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
            // Reject adds that provably exit the extendedYear domain before the ordinal walk: a year has at most 13 months, so the target lies at or beyond extendedYear + monthsToAdd/13.
            let (reach, reachOvf) = extendedYear.addingReportingOverflow(monthsToAdd / 13)
            guard !reachOvf, reach > Self.extendedYearLowerBound, reach < Self.extendedYearUpperBound else { return nil }
            var remaining = monthsToAdd
            while remaining > 0 {
                (extendedYear, ordinal) = Self.nextOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
                remaining -= 1
            }
            while remaining < 0 {
                (extendedYear, ordinal) = Self.prevOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
                remaining += 1
            }
            guard extendedYear > Self.extendedYearLowerBound && extendedYear < Self.extendedYearUpperBound else { return nil }
            let ny = Self.yearData(extendedYear: extendedYear)
            let clampedDay = min(d, ny.monthLength(ordinal: ordinal))
            let rataDie = ny.monthStartRataDie(ordinal: ordinal) + clampedDay - 1
            result = _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                             repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        var daysToAdd = 0
        if let d = components.day { daysToAdd += d }
        if let doy = components.dayOfYear { daysToAdd += doy }
        if let wom = components.weekOfMonth { daysToAdd += wom * 7 }
        if let woy = components.weekOfYear { daysToAdd += woy * 7 }
        if let wo = components.weekdayOrdinal { daysToAdd += wo * 7 }
        if let w = components.weekday { daysToAdd += w }

        // Deliberate divergence from ICU (see dateInterval(.yearForWeekOfYear) note): ICU no-ops YEAR_WOY adds for chinese; we advance by week-years like Hebrew.
        if let n = components.yearForWeekOfYear, n != 0 {
            let timeZone = self.timeZone
            let localComps = dateComponents([.yearForWeekOfYear], from: result, in: timeZone)
            if let yy = localComps.yearForWeekOfYear {
                let (target, overflow) = yy.addingReportingOverflow(n)
                guard !overflow, target > Self.extendedYearLowerBound, target < Self.extendedYearUpperBound else { return nil }
                // Summed per-year week counts telescope to the distance between the two week-year anchors (both firstWeekday-aligned), so the add is O(1).
                daysToAdd += firstDayOfWeekYear(target) - firstDayOfWeekYear(yy)
            }
        }

        if daysToAdd != 0 {
            let timeZone = self.timeZone
            let totalOffset1 = timeZone.secondsFromGMT(for: result)
            let candidate = result + Double(daysToAdd) * 86400
            let totalOffset2 = timeZone.secondsFromGMT(for: candidate)
            result = candidate - Double(totalOffset2 - totalOffset1)
        }

        if let h = components.hour, h != 0 { result += Double(h) * 3600 }
        if let m = components.minute, m != 0 { result += Double(m) * 60 }
        if let s = components.second, s != 0 { result += Double(s) }
        if let ns = components.nanosecond, ns != 0 { result += Double(ns) / 1_000_000_000 }

        return result
    }

    // MARK: Difference

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        var result = DateComponents()
        var curr = start
        for component in Self.orderedDifferenceComponents(components) {
            let (diff, newCurr) = difference(inComponent: component, from: curr, to: end)
            result.setValue(diff, for: component)
            curr = newCurr
        }
        return result
    }

    private static func orderedDifferenceComponents(_ components: Calendar.ComponentSet) -> [Calendar.Component] {
        var out: [Calendar.Component] = []
        if components.contains(.era) { out.append(.era) }
        if components.contains(.year) { out.append(.year) }
        if components.contains(.yearForWeekOfYear) { out.append(.yearForWeekOfYear) }
        if components.contains(.quarter) { out.append(.quarter) }
        if components.contains(.month) { out.append(.month) }
        if components.contains(.weekOfYear) { out.append(.weekOfYear) }
        if components.contains(.weekOfMonth) { out.append(.weekOfMonth) }
        if components.contains(.day) { out.append(.day) }
        if components.contains(.dayOfYear) { out.append(.dayOfYear) }
        if components.contains(.weekday) { out.append(.weekday) }
        if components.contains(.weekdayOrdinal) { out.append(.weekdayOrdinal) }
        if components.contains(.hour) { out.append(.hour) }
        if components.contains(.minute) { out.append(.minute) }
        if components.contains(.second) { out.append(.second) }
        if components.contains(.nanosecond) { out.append(.nanosecond) }
        return out
    }

    private func difference(inComponent component: Calendar.Component, from start: Date, to end: Date) -> (Int, Date) {
        if start == end { return (0, start) }

        switch component {
        case .hour:
            let delta = end.timeIntervalSince(start) / 3600
            let diff = Int(delta.rounded(.towardZero))
            return (diff, start.addingTimeInterval(Double(diff) * 3600))
        case .minute:
            let delta = end.timeIntervalSince(start) / 60
            let diff = Int(delta.rounded(.towardZero))
            return (diff, start.addingTimeInterval(Double(diff) * 60))
        case .second:
            let delta = end.timeIntervalSince(start)
            let diff = Int(delta.rounded(.towardZero))
            return (diff, start.addingTimeInterval(Double(diff)))
        case .nanosecond:
            let delta = end.timeIntervalSince(start) * 1_000_000_000
            let diff = Int(delta.rounded(.towardZero))
            return (diff, start.addingTimeInterval(Double(diff) / 1_000_000_000))
        default:
            break
        }

        let forward = end > start
        let step = forward ? 1 : -1
        var diff = 0
        var current = start
        var safety = 0

        while true {
            let trial = diff + step
            var dc = DateComponents()
            dc.setValue(trial, for: component)
            guard let nextStep = date(byAdding: dc, to: start, wrappingComponents: false) else {
                break
            }
            if nextStep == current {
                break
            }
            let overshoot = forward ? (nextStep > end) : (nextStep < end)
            if overshoot { break }
            current = nextStep
            diff = trial
            safety += 1
            if safety > 1_000_000 { break }
        }
        return (diff, current)
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
