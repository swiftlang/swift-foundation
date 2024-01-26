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

internal final class _CalendarGregorianAutoupdating: _CalendarProtocol, @unchecked Sendable {
    init() {
    }
    
    init(identifier: Calendar.Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil, gregorianStartDate: Date? = nil) {
        fatalError("Unexpected init")
    }
    
    var identifier: Calendar.Identifier {
        CalendarCache.cache._current_gregorian.identifier
    }
    
    var localeIdentifier: String {
        CalendarCache.cache._current_gregorian.localeIdentifier
    }
    
    var debugDescription: String {
        "autoupdating \(identifier)"
    }

    var locale: Locale? {
        get {
            CalendarCache.cache._current_gregorian.locale
        }
        set {
            fatalError("Copy the autoupdating calendar before setting values")
        }
    }
    
    var timeZone: TimeZone {
        get {
            CalendarCache.cache._current_gregorian.timeZone
        }
        set {
            fatalError("Copy the autoupdating calendar before setting values")
        }
    }
    
    var firstWeekday: Int {
        get {
            CalendarCache.cache._current_gregorian.firstWeekday
        }
        set {
            fatalError("Copy the autoupdating calendar before setting values")
        }
    }
    
    var minimumDaysInFirstWeek: Int {
        get {
            CalendarCache.cache._current_gregorian.minimumDaysInFirstWeek
        }
        set {
            fatalError("Copy the autoupdating calendar before setting values")
        }
    }
    
    var isAutoupdating: Bool {
        true
    }
    
    func copy(changingLocale: Locale? = nil,
              changingTimeZone: TimeZone? = nil,
              changingFirstWeekday: Int? = nil,
              changingMinimumDaysInFirstWeek: Int? = nil) -> any _CalendarProtocol {
        CalendarCache.cache._current_gregorian.copy(changingLocale: changingLocale, changingTimeZone: changingTimeZone, changingFirstWeekday: changingFirstWeekday, changingMinimumDaysInFirstWeek: changingMinimumDaysInFirstWeek)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(1)
    }
    
    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        CalendarCache.cache._current_gregorian.minimumRange(of: component)
    }
    
    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        CalendarCache.cache._current_gregorian.maximumRange(of: component)
    }
    
    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        CalendarCache.cache._current_gregorian.range(of: smaller, in: larger, for: date)
    }
    
    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        CalendarCache.cache._current_gregorian.ordinality(of: smaller, in: larger, for: date)
    }
    
    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        CalendarCache.cache._current_gregorian.dateInterval(of: component, for: date)
    }
    
    func isDateInWeekend(_ date: Date) -> Bool {
        CalendarCache.cache._current_gregorian.isDateInWeekend(date)
    }
    
    func date(from components: DateComponents) -> Date? {
        CalendarCache.cache._current_gregorian.date(from: components)
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        CalendarCache.cache._current_gregorian.dateComponents(components, from: date, in: timeZone)
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        CalendarCache.cache._current_gregorian.dateComponents(components, from: date)
    }
    
    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        CalendarCache.cache._current_gregorian.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }
    
    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        CalendarCache.cache._current_gregorian.dateComponents(components, from: start, to: end)
    }
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar {
        _NSSwiftCalendar(calendar: Calendar.autoupdatingCurrent)
    }
#endif
}
