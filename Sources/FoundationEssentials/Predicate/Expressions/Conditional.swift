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

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.Conditional : CustomStringConvertible {
    public var description: String {
        "Conditional(test: \(test), trueBranch: \(trueBranch), falseBranch: \(falseBranch))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Conditional : StandardPredicateExpression where Test : StandardPredicateExpression, If : StandardPredicateExpression, Else : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Conditional : Codable where Test : Codable, If : Codable, Else : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(test)
        try container.encode(trueBranch)
        try container.encode(falseBranch)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        test = try container.decode(Test.self)
        trueBranch = try container.decode(If.self)
        falseBranch = try container.decode(Else.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Conditional : Sendable where Test : Sendable, If : Sendable, Else : Sendable {}
