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
public struct Predicate<Input> : Sendable {
    public let expression : any StandardPredicateExpression<Bool>
    public let variable: (PredicateExpressions.Variable<Input>)
    
    public init<E: StandardPredicateExpression<Bool>>(_ builder: (PredicateExpressions.Variable<Input>) -> E) {
        self.variable = PredicateExpressions.Variable<Input>()
        self.expression = builder(self.variable)
    }
    
    public func evaluate(_ input: Input) throws -> Bool {
        try expression.evaluate(.init((variable, input)))
    }
}

// Namespace for operator expressions
@available(Future, *)
@frozen @_nonSendable public enum PredicateExpressions {}

@available(Future, *)
extension Sequence {
    public func filter(_ predicate: Predicate<Element>) throws -> [Element] {
        try self.filter {
            try predicate.evaluate($0)
        }
    }
}
