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

    /// Moves a date by whole days and keeps the time on the wall clock. Returns nil if the day count overflows.
    /// A time that the new day skips lands after the gap.
    /// A repeated time is the first one when moving forward and the last one when moving back.
    static func date(byAddingDays days: Int, to date: Date, in timeZone: TimeZone) -> Date? {
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: date))
        let (rataDie, secondsInDay): (Int, Double) = rataDieAndSecondsInDay(localSeconds: localSeconds)
        let (moved, overflow) = rataDie.addingReportingOverflow(days)
        guard !overflow else { return nil }
        return utcDate(fromRataDie: moved, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: days > 0 ? .former : .latter, skippedTimePolicy: .former)
    }

    /// The whole part of a count of units, limited to the range of Int so that a huge difference does not trap.
    static func truncatedInt(_ value: Double) -> Int {
        let whole = value.rounded(.towardZero)
        if whole >= Double(Int.max) { return Int.max }
        if whole <= Double(Int.min) { return Int.min }
        return Int(whole)
    }

    /// The value `value + amount`, wrapped into 0..<count.
    static func wrapped(_ value: Int, by amount: Int, count: Int) -> Int {
        ((value + amount % count) % count + count) % count
    }

    /// Rolls the hour, the minute or the second of a date. The roll counts elapsed time.
    /// When the value wraps forward, the count starts at the first instant of the wall clock day, hour or minute.
    /// So a change of the offset on the way does not move the result to another wall clock time.
    static func rolledTimeUnit(_ field: Calendar.Component, by amount: Int, from date: Date, in timeZone: TimeZone) -> Date {
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: date))
        let (rataDie, secondsInDay): (Int, Double) = rataDieAndSecondsInDay(localSeconds: localSeconds)
        let value: Int, limit: Int, length: Double
        switch field {
        case .hour: (value, limit, length) = (Int(secondsInDay / Double(Calendar._secondsInHour)), 24, Double(Calendar._secondsInHour))
        case .minute: (value, limit, length) = (Int(secondsInDay / 60) % 60, 60, 60)
        default: (value, limit, length) = (Int(secondsInDay) % 60, 60, 1)
        }
        let newValue = wrapped(value, by: amount, count: limit)
        guard newValue < value, amount > 0 else { return date + Double(newValue - value) * length }
        let largerLength = length * Double(limit)
        let start = utcDate(fromRataDie: rataDie, secondsInDay: (secondsInDay / largerLength).rounded(.down) * largerLength, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
        return start + Double(newValue) * length + secondsInDay.truncatingRemainder(dividingBy: length)
    }

    /// A date moved by whole elapsed days of 24 hours. When moving forward, a result in a repeated hour is the first occurrence.
    static func moved(_ date: Date, byElapsedDays days: Int, forward: Bool, in timeZone: TimeZone) -> Date {
        let result = date + Double(days) * Double(Calendar._secondsInDay)
        guard forward else { return result }
        let localSeconds = result.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: result))
        let (rataDie, secondsInDay): (Int, Double) = rataDieAndSecondsInDay(localSeconds: localSeconds)
        return utcDate(fromRataDie: rataDie, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    /// Rolls the position of a day inside a month or a year by whole weeks. Returns nil if the period has no week that counts.
    /// The roll adds days outside the period to the first and the last week, so that every week is whole.
    /// A result outside the period moves to its first or last day.
    static func rolledWeekPosition(_ position: Int, length: Int, weekdayOffset: Int, by amount: Int, minimumDaysInFirstWeek: Int) -> Int? {
        let firstOfPeriod = ((weekdayOffset - position + 1) % 7 + 7) % 7
        let start = (7 - firstOfPeriod) < minimumDaysInFirstWeek ? 8 - firstOfPeriod : 1 - firstOfPeriod
        let lastOfPeriod = (length - position + weekdayOffset) % 7
        let gap = length + 7 - lastOfPeriod - start
        guard gap > 0 else { return nil }
        return min(max(wrapped(position - start, by: amount % gap * 7, count: gap) + start, 1), length)
    }

    /// The day of the month that a weekday ordinal names, counted from 1 and possibly outside the month. A negative ordinal counts from the end of the month.
    static func dayOfMonth(weekdayOrdinal ordinal: Int, weekdayOffset: Int, monthStartOffset: Int, monthLength: Int) -> Int {
        var day = weekdayOffset - monthStartOffset + 1
        if day < 1 { day += 7 }
        return ordinal >= 0 ? day + (ordinal - 1) * 7 : day + ((monthLength - day) / 7 + ordinal + 1) * 7
    }

    /// The day of the month for a weekday in a week of the month. It is counted from 1 and can be outside the month. A first week with fewer days than the minimum does not count.
    static func dayOfMonth(weekOfMonth week: Int, weekdayOffset: Int, monthStartOffset: Int, minimumDaysInFirstWeek: Int) -> Int {
        let firstWeekShift = 7 - monthStartOffset < minimumDaysInFirstWeek ? 7 : 0
        return weekdayOffset - monthStartOffset + 1 + firstWeekShift + (week - 1) * 7
    }

    /// The elapsed days to move for a roll of the weekday, the weekday ordinal or the day of the year. The roll wraps inside the week, the month or the year. Returns nil for any other field.
    static func daysToRoll(_ field: Calendar.Component, by amount: Int, weekdayOffset: Int, dayOfMonth: Int, monthLength: Int, dayOfYear: Int, yearLength: Int) -> Int? {
        switch field {
        case .weekday:
            return wrapped(weekdayOffset, by: amount, count: 7) - weekdayOffset
        case .weekdayOrdinal:
            let weeksBefore = (dayOfMonth - 1) / 7
            return (wrapped(weeksBefore, by: amount, count: weeksBefore + (monthLength - dayOfMonth) / 7 + 1) - weeksBefore) * 7
        case .dayOfYear:
            return wrapped(dayOfYear - 1, by: amount, count: yearLength) + 1 - dayOfYear
        default:
            return nil
        }
    }

    /// The days that the day, day of year, week and weekday fields of a date components value add up to. Returns nil if the sum overflows.
    static func dayCount(of components: DateComponents) -> Int? {
        var total = 0
        for (value, factor) in [(components.day, 1), (components.dayOfYear, 1), (components.weekOfMonth, 7), (components.weekOfYear, 7), (components.weekdayOrdinal, 7), (components.weekday, 1)] {
            guard let value else { continue }
            let (days, multiplyOverflow) = value.multipliedReportingOverflow(by: factor)
            let (sum, addOverflow) = total.addingReportingOverflow(days)
            guard !multiplyOverflow, !addOverflow else { return nil }
            total = sum
        }
        return total
    }

    /// The largest count of a unit that moves `start` toward `end` without passing it, and `start` moved by that count. The count is 0 if the unit does not move the date.
    /// `shifted` adds a count to `start`, or gives nil if the count is too large.
    static func differenceBySearch(from start: Date, to end: Date, shifted: (Int) -> Date?) -> (difference: Int, advancedDate: Date) {
        let forward = end > start
        func isPastEnd(_ date: Date) -> Bool { forward ? date > end : date < end }
        var good = 0
        var goodDate = start
        var bad = forward ? 1 : -1
        while true {
            guard let trial = shifted(bad), !isPastEnd(trial) else { break }
            if trial == start { return (0, start) }
            good = bad
            goodDate = trial
            if trial == end { return (good, goodDate) }
            guard abs(bad) < Int.max / 4 else { return (good, goodDate) }
            bad *= 2
        }
        while abs(bad - good) > 1 {
            let middle = good + (bad - good) / 2
            if let trial = shifted(middle), !isPastEnd(trial) {
                good = middle
                goodDate = trial
                if trial == end { break }
            } else {
                bad = middle
            }
        }
        return (good, goodDate)
    }

    /// The interval of the hour, minute, second or nanosecond that holds a date. Returns nil for any other component.
    static func timeUnitInterval(of component: Calendar.Component, for date: Date, in timeZone: TimeZone) -> DateInterval? {
        let time = date.timeIntervalSinceReferenceDate
        switch component {
        case .hour:
            let offset = Double(timeZone.secondsFromGMT(for: date))
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: ((time + offset) / Double(Calendar._secondsInHour)).rounded(.down) * Double(Calendar._secondsInHour) - offset), duration: Double(Calendar._secondsInHour))
        case .minute:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: (time / 60.0).rounded(.down) * 60.0), duration: 60.0)
        case .second:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: time.rounded(.down)), duration: 1.0)
        case .nanosecond:
            return DateInterval(start: date, duration: 1e-9)
        default:
            return nil
        }
    }

    /// The whole count of hours, minutes, seconds or nanoseconds from one date to another, and the start moved by that count.
    /// Returns nil for any other component. Like the Gregorian calendar, the count of nanoseconds stays in the range of Int32.
    static func timeUnitDifference(in component: Calendar.Component, from start: Date, to end: Date) -> (difference: Int, advancedDate: Date)? {
        let seconds = end.timeIntervalSince(start)
        let unit: Double
        switch component {
        case .hour: unit = Double(Calendar._secondsInHour)
        case .minute: unit = 60
        case .second: unit = 1
        case .nanosecond:
            let count = truncatedInt(min(max(seconds * 1_000_000_000, Double(Int32.min)), Double(Int32.max)).rounded())
            return (count, start.addingTimeInterval(Double(count) / 1_000_000_000))
        default:
            return nil
        }
        let count = truncatedInt(seconds / unit)
        return (count, start.addingTimeInterval(Double(count) * unit))
    }

    /// Foundation weekday numbering (1 = Sunday) of a rata die. Rata die 1 was a Monday.
    static func weekday(ofRataDie rataDie: Int) -> Int {
        (rataDie % 7 + 7) % 7 + 1
    }

    /// The components of a difference, from the largest to the smallest.
    static func orderedDifferenceComponents(_ components: Calendar.ComponentSet) -> [Calendar.Component] {
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

    /// The ranges of the smaller unit in each month of the larger unit, added up. Stops after 15 months.
    static func rangeOverMonths<Implementation: _CalendarProtocol>(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date, in calendar: Implementation) -> Range<Int>? {
        guard let interval = calendar.dateInterval(of: larger, for: date) else { return nil }
        let end = interval.end - 1
        var current = interval.start + 1
        var result: Range<Int>?
        for _ in 0..<15 {
            guard let month = calendar.dateInterval(of: .month, for: current),
                  let first = calendar.ordinality(of: smaller, in: .month, for: month.start + 0.1),
                  let last = calendar.ordinality(of: smaller, in: .month, for: month.end - 0.1) else { return result }
            if let previous = result {
                let low = min(previous.lowerBound, first)
                result = low..<low + previous.count + last
            } else {
                result = first..<last + 1
            }
            current = month.end + 1
            if current >= end { break }
        }
        return result
    }

    private static let timeUnits: [Calendar.Component] = [.hour, .minute, .second, .nanosecond]

    /// The ordinality of an hour, a minute, a second or a nanosecond inside a larger unit. It counts from the start of the larger unit, whole seconds first and then the fraction.
    /// `secondsInDay` is the local time of the day. `dayOrdinality` gives the ordinality of the day inside a larger unit that is longer than a day.
    static func timeOrdinality(of smaller: Calendar.Component, in larger: Calendar.Component, secondsInDay: Double, date: Date, dayOrdinality: (Calendar.Component) -> Int?) -> Int? {
        guard let smallerIndex = timeUnits.firstIndex(of: smaller), smallerIndex > (timeUnits.firstIndex(of: larger) ?? -1) else { return nil }
        let wholeSecondsInDay = Int(secondsInDay)
        let seconds: Int
        switch larger {
        case .hour: seconds = wholeSecondsInDay % Calendar._secondsInHour
        case .minute: seconds = wholeSecondsInDay % 60
        case .second: seconds = 0
        case .weekday, .day, .dayOfYear: seconds = wholeSecondsInDay
        case .era, .year, .yearForWeekOfYear, .quarter, .month, .weekOfYear, .weekOfMonth:
            guard let days = dayOrdinality(larger) else { return nil }
            let (daySeconds, multiplyOverflow) = (days - 1).multipliedReportingOverflow(by: Calendar._secondsInDay)
            let (sum, addOverflow) = daySeconds.addingReportingOverflow(wholeSecondsInDay)
            guard !multiplyOverflow, !addOverflow else { return nil }
            seconds = sum
        default:
            return nil
        }
        switch smaller {
        case .hour: return seconds / Calendar._secondsInHour + 1
        case .minute: return seconds / 60 + 1
        case .second: return seconds + 1
        default:
            let fraction = date.timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate.rounded(.down)
            let nanoseconds = (Double(seconds) + fraction) * 1e9
            guard nanoseconds < Double(Int.max) else { return nil }
            return Int(nanoseconds) + 1
        }
    }

    // MARK: - Shared by the fixed month and the Chinese family calendars

    /// The largest magnitude of a month, day, week or ordinal that the calendars take from `DateComponents`. Larger values are outside the supported dates, and their day counts could overflow.
    static let fieldLimit: UInt = 100_000_000

    /// A month number outside 1 to `monthsInYear` moved into the right year: the years to carry and the month inside the year. Returns nil for `Int.min`.
    static func carriedMonth(_ month: Int, monthsInYear: Int) -> (yearsCarried: Int, month: Int)? {
        let (zeroBased, overflow) = month.subtractingReportingOverflow(1)
        guard !overflow else { return nil }
        // The month comes from the remainder, so a month near `Int.min` cannot overflow before the caller checks the year.
        let remainder = zeroBased % monthsInYear
        return (floorDiv(zeroBased, monthsInYear), (remainder < 0 ? remainder + monthsInYear : remainder) + 1)
    }

    /// The smaller unit counted in `counting`, at the first and the last moment of the larger unit.
    static func rangeAtEnds<Implementation: _CalendarProtocol>(of smaller: Calendar.Component, in larger: Calendar.Component, counting: Calendar.Component, for date: Date, in calendar: Implementation) -> Range<Int>? {
        guard let interval = calendar.dateInterval(of: larger, for: date),
              let first = calendar.ordinality(of: smaller, in: counting, for: interval.start + 0.1),
              let last = calendar.ordinality(of: smaller, in: counting, for: interval.end - 0.1) else { return nil }
        return first..<last + 1
    }

    /// The first weekday that a new calendar stores: the value if it names a weekday from 1 to 7, or nil.
    static func storedFirstWeekday(_ value: Int?) -> Int? {
        guard let value, value >= 1 && value <= 7 else { return nil }
        return value
    }

    /// The seconds after local midnight that the hour, minute, second and nanosecond of the components name. A missing field counts as 0.
    static func secondsInDay(of components: DateComponents) -> Double {
        var seconds: Double = 0
        if let hour = components.hour { seconds += Double(hour) * Double(Calendar._secondsInHour) }
        if let minute = components.minute { seconds += Double(minute) * 60 }
        if let second = components.second { seconds += Double(second) }
        if let nanosecond = components.nanosecond { seconds += Double(nanosecond) / 1e9 }
        return seconds
    }

    /// Adds the hours, minutes, seconds and nanoseconds of the components to a date as elapsed time.
    static func adding(timeUnitsOf components: DateComponents, to date: Date) -> Date {
        var result = date
        if let hours = components.hour, hours != 0 { result += Double(hours) * Double(Calendar._secondsInHour) }
        if let minutes = components.minute, minutes != 0 { result += Double(minutes) * 60 }
        if let seconds = components.second, seconds != 0 { result += Double(seconds) }
        if let nanoseconds = components.nanosecond, nanoseconds != 0 { result += Double(nanoseconds) / 1_000_000_000 }
        return result
    }

    /// Sets the hour, minute, second and nanosecond that the set asks for. `secondsInDay` is the time after local midnight, `localSeconds` the local time that gives the fraction of a second.
    static func setTimeFields(_ components: Calendar.ComponentSet, secondsInDay: Double, localSeconds: Double, in result: inout DateComponents) {
        guard components.contains(.hour) || components.contains(.minute) || components.contains(.second) || components.contains(.nanosecond) else { return }
        let hour = Int(secondsInDay / Double(Calendar._secondsInHour))
        let remainderAfterHour = secondsInDay - Double(hour) * Double(Calendar._secondsInHour)
        let minute = Int(remainderAfterHour / 60)
        let remainderAfterMinute = remainderAfterHour - Double(minute) * 60
        if components.contains(.hour) { result.hour = hour }
        if components.contains(.minute) { result.minute = minute }
        if components.contains(.second) { result.second = Int(remainderAfterMinute) }
        if components.contains(.nanosecond) { result.nanosecond = Int((localSeconds - localSeconds.rounded(.down)) * 1_000_000_000) }
    }

    /// The position of a day in its week, from 0 for the first weekday to 6.
    static func relativeWeekday(ofRataDie rataDie: Int, firstWeekday: Int) -> Int {
        (weekday(ofRataDie: rataDie) - firstWeekday + 7) % 7
    }

    /// The position of a weekday number in the week, from 0 for the first weekday to 6. The weekday is reduced first, so `Int.min` does not overflow.
    static func relativeWeekday(of weekday: Int, firstWeekday: Int) -> Int {
        ((weekday % 7 - firstWeekday) % 7 + 7) % 7
    }

    /// The first day of week 1 of a year: the week that holds the first day of the year, or the week after it if the year has fewer days in it than the minimum.
    static func firstDayOfWeekYear(yearStart: Int, firstWeekday: Int, minimumDaysInFirstWeek: Int) -> Int {
        let daysIntoWeek = relativeWeekday(ofRataDie: yearStart, firstWeekday: firstWeekday)
        return (7 - daysIntoWeek) >= minimumDaysInFirstWeek ? yearStart - daysIntoWeek : yearStart + 7 - daysIntoWeek
    }

    /// The week year that holds a day, and the week number in it. `firstDayOfWeekYear` gives the first day of week 1 of a year.
    static func weekYearAndWeek(rataDie: Int, year: Int, firstDayOfWeekYear: (Int) -> Int) -> (weekYear: Int, week: Int) {
        var weekYear = year
        if rataDie < firstDayOfWeekYear(weekYear) {
            weekYear -= 1
        } else if rataDie >= firstDayOfWeekYear(weekYear + 1) {
            weekYear += 1
        }
        return (weekYear, (rataDie - firstDayOfWeekYear(weekYear)) / 7 + 1)
    }

    /// Local midnight at the start of a day. A skipped midnight gives the first moment after the gap.
    static func localMidnight(rataDie: Int, in timeZone: TimeZone) -> Date {
        utcDate(fromRataDie: rataDie, secondsInDay: 0, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    /// The interval from local midnight of one day to local midnight of another.
    static func interval(fromRataDie start: Int, toRataDie end: Int, in timeZone: TimeZone) -> DateInterval {
        let startDate = localMidnight(rataDie: start, in: timeZone)
        return DateInterval(start: startDate, duration: localMidnight(rataDie: end, in: timeZone).timeIntervalSince(startDate))
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
