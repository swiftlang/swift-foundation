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


/// A type that can encode itself into an external representation based on "common" data types.
public protocol CommonEncodable: ~Copyable {
    /// Encodes this value into the given encoder.
    ///
    // TODO: Make sure this is true for the existing encoders.
    /// If the value does not actually encode anything, `encoder` will encode an empty
    /// dictionary in its place.
    ///
    /// This function throws(CodingError.Encoding) an error if any values are invalid for the given
    /// encoder's format.
    ///
    /// - Parameter encoder: The encoder to write data to.
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding)
}

public protocol CommonEncodableWithContext: ~Copyable {
    associatedtype CommonEncodingContext: ~Copyable & ~Escapable
    @_lifetime(encoder: copy encoder)
    func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable, context: inout CommonEncodingContext) throws(CodingError.Encoding)
}

// Convenience for Copyable contexts - allows static member syntax
extension CommonEncodableWithContext where Self: ~Copyable, CommonEncodingContext: Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(encoder: copy encoder)
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable, context: CommonEncodingContext) throws(CodingError.Encoding) {
        var mutableContext = context
        try self.encode(to: &encoder, context: &mutableContext)
    }
}

/// A type that can encode values based on "common" data types into a native format
/// for external representation.
public protocol CommonEncoder: ~Copyable, ~Escapable {
    
    /// The concrete type used by this encoder to encode array values.
    associatedtype ArrayEncoder: CommonArrayEncoder & ~Copyable & ~Escapable
    
    /// The concrete type used by this encoder to encode dictionary values.
    associatedtype DictionaryEncoder: CommonDictionaryEncoder & ~Copyable & ~Escapable
    
    /// The concrete type used by this encoder to encode struct values.
    associatedtype StructEncoder: CommonStructEncoder & ~Copyable & ~Escapable
    
    // TODO: This overload is a workaround for the inability for encoders to dynamically cast to particular Copyable types. It has a default implementation that calls into the normal ~Copyable path.
    @_lifetime(self: copy self)
    mutating func encode<T: CommonEncodable>(_ value: borrowing T) throws(CodingError.Encoding)
    
    /// Encodes a nil value.
    ///
    /// - throws: TBD
    mutating func encodeNil() throws(CodingError.Encoding)
    
    /// Encodes a boolean value.
    ///
    /// - parameter value: The boolean to encode.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encode(_ bool: Bool) throws(CodingError.Encoding)
    
    /// Encodes a integer value.
    ///
    /// - parameter value: The integer to encode.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int) throws(CodingError.Encoding)
    
    // TODO: etc.
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int8) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int16) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int32) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int64) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int128) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt8) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt16) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt32) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt64) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt128) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Float) throws(CodingError.Encoding)
    @_lifetime(self: copy self)
    mutating func encode(_ value: Double) throws(CodingError.Encoding)
    
    /// Encodes a string value.
    ///
    /// The default implementation calls `encode(_:UTF8Span)`.
    ///
    /// - parameter string: The string to encode..
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeString(_ string: String) throws(CodingError.Encoding)
    
    /// Encodes `UTF8Span` as a string.
    ///
    /// - parameter span: The span to encode.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeString(_ span: UTF8Span) throws(CodingError.Encoding)
    
    /// Encodes an sequence of `UInt8`s as bytes, in whatever representation
    /// is best for the format implemented by the encoder.
    ///
    /// This function has a default implementation that calls `encodeArray` and then calls
    /// `ArrayEncoder.encode()`inside the closure for each element in the sequence.
    ///
    /// - parameter bytes: The sequence of bytes to encode.
    /// - parameter byteCount: A hint indicating the exact number of bytes
    /// in the sequence. A non-nil value should always be passed if and only if the exact number
    /// is known. Some serialization formats encode this in advance of a byte sequence,
    /// so providing an incorrect value may result in undefined behavior, including potential
    /// data corruption in the resulting payload. Providing no value may result in the data
    /// being copied first before encoding.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeBytes(_ bytes: some Sequence<UInt8>, count: Int?) throws(CodingError.Encoding)
    
    /// Encodes a `RawSpan`as bytes, in whatever representation
    /// is best for the format implemented by the encoder.
    ///
    /// - parameter span: The span of bytes to encode..
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeBytes(_ span: RawSpan) throws(CodingError.Encoding)
    
    /// Encodes a struct's fields.
    ///
    /// - parameter count: A hint indicating the exact number of struct fields that will be
    /// encoded. A non-nil value should always be passed if and only if the exact number is
    /// known. Some serialization formats encode this in advance of the struct contents, so
    /// providing an incorrect value may result in undefined behavior, including potential data
    /// corruption in the resulting payload. Providing no value may result in the struct values copied first before encoding.
    /// - parameter closure: A closure in which the struct's fields are encoded.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeStructFields(count: Int?, _ closure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)

    /// Encodes a dictionary of keys and values.
    ///
    /// Because encoders are encouraged to serialize values immediately, the order in which
    /// dictionary key-value pairs is important and will often have a direct impact on the resulting
    /// encoded data. For example, if you desire a particular ordering of keys in the output, the
    /// closure passed to this function should encode the key-value pairs in that order.
    ///
    /// - parameter elementCount: A hint indicating the exact number of key-value
    /// pairs in the dictionary. A non-nil value should always be passed if and only if the exact
    /// number is known. Some serialization formats encode this in advance of the dictionary
    /// contents, so providing an incorrect value may result in undefined behavior, including
    /// potential data corruption in the resulting payload. Providing no value may result in the
    /// dictionary contents being copied first before encoding.
    /// - parameter closure: A closure in which the dictionary's contents are encoded.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeDictionary(elementCount: Int?, _ closure: (inout DictionaryEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    /// Encodes a dictionary of keys and values.
    ///
    /// The default implementation calls `self.encodeDictionary` with the dictionary's
    /// element cout and encodes key-value pairs in an unpredicable order.
    ///
    /// - parameter dictionary: The dictionary to encode
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeDictionary<Key: CodingStringKeyRepresentable, Value: CommonEncodable>(_ dictionary: [Key:Value]) throws(CodingError.Encoding)
        
    /// Encodes an array of values.
    ///
    /// - parameter elementCount: A hint indicating the exact number of elements
    /// in the array. A non-nil value should always be passed if and only if the exact number
    /// is known. Some serialization formats encode this in advance of the array contents,
    /// so providing an incorrect value may result in undefined behavior, including potential
    /// data corruption in the resulting payload. Providing no value may result in the array
    /// contents being copied first before encoding.
    /// - parameter closure: A closure in which the array's contents are encoded in
    /// order.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeArray(elementCount: Int?, _ closure: (inout ArrayEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    /// Encodes an array of values.
    ///
    /// - parameter elementCount: A hint indicating the exact number of elements
    /// in the array. A non-nil value should always be passed if and only if the exact number
    /// is known. Some serialization formats encode this in advance of the array contents,
    /// so providing an incorrect value may result in undefined behavior, including potential
    /// data corruption in the resulting payload. Providing no value may result in the array
    /// contents being copied first before encoding.
    /// - parameter closure: A closure in which the array's contents are encoded in
    /// order.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeArray<Element: CommonEncodable>(_ array: [Element]) throws(CodingError.Encoding)
    
    /// Encodes an enum case with no associated values.
    ///
    /// This function has an inlinable default implementation that calls through to
    /// `encodeEnumCase(field.key)`. This is more convenient for the caller and
    /// also enables the optimizer to eliminate the `switch` statement that usually exists
    /// inside the `EncodingField.key` property's implementation.
    ///
    /// This is typically used for `enum` types that are not `RawRepresentable`,
    /// but also have no associated values. The standardized representation of these
    /// is dictionary whose key identifies the case, and whose value is an empty dictionary.
    ///
    /// - parameter name: The name of the enum case.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ field: some EncodingField) throws(CodingError.Encoding)
    
    /// Encodes an enum case with no associated values.
    ///
    /// This is typically used for `enum` types that are not `RawRepresentable`,
    /// but also have no associated values. The standardized representation of these
    /// is dictionary whose key identifies the case, and whose value is an empty dictionary.
    ///
    /// Some serialization formats do not encode string-based names for enums, so calling this
    /// function directly is typically discouraged without some knowledge about what serialization
    /// format is being used.
    ///
    /// - parameter name: The name of the enum case.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: UTF8Span) throws(CodingError.Encoding)
        
    /// Encodes an enum case with associated values.
    ///
    /// This function has an inlinable default implementation that calls through to the variant
    /// of this function that takes a `String`, passing `EncodingField.key`.
    /// This is more convenient for the caller and also enables the optimizer to eliminate the
    /// `switch` statement that usually exists inside the `EncodingField.key` property's
    /// implementation.
    ///
    /// This is typically used for `enum` types that have associated values.
    /// The standardized representation of these is a struct whose field identifies the case,
    /// and whose value is a struct containing the associated values. If the serialization format
    /// uses strings, the associated are values keyed by label names, if any or `"_0"`, `"_1"`,
    /// etc. for any values that have no explicit label.
    ///
    /// - parameter field: The field of the enum case.
    /// - parameter associatedValueCount: The number of associated values
    /// that will be encoded. Some serialization formats encode this in advance of the struct
    /// contents; providing an incorrect value may result in undefined behavior, including potential
    /// data corruption in the resulting payload.
    /// - parameter closure: A closure in which the associated values are encoded in order.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ field: some EncodingField, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    /// Encodes an enum case with associated values.
    ///
    /// This is typically used for `enum` types that have associated values.
    /// The standardized representation of these is a struct whose key identifies the case,
    /// and whose value is a struct containing the associated values. If the serialization format
    /// uses strings, the associated are values keyed by label names, if any or `"_0"`, `"_1"`,
    /// etc. for any values that have no explicit label.
    ///
    /// Some serialization formats do not encode string-based names for enums or, so calling this
    /// function directly is typically discouraged without some knowledge about what serialization
    /// format is being used.
    ///
    /// - parameter name: The name of the enum case.
    /// - parameter associatedValueCount: The number of associated values
    /// that will be encoded. Some serialization formats encode this in advance of the struct
    /// contents; providing an incorrect value may result in undefined behavior, including potential
    /// data corruption in the resulting payload.
    /// - parameter closure: A closure in which the associated values are encoded in order.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: UTF8Span, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
        
    @_disfavoredOverload
    @_lifetime(self: copy self)
    mutating func encode(_ value: some Encodable) throws(CodingError.Encoding)
}

public extension CommonEncoder where Self: ~Copyable & ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeBytes(_ bytes: some Sequence<UInt8>, count: Int?) throws(CodingError.Encoding) {
        try encodeArray(elementCount: count) { arrayEncoder throws(CodingError.Encoding) in
            for byte in bytes {
                try arrayEncoder.encode(byte)
            }
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeDictionary<Key: CodingStringKeyRepresentable, Value: CommonEncodable>(_ dictionary: [Key:Value]) throws(CodingError.Encoding) {
        try encodeDictionary(elementCount: dictionary.count) { dictEncoder throws(CodingError.Encoding) in
            for (key, value) in dictionary {
                try key.withCodingStringUTF8Span { keySpan throws(CodingError.Encoding) in
                    try dictEncoder.encode(key: keySpan, value: value)
                }
            }
        }
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeArray<Element: CommonEncodable>(_ array: [Element]) throws(CodingError.Encoding) {
        try encodeArray(elementCount: array.count) { arrayEncoder throws(CodingError.Encoding) in
            for element in array {
                try arrayEncoder.encode(element)
            }
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ field: some EncodingField) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encodeEnumCase(span)
        }
    }
    
    @_disfavoredOverload
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: String) throws(CodingError.Encoding) {
        // TODO: watchOS 32-bit
        try self.encodeEnumCase(name.utf8Span)
    }

    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: StaticString) throws(CodingError.Encoding) {
        if name.hasPointerRepresentation {
            let utf8Span = UTF8Span(unchecked: .init(_unsafeStart: name.utf8Start, count: name.utf8CodeUnitCount), isKnownASCII: false)
            try self.encodeEnumCase(utf8Span)
        } else {
#if $Embedded
            fatalError("non-pointer representation not supported in embedded Swift")
#else
            // TODO: More efficient without allocations.
            try self.encodeEnumCase(String(name.unicodeScalar).utf8Span)
#endif
        }
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ field: some EncodingField, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encodeEnumCase(span, associatedValueCount: associatedValueCount, associatedValueClosure)
        }
    }
    
    @_disfavoredOverload
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: String, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        // TODO: watchOS 32-bit
        try self.encodeEnumCase(name.utf8Span, associatedValueCount: associatedValueCount, associatedValueClosure)
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: StaticString, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        if name.hasPointerRepresentation {
            let utf8Span = UTF8Span(unchecked: .init(_unsafeStart: name.utf8Start, count: name.utf8CodeUnitCount), isKnownASCII: false)
            try self.encodeEnumCase(utf8Span, associatedValueCount: associatedValueCount, associatedValueClosure)
        } else {
#if $Embedded
            fatalError("non-pointer representation not supported in embedded Swift")
#else
            // TODO: More efficient without allocations.
            try self.encodeEnumCase(String(name.unicodeScalar).utf8Span, associatedValueCount: associatedValueCount, associatedValueClosure)
#endif
        }
    }
}

extension CommonEncoder where Self: ~Copyable & ~Escapable {
    /// Convenience: encode a JSONEncodable value using its default implementation.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try value.encode(to: &self)
    }
    
    // Copyable overload by default calls back into the ~Copyable one. See above.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try value.encode(to: &self)
    }
    
    /// Convenience: encode using an explicit context (inout version for stateful contexts).
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodableWithContext & ~Copyable>(_ value: borrowing T, context: inout T.CommonEncodingContext) throws(CodingError.Encoding) {
        try value.encode(to: &self, context: &context)
    }
    
    /// Convenience: encode using an explicit context (copyable version for static member syntax).
    /// This enables clean syntax: `encoder.encode(date, context: .iso8601)`
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodableWithContext & ~Copyable>(_ value: borrowing T, context: T.CommonEncodingContext) throws(CodingError.Encoding) where T.CommonEncodingContext: Copyable {
        try value.encode(to: &self, context: context)
    }
}

/// A type that can encode a string-based dictionary based on "common"
/// data types into a native format for external representation.
public protocol CommonDictionaryEncoder: ~Copyable, ~Escapable {
    associatedtype KeyEncoder: CommonEncoder & ~Copyable & ~Escapable
    associatedtype ValueEncoder: CommonEncoder & ~Copyable & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func encodeKey(keyEncoder: (inout KeyEncoder) throws(CodingError.Encoding) -> Void, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    @_lifetime(self: copy self)
    mutating func encode(key: String, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    @_lifetime(self: copy self)
    mutating func encode(key: UTF8Span, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
}

public extension CommonDictionaryEncoder where Self: ~Copyable & ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, valueEncoder: valueEncoder)
    }

    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: UTF8Span, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: some Encodable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
}

/// A type that can encode a struct type based on "common" data types into a native format for
/// external representation.
public protocol CommonStructEncoder: ~Copyable, ~Escapable {
    associatedtype ValueEncoder: CommonEncoder & ~Copyable & ~Escapable
    
    @_lifetime(self: copy self)
    mutating func encode(field: some EncodingField, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    @_lifetime(self: copy self)
    mutating func encode(key: String, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    @_lifetime(self: copy self)
    mutating func encode(key: UTF8Span, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
}

public extension CommonStructEncoder where Self: ~Copyable & ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, valueEncoder: valueEncoder)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(field: some EncodingField, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span, valueEncoder: valueEncoder)
        }
    }

    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(field: some EncodingField, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
        }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: UTF8Span, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(field: some EncodingField, value: some Encodable) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
        }
    }
    
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: some Encodable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
}

// To avoid duplicate implementations for types that conform to both.
public extension CommonStructEncoder where Self: CommonDictionaryEncoder & ~Copyable & ~Escapable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, valueEncoder: (inout ValueEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) {
        try self.encode(key: key.utf8Span, valueEncoder: valueEncoder)
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: UTF8Span, value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(field: some EncodingField, value: some Encodable) throws(CodingError.Encoding) {
        try field.withUTF8Span { span throws(CodingError.Encoding) in
            try self.encode(key: span) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
        }
    }
    
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    mutating func encode(key: String, value: some Encodable) throws(CodingError.Encoding) {
        try self.encode(key: key) { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
}

/// A type that can encode an array based on "common" data types into
/// a native format for external representation.
public protocol CommonArrayEncoder: ~Copyable, ~Escapable {
    associatedtype ElementEncoder: CommonEncoder & ~Copyable & ~Escapable
    
    /// Encodes an array element.
    ///
    /// - parameter element: The element to encode.
    /// - throws: TBD
    @_lifetime(self: copy self)
    mutating func encodeElement(_ elementEncoder: (inout ElementEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding)
    
    var codingPath: CodingPath { get }
}

extension CommonArrayEncoder where Self: ~Copyable & ~Escapable {
    /// Convenience: encode a CommonEncodable value.
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: CommonEncodable & ~Copyable>(_ value: borrowing T) throws(CodingError.Encoding) {
        try self.encodeElement { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
    
    /// Convenience: encode an Encodable value.
    @_disfavoredOverload
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(self: copy self)
    public mutating func encode<T: Encodable>(_ value: T) throws(CodingError.Encoding) {
        try self.encodeElement { encoder throws(CodingError.Encoding) in try encoder.encode(value) }
    }
}


// Fall back error implementations:
public extension CommonEncoder where Self: ~Copyable & ~Escapable {
    @_lifetime(self: copy self)
    mutating func encodeNil() throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("nil") }
    @_lifetime(self: copy self)
    mutating func encode(_ bool: Bool) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("boolean") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int8) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int8") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int16) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int16") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int32) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int32") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int64) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int64") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Int128) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Int128") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt8) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt8") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt16) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt16") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt32) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt32") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt64) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt64") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: UInt128) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("UInt128") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Float) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Float") }
    @_lifetime(self: copy self)
    mutating func encode(_ value: Double) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Double") }
    @_lifetime(self: copy self)
    mutating func encodeString(_ string: String) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("string") }
    @_lifetime(self: copy self)
    mutating func encodeString(_ span: UTF8Span) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("string (UTF8Span)") }
    @_lifetime(self: copy self)
    mutating func encodeBytes(_ span: RawSpan) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("bytes") }
    @_lifetime(self: copy self)
    mutating func encodeStructFields(count: Int?, _ closure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) -> Void { throw CodingError.unsupportedEncodingType("struct") }
    @_lifetime(self: copy self)
    mutating func encodeDictionary(elementCount: Int?, _ closure: (inout DictionaryEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) -> Void { throw CodingError.unsupportedEncodingType("dictionary") }
    @_lifetime(self: copy self)
    mutating func encodeArray(elementCount: Int?, _ closure: (inout ArrayEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) -> Void { throw CodingError.unsupportedEncodingType("array") }
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: UTF8Span) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("enum") }
    @_lifetime(self: copy self)
    mutating func encodeEnumCase(_ name: UTF8Span, associatedValueCount: Int, _ associatedValueClosure: (inout StructEncoder) throws(CodingError.Encoding) -> Void) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("enum") }
    @_disfavoredOverload
    @_lifetime(self: copy self)
    mutating func encode(_ value: some Encodable) throws(CodingError.Encoding) { throw CodingError.unsupportedEncodingType("Encodable") }
}
