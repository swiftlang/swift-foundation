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

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension KeyedEncodingContainer {
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, Input>(_ expression: T, forKey key: Self.Key, variables: (PredicateExpressions.Variable<Input>), predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        var container = self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self, forKey: key)
        try container._encode(expression, variables: variables, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, Input>(_ expression: T?, forKey key: Self.Key, variables: (PredicateExpressions.Variable<Input>), predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        guard let expression else { return }
        try self.encodePredicateExpression(expression, forKey: key, variables: variables, predicateConfiguration: predicateConfiguration)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension KeyedDecodingContainer {
    public mutating func decodePredicateExpression<Input>(forKey key: Self.Key, inputs: (Input.Type), predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variables: (PredicateExpressions.Variable<Input>)) {
        var container = try self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self, forKey: key)
        return try container._decode(inputs: inputs, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func decodePredicateExpressionIfPresent<Input>(forKey key: Self.Key, inputs: (Input.Type), predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variables: (PredicateExpressions.Variable<Input>))? {
        guard self.contains(key) else { return nil }
        return try self.decodePredicateExpression(forKey: key, inputs: inputs, predicateConfiguration: predicateConfiguration)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension UnkeyedEncodingContainer {
    public mutating func encodePredicateExpression<T: PredicateExpression & Encodable, Input>(_ expression: T, variables: (PredicateExpressions.Variable<Input>), predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        var container = self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self)
        try container._encode(expression, variables: variables, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func encodePredicateExpressionIfPresent<T: PredicateExpression & Encodable, Input>(_ expression: T?, variables: (PredicateExpressions.Variable<Input>), predicateConfiguration: PredicateCodableConfiguration) throws where T.Output == Bool {
        guard let expression else {
            try self.encodeNil()
            return
        }
        try self.encodePredicateExpression(expression, variables: variables, predicateConfiguration: predicateConfiguration)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension UnkeyedDecodingContainer {
    public mutating func decodePredicateExpression<Input>(inputs: (Input.Type), predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variables: (PredicateExpressions.Variable<Input>)) {
        var container = try self.nestedContainer(keyedBy: PredicateExpressionCodingKeys.self)
        return try container._decode(inputs: inputs, predicateConfiguration: predicateConfiguration)
    }
    
    public mutating func decodePredicateExpressionIfPresent<Input>(inputs: (Input.Type), predicateConfiguration: PredicateCodableConfiguration) throws -> (expression: any PredicateExpression<Bool>, variables: (PredicateExpressions.Variable<Input>))? {
        if try self.decodeNil() {
            return nil
        } else {
            return try self.decodePredicateExpression(inputs: inputs, predicateConfiguration: predicateConfiguration)
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
