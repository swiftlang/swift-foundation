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
    public struct SequenceContains<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output : Sequence,
        LHS.Output.Element : Equatable,
        RHS.Output == LHS.Output.Element
    {
        public typealias Output = Bool
        
        public let sequence: LHS
        public let element: RHS
        
        public init(sequence: LHS, element: RHS) {
            self.sequence = sequence
            self.element = element
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Bool {
            let a = try sequence.evaluate(bindings)
            let b = try element.evaluate(bindings)
            return a.contains(b)
        }
    }
    
    public struct SequenceContainsWhere<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output : Sequence,
        RHS.Output == Bool
    {
        public typealias Element = LHS.Output.Element
        public typealias Output = Bool

        public let sequence: LHS
        public let test: RHS
        public let variable: Variable<Element>
        
        public init(_ sequence: LHS, builder: (Variable<Element>) -> RHS) {
            self.variable = Variable()
            self.sequence = sequence
            self.test = builder(variable)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            var mutableBindings = bindings
            return try sequence.evaluate(bindings).contains {
                mutableBindings[variable] = $0
                return try test.evaluate(mutableBindings)
            }
        }
    }
    
    public struct SequenceAllSatisfy<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output : Sequence,
        RHS.Output == Bool
    {
        public typealias Element = LHS.Output.Element
        public typealias Output = Bool

        public let sequence: LHS
        public let test: RHS
        public let variable: Variable<Element>
        
        public init(_ sequence: LHS, builder: (Variable<Element>) -> RHS) {
            self.variable = Variable()
            self.sequence = sequence
            self.test = builder(variable)
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            var mutableBindings = bindings
            return try sequence.evaluate(bindings).allSatisfy {
                mutableBindings[variable] = $0
                return try test.evaluate(mutableBindings)
            }
        }
    }
    
    public static func build_contains<LHS, RHS>(_ lhs: LHS, _ rhs: RHS) -> SequenceContains<LHS, RHS> {
        SequenceContains(sequence: lhs, element: rhs)
    }
    
    public static func build_contains<LHS, RHS>(_ lhs: LHS, where builder: (Variable<LHS.Output.Element>) -> RHS) -> SequenceContainsWhere<LHS, RHS> {
        SequenceContainsWhere(lhs, builder: builder)
    }
    
    public static func build_allSatisfy<LHS, RHS>(_ lhs: LHS, _ builder: (Variable<LHS.Output.Element>) -> RHS) -> SequenceAllSatisfy<LHS, RHS> {
        SequenceAllSatisfy(lhs, builder: builder)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContains : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContainsWhere : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceAllSatisfy : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContains : Codable where LHS : Codable, RHS : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContainsWhere : Codable where LHS : Codable, RHS : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceAllSatisfy : Codable where LHS : Codable, RHS : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContains : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceContainsWhere : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceAllSatisfy : Sendable where LHS : Sendable, RHS : Sendable {}
