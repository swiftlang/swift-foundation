//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

extension PredicateCodableConfiguration {
    fileprivate static var `default`: Self {
        // If we're encoding this predicate inside of another one, use the parent predicate's configuration since the "default" was specified here
        if var parent = _ThreadLocal[.predicateArchivingState]?.configuration {
            // When decoding sub-predicates, we don't want to overwrite inputs since they by definition must already be in the parent predicate's configuration
            parent.shouldAddInputTypes = false
            return parent
        } else {
            // Otherwise, the default is the standardConfiguration
            return .standardConfiguration
        }
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Predicate : Codable {
    public func encode(to encoder: Encoder) throws {
        try self.encode(to: encoder, configuration: .default)
    }
    
    public init(from decoder: Decoder) throws {
        try self.init(from: decoder, configuration: .default)
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Expression : Codable {
    public func encode(to encoder: Encoder) throws {
        try self.encode(to: encoder, configuration: .default)
    }
    
    public init(from decoder: Decoder) throws {
        try self.init(from: decoder, configuration: .default)
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Predicate : CodableWithConfiguration {
    public typealias EncodingConfiguration = PredicateCodableConfiguration
    public typealias DecodingConfiguration = PredicateCodableConfiguration
    
    public func encode(to encoder: Encoder, configuration: EncodingConfiguration) throws {
        var container = encoder.unkeyedContainer()
        try container.encodePredicateExpression(expression, variable: repeat each variable, predicateConfiguration: configuration)
    }
    
    public init(from decoder: Decoder, configuration: DecodingConfiguration) throws {
        var container = try decoder.unkeyedContainer()
        let result = try container.decodePredicateExpression(input: repeat (each Input).self, predicateConfiguration: configuration)
        guard let trueExpression = result.expression as? any StandardPredicateExpression<Bool> else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "This expression is unsupported by this predicate")
        }
        self.expression = trueExpression
        self.variable = result.variable
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
extension Expression : CodableWithConfiguration {
    public typealias EncodingConfiguration = PredicateCodableConfiguration
    public typealias DecodingConfiguration = PredicateCodableConfiguration
    
    public func encode(to encoder: Encoder, configuration: EncodingConfiguration) throws {
        var container = encoder.unkeyedContainer()
        try container.encodePredicateExpression(expression, variable: repeat each variable, predicateConfiguration: configuration)
    }
    
    public init(from decoder: Decoder, configuration: DecodingConfiguration) throws {
        var container = try decoder.unkeyedContainer()
        let result = try container.decodePredicateExpression(input: repeat (each Input).self, output: Output.self, predicateConfiguration: configuration)
        guard let trueExpression = result.expression as? any StandardPredicateExpression<Output> else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "This archived expression is not supported by this Expression type")
        }
        self.expression = trueExpression
        self.variable = result.variable
    }
}

#endif // FOUNDATION_FRAMEWORK
