
# Additional numeric and conversion APIs for `Decimal`

* Proposal: [SF-NNNN](NNNN-decimal-additions.md)
* Authors: [Xiaodi Wu](https://github.com/xwu)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#2294](https://github.com/swiftlang/swift-foundation/pull/2294)
* Review: ([pitch](https://forums.swift.org/t/pitch-additional-apis-for-decimal/89915))

## Introduction

This proposal adds additional numeric operations and conversions to `Decimal`, using the naming and conventions of Swift's floating-point APIs where they fit the type. The additions include:

* Arithmetic with explicit rounding and scale; (optionally) with reporting of inexact results
* Fused multiply-add
* Nearest and truncating remainder
* Square root
* Integer conversions
* Conversion to `Double`

## Motivation

`Decimal` pre-dates Swift's numeric protocols. Besides familiar arithmetic operators, it now offers some of the properties and methods available on standard library floating-point types, but others are missing even though they would be useful also for `Decimal`. Some of those missing operations have default implementations on `FloatingPoint`, but `Decimal` can't gain them through conformance because its values and behavior do not satisfy all of that protocol's requirements.

To perform arithmetic with a non-default rounding rule, callers may use the legacy, pointer-based `NSDecimal*` functions in `swift-corelibs-foundation` or `Foundation.framework`, but there are currently no methods on `Decimal` itself. Those legacy functions don't support all six `FloatingPointRoundingRule` cases, and when rounding to a specified scale (i.e., a certain number of decimal places), arithmetic followed by a separate call to `NSDecimalRound` can result in double rounding.

## Proposed solution

Add methods that follow the standard library's mutating/nonmutating naming pairs, including `addProduct`/`addingProduct`, `formSquareRoot`/`squareRoot`, and `round`/`rounded`. Provide explicit rounding and scale for operations that may discard digits, alongside `*ReportingInexact` counterparts where the exact mathematical result is not already available to the caller.

For example:

```swift
let subtotal = Decimal(string: "12.345")!
let tip = Decimal(string: "0.006")!
let total = /* 🆕 */ subtotal.adding(tip, rounding: .toNearestOrEven, scale: 2)
// `total` is 12.35; addition and rounding are one operation.

let third = /* 🆕 */ (1 as Decimal).dividedReportingInexact(by: 3, rounding: .toNearestOrEven, scale: 2)
// `third.value` is 0.33; `third.inexact` is `true`.
```

Also, add conversions to a fixed-width integer that preserve the familiar distinction between truncating and exact conversion, and add conversion from a 128-bit integer that's exact without going through `Double`:

```swift
let fractional = Decimal(string: "127.9")!
let truncated = /* 🆕 */ Int8(fractional)      // `127`
let exact = /* 🆕 */ Int8(exactly: fractional) // `nil`
let large = /* 🆕 */ Decimal(UInt128.max)
large == Decimal(string: String(UInt128.max))! // `true`
```

These additions don't change `Decimal`'s representation or make the type conform to `FloatingPoint`. They are complementary but separable from the proposal to [revise the behavior of certain APIs on `Decimal`](https://github.com/xwu/swift-foundation/blob/decimal-api-proposal/Proposals/NNNN-decimal-api-revisions.md), which addresses existing APIs, including their default rounding and conversion behavior.

## Detailed design

Add the following conversions to numeric types in the standard library:

| Operation | Basic API |
| --- | --- |
| Convert 128-bit integer to decimal | `Decimal.init(_: UInt128)`<br>`Decimal.init(_: Int128)` |
| Convert decimal to fixed-width integer | `FixedWidthInteger.init(_:)`<br>`FixedWidthInteger.init?(exactly:)` |
| Convert decimal to binary64 | `Double.init(_ source: Decimal)` (nearest, ties to even) |

Add the arithmetic operations labeled 🆕 in the following matrix, which shows them in the context of existing operations in mutating–nonmutating pairs. Rounding and scale parameters spelled `rounding:scale:` are abbreviated `...:` below.

| Operation | Basic API | Rounding and scale | Inexact reporting |
| --- | --- | --- | --- |
| Addition | `+=`<br>`+` | 🆕 `add(_:...:)`<br>🆕 `adding(_:...:)` | 🆕 `addReportingInexact(_:...:)`<br>🆕 `addingReportingInexact(_:...:)` |
| Subtraction | `-=`<br>`-` | 🆕 `subtract(_:...:)`<br>🆕 `subtracting(_:...:)` | 🆕 `subtractReportingInexact(_:...:)`<br>🆕 `subtractingReportingInexact(_:...:)` |
| Multiplication | `*=`<br>`*` | 🆕 `multiply(by:...:)`<br>🆕 `multiplied(by:...:)` | 🆕 `multiplyReportingInexact(by:...:)`<br>🆕 `multipliedReportingInexact(by:...:)` |
| Division | `/=`<br>`/` | 🆕 `divide(by:...:)`<br>🆕 `divided(by:...:)` | 🆕 `divideReportingInexact(by:...:)`<br>🆕 `dividedReportingInexact(by:...:)` |
| Scaling by power of ten | —<br>`init(sign:exponent:significand:)` | 🆕&nbsp;`multiply(byPowerOfTen:...:)`<br>🆕&nbsp;`multiplied(byPowerOfTen:...:)` | 🆕&nbsp;`multiplyReportingInexact(byPowerOfTen:...:)`<br>🆕&nbsp;`multipliedReportingInexact(byPowerOfTen:...:)` |
| Fused multiply-add | 🆕 `addProduct(_:_:)`<br>🆕 `addingProduct(_:_:)` | 🆕 `addProduct(_:_:...:)`<br>🆕 `addingProduct(_:_:...:)` | 🆕 `addProductReportingInexact(_:_:...:)`<br>🆕 `addingProductReportingInexact(_:_:...:)` |
| Square root | 🆕 `formSquareRoot()`<br>🆕 `squareRoot()` | 🆕 `formSquareRoot(...:)`<br>🆕 `squareRoot(...:)` | 🆕 `formSquareRootReportingInexact(...:)`<br>🆕 `squareRootReportingInexact(...:)` |
| Rounding | 🆕 `round(_:)`<br>🆕 `rounded(_:)` (to integral) | 🆕 `round(_:scale:)`<br>🆕 `rounded(_:scale:)` | — (compare input and result) |
| Nearest remainder | 🆕 `formRemainder(dividingBy:)`<br>🆕 `remainder(dividingBy:)` | — (valid results are exact) | — (valid results are exact) |
| Truncating remainder | 🆕&nbsp;`formTruncatingRemainder(dividingBy:)`<br>🆕&nbsp;`truncatingRemainder(dividingBy:)` | — (valid results are exact) | — (valid results are exact) |

### Rounding and scale

For newly proposed APIs, the `rounding:` parameter takes a [`FloatingPointRoundingRule`](https://docs.swift.org/latest/documentation/swift/floatingpointroundingrule/), with its six cases a superset of the four currently in `NSDecimalNumber.RoundingMode`.

Meanwhile, the `scale:` parameter inherits the same meaning as in [`NSDecimalNumberBehaviors`](https://developer.apple.com/documentation/foundation/nsdecimalnumberbehaviors/scale()), denoting the maximum number of digits after the decimal separator; a negative scale extends the limit to digits before the separator. For example, `2` requests at most two fractional digits, `0` requests an integral value, and `-2` requests a multiple of one hundred. Scale is a constraint on the numeric result, not a request to preserve trailing zeros or return a particular stored exponent: these APIs are not IEEE 'quantize' operations.

For newly proposed APIs, it's a precondition failure if `scale < -165`. The lower bound permits rounding at the highest decimal place occupied by a finite value (`Decimal.greatestFiniteMagnitude` is ~3.4028 × 10<sup>165</sup>); a greater quantum of 10<sup>166</sup> isn't representable as a finite value.

Rounding to a specific scale is performed with no more than one rounding step. Implementations retain the information needed for one-step rounding rather than performing an arithmetic operation that rounds to the maximum precision of the type and then rounding the result again to a specific scale. Multiplication by a power of ten applies the power directly; it does not first construct a possibly unrepresentable `Decimal` value for the power-of-ten multiplier. Fused multiply-add computes `self + lhs * rhs` without rounding the intermediate product.

Converting initializers to and from standard library numeric types have the same rounding behavior as their standard library counterparts. Namely:

* All `Int128` and `UInt128` values are exactly representable in `Decimal`. Their initializers can't lose precision or fail.

* `FixedWidthInteger.init(_ source: Decimal)` removes the fractional part toward zero, then requires the resulting integer to be representable in `Self`. NaN or an out-of-range truncated value causes a runtime error. The range check applies **after** truncation: an unsigned conversion of a decimal value strictly between `-1` and `0` succeeds with zero.

* `FixedWidthInteger.init?(exactly:)` succeeds only for a finite integral source representable in `Self`. It returns `nil` for NaN, a fractional value, or an out-of-range value. (The existing `Decimal.init?(exactly:)` from `BinaryInteger` remains available in the other direction.)

* `Double.init(_ source: Decimal)` returns the nearest representable `Double` with its usual correctly rounded nearest-even conversion contract. It converts `Decimal.nan` to `Double.nan` and `Decimal.zero` to `+0.0`. Every finite nonzero `Decimal` lies within the normal finite magnitude range of `Double`, so the conversion can't overflow or underflow; however, it can still lose precision.

As with standard library floating-point types, `round(_:)` and `rounded(_:)` operations default to the `.toNearestOrAwayFromZero` rule and, where they don't take an explicit `scale:` parameter, round to an integral value. Other arithmetic operations that don't take an explicit `rounding:` parameter will have the same rounding behavior as existing `+` `-` `*` and `/` operators; that is, they will round `.toNearestOrEven` if the proposal to [revise the behavior of certain APIs on `Decimal`](https://github.com/xwu/swift-foundation/blob/decimal-api-proposal/Proposals/NNNN-decimal-api-revisions.md) is adopted (just like standard library floating-point types) and `.toNearestOrAwayFromZero` otherwise.

### Exceptional results and inexactness

None of the proposed APIs throw a legacy `NSDecimalNumber.CalculationError`. Instead, each nonmutating `*ReportingInexact` method returns `(value: Decimal, inexact: Bool)`, and each mutating counterpart stores the result in `self` and returns a `Bool` indicating inexactness, with behavior outlined in the table below. (Methods that don't report inexactness simply return or store the corresponding result.)

| Condition | Result | `inexact` |
| --- | --- | --- |
| An exact finite result | That value | `false` |
| Rounding changes the exact result | The rounded value, possibly zero | `true` |
| Arithmetic overflows finite range | `.nan` | `true` |
| Arithmetic underflows to zero | `0` | `true` |
| NaN operand, division by zero, square root of negative value | `.nan` | `false` |

Note that the Boolean reports loss of exactness, not success or failure. In particular, `false` does not imply a finite result: as with IEEE standard types, propagating NaN or performing an invalid operation (e.g., dividing by zero) is *not* considered to be inexact.

These methods don't expose a complete IEEE exception model, maintain floating-point status flags, or distinguish all error categories. For existing `NSDecimal*` APIs, this proposal doesn't revise the legacy error code contract.

### API declarations and documentation

The following declarations specify the complete added surface. Documentation for implemented APIs follows the implementation branch; the shared contracts above also apply. Availability and implementation-only attributes are omitted from these interface listings and discussed under *Implications on adoption*.

#### Conversion to `Decimal`

```swift
extension Decimal {
    /// Creates a new decimal floating-point value from the given unsigned integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: UInt128)

    /// Creates a new decimal floating-point value from the given signed integer value.
    ///
    /// - Parameter value: The integer to convert to a decimal floating-point value.
    public init(_ value: Int128)
}
```

#### Conversion from `Decimal`

```swift
extension FixedWidthInteger {
    /// Creates an integer from the given decimal floating-point value, rounding toward zero.
    ///
    /// Any fractional part of the value passed as `source` is removed, rounding the value toward zero.
    ///
    ///     let x = Int(Decimal(21.5))
    ///     // x == 21
    ///     let y = Int(Decimal(-21.5))
    ///     // y == -21
    ///
    /// If `source` is NaN or is outside the bounds of this type after rounding toward zero,
    /// a runtime error occurs.
    ///
    /// - Parameter source: A decimal floating-point value to convert to an integer.
    ///   `source` must be representable in this type after rounding toward zero.
    public init(_ source: Decimal)

    /// Creates an integer from the given decimal floating-point value, if it can be represented exactly.
    ///
    /// If the value passed as `source` is not representable exactly, the result is `nil`.
    /// In the following example, `x` is successfully created from a value of `21`,
    /// while the attempt to initialize `y` from `21.5` fails:
    ///
    ///     let x = Int(exactly: Decimal(21))
    ///     // x == Optional(21)
    ///     let y = Int(exactly: Decimal(21.5))
    ///     // y == nil
    ///
    /// If `source` is NaN or is outside the bounds of this type, the result is `nil`.
    ///
    /// - Parameter source: A decimal floating-point value to convert to an integer.
    public init?(exactly source: Decimal)
}

extension Double {
    /// Creates a new binary floating-point value from the given decimal value.
    ///
    /// The result is the nearest representable value to `source`. If two values
    /// are equally close, the result is the one with an even significand.
    ///
    /// If `source` is NaN, the result is NaN. If `source` is zero, the result is
    /// positive zero. A finite nonzero source produces a finite nonzero result,
    /// but the conversion may lose precision.
    ///
    /// - Parameter source: A decimal floating-point value to convert.
    public init(_ source: Decimal)
}
```

#### Basic arithmetic and rounding

```swift
extension Decimal {
    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    public mutating func addProduct(_ lhs: Decimal, _ rhs: Decimal)

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    /// - Returns: The product of `lhs` and `rhs`, added to this value.
    public func addingProduct(_ lhs: Decimal, _ rhs: Decimal) -> Decimal

    /// Replaces this value with the remainder of itself divided by the given value.
    ///
    /// For two finite values `x` and `y`,
    /// the remainder of dividing `x` by `y` satisfies `x == y * q + r`,
    /// where `q` is the integer nearest to `x / y`.
    /// If `x / y` is exactly halfway between two integers, `q` is chosen to be even.
    /// Note that `q` is *not* `x / y` computed in floating-point arithmetic,
    /// and that `q` may not be representable in any available integer type.
    ///
    /// If this value and `other` are both finite numbers,
    /// the remainder is in the closed range `-abs(other / 2)...abs(other / 2)`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    public mutating func formRemainder(dividingBy other: Decimal)

    /// Replaces this value with its square root, rounded to a representable value.
    public mutating func formSquareRoot()

    /// Replaces this value with the remainder of itself divided by the given value
    /// using truncating division.
    ///
    /// Performing truncating division with floating-point values results in a truncated integer quotient and a remainder.
    /// For values `x` and `y` and their truncated integer quotient `q`,
    /// the remainder `r` satisfies `x == y * q + r`.
    ///
    /// If this value and `other` are both finite numbers,
    /// the truncating remainder has the same sign as this value if nonzero and is strictly smaller in magnitude than `other`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    public mutating func formTruncatingRemainder(dividingBy other: Decimal)

    /// Returns the remainder of this value divided by the given value.
    ///
    /// For two finite values `x` and `y`,
    /// the remainder of dividing `x` by `y` satisfies `x == y * q + r`,
    /// where `q` is the integer nearest to `x / y`.
    /// If `x / y` is exactly halfway between two integers, `q` is chosen to be even.
    /// Note that `q` is *not* `x / y` computed in floating-point arithmetic,
    /// and that `q` may not be representable in any available integer type.
    ///
    /// If this value and `other` are both finite numbers,
    /// the remainder is in the closed range `-abs(other / 2)...abs(other / 2)`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    /// - Returns: The remainder of this value divided by `other`.
    public func remainder(dividingBy other: Decimal) -> Decimal

    /// Rounds the value to an integral value using the specified rounding rule.
    ///
    /// For more information about the available rounding rules,
    /// see the `FloatingPointRoundingRule` type.
    ///
    /// - Parameter rule: The rounding rule to use.
    public mutating func round(
        _ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    )

    /// Returns this value rounded to an integral value using the specified rounding rule.
    ///
    /// For more information about the available rounding rules,
    /// see the `FloatingPointRoundingRule` type.
    ///
    /// - Parameter rule: The rounding rule to use.
    /// - Returns: The integral value found by rounding using `rule`.
    public func rounded(
        _ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero
    ) -> Decimal

    /// Returns the square root of the value, rounded to a representable value.
    ///
    /// - Returns: The square root of the value.
    public func squareRoot() -> Decimal

    /// Returns the remainder of this value divided by the given value using truncating division.
    ///
    /// Performing truncating division with floating-point values results in a truncated integer quotient and a remainder.
    /// For values `x` and `y` and their truncated integer quotient `q`,
    /// the remainder `r` satisfies `x == y * q + r`.
    ///
    /// If this value and `other` are both finite numbers,
    /// the truncating remainder has the same sign as this value if nonzero and is strictly smaller in magnitude than `other`.
    /// This method is always exact.
    ///
    /// - Parameter other: The value to use when dividing this value.
    /// - Returns: The remainder of this value divided by `other` using truncating division.
    public func truncatingRemainder(dividingBy other: Decimal) -> Decimal
}
```

#### Arithmetic with explicit rounding and scale

```swift
extension Decimal {
    /// Adds the given value to this value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func add(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Adds the given value to this value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func addReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns the sum of this value and the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The sum of this value and `other`, rounded as specified.
    public func adding(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the sum of this value and the given value, along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to add to this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the sum of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func addingReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Subtracts the given value from this value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func subtract(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Subtracts the given value from this value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func subtractReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns the difference obtained by subtracting the given value from this value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The difference of this value and `other`, rounded as specified.
    public func subtracting(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the difference obtained by subtracting the given value from this value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to subtract from this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the difference of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func subtractingReportingInexact(
        _ other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Multiplies this value by the given value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func multiply(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Multiplies this value by the given value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func multiplyReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns the product of this value and the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The product of this value and `other`, rounded as specified.
    public func multiplied(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the product of this value and the given value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value to multiply by this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the product of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func multipliedReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Multiplies this value by the given power of ten in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func multiply(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Multiplies this value by the given power of ten in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func multiplyReportingInexact(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns this value multiplied by the given power of ten.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The result of this value multiplied by ten raised to `power`, rounded as specified.
    public func multiplied(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns this value multiplied by the given power of ten,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - power: The power of ten by which to multiply this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the result of this value multiplied by ten raised to `power`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func multipliedReportingInexact(
        byPowerOfTen power: Int,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Divides this value by the given value in place.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func divide(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Divides this value by the given value in place, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN or if `other` is zero, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func divideReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns the quotient obtained by dividing this value by the given value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The quotient of this value and `other`, rounded as specified.
    public func divided(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the quotient obtained by dividing this value by the given value,
    /// along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If either operand is NaN or if `other` is zero, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - other: The value by which to divide this value.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the quotient of this value and `other`, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func dividedReportingInexact(
        by other: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func addProduct(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Adds the product of the two given values to this value in place,
    /// computed without intermediate rounding, reporting whether the result is inexact.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If any operand is NaN, the result is NaN and this method returns `false`.
    /// If the result overflows to NaN or underflows to zero, this method returns `true`.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result or if the result overflowed or underflowed; otherwise, `false`.
    public mutating func addProductReportingInexact(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The product of `lhs` and `rhs`, added to this value, rounded as specified.
    public func addingProduct(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the result of adding the product of the two given values to this value,
    /// computed without intermediate rounding, along with a Boolean value indicating whether the result is inexact.
    ///
    /// This method is the fused multiply-add operation.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If any operand is NaN, the result is NaN and `inexact` is `false`.
    /// If the result overflows to NaN or underflows to zero, `inexact` is `true`.
    ///
    /// - Parameters:
    ///   - lhs: One of the values to multiply before adding to this value.
    ///   - rhs: The other value to multiply.
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the product of `lhs` and `rhs`, added to this value, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result or the result overflowed or underflowed.
    public func addingProductReportingInexact(
        _ lhs: Decimal,
        _ rhs: Decimal,
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)

    /// Replaces this value with its square root.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func formSquareRoot(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Replaces this value with its square root, reporting whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN or negative, the result is NaN and this method returns `false`.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: `true` if rounding changed the exact result; otherwise, `false`.
    public mutating func formSquareRootReportingInexact(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Bool

    /// Rounds this value in place using the specified rounding rule and scale.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    public mutating func round(
        _ rule: FloatingPointRoundingRule,
        scale: Int
    )

    /// Returns this value rounded using the specified rounding rule and scale.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The value found by rounding using `rule` and `scale`.
    public func rounded(
        _ rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the square root of this value.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: The square root of this value, rounded as specified.
    public func squareRoot(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> Decimal

    /// Returns the square root of this value, along with a Boolean value indicating whether the result is inexact.
    ///
    /// The result is rounded no more than once using `rule` to at most *n* decimal places,
    /// where *n* is `min(scale, 128)`.
    /// For example, a scale of `2` rounds to two decimal places;
    /// a scale of `0` rounds to an integral value.
    ///
    /// If this value is NaN or less than zero, the result is NaN and `inexact` is `false`.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to use.
    ///   - scale: The maximum number of digits after the decimal separator;
    ///     if negative, the limit extends to digits before the decimal separator, but it must not be less than `-165`.
    /// - Returns: A tuple containing the square root of this value, rounded as specified,
    ///   and a Boolean value indicating whether rounding changed the exact result.
    public func squareRootReportingInexact(
        rounding rule: FloatingPointRoundingRule,
        scale: Int
    ) -> (value: Decimal, inexact: Bool)
}
```

## Source compatibility

The proposal is additive. It doesn't change the numeric representation, add a protocol requirement, remove or rename an existing public API, or change the behavior of an existing arithmetic operation. In particular, existing `NSDecimal*` signatures retain `RoundingMode`.

New members can conflict with similarly named members supplied by client extensions. Clients that already supply an initializer such as `Double.init(_ source: Decimal)` or `FixedWidthInteger.init(_ source: Decimal)`, or methods such as `Decimal.rounded(_:)`, may need to remove or rename those extensions when adopting this Foundation version to avoid ambiguity.

These additions do not require existing conformers to `FixedWidthInteger` to implement new requirements; the initializers are supplied by a protocol extension.

## Implications on adoption

The implementation currently marks the new API families with `@available(FoundationPreview 6.5, *)`; final platform availability follows the Foundation release that ships them. Most arithmetic and conversion implementations depend on new internal entry points and facilities such as `UInt128` or `InlineArray` lookup tables and so can't be backdeployed simply by inlining public wrappers. On platforms with Foundation in the system, adopters must respect the availability of the underlying implementation. Libraries can use availability checks and retain older code paths or raise their deployment requirements.

The public APIs added in this proposal do not freeze `Decimal`'s layout or make private storage usable from client code.

## Future directions

### Representation access

A numeric decomposition API could expose an unsigned integer significand such as `significandInteger: UInt128`, together with a corresponding initializer taking a sign, exponent, and integer significand. Such an API could provide ergonomic access to the value's components without promising a fixed memory layout. It would need to specify the relationship to the existing `significand` and `exponent` properties, NaN handling, representability of the supplied components, and the treatment of a negative sign with a zero significand.

Names such as `exponentBitPattern` and `significandBitPattern` would imply representation commitments that deserve separate consideration. `Decimal` is not an IEEE interchange format, and its integer coefficient does not correspond directly to a standard significand field.

In the absence of dedicated APIs, users can combine existing facilities with those in this proposal to serialize a fixed-width decomposition such as `(x.isNaN, x.sign == .minus, Int8(x.exponent), UInt128(exactly: x.significand) ?? 0)`.

### Additional conversions and arithmetic

`Decimal.init(nearest: Double)` could offer an explicitly numerical nearest-value conversion alongside the shortest-round-tripping interpretation proposed for the unlabeled initializer. An exact binary floating-point conversion initializer or directed conversion variants could also be considered separately.

A broader reporting surface could distinguish invalid operations, division by zero, overflow, underflow, and inexactness, if callers have a need for those distinctions.

Correctly rounded integer powers and other mathematical functions would require their own semantic and implementation work.

### Other operations

Normalization, quantization, compactness, and canonical representation could be explored as distinct concepts. A proposal would need to distinguish changing a representation without changing its numeric value from rounding to a requested quantum, and to distinguish value-level guarantees from properties of private storage. A requested quantum is not always representable within this type's coefficient and exponent bounds; a public quantization API would need a defined failure policy and a decision about whether it preserves an exponent or merely constrains a numeric value.

A `decade` property could be considered as a decimal counterpart to `BinaryFloatingPoint.binade`. Its precise meaning would need to account for `Decimal`'s integer significand, non-uniform decimal precision at coefficient-capacity boundaries, and behavior for zero and NaN. Similarly, other IEEE operations and counterparts to binary floating-point members could be added where they have useful contracts for this type.

## Alternatives considered

### Use `minExponent` instead of `scale`

A lower bound on the result's decimal exponent maps directly to current internal arithmetic helpers. This spelling was explored in the implementation. However, it changes a familiar convention already used by `NSDecimalNumber` as well as decimal APIs in other languages.

### Keep `RoundingMode` for new methods

Using the legacy enum would be familiar to existing Foundation clients but expose only four of the standard library's six rounding rules. (For the Foundation.framework build, the `RoundingMode` case declarations themselves are external to the swift-foundation project.) Adding aliases in `swift-foundation` for nearest rounding rules (e.g., `.toNearestOrAwayFromZero` for `.plain`) could modernize spelling but doesn't truly close the gap. Instead, I propose that new methods accept `FloatingPointRoundingRule`, while compatibility APIs retain their existing API.

### Report every NaN as inexact, or expose legacy calculation errors

Making every NaN result report `inexact: true` would conflate propagation or invalid input with loss of precision. Making every NaN result report `false` would conceal overflow. The proposed distinction follows the purpose of an inexact indication: NaN propagation and invalid operations return `false`, while overflow of a numeric result returns `true`.

A throwing API or a result containing every legacy calculation error could expose more detail, but they would impose more involved error handling and import legacy distinctions that do not align cleanly with the proposed contract. The Boolean follows the standard library's reporting-operation pattern without claiming to be a general status value. Both mutating and nonmutating forms are provided, so callers don't need to create temporary mutable storage just to obtain the result and its flag.

### Expose raw representation as part of this proposal

The implementation explored `significandInteger` and a corresponding initializer before deferring them. An integer component is useful, but the semantic contract is larger than the spelling of a property: it includes nonunique decimal representations and construction of special or unrepresentable values. Separating that design keeps the numeric operations independently reviewable.

## Acknowledgments

Thanks to participants in the [discussion of Decimal API revisions](https://forums.swift.org/t/pitch-revising-certain-behaviors-of-decimal/89754) for motivating a Swift-native arithmetic surface.
