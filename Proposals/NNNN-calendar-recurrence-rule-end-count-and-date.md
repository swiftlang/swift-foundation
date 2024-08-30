# Extending `Calendar.RecurrenceRule.End`


* Proposal: SF-NNNN
* Author(s): Hristo Staykov <hstaykov@apple.com>
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Active review**
* Bugs: <rdar://134294130>
* Implementation: [apple/swift-foundation#888](https://github.com/apple/swift-foundation/pull/888)
* Previous Proposal: [SF-0009](0009-calendar-recurrence-rule.md)

## Revision history

* **v1** Initial version

## Introduction

In [SF-0009](0009-calendar-recurrence-rule.md) we introduced Calendar.RecurrenceRule API. In this API, we represent the end of a recurrence rule with the struct `Calendar.RecurrenceRule.End`:

```swift
/// When a recurring event stops recurring
public struct End: Sendable, Equatable {
    /// The event stops repeating after a given number of times
    /// - Parameter count: how many times to repeat the event, including
    ///                    the first occurrence. `count` must be greater
    ///                    than `0`
    public static func afterOccurrences(_ count: Int) -> Self
    /// The event stops repeating after a given date
    /// - Parameter date: the date on which the event may last occur. No
    ///                   further occurrences will be found after that
    public static func afterDate(_ date: Date) -> Self
    /// The event repeats indefinitely
    public static var never: Self
    
}
```

This is de-facto an enum, but it was declared as struct to be future-proof. However, the original API only allowed construction of the recurrence rule end, but does not allow any introspection afterwards. This proposal adds a few properties to `Calendar.RecurrenceRule.End` to remedy this.

## Detailed design

```swift
public extension Calendar.RecurrenceRule.End {
    /// At most many times the event may occur
    /// This value is set when the struct was initialized with `.afterOccurrences()`
    @available(FoundationPreview 6.0.2, *)
    public var count: Int? { get }

    /// The latest date when the event may occur
    /// This value is set when the struct was initialized with `.afterDate()`
    @available(FoundationPreview 6.0.2, *)
    public var date: Date? { get }
}
```

## Impact on existing code

None.
