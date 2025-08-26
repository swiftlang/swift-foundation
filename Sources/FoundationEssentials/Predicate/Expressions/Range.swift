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
    public struct Range<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output: Comparable
    {
        public typealias Output = Swift.Range<LHS.Output>
        
        public let lower: LHS
        public let upper: RHS
        
        public init(lower: LHS, upper: RHS) {
            self.lower = lower
            self.upper = upper
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Swift.Range<LHS.Output> {
            let low = try lower.evaluate(bindings)
            let high = try upper.evaluate(bindings)
            guard low <= high else {
                throw PredicateError(.invalidInput("Range requires that lowerBound (\(low)) <= upperBound (\(high))"))
            }
            return low ..< high
        }
    }
    
    public static func build_Range<LHS, RHS>(lower: LHS, upper: RHS) -> Range<LHS, RHS> {
        Range(lower: lower, upper: upper)
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.Range : CustomStringConvertible {
    public var description: String {
        "Range(lower: \(lower), upper: \(upper))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Range : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Range : Codable where LHS : Codable, RHS : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lower)
        try container.encode(upper)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lower = try container.decode(LHS.self)
        upper = try container.decode(RHS.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.Range : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    public struct ClosedRange<
        LHS : PredicateExpression,
        RHS : PredicateExpression
    > : PredicateExpression
    where
        LHS.Output == RHS.Output,
        LHS.Output: Comparable
    {
        public typealias Output = Swift.ClosedRange<LHS.Output>
        
        public let lower: LHS
        public let upper: RHS
        
        public init(lower: LHS, upper: RHS) {
            self.lower = lower
            self.upper = upper
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Swift.ClosedRange<LHS.Output> {
            let low = try lower.evaluate(bindings)
            let high = try upper.evaluate(bindings)
            return low...high
        }
    }
    
    public static func build_ClosedRange<LHS, RHS>(lower: LHS, upper: RHS) -> ClosedRange<LHS, RHS> {
        ClosedRange(lower: lower, upper: upper)
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.ClosedRange : CustomStringConvertible {
    public var description: String {
        "ClosedRange(lower: \(lower), upper: \(upper))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.ClosedRange : StandardPredicateExpression where LHS : StandardPredicateExpression, RHS : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.ClosedRange : Codable where LHS : Codable, RHS : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lower)
        try container.encode(upper)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        lower = try container.decode(LHS.self)
        upper = try container.decode(RHS.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.ClosedRange : Sendable where LHS : Sendable, RHS : Sendable {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions {
    public struct RangeExpressionContains<
        RangeExpression : PredicateExpression,
        Element : PredicateExpression
    > : PredicateExpression where
        RangeExpression.Output : Swift.RangeExpression,
        Element.Output == RangeExpression.Output.Bound
    {
        public typealias Output = Bool
        
        public let range: RangeExpression
        public let element: Element
        
        public init(range: RangeExpression, element: Element) {
            self.range = range
            self.element = element
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try range.evaluate(bindings).contains(try element.evaluate(bindings))
        }
    }
    
    public static func build_contains<RangeExpression, Element>(_ range: RangeExpression, _ element: Element) -> RangeExpressionContains<RangeExpression, Element> {
        RangeExpressionContains(range: range, element: element)
    }
}

@available(macOS 14.4, iOS 17.4, tvOS 17.4, watchOS 10.4, *)
extension PredicateExpressions.RangeExpressionContains : CustomStringConvertible {
    public var description: String {
        "RangeExpressionContains(range: \(range), element: \(element))"
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.RangeExpressionContains : StandardPredicateExpression where RangeExpression : StandardPredicateExpression, Element : StandardPredicateExpression {}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.RangeExpressionContains : Codable where RangeExpression : Codable, Element : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(range)
        try container.encode(element)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        range = try container.decode(RangeExpression.self)
        element = try container.decode(Element.self)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension PredicateExpressions.RangeExpressionContains : Sendable where RangeExpression : Sendable, Element : Sendable {}
