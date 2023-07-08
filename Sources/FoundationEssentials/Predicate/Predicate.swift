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

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public struct Predicate<each Input> : Sendable {
    public let expression : any StandardPredicateExpression<Bool>
    public let variable: (repeat PredicateExpressions.Variable<each Input>)

    public init<E: StandardPredicateExpression<Bool>>(_ builder: (repeat PredicateExpressions.Variable<each Input>) -> E) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = builder(repeat each variable.element)
    }
    
    public func evaluate(_ input: repeat each Input) throws -> Bool {
        try expression.evaluate(
            .init(repeat (each variable.element, each input))
        )
    }
}

#if !os(Linux) && !os(Windows)
@freestanding(expression)
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public macro Predicate<Input>(_ body: (Input) -> Bool) -> Predicate<Input> = #externalMacro(module: "FoundationMacros", type: "PredicateMacro")
#endif

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
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
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
@frozen @_nonSendable public enum PredicateExpressions {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension Sequence {
    public func filter(_ predicate: Predicate<Element>) throws -> [Element] {
        try self.filter {
            try predicate.evaluate($0)
        }
    }
}
