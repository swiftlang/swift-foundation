# Support for `nil` comparisons without `Equatable` conformance

* Proposal: [SF-NNNN](NNNN-nil-comparisons-without-equatable.md)
* Authors: [Matthew Turk](https://github.com/MatthewTurk247)
* Review Manager: TBD
* Status: **Pitch**
* Bug: [swiftlang/swift-foundation#711](https://github.com/swiftlang/swift-foundation/issues/711)

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

To better align the `#Predicate` experience with that of Swift itself, I propose a new set of `build_Equal(lhs:rhs:)` and `build_NotEqual(lhs:rhs:)` overloads. These overloads cover the special cases of an expansion where either parameter is an instance of `NilLiteral`. The above example would leverage this one:

```swift
public static func build_Equal<LHS, Wrapped>(
    lhs: LHS,
    rhs: NilLiteral<Wrapped>
) -> Equal<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>
```

## Detailed design

Each overload works by wrapping the non-`Equatable` variable expression in an `OptionalFlatMap`, whose initializer accepts a closure that can evaluate to different outputs based on whether a given input value is present. If a value is present, the closure should discard it and return `Value(true)`. Then, that optional result is compared to `nil` with the binary operator given by the name of the overload. This approach is analogous to using a branch of an `if let` conditional binding as a comparand, for which existing API does not constrain the input to `Equatable` types.

```swift
@available(FoundationPreview 6.4, *)
extension PredicateExpressions {
    public static func build_Equal<LHS, Wrapped>(
        lhs: LHS,
        rhs: NilLiteral<Wrapped>
    ) -> Equal<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>

    public static func build_Equal<Wrapped, RHS>(
        lhs: NilLiteral<Wrapped>,
        rhs: RHS
    ) -> Equal<Value<Bool?>, OptionalFlatMap<RHS, Wrapped, Value<Bool>, Bool>>

    public static func build_NotEqual<LHS, Wrapped>(
        lhs: LHS,
        rhs: NilLiteral<Wrapped>
    ) -> NotEqual<OptionalFlatMap<LHS, Wrapped, Value<Bool>, Bool>, Value<Bool?>>

    public static func build_NotEqual<Wrapped, RHS>(
        lhs: NilLiteral<Wrapped>,
        rhs: RHS
    ) -> NotEqual<Value<Bool?>, OptionalFlatMap<RHS, Wrapped, Value<Bool>, Bool>>
}
```

With Swift’s method resolution, the compiler can choose the most specific overload available, so these will be preferred over the broader ones in ambiguous cases.

## Impact on existing code

Given that the overloads are purely additive and the macro will still generate the same source code as before, there should be no breaking changes.

The new method resolution paths may, however, affect observed compiler performance, particularly for predicate code that already heavily relies on type inference. Below is a summary of compiling sample source files, using an SDK without these new overloads and using an SDK with them.

| Number of predicates in file | Type check time without new overloads (s) | Type check time with new overloads (s) |
|------------------------------|-------------------------------------------|----------------------------------------|
| 10                           | 6.073                                     | 6.135                                  |
| 20                           | 8.599                                     | 8.398                                  |
| 30                           | 11.129                                    | 11.466                                 |
| 40                           | 13.802                                    | 13.732                                 |
| 50                           | 16.266                                    | 16.199                                 |
| 60                           | 18.933                                    | 18.866                                 |
| 70                           | 21.265                                    | 21.458                                 |
| 80                           | 23.999                                    | 23.999                                 |
| 90                           | 26.466                                    | 26.599                                 |
| 100                          | 29.065                                    | 28.999                                 |
| 110                          | 31.599                                    | 31.666                                 |
| 120                          | 34.399                                    | 34.466                                 |
| 130                          | 37.266                                    | 36.665                                 |
| 140                          | 39.985                                    | 39.274                                 |
| 150                          | 42.437                                    | 42.099                                 |
| 160                          | 44.547                                    | 44.798                                 |
| 170                          | 47.298                                    | 47.282                                 |
| 180                          | 49.497                                    | 49.577                                 |
| 190                          | 52.414                                    | 52.251                                 |
| 200                          | 55.247                                    | 54.831                                 |

At a glance, an impact on performance is not noticeable.

## Alternatives considered

### Relaxing requirements for existing `build_Equal(lhs:rhs:)` and `build_NotEqual(lhs:rhs:)` methods

This would require relaxing several `Equatable` requirements elsewhere in the `#Predicate` infrastructure and public API. Such drastic changes could break existing evaluation functions or lead to other unforeseen consequences.

### Introducing a new operator or expression type

This could make the intent behind the API clearer. And with a dedicated operator or expression type, Foundation could support more operations for non-`Equatable` optionals down the line. However, that abstract prospect—for a use case that is already narrow—is unlikely to outweigh the drawbacks of maintaining a greatly expanded API surface, absent newfound technical justification or input from the open-source community.