//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
#if canImport(Synchronization)
internal import Synchronization
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

// This type works with Gregorian calendar only
// It represents just one rule; does not handle historical changes
internal final class _TimeZoneSingleDSTRule: Sendable {

    // MARK: - Constants

    // Which clock the time zone uses to decide when DST goes into effect
    enum TimeMode: Int {
        case wallTime = 0
        case standardTime = 1
        case utcTime = 2
    }

    enum RuleMode {
        case dayOfMonth  // Day of month mode
        case dayOfWeekInMonth // Day of week in month mode
        case dayOfWeekOnOrAfterDayOfMonth  // Day of week >= day of month mode
        case dayOfWeekOnOrBeforeDayOfMonth // Day of week <= day of month mode
    }

    typealias DaylightSavingTimePolicy = TimeZone.DaylightSavingTimePolicy

    // MARK: - Properties

    let rawOffset: Int           // Raw offset in seconds
    let dstSavings: Int          // DST savings in seconds

    struct RuleComponents {
        let month: Int           // 0-based (0 = January)
        let day: Int             // Day-of-month if mode is `.dayOfMonth`, or day-of-week-in-month (2 in "2nd Sunday in March", -1 for "last Sunday in October") if mode is `.dayOfWeekInMonth`
        let dayOfWeek: Int       // 1-based (1 == Sunday, 7 == Saturday)
        let time: Int            // Time in seconds since start of day
        let timeMode: TimeMode
        let mode: RuleMode
        init(month: Int8, day: Int8, dayOfWeek: Int8, time: Int32, timeMode: TimeMode) throws(SingleDSTRuleTimeZoneError) {
            guard month >= 0 && month <= 11 else {
                throw .illegalArgument(.month, Int(month))
            }

            guard time >= 0 && time <= 86400 else {
                throw .illegalArgument(.time, Int(time))
            }

            let adjustedDay: Int8
            let adjustedDayOfWeek: Int8
            let mode: RuleMode

            if day == 0 {
                mode = .dayOfMonth
                adjustedDay = day
                adjustedDayOfWeek = dayOfWeek
            } else {
                if dayOfWeek == 0 {
                    adjustedDay = day
                    adjustedDayOfWeek = dayOfWeek
                    mode = .dayOfMonth
                } else if dayOfWeek > 0 {
                    adjustedDay = day
                    adjustedDayOfWeek = dayOfWeek
                    mode = .dayOfWeekInMonth
                } else {
                    adjustedDayOfWeek = -dayOfWeek
                    if day > 0 {
                        adjustedDay = day
                        mode = .dayOfWeekOnOrAfterDayOfMonth
                    } else {
                        adjustedDay = -day
                        mode = .dayOfWeekOnOrBeforeDayOfMonth
                    }
                }
            }

            guard adjustedDayOfWeek <= 7 else { // 7 is Saturday
                throw .illegalArgument(.dayOfWeek, Int(dayOfWeek))
            }

            switch mode {
            case .dayOfWeekInMonth:
                guard adjustedDay >= -5 && adjustedDay <= 5 else {
                    throw .illegalArgument(.day, Int(day))
                }
            case .dayOfMonth:
                fallthrough
            case .dayOfWeekOnOrAfterDayOfMonth:
                fallthrough
            case .dayOfWeekOnOrBeforeDayOfMonth:
                if adjustedDay < 1 || adjustedDay > _TimeZoneSingleDSTRule.MONTH_LENGTH_LEAP_YEAR[Int(month)] {
                    throw .illegalArgument(.day, Int(day))
                }
            }

            self.month = Int(month)
            self.day = Int(adjustedDay)
            self.dayOfWeek = Int(adjustedDayOfWeek)
            self.time = Int(time)
            self.timeMode = timeMode
            self.mode = mode
        }
    }

    let startRule: RuleComponents // DST starts. For example, PST has startRule.month == March
    let endRule: RuleComponents   // DST ends. For example, PST has endRule.month == November
    let isSouthernHemisphere: Bool

    let startYear: Int
    let useDaylight: Bool

    private static let MONTH_LENGTH_LEAP_YEAR = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    // Precomputed cumulative days in prior months
    private static let DAYS_IN_PRIOR_MONTHS_LEAP_YEAR = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
    private static let DAYS_IN_PRIOR_MONTHS_NOT_LEAP_YEAR = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

    // year for maxJulianDay
    static let MAX_YEAR = 5828963

    // MARK: - Initialization

    let calendar: _CalendarGregorian

    init(offsetSeconds: Int32, dstSavingsSeconds: Int32, startMonth: Int8, startDay: Int8, startDayOfWeek: Int8, startTime: Int32, startTimeMode: TimeMode, endMonth: Int8, endDay: Int8, endDayOfWeek: Int8, endTime: Int32, endTimeMode: TimeMode, startYear: Int32 = 0) throws(SingleDSTRuleTimeZoneError) {

        // Determine if we use daylight time (equivalent to ICU logic)
        let useDaylight = (startDay != 0 && endDay != 0)

        // Validate DST savings
        guard !useDaylight || dstSavingsSeconds != 0 else {
            throw .illegalArgument(.dstSavings, Int(dstSavingsSeconds))
        }
        self.useDaylight = useDaylight

        self.rawOffset = Int(offsetSeconds)
        self.dstSavings = Int(dstSavingsSeconds)
        self.startYear = Int(startYear)
        self.startRule = try RuleComponents(month: startMonth, day: startDay, dayOfWeek: startDayOfWeek, time: startTime, timeMode: startTimeMode)
        self.endRule = try RuleComponents(month: endMonth, day: endDay, dayOfWeek: endDayOfWeek, time: endTime, timeMode: endTimeMode)
        self.isSouthernHemisphere = startRule.month > endRule.month

        // This type of time zone rule is represented in terms of Gregorian calendar
        self.calendar = _CalendarGregorian(identifier: .gregorian, timeZone: .gmt, locale: .unlocalized, firstWeekday: Locale.Weekday.monday.icuIndex, minimumDaysInFirstWeek: 1, gregorianStartDate: nil)
#if FOUNDATION_FRAMEWORK && !os(bridgeOS)
        self._cachedFirstTransition = .init(nil)
#else
        self._cachedFirstTransition = .init(initialState: nil)
#endif
    }


    func rawAndDaylightSavingTimeOffset(for date: Date, local: Bool, duplicatedTimePolicy: DaylightSavingTimePolicy, nonExistingTimePolicy: DaylightSavingTimePolicy) -> (rawOffset: Int, dstSavings: Int) {
        if local {
            let secondsOffsets = _rawAndDSTOffsetForLocalDate(date, nonExistingTimeOpt: nonExistingTimePolicy, duplicatedTimeOpt: duplicatedTimePolicy)
            return secondsOffsets
        }

        // For UTC time, use the existing logic
        let rawOffset = rawOffset
        var localDate = date
        localDate += TimeInterval(rawOffset)

        let totalOffset = _gmtOffset(forLocalDate: localDate)
        let dstOffset = totalOffset - rawOffset
        return (rawOffset, dstOffset)
    }

    // Returns offset in seconds
    func _gmtOffset(forLocalDate date: Date) -> Int {
        // We already adjusted for offset at call site. So date is always local already, so we use a calendar in GMT timezone to avoid adjusting it again
        let components = calendar.dateComponents([.era, .year, .month, .day, .weekday, .hour, .minute, .second, .nanosecond], from: date)

        guard let era = components.era, let year = components.year, let month = components.month, let day = components.day, let dayOfWeek = components.weekday, let hour = components.hour, let minute = components.minute, let second = components.second, let nanosecond = components.nanosecond else {
            return Int(rawOffset)
        }

        // Convert to ICU-style parameters (0-based month, seconds since start of day)
        let icuMonth = month - 1  // Convert from 1-based to 0-based
        let icuDayOfWeek = dayOfWeek  // Sunday = 1
        let seconds = hour * 3600 +
                           minute * 60 +
                           second +
                           nanosecond / 1_000_000_000

        return _gmtOffset(era: era, year: year, month: icuMonth, day: day, dayOfWeek: icuDayOfWeek, seconds: seconds)
    }

    // Returns offset in seconds
    private func _gmtOffset(era: Int, year: Int, month: Int, day: Int, dayOfWeek: Int, seconds: Int) -> Int {
        var result = rawOffset

        guard useDaylight && year >= startYear && era == 1 else {
            return result
        }

        let monthLength = monthLength(year: year, month: month)
        let prevMonthLength = previousMonthLength(year: year, month: month)

        let secondsDelta = switch startRule.timeMode {
        case .wallTime:
            0
        case .standardTime:
            0
        case .utcTime:
            -rawOffset
        }
        let startCompare = compareToRule(
            month: month, monthLength: monthLength, prevMonthLength: prevMonthLength,
            dayOfMonth: day, dayOfWeek: dayOfWeek, seconds: seconds,
            secondsDelta: secondsDelta,
            rule: startRule
        )

        let endCompare: ComparisonResult
        // We don't need to compare the end rule if
        // - We're in northern hemisphere and we're before the start rule
        // - We're in southern hemisphere and we're after the end rule
        // In these cases we must be in DST
        if isSouthernHemisphere != (startCompare != .orderedAscending) {
            let secondsDelta = switch endRule.timeMode {
            case .wallTime:
                dstSavings
            case .standardTime:
                0
            case .utcTime:
                -rawOffset
            }
            endCompare = compareToRule(
                month: month, monthLength: monthLength, prevMonthLength: prevMonthLength,
                dayOfMonth: day, dayOfWeek: dayOfWeek, seconds: seconds,
                secondsDelta: secondsDelta,
                rule: endRule
            )
        } else {
            endCompare = .orderedSame
        }

        if (!isSouthernHemisphere && (startCompare != .orderedAscending && endCompare == .orderedAscending)) ||
           (isSouthernHemisphere && (startCompare != .orderedAscending || endCompare == .orderedAscending)) {
            result += dstSavings
        }

        return result
    }

    // MARK: - Rule Comparison

    // Compare date to a DST rule from large to small components
    // Returns:
    // - .ascending if the date is after the rule date
    // - .descending if the date is before the rule date
    // - .same if the date is equal to the rule date
    private func compareToRule(
        month: Int, monthLength: Int, prevMonthLength: Int,
        dayOfMonth: Int, dayOfWeek: Int, seconds: Int,
        secondsDelta: Int,
        rule: RuleComponents
    ) -> ComparisonResult {
        // Adjust seconds for time mode
        var adjustedSeconds = seconds + secondsDelta
        var adjustedMonth = month
        var adjustedDayOfMonth = dayOfMonth
        var adjustedDayOfWeek = dayOfWeek

        // Handle day overflow/underflow due to time adjustments
        while adjustedSeconds >= 86400 {
            adjustedSeconds -= 86400
            adjustedDayOfMonth += 1
            adjustedDayOfWeek = 1 + (adjustedDayOfWeek % 7)
            if adjustedDayOfMonth > monthLength {
                adjustedDayOfMonth = 1
                adjustedMonth += 1
            }
        }

        while adjustedSeconds < 0 {
            adjustedSeconds += 86400
            adjustedDayOfMonth -= 1
            adjustedDayOfWeek = 1 + ((adjustedDayOfWeek + 5) % 7)
            if adjustedDayOfMonth < 1 {
                adjustedDayOfMonth = prevMonthLength
                adjustedMonth -= 1
            }
        }

        if adjustedMonth < rule.month {
            return .orderedAscending
        } else if adjustedMonth > rule.month {
            return .orderedDescending
        }

        let ruleDayOfMonth = dayOfMonthForRule(ruleMode: rule.mode, ruleDay: rule.day, ruleDayOfWeek: rule.dayOfWeek, monthLength: monthLength, dayOfWeek: adjustedDayOfWeek, dayOfMonth: adjustedDayOfMonth)

        if adjustedDayOfMonth < ruleDayOfMonth {
            return .orderedAscending
        } else if adjustedDayOfMonth > ruleDayOfMonth {
            return .orderedDescending
        }

        if adjustedSeconds < rule.time {
            return .orderedAscending
        } else if adjustedSeconds > rule.time {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    // Calculate the actual day of month for a rule
    private func dayOfMonthForRule(ruleMode: RuleMode, ruleDay: Int, ruleDayOfWeek: Int, monthLength: Int, dayOfWeek: Int, dayOfMonth: Int) -> Int {

        // Adjust for leap year February 29 rules
        let adjustedRuleDay = min(monthLength, ruleDay)

        switch ruleMode {
        case .dayOfMonth:
            return adjustedRuleDay

        case .dayOfWeekInMonth:
            if adjustedRuleDay > 0 {
                return 1 + (adjustedRuleDay - 1) * 7 + (7 + ruleDayOfWeek - (dayOfWeek - dayOfMonth + 1)) % 7
            } else {
                return monthLength + (ruleDay + 1) * 7 - (7 + (dayOfWeek + monthLength - dayOfMonth) - ruleDayOfWeek) % 7
            }

        case .dayOfWeekOnOrAfterDayOfMonth:
            return adjustedRuleDay + (49 + ruleDayOfWeek - adjustedRuleDay - dayOfWeek + dayOfMonth) % 7

        case .dayOfWeekOnOrBeforeDayOfMonth:
            return adjustedRuleDay - (49 - ruleDayOfWeek + adjustedRuleDay + dayOfWeek - dayOfMonth) % 7
        }
    }

    // MARK: - Utility Methods

    func _rawAndDSTOffsetForLocalDate(_ date: Date, nonExistingTimeOpt: DaylightSavingTimePolicy, duplicatedTimeOpt: DaylightSavingTimePolicy) -> (rawOffset: Int, dstSavings: Int) {
        var dstOffset = _gmtOffset(forLocalDate: date) - rawOffset
        // Need to recalculate if either
        // 1. We're in DST AND options say we should try standard time
        // 2. We're in standard time AND options say we should try DST
        let needsRecalculate = (dstOffset > 0 && nonExistingTimeOpt == .former) || (dstOffset == 0 && duplicatedTimeOpt == .former)

        if needsRecalculate {
            // Subtract DST savings from original date and recalculate
            let adjustedDate = date.addingTimeInterval(-TimeInterval(dstSavings))

            let adjustedDSTOffset = _gmtOffset(forLocalDate: adjustedDate) - rawOffset
            dstOffset = adjustedDSTOffset
        }
        return (rawOffset, dstOffset)
    }

    private func monthLength(year: Int, month: Int) -> Int {
        precondition(month >= 0 && month < 12)
        if month == 1 && !isLeapYear(year) {
            // Adjust February for non-leap years
            return 28
        } else {
            return Self.MONTH_LENGTH_LEAP_YEAR[Int(month)]
        }
    }

    private func previousMonthLength(year: Int, month: Int) -> Int {
        month == 0 ? 31 : monthLength(year: year, month: month - 1)
    }

    private func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
    }
    
    // Returns the day number from 1970, with day 0 == Jan 1 1970
    private func daysSince1970(year: Int, month: Int, dayOfMonth: Int) -> Int {
        precondition(month >= 0 && month < 12)

        // Days in prior years (Gregorian calculation)
        let priorYear = Int(year - 1)
        var daysSinceBCE1 = priorYear * 365
        daysSinceBCE1 += priorYear / 4
        daysSinceBCE1 -= priorYear / 100
        daysSinceBCE1 += priorYear / 400

        // Days in prior months this year
        let isLeap = isLeapYear(year)
        let daysInPriorMonths = isLeap ? 
            Self.DAYS_IN_PRIOR_MONTHS_LEAP_YEAR[Int(month)] :
            Self.DAYS_IN_PRIOR_MONTHS_NOT_LEAP_YEAR[Int(month)]
        let totalDaysSinceBCE1 = daysSinceBCE1 + Int(daysInPriorMonths) + Int(dayOfMonth)

        // Jan 1, 1970 CE is day 719163 since BCE 1, Jan 1 in the proleptic Gregorian calendar
        let epochOffset = 719163
        let daysSince1970 = totalDaysSinceBCE1 - epochOffset

        return daysSince1970
    }
    
    // Returns: 1 == Sunday, 2 == Monday, ..., 7 == Saturday
    private func dayOfWeek(daysSince1970: Int) -> Int {
        // Jan 1, 1970 was a Thursday
        let dayOfWeekForJan1 = 5
        let dayOfWeek = ((daysSince1970 % 7) + dayOfWeekForJan1 - 1) % 7 + 1

        return dayOfWeek > 0 ? dayOfWeek : dayOfWeek + 7
    }
    
    // MARK: - Transition Rules Support

    enum TransitionDirection {
        case next
        case previous
    }
    
    // Returns DST transitions before or after the given date
    func dstTransition(relativeTo baseDate: Date, direction: TransitionDirection, inclusive: Bool = false) -> Date? {
        guard useDaylight else {
            return nil
        }

        // Check if base is before or after the first transition time
        if let firstTransition {
            switch direction {
            case .next:
                if baseDate < firstTransition || (inclusive && baseDate == firstTransition) {
                    return firstTransition
                }
            case .previous:
                if baseDate < firstTransition || (!inclusive && baseDate == firstTransition) {
                    return nil
                }
            }
        }

        // dst -> standard time
        let stdStart = startDateForRule(endRule, base: baseDate, direction: direction, inclusive: inclusive, previousRawOffset: rawOffset, previousDSTOffset: dstSavings)

        // standard time -> dst
        let dstStart = startDateForRule(startRule, base: baseDate, direction: direction, inclusive: inclusive, previousRawOffset: rawOffset, previousDSTOffset: 0)

        guard let stdStart, let dstStart else {
            return nil
        }

        switch direction {
        case .next:
            // Choose the transition that comes first (closer to base date)
            return min(stdStart, dstStart)

        case .previous:
            // Choose the transition that comes last (closer to base date)
            return max(stdStart, dstStart)
        }
    }

    // Convenience method for finding the next transition after a date
    func dstTransition(after baseDate: Date, inclusive: Bool = false) -> Date? {
        return dstTransition(relativeTo: baseDate, direction: .next, inclusive: inclusive)
    }
    
    // Convenience method for finding the previous transition before a date
    func dstTransition(before baseDate: Date, inclusive: Bool = false) -> Date? {
        return dstTransition(relativeTo: baseDate, direction: .previous, inclusive: inclusive)
    }

    // Returns the first Date when the rule takes effect after or before `base`, depending on the direction
    private func startDateForRule(_ rule: RuleComponents, base: Date, direction: TransitionDirection, inclusive: Bool, previousRawOffset: Int, previousDSTOffset: Int) -> Date? {

        let baseYear = calendar.dateComponent(.year, from: base)
        guard baseYear >= startYear && baseYear <= _TimeZoneSingleDSTRule.MAX_YEAR else { return nil }

        switch direction {
        case .next:
            if baseYear < startYear {
                return startDateForRuleInYear(startYear, rule: rule, previousRawOffset: previousRawOffset, previousDSTOffset: previousDSTOffset)
            }
            
            // Try current year first
            let currentYearDate = startDateForRuleInYear(baseYear, rule: rule, previousRawOffset: previousRawOffset, previousDSTOffset: previousDSTOffset)

            // If current year transition is after base (or equal with inclusive), returns the current year
            if currentYearDate > base || (inclusive && currentYearDate >= base) {
                return currentYearDate
            } else if baseYear + 1 <= _TimeZoneSingleDSTRule.MAX_YEAR { // currentYearDate <= base
                // Current year's transition has passed, try year + 1
                let nextYearDate = startDateForRuleInYear(baseYear + 1, rule: rule, previousRawOffset: previousRawOffset, previousDSTOffset: previousDSTOffset)
                return nextYearDate
            } else {
                return nil
            }

        case .previous:
            // Try current year first
            let currentYearDate = startDateForRuleInYear(baseYear, rule: rule, previousRawOffset: previousRawOffset, previousDSTOffset: previousDSTOffset)
            // If current year transition is before base (or equal with inclusive), returns the current year
            if currentYearDate < base || (inclusive && currentYearDate == base) {
                return currentYearDate
            } else if baseYear - 1 >= startYear {
                // Try previous year
                let previousYearDate = startDateForRuleInYear(baseYear - 1, rule: rule, previousRawOffset: previousRawOffset, previousDSTOffset: previousDSTOffset)
                return previousYearDate
            } else {
                return nil
            }
        }
    }

    
    // Returns the start date of the rule in the given year
    private func startDateForRuleInYear(_ year: Int, rule: RuleComponents, previousRawOffset: Int, previousDSTOffset: Int) -> Date {
        // For _TimeZoneSingleDSTRule, we don't have explicit end year, so we allow any reasonable year
        precondition(year >= startYear && year <= _TimeZoneSingleDSTRule.MAX_YEAR)

        var ruleDay: Int

        switch rule.mode {
        case .dayOfMonth:
            ruleDay = daysSince1970(year: year, month: rule.month, dayOfMonth: rule.day)

        case .dayOfWeekInMonth:
            // Day of week in month mode (e.g., "2nd Sunday")
            var after = true
            if rule.day > 0 {
                // Positive: count from beginning of month (e.g., 2nd Sunday)
                ruleDay = daysSince1970(year: year, month: rule.month, dayOfMonth: 1)
                ruleDay += 7 * (rule.day - 1)
            } else {
                // Negative: count from end of month (e.g., last Sunday = -1)
                after = false
                let monthLength = monthLength(year: year, month: rule.month)
                ruleDay = daysSince1970(year: year, month: rule.month, dayOfMonth: monthLength)
                ruleDay += 7 * (rule.day + 1) // day is negative
            }
            
            // Apply day-of-week adjustment
            let currentDayOfWeek = self.dayOfWeek(daysSince1970: ruleDay)
            let targetDayOfWeek = rule.dayOfWeek
            var delta = targetDayOfWeek - currentDayOfWeek
            
            if after {
                delta = delta < 0 ? delta + 7 : delta
            } else {
                delta = delta > 0 ? delta - 7 : delta
            }
            ruleDay += Int(delta)

        case .dayOfWeekOnOrAfterDayOfMonth, .dayOfWeekOnOrBeforeDayOfMonth:
            // Day of week >= or <= specific date
            let after = (rule.mode == .dayOfWeekOnOrAfterDayOfMonth)
            var targetDay = rule.day
            
            // Handle Feb <= 29 for non-leap years
            if !after && rule.month == 1 && rule.day == 29 && !isLeapYear(year) { // February
                targetDay = 28
            }
            
            ruleDay = daysSince1970(year: year, month: rule.month, dayOfMonth: targetDay)

            // Apply day-of-week adjustment
            let currentDayOfWeek = self.dayOfWeek(daysSince1970: ruleDay)
            let targetDayOfWeek = rule.dayOfWeek
            var delta = targetDayOfWeek - currentDayOfWeek
            
            if after {
                // move forward to target day
                delta = delta < 0 ? delta + 7 : delta
            } else {
                // move backward to target day
                delta = delta > 0 ? delta - 7 : delta
            }
            ruleDay += Int(delta)
        }
        
        // Convert to seconds and add time of day
        var result = Double(ruleDay) * 86400.0 + Double(rule.time)

        if rule.timeMode != .utcTime {
            result -= Double(previousRawOffset)
        }
        if rule.timeMode == .wallTime {
            result -= Double(previousDSTOffset)
        }

        return Date(timeIntervalSince1970: result)
    }

#if FOUNDATION_FRAMEWORK && !os(bridgeOS)
    let _cachedFirstTransition: Mutex<Date??>
#else
    let _cachedFirstTransition: LockedState<Date??>
#endif
    // the first transition for this timezone
    var firstTransition: Date? {
        // Check if we already have a cached value (including cached nil)
        let cached = _cachedFirstTransition.withLock { $0 }
        if let cached {
            return cached
        }
        let calculated: Date?
        if useDaylight {
            let firstDstStart = startDateForRuleInYear(startYear, rule: startRule, previousRawOffset: rawOffset, previousDSTOffset: 0)
            let firstStdStart = startDateForRuleInYear(startYear, rule: endRule, previousRawOffset: rawOffset, previousDSTOffset: dstSavings)
            calculated = min(firstDstStart, firstStdStart)
        } else {
            calculated = nil
        }
        
        // Cache the result (including nil)
        _cachedFirstTransition.withLock {
            $0 = calculated
        }
        return calculated
    }

}

// MARK: - _TimeZoneSingleDSTRule Error Types

internal enum SingleDSTRuleTimeZoneError: Error {
    enum Component {
        case month
        case time
        case dayOfWeek
        case day
        case dstSavings
    }
    case illegalArgument(Component, Int)
}
