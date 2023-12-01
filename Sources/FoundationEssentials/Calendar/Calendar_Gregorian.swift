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

    case day(year: Int, month: Int, day: Int?, weekOfYear: Int?)
    case weekdayOrdinal(year: Int, month: Int, weekdayOrdinal: Int, weekday: Int?)
    case weekOfYear(year: Int, weekOfYear: Int?, weekday: Int?)
    case weekOfMonth(year: Int, month: Int, weekOfMonth: Int, weekday: Int?)

    // Pick the year field between yearForWeekOfYear and year and resovles era
    static func yearMonth(forDateComponent components: DateComponents) -> (year: Int, month: Int) {
        var rawYear: Int
        if let yearForWeekOfYear = components.yearForWeekOfYear {
            rawYear = yearForWeekOfYear
        } else if let year = components.year {
            rawYear = year
        } else {
            rawYear = 1
        }

        if components.era == 0 /* BC */{
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

    init(preferComponent c: Calendar.Component, dateComponents components: DateComponents) {
        let minWeekdayOrdinal = 1
        switch c {
        case .day:
            let (rawYear, month) = Self.yearMonth(forDateComponent: components)
            self = .day(year: rawYear, month: month, day: components.day, weekOfYear: components.weekOfYear)
        case .weekday:
            let (rawYear, month) = Self.yearMonth(forDateComponent: components)
            if let woy = components.weekOfYear {
                self = .weekOfYear(year: rawYear, weekOfYear: woy, weekday: components.weekday)
            } else if let wom = components.weekOfMonth {
                self = .weekOfMonth(year: rawYear, month: month, weekOfMonth: wom, weekday: components.weekday)
            } else if components.weekdayOrdinal != nil || components.weekday != nil {
                self = .weekdayOrdinal(year: rawYear, month: month, weekdayOrdinal: components.weekdayOrdinal ?? minWeekdayOrdinal, weekday: components.weekday)
            } else {
                self = .init(dateComponents: components)
            }
        case .weekdayOrdinal:
            let (rawYear, month) = Self.yearMonth(forDateComponent: components)
            self = .weekdayOrdinal(year: rawYear, month: month, weekdayOrdinal: components.weekdayOrdinal ?? minWeekdayOrdinal, weekday: components.weekday)
        case .weekOfMonth:
            let (rawYear, month) = Self.yearMonth(forDateComponent: components)
            if let weekOfMonth = components.weekOfMonth {
                self = .weekOfMonth(year: rawYear, month: month, weekOfMonth: weekOfMonth, weekday: components.weekday)
            } else {
                self = .init(dateComponents: components)
            }
        case .weekOfYear:
            let (rawYear, _) = Self.yearMonth(forDateComponent: components)
            self = .weekOfYear(year: rawYear, weekOfYear: components.weekOfYear, weekday: components.weekday)
        case .yearForWeekOfYear:
            let year: Int
            if let y = components.yearForWeekOfYear {
                year = y
            } else {
                year = components.era == 0 ? 0 : 1
            }
            self = .weekOfYear(year: year, weekOfYear: components.weekOfYear, weekday: components.weekday)
        case .year:
            let rawYear: Int
            if let y = components.year {
                rawYear = y
            } else {
                rawYear = components.era == 0 ? 0 : 1
            }
            let (year, month) = Self.carryOver(rawYear: rawYear, rawMonth: components.month)
            self = .day(year: year, month: month, day: components.day, weekOfYear: components.weekOfYear)
        default:
            self = .init(dateComponents: components)
        }
    }
}

/// This class is a placeholder and work-in-progress to provide an implementation of the Gregorian calendar.
internal final class _CalendarGregorian: _CalendarProtocol, @unchecked Sendable {
    
    let julianCutoverDay: Int// Julian day (noon-based) of cutover
    let gregorianStartYear: Int
    let gregorianStartDate: Date

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
        fatalError()
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
        case .calendar, .timeZone:
            nil
        }
    }
    
    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: 0..<2
        case .year: 1..<144684
        case .month: 1..<13
        case .day: 1..<32
        case .hour: 0..<24
        case .minute: 0..<60
        case .second: 0..<60
        case .weekday: 1..<8
        case .weekdayOrdinal: 1..<6
        case .quarter: 1..<5
        case .weekOfMonth: 1..<7
        case .weekOfYear: 1..<54
        case .yearForWeekOfYear: 140742..<144684
        case .nanosecond: 0..<1000000000
        case .isLeapMonth: 0..<2
        case .calendar, .timeZone:
            nil
        }
    }
    
    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        fatalError()
    }
    
    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        fatalError()
    }
    
    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        fatalError()
    }
    
    func isDateInWeekend(_ date: Date) -> Bool {
        fatalError()
    }
    
    func weekendRange() -> WeekendRange? {
        fatalError()
    }
    
    // MARK:

    func date(from components: DateComponents) -> Date? {
        date(from: components, inTimeZone: timeZone)
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
        }

        assert(rawMonth >= 1 || rawMonth <= 12)

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
        }

        return julianDay
    }


    func date(from components: DateComponents, inTimeZone timeZone: TimeZone, resolvedComponents: ResolvedDateComponents? = nil) -> Date? {

        let resolvedComponents = resolvedComponents ?? ResolvedDateComponents(dateComponents: components)

        var useJulianReference = false
        switch resolvedComponents {
        case .weekOfYear(let year, _, _):
            useJulianReference = year == gregorianStartYear
        case .weekOfMonth(_, _, _, _): break
        case .day(_, _, _, _): break
        case .weekdayOrdinal(_, _, _, _): break
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
        let (timeZoneOffset, dstOffset) = timeZone.rawAndDaylightSavingTimeOffset(for: tmpDate)
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
        let v = 3
        let u = 5 // length of any cycle there may be in the pattern of month lengths
        let s = 153
        let w = 2
        let B = 274277
        let C = -38
        let f1 = julianDay + j
        let f: Int
        if useJulianRef {
            f = f1
        } else { // Gregorian
            f = f1 + (((4 * julianDay + B) / 146097) * 3) / 4 + C
        }
        let e = r * f + v
        let g = (e % p) / r
        let h = u * g + w

        let day = (h % s) / u + 1 // day of month
        let month = (((h / s) + m) % n) + 1
        let year = e / p - y + (n + m - month) / n

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

        let (year, month, day) = Self.yearMonthDayFromJulianDay(julianDay, useJulianRef: useJulianRef)

        let era = year < 1 ? 0 : 1
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

        // Week of year calculation, from ICU calendar.cpp :: computeWeekFields
        // 1-based: 1...7
        let weekday = 1 + (julianDay + 1) % 7
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
        if components.contains(.calendar) { dc.calendar = Calendar(identifier: .gregorian) }
        if components.contains(.timeZone) { dc.timeZone = timeZone }
        if components.contains(.era) { dc.era = era }
        if components.contains(.year) { dc.year = year }
        if components.contains(.month) { dc.month = month }
        if components.contains(.day) { dc.day = day }
        if components.contains(.hour) { dc.hour = hour }
        if components.contains(.minute) { dc.minute = minute }
        if components.contains(.second) { dc.second = second }
        if components.contains(.weekday) { dc.weekday = weekday }
        if components.contains(.weekdayOrdinal) { dc.weekdayOrdinal = weekdayOrdinal }
        if components.contains(.quarter) {
            let quarter = if isLeapYear {
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

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        fatalError()
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        fatalError()
    }
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        Calendar(identifier: .gregorian) as NSCalendar
    }
#endif
    
}
