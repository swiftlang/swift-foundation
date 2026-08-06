# HTTP Date Format

* Proposal: [SF-0016](0016-http-date-format.md)
* Authors: [Cory Benfield](https://github.com/Lukasa), [Tobias](https://github.com/t089), [Tony Parker](https://github.com/parkera)
* Review Manager: [Tina L](https://github.com/itingliu)
* Status: **Accepted**
* Review: ([Pitch](https://forums.swift.org/t/pitch-http-date-format-style/76783)) 
* Implementation: [swiftlang/swift-foundation#1127](https://github.com/swiftlang/swift-foundation/pull/1127)

## Introduction

The HTTP specification [requires that all HTTP servers send a `Date` header field](https://www.rfc-editor.org/rfc/rfc9110.html#field.date) that contains the date and time at which a message was originated in a [specific format](https://www.rfc-editor.org/rfc/rfc9110.html#http.date). This proposal adds support to `FoundationEssentials` to generate this "HTTP" date format and to parse it from a `String`.

## Motivation

The HTTP date format is used throughout HTTP to represent instants in time. The format is specified entirely in [RFC 9110 § 5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#http.date). The format is simple and static, emitting a textual representation in the UTC time zone.

This format is used frequently across the web. Providing a high-performance and standard implementation of this transformation for Swift will enable developers on both the client and the server to easily handle this header format.

## Proposed solution

We propose to add two additional format styles to `FoundationEssentials` . This formatter would follow the API shape of `ISO8601FormatStyle`.  The two styles are:

| Name | Input | Output |
| ---- | ----- | ------ |
| Date.HTTPFormatStyle | String | Date |
| DateComponents.HTTPFormatStyle | String | DateComponents |

Both styles allow formatting (creating a `String`) and parsing (taking a `String`).

A principal design goal is to ensure that it is very cheap to parse and serialize these header formats. Thefore, the implementation is focused on performance and safety.

## Detailed design

The parser requires the presence of all fields, with the exception of the weekday. If the weekday is present, then it is validated as being one of the specified values (for example, `Mon`, `Tue`, etc.), but is ignored for purposes of creating the actual `Date`. For the hour, minute, and second fields, the parser validates the values are within the ranges defined in the spec. Foundation does not support leap seconds, so values of 60 for the seconds field are set to 0 instead.

### Date parsing

`Date.HTTPFormatStyle` will add the following new API surface:

```swift
@available(FoundationPreview 6.2, *)
extension Date {
    /// Options for generating and parsing string representations of dates following the HTTP date format
    /// from [RFC 9110 § 5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#http.date).
    public struct HTTPFormatStyle : Sendable, Hashable, Codable {
        public init()
        public init(from decoder: any Decoder) throws
        public func encode(to encoder: any Encoder) throws
        public func hash(into hasher: inout Hasher)
        public static func ==(lhs: HTTPFormatStyle, rhs: HTTPFormatStyle) -> Bool
    }
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : FormatStyle {
    public typealias FormatInput = Date
    public typealias FormatOutput = String
    public func format(_ value: Date) -> String
}

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == Date.HTTPFormatStyle {
    static var http: Self
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> Date
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self
}

@available(FoundationPreview 6.2, *)
extension ParseableFormatStyle where Self == Date.HTTPFormatStyle {
    public static var http: Self
}

@available(FoundationPreview 6.2, *)
extension ParseStrategy where Self == Date.HTTPFormatStyle {
    public static var http: Self
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)?
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == Date.HTTPFormatStyle {
    /// Creates a regex component to match a RFC 9110 HTTP date and time, such as "Sun, 06 Nov 1994 08:49:37 GMT", and capture the string as a `Date`.
    public static var http: Date.HTTPFormatStyle
}
```

#### DateComponents parsing

The components based parser is useful if the caller wishes to know each value in the string. The time zone of the result is set to `.gmt`, per the spec. The components can be converted into a `Date` using the following code, if desired:

```swift
let parsed = try? DateComponents(myString, strategy: .http) // type is DateComponents?
let date = Calendar(identifier: .gregorian).date(from: parsed) // type is Date?
```

`DateComponents.HTTPFormatStyle` will add the following new API surface:

```swift
@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Options for generating and parsing string representations of dates following the HTTP date format
    /// from [RFC 9110 § 5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#http.date).
    public struct HTTPFormatStyle : Sendable, Hashable, Codable {
        public init()
        public init(from decoder: any Decoder) throws
        public func encode(to encoder: any Encoder) throws
        public func hash(into hasher: inout Hasher)
        public static func ==(lhs: HTTPFormatStyle, rhs: HTTPFormatStyle) -> Bool
    }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : FormatStyle {
    public typealias FormatInput = DateComponents
    public typealias FormatOutput = String
    public func format(_ value: DateComponents) -> String
}

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == DateComponents.HTTPFormatStyle {
    static var httpComponents: Self
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> DateComponents
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self
}

@available(FoundationPreview 6.2, *)
extension ParseableFormatStyle where Self == DateComponents.HTTPFormatStyle {
    public static var httpComponents: Self
}

@available(FoundationPreview 6.2, *)
extension ParseStrategy where Self == DateComponents.HTTPFormatStyle {
    public static var httpComponents: Self
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = DateComponents
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: DateComponents)?
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == DateComponents.HTTPFormatStyle {
    /// Creates a regex component to match a RFC 9110 HTTP date and time, such as "Sun, 06 Nov 1994 08:49:37 GMT", and capture the string as a `DateComponents`.
    public static var httpComponents: DateComponents.HTTPFormatStyle
}
```

The extensions on the protocols must use a different name for the `DateComponents` and `Date` versions in order to ambiguity when the return type is not specified, such is in `Regex`'s builder syntax.

### DateComponents Additions

The `DateComponents.HTTPDateFormatStyle` type is the first `FormatStyle` for `DateComponents`. Therefore, a few additions are also needed to the `DateComponents` type as well to allow formatting it directly. These are identical to the existing methods on other formatted types, including `Date`.

```swift
@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Converts `self` to its textual representation.
    /// - Parameter format: The format for formatting `self`.
    /// - Returns: A representation of `self` using the given `format`. The type of the representation is specified by `FormatStyle.FormatOutput`.
    public func formatted<F: FormatStyle>(_ format: F) -> F.FormatOutput where F.FormatInput == DateComponents
    
    // Parsing
    /// Creates a new `Date` by parsing the given representation.
    /// - Parameter value: A representation of a date. The type of the representation is specified by `ParseStrategy.ParseInput`.
    /// - Parameters:
    ///   - value: A representation of a date. The type of the representation is specified by `ParseStrategy.ParseInput`.
    ///   - strategy: The parse strategy to parse `value` whose `ParseOutput` is `DateComponents`.
    public init<T: ParseStrategy>(_ value: T.ParseInput, strategy: T) throws where T.ParseOutput == Self {

    /// Creates a new `DateComponents` by parsing the given string representation.
    @_disfavoredOverload
    public init<T: ParseStrategy, Value: StringProtocol>(_ value: Value, strategy: T) throws where T.ParseOutput == Self, T.ParseInput == String
}
```

### Detecting incorrect components

For fields like the weekday, day number and year number, the style will make a best effort at parsing a sensible date out of the values in the string. If the caller wishes to validate the result matches the values found in the string, they can use the `DateComponents` parser, generate the date, then validate the weekday of the result versus the value of the `weekday` field. See _Validating the weekday_ in the *Alternatives Considered* section for more information about why validation is not the default behavior.

The following example test code demonstrates how this might be done:

```swift
// This date will parse correctly, but of course the value of 99 does not correspond to the actual day.
let strangeDate = "Mon, 99 Jan 2025 19:03:05 GMT"
let date = try XCTUnwrap(Date(strangeDate, strategy: .http))
let components = try XCTUnwrap(DateComponents(strangeDate, strategy: .http))

let actualDay = Calendar(identifier: .gregorian).component(.day, from: date)
let componentDay = try XCTUnwrap(components.day)
XCTAssertNotEqual(actualDay, componentDay)
```

## Source compatibility

There is no impact on source compatibility. This is entirely new API.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility. On Darwin platforms, the feature is aligned with FoundationPreview 6.2 availability.

## Future directions

The HTTP format is exceedingly simple, so it is highly unlikely that any new features or API surface will be added to this format.

## Alternatives considered

### A custom interface instead of a format style

As the HTTP date format is extremely simple and frequently used in performance-sensitive contexts, we could have chosen to provide a very specific function instead of a general purpose date format. This would have the advantage of "funneling" developers towards the highest performance versions of this interface.

This approach was rejected as being unnecessarily restrictive. While it's important that this format can be accessed in a high performance way, there is no compelling reason to avoid offering a generic format style. There are circumstances in which users may wish to use this date format as an offering in other contexts.

### Validating the weekday

The parser could validate the correctness of the weekday value. However, this requires an additional step of decomposing the produced date into components. The authors do not feel this is important enough to warrant the permanent performance penalty, and therefore have provided an alternate method to do so using the components parser in cases where it is required.
