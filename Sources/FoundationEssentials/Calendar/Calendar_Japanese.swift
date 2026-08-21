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

/// Japanese imperial calendar. Same arithmetic as Gregorian; the year is reckoned within the current era.
internal final class _CalendarJapanese: _GregorianBackedCalendar, @unchecked Sendable {

    /// The five modern eras, newest first. Codes match ICU's numbering (Meiji = 232 … Reiwa = 236).
    // Following CLDR/ICU (unicode-org/icu#4019, ICU-23341), the pre-Meiji eras were dropped: dates before Meiji inherit the Gregorian era, so codes 2…231 are undefined.
    // Meiji starts 1868-09-08 to match Apple's runtime ICU (CLDR canonical is 1868-10-23).
    private static let eras = _CalendarEraTable([
        _CalendarEraEntry(code: 236, anchorYear: 2019, startMonth: 5, startDay: 1, direction: .forward),
        _CalendarEraEntry(code: 235, anchorYear: 1989, startMonth: 1, startDay: 8, direction: .forward),
        _CalendarEraEntry(code: 234, anchorYear: 1926, startMonth: 12, startDay: 25, direction: .forward),
        _CalendarEraEntry(code: 233, anchorYear: 1912, startMonth: 7, startDay: 30, direction: .forward),
        _CalendarEraEntry(code: 232, anchorYear: 1868, startMonth: 9, startDay: 8, direction: .forward),
    ])

    let gregorian: _CalendarGregorian
    var eraTable: _CalendarEraTable { Self.eras }
    let identifier: Calendar.Identifier = .japanese

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .japanese, "_CalendarJapanese only handles .japanese")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
