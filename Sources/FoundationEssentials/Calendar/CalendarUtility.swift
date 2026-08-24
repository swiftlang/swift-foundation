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

/// Static helpers shared by `_CalendarProtocol` conformers.
internal enum _CalendarUtility {

    // MARK: - firstWeekday

    /// Validates a `firstWeekday` value (must be 1...7).
    static func validatedFirstWeekday(_ value: Int) -> Int {
        precondition(value >= 1 && value <= 7, "Weekday should be in the range of 1...7")
        return value
    }

    /// Resolves `firstWeekday`: stored value → locale preference → 1 (Sunday).
    static func resolveFirstWeekday(stored: Int?, locale: Locale?) -> Int {
        if let stored {
            return stored
        } else if let locale {
            return locale.firstDayOfWeek.icuIndex
        } else {
            return 1
        }
    }

    // MARK: - minimumDaysInFirstWeek

    /// Clamps `minimumDaysInFirstWeek` to 1...7.
    static func clampedMinimumDaysInFirstWeek(_ value: Int) -> Int {
        if value < 1 { return 1 }
        if value > 7 { return 7 }
        return value
    }

    /// Resolves `minimumDaysInFirstWeek`: stored value → locale preference → 1.
    static func resolveMinimumDaysInFirstWeek(stored: Int?, locale: Locale?) -> Int {
        if let stored {
            return stored
        } else if let locale {
            return locale.minimumDaysInFirstWeek
        } else {
            return 1
        }
    }

    // MARK: - copy()

    /// Resolves `copy(...)` arguments: override if supplied, else current value.
    static func resolvedCopyArgs(
        currentTimeZone: TimeZone, changingTimeZone: TimeZone?,
        currentLocale: Locale?, changingLocale: Locale?,
        currentFirstWeekday: Int?, changingFirstWeekday: Int?,
        currentMinimumDaysInFirstWeek: Int?, changingMinimumDaysInFirstWeek: Int?
    ) -> (timeZone: TimeZone, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?) {
        let newTimeZone = changingTimeZone ?? currentTimeZone
        let newLocale = changingLocale ?? currentLocale
        let newFirstWeekday: Int? = changingFirstWeekday ?? currentFirstWeekday
        let newMinDays: Int? = changingMinimumDaysInFirstWeek ?? currentMinimumDaysInFirstWeek
        return (newTimeZone, newLocale, newFirstWeekday, newMinDays)
    }

    // MARK: - isDateInWeekend

    /// Whether `weekday` + `timeInDay` falls within `weekendRange`.
    static func isDateInWeekend(weekday: Int, timeInDay: TimeInterval, weekendRange: WeekendRange) -> Bool {
        if weekendRange.start == weekendRange.end && weekday != weekendRange.start {
            return false
        } else if weekendRange.start < weekendRange.end && (weekday < weekendRange.start || weekday > weekendRange.end) {
            return false
        } else if weekendRange.start > weekendRange.end && (weekday > weekendRange.end && weekday < weekendRange.start) {
            return false
        }

        if weekday == weekendRange.start {
            guard let onsetTime = weekendRange.onsetTime, onsetTime != 0 else {
                return true
            }
            return timeInDay >= onsetTime
        } else if weekday == weekendRange.end {
            guard let ceaseTime = weekendRange.ceaseTime, ceaseTime < 86400 else {
                return true
            }
            return timeInDay < ceaseTime
        } else {
            return true
        }
    }

    /// Default weekend range (region 001): Sat–Sun, full day.
    static let defaultWeekendRange = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1)

    // MARK: - hash(into:)

    /// Combines exactly the state that `Calendar`'s `==` compares, so calendars that compare equal always hash equally.
    ///
    /// Hashing the stored `firstWeekday` instead of the resolved one breaks that, because an unset value and an explicitly set one that resolves to the same number compare equal.
    static func hash<CalendarType: _CalendarProtocol>(_ calendar: CalendarType, into hasher: inout Hasher) {
        hasher.combine(calendar.identifier)
        hasher.combine(calendar.timeZone)
        hasher.combine(calendar.firstWeekday)
        hasher.combine(calendar.minimumDaysInFirstWeek)
        hasher.combine(calendar.localeIdentifier)
        hasher.combine(calendar.preferredFirstWeekday)
        hasher.combine(calendar.preferredMinimumDaysInFirstweek)
    }

    /// Whether `date` falls in the weekend, for any calendar that can report a weekday and a time of day.
    static func isDateInWeekend<CalendarType: _CalendarProtocol>(_ date: Date, in calendar: CalendarType) -> Bool {
        let weekendRange = calendar.locale?.weekendRange ?? defaultWeekendRange
        let components = calendar.dateComponents([.weekday, .hour, .minute, .second], from: date, in: calendar.timeZone)
        guard let weekday = components.weekday else { return false }
        let timeInDay = TimeInterval((components.hour ?? 0) * Calendar._secondsInHour + (components.minute ?? 0) * Calendar._secondsInMinute + (components.second ?? 0))
        return isDateInWeekend(weekday: weekday, timeInDay: timeInDay, weekendRange: weekendRange)
    }

    // MARK: - Rata die arithmetic (shared by the non-ICU calendars)

    /// Rata die of the Foundation reference date (2001-01-01 == RD 730486).
    static let rataDieAtDateReference = 730_486

    /// Floor division rounding toward negative infinity for any sign of divisor.
    static func floorDiv<I: FixedWidthInteger>(_ a: I, _ b: I) -> I {
        if (a >= 0) == (b > 0) {
            return a / b
        } else {
            return (a &- b &+ 1) / b
        }
    }

    /// Splits local-seconds-since-reference into a fixed-day rata die and the seconds within that day.
    static func rataDieAndSecondsInDay<I: FixedWidthInteger>(localSeconds: Double) -> (rataDie: I, secondsInDay: Double) {
        let totalDays = (localSeconds / 86400).rounded(.down)
        let rataDie = I(totalDays) &+ I(rataDieAtDateReference)
        let secondsInDay = localSeconds - totalDays * 86400
        return (rataDie, secondsInDay)
    }

    /// Builds a UTC `Date` from a fixed-day rata die plus local seconds within the day, subtracting the time zone offset at that local instant.
    static func utcDate<I: FixedWidthInteger>(fromRataDie rataDie: I, secondsInDay: Double, in timeZone: TimeZone,
                                              repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy,
                                              skippedTimePolicy: TimeZone.DaylightSavingTimePolicy) -> Date {
        _ = skippedTimePolicy   // silenced — a fixed-day representation cannot land in a skipped interval
        let daysSinceRef = rataDie &- I(rataDieAtDateReference)
        let secondsAsIfUTC = Double(daysSinceRef) * 86400 + secondsInDay
        let tmpDate = Date(timeIntervalSinceReferenceDate: secondsAsIfUTC)
        let (tzOffset, dstOffset) = timeZone.rawAndDaylightSavingTimeOffset(
            for: tmpDate, repeatedTimePolicy: repeatedTimePolicy)
        return tmpDate - Double(tzOffset) - dstOffset
    }

    /// Week-of-period number using the ICU algorithm, shared across calendars.
    static func weekNumber(desiredDay: Int, dayOfPeriod: Int, weekday: Int,
                           firstWeekday: Int, minimumDaysInFirstWeek: Int) -> Int {
        var periodStartDayOfWeek = (weekday - firstWeekday - dayOfPeriod + 1) % 7
        if periodStartDayOfWeek < 0 { periodStartDayOfWeek += 7 }
        var weekNo = (desiredDay + periodStartDayOfWeek - 1) / 7
        if (7 - periodStartDayOfWeek) >= minimumDaysInFirstWeek {
            weekNo += 1
        }
        return weekNo
    }
}
