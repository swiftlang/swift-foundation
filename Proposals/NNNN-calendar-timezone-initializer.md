# Calendar initializer with time zone, locale, first weekday, and minimum days in first week

* Proposal: [SF-NNNN](NNNN-calendar-timezone-initializer.md)
* Authors: [Kiel Gillard](https://github.com/kielgillard)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/NNNNN)
* Review: ([discussion](https://forums.swift.org/t/expressively-initialising-calendars-for-specific-time-zones), [pitch](https://forums.swift.org))

## Introduction

Add a `Calendar` initializer that accepts optional `TimeZone`, `Locale`, `firstWeekday`, and `minimumDaysInFirstWeek` values, allowing developers to expressively and efficiently initialize a fully configured calendar in a single expression.

## Motivation

Today, if we want a `Calendar` with non-default time zone, locale, first weekday, or minimum days in first week values, we have to initialize the calendar with its identifier and then set its properties, one after the other:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
calendar.locale = Locale(identifier: "en_AU")
calendar.firstWeekday = 2
```

Some observations about this code:

- The calendar must be declared as mutable even when the developer's intent is to use it as an immutable value, undermining intuitions and creating unnecessary friction when trying to read and reason about some code.
- Internally, setting each property results in the initialization of a new underlying calendar storage object, resulting in wasted work when the next property is assigned.
- Date computations depend on the combination of time zone, locale, first weekday, and the minimum days in first week. Setting these one property at a time permits transient intermediate states that do not reflect the intended configuration.

## Proposed solution

Add a new public initializer to `Calendar`:

```swift
    /// Returns a new Calendar using optional, non-default values.
    ///
    /// - parameter identifier: The kind of calendar to use.
    /// - parameter timeZone: A `TimeZone` to use, instead of the default.
    /// - parameter locale: A `Locale` to use, instead of the default.
    /// - parameter firstWeekday: A first day of the week to use, instead of the default.
    /// - parameter minimumDaysInFirstWeek: A number of minimum days in the first week to use, instead of the default.
    public init(identifier: __shared Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil)
```

With this initializer, the motivating example above collapses to a single expression, letting the developer declare the calendar as a constant in scope:

```swift
let calendar = Calendar(
    identifier: .gregorian,
    timeZone: TimeZone(identifier: "Australia/Sydney"),
    locale: Locale(identifier: "en_AU"),
    firstWeekday: 2
)
```

## Detailed design

The new initializer is defined as:

```swift
public init(
    identifier: __shared Identifier,
    timeZone: TimeZone? = nil,
    locale: Locale? = nil,
    firstWeekday: Int? = nil,
    minimumDaysInFirstWeek: Int? = nil
)
```

The initializer is responsible for accepting a value for every publicly settable property of `Calendar` that affects calendrical computations. Presently, it is practically — but not necessarily — a member-wise initializer.

Internally, the initializer sets the values for the properties at once, avoiding the repeated initialization of the underlying calendar storage when setting properties one after the other.

When `timeZone`, `locale`, `firstWeekday`, or `minimumDaysInFirstWeek` are `nil`, the resulting calendar uses the same default values for those corresponding properties as `init(identifier:)`.

## Source compatibility

This proposal is purely additive and merely introduces a new initializer. Existing use of `Calendar.init(identifier:)` is unchanged.

When viewed alongside each other, these two initializers have an overlapping shape:
```swift
init(identifier: __shared Identifier) // existing
init(identifier: __shared Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil) // new
```

Specifically, which initializer is called in the following code, since the `timeZone`, `locale`, etc. arguments are omitted?
```swift
let calendar = Calendar(identifier: .gregorian)
```

The compiler uses the existing initializer.

## Implications on adoption

The new initializer can be freely adopted in source code. Because it is additive, adopting it in a library does not affect source or ABI compatibility for users of that library. The feature can be un-adopted later (by falling back to the identifier-only initializer and setting properties serially) without source-breaking changes.

In general, initializers cannot be back-deployed using `@backDeployed`. Even if they could be, the new initializer uses types and functions internal to Foundation to avoid the wasted initialization of calendar storage objects, and internal types and functions cannot be used in back-deployment.

As stated above, this initializer is responsible for accepting a value for every publicly settable property of `Calendar` that affects calendrical computations. Today, it is practically — but not necessarily — a member-wise initializer. This proposal therefore introduces an implicit presumption: when a new public property affecting calendrical computations is added, a corresponding initializer accepting that property (alongside the existing ones) would be introduced at the same time.

For a contrived example, let us say `Calendar` gains the public property `observerSite` for computing hours, days, years, etc. on Earth or the moon:
```swift
public var observerSite: Calendar.ObserverSite // .earth, .lunar
```

Clearly, this new property affects calendrical computations. We propose there would exist a presumption that a value for `observerSite` could be accepted when initializing a `Calendar` for specifically computing moments on a non-default site, like the moon:
```swift
public init(identifier: __shared Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil, observerSite: ObserverSite? = nil)
```

We consider the concerns about this implication small. `Calendar` and `NSCalendar` have served developers well for many years, and the APIs affecting calendrical computations have changed little. Even if a new property were introduced, perpetuating the responsibility of this initializer (again, to accept a value for every property affecting calendrical computations) carries no source- or ABI-breaking risk.

## Future directions

None.

## Alternatives considered

### Keep the status quo

Developers can continue setting properties on calendar objects, one after the other. However, this fails to address the expressiveness and efficiency value this proposal seeks to add.

Alternatively, developers could provide the expressiveness for themselves by extending `Calendar` with an initializer that sets the properties on the calendar, one by one. This alternative fails to address the minor efficiency value of the proposal. Also, in smaller codebases this could be acceptable, but across larger codebases developers would have to either add it to a "Foundation additions" themed dependency, or re-implement it multiple times. Neither is a particularly convenient developer experience.

## Acknowledgments

Thanks to those who participated in the discussion and code review for such a small change.