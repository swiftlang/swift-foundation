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


#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
import WASILibc
#endif

public typealias CommonCodable = CommonEncodable & CommonDecodable

public typealias JSONCodable = JSONEncodable & JSONDecodable

public typealias CommonCodableWithContext = CommonEncodableWithContext & CommonDecodableWithContext

public typealias JSONCodableWithContext = JSONEncodableWithContext & JSONDecodableWithContext

/// Unsafely discard any lifetime dependency on the `dependent` argument. Return
/// a value identical to `dependent` with a lifetime dependency on the caller's
/// borrow scope of the `source` argument.
@unsafe
@_unsafeNonescapableResult
@_alwaysEmitIntoClient
@_transparent
@_lifetime(borrow source)
internal func _overrideLifetime<
  T: ~Copyable & ~Escapable, U: ~Copyable & ~Escapable
>(
  _ dependent: consuming T, borrowing source: borrowing U
) -> T {
  // TODO: Remove @_unsafeNonescapableResult. Instead, the unsafe dependence
  // should be expressed by a builtin that is hidden within the function body.
  dependent
}

/// Unsafely discard any lifetime dependency on the `dependent` argument.
/// Return a value identical to `dependent` with a lifetime dependency
/// on the caller's exclusive borrow scope of the `source` argument.
@unsafe
@_unsafeNonescapableResult
@_alwaysEmitIntoClient
@_transparent
@_lifetime(&source)
internal func _overrideLifetime<
  T: ~Copyable & ~Escapable, U: ~Copyable & ~Escapable
>(
  _ dependent: consuming T,
  mutating source: inout U
) -> T {
  dependent
}

extension RawSpan {
    @inlinable
    @inline(__always)
    internal func _loadByteUnchecked(_ offset: Int) -> UInt8 {
        unsafeLoadUnaligned(fromUncheckedByteOffset: offset, as: UInt8.self)
    }
}

internal extension Data {
    init(_copying span: RawSpan) {
        self = span.withUnsafeBytes {
            Data($0)
        }
    }
}

extension String {
    @usableFromInline
    static func _tryFromUTF8(_ span: borrowing RawSpan) -> String? {
        return span.withUnsafeBytes {
            _tryFromUTF8($0.bindMemory(to: UInt8.self))
        }
    }
}

/// The base protocol for all decoding visitors.
public protocol BaseDecodingVisitor: ~Copyable & ~Escapable {
    /// The type of value being decoded.
    associatedtype DecodedValue: ~Copyable
}

/// A type that will visit a boolean value from a decoder to produce a decoded value.
public protocol DecodingBoolVisitor: BaseDecodingVisitor & ~Copyable & ~Escapable {
    /// Produces a `DecodedValue` from the boolean encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ bool: Bool) throws(CodingError.Decoding) -> DecodedValue
}

public protocol DecodingNumberVisitor: BaseDecodingVisitor & ~Copyable & ~Escapable {
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int8) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int16) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int32) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int64) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: Int128) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt8) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt16) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt32) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt64) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ integer: UInt128) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ double: Double) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the integer encountered by the decoder
    /// or throws an error if the value is invalid.
    func visit(_ float: Float) throws(CodingError.Decoding) -> DecodedValue
}

/// A type that will visit a numerical value from a decoder to produce a decoded value.
public extension DecodingNumberVisitor where Self: ~Copyable & ~Escapable {
    func visit(_ integer: Int) throws(CodingError.Decoding) -> DecodedValue { try visit(Int64(integer)) }
    func visit(_ integer: Int8) throws(CodingError.Decoding) -> DecodedValue { try visit(Int64(integer)) }
    func visit(_ integer: Int16) throws(CodingError.Decoding) -> DecodedValue { try visit(Int64(integer)) }
    func visit(_ integer: Int32) throws(CodingError.Decoding) -> DecodedValue { try visit(Int64(integer)) }
    func visit(_ integer: Int64) throws(CodingError.Decoding) -> DecodedValue { throw CodingError.unsupportedDecodingType("Int64") }
    func visit(_ integer: Int128) throws(CodingError.Decoding) -> DecodedValue { throw CodingError.unsupportedDecodingType("Int128") }
    func visit(_ integer: UInt) throws(CodingError.Decoding) -> DecodedValue { try visit(UInt64(integer)) }
    func visit(_ integer: UInt8) throws(CodingError.Decoding) -> DecodedValue { try visit(UInt64(integer)) }
    func visit(_ integer: UInt16) throws(CodingError.Decoding) -> DecodedValue { try visit(UInt64(integer)) }
    func visit(_ integer: UInt32) throws(CodingError.Decoding) -> DecodedValue { try visit(UInt64(integer)) }
    func visit(_ integer: UInt64) throws(CodingError.Decoding) -> DecodedValue { throw CodingError.unsupportedDecodingType("UInt64") }
    func visit(_ integer: UInt128) throws(CodingError.Decoding) -> DecodedValue { throw CodingError.unsupportedDecodingType("UInt128") }
    func visit(_ float: Float) throws(CodingError.Decoding) -> DecodedValue { try visit(Double(float)) }
    func visit(_ double: Double) throws(CodingError.Decoding) -> DecodedValue { throw CodingError.unsupportedDecodingType("Double") }
}


/// A type that will visit a string value from a decoder to produce a decoded value.
public protocol DecodingStringVisitor: BaseDecodingVisitor & ~Copyable & ~Escapable {
    /// Produces a `DecodedValue` from the `UTF8Span` encountered by the decoder
    /// or throws an error if the value is invalid. This method must be implemented.
    func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the string encountered by the decoder
    /// or throws an error if the value is invalid. The default implementation calls `visitUTF8Bytes`.
    func visitString(_ string: String) throws(CodingError.Decoding) -> DecodedValue
}

public extension DecodingStringVisitor where Self: ~Copyable & ~Escapable {
    func visitString(_ string: String) throws(CodingError.Decoding) -> DecodedValue {
        // TODO: watchOS/32-bit.
        return try visitUTF8Bytes(string.utf8Span)
    }
}

/// A type that will visit a collection of encoded bytes from a decoder to produce a decoded value.
public protocol DecodingBytesVisitor: BaseDecodingVisitor & ~Copyable & ~Escapable {
    /// Produces a `DecodedValue` from the `RawSpan` encountered by the decoder
    /// or throws an error if the bytes are invalid.
    ///
    /// Decoders may invoke this function if the encoded data directly includes the bytes inline.
    /// Implement this function to avoid making an extra copy of the bytes, when possible. If you do
    /// you must still implement `visitBytes(_:[UInt8])`. The default implementation creates
    /// a `[UInt8]` from the `span` and calls `visitBytes(_:[UInt8])`.
    func visitBytes(_ span: RawSpan) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the byte iterator created by the decoder or throws
    /// an error if the bytes are invalid.
    ///
    /// Decoders may invoke this function if the byte sequence can be produced while referencing
    /// the encoded data without copying it. For example, if a serialization format encodes bytes as
    /// a Base64 string, the decoder can avoid making an extra full copy of the data by supplying
    /// an iterator to this function that progressively decodes one byte at a time from the Base64
    /// string.
    ///
    /// Implement this function to avoid making an extra copy of the bytes, when possible. If you do
    /// you must still implement `visitBytes(_:[UInt8])`. The default implementation creates
    /// a `[UInt8]` from values emitted by the `iterator` and calls `visitBytes(_:[UInt8])`.
    @_lifetime(iterator: copy iterator)
    func visitBytes(_ iterator: inout some (DecodingBytesIterator & ~Copyable & ~Escapable)) throws(CodingError.Decoding) -> DecodedValue
    
    /// Produces a `DecodedValue` from the `[UInt8]` created by the decoder or throws
    /// an error if the bytes are invalid.
    ///
    /// Decoders should invoke this function only if it isn't possible or reasonably efficient to invoke either
    /// of the above two functions.
    ///
    /// This function must be implemented by conformers.
    func visitBytes(_ array: [UInt8]) throws(CodingError.Decoding) -> DecodedValue
}

public extension DecodingBytesVisitor where Self: ~Copyable & ~Escapable {
    func visitBytes(_ span: RawSpan) throws(CodingError.Decoding) -> DecodedValue {
        try span.withUnsafeBytes { bytes throws(CodingError.Decoding) in
            return try visitBytes([UInt8](bytes))
        }
        
    }
    @_lifetime(iterator: copy iterator)
    func visitBytes(_ iterator: inout some (DecodingBytesIterator & ~Copyable & ~Escapable)) throws(CodingError.Decoding) -> DecodedValue {
        var bytes = [UInt8]()
        while let b = try iterator.next() {
            bytes.append(b)
        }
        return try visitBytes(bytes)
    }
}


/// A non-escapable iterator of bytes originating from a decoder.
public protocol DecodingBytesIterator: ~Copyable & ~Escapable {
    /// Advances to the next byte and returns it, or nil if no next byte exists.
    /// - throws: An error if decoding the next byte fails.
    mutating func next() throws(CodingError.Decoding) -> UInt8?
}

public protocol DecodingFieldUTF8SpanComparator: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(copy span)
    init(_ span: UTF8Span)
    
    @_alwaysEmitIntoClient
    @inline(__always)
    func matchesSpan(_ span: UTF8Span) -> Bool
    
    @_alwaysEmitIntoClient
    @inline(__always)
    static func ~= (lhs: StaticString, rhs: Self) -> Bool
}

public extension DecodingFieldUTF8SpanComparator where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    static func ~= (lhs: StaticString, rhs: Self) -> Bool {
        if lhs.hasPointerRepresentation {
            let utf8Span = UTF8Span(unchecked: .init(_unsafeStart: lhs.utf8Start, count: lhs.utf8CodeUnitCount), isKnownASCII: lhs.isASCII)
            return rhs.matchesSpan(utf8Span)
        } else {
#if $Embedded
            fatalError("non-pointer representation not supported in embedded Swift")
#else
            // TODO: More efficient without allocations.
            return rhs.matchesSpan(String(lhs.unicodeScalar).utf8Span)
#endif
        }
    }
}
 
// TODO: This comparator needs testing.

@frozen
public struct DecodingFieldUTF8SpanCanonicalEquivalenceComparator: DecodingFieldUTF8SpanComparator, ~Escapable {
    public let span: UTF8Span
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(copy span)
    public init(_ span: UTF8Span) {
        self.span = span
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func matchesSpan(_ span: UTF8Span) -> Bool {
        self.span.isCanonicallyEquivalent(to: span)
    }
}

@frozen
public struct DecodingFieldUTF8SpanRawByteEquivalanceComparator: DecodingFieldUTF8SpanComparator, ~Escapable {
//    public let span: UTF8Span
    public let buffer: UnsafeBufferPointer<UInt8>
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(copy span)
    public init(_ span: UTF8Span) {
//        self.span = span
        // TODO: This is **AWFUL** but the UTF8Span version isn't getting optimized into the memcmp, which is necessary for the optimized length-bucketed binary search `switch` implementation we want.
        self.buffer = span.span.withUnsafeBufferPointer {
            $0
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func matchesSpan(_ span: UTF8Span) -> Bool {
        guard self.buffer.count == span.count else { return false }
        guard !self.buffer.isEmpty else { return false }
        
        return span.span.withUnsafeBufferPointer { buf2 in
            memcmp(self.buffer.baseAddress!, buf2.baseAddress!, self.buffer.count) == 0
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func ~= (lhs: StaticString, rhs: Self) -> Bool {
        guard lhs.utf8CodeUnitCount == rhs.buffer.count else {
            return false
        }

        return memcmp(lhs.utf8Start, rhs.buffer.baseAddress!, lhs.utf8CodeUnitCount) == 0

    }
}

public protocol DecodingField: ~Escapable {
    associatedtype UTF8SpanComparator: DecodingFieldUTF8SpanComparator & ~Escapable = DecodingFieldUTF8SpanCanonicalEquivalenceComparator
    
    // TODO: Reconsider these callouts. Should there be a `RawSpan/Span<UInt8>` callout when we want to opt in the literal byte comparison (e.g. DecodingFieldUTF8SpanRawByteEquivalanceComparator) to skip the effort of validating the input's UTF-8? If it matches another valid UTF8Span and the client doesn't care about canonical equivalance, then this is redundant work.
    
    /// Converts the given `String` into the corresponding `Field`. If the value is
    /// unexpected, this can return `.unknown` or throw an error, depending on the
    /// desired decoding semantics.
    ///
    /// The default implementation calls `field(for key: UTF8Span)` with `key`'s
    /// `UTF8Span` and returns the result.
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(immortal)
    static func field(for key: String) throws(CodingError.Decoding) -> Self
    
    /// Converts the given `UTF8Span` into the corresponding `Field`. If the value is
    /// unexpected, this can return `.unknown` or throw an error, depending on the
    /// desired decoding semantics.
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(immortal)
    static func field(for key: UTF8Span) throws(CodingError.Decoding) -> Self

    @_alwaysEmitIntoClient
    @inline(__always)
    func matches(_ key: UTF8Span) -> Bool
    
    @_alwaysEmitIntoClient
    @inline(__always)
    // TODO: This doesn't work in the unfortunate case where a StaticString is not a pointer representation.
//    var utf8Span: UTF8Span { @_lifetime(borrow self) get }
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T
}

public extension DecodingField where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(immortal)
    static func field(for key: String) throws(CodingError.Decoding) -> Self {
        try self.field(for: key.utf8Span)
    }
    
    @_alwaysEmitIntoClient
    func matches(_ key: UTF8Span) -> Bool {
        return self.withUTF8Span { thisSpan in
            let comparator = UTF8SpanComparator(thisSpan)
            return comparator.matchesSpan(key)
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    func matches(_ key: String) -> Bool {
        return matches(key.utf8Span)
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    var exactUTF8BCodeUnitCount: Int? { nil }
}

public protocol CodingField: EncodingField, DecodingField, ~Escapable { }

public protocol StaticStringDecodingField: DecodingField & ~Escapable {
    @inline(__always)
    var staticString: StaticString { get }
}

public extension DecodingField where Self: ~Escapable, Self: StaticStringDecodingField {
    @_alwaysEmitIntoClient
    @inline(__always)
    func matches(_ key: UTF8Span) -> Bool {
        let comparator = UTF8SpanComparator(key)
        return self.staticString ~= comparator
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        try self.staticString.withUTF8SpanForCodable(closure)
    }
}

public extension EncodingField where Self: ~Escapable, Self: StaticStringEncodingField {
    @_alwaysEmitIntoClient
    @inline(__always)
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        try self.staticString.withUTF8SpanForCodable(closure)
    }
}

public protocol RawByteEquivalenceDecodingField: DecodingField & ~Escapable where UTF8SpanComparator == DecodingFieldUTF8SpanRawByteEquivalanceComparator {
}

public extension RawByteEquivalenceDecodingField where Self: ~Escapable & StaticStringDecodingField {
    var exactUTF8BCodeUnitCount: Int? { self.staticString.utf8CodeUnitCount }
}

public protocol EncodingField: ~Escapable {
    
    @_alwaysEmitIntoClient
    @inline(__always)
    // TODO: This doesn't work in the unfortunate case where a StaticString is not a pointer representation.
//    var utf8Span: UTF8Span { @_lifetime(borrow self) get }
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T

}

public protocol StaticStringEncodingField: EncodingField, ~Escapable {
    @inline(__always)
    var staticString: StaticString { get }
}

public protocol StaticStringCodingField: StaticStringDecodingField, StaticStringEncodingField, ~Escapable { }

public extension CodingField where Self: StaticStringCodingField & ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
//    var utf8Span: UTF8Span { @_lifetime(borrow self) get }
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        try self.staticString.withUTF8SpanForCodable(closure)
    }
}


extension StaticString {
    @_alwaysEmitIntoClient
    @inline(__always)
    internal func withUTF8SpanForCodable<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        if self.hasPointerRepresentation {
            let utf8Span = UTF8Span(unchecked: .init(_unsafeStart: self.utf8Start, count: self.utf8CodeUnitCount), isKnownASCII: isASCII)
            return try closure(utf8Span)
        } else {
#if $Embedded
            fatalError("non-pointer representation not supported in embedded Swift")
#else
            // TODO: More efficient without allocations.
            return try closure(String(self.unicodeScalar).utf8Span)
#endif
        }
    }
}

public protocol CodingStringKeyRepresentable: ~Copyable {
    associatedtype KeyDecodingVisitor: DecodingStringVisitor & ~Copyable where KeyDecodingVisitor.DecodedValue == Self
    static var codingStringKeyVisitor: KeyDecodingVisitor { get }
    
    func withCodingStringUTF8Span<R, E>(_ body: (UTF8Span) throws(E) -> R) throws(E) -> R
}

extension String: CodingStringKeyRepresentable {
    public static var codingStringKeyVisitor: String.Visitor {
        String.Visitor()
    }
    
    public func withCodingStringUTF8Span<R, E>(_ body: (UTF8Span) throws(E) -> R) throws(E) -> R {
        try body(self.utf8Span)
    }
}

extension Int: CodingStringKeyRepresentable {
    public struct KeyDecodingVisitor: DecodingStringVisitor {
        public typealias DecodedValue = Int
        
        public init() {}
        
        public func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> Int {
            // Try to parse directly from UTF8 bytes for efficiency
            let bytes = buffer.span
            guard bytes.count > 0 else {
                throw CodingError.dataCorrupted(debugDescription: "Empty string cannot be converted to Int key")
            }
            
            var result = 0
            var isNegative = false
            var startIndex = 0
            
            // Check for negative sign
            if bytes[startIndex] == UInt8(ascii: "-") {
                isNegative = true
                startIndex &+= 1
                guard startIndex < bytes.count else {
                    throw CodingError.dataCorrupted(debugDescription: "String '-' cannot be converted to Int key")
                }
            } else if bytes[startIndex] == UInt8(ascii: "+") {
                startIndex &+= 1
                guard startIndex < bytes.count else {
                    throw CodingError.dataCorrupted(debugDescription: "String '+' cannot be converted to Int key")
                }
            }
            
            // Parse digits
            for i in startIndex..<bytes.count {
                let byte = bytes[i]
                guard byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9") else {
                    throw CodingError.dataCorrupted(debugDescription: "String with non-digit character cannot be converted to Int key")
                }
                
                let digit = Int(byte - UInt8(ascii: "0"))
                let (newResult, overflow) = result.multipliedReportingOverflow(by: 10)
                guard !overflow else {
                    throw CodingError.dataCorrupted(debugDescription: "Integer overflow when converting string to Int key")
                }
                
                let (finalResult, addOverflow) = newResult.addingReportingOverflow(digit)
                guard !addOverflow else {
                    throw CodingError.dataCorrupted(debugDescription: "Integer overflow when converting string to Int key")
                }
                
                result = finalResult
            }
            
            return isNegative ? -result : result
        }
        
        public func visitString(_ string: String) throws(CodingError.Decoding) -> Int {
            // Fallback to standard parsing for String case
            guard let intValue = Int(string) else {
                throw CodingError.dataCorrupted(debugDescription: "String '\(string)' cannot be converted to Int key")
            }
            return intValue
        }
    }
    
    public static var codingStringKeyVisitor: KeyDecodingVisitor {
        KeyDecodingVisitor()
    }
    
    public func withCodingStringUTF8Span<R, E>(_ body: (UTF8Span) throws(E) -> R) throws(E) -> R {
        try self.withDecimalDescriptionUTF8Span(body)
    }
}

extension String {
    public struct Visitor: DecodingStringVisitor {
        public typealias DecodedValue = String
        
        public func visitString(_ string: String) throws(CodingError.Decoding) -> DecodedValue {
            return string
        }
        
        public func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> String {
            String(copying: buffer)
        }
    }
}

extension Bool {
    @frozen
    @usableFromInline
    struct Visitor: DecodingBoolVisitor {
        @usableFromInline
        typealias DecodedValue = Bool
        
        @_alwaysEmitIntoClient
        @inline(__always)
        func visit(_ bool: Bool) throws(CodingError.Decoding) -> Bool { bool }
        
        @_alwaysEmitIntoClient
        @inline(__always)
        init(){}
    }
}

struct IntegerVisitor<DecodedValue: FixedWidthInteger>: DecodingNumberVisitor {
    @inline(__always) func visit(_ integer: DecodedValue) throws(CodingError.Decoding) -> DecodedValue { integer }
    @inline(__always) func visit(_ integer: Int64) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: Int128) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: UInt64) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: UInt128) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ float: Float) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: float) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ double: Double) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: double) else {
            fatalError("TODO: Error")
        }
        return exact
    }
}

struct FloatingPointVisitor<DecodedValue: BinaryFloatingPoint>: DecodingNumberVisitor {
    @inline(__always) func visit(_ fp: DecodedValue) throws(CodingError.Decoding) -> DecodedValue { fp }
    @inline(__always) func visit(_ integer: Int64) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: Int128) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: UInt64) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ integer: UInt128) throws(CodingError.Decoding) -> DecodedValue {
        guard let exact = DecodedValue(exactly: integer) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ float: Float) throws(CodingError.Decoding) -> DecodedValue {
        if float.isNaN { return .nan }
        
        guard let exact = DecodedValue(exactly: float) else {
            fatalError("TODO: Error")
        }
        return exact
    }
    @inline(__always) func visit(_ double: Double) throws(CodingError.Decoding) -> DecodedValue {
        if double.isNaN { return .nan }
        
        guard let exact = DecodedValue(exactly: double) else {
            fatalError("TODO: Error")
        }
        return exact
    }
}

extension BinaryInteger {
    
    // Copied from EmbeddedSwift's version of `.description` and simplified down for Base 10 only.
    // TODO: "public" only as a proxy for a similar API the stdlib hopefully exposes. This needs to be used by Twitter's IntString for full coverage.
    @inlinable
    @inline(never)
    public func withDecimalDescriptionSpan<T, E>(_ closure: (Span<UInt8>) throws(E) -> T) throws(E) -> T {
        if self == (0 as Self) {
            let array: InlineArray<1, UInt8> = [UInt8(("0" as Unicode.Scalar).value)]
            return try closure(array.span)
        }
        
        // TODO: Remove awkward workaround for lack of typed-throws on withUnsafeTemporaryAllocation.
        do {
            return try withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 40) { buffer in
                func _ascii(_ digit: UInt8) -> UTF8.CodeUnit {
                    UInt8(("0" as Unicode.Scalar).value) + digit
                }
                let isNegative = Self.isSigned && self < (0 as Self)
                var value = magnitude
                
                var index = buffer.count&-1
                while value != 0 {
                    let (quotient, remainder) = value.quotientAndRemainder(dividingBy: 10)
                    buffer[index] = _ascii(UInt8(truncatingIfNeeded: remainder))
                    index -= 1
                    value = quotient
                }
                if isNegative {
                    buffer[index] = UInt8(("-" as Unicode.Scalar).value)
                    index -= 1
                }
                let length = buffer.count &- (index &+ 1)
                
                return try closure(buffer.span.extracting(last: length))
            }
        } catch let error as E {
            throw error
        } catch { fatalError() }

    }
    
    public func withDecimalDescriptionUTF8Span<T, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        try withDecimalDescriptionSpan { (rawSpan) throws(E) -> T in
            try closure(UTF8Span(unchecked: rawSpan, isKnownASCII: true))
        }
    }
    
}

// TODO: Adopt UniqueArray publicly.
public struct CodingPath: Sendable {
    public var components: [Component]
    
    public init(_ components: [Component]) {
        self.components = components
    }
}

extension CodingPath: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        components.reduce(into: "") {
            $0.append($1.pathDescription(asFirst: $0.isEmpty))
        }
    }
    
    public var debugDescription: String {
        description
    }
}

extension CodingPath {
    public enum Component: Sendable {
        case stringKey(String)
        case integerKey(Int)
        case index(Int)
    }
}

extension CodingPath {
    public func appending(_ key: String) -> CodingPath {
        .init(self.components + [.stringKey(key)])
    }
    public func appending(index: Int) -> CodingPath {
        .init(self.components + [.index(index)])
    }
    @usableFromInline
    internal mutating func replaceLast(with key: String) {
        self.components = self.components.dropLast() + [.stringKey(key)]
    }
    @usableFromInline
    internal mutating func replaceLast(withIndex idx: Int) {
        self.components = self.components.dropLast() + [.index(idx)]
    }
    @usableFromInline
    internal mutating func incrementLast() {
        guard case let .index(idx) = components.last else {
            fatalError("Wrong coding path component type")
        }
        self.components = self.components.dropLast() + [.index(idx + 1)]
    }
}

extension CodingPath.Component: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .stringKey(let string): string
        case .integerKey(let integer): integer.description
        case .index(let integer): "Index \(integer)"
        }
    }
    
    public var debugDescription: String {
        description
    }
}

extension CodingPath.Component {
    internal func pathDescription(asFirst: Bool) -> String {
        switch self {
        case .stringKey(let string): (asFirst ? "" : ".") + string
        case .integerKey(let integer): (asFirst ? "" : ".") + integer.description
        case .index(let index): "[\(index)]"
        }
    }
}
extension CodingPath {
    /// Converts the coding path components to an array of `CodingKey` values
    /// for use with traditional `Decoder` APIs.
    public func toCodingKeys() -> [any CodingKey] {
        components.map { component in
            switch component {
            case .stringKey(let string):
                return _StringCodingKey(stringValue: string)
            case .integerKey(let integer):
                return _IntCodingKey(intValue: integer)
            case .index(let index):
                return _IntCodingKey(intValue: index)
            }
        }
    }
}

/// A simple `CodingKey` implementation for string keys.
private struct _StringCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    
    init(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        return nil
    }
}

/// A simple `CodingKey` implementation for integer keys/indices.
private struct _IntCodingKey: CodingKey {
    let _intValue: Int
    var stringValue: String { "\(_intValue)" }
    var intValue: Int? { _intValue }
    
    init(intValue: Int) {
        self._intValue = intValue
    }
    
    init?(stringValue: String) {
        guard let intValue = Int(stringValue) else {
            return nil
        }
        self._intValue = intValue
    }
}

protocol JSONByteIterator: ~Copyable, ~Escapable {
    mutating func nextByte() throws(JSONError) -> UInt8?
    mutating func finish() throws(JSONError)
}

/**
 Padding character used when the number of bytes to encode is not divisible by 3
 */
private let base64Padding : UInt8 = 61 // =

// This table maps byte values 0-127, input bytes >127 are always invalid.
// Map the ASCII characters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" -> 0...63
// Map '=' (ASCII 61) to 0x40.
// All other values map to 0x7f. This allows '=' and invalid bytes to be checked together by testing bit 6 (0x40).
private let base64Decode: StaticString = """
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{3e}\u{7f}\u{7f}\u{7f}\u{3f}\
\u{34}\u{35}\u{36}\u{37}\u{38}\u{39}\u{3a}\u{3b}\u{3c}\u{3d}\u{7f}\u{7f}\u{7f}\u{40}\u{7f}\u{7f}\
\u{7f}\u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\u{08}\u{09}\u{0a}\u{0b}\u{0c}\u{0d}\u{0e}\
\u{0f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}\u{20}\u{21}\u{22}\u{23}\u{24}\u{25}\u{26}\u{27}\u{28}\
\u{29}\u{2a}\u{2b}\u{2c}\u{2d}\u{2e}\u{2f}\u{30}\u{31}\u{32}\u{33}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}
"""

internal
struct JSONBase64ByteIterator<B64ByteIterator: JSONByteIterator & ~Copyable & ~Escapable>: DecodingBytesIterator, ~Copyable, ~Escapable {
    var iterator: B64ByteIterator

    var currentByte: UInt8 = 0
    var validCharacterCount = 0
    var paddingCount = 0
    var index = 0
    var foundCloseQuote = false

    @_lifetime(copy iterator)
    init(iterator: consuming B64ByteIterator) {
        self.iterator = iterator
    }

    @_lifetime(self: copy self)
    mutating func finish() throws(JSONError) {
        // TODO: This check presumes that the client has already processed all the bytes. What is the right thing to do if they don't?
        guard (validCharacterCount + paddingCount) % 4 == 0 else {
            // Invalid character count of valid input characters.
            fatalError("Incorrect number of input bytes")
        }
        try iterator.finish()
    }

    @_lifetime(self: copy self)
    mutating func processByte(_ base64Char: UInt8) throws(CodingError.Decoding) -> UInt8? {
        var value: UInt8 = 0

        if base64Char >= base64Decode.utf8CodeUnitCount {
            fatalError("Invalid base64 character: \(base64Char)")
        } else {
            value = base64Decode.utf8Start[Int(base64Char)]
            if value & 0x40 == 0x40 {       // Input byte is either '=' or an invalid value.
                if value == 0x7f {
                    fatalError("Invalid base64 character: \(base64Char)")
                } else if value == 0x40 {   // '=' padding at end of input.
                    paddingCount += 1
                    return nil
                }
            }
        }

        validCharacterCount += 1

        // Padding found in the middle of the sequence is invalid.
        if paddingCount > 0 {
            fatalError("Invalid bas64. Padding not at end of input.")
        }

        switch index {
        case 0:
            currentByte = (value << 2)
            index = 1
            return nil
        case 1:
            let byteToReturn = currentByte | (value >> 4)
            currentByte = (value << 4)
            index = 2
            return byteToReturn
        case 2:
            let byteToReturn = currentByte | (value >> 2)
            currentByte = (value << 6)
            index = 3
            return byteToReturn
        case 3:
            let byteToReturn = currentByte | value
            index = 0
            return byteToReturn
        default:
            fatalError("Invalid state")
        }
    }

    @usableFromInline
    mutating func next() throws(CodingError.Decoding) -> UInt8? {
        do {
            while true {
                guard let nextChar = try iterator.nextByte() else {
                    return nil
                }
                if let outputByte = try self.processByte(nextChar) {
                    return outputByte
                }
            }
        } catch {
            fatalError("TODO: I don't know how to implement this conversion.")
        }
    }
}
