#  Additional Configuration Properties for Foundation's `FormatStyle` Implementations

* Proposal: [SF-0002](0002-additional-configuration-properties-for-formatstyle-implementations.md)
* Authors: [Max Obermeier](https://github.com/themomax)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Active review: Jan 4, 2024...Jan 11, 2024**
* Implementation: [apple/swift-foundation#338](https://github.com/apple/swift-foundation/issues/338)
* Review: [Pitch](https://forums.swift.org/t/fou-formatstyle-enhancements/68858)

## Introduction

Foundation defines the `FormatStyle` protocol making it easy to format all kinds of data. However, many of the implementations Foundation provides could offer more customization and do even more to provide access to the configuration after the `FormatStyle` instance has been created. This is critical where the definition of the format and the actual formatting are done in different places or even by different parties.

## Motivation

There are many situations where one only has access to the instance of a `FormatStyle` and is not creating the instance on the spot. Maybe the most important example is the conformance to protocols:

Imagine a UI package that provides a view for rendering a calendar and calendar events. It accepts `FormatStyle`s to configure the way dates are formatted.

```swift
struct CalendarView /* ... */ {
    init<F: FormatStyle>(dateFormat: F, /* ... */) where F.FormatInput == Date, F.FormatOutput == AttributedString
    
    /* ... */
}
```

Instead of requiring the user to configure the `FormatStyle`'s calendar manually, the package wants to define a protocol that allows it to configure the calendar itself (to ensure correctness, or because the view can display different calendars independently of the OS/app calendar):
```swift
protocol CalendarBasedFormatStyle: FormatStyle {
    func calendar(_ calendar: Calendar) -> Self
}
```

The problem is that the UI package cannot implement this protocol for many of Foundation's `FormatStyle` implementations, because they don't expose their calendar property:

```swift
extension Date.AttributedStyle: CalendarBasedFormatStyle {
    func calendar(_ calendar: Calendar) -> Self {
        // there's no way we can implement this because Date.AttributedStyle
        // doesn't expose its base type's calendar
    }
}
```

This, of course, does not only apply to setting the calendar or `Date.AttributedStyle` specifically, but instead, many of Foundation's `FormatStyle` implementations could expose more configuration options and make them accessible after initialization.

## Proposed solution

We extend various format style implementations to expose or add new configuration options.

## Detailed design

### Dynamic Member Lookup for base `Attributed` styles

We already have various `Attributed` derivative `FormatStyle`s, that can be obtained from the `attributed` property of a base `FormatStyle`. However, while we can edit the properties of most base `FormatStyle`s, their `Attributed` variants sometimes neither re-expose their bases' members, nor do they expose the base `FormatStyle` itself. Thus, all those properties can no longer be accessed once the style has been converted to the `attributed` variant.

We thus add a `@dynamicMemberLookup` for existing nested `Attributed` styles that neither expose the base style publicly, nor reproduce its API in a different manner:

```swift
@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle.Attributed {
    public subscript<T>(dynamicMember key: KeyPath<Duration.TimeFormatStyle, T>) -> T { get }
    public subscript<T>(dynamicMember key: WritableKeyPath<Duration.TimeFormatStyle, T>) -> T { get set }
}


@available(FoundationPreview 0.4, *)
extension Duration.UnitsFormatStyle.Attributed {
    public subscript<T>(dynamicMember key: KeyPath<Duration.UnitsFormatStyle, T>) -> T { get }
    public subscript<T>(dynamicMember key: WritableKeyPath<Duration.TimeFormatStyle, T>) -> T { get set }
}

@available(FoundationPreview 0.4, *)
extension Measurement.AttributedStyle {
    public subscript<T>(dynamicMember key: KeyPath<Measurement.FormatStyle, T>) -> T { get }
    public subscript<T>(dynamicMember key: WritableKeyPath<Measurement.FormatStyle, T>) -> T { get set }
}
```

### Allowed fields for `Date.RelativeFormatStyle`

A way to specify that e.g. `.seconds` may not be used. E.g. instead of "in 49 seconds", the output would be "this minute". When using the existing initializer that does not have the `allowedFields` argument, the property is set to include all cases so the current behavior is preserved.

```swift
@available(FoundationPreview 0.4, *)
extension Date.RelativeFormatStyle {
    public typealias Field = Date.ComponentsFormatStyle.Field

    /// The fields that can be used in the formatted output.
    public var allowedFields: Set<Field>

    public init(allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown)
```

### A Grouping option for `Duration.TimeFormatStyle`

A configuration for the grouping for large numbers, e.g. setting the `grouping` to `.never` would yield "10000:00" instead of "10,000:00", which is produced currently.

```swift
@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle {
    /// Returns a modified style that applies the given `grouping` rule to the highest field in the
    /// pattern.
    public func grouping(_ grouping: NumberFormatStyleConfiguration.Grouping) -> Self

    /// The `grouping` rule applied to high number values on the largest field in the pattern.
    public var grouping: NumberFormatStyleConfiguration.Grouping { get set }
}

@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle.Attributed {
    /// Returns a modified style that applies the given `grouping` rule to the highest field in the
    /// pattern.
    public func grouping(_ grouping: NumberFormatStyleConfiguration.Grouping) -> Self
}
```

## Removing symbols from `Date.FormatStyle`

When created, the instance of a `Date.FormatStyle` includes a set of default symbols when formatting a date. One can override this default by specifying symbols manually via the function with the respective symbol's name:

```swift
let style = Date.FormatStyle()
style.format(date)                          // 1/1/1970, 12:00 AM (default)
style.hour().format(date)                   // 12 AM (only shows hour)
```

Previously one could only add more symbols after that. We provide a new `.omitted` case for the relevant symbols which can be used to remove a symbol from the formatted output.

```swift
let style = Date.FormatStyle()
style.format(date)                          // 1/1/1970, 12:00 AM (default)
style.minute(.omitted).format(date)         // 1/1/1970, 12 AM (default - minutes)
```

When all have been removed, `format(_:)` returns an empty string:

```swift
let style = Date.FormatStyle()
style.hour().hour(.omitted).format(date).   //  ("")
```

The following lists the added `omitted` symbols.

```swift
@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Era {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Year {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.YearForWeekOfYear {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.CyclicYear {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Quarter {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Month {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Week {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Day {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.DayOfYear {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Weekday {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.DayPeriod {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Hour {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Minute {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Second {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.SecondFraction {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.TimeZone {
    /// The option for not including the symbol in the formatted output.
    public static var omitted: Self { get }
}
```

### Typed `Date.AttributedStyle`

Since `Date.AttributedStyle` can either be a `Date.FormatStyle` or a `Date.VerbatimFormatStyle` under the hood, we cannot implement the generic dynamic member lookup or expose the base format style in a typed manner.

We deprecate this type and the respective `attributed` properties on `Date.FormatStyle` and `Date.VerbatimFormatStyle`.

```swift
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    @available(macOS, deprecated: 15, introduced: 12, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(iOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(tvOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    @available(watchOS, deprecated: 11, introduced: 8, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
    public struct AttributedStyle : Sendable { /* ... */ }
}

@available(macOS, deprecated: 15, introduced: 12, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(iOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(tvOS, deprecated: 18, introduced: 15, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
@available(watchOS, deprecated: 11, introduced: 8, message: "Use Date.FormatStyle.Attributed or Date.VerbatimFormatStyle.Attributed instead")
extension Date.AttributedStyle : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    public struct VerbatimFormatStyle /* ... */ {
        /* ... */
    
        /// Returns a type erased attributed variant of this style.
        @available(macOS, deprecated: 15, introduced: 12, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 11, introduced: 8, message: "Use attributedStyle instead")
        public var attributed: AttributedStyle { get }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    public struct FormatStyle /* ... */ {
        /* ... */

        /// Returns a type erased attributed variant of this style.
        @available(macOS, deprecated: 15, introduced: 12, message: "Use attributedStyle instead")
        @available(iOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(tvOS, deprecated: 18, introduced: 15, message: "Use attributedStyle instead")
        @available(watchOS, deprecated: 11, introduced: 8, message: "Use attributedStyle instead")
        public var attributed: AttributedStyle { get }
    }
}
```

As a replacement we add typed variants `Date.FormatStyle.Attributed` and `Date.VerbatimFormatStyle.Attributed` along with the respective properties on the base types called `attributedStyle`. Both `Attributed` styles provide dynamic member lookup to their base type.

```swift
@available(FoundationPreview 0.4, *)
extension Date.VerbatimFormatStyle {
    /// The type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    public struct Attributed : FormatStyle, Sendable {
        public subscript<T>(dynamicMember key: KeyPath<Date.VerbatimFormatStyle, T>) -> T { get }

        public subscript<T>(dynamicMember key: WritableKeyPath<Date.VerbatimFormatStyle, T>) -> T { get set }

        public func format(_ value: Date) -> AttributedString

        public func locale(_ locale: Locale) -> Self
    }

    /// Return the type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    public var attributedStyle: Attributed { get }
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle {
    /// The type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    public struct Attributed : FormatStyle, Sendable {
        public subscript<T>(dynamicMember key: KeyPath<Date.FormatStyle, T>) -> T { get }

        public subscript<T>(dynamicMember key: WritableKeyPath<Date.FormatStyle, T>) -> T { get set }

        public func format(_ value: Date) -> AttributedString

        public func locale(_ locale: Locale) -> Self
    }

    /// Return the type preserving attributed variant of this style.
    ///
    /// This style attributes the formatted date with the `AttributeScopes.FoundationAttributes.DateFormatFieldAttribute`.
    public var attributedStyle: Attributed { get }
}
```

`Date.FormatStyle.Attributed` additionally gets the same functions for specifying the symbols as `Date.FormatStyle`:

```swift
@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Attributed {
    /// Change the representation of the era in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func era(_ format: Date.FormatStyle.Symbol.Era = .abbreviated) -> Self

    /// Change the representation of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func year(_ format: Date.FormatStyle.Symbol.Year = .defaultDigits) -> Self
    
    /// Change the representation of the quarter in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func quarter(_ format: Date.FormatStyle.Symbol.Quarter = .abbreviated) -> Self

    /// Change the representation of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func month(_ format: Date.FormatStyle.Symbol.Month = .abbreviated) -> Self

    /// Change the representation of the week in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func week(_ format: Date.FormatStyle.Symbol.Week = .defaultDigits) -> Self

    /// Change the representation of the day of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func day(_ format: Date.FormatStyle.Symbol.Day = .defaultDigits) -> Self

    /// Change the representation of the day of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func dayOfYear(_ format: Date.FormatStyle.Symbol.DayOfYear = .defaultDigits) -> Self

    /// Change the representation of the weekday in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func weekday(_ format: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> Self

    /// Change the representation of the hour in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func hour(_ format: Date.FormatStyle.Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self

    /// Change the representation of the minute in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func minute(_ format: Date.FormatStyle.Symbol.Minute = .defaultDigits) -> Self

    /// Change the representation of the second in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func second(_ format: Date.FormatStyle.Symbol.Second = .defaultDigits) -> Self

    /// Change the representation of the second fraction in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func secondFraction(_ format: Date.FormatStyle.Symbol.SecondFraction) -> Self

    /// Change the representation of the time zone in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func timeZone(_ format: Date.FormatStyle.Symbol.TimeZone = .specificName(.short)) -> Self
}
```

## Source compatibility

All changes are source and ABI compatible. All deprecations are listed under _Detailed design_.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

This proposal consists of minor changes to existing API, but brings no significant new ideas that could be spun further. It thus has no future directions.

## Alternatives considered

### Imperative API for removing symbols from `Date.FormatStyle`

The proposed API for removing symbols from `Date.FormatStyle` (just like the existing API for adding symbols) is designed for declaratively adding or removing the symbols in a convenient way. Specifically, when setting a symbol to anything but `.omitted` right after the style was initialized without specifying any symbols, the resulting style only shows the specified symbol:

```swift
let style = Date.FormatStyle()
style.format(date)                          // 1/1/1970, 12:00 AM (default)
style.minute().format(date)                 // 00 (only shows minute) 
```

While this makes the API very convenient to use, it looks strange when compared to the new `.omitted` case, because omitting a symbol results in more symbols to be used than including the symbol:

```swift
style.minute().format(date)                 // 00 (only shows minute) 
style.minute(.omitted).format(date)         // 1/1/1970, 12 AM (default - minutes)
```

A way out of this dilemma could be an imperative API (e.g. a mutable property for each symbol) that does not provide this magic behavior. However, the declarative API still covers all use cases and the scenarios where the imperative API would be advantageous are so limited they do not justify the additional API surface.

#### Removing symbols from `Date.FormatStyle`: `nil` instead of `.omitted`

Adding a `.omitted` case to the respective `Date.FormatStyle.Symbol` types also influences `Date.VerbatimFormatStyle`. E.g. one can now write the following, which produces an empty string:

```swift
Date.VerbatimFormatStyle(format: "\(day: .omitted)", timeZone: .current, calendar: .current)
```

An alternative would be to make the functions on `Date.FormatStyle` accept an optional of their respective symbol as detailed below. We favor the `.omitted` symbol because it has clear meaning, whereas `nil` always comes with some ambiguity. In this case especially, because many of the functions already have default arguments, and the difference between `style.day()` and `style.day(nil)` is not particularly obvious.

```swift
@available(FoundationPreview 0.4, *)
extension Date.FormatStyle {
    /// Change the representation of the era in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func era(_ format: Symbol.Era? = .abbreviated) -> Self

    /// Change the representation of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func year(_ format: Symbol.Year? = .defaultDigits) -> Self

    /// Change the representation of the quarter in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func quarter(_ format: Symbol.Quarter? = .abbreviated) -> Self

    /// Change the representation of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func month(_ format: Symbol.Month? = .abbreviated) -> Self

    /// Change the representation of the week in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func week(_ format: Symbol.Week? = .defaultDigits) -> Self

    /// Change the representation of the day of the month in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func day(_ format: Symbol.Day? = .defaultDigits) -> Self

    /// Change the representation of the day of the year in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func dayOfYear(_ format: Symbol.DayOfYear? = .defaultDigits) -> Self

    /// Change the representation of the weekday in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func weekday(_ format: Symbol.Weekday? = .abbreviated) -> Self

    /// Change the representation of the hour in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func hour(_ format: Symbol.Hour? = .defaultDigits(amPM: .abbreviated)) -> Self
    /// Change the representation of the minute in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func minute(_ format: Symbol.Minute? = .defaultDigits) -> Self

    /// Change the representation of the second in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func second(_ format: Symbol.Second? = .defaultDigits) -> Self

    /// Change the representation of the second fraction in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func secondFraction(_ format: Symbol.SecondFraction?) -> Self
    
    /// Change the representation of the time zone in the format.
    ///
    /// - Parameter format: Set the symbol representation or pass `nil` to remove it.
    public func timeZone(_ format: Symbol.TimeZone? = .specificName(.short)) -> Self
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
@available(*, deprecated, message: "Use equivalent function with optional argument instead")
extension Date.FormatStyle {
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func era(_ format: Symbol.Era = .abbreviated) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func year(_ format: Symbol.Year = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func quarter(_ format: Symbol.Quarter = .abbreviated) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func month(_ format: Symbol.Month = .abbreviated) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func week(_ format: Symbol.Week = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func day(_ format: Symbol.Day = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func dayOfYear(_ format: Symbol.DayOfYear = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func weekday(_ format: Symbol.Weekday = .abbreviated) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func hour(_ format: Symbol.Hour = .defaultDigits(amPM: .abbreviated)) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func minute(_ format: Symbol.Minute = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func second(_ format: Symbol.Second = .defaultDigits) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func secondFraction(_ format: Symbol.SecondFraction) -> Self
    @available(*, unavailable, message: "Use equivalent function with optional argument instead")
    public func timeZone(_ format: Symbol.TimeZone = .specificName(.short)) -> Self
}
```

#### Removing symbols from `Date.FormatStyle`: `.remove(_:)` function

One could imagine having a `remove(_:)` or `removing(_:)` function that one can pass a calendar field to and which returns the modified style. However, the current API is declarative, where each function should be imagined as the setter for the styling of the respective calendar field. In this mental model, just allowing to pass `.omitted` to the setter feels more natural than having a `remove(x)` function that mutates the property representing the style of `x`.

### Exposing non-attributed base of `Date.AttributedStyle` as an untyped `FormatStyle`

Instead of deprecating `Date.AttributedStyle`, we could provide read-only access to the underlying base style as `any FormatStyle`.

However, in most scenarios, developers need access to the base style in order to _modify_ the style, not to obtain an unattributed version. To do so, developers would have to manually assert for all possible types in which they are not aided by the compiler. Deprecating `Date.AttributedStyle` and introducing typed variants for the two base types also has another benefit. It allows developers to conform one attributed style to a protocol but not the other, which is a reasonable scenario given that the base types' API surfaces are very different.

### Grouping option for `Duration.TimeFormatStyle` as part of the pattern initializer functions

Ultimately the grouping is orthogonal to the pattern. A solution where the grouping is part of the pattern would duplicate a lot of code as can be seen below.

```swift
@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle.Pattern {
    /// Displays a duration in terms of hours and minutes with the specified configurations.
    /// - Parameters:
    ///   - padHourToLength: Padding for the hour field. For example, one hour is formatted as "01:00" in en_US locale when this value is set to 2.
    ///   - roundSeconds: Rounding rule for the remaining second values.
    ///   - grouping: Grouping rule for high hour values.
    /// - Returns: A pattern to format a duration with.
    public static func hourMinute(padHourToLength: Int,
                                  roundSeconds: FloatingPointRoundingRule = .toNearestOrEven,
                                  grouping: NumberFormatStyleConfiguration.Grouping) -> Self

    /// Displays a duration in terms of hours, minutes, and seconds with the specified configurations.
    ///   - padHourToLength: Padding for the hour field. For example, one hour is formatted as "01:00:00" in en_US locale when this value is set to 2.
    ///   - fractionalSecondsLength: The length of the fractional seconds. For example, one hour is formatted as "1:00:00.00" in en_US locale when this value is set to 2.
    ///   - roundFractionalSeconds: Rounding rule for the fractional second values.
    ///   - grouping: Grouping rule for high hour values.
    /// - Returns: A pattern to format a duration with.
    public static func hourMinuteSecond(padHourToLength: Int,
                                        fractionalSecondsLength: Int = 0,
                                        roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven,
                                        grouping: NumberFormatStyleConfiguration.Grouping) -> Self


    /// Displays a duration in minutes and seconds with the specified configurations.
    /// - Parameters:
    ///   - padMinuteToLength: Padding for the minute field. For example, five minutes is formatted as "05:00" in en_US locale when this value is set to 2.
    ///   - fractionalSecondsLength: The length of the fractional seconds. For example, one hour is formatted as "1:00:00.00" in en_US locale when this value is set to 2.
    ///   - roundFractionalSeconds: Rounding rule for the fractional second values.
    ///   - grouping: Grouping rule for high minute values.
    /// - Returns: A pattern to format a duration with.
    public static func minuteSecond(padMinuteToLength: Int,
                                    fractionalSecondsLength: Int = 0,
                                    roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven,
                                    grouping: NumberFormatStyleConfiguration.Grouping) -> Self
}
```

## Acknowledgments

Thanks to [@parkera](https://github.com/parkera), [@spanage](https://github.com/spanage), and [@itingliu](https://github.com/itingliu) for helping me shape this API and polish the proposal.