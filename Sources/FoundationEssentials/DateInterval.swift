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
public struct DateInterval : Comparable, Hashable, Codable, Sendable {

    /// The start date.
    public var start : Date

    /// The end date.
    ///
    /// - precondition: `end >= start`
    public var end : Date {
        get {
            return start + duration
        }
        set {
            precondition(newValue >= start, "Reverse intervals are not allowed")
            duration = newValue.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
        }
    }

    /// The duration.
    ///
    /// - precondition: `duration >= 0`
    public var duration : TimeInterval {
        willSet {
            precondition(newValue >= 0, "Negative durations are not allowed")
        }
    }

    /// Initializes a `DateInterval` with start and end dates set to the current date and the duration set to `0`.
    public init() {
        let d = Date()
        start = d
        duration = 0
    }

    /// Initialize a `DateInterval` with the specified start and end date.
    ///
    /// - precondition: `end >= start`
    public init(start: Date, end: Date) {
        precondition(end >= start, "Reverse intervals are not allowed")
        self.start = start
        duration = end.timeIntervalSince(start)
    }

    /// Initialize a `DateInterval` with the specified start date and duration.
    ///
    /// - precondition: `duration >= 0`
    public init(start: Date, duration: TimeInterval) {
        precondition(duration >= 0, "Negative durations are not allowed")
        self.start = start
        self.duration = duration
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
    
    /**
     Returns the seconds between `self` and `date` or `nil` if there is no difference in time between them.
     
     For example, given this interval and this date on a timeline:
     ```
     |-----| <-- time interval --> *
     ```
     Returns a negative time interval when `date` is a moment greater than or equal to the end of `self` because the receiver specifies a range of times earlier than `date`.
     
     ```
      * <-- time interval --> |-----|
     ```
     Returns a positive time interval when `date` is a moment less than or equal to (before) the start of `self` because the receiver specifies a range of times later than `date`.
     
     A return value of `0` indicates `date` is equal to either the start or end moments of `self`.
     
     A return value of `nil` indicates the `date` is between the start and end dates (`date` is both greater than the start and less than the end moments of `self`):
     ```
      |--*--|
     ```
     */
    public func timeIntervalSince(_ date: Date) -> TimeInterval? {
        if end <= date {
            return end.timeIntervalSince(date)
        } else if date <= start {
            return start.timeIntervalSince(date)
        } else {
            return nil
        }
    }
    
    /**
     Returns the date interval between `self` and `date` or `nil` if there is no difference in time between them.
     
     For example, given this interval and this date on a timeline:
     ```
      * <-- duration --> |-----|
     ```
     Returns a value whose start is `date` and whose `duration` is the time between the `date` and the end of `self`.
     
     ```
     |-----| <-- duration --> *
     ```
     Returns a value whose start is the end of `self` and whose `duration` is the time between the `date` and the the end of `self`.
     
     A return value with a duration of `0` indicates `date` is equal to the start or end of `self`.
     
     A return value of `nil` indicates there are no moments between `date` and `self` (`date` is both greater than the start and less than the end moments of `self`):
     ```
      |--*--|
     ```
     */
    public func dateIntervalSince(_ date: Date) -> DateInterval? {
        if date <= start {
            return DateInterval(start: date, end: start)
            
        } else if end <= date {
            return DateInterval(start: end, end: date)
            
        } else {
            return nil
        }
    }
    
    /**
     Returns the seconds between `self` and `dateInterval` or `nil` if there is no difference in time between them.
     
     For example, given these two intervals on a timeline:
     ```
     |-----| <-- time interval --> |-----|
     ```
     Returns a negative time interval when `self` ends before `dateInterval` starts. A postive time interval indicates `self` starts after `dateInterval` ends.
     
     A return value of `0` indicates `self` starts or ends where `dateInterval` ends or starts (in other words, they intersect at their opposing start/end moments):
     ```
     |-----|-----|
     ```
     
     A return value of `nil` indicates `self` and `dateInterval` do not have any time between them:
     ```
     |--|-----|--|
     ```
     */
    public func timeIntervalSince(_ dateInterval: DateInterval) -> TimeInterval? {
        if end <= dateInterval.start {
            return end.timeIntervalSince(dateInterval.start)
            
        } else if dateInterval.end <= start {
            return start.timeIntervalSince(dateInterval.end)
            
        } else {
            return nil
        }
    }
    
    /**
     Returns the date interval between `self` and `dateInterval` or `nil` if there is no difference in time between them.
     
     For example, given these two intervals on a timeline:
     ```
     |-----| <-- duration --> |-----|
     ```
     The latest start date and the earliest end date between `self` and `dateInterval` is determined. Returns a date interval whose start is the earliest end date and whose duration is the difference in time between the latest start and earliest end.
     
     A return value with a duration of `0` indicates `self` and `dateInterval` form an unbroken, continous interval (in other words, they intersect at opposing starts/ends):
     ```
     |-----|-----|
     ```
     
     A return value of `nil` indicates that no interval exists between `self` and `dateInterval`:
     ```
     |--|-----|--|
     ```
     */
    public func dateIntervalSince(_ dateInterval: DateInterval) -> DateInterval? {
        let earliestEnd: Date
        let duration: TimeInterval
        
        if end <= dateInterval.start {
            earliestEnd = end
            duration = dateInterval.start.timeIntervalSince(end)
            
        } else if dateInterval.end <= start {
            earliestEnd = dateInterval.end
            duration = start.timeIntervalSince(dateInterval.end)
            
        } else {
            return nil
        }
        
        return DateInterval(start: earliestEnd, duration: duration)
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
