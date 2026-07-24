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

/// Japanese imperial calendar. Same arithmetic as Gregorian; year is reckoned within the current era. Delegates to `_CalendarGregorian`.
internal final class _CalendarJapanese: _CalendarProtocol, @unchecked Sendable {

    private struct EraEntry {
        let index: Int
        let startGregorianYear: Int
        let startMonth: Int
        let startDay: Int

        init(_ index: Int32, _ year: Int16, _ month: Int8, _ day: Int8) {
            self.index = Int(index)
            self.startGregorianYear = Int(year)
            self.startMonth = Int(month)
            self.startDay = Int(day)
        }
    }

    /// The five modern Japanese eras (Meiji 1868 → Reiwa 2019), sorted descending. Index values match ICU's era numbering (Meiji = 232 … Reiwa = 236).
    // Following CLDR/ICU (unicode-org/icu#4019, ICU-23341), the pre-Meiji eras were dropped: dates before Meiji inherit the Gregorian era (0 = BCE, 1 = CE), so the indices are sparse (2…231 are undefined).
    // Meiji (232) uses 1868-09-08 to match Apple's runtime ICU (CLDR canonical is 1868-10-23).
    private static let eraData: InlineArray<5, (index: Int32, year: Int16, month: Int8, day: Int8)> = [
        (236, 2019, 5, 1),
        (235, 1989, 1, 8),
        (234, 1926, 12, 25),
        (233, 1912, 7, 30),
        (232, 1868, 9, 8),
    ]

    private static let eraCount = 5

    private static func era(at i: Int) -> EraEntry {
        let raw = eraData[i]
        return EraEntry(raw.index, raw.year, raw.month, raw.day)
    }

    private let gregorian: _CalendarGregorian

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .japanese, "_CalendarJapanese only handles .japanese")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

    let identifier: Calendar.Identifier = .japanese

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
        return _CalendarJapanese(identifier: identifier, timeZone: args.timeZone, locale: args.locale, firstWeekday: args.firstWeekday, minimumDaysInFirstWeek: args.minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    func supportsNextDateFastPath(for components: Calendar.ComponentSet) -> Bool { gregorian.supportsNextDateFastPath(for: components) }

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

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return Range(0...Self.era(at: 0).index) }
        if component == .year { return Range(1...1) }
        return gregorian.minimumRange(of: component)
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        if component == .era { return Range(0...Self.era(at: 0).index) }
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
            return eraInterval(containing: date)
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
        adjustToJapanese(&dc, date: date, requested: components)
        return dc
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        var dc = gregorian.dateComponents(components, from: date)
        adjustToJapanese(&dc, date: date, requested: components)
        return dc
    }

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        gregorian.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        gregorian.dateComponents(components, from: start, to: end)
    }

    func nextDate(after date: Date, matching components: DateComponents, direction: Calendar.SearchDirection) -> Date? {
        gregorian.nextDate(after: date, matching: convertedToGregorian(components), direction: direction)
    }

    // MARK: - Era helpers

    private func eraEntry(forGregorianYear y: Int, month m: Int, day d: Int) -> EraEntry? {
        for i in 0..<Self.eraCount {
            let era = Self.era(at: i)
            if (y, m, d) >= (era.startGregorianYear, era.startMonth, era.startDay) {
                return era
            }
        }
        return nil
    }

    private func eraEntry(byIndex index: Int) -> EraEntry? {
        // Eras are stored descending, so the highest index (Reiwa) is at position 0. Indices are sparse (Meiji = 232 … Reiwa = 236); the Gregorian-inherited eras 0/1 and the gap 2…231 have no entry.
        let i = Self.era(at: 0).index - index
        guard i >= 0 && i < Self.eraCount else { return nil }
        let era = Self.era(at: i)
        return era.index == index ? era : nil
    }

    private func eraInterval(containing date: Date) -> DateInterval? {
        let comps = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        guard let era = eraEntry(forGregorianYear: y, month: m, day: d) else {
            // Before Meiji the era is inherited from Gregorian (BCE/CE), but the CE era is interrupted by Meiji, so clip its end to Meiji's start.
            guard let gregEra = gregorian.dateInterval(of: .era, for: date) else { return nil }
            let meiji = Self.era(at: Self.eraCount - 1)
            let meijiStartDC = DateComponents(year: meiji.startGregorianYear, month: meiji.startMonth, day: meiji.startDay, hour: 0, minute: 0, second: 0)
            guard let meijiStart = gregorian.date(from: meijiStartDC) else { return gregEra }
            if gregEra.start < meijiStart && gregEra.end > meijiStart {
                return DateInterval(start: gregEra.start, end: meijiStart)
            }
            return gregEra
        }
        let startDC = DateComponents(year: era.startGregorianYear, month: era.startMonth, day: era.startDay, hour: 0, minute: 0, second: 0)
        guard let start = gregorian.date(from: startDC) else { return nil }
        let endDate: Date
        let position = Self.era(at: 0).index - era.index
        if position > 0 {
            let next = Self.era(at: position - 1)
            let endDC = DateComponents(year: next.startGregorianYear, month: next.startMonth, day: next.startDay, hour: 0, minute: 0, second: 0)
            guard let e = gregorian.date(from: endDC) else { return nil }
            endDate = e
        } else {
            endDate = start.addingTimeInterval(Calendar._maxDateIntervalDuration)
        }
        return DateInterval(start: start, end: endDate)
    }

    // MARK: - Components conversion

    private func convertedToGregorian(_ components: DateComponents) -> DateComponents {
        var dc = components
        // Default to the latest era (Reiwa) when the era is unspecified, matching ICU.
        let eraIndex = dc.era ?? Self.era(at: 0).index
        if eraIndex <= 1 {
            // Gregorian-inherited era (0 = BCE, 1 = CE): pass the era and year straight through for the Gregorian calendar to reckon.
            return dc
        }
        if let year = dc.year, let eraEntry = eraEntry(byIndex: eraIndex) {
            dc.year = year + eraEntry.startGregorianYear - 1
        }
        dc.era = nil
        return dc
    }

    private func adjustToJapanese(_ dc: inout DateComponents, date: Date, requested: Calendar.ComponentSet) {
        guard requested.contains(.era) || requested.contains(.year) else { return }
        let probe = gregorian.dateComponents([.era, .year, .month, .day], from: date)
        guard let y = probe.year, let m = probe.month, let d = probe.day else { return }
        let extendedYear = probe.era == 0 ? 1 - y : y
        // Meiji onward, relabel to the Japanese era. Before Meiji, ICU inherits the Gregorian era (0 = BCE, 1 = CE), which `dc` already carries from the Gregorian conversion, so leave it untouched.
        if let era = eraEntry(forGregorianYear: extendedYear, month: m, day: d) {
            if requested.contains(.era) { dc.era = era.index }
            if requested.contains(.year) { dc.year = extendedYear - era.startGregorianYear + 1 }
        }
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
