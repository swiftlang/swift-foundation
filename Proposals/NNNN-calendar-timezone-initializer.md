# Calendar initializer with time zone, locale, first weekday, and minimum days in first week

* Proposal: [SF-NNNN](NNNN-calendar-timezone-initializer.md)
* Authors: [Kiel Gillard](https://github.com/kielgillard)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/NNNNN)
* Review: ([discussion](https://forums.swift.org/t/expressively-initialising-calendars-for-specific-time-zones), [pitch](https://forums.swift.org))

## Introduction

Add a  `Calendar` initializer that accepts a `TimeZone` and optional `Locale`, `firstWeekday`, and `minimumDaysInFirstWeek` values, allowing developers to expressively and efficiently initialize a fully configured calendar in a single expression.

## Motivation

Presently, if we want a `Calendar` with non-default time zone, locale, first weekday, or minimum days in first week values, we have to initialize the calendar with its identifier and then set its properties, one after the other:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
calendar.locale = Locale(identifier: "en_AU")
calendar.firstWeekday = 2
```

Some observations about this code:

- The calendar must be declared as mutable even when the developer's intent is as an immutable value, undermining intuitions and creating unneccessary friction when trying to read and reason about some code.
- Internally, setting each property results in the initialization of a new underlying calendar storage object, resulting in wasted work when the next property is assigned.
- Date computations depend on the combination of time zone, locale, first weekday, and the minimum days in first week. Setting these one property at a time permits transient intermediate states that do not reflect the intended configuration.

## Proposed solution

Add a new public initializer to `Calendar`:

```swift
    /// Returns a new Calendar using a specific time zone and optional, non-default values.
    ///
    /// - parameter identifier: The kind of calendar to use.
    /// - parameter timeZone: The `TimeZone` to use.
    /// - parameter locale: A `Locale` to use, instead of the default.
    /// - parameter firstWeekday: A first day of the week to use, instead of the default.
    /// - parameter minimumDaysInFirstWeek: A number of minimum days in the first week to use, instead of the default.
    public init(identifier: __shared Identifier, timeZone: TimeZone, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil)
```

With this initializer, the motivating example above collapses to a single expression and allows the developer to convey the constancy of this calendar's specific value within some scope:

```swift
let calendar = Calendar(
    identifier: .gregorian,
    timeZone: TimeZone(identifier: "Australia/Sydney")!,
    locale: Locale(identifier: "en_AU"),
    firstWeekday: 2
)
```

## Detailed design

The new initializer is defined as:

```swift
public init(
    identifier: __shared Identifier,
    timeZone: TimeZone,
    locale: Locale? = nil,
    firstWeekday: Int? = nil,
    minimumDaysInFirstWeek: Int? = nil
)
```

The initializer accepts a value for every publicly settable property of `Calendar` that affects calendrical computations.

The `timeZone` parameter is required to differentiate this initializer with the existing `init(identifier:)`.

Internally, the initializer sets the values for the properties at once, avoiding the repeated initialization of the underlying calendar storage when setting properties one after the other.

When `locale`, `firstWeekday`, or `minimumDaysInFirstWeek` are `nil`, the resulting calendar uses the same default values for those corresponding properties as `init(identifier:)`.

## Source compatibility

This proposal is purely additive and merely introduces a new initializer. Existing use of `Calendar.init(identifier:)` is unchanged. The new initializer is distinguished by the required `timeZone:` value.

## Implications on adoption

The new initializer can be freely adopted in source code. Because it is additive, adopting it in a library does not affect source or ABI compatibility for users of that library. The feature can be un-adopted later (by falling back to the identifier-only initializer setting properties serially) without source-breaking changes.

In general, initializers cannot be back-deployed using `@backDeployed`. Even if they could be, the new initializer uses types and functions internal to Foundation to avoid the wasted initialization of calendar storage objects, and internal types and functions cannot be used in back-deployment. 

## Future directions

None.

## Alternatives considered

### Keep the status quo

Developers can continue setting properties on calendar objects, one after the other. However, this fails to address the expressiveness and efficiency value this proposal seeks to add.

Alternatively, developers could provide the expressiveness for themselves by extending `Calendar`  with an initializer that sets the properties on the calendar, one by one. This  alternative fails to address the minor efficiency value of the proposal. Also, in smaller codebases this could be acceptable, but across larger codebases developers would have to either add it to a "Foundation additions" themed dependency, or re-implement it multiple times. Neither is a particularly convenient developer experience.

### Make `timeZone` optional as well

An alternative shape would make every parameter after `identifier` optional:

```swift
public init(
    identifier: Identifier,
    timeZone: TimeZone? = nil,
    locale: Locale? = nil,
    firstWeekday: Int? = nil,
    minimumDaysInFirstWeek: Int? = nil
)
```

Having both initializers would create an ambiguity between that and the existing `init(identifier:)` . To avoid a second initializer, we could instead propose modifying `init(identifier:)`  to include the optional parameters in a way that both avoids source breaking changes and caters for the hot path the calendar storage cache optimizes for:

```swift
public init(identifier: __shared Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil) {
    guard timeZone != nil || locale != nil || firstWeekday != nil || minimumDaysInFirstWeek != nil else {
        _calendar = CalendarCache.cache.fixed(identifier)
        return
    }
    let calendarClass = _calendarClass(identifier: identifier)!
    _calendar = calendarClass.init(identifier: identifier, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
}
```

This is quite a subtle implementation that could be a source of bugs for future maintainers. But more seriously, while it is not source breaking, it is certainly an ABI breaking change.

We recommend developers choose the simplest initializer that suits best the intended use of the calendar.

## Acknowledgments

Thanks to those who participated in the discussion and code review for such a small change.