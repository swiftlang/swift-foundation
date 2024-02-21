# `#Expression` Macro and Type

* Proposal: [SF-0006](0006-expression-macro.md)
* Author(s): [Jeremy Schonfeld](https://github.com/jmschonfeld)
* Review Manager: [Tina Liu](https://github.com/itingliu)
* Bug: rdar://122026982
* Status: **Active review: Feb 22, 2024...Feb 29, 2024**
* Implementation: [apple/swift-foundation#432](https://github.com/apple/swift-foundation/pull/432)

## Revision history

* **v1** Initial version

## Introduction

Last year, we introduced the new `#Predicate` macro and its associated type `Predicate`. This macro allows developers to craft boolean expressions via standard swift closure syntax in order to create `Sendable`, serializable, and introspectable predicates for use in higher level APIs such as SwiftData. Since `Predicate` represents a boolean expression, its evaluate function simply returns a `Bool` value and its contained expression is constrained to an output type of `Bool`. However, there are some additional situations in which developers may need to create these serializable/introspectable expressions to reference values that do not produce booleans but rather produce arbitrary types.

## Motivation

There are a few cases where expressions not constrained to a boolean output are helpful. For example, developers may wish to fetch specific values from a model/row in a database rather than the entire model (this is especially helpful when fetching small pieces of information from large models without paging the full model into memory). `Predicate` is extremely useful in filtering which rows should be selected, but selecting just a singular field (or combination of fields) from a row is not possible when introspectable query pieces are constrained to boolean outputs. Instead, developers may wish to express that only a certain keypath (or multiple keypaths concatenated together) should be selected from a model in the database. As a concrete example, see the [`NSFetchRequest.propertiesToFetch`](https://developer.apple.com/documentation/coredata/nsfetchrequest/1506851-propertiestofetch) API. Additionally, non-boolean expressions can be helpful when producing other types of mappings such as mapping properties of a model/row in a database into another shape (such as a spotlight entity). Non-boolean expressions can be used to represent mappings from one model/entity's properties to a different model/entity's properties. For example, developers may wish to use natural swift expressions to represent mapping a model to a [`CSSearchableItemAttributeSet`](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset).

## Proposed solution and example

In order to support these types of APIs in SwiftData and other frameworks, I propose adding a new `#Expression` macro and associated `Expression` type. This type will closely mirror the API of `Predicate` (and will share a lot of the same implementation details and support APIs) but will be generic over the output type rather than constraining the output type to `Bool`. For example, developers would be able to represent the following:

```swift
// Example models
class Library {
	var albums: [Album]
}

class Album {
	var contents: [Photo]
	var isHidden: Bool
}

let libraryAlbumCountExpression = #Expression<Library, Int> { library in
	library.albums.filter {
		!$0.isHidden
	}.count
}

// Evaluate in-memory or pass to some API
let numberOfAlbums = try libraryAlbumCountExpression.evaluate(someLibrary)
```

## Detailed design

In order to support these use cases, I propose the following new APIs:

### `Expression` Type

```swift
@available(FoundationPredicate 0.4, *)
public struct Expression<each Input, Output> : Sendable, Codable, CodableWithConfiguration, CustomStringConvertible, CustomDebugStringConvertible {
    public typealias EncodingConfiguration = PredicateCodableConfiguration
    public typealias DecodingConfiguration = PredicateCodableConfiguration
    
    public let expression: any StandardPredicateExpression<Output>
    public let variable: (repeat PredicateExpressions.Variable<each Input>)
    
    public init(_ builder: (repeat PredicateExpressions.Variable<each Input>) -> any StandardPredicateExpression<Output>)
    
    public func evaluate(_ input: repeat each Input) throws -> Output
}
```

_Note: `Expression` also uses the same `StandardPredicateExpression` protocol that `Predicate` uses to constrain its operators. The set of supported operators will be the same between the two types, with the notable difference that the root output must be a `Bool` for `Predicate` while it can be any generic type `Output` for `Expression`._

### `#Expression` Macro

I propose the following new `#Expression` macro which will transform closures provided to `#Expression` into a concrete `Expression` instance just like the `#Predicate` macro:

```swift
@freestanding(expression)
@available(FoundationPredicate 0.4, *)
public macro Expression<each Input, Output>(_ body: (repeat each Input) -> Output) -> Expression<repeat each Input, Output> = #externalMacro(module: "FoundationMacros", type: "ExpressionMacro")
```

### `ExpressionEvaluate` Operator

I propose a new `ExpressionEvaluate` operator which will represent evaluation of an `Expression` within a parent `Expression` or `Predicate` (just like the `PredicateEvaluate` operator which allows nesting evaluation of a `Predicate` within a parent `Predicate` or `Expression`):

```swift
@available(FoundationPredicate 0.4, *)
extension PredicateExpressions {
    public struct ExpressionEvaluate<
        Transformation : PredicateExpression,
        each Input : PredicateExpression,
        Output
    > : PredicateExpression, CustomStringConvertible
    where
        Transformation.Output == Expression<repeat (each Input).Output, Output>
    {
        
        public let expression: Transformation
        public let input: (repeat each Input)
        
        public init(expression: Transformation, input: repeat each Input)
    }
    
    public static func build_evaluate<Transformation, each Input, Output>(_ expression: Transformation, _ input: repeat each Input) -> ExpressionEvaluate<Transformation, repeat each Input, Output>
}

@available(FoundationPredicate 0.4, *)
extension PredicateExpressions.ExpressionEvaluate : StandardPredicateExpression where Transformation : StandardPredicateExpression, repeat each Input : StandardPredicateExpression {}

@available(FoundationPredicate 0.4, *)
extension PredicateExpressions.ExpressionEvaluate : Codable where Transformation : Codable, repeat each Input : Codable {}

@available(FoundationPredicate 0.4, *)
extension PredicateExpressions.ExpressionEvaluate : Sendable where Transformation : Sendable, repeat each Input : Sendable {}
```

### Conversion between `Expression` and `Predicate`

I propose adding non-failing conversion between the `Expression` and `Predicate` types (constrained to an `Expression` with an `Output` of type `Bool`):

```swift
@available(FoundationPredicate 0.4, *)
extension Predicate {
    public init(_ expression: Expression<repeat each Input, Bool>)
}

@available(FoundationPredicate 0.4, *)
extension Expression {
    public init(_ predicate: Predicate<repeat each Input>) where Output == Bool
}
```

### Conversion to `NSExpression`

Lastly, I propose adding failable conversion of an `Expression` to an `NSExpression`:

```swift
@available(FoundationPredicate 0.4, *)
extension NSExpression {
    public init?<Input, Output>(_ expression: Expression<Input, Output>) where Input : NSObject
}
```

_Note: Conversion to `NSExpression` will support the same set of operators and have the same set of constraints as `Predicate` to `NSPredicate` conversion (most notably that only keypaths to `@objc` properties and a select set of constant values are supported)_

### `Codable` Support

Unfortunately, the existing support functions added to `(Un)Keyed{Encoding,Decoding}Container` also have an `Output == Bool` constraint making them unusable for implementing `Codable`/`CodableWithConfiguration` conformances on custom `Expression` types. In order to support this, I propose adding the following APIs that mirror the existing APIs but do not have an `Output == Bool` constraint:

_Note: The `(Un)KeyedEncodingContainer` functions are marked as `@_disfavoredOverload` in order to prefer the existing APIs when possible. The `(Un)KeyedDecodingContainer` functions are made unambiguous by the inclusion of a new `output:` parameter to specify the `Output` type for the returned `PredicateExpression`_

```swift
@available(FoundationPredicate 0.4, *)
extension KeyedEncodingContainer {
    @_disfavoredOverload
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, each Input>(_ expression: T, forKey key: Self.Key, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws
    
    @_disfavoredOverload
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, each Input>(_ expression: T?, forKey key: Self.Key, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws
}

@available(FoundationPredicate 0.4, *)
extension KeyedDecodingContainer {
    public mutating func decodePredicateExpression<each Input, Output>(forKey key: Self.Key, input: repeat (each Input).Type, output: Output.Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Output>, variable: (repeat PredicateExpressions.Variable<each Input>))
    public mutating func decodePredicateExpressionIfPresent<each Input, Output>(forKey key: Self.Key, input: repeat (each Input).Type, output: Output.Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Output>, variable: (repeat PredicateExpressions.Variable<each Input>))?
}

@available(FoundationPredicate 0.4, *)
extension UnkeyedEncodingContainer {
    @_disfavoredOverload
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, each Input>(_ expression: T, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws
    
    @_disfavoredOverload
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, each Input>(_ expression: T?, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws
}

@available(FoundationPredicate 0.4, *)
extension UnkeyedDecodingContainer {
    public mutating func decodePredicateExpression<each Input, Output>(input: repeat (each Input).Type, output: Output.Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Output>, variable: (repeat PredicateExpressions.Variable<each Input>))
    public mutating func decodePredicateExpressionIfPresent<each Input, Output>(input: repeat (each Input).Type, output: Output.Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Output>, variable: (repeat PredicateExpressions.Variable<each Input>))?
}
```

## Source compatibility

These changes are additive only and there is no impact on existing code.

## Implications on adoption

The added declarations will have `FoundationPredicate 0.4` availability.

## Alternatives considered

### Using `KeyPath` instead of a new `Expression` type

A majority of the operations that developers would write in an `Expression` are likely to just be `KeyPath`s, so I previously investigated just using `KeyPath` as the currency type for these expressions instead of `Expression`. However, there are some cases where `KeyPath` is not enough:

- Aggregate functions such as `min()` and `max()` which are function calls and cannot be represented as a `KeyPath`
- Conditional logic such as using if/else expressions or ternaries to vend different data based on some property

### Defining `Predicate` in terms of `Expression`

For most purposes, `Predicate` is effectively the same as `Expression where Output == Bool`. In an ideal world, perhaps there would be an avenue for definining `Predicate` in terms of `Expression` (i.e. via a `typealias` of sorts) such that conversion between the two types would be unnecessary and we would not need to duplicate some of the similar API surfaces between `Expression` and `Predicate`. However, since `Predicate` is already shipping as ABI in the SDK we cannot change its definition trivially and the reasons for this approach mentioned above are not significant enough to warrant jumping through hoops to perform this re-coring of `Predicate` on `Expression`. Instead, I don't expect the presence of both of these types to have significant impact on the developer experience or maintenance burden so I propose adding the two types side-by-side as discussed above.