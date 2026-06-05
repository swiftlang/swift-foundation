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

/// Pure-Swift implementation of the Hebrew calendar, derived from the
/// Reingold & Dershowitz algorithms (`Calendrical Calculations`).
///
/// This replaces the ICU4C-backed Hebrew path in `_CalendarICU`. It works on
/// all supported platforms and is substantially faster than the ICU path because
/// Foundation's `_CalendarProtocol` contract does not require the ICU
/// `ucal_set` / `add` / `roll` eager recalculation semantics.
internal final class _CalendarHebrew: _CalendarProtocol, @unchecked Sendable {

#if canImport(os)
    internal static let logger: Logger = {
        Logger(subsystem: "com.apple.foundation", category: "hebrew_calendar")
    }()
#endif

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        // .hebrew is the only identifier this class handles. `gregorianStartDate`
        // is ignored (only the Gregorian/Julian cutover calendar uses it).
        assert(identifier == .hebrew, "_CalendarHebrew only handles .hebrew")

        self.identifier = identifier
        self.timeZone = timeZone ?? .default
        self.locale = locale

        if let firstWeekday, (firstWeekday >= 1 && firstWeekday <= 7) {
            _firstWeekday = firstWeekday
        }

        if var minimumDaysInFirstWeek {
            if minimumDaysInFirstWeek < 1 {
                minimumDaysInFirstWeek = 1
            } else if minimumDaysInFirstWeek > 7 {
                minimumDaysInFirstWeek = 7
            }
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
        return _CalendarHebrew(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    // hash(into:) uses the `_CalendarProtocol` default impl.

    // MARK: - Range

    // Year bounds: match ICU's Hebrew reporting of ±5M (covers full Int32 year range
    // practically) rather than Gregorian-narrow bounds.
    private static let icuYearLowerBound = -5_000_000
    private static let icuYearUpperBound = 5_000_001   // exclusive

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return 0..<1                    // Hebrew has just the AM era
        case .year: return Self.icuYearLowerBound..<Self.icuYearUpperBound
        case .month: return 1..<14                 // 1..13 (stable numbering; 6 skipped in common)
        case .day: return 1..<30                   // Hebrew months have 29 or 30 days
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return -1..<6        // ICU allows negative ordinals (count from end)
        case .quarter: return 1..<5
        case .weekOfMonth: return 1..<6            // ICU reports 5 weeks min per month
        case .weekOfYear: return 1..<52
        case .yearForWeekOfYear: return Self.icuYearLowerBound..<Self.icuYearUpperBound
        case .nanosecond: return 0..<1_000_000_000
        case .isLeapMonth: return 0..<1
        case .isRepeatedDay: return 0..<1
        case .dayOfYear: return 1..<354
        case .calendar, .timeZone:
            return nil
        }
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return 0..<1
        case .year: return Self.icuYearLowerBound..<Self.icuYearUpperBound
        case .month: return 1..<14
        case .day: return 1..<31
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return -1..<6
        case .quarter: return 1..<5
        case .weekOfMonth: return 1..<7            // ICU max (month with many weeks)
        case .weekOfYear: return 1..<57            // leap year can have 56 weeks
        case .yearForWeekOfYear: return Self.icuYearLowerBound..<Self.icuYearUpperBound
        case .nanosecond: return 0..<1_000_000_000
        case .isLeapMonth: return 0..<1
        case .isRepeatedDay: return 0..<1
        case .dayOfYear: return 1..<386
        case .calendar, .timeZone:
            return nil
        }
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        // Special cases that match ICU's Hebrew behavior directly (bypass _algorithmA).
        // Matches _CalendarGregorian.range(of:in:for:) structure: time-level and weekday
        // ranges are FIXED regardless of `larger`, so return them via maximumRange.
        switch smaller {
        case .weekday:
            switch larger {
            case .second, .minute, .hour, .day, .weekday:
                return nil
            default:
                return maximumRange(of: smaller)      // 1..<8
            }
        case .hour:
            switch larger {
            case .second, .minute, .hour:
                return nil
            default:
                return maximumRange(of: smaller)      // 0..<24
            }
        case .minute:
            switch larger {
            case .second, .minute:
                return nil
            default:
                return maximumRange(of: smaller)      // 0..<60
            }
        case .second:
            switch larger {
            case .second:
                return nil
            default:
                return maximumRange(of: smaller)      // 0..<60
            }
        case .nanosecond:
            return maximumRange(of: smaller)          // 0..<1_000_000_000
        default:
            break
        }
        switch (smaller, larger) {
        case (.month, .year):
            // ICU reports 1..<14 for Hebrew regardless of common/leap year (the stable
            // numbering has month 13 = Elul always existing).
            return 1..<14
        default:
            break
        }
        // Algorithm-A: query ordinality at interval endpoints.
        guard let interval = dateInterval(of: larger, for: date) else { return nil }
        guard let ord1 = ordinality(of: smaller, in: larger, for: interval.start + 0.1) else { return nil }
        guard let ord2 = ordinality(of: smaller, in: larger, for: interval.start + interval.duration - 0.1) else { return nil }
        if ord2 < ord1 { return ord1..<ord1 }
        return ord1..<(ord2 + 1)
    }

    // MARK: - Ordinality

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        let tz = self.timeZone
        // Pull every field we might need in one dateComponents call.
        let comps = dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond,
             .weekday, .weekOfYear, .weekOfMonth, .weekdayOrdinal, .dayOfYear],
            from: date, in: tz
        )
        guard let year = comps.year, let civilMonth = comps.month, let day = comps.day else { return nil }
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        let nanosecond = comps.nanosecond ?? 0

        switch (smaller, larger) {
        case (.day, .year):
            return comps.dayOfYear ?? (Int(HebrewArithmetic.daysPrecedingCivilMonth(
                year: Int32(year), civilMonth: UInt8(civilMonth))) + day)
        case (.day, .month):
            return day
        case (.month, .year):
            // Match ICU: ordinality returns the civil month number directly
            // (NOT densified). Common years have a "hole" at civil 6, but the
            // numbering of existing months is stable (Adar = 7 in common, Elul = 13).
            return civilMonth
        case (.month, .quarter):
            // ICU's Hebrew mcount table — position of civil month within its quarter.
            // Indexed by civilMonth-1. For common years civil-6 is skipped but the table
            // value at index 5 (AdarI slot) is never queried in that year because
            // dateComponents never returns civilMonth=6 for common years.
            let mcount: [Int] = [1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 1, 2, 3]
            return mcount[civilMonth - 1]
        case (.quarter, .year):
            // ICU's Hebrew mquarter table — which quarter (1..4) this civil month belongs to.
            let mquarter: [Int] = [3, 3, 3, 4, 4, 4, 4, 1, 1, 1, 2, 2, 2]
            return mquarter[civilMonth - 1]
        case (.weekOfYear, .year):
            // ICU uses the firstWeekday-aware UNWRAPPED week number (same as
            // dateComponents.weekOfYear, but no end-of-year wrap). Required for
            // range(.weekOfYear, .year) to report the correct max.
            let dayOfYear = Int(HebrewArithmetic.daysPrecedingCivilMonth(
                year: Int32(year), civilMonth: UInt8(civilMonth))) + day
            let weekday = comps.weekday ?? 1
            let relStart = (weekday - dayOfYear + 7001 - firstWeekday) % 7
            var unwrapped = (dayOfYear - 1 + relStart) / 7
            if (7 - relStart) >= minimumDaysInFirstWeek { unwrapped += 1 }
            return unwrapped
        case (.weekOfMonth, .month):
            // Same firstWeekday-aware formula as dateComponents.weekOfMonth.
            return comps.weekOfMonth
        case (.weekday, .year):
            // "Nth Monday/Tuesday/etc. of year" — simple 7-day chunking.
            let dayOfYear = Int(HebrewArithmetic.daysPrecedingCivilMonth(
                year: Int32(year), civilMonth: UInt8(civilMonth))) + day
            return (dayOfYear - 1) / 7 + 1
        case (.weekday, .month):
            // "Nth Monday/Tuesday/etc. of month."
            return (day - 1) / 7 + 1
        case (.weekday, .weekOfYear):
            // Position within the firstWeekday-anchored week (1..7). When
            // firstWeekday=1 (Sun), this equals the raw weekday; otherwise
            // it rotates so that the first weekday is 1.
            guard let weekday = comps.weekday else { return nil }
            return ((weekday - firstWeekday + 7) % 7) + 1
        case (.weekdayOrdinal, .month):
            // Same as (.weekday, .month): "Nth occurrence of this weekday in month."
            return (day - 1) / 7 + 1
        case (.hour, .day):
            return hour + 1
        case (.minute, .hour):
            return minute + 1
        case (.second, .minute):
            return second + 1
        case (.nanosecond, .second):
            return nanosecond + 1
        default:
            return nil
        }
    }

    // MARK: - Date intervals

    /// Compute the civil date for "one day after (year, civilMonth, day)", handling
    /// month and year boundaries and the civil-6 skip in common years.
    private static func nextDay(year: Int32, civilMonth: UInt8, day: UInt8) -> (Int32, UInt8, UInt8) {
        let monthLength = HebrewArithmetic.daysInCivilMonth(year: year, civilMonth: civilMonth)
        if day < monthLength {
            return (year, civilMonth, day + 1)
        }
        var nextMonth = civilMonth + 1
        var nextYear = year
        if nextMonth > 13 {
            nextMonth = 1
            nextYear += 1
        } else if nextMonth == 6 && !HebrewArithmetic.isLeapYear(nextYear) {
            nextMonth = 7
        }
        return (nextYear, nextMonth, 1)
    }

    /// Compute the civil date for "one month after (year, civilMonth)".
    private static func nextMonth(year: Int32, civilMonth: UInt8) -> (Int32, UInt8) {
        var m = civilMonth + 1
        var y = year
        if m > 13 {
            m = 1
            y += 1
        } else if m == 6 && !HebrewArithmetic.isLeapYear(y) {
            m = 7
        }
        return (y, m)
    }

    /// Fixed day number (RD) of the first day of week 1 of the given Hebrew year, using
    /// the current `firstWeekday` and `minimumDaysInFirstWeek`. This is the anchor for
    /// `yearForWeekOfYear` computations (interval boundaries, multi-year add).
    private func firstDayOfWeekYear(_ year: Int32) -> Int64 {
        let rdTishri1 = HebrewArithmetic.fixedFromHebrew(year: year, month: HebrewArithmetic.TISHRI, day: 1)
        var r = rdTishri1 % 7
        if r < 0 { r += 7 }
        let tishriWeekday = Int(r) + 1                               // 1..7
        let rel = (tishriWeekday - firstWeekday + 7) % 7             // 0..6
        let offset: Int
        if (7 - rel) >= minimumDaysInFirstWeek {
            offset = -rel                                            // start at the Sunday (etc.) before Tishri 1
        } else {
            offset = 7 - rel                                         // first week doesn't have enough days; start the next week
        }
        return rdTishri1 &+ Int64(offset)
    }

    /// Number of weeks in the given Hebrew year for week-of-year semantics.
    /// `dateInterval(.yearForWeekOfYear)` duration = this × 7 × 86400 (in local days).
    /// Returns 50 or 51 for common years, 54–56 for leap years, depending on weekday alignment.
    private func numWeeksInYearForWeekOfYear(_ year: Int32) -> Int {
        let start = firstDayOfWeekYear(year)
        let nextStart = firstDayOfWeekYear(year + 1)
        return Int(nextStart - start) / 7
    }

    /// Build a Date at local midnight of the given (year, civilMonth, day) in the given timezone.
    private func localMidnight(year: Int32, civilMonth: UInt8, day: UInt8, in tz: TimeZone) -> Date? {
        var dc = DateComponents()
        dc.era = 0
        dc.year = Int(year)
        dc.month = Int(civilMonth)
        dc.day = Int(day)
        dc.timeZone = tz
        return self.date(from: dc)
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        let tz = self.timeZone
        let comps = dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date, in: tz)
        guard let yearInt = comps.year, let civilMonthInt = comps.month, let dayInt = comps.day else { return nil }
        let year = Int32(yearInt)
        let civilMonth = UInt8(civilMonthInt)
        let day = UInt8(dayInt)

        switch component {
        case .era:
            // Hebrew has a single AM era spanning from epoch to effectively forever.
            // Matches ICU's reported start (Hebrew epoch, -181,778,083,200 s before
            // Date reference = year 1 AM, Tishrei 1, midnight UTC) and duration (_CalendarConstants.inf_ti).
            return DateInterval(
                start: Date(timeIntervalSinceReferenceDate: -181_778_083_200.0),
                duration: _CalendarConstants.inf_ti
            )
        case .year:
            // Tishri 1 of this year → Tishri 1 of next year.
            guard let start = localMidnight(year: year, civilMonth: 1, day: 1, in: tz),
                  let end = localMidnight(year: year + 1, civilMonth: 1, day: 1, in: tz) else {
                return nil
            }
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .yearForWeekOfYear:
            // Use the date's yearForWeekOfYear, NOT its Hebrew calendar year — these
            // differ near RH because weekOfYear can wrap into the previous or next
            // calendar year (e.g. last days of Elul belonging to next year's week 1,
            // or Tishrei 1–6 belonging to prior year's last week).
            let weekYearComps = dateComponents([.yearForWeekOfYear], from: date, in: tz)
            guard let weekYearInt = weekYearComps.yearForWeekOfYear else { return nil }
            let weekYear = Int32(weekYearInt)
            // Start = first day of week 1 of this yearForWeekOfYear.
            // Duration = (weeks in this year) × 7 days (in local seconds, DST-aware).
            let rdStart = firstDayOfWeekYear(weekYear)
            let rdEnd = firstDayOfWeekYear(weekYear + 1)
            let daysSinceRefStart = rdStart - Self.rataDieAtDateReference
            let daysSinceRefEnd = rdEnd - Self.rataDieAtDateReference
            let utcStart = Date(timeIntervalSinceReferenceDate: Double(daysSinceRefStart) * 86400)
            let utcEnd = Date(timeIntervalSinceReferenceDate: Double(daysSinceRefEnd) * 86400)
            let (o1, d1) = tz.rawAndDaylightSavingTimeOffset(for: utcStart, repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let (o2, d2) = tz.rawAndDaylightSavingTimeOffset(for: utcEnd, repeatedTimePolicy: .former, skippedTimePolicy: .former)
            let start = utcStart - Double(o1) - d1
            let end = utcEnd - Double(o2) - d2
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .quarter:
            // Hebrew quarter mapping matches ICU's internal `mquarter` table, indexed
            // by civil-month-minus-1: [3,3,3,4,4,4,4,1,1,1,2,2,2]. Q4 spans 4 civil
            // month slots (civil 4,5,6,7 = Tevet, Shevat, Adar I if leap, Adar/Adar II);
            // others span 3. The phantom civil-6 slot in common years is transparently
            // skipped by nextMonth().
            let quarterTable: [UInt8] = [3, 3, 3, 4, 4, 4, 4, 1, 1, 1, 2, 2, 2]
            let quarterNum = quarterTable[Int(civilMonth) - 1]
            let firstCivil: UInt8
            switch quarterNum {
            case 1: firstCivil = 8    // Nisan
            case 2: firstCivil = 11   // Tamuz
            case 3: firstCivil = 1    // Tishri
            case 4: firstCivil = 4    // Tevet
            default: firstCivil = 1
            }
            // Advance 3 civil-month slots (skipping phantom civil-6 in common years).
            // Even though Q4 has 4 table entries for civil 4,5,6,7 (leap year), the
            // duration is still 3 real months (nextMonth transparently handles common-
            // year civil-6 skips, and leap year civil-6/7 both count as real months,
            // so the span naturally resolves to 3 "real" months = ~89 days).
            guard let start = localMidnight(year: year, civilMonth: firstCivil, day: 1, in: tz) else { return nil }
            var (ny, nm) = (year, firstCivil)
            for _ in 0..<3 {
                (ny, nm) = Self.nextMonth(year: ny, civilMonth: nm)
            }
            guard let end = localMidnight(year: ny, civilMonth: nm, day: 1, in: tz) else { return nil }
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .weekOfYear, .weekOfMonth:
            // "The 7-day week containing this date." Start = last midnight at
            // firstWeekday on or before this date; duration = 1 local week
            // (normally 7×86400, varies by DST).
            // Compute weekday from (year, civilMonth, day) via its RD.
            let biblicalMonth: UInt8
            if let b = HebrewArithmetic.civilToBiblical(year: year, civilMonth: civilMonth) {
                biblicalMonth = b
            } else {
                return nil
            }
            let rdHere = HebrewArithmetic.fixedFromHebrew(year: year, month: biblicalMonth, day: UInt8(day))
            var r = rdHere % 7
            if r < 0 { r += 7 }
            let weekday = Int(r) + 1
            var daysBack = weekday - firstWeekday
            if daysBack < 0 { daysBack += 7 }

            // Walk back `daysBack` civil days to the start of this week.
            var sY = year, sM = civilMonth, sD = UInt8(day)
            for _ in 0..<daysBack {
                if sD > 1 {
                    sD -= 1
                } else {
                    var pm = sM - 1
                    var py = sY
                    if pm < 1 { pm = 13; py -= 1 }
                    else if pm == 6 && !HebrewArithmetic.isLeapYear(py) { pm = 5 }
                    sM = pm; sY = py
                    sD = HebrewArithmetic.daysInCivilMonth(year: sY, civilMonth: sM)
                }
            }
            guard let start = localMidnight(year: sY, civilMonth: sM, day: sD, in: tz) else { return nil }

            // Walk forward 7 days.
            var eY = sY, eM = sM, eD = sD
            for _ in 0..<7 {
                (eY, eM, eD) = Self.nextDay(year: eY, civilMonth: eM, day: eD)
            }
            guard let end = localMidnight(year: eY, civilMonth: eM, day: eD, in: tz) else { return nil }
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .month:
            guard let start = localMidnight(year: year, civilMonth: civilMonth, day: 1, in: tz) else { return nil }
            let (ny, nm) = Self.nextMonth(year: year, civilMonth: civilMonth)
            guard let end = localMidnight(year: ny, civilMonth: nm, day: 1, in: tz) else { return nil }
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .day, .weekday, .weekdayOrdinal, .dayOfYear:
            // Exact day duration: start-of-next-day minus start-of-today in local time.
            // Captures the 23/25-hour DST days correctly.
            guard let start = localMidnight(year: year, civilMonth: civilMonth, day: day, in: tz) else { return nil }
            let (ny, nm, nd) = Self.nextDay(year: year, civilMonth: civilMonth, day: day)
            guard let end = localMidnight(year: ny, civilMonth: nm, day: nd, in: tz) else { return nil }
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .hour:
            // Local-floor to hour boundary, then back to UTC. Avoids the .former-policy
            // ambiguity hazard at DST repeats: re-constructing via date(from:) with
            // ymd+hour can land in the wrong UTC half of a repeated wall-clock window.
            // Mirrors _CalendarGregorian.dateInterval(of: .hour).
            let ti = Double(tz.secondsFromGMT(for: date))
            let time = date.timeIntervalSinceReferenceDate
            var fixedTime = time + ti
            fixedTime = floor(fixedTime / 3600.0) * 3600.0
            fixedTime = fixedTime - ti
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: fixedTime), duration: 3600.0)
        case .minute:
            // Minute and second don't depend on TZ — float floor on UTC seconds is fine.
            let time = date.timeIntervalSinceReferenceDate
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time / 60.0) * 60.0), duration: 60.0)
        case .second:
            let time = date.timeIntervalSinceReferenceDate
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time)), duration: 1.0)
        case .nanosecond:
            return DateInterval(start: date, duration: 1e-9)
        case .isLeapMonth, .isRepeatedDay, .calendar, .timeZone:
            return nil
        }
    }

    // MARK: - Weekend queries

    func isDateInWeekend(_ date: Date) -> Bool {
        let weekendRange = locale?.weekendRange ?? _CalendarUtility.defaultWeekendRange
        let comps = dateComponents([.weekday, .hour, .minute, .second], from: date, in: self.timeZone)
        guard let dayOfWeek = comps.weekday else { return false }
        let timeInDay = TimeInterval(
            (comps.hour ?? 0) * _CalendarConstants.kSecondsInHour
            + (comps.minute ?? 0) * 60
            + (comps.second ?? 0)
        )
        return _CalendarUtility.isDateInWeekend(weekday: dayOfWeek, timeInDay: timeInDay, weekendRange: weekendRange)
    }

    // MARK: - Date ↔ DateComponents

    /// Rata Die day number of Date's reference instant (midnight UTC, Jan 1 2001).
    internal static let rataDieAtDateReference: Int64 = 730_486

    /// Convert a local-seconds-since-reference value to (RD, seconds-in-day).
    private static func rataDieAndSecondsInDay(localSeconds: Double) -> (rd: Int64, secondsInDay: Double) {
        let totalDays = (localSeconds / 86400).rounded(.down)
        let rd = Int64(totalDays) &+ rataDieAtDateReference
        let secondsInDay = localSeconds - totalDays * 86400
        return (rd, secondsInDay)
    }

    /// Build a UTC Date from a fixed-day RD + local-seconds-within-day,
    /// subtracting the TimeZone offset at that local instant.
    internal func utcDate(fromRataDie rd: Int64, secondsInDay: Double, in timeZone: TimeZone,
                        repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy,
                        skippedTimePolicy: TimeZone.DaylightSavingTimePolicy) -> Date {
        _ = skippedTimePolicy   // silenced — see doc comment
        let daysSinceRef = rd &- Self.rataDieAtDateReference
        let secondsAsIfUTC = Double(daysSinceRef) * 86400 + secondsInDay
        let tmpDate = Date(timeIntervalSinceReferenceDate: secondsAsIfUTC)
        let (tzOffset, dstOffset) = timeZone.rawAndDaylightSavingTimeOffset(
            for: tmpDate, repeatedTimePolicy: repeatedTimePolicy)
        return tmpDate - Double(tzOffset) - dstOffset
    }

    func date(from components: DateComponents) -> Date? {
        // Hebrew calendar has a single era (AM) encoded as era = 0 (matching ICU).
        // We accept era = 0 or era = nil; any other era is rejected.
        if let era = components.era, era != 0 {
            return nil
        }

        guard let yearValue = components.year else { return nil }
        guard yearValue >= Int(Int32.min) && yearValue <= Int(Int32.max) else { return nil }
        let year = Int32(yearValue)

        let civilMonth = components.month ?? 1
        let day = components.day ?? 1

        // Validate civil month is in 1..13 AND corresponds to a real month in this
        // year (civil month 6 is "Adar I" which only exists in leap years).
        guard civilMonth >= 1 && civilMonth <= 13,
              let biblical = HebrewArithmetic.civilToBiblical(year: year, civilMonth: UInt8(civilMonth)) else {
            return nil
        }
        let daysInMonth = Int(HebrewArithmetic.lastDayOfMonth(year, month: biblical))
        guard day >= 1 && day <= daysInMonth else { return nil }

        let rd = HebrewArithmetic.fixedFromHebrew(year: year, month: biblical, day: UInt8(day))

        // Time-of-day in local seconds (defaults to midnight).
        var secondsInDay: Double = 0
        if let hour = components.hour { secondsInDay += Double(hour) * 3600 }
        if let minute = components.minute { secondsInDay += Double(minute) * 60 }
        if let second = components.second { secondsInDay += Double(second) }
        if let nanosecond = components.nanosecond { secondsInDay += Double(nanosecond) / 1e9 }

        let tz = components.timeZone ?? timeZone
        // Matches _CalendarGregorian's DST policy: skipped and repeated both resolve to .former.
        return utcDate(fromRataDie: rd, secondsInDay: secondsInDay, in: tz,
                      repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        // For UTC→local extraction the offset at a given Date is unique — match
        // _CalendarGregorian by using `secondsFromGMT(for:)` instead of the
        // policy-parameterized rawAndDaylightSavingTimeOffset (which can resolve
        // ambiguously at DST transitions when using .former/.latter).
        let totalOffset = timeZone.secondsFromGMT(for: date)
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(totalOffset)
        let (rd, secondsInDay) = Self.rataDieAndSecondsInDay(localSeconds: localSeconds)

        let (year, biblicalMonth, day) = HebrewArithmetic.hebrewFromFixed(rd)
        let civilMonth = HebrewArithmetic.biblicalToCivil(year: year, biblicalMonth: biblicalMonth)

        var result = DateComponents()

        if components.contains(.era) { result.era = 0 } // Hebrew has a single era (AM) encoded as 0 in ICU.
        if components.contains(.year) { result.year = Int(year) }
        if components.contains(.month) { result.month = Int(civilMonth) }
        if components.contains(.day) { result.day = Int(day) }
        // `.isLeapMonth`: always populated with `false` for Hebrew, matching ICU's
        // behavior. `_CalendarICU` ignores whether the caller asked for this field
        // and always fills it in (verified via `Calendar.dateComponents(in:from:)`
        // which does NOT pass `.isLeapMonth` in its component set yet ICU still
        // populates `isLeapMonth = false` in the returned DateComponents).
        result.isLeapMonth = false

        // Time-of-day components.
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
            // RD 1 = Monday (Jan 1, year 1 ISO). Civil weekday: Sunday=1..Saturday=7.
            // Mapping: (RD mod 7) → weekday
            //   RD mod 7 == 0 → Sunday (1)
            //   RD mod 7 == 1 → Monday (2)
            //   RD mod 7 == 2 → Tuesday (3)  ... etc.
            var r = rd % 7
            if r < 0 { r += 7 }
            result.weekday = Int(r) + 1
        }

        if components.contains(.dayOfYear) {
            // Days preceding this civil month in this year, + day.
            let preceding = Int(HebrewArithmetic.daysPrecedingCivilMonth(
                year: year, civilMonth: UInt8(civilMonth)))
            result.dayOfYear = preceding + Int(day)
        }

        if components.contains(.timeZone) {
            result.timeZone = timeZone
        }

        // Week-fields: weekdayOrdinal, weekOfMonth, weekOfYear, yearForWeekOfYear.
        // Formulas mirror _CalendarGregorian.dateComponents(_:from:in:) exactly (these
        // are calendar-agnostic once year-day-number + year-length + weekday are known).
        // Required by the parity protocol — ICU populates these for Hebrew.
        let needsWeekFields = components.contains(.weekdayOrdinal) ||
                              components.contains(.weekOfMonth) ||
                              components.contains(.weekOfYear) ||
                              components.contains(.yearForWeekOfYear)
        if needsWeekFields {
            // weekday in 1..7 (Sunday = 1, … Saturday = 7).
            var r = rd % 7
            if r < 0 { r += 7 }
            let weekday = Int(r) + 1

            let dayInt = Int(day)
            let dayOfYear = Int(HebrewArithmetic.daysPrecedingCivilMonth(
                year: year, civilMonth: UInt8(civilMonth))) + dayInt
            let yearLength = Int(HebrewArithmetic.daysInYear(year))

            // Weekday (0..6) of Tishrei 1 of this year.
            let relativeWeekdayForYearStart = (weekday - dayOfYear + 7001 - firstWeekday) % 7
            let relativeWeekday = (weekday + 7 - firstWeekday) % 7

            // Week of year (provisional; 0 means belongs to previous year's last week).
            var weekOfYear = (dayOfYear - 1 + relativeWeekdayForYearStart) / 7
            if (7 - relativeWeekdayForYearStart) >= minimumDaysInFirstWeek {
                weekOfYear += 1
            }

            var yearForWeekOfYear = Int(year)
            if weekOfYear == 0 {
                // Near the start of the year — the week belongs to the previous year's last week.
                let previousYearLength = Int(HebrewArithmetic.daysInYear(year - 1))
                let previousDayOfYear = dayOfYear + previousYearLength
                weekOfYear = Self.weekNumber(
                    desiredDay: previousDayOfYear, dayOfPeriod: previousDayOfYear, weekday: weekday,
                    firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
                yearForWeekOfYear -= 1
            } else if dayOfYear >= yearLength - 5 {
                // Near end-of-year; this day may belong to week 1 of the next year.
                var lastRelativeDayOfWeek = (relativeWeekday + yearLength - dayOfYear) % 7
                if lastRelativeDayOfWeek < 0 { lastRelativeDayOfWeek += 7 }
                if ((6 - lastRelativeDayOfWeek) >= minimumDaysInFirstWeek)
                    && ((dayOfYear + 7 - relativeWeekday) > yearLength) {
                    weekOfYear = 1
                    yearForWeekOfYear += 1
                }
            }

            let weekOfMonth = Self.weekNumber(
                desiredDay: dayInt, dayOfPeriod: dayInt, weekday: weekday,
                firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
            let weekdayOrdinal = (dayInt - 1) / 7 + 1

            if components.contains(.weekdayOrdinal)    { result.weekdayOrdinal = weekdayOrdinal }
            if components.contains(.weekOfMonth)       { result.weekOfMonth = weekOfMonth }
            if components.contains(.weekOfYear)        { result.weekOfYear = weekOfYear }
            if components.contains(.yearForWeekOfYear) { result.yearForWeekOfYear = yearForWeekOfYear }
        }

        // `.quarter`: ICU returns 0 for Hebrew (Foundation's Hebrew calendar has no
        // meaningful quarter semantics through the query path). Match that sentinel.
        if components.contains(.quarter) {
            result.quarter = 0
        }

        return result
    }

    /// ICU-style week-number calculation. Matches `_CalendarGregorian.weekNumber`
    /// exactly (the logic is calendar-agnostic once the inputs are known).
    private static func weekNumber(
        desiredDay: Int, dayOfPeriod: Int, weekday: Int,
        firstWeekday: Int, minimumDaysInFirstWeek: Int
    ) -> Int {
        // Weekday (0-based) of the first day of the period (year or month).
        var periodStartDayOfWeek = (weekday - firstWeekday - dayOfPeriod + 1) % 7
        if periodStartDayOfWeek < 0 { periodStartDayOfWeek += 7 }

        var weekNo = (desiredDay + periodStartDayOfWeek - 1) / 7
        if (7 - periodStartDayOfWeek) >= minimumDaysInFirstWeek {
            weekNo += 1
        }
        return weekNo
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        dateComponents(components, from: date, in: self.timeZone)
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        // Application order (matching ICU / _CalendarGregorian):
        //   1. year, yearForWeekOfYear, month
        //   2. weeks + day-level components (as days, via offset-delta)
        //   3. time-of-day (direct TimeInterval arithmetic)

        var result = date

        // Wrap-day single-component fast path.
        if wrappingComponents,
           let d = components.day, d != 0,
           (components.year ?? 0) == 0, (components.month ?? 0) == 0,
           (components.weekOfYear ?? 0) == 0, (components.weekOfMonth ?? 0) == 0,
           (components.weekdayOrdinal ?? 0) == 0, (components.weekday ?? 0) == 0,
           (components.dayOfYear ?? 0) == 0, (components.yearForWeekOfYear ?? 0) == 0,
           (components.hour ?? 0) == 0, (components.minute ?? 0) == 0,
           (components.second ?? 0) == 0, (components.nanosecond ?? 0) == 0 {
            let tz = self.timeZone
            let localComps = dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: result, in: tz)
            guard let y = localComps.year, let m = localComps.month, let curDay = localComps.day else { return nil }
            let monthLen = Int(HebrewArithmetic.daysInCivilMonth(year: Int32(y), civilMonth: UInt8(m)))
            let newDay = ((curDay - 1 + d) % monthLen + monthLen) % monthLen + 1
            var newDC = DateComponents()
            newDC.era = 0; newDC.year = y; newDC.month = m; newDC.day = newDay
            newDC.hour = localComps.hour ?? 0
            newDC.minute = localComps.minute ?? 0
            newDC.second = localComps.second ?? 0
            newDC.nanosecond = localComps.nanosecond ?? 0
            newDC.timeZone = tz
            return self.date(from: newDC)
        }

        // Step 1+2: year then month, as separate sequential operations (matching
        // _CalendarGregorian's pattern where each field gets its own decompose →
        // adjust → clamp → reconstruct cycle). Batching year+month into one step
        // would skip the day-clamping between them — e.g. Kislev 30 in a complete
        // year + 1 year landing in a deficient year (Kislev 29) must clamp to 29
        // before the month add runs.
        let yearsToAdd = components.year ?? 0
        let monthsToAdd = components.month ?? 0

        if yearsToAdd != 0 {
            let tz = self.timeZone
            let currentComps = dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: result, in: tz
            )
            guard let y = currentComps.year,
                  let m = currentComps.month,
                  let d = currentComps.day else { return nil }

            let newYear = Int32(y) + Int32(yearsToAdd)
            var newCivilMonth = Int32(m)

            if newCivilMonth == 6 && !HebrewArithmetic.isLeapYear(newYear) {
                newCivilMonth = 7
            }

            let monthLength = Int(HebrewArithmetic.daysInCivilMonth(
                year: newYear, civilMonth: UInt8(newCivilMonth)))
            let clampedDay = min(d, monthLength)

            guard let biblicalNew = HebrewArithmetic.civilToBiblical(year: newYear, civilMonth: UInt8(newCivilMonth)) else { return nil }
            let rdNew = HebrewArithmetic.fixedFromHebrew(year: newYear, month: biblicalNew, day: UInt8(clampedDay))
            var secondsInDay: Double = 0
            if let h = currentComps.hour    { secondsInDay += Double(h) * 3600 }
            if let m = currentComps.minute  { secondsInDay += Double(m) * 60 }
            if let s = currentComps.second  { secondsInDay += Double(s) }
            if let n = currentComps.nanosecond { secondsInDay += Double(n) / 1e9 }
            result = utcDate(fromRataDie: rdNew, secondsInDay: secondsInDay, in: tz,
                            repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        if monthsToAdd != 0 {
            let tz = self.timeZone
            let currentComps = dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: result, in: tz
            )
            guard let y = currentComps.year,
                  let m = currentComps.month,
                  let d = currentComps.day else { return nil }

            var newYear = Int32(y)
            var newCivilMonth = Int32(m)

            var remaining = monthsToAdd
            while remaining > 0 {
                newCivilMonth += 1
                if newCivilMonth > 13 {
                    newCivilMonth = 1
                    newYear += 1
                } else if newCivilMonth == 6 && !HebrewArithmetic.isLeapYear(newYear) {
                    newCivilMonth = 7
                }
                remaining -= 1
            }
            while remaining < 0 {
                newCivilMonth -= 1
                if newCivilMonth < 1 {
                    newCivilMonth = 13
                    newYear -= 1
                } else if newCivilMonth == 6 && !HebrewArithmetic.isLeapYear(newYear) {
                    newCivilMonth = 5
                }
                remaining += 1
            }

            let monthLength = Int(HebrewArithmetic.daysInCivilMonth(
                year: newYear, civilMonth: UInt8(newCivilMonth)))
            let clampedDay = min(d, monthLength)

            guard let biblicalNew = HebrewArithmetic.civilToBiblical(year: newYear, civilMonth: UInt8(newCivilMonth)) else { return nil }
            let rdNew = HebrewArithmetic.fixedFromHebrew(year: newYear, month: biblicalNew, day: UInt8(clampedDay))
            var secondsInDay: Double = 0
            if let h = currentComps.hour    { secondsInDay += Double(h) * 3600 }
            if let m = currentComps.minute  { secondsInDay += Double(m) * 60 }
            if let s = currentComps.second  { secondsInDay += Double(s) }
            if let n = currentComps.nanosecond { secondsInDay += Double(n) / 1e9 }
            result = utcDate(fromRataDie: rdNew, secondsInDay: secondsInDay, in: tz,
                            repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        // Step 3: day-level additions (day, week units, weekday etc.) collapse into a single
        // day-count delta applied via offset-delta DST-aware arithmetic.
        var daysToAdd = 0
        if let d = components.day { daysToAdd += d }
        if let doy = components.dayOfYear { daysToAdd += doy }
        if let wom = components.weekOfMonth { daysToAdd += wom * 7 }
        if let woy = components.weekOfYear { daysToAdd += woy * 7 }
        if let wo = components.weekdayOrdinal { daysToAdd += wo * 7 }
        if let w = components.weekday { daysToAdd += w }

        // `.yearForWeekOfYear`: advance by N week-year lengths (numWeeksInYearForWeekOfYear × 7).
        if let n = components.yearForWeekOfYear, n != 0 {
            let tz = self.timeZone
            let localComps = dateComponents([.yearForWeekOfYear], from: result, in: tz)
            if var yy = localComps.yearForWeekOfYear {
                if n > 0 {
                    for _ in 0..<n {
                        daysToAdd += numWeeksInYearForWeekOfYear(Int32(yy)) * 7
                        yy += 1
                    }
                } else {
                    for _ in 0..<(-n) {
                        yy -= 1
                        daysToAdd -= numWeeksInYearForWeekOfYear(Int32(yy)) * 7
                    }
                }
            }
        }

        if daysToAdd != 0 {
            // DST-aware offset-delta path: keep same local time across DST boundaries.
            // Use secondsFromGMT (single offset at a UTC instant) to match _CalendarGregorian.
            let tz = self.timeZone
            let totalOffset1 = tz.secondsFromGMT(for: result)
            let candidate = result + Double(daysToAdd) * 86400
            let totalOffset2 = tz.secondsFromGMT(for: candidate)
            result = candidate - Double(totalOffset2 - totalOffset1)
        }

        // Step 4: time-of-day additions (plain TimeInterval — no DST adjustment).
        if let h = components.hour, h != 0 { result += Double(h) * 3600 }
        if let m = components.minute, m != 0 { result += Double(m) * 60 }
        if let s = components.second, s != 0 { result += Double(s) }
        if let ns = components.nanosecond, ns != 0 { result += Double(ns) / 1_000_000_000 }

        return result
    }

    // MARK: - Fast enumerate path

    /// Compile the time-of-day (in local seconds) from any hour/minute/second/nanosecond
    /// components present. Defaults to 0 (midnight) when none are set.
    private static func secondsInDay(from c: DateComponents) -> Double {
        var s: Double = 0
        if let h  = c.hour       { s += Double(h) * 3600 }
        if let m  = c.minute     { s += Double(m) * 60 }
        if let sc = c.second     { s += Double(sc) }
        if let ns = c.nanosecond { s += Double(ns) / 1e9 }
        return s
    }

    /// Return the next civil month after `civilMonth` in the given year, accounting for
    /// the civil-6 (Adar I) skip in common years. Returns the new (year, civilMonth).
    private static func nextCivilMonthForward(year: Int32, civilMonth: UInt8) -> (Int32, UInt8) {
        var nm = civilMonth + 1
        var ny = year
        if nm > 13 {
            nm = 1
            ny += 1
        } else if nm == 6 && !HebrewArithmetic.isLeapYear(ny) {
            nm = 7
        }
        return (ny, nm)
    }

    private static func prevCivilMonthBackward(year: Int32, civilMonth: UInt8) -> (Int32, UInt8) {
        var pm = Int(civilMonth) - 1
        var py = year
        if pm < 1 {
            pm = 13
            py -= 1
        } else if pm == 6 && !HebrewArithmetic.isLeapYear(py) {
            pm = 5
        }
        return (py, UInt8(pm))
    }

    package func nextDate(after date: Date, matching components: DateComponents,
                          direction: Calendar.SearchDirection) -> Date? {
        // Reject anything that requires the generic enumerate framework.
        // Time-of-day fields (hour/minute/second/nanosecond) ARE allowed and preserved.
        if components.era != nil || components.year != nil ||
           components.weekOfYear != nil ||
           components.yearForWeekOfYear != nil ||
           components.dayOfYear != nil {
            return nil
        }

        let hasMonth = components.month != nil
        let hasDay = components.day != nil
        let hasWeekday = components.weekday != nil
        let hasWdOrd = components.weekdayOrdinal != nil
        let hasWeekOfMonth = components.weekOfMonth != nil

        // Only {month, weekday, weekOfMonth} is allowed for weekOfMonth patterns.
        if hasWeekOfMonth && !(hasMonth && hasWeekday && !hasDay && !hasWdOrd) { return nil }
        // weekdayOrdinal requires weekday, without day or weekOfMonth.
        if hasWdOrd && !(hasWeekday && !hasDay && !hasWeekOfMonth) { return nil }
        // {weekday, day} and {weekday, month} (without wdOrd/wOM) aren't fast-pathed.
        if hasWeekday && hasDay { return nil }
        if hasWeekday && hasMonth && !hasWdOrd && !hasWeekOfMonth { return nil }
        // Time-only: requires hour/minute/second all set.
        let timeOnly = !hasMonth && !hasDay && !hasWeekday
        if timeOnly {
            guard components.hour != nil, components.minute != nil, components.second != nil else { return nil }
        }

        let tz = self.timeZone
        let totalOffset = tz.secondsFromGMT(for: date)
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(totalOffset)
        let (rd, currentSecsInDay) = Self.rataDieAndSecondsInDay(localSeconds: localSeconds)
        let (year, biblicalMonth, day) = HebrewArithmetic.hebrewFromFixed(rd)
        let civilMonth = HebrewArithmetic.biblicalToCivil(year: year, biblicalMonth: biblicalMonth)
        let secsInDay = Self.secondsInDay(from: components)
        let forward = direction == .forward

        if timeOnly {
            return nextTimeOfDayMatch(rd: rd, currentSecsInDay: currentSecsInDay,
                                      targetSecsInDay: secsInDay,
                                      forward: forward, tz: tz)
        }

        if hasWeekOfMonth {
            return nextMonthWeekdayWeekOfMonthMatch(
                rd: rd, currentSecsInDay: currentSecsInDay, currentYear: year,
                targetMonth: components.month!,
                targetWeekday: components.weekday!,
                targetWeekOfMonth: components.weekOfMonth!,
                targetSecsInDay: secsInDay, forward: forward, tz: tz)
        }

        if hasWdOrd {
            if hasMonth {
                return nextMonthWeekdayOrdinalMatch(
                    rd: rd, currentSecsInDay: currentSecsInDay, currentYear: year,
                    targetMonth: components.month!,
                    targetWeekday: components.weekday!,
                    targetWdOrd: components.weekdayOrdinal!,
                    targetSecsInDay: secsInDay, forward: forward, tz: tz)
            } else {
                return nextWeekdayOrdinalMatch(
                    rd: rd, currentSecsInDay: currentSecsInDay,
                    currentYear: year, currentCivilMonth: civilMonth, currentDay: day,
                    targetWeekday: components.weekday!,
                    targetWdOrd: components.weekdayOrdinal!,
                    targetSecsInDay: secsInDay, forward: forward, tz: tz)
            }
        }

        if hasWeekday {
            return nextWeekdayMatch(rd: rd, currentSecsInDay: currentSecsInDay,
                                    targetWeekday: components.weekday!,
                                    targetSecsInDay: secsInDay, forward: forward, tz: tz)
        }

        return nextMonthDayMatch(rd: rd, currentSecsInDay: currentSecsInDay,
                                 currentYear: year, currentCivilMonth: civilMonth, currentDay: day,
                                 targetMonth: components.month, targetDay: components.day,
                                 targetSecsInDay: secsInDay, forward: forward, tz: tz)
    }

    /// Fast path for `{month?, day?, h?, m?, s?, ns?}` — annual recurrence at month/day.
    /// Either month or day (or both) must be set; missing month iterates months in the
    /// year, missing day defaults to 1.
    private func nextMonthDayMatch(rd: Int64, currentSecsInDay: Double,
                                   currentYear: Int32, currentCivilMonth: UInt8, currentDay: UInt8,
                                   targetMonth: Int?, targetDay: Int?,
                                   targetSecsInDay: Double, forward: Bool,
                                   tz: TimeZone) -> Date? {
        // Build a candidate (year, civilMonth, day) from the request.
        // Returns nil if the candidate is invalid in this year (e.g., civil-6 in common year).
        func candidateRD(_ y: Int32, _ cm: UInt8, _ d: UInt8) -> Int64? {
            guard cm >= 1, cm <= 13 else { return nil }
            guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: cm) else { return nil }
            let dim = HebrewArithmetic.lastDayOfMonth(y, month: bib)
            let clamped = min(d, dim)
            return HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: clamped)
        }

        // Helper: produce a Date from RD + secsInDay, also checking strict-after-input.
        func makeDate(_ targetRd: Int64) -> Date {
            return utcDate(fromRataDie: targetRd, secondsInDay: targetSecsInDay, in: tz,
                          repeatedTimePolicy: .former, skippedTimePolicy: .former)
        }

        if let tm = targetMonth {
            // {month, day?, …} — annual; advance year on each non-match.
            guard tm >= 1, tm <= 13 else { return nil }
            let dayInTarget = UInt8(targetDay ?? 1)
            var targetYear = currentYear

            // Compare current Date to candidate-this-year. If forward and candidate <= input,
            // bump year; same idea backward.
            for _ in 0..<3 {   // at most ~3 iterations: this year, next, then leap-year skip
                if tm == 6 {
                    // Adar I — only exists in leap years.
                    while !HebrewArithmetic.isLeapYear(targetYear) {
                        targetYear += forward ? 1 : -1
                    }
                }
                guard let cRd = candidateRD(targetYear, UInt8(tm), dayInTarget) else { return nil }
                if forward {
                    if cRd > rd || (cRd == rd && targetSecsInDay > currentSecsInDay) {
                        return makeDate(cRd)
                    }
                    targetYear += 1
                } else {
                    if cRd < rd || (cRd == rd && targetSecsInDay < currentSecsInDay) {
                        return makeDate(cRd)
                    }
                    targetYear -= 1
                }
            }
            return nil
        }

        // {day, …} — no month → walk to next/prev civil month boundary.
        let dayInTarget = UInt8(targetDay!)   // hasDay guaranteed by caller (we checked above)
        if dayInTarget < 1 { return nil }

        if forward {
            // Try this month first if day strictly later (or same day with later time-of-day).
            if Int(dayInTarget) > Int(currentDay)
                || (Int(dayInTarget) == Int(currentDay) && targetSecsInDay > currentSecsInDay) {
                if let cRd = candidateRD(currentYear, currentCivilMonth, dayInTarget) {
                    return makeDate(cRd)
                }
            }
            // Else walk forward by months, take first that contains the day.
            var (y, m) = Self.nextCivilMonthForward(year: currentYear, civilMonth: currentCivilMonth)
            for _ in 0..<14 {   // bounded — Hebrew has at most 13 months/year
                if let cRd = candidateRD(y, m, dayInTarget) {
                    // Only accept if dayInTarget actually exists (no clamping on day-only walk).
                    guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: m) else { return nil }
                    if dayInTarget <= HebrewArithmetic.lastDayOfMonth(y, month: bib) {
                        return makeDate(cRd)
                    }
                }
                (y, m) = Self.nextCivilMonthForward(year: y, civilMonth: m)
            }
        } else {
            if Int(dayInTarget) < Int(currentDay)
                || (Int(dayInTarget) == Int(currentDay) && targetSecsInDay < currentSecsInDay) {
                if let cRd = candidateRD(currentYear, currentCivilMonth, dayInTarget) {
                    return makeDate(cRd)
                }
            }
            var (y, m) = Self.prevCivilMonthBackward(year: currentYear, civilMonth: currentCivilMonth)
            for _ in 0..<14 {
                if let cRd = candidateRD(y, m, dayInTarget) {
                    guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: m) else { return nil }
                    if dayInTarget <= HebrewArithmetic.lastDayOfMonth(y, month: bib) {
                        return makeDate(cRd)
                    }
                }
                (y, m) = Self.prevCivilMonthBackward(year: y, civilMonth: m)
            }
        }
        return nil
    }

    /// Fast path for `{h, mi, s, ns?}` — next date with the requested time-of-day.
    private func nextTimeOfDayMatch(rd: Int64, currentSecsInDay: Double,
                                    targetSecsInDay: Double,
                                    forward: Bool, tz: TimeZone) -> Date? {
        let targetRd: Int64
        if forward {
            targetRd = (targetSecsInDay > currentSecsInDay) ? rd : rd + 1
        } else {
            targetRd = (targetSecsInDay < currentSecsInDay) ? rd : rd - 1
        }
        return utcDate(fromRataDie: targetRd, secondsInDay: targetSecsInDay, in: tz,
                      repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    /// Fast path for `{weekday, h?, m?, s?, ns?}` — find the next/prev RD whose
    /// weekday matches (Sun=1..Sat=7, ICU convention). Pure modular RD arithmetic.
    private func nextWeekdayMatch(rd: Int64, currentSecsInDay: Double,
                                  targetWeekday: Int,
                                  targetSecsInDay: Double, forward: Bool,
                                  tz: TimeZone) -> Date? {
        guard targetWeekday >= 1, targetWeekday <= 7 else { return nil }

        // RD 1 = Monday. weekday(rd) where Sun=1..Sat=7:
        //   wday = ((rd % 7) + 7) % 7 gives 0..6 with 0=Sunday (since (RD 0 = Sun)).
        // To map to Sun=1..Sat=7: weekday = wday + 1.
        var wday = rd % 7
        if wday < 0 { wday += 7 }
        let currentWeekday = Int(wday) + 1     // 1..7

        let delta: Int64
        if currentWeekday == targetWeekday {
            // Same weekday: advance by a full week.
            delta = forward ? 7 : -7
        } else if forward {
            let raw = (targetWeekday - currentWeekday + 7) % 7   // 1..6
            delta = Int64(raw)
        } else {
            let raw = (currentWeekday - targetWeekday + 7) % 7   // 1..6
            delta = Int64(-raw)
        }

        let targetRd = rd + delta
        return utcDate(fromRataDie: targetRd, secondsInDay: targetSecsInDay, in: tz,
                      repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    /// Fast path for `{month, weekday, weekdayOrdinal}` — "Nth weekday of month".
    private func nextMonthWeekdayOrdinalMatch(
        rd: Int64, currentSecsInDay: Double, currentYear: Int32,
        targetMonth: Int, targetWeekday: Int, targetWdOrd: Int,
        targetSecsInDay: Double, forward: Bool, tz: TimeZone
    ) -> Date? {
        guard targetMonth >= 1, targetMonth <= 13 else { return nil }
        guard targetWeekday >= 1, targetWeekday <= 7 else { return nil }
        // Negative ordinals (e.g. "last Thursday") aren't supported by ICU's
        // enumerateDates matching contract — fall through to the generic framework
        // so behavior matches `_CalendarICU`.
        guard targetWdOrd >= 1 else { return nil }
        let cm = UInt8(targetMonth)

        // Compute the target day-of-month for the requested ordinal in (year, civilMonth).
        // Returns nil if the month doesn't exist this year (Adar I in common years) or
        // the ordinal is out of range (e.g. 5th Thursday in a 4-Thursday month).
        func dayForOrdinal(in y: Int32) -> (bib: UInt8, day: UInt8)? {
            if cm == 6 && !HebrewArithmetic.isLeapYear(y) { return nil }
            guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: cm) else { return nil }
            let firstRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: 1)
            var firstWd = firstRd % 7
            if firstWd < 0 { firstWd += 7 }
            let firstWeekday = Int(firstWd) + 1                              // 1..7
            let firstOcc = 1 + ((targetWeekday - firstWeekday + 7) % 7)      // 1..7
            let dim = Int(HebrewArithmetic.lastDayOfMonth(y, month: bib))
            let day = firstOcc + (targetWdOrd - 1) * 7
            guard day >= 1, day <= dim else { return nil }
            return (bib, UInt8(day))
        }

        // Bounded year iteration. Hebrew leap-cycle gap is at most 3 years, so 6
        // iterations always reach a leap year for Adar I requests.
        var y = currentYear
        for _ in 0..<6 {
            if let (bib, d) = dayForOrdinal(in: y) {
                let cRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: d)
                if forward {
                    if cRd > rd || (cRd == rd && targetSecsInDay > currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                } else {
                    if cRd < rd || (cRd == rd && targetSecsInDay < currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                }
            }
            y += forward ? 1 : -1
        }
        return nil
    }

    /// Fast path for `{weekday, weekdayOrdinal}` (no month) — Nth weekday in the current month.
    private func nextWeekdayOrdinalMatch(
        rd: Int64, currentSecsInDay: Double,
        currentYear: Int32, currentCivilMonth: UInt8, currentDay: UInt8,
        targetWeekday: Int, targetWdOrd: Int,
        targetSecsInDay: Double, forward: Bool, tz: TimeZone
    ) -> Date? {
        guard targetWeekday >= 1, targetWeekday <= 7 else { return nil }
        guard targetWdOrd >= 1 else { return nil }

        // Day-of-month for (weekday, ordinal) in a given month, or nil if out of range.
        func dayForOrdinal(year y: Int32, civilMonth cm: UInt8) -> (bib: UInt8, day: UInt8)? {
            if cm == 6 && !HebrewArithmetic.isLeapYear(y) { return nil }
            guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: cm) else { return nil }
            let firstRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: 1)
            var firstWd = firstRd % 7
            if firstWd < 0 { firstWd += 7 }
            let firstWeekday = Int(firstWd) + 1                              // 1..7
            let firstOcc = 1 + ((targetWeekday - firstWeekday + 7) % 7)      // 1..7
            let dim = Int(HebrewArithmetic.lastDayOfMonth(y, month: bib))
            let day = firstOcc + (targetWdOrd - 1) * 7
            guard day >= 1, day <= dim else { return nil }
            return (bib, UInt8(day))
        }

        // Walk months until we find the target ordinal in range.
        var y = currentYear
        var cm = currentCivilMonth
        for _ in 0..<14 {
            if let (bib, d) = dayForOrdinal(year: y, civilMonth: cm) {
                let cRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: d)
                if forward {
                    if cRd > rd || (cRd == rd && targetSecsInDay > currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                } else {
                    if cRd < rd || (cRd == rd && targetSecsInDay < currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                }
            }
            // Advance / retreat civil month.
            if forward {
                (y, cm) = Self.nextCivilMonthForward(year: y, civilMonth: cm)
            } else {
                (y, cm) = Self.prevCivilMonthBackward(year: y, civilMonth: cm)
            }
        }
        return nil
    }

    /// Fast path for `{month, weekday, weekOfMonth}` — "weekday in Nth week of month".
    private func nextMonthWeekdayWeekOfMonthMatch(
        rd: Int64, currentSecsInDay: Double, currentYear: Int32,
        targetMonth: Int, targetWeekday: Int, targetWeekOfMonth: Int,
        targetSecsInDay: Double, forward: Bool, tz: TimeZone
    ) -> Date? {
        guard targetMonth >= 1, targetMonth <= 13 else { return nil }
        guard targetWeekday >= 1, targetWeekday <= 7 else { return nil }
        guard targetWeekOfMonth >= 1 else { return nil }
        let cm = UInt8(targetMonth)
        let firstWd = self.firstWeekday
        let minDays = self.minimumDaysInFirstWeek
        let dayOffsetInWeek = ((targetWeekday - firstWd) % 7 + 7) % 7   // 0..6

        // Day-of-month for (weekOfMonth, weekday) in a given year, or nil if out of range.
        func dayForWeekOfMonth(in y: Int32) -> (bib: UInt8, day: UInt8)? {
            if cm == 6 && !HebrewArithmetic.isLeapYear(y) { return nil }
            guard let bib = HebrewArithmetic.civilToBiblical(year: y, civilMonth: cm) else { return nil }
            let firstDayRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: 1)
            var firstDayWd = firstDayRd % 7
            if firstDayWd < 0 { firstDayWd += 7 }
            let firstDayWeekday = Int(firstDayWd) + 1                             // 1..7
            let periodStart = ((firstDayWeekday - firstWd) % 7 + 7) % 7           // 0..6 (offset of day 1 within its week)
            let correction = (7 - periodStart) >= minDays ? 1 : 0
            let day = 7 * (targetWeekOfMonth - correction) + dayOffsetInWeek - periodStart + 1
            let dim = Int(HebrewArithmetic.lastDayOfMonth(y, month: bib))
            guard day >= 1, day <= dim else { return nil }
            return (bib, UInt8(day))
        }

        var y = currentYear
        for _ in 0..<6 {
            if let (bib, d) = dayForWeekOfMonth(in: y) {
                let cRd = HebrewArithmetic.fixedFromHebrew(year: y, month: bib, day: d)
                if forward {
                    if cRd > rd || (cRd == rd && targetSecsInDay > currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                } else {
                    if cRd < rd || (cRd == rd && targetSecsInDay < currentSecsInDay) {
                        return utcDate(fromRataDie: cRd, secondsInDay: targetSecsInDay, in: tz,
                                       repeatedTimePolicy: .former, skippedTimePolicy: .former)
                    }
                }
            }
            y += forward ? 1 : -1
        }
        return nil
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        var result = DateComponents()
        var curr = start

        for component in Self.orderedDiffComponents(components) {
            let (diff, newCurr) = difference(inComponent: component, from: curr, to: end)
            result.setValue(diff, for: component)
            curr = newCurr
        }
        return result
    }

    /// Components in subtraction order (largest first, matching `_CalendarGregorian`).
    private static func orderedDiffComponents(_ components: Calendar.ComponentSet) -> [Calendar.Component] {
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

    /// Returns (diff, newStart) where diff is the integer number of `component` units
    /// that fit between `start` and `end` (sign matches direction), and newStart is
    /// start advanced by that many units (staying at-or-before `end`).
    private func difference(inComponent component: Calendar.Component, from start: Date, to end: Date) -> (Int, Date) {
        if start == end { return (0, start) }

        // Fast path for time components — direct TimeInterval arithmetic.
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
        case .era:
            // Hebrew has a single era; difference is always 0.
            return (0, start)
        default:
            break
        }

        // Calendar-level components: bisect-style search using cumulative add from `start`.
        // IMPORTANT: each trial is `start + n * component`, not iterative `current + 1`.
        // The cumulative form avoids day-clamp accumulation across month boundaries.
        // Example: from AdarI-30, iterative +1 month → AdarII-29 (clamped) → Nisan-29 (preserved-from-clamp).
        // Cumulative +2 months → Nisan-30 (clamps from original day=30 to Nisan's max=30, fits).
        // Matches ICU's diff iteration; the iterative form was producing 1-day drift across DST/leap edges.
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
                // Component didn't advance (e.g., `.quarter` for Hebrew is a no-op).
                break
            }
            let overshoot = forward ? (nextStep > end) : (nextStep < end)
            if overshoot { break }
            current = nextStep
            diff = trial

            // Safety bound in case of pathological inputs.
            safety += 1
            if safety > 1_000_000 { break }
        }
        return (diff, current)
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        fatalError("TODO: bridgeToNSCalendar")
    }
#endif
}

// MARK: - Hebrew calendrical arithmetic (Reingold & Dershowitz)

/// Low-level arithmetic for the Hebrew calendar.
///
/// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018).
/// All algorithms work in biblical month numbering (Nisan = 1, Tishri = 7);
/// civil ordering (Tishri = 1) is converted at the boundary.
internal enum HebrewArithmetic {

    /// Hebrew epoch: Tishri 1 of year 1 AM = R.D. -1,373,427
    /// (= proleptic Julian year -3760, October 7).
    static let epoch: Int64 = -1_373_427

    // Biblical month ordinals.
    static let NISAN: UInt8 = 1
    static let IYYAR: UInt8 = 2
    static let SIVAN: UInt8 = 3
    static let TAMMUZ: UInt8 = 4
    static let AV: UInt8 = 5
    static let ELUL: UInt8 = 6
    static let TISHRI: UInt8 = 7
    static let MARHESHVAN: UInt8 = 8
    static let KISLEV: UInt8 = 9
    static let TEVET: UInt8 = 10
    static let SHEVAT: UInt8 = 11
    static let ADAR: UInt8 = 12
    static let ADARII: UInt8 = 13

    // MARK: Leap Year (Metonic 19-year cycle)

    /// Whether a Hebrew year is a leap year (13 months).
    /// Leap positions in the 19-year cycle: 3, 6, 8, 11, 14, 17, 19.
    static func isLeapYear(_ year: Int32) -> Bool {
        var r = (7 &* Int64(year) &+ 1) % 19
        if r < 0 { r += 19 }
        return r < 7
    }

    static func monthsInYear(_ year: Int32) -> UInt8 {
        isLeapYear(year) ? 13 : 12
    }

    // MARK: Floor Division

    /// Floor division — always rounds toward negative infinity.
    /// Swift's `/` truncates toward zero, which disagrees with R&D's algorithms
    /// for negative numerators (silently produces wrong results for very
    /// negative years).
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        if (a >= 0) == (b > 0) {
            return a / b
        } else {
            return (a &- b &+ 1) / b
        }
    }

    // MARK: Elapsed Days (Molad Arithmetic)

    /// Days elapsed from the epoch to the start of the given Hebrew year,
    /// with all four dehiyot (Lo ADU, Molad Zaken, Gatarad, Betutakpat) applied inline.
    static func calendarElapsedDays(_ year: Int32) -> Int64 {
        let monthsElapsed = floorDiv(235 &* Int64(year) &- 234, 19)
        let partsElapsed = 12084 &+ 13753 &* monthsElapsed
        var days = 29 &* monthsElapsed &+ floorDiv(partsElapsed, 25920)
        var frac = partsElapsed % 25920
        if frac < 0 { frac &+= 25920 }

        // wd numbering matches ICU: 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun.
        var wd = days % 7
        if wd < 0 { wd &+= 7 }

        if wd == 2 || wd == 4 || wd == 6 {
            // Lo ADU Rosh: postpone Sun/Wed/Fri RH by 1 day.
            days &+= 1
            wd = days % 7
            if wd < 0 { wd &+= 7 }
        }
        // Separate `if` (not else-if) — Lo ADU's shift can chain into Betutakpat.
        if wd == 1 && frac > 15 &* 1080 &+ 204 && !isLeapYear(year) {
            // Gatarad: common year, molad after 9:11:20.6 AM Tuesday → prevent 356-day year.
            days &+= 2
        } else if wd == 0 && frac > 21 &* 1080 &+ 589 && isLeapYear(year &- 1) {
            // Betutakpat: year after leap, molad after 15:32:43.6 AM Monday → prevent 382-day year.
            days &+= 1
        }
        return days
    }

    /// Fixed date of Tishri 1 (Hebrew New Year) for the given year.
    static func newYear(_ year: Int32) -> Int64 {
        return epoch &+ calendarElapsedDays(year)
    }

    // MARK: YearData (cached per conversion)

    /// Single-slot YearData cache.
    private static let _yearDataCache = Mutex<YearData?>(nil)

    /// Returns cached `YearData` if available, otherwise computes and caches it.
    internal static func yearData(_ year: Int32) -> YearData {
        if let yd = _yearDataCache.withLock({ $0 }), yd.year == year {
            return yd
        }
        let fresh = YearData(year: year)
        _yearDataCache.withLock { $0 = fresh }
        return fresh
    }

    /// Precomputed year-level metadata cached to avoid repeated molad arithmetic.
    struct YearData {
        let year: Int32
        let newYear: Int64
        let yearLen: Int32          // 353..385
        let isLeap: Bool
        let longMarheshvan: Bool    // Marheshvan 30d
        let shortKislev: Bool       // Kislev 29d

        init(year: Int32) {
            self.year = year
            // calendarElapsedDays now applies all four dehiyot inline (matching
            // ICU's startOfYear), so no post-hoc correction is needed here.
            let ny1 = HebrewArithmetic.calendarElapsedDays(year)
            let ny2 = HebrewArithmetic.calendarElapsedDays(year + 1)
            self.newYear = HebrewArithmetic.epoch &+ ny1
            self.yearLen = Int32(ny2 &- ny1)

            self.isLeap = HebrewArithmetic.isLeapYear(year)
            self.longMarheshvan = self.yearLen == 355 || self.yearLen == 385
            self.shortKislev = self.yearLen == 353 || self.yearLen == 383
        }

        /// Days in a biblical-month within this year.
        func lastDayOfMonth(_ month: UInt8) -> UInt8 {
            switch month {
            case HebrewArithmetic.IYYAR, HebrewArithmetic.TAMMUZ,
                 HebrewArithmetic.ELUL, HebrewArithmetic.TEVET,
                 HebrewArithmetic.ADARII:
                return 29
            case HebrewArithmetic.ADAR:
                return isLeap ? 30 : 29
            case HebrewArithmetic.MARHESHVAN:
                return longMarheshvan ? 30 : 29
            case HebrewArithmetic.KISLEV:
                return shortKislev ? 29 : 30
            default:
                // NISAN, SIVAN, AV, TISHRI, SHEVAT
                return 30
            }
        }

        var lastMonthOfYear: UInt8 {
            isLeap ? HebrewArithmetic.ADARII : HebrewArithmetic.ADAR
        }
    }

    // MARK: Year / Month Queries

    static func daysInYear(_ year: Int32) -> UInt16 {
        UInt16(yearData(year).yearLen)
    }

    static func isLongMarheshvan(_ year: Int32) -> Bool {
        yearData(year).longMarheshvan
    }

    static func isShortKislev(_ year: Int32) -> Bool {
        yearData(year).shortKislev
    }

    static func lastDayOfMonth(_ year: Int32, month: UInt8) -> UInt8 {
        yearData(year).lastDayOfMonth(month)
    }

    // MARK: Fixed ↔ Hebrew Conversion (biblical month ordering)

    static func fixedFromHebrew(year: Int32, month: UInt8, day: UInt8) -> Int64 {
        let yd = yearData(year)
        return fixedFromHebrew(yearData: yd, month: month, day: day)
    }

    static func fixedFromHebrew(yearData yd: YearData, month: UInt8, day: UInt8) -> Int64 {
        var totalDays: Int64 = yd.newYear &+ Int64(day) &- 1
        if month < TISHRI {
            // Add Tishri..lastMonth, then Nisan..(month-1)
            let last = yd.lastMonthOfYear
            var m: UInt8 = TISHRI
            while m <= last {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
            m = NISAN
            while m < month {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
        } else {
            var m: UInt8 = TISHRI
            while m < month {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
        }
        return totalDays
    }

    static func hebrewFromFixed(_ date: Int64) -> (year: Int32, month: UInt8, day: UInt8) {
        // Approximate year using average Hebrew year length. Must err low.
        let dayDelta = date &- epoch
        let approx = Int32(1 &+ floorDiv(dayDelta &* 98496, 35975351))

        var year = approx - 1
        while newYear(year + 1) <= date {
            year += 1
        }

        let yd = yearData(year)
        var rem = Int(date &- yd.newYear)

        // Civil month order for biblical months:
        //   common year: Tishri (7), Marheshvan (8) ... Adar (12), Nisan (1) ... Elul (6)
        //   leap year:   Tishri (7), ... Adar (12), AdarII (13), Nisan (1), ... Elul (6)
        var m: UInt8 = TISHRI
        let last = yd.lastMonthOfYear
        while m <= last {
            let len = Int(yd.lastDayOfMonth(m))
            if rem < len {
                return (year, m, UInt8(rem + 1))
            }
            rem -= len
            m &+= 1
        }

        m = NISAN
        while m < TISHRI {
            let len = Int(yd.lastDayOfMonth(m))
            if rem < len {
                return (year, m, UInt8(rem + 1))
            }
            rem -= len
            m &+= 1
        }

        // Unreachable for a valid in-range date.
        return (year, ELUL, UInt8(rem + 1))
    }

    // MARK: Civil ↔ Biblical Month Conversion
    //
    // Foundation's public `.hebrew` calendar uses **stable** (ICU-style) month
    // numbering, not the dense ordering. Month numbers are:
    //
    //   1 = Tishrei     8 = Nisan
    //   2 = Cheshvan    9 = Iyyar
    //   3 = Kislev     10 = Sivan
    //   4 = Tevet      11 = Tammuz
    //   5 = Shevat     12 = Av
    //   6 = Adar I  ←  only exists in leap years; INVALID in common years.
    //   7 = Adar (common) / Adar II (leap)
    //  13 = Elul
    //
    // So common years have 12 months numbered {1,2,3,4,5,7,8,9,10,11,12,13}
    // (month 6 skipped), and leap years have 13 months {1..13}. This keeps
    // Nisan = 8, Elul = 13 constant across common and leap years, which is
    // what ICU does and what `DateComponents.month` returns.

    /// Convert biblical month → civil month (stable / ICU numbering).
    static func biblicalToCivil(year: Int32, biblicalMonth: UInt8) -> UInt8 {
        let leap = isLeapYear(year)
        switch biblicalMonth {
        case TISHRI: return 1
        case MARHESHVAN: return 2
        case KISLEV: return 3
        case TEVET: return 4
        case SHEVAT: return 5
        case ADAR: return leap ? 6 : 7   // Adar I in leap; plain Adar in common.
        case ADARII: return 7            // leap year only
        case NISAN: return 8
        case IYYAR: return 9
        case SIVAN: return 10
        case TAMMUZ: return 11
        case AV: return 12
        case ELUL: return 13
        default: return 0
        }
    }

    /// Convert civil month (stable / ICU numbering) → biblical month.
    /// Returns `nil` if the civil month doesn't exist in this year
    /// (i.e., civil month 6 / "Adar I" in a common year).
    static func civilToBiblical(year: Int32, civilMonth: UInt8) -> UInt8? {
        let leap = isLeapYear(year)
        switch civilMonth {
        case 1: return TISHRI
        case 2: return MARHESHVAN
        case 3: return KISLEV
        case 4: return TEVET
        case 5: return SHEVAT
        case 6: return leap ? ADAR : nil      // Adar I (leap only)
        case 7: return leap ? ADARII : ADAR
        case 8: return NISAN
        case 9: return IYYAR
        case 10: return SIVAN
        case 11: return TAMMUZ
        case 12: return AV
        case 13: return ELUL
        default: return nil
        }
    }

    /// Days in a civil-ordered month. Returns 0 for the invalid civil-6 slot in common years.
    static func daysInCivilMonth(year: Int32, civilMonth: UInt8) -> UInt8 {
        guard let biblical = civilToBiblical(year: year, civilMonth: civilMonth) else {
            return 0
        }
        return lastDayOfMonth(year, month: biblical)
    }

    /// Days preceding a civil-ordered month in its year (for day-of-year).
    /// Skips civil-6 in common years (where it doesn't exist).
    static func daysPrecedingCivilMonth(year: Int32, civilMonth: UInt8) -> UInt16 {
        let yd = yearData(year)
        var total: UInt16 = 0
        for m: UInt8 in 1..<civilMonth {
            if let biblical = civilToBiblical(year: year, civilMonth: m) {
                total += UInt16(yd.lastDayOfMonth(biblical))
            }
            // else: no-such-month slot — contribute 0 days.
        }
        return total
    }
}
