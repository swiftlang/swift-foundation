//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/**
 `DateComponents` encapsulates the components of a date in an extendable, structured manner.

 It is used to specify a date by providing the temporal components that make up a date and time in a particular calendar: hour, minutes, seconds, day, month, year, and so on. It can also be used to specify a duration of time, for example, 5 hours and 16 minutes. A `DateComponents` is not required to define all the component fields.

 When a new instance of `DateComponents` is created, the date components are set to `nil`.
*/
@available(macOS 10.9, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct DateComponents : Hashable, Equatable, Sendable {
    internal var _calendar: Calendar?
    internal var _timeZone: TimeZone?
    internal var _era: Int?
    internal var _year: Int?
    internal var _month: Int?
    internal var _day: Int?
    internal var _hour: Int?
    internal var _minute: Int?
    internal var _second: Int?
    internal var _nanosecond: Int?
    internal var _weekday: Int?
    internal var _weekdayOrdinal: Int?
    internal var _quarter: Int?
    internal var _week: Int?
    internal var _weekOfMonth: Int?
    internal var _weekOfYear: Int?
    internal var _yearForWeekOfYear: Int?
    internal var _isLeapMonth: Bool?

    /// Initialize a `DateComponents`, optionally specifying values for its fields.
    public init(calendar: Calendar? = nil,
         timeZone: TimeZone? = nil,
         era: Int? = nil,
         year: Int? = nil,
         month: Int? = nil,
         day: Int? = nil,
         hour: Int? = nil,
         minute: Int? = nil,
         second: Int? = nil,
         nanosecond: Int? = nil,
         weekday: Int? = nil,
         weekdayOrdinal: Int? = nil,
         quarter: Int? = nil,
         weekOfMonth: Int? = nil,
         weekOfYear: Int? = nil,
         yearForWeekOfYear: Int? = nil) {

        self.calendar = calendar
        self.timeZone = timeZone
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond
        self.weekday = weekday
        self.weekdayOrdinal = weekdayOrdinal
        self.quarter = quarter
        self.weekOfMonth = weekOfMonth
        self.weekOfYear = weekOfYear
        self.yearForWeekOfYear = yearForWeekOfYear
    }


    // MARK: - Properties

    /// Certain APIs (like Calendar) take Int values for fields like seconds, day, etc. In the legacy ObjC implementation, these would have been interpreted in the ObjC implementation of `NSDateComponents` as "set to nil". Therefore, for compatibility, we treat both `nil` and `Int.max` as "not set".
    private func converted(_ value: Int?) -> Int? {
        switch value {
        case .some(let v):
            return v == Int.max ? nil : v
        default:
            return nil
        }
    }

    /// The `Calendar` used to interpret the other values in this structure.
    ///
    /// - note: API which uses `DateComponents` may have different behavior if this value is `nil`. For example, assuming the current calendar or ignoring certain values.
    public var calendar: Calendar? {
        get { _calendar }
        set {
            _calendar = newValue
            // If the time zone is set, apply that to the calendar
            if let tz = _timeZone {
                _calendar?.timeZone = tz
            }
        }
    }

    /// A time zone.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var timeZone: TimeZone? {
        get { _timeZone }
        set {
            _timeZone = newValue
            // Also changes the time zone of the calendar
            if let newValue {
                _calendar?.timeZone = newValue
            }
        }
    }

    /// An era or count of eras.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var era: Int? {
        get { _era }
        set { _era = converted(newValue) }
    }

    /// A year or count of years.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var year: Int? {
        get { _year }
        set { _year = converted(newValue) }
    }

    /// A month or count of months.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var month: Int? {
        get { _month }
        set { _month = converted(newValue) }
    }

    /// A day or count of days.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var day: Int? {
        get { _day }
        set { _day = converted(newValue) }
    }

    /// An hour or count of hours.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var hour: Int? {
        get { _hour }
        set { _hour = converted(newValue) }
    }

    /// A minute or count of minutes.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var minute: Int? {
        get { _minute }
        set { _minute = converted(newValue) }
    }

    /// A second or count of seconds.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var second: Int? {
        get { _second }
        set { _second = converted(newValue) }
    }

    /// A nanosecond or count of nanoseconds.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var nanosecond: Int? {
        get { _nanosecond }
        set { _nanosecond = converted(newValue) }
    }

    /// A weekday or count of weekdays.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var weekday: Int? {
        get { _weekday }
        set { _weekday = converted(newValue) }
    }

    /// A weekday ordinal or count of weekday ordinals.
    /// Weekday ordinal units represent the position of the weekday within the next larger calendar unit, such as the month. For example, 2 is the weekday ordinal unit for the second Friday of the month.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var weekdayOrdinal: Int? {
        get { _weekdayOrdinal }
        set { _weekdayOrdinal = converted(newValue) }
    }

    /// A quarter or count of quarters.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var quarter: Int? {
        get { _quarter }
        set { _quarter = converted(newValue) }
    }

    /// A week of the month or a count of weeks of the month.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var weekOfMonth: Int? {
        get { _weekOfMonth }
        set { _weekOfMonth = converted(newValue) }
    }

    /// A week of the year or count of the weeks of the year.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var weekOfYear: Int? {
        get { _weekOfYear }
        set { _weekOfYear = converted(newValue) }
    }

    /// This exists only for compatibility with NSDateComponents deprecated `week` value.
    internal var week: Int? {
        get { _week }
        set { _week = converted(newValue) }
    }

    /// The ISO 8601 week-numbering year of the receiver.
    ///
    /// The Gregorian calendar defines a week to have 7 days, and a year to have 365 days, or 366 in a leap year. However, neither 365 or 366 divide evenly into a 7 day week, so it is often the case that the last week of a year ends on a day in the next year, and the first week of a year begins in the preceding year. To reconcile this, ISO 8601 defines a week-numbering year, consisting of either 52 or 53 full weeks (364 or 371 days), such that the first week of a year is designated to be the week containing the first Thursday of the year.
    ///
    /// You can use the yearForWeekOfYear property with the weekOfYear and weekday properties to get the date corresponding to a particular weekday of a given week of a year. For example, the 6th day of the 53rd week of the year 2005 (ISO 2005-W53-6) corresponds to Sat 1 January 2005 on the Gregorian calendar.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    public var yearForWeekOfYear: Int? {
        get { _yearForWeekOfYear }
        set { _yearForWeekOfYear = converted(newValue) }
    }

    /// Set to true if these components represent a leap month.
    public var isLeapMonth: Bool? {
        get { _isLeapMonth }
        set { _isLeapMonth = newValue }
    }

    /// Returns a `Date` calculated from the current components using the `calendar` property.
    public var date: Date? {
        guard let calendar = _calendar else { return nil }

        if let tz = _timeZone, calendar.timeZone != tz {
            var calendarWithTZ = calendar
            calendarWithTZ.timeZone = tz
            return calendarWithTZ.date(from: self)
        } else {
            return calendar.date(from: self)
        }
    }

    // MARK: - Generic Setter/Getters

    /// Set the value of one of the properties, using an enumeration value instead of a property name.
    ///
    /// The calendar and timeZone and isLeapMonth properties cannot be set by this method.
    @available(macOS 10.9, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public mutating func setValue(_ value: Int?, for component: Calendar.Component) {
        switch component {
        case .era: self.era = value
        case .year: self.year = value
        case .month: self.month = value
        case .day: self.day = value
        case .hour: self.hour = value
        case .minute: self.minute = value
        case .second: self.second = value
        case .weekday: self.weekday = value
        case .weekdayOrdinal: self.weekdayOrdinal = value
        case .quarter: self.quarter = value
        case .weekOfMonth: self.weekOfMonth = value
        case .weekOfYear: self.weekOfYear = value
        case .yearForWeekOfYear: self.yearForWeekOfYear = value
        case .nanosecond: self.nanosecond = value
        case .calendar, .timeZone, .isLeapMonth:
            // Do nothing
            break
        }
    }

    /// Returns the value of one of the properties, using an enumeration value instead of a property name.
    ///
    /// The calendar and timeZone and isLeapMonth property values cannot be retrieved by this method.
    @available(macOS 10.9, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func value(for component: Calendar.Component) -> Int? {
        switch component {
        case .era: return self.era
        case .year: return self.year
        case .month: return self.month
        case .day: return self.day
        case .hour: return self.hour
        case .minute: return self.minute
        case .second: return self.second
        case .weekday: return self.weekday
        case .weekdayOrdinal: return self.weekdayOrdinal
        case .quarter: return self.quarter
        case .weekOfMonth: return self.weekOfMonth
        case .weekOfYear: return self.weekOfYear
        case .yearForWeekOfYear: return self.yearForWeekOfYear
        case .nanosecond: return self.nanosecond
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        }
    }

    // MARK: -

    /// Returns true if the combination of properties which have been set in the receiver is a date which exists in the `calendar` property.
    ///
    /// This method is not appropriate for use on `DateComponents` values which are specifying relative quantities of calendar components.
    ///
    /// Except for some trivial cases (e.g., 'seconds' should be 0 - 59 in any calendar), this method is not necessarily cheap.
    ///
    /// If the time zone property is set in the `DateComponents`, it is used.
    ///
    /// The calendar property must be set, or the result is always `false`.
    @available(macOS 10.9, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var isValidDate: Bool {
        guard let calendar = _calendar else { return false }
        return isValidDate(in: calendar)
    }

    /// Returns true if the combination of properties which have been set in the receiver is a date which exists in the specified `Calendar`.
    ///
    /// This method is not appropriate for use on `DateComponents` values which are specifying relative quantities of calendar components.
    ///
    /// Except for some trivial cases (e.g., 'seconds' should be 0 - 59 in any calendar), this method is not necessarily cheap.
    ///
    /// If the time zone property is set in the `DateComponents`, it is used.
    @available(macOS 10.9, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func isValidDate(in calendar: Calendar) -> Bool {
        if let ns = _nanosecond, 1000 * 1000 * 1000 <= ns {
            return false
        }

        var date: Date?

        if let ns = _nanosecond, ns >= 0 {
            // If we have nanoseconds set, clear it temporarily
            var components = self
            components.nanosecond = 0
            date = calendar.date(from: components)
        } else {
            date = calendar.date(from: self)
        }

        guard let date else {
            return false
        }

        // This is similar to the list of units and keys\. in Calendar_Enumerate.swift, but this one does not include nanosecond or leap month
        let units : [Calendar.Component] = [.era, .year, .quarter, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .weekOfMonth, .weekOfYear, .yearForWeekOfYear]

        let newComponents = calendar.dateComponents(Set(units), from: date)

        if let era = _era, era != newComponents.era { return false }
        if let year = _year, year != newComponents.year { return false }
        if let quarter = _quarter, quarter != newComponents.quarter { return false }
        if let month = _month, month != newComponents.month { return false }
        if let day = _day, day != newComponents.day { return false }
        if let hour = _hour, hour != newComponents.hour { return false }
        if let minute = _minute, minute != newComponents.minute { return false }
        if let second = _second, second != newComponents.second { return false }
        if let weekday = _weekday, weekday != newComponents.weekday { return false }
        if let weekdayOrdinal = _weekdayOrdinal, weekdayOrdinal != newComponents.weekdayOrdinal { return false }
        if let weekOfMonth = _weekOfMonth, weekOfMonth != newComponents.weekOfMonth { return false }
        if let weekOfYear = _weekOfYear, weekOfYear != newComponents.weekOfYear { return false }
        if let yearForWeekOfYear = _yearForWeekOfYear, yearForWeekOfYear != newComponents.yearForWeekOfYear { return false }

        return true
    }

    // MARK: -

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_calendar)
        hasher.combine(_timeZone)
        hasher.combine(_era)
        hasher.combine(_year)
        hasher.combine(_month)
        hasher.combine(_day)
        hasher.combine(_hour)
        hasher.combine(_minute)
        hasher.combine(_second)
        hasher.combine(_nanosecond)
        hasher.combine(_weekday)
        hasher.combine(_weekdayOrdinal)
        hasher.combine(_quarter)
        hasher.combine(_weekOfMonth)
        hasher.combine(_weekOfYear)
        hasher.combine(_yearForWeekOfYear)
        hasher.combine(_isLeapMonth)
    }

    // MARK: - Bridging Helpers

    public static func ==(lhs : DateComponents, rhs: DateComponents) -> Bool {
        if lhs.era != rhs.era ||
            lhs.year != rhs.year ||
            lhs.quarter != rhs.quarter ||
            lhs.month != rhs.month ||
            lhs.day != rhs.day ||
            lhs.hour != rhs.hour ||
            lhs.minute != rhs.minute ||
            lhs.second != rhs.second ||
            lhs.weekday != rhs.weekday ||
            lhs.weekdayOrdinal != rhs.weekdayOrdinal ||
            lhs.weekOfMonth != rhs.weekOfMonth ||
            lhs.weekOfYear != rhs.weekOfYear ||
            lhs.yearForWeekOfYear != rhs.yearForWeekOfYear ||
            lhs.nanosecond != rhs.nanosecond {
            return false
        }

        if !((lhs.isLeapMonth == false && rhs.isLeapMonth == nil) ||
             (lhs.isLeapMonth == nil && rhs.isLeapMonth == false) ||
             (lhs.isLeapMonth == rhs.isLeapMonth)) {
            return false
        }

        if lhs.calendar != rhs.calendar { return false }
        if lhs.timeZone != rhs.timeZone { return false }

        return true
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DateComponents : CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {

    public var description: String {
        return self.customMirror.children.reduce(into: "") {
            $0 += "\($1.label ?? ""): \($1.value) "
        }
    }

    public var debugDescription: String {
        return self.description
    }

    public var customMirror: Mirror {
        var c: [(label: String?, value: Any)] = []
        if let r = calendar { c.append((label: "calendar", value: r.debugDescription)) }
        if let r = timeZone { c.append((label: "timeZone", value: r.debugDescription)) }
        if let r = era { c.append((label: "era", value: r)) }
        if let r = year { c.append((label: "year", value: r)) }
        if let r = month { c.append((label: "month", value: r)) }
        if let r = day { c.append((label: "day", value: r)) }
        if let r = hour { c.append((label: "hour", value: r)) }
        if let r = minute { c.append((label: "minute", value: r)) }
        if let r = second { c.append((label: "second", value: r)) }
        if let r = nanosecond { c.append((label: "nanosecond", value: r)) }
        if let r = weekday { c.append((label: "weekday", value: r)) }
        if let r = weekdayOrdinal { c.append((label: "weekdayOrdinal", value: r)) }
        if let r = quarter { c.append((label: "quarter", value: r)) }
        if let r = weekOfMonth { c.append((label: "weekOfMonth", value: r)) }
        if let r = weekOfYear { c.append((label: "weekOfYear", value: r)) }
        if let r = yearForWeekOfYear { c.append((label: "yearForWeekOfYear", value: r)) }
        if let r = isLeapMonth { c.append((label: "isLeapMonth", value: r)) }
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DateComponents : Codable {
    private enum CodingKeys : Int, CodingKey {
        case calendar
        case timeZone
        case era
        case year
        case month
        case day
        case hour
        case minute
        case second
        case nanosecond
        case weekday
        case weekdayOrdinal
        case quarter
        case weekOfMonth
        case weekOfYear
        case yearForWeekOfYear
        case isLeapMonth
    }

    public init(from decoder: Decoder) throws {
        let container  = try decoder.container(keyedBy: CodingKeys.self)
        let calendar   = try container.decodeIfPresent(Calendar.self, forKey: .calendar)
        let timeZone   = try container.decodeIfPresent(TimeZone.self, forKey: .timeZone)
        let era        = try container.decodeIfPresent(Int.self, forKey: .era)
        let year       = try container.decodeIfPresent(Int.self, forKey: .year)
        let month      = try container.decodeIfPresent(Int.self, forKey: .month)
        let day        = try container.decodeIfPresent(Int.self, forKey: .day)
        let hour       = try container.decodeIfPresent(Int.self, forKey: .hour)
        let minute     = try container.decodeIfPresent(Int.self, forKey: .minute)
        let second     = try container.decodeIfPresent(Int.self, forKey: .second)
        let nanosecond = try container.decodeIfPresent(Int.self, forKey: .nanosecond)

        let weekday           = try container.decodeIfPresent(Int.self, forKey: .weekday)
        let weekdayOrdinal    = try container.decodeIfPresent(Int.self, forKey: .weekdayOrdinal)
        let quarter           = try container.decodeIfPresent(Int.self, forKey: .quarter)
        let weekOfMonth       = try container.decodeIfPresent(Int.self, forKey: .weekOfMonth)
        let weekOfYear        = try container.decodeIfPresent(Int.self, forKey: .weekOfYear)
        let yearForWeekOfYear = try container.decodeIfPresent(Int.self, forKey: .yearForWeekOfYear)

        let isLeapMonth = try container.decodeIfPresent(Bool.self, forKey: .isLeapMonth)

        self.init(calendar: calendar,
                  timeZone: timeZone,
                  era: era,
                  year: year,
                  month: month,
                  day: day,
                  hour: hour,
                  minute: minute,
                  second: second,
                  nanosecond: nanosecond,
                  weekday: weekday,
                  weekdayOrdinal: weekdayOrdinal,
                  quarter: quarter,
                  weekOfMonth: weekOfMonth,
                  weekOfYear: weekOfYear,
                  yearForWeekOfYear: yearForWeekOfYear)

        if let isLeapMonth {
            self.isLeapMonth = isLeapMonth
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.calendar, forKey: .calendar)
        try container.encodeIfPresent(self.timeZone, forKey: .timeZone)
        try container.encodeIfPresent(self.era, forKey: .era)
        try container.encodeIfPresent(self.year, forKey: .year)
        try container.encodeIfPresent(self.month, forKey: .month)
        try container.encodeIfPresent(self.day, forKey: .day)
        try container.encodeIfPresent(self.hour, forKey: .hour)
        try container.encodeIfPresent(self.minute, forKey: .minute)
        try container.encodeIfPresent(self.second, forKey: .second)
        try container.encodeIfPresent(self.nanosecond, forKey: .nanosecond)
        try container.encodeIfPresent(self.weekday, forKey: .weekday)
        try container.encodeIfPresent(self.weekdayOrdinal, forKey: .weekdayOrdinal)
        try container.encodeIfPresent(self.quarter, forKey: .quarter)
        try container.encodeIfPresent(self.weekOfMonth, forKey: .weekOfMonth)
        try container.encodeIfPresent(self.weekOfYear, forKey: .weekOfYear)
        try container.encodeIfPresent(self.yearForWeekOfYear, forKey: .yearForWeekOfYear)
        try container.encodeIfPresent(self.isLeapMonth, forKey: .isLeapMonth)
    }
}

// MARK: - Bridging

#if FOUNDATION_FRAMEWORK

@_implementationOnly import _ForSwiftFoundation

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension DateComponents : ReferenceConvertible, _ObjectiveCBridgeable {
    public typealias ReferenceType = NSDateComponents

    public static func _getObjectiveCType() -> Any.Type {
        return NSDateComponents.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSDateComponents {
        let ns = NSDateComponents()
        if let _calendar { ns.calendar = _calendar }
        if let _timeZone { ns.timeZone = _timeZone }
        if let _era { ns.era = _era }
        if let _year { ns.year = _year }
        if let _month { ns.month = _month }
        if let _day { ns.day = _day }
        if let _hour { ns.hour = _hour }
        if let _minute { ns.minute = _minute }
        if let _second { ns.second = _second }
        if let _nanosecond { ns.nanosecond = _nanosecond }
        if let _weekday { ns.weekday = _weekday }
        if let _weekdayOrdinal { ns.weekdayOrdinal = _weekdayOrdinal }
        if let _quarter { ns.quarter = _quarter }
        if let _weekOfMonth { ns.weekOfMonth = _weekOfMonth }
        if let _weekOfYear { ns.weekOfYear = _weekOfYear }
        if let _yearForWeekOfYear { ns.yearForWeekOfYear = _yearForWeekOfYear }
        if let _isLeapMonth { ns.isLeapMonth = _isLeapMonth }
        if let _week { __NSDateComponentsSetWeek(ns, _week) }
        return ns
    }

    public static func _forceBridgeFromObjectiveC(_ dateComponents: NSDateComponents, result: inout DateComponents?) {
        if !_conditionallyBridgeFromObjectiveC(dateComponents, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ ns: NSDateComponents, result: inout DateComponents?) -> Bool {
        var dc = DateComponents()
        if let calendar = ns.calendar { dc.calendar = calendar }
        if let timeZone = ns.timeZone { dc.timeZone = timeZone }
        if ns.era != NSInteger.max { dc.era = ns.era }
        if ns.year != NSInteger.max { dc.year = ns.year }
        if ns.month != NSInteger.max { dc.month = ns.month }
        if ns.day != NSInteger.max { dc.day = ns.day }
        if ns.hour != NSInteger.max { dc.hour = ns.hour }
        if ns.minute != NSInteger.max { dc.minute = ns.minute }
        if ns.second != NSInteger.max { dc.second = ns.second }
        if ns.nanosecond != NSInteger.max { dc.nanosecond = ns.nanosecond }
        if ns.weekday != NSInteger.max { dc.weekday = ns.weekday }
        if ns.weekdayOrdinal != NSInteger.max { dc.weekdayOrdinal = ns.weekdayOrdinal }
        if ns.quarter != NSInteger.max { dc.quarter = ns.quarter }
        if ns.weekOfMonth != NSInteger.max { dc.weekOfMonth = ns.weekOfMonth }
        if ns.weekOfYear != NSInteger.max { dc.weekOfYear = ns.weekOfYear }
        if ns.yearForWeekOfYear != NSInteger.max { dc.yearForWeekOfYear = ns.yearForWeekOfYear }
        if (__NSDateComponentsIsLeapMonthSet(ns)) {
            dc.isLeapMonth = ns.isLeapMonth
        }
        if (__NSDateComponentsWeek(ns) != NSInteger.max) {
            dc._week = __NSDateComponentsWeek(ns)
        }
        result = dc
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSDateComponents?) -> DateComponents {
        guard let src = source else { return DateComponents() }
        var result: DateComponents? = DateComponents()
        _ = _conditionallyBridgeFromObjectiveC(src, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSDateComponents : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as DateComponents)
    }
}
#endif // FOUNDATION_FRAMEWORK
