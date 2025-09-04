# Search for recurrence in partial ranges

* Proposal: SF-0032
* Author: Hristo Staykov <https://github.com/hristost>
* Implementation: [#1456](https://github.com/swiftlang/swift-foundation/pull/1456)
* Status: **Review: 2025-09-04...2025-09-11**

## Revision history

* **v1** Initial version

## Introduction

In [SF-0009](0009-calendar-recurrence-rule.md) we introduced `Calendar.RecurrenceRule`. With this API, we can find occurences of a recurring event in a given range:

```swift
let birthday   = Date(timeIntervalSince1970: 813283200.0)  // 1995-10-10T00:00:00-0000
let rangeStart = Date(timeIntervalSince1970: 946684800.0)  // 2000-01-01T00:00:00-0000
let rangeEnd   = Date(timeIntervalSince1970: 1293840000.0) // 2011-01-01T00:00:00-0000

let recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .yearly)
for date in recurrence.recurrences(of: birthday, in: rangeStart..<rangeEnd) {
    // All occurrences of `birthday` between 2000 and 2010
}
```

However, enumerating recurrences in a partial range is not supported: the user has to enumerate over a larger range, and discard results that are not necessary:

```swift
for date in recurrence.recurrences(of: birthday) where date >= rangeStart {
    // All occurrences of `birthday` after 2000
}
```

or specify a range that stretches to `Date.distantPast` or `Date.distantFuture`:

```swift
for date in recurrence.recurrences(of: birthday, in: rangeStart..<Date.distantFuture) {
    // All occurrences of `birthday` after 2000
}
```

This proposal adds a method similar to `recurrences` that allows specifying partial ranges.


## Detailed design

```swift
public extension Calendar.RecurrenceRule.End {
    @available(FoundationPreview 6.3, *)
    public func recurrences(of start: Date,
                            in range: PartialRangeThrough<Date>
                            ) -> some (Sequence<Date> & Sendable)
    @available(FoundationPreview 6.3, *)
    public func recurrences(of start: Date,
                            in range: PartialRangeTo<Date>
                            ) -> some (Sequence<Date> & Sendable)
    @available(FoundationPreview 6.3, *)
    public func recurrences(of start: Date,
                            in range: PartialRangeFrom<Date>
                            ) -> some (Sequence<Date> & Sendable)
    @available(FoundationPreview 6.3, *)
    public func recurrences(of start: Date,
                            in range: ClosedRange<Date>
                            ) -> some (Sequence<Date> & Sendable)
}
```


With this, the above example would simply become:

```swift
for date in recurrence.recurrences(of: birthday, in: rangeStart...) {
    // All occurrences of `birthday` after 2000
}
```


## Impact on existing code

None.

## Alternatives considered

This API is a convenience over the workarounds presented in the introduction, but it
is also more performant since we don't calculate dates we don't need in the final range.

For cases where we're looking for recurrences up until a date, it might be tempting to set the `end` property of the recurrence rule to the end of the range:
```swift
recurrence.end = .afterDate(rangeEnd)
```
That is not advised for the recurrence rule might already have an `end` property of `.afterOcurrences()`. Besides, the recurrence rule struct represents when the event occurs, and the range in which we search is does not change that.

We did consider instead only adding one method that accepts a `RangeExpression<Date>` argument. However, that means supporting any arbitrary ranges conforming to the protocol, in which cases we may not have lower and upper bounds that allow us to optimize search.
