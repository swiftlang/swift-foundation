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

// Required to be `AnyObject` because it optimizes the call sites in the `struct` wrapper for efficient function dispatch.
package protocol _TimeZoneProtocol : AnyObject, Sendable, CustomDebugStringConvertible {
    init?(secondsFromGMT: Int)
    init?(identifier: String)
    
    var identifier: String { get }
    func secondsFromGMT(for date: Date) -> Int

    /// Essentially this is equivalent to adjusting `date` to this time zone using `rawOffset`, then passing the adjusted date to `daylightSavingTimeOffset(for: <adjusted date>)`.
    /// This also handles the skipped time frame on DST start day differently from `daylightSavingTimeOffset(:)`, where dates in the skipped time frame are considered *not* in DST here, hence the DST offset would be 0.
    func rawAndDaylightSavingTimeOffset(for date: Date, repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy, skippedTimePolicy: TimeZone.DaylightSavingTimePolicy) -> (rawOffset: Int, daylightSavingOffset: TimeInterval)

    func abbreviation(for date: Date) -> String?
    func isDaylightSavingTime(for date: Date) -> Bool
    func daylightSavingTimeOffset(for date: Date) -> TimeInterval
    func nextDaylightSavingTimeTransition(after date: Date) -> Date?
    func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String?
    
    // Used by legacy ObjC clients only
    var data: Data? { get }
    var isAutoupdating: Bool { get }
    var debugDescription: String { get }
    func hash(into hasher: inout Hasher)
#if FOUNDATION_FRAMEWORK
    func bridgeToNSTimeZone() -> NSTimeZone
#endif
}

extension _TimeZoneProtocol {
    package var data: Data? {
        nil
    }
    
    package var isAutoupdating: Bool {
        false
    }
    
    package var debugDescription: String {
        identifier
    }
    
    package func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
#if FOUNDATION_FRAMEWORK
    package func bridgeToNSTimeZone() -> NSTimeZone {
        _NSSwiftTimeZone(timeZone: TimeZone(inner: self))
    }
#endif
}
