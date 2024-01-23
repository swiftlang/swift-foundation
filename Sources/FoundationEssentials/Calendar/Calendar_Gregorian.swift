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

#if canImport(os)
#if FOUNDATION_FRAMEWORK
@_implementationOnly import os
#else
package import os
#endif // FOUNDATION_FRAMEWORK
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(CRT)
import CRT
#endif


/// Julian date helper
/// Julian dates are noon-based. Gregorian dates are midnight-based.
/// JulianDates        `2451544.5 ..< 2451545.5` (Jan 01 2000, 00:00 - Jan 02 2000, 00:00)
/// maps to JulianDay  `2451545`                 (Jan 01 2000, 12:00)
extension Date {
    static let julianDayAtDateReference: Double = 2_451_910.5 // 2001 Jan 1, midnight, UTC

    var julianDate: Double {
        timeIntervalSinceReferenceDate / 86400 + Self.julianDayAtDateReference
    }

    var julianDay: Int {
        Int(julianDate.rounded())
    }

    init(julianDay: Int) {
        self.init(julianDate: Double(julianDay))
    }

    init(julianDate: Double) {
        let secondsSinceJulianReference = (julianDate - Self.julianDayAtDateReference) * 86400
        self.init(timeIntervalSinceReferenceDate: secondsSinceJulianReference)
    }
}

/// It is possible that a `DateComponents` does not represent a valid date,
/// e.g. year: 1996, month: 3, day: 1, weekday: 6.
/// This helper records which components should take precedence.
enum ResolvedDateComponents {

    case dayOfYear(year: Int, dayOfYear: Int)
    case day(year: Int, month: Int, day: Int?, weekOfYear: Int?)
    case weekdayOrdinal(year: Int, month: Int, weekdayOrdinal: Int, weekday: Int?)
    case weekOfYear(year: Int, weekOfYear: Int?, weekday: Int?)
    case weekOfMonth(year: Int, month: Int, weekOfMonth: Int, weekday: Int?)

    // Pick the year field between yearForWeekOfYear and year and resovles era
    static func yearMonth(forDateComponent components: DateComponents) -> (year: Int, month: Int) {
        var rawYear: Int
        // Don't adjust for era if week is also specified
        var adjustEra = true
        if let yearForWeekOfYear = components.yearForWeekOfYear {
            if components.weekOfYear != nil {
                adjustEra = false
            }
            rawYear = yearForWeekOfYear
        } else if let year = components.year {
            rawYear = year
        } else {
            rawYear = 1
        }

        if adjustEra && components.era == 0 /* BC */{
           rawYear = 1 - rawYear
        }

        guard let rawMonth = components.month else {
            return (rawYear, 1)
        }
        return carryOver(rawYear: rawYear, rawMonth: rawMonth)
    }

    static func carryOver(rawYear: Int, rawMonth: Int?) -> (year: Int, month: Int) {
        guard let rawMonth else {
            return (rawYear, 1)
        }
        let month: Int
        let year: Int
        if rawMonth > 12 {
            let (q, r) = (rawMonth - 1 ).quotientAndRemainder(dividingBy: 12)
            year = rawYear + q
            month = r + 1
        } else if rawMonth < 1 {
            let (q, r) = rawMonth.quotientAndRemainder(dividingBy: 12)
            year = rawYear + q - 1
            month = r + 12
        } else {
            year = rawYear
            month = rawMonth
        }

        return (year,  month)
    }
    
    init(dateComponents components: DateComponents) {
        var (year, month) = Self.yearMonth(forDateComponent: components)
        let minWeekdayOrdinal = 1
        
        // TODO: Check day of year value here
        if let d = components.day {
            if components.yearForWeekOfYear != nil, let weekOfYear = components.weekOfYear {
                if components.month == nil && weekOfYear >= 52 {
                    year += 1
                } else if weekOfYear == 1 {
                    year -= 1
                }
            }
            self = .day(year: year, month: month, day: d, weekOfYear: components.weekOfYear)
        } else if let woy = components.weekOfYear, let weekday = components.weekday {
            self = .weekOfYear(year: year, weekOfYear: woy, weekday: weekday)
        } else if let wom = components.weekOfMonth, let weekday = components.weekday {
            self = .weekOfMonth(year: year, month: month, weekOfMonth: wom, weekday: weekday)
        } else if let weekdayOrdinal = components.weekdayOrdinal, let weekday = components.weekday {
            self = .weekdayOrdinal(year: year, month: month, weekdayOrdinal: weekdayOrdinal, weekday: weekday)
        } else if let dayOfYear = components.dayOfYear {
            self = .dayOfYear(year: year, dayOfYear: dayOfYear)
        } else if components.year != nil {
            self = .day(year: year, month: month, day: components.day, weekOfYear: components.weekOfYear)
        } else if components.yearForWeekOfYear != nil  {
            self = .weekOfYear(year: year, weekOfYear: components.weekOfYear, weekday: components.weekday)
        } else if let weekOfYear = components.weekOfYear  {
            self = .weekOfYear(year: year, weekOfYear: weekOfYear, weekday: components.weekday)
        } else if let weekOfMonth = components.weekOfMonth {
            self = .weekOfMonth(year: year, month: month, weekOfMonth: weekOfMonth, weekday: components.weekday)
        } else if let weekdayOrdinal = components.weekdayOrdinal {
            self = .weekdayOrdinal(year: year, month: month, weekdayOrdinal: weekdayOrdinal, weekday: components.weekday)
        } else if let weekday = components.weekday {
            self = .weekdayOrdinal(year: year, month: month, weekdayOrdinal: components.weekdayOrdinal ?? minWeekdayOrdinal, weekday: weekday)
        } else {
            self = .day(year: year, month: month, day: components.day, weekOfYear: components.weekOfYear)
        }
    }

}


/// Internal-use error for indicating unexpected situations when finding dates.
enum GregorianCalendarError : Error {
    case overflow(Calendar.Component, Date /* failing start date */, Date /* failing end date */)
    case notAdvancing(Date /* next */, Date /* previous */)
}

/// This class is a placeholder and work-in-progress to provide an implementation of the Gregorian calendar.
internal final class _CalendarGregorian: _CalendarProtocol, @unchecked Sendable {

#if canImport(os)
    fileprivate static let logger: Logger = {
        Logger(subsystem: "com.apple.foundation", category: "gregorian_calendar")
    }()
#endif

    let kSecondsInWeek = 604_800
    let kSecondsInDay = 86400
    let kSecondsInHour = 3600
    let kSecondsInMinute = 60

    let julianCutoverDay: Int// Julian day (noon-based) of cutover
    let gregorianStartYear: Int
    let gregorianStartDate: Date

    let inf_ti : TimeInterval = 4398046511104.0

    // Only respects Gregorian identifier
    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {

        self.timeZone = timeZone ?? .gmt
        if let gregorianStartDate {
            self.gregorianStartDate = gregorianStartDate
            self.julianCutoverDay = gregorianStartDate.julianDay
            let (y, _, _) = Self.yearMonthDayFromJulianDay(julianCutoverDay, useJulianRef: false)
            self.gregorianStartYear = y
        } else {
            self.gregorianStartYear = 1582
            self.julianCutoverDay = 2299161
            self.gregorianStartDate = Date(timeIntervalSince1970: -12219292800) // 1582-10-15T00:00:00Z
        }

        self.locale = locale
        self.localeIdentifier = locale?.identifier ?? ""
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
    
    var identifier: Calendar.Identifier {
        .gregorian
    }
    
    var locale: Locale?

    var localeIdentifier: String
    
    var timeZone: TimeZone
    
    var _firstWeekday: Int?
    var firstWeekday: Int {
        set {
            precondition(newValue >= 1 && newValue <= 7, "Weekday should be in the range of 1...7")
            _firstWeekday = newValue
        }

        get {
            _firstWeekday ?? 1
        }
    }

    var _minimumDaysInFirstWeek: Int?
    var minimumDaysInFirstWeek: Int {
        set {
            if newValue < 1 {
                _minimumDaysInFirstWeek = 1
            } else if newValue > 7 {
                _minimumDaysInFirstWeek = 7
            } else {
                _minimumDaysInFirstWeek = newValue
            }
        }

        get {
            _minimumDaysInFirstWeek ?? 1
        }
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> _CalendarProtocol {
        let newTimeZone = changingTimeZone ?? self.timeZone
        let newLocale = changingLocale ?? self.locale

        let newFirstWeekday: Int?
        if let changingFirstWeekday {
            newFirstWeekday = changingFirstWeekday
        } else if let _firstWeekday {
            newFirstWeekday = _firstWeekday
        } else {
            newFirstWeekday = nil
        }

        let newMinDays: Int?
        if let changingMinimumDaysInFirstWeek {
            newMinDays = changingMinimumDaysInFirstWeek
        } else if let _minimumDaysInFirstWeek {
            newMinDays = _minimumDaysInFirstWeek
        } else {
            newMinDays = nil
        }

        return _CalendarGregorian.init(identifier: identifier, timeZone: newTimeZone, locale: newLocale, firstWeekday: newFirstWeekday, minimumDaysInFirstWeek: newMinDays, gregorianStartDate: nil)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(timeZone)
        hasher.combine(firstWeekday)
        hasher.combine(minimumDaysInFirstWeek)
        hasher.combine(localeIdentifier)
        hasher.combine(preferredFirstWeekday)
        hasher.combine(preferredMinimumDaysInFirstweek)
    }
    
    // MARK: - Range

    // Returns the range of a component in Gregorian Calendar.
    // When there are multiple possible upper bounds, the smallest one is returned.
    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: 0..<2
        case .year: 1..<140743
        case .month: 1..<13
        case .day: 1..<29
        case .hour: 0..<24
        case .minute: 0..<60
        case .second: 0..<60
        case .weekday: 1..<8
        case .weekdayOrdinal: 1..<5
        case .quarter: 1..<5
        case .weekOfMonth: 1..<5
        case .weekOfYear: 1..<53
        case .yearForWeekOfYear: 140742..<140743
        case .nanosecond: 0..<1000000000
        case .isLeapMonth: 0..<2
        case .dayOfYear: 1..<366
        case .calendar, .timeZone:
            nil
        }
    }
    
    // Returns the range of a component in Gregorian Calendar.
    // When there are multiple possible upper bounds, the largest one is returned.
    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return 0..<2
        case .year: return 1..<144684
        case .month: return 1..<13
        case .day: return 1..<32
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal:
            return 1..<6
        case .quarter: return 1..<5
        case .weekOfMonth:
            let lowerBound = minimumDaysInFirstWeek == 1 ? 1 : 0
            let daysInMonthLimit = 31
            let upperBound = (daysInMonthLimit + 6 + (7 - minimumDaysInFirstWeek)) / 7;
            return lowerBound ..< (upperBound + 1)
        case .weekOfYear: return 1..<54
        case .yearForWeekOfYear: return 140742..<144684
        case .nanosecond: return 0..<1000000000
        case .isLeapMonth: return 0..<2
        case .dayOfYear: return 1..<367
        case .calendar, .timeZone:
            return nil
        }
    }

    // There is a chance of refactoring Calendar_ICU to use these
    func _algorithmA(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = dateInterval(of: larger, for: at) else {
            return nil
        }

        guard let ord1 = ordinality(of: smaller, in: larger, for: interval.start + 0.1) else {
            return nil
        }

        guard let ord2 = ordinality(of: smaller, in: larger, for: interval.start + interval.duration - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    private func _algorithmB(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = dateInterval(of: larger, for: at) else {
            return nil
        }

        var counter = 15 // stopgap in case something goes wrong
        let end = interval.start + interval.duration - 1.0
        var current = interval.start + 1.0

        var result: Range<Int>?
        repeat {
            guard let innerInterval = dateInterval(of: .month, for: current) else {
                return result
            }

            guard let ord1 = ordinality(of: smaller, in: .month, for: innerInterval.start + 0.1) else {
                return result
            }

            guard let ord2 = ordinality(of: smaller, in: .month, for: innerInterval.start + innerInterval.duration - 0.1) else {
                return result
            }

            if let lastResult = result {
                let mn = min(lastResult.first!, ord1)
                result = mn..<(mn + lastResult.count + ord2)
            } else if ord2 >= ord1 {
                result = ord1..<(ord2 + 1)
            } else {
                return ord1..<ord1
            }

            counter -= 1
            current = innerInterval.start + innerInterval.duration + 1.0
        } while current < end && 0 < counter

        return result
    }

    private func _algorithmC(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = dateInterval(of: larger, for: at) else {
            return nil
        }

        guard let ord1 = ordinality(of: smaller, in: .year, for: interval.start + 0.1) else {
            return nil
        }

        guard let ord2 = ordinality(of: smaller, in: .year, for: interval.start + interval.duration - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    private func _algorithmD(at: Date) -> Range<Int>? {
        guard let weekInterval = dateInterval(of: .weekOfMonth, for: at) else {
            return nil
        }

        guard let monthInterval = dateInterval(of: .month, for: at) else {
            return nil
        }

        let start = weekInterval.start < monthInterval.start ? monthInterval.start : weekInterval.start
        let end = weekInterval.end < monthInterval.end ? weekInterval.end : monthInterval.end

        guard let ord1 = ordinality(of: .day, in: .month, for: start + 0.1) else {
            return nil
        }

        guard let ord2 = ordinality(of: .day, in: .month, for: end - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        func isValidComponent(_ c: Calendar.Component) -> Bool {
            return !(c == .calendar || c == .timeZone || c == .weekdayOrdinal || c == .nanosecond)
        }

        guard isValidComponent(larger) else { return nil }

        let capped = date.capped

        // The range of these fields are fixed, and so are independent of what larger fields are
        switch smaller {
        case .weekday:
            switch larger {
            case .second, .minute, .hour, .day, .weekday:
                return nil
            default:
                return maximumRange(of: smaller)
            }
        case .hour:
            switch larger {
            case .second, .minute, .hour:
                return nil
            default:
                return maximumRange(of: smaller)
            }
        case .minute:
            switch larger {
            case .second, .minute:
                return nil
            default:
                return maximumRange(of: smaller)
            }
        case .second:
            switch larger {
            case .second:
                return nil
            default:
                return maximumRange(of: smaller)
            }
        case .nanosecond:
            return maximumRange(of: smaller)
        default:
            break // Continue search
        }

        switch larger {
        case .era:
            // assume it cycles through every possible combination in an era at least once; this is a little dodgy for the Japanese calendar but this calculation isn't terribly useful either
            switch smaller {
            case .year, .quarter, .month, .weekOfYear, .weekOfMonth, .day:
                return maximumRange(of: smaller)
            case .weekdayOrdinal:
                guard let r = maximumRange(of: .day) else { return nil }
                return 1..<(((r.lowerBound + (r.upperBound - r.lowerBound) - 1 + 6) / 7) + 1)
            default:
                break
            }
        case .year:
            switch smaller {
            case .month:
                return 1..<13
            case .quarter, .weekOfYear: /* deprecated week */
                return _algorithmA(smaller: smaller, larger: larger, at: capped)
            case .day, .dayOfYear:
                let year = dateComponent(.year, from: date)
                let max = gregorianYearIsLeap(year) ? 366 : 365
                return 1 ..< max + 1
            case .weekOfMonth, .weekdayOrdinal:
                return _algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .yearForWeekOfYear:
            switch smaller {
            case .quarter, .month, .weekOfYear:
                return _algorithmA(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth:
                break
            case .day, .weekdayOrdinal:
                return _algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .quarter:
            switch smaller {
            case .month, .weekOfYear: /* deprecated week */
                return _algorithmC(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth, .day, .weekdayOrdinal:
                return _algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .month:
            switch smaller {
            case .weekOfYear: /* deprecated week */
                return _algorithmC(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth, .day, .weekdayOrdinal:
                return _algorithmA(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .weekOfYear:
            break
        case .weekOfMonth: /* deprecated week */
            switch smaller {
            case .day:
                return _algorithmD(at: capped)
            default:
                break
            }
        default:
            break
        }

        return nil
    }
    
    func minMaxRange(of component: Calendar.Component, in dateComponent: DateComponents) -> Range<Int>? {
        let allComponents: Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear]

        // Returns the actual `maxRange` using the passed in `range` as a hint.
        // e.g. Some year has 52 weeks, while some year has 53, so we would pass in `52..<54` for `.weekOfYear`.
        // and we'd expect this function to return the actual number of weeks of year in the given `dateComponent`
        // Mostly follows ICU::Calendar::getActualHelper
        func actualMax(inRange range: Range<Int>) -> Int? {
            if range.count == 0 {
                return range.lowerBound
            }
            guard let date = self.date(from: dateComponent) else {
                return nil
            }

            let tz = dateComponent.timeZone ?? self.timeZone
            // now try each value from the start to the end one by one until
            // we get a value that normalizes to another value.  The last value that
            // normalizes to itself is the actual maximum for the current date
            var start = range.lowerBound
            var result = start
            // FIXME: Add a fail-safe for searching functions to prevent infinite loop
            repeat {
                start += 1
                let newDate = add(component, to: date, amount: 1, inTimeZone: tz)
                let newDC = dateComponents(allComponents, from: newDate, in: tz)
                let value = newDC.value(for: component)
                if value != start {
                    break
                }
                result = start

            } while start != range.upperBound

            assert(result < range.upperBound)
            return result
        }

        switch component {
        case .era:
            return 0..<2
        case .year:
            guard let max = actualMax(inRange: 140742..<144684) else {
                return nil
            }
            return 1..<max + 1
        case .month:
            return 1..<13
        case .dayOfYear:
            guard let year = dateComponent.year else {
                return nil
            }
            if gregorianYearIsLeap(year) {
                return 1..<367
            } else {
                return 1..<366
            }
        case .day: // day in month
            guard let month = dateComponent.month, let year = dateComponent.year else {
                return nil
            }
            let daysInMonth = numberOfDaysInMonth(month, year: year)
            return 1 ..< (daysInMonth + 1)
        case .hour:
            return 0..<24
        case .minute:
            return 0..<60
        case .second:
            return 0..<60
        case .weekday:
            return 1..<8
        case .weekdayOrdinal:
            guard let max = actualMax(inRange: 4..<6) else {
                return nil
            }
            return 1..<max + 1
        case .quarter:
            return 1..<5
        case .weekOfMonth:
            // Not following ICU: Simply return the week of month value of the last day in the month instead of doing an incremental search.
            guard let date = self.date(from: dateComponent) else {
                return nil
            }
            var lastDayInMonthDC = dateComponents(allComponents, from: date, in: timeZone)
            let daysInMonth = numberOfDaysInMonth(lastDayInMonthDC.month!, year: lastDayInMonthDC.year!)
            lastDayInMonthDC.day = daysInMonth
            let lastDayInMonth = self.date(from: lastDayInMonthDC)!
            let lastDayInMonthDC_Complete =  dateComponents(allComponents, from: lastDayInMonth, in: timeZone)
            let weekOfMonthOfLastDay = lastDayInMonthDC_Complete.weekOfMonth!
            return 1..<weekOfMonthOfLastDay + 1

        case .weekOfYear:
            guard let max = actualMax(inRange: 52..<54) else {
                return nil
            }
            return 1..<max + 1
        case .yearForWeekOfYear:
            guard let max = actualMax(inRange: 140742..<144684) else {
                return nil
            }
            return -140742..<max + 1
        case .nanosecond:
            return 0..<1_000_000_000
        case .calendar:
            return nil
        case .timeZone:
            return nil
        case .isLeapMonth:
            return nil
        }
    }

    // MARK: - Ordinality

    func firstInstant(of unit: Calendar.Component, at date: Date) -> Date {
        var startAtUnit = unit
        let monthBasedComponents : Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday]
        let weekBasedComponents: Calendar.ComponentSet = [.era, .weekday, .weekOfYear, .yearForWeekOfYear, .hour, .minute, .second, .nanosecond ]
        let relevantComponents: Calendar.ComponentSet
        if startAtUnit == .yearForWeekOfYear || startAtUnit == .weekOfYear || startAtUnit == .weekOfMonth {
            relevantComponents = weekBasedComponents
        } else {
            relevantComponents = monthBasedComponents
        }

        var dc = dateComponents(relevantComponents, from: date, in: timeZone)
        // For these units, we will adjust which unit to start at then proceed to second check
        switch startAtUnit {
        case .quarter:
            var month = dc.month! - 1
            // A lunar leap month is considered to be in the same quarter that the base month number is in.
            let qmonth : [Int] = [0, 0, 0, 3, 3, 3, 6, 6, 6, 9, 9, 9, 9]
            month = qmonth[Int(month)]
            dc.month = month + 1
            dc.isLeapMonth = false
            startAtUnit = .month
        case .yearForWeekOfYear:

            let minWOY = minMaxRange(of: .year, in: dc)!
            dc.weekOfYear = minWOY.lowerBound
            fallthrough

        case .weekOfMonth, .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
            // reduce to first day of week, then reduce the rest of the day
            let updatedDate = self.date(from: dc)!

            var dow = dateComponent(.weekday, from: updatedDate)
            var work = updatedDate
            // FIXME: Add a fail-safe for searching functions to prevent infinite loop
            while dow != firstWeekday {
                work = add(.day, to: work, amount: -3, inTimeZone: timeZone)
                work = add(.day, to: work, amount: 2, inTimeZone: timeZone)
                dow = dateComponent(.weekday, from: work)

            }
            dc = dateComponents(relevantComponents, from: work)
            startAtUnit = .day

        default:
            // Leave startAtUnit alone
            break
        }

        // largest to smallest, we set the fields to their minimum value
        switch startAtUnit {
        case .era:
            dc.year = minMaxRange(of: .year, in: dc)?.lowerBound
            fallthrough

        case .year:
            dc.month = minMaxRange(of: .month, in: dc)?.lowerBound
            dc.isLeapMonth = false
            fallthrough

        case .month:
            dc.day = minMaxRange(of: .day, in: dc)?.lowerBound
            fallthrough

        case .weekdayOrdinal, .weekday, .day, .dayOfYear:
            dc.hour = minMaxRange(of: .hour, in: dc)?.lowerBound
            fallthrough

        case .hour:
            dc.minute = minMaxRange(of: .minute, in: dc)?.lowerBound
            fallthrough

        case .minute:
            dc.second = minMaxRange(of: .second, in: dc)?.lowerBound
            fallthrough

        case .second:
            dc.nanosecond = 0

        default:
            // do nothing extra
            break
        }

        let updatedDate = self.date(from: dc)!

        let start: Date
        if startAtUnit == .day || startAtUnit == .weekday || startAtUnit == .weekdayOrdinal {
            let targetDay = dateComponent(.day, from: updatedDate)
            var currentDay = targetDay
            var udate = updatedDate
            // FIXME: Add a fail-safe for searching functions to prevent infinite loop
            var prev: Date
            repeat {
                prev = udate
                udate = self.add(.second, to: prev, amount: -1, inTimeZone: timeZone)
                currentDay = dateComponent(.day, from: udate)
            } while targetDay == currentDay

            start = prev
        } else {
            start = updatedDate
        }

        // FIXME: dst transition
        return start
    }

    // FIXME: This is almost the same with Calendar_ICU's _locked_start(of:).
    // There is a chance of refactoring Calendar_ICU to use this one
    func start(of unit: Calendar.Component, at: Date) -> Date? {
        let capped = at.capped

        let time = capped.timeIntervalSinceReferenceDate

        var effectiveUnit = unit
        switch effectiveUnit {
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        case .era:
            if time < -63113904000.0 {
                return Date(timeIntervalSinceReferenceDate: -63113904000.0 - inf_ti)
            } else {
                return Date(timeIntervalSinceReferenceDate: -63113904000.0)
            }

        case .hour:
            let ti = Double(timeZone.secondsFromGMT(for: capped))
            var fixedTime = time + ti // compute local time
            fixedTime = floor(fixedTime / 3600.0) * 3600.0
            fixedTime = fixedTime - ti // compute GMT
            return Date(timeIntervalSinceReferenceDate: fixedTime)
        case .minute:
            return Date(timeIntervalSinceReferenceDate: floor(time / 60.0) * 60.0)
        case .second:
            return Date(timeIntervalSinceReferenceDate: floor(time))
        case .nanosecond:
            return Date(timeIntervalSinceReferenceDate: floor(time * 1.0e+9) * 1.0e-9)
        case .year, .yearForWeekOfYear, .quarter, .month, .day, .dayOfYear, .weekOfMonth, .weekOfYear:
            // Continue to below
            break
        case .weekdayOrdinal, .weekday:
            // Continue to below, after changing the unit
            effectiveUnit = .day
            break
        }

        let firstInstant = firstInstant(of: effectiveUnit, at: capped)
        return firstInstant
    }

    // move date to target day of week
    func dateAfterDateWithTargetDoW(_ start: Date, _ targetDoW: Int) -> (Date, daysAdded: Int) {
        var daysAdded = 0
        var weekday = dateComponent(.weekday, from: start)
        var work = start
        // FIXME: Add a fail-safe for searching functions to prevent infinite loop
        while weekday != targetDoW {
            work = self.add(.day, to: work, amount: 1, inTimeZone: timeZone)
            weekday = dateComponent(.weekday, from: work)
            daysAdded += 1
        }
        return (work, daysAdded)
    }

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {

        switch larger {
        case .era:
            switch smaller {
            case .year:
                return dateComponent(.year, from: date)

            case .yearForWeekOfYear:
                return dateComponent(.yearForWeekOfYear, from: date)

            case .quarter:
                guard let year = ordinality(of: .year, in: .era, for: date) else { return nil }
                guard let q = ordinality(of: .quarter, in: .year, for: date) else { return nil }
                let quarter = 4 * (year - 1) + q
                return quarter

            case .month:
                guard let start = start(of: .era, at: date) else { return nil }
                var test: Date
                var month = 0
                if let r = maximumRange(of: .day) {
                    month = Int(floor(
                        (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                        86400.0 /
                        Double(r.count + 1) *
                        0.96875
                    ))
                    // low-ball the estimate
                    month = 10 < month ? month - 10 : 0
                    // low-ball the estimate further

                    // FIXME: Add a fail-safe for searching functions to prevent infinite loop
                    repeat {
                        month += 1
                        test = add(.month, to: start, amount: month, inTimeZone: timeZone)
                    } while test <= date
                }
                return month

            case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                guard var start = start(of: .era, at: date) else { return nil }
                var (startMatchinWeekday, daysAdded) = self.dateAfterDateWithTargetDoW(start, firstWeekday)

                start += Double(daysAdded) * 86400.0
                assert(startMatchinWeekday == start)

                if minimumDaysInFirstWeek <= daysAdded {
                    // previous week chunk was big enough, count it
                    startMatchinWeekday -= 7 * 86400.0
                    start -=  7 * 86400.0
                }
                var week = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0 /
                    7.0
                ))
                // low-ball the estimate
                var test: Date
                week = 10 < week ? week - 109 : 0
                // FIXME: Add a fail-safe for searching functions to prevent infinite loop
                repeat {
                    week += 1
                    test = add(.weekOfYear, to: start, amount: week, inTimeZone: timeZone)
                } while test <= date

                return week

            case .weekdayOrdinal, .weekday:
                guard let start = start(of: .era, at: date) else { return nil }
                let targetDOW = dateComponent(.weekday, from: date)
                let (startMatchingWeekday, _) = self.dateAfterDateWithTargetDoW(start, targetDOW)

                var nthWeekday = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0 /
                    7.0
                ))

                // Low-ball estimate
                nthWeekday = (10 < nthWeekday) ? nthWeekday - 10 : 0

                var test: Date
                // FIXME: Add a fail-safe for searching functions to prevent infinite loop
                repeat {
                    nthWeekday += 1
                    test = self.add(.weekOfYear, to: startMatchingWeekday, amount: nthWeekday, inTimeZone: timeZone)
                } while test < date

                return nthWeekday

            case .day:
                guard let start = start(of: .era, at: date) else {
                    return nil
                }
                let day = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0
                )) + 1
                return day

            case .hour:
                guard let day = ordinality(of: .day, in: .era, for: date) else { return nil }
                if (Int.max - 24) / 24 < (day - 1) { return nil }
                let hour = dateComponent(.hour, from: date)
                let newHour = (day - 1) * 24 + hour + 1
                return newHour

            case .minute:
                guard let hour = ordinality(of: .hour, in: .era, for: date) else { return nil }
                if (Int.max - 60) / 60 < (hour - 1) { return nil }
                let minute = dateComponent(.minute, from: date)
                let newMinute = (hour - 1) * 60 + minute + 1
                return newMinute

            case .second:
                guard let minute = ordinality(of: .minute, in: .era, for: date) else { return nil }
                if (Int.max - 60) / 60 < (minute - 1) { return nil }
                let second = dateComponent(.second, from: date)
                let newSecond = (minute - 1) * 60 + second + 1
                return newSecond

            default:
                return nil
            }
        case .year:
            switch smaller {
            case .quarter:
                let month = dateComponent(.month, from: date)
                let quarter = month - 1
                let mquarter = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4]
                return mquarter[Int(quarter)]

            case .month:
                return dateComponent(.month, from: date)

            case .weekOfMonth:
                return nil

            case .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
                let dc = self.dateComponents([.year, .month, .day], from: date, in: timeZone)
                let doy = dayOfYear(fromYear: dc.year!, month: dc.month!, day: dc.day!)
                var work = dc
                work.day = 1
                work.month = 1
                let workDate = self.date(from: work)!
                let yearStartWeekday = dateComponent(.weekday, from: workDate)
                let week = (doy + 7 - minimumDaysInFirstWeek + (yearStartWeekday + minimumDaysInFirstWeek - firstWeekday + 6) % 7) / 7

                return week

            case .weekdayOrdinal, .weekday:
                guard let start = start(of: .year, at: date) else { return nil }
                guard let dateWeek = ordinality(of: .weekOfYear, in: .year, for: date) else { return nil }

                let targetDoW = dateComponent(.weekday, from: date)
                let (startMatchingWeekday, _) = self.dateAfterDateWithTargetDoW(start, targetDoW)
                let newStart = startMatchingWeekday
                guard let startWeek = ordinality(of: .weekOfYear, in: .year, for: newStart) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday

            case .day, .dayOfYear:
                let dc = self.dateComponents([.year, .month, .day], from: date, in: timeZone)
                let doy = dayOfYear(fromYear: dc.year!, month: dc.month!, day: dc.day!)
                return doy

            case .hour:
                guard let day = ordinality(of: .day, in: .year, for: date) else { return nil }
                let hour = dateComponent(.hour, from: date)
                let ord = (day - 1) * 24 + hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .year, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)

                let ord = (hour - 1) * 60 + minute + 1
                return ord

            case .second:
                guard let minute = ordinality(of: .minute, in: .year, for: date) else { return nil }
                let second = dateComponent(.second, from: date)

                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .year, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }

        case .yearForWeekOfYear:
            switch smaller {
            case .quarter:
                return nil
            case .month:
                return nil
            case .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                return nil
            case .weekOfYear:
                let weekOfYear = dateComponent(.weekOfYear, from: date)
                return weekOfYear

            case .weekdayOrdinal, .weekday:
                guard let start = start(of: .yearForWeekOfYear, at: date) else { return nil }
                guard let dateWeek = ordinality(of: .weekOfYear, in: .yearForWeekOfYear, for: date) else {
                    return nil
                }
                let targetDoW = dateComponent(.weekday, from: date)

                let (startMatchingWeekday, _) = self.dateAfterDateWithTargetDoW(start, targetDoW)
                guard let startWeek = ordinality(of: .weekOfYear, in: .yearForWeekOfYear, for: startMatchingWeekday) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday

            case .day, .dayOfYear:
                guard let start = start(of: .yearForWeekOfYear, at: date) else { return nil }
                let day = Int(floor((date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / 86400.0)) + 1
                return day

            case .hour:
                guard let day = ordinality(of: .day, in: .yearForWeekOfYear, for: date) else { return nil }
                let hour = dateComponent(.hour, from: date)

                let ord = (day - 1) * 24 + hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .yearForWeekOfYear, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)

                let ord = (hour - 1) * 60 + minute + 1
                return ord
            case .second:
                guard let minute = ordinality(of: .minute, in: .yearForWeekOfYear, for: date) else { return nil }
                let second = dateComponent(.second, from: date)

                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .yearForWeekOfYear, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }

        case .quarter:
            switch smaller {
            case .month:
                let month = dateComponent(.month, from: date)
                let mcount = [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 4]
                return mcount[month - 1]

            case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                guard let start = start(of: .quarter, at: date) else { return nil }
                let (startMatchingWeekday, daysAdded) = self.dateAfterDateWithTargetDoW(start, firstWeekday)
                guard var startWeek = ordinality(of: .weekOfYear, in: .year, for: startMatchingWeekday) else { return nil }
                if minimumDaysInFirstWeek <= daysAdded {
                    // previous week chunk was big enough, back up
                    startWeek -= 1
                }
                guard let dateWeek = ordinality(of: .weekOfYear, in: .year, for: date) else { return nil }
                let week = dateWeek - startWeek + 1
                return week

            case .weekdayOrdinal, .weekday:
                guard let start = start(of: .quarter, at: date) else { return nil }
                let targetDoW = dateComponent(.weekday, from: date)

                guard let dateWeek = ordinality(of: .weekOfYear, in: .year, for: date) else {
                    return nil
                }

                // move start forward to target day of week if not already there
                let (startMatchingWeekday, _) = self.dateAfterDateWithTargetDoW(start, targetDoW)
                guard let startWeek = ordinality(of: .weekOfYear, in: .year, for: startMatchingWeekday) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday

            case .day, .dayOfYear:
                let start = start(of: .quarter, at: date)
                guard let start else { return nil }
                let day = Int(floor((date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / 86400.0)) + 1
                return day

            case .hour:
                guard let day = ordinality(of: .day, in: .quarter, for: date) else { return nil }
                let hour = dateComponent(.hour, from: date)

                let ord = (day - 1) * 24 + hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .quarter, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)

                let ord = (hour - 1) * 60 + minute + 1
                return ord
            case .second:
                guard let minute = ordinality(of: .minute, in: .quarter, for: date) else { return nil }
                let second = dateComponent(.second, from: date)

                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .quarter, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .month:
            switch smaller {
            case .weekOfYear:
                return nil
            case .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                let week = dateComponent(.weekOfMonth, from: date)
                return week

            case .day:
                let day = dateComponent(.day, from: date)
                return day

            case .weekdayOrdinal, .weekday:
                guard let day = ordinality(of: .day, in: .month, for: date) else { return nil }
                let nthWeekday = (day + 6) / 7
                return nthWeekday

            case .hour:
                guard let day = ordinality(of: .day, in: .month, for: date) else { return nil }
                let hour = dateComponent(.hour, from: date)

                let ord = (day - 1) * 24 + hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .month, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)

                let ord = (hour - 1) * 60 + minute + 1
                return ord

            case .second:
                guard let minute = ordinality(of: .minute, in: .month, for: date) else { return nil }
                let second = dateComponent(.second, from: date)

                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .month, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated  */
            switch smaller {
            case .day, .weekday:
                let weekday = dateComponent(.weekday, from: date)

                let day = weekday + 1 - firstWeekday
                if day <= 0 {
                    return day + 7
                } else {
                    return day
                }
            case .hour:
                guard let day = ordinality(of: .day, in: .weekOfYear, for: date) else { return nil }
                let hour = dateComponent(.hour, from: date)

                let ord = (day - 1) * 24 + hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .weekOfYear, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)

                let ord = (hour - 1) * 60 + minute + 1
                return ord

            case .second:

                guard let minute = ordinality(of: .minute, in: .weekOfYear, for: date) else { return nil }
                let second = dateComponent(.second, from: date)

                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .weekOfYear, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .weekday, .day, .dayOfYear:
            switch smaller {
            case .hour:
                let hour = dateComponent(.hour, from: date)
                let ord = hour + 1
                return ord

            case .minute:
                guard let hour = ordinality(of: .hour, in: .day, for: date) else { return nil }
                let minute = dateComponent(.minute, from: date)
                let ord = (hour - 1) * 60 + minute + 1
                return ord

            case .second:
                guard let minute = ordinality(of: .minute, in: .day, for: date) else { return nil }
                let second = dateComponent(.second, from: date)
                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .day, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .hour:
            switch smaller {
            case .minute:
                let minute = dateComponent(.minute, from: date)
                let ord = minute + 1
                return ord

            case .second:
                guard let minute = ordinality(of: .minute, in: .hour, for: date) else { return nil }
                let second = dateComponent(.second, from: date)
                let ord = (minute - 1) * 60 + second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .hour, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .minute:
            switch smaller {
            case .second:
                let second = dateComponent(.second, from: date)
                let ord = second + 1
                return ord

            case .nanosecond:
                guard let second = ordinality(of: .second, in: .minute, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .second:
            switch smaller {
            case .nanosecond:
                return Int(((date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate)) * 1.0e9) + 1)

            default:
                return nil
            }
        case .nanosecond:
            return nil
        case .weekdayOrdinal:
            return nil

        default:
            return nil
        }

        // No return here to ensure we've covered all cases in switch statements above, even via `default`.
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {

        let capped = date.capped
        let time = capped.timeIntervalSinceReferenceDate
        var effectiveUnit = component
        switch effectiveUnit {
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        case .era:
            if time < -63113904000.0 {
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -63113904000.0 - inf_ti), duration: inf_ti)
            } else {
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -63113904000.0), duration: inf_ti)
            }

        case .hour:
            let ti = Double(timeZone.secondsFromGMT(for: capped))
            var fixedTime = time + ti // compute local time
            fixedTime = floor(fixedTime / 3600.0) * 3600.0
            fixedTime = fixedTime - ti // compute GMT
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: fixedTime), duration: 3600.0)
        case .minute:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time / 60.0) * 60.0), duration: 60.0)
        case .second:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time)), duration: 1.0)
        case .nanosecond:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time * 1.0e+9) * 1.0e-9), duration: 1.0e-9)
        case .year, .yearForWeekOfYear, .quarter, .month, .day, .dayOfYear, .weekOfMonth, .weekOfYear:
            // Continue to below
            break
        case .weekdayOrdinal, .weekday:
            // Continue to below, after changing the unit
            effectiveUnit = .day
            break
        }

        let start = firstInstant(of: effectiveUnit, at: capped)

        var upperBound: Date
        switch effectiveUnit {
        case .era:
            let newUDate = add(.era, to: start, amount: 1, inTimeZone: timeZone)
            guard newUDate != start else {
                // Probably because we are at the limit of era.
                return DateInterval(start: start, duration: inf_ti)
            }
            upperBound = start

        case .year:
            upperBound = add(.year, to: start, amount: 1, inTimeZone: timeZone)

        case .yearForWeekOfYear:
            upperBound = add(.yearForWeekOfYear, to: start, amount: 1, inTimeZone: timeZone)

        case .quarter:
            upperBound = add(.month, to: start, amount: 3, inTimeZone: timeZone)

        case .month:
            upperBound = add(.month, to: start, amount: 1, inTimeZone: timeZone)

        case .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
            upperBound = add(.weekOfYear, to: start, amount: 1, inTimeZone: timeZone)

        case .weekOfMonth:
            upperBound = add(.weekOfMonth, to: start, amount: 1, inTimeZone: timeZone)

        case .day, .dayOfYear:
            upperBound = add(.day, to: start, amount: 1, inTimeZone: timeZone)

        default:
            upperBound = start
        }

        // move back to 0h0m0s, in case the start of the unit wasn't at 0h0m0s
        upperBound = firstInstant(of: .day, at: upperBound)

        if let tzTransition = timeZoneTransitionInterval(at: upperBound, timeZone: timeZone) {
            return DateInterval(start: start, end: upperBound - tzTransition.duration)
        } else if upperBound > start {
            return DateInterval(start: start, end: upperBound)
        } else {
            // Out of range
            return nil
        }
    }
    
    func timeInDay(for date: Date) -> TimeInterval {
        let timeInDay = dateComponents([.hour, .minute, .second], from: date)
        guard let hour = timeInDay.hour, let minute = timeInDay.minute, let second = timeInDay.second else {
            preconditionFailure("Unexpected nil values for hour, minute, or second")
        }
        return TimeInterval(hour * kSecondsInHour + minute * 60 + second)
    }

    func isDateInWeekend(_ date: Date) -> Bool {
        let weekendRange: WeekendRange
        if let localeWeekendRange = locale?.weekendRange {
            weekendRange = localeWeekendRange
        } else {
            // Weekend range for 001 region
            weekendRange = WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1)
        }

        return isDateInWeekend(date, weekendRange: weekendRange)
    }

    // For testing purpose
    internal func isDateInWeekend(_ date: Date, weekendRange: WeekendRange) -> Bool {

        // First, compare the day of the week
        let dayOfWeek = dateComponent(.weekday, from: date)
        if weekendRange.start == weekendRange.end && dayOfWeek != weekendRange.start {
            return false
        } else if weekendRange.start < weekendRange.end && (dayOfWeek < weekendRange.start || dayOfWeek > weekendRange.end)  {
            return false
        } else if weekendRange.start > weekendRange.end && (dayOfWeek > weekendRange.end && dayOfWeek < weekendRange.start) {
            return false
        }

        // Then compare the time in the day if the day falls on the start or the end of weekend
        if dayOfWeek == weekendRange.start {
            guard let onsetTime = weekendRange.onsetTime, onsetTime != 0 else {
                return true
            }

            let timeInDay = timeInDay(for: date)
            return timeInDay >= onsetTime
        } else if dayOfWeek == weekendRange.end {
            guard let ceaseTime = weekendRange.ceaseTime, ceaseTime < 86400 else {
                return true
            }

            let timeInDay = timeInDay(for: date)
            return timeInDay < ceaseTime
        } else {
            return true
        }
    }
    
    // MARK:

    func date(from components: DateComponents) -> Date? {
        // If the date falls into the skipped time frame when transitioning into DST (e.g. 1:00 - 3:00 AM for PDT), we want to treat it as if DST hasn't happened yet. So, use .former for dstRepeatedTimePolicy.
        // If the date falls into the repeated time frame when DST ends (e.g. 1:00 - 2:00 AM for PDT), we want the first instance, i.e. the instance before turning back the clock. So, use .former for dstSkippedTimePolicy.
        date(from: components, inTimeZone: timeZone, dstRepeatedTimePolicy: .former, dstSkippedTimePolicy: .former)
    }

    //  Returns the weekday with reference to `firstWeekday`, in the range of 0...6
    func relativeWeekday(fromJulianDay julianDay: Int) -> Int {
        // Julian day is 0 based; day 0 == Sunday
        let weekday = (julianDay + 1) % 7 + 1

        let relativeWeekday = (weekday + 7 - firstWeekday) % 7
        return relativeWeekday
    }

    func numberOfDaysInMonth(_ month: Int, year: Int) -> Int {
        var month = month
        if month > 12 {
            month = (month - 1) % 12 + 1
        } else if month < 1 {
            month = month % 12 + 12
        }
        switch month {
        case 1, 3, 5, 7, 8, 10, 12:
            return 31
        case 4, 6, 9, 11:
            return 30
        case 2:
            return gregorianYearIsLeap(year) ? 29 : 28
        default:
            fatalError("programming error, month out of range")
        }
    }

    // Returns the weekday with reference to `firstWeekday`, in the range of 0...6
    func wrapAroundRelativeWeekday(_ weekday: Int) -> Int {
        var dow = (weekday - firstWeekday) % 7
        if dow < 0 {
            dow += 7
        }
        return dow
    }

    func julianDay(usingJulianReference: Bool, resolvedComponents: ResolvedDateComponents) -> Int {

        var rawMonth: Int // 1-based
        let monthStart = 1

        var rawYear: Int
        switch resolvedComponents {
        case .day(let year, let month, _, _):
            rawMonth = month
            rawYear = year
        case .weekdayOrdinal(let year, let month, _, _):
            rawMonth = month
            rawYear = year
        case .weekOfYear(let year, _, _):
            rawMonth = monthStart
            rawYear = year
        case .weekOfMonth(let year, let month, _, _):
            rawMonth = month
            rawYear = year
        case .dayOfYear(let year, _):
            rawMonth = monthStart
            rawYear = year
        }

        // `julianDayAtBeginningOfYear` points to the noon of the day *before* the beginning of year/month
        let julianDayAtBeginningOfYear = Self.julianDay(ofDay: 0, month: rawMonth, year: rawYear, useJulianReference: usingJulianReference)

        let first = relativeWeekday(fromJulianDay: julianDayAtBeginningOfYear + 1) // weekday of the first day in the month, 0...6

        let julianDay: Int
        switch resolvedComponents {
        case .day(_, _, let day, _):
            julianDay = julianDayAtBeginningOfYear + (day ?? 1)
        case .weekdayOrdinal(_, _, let weekdayOrdinal, let weekday):
            let dow = (weekday != nil) ? wrapAroundRelativeWeekday(weekday!) : 0

            // `date` is the first day of month whose weekday matches the target relative weekday (`dow`), -5...7
            //  e.g. If we're looking for weekday == 2 (Tuesday), `date` would be the day number of the first Tuesday in the month
            var date = dow - first + 1
            if date < 1 {
                date += 7
            }

            if weekdayOrdinal >= 0 {
                date += (weekdayOrdinal - 1) * 7
            } else {
                // Negative weekdayOrdinal means counting from back.
                // e.g. -1 means the last day in the month whose weekday is the target `weekday`
                let monthLength = numberOfDaysInMonth(rawMonth, year: rawYear)
                date += ((monthLength - date) / 7 + weekdayOrdinal + 1 ) * 7
            }

            julianDay = julianDayAtBeginningOfYear + date

        case .weekOfYear(_, let weekOfYear, let weekday):

            let dow = (weekday != nil) ? wrapAroundRelativeWeekday(weekday!) : 0

            var date = dow - first + 1 // the first day of month whose weekday matches the target relative weekday (`dow`), -5...7
            if 7 - first < minimumDaysInFirstWeek {
                // move forward to the next week if the found date is in the first week of month, but the first week is a partial week
                date += 7
            }

            if let weekOfYear {
                date += (weekOfYear - 1) * 7
            }

            julianDay = julianDayAtBeginningOfYear + date

        case .weekOfMonth(_, _, let weekOfMonth, let weekday):

            let dow = (weekday != nil) ? wrapAroundRelativeWeekday(weekday!) : 0
            var date = dow - first + 1 //  // the first day of month whose weekday matches the target relative weekday (`dow`), -5...7

            if 7 - first < minimumDaysInFirstWeek {
                // move forward to the next week if the found date is in the first week of month, but the first week is a partial week
                date += 7
            }

            date = date + (weekOfMonth - 1) * 7

            julianDay = julianDayAtBeginningOfYear + date
        case .dayOfYear(_, let dayOfYear):
            julianDay = julianDayAtBeginningOfYear + dayOfYear
        }

        return julianDay
    }

    func date(from components: DateComponents, inTimeZone timeZone: TimeZone, dstRepeatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, dstSkippedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> Date? {

        let resolvedComponents = ResolvedDateComponents(dateComponents: components)

        var useJulianReference = false
        switch resolvedComponents {
        case .weekOfYear(let year, _, _):
            useJulianReference = year == gregorianStartYear
        case .weekOfMonth, .day, .weekdayOrdinal, .dayOfYear:
            break
        }

        var julianDay = self.julianDay(usingJulianReference: useJulianReference, resolvedComponents: resolvedComponents)
        if !useJulianReference && julianDay < julianCutoverDay { // Recalculate using julian reference if we're before cutover
            julianDay = self.julianDay(usingJulianReference: true, resolvedComponents: resolvedComponents)
        }

        let nano_coef = 1_000_000_000

        var secondsInDay = 0.0
        if let hour = components.hour {
            secondsInDay += Double(hour) * 3600.0
        }
        if let minute = components.minute {
            secondsInDay += Double(minute) * 60.0
        }
        if let second = components.second {
            secondsInDay += Double(second)
        }
        if let nanosecond = components.nanosecond {
            secondsInDay += Double(nanosecond) / Double(nano_coef)
        }

        // Rewind from Julian day, which starts at noon, back to midnight
        var tmpDate = Date(julianDay: julianDay) - 43200 + secondsInDay

        // tmpDate now is in GMT. Adjust it back into local time zone
        let (timeZoneOffset, dstOffset) = timeZone.rawAndDaylightSavingTimeOffset(for: tmpDate, repeatedTimePolicy: dstRepeatedTimePolicy)
        tmpDate = tmpDate - Double(timeZoneOffset) - dstOffset

        return tmpDate
    }


    // MARK: - Julian day number calculation
    // Algorithm from Explanatory Supplement to the Astronomical Almanac, ch 15. Calendars, by E.G. Richards
    // Return day and month are 1-based
    static func yearMonthDayFromJulianDay(_ julianDay: Int, useJulianRef: Bool) -> (year: Int, month: Int, day: Int) {
        let y = 4716 // number of years from epoch of computation to epoch of calendar
        let j = 1401 // number of days from the epoch of computation to the first day of the Julian period
        let m = 2 // value of M for which M' is zero
        let n = 12 // the number of effective months in the year, counting the epagomenal days of the mobile calendars as an additional month
        let r = 4 // number of years in leap-year cycle
        let p = 1461
        // let q = 0
        let v = 3
        let u = 5 // length of any cycle there may be in the pattern of month lengths
        let s = 153
        // let t = 2
        let w = 2
        // let A = 184
        let B = 274277
        let C = -38
        let f1 = julianDay + j
        let f: Int
        if useJulianRef {
            f = f1
        } else {
            // Gregorian
            f = f1 + (((4 * julianDay + B) / 146097) * 3) / 4 + C
        }
        let e = r * f + v
        func remainder(numerator: Int, denominator: Int ) -> Int {
            let r = numerator % denominator
            return r >= 0 ? r : r + denominator
        }
        let g = remainder(numerator: e, denominator: p) / r
        let h = u * g + w
        func floorDivide(_ numerator: Int, _ denominator: Int) -> Int {
            return (numerator >= 0) ?
                numerator / denominator : ((numerator + 1) / denominator) - 1
        }
        let day = floorDivide((h % s), u)  + 1 // day of month
        let month = ((floorDivide(h, s) + m) % n) + 1
        let year = floorDivide(e, p) - y + (n + m - month) / n

        return (year, month, day)
    }

    // day and month are 1-based
    static func julianDay(ofDay day: Int, month: Int, year: Int, useJulianReference: Bool = false) -> Int {
        let y = 4716 // number of years from epoch of computation to epoch of calendar
        let j = 1401 // number of days from the epoch of computation to the first day of the Julian period
        let m = 2 // value of M for which M' is zero
        let n = 12 // the number of effective months in the year, counting the epagomenal days of the mobile calendars as an additional month
        let r = 4 // number of years in leap-year cycle
        let p = 1461
        let q = 0
        let u = 5 // length of any cycle there may be in the pattern of month lengths
        let s = 153
        let t = 2
        let A = 184
        let C = -38

        let h = month - m
        let g = year + y - (n - h) / n
        let f = (h - 1 + n) % n
        let e = (p * g + q) / r + day - 1 - j
        let J = e + (s * f + t) / u
        let julianDayNumber: Int
        if useJulianReference {
            julianDayNumber = J
        } else { // Gregorian calendar
            julianDayNumber = J - (3 * ((g + A) / 100)) / 4 - C
        }
        return julianDayNumber
    }

    // MARK: -
    func useJulianReference(_ date: Date) -> Bool {
        return date < gregorianStartDate
    }

    func dayOfYear(fromYear year: Int, month: Int, day: Int) -> Int {
        let daysBeforeMonthNonLeap = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let daysBeforeMonthLeap =    [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

        let julianDay = Self.julianDay(ofDay: day, month: month, year: year)
        let useJulianCalendar = julianDay < julianCutoverDay
        let isLeapYear = gregorianYearIsLeap(year)
        var dayOfYear = (isLeapYear ? daysBeforeMonthLeap : daysBeforeMonthNonLeap)[month - 1] + day
        if !useJulianCalendar && year == gregorianStartYear {
            // Use julian's week number for 1582, so recalculate day of year
            let gregorianDayShift = (year - 1) / 400 - (year - 1) / 100 + 2
            dayOfYear += gregorianDayShift
        }
        return dayOfYear
    }

    func gregorianYearIsLeap(_ year: Int) -> Bool {
        if year >= gregorianStartYear {
            return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
        } else {
            return (year % 4 == 0)
        }
    }

    // from ICU calendar.cpp
    func weekNumber(desiredDay: Int, dayOfPeriod: Int, weekday: Int) -> Int {
        // Determine the day of the week of the first day of the period in question (either a year or a month).  Zero represents the first day of the week on this calendar.
        var periodStartDayOfWeek = (weekday - firstWeekday - dayOfPeriod + 1) % 7
        if periodStartDayOfWeek < 0 { periodStartDayOfWeek += 7 }

        // Compute the week number.  Initially, ignore the first week, which may be fractional (or may not be).  We add periodStartDayOfWeek in order to fill out the first week, if it is fractional.
        var weekNo = (desiredDay + periodStartDayOfWeek - 1) / 7

        // If the first week is long enough, then count it.  If the minimal days in the first week is one, or if the period start is zero, we always increment weekNo.
        if ((7 - periodStartDayOfWeek) >= minimumDaysInFirstWeek) { weekNo = weekNo + 1 }

        return weekNo
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        let date = date + Double(timeZone.secondsFromGMT(for: date))

        let julianDay = date.julianDay

        let useJulianRef = useJulianReference(date)

        var timeInDay = date.timeIntervalSinceReferenceDate.remainder(dividingBy: 86400)
        if (timeInDay < 0) {
            timeInDay += 86400
        }

        var (year, month, day) = Self.yearMonthDayFromJulianDay(julianDay, useJulianRef: useJulianRef)
        let isLeapYear = gregorianYearIsLeap(year)


        let hour = Int(timeInDay / 3600) // zero-based
        timeInDay = timeInDay.truncatingRemainder(dividingBy: 3600.0)

        let minute = Int(timeInDay / 60)
        timeInDay = timeInDay.truncatingRemainder(dividingBy: 60.0)

        let second = Int(timeInDay)
        timeInDay = timeInDay.truncatingRemainder(dividingBy: 1)

        let nanosecond = Int(timeInDay * 1_000_000_000)
        // To calculate day of year, work backwards with month/day
        let dayOfYear = dayOfYear(fromYear: year, month: month, day: day)

        func remainder(numerator: Int, denominator: Int ) -> Int {
            let r = numerator % denominator
            return r >= 0 ? r : r + denominator
        }
        // Week of year calculation, from ICU calendar.cpp :: computeWeekFields
        // 1-based: 1...7
        let weekday = remainder(numerator: julianDay + 1, denominator: 7) + 1

        // 0-based 0...6
        let relativeWeekday = (weekday + 7 - firstWeekday) % 7
        let relativeWeekdayForJan1 = (weekday - dayOfYear + 7001 - firstWeekday) % 7
        var weekOfYear = (dayOfYear - 1 + relativeWeekdayForJan1) / 7 // 0...53
        if (7 - relativeWeekdayForJan1) >= minimumDaysInFirstWeek {
            weekOfYear += 1
        }

        var yearForWeekOfYear = year
        // Adjust for weeks at end of the year that overlap into previous or next calendar year
        if weekOfYear == 0 {
            let previousDayOfYear = dayOfYear + (gregorianYearIsLeap(year - 1) ? 366 : 365)
            weekOfYear = weekNumber(desiredDay: previousDayOfYear, dayOfPeriod: previousDayOfYear, weekday: weekday)
            yearForWeekOfYear -= 1
        } else {
            let lastDayOfYear = (gregorianYearIsLeap(year) ? 366 : 365)
            // Fast check: For it to be week 1 of the next year, the DOY
            // must be on or after L-5, where L is yearLength(), then it
            // cannot possibly be week 1 of the next year:
            //          L-5                  L
            // doy: 359 360 361 362 363 364 365 001
            // dow:      1   2   3   4   5   6   7
            if dayOfYear >= lastDayOfYear - 5 {
                var lastRelativeDayOfWeek = (relativeWeekday + lastDayOfYear - dayOfYear) % 7
                if lastRelativeDayOfWeek < 0 {
                    lastRelativeDayOfWeek += 7
                }

                if ((6 - lastRelativeDayOfWeek) >= minimumDaysInFirstWeek) && ((dayOfYear + 7 - relativeWeekday) > lastDayOfYear) {
                    weekOfYear = 1
                    yearForWeekOfYear += 1
                }
            }
        }

        let weekOfMonth = weekNumber(desiredDay: day, dayOfPeriod: day, weekday: weekday)
        let weekdayOrdinal = (day - 1) / 7 + 1

        var dc = DateComponents()
        if components.contains(.calendar) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            dc.calendar = calendar
        }
        if components.contains(.timeZone) { dc.timeZone = timeZone }
        if components.contains(.era) {
            let era: Int
            if year < 1 {
                era = 0
            } else {
                era = 1
            }
            dc.era = era
        }
        if components.contains(.year) {
            if year < 1 {
                year = 1 - year
            }
            dc.year = year
        }
        if components.contains(.month) { dc.month = month }
        if components.contains(.day) { dc.day = day }
        if components.contains(.dayOfYear) { dc.dayOfYear = dayOfYear }
        if components.contains(.hour) { dc.hour = hour }
        if components.contains(.minute) { dc.minute = minute }
        if components.contains(.second) { dc.second = second }
        if components.contains(.weekday) { dc.weekday = weekday }
        if components.contains(.weekdayOrdinal) { dc.weekdayOrdinal = weekdayOrdinal }
        if components.contains(.quarter) {
            let quarter = if !isLeapYear {
                if dayOfYear < 90 { 1 }
                else if dayOfYear < 181 { 2 }
                else if dayOfYear < 273 { 3 }
                else if dayOfYear < 366 { 4 }
                else { fatalError() }
            } else {
                if dayOfYear < 91 { 1 }
                else if dayOfYear < 182 { 2 }
                else if dayOfYear < 274 { 3 }
                else if dayOfYear < 367 { 4 }
                else { fatalError() }
            }

            dc.quarter = quarter
        }
        if components.contains(.weekOfMonth) { dc.weekOfMonth = weekOfMonth }
        if components.contains(.weekOfYear) { dc.weekOfYear = weekOfYear }
        if components.contains(.yearForWeekOfYear) { dc.yearForWeekOfYear = yearForWeekOfYear }
        if components.contains(.nanosecond) { dc.nanosecond = nanosecond }

        if components.contains(.isLeapMonth) || components.contains(.month) { dc.isLeapMonth = false }
        return dc
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        dateComponents(components, from: date, in: timeZone)
    }

    func dateComponent(_ component: Calendar.Component, from date: Date) -> Int {
        guard let value = dateComponents(.init(single: component), from: date, in: timeZone).value(for: component) else {
            preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
        }
        return value
    }

    // MARK: - Add

    // Returns the weekday of the last day of the month or the year, using `referenceDayOfPeriod` and `referenceDayWeekday` as the reference
    func relativeWeekdayForLastDayOfPeriod(periodLength: Int, referenceDayOfPeriod dayOfPeriod: Int, referenceDayWeekday weekday: Int) -> Int {
        return (periodLength - dayOfPeriod + weekday - firstWeekday) % 7
    }

    // Returns the "adjusted" day of month considering gregorian cutover:
    // In the Gregorian cutover month, 10 days were taken away -- Thursday, Oct 4, 1582 was followed by Friday, Oct 15, 1582
    // This affects the length of month and the start of the month of a given date if it falls in the cutover month
    func dayOfMonthConsideringGregorianCutover(_ date: Date, inTimeZone timeZone: TimeZone) -> (dayOfMonthAdjustingJulianDay: Int, monthStart: Date, monthLen: Int, isCutover: Bool) {
        let dc = dateComponents([.year, .month, .day], from: date, in: timeZone)
        guard let year = dc.year, let month = dc.month, let day = dc.day else {
            preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
        }
        let monthLen = numberOfDaysInMonth(month, year: year)
        guard year == gregorianStartYear else {
            let monthStartDate = date - Double((day - 1) * kSecondsInDay)
            return (day, monthStartDate, monthLen, false)
        }

        let kCutoverMonthRollbackDays = 10
        let attemptDayOfMonth: Int
        if date >= gregorianStartDate {
            attemptDayOfMonth = day - kCutoverMonthRollbackDays
        } else {
            attemptDayOfMonth = day
        }
        let monthStartDate = date - Double((attemptDayOfMonth - 1) * kSecondsInDay)
        let monthEndDateForCutoverMonth = monthStartDate + Double((monthLen - kCutoverMonthRollbackDays) * kSecondsInDay)
        if monthStartDate < gregorianStartDate && monthEndDateForCutoverMonth >= gregorianStartDate {
            // this month is the cutover month
            return (attemptDayOfMonth, monthStartDate, monthLen - kCutoverMonthRollbackDays, true)
        }

        return (day, monthStartDate, monthLen, false)
    }

    // Limits the day of month to the number of days in the given month
    func capDay(in dateComponent: inout DateComponents) {
        guard let day = dateComponent.day, let month = dateComponent.month, let year = dateComponent.year else {
            return
        }

        let daysInMonth = numberOfDaysInMonth(month, year: year)
        if day > daysInMonth {
            dateComponent.day = daysInMonth
        } else if day < 1 {
            dateComponent.day = 1
        }
    }

    // TODO: This is almost identical to Calendar_ICU's _locked_timeZoneTransitionInterval. We should refactor to share code
    func timeZoneTransitionInterval(at date: Date, timeZone: TimeZone) -> DateInterval? {
        // if the given time is before 1900, assume there is no dst transition yet
        if date.timeIntervalSinceReferenceDate < -3187299600.0 {
            return nil
        }

        // start back 48 hours
        let start = date - 48.0 * 60.0 * 60.0
        let limit = start + 4 * 86400 * 1000 // ???
        guard let nextDSTTransition = timeZone.nextDaylightSavingTimeTransition(after: start), nextDSTTransition < limit else {
            return nil
        }

        // the transition must be at or before "date" if "date" is within the repeated time frame
        if nextDSTTransition > date {
            return nil
        }

        // gmt offset includes dst offset
        let preOffset = timeZone.secondsFromGMT(for: nextDSTTransition - 1.0)
        let nextOffset = timeZone.secondsFromGMT(for: nextDSTTransition + 1.0)
        let diff = preOffset - nextOffset

        // gmt offset before the transition > gmt offset after the transition => backward dst transition
        if diff > 0 && date >= nextDSTTransition && date < (nextDSTTransition + Double(diff)) {
            return DateInterval(start: nextDSTTransition, duration: Double(diff))
        }

        return nil
    }

    func add(_ field: Calendar.Component, to date: Date, amount: Int, inTimeZone timeZone: TimeZone) -> Date {

        let amountInSeconds: Int
        var nanoseconds: Double = 0

        // month-based calculations uses .month and .year, while week-based uses .weekOfYear and .yearForWeekOfYear.
        // When performing date adding calculations, we need to be specific whether it's "month based" or "week based". We do not want existing week-related fields in the DateComponents to conflict with the newly set month-related fields when doing month-based calculation, and vice versa. So it's necessary to only include relevant components rather than all components when performing adding calculation.
        let monthBasedComponents : Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond]
        let weekBasedComponents: Calendar.ComponentSet = [.era, .weekday, .weekOfYear, .yearForWeekOfYear, .hour, .minute, .second, .nanosecond ]

        var result: Date?

        switch field {
        case .era:
            // We've been ignorning era historically. Do the same for compatibility reason.
            return date

        case .yearForWeekOfYear:
            var dc = dateComponents(weekBasedComponents, from: date, in: timeZone)
            var amount = amount
            if let era = dc.era, era == 0 {
                amount = -amount
            }
            dc.yearForWeekOfYear = (dc.yearForWeekOfYear ?? 0) + amount
            capDay(in: &dc)
            // Use .latter for `repeatedTimePolicy` since we handle the repeated time below ourself
            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!

        case .year:
            var dc = dateComponents(monthBasedComponents, from: date, in: timeZone)
            var amount = amount
            if let era = dc.era, era == 0 {
                amount = -amount
            }
            dc.year = (dc.year ?? 0) + amount
            capDay(in: &dc)
            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!

        case .month:
            var dc = dateComponents(monthBasedComponents, from: date, in: timeZone)
            dc.month = (dc.month ?? 0) + amount
            capDay(in: &dc) // adding 1 month to Jan 31 should return Feb 29, not Feb 31
            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!
        case .quarter:
            // TODO: This isn't supported in Calendar_ICU either. We should do it here though.
            return date
            // nothing to do for the below fields
        case .calendar, .timeZone, .isLeapMonth:
            return date
        case .day, .dayOfYear, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfMonth, .weekOfYear, .nanosecond:
            // Handle below
            break
        }

        // If the new date falls in the repeated hour during DST transition day, rewind it back to the first occurrence of that time
        if let result {
            if amount > 0, let interval = timeZoneTransitionInterval(at: result, timeZone: timeZone) {
                let adjusted = result - interval.duration
                return adjusted
            } else {
                return result
            }
        }

        // The time in the day should remain unchanged when adding units larger than hour
        let keepWallTime: Bool
        switch field {
        case .weekdayOrdinal:
            amountInSeconds = kSecondsInWeek * amount
            keepWallTime = true

        case .weekOfMonth:
            amountInSeconds = kSecondsInWeek * amount
            keepWallTime = true

        case .weekOfYear:
            amountInSeconds = kSecondsInWeek * amount
            keepWallTime = true

        case .day, .dayOfYear, .weekday:
            amountInSeconds = amount * kSecondsInDay
            keepWallTime = true

        case .hour:
            amountInSeconds = amount * kSecondsInHour
            keepWallTime = false

        case .minute:
            amountInSeconds = amount * 60
            keepWallTime = false

        case .second:
            amountInSeconds = amount
            keepWallTime = false

        case .nanosecond:
            amountInSeconds = 0
            nanoseconds = Double(amount) / 1_000_000_000
            keepWallTime = false

        case .era, .year, .month, .quarter, .yearForWeekOfYear, .calendar, .timeZone, .isLeapMonth:
            preconditionFailure("Should not reach")
        }


        var newDate = date + Double(amountInSeconds) + nanoseconds

        if keepWallTime {
            let newOffset = timeZone.daylightSavingTimeOffset(for: newDate)
            let prevOffset = timeZone.daylightSavingTimeOffset(for: date)
            // No need for normal gmt-offset adjustment because the revelant bits are handled above individually
            // We do have to adjust DST offset when the new date crosses DST boundary, such as adding an hour to dst transitioning day
            if newOffset != prevOffset {
                newDate = newDate + Double(prevOffset - newOffset)
            }

            // If the new date falls in the repeated hour during DST transition day, rewind it back to the first occurrence of that time
            if amount > 0, let interval = timeZoneTransitionInterval(at: newDate, timeZone: timeZone) {
                newDate = newDate - interval.duration
            }
        }

        return newDate
    }


    func add(amount: Int, to value: Int, wrappingTo range: Range<Int>) -> Int {
        guard amount != 0 else {
            return value
        }

        var newValue = (value + amount - range.lowerBound) % range.count
        if newValue < 0 {
            newValue += range.count
        }
        newValue += range.lowerBound
        return newValue
    }

    func addAndWrap(_ field: Calendar.Component, to date: Date, amount: Int, inTimeZone timeZone: TimeZone) -> Date {

        guard amount != 0 else {
            return date
        }

        // month-based calculations uses .day, .month, and .year, while week-based uses .weekday, .weekOfYear and .yearForWeekOfYear.
        // When performing date adding calculations, we need to be specific whether it's "month based" or "week based". We do not want existing week-related fields in the DateComponents to conflict with the newly set month-related fields when doing month-based calculation, and vice versa. So it's necessary to only include relevant components rather than all components when performing adding calculation.
        let monthBasedComponents : Calendar.ComponentSet = [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond]
        let weekBasedComponents: Calendar.ComponentSet = [.era, .weekday, .weekOfYear, .yearForWeekOfYear, .hour, .minute, .second, .nanosecond ]

        var result: Date

        switch field {
        case .era:
            // FCF ignores era
            return date

        case .year:
            var dc = dateComponents(monthBasedComponents, from: date, in: timeZone)
            guard let year = dc.year else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            var amount = amount
            if dc.era == 0 /* BC */ {
                // in BC year goes backwards
                amount = -amount
            }

            var newValue = year + amount
            if newValue < 1 {
                newValue = 1
            }
            dc.year = newValue
            capDay(in: &dc) // day in month may change if the year changes from a leap year to a non-leap year for Feb

            // Use .latter for `repeatedTimePolicy` since we handle the repeated time below ourself
            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!

        case .month:
            var dc = dateComponents(monthBasedComponents, from: date, in: timeZone)
            guard let month = dc.month else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            let newMonth = add(amount: amount, to: month, wrappingTo: 1..<13)
            dc.month = newMonth

            capDay(in: &dc) // adding 1 month to Jan 31 should return Feb 29, not Feb 31
            result = self.date(from: dc, inTimeZone: timeZone)!

        case .dayOfYear:
            var monthIncludingDayOfYear = monthBasedComponents
            monthIncludingDayOfYear.insert(.dayOfYear)
            let dc = dateComponents(monthIncludingDayOfYear, from: date, in: timeZone)
            guard let year = dc.year, let dayOfYear = dc.dayOfYear else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            
            let range: Range<Int>
            if gregorianYearIsLeap(year) {
                // max is 366
                range = 1..<367
            } else {
                // max is 365
                range = 1..<366
            }
            
            let newDayOfYear = add(amount: amount, to: dayOfYear, wrappingTo: range)
            // Clear the month and day from the date components. Keep the era, year, and time values (hour, min, etc.)
            var adjustedDateComponents = dc
            adjustedDateComponents.month = nil
            adjustedDateComponents.day = nil
            adjustedDateComponents.dayOfYear = newDayOfYear
            result = self.date(from: adjustedDateComponents, inTimeZone: timeZone)!
           
        case .day:
            let (_, monthStart, daysInMonth, inGregorianCutoverMonth) = dayOfMonthConsideringGregorianCutover(date, inTimeZone: timeZone)

            if inGregorianCutoverMonth {
                // Manipulating time directly generally does not work with DST. In these cases we want to go through our normal path as below
                let monthLengthInSec = Double(daysInMonth * kSecondsInDay)
                var timeIntervalIntoMonth = (date.timeIntervalSince(monthStart) + Double(amount * kSecondsInDay)).remainder(dividingBy: monthLengthInSec)
                if timeIntervalIntoMonth < 0 {
                    timeIntervalIntoMonth += monthLengthInSec
                }
                return monthStart + timeIntervalIntoMonth
            } else {
                var dc = dateComponents(monthBasedComponents, from: date, in: timeZone)

                let day = dateComponent(.day, from: date)
                let range = minMaxRange(of: .day, in: dc)!
                let newDay = add(amount: amount, to: day, wrappingTo: range)
                dc.day = newDay
                result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!
            }

        case .hour:
            let dc = dateComponents([.hour], from: date, in: timeZone)
            guard let hour = dc.hour else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }

            let newHour = add(amount: amount, to: hour, wrappingTo: 0..<24)
            let newDate = date + Double((newHour - hour) * kSecondsInHour)
            return newDate

        case .minute:
            let minute = dateComponent(.minute, from: date)
            let newMinute = add(amount: amount, to: minute, wrappingTo: 0..<60)
            let newDate = date + Double((newMinute - minute) * kSecondsInMinute)

            return newDate

        case .second:
            let second = dateComponent(.second, from: date)
            let newSecond = add(amount: amount, to: second, wrappingTo: 0..<60)
            let newDate = date + Double(newSecond - second)
            return newDate

        case .weekday:
            let weekday = dateComponent(.weekday, from: date)
            var dayOffset = weekday - firstWeekday
            if dayOffset < 0 {
                dayOffset += 7
            }

            let rewindedDate = date - Double(dayOffset * kSecondsInDay) // shifted date considering first day of week
            let newDate = date + Double(amount * kSecondsInDay)

            var newSecondsOffset = newDate.timeIntervalSince(rewindedDate)
            newSecondsOffset = newSecondsOffset.remainder(dividingBy: Double(kSecondsInWeek))  // constrain the offset to fewer than a week
            if newSecondsOffset < 0 {
                newSecondsOffset += Double(kSecondsInWeek)
            }

            result = rewindedDate + newSecondsOffset

        case .weekdayOrdinal:
            // similar to weekday calculation
            let dc = dateComponents([.day, .month, .year], from: date, in: timeZone)
            guard let year = dc.year, let day = dc.day, let month = dc.month else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            let preWeeks = (day - 1) / 7
            let numberOfDaysInMonth = numberOfDaysInMonth(month, year: year)
            let postWeeks = (numberOfDaysInMonth - day) / 7
            let rewindedDate = date - Double(preWeeks * kSecondsInWeek) // same time in the day on the first same weekday in the month
            let newDate = date + Double(amount * kSecondsInWeek)
            let gap = Double((preWeeks + postWeeks + 1) * kSecondsInWeek) // number of seconds in this month, calculated based on the number of weeks
            var newSecondsOffset = newDate.timeIntervalSince(rewindedDate)
            newSecondsOffset = newSecondsOffset.remainder(dividingBy: gap) // constrain the offset to fewer than a month, starting from the first weekday of the month
            if newSecondsOffset < 0 {
                newSecondsOffset += gap
            }

            result = rewindedDate + newSecondsOffset

        case .quarter:
            // TODO: This isn't supported in Calendar_ICU either. We should do it here though.
            return date

        case .weekOfMonth:
            let tzOffset = timeZone.secondsFromGMT(for: date)
            let date = date + Double(tzOffset)
            guard let weekday = dateComponents([.weekday], from: date, in: .gmt).weekday else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            let (dayOfMonth, monthStart, nDaysInMonth, inGregorianCutoverMonth) = dayOfMonthConsideringGregorianCutover(date, inTimeZone: .gmt)

            // needs special handling of the first and last week if it's an incomplete week
            var relativeWeekday = weekday - firstWeekday // 0...6
            if relativeWeekday < 0 {
                relativeWeekday += 7
            }

            var relativeWeekdayForFirstOfMonth = (relativeWeekday - dayOfMonth + 1) % 7 // relative weekday for the first day of the month, 0...6
            if relativeWeekdayForFirstOfMonth < 0 {
                relativeWeekdayForFirstOfMonth += 7
            }

            // handle the first week (may be partial)
            let startDayForFirstWeek: Int // the day number for the first day of the first full week of the month
            if 7 - relativeWeekdayForFirstOfMonth < minimumDaysInFirstWeek {
                startDayForFirstWeek = 8 - relativeWeekdayForFirstOfMonth
            } else {
                startDayForFirstWeek = 1 - relativeWeekdayForFirstOfMonth
            }

            // handle the last week (may be partial)
            let relativeWeekdayForLastOfMonth = relativeWeekdayForLastDayOfPeriod(periodLength: nDaysInMonth, referenceDayOfPeriod: dayOfMonth, referenceDayWeekday: weekday)
            let endDayForLastWeek = nDaysInMonth + (7 - relativeWeekdayForLastOfMonth) // the day number for the last day of the last full week of the month. relative weekday of this day should be 0

            var newDayOfMonth = add(amount: amount * 7, to: dayOfMonth, wrappingTo: startDayForFirstWeek ..< endDayForLastWeek)

            // newDayOfMonth now falls in the full block that might extend the actual month. Now pin it back to the actual month
            if newDayOfMonth < 1 {
                newDayOfMonth = 1
            } else if newDayOfMonth > nDaysInMonth {
                newDayOfMonth = nDaysInMonth
            }

            // Manipulating time directly does not work well with DST. Go through our normal path as below
            if inGregorianCutoverMonth {
                return monthStart + TimeInterval((newDayOfMonth - 1) * kSecondsInDay) - TimeInterval(tzOffset)
            } else {
                var dc = dateComponents(monthBasedComponents, from: date, in: .gmt)
                dc.day = newDayOfMonth
                result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!
            }

        case .weekOfYear:
            func yearLength(_ year: Int) -> Int {
                return gregorianYearIsLeap(year) ? 366 : 365
            }

            var dc = dateComponents(weekBasedComponents, from: date, in: timeZone)
            guard let weekOfYear = dc.weekOfYear, let yearForWeekOfYear = dc.yearForWeekOfYear, let weekday = dc.weekday else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }
            var newWeekOfYear = weekOfYear + amount
            if newWeekOfYear < 1 || newWeekOfYear > 52 {
                let work = dateComponents([.month, .year, .day], from: date)
                guard let month = work.month, let year = work.year, let day = work.day else {
                    preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
                }
                var isoDayOfYear = dayOfYear(fromYear: year, month: month, day: day)
                if month == 1 && weekOfYear > 52 {
                    // the first week of the next year
                    isoDayOfYear += yearLength(yearForWeekOfYear)
                } else if month != 1 && weekOfYear == 1 {
                    // the last week of the previous year
                    isoDayOfYear -= yearLength(yearForWeekOfYear - 1)
                }

                var lastDoy = yearLength(yearForWeekOfYear)
                let relativeWeekdayForLastOfYear = relativeWeekdayForLastDayOfPeriod(periodLength: lastDoy, referenceDayOfPeriod: isoDayOfYear, referenceDayWeekday: weekday)
                if 6 - relativeWeekdayForLastOfYear >= minimumDaysInFirstWeek {
                    // last week for this year needs to go to the next year
                    lastDoy -= 7
                }
                let lastWeekOfYear = weekNumber(desiredDay: lastDoy, dayOfPeriod: lastDoy, weekday: relativeWeekdayForLastOfYear + 1)
                newWeekOfYear = (newWeekOfYear + lastWeekOfYear - 1) % lastWeekOfYear + 1
            }

            dc.weekOfYear = newWeekOfYear

            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!

        case .yearForWeekOfYear:
            // basically the same as year calculation
            var dc = dateComponents(weekBasedComponents, from: date, in: timeZone)
            guard let yearForWeekOfYear = dc.yearForWeekOfYear else {
                preconditionFailure("dateComponents(:from:in:) unexpectedly returns nil for requested component")
            }

            var amount = amount
            if dc.era == 0 /* BC */ {
                // in BC year goes backwards
                amount = -amount
            }

            var newValue = yearForWeekOfYear + amount
            if newValue < 1 {
                newValue = 1
            }
            dc.yearForWeekOfYear = newValue
            capDay(in: &dc) // day in month may change if the year changes from a leap year to a non-leap year for Feb

            result = self.date(from: dc, inTimeZone: timeZone, dstRepeatedTimePolicy: .latter)!

        case .nanosecond:
            return date + (Double(amount) * 1.0e-9)
        case .calendar, .timeZone, .isLeapMonth:
            return date
        }

        // If the new date falls in the repeated hour during DST transition day, rewind it back to the first occurrence of that time
        if amount > 0, let interval = timeZoneTransitionInterval(at: result, timeZone: timeZone) {
            result = result - interval.duration
        }

        return result
    }


    func date(byAddingAndWrapping components: DateComponents, to date: Date) -> Date? {
        let timeZone = components.timeZone ?? self.timeZone
        var result = date
        // No leap month support needed here, since these are quantities, not values
        if let amount = components.era {
            result = addAndWrap(.era, to: result, amount: amount, inTimeZone: timeZone) }
        if let amount = components.year {
            result = addAndWrap(.year, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.yearForWeekOfYear {
            result = addAndWrap(.yearForWeekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.quarter { 
            result = addAndWrap(.quarter, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.month {
            result = addAndWrap(.month, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.day {
            result = addAndWrap(.day, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.dayOfYear {
            result = addAndWrap(.dayOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekOfYear {
            result = addAndWrap(.weekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        // `week` is for backward compatibility only, and is only used if weekOfYear is missing
        if let amount = components.week, components.weekOfYear == nil {
            result = addAndWrap(.weekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekOfMonth {
            result = addAndWrap(.weekOfMonth, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekday {
            result = addAndWrap(.weekday, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekdayOrdinal {
            result = addAndWrap(.weekdayOrdinal, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.hour {
            result = addAndWrap(.hour, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.minute {
            result = addAndWrap(.minute, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.second {
            result = addAndWrap(.second, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.nanosecond { 
            result = addAndWrap(.nanosecond, to: result, amount: amount, inTimeZone: timeZone)
        }
        return result
    }

    func date(byAddingAndCarryingOverComponents components: DateComponents, to date: Date) -> Date? {
        let timeZone = components.timeZone ?? self.timeZone
        var result = date
        // No leap month support needed here, since these are quantities, not values
        if let amount = components.era {
            result = add(.era, to: result, amount: amount, inTimeZone: timeZone) }
        if let amount = components.year {
            result = add(.year, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.yearForWeekOfYear {
            result = add(.yearForWeekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.quarter {
            result = add(.quarter, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.month {
            result = add(.month, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.day {
            result = add(.day, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.dayOfYear {
            result = add(.dayOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekOfYear {
            result = add(.weekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }
        // `week` is for backward compatibility only, and is only used if weekOfYear is missing
        if let amount = components.week, components.weekOfYear == nil {
            result = add(.weekOfYear, to: result, amount: amount, inTimeZone: timeZone)
        }        
        if let amount = components.weekOfMonth {
            result = add(.weekOfMonth, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekday {
            result = add(.weekday, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.weekdayOrdinal {
            result = add(.weekdayOrdinal, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.hour {
            result = add(.hour, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.minute {
            result = add(.minute, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.second {
            result = add(.second, to: result, amount: amount, inTimeZone: timeZone)
        }
        if let amount = components.nanosecond { 
            result = add(.nanosecond, to: result, amount: amount, inTimeZone: timeZone)
        }
        return result
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        if wrappingComponents {
            return self.date(byAddingAndWrapping: components, to: date)
        } else {
            return self.date(byAddingAndCarryingOverComponents: components, to: date)
        }
    }

    // MARK: Differences

    // Calendar::fieldDifference
    func difference(inComponent component: Calendar.Component, from start: Date, to end: Date) throws -> (difference: Int, newStart: Date) {
        guard end != start else {
            return (0, start)
        }

        switch component {
        case .calendar, .timeZone, .isLeapMonth:
            preconditionFailure("Invalid arguments")

        case .era:
            // Special handling since `add` below doesn't work with `era`
            let currEra = dateComponent(.era, from: start)
            let goalEra = dateComponent(.era, from: end)

            return (goalEra - currEra, start)
        case .nanosecond:
            let diffInNano = end.timeIntervalSince(start).remainder(dividingBy: 1) * 1.0e+9
            let diff = diffInNano < Double(Int32.max) ? Int(diffInNano) : Int(Int32.max)
            let advanced = add(component, to: start, amount: diff, inTimeZone: timeZone)
            return (diff, advanced)

        case .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear:
            // continue to below
            break
        }

        let forward = end > start
        var max = forward ? 1 : -1
        var min = 0
        while true {
            let ms = add(component, to: start, amount: max, inTimeZone: timeZone)
            guard forward ? (ms > start) : (ms < start) else {
                throw GregorianCalendarError.notAdvancing(start, ms)
            }

            if ms == end {
                return (max, ms)
            } else if (forward && ms > end) || (!forward && ms < end) {
                break
            } else {
                min = max
                max <<= 1
                guard forward ? max >= 0 : max < 0 else {
                    throw GregorianCalendarError.overflow(component, start, end)
                }
            }
        }

        // Binary search
        while (forward && (max - min) > 1) || (!forward && (min - max > 1)) {
            let t = min + (max - min) / 2

            let ms = add(component, to: start, amount: t, inTimeZone: timeZone)
            if ms == end {
                return (t, ms)
            } else if (forward && ms > end) || (!forward && ms < end) {
                max = t
            } else {
                min = t
            }
        }

        let advanced = add(component, to: start, amount: min, inTimeZone: timeZone)

        return (min, advanced)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        let cappedStart = start.capped
        let cappedEnd = end.capped

        let subseconds = cappedStart.timeIntervalSinceReferenceDate.remainder(dividingBy: 1)

        var curr = cappedStart  - subseconds
        let goal = cappedEnd - subseconds
        func orderedComponents(_ components: Calendar.ComponentSet) -> [Calendar.Component] {
            var comps: [Calendar.Component] = []
            if components.contains(.era) {
                comps.append(.era)
            }
            if components.contains(.year) {
                comps.append(.year)
            }
            if components.contains(.yearForWeekOfYear) {
                comps.append(.yearForWeekOfYear)
            }
            if components.contains(.quarter) {
                comps.append(.quarter)
            }
            if components.contains(.month) {
                comps.append(.month)
            }
            if components.contains(.weekOfYear) {
                comps.append(.weekOfYear)
            }
            if components.contains(.weekOfMonth) {
                comps.append(.weekOfMonth)
            }
            if components.contains(.day) {
                comps.append(.day)
            }
            if components.contains(.weekday) {
                comps.append(.weekday)
            }
            if components.contains(.weekdayOrdinal) {
                comps.append(.weekdayOrdinal)
            }
            if components.contains(.hour) {
                comps.append(.hour)
            }
            if components.contains(.minute) {
                comps.append(.minute)
            }
            if components.contains(.second) {
                comps.append(.second)
            }

            if components.contains(.nanosecond) {
                comps.append(.nanosecond)
            }

            return comps
        }

        var dc = DateComponents()

        for component in orderedComponents(components) {
            switch component {
            case .era, .year, .month, .day, .dayOfYear, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfYear, .yearForWeekOfYear, .weekOfMonth, .nanosecond:
                do {
                    let (diff, newStart) = try difference(inComponent: component, from: curr, to: goal)
                    dc.setValue(diff, for: component)
                    curr = newStart
                } catch let error as GregorianCalendarError {
#if canImport(os)
                    switch error {
                    case .overflow(_, _, _):
                        _CalendarGregorian.logger.error("Overflowing in dateComponents(from:start:end:). start: \(start.timeIntervalSinceReferenceDate, privacy: .public). end: \(end.timeIntervalSinceReferenceDate, privacy: .public). component: \(component.debugDescription, privacy: .public)")
                    case .notAdvancing(_, _):
                        _CalendarGregorian.logger.error("Not advancing in dateComponents(from:start:end:). start: \(start.timeIntervalSinceReferenceDate, privacy: .public) end: \(end.timeIntervalSinceReferenceDate, privacy: .public) component: \(component.debugDescription, privacy: .public)")
                    }
#endif
                    dc.setValue(0, for: component)
                } catch {
                    preconditionFailure("Unknown error: \(error)")
                }

            case .timeZone, .isLeapMonth, .calendar:
                // No leap month support needed here, since these are quantities, not values
                break
            case .quarter:
                // Currently unsupported so always return 0
                dc.quarter = 0
            }
        }

        return dc
    }
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        Calendar(identifier: .gregorian) as NSCalendar
    }
#endif
    
}
