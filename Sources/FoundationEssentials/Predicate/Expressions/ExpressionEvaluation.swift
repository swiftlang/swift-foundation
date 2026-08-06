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

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    public struct ExpressionEvaluate<
        Transformation : PredicateExpression,
        each Input : PredicateExpression,
        Output
    > : PredicateExpression
    where
    Transformation.Output == Expression<repeat (each Input).Output, Output>
    {
        
        public let expression: Transformation
        public let input: (repeat each Input)
        
        public init(expression: Transformation, input: repeat each Input) {
            self.expression = expression
            self.input = (repeat each input)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try expression.evaluate(bindings).evaluate(repeat try (each input).evaluate(bindings))
        }
    }
    
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    public static func build_evaluate<Transformation, each Input, Output>(_ expression: Transformation, _ input: repeat each Input) -> ExpressionEvaluate<Transformation, repeat each Input, Output> {
        ExpressionEvaluate(expression: expression, input: repeat each input)
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension PredicateExpressions.ExpressionEvaluate : CustomStringConvertible {
    public var description: String {
        "ExpressionEvaluate(expression: \(expression), input: \(input))"
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension PredicateExpressions.ExpressionEvaluate : StandardPredicateExpression where Transformation : StandardPredicateExpression, repeat each Input : StandardPredicateExpression {}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension PredicateExpressions.ExpressionEvaluate : Codable where Transformation : Codable, repeat each Input : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(expression)
        repeat try container.encode(each input)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.expression = try container.decode(Transformation.self)
        self.input = (repeat try container.decode((each Input).self))
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension PredicateExpressions.ExpressionEvaluate : Sendable where Transformation : Sendable, repeat each Input : Sendable {}
