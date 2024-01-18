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

#if FOUNDATION_FRAMEWORK

@available(FoundationPredicate 0.1, *)
extension KeyedEncodingContainer {
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, each Input>(_ expression: T, forKey key: Self.Key, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        var container = self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self, forKey: key)
        try container._encode(expression, variable: repeat each variable, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, each Input>(_ expression: T?, forKey key: Self.Key, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        guard let expression else { return }
        try self.encodePredicateExpression(expression, forKey: key, variable: repeat each variable, predicateConfiguration: predicateConfiguration)
    }
}

@available(FoundationPredicate 0.1, *)
extension KeyedDecodingContainer {
    public mutating func decodePredicateExpression<each Input>(forKey key: Self.Key, input: repeat (each Input).Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variable: (repeat PredicateExpressions.Variable<each Input>)) {
        var container = try self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self, forKey: key)
        return try container._decode(input: repeat each input, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func decodePredicateExpressionIfPresent<each Input>(forKey key: Self.Key, input: repeat (each Input).Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variable: (repeat PredicateExpressions.Variable<each Input>))? {
        guard self.contains(key) else { return nil }
        return try self.decodePredicateExpression(forKey: key, input: repeat each input, predicateConfiguration: predicateConfiguration)
    }
}

@available(FoundationPredicate 0.1, *)
extension UnkeyedEncodingContainer {
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, each Input>(_ expression: T, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        var container = self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self)
        try container._encode(expression, variable: repeat each variable, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, each Input>(_ expression: T?, variable: repeat PredicateExpressions.Variable<each Input>, predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        guard let expression else {
            try self.encodeNil()
            return
        }
        try self.encodePredicateExpression(expression, variable: repeat each variable, predicateConfiguration: predicateConfiguration)
    }
}

@available(FoundationPredicate 0.1, *)
extension UnkeyedDecodingContainer {
    public mutating func decodePredicateExpression<each Input>(input: repeat (each Input).Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variable: (repeat PredicateExpressions.Variable<each Input>)) {
        var container = try self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self)
        return try container._decode(input: repeat each input, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func decodePredicateExpressionIfPresent<each Input>(input: repeat (each Input).Type, predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variable: (repeat PredicateExpressions.Variable<each Input>))? {
        if try self.decodeNil() {
            return nil
        } else {
            return try self.decodePredicateExpression(input: repeat each input, predicateConfiguration: predicateConfiguration)
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
