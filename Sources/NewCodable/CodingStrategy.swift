//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A strategy for decoding a value from a format-agnostic `CommonDecoder`.
///
/// When a property is annotated with `@DecodableBy` or `@CodableBy`, the
/// macro-generated decoding code delegates to the strategy's `decode(from:)`
/// method instead of using the type's default `CommonDecodable` conformance.
///
/// Conforming types receive the decoder directly and can call any of its
/// methods — decode primitives, structs, arrays, visit raw bytes, etc.
///
///     @CodableBy(.losslessStringConversion)
///     let port: UInt16  // decoded from "8080" instead of 8080
public protocol CommonDecodingStrategy {
    associatedtype Value: ~Copyable
    func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Value
}

/// A strategy for encoding a value into a format-agnostic `CommonEncoder`.
///
/// When a property is annotated with `@EncodableBy` or `@CodableBy`, the
/// macro-generated encoding code delegates to the strategy's `encode(_:to:)`
/// method instead of using the type's default `CommonEncodable` conformance.
///
/// Conforming types receive the encoder directly and can call any of its
/// methods — encode primitives, strings, bytes, structs, etc.
public protocol CommonEncodingStrategy {
    associatedtype Value: ~Copyable
    func encode(_ value: borrowing Value, to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding)
}

/// A strategy that can both encode and decode a value.
///
/// Most strategies used with `@CodableBy` conform to this protocol since they
/// handle both directions. It is a convenience composition of
/// ``CommonEncodingStrategy`` and ``CommonDecodingStrategy``.
public protocol CommonCodingStrategy: CommonEncodingStrategy & CommonDecodingStrategy {}

// MARK: - JSON-specific strategy specializations

/// A JSON-specialized decoding strategy.
///
/// Conformers receive a `JSONDecoderProtocol` decoder, which provides access
/// to JSON-specific primitives.
///
/// Types that also conform to ``CommonDecodingStrategy`` can use their
/// `CommonDecoder` implementation to satisfy this requirement, since
/// `JSONDecoderProtocol` refines `CommonDecoder`. Provide a separate
/// implementation here only when you need JSON-specific behavior.
public protocol JSONDecodingStrategy {
    associatedtype Value: ~Copyable
    func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> Value
}

/// A JSON-specialized encoding strategy.
///
/// Conformers receive a concrete `JSONDirectEncoder` and can use JSON-native
/// encoding primitives.
///
/// Types that also conform to ``CommonEncodingStrategy`` can use their
/// `CommonEncoder` implementation to satisfy this requirement, since
/// `JSONDirectEncoder` conforms to `CommonEncoder`. Provide a separate
/// implementation here only when you need JSON-specific behavior.
public protocol JSONEncodingStrategy {
    associatedtype Value: ~Copyable
    func encode(_ value: borrowing Value, to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding)
}

/// A JSON-specialized strategy that can both encode and decode.
public protocol JSONCodingStrategy: JSONEncodingStrategy & JSONDecodingStrategy {}

// MARK: - Extension methods for macro-generated code

extension CommonDecoder where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decode<S: CommonDecodingStrategy>(using strategy: S) throws(CodingError.Decoding) -> S.Value {
        try strategy.decode(from: &self)
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decode<S: CommonDecodingStrategy>(_: S.Value.Type, using strategy: S) throws(CodingError.Decoding) -> S.Value {
        try strategy.decode(from: &self)
    }
}

extension CommonEncoder where Self: ~Copyable & ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public mutating func encode<S: CommonEncodingStrategy>(_ value: borrowing S.Value, using strategy: S) throws(CodingError.Encoding) {
        try strategy.encode(value, to: &self)
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    public mutating func encode<S: CommonEncodingStrategy>(_ value: borrowing S.Value, as: S.Value.Type, using strategy: S) throws(CodingError.Encoding) {
        try strategy.encode(value, to: &self)
    }
}

// MARK: JSON-specialized overloads
//
// When the strategy conforms to JSONDecodingStrategy/JSONEncodingStrategy,
// these more-specific overloads win, dispatching to the JSON-native method.
// When it doesn't, the CommonDecoder/CommonEncoder overloads above match
// (since JSONDecoderProtocol refines CommonDecoder).

extension JSONDecoderProtocol where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decode<S: JSONDecodingStrategy>(using strategy: S) throws(CodingError.Decoding) -> S.Value {
        try strategy.decode(from: &self)
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decode<S: JSONDecodingStrategy>(_: S.Value.Type, using strategy: S) throws(CodingError.Decoding) -> S.Value {
        try strategy.decode(from: &self)
    }
}

extension JSONDirectEncoder {
    @_alwaysEmitIntoClient
    @inline(__always)
    public mutating func encode<S: JSONEncodingStrategy>(_ value: borrowing S.Value, using strategy: S) throws(CodingError.Encoding) {
        try strategy.encode(value, to: &self)
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    public mutating func encode<S: JSONEncodingStrategy>(_ value: borrowing S.Value, as: S.Value.Type, using strategy: S) throws(CodingError.Encoding) {
        try strategy.encode(value, to: &self)
    }
}

