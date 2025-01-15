//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#elseif os(WASI)
import WASILibc
#endif

#if !FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public typealias TimeInterval = Double
#endif // !FOUNDATION_FRAMEWORK
/**
 `Date` represents a single point in time.

 A `Date` is independent of a particular calendar or time zone. To represent a `Date` to a user, you must interpret it in the context of a `Calendar`.
*/
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Date : Comparable, Hashable, Equatable, Sendable {

    internal var _time : TimeInterval

    /// The number of seconds from 1 January 1970 to the reference date, 1 January 2001.
    public static let timeIntervalBetween1970AndReferenceDate : TimeInterval = 978307200.0

    /// The number of seconds from 1 January 1601 to the reference date, 1 January 2001.
    internal static let timeIntervalBetween1601AndReferenceDate: TimeInterval = 12622780800.0

    /// The interval between 00:00:00 UTC on 1 January 2001 and the current date and time.
    public static var timeIntervalSinceReferenceDate : TimeInterval {
        return Self.getCurrentAbsoluteTime()
    }

    /// Returns a `Date` initialized to the current date and time.
    public init() {
        _time = Self.getCurrentAbsoluteTime()
    }

    /// Returns a `Date` initialized relative to the current date and time by a given number of seconds.
    public init(timeIntervalSinceNow: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: timeIntervalSinceNow + Self.getCurrentAbsoluteTime())
    }

    /// Returns a `Date` initialized relative to 00:00:00 UTC on 1 January 1970 by a given number of seconds.
    public init(timeIntervalSince1970: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: timeIntervalSince1970 - Date.timeIntervalBetween1970AndReferenceDate)
    }

    /**
    Returns a `Date` initialized relative to another given date by a given number of seconds.

    - Parameter timeInterval: The number of seconds to add to `date`. A negative value means the receiver will be earlier than `date`.
    - Parameter date: The reference date.
    */
    public init(timeInterval: TimeInterval, since date: Date) {
        self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + timeInterval)
    }

    /// Returns a `Date` initialized relative to 00:00:00 UTC on 1 January 2001 by a given number of seconds.
    public init(timeIntervalSinceReferenceDate ti: TimeInterval) {
        _time = ti
    }

    /**
    Returns the interval between the date object and 00:00:00 UTC on 1 January 2001.

    This property's value is negative if the date object is earlier than the system's absolute reference date (00:00:00 UTC on 1 January 2001).
    */
    public var timeIntervalSinceReferenceDate: TimeInterval {
        return _time
    }

    /**
    Returns the interval between the receiver and another given date.

    - Parameter another: The date with which to compare the receiver.

    - Returns: The interval between the receiver and the `another` parameter. If the receiver is earlier than `anotherDate`, the return value is negative. If `anotherDate` is `nil`, the results are undefined.

    - SeeAlso: `timeIntervalSince1970`
    - SeeAlso: `timeIntervalSinceNow`
    - SeeAlso: `timeIntervalSinceReferenceDate`
    */
    public func timeIntervalSince(_ date: Date) -> TimeInterval {
        return self.timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate
    }

    /**
    The time interval between the date and the current date and time.

    If the date is earlier than the current date and time, this property's value is negative.

    - SeeAlso: `timeIntervalSince(_:)`
    - SeeAlso: `timeIntervalSince1970`
    - SeeAlso: `timeIntervalSinceReferenceDate`
    */
    public var timeIntervalSinceNow: TimeInterval {
        return self.timeIntervalSinceReferenceDate - Self.getCurrentAbsoluteTime()
    }

    /**
    The interval between the date object and 00:00:00 UTC on 1 January 1970.

    This property's value is negative if the date object is earlier than 00:00:00 UTC on 1 January 1970.

    - SeeAlso: `timeIntervalSince(_:)`
    - SeeAlso: `timeIntervalSinceNow`
    - SeeAlso: `timeIntervalSinceReferenceDate`
    */
    public var timeIntervalSince1970: TimeInterval {
        return self.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
    }

    internal var timeIntervalSince1601: TimeInterval {
        return self.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1601AndReferenceDate
    }

    /// Return a new `Date` by adding a `TimeInterval` to this `Date`.
    ///
    /// - parameter timeInterval: The value to add, in seconds.
    /// - warning: This only adjusts an absolute value. If you wish to add calendrical concepts like hours, days, months then you must use a `Calendar`. That will take into account complexities like daylight saving time, months with different numbers of days, and more.
    public func addingTimeInterval(_ timeInterval: TimeInterval) -> Date {
        return self + timeInterval
    }

    /// Add a `TimeInterval` to this `Date`.
    ///
    /// - parameter timeInterval: The value to add, in seconds.
    /// - warning: This only adjusts an absolute value. If you wish to add calendrical concepts like hours, days, months then you must use a `Calendar`. That will take into account complexities like daylight saving time, months with different numbers of days, and more.
    public mutating func addTimeInterval(_ timeInterval: TimeInterval) {
        self += timeInterval
    }

    /**
    Creates and returns a Date value representing a date in the distant future.

    The distant future is in terms of centuries.
    */
    public static let distantFuture = Date(timeIntervalSinceReferenceDate: 63113904000.0)

    /**
    Creates and returns a Date value representing a date in the distant past.

    The distant past is in terms of centuries.
    */
    public static let distantPast = Date(timeIntervalSinceReferenceDate: -63114076800.0)

    /// Returns a `Date` initialized to the current date and time.
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public static var now : Date { Date() }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(_time)
    }

    /// Compare two `Date` values.
    public func compare(_ other: Date) -> ComparisonResult {
        if _time < other.timeIntervalSinceReferenceDate {
            return .orderedAscending
        } else if _time > other.timeIntervalSinceReferenceDate {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    /// Returns true if the two `Date` values represent the same point in time.
    public static func ==(lhs: Date, rhs: Date) -> Bool {
        return lhs.timeIntervalSinceReferenceDate == rhs.timeIntervalSinceReferenceDate
    }

    /// Returns true if the left hand `Date` is earlier in time than the right hand `Date`.
    public static func <(lhs: Date, rhs: Date) -> Bool {
        return lhs.timeIntervalSinceReferenceDate < rhs.timeIntervalSinceReferenceDate
    }

    /// Returns true if the left hand `Date` is later in time than the right hand `Date`.
    public static func >(lhs: Date, rhs: Date) -> Bool {
        return lhs.timeIntervalSinceReferenceDate > rhs.timeIntervalSinceReferenceDate
    }

    /// Returns a `Date` with a specified amount of time added to it.
    public static func +(lhs: Date, rhs: TimeInterval) -> Date {
        return Date(timeIntervalSinceReferenceDate: lhs.timeIntervalSinceReferenceDate + rhs)
    }

    /// Returns a `Date` with a specified amount of time subtracted from it.
    public static func -(lhs: Date, rhs: TimeInterval) -> Date {
        return Date(timeIntervalSinceReferenceDate: lhs.timeIntervalSinceReferenceDate - rhs)
    }

    /// Add a `TimeInterval` to a `Date`.
    ///
    /// - warning: This only adjusts an absolute value. If you wish to add calendrical concepts like hours, days, months then you must use a `Calendar`. That will take into account complexities like daylight saving time, months with different numbers of days, and more.
    public static func +=(lhs: inout Date, rhs: TimeInterval) {
        lhs = lhs + rhs
    }

    /// Subtract a `TimeInterval` from a `Date`.
    ///
    /// - warning: This only adjusts an absolute value. If you wish to add calendrical concepts like hours, days, months then you must use a `Calendar`. That will take into account complexities like daylight saving time, months with different numbers of days, and more.
    public static func -=(lhs: inout Date, rhs: TimeInterval) {
        lhs = lhs - rhs
    }

}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Date {
    private static func getCurrentAbsoluteTime() -> TimeInterval {
#if canImport(WinSDK)
        var ft: FILETIME = FILETIME()
        var li: ULARGE_INTEGER = ULARGE_INTEGER()
        GetSystemTimePreciseAsFileTime(&ft)
        li.LowPart = ft.dwLowDateTime
        li.HighPart = ft.dwHighDateTime
        // FILETIME represents 100-ns intervals since January 1, 1601 (UTC)
        return TimeInterval(Double(li.QuadPart) / 10_000_000.0 - Self.timeIntervalBetween1601AndReferenceDate)
#else
        var ts: timespec = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        var ret = TimeInterval(ts.tv_sec) - Self.timeIntervalBetween1970AndReferenceDate
        ret += (1.0E-9 * TimeInterval(ts.tv_nsec))
        return ret
#endif // canImport(WinSDK)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Date : CustomDebugStringConvertible, CustomStringConvertible, CustomReflectable {
// For backwards compatibility, the Darwin version of this method is left alone
// because it uses `NSDateFormatter` and may behave slightly differently.
#if !FOUNDATION_FRAMEWORK
    /// A string representation of the date object (read-only).
    /// The representation is useful for debugging only.
    /// There are a number of options to acquire a formatted string for a date including: date formatters
    /// (see [NSDateFormatter](//apple_ref/occ/cl/NSDateFormatter) and
    /// [Data Formatting Guide](//apple_ref/doc/uid/10000029i)), and the `Date`
    /// function `description(locale:)`.
    public var description: String {
        // NSDate uses the constant format `uuuu-MM-dd HH:mm:ss '+0000'`

        // Glibc needs a non-standard format option to pad %Y to 4 digits
#if canImport(Glibc) && !os(FreeBSD)
        let format = "%4Y-%m-%d %H:%M:%S +0000"
#else
        let format = "%Y-%m-%d %H:%M:%S +0000"
#endif
        let unavailable = "<description unavailable>"

        guard self >= Date.distantPast else {
            return unavailable
        }
        guard self <= Date.distantFuture else {
            return unavailable
        }

        var info = tm()
#if os(Windows)
        var time = __time64_t(self.timeIntervalSince1970)
        let errno: errno_t = _gmtime64_s(&info, &time)
        guard errno == 0 else { return unavailable }
#else
        var time = time_t(self.timeIntervalSince1970)
        gmtime_r(&time, &info)
#endif

        // This allocates stack space for range of 10^102 years
        // That's more than Date currently supports.
        let bufferSize = 128
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: bufferSize) { buffer in
            guard let ptr = buffer.baseAddress else {
                return unavailable
            }

            guard strftime(ptr, bufferSize, format, &info) != 0 else {
                return unavailable
            }

            guard let result = String(validatingUTF8: ptr) else {
                return unavailable
            }

            return result
        }
    }
#endif // !FOUNDATION_FRAMEWORK

    public var debugDescription: String {
        return description
    }

    public var customMirror: Mirror {
        let c: [(label: String?, value: Any)] = [
          ("timeIntervalSinceReferenceDate", timeIntervalSinceReferenceDate)
        ]
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Date : Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let timestamp = try container.decode(Double.self)
        self.init(timeIntervalSinceReferenceDate: timestamp)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.timeIntervalSinceReferenceDate)
    }
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Date : ReferenceConvertible, _ObjectiveCBridgeable {
    public typealias ReferenceType = NSDate

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSDate {
        return NSDate(timeIntervalSinceReferenceDate: _time)
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSDate, result: inout Date?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSDate, result: inout Date?) -> Bool {
        result = Date(timeIntervalSinceReferenceDate: x.timeIntervalSinceReferenceDate)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSDate?) -> Date {
        var result: Date?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSDate : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as Date)
    }
}
#endif // FOUNDATION_FRAMEWORK

// MARK: - Playground Support
#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Date : _CustomPlaygroundQuickLookable {
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: self)
    }

    @available(*, deprecated, message: "Date.customPlaygroundQuickLook will be removed in a future Swift version")
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return .text(summary)
    }
}
#endif // FOUNDATION_FRAMEWORK

extension Date {
    // Julian day 0 (-4713-01-01 12:00:00 +0000) in CFAbsoluteTime to 506713-02-07 00:00:00 +0000, smaller than the max time ICU supported.
    package static let validCalendarRange = Date(timeIntervalSinceReferenceDate: TimeInterval(-211845067200.0))...Date(timeIntervalSinceReferenceDate: TimeInterval(15927175497600.0))

    // aka __CFCalendarValidateAndCapTimeRange
    package var capped: Date {
        return max(min(self, Date.validCalendarRange.upperBound), Date.validCalendarRange.lowerBound)
    }
    
    package var isValidForEnumeration: Bool {
        Date.validCalendarRange.contains(self)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Date {
    public typealias Stride = TimeInterval
    
    public func distance(to other: Date) -> TimeInterval {
        return other.timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate
    }
    
    public func advanced(by n: TimeInterval) -> Date {
        return self + n
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Date: Strideable {
}
