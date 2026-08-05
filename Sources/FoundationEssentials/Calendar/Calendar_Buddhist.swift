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

/// Buddhist calendar. Year = Gregorian + 543, single era (BE). Delegates to `_CalendarGregorian`.
internal final class _CalendarBuddhist: _CalendarProtocol, @unchecked Sendable {

    static let yearOffset = 543

    private let gregorian: _CalendarGregorian

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .buddhist, "_CalendarBuddhist only handles .buddhist")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

    let identifier: Calendar.Identifier = .buddhist

    var locale: Locale? {
        get { gregorian.locale }
        set { gregorian.locale = newValue }
    }

    var timeZone: TimeZone {
        get { gregorian.timeZone }
        set { gregorian.timeZone = newValue }
    }

    var firstWeekday: Int {
        get { gregorian.firstWeekday }
        set { gregorian.firstWeekday = newValue }
    }

    var minimumDaysInFirstWeek: Int {
        get { gregorian.minimumDaysInFirstWeek }
        set { gregorian.minimumDaysInFirstWeek = newValue }
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> any _CalendarProtocol {
        let args = _CalendarUtility.resolvedCopyArgs(
            currentTimeZone: gregorian.timeZone, changingTimeZone: changingTimeZone,
            currentLocale: gregorian.locale, changingLocale: changingLocale,
            currentFirstWeekday: gregorian._firstWeekday, changingFirstWeekday: changingFirstWeekday,
            currentMinimumDaysInFirstWeek: gregorian._minimumDaysInFirstWeek, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek
        )
        return _CalendarBuddhist(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
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

    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool { gregorian.supportsNextDateFastPath(for: components) }

    // MARK: - Range

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return Range(0...0) }
        return gregorian.minimumRange(of: component)
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return Range(0...0) }
        return gregorian.maximumRange(of: component)
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        gregorian.range(of: smaller, in: larger, for: date)
    }

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        gregorian.ordinality(of: smaller, in: larger, for: date)
    }

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        if component == .era {
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: -63113904000.0 - Calendar._maxDateIntervalDuration), duration: Calendar._maxDateIntervalDuration)
        }
        return gregorian.dateInterval(of: component, for: date)
    }

    func isDateInWeekend(_ date: Date) -> Bool {
        gregorian.isDateInWeekend(date)
    }

    // MARK: - Date / DateComponents conversion

    func date(from components: DateComponents) -> Date? {
        gregorian.date(from: convertedToGregorian(components))
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: date, in: timeZone)
        adjustToBuddhist(&dc, requested: components)
        return dc
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: date)
        adjustToBuddhist(&dc, requested: components)
        return dc
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        gregorian.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: start, to: end)
        if components.contains(.era) { dc.era = 0 }
        return dc
    }

    // MARK: - Fast path

    func nextDate(after date: Date, matching components: DateComponents, direction: Calendar.SearchDirection) -> Date? {
        gregorian.nextDate(after: date, matching: convertedToGregorian(components), direction: direction)
    }

    // MARK: - Helpers

    private func convertedToGregorian(_ components: DateComponents) -> DateComponents {
        var dc = components
        if let y = dc.year { dc.year = y - Self.yearOffset }
        dc.era = nil
        return dc
    }

    private func adjustToBuddhist(_ dc: inout DateComponents, requested: Calendar.ComponentSet) {
        if requested.contains(.year), let y = dc.year { dc.year = y + Self.yearOffset }
        if requested.contains(.era) { dc.era = 0 }
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
