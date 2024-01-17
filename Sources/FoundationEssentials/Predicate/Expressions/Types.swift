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

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions {
    public struct ConditionalCast<
        Input : PredicateExpression,
        Desired
    > : PredicateExpression
    {
        public typealias Output = Optional<Desired>
        public let input: Input
        
        public init(_ input: Input) {
            self.input = input
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            return try input.evaluate(bindings) as? Desired
        }
    }
    
    public struct ForceCast<
        Input : PredicateExpression,
        Desired
    > : PredicateExpression
    {
        public typealias Output = Desired
        public let input: Input
        
        public init(_ input: Input) {
            self.input = input
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let input = try input.evaluate(bindings)
            guard let output = input as? Desired else {
                throw PredicateError(.forceCastFailure("Failed to cast value of type '\(type(of: input))' to '\(Desired.self)'"))
            }
            return output
        }
    }
    
    public struct TypeCheck<
        Input : PredicateExpression,
        Desired
    > : PredicateExpression
    {
        public typealias Output = Bool
        public let input: Input
        
        public init(_ input: Input) {
            self.input = input
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            return try input.evaluate(bindings) is Desired
        }
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ConditionalCast : CustomStringConvertible {
    public var description: String {
        "ConditionalCast(input: \(input), desiredType: \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.ForceCast : CustomStringConvertible {
    public var description: String {
        "ForceCast(input: \(input), desiredType: \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.TypeCheck : CustomStringConvertible {
    public var description: String {
        "TypeCheck(input: \(input), desiredType: \(_typeName(Desired.self)))"
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ConditionalCast : StandardPredicateExpression where Input : StandardPredicateExpression {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ForceCast : StandardPredicateExpression where Input : StandardPredicateExpression {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.TypeCheck : StandardPredicateExpression where Input : StandardPredicateExpression {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ConditionalCast : Codable where Input : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(input)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        input = try container.decode(Input.self)
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ForceCast : Codable where Input : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(input)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        input = try container.decode(Input.self)
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.TypeCheck : Codable where Input : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(input)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        input = try container.decode(Input.self)
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ConditionalCast : Sendable where Input : Sendable {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.ForceCast : Sendable where Input : Sendable {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.TypeCheck : Sendable where Input : Sendable {}
