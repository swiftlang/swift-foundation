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
    public struct IntDivision<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output : BinaryInteger
    {
        public typealias Output = LHS.Output
        
        public let lhs: LHS
        public let rhs: RHS
        
        public init(lhs: LHS, rhs: RHS) {
            self.lhs = lhs
            self.rhs = rhs
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let a = try lhs.evaluate(bindings)
            let b = try rhs.evaluate(bindings)
            return a / b
        }
    }

    public struct IntRemainder<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output : BinaryInteger
    {
        public typealias Output = LHS.Output
        
        public let lhs: LHS
        public let rhs: RHS
        
        public init(lhs: LHS, rhs: RHS) {
            self.lhs = lhs
            self.rhs = rhs
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let a = try lhs.evaluate(bindings)
            let b = try rhs.evaluate(bindings)
            return a % b
        }
    }

    public struct FloatDivision<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output : FloatingPoint
    {
        public typealias Output = LHS.Output
        
        public let lhs: LHS
        public let rhs: RHS
        
        public init(lhs: LHS, rhs: RHS) {
            self.lhs = lhs
            self.rhs = rhs
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let a = try lhs.evaluate(bindings)
            let b = try rhs.evaluate(bindings)
            return a / b
        }
    }
    
    public static func build_Division<LHS, RHS>(lhs: LHS, rhs: RHS) -> IntDivision<LHS, RHS> {
        IntDivision(lhs: lhs, rhs: rhs)
    }
    
    public static func build_Division<LHS, RHS>(lhs: LHS, rhs: RHS) -> FloatDivision<LHS, RHS> {
        FloatDivision(lhs: lhs, rhs: rhs)
    }
    
    public static func build_Remainder<LHS, RHS>(lhs: LHS, rhs: RHS) -> IntRemainder<LHS, RHS> {
        IntRemainder(lhs: lhs, rhs: rhs)
    }
}

@available(Future, *)
extension PredicateExpressions.FloatDivision : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.IntRemainder : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.IntDivision : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.FloatDivision : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.IntRemainder : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.IntDivision : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.FloatDivision : Sendable where LHS : Sendable, RHS : Sendable {}

@available(Future, *)
extension PredicateExpressions.IntRemainder : Sendable where LHS : Sendable, RHS : Sendable {}

@available(Future, *)
extension PredicateExpressions.IntDivision : Sendable where LHS : Sendable, RHS : Sendable {}
