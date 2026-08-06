//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public struct Expression<each Input, Output> : Sendable {
    public let expression : any StandardPredicateExpression<Output>
    public let variable: (repeat PredicateExpressions.Variable<each Input>)
    
    public init(_ builder: (repeat PredicateExpressions.Variable<each Input>) -> any StandardPredicateExpression<Output>) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = builder(repeat each variable)
    }
    
    public func evaluate(_ input: repeat each Input) throws -> Output {
        try expression.evaluate(
            .init(repeat (each variable, each input))
        )
    }
}

#if hasFeature(Macros)
@freestanding(expression)
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public macro Expression<each Input, Output>(_ body: (repeat each Input) -> Output) -> Expression<repeat each Input, Output> = #externalMacro(module: "FoundationMacros", type: "ExpressionMacro")
#endif
