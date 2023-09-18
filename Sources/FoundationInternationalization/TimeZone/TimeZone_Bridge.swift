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

/// Wraps an `NSTimeZone` with a more Swift-like `TimeZone` API.
/// This is only used in the case where we have a custom Objective-C subclass of `NSTimeZone`.
internal final class _TimeZoneBridged: _TimeZoneBase, @unchecked Sendable {
    let _timeZone: NSTimeZone

    // MARK: -
    // MARK: Bridging

    internal init(adoptingReference reference: NSTimeZone) {
        _timeZone = reference
    }

    override func hash(into hasher: inout Hasher) {
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

    override var identifier: String {
        _timeZone.name
    }

    override var data: Data {
        _timeZone.data
    }

    override func secondsFromGMT(for date: Date) -> Int {
        _timeZone.secondsFromGMT(for: date)
    }

    override func abbreviation(for date: Date) -> String? {
        _timeZone.abbreviation(for: date)
    }

    override func isDaylightSavingTime(for date: Date) -> Bool {
        _timeZone.isDaylightSavingTime(for: date)
    }

    override func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        _timeZone.daylightSavingTimeOffset(for: date)
    }

    override func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        _timeZone.nextDaylightSavingTimeTransition(after: date)
    }

    override func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        _timeZone.localizedName(style, locale: locale)
    }
    
    override func bridgeToNSTimeZone() -> NSTimeZone {
        _timeZone.copy() as! NSTimeZone
    }
}

#endif // FOUNDATION_FRAMEWORK
