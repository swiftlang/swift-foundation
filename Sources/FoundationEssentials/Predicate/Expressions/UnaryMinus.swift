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
    public struct UnaryMinus<Wrapped: PredicateExpression> : PredicateExpression where Wrapped.Output: SignedNumeric {
        public typealias Output = Wrapped.Output
        
        public let wrapped: Wrapped
        
        public init(_ wrapped: Wrapped) {
            self.wrapped = wrapped
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try -wrapped.evaluate(bindings)
        }
    }
    
    public static func build_UnaryMinus<T>(_ inner: T) -> UnaryMinus<T> {
        UnaryMinus(inner)
    }
}

@available(Future, *)
extension PredicateExpressions.UnaryMinus : StandardPredicateExpression where Wrapped : StandardPredicateExpression {}

@available(Future, *)
extension PredicateExpressions.UnaryMinus : Codable where Wrapped : Codable {}

@available(Future, *)
extension PredicateExpressions.UnaryMinus : Sendable where Wrapped : Sendable {}
