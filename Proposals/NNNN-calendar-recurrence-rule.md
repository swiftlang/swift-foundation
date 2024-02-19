# Recurrence rules in `Calendar`

* Proposal: SF-NNNN
* Author: Hristo Staykov <https://github.com/hristost>
* Status: **Draft**
* Review Manager: TBD
* Status: **Draft**
* Bugs: <rdar://120559017>

## Revision history

* **v1** Initial draft

## Introduction

This proposal introduces API for enumerating dates matching a specific recurrence rule, and a structure to represent recurrence rules.


## Motivation

In a calendar, a recurrence rule is a set of rules describing how often a repeating event should occur. E.g. _"Yearly"_, _"Every 1st Saturday of the month"_, etc.

There are two existing APIs in the Apple ecosystem that allow for enumerating repeating events:

- `EKRecurrenceRule` in EventKit [^1]
- `INRecurrenceRule` in SiriKit [^2]

Both APIs are subsets of RFC-5545[^rfc-5545].

Foundation owns the `Calendar` type, and as such it makes sense for recurrence rules to be implement alongside Calendar.
## Proposed solution and example

We introduce `struct Calendar.RecurrenceRule` that describes how often an event should repeat. The structure models a subset of `RRULE` specified in:

- RFC-5545 Internet Calendaring and Scheduling Core Object Specification (iCalendar), 3.3.10. Recurrence Rule [^rfc-5545]
- RFC-7529 Non-Gregorian Recurrence Rules in the Internet Calendaring and Scheduling Core Object Specification (iCalendar) [^rfc-7529]

There are slight differences from the iCalendar RFCs and Apple's existing APIs:

- The complete iCalendar RFC allows repetition by seconds, whereas `Calendar.RecurrenceRule` does not. This may be added at a later time to ensure full conformance.
- Compared to our existing APIs, `Calendar.RecurrenceRule` is designed with non-Gregorian calendars in mind.
- Any recurrence rule that can be represented using `Calendar.RecurrenceRule` can be represented in iCalendar.

## Detailed design

```swift
extension Calendar {
    /// A rule which specifies how often an event should repeat in the future
    @available(FoundationPreview 0.4, *)
    public struct RecurrenceRule: Codable, Sendable {
        /// The calendar in which the recurrence occurs
        public var calendar: Calendar
        /// What to do when a recurrence is not a valid date
        ///
        /// Default value is `.nextTimePreservingSmallerComponents`
        public var matchingPolicy: Calendar.MatchingPolicy
        /// Which dates to consider when two dates occur at the same time during
        /// the day, but in different time zones due to a daylight saving switch
        public enum RepeatedTimePolicy : Sendable, Codable {
            /// Consider only the eariler date
            case onlyFirst
            /// Consider only the later date
            case onlyLast
            /// Consider both dates
            case both
        }
        /// What to do when there are multiple recurrences occurring at the same
        /// time of the day but in different time zones due to a daylight saving
        /// transition.
        ///
        /// For example, an event with daily recurrence rule that starts at 1 am
        /// on November 2 in PST will repeat on:
        ///
        /// - 2024-11-02 01:00 PDT (08:00 UTC)
        /// - 2024-11-03 01:00 PDT (08:00 UTC)
        ///   (Time zone switches from PST to PDT - clock jumps back one hour at
        ///    02:00 PDT)
        /// - 2024-11-03 01:00 PST (09:00 UTC)
        /// - 2024-11-04 01:00 PST (09:00 UTC)
        ///
        /// Due to the time zone switch on November 3, there are different times
        /// when the event might repeat.
        ///
        /// Default value is `.onlyFirst`
        public var repeatedTimePolicy: RepeatedTimePolicy
        /// How often a recurring event repeats
        public enum Frequency: Sendable, Codable {
            case minutely, hourly, daily, weekly, monthly, yearly
        }
        /// How often the event repeats
        public var frequency: Frequency
        /// At what interval to repeat
        ///
        /// Default value is `1`
        public var interval: Int
        /// When a recurring event stops recurring
        public struct End: Sendable, Codable {
            /// The event stops repeating after a given number of times
            /// - Parameter count: how many times to repeat the event, including
            ///                    the first occurrence. `count` must be greater
            ///                    than `0`
            public static func afterOcurrences(_ count: Int) -> Self
            /// The event stops repeating after a given date
            /// - Parameter date: the date on which the event may last occur. No
            ///                   further ocurrences will be found after that
            public static func afterDate(_ date: Date) -> Self
            /// The event repeats indefinitely
            public static var never: Self
        }
        /// For how long the event repeats
        ///
        /// Default value is `.never`
        public var end: End
        
        public enum Weekday: Sendable, Codable {
            /// Repeat on every weekday
            case every(Locale.Weekday)
            /// Repeat on the n-th instance of the specified weekday in a month,
            /// if the recurrence has a monthly frequency. If the recurrence has
            /// a yearly frequency, repeat on the n-th week of the year.
            /// 
            /// If n is negative, repeat on the n-to-last of the given weekday.
            case nth(Int, Locale.Weekday)
        }
        
        /// Uniquely identifies a month in any calendar system
        public struct Month: Sendable, Codable, ExpressibleByIntegerLiteral {
            public var index: Int
            public var isLeap: Bool

            public init(_ index: Int, isLeap: Bool = false)
        }
        
        /// On which seconds of the minute the event should repeat. Valid values
        /// between 0 and 60
        public var seconds: [Int]?
        /// On which minutes of the hour the event should repeat. Accepts values
        /// between 0 and 59
        public var minutes: [Int]?
        /// On which hours of a 24-hour day the event should repeat.
        public var hours: [Int]?
        /// On which days of the week the event should occur
        public var weekdays: [Weekday]?
        /// On which days in the month the event should occur
        /// - 1 signifies the first day of the month.
        /// - Negative values point to a day counted backwards from the last day
        ///   of the month
        /// This field is unused when `frequency` is `.weekly`.
        public var daysOfTheMonth: [Int]?
        /// On which days of the year the event may occur.
        /// - 1 signifies the first day of the year.
        /// - Negative values point to a day counted backwards from the last day
        ///   of the year
        /// This field is unused when `frequency` is any of `.daily`, `.weekly`,
        /// or `.monthly`.
        public var daysOfTheYear: [Int]?
        /// On which months the event should occur.
        /// - 1 is the first month of the year (January in Gregorian calendars)
        public var months: [Month]?
        /// On which weeks of the year the event should occur.
        /// - 1 is the first week of the year. `calendar.minimumDaysInFirstWeek`
        ///   defines which week is considered first.
        /// - Negative values refer to weeks if counting backwards from the last
        ///   week of the year. -1 is the last week of the year.
        /// This field is unused when `frequency` is other than `.yearly`.
        public var weeks: [Int]?
        /// Which occurrences within every interval should be returned
        public var setPositions: [Int]?

        public init(calendar: Calendar,
                    frequency: Frequency,
                    interval: Int = 1,
                    end: End = .never,
                    matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents,
                    repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst,
                    months: [Month]? = nil,
                    daysOfTheYear: [Int]? = nil,
                    daysOfTheMonth: [Int]? = nil,
                    weeks: [Int]? = nil,
                    weekdays: [Weekday]? = nil,
                    hours: [Int]? = nil,
                    minutes: [Int]? = nil,
                    seconds: [Int]? = nil,
                    setPositions: [Int]? = nil) -> Self

        /// Find recurrences of the given date
        ///
        /// The calculations are implemented according to RFC-5545 and RFC-7529.
        ///
        /// - Parameter start: the date which defines the starting point for the
        ///   recurrence rule.
        /// - Parameter range: a range of dates which to search for recurrences.
        ///   If `nil`, return all recurrences of the event.
        /// - Returns: a sequence of dates conforming to the recurrence rule, in
        ///   the given `range`. An empty sequence if the rule doesn't match any
        ///   dates.
        public func recurrences(of start: Date,
                                in range: Range<Date>? = nil
                                ) -> some (Sequence<Date> & Sendable)

        /// A recurrence that repeats every `interval` minutes
        public static func minutely(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, daysOfTheYear: [Int]? = nil, daysOfTheMonth: [Int]? = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
        /// A recurrence that repeats every `interval` hours
        public static func hourly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, daysOfTheYear: [Int]? = nil, daysOfTheMonth: [Int]? = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
        /// A recurrence that repeats every `interval` days
        public static func daily(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, daysOfTheMonth: [Int]? = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
        /// A recurrence that repeats every `interval` weeks
        public static func weekly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
        /// A recurrence that repeats every `interval` months
        public static func monthly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, daysOfTheMonth: [Int?] = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
        /// A recurrence that repeats every `interval` years
        public static func yearly(calendar: Calendar, interval: Int = 1, end: End = .never, matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents, repeatedTimePolicy: RepeatedTimePolicy = .onlyFirst, months: [Month]? = nil, daysOfTheYear: [Int]? = nil, daysOfTheMonth: [Int]? = nil, weeks: [Int]? = nil, weekdays: [Weekday]? = nil, hours: [Int]? = nil, minutes: [Int]? = nil, seconds: [Int]? = nil setPositions: [Int]? = nil) -> Self
    }
}
```



There is no Objective-C interface to this API.

### Usage
A recurrence rule of a given frequency repeats the start date with the interval of that frequency. For example, assume that now it is February 09 2024, 13:43. Creating a daily recurrence would yield a result for each following date at the same time:

```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .daily)
for date in recurrence.recurrences(of: .now) {
    // 2024-02-09, 13:43
    // 2024-02-10, 13:43
    // 2024-02-11, 13:43
    // 2024-02-12, 13:43
    // ...
}
```

A recurrence can be limited by a given end date:
```swift
let until: Date // = 01 March 2024, 00:00
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .daily, until: until)
for date in recurrence.recurrences(of: .now) {
    // 2024-02-09, 13:43
    // 2024-02-10, 13:43
    // ...
    // 2024-02-28, 13:43
    // 2024-02-29, 13:43
}
```

or by a given count:
```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .daily, count: 3)
for date in recurrence.recurrences(of: .now) {
    // 2024-02-09, 13:43
    // 2024-02-10, 13:43
    // 2024-02-11, 13:43
}
```

An internal can be specified so we don't repeat at every unit of the frequency. For example, a weekly recurrence with a frequency of 2 means to repeat every other week, at the same time:
```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .weekly)
recurrence.interval = 2
for date in recurrence.recurrences(of: .now) {
    // 2024-02-09, 13:43
    // 2024-02-23, 13:43
    // 2024-03-08, 13:43
}
```

The `minutes`, `hours`, `weekdays`, `daysOfTheMonth`, `months`, and `daysOfTheYear` can be used to limit or expand the search so it returns multiple results per unit of repetitions. For example, if we want to repeat an event every Tuesday, Wednesday, and Thursday:
```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .weekly)
recurrence.weekdays = [.every(.tuesday), .every(.wednesday), .every(.thursday)]
for date in recurrence.recurrences(of: .now) {
    // 2024-02-13, 13:43 (Tuesday)
    // 2024-02-14, 13:43 (Wednesday)
    // 2024-02-15, 13:43 (Thursday)
    // 2024-02-20, 13:43 (Tuesday)
    // 2024-02-21, 13:43 (Wednesday)
    // ...
}
```

Note that the start date is not part of the sequence, for it is on a Friday. Smaller components of the start date like hour and minute are preserved, unless overwritten with the recurrence rule.

The same fields can be used to limit the search. For example, if we want all the Fridays in February from now on:
```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .weekly)
recurrence.weekdays = [.every(.friday)]
for date in recurrence.recurrences(of: .now) {
    // 2024-02-09, 13:43
    // 2024-02-16, 13:43
    // 2024-02-19, 13:43
    // 2024-02-23, 13:43
    // 2025-02-07, 13:43
    // ...
}
```

Lastly, the "set position" can be used to filter results by their position in the repetition interval. For example, if we want the first weekend day of the month, we filter by Saturdays and Sundays in every month, and return only the first match in the repetition interval (a month):

```swift
var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .monthly)
recurrence.weekdays = [.every(.saturday), .every(.sunday)]
recurrence.setPositions = [1]
for date in recurrence.recurrences(of: .now) {
    // 2024-03-01, 13:43
    // 2024-04-06, 13:43
    // ...
}
```

The precise semantics of whether a field limits or expands the search vary by the specified frequency. In practice, we adhere to RFC-5545 for calculating recurrences. Please consult that document for further reference.

<details>
  <summary>Valid combinations of frequencies and fields</summary>
RFC-5545 specifies the following valid combinations of frequencies and fields. _"Limit"_ indicates that specifying the field filters results, whereas _"Expand"_ results in more matches per frequency interval. _"N/A"_ indicates that the field will not be used with the given frequency.

| Frequency        |`.minutely`|`.hourly` |`.daily`  |`.weekly`|`.monthly`|`.yearly`|
|------------------|-----------|----------|----------|---------|----------|---------|
|`.months`         |Limit      |Limit     |Limit     |Limit    |Limit     |Expand   |
|`.weeks`          |N/A        |N/A       |N/A       |N/A      |N/A       |Expand   |
|`.daysOfTheYear`  |Limit      |Limit     |N/A       |N/A      |N/A       |Expand   |
|`.daysOfTheMonth` |Limit      |Limit     |Limit     |N/A      |Expand    |Expand   |
|`.weekdays`       |Limit      |Limit     |Limit     |Expand   |Note 1    |Note 2   |
|`.hours`          |Limit      |Limit     |Expand    |Expand   |Expand    |Expand   |
|`.minutes`        |Limit      |Expand    |Expand    |Expand   |Expand    |Expand   |
|`.setPositions`   |Limit      |Limit     |Limit     |Limit    |Limit     |Limit    |

- Note 1:  Limit if `daysOfTheMonth` is present; otherwise expand
- Note 2:  Limit if `daysOfTheYear` or `daysOfTheMonth` is present; otherwise expand
</details>

#### Matching policy

Some dates created by a recurrence may not exist in a given calendar. For example, consider a person born on the 29th of February 1996. Their birthdays would be enumerated by repeating that date yearly:
```swift
let birthday: Date // = 29 February 1996 14:00
var recurrence = Calendar.RecurrenceRule(calendar.current, frequency: .yearly)
```

If we want to choose Feburary 28 to observe the birthday on non-leap years, we can use `.previousTimePreservingSmallerComponents`:
```swift
recurrence.matchingPolicy = .previousTimePreservingSmallerComponents
let birthdays = recurrence.recurrences(of: birthday)
// 1996-02-29 14:00
// 1997-02-28 14:00
// 1998-02-28 14:00
// 1999-02-28 14:00
// 2000-02-29 14:00
// ...
```

If we would like to use March 1st, we may use `.nextTimePreservingSmallerComponents`:
```swift
recurrence.matchingPolicy = .nextTimePreservingSmallerComponents
let birthdays = recurrence.recurrences(of: birthday)
// 1996-02-29 14:00
// 1997-03-01 14:00
// 1998-03-01 14:00
// 1999-03-01 14:00
// 2000-02-29 14:00
// ...
```

Alternatively, if we only care about exact matches, we can use `.strict`:
```swift
recurrence.matchingPolicy = .strict
let birthdays = recurrence.recurrences(of: birthday)
// 1996-02-29 14:00
// 2000-02-29 14:00
// 2004-02-29 14:00
// ...
```

### Examples

- Every 21st of September in the future:
  ```swift
  var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .yearly)
  recurrence.months = [9]
  recurrence.daysOfTheMonth = [21]

  for date in recurrence.recurrences(of: .now) {
      // 21 Sept 2024, 21 Sept 2025, and so on.
  }
  ```
- Start of the Lunar New Year:
  ```swift
  let lunarCalendar = Calendar(identifier: .chinese)
  var recurrence = Calendar.RecurrenceRule(calendar: lunarCalendar, frequency: .yearly, count: 5)
  recurrence.daysOfTheMonth = [1]
  recurrence.months = [1]

  for date in recurrence.recurrences(of: .now) {
      // First day of the Lunar New Year
  }
  ```
- Every last Friday of the month at 6PM, from now until 5 bike parties later:
  ```swift
  var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .monthly, count: 5)
  recurrence.weekdays = [.nth(-1, .friday)]
  recurrence.hours = [18]
  recurrence.minutes = [0]

  for date in recurrence.recurrences(of: .now) {
      // Critical mass bike ride
  }
  ```
- The first weekend day of each month:
  ```swift
  var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .monthly, count: 5)
  recurrence.weekdays = [.nth(1, .saturday), .nth(1, .sunday)]
  recurrence.setPositions = [1]
  for date in recurrence.recurrences(of: .now) {
      // The first Saturday or Sunday in the month, whichever comes first
  }
  ```
- Every weekday at 8:05, 8:35, 9:05, and 9:35am:
  ```swift
  var recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .monthly, count: 5)
  recurrence.weekdays = [.every(.monday), .every(.tuesday), .every(.wednesday), .every(.thursday), .every(.friday)]
  recurrence.hours = [8, 9]
  recurrence.minutes = [5, 35]
  ```


## Impact on existing code

None. This is an additive change.


## Alternatives considered

### Making the start time part of the recurrence rule

The starting date could also be made of the recurrence rule itself. Then, API usage could look like:
```swift
var recurrence = Calendar.Recurrence(calendar: .current, startingAt: .now, frequency: .monthly, count: 5)
for date in recurrence {

}
```

However, this would likely result in developers persisting the starting date twice. Imagine the following model for describing an event in a calendar:
```swift
struct Event {
    var start: Date
    var duration: Duration
    var recurrence: Calendar.RecurrenceRule?
}
```

The recurrence rule only describes how often an event should occur, not all of the event itself. Requiring the start time be part of the rule results in duplication thus and the possibility of mismatches in the above model.

Furthermore, moving the start date into the recurrence rule changes the semantics of what this API represents -- it would be no longer a recurrence rule, but a set of recurring dates.

### Enforcing valid states

Some combinations of fields in a recurrence rule are invalid. For example, it is not allowed to set `weeks` on a recurrence rule which has an hourly frequency. In such cases, we have to ignore invalid values. The static methods on `RecurrenceRule` allow it to be initialized with only valid fields for the given frequency. 

If we deem that enforcing valid states is important at compile time, we could remove the generic `init()` initializer, and make every property read-only so it may only be initialized with the appropriate static method for the desired frequency. This does not amount to full validation, as the there may still be invalid values such as months and weeks that are out of range for the given calendar. Furthermore, if this model ends up being used for iCalendar events, we want to make sure that round-trip encoding is possible even with an invalid state.

On the other hand, we can simply remove the static methods and let the user initialize each field separately, with the caveat that some values may be unused. Such is already the case with `DateComponents`.

## Future directions


[^1]: <https://developer.apple.com/documentation/eventkit/ekrecurrencerule>
[^2]: <https://developer.apple.com/documentation/sirikit/inrecurrencerule>
[^rfc-5545]: <https://www.rfc-editor.org/info/rfc5545>
[^rfc-7529]: <https://www.rfc-editor.org/info/rfc7529>
