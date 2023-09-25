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

// Required to be `AnyObject` because it optimizes the call sites in the `struct` wrapper for efficient function dispatch.
package protocol _CalendarProtocol: AnyObject, Sendable, CustomDebugStringConvertible {
    
    init(identifier: Calendar.Identifier, timeZone: TimeZone?, locale: Locale?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?)
    
    var identifier: Calendar.Identifier { get }
    var locale: Locale? { get }
    var localeIdentifier: String { get }
    var timeZone: TimeZone { get }
    var firstWeekday: Int { get }
    /// Returns a different first weekday than the Calendar might normally use, based on Locale preferences.
    var preferredFirstWeekday: Int? { get }
    var minimumDaysInFirstWeek: Int { get }
    /// Returns a different min days in first week than the Calendar might normally use, based on Locale preferences.
    var preferredMinimumDaysInFirstweek: Int? { get }
    var gregorianStartDate: Date? { get }
    var isAutoupdating: Bool { get }
    var isBridged: Bool { get }
    
    var debugDescription: String { get }
    
    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> any _CalendarProtocol
    
    func hash(into hasher: inout Hasher)
    
    func minimumRange(of component: Calendar.Component) -> Range<Int>?
    func maximumRange(of component: Calendar.Component) -> Range<Int>?
    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>?
    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int?
    
    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval?
    
    func isDateInWeekend(_ date: Date) -> Bool
    func weekendRange() -> WeekendRange?
    func date(from components: DateComponents) -> Date?
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents
    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date?
    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSCalendar() -> NSCalendar
#endif
}

extension _CalendarProtocol {
    package var preferredFirstWeekday: Int? { nil }
    package var preferredMinimumDaysInFirstweek: Int? { nil }
    
    package var isAutoupdating: Bool { false }
    package var isBridged: Bool { false }
    
    package var gregorianStartDate: Date? { nil }
    package var debugDescription: String { "\(identifier)" }
}
