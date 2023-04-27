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
import CoreFoundation
@_implementationOnly import os
@_implementationOnly import CoreFoundation_Private.CFLocale

extension NSCalendar.Unit {
    // Avoid the deprecation warning for .NSWeekCalendarUnit
    static let deprecatedWeekUnit: NSCalendar.Unit = NSCalendar.Unit(rawValue: (1 << 8))
}

@objc
extension NSCalendar {
    @objc
    static var _autoupdatingCurrent: NSCalendar {
        _NSSwiftCalendar(calendar: Calendar.autoupdatingCurrent)
    }

    @objc
    static var _current: NSCalendar {
        _NSSwiftCalendar(calendar: Calendar.current)
    }

    @objc
    class func _newCalendarWithIdentifier(_ idStr: CFCalendarIdentifier) -> NSCalendar? {
        let id: Calendar.Identifier
        if idStr == CFCalendarIdentifier.gregorianCalendar {
            id = .gregorian
        } else if idStr == CFCalendarIdentifier.buddhistCalendar {
            id = .buddhist
        } else if idStr == CFCalendarIdentifier.chineseCalendar {
            id = .chinese
        } else if idStr == CFCalendarIdentifier.hebrewCalendar {
            id = .hebrew
        } else if idStr == CFCalendarIdentifier.islamicCalendar {
            id = .islamic
        } else if idStr == CFCalendarIdentifier.islamicCivilCalendar {
            id = .islamicCivil
        } else if idStr == CFCalendarIdentifier.japaneseCalendar {
            id = .japanese
        } else if idStr == CFCalendarIdentifier.republicOfChinaCalendar {
            id = .republicOfChina
        } else if idStr == CFCalendarIdentifier.persianCalendar {
            id = .persian
        } else if idStr == CFCalendarIdentifier.indianCalendar {
            id = .indian
        } else if idStr == CFCalendarIdentifier.cfiso8601Calendar {
            id = .iso8601
        } else if idStr == CFCalendarIdentifier.islamicTabularCalendar {
            id = .islamicTabular
        } else if idStr == CFCalendarIdentifier.islamicUmmAlQuraCalendar {
            id = .islamicUmmAlQura
        } else if idStr == CFCalendarIdentifier.coptic {
            id = .coptic
        } else if idStr == CFCalendarIdentifier.ethiopicAmeteMihret {
            id = .ethiopicAmeteMihret
        } else if idStr == CFCalendarIdentifier.ethiopicAmeteAlem {
            id = .ethiopicAmeteAlem
        } else {
            return nil
        }
        return _NSSwiftCalendar(calendar: Calendar(identifier: id))
    }

    @objc
    class func _resetCurrent() {
        CalendarCache.cache.reset()
    }
}

/// Wraps an `NSCalendar` with more Swift-like `Calendar` API. See also: `_NSSwiftCalendar`.
/// This is only used in the case where we have custom Objective-C subclasses of `NSCalendar`. It is assumed that the subclass is Sendable.
internal final class _NSCalendarSwiftWrapper: @unchecked Sendable {
    let _calendar: NSCalendar

    // MARK: -
    // MARK: Bridging

    internal init(adoptingReference reference: NSCalendar) {
        _calendar = reference
    }

    static func == (lhs: _NSCalendarSwiftWrapper, rhs: _NSCalendarSwiftWrapper) -> Bool {
        return lhs._calendar == rhs._calendar
    }

    func bridgeToObjectiveC() -> NSCalendar {
        return _calendar.copy() as! NSCalendar
    }

    // MARK: -
    //

    /// The identifier of the calendar.
    var identifier: Calendar.Identifier {
        return Calendar._fromNSCalendarIdentifier(_calendar.calendarIdentifier)!
    }

    /// The locale of the calendar.
    var locale: Locale? {
        get {
            _calendar.locale
        }
        set {
            _calendar.locale = newValue
        }
    }

    /// The time zone of the calendar.
    var timeZone: TimeZone {
        get {
            _calendar.timeZone
        }
        set {
            _calendar.timeZone = newValue
        }
    }

    /// The first weekday of the calendar.
    var firstWeekday: Int {
        get {
            _calendar.firstWeekday
        }
        set {
            _calendar.firstWeekday = newValue
        }
    }

    /// The number of minimum days in the first week.
    var minimumDaysInFirstWeek: Int {
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
        return Range(_calendar.minimumRange(of: _toNSCalendarUnit([component])))
    }

    /// The maximum range limits of the values that a given component can take on in the receive
    ///
    /// As an example, in the Gregorian calendar the maximum range of values for the Day component is 1-31.
    /// - parameter component: A component to calculate a range for.
    /// - returns: The range, or nil if it could not be calculated.
    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        return Range(_calendar.maximumRange(of: _toNSCalendarUnit([component])))
    }


    /// Returns the range of absolute time values that a smaller calendar component (such as a day) can take on in a larger calendar component (such as a month) that includes a specified absolute time.
    ///
    /// You can use this method to calculate, for example, the range the `day` component can take on in the `month` in which `date` lies.
    /// - parameter smaller: The smaller calendar component.
    /// - parameter larger: The larger calendar component.
    /// - parameter date: The absolute time for which the calculation is performed.
    /// - returns: The range of absolute time values smaller can take on in larger at the time specified by date. Returns `nil` if larger is not logically bigger than smaller in the calendar, or the given combination of components does not make sense (or is a computation which is undefined).
    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        return Range(_calendar.range(of: _toNSCalendarUnit([smaller]), in: _toNSCalendarUnit([larger]), for: date))
    }

    /// Returns the starting time and duration of a given calendar component that contains a given date.
    ///
    /// - parameter component: A calendar component.
    /// - parameter date: The specified date.
    /// - returns: A new `DateInterval` if the starting time and duration of a component could be calculated, otherwise `nil`.
    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        var interval: TimeInterval = 0
        var nsDate: NSDate? = NSDate(timeIntervalSinceReferenceDate: 0)
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
        return _calendar.date(byAdding: components, to: date, options: wrappingComponents ? [.wrapComponents] : [])
    }

    /// Returns a date created from the specified components.
    ///
    /// - parameter components: Used as input to the search algorithm for finding a corresponding date.
    /// - returns: A new `Date`, or nil if a date could not be found which matches the components.
    func date(from components: DateComponents) -> Date? {
        return _calendar.date(from: components)
    }

    /// Returns all the date components of a date, using the calendar time zone.
    ///
    /// - note: If you want "date information in a given time zone" in order to display it, you should use `DateFormatter` to format the date.
    /// - parameter date: The `Date` to use.
    /// - returns: The date components of the specified date.
    func dateComponents(_ components: Set<Calendar.Component>, from date: Date) -> DateComponents {
        return _calendar.components(_toNSCalendarUnit(components), from: date)
    }

    /// Returns all the date components of a date, as if in a given time zone (instead of the `Calendar` time zone).
    ///
    /// The time zone overrides the time zone of the `Calendar` for the purposes of this calculation.
    /// - note: If you want "date information in a given time zone" in order to display it, you should use `DateFormatter` to format the date.
    /// - parameter timeZone: The `TimeZone` to use.
    /// - parameter date: The `Date` to use.
    /// - returns: All components, calculated using the `Calendar` and `TimeZone`.
    func dateComponents(in timeZone: TimeZone, from date: Date) -> DateComponents {
        return _calendar.components(in: timeZone, from: date)
    }

    /// Returns the difference between two dates.
    ///
    /// - parameter components: Which components to compare.
    /// - parameter start: The starting date.
    /// - parameter end: The ending date.
    /// - returns: The result of calculating the difference from start to end.
    func dateComponents(_ components: Set<Calendar.Component>, from start: Date, to end: Date) -> DateComponents {
        return _calendar.components(_toNSCalendarUnit(components), from: start, to: end, options: [])
    }

    /// Returns `true` if the given date is within a weekend period, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within a weekend.
    func isDateInWeekend(_ date: Date) -> Bool {
        return _calendar.isDateInWeekend(date)
    }

    func nextWeekend(startingAfter date: Date, direction: Calendar.SearchDirection = .forward) -> DateInterval? {
        // The implementation actually overrides previousKeepSmaller and nextKeepSmaller with matchNext, always - but strict still trumps all.
        var nsDate: NSDate?
        var ti: TimeInterval = 0
        guard _calendar.nextWeekendStart(&nsDate, interval: &ti, options: direction == .backward ? [.searchBackwards] : [], after: date) else {
            return nil
        }
        /// WARNING: searching backwards is totally broken! 26643365
        return DateInterval(start: nsDate! as Date, duration: ti)
    }

    // MARK: -
    //

    func hash(into hasher: inout Hasher) {
        hasher.combine(_calendar)
    }

    func isEqual(to other: Any) -> Bool {
        if let other = other as? _NSCalendarSwiftWrapper {
            // NSCalendar's isEqual is broken (27019864) so we must implement this ourselves
            return identifier == other.identifier &&
            locale == other.locale &&
            timeZone == other.timeZone &&
            firstWeekday == other.firstWeekday &&
            minimumDaysInFirstWeek == other.minimumDaysInFirstWeek
        } else if let other = other as? _Calendar {
            return identifier == other.identifier &&
            locale == other.locale &&
            timeZone == other.timeZone &&
            firstWeekday == other.firstWeekday &&
            minimumDaysInFirstWeek == other.minimumDaysInFirstWeek
        } else {
            return false
        }
    }

}

// MARK: -

/// Wraps a Swift `struct Calendar` with an NSCalendar, so it can be used from Objective-C. The goal here is to forward as much of the meaningful implementation as possible to Swift.
@objc(_NSSwiftCalendar)
internal class _NSSwiftCalendar: _NSCalendarBridge {
    // NSCalendar is thread safe, so all access to its data is protected by this lock.
    let _lock: OSAllocatedUnfairLock<Calendar>

    // We can use the calendar (for non-mutating functions) after retrieving it from inside the lock because `struct Calendar` is itself thread safe. Once we have another copy of the inner pointer (by returning the struct from this closure), any mutation of the original struct will trigger a copy-on-write. The code which has the original one will continue on with the original value, which is fine.
    // Mutating operations still have to take the lock and operate on the state inside there, so we don't lose the new state after the mutation is complete.
    var calendar: Calendar {
        _lock.withLock { $0 }
    }

    override func copy(with zone: NSZone? = nil) -> Any {
        return _NSSwiftCalendar(calendar: calendar)!
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? _NSSwiftCalendar {
            return calendar == other.calendar
        } else if let other = object as? NSCalendar {
            return calendar == other as Calendar
        } else {
            return false
        }
    }

    override init?(checkedCalendarIdentifier ident: NSCalendar.Identifier) {
        guard let id = Calendar._fromNSCalendarIdentifier(ident) else {
            return nil
        }

        _lock = OSAllocatedUnfairLock(initialState: Calendar(identifier: id))
        // This does nothing in NSCalendarBridge, but we still need to call it
        super.init(checkedCalendarIdentifier: ident)
    }

    init!(calendar: Calendar) {
        _lock = OSAllocatedUnfairLock(initialState: calendar)
        // This does nothing in NSCalendarBridge, but we still need to call it
        super.init(checkedCalendarIdentifier: .gregorian)
    }
    
    // MARK: - Coding

    override var classForCoder: AnyClass {
        if calendar == Calendar.autoupdatingCurrent {
            return _NSAutoCalendar.self
        }
        return NSCalendar.self
    }
        
    override static var supportsSecureCoding: Bool { true }

    /// `NSCalendar`'s `+allocWithZone:` returns `_NSSwiftCalendar`, which results in the following implementation being called when initializing an instance from an archive.
    required init?(coder: NSCoder) {
        guard coder.allowsKeyedCoding else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Cannot be decoded without keyed coding"]))
            return nil
        }

        guard let encodedIdentifier = coder.decodeObject(of: NSString.self, forKey: "NS.identifier") as? String else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Identifier has been corrupted"]))
            return nil
        }

        guard let locale = coder.decodeObject(of: NSLocale.self, forKey: "NS.locale"), locale.isKind(of: NSLocale.self) else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Locale has been corrupted!"]))
            return nil
        }

        let encodedTimeZone = coder.decodeObject(of: NSTimeZone.self, forKey: "NS.timezone")
        let gregStartDate = coder.decodeObject(of: NSDate.self, forKey: "NS.gstartdate")
        let firstWeekday = coder.containsValue(forKey: "NS.firstwkdy") ? coder.decodeInteger(forKey: "NS.firstwkdy") : nil
        let minDays = coder.containsValue(forKey: "NS.mindays") ? coder.decodeInteger(forKey: "NS.mindays") : nil

        guard coder.error == nil else {
            return nil
        }

        guard let id = Calendar._fromNSCalendarIdentifier(.init(rawValue: encodedIdentifier)) else {
            coder.failWithError(CocoaError(CocoaError.coderReadCorrupt, userInfo: [NSDebugDescriptionErrorKey : "Unknown calendar identifier"]))
            return nil
        }

        let tz = encodedTimeZone as? TimeZone

        _lock = OSAllocatedUnfairLock(initialState: Calendar(identifier: id, locale: locale as Locale, timeZone: tz, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minDays, gregorianStartDate: gregStartDate as Date?))

        // This doesn't do anything in the abstract superclass, but we have to call it anyway.
        super.init(checkedCalendarIdentifier: .init(encodedIdentifier))
    }

    override func encode(with coder: NSCoder) {
        if calendar == Calendar.autoupdatingCurrent {
            // We used to encode locale, timeZone, gregorian start date, firstWeekday, and min days here if they were changed on the autocalendar. With our rewrite into Swift, changing these properties means that the calendar is not autoupdating at all anymore. If we don't end up keeping that behavior, then we need to encode those properties here (if customized) along with the fact that this was autoupdating.
            return
        }
        // We could implement this in Swift, but for now call up to ObjC superclass.
        super.encode(with: coder)
    }

    // MARK: -
    
    override var debugDescription: String {
        let inner = _lock.withLock { $0.debugDescription }
        return "\(super.debugDescription) \(inner)"
    }

    override var calendarIdentifier: NSCalendar.Identifier {
        Calendar._toNSCalendarIdentifier(calendar.identifier)
    }

    override var locale: Locale? {
        get {
            calendar.locale
        }
        set {
            _lock.withLock { $0.locale = newValue }
        }
    }

    override var timeZone: TimeZone? {
        get {
            calendar.timeZone
        }
        set {
            _lock.withLock { $0.timeZone = newValue ?? TimeZone.default }
        }
    }

    override var firstWeekday: Int {
        get {
            calendar.firstWeekday
        }
        set {
            _lock.withLock { $0.firstWeekday = newValue }
        }
    }

    override var minimumDaysInFirstWeek: Int {
        get {
            calendar.minimumDaysInFirstWeek
        }
        set {
            _lock.withLock { $0.minimumDaysInFirstWeek = newValue }
        }
    }

    override func minimumRange(of unit: NSCalendar.Unit) -> NSRange {
        guard let unit = _fromNSCalendarUnit(unit) else { return .notFound }
        return _toNSRange(calendar.minimumRange(of: unit))
    }

    override func maximumRange(of unit: NSCalendar.Unit) -> NSRange {
        guard let unit = _fromNSCalendarUnit(unit) else { return .notFound }
        return _toNSRange(calendar.maximumRange(of: unit))
    }

    override func range(of smaller: NSCalendar.Unit, in larger: NSCalendar.Unit, for date: Date) -> NSRange {
        guard let s = _fromNSCalendarUnit(smaller) else { return .notFound }
        guard let l = _fromNSCalendarUnit(larger) else { return .notFound }
        return _toNSRange(calendar.range(of: s, in: l, for: date))
    }

    override func ordinality(of smaller: NSCalendar.Unit, in larger: NSCalendar.Unit, for date: Date) -> Int {
        guard let s = _fromNSCalendarUnit(smaller) else { return NSNotFound }
        guard let l = _fromNSCalendarUnit(larger) else { return NSNotFound }
        return calendar.ordinality(of: s, in: l, for: date) ?? NSNotFound
    }

    override func range(of unit: NSCalendar.Unit, start datep: AutoreleasingUnsafeMutablePointer<NSDate?>?, interval tip: UnsafeMutablePointer<TimeInterval>?, for date: Date) -> Bool {
        guard let u = _fromNSCalendarUnit(unit) else { return false }
        guard let interval = calendar.dateInterval(of: u, for: date) else { return false }
        datep?.pointee = interval.start as NSDate
        tip?.pointee = interval.duration
        return true
    }

    @objc(_dateFromComponents:)
    override func _date(from comps: DateComponents) -> Date? {
        calendar.date(from: comps)
    }

    override func component(_ unit: NSCalendar.Unit, from date: Date) -> Int {
        guard let u = _fromNSCalendarUnit(unit) else { return NSNotFound }
        return calendar.component(u, from: date)
    }

    override func date(byAdding comps: DateComponents, to date: Date, options opts: NSCalendar.Options = []) -> Date? {
        let wrapping = opts.contains(.wrapComponents)
        return calendar.date(byAdding: comps, to: date, wrappingComponents: wrapping)
    }

    override func components(_ unitFlags: NSCalendar.Unit, from startingDate: Date, to resultDate: Date, options opts: NSCalendar.Options = []) -> DateComponents {
        let us = _fromNSCalendarUnits(unitFlags)
        // Options are unused
        var dc = calendar.dateComponents(us, from: startingDate, to: resultDate)
        if unitFlags.contains(.calendar) {
            dc.calendar = self as Calendar // turducken Calendar
        }

        // Compatibility for deprecated field
        if unitFlags.contains(.deprecatedWeekUnit) {
            dc._week = dc.weekOfYear
        }
        return dc
    }

    /// Special case to allow `nil` input to `-components:fromDate:` from ObjC. "Bridge" superclass implements `-components:fromDate:` and calls this method.
    override func _components(_ unitFlags: NSCalendar.Unit, from date: Date) -> DateComponents {
        let us = _fromNSCalendarUnits(unitFlags)
        var dc = calendar.dateComponents(us, from: date)
        if unitFlags.contains(.calendar) {
            dc.calendar = self as Calendar // turducken Calendar
        }


        // Compatibility for deprecated field
        if unitFlags.contains(.deprecatedWeekUnit) {
            dc._week = dc.weekOfYear
        }
        return dc
    }

    /// Special case to allow `nil` input to `-componentsInTimeZone:fromDate:` from ObjC. "Bridge" superclass implements `-componentsInTimeZone:fromDate:` and calls this method.
    override func _components(in timezone: TimeZone, from date: Date) -> DateComponents {
        var dc = calendar.dateComponents(in: timezone, from: date)
        dc.calendar = self as Calendar // turducken Calendar
        return dc
    }

    override func isDateInWeekend(_ date: Date) -> Bool {
        calendar.isDateInWeekend(date)
    }

    override func nextWeekendStart(_ datep: AutoreleasingUnsafeMutablePointer<NSDate?>?, interval tip: UnsafeMutablePointer<TimeInterval>?, options: NSCalendar.Options = [], after date: Date) -> Bool {
        let (_, _, direction) = _fromNSCalendarOptions(options)
        guard let interval = calendar.nextWeekend(startingAfter: date, direction: direction) else { return false }
        datep?.pointee = interval.start as NSDate
        tip?.pointee = interval.duration
        return true
    }

    override func _enumerateDatesStarting(after start: Date, matching comps: DateComponents, options opts: NSCalendar.Options = [], using block: (Date?, Bool, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(opts)
        calendar.enumerateDates(startingAfter: start, matching: comps, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction) { result, exactMatch, stop in
            let ptr = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 1)
            ptr.initialize(to: ObjCBool(false))
            block(result, exactMatch, ptr)
            if ptr.pointee.boolValue {
                stop = true
            }
            ptr.deinitialize(count: 1)
            ptr.deallocate()
        }
    }

    override func compare(_ date1: Date, to date2: Date, toUnitGranularity unit: NSCalendar.Unit) -> ComparisonResult {
        guard let us = _fromNSCalendarUnit(unit) else { return .orderedSame }
        return calendar.compare(date1, to: date2, toGranularity: us)
    }

    override func date(_ date: Date, matchesComponents components: DateComponents) -> Bool {
        calendar.date(date, matchesComponents: components)
    }

    override func components(_ unitFlags: NSCalendar.Unit, from: DateComponents, to: DateComponents, options: NSCalendar.Options) -> DateComponents {
        var dc = calendar.dateComponents(_fromNSCalendarUnits(unitFlags), from: from, to: to)
        // Compatibility for deprecated field
        if unitFlags.contains(.deprecatedWeekUnit) {
            dc._week = dc.weekOfYear
        }
        return dc
    }

    override func getEra(_ era: UnsafeMutablePointer<Int>?, year: UnsafeMutablePointer<Int>?, month: UnsafeMutablePointer<Int>?, day: UnsafeMutablePointer<Int>?, from date: Date) {
        let dc = calendar._dateComponents([.era, .year, .month, .day], from: date)
        era?.pointee = dc.era ?? 0
        year?.pointee = dc.year ?? 0
        month?.pointee = dc.month ?? 0
        day?.pointee = dc.day ?? 0
    }

    override func getEra(_ era: UnsafeMutablePointer<Int>?, yearForWeekOfYear: UnsafeMutablePointer<Int>?, weekOfYear: UnsafeMutablePointer<Int>?, weekday: UnsafeMutablePointer<Int>?, from date: Date) {
        let dc = calendar._dateComponents([.era, .yearForWeekOfYear, .weekOfYear, .weekday], from: date)
        era?.pointee = dc.era ?? 0
        yearForWeekOfYear?.pointee = dc.yearForWeekOfYear ?? 0
        weekOfYear?.pointee = dc.weekOfYear ?? 0
        weekday?.pointee = dc.weekday ?? 0
    }

    override func getHour(_ hour: UnsafeMutablePointer<Int>?, minute: UnsafeMutablePointer<Int>?, second: UnsafeMutablePointer<Int>?, nanosecond: UnsafeMutablePointer<Int>?, from date: Date) {
        let dc = calendar._dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        hour?.pointee = dc.hour ?? 0
        minute?.pointee = dc.minute ?? 0
        second?.pointee = dc.second ?? 0
        nanosecond?.pointee = dc.nanosecond ?? 0
    }

    override func range(ofWeekendStart start: AutoreleasingUnsafeMutablePointer<NSDate?>?, interval: UnsafeMutablePointer<TimeInterval>?, containing date: Date) -> Bool {
        var next: Date = .now
        var prev: Date = .now
        var nextTi: TimeInterval = 0
        var prevTi: TimeInterval = 0
        guard calendar.nextWeekend(startingAfter: date, start: &next, interval: &nextTi, direction: .forward) else {
            return false
        }

        guard calendar.nextWeekend(startingAfter: next, start: &prev, interval: &prevTi, direction: .backward) else {
            return false
        }

        guard prev <= date && date < prev + prevTi else {
            return false
        }

        start?.pointee = prev as NSDate
        interval?.pointee = prevTi
        return true
    }

    override func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    override func nextDate(after date: Date, matching components: DateComponents, options: NSCalendar.Options) -> Date? {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(options)
        return calendar.nextDate(after: date, matching: components, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }

    override func nextDate(after date: Date, matchingHour: Int, minute: Int, second: Int, options: NSCalendar.Options) -> Date? {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(options)
        let dc = DateComponents(hour: matchingHour, minute: minute, second: second)
        return calendar.nextDate(after: date, matching: dc, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }

    override func nextDate(after date: Date, matching unit: NSCalendar.Unit, value: Int, options: NSCalendar.Options) -> Date? {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(options)
        guard let us = _fromNSCalendarUnit(unit) else { return nil }
        var dc = DateComponents()
        dc.setValue(value, for: us)
        return calendar.nextDate(after: date, matching: dc, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }

    override func date(byAdding unit: NSCalendar.Unit, value: Int, to date: Date, options: NSCalendar.Options) -> Date? {
        guard let us = _fromNSCalendarUnit(unit) else { return nil }
        var dc = DateComponents()
        dc.setValue(value, for: us)
        return calendar.date(byAdding: dc, to: date, wrappingComponents: options.contains(.wrapComponents))
    }

    override func date(bySettingHour hour: Int, minute: Int, second: Int, of date: Date, options: NSCalendar.Options) -> Date? {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(options)
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: date, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }

    override func date(bySettingUnit unit: NSCalendar.Unit, value: Int, of date: Date, options: NSCalendar.Options) -> Date? {
        let (matchingPolicy, repeatedTimePolicy, direction) = _fromNSCalendarOptions(options)
        guard let us = _fromNSCalendarUnit(unit) else { return nil }
        let current = calendar.component(us, from: date)
        if current == value {
            return date
        }

        var target = DateComponents()
        target.setValue(value, for: us)
        var result: Date?
        calendar.enumerateDates(startingAfter: date, matching: target, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction) { date, exactMatch, stop in
            result = date
            stop = true
        }
        return result
    }

    override func date(era: Int, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, nanosecond: Int) -> Date? {
        let dc = DateComponents(era: era, year: year, month: month, day: day, hour: hour, minute: minute, second: second, nanosecond: nanosecond)
        return calendar.date(from: dc)
    }

    override func date(era: Int, yearForWeekOfYear: Int, weekOfYear: Int, weekday: Int, hour: Int, minute: Int, second: Int, nanosecond: Int) -> Date? {
        let dc = DateComponents(era: era, hour: hour, minute: minute, second: second, nanosecond: nanosecond, weekday: weekday, weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeekOfYear)
        return calendar.date(from: dc)
    }

    override func isDate(_ date: Date, equalTo otherDate: Date, toUnitGranularity unit: NSCalendar.Unit) -> Bool {
        guard let us = _fromNSCalendarUnit(unit) else { return false }
        return calendar.isDate(date, equalTo: otherDate, toGranularity: us)
    }

    override func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }

    override func isDateInToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    override func isDateInTomorrow(_ date: Date) -> Bool {
        calendar.isDateInTomorrow(date)
    }

    override func isDateInYesterday(_ date: Date) -> Bool {
        calendar.isDateInYesterday(date)
    }
}

// MARK: - Conversion Helpers

/// Turn our more-specific options into the big bucket option set of NSCalendar
private func _toCalendarOptions(matchingPolicy: Calendar.MatchingPolicy, repeatedTimePolicy: Calendar.RepeatedTimePolicy, direction: Calendar.SearchDirection) -> NSCalendar.Options {
    var result: NSCalendar.Options = []

    switch matchingPolicy {
    case .nextTime:
        result.insert(.matchNextTime)
    case .nextTimePreservingSmallerComponents:
        result.insert(.matchNextTimePreservingSmallerUnits)
    case .previousTimePreservingSmallerComponents:
        result.insert(.matchPreviousTimePreservingSmallerUnits)
    case .strict:
        result.insert(.matchStrictly)
    }

    switch repeatedTimePolicy {
    case .first:
        result.insert(.matchFirst)
    case .last:
        result.insert(.matchLast)
    }

    switch direction {
    case .backward:
        result.insert(.searchBackwards)
    case .forward:
        break
    }

    return result
}

private func _fromNSCalendarOptions(_ options: NSCalendar.Options) -> (matchingPolicy: Calendar.MatchingPolicy, repeatedTimePolicy: Calendar.RepeatedTimePolicy, direction: Calendar.SearchDirection) {

    let matchingPolicy: Calendar.MatchingPolicy
    let repeatedTimePolicy: Calendar.RepeatedTimePolicy
    let direction: Calendar.SearchDirection

    if options.contains(.matchNextTime) {
        matchingPolicy = .nextTime
    } else if options.contains(.matchNextTimePreservingSmallerUnits) {
        matchingPolicy = .nextTimePreservingSmallerComponents
    } else if options.contains(.matchPreviousTimePreservingSmallerUnits) {
        matchingPolicy = .previousTimePreservingSmallerComponents
    } else if options.contains(.matchStrictly) {
        matchingPolicy = .strict
    } else {
        // Default
        matchingPolicy = .nextTime
    }

    if options.contains(.matchFirst) {
        repeatedTimePolicy = .first
    } else if options.contains(.matchLast) {
        repeatedTimePolicy = .last
    } else {
        // Default
        repeatedTimePolicy = .first
    }

    if options.contains(.searchBackwards) {
        direction = .backward
    } else {
        direction = .forward
    }

    return (matchingPolicy, repeatedTimePolicy, direction)
}

// TODO: These conversion functions could probably be written in a much more efficient manner.

// Also used by Date+ComponentsFormatStyle
internal func _toNSCalendarUnit(_ components : Set<Calendar.Component>) -> NSCalendar.Unit {
    let componentMap : [Calendar.Component : NSCalendar.Unit] =
        [.era : .era,
         .year : .year,
         .month : .month,
         .day : .day,
         .hour : .hour,
         .minute : .minute,
         .second : .second,
         .weekday : .weekday,
         .weekdayOrdinal : .weekdayOrdinal,
         .quarter : .quarter,
         .weekOfMonth : .weekOfMonth,
         .weekOfYear : .weekOfYear,
         .yearForWeekOfYear : .yearForWeekOfYear,
         .nanosecond : .nanosecond,
         .calendar : .calendar,
         .timeZone : .timeZone]

    var result = NSCalendar.Unit()
    for u in components {
        result.insert(componentMap[u]!)
    }
    return result
}

private func _fromNSCalendarUnits(_ units: NSCalendar.Unit) -> Set<Calendar.Component> {
    var result = Set<Calendar.Component>()
    if units.contains(.era) { result.insert(.era) }
    if units.contains(.year) { result.insert(.year) }
    if units.contains(.month) { result.insert(.month) }
    if units.contains(.day) { result.insert(.day) }
    if units.contains(.hour) { result.insert(.hour) }
    if units.contains(.minute) { result.insert(.minute) }
    if units.contains(.second) { result.insert(.second) }
    if units.contains(.weekday) { result.insert(.weekday) }
    if units.contains(.weekdayOrdinal) { result.insert(.weekdayOrdinal) }
    if units.contains(.quarter) { result.insert(.quarter) }
    if units.contains(.weekOfMonth) { result.insert(.weekOfMonth) }
    if units.contains(.weekOfYear) { result.insert(.weekOfYear) }
    if units.contains(.yearForWeekOfYear) { result.insert(.yearForWeekOfYear) }
    if units.contains(.nanosecond) { result.insert(.nanosecond) }
    if units.contains(.calendar) { result.insert(.calendar) }
    if units.contains(.timeZone) { result.insert(.timeZone) }
    if units.contains(.deprecatedWeekUnit) { result.insert(.weekOfYear) }
    return result
}

private func _fromNSCalendarUnit(_ unit: NSCalendar.Unit) -> Calendar.Component? {
    switch unit {
    case .era: return .era
    case .year: return .year
    case .month: return .month
    case .day: return .day
    case .hour: return .hour
    case .minute: return .minute
    case .second: return .second
    case .weekday: return .weekday
    case .weekdayOrdinal: return .weekdayOrdinal
    case .quarter: return .quarter
    case .weekOfMonth: return .weekOfMonth
    case .weekOfYear: return .weekOfYear
    case .yearForWeekOfYear: return .yearForWeekOfYear
    case .nanosecond: return .nanosecond
    case .calendar: return .calendar
    case .timeZone: return .timeZone
    case .deprecatedWeekUnit: return .weekOfYear
    default:
        return nil
    }
}

private func _toNSRange(_ range: Range<Int>?) -> NSRange {
    if let r = range {
        return NSRange(location: r.lowerBound, length: r.upperBound - r.lowerBound)
    } else {
        return NSRange(location: NSNotFound, length: NSNotFound)
    }
}

extension NSRange {
    fileprivate static var notFound: NSRange { NSRange(location: NSNotFound, length: NSNotFound) }
}

#endif // FOUNDATION_FRAMEWORK

