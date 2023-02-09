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
    public struct Conditional<
        Test : PredicateExpression,
        If : PredicateExpression,
        Else : PredicateExpression
    > : PredicateExpression
    where
    Test.Output == Bool,
    If.Output == Else.Output
    {
        public typealias Output = If.Output
        
        public let test : Test
        public let trueBranch : If
        public let falseBranch : Else
        
        public init(test: Test, trueBranch: If, falseBranch: Else) {
            self.test = test
            self.trueBranch = trueBranch
            self.falseBranch = falseBranch
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> If.Output {
            let result = try test.evaluate(bindings)
            if result {
                return try trueBranch.evaluate(bindings)
            } else {
                return try falseBranch.evaluate(bindings)
            }
        }
    }
    
    public static func build_Conditional<Test, If, Else>(_ test: Test, _ trueBranch: If, _ falseBranch: Else) -> Conditional<Test, If, Else> {
        Conditional(test: test, trueBranch: trueBranch, falseBranch: falseBranch)
    }
}

@available(Future, *)
extension PredicateExpressions.Conditional : StandardPredicateExpression where Test : StandardPredicateExpression, If : StandardPredicateExpression, Else : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.Conditional : Codable where Test : Codable, If : Codable, Else : Codable {}

@available(Future, *)
extension PredicateExpressions.Conditional : Sendable where Test : Sendable, If : Sendable, Else : Sendable {}
