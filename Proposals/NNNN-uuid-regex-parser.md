# UUID Regex Parser Component

* Proposal: [SF-NNNN](NNNN-uuid-regex-parser.md)
* Authors: [beltradini](https://github.com/beltradini)
* Review Manager: TBD
* Status: **Awaiting implementation**
* Bug: [swiftlang/swift-foundation#1470](https://github.com/swiftlang/swift-foundation/issues/1470)
* Implementation: [swiftlang/swift-foundation#1547](https://github.com/swiftlang/swift-foundation/pull/1547)

## Introduction

This proposal adds a dedicated UUID parser component for Swift Regex so callers can match and capture UUID text directly as `UUID` values.

## Motivation

Users can currently match UUID-shaped text with a string pattern and then manually construct `UUID(uuidString:)` in a follow-up step. This is repetitive and easy to get wrong when combining with larger regexes.

A first-class regex component improves ergonomics and makes captures strongly typed.

## Proposed solution

Add a new nested type, `UUID.RegexComponent`, that conforms to `CustomConsumingRegexComponent`.

Also add a convenience regex factory:

```swift
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == UUID.RegexComponent {
    public static var uuid: UUID.RegexComponent { UUID.RegexComponent() }
}
```

This enables regex usage like:

```swift
let match = input.firstMatch(of: /id=\(.uuid)/)
```

## Detailed design

`UUID.RegexComponent` consumes exactly 36 characters from the current regex index and uses `UUID(uuidString:)` to validate and produce a typed `UUID` capture.

If there are fewer than 36 characters remaining, or the 36-character slice is not a valid UUID, matching fails at that position.

### API surface

```swift
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension UUID {
    public struct RegexComponent : CustomConsumingRegexComponent {
        public init()
        public typealias RegexOutput = UUID
        public func consuming(
            _ input: String,
            startingAt index: String.Index,
            in bounds: Range<String.Index>
        ) throws -> (upperBound: String.Index, output: UUID)?
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == UUID.RegexComponent {
    public static var uuid: UUID.RegexComponent
}
```

## Source compatibility

This is an additive API change with no source break.

## Implications on adoption

Adopters can gate use with standard availability checks for Regex APIs (`macOS 13 / iOS 16 / tvOS 16 / watchOS 9`).

## Future directions

Future revisions could add parsing components for other common scalar identifiers that already have string initializers.

## Alternatives considered

### Keep using string captures + manual parsing

This remains possible but duplicates parsing work at call sites and weakens type-safety.

### Make `UUID` itself the regex component

Using a dedicated parser type avoids making ordinary `UUID` values double as parser instances and keeps API intent explicit.
