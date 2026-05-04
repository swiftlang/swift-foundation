# Calendar initializer with time zone, locale, first weekday, and minimum days in first week

* Proposal: [SF-NNNN](NNNN-calendar-timezone-initializer.md)
* Authors: [Kiel Gillard](https://github.com/kielgillard)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/NNNNN)
* Review: ([discussion](https://forums.swift.org/t/expressively-initialising-calendars-for-specific-time-zones), [pitch](https://forums.swift.org))

## Introduction

Add a `Calendar` initializer that accepts optional `timeZone`, `locale`, `firstWeekday`, and `minimumDaysInFirstWeek` values, allowing developers to expressively and efficiently initialize a fully configured calendar in a single expression.

## Motivation

Today, if we want a `Calendar` with non-default `timeZone`, `locale`, `firstWeekday`, or `minimumDaysInFirstWeek` values, we have to initialize the calendar with its identifier and then set its properties, one after the other:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
calendar.locale = Locale(identifier: "en_AU")
calendar.firstWeekday = 2
```

Some observations about this code:

- The calendar must be declared as mutable even when the developer's intent is to use it as an immutable value, undermining intuitions and creating unnecessary friction when trying to read and reason about code.
- Internally, setting each property results in the initialization of a new underlying calendar storage object, resulting in wasted work when the next property is assigned.
- Date computations depend on the combination of `timeZone`, `locale`, `firstWeekday`, and `minimumDaysInFirstWeek`. Setting these one property at a time permits transient intermediate states that do not reflect the intended configuration.

Developers need to specifically configure calendars for features in applications to do with booking reservations, travel planning, workforce scheduling, project management, financial transactions, clocks, alarms and more. This also includes writing tests for those features. In these cases, it is quite likely the default values are not the right values to use.

## Proposed solution

Add a new public initializer to `Calendar`:

```swift
/// Returns a new Calendar using optional, non-default values.
///
/// - parameter identifier: The kind of calendar to use.
/// - parameter timeZone: A `TimeZone` to use, instead of the default.
/// - parameter locale: A `Locale` to use, instead of the default.
/// - parameter firstWeekday: The first day of the week to use, instead of the default.
/// - parameter minimumDaysInFirstWeek: The minimum number of days in the first week to use, instead of the default.
public init(identifier: Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil)
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

The initializer is responsible for accepting a value for every publicly settable property of `Calendar` that affects calendrical computations. In this proposal, it happens to be — but is not required to be — a member-wise initializer.

Internally, the initializer sets all properties at once, avoiding the repeated initialization of the underlying calendar storage that occurs when setting properties one after the other.

When `timeZone`, `locale`, `firstWeekday`, or `minimumDaysInFirstWeek` are `nil`, the resulting calendar uses the same default values for those properties as `init(identifier:)`.

## Source compatibility

This proposal is purely additive and merely introduces a new initializer. Existing use of `Calendar.init(identifier:)` is unchanged.

Side by side, the two initializers have overlapping shapes:
```swift
init(identifier: Identifier) // existing
init(identifier: Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil) // new
```

When `timeZone`, `locale`, `firstWeekday`, or `minimumDaysInFirstWeek` are `nil`, which initializer does the compiler choose, as in the following code?
```swift
let calendar = Calendar(identifier: .gregorian)
```

The compiler uses the existing initializer.

## Implications on adoption

The new initializer can be freely adopted in source code. Because it is additive, adopting it in Foundation does not affect source or ABI compatibility. The feature can be un-adopted later (by falling back to the identifier-only initializer and setting properties serially) without source-breaking changes.

In general, initializers cannot be back-deployed using `@backDeployed`. Even if they could be, the new initializer uses types and functions internal to Foundation to avoid the wasted initialization of calendar storage objects, and internal types and functions cannot be used in back-deployment.

### Maintaining the initializer and ABI stability
As stated above, this initializer is responsible for accepting a value for every publicly settable property of `Calendar` that affects calendrical computations. The proposal presents it as a member-wise initializer, though that is coincidental and not required.

So what happens if a public property affecting calendrical computations is added or deprecated? To put the question another way, how can the initializer maintain its responsibility without ABI-breaking changes? There are a few answers to this question.

First, Foundation could multiply initializers, introducing new initializers that accept values for those properties alongside the existing ones.

For a contrived example, let us say `Calendar` gains the public property `observerSite` for computing hours, days, years, etc. on Earth or the moon:
```swift
public var observerSite: Calendar.ObserverSite // .earth, .lunar
```

Clearly, this new property affects calendrical computations. We propose there would exist an intuition or presumption that a value for `observerSite` could be accepted when initializing a `Calendar` for specifically computing moments on a non-default site, like the moon:
```swift
public init(identifier: __shared Identifier, timeZone: TimeZone? = nil, locale: Locale? = nil, firstWeekday: Int? = nil, minimumDaysInFirstWeek: Int? = nil, observerSite: ObserverSite? = nil)
```

It would be an ABI-breaking change to add this new property to the existing initializer, so to support that intuition, Foundation could offer a whole new initializer.

For another example, let us say `Calendar` no longer requires the `minimumDaysInFirstWeek` property, and Foundation moves to deprecate it. Clearly, it too is a property affecting calendrical computations. Also, it would be an ABI-breaking change to remove a value for this property from the existing initializer, so Foundation would also need to deprecate the existing initializer, and introduce a new initializer without a value for the deprecated property.

Multiplying initializers is the first answer to the question. A second answer is to accept the risk the initializer cannot maintain this responsibility under ABI constraints, since maintaining a family of initializers is messy. We could justify this approach for several reasons:

First, the probability of adding or removing properties that affect calendrical computations is small. `Calendar` and `NSCalendar` have served developers well for many years, and the APIs affecting calendrical computations have changed little. So we do not reasonably expect the shape of the initializer to change.

Second, even if Foundation needed to add such a property, it is likely to be so exotic that the vast majority of use cases would settle for the default, and the loss of expressivity would be an acceptable trade-off compared to maintaining a family of initializers.

Third, there is precedent. `DateComponents` gained a `dayOfYear` property, but the `DateComponents` initializer did not gain a parameter for it. Developers cannot expressively initialize a `DateComponents` object with a `dayOfYear` value, and have to set it in a separate step. This precedent was accepted before; perhaps we can accept it now.

Fourth, in the unlikely situation that a property is deprecated, Foundation could either keep the initializer (retaining the deprecated parameter with a default value but ignoring it), or deprecate the initializer and introduce a new one without a value for the deprecated property.

To answer the question, we propose that the unfortunate risk of it failing to maintain this responsibility is small and acceptable, for the reasons outlined above. There is, however, a third answer below, in the "Alternatives considered" section.

## Future directions

None.

## Alternatives considered

### Keep the status quo

Developers can continue setting properties on calendar objects, one after the other. However, this fails to address the expressiveness and efficiency benefits this proposal seeks to add.

Developers could provide the expressiveness for themselves by extending `Calendar` with an initializer that sets the properties on the calendar, one by one. This alternative fails to address the efficiency benefit of the proposal. Also, in smaller codebases this could be acceptable, but across larger codebases developers would have to either add it to a shared "Foundation additions" library, or re-implement it multiple times. Neither is a particularly convenient developer experience.

### Initializing a `Calendar` with a `Calendar.Configuration` value

In the "Implications on adoption" section above, this question was posed: without ABI-breaking changes, how can the initializer maintain its responsibility for accepting a value for every publicly settable property of `Calendar` that affects calendrical computations?  We proposed that the risk of it failing to maintain this responsibility is small and acceptable compared to alternative of multiplying initializers. However, there is another answer.

An alternative design introduces a nested `Calendar.Configuration` value type responsible for describing a calendar's configuration, and a single new initializer `Calendar.init(_ configuration: Configuration)` accepting a configuration value. Configurations are composed via chained methods that return a modified copy. For example:

```swift
public struct Calendar {
    public struct Configuration: Hashable, Sendable {
        public static func identifier(_ identifier: Identifier) -> Self
        public static var iso8601: Self { get }
        public static var current: Self { get }
        public static var autoupdatingCurrent: Self { get }

        public func identifier(_ identifier: Identifier) -> Self
        public func locale(_ locale: Locale?) -> Self
        public func timeZone(_ timeZone: TimeZone?) -> Self
        public func firstWeekday(_ firstWeekday: Int?) -> Self
        public func minimumDaysInFirstWeek(_ minimumDaysInFirstWeek: Int?) -> Self
    }

    public init(_ configuration: Configuration)
}
```

The motivating example becomes:

```swift
let calendar = Calendar(
    .identifier(.gregorian)
    .timeZone(TimeZone(identifier: "Australia/Sydney"))
    .locale(Locale(identifier: "en_AU"))
    .firstWeekday(2)
)
```

It also unlocks a unified, extensible, and expressive means for developers to initialize a calendar:

```swift
let current = Calendar(.current)
let autoupdatingCurrent = Calendar(.autoupdatingCurrent)
let gregorian = Calendar(.identifier(.gregorian))

extension Calendar.Configuration {
    static var sydneyAustralia: Self {
        Self.identifier(.gregorian)
            .locale(Locale(identifier: "en_AU"))
            .timeZone(TimeZone(identifier: "Australia/Sydney"))
    }
}

let sydney = Calendar(.sydneyAustralia)

extension Calendar.Configuration {
    /// Conveniently construct time zone objects from an IANA identifier.
    static func timeZone(_ identifier: String) -> Self {
        self.timeZone(TimeZone(identifier: identifier))
    }
    /// … one for Locale by identifier …
}

let calendar = Calendar(
    .identifier(.gregorian)
    .timeZone("Australia/Sydney")
    .locale("en_AU")
    .firstWeekday(2)
)
```

We find this design to be appealing:

- It is open to extension: adding a new property affecting calendrical computations only requires adding one method on `Configuration`, rather than introducing a new initializer overload. Importantly, this avoids the complexity of reshaping or multiplying the initializer API, as described above.
- It unifies creation of fixed-identifier, `.current`, `.autoupdatingCurrent`, and specifically configured calendars behind a single initializer.
- The *Fluent* (or "values in chains") style is increasingly familiar, resembling concrete `FormatStyle` types in Foundation.
- A `Configuration` value is independently useful for developers who want to describe a calendar without instantiating one, or use the configuration as a key for a cache, in the same way Foundation uses a `Date.FormatStyle` value is used as a key to cache date formatters.

This design also has some mild disadvantages:

- It invites duplication of existing API surface area (e.g., there would be two ways of accessing the current calendar, which is potentially confusing).
- As a means of initializing an object, "values in chains" are less idiomatic or conventional Swift than labeled arguments.
- The extensibility benefit is modest in practice. As noted above, `Calendar`'s configuration surface has changed little over many years; the weight of the design may not be sufficiently compelling for a form of extension that is unlikely to be needed.
- The solution is heavier: one new type, four static and five instance methods, and one initializer — to solve the same problem that a single initializer arguably addresses.

We are very open to pursuing this alternate direction, should the community find it compelling or desirable.

## Acknowledgments

Thanks to those who participated in the discussion and code review. In particular, [tera](https://forums.swift.org/t/expressively-initialising-calendars-for-specific-time-zones/86139/9) for thoughtful comments and suggesting the "values in chains" alternative.