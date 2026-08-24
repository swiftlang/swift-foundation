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

/// The direction an era counts its years.
internal enum _CalendarEraDirection: Sendable {
    /// Years count up from the anchor year, like every Japanese era and the Buddhist and Minguo eras.
    case forward
    /// Years count down from the anchor year, like ROC's Before-Minguo era.
    case backward
}

/// One era of a Gregorian-backed calendar.
internal struct _CalendarEraEntry: Sendable {
    /// The value `DateComponents.era` carries for this era. These match ICU's numbering.
    let code: Int
    /// The extended Gregorian year holding this era's boundary. A forward era numbers that year 1; a backward era counts down from it.
    let anchorYear: Int
    /// Month and day of the boundary within `anchorYear`.
    let startMonth: Int
    let startDay: Int
    let direction: _CalendarEraDirection
    /// True when the era labels dates before its boundary too. ICU's Buddhist era does this: 1000 BCE gets a Buddhist year but no era interval.
    let labelsEveryDate: Bool

    init(code: Int, anchorYear: Int, startMonth: Int, startDay: Int, direction: _CalendarEraDirection, labelsEveryDate: Bool = false) {
        self.code = code
        self.anchorYear = anchorYear
        self.startMonth = startMonth
        self.startDay = startDay
        self.direction = direction
        self.labelsEveryDate = labelsEveryDate
    }

    /// Whether this era labels the given date, expressed as an extended Gregorian year plus a month and day.
    func labels(extendedYear year: Int, month: Int, day: Int) -> Bool {
        if labelsEveryDate { return true }
        let isAtOrAfterBoundary = (year, month, day) >= (anchorYear, startMonth, startDay)
        return direction == .forward ? isAtOrAfterBoundary : !isAtOrAfterBoundary
    }

    /// This era's year number for a date in the given extended Gregorian year.
    func eraYear(fromExtendedYear year: Int) -> Int {
        switch direction {
        case .forward: return year - anchorYear + 1
        case .backward: return anchorYear - year
        }
    }

    /// The extended Gregorian year for a year number in this era.
    func extendedYear(fromEraYear year: Int) -> Int {
        switch direction {
        case .forward: return year + anchorYear - 1
        case .backward: return anchorYear - year
        }
    }
}

/// The eras of one Gregorian-backed calendar, newest first.
internal struct _CalendarEraTable: Sendable {
    let entries: [_CalendarEraEntry]

    /// The highest era code. Era ranges run from 0 up to this value, because codes 0 and 1 stay reserved for the Gregorian BCE and CE eras a calendar inherits.
    let highestCode: Int

    /// The code to assume when `DateComponents.era` is absent. ICU defaults to the newest era.
    let defaultCode: Int

    /// The anchor year of the newest era, which limits how high a year number can go once years are era-relative.
    let newestAnchorYear: Int

    /// True when an era can end as well as begin, so one era can cover a single year. The Japanese eras do; the Buddhist and Minguo eras run on without limit.
    let erasCanEnd: Bool

    init(_ entries: [_CalendarEraEntry]) {
        self.entries = entries
        self.highestCode = entries.map(\.code).max() ?? 0
        self.defaultCode = entries.first?.code ?? 0
        self.newestAnchorYear = entries.first?.anchorYear ?? 0
        self.erasCanEnd = entries.filter { $0.direction == .forward && !$0.labelsEveryDate }.count > 1
    }

    /// The era labeling the given date, or nil when the date falls before every era in the table.
    func entry(extendedYear year: Int, month: Int, day: Int) -> _CalendarEraEntry? {
        entries.first { $0.labels(extendedYear: year, month: month, day: day) }
    }

    func entry(code: Int) -> _CalendarEraEntry? {
        entries.first { $0.code == code }
    }

    /// The era that follows `entry`, or nil when `entry` is the newest one.
    func eraAfter(_ entry: _CalendarEraEntry) -> _CalendarEraEntry? {
        guard let index = entries.firstIndex(where: { $0.code == entry.code }), index > 0 else { return nil }
        return entries[index - 1]
    }
}

/// A calendar that shares Gregorian arithmetic and differs from it only by how it labels eras and numbers years within them.
///
/// A conformer supplies a `_CalendarGregorian` for the arithmetic and an era table for the relabeling. Everything else is shared here.
///
/// Era codes 0 and 1 stay reserved for the Gregorian BCE and CE eras. A calendar whose eras all start after year 1, like the Japanese one, inherits those two for dates its own table does not label.
internal protocol _GregorianBackedCalendar: _CalendarProtocol {
    var gregorian: _CalendarGregorian { get }
    var eraTable: _CalendarEraTable { get }
}

extension _GregorianBackedCalendar {

    var locale: Locale? { gregorian.locale }
    var timeZone: TimeZone { gregorian.timeZone }
    var firstWeekday: Int { gregorian.firstWeekday }
    var minimumDaysInFirstWeek: Int { gregorian.minimumDaysInFirstWeek }
    var gregorianStartDate: Date? { gregorian.gregorianStartDate }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> any _CalendarProtocol {
        let args = _CalendarUtility.resolvedCopyArgs(
            currentTimeZone: gregorian.timeZone, changingTimeZone: changingTimeZone,
            currentLocale: gregorian.locale, changingLocale: changingLocale,
            currentFirstWeekday: gregorian._firstWeekday, changingFirstWeekday: changingFirstWeekday,
            currentMinimumDaysInFirstWeek: gregorian._minimumDaysInFirstWeek, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek
        )
        return Self(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool {
        gregorian.supportsNextDateFastPath(for: components)
    }

    // MARK: - Range

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return 0..<eraTable.highestCode + 1 }
        // An era can be a single year long once eras end, so the shortest year range is one year.
        if component == .year, eraTable.erasCanEnd { return 1..<2 }
        return gregorian.minimumRange(of: component)
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return 0..<eraTable.highestCode + 1 }
        // A year number restarts at 1 in each era, so the highest one this calendar reaches is short by however late the newest era starts. ICU does the same in `JapaneseCalendar::handleGetLimit`.
        if component == .year, eraTable.erasCanEnd, let years = gregorian.maximumRange(of: .year) {
            return years.lowerBound..<years.upperBound - eraTable.newestAnchorYear
        }
        return gregorian.maximumRange(of: component)
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        // The year range inside an era is the same shortened range `maximumRange(of: .year)` reports, for the same reason.
        if smaller == .year, larger == .era, eraTable.erasCanEnd { return maximumRange(of: .year) }
        return gregorian.range(of: smaller, in: larger, for: date)
    }

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        guard larger == .era else { return gregorian.ordinality(of: smaller, in: larger, for: date) }
        return eraOrdinality(of: smaller, for: date)
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        if component == .era { return eraInterval(containing: date) }
        return gregorian.dateInterval(of: component, for: date)
    }

    func isDateInWeekend(_ date: Date) -> Bool {
        // The engine has a faster path than the shared helper, so use it rather than recomputing components here.
        gregorian.isDateInWeekend(date)
    }

    // MARK: - Date and DateComponents conversion

    func date(from components: DateComponents) -> Date? {
        gregorian.date(from: convertedToGregorian(components))
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        var dateComponents = gregorian.dateComponents(components, from: date, in: timeZone)
        relabelFromGregorian(&dateComponents, date: date, requested: components)
        return dateComponents
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        var dateComponents = gregorian.dateComponents(components, from: date)
        relabelFromGregorian(&dateComponents, date: date, requested: components)
        return dateComponents
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        // Adding to `.era` does not move the date, because the Gregorian engine ignores the era field for compatibility.
        gregorian.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        var dateComponents = gregorian.dateComponents(components, from: start, to: end)
        // A calendar with one era can never cross an era boundary, so the difference is always zero.
        if components.contains(.era), eraTable.entries.count == 1 { dateComponents.era = 0 }
        return dateComponents
    }

    func nextDate(after date: Date, matching components: DateComponents, direction: Calendar.SearchDirection) -> Date? {
        gregorian.nextDate(after: date, matching: convertedToGregorian(components), direction: direction)
    }

    // MARK: - Era relabeling

    /// The extended Gregorian year, month and day of `date`. The Gregorian engine reports an era-relative year, so era 0 (BCE) folds back onto one continuous year line.
    private func extendedDate(for date: Date) -> (year: Int, month: Int, day: Int)? {
        let probe = gregorian.dateComponents([.era, .year, .month, .day], from: date)
        guard let year = probe.year, let month = probe.month, let day = probe.day else { return nil }
        return (probe.era == 0 ? 1 - year : year, month, day)
    }

    /// Rewrites this calendar's era and year into the extended Gregorian year the engine expects.
    private func convertedToGregorian(_ components: DateComponents) -> DateComponents {
        var dateComponents = components
        let code = dateComponents.era ?? eraTable.defaultCode
        guard let entry = eraTable.entry(code: code) else {
            // The code is not one of this calendar's own eras, so it is a Gregorian era this calendar inherits (0 = BCE, 1 = CE). Leave both fields for the engine to reckon.
            return dateComponents
        }
        if let year = dateComponents.year {
            dateComponents.year = entry.extendedYear(fromEraYear: year)
        } else if dateComponents.yearForWeekOfYear == nil {
            // No year was given, so use year 1 of this calendar's own era, as ICU does. The engine would otherwise fall back to Gregorian year 1.
            dateComponents.year = entry.extendedYear(fromEraYear: 1)
        }
        // The year is now an extended Gregorian year, which the engine reads when no era is set.
        dateComponents.era = nil
        return dateComponents
    }

    /// Rewrites the engine's Gregorian era and year into this calendar's own.
    private func relabelFromGregorian(_ dateComponents: inout DateComponents, date: Date, requested: Calendar.ComponentSet) {
        guard requested.contains(.era) || requested.contains(.year) else { return }
        guard let (extendedYear, month, day) = extendedDate(for: date) else { return }
        guard let entry = eraTable.entry(extendedYear: extendedYear, month: month, day: day) else {
            // The date falls before every era in the table, so it keeps the Gregorian era and year already in place.
            return
        }
        if requested.contains(.era) { dateComponents.era = entry.code }
        if requested.contains(.year) { dateComponents.year = entry.eraYear(fromExtendedYear: extendedYear) }
    }

    // MARK: - Era interval

    private func boundary(of entry: _CalendarEraEntry) -> Date? {        gregorian.date(from: DateComponents(year: entry.anchorYear, month: entry.startMonth, day: entry.startDay, hour: 0, minute: 0, second: 0))
    }

    private func eraInterval(containing date: Date) -> DateInterval? {
        guard let (extendedYear, month, day) = extendedDate(for: date) else { return nil }
        guard let entry = eraTable.entry(extendedYear: extendedYear, month: month, day: day) else {
            return inheritedGregorianEraInterval(for: date)
        }
        guard let boundary = boundary(of: entry) else { return nil }

        if entry.direction == .backward {
            // The era counts down from its boundary, so it ends there and has no beginning. ICU reports the same open-ended shape it uses for BCE.
            return DateInterval(start: boundary - Calendar._maxDateIntervalDuration, end: boundary)
        }

        // A forward era begins at its boundary. An era that labels earlier dates anyway, like the Buddhist one, still reports no interval for them, which is what ICU does.
        guard date >= boundary else { return nil }

        // An era ends where the next one begins. This is a deliberate divergence from ICU, which
        // instead bumps the era field and keeps the era start's month and day, so it reports Showa
        // ending 1989-12-25 — eleven months after Heisei began on 1989-01-08, and overlapping it.
        // See `eraIntervalEndsWhereTheNextEraStarts` for the pinned values.
        guard let next = eraTable.eraAfter(entry), let end = self.boundary(of: next) else {
            return DateInterval(start: boundary, duration: Calendar._maxDateIntervalDuration)
        }
        return DateInterval(start: boundary, end: end)
    }

    /// The Gregorian era interval for a date older than every era in the table, cut short where the oldest era begins.
    private func inheritedGregorianEraInterval(for date: Date) -> DateInterval? {
        guard let gregorianEra = gregorian.dateInterval(of: .era, for: date) else { return nil }
        guard let oldest = eraTable.entries.last, let oldestBoundary = boundary(of: oldest) else { return gregorianEra }
        // The inherited CE era runs past this calendar's oldest era, so end it where that era takes over.
        if gregorianEra.start < oldestBoundary && gregorianEra.end > oldestBoundary {
            return DateInterval(start: gregorianEra.start, end: oldestBoundary)
        }
        return gregorianEra
    }

    // MARK: - Era ordinality

    /// How far into the era `date` falls, counted in `smaller` units starting at 1.
    ///
    /// The Gregorian engine counts these from its own era start, so it would report the Buddhist year as 2025 rather than 2568. Everything here counts from this calendar's era instead.
    private func eraOrdinality(of smaller: Calendar.Component, for date: Date) -> Int? {
        switch smaller {
        case .year:
            return dateComponents([.year], from: date).year

        case .quarter:
            // ICU keeps four quarters per era-year even when the era starts mid-year, so this stays a plain multiple of the era-year rather than a count from the era boundary.
            guard let year = eraOrdinality(of: .year, for: date),
                  let quarterInYear = gregorian.ordinality(of: .quarter, in: .year, for: date) else { return nil }
            return 4 * (year - 1) + quarterInYear

        case .month:
            // Months are counted from the era boundary, which can fall mid-year, so this is not a multiple of the era-year.
            guard let start = eraStart(for: date),
                  let months = gregorian.dateComponents([.month], from: start, to: date).month else { return nil }
            return months + 1

        case .day:
            return dayInEra(for: date)

        case .weekOfYear, .weekOfMonth:
            guard let day = dayInEra(for: date),
                  let weekday = gregorian.dateComponents([.weekday], from: date).weekday else { return nil }
            return _CalendarUtility.weekNumber(desiredDay: day, dayOfPeriod: day, weekday: weekday, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek)

        case .hour:
            guard let day = dayInEra(for: date), (Int.max - 24) / 24 >= day - 1,
                  let hourOfDay = gregorian.dateComponents([.hour], from: date).hour else { return nil }
            return (day - 1) * 24 + hourOfDay + 1

        case .minute:
            guard let hour = eraOrdinality(of: .hour, for: date), (Int.max - 60) / 60 >= hour - 1,
                  let minuteOfHour = gregorian.dateComponents([.minute], from: date).minute else { return nil }
            return (hour - 1) * 60 + minuteOfHour + 1

        case .second:
            guard let minute = eraOrdinality(of: .minute, for: date), (Int.max - 60) / 60 >= minute - 1,
                  let secondOfMinute = gregorian.dateComponents([.second], from: date).second else { return nil }
            return (minute - 1) * 60 + secondOfMinute + 1

        default:
            // `.yearForWeekOfYear` is not relabeled by this calendar, and the rest the engine answers with nil.
            return gregorian.ordinality(of: smaller, in: .era, for: date)
        }
    }

    /// The first instant of the era holding `date`, or nil when the era has no start this calendar can name.
    private func eraStart(for date: Date) -> Date? {
        eraInterval(containing: date)?.start
    }

    private func dayInEra(for date: Date) -> Int? {
        guard let start = eraStart(for: date) else { return nil }
        return Int(((date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / 86400).rounded(.down)) + 1
    }
}
