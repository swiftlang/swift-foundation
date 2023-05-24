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

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(ucrt)
import ucrt
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _ForSwiftFoundation
@_implementationOnly import CoreFoundation_Private.CFNotificationCenter
#endif

/// Singleton which listens for notifications about preference changes for TimeZone and holds cached values for current, fixed time zones, etc.
struct TimeZoneCache : Sendable {
    struct State {
        // a.k.a. `systemTimeZone`
        private var currentTimeZone: TimeZone!

        // If this is not set, the behavior is to fall back to the current time zone
        private var defaultTimeZone: TimeZone?

        // This cache is not cleared, but only holds validly named time zones.
        private var fixedTimeZones: [String: TimeZone] = [:]

        // This cache holds offset-specified time zones, but only a subset of the universe of possible values. See the implementation below for the policy.
        private var offsetTimeZones: [Int: TimeZone] = [:]

        private var noteCount = -1
        private var identifiers: [String]?
        private var abbreviations: [String : String]?

#if FOUNDATION_FRAMEWORK
        // These are caches of the NSTimeZone subclasses for use from Objective-C (without allocating each time)
        private var bridgedCurrentTimeZone: _NSSwiftTimeZone!
        private var bridgedAutoupdatingCurrentTimeZone: _NSSwiftTimeZone!
        private var bridgedDefaultTimeZone: _NSSwiftTimeZone?
        private var bridgedFixedTimeZones: [String : _NSSwiftTimeZone] = [:]
        private var bridgedOffsetTimeZones: [Int : _NSSwiftTimeZone] = [:]
#endif // FOUNDATION_FRAMEWORK

        mutating func check() {
#if FOUNDATION_FRAMEWORK
            // On Darwin we listen for certain distributed notifications to reset the current TimeZone.
            let newNoteCount = _CFLocaleGetNoteCount() + _CFTimeZoneGetNoteCount() + Int(_CFCalendarGetMidnightNoteCount())
#else
            let newNoteCount = 1
#endif // FOUNDATION_FRAMEWORK

            if newNoteCount != noteCount {
                currentTimeZone = findCurrentTimeZone()
                noteCount = newNoteCount
#if FOUNDATION_FRAMEWORK
                bridgedCurrentTimeZone = _NSSwiftTimeZone(timeZone: currentTimeZone)
                _CFNotificationCenterInitializeDependentNotificationIfNecessary(CFNotificationName.cfTimeZoneSystemTimeZoneDidChange!.rawValue)
#endif // FOUNDATION_FRAMEWORK
            }
        }

        mutating func reset() -> TimeZone? {
            let oldTimeZone = currentTimeZone

            // Ensure we do not reuse the existing time zone
            noteCount = -1
            check()

            return oldTimeZone
        }

        /// Reads from environment variables `TZFILE`, `TZ` and finally the symlink pointed at by the C macro `TZDEFAULT` to figure out what the current (aka "system") time zone is.
        mutating func findCurrentTimeZone() -> TimeZone {
            if let tzenv = getenv("TZFILE") {
                if let name = String(utf8String: tzenv) {
                    if let result = fixed(name) {
                        return result
                    }
                }
            }

            if let tz = getenv("TZ") {
                if let name = String(utf8String: tz) {
                    // Try as an abbreviation first
                    // Use cached function here to avoid recursive lock
                    if let name2 = timeZoneAbbreviations()[name] {
                        if let result = fixed(name2) {
                            return result
                        }
                    }

                    // Try with just the name
                    if let result = fixed(name) {
                        return result
                    }
                }
            }

            let buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(PATH_MAX + 1))
            defer { buffer.deallocate() }
            buffer.initialize(repeating: 0)

            let ret = readlink(_TimeZone.TZDEFAULT, buffer.baseAddress!, Int(PATH_MAX))
            if ret >= 0 {
                // Null-terminate the value
                buffer[ret] = 0
                if let file = String(utf8String: buffer.baseAddress!) {
#if targetEnvironment(simulator) && (os(iOS) || os(tvOS) || os(watchOS))
                    let lookFor = "zoneinfo/"
#else
                    let lookFor = _TimeZone.TZDIR + "/"
#endif
                    if let rangeOfZoneInfo = file.range(of: lookFor) {
                        let name = file[rangeOfZoneInfo.upperBound...]
                        if let result = fixed(String(name)) {
                            return result
                        }
                    }
                }
            }

            // Last option as a default is the GMT value (again, using the cached version directly to avoid recursive lock)
            return offsetFixed(0)!
        }

        mutating func current() -> TimeZone {
            check()
            return currentTimeZone
        }

        mutating func `default`() -> TimeZone {
            check()
            if let manuallySetDefault = defaultTimeZone {
                return manuallySetDefault
            } else {
                return currentTimeZone
            }
        }

        mutating func setDefaultTimeZone(_ tz: TimeZone?) -> TimeZone? {
            // Ensure we are listening for notifications from here on out
            check()
            let old = defaultTimeZone
            defaultTimeZone = tz
#if FOUNDATION_FRAMEWORK
            if let tz {
                bridgedDefaultTimeZone = _NSSwiftTimeZone(timeZone: tz)
            } else {
                bridgedDefaultTimeZone = nil
            }
#endif // FOUNDATION_FRAMEWORK
            return old
        }

        mutating func fixed(_ identifier: String) -> TimeZone? {
            if let cached = fixedTimeZones[identifier] {
                return cached
            } else {
                if let innerTz = _TimeZone(identifier: identifier) {
                    let tz = TimeZone(fixed: innerTz)
                    fixedTimeZones[identifier] = tz
                    return tz
                } else {
                    return nil
                }
            }
        }

        mutating func offsetFixed(_ offset: Int) -> TimeZone? {
            if let cached = offsetTimeZones[offset] {
                return cached
            } else {
                // In order to avoid bloating a cache with weird time zones, only cache values that are 30min offsets (including 1hr offsets).
                let doCache = abs(offset) % 1800 == 0
                if let innerTz = _TimeZone(secondsFromGMT: offset) {
                    let tz = TimeZone(fixed: innerTz)
                    if doCache {
                        offsetTimeZones[offset] = tz
                    }
                    return tz
                } else {
                    return nil
                }
            }
        }

        mutating func knownTimeZoneIdentifiers() -> [String] {
            if identifiers == nil {
                identifiers = _TimeZone.timeZoneNamesFromICU()
            }
            return identifiers!
        }

        mutating func timeZoneAbbreviations() -> [String : String] {
            if abbreviations == nil {
                abbreviations = defaultAbbreviations
            }
            return abbreviations!
        }

        mutating func setTimeZoneAbbreviations(_ abbreviations: [String : String]) {
            self.abbreviations = abbreviations
        }

        let defaultAbbreviations: [String: String] = [
            "ADT":  "America/Halifax",
            "AKDT": "America/Juneau",
            "AKST": "America/Juneau",
            "ART":  "America/Argentina/Buenos_Aires",
            "AST":  "America/Halifax",
            "BDT":  "Asia/Dhaka",
            "BRST": "America/Sao_Paulo",
            "BRT":  "America/Sao_Paulo",
            "BST":  "Europe/London",
            "CAT":  "Africa/Harare",
            "CDT":  "America/Chicago",
            "CEST": "Europe/Paris",
            "CET":  "Europe/Paris",
            "CLST": "America/Santiago",
            "CLT":  "America/Santiago",
            "COT":  "America/Bogota",
            "CST":  "America/Chicago",
            "EAT":  "Africa/Addis_Ababa",
            "EDT":  "America/New_York",
            "EEST": "Europe/Athens",
            "EET":  "Europe/Athens",
            "EST":  "America/New_York",
            "GMT":  "GMT",
            "GST":  "Asia/Dubai",
            "HKT":  "Asia/Hong_Kong",
            "HST":  "Pacific/Honolulu",
            "ICT":  "Asia/Bangkok",
            "IRST": "Asia/Tehran",
            "IST":  "Asia/Kolkata",
            "JST":  "Asia/Tokyo",
            "KST":  "Asia/Seoul",
            "MDT":  "America/Denver",
            "MSD":  "Europe/Moscow",
            "MSK":  "Europe/Moscow",
            "MST":  "America/Phoenix",
            "NDT":  "America/St_Johns",
            "NST":  "America/St_Johns",
            "NZDT": "Pacific/Auckland",
            "NZST": "Pacific/Auckland",
            "PDT":  "America/Los_Angeles",
            "PET":  "America/Lima",
            "PHT":  "Asia/Manila",
            "PKT":  "Asia/Karachi",
            "PST":  "America/Los_Angeles",
            "SGT":  "Asia/Singapore",
            "TRT":  "Europe/Istanbul",
            "UTC":  "UTC",
            "WAT":  "Africa/Lagos",
            "WEST": "Europe/Lisbon",
            "WET":  "Europe/Lisbon",
            "WIT":  "Asia/Jakarta",
        ]

// MARK: - State Bridging
#if FOUNDATION_FRAMEWORK
        mutating func bridgedCurrent() -> _NSSwiftTimeZone {
            check()
            return bridgedCurrentTimeZone
        }

        mutating func bridgedAutoupdatingCurrent() -> _NSSwiftTimeZone {
            if let autoupdating = bridgedAutoupdatingCurrentTimeZone {
                return autoupdating
            } else {
                let result = _NSSwiftTimeZone(timeZone: TimeZone.autoupdatingCurrent)
                bridgedAutoupdatingCurrentTimeZone = result
                return result
            }
        }

        mutating func bridgedDefault() -> _NSSwiftTimeZone {
            check()
            if let manuallySetDefault = bridgedDefaultTimeZone {
                return manuallySetDefault
            } else {
                return bridgedCurrentTimeZone
            }
        }

        mutating func bridgedFixed(_ identifier: String) -> _NSSwiftTimeZone? {
            if let cached = bridgedFixedTimeZones[identifier] {
                return cached
            } else if let swiftCached = fixedTimeZones[identifier] {
                // If we don't have a bridged instance yet, check to see if we have a Swift one and re-use that
                let bridged = _NSSwiftTimeZone(timeZone: swiftCached)
                bridgedFixedTimeZones[identifier] = bridged
                return bridged
            } else if let innerTz = _TimeZone(identifier: identifier) {
                // In this case, the identifier is unique and we need to cache it (in two places)
                let tz = TimeZone(fixed: innerTz)
                fixedTimeZones[identifier] = tz
                let bridgedTz = _NSSwiftTimeZone(timeZone: tz)
                bridgedFixedTimeZones[identifier] = bridgedTz
                return bridgedTz
            } else {
                return nil
            }
        }

        mutating func bridgedOffsetFixed(_ offset: Int) -> _NSSwiftTimeZone? {
            if let cached = bridgedOffsetTimeZones[offset] {
                return cached
            } else if let swiftCached = offsetTimeZones[offset] {
                // If we don't have a bridged instance yet, check to see if we have a Swift one and re-use that
                let bridged = _NSSwiftTimeZone(timeZone: swiftCached)
                bridgedOffsetTimeZones[offset] = bridged
                return bridged
            } else if let innerTz = _TimeZone(secondsFromGMT: offset) {
                // In order to avoid bloating a cache with weird time zones, only cache values that are 30min offsets (including 1hr offsets).
                let doCache = abs(offset) % 1800 == 0

                // In this case, the offset is unique and we need to cache it (in two places)
                let tz = TimeZone(fixed: innerTz)
                let bridgedTz = _NSSwiftTimeZone(timeZone: tz)
                if doCache {
                    offsetTimeZones[offset] = tz
                    bridgedOffsetTimeZones[offset] = bridgedTz
                }
                return bridgedTz
            } else {
                return nil
            }
        }
#endif // FOUNDATION_FRAMEWORK
    }

    let lock: LockedState<State>

    static let cache = TimeZoneCache()

    fileprivate init() {
        lock = LockedState(initialState: State())
    }

    func reset() -> TimeZone? {
        return lock.withLock { $0.reset() }
    }

    var current: TimeZone {
        lock.withLock { $0.current() }
    }

    var `default`: TimeZone {
        lock.withLock { $0.default() }
    }

    func setDefault(_ tz: TimeZone?) {
        let oldDefaultTimeZone = lock.withLock {
            return $0.setDefaultTimeZone(tz)
        }

        CalendarCache.cache.reset()
#if FOUNDATION_FRAMEWORK
        if let oldDefaultTimeZone {
            let noteName = CFNotificationName(rawValue: "kCFTimeZoneSystemTimeZoneDidChangeNotification-2" as CFString)
            let oldAsNS = oldDefaultTimeZone as NSTimeZone
            let unmanaged = Unmanaged.passRetained(oldAsNS).autorelease()
            CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), noteName, unmanaged.toOpaque(), nil, true)
        }
#endif // FOUNDATION_FRAMEWORK
    }

    func fixed(_ identifier: String) -> TimeZone? {
        lock.withLock { $0.fixed(identifier) }
    }

    func offsetFixed(_ seconds: Int) -> TimeZone? {
        lock.withLock { $0.offsetFixed(seconds) }
    }

    func knownTimeZoneIdentifiers() -> [String] {
        lock.withLock { $0.knownTimeZoneIdentifiers() }
    }

    func timeZoneAbbreviations() -> [String : String] {
        lock.withLock { $0.timeZoneAbbreviations() }
    }

    func setTimeZoneAbbreviations(_ abbreviations: [String : String]) {
        lock.withLock { $0.setTimeZoneAbbreviations(abbreviations) }
    }

    // MARK: - Cache for bridged types
#if FOUNDATION_FRAMEWORK
    var bridgedCurrent: _NSSwiftTimeZone {
        lock.withLock { $0.bridgedCurrent() }
    }

    var bridgedAutoupdatingCurrent: _NSSwiftTimeZone {
        lock.withLock { $0.bridgedAutoupdatingCurrent() }
    }

    var bridgedDefault: _NSSwiftTimeZone {
        lock.withLock { $0.bridgedDefault() }
    }

    func bridgedFixed(_ identifier: String) -> _NSSwiftTimeZone? {
        lock.withLock { $0.bridgedFixed(identifier) }
    }

    func bridgedOffsetFixed(_ seconds: Int) -> _NSSwiftTimeZone? {
        lock.withLock { $0.bridgedOffsetFixed(seconds) }
    }
#endif // FOUNDATION_FRAMEWORK
}
