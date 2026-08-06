//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    @available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
    public struct PredicateEvaluate<
        Condition : PredicateExpression,
        each Input : PredicateExpression
    > : PredicateExpression
    where
        Condition.Output == Predicate<repeat (each Input).Output>
    {
        
        public typealias Output = Bool
        
        public let predicate: Condition
        public let input: (repeat each Input)
        
        public init(predicate: Condition, input: repeat each Input) {
            self.predicate = predicate
            self.input = (repeat each input)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try predicate.evaluate(bindings).evaluate(repeat try (each input).evaluate(bindings))
        }
    }
    
    @available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
    public static func build_evaluate<Condition, each Input>(_ predicate: Condition, _ input: repeat each Input) -> PredicateEvaluate<Condition, repeat each Input> {
        PredicateEvaluate<Condition, repeat each Input>(predicate: predicate, input: repeat each input)
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.PredicateEvaluate : CustomStringConvertible {
    public var description: String {
        "PredicateEvaluate(predicate: \(predicate), input: \(input))"
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.PredicateEvaluate : StandardPredicateExpression where Condition : StandardPredicateExpression, repeat each Input : StandardPredicateExpression {}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.PredicateEvaluate : Codable where Condition : Codable, repeat each Input : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(predicate)
        repeat try container.encode(each input)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.predicate = try container.decode(Condition.self)
        self.input = (repeat try container.decode((each Input).self))
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.PredicateEvaluate : Sendable where Condition : Sendable, repeat each Input : Sendable {}
#endif
