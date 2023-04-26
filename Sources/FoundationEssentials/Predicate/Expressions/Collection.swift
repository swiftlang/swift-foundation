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
    public struct CollectionIndexSubscript<
        Wrapped : PredicateExpression,
        Index : PredicateExpression
    > : PredicateExpression
    where
        Wrapped.Output : Collection,
        Index.Output == Wrapped.Output.Index
    {
        public typealias Output = Wrapped.Output.Element
        
        public let wrapped: Wrapped
        public let index: Index
        
        public init(wrapped: Wrapped, index: Index) {
            self.wrapped = wrapped
            self.index = index
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let collection = try wrapped.evaluate(bindings)
            let indexValue = try index.evaluate(bindings)
            guard indexValue >= collection.startIndex && indexValue < collection.endIndex else {
                throw PredicateError(.invalidInput("Index \(indexValue) was not within the valid bounds of the collection (\(collection.startIndex) ..< \(collection.endIndex))"))
            }
            return collection[indexValue]
        }
    }
    
    public static func build_subscript<Wrapped, Index>(_ wrapped: Wrapped, _ index: Index) -> CollectionIndexSubscript<Wrapped, Index> {
        CollectionIndexSubscript(wrapped: wrapped, index: index)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionIndexSubscript : Sendable where Wrapped : Sendable, Index : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionIndexSubscript : Codable where Wrapped : Codable, Index : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(wrapped)
        try container.encode(index)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.wrapped = try container.decode(Wrapped.self)
        self.index = try container.decode(Index.self)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionIndexSubscript : StandardPredicateExpression where Wrapped : StandardPredicateExpression, Index : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions {
    public struct CollectionRangeSubscript<
        Wrapped : PredicateExpression,
        Range : PredicateExpression
    > : PredicateExpression
    where
        Wrapped.Output : Collection,
        Range.Output == Swift.Range<Wrapped.Output.Index>
    {
        public typealias Output = Wrapped.Output.SubSequence
        
        public let wrapped: Wrapped
        public let range: Range
        
        public init(wrapped: Wrapped, range: Range) {
            self.wrapped = wrapped
            self.range = range
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            let collection = try wrapped.evaluate(bindings)
            let rangeValue = try range.evaluate(bindings)
            
            guard rangeValue.lowerBound >= collection.startIndex && rangeValue.lowerBound <= collection.endIndex else {
                throw PredicateError(.invalidInput("Index \(rangeValue.lowerBound) was not within the valid bounds of the collection (\(collection.startIndex) ... \(collection.endIndex))"))
            }
            guard rangeValue.upperBound >= collection.startIndex && rangeValue.upperBound <= collection.endIndex else {
                throw PredicateError(.invalidInput("Index \(rangeValue.upperBound) was not within the valid bounds of the collection (\(collection.startIndex) ... \(collection.endIndex))"))
            }
            
            return collection[rangeValue]
        }
    }
    
    public static func build_subscript<Wrapped, Range>(_ wrapped: Wrapped, _ range: Range) -> CollectionRangeSubscript<Wrapped, Range> {
        CollectionRangeSubscript(wrapped: wrapped, range: range)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionRangeSubscript : Sendable where Wrapped : Sendable, Range : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionRangeSubscript : Codable where Wrapped : Codable, Range : Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(wrapped)
        try container.encode(range)
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.wrapped = try container.decode(Wrapped.self)
        self.range = try container.decode(Range.self)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.CollectionRangeSubscript : StandardPredicateExpression where Wrapped : StandardPredicateExpression, Range : StandardPredicateExpression {}
