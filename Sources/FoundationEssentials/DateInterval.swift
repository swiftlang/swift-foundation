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

/// DateInterval represents a closed date interval in the form of [startDate, endDate].  It is possible for the start and end dates to be the same with a duration of 0.  DateInterval does not support reverse intervals i.e. intervals where the duration is less than 0 and the end date occurs earlier in time than the start date.
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
public struct DateInterval: Comparable, Hashable, Codable, Sendable {

    /// The start date.
    public var start: Date
    
    /// Underlying storage for `duration`
    internal var _duration: DoubleDouble

    /// The end date.
    ///
    /// - precondition: `end >= start`
    public var end: Date {
        get {
            return Date(start._time + _duration)
        }
        set {
            precondition(newValue >= start, "Reverse intervals are not allowed")
            _duration = (newValue._time - start._time)
        }
    }
    
    /// The duration
    ///
    /// - precondition: `duration >= 0`
    public var duration: TimeInterval {
        get {
            _duration.head
        }
        set {
            precondition(newValue >= 0, "Negative durations are not allowed")
            _duration = DoubleDouble(uncheckedHead: newValue, tail: 0)
        }
    }

    /// Initializes a `DateInterval` with start and end dates set to the current date and the duration set to `0`.
    public init() {
        let d = Date()
        start = d
        _duration = .zero
    }

    /// Initialize a `DateInterval` with the specified start and end date.
    ///
    /// - precondition: `end >= start`
    public init(start: Date, end: Date) {
        precondition(end >= start, "Reverse intervals are not allowed")
        self.start = start
        _duration = end._time - start._time
    }

    /// Initialize a `DateInterval` with the specified start date and duration.
    ///
    /// - precondition: `duration >= 0`
    public init(start: Date, duration: TimeInterval) {
        precondition(duration >= 0, "Negative durations are not allowed")
        self.start = start
        _duration = DoubleDouble(uncheckedHead: duration, tail: 0)
    }

    /**
     Compare two DateIntervals.

     This method prioritizes ordering by start date. If the start dates are equal, then it will order by duration.
     e.g. Given intervals a and b
     ```
     a.   |-----|
     b.      |-----|
     ```

     `a.compare(b)` would return `.OrderedAscending` because a's start date is earlier in time than b's start date.

     In the event that the start dates are equal, the compare method will attempt to order by duration.
     e.g. Given intervals c and d
     ```
     c.  |-----|
     d.  |---|
     ```
     `c.compare(d)` would result in `.OrderedDescending` because c is longer than d.

     If both the start dates and the durations are equal, then the intervals are considered equal and `.OrderedSame` is returned as the result.
    */
    public func compare(_ dateInterval: DateInterval) -> ComparisonResult {
        let result = start.compare(dateInterval.start)
        if result == .orderedSame {
            if self.duration < dateInterval.duration { return .orderedAscending }
            if self.duration > dateInterval.duration { return .orderedDescending }
            return .orderedSame
        }
        return result
    }

    /// Returns `true` if `self` intersects the `dateInterval`.
    public func intersects(_ dateInterval: DateInterval) -> Bool {
        return contains(dateInterval.start) || contains(dateInterval.end) || dateInterval.contains(start) || dateInterval.contains(end)
    }

    /// Returns a DateInterval that represents the interval where the given date interval and the current instance intersect.
    ///
    /// In the event that there is no intersection, the method returns nil.
    public func intersection(with dateInterval: DateInterval) -> DateInterval? {
        if !intersects(dateInterval) {
            return nil
        }

        if self == dateInterval {
            return self
        }

        let timeIntervalForSelfStart = start.timeIntervalSinceReferenceDate
        let timeIntervalForSelfEnd = end.timeIntervalSinceReferenceDate
        let timeIntervalForGivenStart = dateInterval.start.timeIntervalSinceReferenceDate
        let timeIntervalForGivenEnd = dateInterval.end.timeIntervalSinceReferenceDate

        let resultStartDate : Date
        if timeIntervalForGivenStart >= timeIntervalForSelfStart {
            resultStartDate = dateInterval.start
        } else {
            // self starts after given
            resultStartDate = start
        }

        let resultEndDate : Date
        if timeIntervalForGivenEnd >= timeIntervalForSelfEnd {
            resultEndDate = end
        } else {
            // given ends before self
            resultEndDate = dateInterval.end
        }

        return DateInterval(start: resultStartDate, end: resultEndDate)
    }

    /// Returns `true` if `self` contains `date`.
    public func contains(_ date: Date) -> Bool {
        let timeIntervalForGivenDate = date.timeIntervalSinceReferenceDate
        let timeIntervalForSelfStart = start.timeIntervalSinceReferenceDate
        let timeIntervalForSelfEnd = end.timeIntervalSinceReferenceDate
        if (timeIntervalForGivenDate >= timeIntervalForSelfStart) && (timeIntervalForGivenDate <= timeIntervalForSelfEnd) {
            return true
        }
        return false
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(duration)
    }

    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    public static func ==(lhs: DateInterval, rhs: DateInterval) -> Bool {
        return lhs.start == rhs.start && lhs.duration == rhs.duration
    }

    @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    public static func <(lhs: DateInterval, rhs: DateInterval) -> Bool {
        return lhs.compare(rhs) == .orderedAscending
    }
    
    enum CodingKeys: String, CodingKey {
        case start = "start"
        case duration = "duration"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(Date.self, forKey: .start)
        let duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.init(start: start, duration: duration)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(duration, forKey: .duration)
    }
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension DateInterval : CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        return "\(start) to \(end)"
    }

    public var debugDescription: String {
        return description
    }

    public var customMirror: Mirror {
        var c: [(label: String?, value: Any)] = []
        c.append((label: "start", value: start))
        c.append((label: "end", value: end))
        c.append((label: "duration", value: duration))
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension DateInterval : ReferenceConvertible, _ObjectiveCBridgeable {
    public typealias ReferenceType = NSDateInterval

    public static func _getObjectiveCType() -> Any.Type {
        return NSDateInterval.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSDateInterval {
        return NSDateInterval(start: start, duration: duration)
    }

    public static func _forceBridgeFromObjectiveC(_ dateInterval: NSDateInterval, result: inout DateInterval?) {
        if !_conditionallyBridgeFromObjectiveC(dateInterval, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ dateInterval : NSDateInterval, result: inout DateInterval?) -> Bool {
        result = DateInterval(start: dateInterval.startDate, duration: dateInterval.duration)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSDateInterval?) -> DateInterval {
        var result: DateInterval?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
extension NSDateInterval : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as DateInterval)
    }
}
#endif
