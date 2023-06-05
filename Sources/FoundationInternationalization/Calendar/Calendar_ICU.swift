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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if canImport(Glibc)
import Glibc
#endif

#if canImport(CRT)
import CRT
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

internal final class _Calendar: Equatable, @unchecked Sendable {
    let lock: LockedState<Void>
    let identifier: Calendar.Identifier

    var ucalendar: UnsafeMutablePointer<UCalendar?>

    var _timeZone: TimeZone

    // These custom values take precedence over the locale values
    private var customFirstWeekday: Int?
    private var customMinimumFirstDaysInWeek: Int?

    // Identifier of any locale used
    private var localeIdentifier: String
    // Custom user preferences of any locale used (current locale or current locale imitation only). We need to store this to correctly rebuild a Locale that has been stored inside Calendar as an identifier.
    private var localePrefs: LocalePreferences?
    
    let customGregorianStartDate: Date?

    internal init(identifier: Calendar.Identifier,
                  timeZone: TimeZone? = nil,
                  locale: Locale? = nil,
                  firstWeekday: Int? = nil,
                  minimumDaysInFirstWeek: Int? = nil,
                  gregorianStartDate: Date? = nil)
    {
        self.identifier = identifier

        lock = LockedState<Void>()

        // We do not store the Locale here, as Locale stores a Calendar. We only keep the values we need that affect Calendar's operation.
        if let locale {
            localeIdentifier = locale.identifier
            localePrefs = locale.prefs
        } else {
            localeIdentifier = ""
            localePrefs = nil
        }
        _timeZone = timeZone ?? TimeZone.default

        customFirstWeekday = firstWeekday
        customMinimumFirstDaysInWeek = minimumDaysInFirstWeek
        customGregorianStartDate = gregorianStartDate
        
        ucalendar = Self.icuCalendar(identifier: identifier, timeZone: _timeZone, localeIdentifier: localeIdentifier, localePrefs: localePrefs, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: customGregorianStartDate)
    }

    static func icuCalendar(identifier: Calendar.Identifier,
                            timeZone: TimeZone,
                            localeIdentifier: String,
                            localePrefs: LocalePreferences?,
                            firstWeekday: Int?,
                            minimumDaysInFirstWeek: Int?,
                            gregorianStartDate: Date?) -> UnsafeMutablePointer<UCalendar?> {
        // TODO: I think this may be a waste; we always override the calendar, the rest is ignored
        var localeComponents = Locale.Components(identifier: localeIdentifier)
        localeComponents.calendar = identifier
        let calendarLocale = localeComponents.identifier

        let timeZoneIdentifier = Array(timeZone.identifier.utf16)
        var status = U_ZERO_ERROR
        let calendar = timeZoneIdentifier.withUnsafeBufferPointer {
            ucal_open($0.baseAddress, Int32($0.count), calendarLocale, UCAL_DEFAULT, &status)
        }

        guard let calendar, status.isSuccess else {
            fatalError("Unexpected failure creating calendar identifier \(localeIdentifier) \(identifier): \(status)")
        }

        if identifier == .gregorian {
            let gregorianChangeDate: Date
            let udate = ucal_getGregorianChange(calendar, &status)
            if status.isSuccess {
                gregorianChangeDate = Date(udate: udate)
            } else {
                gregorianChangeDate = Date(timeIntervalSinceReferenceDate: -13197600000.0)  // Oct 15, 1582
            }

            ucal_setGregorianChange(calendar, gregorianChangeDate.udate, &status)
        }

        if let firstWeekday {
            ucal_setAttribute(calendar, UCAL_FIRST_DAY_OF_WEEK, Int32(firstWeekday))
        } else if let forcedNumber = localePrefs?.firstWeekday?[identifier], let forced = Locale.Weekday(Int32(forcedNumber)) {
            // Make sure we don't have an off-by-one error here by using the ICU function. This could probably be simplified.
            ucal_setAttribute(calendar, UCAL_FIRST_DAY_OF_WEEK, Int32(forced.icuIndex))
        }

        if let minimumDaysInFirstWeek {
            ucal_setAttribute(calendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, Int32(truncatingIfNeeded: minimumDaysInFirstWeek))
        } else if let forced = localePrefs?.minDaysInFirstWeek?[identifier] {
            ucal_setAttribute(calendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, Int32(truncatingIfNeeded: forced))
        }

        return calendar
    }

    deinit {
        ucal_close(ucalendar)
    }

    // MARK: -

    func _locked_regenerate() {
        ucal_close(ucalendar)
        ucalendar = Self.icuCalendar(
            identifier: identifier,
            timeZone: _timeZone,
            localeIdentifier: localeIdentifier,
            localePrefs: localePrefs,
            firstWeekday: customFirstWeekday,
            minimumDaysInFirstWeek: customMinimumFirstDaysInWeek,
            gregorianStartDate: customGregorianStartDate)
    }

    var locale: Locale {
        get {
            return Locale(identifier: localeIdentifier, calendarIdentifier: identifier, prefs: localePrefs)
        }
        set {
            lock.withLock {
                localeIdentifier = newValue.identifier
                localePrefs = newValue.prefs
                _locked_regenerate()
            }
        }
    }

    var timeZone: TimeZone {
        get {
            _timeZone
        }
        set {
            lock.withLock {
                _timeZone = newValue
                _locked_regenerate()
            }
        }
    }

    var firstWeekday: Int {
        get {
            lock.withLock {
                _locked_firstWeekday
            }
        }
        set {
            lock.withLock {
                customFirstWeekday = newValue
                ucal_setAttribute(ucalendar, UCAL_FIRST_DAY_OF_WEEK, Int32(newValue))
            }
        }
    }

    private var _locked_firstWeekday: Int {
        customFirstWeekday ?? Int(ucal_getAttribute(ucalendar, UCAL_FIRST_DAY_OF_WEEK))
    }

    var minimumDaysInFirstWeek: Int {
        get {
            lock.withLock {
                _locked_minimumDaysInFirstWeek
            }
        }
        set {
            lock.withLock {
                customMinimumFirstDaysInWeek = newValue
                ucal_setAttribute(ucalendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, Int32(newValue))
            }
        }
    }

    private var _locked_minimumDaysInFirstWeek: Int {
        customMinimumFirstDaysInWeek ?? Int(ucal_getAttribute(ucalendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK))
    }

    // MARK: -

    func copy(changingLocale: Locale? = nil,
              changingTimeZone: TimeZone? = nil,
              changingFirstWeekday: Int? = nil,
              changingMinimumDaysInFirstWeek: Int? = nil) -> _Calendar {
        return lock.withLock {
            var newLocale = self.locale
            var newTimeZone = self.timeZone
            var newFirstWeekday: Int?
            var newMinDays: Int?

            if let changingLocale {
                newLocale = changingLocale
            }

            if let changingTimeZone {
                newTimeZone = changingTimeZone
            }

            if let changingFirstWeekday {
                newFirstWeekday = changingFirstWeekday
            } else if let customFirstWeekday {
                newFirstWeekday = customFirstWeekday
            } else {
                newFirstWeekday = nil
            }

            if let changingMinimumDaysInFirstWeek {
                newMinDays = changingMinimumDaysInFirstWeek
            } else if let customMinimumFirstDaysInWeek {
                newMinDays = customMinimumFirstDaysInWeek
            } else {
                newMinDays = nil
            }

            return _Calendar(identifier: identifier, timeZone: newTimeZone, locale: newLocale, firstWeekday: newFirstWeekday, minimumDaysInFirstWeek: newMinDays)
        }
    }

    static func ==(lhs: _Calendar, rhs: _Calendar) -> Bool {
        // n.b. this comparison doesn't take a lock on all the state for both calendars. If the firstWeekday, locale, timeZone et. al. change in the middle then we could get an inconsistent result. This is however the same race that could happen if the values of the properties changed after a lock was released and before the function returns.
        // For Locale, it's important to compare only the properties that affect the Calendar itself. That allows e.g. currentLocale (with an irrelevant pref about something like preferred metric unit) to compare equal to a different locale.
        return
            lhs.identifier == rhs.identifier &&
            lhs.timeZone == rhs.timeZone &&
            lhs.firstWeekday == rhs.firstWeekday &&
            lhs.minimumDaysInFirstWeek == rhs.minimumDaysInFirstWeek &&
            lhs.localeIdentifier == rhs.localeIdentifier &&
            lhs.localePrefs?.firstWeekday?[lhs.identifier] == rhs.localePrefs?.firstWeekday?[rhs.identifier] &&
            lhs.localePrefs?.minDaysInFirstWeek?[lhs.identifier] == rhs.localePrefs?.minDaysInFirstWeek?[rhs.identifier]
    }

    func hash(into hasher: inout Hasher) {
        lock.lock()
        hasher.combine(identifier)
        hasher.combine(timeZone)
        hasher.combine(_locked_firstWeekday)
        hasher.combine(_locked_minimumDaysInFirstWeek)
        hasher.combine(localeIdentifier)
        // It's important to include only properties that affect the Calendar itself. That allows e.g. currentLocale (with an irrelevant pref about something like preferred metric unit) to compare equal to a different locale.
        hasher.combine(localePrefs?.firstWeekday?[identifier])
        hasher.combine(localePrefs?.minDaysInFirstWeek?[identifier])
        lock.unlock()
    }

    // MARK: -

    /// Some components have really easy-to-calculate minimum ranges, others need to go to ICU.
    /// Returns nil if there is no easy answer.
    private func easyMinMaxRange(of component: Calendar.Component) -> Range<Int>? {
        switch component {
        case .hour:
            return 0..<24
        case .minute:
            return 0..<60
        case .second:
            return 0..<60
        case .nanosecond:
            // The legacy implementation returns the range `0..<1_000_000_000` for `range(of: .nanosecond, in: <anything>, for: <anything>), which doesn't really seem correct. Our implementation could probably return something for smaller combinations like nanosecond in second. A future ER would be to improve that, along with the rest of our nanosecond support.
            return 0..<1_000_000_000
        case .weekday:
            return 1..<8
        case .quarter:
            return 1..<5
        case .calendar, .timeZone:
            return nil
        case .era, .year, .month, .day, .weekdayOrdinal, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .isLeapMonth:
            return nil
        }
    }

    func minimumRange(of component: Calendar.Component) -> Range<Int>? {
        if let easy = easyMinMaxRange(of: component) {
            return easy
        }

        guard let fields = component.icuFieldCode else {
            return nil
        }

        return lock.withLock {
            var status = U_ZERO_ERROR
            let min = ucal_getLimit(ucalendar, fields, UCAL_GREATEST_MINIMUM, &status)
            guard status.isSuccess else { return nil }
            let max = ucal_getLimit(ucalendar, fields, UCAL_LEAST_MAXIMUM, &status)
            guard status.isSuccess else { return nil }

            // We add 1 to the values for month due to a difference in opinion about what 0 means
            if component == .month {
                return Int(min + 1)..<Int(max + 2)
            } else {
                return Int(min)..<Int(max + 1)
            }
        }
    }

    func maximumRange(of component: Calendar.Component) -> Range<Int>? {
        return lock.withLock {
            return _locked_maximumRange(of: component)
        }
    }

    private func _locked_maximumRange(of component: Calendar.Component) -> Range<Int>? {
        if let easy = easyMinMaxRange(of: component) {
            return easy
        }

        guard let fields = component.icuFieldCode else {
            return nil
        }

        var status = U_ZERO_ERROR
        let min = ucal_getLimit(ucalendar, fields, UCAL_MINIMUM, &status)
        guard status.isSuccess else { return nil }
        let max = ucal_getLimit(ucalendar, fields, UCAL_MAXIMUM, &status)
        guard status.isSuccess else { return nil }

        // We add 1 to the values for month due to a difference in opinion about what 0 means
        if component == .month {
            return Int(min + 1)..<Int(max + 2)
        } else {
            return Int(min)..<Int(max + 1)
        }
    }

    private func _locked_algorithmA(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = _locked_dateInterval(of: larger, at: at) else {
            return nil
        }

        guard let ord1 = _locked_ordinality(of: smaller, in: larger, for: interval.start + 0.1) else {
            return nil
        }

        guard let ord2 = _locked_ordinality(of: smaller, in: larger, for: interval.start + interval.duration - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            // Protect against an unexpected value from ICU for ord2
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    private func _locked_algorithmB(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = _locked_dateInterval(of: larger, at: at) else {
            return nil
        }

        var counter = 15 // stopgap in case something goes wrong
        let end = interval.start + interval.duration - 1.0
        var current = interval.start + 1.0

        var result: Range<Int>?
        repeat {
            guard let innerInterval = _locked_dateInterval(of: .month, at: current) else {
                return result
            }

            guard let ord1 = _locked_ordinality(of: smaller, in: .month, for: innerInterval.start + 0.1) else {
                return result
            }

            guard let ord2 = _locked_ordinality(of: smaller, in: .month, for: innerInterval.start + innerInterval.duration - 0.1) else {
                return result
            }

            if let lastResult = result {
                let mn = min(lastResult.first!, ord1)
                result = mn..<(mn + lastResult.count + ord2)
            } else if ord2 >= ord1 {
                result = ord1..<(ord2 + 1)
            } else {
                // Protect against an unexpected value from ICU for ord2
                return ord1..<ord1
            }

            counter -= 1
            current = innerInterval.start + innerInterval.duration + 1.0
        } while current < end && 0 < counter

        return result
    }

    private func _locked_algorithmC(smaller: Calendar.Component, larger: Calendar.Component, at: Date) -> Range<Int>? {
        guard let interval = _locked_dateInterval(of: larger, at: at) else {
            return nil
        }

        guard let ord1 = _locked_ordinality(of: smaller, in: .year, for: interval.start + 0.1) else {
            return nil
        }

        guard let ord2 = _locked_ordinality(of: smaller, in: .year, for: interval.start + interval.duration - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            // Protect against an unexpected value from ICU for ord2
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    private func _locked_algorithmD(at: Date) -> Range<Int>? {
        guard let weekInterval = _locked_dateInterval(of: .weekOfMonth, at: at) else {
            return nil
        }

        guard let monthInterval = _locked_dateInterval(of: .month, at: at) else {
            return nil
        }

        let start = weekInterval.start < monthInterval.start ? monthInterval.start : weekInterval.start
        let end = weekInterval.end < monthInterval.end ? weekInterval.end : monthInterval.end

        guard let ord1 = _locked_ordinality(of: .day, in: .month, for: start + 0.1) else {
            return nil
        }

        guard let ord2 = _locked_ordinality(of: .day, in: .month, for: end - 0.1) else {
            return nil
        }

        guard ord2 >= ord1 else {
            // Protect against an unexpected value from ICU for ord2
            return ord1..<ord1
        }

        return ord1..<(ord2 + 1)
    }

    func range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        return lock.withLock {
            return _locked_range(of: smaller, in: larger, for: date)
        }
    }

    func _locked_range(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Range<Int>? {
        let capped = date.capped

        if larger == .calendar || larger == .timeZone || larger == .weekdayOrdinal || larger == .nanosecond {
            return nil
        }

        switch smaller {
        case .weekday:
            switch larger {
            case .second, .minute, .hour, .day, .weekday:
                return nil
            default:
                return _locked_maximumRange(of: smaller)
            }
        case .hour:
            switch larger {
            case .second, .minute, .hour:
                return nil
            default:
                return _locked_maximumRange(of: smaller)
            }
        case .minute:
            switch larger {
            case .second, .minute:
                return nil
            default:
                return _locked_maximumRange(of: smaller)
            }
        case .second:
            switch larger {
            case .second:
                return nil
            default:
                return _locked_maximumRange(of: smaller)
            }
        case .nanosecond:
            return _locked_maximumRange(of: smaller)
        default:
            break // Continue search
        }

        switch larger {
        case .era:
            // assume it cycles through every possible combination in an era at least once; this is a little dodgy for the Japanese calendar but this calculation isn't terribly useful either
            switch smaller {
            case .year, .quarter, .month, .weekOfYear, .weekOfMonth, .day: /* kCFCalendarUnitWeek_Deprecated */
                return _locked_maximumRange(of: smaller)
            case .weekdayOrdinal:
                guard let r = _locked_maximumRange(of: .day) else { return nil }
                return 1..<(((r.lowerBound + (r.upperBound - r.lowerBound) - 1 + 6) / 7) + 1)
            default:
                break
            }
        case .year:
            switch smaller {
            case .quarter, .month, .weekOfYear: /* deprecated week */
                return _locked_algorithmA(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth, .day, .weekdayOrdinal:
                return _locked_algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .yearForWeekOfYear:
            switch smaller {
            case .quarter, .month, .weekOfYear: /* deprecated week */
                return _locked_algorithmA(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth:
                break
            case .day, .weekdayOrdinal:
                return _locked_algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .quarter:
            switch smaller {
            case .month, .weekOfYear: /* deprecated week */
                return _locked_algorithmC(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth, .day, .weekdayOrdinal:
                return _locked_algorithmB(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .month:
            switch smaller {
            case .weekOfYear: /* deprecated week */
                return _locked_algorithmC(smaller: smaller, larger: larger, at: capped)
            case .weekOfMonth, .day, .weekdayOrdinal:
                return _locked_algorithmA(smaller: smaller, larger: larger, at: capped)
            default:
                break
            }
        case .weekOfYear:
            break
        case .weekOfMonth: /* deprecated week */
            switch smaller {
            case .day:
                return _locked_algorithmD(at: capped)
            default:
                break
            }
        default:
            break
        }

        return nil
    }

    func ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        lock.withLock {
            _locked_ordinality(of: smaller, in: larger, for: date)
        }
    }

    func _locked_ordinality(of smaller: Calendar.Component, in larger: Calendar.Component, for date: Date) -> Int? {
        // The recursion in this function assumes the order of the unit is dependent upon the order of the higher unit before it.  For example, the ordinality of the week of the month is dependent upon the ordinality of the month in which it lies, and that month is dependent upon the ordinality of the year in which it lies, etc.

        switch larger {
        case .era:
            switch smaller {
            case .year:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                return Int(ucal_get(ucalendar, UCAL_YEAR, &status))
            case .yearForWeekOfYear:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                return Int(ucal_get(ucalendar, UCAL_YEAR_WOY, &status))
            case .quarter:
                guard let year = _locked_ordinality(of: .year, in: .era, for: date) else { return nil }
                guard let q = _locked_ordinality(of: .quarter, in: .year, for: date) else { return nil }
                let quarter = 4 * (year - 1) + q
                return quarter
            case .month:
                guard let start = _locked_start(of: .era, at: date) else { return nil }
                let dateUDate = date.udateInSeconds
                let startUDate = start.udateInSeconds
                var testUDate: UDate

                var month = 0
                if let r = _locked_maximumRange(of: .day) {
                    month = Int(floor(
                        (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                        86400.0 /
                        Double(r.count + 1) *
                        0.96875
                    ))
                    // low-ball the estimate
                    month = 10 < month ? month - 10 : 0
                    // low-ball the estimate further

                    repeat {
                        month += 1
                        var status = U_ZERO_ERROR
                        ucal_clear(ucalendar)
                        ucal_setMillis(ucalendar, startUDate, &status)
                        testUDate = _locked_add(UCAL_MONTH, amount: month, wrap: false, status: &status)
                    } while testUDate <= dateUDate
                }
                return month

            case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .era, at: date) else { return nil }
                let dateUDate = date.udateInSeconds
                var startUDate = start.udateInSeconds
                var testUDate: UDate

                var daysAdded = 0
                var status = U_ZERO_ERROR
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != _locked_firstWeekday {
                    // Mutate the calendar but don't use the result here
                    _ = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                    daysAdded += 1
                }

                startUDate += Double(daysAdded) * 86400.0 * 1000.0
                if _locked_minimumDaysInFirstWeek <= daysAdded {
                    // previous week chunk was big enough, count it
                    startUDate -= 7 * 86400.0 * 1000.0
                }

                var week = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0 /
                    7.0
                ))
                // low-ball the estimate
                week = 10 < week ? week - 109 : 0
                repeat {
                    week += 1
                    ucal_clear(ucalendar)
                    ucal_setMillis(ucalendar, startUDate, &status)
                    testUDate = _locked_add(UCAL_WEEK_OF_YEAR, amount: week, wrap: false, status: &status)
                } while testUDate <= dateUDate

                return week
            case .weekdayOrdinal, .weekday:
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .era, at: date) else { return nil }
                let dateUDate = date.udateInSeconds
                var startUDate = start.udateInSeconds
                var testUDate: UDate

                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, dateUDate, &status)
                let targetDoW = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, startUDate, &status)
                // move start forward to target day of week if not already there
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != targetDoW {
                    _ = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                    startUDate += 86400.0 * 1000.0
                }

                var nthWeekday = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0 /
                    7.0
                ))

                // Low-ball estimate
                nthWeekday = (10 < nthWeekday) ? nthWeekday - 10 : 0

                repeat {
                    nthWeekday += 1
                    status = U_ZERO_ERROR
                    ucal_clear(ucalendar)
                    ucal_setMillis(ucalendar, startUDate, &status)
                    testUDate = _locked_add(UCAL_WEEK_OF_YEAR, amount: nthWeekday, wrap: false, status: &status)
                } while testUDate < dateUDate

                return nthWeekday
            case .day:
                let start = _locked_start(of: .era, at: date)
                // Must do this to make sure things are set up for recursive calls to ordinality(of...)
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                guard let start else { return nil }
                let day = Int(floor(
                    (date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) /
                    86400.0
                )) + 1
                return day
            case .hour:
                guard let day = _locked_ordinality(of: .day, in: .era, for: date) else { return nil }
                if (Int.max - 24) / 24 < (day - 1) { return nil }
                var status = U_ZERO_ERROR
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                guard let hour = _locked_ordinality(of: .hour, in: .era, for: date) else { return nil }
                if (Int.max - 60) / 60 < (hour - 1) { return nil }
                var status = U_ZERO_ERROR
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                guard let minute = _locked_ordinality(of: .minute, in: .era, for: date) else { return nil }
                if (Int.max - 60) / 60 < (minute - 1) { return nil }
                var status = U_ZERO_ERROR
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            default:
                return nil
            }
        case .year:
            switch smaller {
            case .quarter:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let quarter = ucal_get(ucalendar, UCAL_MONTH, &status)
                if identifier == .hebrew {
                    let mquarter = [3, 3, 3, 4, 4, 4, 4, 1, 1, 1, 2, 2, 2]
                    return mquarter[Int(quarter)]
                } else {
                    let mquarter = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4]
                    return mquarter[Int(quarter)]
                }
            case .month:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                return Int(ucal_get(ucalendar, UCAL_MONTH, &status)) + 1
            case .weekOfMonth:
                return nil
            case .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let doy = Int(ucal_get(ucalendar, UCAL_DAY_OF_YEAR, &status))
                ucal_set(ucalendar, UCAL_DAY_OF_YEAR, 1)
                let fdDoW = Int(ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status))
                let ucalFirstWeekday = _locked_firstWeekday
                let ucalMinDaysInFirstWeek = _locked_minimumDaysInFirstWeek
                let week = (doy + 7 - ucalMinDaysInFirstWeek + (fdDoW + ucalMinDaysInFirstWeek - ucalFirstWeekday + 6) % 7) / 7
                status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                return week
            case .weekdayOrdinal, .weekday:
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .year, at: date) else { return nil }
                var status = U_ZERO_ERROR

                guard let dateWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: date) else { return nil }
                let targetDoW = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)

                status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                var udate = start.udateInSeconds
                ucal_setMillis(ucalendar, udate, &status)
                // move start forward to target day of week if not already there
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != targetDoW {
                    udate = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                }

                let newStart = Date(udate: udate)
                guard let startWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: newStart) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday
            case .day:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let day = Int(ucal_get(ucalendar, UCAL_DAY_OF_YEAR, &status))
                return day
            case .hour:
                var status = U_ZERO_ERROR
                guard let day = _locked_ordinality(of: .day, in: .year, for: date) else { return nil }
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .year, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .year, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .year, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .yearForWeekOfYear:
            switch smaller {
            case .quarter:
                return nil
            case .month:
                return nil
            case .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                return nil
            case .weekOfYear:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let week = Int(ucal_get(ucalendar, UCAL_WEEK_OF_YEAR, &status))
                guard status.isSuccess else { return nil }
                return week
            case .weekdayOrdinal, .weekday:
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .yearForWeekOfYear, at: date) else { return nil }
                var status = U_ZERO_ERROR
                let dateWeek = _locked_ordinality(of: .weekOfYear, in: .yearForWeekOfYear, for: date)
                let targetDoW = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)
                guard let dateWeek else { return nil }

                status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                var udate = start.udateInSeconds
                ucal_setMillis(ucalendar, udate, &status)
                // move start forward to target day of week if not already there
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != targetDoW {
                    udate = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                }
                guard let startWeek = _locked_ordinality(of: .weekOfYear, in: .yearForWeekOfYear, for: Date(udate: udate)) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday
            case .day:
                guard let start = _locked_start(of: .yearForWeekOfYear, at: date) else { return nil }
                let day = Int(floor((date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / 86400.0)) + 1
                return day
            case .hour:
                var status = U_ZERO_ERROR
                guard let day = _locked_ordinality(of: .day, in: .yearForWeekOfYear, for: date) else { return nil }
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .yearForWeekOfYear, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .yearForWeekOfYear, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .yearForWeekOfYear, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1


            default:
                return nil
            }
        case .quarter:
            switch smaller {
            case .month:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let month = Int(ucal_get(ucalendar, UCAL_MONTH, &status))
                if identifier == .hebrew {
                    let mcount = [1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 1, 2, 3]
                    return mcount[month]
                } else {
                    let mcount = [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 4]
                    return mcount[month]
                }
            case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .quarter, at: date) else { return nil }
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                var udate = start.udateInSeconds
                ucal_setMillis(ucalendar, udate, &status)
                // move start forward to first day of week if not already there
                var daysAdded = 0
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != _locked_firstWeekday {
                    udate = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                    daysAdded += 1
                }
                guard var startWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: Date(udate: udate)) else { return nil }
                if _locked_minimumDaysInFirstWeek <= daysAdded {
                    // previous week chunk was big enough, back up
                    startWeek -= 1
                }
                guard let dateWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: date) else { return nil }
                let week = dateWeek - startWeek + 1
                return week
            case .weekdayOrdinal, .weekday:
                // Do not use this combo for recursion
                guard let start = _locked_start(of: .quarter, at: date) else { return nil }
                var status = U_ZERO_ERROR
                let dateWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: date)
                let targetDoW = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)
                guard let dateWeek else { return nil }

                status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                var udate = start.udateInSeconds
                ucal_setMillis(ucalendar, udate, &status)
                // move start forward to target day of week if not already there
                while ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status) != targetDoW {
                    udate = _locked_add(UCAL_DAY_OF_MONTH, amount: 1, wrap: false, status: &status)
                }
                guard let startWeek = _locked_ordinality(of: .weekOfYear, in: .year, for: Date(udate: udate)) else { return nil }
                let nthWeekday = dateWeek - startWeek + 1
                return nthWeekday
            case .day:
                let start = _locked_start(of: .quarter, at: date)
                // must do this before returning to make sure things are set up for recursive calls to ordinality(of:...)
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                guard let start else { return nil }
                let day = Int(floor((date.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate) / 86400.0)) + 1
                return day
            case .hour:
                var status = U_ZERO_ERROR
                guard let day = _locked_ordinality(of: .day, in: .quarter, for: date) else { return nil }
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .quarter, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .quarter, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .quarter, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .month:
            switch smaller {
            case .weekOfYear:
                return nil
            case .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated */
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let week = Int(ucal_get(ucalendar, UCAL_WEEK_OF_MONTH, &status))
                return week
            case .day:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let day = Int(ucal_get(ucalendar, UCAL_DAY_OF_MONTH, &status))
                return day
            case .weekdayOrdinal, .weekday:
                guard let day = _locked_ordinality(of: .day, in: .month, for: date) else { return nil }
                let nthWeekday = (day + 6) / 7
                return nthWeekday
            case .hour:
                var status = U_ZERO_ERROR
                guard let day = _locked_ordinality(of: .day, in: .month, for: date) else { return nil }
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .month, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .month, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .month, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .weekOfYear, .weekOfMonth: /* kCFCalendarUnitWeek_Deprecated  */
            switch smaller {
            case .day, .weekday:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let day = Int(ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)) + 1 - _locked_firstWeekday
                if day <= 0 {
                    return day + 7
                } else {
                    return day
                }
            case .hour:
                var status = U_ZERO_ERROR
                guard let day = _locked_ordinality(of: .day, in: .weekOfYear, for: date) else { return nil }
                let hour = (day - 1) * 24 + Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .weekOfYear, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .weekOfYear, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .weekOfYear, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .weekday, .day:
            switch smaller {
            case .hour:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let hour = Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) + 1
                return hour
            case .minute:
                var status = U_ZERO_ERROR
                guard let hour = _locked_ordinality(of: .hour, in: .day, for: date) else { return nil }
                let minute = (hour - 1) * 60 + Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .day, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .day, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .hour:
            switch smaller {
            case .minute:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let minute = Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) + 1
                return minute
            case .second:
                var status = U_ZERO_ERROR
                guard let minute = _locked_ordinality(of: .minute, in: .hour, for: date) else { return nil }
                let second = (minute - 1) * 60 + Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .hour, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .minute:
            switch smaller {
            case .second:
                var status = U_ZERO_ERROR
                ucal_clear(ucalendar)
                ucal_setMillis(ucalendar, date.udateInSeconds, &status)
                let second = Int(ucal_get(ucalendar, UCAL_SECOND, &status)) + 1
                return second
            case .nanosecond:
                guard let second = _locked_ordinality(of: .second, in: .minute, for: date) else { return nil }
                let dseconds = (Double(second) - 1.0) + (date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate))
                return Int(dseconds * 1.0e9) + 1

            default:
                return nil
            }
        case .second:
            switch smaller {
            case .nanosecond:
                return Int(((date.timeIntervalSinceReferenceDate - floor(date.timeIntervalSinceReferenceDate)) * 1.0e9) + 1)

            default:
                return nil
            }
        case .nanosecond:
            return nil
        case .weekdayOrdinal:
            return nil

        default:
            return nil
        }

        // No return here to ensure we've covered all cases in switch statements above, even via `default`.
    }

    // MARK: - Date Interval Creation

    func dateInterval(of component: Calendar.Component, for date: Date) -> DateInterval? {
        lock.withLock {
            _locked_dateInterval(of: component, at: date)
        }
    }

    // MARK: - Weekends and Special Times

    func isDateInWeekend(_ date: Date) -> Bool {
        return lock.withLock {
            var status = U_ZERO_ERROR
            return ucal_isWeekend(ucalendar, date.udate, &status).boolValue
        }
    }

    func weekendRange() -> WeekendRange? {
        return lock.withLock { () -> WeekendRange? in
            var result = WeekendRange(start: 0, end: 0)

            var weekdaysIndex : [UInt32] = [0, 0, 0, 0, 0, 0, 0]
            weekdaysIndex[0] = UInt32(_locked_firstWeekday)
            for i in 1..<7 {
                weekdaysIndex[i] = (weekdaysIndex[i - 1] % 7) + 1
            }

            var weekdayTypes : [UCalendarWeekdayType] = [UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY]

            var onset: UInt32?
            var cease: UInt32?

            for i in 0..<7 {
                var status = U_ZERO_ERROR
                weekdayTypes[i] = ucal_getDayOfWeekType(ucalendar, UCalendarDaysOfWeek(CInt(weekdaysIndex[i])), &status)
                if weekdayTypes[i] == UCAL_WEEKEND_ONSET {
                    onset = weekdaysIndex[i]
                } else if weekdayTypes[i] == UCAL_WEEKEND_CEASE {
                    cease = weekdaysIndex[i]
                }
            }

            let hasWeekend = weekdayTypes.contains {
                $0 == UCAL_WEEKEND || $0 == UCAL_WEEKEND_ONSET || $0 == UCAL_WEEKEND_CEASE
            }

            guard hasWeekend else {
                return nil
            }

            if let onset {
                var status = U_ZERO_ERROR
                // onsetTime is milliseconds after midnight at which the weekend starts. Divide to get to TimeInterval (seconds)
                result.onsetTime = Double(ucal_getWeekendTransition(ucalendar, UCalendarDaysOfWeek(CInt(onset)), &status)) / 1000.0
            }

            if let cease {
                var status = U_ZERO_ERROR
                // onsetTime is milliseconds after midnight at which the weekend ends. Divide to get to TimeInterval (seconds)
                result.ceaseTime = Double(ucal_getWeekendTransition(ucalendar, UCalendarDaysOfWeek(CInt(cease)), &status)) / 1000.0
            }

            var weekendStart: UInt32?
            var weekendEnd: UInt32?

            if let onset {
                weekendStart = onset
            } else {
                if weekdayTypes[0] == UCAL_WEEKEND && weekdayTypes[6] == UCAL_WEEKEND {
                    for i in (0...5).reversed() {
                        if weekdayTypes[i] != UCAL_WEEKEND {
                            weekendStart = weekdaysIndex[i + 1]
                            break
                        }
                    }
                } else {
                    for i in 0..<7 {
                        if weekdayTypes[i] == UCAL_WEEKEND {
                            weekendStart = weekdaysIndex[i]
                            break
                        }
                    }
                }
            }

            if let cease {
                weekendEnd = cease
            } else {
                if weekdayTypes[0] == UCAL_WEEKEND && weekdayTypes[6] == UCAL_WEEKEND {
                    for i in 1..<7 {
                        if weekdayTypes[i] != UCAL_WEEKEND {
                            weekendEnd = weekdaysIndex[i - 1]
                            break
                        }
                    }
                } else {
                    for i in (0...6).reversed() {
                        if weekdayTypes[i] == UCAL_WEEKEND {
                            weekendEnd = weekdaysIndex[i]
                            break
                        }
                    }
                }
            }

            // There needs to be a start and end to have a next weekend
            guard let weekendStart, let weekendEnd else {
                return nil
            }

            result.start = Int(weekendStart)
            result.end = Int(weekendEnd)
            return result
        }
    }

    // MARK: - Date Creation / Matching Primitives

    func date(from components: DateComponents) -> Date? {
        // If the components specifies a new time zone, we need to copy ourselves and perform this calculation with the new `ucalendar` instance. timeZone is immutable.
        if let tz = components.timeZone {
            let withTz = copy(changingTimeZone: tz)

            // Clear the dc time zone or we'll recurse forever
            var dc = components
            dc.timeZone = nil
            return withTz.date(from: dc)
        }

        return lock.withLock {
            ucal_clear(ucalendar)
            ucal_set(ucalendar, UCAL_YEAR, 1)
            ucal_set(ucalendar, UCAL_MONTH, 0)
            ucal_set(ucalendar, UCAL_IS_LEAP_MONTH, 0)
            ucal_set(ucalendar, UCAL_DAY_OF_MONTH, 1)
            ucal_set(ucalendar, UCAL_HOUR_OF_DAY, 0)
            ucal_set(ucalendar, UCAL_MINUTE, 0)
            ucal_set(ucalendar, UCAL_SECOND, 0)
            ucal_set(ucalendar, UCAL_MILLISECOND, 0)

            var nanosecond = 0.0

            if let value = components.era { ucal_set(ucalendar, UCAL_ERA, Int32(truncatingIfNeeded: value)) }
            if let value = components.year { ucal_set(ucalendar, UCAL_YEAR, Int32(truncatingIfNeeded: value)) }
            // quarter is unsupported
            if let value = components.weekOfYear { ucal_set(ucalendar, UCAL_WEEK_OF_YEAR, Int32(truncatingIfNeeded: value)) }
            if let value = components.weekOfMonth { ucal_set(ucalendar, UCAL_WEEK_OF_MONTH, Int32(truncatingIfNeeded: value)) }
            if let value = components.yearForWeekOfYear { ucal_set(ucalendar, UCAL_YEAR_WOY, Int32(truncatingIfNeeded: value)) }
            if let value = components.weekday { ucal_set(ucalendar, UCAL_DAY_OF_WEEK, Int32(truncatingIfNeeded: value)) }
            if let value = components.weekdayOrdinal { ucal_set(ucalendar, UCAL_DAY_OF_WEEK_IN_MONTH, Int32(truncatingIfNeeded: value)) }
            // DateComponents month field is +1 from ICU
            if let value = components.month { ucal_set(ucalendar, UCAL_MONTH, Int32(truncatingIfNeeded: value - 1)) }
            if let value = components.day { ucal_set(ucalendar, UCAL_DAY_OF_MONTH, Int32(truncatingIfNeeded: value)) }
            if let value = components.hour { ucal_set(ucalendar, UCAL_HOUR_OF_DAY, Int32(truncatingIfNeeded: value)) }
            if let value = components.minute { ucal_set(ucalendar, UCAL_MINUTE, Int32(truncatingIfNeeded: value)) }
            if let value = components.second { ucal_set(ucalendar, UCAL_SECOND, Int32(truncatingIfNeeded: value)) }
            if let value = components.nanosecond { nanosecond = Double(value) }
            if let isLeap = components.isLeapMonth, isLeap { ucal_set(ucalendar, UCAL_IS_LEAP_MONTH, 1) }

            var status = U_ZERO_ERROR
            let udate = ucal_getMillis(ucalendar, &status)
            var date = Date(udate: udate) + nanosecond * 1.0e-9
            if let tzInterval = _locked_timeZoneTransitionInterval(at: date) {
                // Adjust the date backwards to account for the duration of the time zone transition
                date = date - tzInterval.duration
            }

            guard status.isSuccess else {
                return nil
            }

            return date
        }
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date, in timeZone: TimeZone) -> DateComponents {
        if self.timeZone != timeZone {
            // Make a copy of ourselves with the new time zone set
            let withTz = copy(changingTimeZone: timeZone)
            return withTz.dateComponents(components, from: date)
        } else {
            return dateComponents(components, from: date)
        }
    }

    func dateComponents(_ components: Calendar.ComponentSet, from date: Date) -> DateComponents {
        return lock.withLock {
            let capped = date.capped
            var status = U_ZERO_ERROR
            ucal_clear(ucalendar)
            ucal_setMillis(ucalendar, capped.udateInSeconds, &status)

            var dc = DateComponents()
            if components.contains(.era) { dc.era = Int(ucal_get(ucalendar, UCAL_ERA, &status)) }
            if components.contains(.year) { dc.year = Int(ucal_get(ucalendar, UCAL_YEAR, &status)) }
            // unsupported, always filled out to 0
            if components.contains(.quarter) { dc.quarter = 0 }
            // ICU's Month is -1 from DateComponents
            if components.contains(.month) { dc.month = Int(ucal_get(ucalendar, UCAL_MONTH, &status)) + 1 }
            if components.contains(.day) { dc.day = Int(ucal_get(ucalendar, UCAL_DAY_OF_MONTH, &status)) }
            if components.contains(.weekOfYear) { dc.weekOfYear = Int(ucal_get(ucalendar, UCAL_WEEK_OF_YEAR, &status)) }
            if components.contains(.weekOfMonth) { dc.weekOfMonth = Int(ucal_get(ucalendar, UCAL_WEEK_OF_MONTH, &status)) }
            if components.contains(.yearForWeekOfYear) { dc.yearForWeekOfYear = Int(ucal_get(ucalendar, UCAL_YEAR_WOY, &status)) }
            if components.contains(.weekday) { dc.weekday = Int(ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)) }
            if components.contains(.weekdayOrdinal) { dc.weekdayOrdinal = Int(ucal_get(ucalendar, UCAL_DAY_OF_WEEK_IN_MONTH, &status)) }
            if components.contains(.hour) { dc.hour = Int(ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)) }
            if components.contains(.minute) { dc.minute = Int(ucal_get(ucalendar, UCAL_MINUTE, &status)) }
            if components.contains(.second) { dc.second = Int(ucal_get(ucalendar, UCAL_SECOND, &status)) }
            if components.contains(.nanosecond) { dc.nanosecond = Int((capped.timeIntervalSinceReferenceDate - floor(capped.timeIntervalSinceReferenceDate)) * 1.0e+9) }

            // TODO: See if we can exclude this for calendars which do not use leap month
            if components.contains(.isLeapMonth) || components.contains(.month) {
                let result = ucal_get(ucalendar, UCAL_IS_LEAP_MONTH, &status)
                dc.isLeapMonth = result == 0 ? false : true
            }

            if components.contains(.timeZone) {
                dc.timeZone = timeZone
            }

            return dc
        }
    }

    // MARK: -

    func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool) -> Date? {
        return lock.withLock {
            let capped = date.capped

            var status = U_ZERO_ERROR
            ucal_clear(ucalendar)
            var (startingInt, startingFrac) = modf(capped.timeIntervalSinceReferenceDate)

            if startingFrac < 0 {
                // `modf` returns negative integral and fractional parts when `capped.timeIntervalSinceReferenceDate` is negative. In this case, we would wrongly turn the time backwards by adding the negative fractional part back after we're done with wrapping in `add` below. To avoid this, ensure that `startingFrac` is always positive: subseconds do not contribute to the wrapping of a second, so they should always be additive to the time ahead.
                startingFrac += 1.0
                startingInt -= 1.0
            }

            ucal_setMillis(ucalendar, Date(timeIntervalSinceReferenceDate: startingInt).udate, &status)
            var nanosecond = 0

            // No leap month support needed here, since these are quantities, not values
            if let amount = components.era { _ = _locked_add(UCAL_ERA, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.year { _ = _locked_add(UCAL_YEAR, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.yearForWeekOfYear { _ = _locked_add(UCAL_YEAR_WOY, amount: amount, wrap: wrappingComponents, status: &status) }
            // TODO: Support quarter
            // if let _ = components.quarter {  }
            if let amount = components.month { _ = _locked_add(UCAL_MONTH, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.day { _ = _locked_add(UCAL_DAY_OF_MONTH, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.weekOfYear { _ = _locked_add(UCAL_WEEK_OF_YEAR, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.weekOfMonth { _ = _locked_add(UCAL_WEEK_OF_MONTH, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.weekday { _ = _locked_add(UCAL_DAY_OF_WEEK, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.weekdayOrdinal { _ = _locked_add(UCAL_DAY_OF_WEEK_IN_MONTH, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.hour { _ = _locked_add(UCAL_HOUR_OF_DAY, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.minute { _ = _locked_add(UCAL_MINUTE, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.second { _ = _locked_add(UCAL_SECOND, amount: amount, wrap: wrappingComponents, status: &status) }
            if let amount = components.nanosecond { nanosecond = amount }

            let udate = ucal_getMillis(self.ucalendar, &status)
            if status.isSuccess {
                return Date(udate: udate) + startingFrac + (Double(nanosecond) * 1.0e-9)
            } else {
                return nil
            }
        }
    }

    func dateComponents(_ components: Calendar.ComponentSet, from start: Date, to end: Date) -> DateComponents {
        return lock.withLock {
            let cappedStart = start.capped
            let cappedEnd = end.capped

            var status = U_ZERO_ERROR
            ucal_clear(ucalendar)

            var curr = cappedStart.udate
            let currX = floor(curr)
            let diff = curr - currX
            curr = currX
            var goal = cappedEnd.udate
            goal -= diff

            ucal_setMillis(ucalendar, curr, &status)

            var dc = DateComponents()
            // No leap month support needed here, since these are quantities, not values

            if components.contains(.era) {
                // ICU refuses to do the subtraction, probably because we are at the limit of UCAL_ERA.  Use alternate strategy.
                curr = ucal_getMillis(ucalendar, &status)
                let currEra = ucal_get(ucalendar, UCAL_ERA, &status)
                ucal_setMillis(ucalendar, goal, &status)
                let goalEra = ucal_get(ucalendar, UCAL_ERA, &status)
                ucal_setMillis(ucalendar, curr, &status)
                ucal_set(ucalendar, UCAL_ERA, goalEra)
                dc.era = Int(goalEra - currEra)
            }
            if components.contains(.year) { dc.year = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_YEAR, &status)) }
            if components.contains(.yearForWeekOfYear) { dc.yearForWeekOfYear = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_YEAR_WOY, &status)) }
            if components.contains(.quarter) {
                // unsupported, always filled out to 0
                dc.quarter = 0
            }
            if components.contains(.month) { dc.month = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_MONTH, &status)) }
            if components.contains(.weekOfYear) { dc.weekOfYear = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_WEEK_OF_YEAR, &status)) }
            if components.contains(.weekOfMonth) { dc.weekOfMonth = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_WEEK_OF_MONTH, &status)) }
            if components.contains(.day) { dc.day = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_DAY_OF_MONTH, &status)) }
            if components.contains(.weekday) { dc.weekday = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_DAY_OF_WEEK, &status)) }
            if components.contains(.weekdayOrdinal) { dc.weekdayOrdinal = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_DAY_OF_WEEK_IN_MONTH, &status)) }
            if components.contains(.hour) { dc.hour = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_HOUR_OF_DAY, &status)) }
            if components.contains(.minute) { dc.minute = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_MINUTE, &status)) }
            if components.contains(.second) { dc.second = Int(ucal_getFieldDifference(ucalendar, goal, UCAL_SECOND, &status)) }
            if components.contains(.nanosecond) {
                let curr0 = ucal_getMillis(ucalendar, &status)
                let tmp = floor((goal - curr0) * 1.0e+6)
                if tmp < Double(Int32.max) {
                    dc.nanosecond = Int(tmp)
                } else {
                    dc.nanosecond = Int(Int32.max)
                }
            }

            return dc
        }
    }

    // MARK: - Helpers

    private func _locked_start(of unit: Calendar.Component, at: Date) -> Date? {
        // This shares some magic numbers with _locked_dateInterval, but the clarity at the call site of using only the start date vs needing the interval (plus the performance benefit of not calculating it if we don't need it) makes the duplication worth it.
        let capped = at.capped

        let inf_ti : TimeInterval = 4398046511104.0
        let time = capped.timeIntervalSinceReferenceDate

        var effectiveUnit = unit
        switch effectiveUnit {
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        case .era:
            switch identifier {
            case .gregorian, .iso8601:
                if time < -63113904000.0 {
                    return Date(timeIntervalSinceReferenceDate: -63113904000.0 - inf_ti)
                } else {
                    return Date(timeIntervalSinceReferenceDate: -63113904000.0)
                }
            case .republicOfChina:
                if time < -2808691200.0 {
                    return Date(timeIntervalSinceReferenceDate: -2808691200.0 - inf_ti)
                } else {
                    return Date(timeIntervalSinceReferenceDate: -2808691200.0)
                }
            case .coptic:
                if time < -54162518400.0 {
                    return Date(timeIntervalSinceReferenceDate: -54162518400.0 - inf_ti)
                } else {
                    return Date(timeIntervalSinceReferenceDate: -54162518400.0)
                }
            case .buddhist:
                if time < -80249875200.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -80249875200.0)
            case .islamic, .islamicTabular, .islamicUmmAlQura:
                if time < -43499980800.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -43499980800.0)
            case .islamicCivil:
                if time < -43499894400.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -43499894400.0)
            case .hebrew:
                if time < -181778083200.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -181778083200.0)
            case .persian:
                if time < -43510176000.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -43510176000.0)
            case .indian:
                if time < -60645542400.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -60645542400.0)
            case .ethiopicAmeteAlem:
                if time < -236439216000.0 { return nil }
                return Date(timeIntervalSinceReferenceDate: -236439216000.0)
            case .ethiopicAmeteMihret:
                if time < -236439216000.0 { return nil }
                if time < -62872416000.0 {
                    return Date(timeIntervalSinceReferenceDate: -236439216000.0)
                } else {
                    return Date(timeIntervalSinceReferenceDate: -62872416000.0)
                }
            case .japanese:
                if time < -42790982400.0 { return nil }
            case .chinese:
                if time < -146325744000.0 { return nil }
            }
        case .hour:
            let ti = Double(timeZone.secondsFromGMT(for: capped))
            var fixedTime = time + ti // compute local time
            fixedTime = floor(fixedTime / 3600.0) * 3600.0
            fixedTime = fixedTime - ti // compute GMT
            return Date(timeIntervalSinceReferenceDate: fixedTime)
        case .minute:
            return Date(timeIntervalSinceReferenceDate: floor(time / 60.0) * 60.0)
        case .second:
            return Date(timeIntervalSinceReferenceDate: floor(time))
        case .nanosecond:
            return Date(timeIntervalSinceReferenceDate: floor(time * 1.0e+9) * 1.0e-9)
        case .year, .yearForWeekOfYear, .quarter, .month, .day, .weekOfMonth, .weekOfYear:
            // Continue to below
            break
        case .weekdayOrdinal, .weekday:
            // Continue to below, after changing the unit
            effectiveUnit = .day
            break
        }

        // Set UCalendar to first instant of unit prior to 'at'
        _locked_setToFirstInstant(of: effectiveUnit, at: capped)

        var status = U_ZERO_ERROR
        let startUDate = ucal_getMillis(ucalendar, &status)
        return Date(udate: startUDate)
    }

    private func _locked_dateInterval(of unit: Calendar.Component, at: Date) -> DateInterval? {
        let capped = at.capped

        let inf_ti : TimeInterval = 4398046511104.0
        let time = capped.timeIntervalSinceReferenceDate

        var effectiveUnit = unit
        switch effectiveUnit {
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        case .era:
            switch identifier {
            case .gregorian, .iso8601:
                if time < -63113904000.0 {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -63113904000.0 - inf_ti), duration: inf_ti)
                } else {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -63113904000.0), duration: inf_ti)
                }
            case .republicOfChina:
                if time < -2808691200.0 {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -2808691200.0 - inf_ti), duration: inf_ti)
                } else {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -2808691200.0), duration: inf_ti)
                }
            case .coptic:
                if time < -54162518400.0 {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -54162518400.0 - inf_ti), duration: inf_ti)
                } else {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -54162518400.0), duration: inf_ti)
                }
            case .buddhist:
                if time < -80249875200.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -80249875200.0), duration: inf_ti)
            case .islamic, .islamicTabular, .islamicUmmAlQura:
                if time < -43499980800.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -43499980800.0), duration: inf_ti)
            case .islamicCivil:
                if time < -43499894400.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -43499894400.0), duration: inf_ti)
            case .hebrew:
                if time < -181778083200.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -181778083200.0), duration: inf_ti)
            case .persian:
                if time < -43510176000.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -43510176000.0), duration: inf_ti)
            case .indian:
                if time < -60645542400.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -60645542400.0), duration: inf_ti)
            case .ethiopicAmeteAlem:
                if time < -236439216000.0 { return nil }
                return DateInterval(start: Date(timeIntervalSinceReferenceDate: -236439216000.0), duration: inf_ti)
            case .ethiopicAmeteMihret:
                if time < -236439216000.0 { return nil }
                if time < -62872416000.0 {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -236439216000.0), duration: -62872416000.0 - -236439216000.0)
                } else {
                    return DateInterval(start: Date(timeIntervalSinceReferenceDate: -62872416000.0), duration: inf_ti)
                }
            case .japanese:
                if time < -42790982400.0 { return nil }
            case .chinese:
                if time < -146325744000.0 { return nil }
            }
        case .hour:
            let ti = Double(timeZone.secondsFromGMT(for: capped))
            var fixedTime = time + ti // compute local time
            fixedTime = floor(fixedTime / 3600.0) * 3600.0
            fixedTime = fixedTime - ti // compute GMT
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: fixedTime), duration: 3600.0)
        case .minute:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time / 60.0) * 60.0), duration: 60.0)
        case .second:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time)), duration: 1.0)
        case .nanosecond:
            return DateInterval(start: Date(timeIntervalSinceReferenceDate: floor(time * 1.0e+9) * 1.0e-9), duration: 1.0e-9)
        case .year, .yearForWeekOfYear, .quarter, .month, .day, .weekOfMonth, .weekOfYear:
            // Continue to below
            break
        case .weekdayOrdinal, .weekday:
            // Continue to below, after changing the unit
            effectiveUnit = .day
            break
        }

        // Set UCalendar to first instant of unit prior to 'at'
        _locked_setToFirstInstant(of: effectiveUnit, at: capped)

        var status = U_ZERO_ERROR
        let startUDate = ucal_getMillis(ucalendar, &status)
        let start = Date(udate: startUDate)

        switch effectiveUnit {
        case .era:
            ucal_add(ucalendar, UCAL_ERA, 1, &status)
            let newUDate = ucal_getMillis(ucalendar, &status)
            if newUDate == startUDate {
                // ICU refused to do the addition, probably because we are at the limit of UCAL_ERA.
                return DateInterval(start: start, duration: inf_ti)
            }

        case .year:
            ucal_add(ucalendar, UCAL_YEAR, 1, &status)

        case .yearForWeekOfYear:
            ucal_add(ucalendar, UCAL_YEAR_WOY, 1, &status)

        case .quarter:
            // TODO: adding 3 months and tacking any 13th month in the last quarter is not right for Hebrew
            ucal_add(ucalendar, UCAL_MONTH, 3, &status)
            let m = ucal_get(ucalendar, UCAL_MONTH, &status)
            if (m == 12) {
                // For calendars with 13 months
                ucal_add(ucalendar, UCAL_MONTH, 1, &status)
                // workaround ICU bug with Coptic, Ethiopic calendars
                let d = ucal_get(ucalendar, UCAL_DAY_OF_MONTH, &status)
                let d1 = ucal_getLimit(ucalendar, UCAL_DAY_OF_MONTH, UCAL_ACTUAL_MINIMUM, &status)
                if d != d1 {
                    ucal_set(ucalendar, UCAL_DAY_OF_MONTH, d1)
                }
            }

        case .month:
            ucal_add(ucalendar, UCAL_MONTH, 1, &status)

        case .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
            ucal_add(ucalendar, UCAL_WEEK_OF_YEAR, 1, &status)

        case .weekOfMonth:
            ucal_add(ucalendar, UCAL_WEEK_OF_MONTH, 1, &status)

        case .day:
            ucal_add(ucalendar, UCAL_DAY_OF_MONTH, 1, &status)

        default:
            break
        }

        // move back to 0h0m0s, in case the start of the unit wasn't at 0h0m0s
        ucal_set(ucalendar, UCAL_HOUR_OF_DAY, ucal_getLimit(ucalendar, UCAL_HOUR_OF_DAY, UCAL_ACTUAL_MINIMUM, &status))
        ucal_set(ucalendar, UCAL_MINUTE, ucal_getLimit(ucalendar, UCAL_MINUTE, UCAL_ACTUAL_MINIMUM, &status))
        ucal_set(ucalendar, UCAL_SECOND, ucal_getLimit(ucalendar, UCAL_SECOND, UCAL_ACTUAL_MINIMUM, &status))
        ucal_set(ucalendar, UCAL_MILLISECOND, 0)

        status = U_ZERO_ERROR;
        let end = Date(udate: ucal_getMillis(ucalendar, &status))
        if let tzTransition = _locked_timeZoneTransitionInterval(at: end) {
            return DateInterval(start: start, end: end - tzTransition.duration)
        } else if end > start {
            return DateInterval(start: start, end: end)
        } else {
            // Out of range
            return nil
        }
    }

    private func _locked_nextDaylightSavingTimeTransition(startingAt: Date, limit: Date) -> Date? {
        _TimeZone.nextDaylightSavingTimeTransition(forLocked: ucalendar, startingAt: startingAt, limit: limit)
    }

    private func _locked_timeZoneTransitionInterval(at date: Date) -> DateInterval? {
        // if the given time is before 1900, assume there is no dst transition yet
        if date.timeIntervalSinceReferenceDate < -3187299600.0 {
            return nil
        }

        // start back 48 hours
        let start = date - 48.0 * 60.0 * 60.0


        guard let nextDSTTransition = _locked_nextDaylightSavingTimeTransition(startingAt: start, limit: start + 4 * 8600 * 1000.0) else {
            return nil
        }

        // the transition must be at or before "date" if "date" is within the repeated time frame
        if nextDSTTransition > date {
            return nil
        }

        // gmt offset includes dst offset
        let preOffset = timeZone.secondsFromGMT(for: nextDSTTransition - 1.0)
        let nextOffset = timeZone.secondsFromGMT(for: nextDSTTransition + 1.0)
        let diff = preOffset - nextOffset

        // gmt offset before the transition > gmt offset after the transition => backward dst transition
        if diff > 0 && date >= nextDSTTransition && date < (nextDSTTransition + Double(diff)) {
            return DateInterval(start: nextDSTTransition, duration: Double(diff))
        }

        return nil
    }

    /// Set the calendar to the first instant of a particular component given a point in time. For example, the first instant of a day.
    private func _locked_setToFirstInstant(of unit: Calendar.Component, at: Date) {
        var status = U_ZERO_ERROR
        var udate = at.udateInSeconds
        ucal_setMillis(ucalendar, udate, &status)

        var targetEra: Int32?

        var startAtUnit = unit

        // For these units, we will adjust which unit to start at then proceed to second check
        switch startAtUnit {
        case .quarter:
            var month = ucal_get(ucalendar, UCAL_MONTH, &status)
            if identifier == .hebrew {
                let qmonth : [Int32] = [0, 0, 0, 3, 3, 3, 3, 7, 7, 7, 10, 10, 10]
                month = qmonth[Int(month)]
            } else {
                // A lunar leap month is considered to be in the same quarter that the base month number is in.
                let qmonth : [Int32] = [0, 0, 0, 3, 3, 3, 6, 6, 6, 9, 9, 9, 9]
                month = qmonth[Int(month)]
            }
            // TODO: if there is a lunar leap month of the same number *preceeding* month N, then we should set the calendar to the leap month, not the regular month.
            ucal_set(ucalendar, UCAL_MONTH, month)
            ucal_set(ucalendar, UCAL_IS_LEAP_MONTH, 0)

            startAtUnit = .month

        case .yearForWeekOfYear:
            ucal_set(ucalendar, UCAL_WEEK_OF_YEAR, ucal_getLimit(ucalendar, UCAL_WEEK_OF_YEAR, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .weekOfMonth, .weekOfYear: /* kCFCalendarUnitWeek_Deprecated */
            // reduce to first day of week, then reduce the rest of the day
            let goal = _locked_firstWeekday
            var dow = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)
            while dow != goal {
                ucal_add(ucalendar, UCAL_DAY_OF_MONTH, -3, &status)
                ucal_add(ucalendar, UCAL_DAY_OF_MONTH, 2, &status)
                dow = ucal_get(ucalendar, UCAL_DAY_OF_WEEK, &status)
            }

            startAtUnit = .day

        default:
            // Leave startAtUnit alone
            break
        }

        // largest to smallest, we set the fields to their minimum value
        switch startAtUnit {
        case .era:
            targetEra = ucal_get(ucalendar, UCAL_ERA, &status)
            ucal_set(ucalendar, UCAL_YEAR, ucal_getLimit(ucalendar, UCAL_YEAR, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .year:
            ucal_set(ucalendar, UCAL_MONTH, ucal_getLimit(ucalendar, UCAL_MONTH, UCAL_ACTUAL_MINIMUM, &status))
            ucal_set(ucalendar, UCAL_IS_LEAP_MONTH, 0)
            fallthrough

        case .month:
            ucal_set(ucalendar, UCAL_DAY_OF_MONTH, ucal_getLimit(ucalendar, UCAL_DAY_OF_MONTH, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .weekdayOrdinal, .weekday, .day:
            ucal_set(ucalendar, UCAL_HOUR_OF_DAY, ucal_getLimit(ucalendar, UCAL_HOUR_OF_DAY, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .hour:
            ucal_set(ucalendar, UCAL_MINUTE, ucal_getLimit(ucalendar, UCAL_MINUTE, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .minute:
            ucal_set(ucalendar, UCAL_SECOND, ucal_getLimit(ucalendar, UCAL_SECOND, UCAL_ACTUAL_MINIMUM, &status))
            fallthrough

        case .second:
            ucal_set(ucalendar, UCAL_MILLISECOND, 0)

        default:
            // do nothing extra
            break
        }

        if let targetEra, ucal_get(ucalendar, UCAL_ERA, &status) < targetEra {
            // In the Japanese calendar, and possibly others, eras don't necessarily start on the first day of a year, so the previous code may have backed up into the previous era, and we have to correct forward.

            var badUDate = ucal_getMillis(ucalendar, &status)
            ucal_add(ucalendar, UCAL_MONTH, 1, &status)
            while ucal_get(ucalendar, UCAL_ERA, &status) < targetEra {
                badUDate = ucal_getMillis(ucalendar, &status)
                ucal_add(ucalendar, UCAL_MONTH, 1, &status)
            }

            udate = ucal_getMillis(ucalendar, &status)

            // target date is between badUDate and udate. Do a search
            repeat {
                let testUDate = (udate + badUDate) / 2
                ucal_setMillis(ucalendar, testUDate, &status)
                if ucal_get(ucalendar, UCAL_ERA, &status) < targetEra {
                    badUDate = testUDate
                } else {
                    udate = testUDate
                }

                if fabs(udate - badUDate) < 1000 {
                    break
                }
            } while true

            repeat {
                // TODO: Double check C math trick here
                badUDate = floor((badUDate + 1000) / 1000) * 1000
                ucal_setMillis(ucalendar, badUDate, &status)
            } while ucal_get(ucalendar, UCAL_ERA, &status) < targetEra
        }

        if startAtUnit == .day || startAtUnit == .weekday || startAtUnit == .weekdayOrdinal {
            let targetDay = ucal_get(ucalendar, UCAL_DAY_OF_MONTH, &status)
            var currentDay = targetDay

            repeat {
                udate = ucal_getMillis(ucalendar, &status)
                ucal_add(ucalendar, UCAL_SECOND, -1, &status)
                currentDay = ucal_get(ucalendar, UCAL_DAY_OF_MONTH, &status)
            } while targetDay == currentDay
            ucal_setMillis(ucalendar, udate, &status)
        }

        udate = ucal_getMillis(ucalendar, &status)
        let start = Date(udate: udate)

        if let tzTransition = _locked_timeZoneTransitionInterval(at: start) {
            udate = (start - tzTransition.duration).udate
            ucal_setMillis(ucalendar, udate, &status)
        }
    }

    private func _locked_add(_ field: UCalendarDateFields, amount: Int, wrap: Bool, status: inout UErrorCode) -> UDate {
        // we rely on ICU to add and roll units which are larger than or equal to DAYs
        // we have an assumption which is we assume that there is no time zone with a backward repeated day
        // at the time of writing this code, there is only one instance of DST that forwards a day
        if field == UCAL_MILLISECOND || field == UCAL_SECOND || field == UCAL_MINUTE || field == UCAL_HOUR_OF_DAY || field == UCAL_HOUR || field == UCAL_MILLISECONDS_IN_DAY || field == UCAL_AM_PM {

            var unitLength = 0.0
            var keepHourInvariant = false
            var newAmount = Int32(truncatingIfNeeded: amount)
            switch field {
            case UCAL_MILLISECOND, UCAL_MILLISECONDS_IN_DAY:
                unitLength = 1.0
            case UCAL_MINUTE:
                unitLength = 60000.0
            case UCAL_SECOND:
                unitLength = 1000.0
            case UCAL_HOUR, UCAL_HOUR_OF_DAY:
                unitLength = 3600000.0
            case UCAL_AM_PM:
                unitLength = 3600000.0 * 12.0
                keepHourInvariant = true
            default:
                break
            }

            var leftoverTime = 0.0
            if wrap {
                let min = ucal_getLimit(ucalendar, field, UCAL_ACTUAL_MINIMUM, &status)
                let max = ucal_getLimit(ucalendar, field, UCAL_ACTUAL_MAXIMUM, &status)
                let gap = max - min + 1
                let originalValue = ucal_get(ucalendar, field, &status)
                var finalValue = originalValue + newAmount
                finalValue = (finalValue - min) % gap
                if finalValue < 0 {
                    finalValue += gap
                }
                finalValue += min
                if finalValue < originalValue && amount > 0 {
                    newAmount = finalValue
                    let at = Date(udate: ucal_getMillis(ucalendar, &status))
                    let largeField: Calendar.Component
                    switch field {
                    case UCAL_MILLISECOND, UCAL_MILLISECONDS_IN_DAY:
                        largeField = .second
                    case UCAL_SECOND:
                        largeField = .minute
                    case UCAL_MINUTE:
                        largeField = .hour
                    case UCAL_HOUR_OF_DAY, UCAL_HOUR:
                        largeField = .day
                    default:
                        // Just pick some value
                        largeField = .second
                    }

                    leftoverTime = totalSecondsInSmallUnits(field, status: &status)
                    _locked_setToFirstInstant(of: largeField, at: at)
                } else {
                    newAmount = finalValue - originalValue
                }
            }

            var dst: Int32 = 0
            var hour: Int32 = 0

            if keepHourInvariant {
                dst = ucal_get(ucalendar, UCAL_DST_OFFSET, &status) + ucal_get(ucalendar, UCAL_ZONE_OFFSET, &status)
                hour = ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status)
            }

            var result = ucal_getMillis(ucalendar, &status)
            result += Double(newAmount) * unitLength
            result += leftoverTime * 1000.0
            ucal_setMillis(ucalendar, result, &status)

            if keepHourInvariant {
                dst -= ucal_get(ucalendar, UCAL_DST_OFFSET, &status) + ucal_get(ucalendar, UCAL_ZONE_OFFSET, &status)
                if dst != 0 {
                    result = ucal_getMillis(ucalendar, &status) + Double(dst)
                    ucal_setMillis(ucalendar, result, &status)
                    if ucal_get(ucalendar, UCAL_HOUR_OF_DAY, &status) != hour {
                        result -= Double(dst)
                        ucal_setMillis(ucalendar, result, &status)
                    }
                }
            }

            return result
        } else {
            if wrap {
                ucal_roll(ucalendar, field, Int32(truncatingIfNeeded: amount), &status)
            } else {
                ucal_add(ucalendar, field, Int32(truncatingIfNeeded: amount), &status)
            }

            let result = ucal_getMillis(ucalendar, &status)
            let start = Date(udate: result)
            if amount > 0, let interval = _locked_timeZoneTransitionInterval(at: start) {
                let adjusted = (start - interval.duration).udate
                ucal_setMillis(ucalendar, adjusted, &status)
            }

            return result
        }
    }

    private func totalSecondsInSmallUnits(_ field: UCalendarDateFields, status: inout UErrorCode) -> Double {
        // assume field is within millisecond to hour
        var totalSecond = 0.0
        if field == UCAL_MILLISECOND || field == UCAL_MILLISECONDS_IN_DAY {
            return totalSecond
        }

        var value = Double(ucal_get(ucalendar, UCAL_MILLISECOND, &status))
        totalSecond += value / 1000.0

        if field == UCAL_SECOND {
            return totalSecond
        }

        value = Double(ucal_get(ucalendar, UCAL_SECOND, &status))
        totalSecond += value

        if field == UCAL_MINUTE {
            return totalSecond
        }

        value = Double(ucal_get(ucalendar, UCAL_MINUTE, &status))
        totalSecond += value * 60.0

        return totalSecond
    }
}

extension Date {
    // Julian day 0 (-4713-01-01 12:00:00 +0000) in CFAbsoluteTime to 50000-01-01 00:00:00 +0000, smaller than the max time ICU supported.
    internal static let validCalendarRange = Date(timeIntervalSinceReferenceDate: TimeInterval(-211845067200.0))...Date(timeIntervalSinceReferenceDate: TimeInterval(15927175497600.0))

    // aka __CFCalendarValidateAndCapTimeRange
    internal var capped: Date {
        return max(min(self, Date.validCalendarRange.upperBound), Date.validCalendarRange.lowerBound)
    }
}
