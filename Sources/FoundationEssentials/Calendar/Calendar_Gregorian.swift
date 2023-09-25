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

/// This class is a placeholder and work-in-progress to provide an implementation of the Gregorian calendar.
internal final class _CalendarGregorian: _CalendarProtocol, @unchecked Sendable {
    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        fatalError()
    }
    
    var identifier: Calendar.Identifier {
        .gregorian
    }
    
    var locale: Locale?
    
    var localeIdentifier: String
    
    var timeZone: TimeZone
    
    var firstWeekday: Int
    
    var minimumDaysInFirstWeek: Int
    
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
    
    func date(from components: DateComponents) -> Date? {
        fatalError()
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        fatalError()
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        fatalError()
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
