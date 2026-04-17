//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A logical condition used to test a set of input values for searching or filtering.
///
/// A predicate is a logical condition that evaluates to a Boolean value (true or false). You use predicates for operations like filtering a collection or searching for matching elements.
///
/// To create a predicate, use the `Predicate(_:)` macro. For example:
///
/// ```swift
/// let messagePredicate = #Predicate<Message> { message in
///     message.length < 100 && message.sender == "Jeremy"
/// }
/// ```
///
/// In the example above, the closure that contains the predicate's conditions takes one argument — the value being tested. Even though you write the predicate using a closure, the macro transforms that closure into a predicate when you compile. The code in the closure isn't run as part of your program.
///
/// In the predicate's definition, you can use the following operations:
///
/// - Arithmetic (`+`, `-`, `*`, `/`, `%`)
/// - Unary minus (`-`)
/// - Range (`...`, `..<`)
/// - Comparison (`<`, `<=`, `>`, `>=`, `==`, `!=`)
/// - Ternary conditional (`?:`)
/// - Conditional expressions
/// - Boolean logic (`&&`, `||`, `!`)
/// - Swift optionals (`?`, `??`, `!`, `flatMap(_:)`, `if`-`let` expressions)
/// - Types (`as`, `as?`, `as!`, `is`)
/// - Sequence operations (`allSatisfy()`, `filter()`, `contains()`, `contains(where:)`, `starts(with:)`, `max()`, `min()`)
/// - Subscript and member access (`[]`, `.`)
/// - String comparisons (`contains(_:)`, `localizedStandardContains(_:)`, `caseInsensitiveCompare(_:)`, `localizedCompare(_:)`)
///
/// A predicate can't contain any nested declarations, use any flow control such as `for` loops,
/// or modify variables from its enclosing scope. However, it can refer to constants that are in
/// scope.
///
/// To express more complex queries, you can nest expressions in the predicate:
///
/// ```swift
/// let messagePredicate = #Predicate<Message> { message in
///     message.recipients.contains {
///         $0.firstName == message.sender.firstName
///     }
/// }
/// ```
///
/// You can safely encode and decode predicates, pass predicates across concurrency boundaries, and load a predicate from a file. To define a list of types and key paths that are allowed when reading an archived predicate, use ``PredicateCodableConfiguration``.
///
/// You can transform a predicate into another representation — for example, to express a predicate in another query language, or to create a modified predicate — using the ``expression`` property.
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public struct Predicate<each Input> : Sendable {
    /// The component expressions of the predicate.
    public let expression : any StandardPredicateExpression<Bool>
    public let variable: (repeat PredicateExpressions.Variable<each Input>)
    
    public init(_ builder: (repeat PredicateExpressions.Variable<each Input>) -> any StandardPredicateExpression<Bool>) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = builder(repeat each variable)
    }
    
    public func evaluate(_ input: repeat each Input) throws -> Bool {
        try expression.evaluate(
            .init(repeat (each variable, each input))
        )
    }
}

#if hasFeature(Macros)
@freestanding(expression)
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public macro Predicate<each Input>(_ body: (repeat each Input) -> Bool) -> Predicate<repeat each Input> = #externalMacro(module: "FoundationMacros", type: "PredicateMacro")
#endif

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Predicate {
    private init(value: Bool) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = PredicateExpressions.Value(value)
    }
    
    public static var `true`: Self {
        Self(value: true)
    }
    
    public static var `false`: Self {
        Self(value: false)
    }
}


// Namespace for operator expressions
/// The expressions that make up a predicate.
///
/// Don't use this type directly. When you call the `Predicate(_:)` macro in
/// your code, the expansion of that macro produces these values.
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@frozen public enum PredicateExpressions {}

@available(macOS, unavailable, introduced: 14.0)
@available(iOS, unavailable, introduced: 17.0)
@available(tvOS, unavailable, introduced: 17.0)
@available(watchOS, unavailable, introduced: 10.0)
@available(*, unavailable)
extension PredicateExpressions : Sendable {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Sequence {
    public func filter(_ predicate: Predicate<Element>) throws -> [Element] {
        try self.filter {
            try predicate.evaluate($0)
        }
    }
}
