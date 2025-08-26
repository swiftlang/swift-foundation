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
#endif

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
internal func _calendarICUClass() -> _CalendarProtocol.Type? {
    _CalendarICU.self
}
#else
dynamic package func _calendarICUClass() -> _CalendarProtocol.Type? {
    nil
}
#endif

func _calendarClass(identifier: Calendar.Identifier) -> _CalendarProtocol.Type? {
    if identifier == .gregorian || identifier == .iso8601 {
        return _CalendarGregorian.self
    } else {
        return _calendarICUClass()
    }
}

/// Singleton which listens for notifications about preference changes for Calendar and holds cached singletons for the current locale, calendar, and time zone.
struct CalendarCache : Sendable, ~Copyable {
    // MARK: - State
    
    static let cache = CalendarCache()
    
    // The values stored in these two locks do not depend upon each other, so it is safe to access them with separate locks. This helps avoids contention on a single lock.
    
    private let _current = LockedState<(any _CalendarProtocol)?>(initialState: nil)
    private let _fixed = LockedState<[Calendar.Identifier: any _CalendarProtocol]>(initialState: [:])
    
    fileprivate init() {
    }
    
    var current: any _CalendarProtocol {
        if let result = _current.withLock({ $0 }) {
            return result
        }
                        
        let id = Locale.current._calendarIdentifier
        // If we cannot create the right kind of class, we fail immediately here
        let calendarClass = _calendarClass(identifier: id)!
        let calendar = calendarClass.init(identifier: id, timeZone: nil, locale: Locale.current, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        
        return _current.withLock {
            if let current = $0 {
                // Someone beat us to setting it - use the existing one
                return current
            } else {
                $0 = calendar
                return calendar
            }
        }
    }
    
    func reset() {
        // rdar://102017659
        // Don't create `currentCalendar` here to avoid deadlocking when retrieving a fixed
        // calendar. Creating the current calendar gets the current locale, decodes a plist
        // from CFPreferences, and may call +[NSDate initialize] on a separate thread. This
        // leads to a deadlock if we are also initializing a class on the current thread
        _current.withLock { $0 = nil }
        _fixed.withLock { $0 = [:] }
    }
    
    // MARK: Singletons
    
    static let autoupdatingCurrent = _CalendarAutoupdating()
    
    // MARK: -
    
    func fixed(_ id: Calendar.Identifier) -> any _CalendarProtocol {
        if let existing = _fixed.withLock({ $0[id] }) {
            return existing
        }
        
        // If we cannot create the right kind of class, we fail immediately here
        let calendarClass = _calendarClass(identifier: id)!
        let new = calendarClass.init(identifier: id, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
        
        return _fixed.withLock {
            if let existing = $0[id] {
                return existing
            } else {
                $0[id] = new
                return new
            }
        }
    }
    
    func fixed(identifier: Calendar.Identifier, locale: Locale?, timeZone: TimeZone?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) -> any _CalendarProtocol {
        // Note: Only the ObjC NSCalendar initWithCoder supports gregorian start date values. For Swift it is always nil.
        // If we cannot create the right kind of class, we fail immediately here
        let calendarClass = _calendarClass(identifier: identifier)!
        return calendarClass.init(identifier: identifier, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

}
