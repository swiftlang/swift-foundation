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

/// Republic of China (Minguo) calendar. Same arithmetic as Gregorian; 1912 CE is Minguo 1, and years before that count backward in a second era.
internal final class _CalendarRepublicOfChina: _GregorianBackedCalendar, @unchecked Sendable {

    /// The two eras, newest first. Codes match ICU's `TaiwanCalendar` (Before-Minguo = 0, Minguo = 1).
    private static let eras = _CalendarEraTable([
        _CalendarEraEntry(code: 1, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .forward),
        _CalendarEraEntry(code: 0, anchorYear: 1912, startMonth: 1, startDay: 1, direction: .backward),
    ])

    let gregorian: _CalendarGregorian
    var eraTable: _CalendarEraTable { Self.eras }
    let identifier: Calendar.Identifier = .republicOfChina

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .republicOfChina, "_CalendarRepublicOfChina only handles .republicOfChina")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
