# URI Templating

* Proposal: [SF-00019](00019-uri-templating.md)
* Authors: [Daniel Eggert](https://github.com/danieleggert)
* Review Manager: TBD
* Status: **Awaiting implementation**
* Implementation: [swiftlang/swift-foundation#1198](https://github.com/swiftlang/swift-foundation/pull/1198)
* Review: ([pitch](https://forums.swift.org/t/pitch-uri-templating/78030))

## Introduction

This proposal adds support for [RFC 6570](https://datatracker.ietf.org/doc/html/rfc6570) _URI templates_ to the Swift URL type.

Although there are multiple levels of expansion, the core concept is that you can define a _template_ such as
```
http://example.com/~{username}/
http://example.com/dictionary/{term:1}/{term}
http://example.com/search{?q,lang}
```

and then _expand_ these using named values (i.e. a dictionary) into a `URL`.

The templating has a rich set of options for substituting various parts of URLs. [RFC 6570 section 1.2](https://datatracker.ietf.org/doc/html/rfc6570#section-1.2) lists all 4 levels of increasing complexity.

## Motivation

[RFC 6570](https://datatracker.ietf.org/doc/html/rfc6570) provides a simple, yet powerful way to allow for variable expansion in URLs.

This provides a mechanism for a server to convey to clients how to construct URLs for specific resources. In the [RFC 8620 JMAP protocol](https://datatracker.ietf.org/doc/html/rfc8620) for example, the server sends it client a template such as 
```
https://jmap.example.com/download/{accountId}/{blobId}/{name}?accept={type}
```
and the client can then use variable expansion to construct a URL for resources. The API contract between the server and the client defines which variables this specific template has, and which ones are optional.

Since URI templates provide a powerful way to define URL patterns with placeholders, they are adopted in various standards.

## Proposed solution

```swift
let template = URL.Template("http://www.example.com/foo{?query,number}")
let url = template?.makeURL(variables: [
    "query": "bar baz",
    "number": "234",
])
```

The RFC 6570 template gets parsed as part of the `URL.Template(_:)` initializer. It will return `nil` if the passed in string is not a valid template.

The `Template` can then be expanded with _variables_ to create a URL:
```swift
extension URL.Template {
    public makeURL(
        variables: [URL.Template.VariableName: URL.Template.Value]
    ) -> URL?
}
```

## Detailed design

### Templates and Expansion

[RFC 6570](https://datatracker.ietf.org/doc/html/rfc6570) defines 8 different kinds of expansions:
 * Simple String Expansion: `{var}`
 * Reserved Expansion: `{+var}`
 * Fragment Expansion: `{#var}`
 * Label Expansion with Dot-Prefix: `{.var}`
 * Path Segment Expansion: `{/var}`
 * Path-Style Parameter Expansion: `{;var}`
 * Form-Style Query Expansion: `{?var}`
 * Form-Style Query Continuation: `{&var}`

Additionally, RFC 6570 allows for _prefix values_ and _composite values_.

Prefix values allow for e.g. `{var:3}` which would result in (up to) the first 3 characters of `var`.

Composite values allow `/mapper{?address*}` to e.g. expand into `/mapper?city=Newport%20Beach&state=CA`.

This implementation covers all levels and expression types defined in the RFC.

### API Details

There are 3 new types:
 * `URL.Template`
 * `URL.Template.VariableName`
 * `URL.Template.Value`

All new API is guarded by `@available(FoundationPreview 6.2, *)`.

#### `Template`

`URL.Template` represents a parsed template that can be used to create a `URL` from it by _expanding_ variables according to RFC 6570.

Its sole API is its initializer:
```swift
extension URL {
    /// A template for constructing a URL from variable expansions.
    ///
    /// This is an template that can be expanded into
    /// a ``URL`` by calling ``URL(template:variables:)``.
    ///
    /// Templating has a rich set of options for substituting various parts of URLs. See
    /// [RFC 6570](https://datatracker.ietf.org/doc/html/rfc6570) for
    /// details.
    public struct Template: Sendable, Hashable {}
}

extension URL.Template {
    /// Creates a new template from its text form.
    ///
    /// The template string needs to be a valid RFC 6570 template.
    ///
    /// If parsing the template fails, this will return `nil`.
    public init?(_ template: String)
}
```

It will return `nil` if the provided string can not be parsed as a valid template.

#### Variables

Variables are represented as a `[URL.Template.VariableName: URL.Template.Value]`.

#### `VariableName`

The `URL.Template.VariableName` type is a type-safe wrapper around `String`
```swift
extension URL.Template {
    /// The name of a variable used for expanding a template.
    public struct VariableName: Sendable, Hashable {
        public init(_ key: String)
    }
}
```

The following extensions and conformances make it easy to convert between `VariableName` and `String`:
```swift
extension String {
    public init(_ key: URL.Template.VariableName)
}

extension URL.Template.VariableName: CustomStringConvertible {
    public var description: String
}

extension URL.Template.VariableName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String)
}
```

#### `Value`

The `URL.Template.Value` type can represent the 3 different kinds of values that RFC 6570 supports:
```swift
extension URL.Template {
    /// The value of a variable used for expanding a template.
    ///
    /// A ``Value`` can be one of 3 kinds:
    ///  1. "text": a single `String`
    ///  2. "list": an array of `String`
    ///  3. "associative list": an ordered array of key-value pairs of `String` (similar to `Dictionary`, but ordered).
    public struct Value: Sendable, Hashable {}
}

extension URL.Template.Value {
    /// A text value to be used with a ``URL.Template``.
    public static func text(_ text: String) -> URL.Template.Value

    /// A list value (an array of `String`s) to be used with a ``URL.Template``.
    public static func list(_ list: some Sequence<String>) -> URL.Template.Value
    
    /// An associative list value (ordered key-value pairs) to be used with a ``URL.Template``.
    public static func associativeList(_ list: some Sequence<(key: String, value: String)>) -> URL.Template.Value
}
```

To make it easier to use hard-coded values, the following `ExpressibleBy…` conformances are provided:
```swift
extension URL.Template.Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String)
}

extension URL.Template.Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...)
}

extension URL.Template.Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...)
}
```

#### Expansion to `URL`

Finally, `URL.Template` has this factory method:
```swift
extension URL.Template {
    /// Creates a new `URL` by expanding the RFC 6570 template and variables.
    ///
    /// This will return `nil` if variable expansion does not produce a valid,
    /// well-formed URL.
    ///
    /// All text will be converted to NFC (Unicode Normalization Form C) and UTF-8
    /// before being percent-encoded if needed.
    public func makeURL(
        variables: [URL.Template.VariableName: URL.Template.Value]
    ) -> URL?
}
```

This will only fail (return `nil`) if `URL.init?(string:)` fails.

It may seem counterintuitive when and how this could fail, but a string such as `http://example.com:bad%port/` would cause `URL.init?(string:)` to fail, and URI Templates do not provide a way to prevent this. It is also worth noting that it is valid to not provide values for all variables in the template. Expansion will still succeed, generating a string. If this string is a valid URL, depends on the exact details of the template. Determining which variables exist in a template, which are required for expansion, and whether the resulting URL is valid is part of the API contract between the server providing the template and the client generating the URL.

Additionally, the new types `URL.Template`, `URL.Template.VariableName`, and `URL.Template.Value` all conform to `CustomStringConvertible`.

### Unicode

The _expansion_ that happens as part of calling `URL(template:variables:)` will
 * convert text to NFC (Unicode Normalization Form C)
 * convert text to UTF-8 before being percent-encoded (if needed).

as per [RFC 6570 section 1.6](https://datatracker.ietf.org/doc/html/rfc6570#section-1.6).

## Source compatibility

These changes are additive only and are not expected to have an impact on source compatibility.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

Since this proposal covers all of RFC 6570, the current expectation is for it to not be extended further.

## Alternatives considered

Instead of `URL.Template.makeURL(variables:)`, the API could have a (failable) inititializer `URL.init?(template:variables:)`. The `makeURL(variables:)` (factory) method would be easier to discover through autocomplete, and when looking at the `URL.Template` type’s documentation is it easier to discover. The `URL.init?` approach would be less discoverable. There was some feedback to the initial pitch, though, that preferred the `URL.init?` method which aligns with the existing `URL.init?(string:)` initializer.

Additionally, the API _could_ expose a (non-failing!) `URL.Template.expand(variables:)` (or other naming) that returns a `String`. But since the purpose is very clearly to create URLs, it feels like that would just add noise.

Using a DSL (domain-specific language) for `URL.Template` could improve type safety. However, because servers typically send templates as strings for client-side processing and request generation, the added complexity of a DSL outweighs its benefits. The proposed implementation is string-based (_stringly typed_) because that is what the RFC 6570 mandates.

There was a lot of interest during the pitch to have an API that lends itself to _routing_, providing a way to go back-and-forth between a route and its variables. But that’s a very different use case than the RFC 6570 templates provide, and it would be better suited to have a web server routing specific API, either in Foundation or in a web server specific package. [pointfreeco/swift-url-routing](https://github.com/pointfreeco/swift-url-routing) is one such example.

Instead of using the `text`, `list` and `associativeList` names (which are _terms of art_ in RFC 6570), the names `string`, `array`, and `orderedDictioary` would align better with normal Swift naming conventions. The proposal favors the _terms of art_, but there was some interest in using changing this.
