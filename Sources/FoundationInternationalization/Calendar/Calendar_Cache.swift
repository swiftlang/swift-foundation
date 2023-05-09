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

@_implementationOnly import FoundationICU

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _ForSwiftFoundation
import CoreFoundation
#endif

package import FoundationInternals

/// Singleton which listens for notifications about preference changes for Calendar and holds cached singletons for the current locale, calendar, and time zone.
struct CalendarCache : Sendable {
    struct State {
        // If nil, the calendar has been invalidated and will be created next time State.current() is called
        private var currentCalendar: _Calendar?
        private var fixedCalendars: [Calendar.Identifier: _Calendar] = [:]
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

        mutating func current() -> _Calendar {
            check()
            if let currentCalendar {
                return currentCalendar
            } else {
                let id = Locale.current._calendarIdentifier
                let calendar = _Calendar(identifier: id, locale: Locale.current)
                currentCalendar = calendar
                return calendar
            }
        }

        mutating func fixed(_ id: Calendar.Identifier) -> _Calendar {
            check()
            if let cached = fixedCalendars[id] {
                return cached
            } else {
                let new = _Calendar(identifier: id)
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

    var current: _Calendar {
        lock.withLock { $0.current() }
    }

    func fixed(_ id: Calendar.Identifier) -> _Calendar {
        lock.withLock { $0.fixed(id) }
    }
}
