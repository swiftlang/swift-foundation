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

@available(Future, *)
extension PredicateExpressions {
    public struct Range<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output: Comparable
    {
        public typealias Output = Swift.Range<LHS.Output>
        
        public let lower: LHS
        public let upper: RHS
        
        public init(lower: LHS, upper: RHS) {
            self.lower = lower
            self.upper = upper
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Swift.Range<LHS.Output> {
            let low = try lower.evaluate(bindings)
            let high = try upper.evaluate(bindings)
            return low..<high
        }
    }
    
    public static func build_Range<LHS, RHS>(lower: LHS, upper: RHS) -> Range<LHS, RHS> {
        Range(lower: lower, upper: upper)
    }
}

@available(Future, *)
extension PredicateExpressions.Range : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.Range : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.Range : Sendable where LHS : Sendable, RHS : Sendable {}
