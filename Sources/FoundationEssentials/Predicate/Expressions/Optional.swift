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
        Inner : PredicateExpression,
        Wrapped
    > : PredicateExpression
    where
        Inner.Output == Optional<Wrapped>
    {
        public typealias Output = Wrapped
        
        public let inner: Inner
        
        public init(_ inner: Inner) {
            self.inner = inner
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Wrapped {
            let input = try inner.evaluate(bindings)
            if let result = input {
                return result
            }
            throw PredicateError(.forceUnwrapFailure("Found nil when unwrapping value of type '\(type(of: input))'"))
        }
    }
    
    public static func build_ForcedUnwrap<Inner, Wrapped>(_ inner: Inner) -> ForcedUnwrap<Inner, Wrapped> where Inner.Output == Optional<Wrapped> {
        ForcedUnwrap(inner)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.OptionalFlatMap : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.NilCoalesce : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.ForcedUnwrap : StandardPredicateExpression where Inner : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.OptionalFlatMap : Codable where LHS : Codable, RHS : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(wrapped)
        try container.encode(transform)
        try container.encode(variable)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        wrapped = try container.decode(LHS.self)
        transform = try container.decode(RHS.self)
        variable = try container.decode(PredicateExpressions.Variable<Wrapped>.self)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.NilCoalesce : Codable where LHS : Codable, RHS : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lhs)
        try container.encode(rhs)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lhs = try container.decode(LHS.self)
        rhs = try container.decode(RHS.self)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.ForcedUnwrap : Codable where Inner : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(inner)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        inner = try container.decode(Inner.self)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.OptionalFlatMap : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.NilCoalesce : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.ForcedUnwrap : Sendable where Inner : Sendable {}
