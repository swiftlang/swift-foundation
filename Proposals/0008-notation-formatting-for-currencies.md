# Support notation when formatting currencies

* Proposal: [SF-0008](0008-notation-formatting-for-currencies.md)
* Authors: [Jacob Lukas](https://github.com/jacoblukas)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Status: **Accepted**
* Bug: [apple/swift-foundation#379](https://github.com/apple/swift-foundation/issues/379)
* Implementation: [apple/swift-foundation#449](https://github.com/apple/swift-foundation/pull/449)
* Review: ([pitch](https://forums.swift.org/t/pitch-support-notation-when-formatting-currencies/70223))

## Introduction/Motivation

When formatting numbers or percents, we can specify a notation, for example:

```swift
let count = 1_500_000
let result = count.formatted(.number.notation(.compactName))
assert(result == "1.5M")
```

We will enable this for currency formatters as well.

## Proposed solution

Add the `notation` modifier to the various currency formatters. All of the notations supported by the number and percent formatters will be supported by the currency formatters.

```swift
let price = Decimal(1_500_000.59)
let result = price.formatted(.currency(code: "USD").notation(.compactName))
assert(result == "$1.5M")
```

The underlying ICU formatters already support this, so we just have to forward the appropriate options.

## Detailed design

```swift
extension IntegerFormatStyle.Currency {
    /// Modifies the format style to use the specified notation.
    ///
    /// - Parameter notation: The notation to apply to the format style.
    /// - Returns: An integer currency format style modified to use the specified notation.
    @available(FoundationPreview 0.4, *)
    public func notation(_ notation: Configuration.Notation) -> Self
}

extension FloatingPointFormatStyle.Currency {
    /// Modifies the format style to use the specified notation.
    ///
    /// - Parameter notation: The notation to apply to the format style.
    /// - Returns: A floating-point currency format style modified to use the specified notation.
    @available(FoundationPreview 0.4, *)
    public func notation(_ notation: Configuration.Notation) -> Self
}

extension Decimal.FormatStyle.Currency {
    /// Modifies the format style to use the specified notation.
    ///
    /// - Parameter notation: The notation to apply to the format style.
    /// - Returns: A decimal currency format style modified to use the specified notation.
    @available(FoundationPreview 0.4, *)
    public func notation(_ notation: Configuration.Notation) -> Self
}

extension CurrencyFormatStyleConfiguration {
    /// The type used to configure notation for currency format styles.
    @available(FoundationPreview 0.4, *)
    public typealias Notation = NumberFormatStyleConfiguration.Notation
}
```

## Source compatibility

These changes are additive only and are not expected to have an impact on source compatibility.

## Implications on adoption

This new API will have FoundationPreview 0.4 availability.

## Alternatives considered

None.
