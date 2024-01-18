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
    public struct Filter<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output: Sequence,
        RHS.Output == Bool
    {
        public typealias Element = LHS.Output.Element
        public typealias Output = [Element]
        
        public let sequence: LHS
        public let filter: RHS
        public let variable: Variable<Element>
        
        public init(_ sequence: LHS, _ builder: (Variable<Element>) -> RHS) {
            self.variable = Variable()
            self.sequence = sequence
            self.filter = builder(variable)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            var mutableBindings = bindings
            return try sequence.evaluate(bindings).filter {
                mutableBindings[variable] = $0
                return try filter.evaluate(mutableBindings)
            }
        }
    }
    
    public static func build_filter<LHS, RHS>(_ lhs: LHS, _ builder: (Variable<LHS.Output.Element>) -> RHS) -> Filter<LHS, RHS> {
        Filter(lhs, builder)
    }
}

@available(FoundationPredicate 0.3, *)
extension PredicateExpressions.Filter : CustomStringConvertible {
    public var description: String {
        "Filter(sequence: \(sequence), variable: \(variable), filter: \(filter))"
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Filter : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Filter : Codable where LHS : Codable, RHS : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(sequence)
        try container.encode(filter)
        try container.encode(variable)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        sequence = try container.decode(LHS.self)
        filter = try container.decode(RHS.self)
        variable = try container.decode(PredicateExpressions.Variable<Element>.self)
    }
}

@available(FoundationPredicate 0.1, *)
extension PredicateExpressions.Filter : Sendable where LHS : Sendable, RHS : Sendable {}
