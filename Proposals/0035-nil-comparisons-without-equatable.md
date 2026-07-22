# `PredicateExpressions` API for `nil` comparisons without `Equatable` conformance within `#Predicate`s

* Proposal: [SF-0035](0035-nil-comparisons-without-equatable.md)
* Authors: [Matthew Turk](https://github.com/MatthewTurk247)
* Review Manager: [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Status: **Review (2026-07-22...2026-07-29**
* Bug: [swiftlang/swift-foundation#711](https://github.com/swiftlang/swift-foundation/issues/711)

## Revision history

* **v1** Initial version
* **v2** Replaced overloads with new builder functions

## Introduction/Motivation

Foundation’s current implementation of `build_Equal(lhs:rhs:)` requires `Equatable` output conformance for its left- and right-hand expressions under all circumstances. As such, a declared predicate that compares a non-`Equatable` optional variable to `nil` does not compile. For example:

```swift
struct Message {
    struct Subject {
        let value: String
    }

    let subject: Subject?
}

let predicate = #Predicate<Message> { $0.subject == nil }
// Referencing static method 'build_Equal(lhs:rhs:)' on 'Optional' requires that 'Message.Subject' conform to 'Equatable'
```

This outcome is inconsistent with the semantics of the Swift standard library, which allows for optionals to be compared with `nil` regardless of whether the wrapped type conforms to `Equatable`.

## Proposed solution and example

To better align the `#Predicate` experience with that of Swift itself, I propose a new set of builder functions. These overloads cover the special cases of an expansion where either parameter is an instance of `NilLiteral`. The above example would leverage this one:

```swift
public static func build_Equal<LHS, Wrapped>(
    lhs: LHS,
    nilLiteral: NilLiteral<Wrapped>
) -> Equal<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>
```

## Detailed design

Upon inspecting the operands of an equality or inequality, if either syntax node is of type `NilLiteralExprSyntax`, then `#Predicate` should produce argument labels of  `nilLiteral` and `lhs` or `rhs`.

Emit `build_Equal` in the `==`  case and use the `nilLiteral` label for the `nil` side. For the other argument, use the label associated with whichever side remains. Emit `build_NotEqual` in the `!=` case and follow the aforementioned procedure to place the argument labels.

If both sides are `nil`, fall back to `build_Equal(lhs:rhs:)`. Note that `#Predicate` may then require an explicit type annotation.

Each builder works by wrapping the non-`Equatable` variable expression in an `OptionalFlatMap`, whose initializer accepts a closure that can evaluate to different outputs based on whether a given input value is present. If a value is present, the closure should discard it and return `Value(true)`. Then, that optional result is compared to `nil` with the binary operator given by the name of the method. This approach is analogous to using a branch of an `if let` conditional binding as a comparand, for which existing API does not constrain the input to `Equatable` types.

```swift
@available(FoundationPreview 6.5, *)
extension PredicateExpressions {
    public static func build_Equal<LHS, Wrapped>(
        lhs: LHS,
        nilLiteral: NilLiteral<Wrapped>
    ) -> Equal<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>

    public static func build_Equal<Wrapped, RHS>(
        nilLiteral: NilLiteral<Wrapped>,
        rhs: RHS
    ) -> Equal<Value<Bool?>, OptionalFlatMap<RHS, Wrapped, Value<Bool>, Bool>>

    public static func build_NotEqual<LHS, Wrapped>(
        lhs: LHS,
        nilLiteral: NilLiteral<Wrapped>
    ) -> NotEqual<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>

    public static func build_NotEqual<Wrapped, RHS>(
        nilLiteral: NilLiteral<Wrapped>,
        rhs: RHS
    ) -> NotEqual<Value<Bool?>, OptionalFlatMap<RHS, Wrapped, Value<Bool>, Bool>>
}
```

## Impact on existing code

Given that the builder functions are purely additive and do not collide with existing symbols in the SDK, there should be no breaking changes.

## Alternatives considered

### Relaxing requirements for existing `build_Equal(lhs:rhs:)` and `build_NotEqual(lhs:rhs:)` methods

This would require relaxing several `Equatable` requirements elsewhere in the `#Predicate` infrastructure and public API. Such drastic changes could break existing evaluation functions or lead to other unforeseen consequences.

### Overloading `build_Equal(lhs:rhs:)` and `build_NotEqual(lhs:rhs:)`

An earlier version of this proposal shared the same `OptionalFlatMap` mechanism and likewise accepted a `NilLiteral` directly, differing only in that it kept the existing `lhs` and `rhs` argument labels. Reusing those labels made the new functions overloads of `build_Equal(lhs:rhs:)` and `build_NotEqual(lhs:rhs:)`. The overloading approach succeeded in preliminary testing, but building downstream raised issues. For a small number of projects using anonymous closure arguments, an SDK with the new overloads apparently pushed the Swift type checker to a “tipping point,” beyond which it would time out or fail to resolve as expected. Breaking downstream build routines in the name of a modest quality-of-life improvement is not acceptable.

The revised functions have a distinct `nilLiteral` label, and `#Predicate` selects the correct one by inspecting the operands, which shifts that responsibility of method resolution from the type checker to the macro.

### Introducing a new operator or expression type

This could make the intent behind the API clearer. And with a dedicated operator or expression type, Foundation could support more operations for non-`Equatable` optionals down the line. However, that abstract prospect—for a use case that is already narrow—is unlikely to outweigh the drawbacks of maintaining a greatly expanded API surface, absent newfound technical justification or input from the open-source community.
