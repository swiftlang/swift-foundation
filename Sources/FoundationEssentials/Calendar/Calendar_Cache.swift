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

/// Singleton which listens for notifications about preference changes for Calendar and holds cached singletons for the current locale, calendar, and time zone.
struct CalendarCache : Sendable {
    
    // MARK: - Concrete Classes
    
    // _CalendarICU, if present
    static func calendarICUClass(identifier: Calendar.Identifier, useGregorian: Bool) -> _CalendarProtocol.Type? {
#if FOUNDATION_FRAMEWORK && canImport(FoundationICU)
        if useGregorian && identifier == .gregorian {
            return _CalendarGregorian.self
        } else {
            return _CalendarICU.self
        }
#else
        if useGregorian && identifier == .gregorian {
            return _CalendarGregorian.self
        } else if let name = _typeByName("FoundationInternationalization._CalendarICU"), let t = name as? _CalendarProtocol.Type {
            return t
        } else {
            return nil
        }
#endif
    }

    // MARK: - State
    
    struct State : Sendable {
        // If nil, the calendar has been invalidated and will be created next time State.current() is called
        private var currentCalendar: (any _CalendarProtocol)?
        private var autoupdatingCurrentCalendar: _CalendarAutoupdating?
        private var fixedCalendars: [Calendar.Identifier: any _CalendarProtocol] = [:]

        private var noteCount = -1
        private var wasResetManually = false
                
        mutating func check() {
#if FOUNDATION_FRAMEWORK
            // On Darwin we listen for certain distributed notifications to reset the current Calendar.
            let newNoteCount = _CFLocaleGetNoteCount() + _CFTimeZoneGetNoteCount() + Int(_CFCalendarGetMidnightNoteCount())
#else
            let newNoteCount = 1
#endif
            if newNoteCount != noteCount || wasResetManually {
                // rdar://102017659
                // Don't create `currentCalendar` here to avoid deadlocking when retrieving a fixed
                // calendar. Creating the current calendar gets the current locale, decodes a plist
                // from CFPreferences, and may call +[NSDate initialize] on a separate thread. This
                // leads to a deadlock if we are also initializing a class on the current thread
                currentCalendar = nil
                fixedCalendars = [:]

                noteCount = newNoteCount
                wasResetManually = false
            }
        }

        mutating func current() -> any _CalendarProtocol {
            check()
            if let currentCalendar {
                return currentCalendar
            } else {
                let id = Locale.current._calendarIdentifier
                let useCalendarGregorianForGregorianCalendar = _foundation_essentials_feature_enabled()
                // If we cannot create the right kind of class, we fail immediately here
                let calendarClass = CalendarCache.calendarICUClass(identifier: id, useGregorian: useCalendarGregorianForGregorianCalendar)!
                let calendar = calendarClass.init(identifier: id, timeZone: nil, locale: Locale.current, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
                currentCalendar = calendar
                return calendar
            }
        }
        
        mutating func autoupdatingCurrent() -> any _CalendarProtocol {
            if let autoupdatingCurrentCalendar {
                return autoupdatingCurrentCalendar
            } else {
                let calendar = _CalendarAutoupdating()
                autoupdatingCurrentCalendar = calendar
                return calendar
            }
        }

        mutating func fixed(_ id: Calendar.Identifier) -> any _CalendarProtocol {
            check()
            if let cached = fixedCalendars[id] {
                return cached
            } else {
                let useCalendarGregorianForGregorianCalendar = _foundation_essentials_feature_enabled()
                // If we cannot create the right kind of class, we fail immediately here
                let calendarClass = CalendarCache.calendarICUClass(identifier: id, useGregorian: useCalendarGregorianForGregorianCalendar)!
                let new = calendarClass.init(identifier: id, timeZone: nil, locale: nil, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
                fixedCalendars[id] = new
                return new
            }
        }

        mutating func reset() {
            wasResetManually = true
        }
    }

    let lock: LockedState<State>

    static let cache = CalendarCache()

    fileprivate init() {
        lock = LockedState(initialState: State())
    }

    func reset() {
        lock.withLock { $0.reset() }
    }

    var current: any _CalendarProtocol {
        lock.withLock { $0.current() }
    }
    
    var autoupdatingCurrent: any _CalendarProtocol {
        lock.withLock { $0.autoupdatingCurrent() }
    }
    
    func fixed(_ id: Calendar.Identifier) -> any _CalendarProtocol {
        lock.withLock { $0.fixed(id) }
    }
    
    func fixed(identifier: Calendar.Identifier, locale: Locale?, timeZone: TimeZone?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) -> any _CalendarProtocol {
        // Note: Only the ObjC NSCalendar initWithCoder supports gregorian start date values. For Swift it is always nil.
        // If we cannot create the right kind of class, we fail immediately here
        let useCalendarGregorianForGregorianCalendar = _foundation_essentials_feature_enabled()
        let calendarClass = CalendarCache.calendarICUClass(identifier: identifier, useGregorian: useCalendarGregorianForGregorianCalendar)!
        return calendarClass.init(identifier: identifier, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

}
