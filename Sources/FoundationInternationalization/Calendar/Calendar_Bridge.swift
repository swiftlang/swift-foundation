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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _ForSwiftFoundation

/// Wraps an `NSCalendar` with more Swift-like `Calendar` API. See also: `_NSSwiftCalendar`.
/// This is only used in the case where we have custom Objective-C subclasses of `NSCalendar`. It is assumed that the subclass is Sendable.
internal final class _CalendarBridged: _CalendarProtocol, @unchecked Sendable {
    let _calendar: NSCalendar

    // MARK: -
    // MARK: Bridging

    internal init(adoptingReference reference: NSCalendar) {
        _calendar = reference
    }
    
    required init(identifier: Calendar.Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil, gregorianStartDate: Date? = nil) {
        fatalError("Unexpected init")
    }
    
    static func == (lhs: _CalendarBridged, rhs: _CalendarBridged) -> Bool {
        lhs._calendar == rhs._calendar
    }

    func bridgeToNSCalendar() -> NSCalendar {
        _calendar.copy() as! NSCalendar
    }

    func copy(changingLocale: Locale?, changingTimeZone: TimeZone?, changingFirstWeekday: Int?, changingMinimumDaysInFirstWeek: Int?) -> any _CalendarProtocol {
        CalendarCache.cache.fixed(identifier: self.identifier, 
                                  locale: changingLocale ?? locale,
                                  timeZone: changingTimeZone ?? timeZone,
                                  firstWeekday: changingFirstWeekday ?? firstWeekday,
                                  minimumDaysInFirstWeek: changingMinimumDaysInFirstWeek ?? minimumDaysInFirstWeek,
                                  gregorianStartDate: gregorianStartDate)
    }
    
    // MARK: -
    //

    /// The identifier of the calendar.
    var identifier : Calendar.Identifier {
        return Calendar._fromNSCalendarIdentifier(_calendar.calendarIdentifier)!
    }

    /// The locale of the calendar.
    var locale : Locale? {
        get {
            _calendar.locale
        }
        set {
            _calendar.locale = newValue
        }
    }

    var localeIdentifier: String {
        _calendar.locale?.identifier ?? ""
    }
    
    /// The time zone of the calendar.
    var timeZone : TimeZone {
        get {
            _calendar.timeZone
        }
        set {
            _calendar.timeZone = newValue
        }
    }

    /// The first weekday of the calendar.
    var firstWeekday : Int {
        get {
            _calendar.firstWeekday
        }
        set {
            _calendar.firstWeekday = newValue
        }
    }

    /// The number of minimum days in the first week.
    var minimumDaysInFirstWeek : Int {
        get {
            _calendar.minimumDaysInFirstWeek
        }
        set {
            _calendar.minimumDaysInFirstWeek = newValue
        }
    }

    // MARK: -
    //

    /// Returns the minimum range limits of the values that a given component can take on in the receiver.
    ///
    /// As an example, in the Gregorian calendar the minimum range of values for the Day component is 1-28.
    /// - parameter component: A component to calculate a range for.
    /// - returns: The range, or nil if it could not be calculated.
    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        Range(_calendar.minimumRange(of: _toNSCalendarUnit([component])))
    }

    /// The maximum range limits of the values that a given component can take on in the receive
    ///
    /// As an example, in the Gregorian calendar the maximum range of values for the Day component is 1-31.
    /// - parameter component: A component to calculate a range for.
    /// - returns: The range, or nil if it could not be calculated.
    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        Range(_calendar.maximumRange(of: _toNSCalendarUnit([component])))
    }


    /// Returns the range of absolute time values that a smaller calendar component (such as a day) can take on in a larger calendar component (such as a month) that includes a specified absolute time.
    ///
    /// You can use this method to calculate, for example, the range the `day` component can take on in the `month` in which `date` lies.
    /// - parameter smaller: The smaller calendar component.
    /// - parameter larger: The larger calendar component.
    /// - parameter date: The absolute time for which the calculation is performed.
    /// - returns: The range of absolute time values smaller can take on in larger at the time specified by date. Returns `nil` if larger is not logically bigger than smaller in the calendar, or the given combination of components does not make sense (or is a computation which is undefined).
    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        Range(_calendar.range(of: _toNSCalendarUnit([smaller]), in: _toNSCalendarUnit([larger]), for: date))
    }

    /// Returns the starting time and duration of a given calendar component that contains a given date.
    ///
    /// - parameter component: A calendar component.
    /// - parameter date: The specified date.
    /// - returns: A new `DateInterval` if the starting time and duration of a component could be calculated, otherwise `nil`.
    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        var interval : TimeInterval = 0
        var nsDate : NSDate? = NSDate(timeIntervalSinceReferenceDate: 0)
        if _calendar.range(of: _toNSCalendarUnit([component]), start: &nsDate, interval: &interval, for: date) {
            guard let nsDate else { return nil }
            return DateInterval(start: nsDate as Date, duration: interval)
        } else {
            return nil
        }
    }

    /// Returns, for a given absolute time, the ordinal number of a smaller calendar component (such as a day) within a specified larger calendar component (such as a week).
    ///
    /// The ordinality is in most cases not the same as the decomposed value of the component. Typically return values are 1 and greater. For example, the time 00:45 is in the first hour of the day, and for components `hour` and `day` respectively, the result would be 1. An exception is the week-in-month calculation, which returns 0 for days before the first week in the month containing the date.
    ///
    /// - note: Some computations can take a relatively long time.
    /// - parameter smaller: The smaller calendar component.
    /// - parameter larger: The larger calendar component.
    /// - parameter date: The absolute time for which the calculation is performed.
    /// - returns: The ordinal number of smaller within larger at the time specified by date. Returns `nil` if larger is not logically bigger than smaller in the calendar, or the given combination of components does not make sense (or is a computation which is undefined).
    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        let result = _calendar.ordinality(of: _toNSCalendarUnit([smaller]), in: _toNSCalendarUnit([larger]), for: date)
        if result == NSNotFound { return nil }
        return result
    }

    /// Returns a new `Date` representing the date calculated by adding components to a given date.
    ///
    /// - parameter components: A set of values to add to the date.
    /// - parameter date: The starting date.
    /// - parameter wrappingComponents: If `true`, the component should be incremented and wrap around to zero/one on overflow, and should not cause higher components to be incremented. The default value is `false`.
    /// - returns: A new date, or nil if a date could not be calculated with the given input.
    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date? {
        _calendar.date(byAdding: components, to: date, options: wrappingComponents ? [.wrapComponents] : [])
    }

    /// Returns a date created from the specified components.
    ///
    /// - parameter components: Used as input to the search algorithm for finding a corresponding date.
    /// - returns: A new `Date`, or nil if a date could not be found which matches the components.
    func date(from components: DateComponents) -> Date? {
        _calendar.date(from: components)
    }

    /// Returns all the date components of a date, using the calendar time zone.
    ///
    /// - note: If you want "date information in a given time zone" in order to display it, you should use `DateFormatter` to format the date.
    /// - parameter date: The `Date` to use.
    /// - returns: The date components of the specified date.
    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        _calendar.components(_toNSCalendarUnit(components.set), from: date)
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        let originalTimeZone = _calendar.timeZone
        _calendar.timeZone = timeZone
        defer { _calendar.timeZone = originalTimeZone }

        return self.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
    }


    /// Returns the difference between two dates.
    ///
    /// - parameter components: Which components to compare.
    /// - parameter start: The starting date.
    /// - parameter end: The ending date.
    /// - returns: The result of calculating the difference from start to end.
    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        _calendar.components(_toNSCalendarUnit(components.set), from: start, to: end, options: [])
    }

    /// Returns `true` if the given date is within a weekend period, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within a weekend.
    func isDateInWeekend(_ date: Date) -> Bool {
        _calendar.isDateInWeekend(date)
    }
    
    // MARK: -
    //

    func hash(into hasher: inout Hasher) {
        hasher.combine(_calendar)
    }

    var debugDescription: String {
        "bridged \(_calendar.debugDescription)"
    }
    
    var isBridged: Bool {
        true
    }
}

#endif // FOUNDATION_FRAMEWORK
