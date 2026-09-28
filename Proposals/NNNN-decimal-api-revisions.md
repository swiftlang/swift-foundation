
# Revising the behavior of certain APIs on `Decimal`

* Proposal: [SF-NNNN](NNNN-decimal-api-revisions.md)
* Authors: [Xiaodi Wu](https://github.com/xwu)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-foundation#NNNNN](https://github.com/swiftlang/swift-foundation/pull/NNNNN)
* Review: ([pitch](https://forums.swift.org/t/pitch-revising-certain-behaviors-of-decimal/89754))

## Introduction

This document proposes to specify and regularize certain behaviors of the `Decimal` type and to deprecate some APIs retained from an earlier stage of Swift's evolution.
Explicitly omitted are any changes in the type's representation or new APIs.

## Motivation

`Foundation.Decimal` is Swift's existing general-purpose decimal floating-point type.
It pre-dates Swift's floating-point protocols and differs from standard library binary floating-point types in fundamental respects:
for example, `Decimal` does not represent infinity or negative zero.

Recent implementation work has substantially rewritten `Decimal` arithmetic, formatting, conversion, and normalization for performance and correctness.
With that, it's become now possible (and necessary) to make and deliver on behavior guarantees that were previously inconsistently honored or underspecified.

## Proposed solution


### Arithmetic rounding mode

**Specify that `Decimal` arithmetic operations use `.bankers` rounding mode (i.e., round to nearest, ties to even) instead of `.plain` rounding mode.**

This would be in line with the rounding convention for ordinary binary floating-point arithmetic (and also implicitly used already in some `Decimal` APIs).
It is also what some users [have said](https://forums.swift.org/t/fixedpointdecimal-exact-decimal-arithmetic-50x-1000x-faster-than-foundation-decimal/85642) they expect for a decimal floating-point type for financial systems.

The change would **not** affect legacy `NSDecimal*` functions, which explicitly accept a rounding mode and continue to permit callers to request `.plain` or another mode.

Changing a default generally deserves considerable caution.
Here, however, existing behavior is a particularly weak compatibility constraint:
many arithmetic operations did not in fact round as documented and/or did not have the precision necessary to do so.
With recent improvements in correctness and precision, now is a key time to establish a consistent, desirable default.
See **Source compatibility** for further discussion.


### Conversions between `Double` and `Decimal`

**Specify explicit semantics for conversion in each direction.**

There are (at least) two reasonable ways to convert a `Double` to a `Decimal`:
the result can be either the **nearest** to the `Double` (at the full precision afforded by `Decimal`),
or it can be the **shortest** (i.e., one with the least precision necessary, ties to nearest or even) for which the original value is the nearest `Double`.

It's possible that we will eventually want explicit APIs for both ways of converting.
However, irrespective of hypothetical new APIs, there's an existing unlabeled converting initializer that's not going anywhere.
Its current implementation doesn't convert precisely enough to align with either of the desired behaviors.
A revised implementation that would improve on it needs to wait for a policy decision (this proposal) on what the behavior *should* be:

`Decimal.init(_ value: Double)` should give the **shortest** `Decimal` representation of `value`, just as `value.description` gives the shortest decimal string representation.
This preserves a useful and intuitive relationship:
when a user expresses a `Double` by its shortest roundtripping decimal representation,
converting that value to `Decimal` doesn't result in additional decimal digits that arise solely from the binary representation:

```swift
let x = 0.1
Decimal(x) == Decimal(string: x.description)
```

`Decimal`'s float literal initializer would adopt the same semantics so that near-equivalent ways of constructing a `Decimal` do not unexpectedly produce different values.

When a public API is eventually exposed for conversion in the other direction,
it should give the **nearest** `Double` representation,
such that `Double`-to-`Decimal` roundtrip conversion (unless the result is overlarge, etc.) parallels the lossless behavior of `Double`-to-`String` roundtrip conversion.

The idea is that these behaviors would be the least astonishing for most users.


### Subnormal values

**Recognize that values with magnitude sufficiently small that they can't be represented with the type's full precision are subnormal.**

Currently, `Decimal` classifies every finite nonzero value as normal, reasoning that it doesn't use an IEEE format.
But, just like subnormal values in IEEE formats, finite nonzero values that are sufficiently small can only be represented using fewer significant digits than fit in the type's significand (mantissa) capacity.

It would be more useful to classify values in that reduced-precision range as subnormal.
`leastNormalMagnitude` would then change to be `(UInt128.max / 10 + 1) * 1e-128`,
and `isSubnormal`, `isNormal`, and `floatingPointClass` would be updated consistently.


### Constants and floating-point classification

**Correct some existing constants and floating-point classification properties.**

Currently, `Decimal.leastNonzeroMagnitude` has exponent `-127` when it should have exponent `-128` (because that's the exponent of the actual least nonzero magnitude).
The current state of affairs arose as a typo;
it was corrected for a time in swift-corelibs-foundation but never synchronized in the Apple overlay,
and it has now regressed for all platforms in swift-foundation.

Currently, `Decimal.pi` is rounded toward zero, in line with prior semantics for `FloatingPoint.pi`;
it should now be rounded to nearest in tandem with [SE-0552](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0552-float-pi-rounding.md) adopting a revised rounding requirement for `FloatingPoint.pi`.


### Other deprecations

Parts of `Decimal`'s public API surface were added to align with early drafts of Swift's floating-point protocols.
Not all are a good fit for `Decimal` as it is.
Moreover, the standard library subsequently changed the design of `FloatingPoint`, abandoning certain spellings,
but `Decimal` continued to retain those abandoned forms.

**Deprecate APIs that are misleading, use abandoned spellings, or both:**

- `isCanonical` in favor of `true` — this type hasn't done anything meaningful to adapt what it means to be 'canonical' and the property is always `true`, even for malformed encodings
- `isSignaling` (redundant abandoned spelling) in favor of `isSignalingNaN`
- `isTotallyOrdered(belowOrEqualTo:)` — the current implementation *doesn't* provide a total order (for example, NaN compared to NaN is `false`), and altering its behavior could cause binary compatibility problems; ironically, `<=` *does* provide a total order
- `leastFiniteMagnitude` in favor of `-Decimal.greatestFiniteMagnitude` — the constant actually gives the most negative finite value, which is *not* a (non-negative) magnitude
- `quietNaN` (redundant abandoned spelling) in favor of `nan`

## Detailed design

No new public APIs are added.
See accompanying implementation for full updated documentation comments detailing the revised semantics of the relevant existing APIs.

## Source compatibility

All Swift code that compiled in previous releases would continue to build.
Independent of this proposal, arithmetic results will be more precise with the next release due to implementation-level improvements.
Previously, as described above, users couldn't rely on accurate rounding;
if the proposal is *not* adopted, results in the next release will be recognizably rounded to nearest, ties away (`.plain`),
and if the proposal *is* adopted, results will be recognizably rounded to nearest, ties to even (`.bankers`).

Although it's possible for correctly rounded midpoint results to change with this proposal,
retaining the documented `.plain` rounding mode does not generally preserve existing results.
Consider, for example, the following test case:

```swift
let a = Decimal(
    _exponent: 0, _length: 8, _isNegative: 0, _isCompact: 1, _reserved: 0,
    _mantissa: (0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff))
let b = Decimal(
    _exponent: 0, _length: 1, _isNegative: 0, _isCompact: 0, _reserved: 0,
    _mantissa: (10, 0, 0, 0, 0, 0, 0, 0))
#expect((a + b)._mantissa.0 == 39322) // Round down.
```

In the 6.4 release, the test case passes because the currently shipping implementation spuriously *truncates*.
With proper `.plain` rounding actually implemented (a bugfix), the test case fails because the mantissa should be rounded up in that mode.
With `.bankers` rounding (this proposal), the original test case passes again.

On ABI-stable platforms, `Decimal` APIs are not inlinable (throughout).
The revised implementations that improve performance and precision rely on modern features such as `UInt128` and `InlineArray`, which are not backdeployed.
Therefore, such improved results and changes in the rounding of them are themselves not straightforward to backdeploy.
Binaries, whether compiled against a newer Foundation or an older one,
will perform `Decimal` arithmetic operations based on the version of Foundation available in the system on which they're running.

Users who require `.plain` rounding will be able to use `NSDecimal*` APIs that take an explicit rounding mode to obtain their desired results.
(These APIs themselves are of longstanding vintage and therefore have the broadest availability,
but again the actual bugfixes for precision and reliable rounding aren't backdeployed.)

With `Double` to shortest `Decimal` conversion the new default,
where the old implementation failed to choose the shortest representation,
results would change when code is rebuilt against a newer version of Foundation and run on a newer system.
As with arithmetic operations, the new implementations aren't backdeployed on older systems.

As a single obvious "right" answer for floating-point conversion is not necessarily agreed upon,
it's possible that quirks of the old `Double`-to-`Decimal` implementation are load-bearing for existing binaries,
with usages not obviously "improved" by suddenly swapping to shortest conversion at runtime.
Therefore, we'd retain legacy entrypoints for binaries compiled against older versions of Foundation
for both the `init(_: Double)` initializer and the `init(floatLiteral: Double)` initializer.
To maintain legacy behavior specifically in `ExpressibleByFloatLiteral` generic contexts for existing binaries (likely rare),
the platform owner would additionally need to add a linked-on-or-after runtime check.

Corrected constants and changes to subnormal classification could change the runtime behavior of code that explicitly observes the relevant properties.
These observable changes replace behavior that was insufficiently specified and/or incorrect with behavior that users can reason about and rely on.
As `Decimal` has never conformed to `FloatingPoint`, none of the corrected constants and changes to subnormal classification implicate protocol requirements that could affect the results of generic routines.

It's unlikely that the APIs proposed for deprecation are in wide use,
but in any case deprecation is source-compatible and directs users to more idiomatic spellings and/or less misleading alternatives.

## Implications on adoption

In that this proposal introduces no new features, implications on adoption are limited to the source compatibility concerns detailed above.

## Future directions

API additions to expose additional facilities directly on the `Decimal` type,
some not currently available at all and some only via legacy `NSDecimal*` APIs,
can be the subject of future proposals.
This might include, for example, arithmetic with explicit rounding mode and scale parameters,
conversions to and from `(U)Int128`, a `rounded(_:scale:)` API, or additional rounding modes.
Additionally, public APIs to access the bitwise representation of a value (or of its exponent and significand) could be desirable for performance-sensitive serialization.

## Alternatives considered

A broad alternative is to stick with `.plain` rounding as default, leave conversion behavior unspecified,
and to maintain current constants and duplicative APIs, all on compatibility grounds.
That is unattractive for `Decimal` because much of the behavior addressed here was never a coherent semantic contract:
rounding was not implemented consistently,
binary floating-point conversion behavior arose from implementation limitations,
constants and floating-point classification APIs were inaccurate,
and public members were retained from protocol designs subsequently abandoned.

If the proposed notion of subnormals is not adopted and no value is to be subnormal,
`leastNormalMagnitude` must nonetheless be changed in tandem with `leastNonzeroMagnitude` so that they continue to be equal.

## Acknowledgments

Thanks in particular to Steve Canon and Keith Bauer for prompting deeper consideration of effects on clients particularly on ABI-stable platforms.
