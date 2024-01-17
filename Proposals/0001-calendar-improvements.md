# Calendar Sequence Enumeration

* Proposal: [SF-0001](0001-calendar-improvements.md)
* Authors: [Tony Parker](https://github.com/parkera)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Accepted**
* Implementation: [Pull Request](https://github.com/apple/swift-foundation/pull/322)
* Review: [Pitch](https://forums.swift.org/t/pitch-calendar-sequence-enumeration/68521)

## Introduction

In macOS 14 / iOS 17, `Calendar` was rewritten entirely in Swift. One of the many benefits of this change is that we can now more easily create Swift-specific `Calendar` API that feels more natural than the existing `enumerate` methods. In addition, we are taking the opportunity to add a new field to the `DateComponents` type to handle one case that was only exposed via the somewhat esoteric CoreFoundation API `CFCalendarDecomposeAbsoluteTime`.

## Motivation

The existing `enumerateDates` method on `Calendar` is basically imported from an Objective-C implementation. We can provide much better integration with other Swift API by providing a `Sequence`-backed enumeration. The `nextDate` API can similarly be improved with a `Sequence` API.

We also need to support a new `dayOfYear` field on `DateComponents` to support a Swift-only implementation of `ISO8601FormatStyle` in `FoundationEssentials`.

## Proposed solution

We propose a new field on `DateComponents` and associated options / units:

```swift
extension Calendar {
    public enum Component : Sendable {
        // .. existing fields

        @available(FoundationPreview 0.4, *)
        case dayOfYear
    }
}
```

```swift
extension DateComponents {
    /// A day of the year.
    /// For example, in the Gregorian calendar, can go from 1 to 365 or 1 to 366 in leap years.
    /// - note: This value is interpreted in the context of the calendar in which it is used.
    @available(FoundationPreview 0.4, *)
    public var dayOfYear: Int?
}
```

We also propose API on `Calendar` enumerate matches with a `Sequence`:

```swift
extension Calendar {
    /// Computes the dates which match (or most closely match) a given set of components, returned as a `Sequence`.
    ///
    /// If `direction` is set to `.backward`, this method finds the previous match before the start date. The intent is that the same matches as for a `.forward` search will be found. For example, if you are searching forwards or backwards for each hour with minute "27", the seconds in the date you will get in both a `.forward` and `.backward` search would be `00`.  Similarly, for DST backwards jumps which repeat times, you'll get the first match by default, where "first" is defined from the point of view of searching forwards. Therefore, when searching backwards looking for a particular hour, with no minute and second specified, you don't get a minute and second of `59:59` for the matching hour but instead `00:00`.
    ///
    /// If a range is supplied, the sequence terminates if the next result is not contained in the range. The starting point does not need to be contained in the range, but if the first result is outside of the range then the result will be an empty sequence.
    ///
    /// If an exact match is not possible, and requested with the `strict` option, the sequence ends.
    ///
    /// Result dates have an integer number of seconds (as if 0 was specified for the nanoseconds property of the `DateComponents` matching parameter), unless a value was set in the nanoseconds property, in which case the result date will have that number of nanoseconds, or as close as possible with floating point numbers.
    /// - parameter start: The `Date` at which to start the search.
    /// - parameter range: The range of dates to allow in the result. The sequence terminates if the next result is not contained in this range. If `nil`, all results are allowed.
    /// - parameter components: The `DateComponents` to use as input to the search algorithm.
    /// - parameter matchingPolicy: Determines the behavior of the search algorithm when the input produces an ambiguous result.
    /// - parameter repeatedTimePolicy: Determines the behavior of the search algorithm when the input produces a time that occurs twice on a particular day.
    /// - parameter direction: Which direction in time to search. The default value is `.forward`, which means later in time.
    @available(FoundationPreview 0.4, *)
    public func dates(byMatching components: DateComponents,
                      startingAt start: Date,
                      in range: Range<Date>? = nil,                      
                      matchingPolicy: MatchingPolicy = .nextTime,
                      repeatedTimePolicy: RepeatedTimePolicy = .first,
                      direction: SearchDirection = .forward) -> some (Sequence<Date> & Sendable)
}
```

And API on `Calendar` to enumerate addition with a `Sequence`:

```swift
extension Calendar {
    /// Returns a sequence of `Date`s, calculated by adding a scaled amount of `Calendar.Component`s to a starting `Date`. 
    /// If a range is supplied, the sequence terminates if the next result is not contained in the range. The starting point does not need to be contained in the range, but if the first result is outside of the range then the result will be an empty sequence.
    ///
    /// - parameter startingAt: The starting point of the search.
    /// - parameter range: The range of dates to allow in the result. The sequence terminates if the next result is not contained in this range. If `nil`, all results are allowed.
    /// - parameter component: A component to add or subtract.
    /// - parameter value: The value of the specified component to add or subtract. The default value is `1`. The value can be negative, which causes subtraction.
    /// - parameter wrappingComponents: If `true`, the component should be incremented and wrap around to zero/one on overflow, and should not cause higher components to be incremented. The default value is `false`.
    /// - returns: A `Sequence` of `Date` values, or an empty sequence if no addition could be performed.
    @available(FoundationPreview 0.4, *)
    public func dates(byAdding component: Calendar.Component,
                      value: Int = 1,
                      startingAt start: Date,
                      in range: Range<Date>? = nil,                      
                      wrappingComponents: Bool = false) -> some (Sequence<Date> & Sendable)
    
    /// Returns a sequence of `Date`s, calculated by adding a scaled amount of `DateComponents` to a starting `Date`.
    /// If a range is supplied, the sequence terminates if the next result is not contained in the range. The starting point does not need to be contained in the range, but if the first result is outside of the range then the result will be an empty sequence.
    ///
    /// - parameter startingAt: The starting point of the search.
    /// - parameter range: The range of dates to allow in the result. The sequence terminates if the next result is not contained in this range. If `nil`, all results are allowed.
    /// - parameter components: The components to add or subtract.
    /// - parameter wrappingComponents: If `true`, the component should be incremented and wrap around to zero/one on overflow, and should not cause higher components to be incremented. The default value is `false`.
    /// - returns: A `Sequence` of `Date` values, or an empty sequence if no addition could be performed.
    @available(FoundationPreview 0.4, *)
    public func dates(byAdding components: DateComponents,
                      startingAt start: Date,
                      in range: Range<Date>? = nil,                      
                      wrappingComponents: Bool = false) -> some (Sequence<Date> & Sendable)
}
```


## Detailed design

### Matching Sequences

The new `Sequence`-based API is a great fit for Swift because it composes with all the existing algorithms and functions that exist on `Sequence`. For example, the following code finds the next 3 minutes after _August 22, 2022 at 3:02:38 PM PDT_, then uses `zip` to combine them with some strings. The second array naturally has 3 elements. In contrast with the existing `enumerate` method, no additional counting of how many values we've seen and manully setting a `stop` argument to break out of a loop is required.

```swift
let cal = Calendar(identifier: .gregorian)
let date = Date(timeIntervalSinceReferenceDate: 682869758.712307)   // August 22, 2022 at 7:02:38 AM PDT
let dates = zip(
    cal.dates(byMatching: DateComponents(minute: 0), startingAt: date, matchingPolicy: .nextTime)
    ["1st period", "2nd period", "3rd period"]
)

let description = dates
        .map { "\($0.formatted(date: .omitted, time: .shortened)): \($1)" }
        .formatted()
// 8:00 AM: 1st period, 9:00 AM: 2nd period, and 10:00 AM: 3rd period
```

Another example is using the generic `prefix` function. Here, it is combined with use of the new `dayOfYear` field:

```swift
var matchingComps = DateComponents()
matchingComps.dayOfYear = 234
// Including a leap year, find the next 5 "day 234"s
let result = cal.dates(byMatching: matchingComps, startingAt: date).prefix(5)
/* 
  Result:
    2022-08-22 00:00:00 +0000
    2023-08-22 00:00:00 +0000
    2024-08-21 00:00:00 +0000 // note: leap year, one additional day in Feb
    2025-08-22 00:00:00 +0000
    2026-08-22 00:00:00 +0000
*/
```

### Searching by Range

The new function also has an option for using a `Range` to limit a search:

```swift
// Find the next 3 days at hour 22.
let startDate = Date(timeIntervalSinceReferenceDate: 682898558.712307) // 2022-08-22 22:02:38 UTC
let endDate = startDate + (86400 * 3) // Three 86400 second days
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone.gmt

var dc = DateComponents()
dc.hour = 22

let result = cal.dates(byMatching: dc, startingAt: startDate, in: startDate..<endDate)
/*
  Result:
    2022-08-23 22:00:00 +0000
    2022-08-24 22:00:00 +0000
    2022-08-25 22:00:00 +0000
*/
```

The API also allows for backwards searches. Note that the `Range` remains ordered forward in time as Swift does not allow for reverse ranges. The separation of the starting point from the range allows for the caller to control where they want the search to start in the range (start or end, for example). The search can also start outside of the range, and will return results as long as the first result is inside of the range. The sequence terminates as soon as a result is not contained in the range.

```swift
let result = cal.dates(byMatching: dc, startingAt: endDate, in: startDate..<endDate, direction: .backward)
/*
  Result:
    2022-08-25 22:00:00 +0000
    2022-08-24 22:00:00 +0000
    2022-08-23 22:00:00 +0000
*/
```

### Addition Sequences

`Calendar` has existing API for calculating a `Date` based on addition (or subtraction) of a `Calendar.Component` or `DateComponents` with a start date.

```swift
struct Calendar {
    /// Pre-existing API
    public func date(byAdding component: Component, value: Int, to date: Date, wrappingComponents: Bool = false) -> Date?

    /// Pre-existing API
    public func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date?
}
```

We propose complementing this single-result API with a `Sequence`-based one.

```swift
let startDate = Date(timeIntervalSinceReferenceDate: 689292158.712307) // 2022-11-04 22:02:38 UTC
let endDate = startDate + (86400 * 3) + (3600 * 2) // 3 days + 2 hours later - cross a DST boundary which adds a day with an additional hour in it
var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(name: "America/Los_Angeles")!

let result = cal.dates(byAdding: .day, startingAt: startDate, in: startDate..<endDate)
/* 
  Result:
    2022-11-05 22:02:38 +0000
    2022-11-06 23:02:38 +0000 // note: DST day, one additional hour
    2022-11-07 23:02:38 +0000
*/
```

### Day of Year

The new `dayOfYear` option composes with existing `Calendar` API, and can be useful for specialized calculations.

```swift
let date = Date(timeIntervalSinceReferenceDate: 682898558.712307) // 2022-08-22 22:02:38 UTC, day 234
let dayOfYear = cal.component(.dayOfYear, from: date) // 234
let leapYearDate = cal.date(from: .init(year: 2024, month: 1, day: 1))!

let range1 = cal.range(of: .dayOfYear, in: .year, for: date) // 1..<366
let range2 = cal.range(of: .dayOfYear, in: .year, for: leapYearDate) // 1..<367

// What day of the week is the 100th day of the year?
let whatDay = cal.date(bySetting: .dayOfYear, value: 100, of: Date.now)!
let dayOfWeek = cal.component(.weekday, from: whatDay) // 3 (Tuesday)
```


## Source compatibility

The proposed changes are additive and no significant impact on existing code is expected. Some `Calendar` API will begin to return `DateComponents` results with the additional field populated.

## Implications on adoption

The new API has an availability of FoundationPreview 0.4 or later.

## Alternatives considered

The `DateSequence` API is missing one parameter that `enumerateDates` has - a `Boolean` argument to indicate if the result date is an exact match or not. In research for this proposal, we surveyed many callers of the existing `enumerateDates` API and found only one that did not ignore this argument. Given the greater usability of having a simple `Date` as the element of the `Sequence`, we decided to omit the value from the `Sequence` API. The existing `enumerateDates` method will continue to exist in the rare case that the exact-match value is required.

We decided not to add the new fields to the `DateComponents` initializer. Swift might add a new "magic `with`" [operator](https://github.com/apple/swift-evolution/pull/2123) which will provide a better pattern for initializing immutable struct types with `var` fields. Even if that proposal does not end up accepted, adding a new initializer for each new field will quickly become unmanageable, and using default values makes the initializers ambiguous. Instead, the caller can simply set the desired value after initialization.

We originally considered adding a field for Julian days, but decided this would be better expressed as a conversion from `Date` instead of from a `DateComponents`. Julian days are similar to `Date` in that they represent a point on a fixed timeline. For Julian days, they also assume a fixed calendar and time zone. Combining this with the open API of a `DateComponents`, which allows setting both a `Calendar` and `TimeZone` property, provides an opportunity for confusion. In addition, ICU defines a Julian day slightly differently than other standards and our current implementation relies on ICU for the calculations. This discrepency could lead to errors if the developer was not careful to offset the result manually.

We considered changing the type of the `byAdding` argument to `dates(startingAt:byAdding:value:wrappingComponents:)` from `Calendar.Component` to `Int`, reading as something like: "dates starting at D, by adding 1, .day". However, we instead chose to use the same argument names and types as the existing `date(byAdding:value:to:wrappingComponent:)` API (which this new `Sequence` API calls) for consistency in the overall `Calendar` API.

We considered a `PartialRangeFrom` based API instead of a `Date` plus optional `Range`. However, we felt that a "backwards" search would be confusing:

```swift
let dates = calendar.dates(in: start..., matching: components, direction: .backward) // Starts at start but goes 'backwards', even though range is 'From' start
```

We considered adding new `Calendar.SearchDirection` enumeration values (backwards from, forwards from), but existing API would not know how to use them. We also feel that adding a new enumeration type for this API is more complicated than simply adding arguments to the functions themselves.

We considered omitting the `startingAt` argument and assuming a starting point in the `range` argument based on `direction`. This works for the matching API (although it may be a little confusing), but it doesn't work for the adding API because it does not use a direction but instead the positive or negative values of the `DateComponents`. These components may be a combination of positive and negative values, making it diffcult to make a predictable assumption about where the starting point of the search should be. It is better to simply ask for it directly. 

## Acknowledgments

Thanks to [Tina Liu](https://github.com/itingliu) for early and continued feedback on this proposal.
