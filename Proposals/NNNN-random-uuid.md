# Generating UUIDs using RandomNumberGenerators

* Proposal: [SF-NNNN](NNNN-random-uuid.md)
* Authors: [FranzBusch](https://github.com/FranzBusch)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#1271](https://github.com/swiftlang/swift-foundation/pull/1271)
* Review: ([pitch](https://forums.swift.org/...))

## Introduction

UUIDs (Universally Unique IDentifiers) are 128 bits long and is intended to
guarantee uniqueness across space and time. This proposal adds APIs to generate
UUIDs from Swift's random number generators.

## Motivation

UUIDs often need to be randomly generated. This is currently possible by calling
the `UUID` initializer. However, this initializer doesn't allow providing a
custom source from which the `UUID` is generated. Swift's standard library
provides a common abstraction for random number generators through the
`RandomNumberGenerator` protocol. Providing methods to generate `UUID`s using a
`RandomNumberGenerator` allows developers to customize their source of randomness.

An example where this is useful is where a system needs to generate UUIDs using a
deterministically seeded random number generator.

## Proposed solution

This proposal adds a new static method to the `UUID` type to generate new random `UUIDs` using a `RandomNumberGenerator`.

```swift
/// Generates a new random UUID.
///
/// - Parameter generator: The random number generator to use when creating the new random value.
/// - Returns: A random UUID.
@available(FoundationPreview 6.3, *)
public static func random(
    using generator: inout some RandomNumberGenerator
) -> UUID
```

## Source compatibility

The new API is purely additive and ha no impact on the existing API.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Alternatives considered

### Initializer based random UUID generation

The existing `UUID.init()` is already generating new random `UUID`s and a new
`UUID(using: &rng)` method would be a good alternative to the proposed static method.
However, the static `random` method has precedence on various types such as [Int.random](https://developer.apple.com/documentation/swift/int/random(in:)-9mjpw).
