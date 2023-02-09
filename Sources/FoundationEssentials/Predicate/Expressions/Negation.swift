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
    public struct Negation<Wrapped: PredicateExpression> : PredicateExpression where Wrapped.Output == Bool {
        public typealias Output = Bool
        
        public let wrapped: Wrapped
        
        public init(_ wrapped: Wrapped) {
            self.wrapped = wrapped
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Bool {
            try !wrapped.evaluate(bindings)
        }
    }
    
    public static func build_Negation<T>(_ wrapped: T) -> Negation<T> {
        Negation(wrapped)
    }
}

@available(Future, *)
extension PredicateExpressions.Negation : StandardPredicateExpression where Wrapped : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.Negation : Codable where Wrapped : Codable {}

@available(Future, *)
extension PredicateExpressions.Negation : Sendable where Wrapped : Sendable {}
