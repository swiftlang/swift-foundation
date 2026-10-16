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

#if !hasFeature(Embedded)

// Engine for the Chinese, Dangi and Vietnamese calendars: a baked table for 1901 to 2100, astronomy for the other years. `Docs/Chinese_Family_Calendars.md` explains the variants.

// MARK: - Variants

/// The calendars that share the Chinese rules. They differ in the day boundary, the baked table, and the `.yearForWeekOfYear` number.
internal enum ChineseCalendarVariant: Sendable {
    case chinese
    case dangi
    case vietnamese

    init?(identifier: Calendar.Identifier) {
        switch identifier {
        case .chinese: self = .chinese
        case .dangi: self = .dangi
        case .vietnamese: self = .vietnamese
        default: return nil
        }
    }

    /// The number of hours that the day boundary is ahead of UTC. The moment is a count of days since the rata die epoch.
    ///
    /// Chinese uses UTC+8. Dangi uses UTC+8 before 1897, UTC+7 in 1897, UTC+8 from 1898 to 1911, and UTC+9 from 1912. Vietnamese uses UTC+8 before 1968, then UTC+7.
    /// Each change is at local midnight of the earlier offset, on 1897-01-18, 1898-01-18 and 1912-01-16 (Dangi) and 1968-01-02 (Vietnamese).
    /// The dates come from counting 365 days for every year since 1970.
    func utcOffsetHours(atMoment moment: Double) -> Double {
        switch self {
        case .chinese:
            return 8.0
        case .dangi:
            if moment < Self.moment(ofYear: 1897, offsetBefore: 8.0) { return 8.0 }
            if moment < Self.moment(ofYear: 1898, offsetBefore: 7.0) { return 7.0 }
            if moment < Self.moment(ofYear: 1912, offsetBefore: 8.0) { return 8.0 }
            return 9.0
        case .vietnamese:
            return moment < Self.moment(ofYear: 1968, offsetBefore: 8.0) ? 8.0 : 7.0
        }
    }

    private static let rataDieOfEpoch1970 = 719_163.0

    private static func moment(ofYear year: Int, offsetBefore hours: Double) -> Double {
        rataDieOfEpoch1970 + Double((year - 1970) * 365) - hours / 24.0
    }

    /// The number added to the related Gregorian year to get the number that `.yearForWeekOfYear` reports.
    var weekYearOffset: Int {
        switch self {
        case .chinese, .vietnamese: return 2637
        case .dangi: return 2333
        }
    }
}

// MARK: - Month-structure rules over the astronomy engine
//
// The astronomy returns moments in universal time. These rules use the offset of the variant to find the day that holds a moment. The months do not depend on the calendar's `timeZone`.
//
// These functions compute directly, without caching, which keeps the code minimal. They only run for out-of-range years (before 1901 or after 2100); the in-range path reads the baked table and never calls them, so normal usage is unaffected.
//
// Optimization opportunity: within one out-of-range year, each of its 12 or 13 month labels recomputes the same two or three winter solstices, which are the expensive astronomy. Adding a small local memo of the winter solstice and New Year lookups (a plain dictionary, no lock, inside `year(relatedISOYear:)`) would compute each solstice once per year instead of once per month, making out-of-range computation roughly 1.6 to 1.8 times faster. Add it if out-of-range performance ever becomes a real bottleneck.

fileprivate let chineseSynodicGap = 25

// Local midnight of an RD day, as a universal moment.
fileprivate func chineseMidnight(_ rataDie: Int, _ variant: ChineseCalendarVariant) -> Double {
    Double(rataDie) - 1.0 + (24.0 - variant.utcOffsetHours(atMoment: Double(rataDie))) / 24.0
}

fileprivate func chineseLocalDay(_ moment: Double, _ variant: ChineseCalendarVariant) -> Int {
    Int((moment + variant.utcOffsetHours(atMoment: moment) / 24.0).rounded(.down))
}

// Winter solstice day on or after Dec 1 (chnsecal winterSolstice).
fileprivate func chineseWinterSolstice(_ gregorianYear: Int, _ variant: ChineseCalendarVariant) -> Int {
    var day = _CalendarAstronomy.gregorianRataDie(gregorianYear, 12, 10)
    while true {
        let lon = _CalendarAstronomy.solarLongitude(at: chineseMidnight(day + 1, variant))
        if lon >= 270.0 && lon < 350.0 { break }
        day += 1
    }
    return day
}

fileprivate func chineseNewMoonNear(_ days: Int, _ after: Bool, _ variant: ChineseCalendarVariant) -> Int {
    let m = chineseMidnight(days, variant)
    let nm = after ? _CalendarAstronomy.newMoonAtOrAfter(m) : _CalendarAstronomy.newMoonBefore(m)
    return chineseLocalDay(nm, variant)
}

fileprivate func chineseSynodicMonthsBetween(_ day1: Int, _ day2: Int) -> Int {
    let r = Double(day2 - day1) / _CalendarAstronomy.meanSynodicMonth
    return Int(r + (r >= 0 ? 0.5 : -0.5))
}

fileprivate func chineseMajorSolarTerm(_ days: Int, _ variant: ChineseCalendarVariant) -> Int {
    let lon = _CalendarAstronomy.solarLongitude(at: chineseMidnight(days, variant))
    var term = (Int(lon / 30.0) + 2) % 12
    if term < 1 { term += 12 }
    return term
}

fileprivate func chineseHasNoMajorSolarTerm(_ newMoon: Int, _ variant: ChineseCalendarVariant) -> Bool {
    chineseMajorSolarTerm(newMoon, variant) == chineseMajorSolarTerm(chineseNewMoonNear(newMoon + chineseSynodicGap, true, variant), variant)
}

fileprivate func chineseIsLeapMonthBetween(_ newMoon1: Int, _ newMoon2: Int, _ variant: ChineseCalendarVariant) -> Bool {
    var m2 = newMoon2
    while m2 >= newMoon1 {
        if chineseHasNoMajorSolarTerm(m2, variant) { return true }
        m2 = chineseNewMoonNear(m2 - chineseSynodicGap, false, variant)
    }
    return false
}

fileprivate func chineseNewYear(_ gregorianYear: Int, _ variant: ChineseCalendarVariant) -> Int {
    let solsticeBefore = chineseWinterSolstice(gregorianYear - 1, variant)
    let solsticeAfter = chineseWinterSolstice(gregorianYear, variant)
    let newMoon1 = chineseNewMoonNear(solsticeBefore + 1, true, variant)
    let newMoon2 = chineseNewMoonNear(newMoon1 + chineseSynodicGap, true, variant)
    let newMoon11 = chineseNewMoonNear(solsticeAfter + 1, false, variant)
    let value: Int
    if chineseSynodicMonthsBetween(newMoon1, newMoon11) == 12 &&
        (chineseHasNoMajorSolarTerm(newMoon1, variant) || chineseHasNoMajorSolarTerm(newMoon2, variant)) {
        value = chineseNewMoonNear(newMoon2 + chineseSynodicGap, true, variant)
    } else {
        value = newMoon2
    }
    return value
}

// (month, isLeapMonth) label for the month starting at new moon `start`.
fileprivate func chineseMonthLabel(startingAt start: Int, gregorianYear: Int, _ variant: ChineseCalendarVariant) -> (month: Int, isLeap: Bool) {
    var solsticeBefore: Int
    var solsticeAfter = chineseWinterSolstice(gregorianYear, variant)
    if start < solsticeAfter {
        solsticeBefore = chineseWinterSolstice(gregorianYear - 1, variant)
    } else {
        solsticeBefore = solsticeAfter
        solsticeAfter = chineseWinterSolstice(gregorianYear + 1, variant)
    }
    let firstMoon = chineseNewMoonNear(solsticeBefore + 1, true, variant)
    let lastMoon = chineseNewMoonNear(solsticeAfter + 1, false, variant)
    let hasLeap = chineseSynodicMonthsBetween(firstMoon, lastMoon) == 12
    var month = chineseSynodicMonthsBetween(firstMoon, start)
    if hasLeap && chineseIsLeapMonthBetween(firstMoon, start, variant) {
        month -= 1
    }
    if month < 1 { month += 12 }
    let isLeap = hasLeap && chineseHasNoMajorSolarTerm(start, variant) &&
        !chineseIsLeapMonthBetween(firstMoon, chineseNewMoonNear(start - chineseSynodicGap, false, variant), variant)
    return (month, isLeap)
}

// MARK: - Year structure

internal struct _ChineseYear: Sendable {
    let relatedISOYear: Int
    let newYearRataDie: Int
    let monthLengthBits: UInt16    // bit i set = ordinal month i+1 has 30 days
    let monthCount: UInt8          // 12 or 13
    let leapMonthNumber: UInt8         // 0 = no leap month; otherwise the leap month shows as this month number (the year has a second month with this number)

    // Ordinal position (1-based) of the leap month, if any.
    var leapOrdinal: Int? { leapMonthNumber == 0 ? nil : Int(leapMonthNumber) + 1 }

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

    // The displayed month number and leap flag for the given ordinal (1-based) position in the year. In a leap year the leap month shares the previous month's number and is returned with isLeap set to true.
    func monthLabel(ordinal: Int) -> (month: Int, isLeap: Bool) {
        guard let lo = leapOrdinal else { return (ordinal, false) }
        if ordinal == lo { return (Int(leapMonthNumber), true) }
        if ordinal > lo { return (ordinal - 1, false) }
        return (ordinal, false)
    }

    func ordinal(month: Int, isLeap: Bool) -> Int? {
        guard month >= 1 && month <= 12 else { return nil }
        guard let lo = leapOrdinal else { return isLeap ? nil : month }
        if isLeap {
            return month == Int(leapMonthNumber) ? lo : nil
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


// MARK: - _CalendarChinese

/// Swift implementation of the Chinese lunisolar calendar.
///
/// Field conventions match ICU: era = 60-year cycle number since the 2637 BCE epoch, year = 1...60 within the cycle, month = 1...12 with `isLeapMonth` distinguishing the repeated month.
/// The extended year is the related Gregorian year + 2637.
/// `.yearForWeekOfYear` reports the extended year for Chinese and Vietnamese, and 304 less for Dangi.
// @unchecked Sendable: mutable state is confined to copy-on-write via copy(), matching the other Swift calendar classes.
internal final class _CalendarChinese: _CalendarProtocol, @unchecked Sendable {

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        guard let variant = ChineseCalendarVariant(identifier: identifier) else {
            preconditionFailure("_CalendarChinese does not handle this identifier")
        }
        self.variant = variant
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
    let variant: ChineseCalendarVariant
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

    // No fast paths in phase 1, leap months complicate the matching patterns.
    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool { false }

    // MARK: Extended year model

    // extended year = related Gregorian year + 2637; era = 60-year cycle.
    static let extendedYearOffset = 2637

    // Supported extended-year domain (same convention as Hebrew's icuYearLowerBound/icuYearUpperBound).
    private static let extendedYearLowerBound = -5_000_000
    private static let extendedYearUpperBound = 5_000_000

    private func yearData(extendedYear: Int) -> _ChineseYear {
        Self.year(relatedISOYear: extendedYear - Self.extendedYearOffset, variant)
    }

    private func rataDie(extendedYear: Int, ordinal: Int, day: Int) -> Int {
        yearData(extendedYear: extendedYear).monthStartRataDie(ordinal: ordinal) + day - 1
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
        case .era: return Range(1...83333)          // ICU chnsecal LIMITS
        case .year: return Range(1...60)
        case .month: return Range(1...12)
        case .day: return Range(1...29)
        case .hour: return Range(0...23)
        case .minute: return Range(0...59)
        case .second: return Range(0...59)
        case .weekday: return Range(1...7)
        case .weekdayOrdinal: return Range(-1...5)
        case .quarter: return Range(1...4)
        case .weekOfMonth: return 1..<(29 + 7 - minimumDaysInFirstWeek) / 7 + 1
        case .weekOfYear: return Range(1...50)
        case .yearForWeekOfYear: return Range(Self.extendedYearLowerBound...Self.extendedYearUpperBound)
        case .nanosecond: return Range(0...999_999_999)
        case .isLeapMonth: return Range(0...1)
        case .isRepeatedDay: return Range(0...0)
        case .dayOfYear: return Range(1...353)
        case .calendar, .timeZone:
            return nil
        }
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return Range(1...83333)
        case .year: return Range(1...60)
        case .month: return Range(1...12)
        case .day: return Range(1...30)
        case .hour: return Range(0...23)
        case .minute: return Range(0...59)
        case .second: return Range(0...59)
        case .weekday: return Range(1...7)
        case .weekdayOrdinal: return Range(-1...5)
        case .quarter: return Range(1...4)
        case .weekOfMonth: return (minimumDaysInFirstWeek == 1 ? 1 : 0)..<(30 + 13 - minimumDaysInFirstWeek) / 7 + 1
        case .weekOfYear: return Range(1...55)
        case .yearForWeekOfYear: return Range(Self.extendedYearLowerBound...Self.extendedYearUpperBound)
        case .nanosecond: return Range(0...999_999_999)
        case .isLeapMonth: return Range(0...1)
        case .isRepeatedDay: return Range(0...0)
        case .dayOfYear: return Range(1...385)
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
            return larger == .nanosecond ? nil : maximumRange(of: smaller)
        default:
            break
        }
        switch (smaller, larger) {
        case (.month, .year):
            // Number of display months is always 12 (the leap repeats a number).
            return Range(1...12)
        case (.month, .quarter):
            // ICU reports display month numbers spanned by the quarter; the span can shrink (see quarterSpan).
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            guard let span = quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            return Range(span.firstDisplay...span.lastDisplay)
        case (.dayOfYear, .year):
            let (extendedYear, _, _) = fields(for: date, in: timeZone)
            let year = yearData(extendedYear: extendedYear)
            return 1..<year.endRataDie - year.newYearRataDie + 1
        case (.weekOfYear, .month):
            // The week numbers of the year at the first and the last moment of the month.
            guard let interval = dateInterval(of: .month, for: date),
                  let first = ordinality(of: .weekOfYear, in: .year, for: interval.start + 0.1),
                  let last = ordinality(of: .weekOfYear, in: .year, for: interval.end - 0.1) else { return nil }
            return first..<last + 1
        case (.day, .weekOfMonth):
            // Which days of the month this week covers, as day-of-month values. A week can start before or end after the month, so clip both ends.
            guard let week = dateInterval(of: .weekOfMonth, for: date) else { return nil }
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            let monthLength = yearData(extendedYear: extendedYear).monthLength(ordinal: ordinal)
            let monthStart = rataDie(extendedYear: extendedYear, ordinal: ordinal, day: 1)
            let localSeconds = week.start.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: week.start))
            let (weekStart, _): (Int, Double) = _CalendarUtility.rataDieAndSecondsInDay(localSeconds: localSeconds)
            let firstDay = max(1, weekStart - monthStart + 1)
            let lastDay = min(monthLength, weekStart - monthStart + 7)
            return firstDay..<lastDay + 1
        case (.day, .quarter):
            // ICU counts calendar days here, not 86400 s chunks, the generic interval+ordinality fallback overcounts by one in DST fall-back quarters.
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            guard let span = quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            let startRataDie = rataDie(extendedYear: extendedYear, ordinal: span.startOrdinal, day: 1)
            let endRataDie = rataDie(extendedYear: span.endExtendedYear, ordinal: span.endOrdinal, day: 1)
            return Range(1...(endRataDie - startRataDie))
        case (.year, .era), (.month, .era), (.day, .era):
            return maximumRange(of: smaller)
        case (.weekOfMonth, .year), (.weekdayOrdinal, .year):
            return _CalendarUtility.rangeOverMonths(of: smaller, in: larger, for: date, in: self)
        default:
            break
        }
        guard let interval = dateInterval(of: larger, for: date) else { return nil }
        guard let ord1 = ordinality(of: smaller, in: larger, for: interval.start + 0.1) else { return nil }
        guard let ord2 = ordinality(of: smaller, in: larger, for: interval.start + interval.duration - 0.1) else { return nil }
        if ord2 < ord1 { return ord1..<ord1 }
        return Range(ord1...ord2)
    }

    // MARK: Ordinality

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        let timeZone = self.timeZone
        switch (smaller, larger) {
        case (.day, .year), (.dayOfYear, .year):
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
            return _CalendarUtility.weekNumber(desiredDay: dayOfYear, dayOfPeriod: dayOfYear, weekday: weekday, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
        case (.weekOfMonth, .month):
            return dateComponents([.weekOfMonth], from: date, in: timeZone).weekOfMonth
        case (.weekday, .year), (.weekdayOrdinal, .year):
            guard let dayOfYear = dateComponents([.dayOfYear], from: date, in: timeZone).dayOfYear else { return nil }
            return (dayOfYear - 1) / 7 + 1
        case (.weekday, .month), (.weekdayOrdinal, .month):
            guard let day = dateComponents([.day], from: date, in: timeZone).day else { return nil }
            return (day - 1) / 7 + 1
        case (.weekday, .weekOfYear), (.day, .weekOfYear), (.day, .weekOfMonth), (.weekday, .weekOfMonth):
            // Position of the day inside its week, counting from firstWeekday.
            guard let weekday = dateComponents([.weekday], from: date, in: timeZone).weekday else { return nil }
            return ((weekday - firstWeekday + 7) % 7) + 1
        case (.hour, _), (.minute, _), (.second, _), (.nanosecond, _):
            let (_, _, _, secondsInDay) = fieldsAndTime(for: date, in: timeZone)
            return _CalendarUtility.timeOrdinality(of: smaller, in: larger, secondsInDay: secondsInDay, date: date) { ordinality(of: .day, in: $0, for: date) }
        case (.year, .era):
            let (extendedYear, _, _) = fields(for: date, in: timeZone)
            return Self.eraAndYear(extendedYear: extendedYear).year
        case (.month, .era):
            // The months of the earlier years of the era, leap months included, then the month of the date.
            let (extendedYear, ordinal, _) = fields(for: date, in: timeZone)
            let firstYearOfEra = extendedYear - Self.eraAndYear(extendedYear: extendedYear).year + 1
            return (firstYearOfEra..<extendedYear).reduce(ordinal) { $0 + Int(yearData(extendedYear: $1).monthCount) }
        case (.day, .era):
            let (extendedYear, ordinal, day) = fields(for: date, in: timeZone)
            let firstYearOfEra = extendedYear - Self.eraAndYear(extendedYear: extendedYear).year + 1
            return rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day) - yearData(extendedYear: firstYearOfEra).newYearRataDie + 1
        case (.weekOfYear, .yearForWeekOfYear):
            return dateComponents([.weekOfYear], from: date, in: timeZone).weekOfYear
        case (.day, .yearForWeekOfYear):
            guard let weekYear = dateComponents([.yearForWeekOfYear], from: date, in: timeZone).yearForWeekOfYear else { return nil }
            let (extendedYear, ordinal, day) = fields(for: date, in: timeZone)
            return rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day) - firstDayOfWeekYear(yearNumber(ofWeekYear: weekYear)) + 1
        default:
            return nil
        }
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
        let y = Self.year(containingRataDie: rataDie, variant)
        guard let (ordinal, day) = y.ordinalAndDay(rataDie: rataDie) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(rataDie)")
        }
        return (y.relatedISOYear + Self.extendedYearOffset, ordinal, day, secondsInDay)
    }

    // MARK: Date intervals

    // Like ICU, a leap month is not absorbed into its quarter: dates in it can fall outside their own quarter interval and the month range shrinks.
    private func quarterSpan(extendedYear: Int, ordinal: Int) -> (firstDisplay: Int, startOrdinal: Int, lastDisplay: Int, endExtendedYear: Int, endOrdinal: Int)? {
        let y = yearData(extendedYear: extendedYear)
        let q = (y.monthLabel(ordinal: ordinal).month + 2) / 3
        let firstDisplay = 3 * (q - 1) + 1
        guard let startOrdinal = y.ordinal(month: firstDisplay, isLeap: false) else { return nil }
        var (ey, eo) = (extendedYear, startOrdinal)
        for _ in 0..<2 { (ey, eo) = nextOrdinalMonth(extendedYear: ey, ordinal: eo) }
        let lastDisplay = yearData(extendedYear: ey).monthLabel(ordinal: eo).month
        let (endExtendedYear, endOrdinal) = nextOrdinalMonth(extendedYear: ey, ordinal: eo)
        return (firstDisplay, startOrdinal, lastDisplay, endExtendedYear, endOrdinal)
    }

    private func nextOrdinalMonth(extendedYear: Int, ordinal: Int) -> (Int, Int) {
        let y = yearData(extendedYear: extendedYear)
        if ordinal < Int(y.monthCount) { return (extendedYear, ordinal + 1) }
        return (extendedYear + 1, 1)
    }

    private func prevOrdinalMonth(extendedYear: Int, ordinal: Int) -> (Int, Int) {
        if ordinal > 1 { return (extendedYear, ordinal - 1) }
        let py = yearData(extendedYear: extendedYear - 1)
        return (extendedYear - 1, Int(py.monthCount))
    }

    // Converts between the extended year and the `.yearForWeekOfYear` number. Chinese and Vietnamese use the same offset.
    private func weekYearNumber(ofYearNumber extendedYear: Int) -> Int {
        extendedYear - Self.extendedYearOffset + variant.weekYearOffset
    }

    private func yearNumber(ofWeekYear weekYear: Int) -> Int {
        weekYear - variant.weekYearOffset + Self.extendedYearOffset
    }

    // Whether a `.yearForWeekOfYear` number is inside the limits of the extended year.
    private func isSupported(weekYear: Int) -> Bool {
        weekYear > weekYearNumber(ofYearNumber: Self.extendedYearLowerBound) && weekYear < weekYearNumber(ofYearNumber: Self.extendedYearUpperBound)
    }

    private func firstDayOfWeekYear(_ extendedYear: Int) -> Int {
        let rdNY = yearData(extendedYear: extendedYear).newYearRataDie
        let nyWeekday = _CalendarUtility.weekday(ofRataDie: rdNY)
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
        _CalendarUtility.utcDate(fromRataDie: rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day), secondsInDay: 0, in: timeZone,
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
            // The year that owns a week, which can differ from the calendar year at either end of a year. ICU returns nil here for the Chinese calendar; we deliberately return a real interval, as the Gregorian and Hebrew calendars do.
            let weekYearComps = dateComponents([.yearForWeekOfYear], from: date, in: timeZone)
            guard let reportedWeekYear = weekYearComps.yearForWeekOfYear else { return nil }
            let weekYear = yearNumber(ofWeekYear: reportedWeekYear)
            let rdStart = firstDayOfWeekYear(weekYear)
            let rdEnd = firstDayOfWeekYear(weekYear + 1)
            let start = _CalendarUtility.utcDate(fromRataDie: rdStart, secondsInDay: 0, in: timeZone,
                                repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let end = _CalendarUtility.utcDate(fromRataDie: rdEnd, secondsInDay: 0, in: timeZone,
                              repeatedTimePolicy: .former, skippedTimePolicy: .former)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .month:
            let start = localMidnight(extendedYear: extendedYear, ordinal: ordinal, day: 1, in: timeZone)
            let (nextYear, nextMonth) = nextOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
            let end = localMidnight(extendedYear: nextYear, ordinal: nextMonth, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .weekOfYear, .weekOfMonth:
            let rdHere = rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day)
            let weekday = _CalendarUtility.weekday(ofRataDie: rdHere)
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
            guard let span = quarterSpan(extendedYear: extendedYear, ordinal: ordinal) else { return nil }
            let start = localMidnight(extendedYear: extendedYear, ordinal: span.startOrdinal, day: 1, in: timeZone)
            let end = localMidnight(extendedYear: span.endExtendedYear, ordinal: span.endOrdinal, day: 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .day, .weekday, .weekdayOrdinal, .dayOfYear:
            let rdHere = rataDie(extendedYear: extendedYear, ordinal: ordinal, day: day)
            let start = _CalendarUtility.utcDate(fromRataDie: rdHere, secondsInDay: 0, in: timeZone,
                                repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let end = _CalendarUtility.utcDate(fromRataDie: rdHere + 1, secondsInDay: 0, in: timeZone,
                              repeatedTimePolicy: .former, skippedTimePolicy: .former)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .hour, .minute, .second, .nanosecond:
            return _CalendarUtility.timeUnitInterval(of: component, for: date, in: timeZone)
        case .isLeapMonth, .isRepeatedDay, .calendar, .timeZone:
            return nil
        }
    }

    // MARK: Date ↔ DateComponents

    func date(from components: DateComponents) -> Date? {
        var secondsInDay: Double = 0
        if let hour = components.hour { secondsInDay += Double(hour) * 3600 }
        if let minute = components.minute { secondsInDay += Double(minute) * 60 }
        if let second = components.second { secondsInDay += Double(second) }
        if let nanosecond = components.nanosecond { secondsInDay += Double(nanosecond) / 1e9 }

        let timeZone = components.timeZone ?? timeZone

        // `.yearForWeekOfYear`, `.weekOfYear` and `.weekday` name a date too, with no `.era`. A week past the end of the year runs on into the next, as in the Gregorian calendar.
        if components.year == nil, let weekYear = components.yearForWeekOfYear {
            guard isSupported(weekYear: weekYear) else { return nil }
            let weekOfYear = components.weekOfYear ?? 1
            let weekday = components.weekday ?? firstWeekday
            let dayWithinWeek = ((weekday % 7 - firstWeekday) % 7 + 7) % 7
            let (weeksAfterFirst, subtractOverflow) = weekOfYear.subtractingReportingOverflow(1)
            let (daysAfterFirst, multiplyOverflow) = weeksAfterFirst.multipliedReportingOverflow(by: 7)
            let (rataDie, addOverflow) = (firstDayOfWeekYear(yearNumber(ofWeekYear: weekYear)) + dayWithinWeek).addingReportingOverflow(daysAfterFirst)
            guard !subtractOverflow, !multiplyOverflow, !addOverflow else { return nil }
            return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        // Missing era defaults to the CURRENT date's era (ICU fields default from now).
        let era: Int
        if let e = components.era {
            era = e
        } else {
            let (nowExtendedYear, _, _) = fields(for: Date.now, in: timeZone)
            era = Self.eraAndYear(extendedYear: nowExtendedYear).era
        }
        let yearValue = components.year ?? 1
        guard let inputExtendedYear = Self.extendedYear(era: era, year: yearValue),
              inputExtendedYear > Self.extendedYearLowerBound && inputExtendedYear < Self.extendedYearUpperBound else { return nil }

        let monthValue = components.month ?? 1
        let day = components.day ?? 1
        let fieldLimit: UInt = 100_000_000
        guard monthValue.magnitude <= fieldLimit, day.magnitude <= fieldLimit else { return nil }
        // A weekday or an ordinal alone does not name a day, so the day of the month decides.
        let weekdayOffset = components.weekday.map { (($0 % 7 - firstWeekday) % 7 + 7) % 7 } ?? 0

        // A month outside 1...12 moves into another year, and leap months do not count. A day outside the month counts on from the start of the month.
        func monthFields() -> (start: Int, length: Int, startOffset: Int)? {
            let yearsFromMonth = _CalendarUtility.floorDiv(monthValue - 1, 12)
            let month = monthValue - 1 - yearsFromMonth * 12 + 1
            let extendedYear = inputExtendedYear + yearsFromMonth
            guard extendedYear > Self.extendedYearLowerBound && extendedYear < Self.extendedYearUpperBound else { return nil }
            let yearOfMonth = yearData(extendedYear: extendedYear)
            // A leap month that doesn't exist in this year falls back to the regular month.
            let isLeap = components.isLeapMonth ?? false
            let ordinal: Int
            if let found = yearOfMonth.ordinal(month: month, isLeap: isLeap) {
                ordinal = found
            } else if isLeap, let found = yearOfMonth.ordinal(month: month, isLeap: false) {
                ordinal = found
            } else {
                return nil
            }
            let start = yearOfMonth.monthStartRataDie(ordinal: ordinal)
            return (start, yearOfMonth.monthLength(ordinal: ordinal), (_CalendarUtility.weekday(ofRataDie: start) - firstWeekday + 7) % 7)
        }

        // The forms by week of the year and by day of the year ignore the month.
        let rataDie: Int
        if components.day == nil, let ordinalValue = components.weekdayOrdinal, components.weekday != nil {
            guard ordinalValue.magnitude <= fieldLimit, let month = monthFields() else { return nil }
            rataDie = month.start + _CalendarUtility.dayOfMonth(weekdayOrdinal: ordinalValue, weekdayOffset: weekdayOffset, monthStartOffset: month.startOffset, monthLength: month.length) - 1
        } else if components.day == nil, let week = components.weekOfYear, components.weekday != nil {
            guard week.magnitude <= fieldLimit else { return nil }
            rataDie = firstDayOfWeekYear(inputExtendedYear) + weekdayOffset + (week - 1) * 7
        } else if components.day == nil, let week = components.weekOfMonth, components.weekday != nil || components.dayOfYear == nil {
            guard week.magnitude <= fieldLimit, let month = monthFields() else { return nil }
            rataDie = month.start + _CalendarUtility.dayOfMonth(weekOfMonth: week, weekdayOffset: weekdayOffset, monthStartOffset: month.startOffset, minimumDaysInFirstWeek: minimumDaysInFirstWeek) - 1
        } else if components.day == nil, let dayOfYear = components.dayOfYear {
            guard dayOfYear.magnitude <= fieldLimit else { return nil }
            rataDie = yearData(extendedYear: inputExtendedYear).newYearRataDie + dayOfYear - 1
        } else {
            guard let month = monthFields() else { return nil }
            rataDie = month.start + day - 1
        }

        return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        let totalOffset = timeZone.secondsFromGMT(for: date)
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(totalOffset)
        let (rataDie, secondsInDay): (Int, Double) = _CalendarUtility.rataDieAndSecondsInDay(localSeconds: localSeconds)

        let y = Self.year(containingRataDie: rataDie, variant)
        guard let (ordinal, day) = y.ordinalAndDay(rataDie: rataDie) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(rataDie)")
        }
        let label = y.monthLabel(ordinal: ordinal)
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
            result.weekday = _CalendarUtility.weekday(ofRataDie: rataDie)
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
            let weekday = _CalendarUtility.weekday(ofRataDie: rataDie)
            let dayOfYear = rataDie - y.newYearRataDie + 1
            let yearLength = y.daysInYear
            let relativeWeekday = (weekday + 7 - firstWeekday) % 7

            var weekOfYear = _CalendarUtility.weekNumber(desiredDay: dayOfYear, dayOfPeriod: dayOfYear, weekday: weekday, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
            var yearForWeekOfYear = extendedYear
            if weekOfYear == 0 {
                let previousYearLength = yearData(extendedYear: extendedYear - 1).daysInYear
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
            if components.contains(.yearForWeekOfYear) { result.yearForWeekOfYear = weekYearNumber(ofYearNumber: yearForWeekOfYear) }
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
    private func resolvedMonthStart(extendedYear: Int, display: Int, leap: Bool) -> Int {
        let ny = yearData(extendedYear: extendedYear).newYearRataDie
        let target = ny + (display - 1) * 29
        var y = Self.year(containingRataDie: target, variant)
        guard let od = y.ordinalAndDay(rataDie: target) else {
            fatalError("year(containingRataDie:) returned a year not containing rataDie \(target)")
        }
        var ordinal = od.ordinal
        var est = y.monthStartRataDie(ordinal: ordinal)
        if est < target {   // target mid-month: next month start
            (est, y, ordinal) = nextMonthStart(after: y, ordinal: ordinal)
        }
        let lbl = y.monthLabel(ordinal: ordinal)
        if lbl.month != display || lbl.isLeap != leap {
            (est, y, ordinal) = nextMonthStart(after: y, ordinal: ordinal)
        }
        return est
    }

    // Returns the start of the month after (`y`, `ordinal`): its rata die, the year it falls in, and its ordinal within that year (rolling into the next year when past the last month).
    private func nextMonthStart(after y: _ChineseYear, ordinal: Int) -> (rataDie: Int, year: _ChineseYear, ordinal: Int) {
        if ordinal < Int(y.monthCount) {
            return (y.monthStartRataDie(ordinal: ordinal + 1), y, ordinal + 1)
        }
        let ny = Self.year(relatedISOYear: y.relatedISOYear + 1, variant)
        return (ny.newYearRataDie, ny, 1)
    }

    // MARK: Adding

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        var result = date

        // How many fields carry a non-zero value.
        func nonZeroFieldCount(_ c: DateComponents) -> Int {
            var count = 0
            if (c.era ?? 0) != 0 { count += 1 }
            if (c.year ?? 0) != 0 { count += 1 }
            if (c.month ?? 0) != 0 { count += 1 }
            if (c.day ?? 0) != 0 { count += 1 }
            if (c.hour ?? 0) != 0 { count += 1 }
            if (c.minute ?? 0) != 0 { count += 1 }
            if (c.second ?? 0) != 0 { count += 1 }
            if (c.nanosecond ?? 0) != 0 { count += 1 }
            if (c.weekday ?? 0) != 0 { count += 1 }
            if (c.weekdayOrdinal ?? 0) != 0 { count += 1 }
            if (c.weekOfMonth ?? 0) != 0 { count += 1 }
            if (c.weekOfYear ?? 0) != 0 { count += 1 }
            if (c.yearForWeekOfYear ?? 0) != 0 { count += 1 }
            if (c.dayOfYear ?? 0) != 0 { count += 1 }
            return count
        }

        // Wrapping changes one field only, so these shortcuts need exactly one field set.
        if wrappingComponents, nonZeroFieldCount(components) == 1 {
            let timeZone = self.timeZone
            if let dayAmount = components.day, dayAmount != 0 {
                let (extendedYear, ordinal, currentDay, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
                let year = yearData(extendedYear: extendedYear)
                let monthLength = year.monthLength(ordinal: ordinal)
                let newDay = _CalendarUtility.wrapped(currentDay - 1, by: dayAmount, count: monthLength) + 1
                let rataDie = year.monthStartRataDie(ordinal: ordinal) + newDay - 1
                return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: dayAmount > 0 ? .former : .latter, skippedTimePolicy: .former)
            }
            // The year wraps inside the 60 year cycle, so the roll is an add of the difference in the cycle.
            if let yearAmount = components.year, yearAmount != 0 {
                guard let year = dateComponents([.year], from: result, in: timeZone).year else { return nil }
                let difference = _CalendarUtility.wrapped(year - 1, by: yearAmount, count: 60) + 1 - year
                return difference == 0 ? result : self.date(byAdding: DateComponents(year: difference), to: result, wrappingComponents: false)
            }
            if let amount = [components.hour, components.minute, components.second].compactMap({ $0 }).first(where: { $0 != 0 }) {
                let field: Calendar.Component = (components.hour ?? 0) != 0 ? .hour : (components.minute ?? 0) != 0 ? .minute : .second
                return _CalendarUtility.rolledTimeUnit(field, by: amount, from: result, in: timeZone)
            }
            // The weekday, the weekday ordinal, the day of the year and the weeks wrap inside the month or the year.
            if (components.weekday ?? 0) != 0 || (components.weekdayOrdinal ?? 0) != 0 || (components.dayOfYear ?? 0) != 0 || (components.weekOfMonth ?? 0) != 0 || (components.weekOfYear ?? 0) != 0 {
                let (extendedYear, ordinal, currentDay, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
                let year = yearData(extendedYear: extendedYear)
                let monthLength = year.monthLength(ordinal: ordinal)
                let monthStart = year.monthStartRataDie(ordinal: ordinal)
                let rataDie = monthStart + currentDay - 1
                let weekdayOffset = (_CalendarUtility.weekday(ofRataDie: rataDie) - firstWeekday + 7) % 7
                let yearLength = year.endRataDie - year.newYearRataDie
                let dayOfYear = rataDie - year.newYearRataDie + 1
                func elapsed(days: Int, forward: Bool) -> Date { _CalendarUtility.moved(result, byElapsedDays: days, forward: forward, in: timeZone) }
                for field in [Calendar.Component.weekday, .weekdayOrdinal, .dayOfYear] {
                    guard let amount = components.value(for: field), amount != 0,
                          let days = _CalendarUtility.daysToRoll(field, by: amount, weekdayOffset: weekdayOffset, dayOfMonth: currentDay, monthLength: monthLength, dayOfYear: dayOfYear, yearLength: yearLength) else { continue }
                    return elapsed(days: days, forward: amount > 0)
                }
                if let amount = components.weekOfMonth, amount != 0 {
                    guard let newDay = _CalendarUtility.rolledWeekPosition(currentDay, length: monthLength, weekdayOffset: weekdayOffset, by: amount, minimumDaysInFirstWeek: minimumDaysInFirstWeek) else { return nil }
                    return _CalendarUtility.utcDate(fromRataDie: monthStart + newDay - 1, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: amount > 0 ? .former : .latter, skippedTimePolicy: .former)
                }
                if let amount = components.weekOfYear, amount != 0 {
                    guard let newDayOfYear = _CalendarUtility.rolledWeekPosition(dayOfYear, length: yearLength, weekdayOffset: weekdayOffset, by: amount, minimumDaysInFirstWeek: minimumDaysInFirstWeek) else { return nil }
                    return _CalendarUtility.utcDate(fromRataDie: year.newYearRataDie + newDayOfYear - 1, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: amount > 0 ? .former : .latter, skippedTimePolicy: .former)
                }
            }
            // Wraps over this year's month count, 13 in a leap year, so the year never changes. Adding without wrapping can cross into the next year.
            if let monthAmount = components.month, monthAmount != 0 {
                let (extendedYear, ordinal, currentDay, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
                let year = yearData(extendedYear: extendedYear)
                let monthCount = Int(year.monthCount)
                let newOrdinal = _CalendarUtility.wrapped(ordinal - 1, by: monthAmount, count: monthCount) + 1
                // A shorter target month clamps the day, as adding without wrapping does.
                let clampedDay = min(currentDay, year.monthLength(ordinal: newOrdinal))
                let rataDie = year.monthStartRataDie(ordinal: newOrdinal) + clampedDay - 1
                return _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: monthAmount > 0 ? .former : .latter, skippedTimePolicy: .former)
            }
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
            let y = yearData(extendedYear: extendedYear)
            let label = y.monthLabel(ordinal: ordinal)
            let (newExt, ovf) = extendedYear.addingReportingOverflow(yearsToAdd)
            guard !ovf, newExt > Self.extendedYearLowerBound, newExt < Self.extendedYearUpperBound else { return nil }
            // ICU's add-year pin: resolve the month by single-bump, pin the day via a second resolution that keeps the source leap flag, then spill leniently (Calendar::add + getActualMaximum semantics).
            let start0 = resolvedMonthStart(extendedYear: newExt, display: label.month, leap: label.isLeap)
            let y1 = Self.year(containingRataDie: start0, variant)
            guard let od1 = y1.ordinalAndDay(rataDie: start0) else {
                fatalError("year(containingRataDie:) returned a year not containing rataDie \(start0)")
            }
            let ord1 = od1.ordinal
            let display1 = y1.monthLabel(ordinal: ord1).month
            let start2 = resolvedMonthStart(extendedYear: newExt, display: display1, leap: label.isLeap)
            let y2 = Self.year(containingRataDie: start2, variant)
            guard let od2 = y2.ordinalAndDay(rataDie: start2) else {
                fatalError("year(containingRataDie:) returned a year not containing rataDie \(start2)")
            }
            let ord2 = od2.ordinal
            let maxDom = y2.monthLength(ordinal: ord2)
            let pinnedDay = min(d, maxDom)
            let rataDie = start0 + pinnedDay - 1
            result = _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                             repeatedTimePolicy: yearsToAdd > 0 ? .former : .latter, skippedTimePolicy: .former)
        }

        if monthsToAdd != 0 {
            let timeZone = self.timeZone
            var (extendedYear, ordinal, d, secondsInDay) = fieldsAndTime(for: result, in: timeZone)
            // Reject adds that provably exit the extendedYear domain before the ordinal walk: a year has at most 13 months, so the target lies at or beyond extendedYear + monthsToAdd/13.
            let (reach, reachOvf) = extendedYear.addingReportingOverflow(monthsToAdd / 13)
            guard !reachOvf, reach > Self.extendedYearLowerBound, reach < Self.extendedYearUpperBound else { return nil }
            var remaining = monthsToAdd
            while remaining > 0 {
                (extendedYear, ordinal) = nextOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
                remaining -= 1
            }
            while remaining < 0 {
                (extendedYear, ordinal) = prevOrdinalMonth(extendedYear: extendedYear, ordinal: ordinal)
                remaining += 1
            }
            guard extendedYear > Self.extendedYearLowerBound && extendedYear < Self.extendedYearUpperBound else { return nil }
            let targetYear = yearData(extendedYear: extendedYear)
            let clampedDay = min(d, targetYear.monthLength(ordinal: ordinal))
            let rataDie = targetYear.monthStartRataDie(ordinal: ordinal) + clampedDay - 1
            result = _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone,
                             repeatedTimePolicy: monthsToAdd > 0 ? .former : .latter, skippedTimePolicy: .former)
        }

        guard var daysToAdd = _CalendarUtility.dayCount(of: components) else { return nil }

        // Moves by whole week-years. ICU ignores this add for the Chinese calendar; see the note on `dateInterval(of: .yearForWeekOfYear)`.
        if let n = components.yearForWeekOfYear, n != 0 {
            let timeZone = self.timeZone
            let localComps = dateComponents([.yearForWeekOfYear], from: result, in: timeZone)
            if let yy = localComps.yearForWeekOfYear {
                let (target, overflow) = yy.addingReportingOverflow(n)
                guard !overflow, isSupported(weekYear: target) else { return nil }
                // Summed per-year week counts telescope to the distance between the two week-year anchors (both firstWeekday-aligned), so the add is O(1).
                let (sum, sumOverflow) = daysToAdd.addingReportingOverflow(firstDayOfWeekYear(yearNumber(ofWeekYear: target)) - firstDayOfWeekYear(yearNumber(ofWeekYear: yy)))
                guard !sumOverflow else { return nil }
                daysToAdd = sum
            }
        }

        if daysToAdd != 0 {
            guard let moved = _CalendarUtility.date(byAddingDays: daysToAdd, to: result, in: timeZone) else { return nil }
            result = moved
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
        for component in _CalendarUtility.orderedDifferenceComponents(components) {
            let (diff, newCurr) = difference(inComponent: component, from: curr, to: end)
            result.setValue(diff, for: component)
            curr = newCurr
        }
        return result
    }

    private func difference(inComponent component: Calendar.Component, from start: Date, to end: Date) -> (Int, Date) {
        if start == end { return (0, start) }
        if let result = _CalendarUtility.timeUnitDifference(in: component, from: start, to: end) { return result }

        return _CalendarUtility.differenceBySearch(from: start, to: end) { count in
            var components = DateComponents()
            components.setValue(count, for: component)
            return date(byAdding: components, to: start, wrappingComponents: false)
        }
    }
}

// MARK: - Baked table

// The baked month-structure table and the year lookups that read it. Years 1901 through 2100 come straight from the table; outside that range the structure is computed from the astronomy rules above.
extension _CalendarChinese {
    // One entry per Chinese year, indexed by the Gregorian year in which that Chinese year begins.
    // Each entry packs one Chinese year into a UInt32:
    //   bits 0-12: month lengths, one bit per month starting at month 1, where 1 means a 30-day month and 0 means a 29-day month.
    //   bits 13-16: the leap month number, 0 for no leap month; otherwise the leap month shares this number (N means the leap month follows month N).
    //   bits 17-22: the New Year offset, the number of days from January 19 of this Gregorian year to Chinese New Year.
    // Worked example: 0x003E0752. Bits 0-12 = 0b0_0111_0101_0010, so months 2, 5, 7, 9, 10, and 11 have 30 days and the rest have 29. Bits 13-16 = 0, so there is no leap month. Bits 17-22 = 31, so New Year is January 19 plus 31 days.
    static let firstTableYear = 1901
    private static let chineseTable: InlineArray<200, UInt32> = [
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

    // The same layout for the Dangi calendar, whose day boundary is UTC+9 from 1912.
    private static let dangiTable: InlineArray<200, UInt32> = [
    0x003E0752, 0x00280EA5, 0x0014B64A, 0x0038064B, // 1901-1904
    0x00200A9B, 0x000C9556, 0x0032056A, 0x001C0B59, // 1905-1908
    0x00065752, 0x002C0752, 0x0016DB25, 0x003C0B25, // 1909-1912
    0x00240A4B, 0x000EB29B, 0x00340AAD, 0x0020056A, // 1913-1916
    0x00084B69, 0x002E0BA9, 0x001AFB52, 0x00400D92, // 1917-1920
    0x00280D25, 0x0012BA4D, 0x00380956, 0x002202B5, // 1921-1924
    0x000A95AD, 0x003206D4, 0x001C0DA9, 0x00085D92, // 1925-1928
    0x002C0E92, 0x0016CD26, 0x003A0527, 0x00240A57, // 1929-1932
    0x000EB2B6, 0x00340ADA, 0x002006D4, 0x000A6EA9, // 1933-1936
    0x002E0749, 0x0018F693, 0x003E0A93, 0x0028052B, // 1937-1940
    0x0010CA5B, 0x0036096D, 0x00220B6A, 0x000E9B54, // 1941-1944
    0x00320BA4, 0x001C0B49, 0x00065A93, 0x002C0A95, // 1945-1948
    0x0014F52B, 0x003A052D, 0x00240AAD, 0x0010B56A, // 1949-1952
    0x00340DB2, 0x00200DA4, 0x000A7D49, 0x00300D4A, // 1953-1956
    0x00191A95, 0x003E0A96, 0x00280556, 0x0012CAB5, // 1957-1960
    0x00360AD5, 0x002206D2, 0x000C8EA5, 0x00320EA5, // 1961-1964
    0x001C0E4A, 0x00066C96, 0x002A0A9B, 0x0016F556, // 1965-1968
    0x003A056A, 0x00240B59, 0x0010B752, 0x00360752, // 1969-1972
    0x001E0725, 0x0008964B, 0x002E0A4B, 0x001912AB, // 1973-1976
    0x003C02AD, 0x0026056B, 0x0012CB69, 0x00380DA9, // 1977-1980
    0x00220D92, 0x000C9B25, 0x00320D25, 0x001D5A4D, // 1981-1984
    0x00400A56, 0x002A02B6, 0x0014D5AD, 0x003C06D4, // 1985-1988
    0x00240DA9, 0x0010BD92, 0x00360E92, 0x00200D26, // 1989-1992
    0x00086A56, 0x002C0A57, 0x001912B6, 0x003E0B5A, // 1993-1996
    0x002806D4, 0x0012AEC9, 0x00380749, 0x00220693, // 1997-2000
    0x000A9527, 0x0030052B, 0x001A0A5B, 0x0006555A, // 2001-2004
    0x002A036A, 0x0014FB55, 0x003C0BA4, 0x00260B49, // 2005-2008
    0x000EBA93, 0x00340A95, 0x001E052D, 0x00086A5D, // 2009-2012
    0x002C0AAD, 0x001935AA, 0x003E05D2, 0x00280DA5, // 2013-2016
    0x0012BD4A, 0x00380D4A, 0x00220A95, 0x000C952D, // 2017-2020
    0x00300556, 0x001A0AB5, 0x000655AA, 0x002C06D2, // 2021-2024
    0x0014CEA5, 0x003A0EA5, 0x00260E4A, 0x0010AC96, // 2025-2028
    0x00320C9B, 0x001E055A, 0x00086AD5, 0x002E0B69, // 2029-2032
    0x00197752, 0x003E0752, 0x00280B25, 0x0012D64B, // 2033-2036
    0x00360A4B, 0x002004AB, 0x000AA55B, 0x0030056D, // 2037-2040
    0x001A0B69, 0x00065B52, 0x002C0D92, 0x0016FD25, // 2041-2044
    0x003A0D25, 0x00240A4D, 0x000EB4AD, 0x003402B6, // 2045-2048
    0x001C05B5, 0x00086DA9, 0x002E0EA9, 0x001B1D92, // 2049-2052
    0x003E0E92, 0x00280D26, 0x0012CA56, 0x00360A57, // 2053-2056
    0x002004D6, 0x000A86B5, 0x003006D5, 0x001C0EC9, // 2057-2060
    0x00066E92, 0x002A0693, 0x0014F52B, 0x003A052B, // 2061-2064
    0x00220A5B, 0x000EB55A, 0x0034056A, 0x001E0B55, // 2065-2068
    0x00089749, 0x002E0B49, 0x00191A93, 0x003E0A95, // 2069-2072
    0x0026052D, 0x0010CAAD, 0x00360AB5, 0x002205AA, // 2073-2076
    0x000A8BA5, 0x00300DA5, 0x001C0D4A, 0x00067A95, // 2077-2080
    0x002A0C95, 0x0014F52E, 0x003A0556, 0x00240AB5, // 2081-2084
    0x000EB5B2, 0x003406D2, 0x001E0EA5, 0x000A9E4A, // 2085-2088
    0x002E064A, 0x00170C97, 0x003C0CAB, 0x0028055A, // 2089-2092
    0x0010CAD5, 0x00360B69, 0x00220752, 0x000C96A5, // 2093-2096
    0x00300B25, 0x001A064B, 0x00047497, 0x002A04AB, // 2097-2100
    ]

    // The same layout for the Vietnamese calendar, whose day boundary is UTC+7 from 1968.
    private static let vietnameseTable: InlineArray<200, UInt32> = [
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
    0x001C064A, 0x00046C97, 0x002A029B, 0x0014E55B, // 1965-1968
    0x0038056B, 0x00240B69, 0x0010B752, 0x00360B52, // 1969-1972
    0x001E0B25, 0x00089A4B, 0x002E0A4D, 0x001914AB, // 1973-1976
    0x003C02AD, 0x002605AD, 0x0012CB6A, 0x00380DA9, // 1977-1980
    0x00220D92, 0x000C9D25, 0x00320D25, 0x001D7A55, // 1981-1984
    0x00400A56, 0x002A04B6, 0x0014E5B5, 0x003A06D5, // 1985-1988
    0x00240EC9, 0x0010BE92, 0x00360E92, 0x00200D26, // 1989-1992
    0x00086A56, 0x002C0A57, 0x00191556, 0x003E056A, // 1993-1996
    0x00260B55, 0x0012B6C9, 0x00380749, 0x00220693, // 1997-2000
    0x000A952B, 0x0030052B, 0x001A0A5B, 0x0006555A, // 2001-2004
    0x002A056A, 0x0014EB65, 0x003A0BA5, 0x00260D49, // 2005-2008
    0x000EBA95, 0x00340A95, 0x001E052D, 0x00088AAD, // 2009-2012
    0x002C0AB5, 0x001935AA, 0x003E05D2, 0x00280DA5, // 2013-2016
    0x0012DD4A, 0x00380E4A, 0x00220C96, 0x000C992E, // 2017-2020
    0x00300556, 0x001A0AB5, 0x000655B2, 0x002C06D2, // 2021-2024
    0x0014CEA5, 0x003A0725, 0x0024064B, 0x000EAC97, // 2025-2028
    0x003204AB, 0x001C055B, 0x00086ADA, 0x002E0B6A, // 2029-2032
    0x00197752, 0x003E0B92, 0x00280B25, 0x0012DA4B, // 2033-2036
    0x00360A4D, 0x002004AD, 0x000AA95B, 0x003005AD, // 2037-2040
    0x001A0BAA, 0x00065B52, 0x002C0D92, 0x0016FD25, // 2041-2044
    0x003A0D25, 0x00240A55, 0x000EB4AD, 0x003404B6, // 2045-2048
    0x001C06B5, 0x00086DAA, 0x002E0ECA, 0x001B0E92, // 2049-2052
    0x003C0E93, 0x00280D2A, 0x0012CA56, 0x00360A5B, // 2053-2056
    0x0020055A, 0x000A8AD5, 0x00300B55, 0x001C074A, // 2057-2060
    0x00046E93, 0x002A0A93, 0x0014F52B, 0x003A052B, // 2061-2064
    0x00220A9B, 0x000EB55A, 0x0034056A, 0x001E0B65, // 2065-2068
    0x0008974A, 0x002E0D4A, 0x00191A95, 0x003E0C95, // 2069-2072
    0x0026092D, 0x0010CAAD, 0x00360AB5, 0x002205AA, // 2073-2076
    0x000A8DA5, 0x00300EA5, 0x001C0D4A, 0x00067D15, // 2077-2080
    0x002A0C96, 0x0014F956, 0x003A0556, 0x00240AB5, // 2081-2084
    0x000EB6B4, 0x003406D4, 0x001E0EA5, 0x000A8E8A, // 2085-2088
    0x002C068B, 0x00171497, 0x003C04AB, 0x0026095B, // 2089-2092
    0x0010CADA, 0x00360B6A, 0x00220754, 0x000C9725, // 2093-2096
    0x00300B45, 0x001A0A8B, 0x0004552B, 0x002A04AD, // 2097-2100
    ]

    private static func tableEntry(_ index: Int, _ variant: ChineseCalendarVariant) -> UInt32 {
        switch variant {
        case .chinese: return chineseTable[index]
        case .dangi: return dangiTable[index]
        case .vietnamese: return vietnameseTable[index]
        }
    }

    private static let tableYearCount = chineseTable.count

    private static func decodeTableYear(relatedISOYear: Int, _ variant: ChineseCalendarVariant) -> _ChineseYear {
        let entry = tableEntry(relatedISOYear - firstTableYear, variant)
        let leap = UInt8((entry >> 13) & 0xF)
        return _ChineseYear(relatedISOYear: relatedISOYear, newYearRataDie: _CalendarAstronomy.gregorianRataDie(relatedISOYear, 1, 19) + Int((entry >> 17) & 0x3F), monthLengthBits: UInt16(entry & 0x1FFF), monthCount: leap == 0 ? 12 : 13, leapMonthNumber: leap)
    }

    /// Month structure for the Chinese year whose New Year falls in Gregorian `relatedISOYear`.
    ///
    /// In the baked range (1901...2100) this is a direct table decode.
    /// Outside it the astronomy gives the structure, without a cache. The code finds this year's New Year and the next year's, and walks the new moons between them to get the first day of each month.
    /// It records the 29 or 30 day lengths as bits, and marks the leap month, which is the month with no major solar term.
    /// The years next to the table edges start and end on the New Year days of the table, so the computed years join the baked years with no gap and no overlap.
    static func year(relatedISOYear: Int, _ variant: ChineseCalendarVariant) -> _ChineseYear {
        let idx = relatedISOYear - firstTableYear
        if idx >= 0 && idx < tableYearCount {
            return decodeTableYear(relatedISOYear: relatedISOYear, variant)
        }
        // Out-of-range: compute the month structure from astronomy. No caching; see the note on the rule functions above.
        // Join the baked table with no gap and no overlap at its edges.
        let ny: Int
        if relatedISOYear == firstTableYear + tableYearCount {
            ny = decodeTableYear(relatedISOYear: relatedISOYear - 1, variant).endRataDie
        } else {
            ny = chineseNewYear(relatedISOYear, variant)
        }
        let nyNext: Int
        if relatedISOYear + 1 == firstTableYear {
            nyNext = decodeTableYear(relatedISOYear: firstTableYear, variant).newYearRataDie
        } else {
            nyNext = chineseNewYear(relatedISOYear + 1, variant)
        }
        // Collect each month's first day: successive new moons from this New Year up to (but not including) the next year's New Year.
        var starts = [ny]
        var cur = ny
        while true {
            let nxt = chineseNewMoonNear(cur + chineseSynodicGap, true, variant)
            if nxt >= nyNext { break }
            starts.append(nxt)
            cur = nxt
        }
        // Pack month lengths (30-day months set a bit) and record the leap month, if any.
        var monthLengthBits: UInt16 = 0
        var leapMonthNumber: UInt8 = 0
        for (i, s) in starts.enumerated() {
            let next = (i + 1 < starts.count) ? starts[i + 1] : nyNext
            assert(next - s == 29 || next - s == 30, "non-lunation month length \(next - s) in fallback year \(relatedISOYear)")
            if next - s == 30 { monthLengthBits |= UInt16(1) << i }
            let label = chineseMonthLabel(startingAt: s, gregorianYear: _CalendarAstronomy.gregorianYear(ofRataDie: s), variant)
            if label.isLeap { leapMonthNumber = UInt8(label.month) }
        }
        return _ChineseYear(relatedISOYear: relatedISOYear, newYearRataDie: ny, monthLengthBits: monthLengthBits, monthCount: UInt8(starts.count), leapMonthNumber: leapMonthNumber)
    }

    static func year(containingRataDie rataDie: Int, _ variant: ChineseCalendarVariant) -> _ChineseYear {
        // CNY falls Jan 19 + [2, 61]; estimate by Gregorian year and adjust.
        var iso = _CalendarAstronomy.gregorianYear(ofRataDie: rataDie)
        var y = year(relatedISOYear: iso, variant)
        while rataDie < y.newYearRataDie {
            iso -= 1
            y = year(relatedISOYear: iso, variant)
        }
        while rataDie >= y.endRataDie {
            iso += 1
            y = year(relatedISOYear: iso, variant)
        }
        return y
    }
}

#endif // !hasFeature(Embedded)
