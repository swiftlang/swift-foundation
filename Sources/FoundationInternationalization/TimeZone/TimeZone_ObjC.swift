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

@objc
extension NSTimeZone {
    /// Called from `__NSPlaceholderTimeZone` to create an ObjC `NSTimeZone`.
    @objc
    static func _timeZoneWith(name: String, data: Data?) -> _NSSwiftTimeZone? {
        if let data {
            // We don't cache data-based TimeZones
            guard let tz = TimeZone(identifier: name) else {
                return nil
            }
            return _NSSwiftTimeZone(timeZone: tz, data: data)
        } else {
            return _timeZoneWith(name: name)
        }
    }

    /// Called from `__NSPlaceholderTimeZone` to create an ObjC `NSTimeZone`.
    @objc
    static func _timeZoneWith(name: String) -> _NSSwiftTimeZone? {
        TimeZoneCache.cache.bridgedFixed(name)
    }

    /// Called from `CFTimeZoneCreateWithTimeIntervalFromGMT`
    @objc
    static func _timeZoneWith(secondsFromGMT: Int) -> _NSSwiftTimeZone? {
        TimeZoneCache.cache.bridgedOffsetFixed(secondsFromGMT)
    }

    /// Called from `CFTimeZoneCreateWithName`
    @objc
    static func _timeZoneWith(name: String, tryAbbrev: Bool) -> _NSSwiftTimeZone? {
        if tryAbbrev {
            if let name2 = TimeZone.abbreviationDictionary[name] {
                return _timeZoneWith(name: name2)
            }
        }

        return _timeZoneWith(name: name)
    }

    /// In contrast to `tryAbbrev`, *only* accepts the abbreviation and GMT names.
    @objc
    static func _timeZoneWith(abbreviation: String) -> _NSSwiftTimeZone? {
        guard let id = TimeZone.identifierForAbbreviation(abbreviation) else {
            return nil
        }

        return TimeZoneCache.cache.bridgedFixed(id)
    }

    /// a.k.a. `NSLocalTimeZone`
    @objc
    static func _autoupdating() -> _NSSwiftTimeZone {
        TimeZoneCache.cache.bridgedAutoupdatingCurrent
    }

    @objc
    static func _current() -> _NSSwiftTimeZone {
        TimeZoneCache.cache.bridgedCurrent
    }

    @objc
    static func _default() -> _NSSwiftTimeZone {
        TimeZoneCache.cache.bridgedDefault
    }

    @objc
    static func _setDefaultTimeZone(_ timeZone: TimeZone?) {
        TimeZone.default = timeZone
    }

    @objc
    static func _resetSystemTimeZone() -> _NSSwiftTimeZone? {
        let oldTimeZone = TimeZone.resetSystemTimeZone()
        if let oldTimeZone {
            return _NSSwiftTimeZone(timeZone: oldTimeZone)
        } else {
            return nil
        }
    }

    @objc
    static func _abbreviationDictionary() -> [String: String] {
        TimeZoneCache.cache.timeZoneAbbreviations()
    }

    @objc
    static func _setAbbreviationDictionary(_ abbrev: [String: String]) {
        TimeZoneCache.cache.setTimeZoneAbbreviations(abbrev)
    }

    @objc
    static func _knownTimeZoneIdentifiers() -> [String] {
#if canImport(_FoundationICU)
        TimeZone.knownTimeZoneIdentifiers
#else
        []
#endif
    }

    @objc
    static func _timeZoneDataVersion() -> String {
#if canImport(_FoundationICU)
        TimeZone.timeZoneDataVersion
#else
        ""
#endif
    }
}

// MARK: -

/// Wraps a Swift `struct TimeZone` with an `NSTimeZone` so it can be used from Objective-C. The goal here is to forward as much of the meaningful implementation as possible to Swift.
@objc(_NSSwiftTimeZone)
final class _NSSwiftTimeZone: _NSTimeZoneBridge, @unchecked Sendable {
    var timeZone: TimeZone
    struct State {
        var data: Data?
    }

    let lock: LockedState<State>

    init(timeZone: TimeZone, data: Data? = nil) {
        self.timeZone = timeZone
        lock = LockedState(initialState: State(data: data))
        super.init()
    }
    
    // MARK: - Coding
    
    override var classForCoder: AnyClass {
        NSTimeZone.self
    }
    
    // Even though we do not expect init(coder:) to be called, we have to implement it per the DI rules - and if we implement it, we are required to override this method to prove that we support secure coding.
    override static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        // TODO: If we intend to implement this in Swift, we will need to remove the placeholder TimeZone in CoreFoundation
        fatalError("Only NSTimeZone should be encoded in an archive")
    }
    
    override func replacementObject(for archiver: NSKeyedArchiver) -> Any? {
        if timeZone == TimeZone.autoupdatingCurrent {
            return __NSLocalTimeZone()
        } else {
            return self
        }
    }

    // MARK: -

    override func encode(with coder: NSCoder) {
        // Rely on superclass implementation
        super.encode(with: coder)
    }

    override var name: String {
        timeZone.identifier
    }

    override var data: Data {
        let name = timeZone.identifier
        return lock.withLock {
            if let data = $0.data {
                return data
            }
            
            let data = TimeZone.dataFromTZFile(name)
            $0.data = data
            return data
        }
    }

    override func secondsFromGMT(for aDate: Date) -> Int {
        timeZone.secondsFromGMT(for: aDate)
    }

    override func abbreviation(for aDate: Date) -> String? {
        timeZone.abbreviation(for: aDate)
    }

    override func isDaylightSavingTime(for aDate: Date) -> Bool {
        timeZone.isDaylightSavingTime(for: aDate)
    }

    override func daylightSavingTimeOffset(for aDate: Date) -> TimeInterval {
        timeZone.daylightSavingTimeOffset(for: aDate)
    }

    override func nextDaylightSavingTimeTransition(after aDate: Date) -> Date? {
        timeZone.nextDaylightSavingTimeTransition(after: aDate)
    }

    override var secondsFromGMT: Int {
        timeZone.secondsFromGMT()
    }

    override var abbreviation: String? {
        timeZone.abbreviation()
    }

    override var isDaylightSavingTime: Bool {
        timeZone.isDaylightSavingTime()
    }

    override var daylightSavingTimeOffset: TimeInterval {
        timeZone.daylightSavingTimeOffset()
    }

    override var nextDaylightSavingTimeTransition: Date? {
        timeZone.nextDaylightSavingTimeTransition
    }

    override func localizedName(_ style: TimeZone.NameStyle, locale: Locale?) -> String? {
        timeZone.localizedName(for: style, locale: locale)
    }
}

#endif

