//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions {
    public struct SequenceMaximum<
        Elements : PredicateExpression
    > : PredicateExpression where
        Elements.Output : Sequence,
        Elements.Output.Element : Comparable
    {
        public typealias Output = Optional<Elements.Output.Element>
        
        public let elements: Elements
        
        public init(elements: Elements) {
            self.elements = elements
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try elements.evaluate(bindings).max()
        }
    }
    
    public static func build_max<Elements>(_ elements: Elements) -> SequenceMaximum<Elements> {
        SequenceMaximum(elements: elements)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMaximum : StandardPredicateExpression where Elements : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMaximum : Codable where Elements : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMaximum : Sendable where Elements : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions {
    public struct SequenceMinimum<
        Elements : PredicateExpression
    > : PredicateExpression where
        Elements.Output : Sequence,
        Elements.Output.Element : Comparable
    {
        public typealias Output = Optional<Elements.Output.Element>
        
        public let elements: Elements
        
        public init(elements: Elements) {
            self.elements = elements
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            try elements.evaluate(bindings).min()
        }
    }
    
    public static func build_min<Elements>(_ elements: Elements) -> SequenceMinimum<Elements> {
        SequenceMinimum(elements: elements)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMinimum : StandardPredicateExpression where Elements : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMinimum : Codable where Elements : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.SequenceMinimum : Sendable where Elements : Sendable {}
