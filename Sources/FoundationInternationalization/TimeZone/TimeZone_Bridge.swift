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

/// Wraps an `NSTimeZone` with a more Swift-like `TimeZone` API.
/// This is only used in the case where we have a custom Objective-C subclass of `NSTimeZone`.
internal final class _TimeZoneBridged: _TimeZoneProtocol, @unchecked Sendable {
    init?(secondsFromGMT: Int) {
        fatalError("Unexpected init")
    }
    
    init?(identifier: String) {
        fatalError("Unexpected init")
    }
    
    let _timeZone: NSTimeZone

    // MARK: -
    // MARK: Bridging

    internal init(adoptingReference reference: NSTimeZone) {
        _timeZone = reference
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(_timeZone)
    }

    func isEqual(to other: Any) -> Bool {
        if let other = other as? _TimeZoneBridged {
            return _timeZone == other._timeZone
        } else {
            return false
        }
    }

    // MARK: -
    //

    var identifier: String {
        _timeZone.name
    }

    var data: Data {
        _timeZone.data
    }

    func secondsFromGMT(for date: Date) -> Int {
        _timeZone.secondsFromGMT(for: date)
    }

    func abbreviation(for date: Date) -> String? {
        _timeZone.abbreviation(for: date)
    }

    func isDaylightSavingTime(for date: Date) -> Bool {
        _timeZone.isDaylightSavingTime(for: date)
    }

    func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        _timeZone.daylightSavingTimeOffset(for: date)
    }

    func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        _timeZone.nextDaylightSavingTimeTransition(after: date)
    }

    func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        _timeZone.localizedName(style, locale: locale)
    }

    func rawAndDaylightSavingTimeOffset(for date: Date, repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, skippedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        (_timeZone.secondsFromGMT(for: date), _timeZone.daylightSavingTimeOffset(for: date))
    }

    func bridgeToNSTimeZone() -> NSTimeZone {
        _timeZone.copy() as! NSTimeZone
    }
}

#endif // FOUNDATION_FRAMEWORK
