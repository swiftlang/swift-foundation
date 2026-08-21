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

/// Buddhist calendar. Same arithmetic as Gregorian; one era, whose year 1 is 543 BCE.
internal final class _CalendarBuddhist: _GregorianBackedCalendar, @unchecked Sendable {

    /// The single BE era. It labels every date the calendar can express, which is how ICU's `BuddhistCalendar` behaves.
    private static let eras = _CalendarEraTable([
        _CalendarEraEntry(code: 0, anchorYear: -542, startMonth: 1, startDay: 1, direction: .forward, labelsEveryDate: true)
    ])

    let gregorian: _CalendarGregorian
    var eraTable: _CalendarEraTable { Self.eras }
    let identifier: Calendar.Identifier = .buddhist

    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        assert(identifier == .buddhist, "_CalendarBuddhist only handles .buddhist")
        self.gregorian = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar(inner: self))
    }
#endif
}
