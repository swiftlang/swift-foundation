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

internal import _ForSwiftFoundation
import CoreFoundation
internal import os
internal import CoreFoundation_Private.CFLocale

extension NSCalendar.Unit {
    // Avoid the deprecation warning for .NSWeekCalendarUnit
    static let deprecatedWeekUnit: NSCalendar.Unit = NSCalendar.Unit(rawValue: (1 << 8))
}

@objc
extension NSCalendar {
    @objc
    static var _autoupdatingCurrent: NSCalendar {
        // Note: This is not cached, because NSCalendar has mutating properties and therefore we can't return a singleton.
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
        // Ensure _lock is populated first in case of a re-entrant call from the unarchiver.
        _lock = OSAllocatedUnfairLock(initialState: Calendar(identifier: .gregorian))

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

        // Reset the state with the correctly decoded Calendar instance
        _lock.withLock { state in
            state = Calendar(identifier: id, locale: locale as Locale, timeZone: tz, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minDays, gregorianStartDate: gregStartDate as Date?)
        }

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
    var result : NSCalendar.Options = []

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

private func _fromNSCalendarUnits(_ units : NSCalendar.Unit) -> Set<Calendar.Component> {
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
    if units.contains(.dayOfYear) { result.insert(.dayOfYear) }
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
    case .dayOfYear: return .dayOfYear
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

