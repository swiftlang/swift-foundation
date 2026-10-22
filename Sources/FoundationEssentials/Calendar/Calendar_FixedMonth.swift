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

// One class for Coptic, the two Ethiopic calendars, Persian and Indian. `Arithmetic` holds the arithmetic of each. `Docs/Fixed_Month_Calendars.md` explains the rules.
internal final class _CalendarFixedMonth: _CalendarProtocol, Sendable {

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        guard let rules = Arithmetic(identifier: identifier) else {
            preconditionFailure("_CalendarFixedMonth does not handle this identifier")
        }
        self.rules = rules
        self.identifier = identifier
        self.timeZone = timeZone ?? .default
        self.locale = locale
        if let firstWeekday, (firstWeekday >= 1 && firstWeekday <= 7) {
            _firstWeekday = firstWeekday
        } else {
            _firstWeekday = nil
        }
        _minimumDaysInFirstWeek = minimumDaysInFirstWeek.map(_CalendarUtility.clampedMinimumDaysInFirstWeek)
    }

    let identifier: Calendar.Identifier
    let rules: Arithmetic
    let locale: Locale?
    let timeZone: TimeZone

    let _firstWeekday: Int?
    var firstWeekday: Int {
        _CalendarUtility.resolveFirstWeekday(stored: _firstWeekday, locale: locale)
    }

    let _minimumDaysInFirstWeek: Int?
    var minimumDaysInFirstWeek: Int {
        _CalendarUtility.resolveMinimumDaysInFirstWeek(stored: _minimumDaysInFirstWeek, locale: locale)
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> _CalendarProtocol {
        let args = _CalendarUtility.resolvedCopyArgs(
            currentTimeZone: timeZone, changingTimeZone: changingTimeZone,
            currentLocale: locale, changingLocale: changingLocale,
            currentFirstWeekday: _firstWeekday, changingFirstWeekday: changingFirstWeekday,
            currentMinimumDaysInFirstWeek: _minimumDaysInFirstWeek, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek
        )
        return _CalendarFixedMonth(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    // MARK: Helpers

    // The extended years that the class supports. The class resolves a date to a rata die first, so a year outside this range has no date.
    private static let extendedYearLimit = 5_000_000

    // The largest day number (rata die, day 1 is 0001-01-01) that the class handles, about 5.5 million years. It is above the last day of the supported years and below `Int32.max`.
    private static let rataDieLimit = 2_000_000_000

    private static func isSupported(extendedYear: Int) -> Bool {
        extendedYear >= -extendedYearLimit && extendedYear <= extendedYearLimit
    }

    // 0 for the first weekday of the week, up to 6.
    private func relativeWeekday(ofRataDie rataDie: Int) -> Int {
        (_CalendarUtility.weekday(ofRataDie: rataDie) - firstWeekday + 7) % 7
    }

    // The class reduces the weekday first, so a weekday of Int.min does not overflow.
    private func relativeWeekday(of weekday: Int) -> Int {
        ((weekday % 7 - firstWeekday) % 7 + 7) % 7
    }

    private func localMidnight(rataDie: Int, in timeZone: TimeZone) -> Date {
        _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: 0, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    // Moves a month number outside the range into the right year. Returns nil if the class does not support the year.
    private func carriedMonth(year: Int, month: Int) -> (year: Int, month: Int)? {
        let monthsInYear = rules.monthsInYear
        let (zeroBased, overflow) = month.subtractingReportingOverflow(1)
        guard !overflow else { return nil }
        let yearsCarried = _CalendarUtility.floorDiv(zeroBased, monthsInYear)
        let (newYear, yearOverflow) = year.addingReportingOverflow(yearsCarried)
        guard !yearOverflow, Self.isSupported(extendedYear: newYear) else { return nil }
        return (newYear, zeroBased - yearsCarried * monthsInYear + 1)
    }

    private func offset(_ rataDie: Int, by days: Int) -> Int? {
        let (sum, overflow) = rataDie.addingReportingOverflow(days)
        guard !overflow, sum > -Self.rataDieLimit, sum < Self.rataDieLimit else { return nil }
        return sum
    }

    // The first day of week 1 of a year that `.yearForWeekOfYear` counts.
    private func firstDayOfWeekYear(_ extendedYear: Int) -> Int {
        let yearStart = rules.startOfYear(extendedYear)
        let daysIntoWeek = relativeWeekday(ofRataDie: yearStart)
        return (7 - daysIntoWeek) >= minimumDaysInFirstWeek ? yearStart - daysIntoWeek : yearStart + 7 - daysIntoWeek
    }

    private struct DayFields {
        var rataDie: Int
        var secondsInDay: Double
        var year: Int
        var month: Int
        var day: Int
        var dayOfYear: Int
    }

    private func dayFields(for date: Date, in timeZone: TimeZone) -> DayFields {
        dayFields(localSeconds: date.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: date)))
    }

    private func dayFields(localSeconds: Double) -> DayFields {
        let (rataDie, secondsInDay): (Int, Double) = _CalendarUtility.rataDieAndSecondsInDay(localSeconds: localSeconds)
        let fields = rules.fields(rataDie: rataDie)
        return DayFields(rataDie: rataDie, secondsInDay: secondsInDay, year: fields.year, month: fields.month, day: fields.day, dayOfYear: fields.dayOfYear)
    }

    // The `.yearForWeekOfYear` of a day and the week number inside it.
    private func weekYearAndWeek(rataDie: Int, year: Int) -> (weekYear: Int, week: Int) {
        var weekYear = year
        if rataDie < firstDayOfWeekYear(weekYear) {
            weekYear -= 1
        } else if rataDie >= firstDayOfWeekYear(weekYear + 1) {
            weekYear += 1
        }
        return (weekYear, (rataDie - firstDayOfWeekYear(weekYear)) / 7 + 1)
    }

    // MARK: Range

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .era: return rules.eraRange
        case .year: return rules.yearRange
        case .month: return 1..<rules.monthsInYear + 1
        case .day: return rules.minimumDayRange
        case .hour: return 0..<24
        case .minute: return 0..<60
        case .second: return 0..<60
        case .weekday: return 1..<8
        case .weekdayOrdinal: return rules.minimumWeekdayOrdinalRange
        case .quarter: return 1..<5
        case .weekOfMonth: return 1..<(rules.minimumDayRange.upperBound + 6 - minimumDaysInFirstWeek) / 7 + 1
        case .weekOfYear: return 1..<53
        case .yearForWeekOfYear: return -Self.extendedYearLimit..<Self.extendedYearLimit + 1
        case .nanosecond: return 0..<1_000_000_000
        case .isLeapMonth: return 0..<1
        case .isRepeatedDay: return 0..<1
        case .dayOfYear: return 1..<366
        case .calendar, .timeZone:
            return nil
        }
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .day: return rules.maximumDayRange
        case .weekdayOrdinal: return rules.maximumWeekdayOrdinalRange
        case .weekOfMonth: return (minimumDaysInFirstWeek == 1 ? 1 : 0)..<(rules.maximumDayRange.upperBound + 12 - minimumDaysInFirstWeek) / 7 + 1
        case .weekOfYear: return 1..<54
        case .dayOfYear: return 1..<367
        default: return minimumRange(of: component)
        }
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        if larger == .calendar || larger == .timeZone || larger == .weekdayOrdinal || larger == .nanosecond { return nil }
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
        let fields = dayFields(for: date, in: timeZone)
        switch (smaller, larger) {
        case (.month, .year):
            return 1..<rules.monthsInYear + 1
        case (.day, .month):
            return 1..<rules.daysInMonth(year: fields.year, month: fields.month) + 1
        case (.day, .year), (.dayOfYear, .year):
            return 1..<rules.daysInYear(fields.year) + 1
        case (.month, .quarter):
            let quarter = rules.quarter(ofMonth: fields.month)
            return rules.firstMonth(ofQuarter: quarter)..<rules.lastMonth(ofQuarter: quarter) + 1
        case (.day, .quarter):
            let quarter = rules.quarter(ofMonth: fields.month)
            let start = rules.daysBeforeMonth(year: fields.year, month: rules.firstMonth(ofQuarter: quarter))
            let end = rules.daysBeforeMonth(year: fields.year, month: rules.lastMonth(ofQuarter: quarter) + 1)
            return 1..<end - start + 1
        case (.day, .weekOfMonth):
            // The days of the month that this week covers. A week can start before or end after the month, so clip both ends.
            let monthLength = rules.daysInMonth(year: fields.year, month: fields.month)
            let weekStart = fields.rataDie - relativeWeekday(ofRataDie: fields.rataDie)
            let monthStart = fields.rataDie - fields.day + 1
            let firstDay = max(1, weekStart - monthStart + 1)
            let lastDay = min(monthLength, weekStart - monthStart + 7)
            return firstDay..<lastDay + 1
        default:
            break
        }
        // The other pairs follow one rule for each larger unit. Most count the smaller unit at the two ends of the larger one.
        switch larger {
        case .era:
            switch smaller {
            case .year, .quarter, .month, .weekOfYear, .weekOfMonth, .day: return maximumRange(of: smaller)
            case .weekdayOrdinal: return maximumRange(of: .day).map { 1..<($0.upperBound + 5) / 7 + 1 }
            default: return nil
            }
        case .year:
            switch smaller {
            case .quarter, .weekOfYear: return rangeAtEnds(of: smaller, in: larger, counting: larger, for: date)
            case .weekOfMonth, .weekdayOrdinal: return _CalendarUtility.rangeOverMonths(of: smaller, in: larger, for: date, in: self)
            default: return nil
            }
        case .yearForWeekOfYear:
            switch smaller {
            case .quarter, .month, .weekOfYear: return rangeAtEnds(of: smaller, in: larger, counting: larger, for: date)
            case .day, .weekdayOrdinal: return _CalendarUtility.rangeOverMonths(of: smaller, in: larger, for: date, in: self)
            default: return nil
            }
        case .quarter:
            switch smaller {
            case .weekOfYear: return rangeAtEnds(of: smaller, in: larger, counting: .year, for: date)
            case .weekOfMonth, .weekdayOrdinal: return _CalendarUtility.rangeOverMonths(of: smaller, in: larger, for: date, in: self)
            default: return nil
            }
        case .month:
            switch smaller {
            case .weekOfYear: return rangeAtEnds(of: smaller, in: larger, counting: .year, for: date)
            case .weekOfMonth, .weekdayOrdinal: return rangeAtEnds(of: smaller, in: larger, counting: larger, for: date)
            default: return nil
            }
        default:
            return nil
        }
    }

    // The smaller unit counted in `counting`, at the first and the last moment of the larger unit.
    private func rangeAtEnds(of smaller: Calendar.Component, in larger: Calendar.Component, counting: Calendar.Component, for date: Date) -> Range<Int>? {
        guard let interval = dateInterval(of: larger, for: date) else { return nil }
        guard let first = ordinality(of: smaller, in: counting, for: interval.start + 0.1) else { return nil }
        guard let last = ordinality(of: smaller, in: counting, for: interval.end - 0.1) else { return nil }
        return first..<last + 1
    }

    // MARK: Ordinality

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        let fields = dayFields(for: date, in: timeZone)
        switch (smaller, larger) {
        case (.hour, _), (.minute, _), (.second, _), (.nanosecond, _):
            return _CalendarUtility.timeOrdinality(of: smaller, in: larger, secondsInDay: fields.secondsInDay, date: date) { ordinality(of: .day, in: $0, for: date) }
        case (.day, .era), (.day, .year), (.dayOfYear, .year), (.day, .yearForWeekOfYear), (.day, .month):
            return startRataDie(of: larger, fields: fields, date: date).map { fields.rataDie - $0 + 1 }
        case (.day, .quarter):
            // The quarter counts elapsed 24 hour blocks from its start, so a change of the offset inside it moves the count.
            guard let interval = dateInterval(of: .quarter, for: date) else { return nil }
            return Int((date.timeIntervalSince(interval.start) / Double(Calendar._secondsInDay)).rounded(.down)) + 1
        case (.month, .year):
            return fields.month
        case (.quarter, .year):
            return rules.quarter(ofMonth: fields.month)
        case (.month, .quarter):
            return fields.month - rules.firstMonth(ofQuarter: rules.quarter(ofMonth: fields.month)) + 1
        case (.year, .era):
            return rules.eraAndYear(extendedYear: fields.year).year
        case (.yearForWeekOfYear, .era):
            return weekYearAndWeek(rataDie: fields.rataDie, year: fields.year).weekYear
        case (.quarter, .era):
            return 4 * (rules.eraAndYear(extendedYear: fields.year).year - 1) + rules.quarter(ofMonth: fields.month)
        case (.month, .era):
            guard let start = startRataDie(of: .era, fields: fields, date: date) else { return nil }
            let first = rules.fields(rataDie: start)
            return (fields.year - first.year) * rules.monthsInYear + fields.month - first.month + (fields.day < first.day ? 0 : 1)
        case (.weekOfYear, .year):
            return _CalendarUtility.weekNumber(desiredDay: fields.dayOfYear, dayOfPeriod: fields.dayOfYear, weekday: _CalendarUtility.weekday(ofRataDie: fields.rataDie), firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
        case (.weekOfYear, .yearForWeekOfYear):
            return weekYearAndWeek(rataDie: fields.rataDie, year: fields.year).week
        case (.weekOfMonth, .month):
            return _CalendarUtility.weekNumber(desiredDay: fields.day, dayOfPeriod: fields.day, weekday: _CalendarUtility.weekday(ofRataDie: fields.rataDie), firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
        case (.weekOfYear, .era), (.weekOfMonth, .era):
            // The first week of the era is the week that holds its first day, if enough of it belongs to the era.
            guard let start = startRataDie(of: .era, fields: fields, date: date) else { return nil }
            let daysBeforeWeek = (7 - relativeWeekday(ofRataDie: start)) % 7
            let firstWeekStart = start + daysBeforeWeek - (minimumDaysInFirstWeek <= daysBeforeWeek ? 7 : 0)
            return _CalendarUtility.floorDiv(fields.rataDie - firstWeekStart, 7) + 1
        case (.weekOfYear, .quarter), (.weekOfMonth, .quarter):
            // The week numbers of the year, counted from the first week that starts in the quarter.
            guard let start = startRataDie(of: .quarter, fields: fields, date: date) else { return nil }
            let daysBeforeWeek = (7 - relativeWeekday(ofRataDie: start)) % 7
            let firstWeekStart = start + daysBeforeWeek
            let firstDayOfYear = firstWeekStart - rules.startOfYear(fields.year) + 1
            let firstWeek = _CalendarUtility.weekNumber(desiredDay: firstDayOfYear, dayOfPeriod: firstDayOfYear, weekday: _CalendarUtility.weekday(ofRataDie: firstWeekStart), firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek) - (minimumDaysInFirstWeek <= daysBeforeWeek ? 1 : 0)
            return _CalendarUtility.weekNumber(desiredDay: fields.dayOfYear, dayOfPeriod: fields.dayOfYear, weekday: _CalendarUtility.weekday(ofRataDie: fields.rataDie), firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek) - firstWeek + 1
        case (.day, .weekOfYear), (.day, .weekOfMonth), (.weekday, .weekOfYear), (.weekday, .weekOfMonth):
            // Position of the day inside its week, counting from firstWeekday.
            return relativeWeekday(ofRataDie: fields.rataDie) + 1
        case (.weekday, _), (.weekdayOrdinal, _):
            // The count of that weekday since the start of the larger unit.
            return startRataDie(of: larger, fields: fields, date: date).map { (fields.rataDie - $0) / 7 + 1 }
        default:
            return nil
        }
    }

    // The first day of the unit that holds the day. Units that start in the middle of a day have none.
    private func startRataDie(of larger: Calendar.Component, fields: DayFields, date: Date) -> Int? {
        switch larger {
        case .era:
            if let startYear = rules.eraStartYear(extendedYear: fields.year) { return rules.startOfYear(startYear) }
            // Coptic era 0 has no first day. Its interval starts a fixed distance before era 1, and the days count as whole elapsed days from that moment.
            guard rules == .coptic, let interval = eraInterval(extendedYear: fields.year, in: timeZone) else { return nil }
            return fields.rataDie - Int((date.timeIntervalSince(interval.start) / Double(Calendar._secondsInDay)).rounded(.down))
        case .year: return rules.startOfYear(fields.year)
        case .yearForWeekOfYear: return firstDayOfWeekYear(weekYearAndWeek(rataDie: fields.rataDie, year: fields.year).weekYear)
        case .quarter: return rules.startOfYear(fields.year) + rules.daysBeforeMonth(year: fields.year, month: rules.firstMonth(ofQuarter: rules.quarter(ofMonth: fields.month)))
        case .month: return fields.rataDie - fields.day + 1
        default: return nil
        }
    }

    // MARK: Date intervals

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        let timeZone = self.timeZone
        let fields = dayFields(for: date, in: timeZone)

        switch component {
        case .era:
            return eraInterval(extendedYear: fields.year, in: timeZone)
        case .year:
            let start = localMidnight(rataDie: rules.startOfYear(fields.year), in: timeZone)
            let end = localMidnight(rataDie: rules.startOfYear(fields.year + 1), in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .yearForWeekOfYear:
            // The year that owns a week, which can differ from the calendar year at either end of a year.
            let (weekYear, _) = weekYearAndWeek(rataDie: fields.rataDie, year: fields.year)
            let start = localMidnight(rataDie: firstDayOfWeekYear(weekYear), in: timeZone)
            let end = localMidnight(rataDie: firstDayOfWeekYear(weekYear + 1), in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .quarter:
            let quarter = rules.quarter(ofMonth: fields.month)
            let yearStart = rules.startOfYear(fields.year)
            let start = localMidnight(rataDie: yearStart + rules.daysBeforeMonth(year: fields.year, month: rules.firstMonth(ofQuarter: quarter)), in: timeZone)
            let end = localMidnight(rataDie: yearStart + rules.daysBeforeMonth(year: fields.year, month: rules.lastMonth(ofQuarter: quarter) + 1), in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .month:
            let monthStart = fields.rataDie - fields.day + 1
            let start = localMidnight(rataDie: monthStart, in: timeZone)
            let end = localMidnight(rataDie: monthStart + rules.daysInMonth(year: fields.year, month: fields.month), in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .weekOfYear, .weekOfMonth:
            let weekStart = fields.rataDie - relativeWeekday(ofRataDie: fields.rataDie)
            let start = localMidnight(rataDie: weekStart, in: timeZone)
            let end = localMidnight(rataDie: weekStart + 7, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .day, .weekday, .weekdayOrdinal, .dayOfYear:
            let start = localMidnight(rataDie: fields.rataDie, in: timeZone)
            let end = localMidnight(rataDie: fields.rataDie + 1, in: timeZone)
            return DateInterval(start: start, duration: end.timeIntervalSince(start))
        case .hour, .minute, .second, .nanosecond:
            return _CalendarUtility.timeUnitInterval(of: component, for: date, in: timeZone)
        case .isLeapMonth, .isRepeatedDay, .calendar, .timeZone:
            return nil
        }
    }

    // An era runs for the longest interval Foundation allows, from the first day of year 1. Era 0 ends where era 1 starts.
    private func eraInterval(extendedYear: Int, in timeZone: TimeZone) -> DateInterval? {
        let (era, _) = rules.eraAndYear(extendedYear: extendedYear)
        let duration = Calendar._maxDateIntervalDuration
        switch rules {
        case .coptic, .ethiopicAmeteMihret:
            let secondEraStart = localMidnight(rataDie: rules.startOfYear(1), in: timeZone)
            if era == 1 {
                return DateInterval(start: secondEraStart, duration: duration)
            }
            if rules == .coptic {
                return DateInterval(start: secondEraStart - duration, end: secondEraStart)
            }
            // The era before the first one starts on the first day of the Amete Alem calendar.
            let firstEraStart = localMidnight(rataDie: rules.startOfYear(1 - rules.ameteAlemOffset), in: timeZone)
            return DateInterval(start: firstEraStart, end: secondEraStart)
        case .ethiopicAmeteAlem:
            return DateInterval(start: localMidnight(rataDie: rules.startOfYear(1), in: timeZone), duration: duration)
        case .persian, .indian:
            guard extendedYear >= 1 else { return nil }
            return DateInterval(start: localMidnight(rataDie: rules.startOfYear(1), in: timeZone), duration: duration)
        }
    }

    // MARK: Date and components

    // How a set of date components names a day.
    private enum DateForm {
        case day(Int?)
        case weekdayOrdinal(Int, weekday: Int?)
        case weekOfYear(Int?, weekday: Int?)
        case weekOfMonth(Int, weekday: Int?)
        case dayOfYear(Int)

        init(_ components: DateComponents) {
            // A form needs all its fields. A weekday or an ordinal alone does not name a day, so the day of the month decides, as day 1 when it is missing.
            if let day = components.day {
                self = .day(day)
            } else if let ordinal = components.weekdayOrdinal, let weekday = components.weekday {
                self = .weekdayOrdinal(ordinal, weekday: weekday)
            } else if let week = components.weekOfYear, let weekday = components.weekday {
                self = .weekOfYear(week, weekday: weekday)
            } else if let week = components.weekOfMonth, let weekday = components.weekday {
                self = .weekOfMonth(week, weekday: weekday)
            } else if let dayOfYear = components.dayOfYear {
                self = .dayOfYear(dayOfYear)
            } else if components.yearForWeekOfYear != nil {
                self = .weekOfYear(components.weekOfYear, weekday: components.weekday)
            } else if let week = components.weekOfMonth {
                self = .weekOfMonth(week, weekday: components.weekday)
            } else {
                self = .day(nil)
            }
        }
    }

    // A week or an ordinal this large is outside the supported dates, and its day count could overflow.
    private static let fieldLimit = 100_000_000

    private func rataDie(from components: DateComponents) -> Int? {
        let form = DateForm(components)

        // The `.yearForWeekOfYear` of a week-based form is an extended year. Every other form takes its year from the era and the year.
        let extendedYear: Int
        if case .weekOfYear = form, let weekYear = components.yearForWeekOfYear {
            extendedYear = weekYear
        } else if let year = rules.extendedYear(era: components.era, year: components.year) {
            extendedYear = year
        } else {
            return nil
        }
        guard Self.isSupported(extendedYear: extendedYear) else { return nil }

        switch form {
        case .day(let day):
            guard let (year, month) = carriedMonth(year: extendedYear, month: components.month ?? 1) else { return nil }
            let dayValue = day ?? 1
            guard dayValue > -Self.rataDieLimit, dayValue < Self.rataDieLimit else { return nil }
            return offset(rules.rataDie(year: year, month: month, day: 1), by: dayValue - 1)

        case .weekdayOrdinal(let ordinal, let weekday):
            guard ordinal.magnitude <= UInt(Self.fieldLimit), let (year, month) = carriedMonth(year: extendedYear, month: components.month ?? 1) else { return nil }
            let monthStart = rules.rataDie(year: year, month: month, day: 1)
            let first = relativeWeekday(ofRataDie: monthStart)
            let weekdayOffset = weekday.map { relativeWeekday(of: $0) } ?? 0
            let day = _CalendarUtility.dayOfMonth(weekdayOrdinal: ordinal, weekdayOffset: weekdayOffset, monthStartOffset: first, monthLength: rules.daysInMonth(year: year, month: month))
            return offset(monthStart, by: day - 1)

        case .weekOfYear(let week, let weekday):
            // A `.yearForWeekOfYear` without a `.weekOfYear` means week 0.
            let weekValue = week ?? 0
            guard weekValue.magnitude <= UInt(Self.fieldLimit) else { return nil }
            let weekdayOffset = weekday.map { relativeWeekday(of: $0) } ?? 0
            return offset(firstDayOfWeekYear(extendedYear), by: weekdayOffset + (weekValue - 1) * 7)

        case .weekOfMonth(let week, let weekday):
            guard week.magnitude <= UInt(Self.fieldLimit), let (year, month) = carriedMonth(year: extendedYear, month: components.month ?? 1) else { return nil }
            let monthStart = rules.rataDie(year: year, month: month, day: 1)
            let first = relativeWeekday(ofRataDie: monthStart)
            let weekdayOffset = weekday.map { relativeWeekday(of: $0) } ?? 0
            let day = _CalendarUtility.dayOfMonth(weekOfMonth: week, weekdayOffset: weekdayOffset, monthStartOffset: first, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
            return offset(monthStart, by: day - 1)

        case .dayOfYear(let dayOfYear):
            guard dayOfYear > -Self.rataDieLimit, dayOfYear < Self.rataDieLimit else { return nil }
            return offset(rules.startOfYear(extendedYear), by: dayOfYear - 1)
        }
    }

    func date(from components: DateComponents) -> Date? {
        var secondsInDay: Double = 0
        if let hour = components.hour { secondsInDay += Double(hour) * Double(Calendar._secondsInHour) }
        if let minute = components.minute { secondsInDay += Double(minute) * 60 }
        if let second = components.second { secondsInDay += Double(second) }
        if let nanosecond = components.nanosecond { secondsInDay += Double(nanosecond) / 1e9 }

        let timeZone = components.timeZone ?? self.timeZone
        guard let resolvedDay = rataDie(from: components) else { return nil }
        return _CalendarUtility.utcDate(fromRataDie: resolvedDay, secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: .former, skippedTimePolicy: .former)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        let localSeconds = date.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: date))
        let fields = dayFields(localSeconds: localSeconds)
        let secondsInDay = fields.secondsInDay

        var result = DateComponents()

        if components.contains(.era) || components.contains(.year) {
            let (era, year) = rules.eraAndYear(extendedYear: fields.year)
            if components.contains(.era) { result.era = era }
            if components.contains(.year) { result.year = year }
        }
        if components.contains(.month) { result.month = fields.month }
        if components.contains(.day) { result.day = fields.day }
        if components.contains(.dayOfYear) { result.dayOfYear = fields.dayOfYear }
        // None of these calendars has a leap month, but `isLeapMonth` still has a value when the caller asks for a month.
        if components.contains(.month) || components.contains(.isLeapMonth) {
            result.isLeapMonth = false
        }

        if components.contains(.hour) || components.contains(.minute)
            || components.contains(.second) || components.contains(.nanosecond) {
            let hour = Int(secondsInDay / Double(Calendar._secondsInHour))
            let remainderAfterHour = secondsInDay - Double(hour) * Double(Calendar._secondsInHour)
            let minute = Int(remainderAfterHour / 60)
            let remainderAfterMinute = remainderAfterHour - Double(minute) * 60
            let second = Int(remainderAfterMinute)
            let nanosecond = Int((localSeconds - localSeconds.rounded(.down)) * 1_000_000_000)
            if components.contains(.hour) { result.hour = hour }
            if components.contains(.minute) { result.minute = minute }
            if components.contains(.second) { result.second = second }
            if components.contains(.nanosecond) { result.nanosecond = nanosecond }
        }

        if components.contains(.weekday) {
            result.weekday = _CalendarUtility.weekday(ofRataDie: fields.rataDie)
        }

        if components.contains(.timeZone) {
            result.timeZone = timeZone
        }

        if components.contains(.weekdayOrdinal) {
            result.weekdayOrdinal = (fields.day - 1) / 7 + 1
        }
        if components.contains(.weekOfMonth) {
            result.weekOfMonth = _CalendarUtility.weekNumber(desiredDay: fields.day, dayOfPeriod: fields.day, weekday: _CalendarUtility.weekday(ofRataDie: fields.rataDie), firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)
        }
        if components.contains(.weekOfYear) || components.contains(.yearForWeekOfYear) {
            let (weekYear, week) = weekYearAndWeek(rataDie: fields.rataDie, year: fields.year)
            if components.contains(.weekOfYear) { result.weekOfYear = week }
            if components.contains(.yearForWeekOfYear) { result.yearForWeekOfYear = weekYear }
        }

        // The quarter is always 0 here, as in every other calendar.
        if components.contains(.quarter) {
            result.quarter = 0
        }

        return result
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        dateComponents(components, from: date, in: self.timeZone)
    }

    // MARK: Adding

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        if wrappingComponents {
            return self.date(rollingBy: components, from: date)
        }

        var result = date
        let timeZone = self.timeZone

        let yearsToAdd = components.year ?? 0
        let monthsToAdd = components.month ?? 0

        if yearsToAdd != 0 {
            let fields = dayFields(for: result, in: timeZone)
            let (newYear, overflow) = fields.year.addingReportingOverflow(yearsToAdd)
            guard !overflow, Self.isSupported(extendedYear: newYear) else { return nil }
            result = rebuilt(year: newYear, month: fields.month, day: fields.day, secondsInDay: fields.secondsInDay, forward: yearsToAdd > 0, in: timeZone)
        }

        // Moves by whole years of `.yearForWeekOfYear`, after the years and before the months. The distance is the sum of the week counts in between.
        if let weekYears = components.yearForWeekOfYear, weekYears != 0 {
            let fields = dayFields(for: result, in: timeZone)
            let (weekYear, _) = weekYearAndWeek(rataDie: fields.rataDie, year: fields.year)
            let (target, overflow) = weekYear.addingReportingOverflow(weekYears)
            guard !overflow, Self.isSupported(extendedYear: target) else { return nil }
            guard let moved = _CalendarUtility.date(byAddingDays: firstDayOfWeekYear(target) - firstDayOfWeekYear(weekYear), to: result, in: timeZone) else { return nil }
            result = moved
        }

        if monthsToAdd != 0 {
            let fields = dayFields(for: result, in: timeZone)
            let (newMonth, overflow) = fields.month.addingReportingOverflow(monthsToAdd)
            guard !overflow, let (year, month) = carriedMonth(year: fields.year, month: newMonth) else { return nil }
            result = rebuilt(year: year, month: month, day: fields.day, secondsInDay: fields.secondsInDay, forward: monthsToAdd > 0, in: timeZone)
        }

        guard let daysToAdd = _CalendarUtility.dayCount(of: components) else { return nil }

        if daysToAdd != 0 {
            guard let moved = _CalendarUtility.date(byAddingDays: daysToAdd, to: result, in: timeZone) else { return nil }
            result = moved
        }

        if let hours = components.hour, hours != 0 { result += Double(hours) * Double(Calendar._secondsInHour) }
        if let minutes = components.minute, minutes != 0 { result += Double(minutes) * 60 }
        if let seconds = components.second, seconds != 0 { result += Double(seconds) }
        if let nanoseconds = components.nanosecond, nanoseconds != 0 { result += Double(nanoseconds) / 1_000_000_000 }

        return result
    }

    // The day of a month that is too short for it moves to the last day of the month.
    private func rebuilt(year: Int, month: Int, day: Int, secondsInDay: Double, forward: Bool, in timeZone: TimeZone) -> Date {
        let clampedDay = min(day, rules.daysInMonth(year: year, month: month))
        return _CalendarUtility.utcDate(fromRataDie: rules.rataDie(year: year, month: month, day: clampedDay), secondsInDay: secondsInDay, in: timeZone, repeatedTimePolicy: forward ? .former : .latter, skippedTimePolicy: .former)
    }

    // Each field wraps inside the larger field that holds it. The fields go from the largest to the smallest, as in a plain add.
    private func date(rollingBy components: DateComponents, from date: Date) -> Date? {
        var result = date
        func roll(_ field: Calendar.Component, _ amount: Int?) -> Bool {
            guard let amount, amount != 0 else { return true }
            guard let newDate = rolled(field, by: amount, from: result) else { return false }
            result = newDate
            return true
        }
        guard roll(.year, components.year),
              roll(.yearForWeekOfYear, components.yearForWeekOfYear),
              roll(.month, components.month),
              roll(.weekOfYear, components.weekOfYear),
              roll(.weekOfMonth, components.weekOfMonth),
              roll(.weekdayOrdinal, components.weekdayOrdinal),
              roll(.day, components.day),
              roll(.dayOfYear, components.dayOfYear),
              roll(.weekday, components.weekday),
              roll(.hour, components.hour),
              roll(.minute, components.minute),
              roll(.second, components.second) else { return nil }
        if let nanoseconds = components.nanosecond, nanoseconds != 0 { result += Double(nanoseconds) / 1_000_000_000 }
        return result
    }

    private func rolled(_ field: Calendar.Component, by amount: Int, from date: Date) -> Date? {
        let timeZone = self.timeZone
        let fields = dayFields(for: date, in: timeZone)

        func dateAt(rataDie: Int) -> Date {
            _CalendarUtility.utcDate(fromRataDie: rataDie, secondsInDay: fields.secondsInDay, in: timeZone, repeatedTimePolicy: amount > 0 ? .former : .latter, skippedTimePolicy: .former)
        }

        // Rolls of the day of the year and of the weekday count elapsed days.
        func elapsed(days: Int) -> Date { _CalendarUtility.moved(date, byElapsedDays: days, forward: amount > 0, in: timeZone) }

        switch field {
        case .year:
            // Years stay in their era and stop at the first year. The years of the era before the first one count backward in a calendar that has such an era.
            let (era, displayedYear) = rules.eraAndYear(extendedYear: fields.year)
            let (step, negationOverflow) = (era == 0 && rules.yearsCountBackwardInEraZero) ? 0.subtractingReportingOverflow(amount) : (amount, false)
            let (sum, overflow) = displayedYear.addingReportingOverflow(step)
            guard !negationOverflow, !overflow else { return nil }
            var newYear = sum
            if era > 0 || newYear >= 1 {
                if newYear < 1 { newYear = 1 }
            } else if era == 0 && rules.yearsCountBackwardInEraZero {
                newYear = 1
            }
            guard let extendedYear = rules.extendedYear(era: era, year: newYear), Self.isSupported(extendedYear: extendedYear) else { return nil }
            return rebuilt(year: extendedYear, month: fields.month, day: fields.day, secondsInDay: fields.secondsInDay, forward: amount > 0, in: timeZone)

        case .yearForWeekOfYear:
            // The roll adds to `.yearForWeekOfYear`. In an era after 0 it stops at 1, as the roll of `.year` stops at year 1.
            var components = DateComponents()
            components.yearForWeekOfYear = amount
            if rules.eraAndYear(extendedYear: fields.year).era > 0 {
                components.yearForWeekOfYear = max(amount, 1 - weekYearAndWeek(rataDie: fields.rataDie, year: fields.year).weekYear)
            }
            return self.date(byAdding: components, to: date, wrappingComponents: false)

        case .month:
            let newMonth = _CalendarUtility.wrapped(fields.month - 1, by: amount, count: rules.monthsInYear) + 1
            return rebuilt(year: fields.year, month: newMonth, day: fields.day, secondsInDay: fields.secondsInDay, forward: amount > 0, in: timeZone)

        case .day:
            let monthLength = rules.daysInMonth(year: fields.year, month: fields.month)
            let newDay = _CalendarUtility.wrapped(fields.day - 1, by: amount, count: monthLength) + 1
            return dateAt(rataDie: fields.rataDie - fields.day + newDay)

        case .dayOfYear, .weekday, .weekdayOrdinal:
            let days = _CalendarUtility.daysToRoll(field, by: amount, weekdayOffset: relativeWeekday(ofRataDie: fields.rataDie), dayOfMonth: fields.day, monthLength: rules.daysInMonth(year: fields.year, month: fields.month), dayOfYear: fields.dayOfYear, yearLength: rules.daysInYear(fields.year))
            return days.map { elapsed(days: $0) }

        case .weekOfMonth:
            // A short month whose only week does not count has no weeks to roll over.
            let monthLength = rules.daysInMonth(year: fields.year, month: fields.month)
            guard let newDay = _CalendarUtility.rolledWeekPosition(fields.day, length: monthLength, weekdayOffset: relativeWeekday(ofRataDie: fields.rataDie), by: amount, minimumDaysInFirstWeek: minimumDaysInFirstWeek) else { return nil }
            return dateAt(rataDie: fields.rataDie - fields.day + newDay)

        case .weekOfYear:
            let yearLength = rules.daysInYear(fields.year)
            guard let newDayOfYear = _CalendarUtility.rolledWeekPosition(fields.dayOfYear, length: yearLength, weekdayOffset: relativeWeekday(ofRataDie: fields.rataDie), by: amount, minimumDaysInFirstWeek: minimumDaysInFirstWeek) else { return nil }
            return dateAt(rataDie: fields.rataDie - fields.dayOfYear + newDayOfYear)

        case .hour, .minute, .second:
            return _CalendarUtility.rolledTimeUnit(field, by: amount, from: date, in: timeZone)

        case .era, .quarter, .nanosecond, .calendar, .timeZone, .isLeapMonth, .isRepeatedDay:
            return date
        }
    }

    // MARK: Difference

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        var result = DateComponents()
        var current = start
        for component in _CalendarUtility.orderedDifferenceComponents(components) {
            let (difference, newCurrent) = difference(inComponent: component, from: current, to: end)
            result.setValue(difference, for: component)
            current = newCurrent
        }
        return result
    }

    // The whole number of `component` units from `start` toward `end`, and `start` moved by that many units. Each trial adds to `start`, so a clamped day does not carry over.
    private func difference(inComponent component: Calendar.Component, from start: Date, to end: Date) -> (Int, Date) {
        if start == end { return (0, start) }
        if let result = _CalendarUtility.timeUnitDifference(in: component, from: start, to: end) { return result }

        switch component {
        case .era:
            // Only the count of eras. The start date does not move into the era of the end date.
            let startEra = rules.eraAndYear(extendedYear: dayFields(for: start, in: timeZone).year).era
            let endEra = rules.eraAndYear(extendedYear: dayFields(for: end, in: timeZone).year).era
            return (endEra - startEra, start)
        default:
            break
        }

        return _CalendarUtility.differenceBySearch(from: start, to: end) { count in
            var components = DateComponents()
            components.setValue(count, for: component)
            return date(byAdding: components, to: start, wrappingComponents: false)
        }
    }
}

// MARK: - Arithmetic of each calendar

extension _CalendarFixedMonth {
    /// The arithmetic of one calendar. Every function works on the extended year, which counts years across all eras.
    /// A rata die is the number of days since 0001-01-01, where that day is day 1.
    enum Arithmetic: Sendable {
        case coptic
        case ethiopicAmeteMihret
        case ethiopicAmeteAlem
        case persian
        case indian

        init?(identifier: Calendar.Identifier) {
            switch identifier {
            case .coptic: self = .coptic
            case .ethiopicAmeteMihret: self = .ethiopicAmeteMihret
            case .ethiopicAmeteAlem: self = .ethiopicAmeteAlem
            case .persian: self = .persian
            case .indian: self = .indian
            default: return nil
            }
        }

        var monthsInYear: Int {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return 13
            case .persian, .indian: return 12
            }
        }

        // MARK: Ranges

        var eraRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret: return 0..<2
            case .ethiopicAmeteAlem, .persian, .indian: return 0..<1
            }
        }

        var yearRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return 1..<5_000_001
            case .persian, .indian: return -5_000_000..<5_000_001
            }
        }

        var minimumDayRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return 1..<6
            case .persian: return 1..<30
            case .indian: return 1..<31
            }
        }

        var maximumDayRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return 1..<31
            case .persian, .indian: return 1..<32
            }
        }

        var minimumWeekdayOrdinalRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return -1..<2
            case .persian: return 1..<6
            case .indian: return -1..<6
            }
        }

        var maximumWeekdayOrdinalRange: Range<Int> {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem: return -1..<6
            case .persian: return 1..<6
            case .indian: return -1..<6
            }
        }

        // MARK: Eras

        // The difference between the years of the Amete Alem calendar and the years of the Amete Mihret calendar.
        var ameteAlemOffset: Int { 5500 }

        // Whether the years of era 0 count backward, so that year 1 of era 0 is the year before year 1 of era 1.
        var yearsCountBackwardInEraZero: Bool { self == .coptic }

        func eraAndYear(extendedYear: Int) -> (era: Int, year: Int) {
            switch self {
            case .coptic:
                return extendedYear > 0 ? (1, extendedYear) : (0, 1 - extendedYear)
            case .ethiopicAmeteMihret:
                return extendedYear > 0 ? (1, extendedYear) : (0, extendedYear + ameteAlemOffset)
            case .ethiopicAmeteAlem, .persian, .indian:
                return (0, extendedYear)
            }
        }

        // The extended year for an era and a year. A missing era is the current one, a missing year is year 1. Returns nil for an era that the calendar does not have.
        func extendedYear(era: Int?, year: Int?) -> Int? {
            let year = year ?? 1
            switch self {
            case .coptic:
                switch era ?? 1 {
                case 1: return year
                case 0:
                    let (result, overflow) = 1.subtractingReportingOverflow(year)
                    return overflow ? nil : result
                default: return nil
                }
            case .ethiopicAmeteMihret:
                if (era ?? 1) == 1 { return year }
                let (result, overflow) = year.subtractingReportingOverflow(ameteAlemOffset)
                return overflow ? nil : result
            case .ethiopicAmeteAlem, .persian, .indian:
                return year
            }
        }

        // MARK: Quarters

        // The last quarter takes the thirteenth month of the Coptic and Ethiopic calendars.
        func quarter(ofMonth month: Int) -> Int { min((month - 1) / 3, 3) + 1 }
        func firstMonth(ofQuarter quarter: Int) -> Int { 3 * (quarter - 1) + 1 }
        func lastMonth(ofQuarter quarter: Int) -> Int { quarter == 4 ? monthsInYear : 3 * quarter }

        // MARK: Years and months

        // The rata die of the first day of year 0 of the Coptic and Ethiopic calendars.
        private var epochRataDie: Int {
            switch self {
            case .coptic: return 103_240
            case .ethiopicAmeteMihret: return 2_431
            case .ethiopicAmeteAlem: return -2_006_444
            case .persian, .indian: return 0
            }
        }

        // The rata die of the first day of the year.
        func startOfYear(_ year: Int) -> Int {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem:
                return epochRataDie + 365 * year + _CalendarUtility.floorDiv(year, 4)
            case .persian:
                // Each year in the correction table is one day shorter than the 33 year rule says. The year after it starts one day earlier.
                func isCorrected(_ year: Int) -> Bool {
                    let table = Self.persianCorrectedYears
                    guard year >= Int(table[0]), year <= Int(table[table.count - 1]) else { return false }
                    var low = 0
                    var high = table.count - 1
                    while low <= high {
                        let middle = (low + high) / 2
                        let value = Int(table[middle])
                        if value == year { return true }
                        if value < year { low = middle + 1 } else { high = middle - 1 }
                    }
                    return false
                }
                let corrected = isCorrected(year - 1)
                return 226_895 + 365 * (year - 1) + _CalendarUtility.floorDiv(8 * year + 21, 33) - (corrected ? 1 : 0)
            case .indian:
                let gregorianYear = year + 78
                return _CalendarAstronomy.gregorianRataDie(gregorianYear, 3, _CalendarGregorian.isLeapYear(gregorianYear) ? 21 : 22)
            }
        }

        func daysInYear(_ year: Int) -> Int {
            startOfYear(year + 1) - startOfYear(year)
        }

        func daysInMonth(year: Int, month: Int) -> Int {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem:
                return month < 13 ? 30 : daysInYear(year) - 360
            case .persian:
                if month <= 6 { return 31 }
                return month <= 11 ? 30 : daysInYear(year) - 336
            case .indian:
                if month == 1 { return _CalendarGregorian.isLeapYear(year + 78) ? 31 : 30 }
                return month <= 6 ? 31 : 30
            }
        }

        // The number of days in the year before the month. The month after the last one stands for the end of the year.
        func daysBeforeMonth(year: Int, month: Int) -> Int {
            if month > monthsInYear { return daysInYear(year) }
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem:
                return 30 * (month - 1)
            case .persian:
                return Self.persianDaysBeforeMonth[month - 1]
            case .indian:
                if month == 1 { return 0 }
                let firstMonthLength = daysInMonth(year: year, month: 1)
                return firstMonthLength + 31 * (min(month, 7) - 2) + (month >= 8 ? 30 * (month - 7) : 0)
            }
        }

        func rataDie(year: Int, month: Int, day: Int) -> Int {
            startOfYear(year) + daysBeforeMonth(year: year, month: month) + day - 1
        }

        // The year that starts the era, or nil for Coptic era 0, which has no first year, and for the days before year 1 of Persian and Indian.
        func eraStartYear(extendedYear: Int) -> Int? {
            let (era, _) = eraAndYear(extendedYear: extendedYear)
            switch self {
            case .coptic: return era == 1 ? 1 : nil
            case .ethiopicAmeteMihret: return era == 1 ? 1 : 1 - ameteAlemOffset
            case .ethiopicAmeteAlem: return 1
            case .persian, .indian: return extendedYear >= 1 ? 1 : nil
            }
        }

        // The year, month, day and day of the year of a rata die.
        func fields(rataDie: Int) -> (year: Int, month: Int, day: Int, dayOfYear: Int) {
            switch self {
            case .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem:
                // Four years make a cycle of 1461 days. Within a cycle, the last year is the long one.
                let days = rataDie - epochRataDie
                let cycle = _CalendarUtility.floorDiv(days, 1461)
                let dayOfCycle = days - cycle * 1461
                let year = 4 * cycle + (dayOfCycle / 365 - dayOfCycle / 1460)
                let dayIndex = dayOfCycle == 1460 ? 365 : dayOfCycle % 365
                return (year, dayIndex / 30 + 1, dayIndex % 30 + 1, dayIndex + 1)
            case .persian:
                // The average length of 33 years (12,053 days) gives the year. Near a year start it can be one year off, so the two loops step to the year that holds the day.
                var year = Int(_CalendarUtility.floorDiv(Int64(rataDie - 226_895) * 33 + 3, 12_053)) + 1
                while rataDie < startOfYear(year) { year -= 1 }
                while rataDie >= startOfYear(year + 1) { year += 1 }
                let dayIndex = rataDie - startOfYear(year)
                let monthIndex = dayIndex < 216 ? dayIndex / 31 : (dayIndex - 6) / 30
                return (year, monthIndex + 1, dayIndex - Self.persianDaysBeforeMonth[monthIndex] + 1, dayIndex + 1)
            case .indian:
                // The year starts in March of the Gregorian year that is 78 years later.
                var year = _CalendarAstronomy.gregorianYear(ofRataDie: rataDie) - 78
                if rataDie < startOfYear(year) { year -= 1 }
                let dayIndex = rataDie - startOfYear(year)
                let firstMonthLength = daysInMonth(year: year, month: 1)
                if dayIndex < firstMonthLength { return (year, 1, dayIndex + 1, dayIndex + 1) }
                var remainder = dayIndex - firstMonthLength
                if remainder < 31 * 5 { return (year, remainder / 31 + 2, remainder % 31 + 1, dayIndex + 1) }
                remainder -= 31 * 5
                return (year, remainder / 30 + 7, remainder % 30 + 1, dayIndex + 1)
            }
        }

        private static let persianDaysBeforeMonth = [0, 31, 62, 93, 124, 155, 186, 216, 246, 276, 306, 336]

        // The Persian years where the 33 year rule puts a leap day too early. Sorted, for a binary search.
        private static let persianCorrectedYears: [Int16] = [
            1502, 1601, 1634, 1667, 1700, 1733, 1766, 1799, 1832, 1865, 1898, 1931, 1964, 1997, 2030, 2059,
            2063, 2096, 2129, 2158, 2162, 2191, 2195, 2224, 2228, 2257, 2261, 2290, 2294, 2323, 2327, 2356,
            2360, 2389, 2393, 2422, 2426, 2455, 2459, 2488, 2492, 2521, 2525, 2554, 2558, 2587, 2591, 2620,
            2624, 2653, 2657, 2686, 2690, 2719, 2723, 2748, 2752, 2756, 2781, 2785, 2789, 2818, 2822, 2847,
            2851, 2855, 2880, 2884, 2888, 2913, 2917, 2921, 2946, 2950, 2954, 2979, 2983, 2987,
        ]
    }
}

#endif // !hasFeature(Embedded)
