# Initializers for joining a sequence of predicates

* Proposal: [SF-0036](0036-initializers-join-predicates.md)
* Authors: [Matthew Turk](https://github.com/MatthewTurk247)
* Review Manager: Jeremy S
* Status: **Approved**
* Review: ([pitch](https://forums.swift.org/t/pitch-initializers-for-joining-a-sequence-of-predicates/85652) [review](https://forums.swift.org/t/review-sf-0036-initializers-for-joining-a-sequence-of-predicates/85810))

## Introduction

Joining a fixed number of predicates with a logical operator is possible by initializing another predicate and evaluating each subpredicate inside of `#Predicate`’s builder closure:

```swift
#Predicate<Message> { fooPredicate.evaluate($0) && barPredicate.evaluate($0) }
```

However, a common use case of `Predicate` is to dynamically construct a conjunction or disjunction of several user-specified filters. For example, suppose a user-facing program displays entries from a remote or on-disk database of books. If someone wants to search through these entries, maybe they’ll enter the name of an author, a range of publication dates, and a genre. Their search preferences aren’t known ahead of time, and neither is the number of preferences, so it is reasonable to store the individual filter inputs in a dynamically allocated array and then construct a final filter from the elements. Historically, `+[NSPredicate andPredicateWithSubpredicates:]` and `+[NSPredicate orPredicateWithSubpredicates:]` have served the role of piecing together such elements.

`Predicate` does not have equivalent methods, so developers must craft their own or wrangle existing API into the following shape:

```swift
let predicates = [
    #Predicate<Book> { $0.title.localizedStandardContains("Swift") },
    #Predicate<Book> { $0.rating > 4 / 5 },
    #Predicate<Book> { $0.series != nil }
]

let conjunction = Predicate<Book> {
    var pieces: any StandardPredicateExpression<Bool> = PredicateExpressions.build_evaluate(PredicateExpressions.build_Arg(predicates[0]), $0)

    func append<T: StandardPredicateExpression<Bool>, U: StandardPredicateExpression<Bool>>(_ leftPredicate: T, _ rightPredicate: U) {
        // The generic context is required for this line to compile.
        pieces = PredicateExpressions.build_Conjunction(lhs: leftPredicate, rhs: rightPredicate)
    }

    for next in predicates.dropFirst() {
        append(pieces, PredicateExpressions.build_evaluate(PredicateExpressions.build_Arg(next), $0))
    }

    return pieces
}
```

## Motivation

The above solution is not particularly obvious and has a few jagged edges. One must extract the first subpredicate, adjust the original array, and directly construct a result instead of relying on `#Predicate` for builder expansion.

Meaningful alternatives for joining predicates do exist in the SDK (discussed later), but they leverage undocumented semantics. A better developer experience is possible with additional API and carefully considered ergonomics for wide-ranging use cases.

## Proposed solution and example

To deliver the desired ergonomics and encapsulate expression-building complexity, I propose two new initializers: `Predicate(all:)` and `Predicate(any:)`. Each accepts a homogeneous collection of subpredicates and produces a corresponding conjunction or disjunction, respectively. For example:

```swift
let predicates = [#Predicate<Int> { $0 > 2 }, #Predicate<Int> { $0 <= 9 }, #Predicate<Int> { $0 != 5 }, #Predicate<Int> { $0 % 2 != 0 }]
let conjunction = Predicate(all: predicates)
```

## Detailed design

`Predicate(all:)` creates a `Predicate` such that all subpredicates must be satisfied for the provided input. In the case of zero subpredicates, it returns `Predicate.true`.

`Predicate(any:)` creates a `Predicate` such that at least one subpredicate must be satisfied for the provided input. In the case of zero subpredicates, it returns `Predicate.false`.

```swift
@available(FoundationPreview 6.4, *)
extension Predicate {
    public init(all subpredicates: some BidirectionalCollection<Self>)
    public init(any subpredicates: some BidirectionalCollection<Self>)
}
```

## Impact on existing code

These changes are purely additive. No existing source code should be affected.

## Alternatives considered

### Do nothing

Instead of adding new API, we could promote an uncommon approach that captures an array of subpredicates inside of a new predicate and builds a `PredicateExpressions.SequenceAllSatisfy` representation of the conjunction:

```swift
#Predicate<Book> { input in
    array.allSatisfy { $0.evaluate(input) }
}
```

Similarly, for the disjunction case (`PredicateExpressions.SequenceContainsWhere`):

```swift
#Predicate<Book> { input in
    array.contains { $0.evaluate(input) }
}
```

This pattern works, but it is not easily discoverable, nor does it appear in public documentation. The proposed initializers are more concise, more expressive of intent, and more familiar for those coming from `NSCompoundPredicate`.

### Add initializers `Predicate(conjunction:)` and `Predicate(disjunction:)`

```swift
extension Predicate {
    public init(conjunction subpredicates: some BidirectionalCollection<Self>)
    public init(disjunction subpredicates: some BidirectionalCollection<Self>)
}
```

These are fine, semantically speaking, but the parameter labels may be unclear to many without pausing to trace back a connection to first-order logic. Furthermore, `Predicate` was designed to elide operators named as functions and instead use Swift syntax directly, with intuitive, analogous semantics. Something like `Predicate<Int>(conjunction: predicates)` may not remain true to this vision.

### Add initializers `Predicate(allOf:)` and `Predicate(anyOf:)`

```swift
extension Predicate {
    public init(allOf subpredicates: some BidirectionalCollection<Self>)
    public init(anyOf subpredicates: some BidirectionalCollection<Self>)
}
```

`Predicate(allOf: filters)` and `Predicate(anyOf: filters)` read as noun phrases and avoid any possible confusion with the `any` keyword by using compound labels. It’s a viable alternative to the proposed `all:` and `any:` labels, trading brevity for slightly more explicit grammar. In practice, the input type already suggests that the labels mean “all of” and “any of.”

### Add operator overloads as extensions on `Predicate`

These overloads would be akin to the standard `&&` and `||` for Boolean expressions, except with `Predicate` the instances would remain highly structured and prepared for later evaluation. The advantage would be a capability to implicitly bracket the subpredicates in a shared lexical scope for the builder closure. The earlier example of a fixed number of predicates could be rewritten like so, maintaining type safety:

```swift
fooPredicate && barPredicate
```

Then a developer could join predicates in whatever manner they already prefer to accumulate a collection of values. For example:

```swift
let additionalPredicates = [authorPredicate, publicationDatePredicate, genrePredicate]
let result = additionalPredicates.reduce(onSalePredicate, &&)
```

The problem, however, is that `&&` and `||` are global functions in a global namespace. Adding new overloads—even with constrained types—expands the search space that the Swift type checker must evaluate at every occurrence of these operators throughout a codebase. Naturally, such a change would increase average build times. In fact, one reason that `Predicate` has an associated freestanding macro is to transform operators into functions that are scoped to the `PredicateExpressions` namespace, sidestepping a need for unsustainable new overloads. With this proposal, too, the convenience of overloading `&&` and `||` is not worth the cost.

### Add static methods `Predicate.all(_:)` and `Predicate.any(_:)`

A more minimal naming approach would place the quantifier as the method name itself:

```swift
extension Predicate {
    public static func all(_ subpredicates: some BidirectionalCollection<Self>) -> Self
    public static func any(_ subpredicates: some BidirectionalCollection<Self>) -> Self
}
```

These are concise and read naturally. However, `any` visually collides with Swift’s `any` keyword used in existential type syntax, even if it is technically a valid function identifier.

### Add static methods `Predicate.and(_:)` and `Predicate.or(_:)`

```swift
extension Predicate {
    public static func and(_ subpredicates: some BidirectionalCollection<Self>) -> Self
    public static func or(_ subpredicates: some BidirectionalCollection<Self>) -> Self
}
```

A line like `Predicate.and(filters)`, when taken out of context, does not communicate what kind of value is being constructed.

### Add methods on `Collection` instead of `Predicate`

Rather than `Predicate` initializers, the API could consist of an extension on collections of predicates:

```swift
extension BidirectionalCollection where Element == Predicate<each Input> {
    public func conjunction() -> Predicate<each Input>
    public func disjunction() -> Predicate<each Input>
}
```

A line like `predicates.conjunction()` reads naturally and mirrors patterns like `joined(separator:)` on `Collection` where `Element` conforms to `StringProtocol`. The downside is discoverability. A developer looking at `Predicate`’s API surface would not find it, and predicate-specific operations would appear in the generic `Collection` documentation where they would stick out. Initializers on `Predicate` are more likely to appear in documentation and autocomplete when exploring the type.

### Add static methods `Predicate.compound(all:)` and `Predicate.compound(any:)`

The API could use static methods with a shared `compound` method name:

```swift
extension Predicate {
    public static func compound(all subpredicates: some BidirectionalCollection<Self>) -> Self
    public static func compound(any subpredicates: some BidirectionalCollection<Self>) -> Self
}
```

A developer typing `Predicate.compound(` would see both variants together in autocomplete, reinforcing that they are counterparts. However, newcomers may not recognize this terminology from `NSCompoundPredicate`. Names containing `compound` would need to be pervasively used throughout the Swift ecosystem to feel natural. Initializers are a more conventional shape for constructing a value from inputs, and the `all` and `any` labels are sufficiently descriptive on their own without an additional grouping word.
