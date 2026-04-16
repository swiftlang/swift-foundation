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

// MARK: - JSON Decoding Context Design

/// Types that can be decoded from JSON.
public protocol JSONDecodable: ~Copyable {
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self
}

/// Types that can be decoded from JSON with a context.
public protocol JSONDecodableWithContext: ~Copyable {
    associatedtype JSONDecodingContext: ~Copyable & ~Escapable
    @_lifetime(decoder: copy decoder)
    static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D, context: inout JSONDecodingContext) throws(CodingError.Decoding) -> Self
}

// Convenience for Copyable contexts - allows static member syntax
extension JSONDecodableWithContext where Self: ~Copyable, JSONDecodingContext: Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(decoder: copy decoder)
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D, context: JSONDecodingContext) throws(CodingError.Decoding) -> Self {
        var mutableContext = context
        return try Self.decode(from: &decoder, context: &mutableContext)
    }
}

// TODO: Generalize for non-JSON?
public protocol JSONFieldDecoder: ~Escapable {
    @inlinable
    func decode<T: DecodingField>(_: T.Type) throws(CodingError.Decoding) -> T
    
    @inlinable
    func matches(_ field: some DecodingField) -> Bool
    
    @_alwaysEmitIntoClient
    func matches(_ key: StaticString) -> Bool
}

public protocol JSONDictionaryDecoder: ~Escapable {
    associatedtype FieldDecoder: JSONFieldDecoder & ~Escapable
    associatedtype ValueDecoder: JSONDecoderProtocol & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func decodeExpectedOrderField(required: Bool, matchingClosure: (UTF8Span) -> Bool, optimizedSafeStringKey: JSONSafeStringKey?, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool
    
    @_lifetime(self: copy self)
    mutating func decodeEachField(_ fieldDecoderClosure: (inout FieldDecoder) throws(CodingError.Decoding) -> Void, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
        
    @_lifetime(self: copy self)
    mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Bool) throws(CodingError.Decoding)

    @_lifetime(self: copy self)
    mutating func decodeKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) -> Bool

    @_lifetime(self: copy self)
    mutating func withWrappingDecoder<T>(_ closure: (inout ValueDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
    
    func prepareIntermediateValueStorage() -> JSONIntermediateKeyValueStorage
    
    var sizeHint: Int? { get }
    
    var codingPath: CodingPath { get }
}

public extension JSONDictionaryDecoder where Self: ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func decodeExpectedOrderField<Field: DecodingField>(_ field: Field, inOrder: inout Bool, required: Bool = true, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        guard inOrder else { return }
        inOrder = try self.decodeExpectedOrderField(required: required, matchingClosure: { span in field.matches(span) }, optimizedSafeStringKey: nil, andValue: valueDecoderClosure)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func decodeExpectedOrderField<Field: JSONOptimizedDecodingField>(_ field: Field, inOrder: inout Bool, required: Bool = true, andValue valueDecoderClosure: (inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        guard inOrder else { return }
        inOrder = try self.decodeExpectedOrderField(required: required, matchingClosure: { _ in false }, optimizedSafeStringKey: field.safeStringKey, andValue: valueDecoderClosure)
    }

    @_lifetime(self: copy self)
    mutating func decodeEachKeyAndValue(_ closure: (String, inout ValueDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding) {
        try self.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
            try closure(key, &valueDecoder)
            return false
        }
    }
}

extension JSONDictionaryDecoder where Self: ~Escapable {
    public var sizeHint: Int? { nil }
}

public protocol JSONArrayDecoder: ~Escapable {
    associatedtype ElementDecoder: JSONDecoderProtocol & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func decodeNext<T: ~Copyable>(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T?
    
    @_lifetime(self: copy self)
    mutating func decodeEachElement(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    var sizeHint: Int? { get }
    
    var codingPath: CodingPath { get }
}

extension JSONArrayDecoder where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decodeNext<T: JSONDecodable & ~Copyable>(_ t: T.Type) throws(CodingError.Decoding) -> T? {
        try self.decodeNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decodeRequiredNext<T: ~Copyable>(_ closure: (inout ElementDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        guard let result = try self.decodeNext(closure) else {
            throw CodingError.valueNotFound(expectedType: T.self, at: self.codingPath)
        }
        return result
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    public mutating func decodeRequiredNext<T: JSONDecodable & ~Copyable>(_ t: T.Type) throws(CodingError.Decoding) -> T {
        return try decodeRequiredNext { elementDecoder throws(CodingError.Decoding) in
            try elementDecoder.decode(t)
        }
    }

    public var sizeHint: Int? { nil }
}

public protocol JSONDecoderProtocol: ~Escapable {
    associatedtype StructDecoder: JSONDictionaryDecoder & ~Escapable
    associatedtype ArrayDecoder: JSONArrayDecoder & ~Escapable
    associatedtype FieldDecoder: JSONFieldDecoder & ~Escapable
    
    // MARK: - Structural Decoding
    
    @_lifetime(self: copy self)
    mutating func decodeStruct<T: ~Copyable>(_ closure: (inout StructDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decodeArray<T: ~Copyable>(_ closure: (inout ArrayDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T
    
    // MARK: - Enum Decoding
    
    /// Decodes an enum case with no associated values from `{"caseName":{}}` format
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (inout FieldDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T
    
    /// Decodes an enum case with associated values from `{"caseName":{"field1":value1,...}}` format
    @_lifetime(self: copy self)
    mutating func decodeEnumCase<T: ~Copyable>(
        _ closure: (_ caseName: inout FieldDecoder, _ associatedValues: inout StructDecoder) throws(CodingError.Decoding) -> T
    ) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decode<Key: CodingStringKeyRepresentable, Value: JSONDecodable>(_: [Key:Value].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Key:Value]
    
    @_lifetime(self: copy self)
    mutating func decode<Element: JSONDecodable>(_: [Element].Type, sizeHint: Int) throws(CodingError.Decoding) -> [Element]
    
    @_lifetime(self: copy self)
    mutating func decode<Element: JSONDecodableWithContext>(_: [Element].Type, context: inout Element.JSONDecodingContext, sizeHint: Int) throws(CodingError.Decoding) -> [Element]
    
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
    mutating func decodeString<V: DecodingStringVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue
    
    @_lifetime(self: copy self)
    mutating func decodeBytes<V: DecodingBytesVisitor>(visitor: V) throws(CodingError.Decoding) -> V.DecodedValue
    
    @_lifetime(self: copy self)
    mutating func decodeNumber() throws(CodingError.Decoding) -> JSONPrimitive.Number
    
    @_lifetime(self: copy self)
    mutating func decodeNil() throws(CodingError.Decoding) -> Bool
    
    @_lifetime(self: copy self)
    mutating func decodeOptional(_ closure: (inout Self) throws(CodingError.Decoding) -> Void) throws(CodingError.Decoding)
    
    @_lifetime(self: copy self)
    mutating func decodeAny<V: JSONDecodingVisitor & ~Copyable & ~Escapable>(_ visitor: borrowing V) throws(CodingError.Decoding) -> V.DecodedValue
    
    @_lifetime(self: copy self)
    mutating func decodeJSONPrimitive() throws(CodingError.Decoding) -> JSONPrimitive
    
    // TODO: Reconsider whether this is necessary. For this to work, both the `JSONDecodable & CommonDecodable` and `CommonDecodable` overloads need to be in the SAME place (as requirements, and on the concrete type). It doesn't work if the former is in an extension on just `JSONDecoderProtocol` alone.
    @_lifetime(self: copy self)
    mutating func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decode<T: JSONDecodable & CommonDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T
    
    @_lifetime(self: copy self)
    mutating func decode<T: CommonDecodable & ~Copyable>(_ t: T.Type) throws(CodingError.Decoding) -> T
    
    @_disfavoredOverload
    @_lifetime(self: copy self)
    mutating func decode<T: Decodable>(_ t: T.Type) throws(CodingError.Decoding) -> T
    
    var codingPath: CodingPath { get }
}

// MARK: - Convenience Extensions

extension JSONDecoderProtocol where Self: ~Escapable {
    /// Convenience: decode a value using the provided context.
    @_lifetime(self: copy self)
    @inline(__always)
    @_alwaysEmitIntoClient
    public mutating func decode<T: JSONDecodableWithContext & ~Copyable>(with context: inout T.JSONDecodingContext) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self, context: &context)
    }
    
    /// Convenience: decode a JSONDecodable type using its default implementation.
    @_lifetime(self: copy self)
    @inline(__always)
    @_alwaysEmitIntoClient
    public mutating func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self)
    }
    
    /// Convenience: decode using an explicit context (inout version for stateful contexts).
    @_lifetime(self: copy self)
    @inline(__always)
    @_alwaysEmitIntoClient
    public mutating func decode<T: JSONDecodableWithContext & ~Copyable>(_ type: T.Type, context: inout T.JSONDecodingContext) throws(CodingError.Decoding) -> T {
        try T.decode(from: &self, context: &context)
    }
    
    /// Convenience: decode using an explicit context (copyable version for static member syntax).
    /// This enables clean syntax: `decoder.decode(Date.self, context: .iso8601)`
    @_lifetime(self: copy self)
    @inline(__always)
    @_alwaysEmitIntoClient
    public mutating func decode<T: JSONDecodableWithContext & ~Copyable>(_ type: T.Type, context: T.JSONDecodingContext) throws(CodingError.Decoding) -> T where T.JSONDecodingContext: Copyable {
        try T.decode(from: &self, context: context)
    }
}

public protocol JSONDecodingVisitor: DecodingBoolVisitor, DecodingNumberVisitor, DecodingStringVisitor, ~Copyable, ~Escapable {
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue
    @_lifetime(decoder: copy decoder)
    func visit(decoder: inout some JSONArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue

    // TODO: Should these be in a JSON-specific refinement of DecodingNumberVisitor?
    var prefersArbitraryPrecisionNumbers: Bool { get }
    func visitArbitraryPrecisionNumber(_ span: UTF8Span) throws(CodingError.Decoding) -> DecodedValue
    func visitArbitraryPrecisionNumber(_ string: String) throws(CodingError.Decoding) -> DecodedValue

    func visitNone() throws(CodingError.Decoding) -> DecodedValue
}

extension JSONDecodingVisitor where Self: ~Copyable & ~Escapable {
    var prefersArbitraryPrecisionNumbers: Bool { false }
}

// MARK: Primitive type adoptions:

extension Bool: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension String: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int8: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int16: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int32: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int64: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int128: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt8: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt16: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt32: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt64: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt128: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Float: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Double: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Optional: JSONDecodable where Wrapped: JSONDecodable & ~Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        var result: Exclusive<Wrapped>? = nil
        try decoder.decodeOptional { valueDecoder throws(CodingError.Decoding) in
            result = Exclusive(try valueDecoder.decode(Wrapped.self))
        }
        return result?.take()
    }
}

extension Array: JSONDecodable where Element: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self, sizeHint: 0)
    }
}

extension Dictionary: JSONDecodable where Key: CodingStringKeyRepresentable, Value: JSONDecodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self, sizeHint: 0)
    }
}

// MARK: RawRepresentable extension

extension RawRepresentable where Self: JSONDecodable, RawValue: JSONDecodable {
    @_alwaysEmitIntoClient
    @inlinable
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        let rawValue = try decoder.decode(RawValue.self)
        guard let result = Self(rawValue: rawValue) else {
            throw CodingError.dataCorrupted(debugDescription: "Invalid raw value \(rawValue) for type \(Self.self)")
        }
        return result
    }
}

// MARK: stdlib adoptions

extension InlineArray: JSONDecodable where Element: JSONDecodable & ~Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> InlineArray<count, Element> {
        try .init(initializingWith: { outputSpan throws(CodingError.Decoding) in
            try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                var total = 0
                try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                    total &+= 1
                    // TODO: Error.
                    guard total <= Self.count else { throw CodingError.dataCorrupted() }
                    let element = try elementDecoder.decode(Element.self)
                    outputSpan.append(element)
                }
                guard total == Self.count else {
                    // TODO: Error.
                    throw CodingError.dataCorrupted()
                }
            }
        })
    }
}

extension Range: JSONDecodable where Bound: JSONDecodable {
    public static func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> Range {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            let lowerBound = try arrayDecoder.decodeRequiredNext(Bound.self)
            let upperBound = try arrayDecoder.decodeRequiredNext(Bound.self)
            
            guard lowerBound <= upperBound else {
                throw CodingError.dataCorrupted(
                  debugDescription: "Cannot initialize \(Range.self) with a lowerBound (\(lowerBound)) greater than upperBound (\(upperBound))"
                )
            }
            return self.init(uncheckedBounds: (lower: lowerBound, upper: upperBound))
        }
    }
}

extension PartialRangeUpTo: JSONDecodable where Bound: JSONDecodable {
    public static func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> PartialRangeUpTo {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            let upperBound = try arrayDecoder.decodeRequiredNext(Bound.self)
            return .init(upperBound)
        }
    }
}

// TODO: Etc.

@frozen
public struct JSONSafeStringKey {
    public let string: StaticString
    
    @inline(__always)
    @_alwaysEmitIntoClient
    init(_ string: StaticString) {
        // TODO: The idea was that this would be constant-folded at compile time for any given string, but it appears to stop working after 9 characters in lenght.
//        if Self.containsUnescapedQuote(string) {
//            preconditionFailure("Unsafe JSON key")
//        }
        self.string = string
    }
    
//    @inline(__always)
//    @_alwaysEmitIntoClient
//    static func containsUnescapedQuote(_ string: StaticString) -> Bool {
//        let utf8Start = string.utf8Start
//        let count = string.utf8CodeUnitCount
//        
//        var i = 0
//        while i < count {
//            let byte = utf8Start[i]
//            
//            // Check if we found a quote
//            if byte == UInt8(ascii: "\"") {
//                // Count preceding backslashes
//                var backslashCount = 0
//                var j = i - 1
//                while j >= 0 && utf8Start[j] == UInt8(ascii: "\\") {
//                    backslashCount += 1
//                    j -= 1
//                }
//                
//                // If even number of backslashes (including 0), the quote is unescaped
//                if backslashCount % 2 == 0 {
//                    return true
//                }
//            }
//            
//            i += 1
//        }
//        
//        return false
//    }
}

public protocol JSONOptimizedDecodingField: StaticStringDecodingField, ~Escapable where Self.UTF8SpanComparator == DecodingFieldUTF8SpanRawByteEquivalanceComparator {
    var safeStringKey: JSONSafeStringKey { get }
}

public extension JSONOptimizedDecodingField where Self: ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    var safeStringKey: JSONSafeStringKey {
        .init(self.staticString)
    }
}
