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


/// A type that can decode itself from an external representation based on "common" data types.
public protocol CommonDecodable: ~Copyable {
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// This initializer throws an error if reading from the decoder fails, or
    /// if the data read is corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self
}

public protocol CommonDecodableWithContext: ~Copyable {
    associatedtype CommonDecodingContext: ~Copyable & ~Escapable
    @_lifetime(decoder: copy decoder)
    static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D, context: inout CommonDecodingContext) throws(CodingError.Decoding) -> Self
}

// Convenience for Copyable contexts - allows static member syntax
extension CommonDecodableWithContext where Self: ~Copyable, CommonDecodingContext: Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(decoder: copy decoder)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D, context: CommonDecodingContext) throws(CodingError.Decoding) -> Self {
        var mutableContext = context
        return try Self.decode(from: &decoder, context: &mutableContext)
    }
}

public protocol CommonFieldDecoder: ~Escapable {
    @inlinable
    func decode<T: DecodingField>(_: T.Type) throws(CodingError.Decoding) -> T
    
    @inlinable
    func matches(_ field: some DecodingField) -> Bool
    
    @inlinable
    func matches(_ key: StaticString) -> Bool
}

public protocol CommonDecodingVisitor: DecodingBoolVisitor, DecodingNumberVisitor, DecodingStringVisitor, DecodingBytesVisitor, ~Copyable, ~Escapable {
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some CommonArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue

    func visitNone() throws(CodingError.Decoding) -> DecodedValue
}

// TODO: Traditional Decodable support

/// A type that can decode values based on "common" data types from a native format
///  into in-memory representations.
public protocol CommonDecoder: ~Escapable {
    associatedtype StructDecoder: CommonStructDecoder & ~Escapable
    associatedtype DictionaryDecoder: CommonDictionaryDecoder & ~Escapable
    associatedtype ArrayDecoder: CommonArrayDecoder & ~Escapable
    associatedtype FieldDecoder: CommonFieldDecoder & ~Escapable
    
    // TODO: This overload is a workaround for the inability for decoder to dynamically cast particular Copyable types to T: CommonDecodable & ~Copyable. It has a default implementation that calls into the normal ~Copyable path.
    @_lifetime(self: copy self)
    mutating func decode<T: CommonDecodable>(_: T.Type) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decodeStruct<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decodeDictionary<T: ~Copyable>( _ closure: (inout DictionaryDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
        
    @_lifetime(self: copy self)
    mutating func decodeArray<T: ~Copyable>(_ closure: (inout ArrayDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
    
    // MARK: - Enum Decoding
    
    /// Decodes an enum case with no associated values
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (inout FieldDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T
    
    /// Decodes an enum case with associated values
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (_ caseName: inout FieldDecoder, _ associatedValues: inout StructDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decode<Key: CodingStringKeyRepresentable, Value: CommonDecodable>(_: [Key:Value].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Key:Value]
    
    @_lifetime(self: copy self)
    mutating func decode<Element: CommonDecodable>(_: [Element].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Element]
        
    @_lifetime(self: copy self)
    mutating func decode(_: Bool.Type) throws(CodingError.Decoding) -> Bool
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int.Type) throws(CodingError.Decoding) -> Int
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int8.Type) throws(CodingError.Decoding) -> Int8
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int16.Type) throws(CodingError.Decoding) -> Int16
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int32.Type) throws(CodingError.Decoding) -> Int32
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int64.Type) throws(CodingError.Decoding) -> Int64
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int128.Type) throws(CodingError.Decoding) -> Int128
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt.Type) throws(CodingError.Decoding) -> UInt
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt8.Type) throws(CodingError.Decoding) -> UInt8
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt16.Type) throws(CodingError.Decoding) -> UInt16
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt32.Type) throws(CodingError.Decoding) -> UInt32
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt64.Type) throws(CodingError.Decoding) -> UInt64
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt128.Type) throws(CodingError.Decoding) -> UInt128
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Float.Type) throws(CodingError.Decoding) -> Float
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Double.Type) throws(CodingError.Decoding) -> Double
    
    @_lifetime(self: copy self)
    mutating func decode(_: String.Type) throws(CodingError.Decoding) -> String
    
    @_lifetime(self: copy self)
    mutating func decodeString<V: DecodingStringVisitor & ~Copyable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue
    
    @_lifetime(self: copy self)
    mutating func decodeNil() throws(CodingError.Decoding) -> Bool
    
    @_lifetime(self: copy self)
    mutating func decodeOptional(_ closure: (inout Self) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    // TODO: Require this, or just have `decodeAny` throw?
    var supportsDecodeAny: Bool { get }
    
    @_lifetime(self: copy self)
    mutating func decodeAny<V: CommonDecodingVisitor>(_ visitor: V) throws(CodingError.Decoding) -> V.DecodedValue
    
    /// Decode a value using a visitor, with a hint that a collection of bytes is expected in the encoded data.
    ///
    /// - parameter visitor: An instance of the type that will create the `DecodedValue`
    ///   from the bytes the decoder makes it visit.
    /// - returns: The value created by the `visitor`.
    /// - throws: TBD. An error thrown by the `visitor`. Others?
    @_lifetime(self: copy self)
    mutating func decodeBytes<V: DecodingBytesVisitor>(visitor: V) throws(CodingError.Decoding) -> V.DecodedValue
    
    /// Decodes a value conforming to the standard `Decodable` protocol using `decodeAny` and an `AdaptorDecoder`.
    ///
    /// This method provides a bridge between the new `CommonDecoder` protocol and the existing `Decodable` protocol
    /// by using `decodeAny` to capture the raw value and then wrapping it in an `AdaptorDecoder` for standard decoding.
    ///
    /// - parameter type: The type of value to decode.
    /// - returns: The decoded value.
    /// - throws: `CodingError.Decoding` if decoding fails.
    @_disfavoredOverload
    @_lifetime(self: copy self)
    mutating func decode<D: Decodable>(_: D.Type) throws(CodingError.Decoding) -> D
    
    var codingPath: CodingPath { get }
}

extension CommonDecoder where Self: ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodable & ~Copyable>(_: T.Type) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodable>(_: T.Type) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodableWithContext & ~Copyable>(with context: inout T.CommonDecodingContext) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self, context: &context)
    }
    
    /// Convenience: decode using an explicit context (inout version for stateful contexts).
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodableWithContext & ~Copyable>(_ type: T.Type, context: inout T.CommonDecodingContext) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self, context: &context)
    }
    
    /// Convenience: decode using an explicit context (copyable version for static member syntax).
    /// This enables clean syntax: `decoder.decode(Date.self, context: .iso8601)`
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func decode<T: CommonDecodableWithContext & ~Copyable>(_ type: T.Type, context: T.CommonDecodingContext) throws(CodingError.Decoding) -> T where T.CommonDecodingContext: Copyable {
        try T.decode(from: &self, context: context)
    }
}

/// A decoder that allows a dictionary visitor to decode string-based keys and values
/// one at a time from an encoded dictionary.
public protocol CommonStructDecoder: ~Escapable {
    associatedtype FieldDecoder: CommonFieldDecoder & ~Escapable
    associatedtype ValueDecoder: CommonDecoder & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool

    @_lifetime(self: copy self)
    mutating func decodeEachField(_ fieldDecoderClosure: (inout FieldDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    @_lifetime(self: copy self)
    mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Bool) throws(CodingError.Decoding)
    
    var sizeHint: Int? { get }
    var codingPath: CodingPath { get }
}

public extension CommonStructDecoder where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func decodeExpectedOrderField(matchingClosure: (UTF8Span) -> Bool, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool {
        try decodeExpectedOrderField(required: true, matchingClosure: matchingClosure, andValue: valueDecoderClosure)
    }

    @_lifetime(self: copy self)
    mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        try self.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
            try closure(key, &valueDecoder)
            return false
        }
    }
}

public extension CommonStructDecoder where Self: ~Escapable {
    var sizeHint: Int? { nil }
}

public protocol CommonDictionaryDecoder: ~Escapable {
    associatedtype KeyDecoder: CommonDecoder & ~Escapable
    associatedtype ValueDecoder: CommonDecoder & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func decodeEachKey(_ keyDecodingClosure: (inout KeyDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    @_lifetime(self: copy self)
    mutating func decodeKey(_ keyDecodingClosure: (inout KeyDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool
    
    var codingPath: CodingPath { get }
}

public protocol CommonArrayDecoder: ~Escapable {
    associatedtype ElementDecoder: CommonDecoder & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func decodeNext<T: ~Copyable>(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T?
    
    @_lifetime(self: copy self)
    mutating func decodeEachElement(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    var sizeHint: Int? { get }
    var codingPath: CodingPath { get }
}

public extension CommonArrayDecoder where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func decodeNext<T: CommonDecodable & ~Copyable>(_ t: T.Type) throws(CodingError.Decoding) -> T? {
        try self.decodeNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func decodeRequiredNext<T: ~Copyable>(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        guard let result = try self.decodeNext(closure) else {
            throw CodingError.valueNotFound(expectedType: T.self)
        }
        return result
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func decodeRequiredNext<T: CommonDecodable & ~Copyable>(_ t: T.Type) throws(CodingError.Decoding) -> T {
        return try decodeRequiredNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }
    
    @_disfavoredOverload
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func decodeNext<T: Decodable>(_ t: T.Type) throws(CodingError.Decoding) -> T? {
        try self.decodeNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }
    
    @_disfavoredOverload
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func decodeRequiredNext<T: Decodable>(_ t: T.Type) throws(CodingError.Decoding) -> T {
        return try decodeRequiredNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }
    
    var sizeHint: Int? { nil }
}

public extension CommonDecoder where Self: ~Escapable {
    @_lifetime(self: copy self)
    mutating func decode<Key: CodingStringKeyRepresentable, Value: CommonDecodable>(_: [Key:Value].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Key:Value] {
        return try self.decodeDictionary { dictDecoder throws(CodingError.Decoding) in
            var accumulatedDictionary = [Key:Value]()
            accumulatedDictionary.reserveCapacity(sizeHint)
            
            var key: Key? = nil
            try dictDecoder.decodeEachKey { keyDecoder throws(CodingError.Decoding) in
                key = try keyDecoder.decodeString(Key.codingStringKeyVisitor)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                let value = try valueDecoder.decode(Value.self)
                accumulatedDictionary[key!] = value
            }
            
            return accumulatedDictionary
        }
    }
    
    @_lifetime(self: copy self)
    mutating func decode<Element: CommonDecodable>(_: [Element].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Element] {
        return try self.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            var accumulatedArray = [Element]()
            accumulatedArray.reserveCapacity(sizeHint)
            
            try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                let element = try elementDecoder.decode(Element.self)
                accumulatedArray.append(element)
            }
            return accumulatedArray
        }
    }
}

public extension CommonDecoder where Self: ~Escapable {
    @_lifetime(self: copy self)
    mutating func decodeStruct<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        throw CodingError.unsupportedDecodingType("struct")
    }
    
    @_lifetime(self: copy self)
    mutating func decodeDictionary<T: ~Copyable>( _ closure: (inout DictionaryDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        throw CodingError.unsupportedDecodingType("dictionary")
    }
    
    @_lifetime(self: copy self)
    mutating func decodeArray<T: ~Copyable>(_ closure: (inout ArrayDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        throw CodingError.unsupportedDecodingType("array")
    }
    
    // MARK: - Enum Decoding
    
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (inout FieldDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        throw CodingError.unsupportedDecodingType("enum")
    }
    
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (_ caseName: inout FieldDecoder, _ associatedValues: inout StructDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T {
        throw CodingError.unsupportedDecodingType("enum")
    }
    
    @_lifetime(self: copy self)
    mutating func decode(_: Bool.Type) throws(CodingError.Decoding) -> Bool { throw CodingError.unsupportedDecodingType("boolean") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int.Type) throws(CodingError.Decoding) -> Int { throw CodingError.unsupportedDecodingType("Int") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int8.Type) throws(CodingError.Decoding) -> Int8 { throw CodingError.unsupportedDecodingType("Int8") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int16.Type) throws(CodingError.Decoding) -> Int16 { throw CodingError.unsupportedDecodingType("Int16") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int32.Type) throws(CodingError.Decoding) -> Int32 { throw CodingError.unsupportedDecodingType("Int32") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int64.Type) throws(CodingError.Decoding) -> Int64 { throw CodingError.unsupportedDecodingType("Int64") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Int128.Type) throws(CodingError.Decoding) -> Int128 { throw CodingError.unsupportedDecodingType("Int128") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt.Type) throws(CodingError.Decoding) -> UInt { throw CodingError.unsupportedDecodingType("UInt") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt8.Type) throws(CodingError.Decoding) -> UInt8 { throw CodingError.unsupportedDecodingType("UInt8") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt16.Type) throws(CodingError.Decoding) -> UInt16 { throw CodingError.unsupportedDecodingType("UInt16") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt32.Type) throws(CodingError.Decoding) -> UInt32 { throw CodingError.unsupportedDecodingType("UInt32") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt64.Type) throws(CodingError.Decoding) -> UInt64 { throw CodingError.unsupportedDecodingType("UInt64") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: UInt128.Type) throws(CodingError.Decoding) -> UInt128 { throw CodingError.unsupportedDecodingType("UInt128") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Float.Type) throws(CodingError.Decoding) -> Float { throw CodingError.unsupportedDecodingType("Float") }
    
    @_lifetime(self: copy self)
    mutating func decode(_ hint: Double.Type) throws(CodingError.Decoding) -> Double { throw CodingError.unsupportedDecodingType("Double") }
    
    @_lifetime(self: copy self)
    mutating func decode(_: String.Type) throws(CodingError.Decoding) -> String { throw CodingError.unsupportedDecodingType("string") }
    
    @_lifetime(self: copy self)
    mutating func decodeString<V: DecodingStringVisitor>(_ visitor: V) throws(CodingError.Decoding) -> V.DecodedValue { throw CodingError.unsupportedDecodingType("string") }
    
    @_lifetime(self: copy self)
    mutating func decodeNil() throws(CodingError.Decoding) -> Bool { throw CodingError.unsupportedDecodingType("nil") }
    
    @_lifetime(self: copy self)
    mutating func decodeOptional(_ closure: (inout Self) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) { throw CodingError.unsupportedDecodingType("optional") }
    
    var supportsDecodeAny: Bool { false }
    
    @_lifetime(self: copy self)
    mutating func decodeAny<V: CommonDecodingVisitor>(_ visitor: V) throws(CodingError.Decoding) -> V.DecodedValue  { throw CodingError.unsupportedDecodingType("any") }
    
    //    @_lifetime(self: copy self)
    //    mutating func decodePrimitive() throws(CodingError.Decoding) -> CommonCodingPrimitive { throw CodingError.unsupportedDecodingType("primitive") }
    
    
    /// Decode a value using a visitor, with a hint that a collection of bytes is expected in the encoded data.
    ///
    /// - parameter visitor: An instance of the type that will create the `DecodedValue`
    ///   from the bytes the decoder makes it visit.
    /// - returns: The value created by the `visitor`.
    /// - throws: TBD. An error thrown by the `visitor`. Others?
    @_lifetime(self: copy self)
    mutating func decodeBytes<V: DecodingBytesVisitor>(visitor: V) throws(CodingError.Decoding) -> V.DecodedValue  { throw CodingError.unsupportedDecodingType("bytes") }
}

public extension CommonDecodingVisitor where Self: ~Copyable & ~Escapable {
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue {
        throw CodingError.unsupportedDecodingType("struct")
    }
    
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some CommonArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue {
        throw CodingError.unsupportedDecodingType("sequence")
    }

    func visitNone() throws(CodingError.Decoding) -> DecodedValue {
        throw CodingError.unsupportedDecodingType("none")
    }
    
    // A conformer of just DecodingBytesVisitor or DecodingStringVisitor is expected to implement these methods, but a general CommonDecodingVisitor does not.
    
    func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
        throw CodingError.unsupportedDecodingType("UTF8 string bytes")
    }
    
    func visitBytes(_ array: [UInt8]) throws(CodingError.Decoding) -> DecodedValue {
        throw CodingError.unsupportedDecodingType("bytes")
    }
}

public extension CommonDecoder where Self: ~Escapable {
    /// Default implementation for decoding standard `Decodable` types using `decodeAny` and `AdaptorDecoder`.
    ///
    /// This implementation uses a visitor pattern to capture the raw value as `CommonCodablePrimitive` via `decodeAny`,
    /// then wraps it in an `AdaptorDecoder` to provide the standard `Decoder` interface expected by `Decodable` types.
    @_lifetime(self: copy self)
    mutating func decode<D: Decodable>(_: D.Type) throws(CodingError.Decoding) -> D {
        guard self.supportsDecodeAny else {
            throw CodingError.unsupportedDecodingType("any")
        }
        
        let visitor = CommonPrimitiveVisitor()
        let element = try self.decodeAny(visitor)
        let decoder = AdaptorDecoder(value: element, decoderContext: [:], codingPath: self.codingPath.toCodingKeys())
        
        do {
            return try D(from: decoder)
        } catch {
            // TODO: Wrap error better.
            throw CodingError.unsupportedDecodingType("Failed to decode \(D.self): \(error)")
        }
    }
}
