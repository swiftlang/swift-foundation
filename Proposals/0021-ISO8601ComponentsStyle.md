# ISO8601 Components Formatting and Parsing

* Proposal: SF-0021
* Author(s): Tony Parker <anthony.parker@apple.com>
* Status: **Review: March 14, 2025...March 21, 2025**
* Intended Release:  _Swift 6.2_
* Review: ([pitch](https://forums.swift.org/t/pitch-iso8601-components-format-style/77990))
*_Related issues_*

* https://github.com/swiftlang/swift-foundation/issues/323
* https://github.com/swiftlang/swift-foundation/issues/967
* https://github.com/swiftlang/swift-foundation/issues/1159

## Revision history

* **v1** Initial version

## Introduction

Based upon feedback from adoption of `ISO8601FormatStyle`, we propose two changes and one addition to the API: 

- Change the behavior of the `includingFractionalSeconds` flag with respect to parsing. `ISO8601FormatStyle` will now always allow fractional seconds regardless of the setting.
- Change the behavior of the time zone flag with respect to parsing. `ISO8601FormatStyle` will now always allow hours-only time zone offsets.
- Add a _components_ style, which formats `DateComponents` into ISO8601 and parses ISO8601-formatted `String`s into `DateComponents`.

## Motivation

The existing `Date.ISO8601FormatStyle` type has one property for controlling fractional seconds, and it is also settable in the initializer. The existing behavior is that parsing _requires_ presence of fractional seconds if set, and _requires_ absence of fractional seconds if not set.

If the caller does not know if the string contains the fractional seconds or not, they are forced to parse the string twice:

```swift
let str = "2022-01-28T15:35:46Z"
var result = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(str)
if result == nil {
    result = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(str)
}
```

In most cases, the caller simply does not care if the fractional seconds are present or not. Therefore, we propose changing the behavior of the parser to **always** allow fractional seconds, regardless of the setting of the `includeFractionalSeconds` flag. The flag is still used for formatting.

With respect to time zone offsets, the parser has always allowed the optional presence of seconds, as well the optional presence of `:`. We propose extending this behavior to allow optional minutes as well. The following are considered well-formed by the parser:

```
2022-01-28T15:35:46 +08
2022-01-28T15:35:46 +0800
2022-01-28T15:35:46 +080000
2022-01-28T15:35:46 +08
2022-01-28T15:35:46 +08:00
2022-01-28T15:35:46 +08:00:00
```

In order to provide an alternative for cases where strict parsing is required, a new parser is provided that returns the _components_ of the parsed date instead of the resolved `Date` itself. This new parser also provides a mechanism to retrieve the time zone from an ISO8601-formatted string. Following parsing of the components, the caller can resolve them into a `Date` using the regular `Calendar` and `DateComponents` API.

## Proposed solution and example

In addition to the behavior change above, we propose introducing a new `DateComponents.ISO8601FormatStyle`. The API surface is nearly identical to `Date.ISO8601FormatStyle`, with the exception of the output type. It reuses the same inner types, and they share a common implementation. The full API surface is in the detailed design, below.

Formatting ISO8601 components is just as straightforward as formatting a `Date`.

```swift
let components = DateComponents(year: 1999, month: 12, day: 31, hour: 23, minute: 59, second: 59)
let formatted = components.formatted(.iso8601Components)
print(formatted) // 1999-12-31T23:59:59Z
```

Parsing ISO8601 components follows the same pattern as other parse strategies:

```swift
let components = try DateComponents.ISO8601FormatStyle().parse("2022-01-28T15:35:46Z")
// components are: DateComponents(timeZone: .gmt, year: 2022, month: 1, day: 28, hour: 15, minute: 35, second: 46))
```

If further conversion to a `Date` is required, the existing `Calendar` API can be used:

```swift
let date = components.date // optional result, date may be invalid
```

## Detailed design

The full API surface of the new style is:

```swift
@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Options for generating and parsing string representations of dates following the ISO 8601 standard.
    public struct ISO8601FormatStyle : Sendable, Codable, Hashable {
        public var timeSeparator: Date.ISO8601FormatStyle.TimeSeparator { get }
        /// If set, fractional seconds will be present in formatted output. Fractional seconds may be present in parsing regardless of the setting of this property.
        public var includingFractionalSeconds: Bool { get }
        public var timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator { get }
        public var dateSeparator: Date.ISO8601FormatStyle.DateSeparator { get }
        public var dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator { get }

        public init(from decoder: any Decoder) throws
        public func encode(to encoder: any Encoder) throws

        public func hash(into hasher: inout Hasher)

        public static func ==(lhs: ISO8601FormatStyle, rhs: ISO8601FormatStyle) -> Bool
        public var timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!

        // The default is the format of RFC 3339 with no fractional seconds: "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        public init(dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon, timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!)
	}
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle {
    public func year() -> Self
    public func weekOfYear() -> Self
    public func month() -> Self
    public func day() -> Self
    public func time(includingFractionalSeconds: Bool) -> Self
    public func timeZone(separator: Date.ISO8601FormatStyle.TimeZoneSeparator) -> Self
    public func dateSeparator(_ separator: Date.ISO8601FormatStyle.DateSeparator) -> Self
    public func dateTimeSeparator(_ separator: Date.ISO8601FormatStyle.DateTimeSeparator) -> Self
    public func timeSeparator(_ separator: Date.ISO8601FormatStyle.TimeSeparator) -> Self
    public func timeZoneSeparator(_ separator: Date.ISO8601FormatStyle.TimeZoneSeparator) -> Self
    }

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : FormatStyle {
    public func format(_ value: DateComponents) -> String
}

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == DateComponents.ISO8601FormatStyle {
    static var iso8601Components: Self
}

@available(FoundationPreview 6.2, *)
public extension ParseableFormatStyle where Self == DateComponents.ISO8601FormatStyle {
    static var iso8601Components: Self
}

@available(FoundationPreview 6.2, *)
public extension ParseStrategy where Self == DateComponents.ISO8601FormatStyle {
    @_disfavoredOverload
    static var iso8601Components: Self
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> DateComponents
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = DateComponents
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: DateComponents)?
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == DateComponents.ISO8601FormatStyle {
    @_disfavoredOverload
    public static var iso8601Components: DateComponents.ISO8601FormatStyle

    public static func iso8601ComponentsWithTimeZone(includingFractionalSeconds: Bool = false, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon, timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator = .omitted) -> Self

    public static func iso8601Components(timeZone: TimeZone, includingFractionalSeconds: Bool = false, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon) -> Self

    public static func iso8601Components(timeZone: TimeZone, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash) -> Self
}
```

Unlike the `Date` format style, formatting with a `DateComponents` style can have a mismatch between the specified output fields and the contents of the `DateComponents` struct. In the case where the input `DateComponents` is missing required values, then the formatter will fill in default values to ensure correct output.

```swift
let components = DateComponents(year: 1999, month: 12, day: 31)
let formatted = components.formatted(.iso8601Components) // 1999-12-31T00:00:00Z
```

## Impact on existing code

The change to always allow fractional seconds will affect existing code. As described above, we believe the improvement in the API surface is worth the risk of introducing unexpected behavior for the rare case that a parser truly needs to specify the exact presence or absence of frational seconds.

If code depending on this new behavior must be backdeployed before Swift 6.2, then Swift's `if #available` checks may be used to parse twice on older releases of the OS or Swift.

## Alternatives considered

### "Allowing" Option

We considered adding a new flag to `Date.ISO8601FormatStyle` to control the optional parsing of fractional seconds. However, the truth table quickly became confusing:

#### Formatting

| `includingFractionalSeconds` | `allowingFractionalSeconds` | Fractional Seconds |
| -- | -- | -- |
| `true` | `true` | Included |
| `true` | `false` | Included |
| `false` | `true` | Excluded |
| `false` | `true` | Excluded |

#### Parsing

| `includingFractionalSeconds` | `allowingFractionalSeconds` | Fractional Seconds |
| -- | -- | -- |
| `true` | `true` | Required Present |
| `true` | `false` | Required Present |
| `false` | `true` | ? |
| `false` | `true` | Allow Present or Missing |

In addition, all the initializers needed to be duplicated to add the new option.

In practice, the additional complexity did not seem worth the tradeoff with the potential for a compatibility issue with the existing style. This does require callers to be aware that the behavior has changed in the release in which this feature ships. Therefore, we will be clear in the documentation about the change.
