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
public struct Predicate<each Input> : Sendable {
    public let expression : any StandardPredicateExpression<Bool>
    public let variable: (repeat PredicateExpressions.Variable<each Input>)
    
    public init(_ builder: (repeat PredicateExpressions.Variable<each Input>) -> any StandardPredicateExpression<Bool>) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = builder(repeat each variable)
    }
    
    public func evaluate(_ input: repeat each Input) throws -> Bool {
        try expression.evaluate(
            .init(repeat (each variable, each input))
        )
    }
}

#if hasFeature(Macros)
@freestanding(expression)
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public macro Predicate<each Input>(_ body: (repeat each Input) -> Bool) -> Predicate<repeat each Input> = #externalMacro(module: "FoundationMacros", type: "PredicateMacro")
#endif

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Predicate {
    private init(value: Bool) {
        self.variable = (repeat PredicateExpressions.Variable<each Input>())
        self.expression = PredicateExpressions.Value(value)
    }
    
    public static var `true`: Self {
        Self(value: true)
    }
    
    public static var `false`: Self {
        Self(value: false)
    }
}

@available(FoundationPreview 6.4, *)
extension Predicate {
    public init(all subpredicates: some BidirectionalCollection<Self>) {
        var iterator = subpredicates.reversed().makeIterator()
        
        if let guarded = iterator.next() {
            self.init({ (input: repeat PredicateExpressions.Variable<each Input>) in
                let condition: PredicateExpressions.Value<Self> = PredicateExpressions.build_Arg(guarded)
                var pieces: any StandardPredicateExpression<Bool> = PredicateExpressions.build_evaluate(condition, repeat each input)
                
                while let next = iterator.next() {
                    pieces = Self.meet(PredicateExpressions.build_evaluate(PredicateExpressions.build_Arg(next), repeat each input), pieces)
                }
                
                return pieces
            })
        } else {
            self.init(value: true)
        }
    }
    
    public init(any subpredicates: some BidirectionalCollection<Self>) {
        var iterator = subpredicates.reversed().makeIterator()
        
        if let guarded = iterator.next() {
            self.init({ (input: repeat PredicateExpressions.Variable<each Input>) in
                let condition: PredicateExpressions.Value<Self> = PredicateExpressions.build_Arg(guarded)
                var pieces: any StandardPredicateExpression<Bool> = PredicateExpressions.build_evaluate(condition, repeat each input)
                
                while let next = iterator.next() {
                    pieces = Self.join(PredicateExpressions.build_evaluate(PredicateExpressions.build_Arg(next), repeat each input), pieces)
                }
                
                return pieces
            })
        } else {
            self.init(value: false)
        }
    }
    
    fileprivate static func meet<T: StandardPredicateExpression<Bool>, U: StandardPredicateExpression<Bool>>(_ lhs: T, _ rhs: U) -> any StandardPredicateExpression<Bool> {
        PredicateExpressions.build_Conjunction(lhs: lhs, rhs: rhs)
    }
    
    fileprivate static func join<T: StandardPredicateExpression<Bool>, U: StandardPredicateExpression<Bool>>(_ lhs: T, _ rhs: U) -> any StandardPredicateExpression<Bool> {
        PredicateExpressions.build_Disjunction(lhs: lhs, rhs: rhs)
    }
}

// Namespace for operator expressions
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@frozen public enum PredicateExpressions {}

@available(macOS, unavailable, introduced: 14.0)
@available(iOS, unavailable, introduced: 17.0)
@available(tvOS, unavailable, introduced: 17.0)
@available(watchOS, unavailable, introduced: 10.0)
@available(*, unavailable)
extension PredicateExpressions : Sendable {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Sequence {
    public func filter(_ predicate: Predicate<Element>) throws -> [Element] {
        try self.filter {
            try predicate.evaluate($0)
        }
    }
}
