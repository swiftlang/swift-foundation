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

/// A type that provides context relevant for both the overall decoding operation, as well as the
/// decoding of a specific value.
public struct AdaptorDecodableValueContext<Value: AdaptableDecodableValue> {
    
    /// The decoder-specific context info, including the `userInfo`.
    public var decoderContext: Value.DecoderContext { _decoder.decoderContext }
    
    internal let _decoder: AdaptorDecoder<Value>
    internal let partialCodingPath: [any CodingKey]
    internal let currentCodingKey: (any CodingKey)?
    
    /// The coding path identifying a specific value being decoded.
    public var codingPath: [any CodingKey] {
        _decoder.codingPath + partialCodingPath + (currentCodingKey.map{[$0]} ?? [])
    }
    
    private func decoder(forValue value: Value) -> AdaptorDecoder<Value> {
        if let takenDecoder = _decoder.sharedSubDecoder {
            _decoder.sharedSubDecoder = nil
            takenDecoder.codingKey = currentCodingKey
            takenDecoder.ownerDecoder = _decoder
            takenDecoder.value = value
            return takenDecoder
        }
        return AdaptorDecoder<Value>(value: value, decoderContext: _decoder.decoderContext, ownerDecoder: _decoder, codingKey: currentCodingKey)
    }
    
    private func returnDecoder(_ decoder: inout AdaptorDecoder<Value>) {
        if decoder !== _decoder, _decoder.sharedSubDecoder == nil, isKnownUniquelyReferenced(&decoder) {
            decoder.codingKey = nil
            decoder.ownerDecoder = nil // Prevent retain cycle.
            _decoder.sharedSubDecoder = decoder
        }
    }
    
    /// Creates a sub-decoder for a given value and passes it to the `work` closure, which
    /// decodes a `Decodable` type.
    ///
    /// Every `Value` needs its own `DecodableAdapator`. Using function can reduce redundant
    /// allocations and deallocations of these objects by reusing prior instances that are no longer being
    /// used. It also automatically ensures that the resulting `Decoder` will have the correct
    /// `decoderContext` and `codingPath`.
    public func withDecoder<Result, E: Error>(for value: Value, perform work: (AdaptorDecoder<Value>) throws(E) -> Result) throws (E) -> Result {
        var decoder = self.decoder(forValue: value)
        defer {
            returnDecoder(&decoder)
        }
        
        return try work(decoder)
    }
}

/// An abstract data type that can be used to implement a generic `Decoder`, and is often
/// employed to facilitate compatibility between a serialization format-specific decoding protocol
/// and traditional `Decodable` types.
public protocol AdaptableDecodableValue {
    
    /// The decoder-global context type used during decoding of this value.
    associatedtype DecoderContext: AdaptorDecoderContext = [CodingUserInfoKey:Any]
    
    /// The iterator type used for enumerating contents of an array that contains more values of
    /// `Self`.
    associatedtype ArrayIterator: IteratorProtocol<Self>
    
    /// If `self` describes a nil value, returns `true`, otherwise returns `false`.
    func decodeNil(context: AdaptorDecodableValueContext<Self>) -> Bool
    
    /// If `self` describes a boolean value, returns that value.
    /// - parameter context: Provides decoder-specific context.
    /// - throws: Error TBD if `self` does not describe a boolean value, or another decoding
    /// error occurs
    func decode(_ type: Bool.Type, context: AdaptorDecodableValueContext<Self>) throws -> Bool
    
    // TODO: Et cetera.
    func decode(_ type: Int.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int
    func decode(_ type: Int8.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int8
    func decode(_ type: Int16.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int16
    func decode(_ type: Int32.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int32
    func decode(_ type: Int64.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int64
    func decode(_ type: Int128.Type, context: AdaptorDecodableValueContext<Self>) throws -> Int128
    func decode(_ type: UInt.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt
    func decode(_ type: UInt8.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt8
    func decode(_ type: UInt16.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt16
    func decode(_ type: UInt32.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt32
    func decode(_ type: UInt64.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt64
    func decode(_ type: UInt128.Type, context: AdaptorDecodableValueContext<Self>) throws -> UInt128
    func decode(_ type: String.Type, context: AdaptorDecodableValueContext<Self>) throws -> String
    func decode(_ type: Double.Type, context: AdaptorDecodableValueContext<Self>) throws -> Double
    func decode(_ type: Float.Type, context: AdaptorDecodableValueContext<Self>) throws -> Float
    func decode<T: Decodable>(_ type: T.Type, context: AdaptorDecodableValueContext<Self>) throws -> T
    
    /// If `self` describes the contents of a String-keyed dictionary, returns a copy of that dictionary.
    /// Otherwise, throws an error.
    func makeDictionary(context: AdaptorDecodableValueContext<Self>) throws -> [String:Self]
    
    /// If `self` describes the contents of an array, returns an iterator for that array as well as a hint
    /// about the number of items in the array, if available.
    func makeArrayIterator(context: AdaptorDecodableValueContext<Self>) throws -> (ArrayIterator, countHint: Int?)
}

/// Decoder-specific contextual information that can be used to modify or inform about
/// a specific instance of decoding. This must include at minimum a `userInfo` dictionary
/// that gets vended to `Decodable` types via a `Decoder`.
public protocol AdaptorDecoderContext {
    
    /// The user info that gets vended to `Decodable` types via a `Decoder` or its
    /// container types.
    var userInfo: [CodingUserInfoKey:Any] { get }

}

// TODO: Put this somewhere better? Can't split up the conformances redclaring the same requirement.
extension [CodingUserInfoKey:Any]: AdaptorDecoderContext, AdaptorEncoderContext {
    public var userInfo: [CodingUserInfoKey : Any] { self }
}

/// A generic `Decoder` that can be used with any specific `AdaptableDecodableValue` to provide
/// basic `Decodable` functionality. This is often used to facilitate compatibility between a
/// format-specialized decoding protocol and tranditional `Decodable` types.
public class AdaptorDecoder<Value: AdaptableDecodableValue>: Decoder {
    var value: Value
    let decoderContext: Value.DecoderContext
    
    var ownerDecoder: AdaptorDecoder<Value>?
    var sharedSubDecoder: AdaptorDecoder<Value>?
    var codingKey: (any CodingKey)?
    var rootCodingPath: [any CodingKey]?
    
    /// Creates a `Decoder` to enable calling `init(from: Decoder)` on a
    /// `Decodable` type, which will attempt to decode from the given `value`.
    /// The `decoderContext` and `codingPath` parameters will influence the
    /// `codingPath` and `userInfo` of the resulting decoder and its sub-decoders.
    public init(value: Value, decoderContext: Value.DecoderContext, codingPath: [any CodingKey]) {
        self.value = value
        self.decoderContext = decoderContext
        self.rootCodingPath = codingPath
    }
    
    internal init(value: Value, decoderContext: Value.DecoderContext, ownerDecoder: AdaptorDecoder<Value>?, codingKey: (any CodingKey)?) {
        self.value = value
        self.decoderContext = decoderContext
        self.ownerDecoder = ownerDecoder
        self.codingKey = codingKey
    }
    
    public var codingPath: [any CodingKey] {
        var result = [any CodingKey]()
        var decoder = self
        if let codingKey {
            result.append(codingKey)
        }

        while let ownerDecoder = decoder.ownerDecoder {
            if let key = ownerDecoder.codingKey {
                result.append(key)
            }
            if let codingPath = ownerDecoder.rootCodingPath {
                result.append(contentsOf: codingPath)
            }
            decoder = ownerDecoder
        }
        
        if let rootCodingPath {
            result.append(contentsOf: rootCodingPath.reversed())
        }

        return result.reversed()
    }
    
    public var userInfo: [CodingUserInfoKey : Any] {
        decoderContext.userInfo
    }
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = try KeyedContainer<Key>(value: self.value, decoder: self, partialCodingPath: [])
        return KeyedDecodingContainer(container)
    }
    
    public func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let container = try UnkeyedContainer(value: self.value, decoder: self, partialCodingPath: [])
        return container
    }
    
    public func singleValueContainer() throws -> any SingleValueDecodingContainer {
        self
    }
}

extension AdaptorDecoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let dict: [String:Value]
        let decoder: AdaptorDecoder<Value>

        let partialCodingPath: [any CodingKey]
        var decoderContext: Value.DecoderContext { decoder.decoderContext }
        
        init(value: Value, decoder: AdaptorDecoder<Value>, partialCodingPath: [any CodingKey]) throws {
            self.dict = try value.makeDictionary(context: .init(_decoder: decoder, partialCodingPath: partialCodingPath, currentCodingKey: nil))
            self.decoder = decoder
            self.partialCodingPath = partialCodingPath
        }
        
        // TODO: CodingPath
        public var codingPath: [any CodingKey] {
            decoder.codingPath + partialCodingPath
        }
        
        public var allKeys: [Key] {
            self.dict.keys.compactMap { Key(stringValue: $0) }
        }
        
        func contains(_ key: Key) -> Bool {
            dict.keys.contains(key.stringValue)
        }
        
        internal func getValue(forKey key: Key) throws -> Value {
            guard let value = dict[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: [], debugDescription: "No value assicated with key \(key) (\"\(key.stringValue)\")"))
            }
            return value
        }
        
        internal func context(for key: Key) -> AdaptorDecodableValueContext<Value> {
            .init(_decoder: self.decoder, partialCodingPath: self.partialCodingPath, currentCodingKey: key)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            try getValue(forKey: key).decodeNil(context: context(for: key))
        }
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            try getValue(forKey: key).decode(type, context: context(for: key))
        }
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let value = try getValue(forKey: key)
            let container = try KeyedContainer<NestedKey>(value: value, decoder: decoder, partialCodingPath: self.partialCodingPath + [key])
            return KeyedDecodingContainer(container)
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            return try UnkeyedContainer(value: value, decoder: decoder, partialCodingPath: self.partialCodingPath + [key])
        }
        
        func superDecoder() throws -> any Decoder {
            fatalError("TODO")
        }
        
        func superDecoder(forKey key: Key) throws -> any Decoder {
            fatalError("TODO")
        }
    }
}

extension AdaptorDecoder {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        var valueIterator: Value.ArrayIterator
        let decoder: AdaptorDecoder<Value>
        let partialCodingPath: [any CodingKey]
        
        var peekedValue: Value?
        let count: Int?

        var isAtEnd: Bool { self.currentIndex >= (self.count!) }
        var currentIndex = 0
        
        var decoderContext: Value.DecoderContext { decoder.decoderContext }

        init(value: Value, decoder: AdaptorDecoder<Value>, partialCodingPath: [any CodingKey]) throws {
            (self.valueIterator, self.count) = try value.makeArrayIterator(context: .init(_decoder: decoder, partialCodingPath: partialCodingPath, currentCodingKey: nil))
            self.decoder = decoder
            self.partialCodingPath = partialCodingPath
        }

        public var codingPath: [CodingKey] {
            self.decoder.codingPath + self.partialCodingPath
        }

        @inline(__always)
        var currentIndexKey : _CodingKey {
            .init(index: currentIndex)
        }

        @inline(__always)
        var currentCodingPath: [CodingKey] {
            self.codingPath + [currentIndexKey]
        }

        private mutating func advanceToNextValue() {
            currentIndex += 1
            peekedValue = nil
        }
        
        var context: AdaptorDecodableValueContext<Value> {
            .init(_decoder: decoder, partialCodingPath: partialCodingPath, currentCodingKey: currentIndexKey)
        }

        mutating func decodeNil() throws -> Bool {
            let value = try self.peekNextValue(ofType: Never.self)
            if value.decodeNil(context: context) {
                advanceToNextValue()
                return true
            } else {
                // The protocol states:
                //   If the value is not null, does not increment currentIndex.
                return false
            }
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_ type: Int128.Type) throws -> Int128 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }
      
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let value = try self.peekNextValue(ofType: type).decode(type, context: context)
            advanceToNextValue()
            return value
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try self.peekNextValue(ofType: KeyedDecodingContainer<NestedKey>.self)
            let container = try KeyedContainer<NestedKey>(value: value, decoder: decoder, partialCodingPath: self.partialCodingPath + [currentIndexKey])

            advanceToNextValue()
            return KeyedDecodingContainer(container)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try self.peekNextValue(ofType: UnkeyedDecodingContainer.self)
            let container = try UnkeyedContainer(value: value, decoder: decoder, partialCodingPath: self.partialCodingPath + [currentIndexKey])
            advanceToNextValue()
            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let decoder = try decoderForNextElement(ofType: Decoder.self)
            advanceToNextValue()
            return decoder
        }

        private mutating func decoderForNextElement<T>(ofType type: T.Type) throws -> AdaptorDecoder<Value> {
            let value = try self.peekNextValue(ofType: type)
            let decoder = AdaptorDecoder(value: value, decoderContext: decoder.decoderContext, ownerDecoder: decoder, codingKey: currentIndexKey)
            return decoder
        }

        @inline(__always)
        private mutating func peekNextValue<T>(ofType type: T.Type) throws -> Value {
            if let value = peekedValue {
                return value
            }
            guard let nextValue = valueIterator.next() else {
                var message = "Unkeyed container is at end."
                if T.self == UnkeyedContainer.self {
                    message = "Cannot get nested unkeyed container -- unkeyed container is at end."
                }
                if T.self == Decoder.self {
                    message = "Cannot get superDecoder() -- unkeyed container is at end."
                }

                var path = self.codingPath
                path.append(_CodingKey(index: self.currentIndex))

                throw DecodingError.valueNotFound(
                    type,
                    .init(codingPath: path,
                          debugDescription: message,
                          underlyingError: nil))
            }
            peekedValue = nextValue
            return nextValue
        }
    }

}

extension AdaptorDecoder: SingleValueDecodingContainer {
    var context: AdaptorDecodableValueContext<Value> {
        .init(_decoder: self, partialCodingPath: [], currentCodingKey: nil)
    }
    
    public func decodeNil() -> Bool { value.decodeNil(context: context) }
    public func decode(_ type: Bool.Type) throws -> Bool { try value.decode(type, context: context) }
    public func decode(_ type: String.Type) throws -> String { try value.decode(type, context: context) }
    public func decode(_ type: Double.Type) throws -> Double { try value.decode(type, context: context) }
    public func decode(_ type: Float.Type) throws -> Float { try value.decode(type, context: context) }
    public func decode(_ type: Int.Type) throws -> Int { try value.decode(type, context: context) }
    public func decode(_ type: Int8.Type) throws -> Int8 { try value.decode(type, context: context) }
    public func decode(_ type: Int16.Type) throws -> Int16 { try value.decode(type, context: context) }
    public func decode(_ type: Int32.Type) throws -> Int32 { try value.decode(type, context: context) }
    public func decode(_ type: Int64.Type) throws -> Int64 { try value.decode(type, context: context) }
    public func decode(_ type: Int128.Type) throws -> Int128 { try value.decode(type, context: context) }
    public func decode(_ type: UInt.Type) throws -> UInt { try value.decode(type, context: context) }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { try value.decode(type, context: context) }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { try value.decode(type, context: context) }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { try value.decode(type, context: context) }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { try value.decode(type, context: context) }
    public func decode(_ type: UInt128.Type) throws -> UInt128 { try value.decode(type, context: context) }
    public func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try value.decode(type, context: context) }
}

