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
    static func isDateInWeekend(weekday: Int, timeInDay: TimeInterval,
                                 weekendRange: WeekendRange) -> Bool {
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
}
