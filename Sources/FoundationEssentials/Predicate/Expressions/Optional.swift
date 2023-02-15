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
    public struct OptionalFlatMap<
        LHS : PredicateExpression,
        Wrapped,
        RHS : PredicateExpression,
        Result
    > : PredicateExpression
    where
    LHS.Output == Optional<Wrapped>
    {
        public typealias Output = Optional<Result>

        public let wrapped: LHS
        public let transform: RHS
        public let variable: Variable<Wrapped>

        public init(_ wrapped: LHS, _ builder: (Variable<Wrapped>) -> RHS) where RHS.Output == Result {
            self.wrapped = wrapped
            self.variable = Variable()
            self.transform = builder(variable)
        }
        
        public init(_ wrapped: LHS, _ builder: (Variable<Wrapped>) -> RHS) where RHS.Output == Optional<Result> {
            self.wrapped = wrapped
            self.variable = Variable()
            self.transform = builder(variable)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            var mutableBindings = bindings
            return try wrapped.evaluate(bindings).flatMap { inner in
                mutableBindings[variable] = inner
                return try transform.evaluate(mutableBindings) as! Result?
            }
        }
    }

    public static func build_flatMap<LHS, RHS, Wrapped, Result>(_ wrapped: LHS, _ builder: (Variable<Wrapped>) -> RHS) -> OptionalFlatMap<LHS, Wrapped, RHS, Result> where RHS.Output == Result {
        OptionalFlatMap(wrapped, builder)
    }

    public static func build_flatMap<LHS, RHS, Wrapped, Result>(_ wrapped: LHS, _ builder: (Variable<Wrapped>) -> RHS) -> OptionalFlatMap<LHS, Wrapped, RHS, Result> where RHS.Output == Optional<Result> {
        OptionalFlatMap(wrapped, builder)
    }
    
    public struct NilCoalesce<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
    LHS.Output == Optional<RHS.Output>
    {
        public typealias Output = RHS.Output
        
        public let lhs: LHS
        public let rhs: RHS
        
        public init(lhs: LHS, rhs: RHS) {
            self.lhs = lhs
            self.rhs = rhs
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try lhs.evaluate(bindings) ?? rhs.evaluate(bindings)
        }
    }
    
    public static func build_NilCoalesce<LHS, RHS>(lhs: LHS, rhs: RHS) -> NilCoalesce<LHS, RHS> {
        NilCoalesce(lhs: lhs, rhs: rhs)
    }
    
    public struct ForcedUnwrap<
        LHS : PredicateExpression,
        Wrapped
    > : PredicateExpression
    where
    LHS.Output == Optional<Wrapped>
    {
        public typealias Output = Wrapped
        
        public let lhs: LHS
        
        public init(lhs: LHS) {
            self.lhs = lhs
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Wrapped {
            let input = try lhs.evaluate(bindings)
            if let result = input {
                return result
            }
            throw PredicateError(.forceUnwrapFailure("Found nil when unwrapping value of type '\(type(of: input))'"))
        }
    }
    
    public static func build_ForcedUnwrap<LHS, Wrapped>(lhs: LHS) -> ForcedUnwrap<LHS, Wrapped> where LHS.Output == Optional<Wrapped> {
        ForcedUnwrap(lhs: lhs)
    }
}

@available(Future, *)
extension PredicateExpressions.OptionalFlatMap : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.NilCoalesce : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.ForcedUnwrap : StandardPredicateExpression where LHS : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.OptionalFlatMap : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.NilCoalesce : Codable where LHS : Codable, RHS : Codable {}

@available(Future, *)
extension PredicateExpressions.ForcedUnwrap : Codable where LHS : Codable {}

@available(Future, *)
extension PredicateExpressions.OptionalFlatMap : Sendable where LHS : Sendable, RHS : Sendable {}

@available(Future, *)
extension PredicateExpressions.NilCoalesce : Sendable where LHS : Sendable, RHS : Sendable {}

@available(Future, *)
extension PredicateExpressions.ForcedUnwrap : Sendable where LHS : Sendable {}
