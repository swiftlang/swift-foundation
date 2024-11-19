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
#elseif canImport(Android)
import unistd
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#endif

#if os(Windows)
import WinSDK
#endif

internal import _FoundationCShims

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import CoreFoundation_Private.CFNotificationCenter
#endif


#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
internal func _timeZoneICUClass() -> _TimeZoneProtocol.Type? {
    _TimeZoneICU.self
}
internal func _timeZoneGMTClass() -> _TimeZoneProtocol.Type {
    _TimeZoneGMTICU.self
}
#else
dynamic package func _timeZoneICUClass() -> _TimeZoneProtocol.Type? {
    nil
}
dynamic package func _timeZoneGMTClass() -> _TimeZoneProtocol.Type {
    _TimeZoneGMT.self
}
#endif

#if os(Windows)
dynamic package func _timeZoneIdentifier(forWindowsIdentifier windowsIdentifier: String) -> String? {
    nil
}
#endif

/// Singleton which listens for notifications about preference changes for TimeZone and holds cached values for current, fixed time zones, etc.
struct TimeZoneCache : Sendable, ~Copyable {
    // MARK: - State
    
    struct State {
        
        init() {
#if FOUNDATION_FRAMEWORK
            // On Darwin we listen for certain distributed notifications to reset the current TimeZone.
            _CFNotificationCenterInitializeDependentNotificationIfNecessary(CFNotificationName.cfTimeZoneSystemTimeZoneDidChange!.rawValue)
#endif
        }
        // a.k.a. `systemTimeZone`
        private var currentTimeZone: TimeZone?
        
        // If this is not set, the behavior is to fall back to the current time zone
        private var defaultTimeZone: TimeZone?

        // This cache is not cleared, but only holds validly named time zones.
        private var fixedTimeZones: [String: any _TimeZoneProtocol] = [:]

        // This cache holds offset-specified time zones, but only a subset of the universe of possible values. See the implementation below for the policy.
        private var offsetTimeZones: [Int: any _TimeZoneProtocol] = [:]

        private var identifiers: [String]?
        private var abbreviations: [String : String]?

#if FOUNDATION_FRAMEWORK
        // These are caches of the NSTimeZone subclasses for use from Objective-C (without allocating each time)
        private var bridgedCurrentTimeZone: _NSSwiftTimeZone?
        private var bridgedDefaultTimeZone: _NSSwiftTimeZone?
        private var bridgedFixedTimeZones: [String : _NSSwiftTimeZone] = [:]
        private var bridgedOffsetTimeZones: [Int : _NSSwiftTimeZone] = [:]
#endif // FOUNDATION_FRAMEWORK
        
        mutating func reset() -> TimeZone? {
            let oldTimeZone = currentTimeZone

            currentTimeZone = nil
#if FOUNDATION_FRAMEWORK
            bridgedCurrentTimeZone = nil
#endif
            return oldTimeZone
        }

        /// Reads from environment variables `TZFILE`, `TZ` and finally the symlink pointed at by the C macro `TZDEFAULT` to figure out what the current (aka "system") time zone is.
        mutating func findCurrentTimeZone() -> TimeZone {
#if !NO_TZFILE
            if let tzenv = ProcessInfo.processInfo.environment["TZFILE"], let result = fixed(tzenv) {
                return TimeZone(inner: result)
            }

            if let tz = ProcessInfo.processInfo.environment["TZ"] {
                // Try as an abbreviation first
                // Use cached function here to avoid recursive lock
                if let name = timeZoneAbbreviations()[tz], let result = fixed(name) {
                    return TimeZone(inner: result)
                }
                if let result = fixed(tz) {
                    return TimeZone(inner: result)
                }
            }

#if os(Windows)
            var timeZoneInfo = TIME_ZONE_INFORMATION()
            if GetTimeZoneInformation(&timeZoneInfo) != TIME_ZONE_ID_INVALID {
                let windowsName = withUnsafePointer(to: &(timeZoneInfo.StandardName)) {
                    $0.withMemoryRebound(to: WCHAR.self, capacity: 32) {
                        String(decoding: UnsafeBufferPointer(start: $0, count: wcslen($0)), as: UTF16.self)
                    }
                }
                if let identifier = _timeZoneIdentifier(forWindowsIdentifier: windowsName), let result = fixed(identifier) {
                    return TimeZone(inner: result)
                }
            }
#elseif os(WASI)
            // WASI doesn't provide a way to get the current timezone for now, so
            // just return the default GMT timezone.
#else
            let buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(PATH_MAX + 1))
            defer { buffer.deallocate() }
            buffer.initialize(repeating: 0)

            let ret = readlink(TZDEFAULT, buffer.baseAddress!, Int(PATH_MAX))
            if ret >= 0 {
                // Null-terminate the value
                buffer[ret] = 0
                if let file = String(validatingUTF8: buffer.baseAddress!) {
#if targetEnvironment(simulator) && (os(iOS) || os(tvOS) || os(watchOS))
                    let lookFor = "zoneinfo/"
#else
                    let lookFor: String
                    if let l = TZDIR.last, l == "/" {
                        lookFor = TZDIR
                    } else {
                        lookFor = TZDIR + "/"
                    }
#endif
                    if let rangeOfZoneInfo = file._range(of: lookFor, anchored: false, backwards: false) {
                        let name = file[rangeOfZoneInfo.upperBound...]
                        if let result = fixed(String(name)) {
                            return TimeZone(inner: result)
                        }
                    }
                }
            }
            
#if os(Linux) || os(Android)
            // Try localtime
            tzset()
            var t = time(nil)
            var lt : tm = tm()
            localtime_r(&t, &lt)

            if let name = String(validatingUTF8: lt.tm_zone) {
                if let result = fixed(name) {
                    return TimeZone(inner: result)
                }
            }
#endif

#endif
#endif //!NO_TZFILE
            // Last option as a default is the GMT value (again, using the cached version directly to avoid recursive lock)
            return TimeZone(inner: offsetFixed(0)!)
        }

        mutating func current() -> TimeZone {
            if let currentTimeZone {
                return currentTimeZone
            } else {
                let newCurrent = findCurrentTimeZone()
                currentTimeZone = newCurrent
                return newCurrent
            }
        }

        mutating func `default`() -> TimeZone {
            if let manuallySetDefault = defaultTimeZone {
                return manuallySetDefault
            } else {
                return current()
            }
        }

        mutating func setDefaultTimeZone(_ tz: TimeZone?) {
            defaultTimeZone = tz
#if FOUNDATION_FRAMEWORK
            if let tz {
                bridgedDefaultTimeZone = _NSSwiftTimeZone(timeZone: tz)
            } else {
                bridgedDefaultTimeZone = nil
            }
#endif // FOUNDATION_FRAMEWORK
        }
        
        mutating func fixed(_ identifier: String) -> (any _TimeZoneProtocol)? {
            // Check for GMT/UTC
            if identifier == "GMT" {
                return offsetFixed(0)
            } else if let cached = fixedTimeZones[identifier] {
                return cached
            } else {
                if let innerTz = _timeZoneICUClass()?.init(identifier: identifier) {
                    fixedTimeZones[identifier] = innerTz
                    return innerTz
                } else {
                    return nil
                }
            }
        }
        
        mutating func offsetFixed(_ offset: Int) -> (any _TimeZoneProtocol)? {
            if let cached = offsetTimeZones[offset] {
                return cached
            } else {
                // In order to avoid bloating a cache with weird time zones, only cache values that are 30min offsets (including 1hr offsets).
                let doCache = abs(offset) % 1800 == 0
                if let innerTz = _timeZoneGMTClass().init(secondsFromGMT: offset) {
                    if doCache {
                        offsetTimeZones[offset] = innerTz
                    }
                    return innerTz
                } else {
                    return nil
                }
            }
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
            if let bridgedCurrentTimeZone {
                return bridgedCurrentTimeZone
            } else {
                let newBridged = _NSSwiftTimeZone(timeZone: current())
                bridgedCurrentTimeZone = newBridged
                return newBridged
            }
        }

        mutating func bridgedDefault() -> _NSSwiftTimeZone {
            if let manuallySetDefault = bridgedDefaultTimeZone {
                return manuallySetDefault
            } else {
                return bridgedCurrent()
            }
        }

        mutating func bridgedFixed(_ identifier: String) -> _NSSwiftTimeZone? {
            if let cached = bridgedFixedTimeZones[identifier] {
                return cached
            }
            if let swiftCached = fixedTimeZones[identifier] {
                // If we don't have a bridged instance yet, check to see if we have a Swift one and re-use that
                let bridged = _NSSwiftTimeZone(timeZone: TimeZone(inner: swiftCached))
                bridgedFixedTimeZones[identifier] = bridged
                return bridged
            }
#if canImport(_FoundationICU)
            if let innerTz = _TimeZoneICU(identifier: identifier) {
                // In this case, the identifier is unique and we need to cache it (in two places)
                fixedTimeZones[identifier] = innerTz
                let bridgedTz = _NSSwiftTimeZone(timeZone: TimeZone(inner: innerTz))
                bridgedFixedTimeZones[identifier] = bridgedTz
                return bridgedTz
            }
#endif
            return nil
        }

        mutating func bridgedOffsetFixed(_ offset: Int) -> _NSSwiftTimeZone? {
            if let cached = bridgedOffsetTimeZones[offset] {
                return cached
            }
            if let swiftCached = offsetTimeZones[offset] {
                // If we don't have a bridged instance yet, check to see if we have a Swift one and re-use that
                let bridged = _NSSwiftTimeZone(timeZone: TimeZone(inner: swiftCached))
                bridgedOffsetTimeZones[offset] = bridged
                return bridged
            }
#if canImport(_FoundationICU)
            let maybeInnerTz = _TimeZoneGMTICU(secondsFromGMT: offset)
#else
            let maybeInnerTz = _TimeZoneGMT(secondsFromGMT: offset)
#endif
            if let innerTz = maybeInnerTz {
                // In order to avoid bloating a cache with weird time zones, only cache values that are 30min offsets (including 1hr offsets).
                let doCache = abs(offset) % 1800 == 0
                
                // In this case, the offset is unique and we need to cache it (in two places)
                let bridgedTz = _NSSwiftTimeZone(timeZone: TimeZone(inner: innerTz))
                if doCache {
                    offsetTimeZones[offset] = innerTz
                    bridgedOffsetTimeZones[offset] = bridgedTz
                }
                return bridgedTz
            }
            
            return nil
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
        lock.withLock { $0.setDefaultTimeZone(tz) }

        // Reset any 'current' locales, calendars, time zones
        LocaleNotifications.cache.reset()
    }

    func fixed(_ identifier: String) -> _TimeZoneProtocol? {
        lock.withLock { $0.fixed(identifier) }
    }

    func offsetFixed(_ seconds: Int) -> (any _TimeZoneProtocol)? {
        lock.withLock { $0.offsetFixed(seconds) }
    }
    
    private static let _autoupdatingCurrentCache = _TimeZoneAutoupdating()
    var autoupdatingCurrent: _TimeZoneAutoupdating {
        return Self._autoupdatingCurrentCache
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

    private static let _bridgedAutoupdatingCurrent = _NSSwiftTimeZone(timeZone: TimeZone(inner: TimeZoneCache.cache.autoupdatingCurrent))
    var bridgedAutoupdatingCurrent: _NSSwiftTimeZone {
        Self._bridgedAutoupdatingCurrent
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
