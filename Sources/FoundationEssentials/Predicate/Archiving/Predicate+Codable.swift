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
extension Predicate : Codable {
    public func encode(to encoder: Encoder) throws {
        try self.encode(to: encoder, configuration: .standardConfiguration)
    }
    
    public init(from decoder: Decoder) throws {
        try self.init(from: decoder, configuration: .standardConfiguration)
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
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

#endif // FOUNDATION_FRAMEWORK
