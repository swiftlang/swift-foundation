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


// TBD?
public struct AdaptorEncodableValueContext<Value: AdaptorEncodableValue> {
    
    /// The decoder-specific context info, including the `userInfo`.
    public var encoderContext: Value.EncoderContext { _encoder.encoderContext }
    
    internal let _encoder: AdaptorEncoder<Value>
    internal let partialCodingPath: [any CodingKey]
    internal let currentCodingKey: (any CodingKey)?
    
    /// The coding path identifying a specific value being decoded.
    public var codingPath: [any CodingKey] {
        _encoder.codingPath + partialCodingPath + (currentCodingKey.map{[$0]} ?? [])
    }
    
    /// Creates a sub-decoder for a given value and passes it to the `work` closure, which
    /// decodes a `Decodable` type.
    ///
    /// Every `Value` needs its own `DecodableAdapator`. Using function can reduce redundant
    /// allocations and deallocations of these objects by reusing prior instances that are no longer being
    /// used. It also automatically ensures that the resulting `Decoder` will have the correct
    /// `decoderContext` and `codingPath`.
    public func withEncoder<Result, E: Error>(perform work: (AdaptorEncoder<Value>) throws(E) -> Result) throws (E) -> Result {
        var encoder = _encoder.getEncoder(for: currentCodingKey)
        defer {
            _encoder.returnEncoder(&encoder)
        }
        
        return try work(encoder)
    }
}

/// Encoder-specific contextual information that can be used to modify or inform about
/// a specific instance of encoding. This must include at minimum a `userInfo` dictionary
/// that gets vended to `Encodable` types via a `Encoder`.
public protocol AdaptorEncoderContext {
    
    /// The user info that gets vended to `Encodable` types via a `Encoder` or its
    /// container types.
    var userInfo: [CodingUserInfoKey:Any] { get }

}

/// An abstract data type that can be used to implement a generic `Encoder`, and is often
/// employed to facilitate compatibility between a serialization format-specific encoder protocol
/// and traditional `Encodable` types.
public protocol AdaptorEncodableValue {
    associatedtype EncoderContext: AdaptorEncoderContext
    
    // TODO: Throw for all of these? Pass keys for better error throwing? Or failable?
    static var null: Self { get }
    init(_ value: Bool, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: String, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Double, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Float, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int8, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int16, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int32, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int64, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: Int128, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt8, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt16, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt32, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt64, context: AdaptorEncodableValueContext<Self>) throws
    init(_ value: UInt128, context: AdaptorEncodableValueContext<Self>) throws
    // TODO: Re-evaluate contexts and throws for these.
    init(_ array: [Self])
    init(_ dict: [String:Self])
    init<T: Encodable>(from value: T, context: AdaptorEncodableValueContext<Self>) throws
    
    var array: [Self]? { get }
    var dictionary: [String:Self]? { get }
}

public class AdaptorEncoder<Value: AdaptorEncodableValue>: Encoder {
    typealias Future = AdaptorEncoderFuture<Value>
    
    let encoderContext: Value.EncoderContext
    
    var singleValue: Value?
    var array: Future.RefArray?
    var dict: Future.RefDictionary?

    public var encodedValue: Value {
        if let dict = self.dict {
            return .init(dict.values)
        }
        if let array = self.array {
            return .init(array.values)
        }
        if let singleValue {
            return singleValue
        }
        return .init([:])
    }

    var ownerEncoder: AdaptorEncoder<Value>?
    var sharedSubEncoder: AdaptorEncoder<Value>?
    var codingKey: (any CodingKey)?
    var rootCodingPath: [any CodingKey]?

    /// The path to the current point in encoding.
    public var codingPath: [any CodingKey] {
        var result = [any CodingKey]()
        var encoder = self
        if let codingKey {
            result.append(codingKey)
        }

        while let ownerEncoder = encoder.ownerEncoder,
              let key = ownerEncoder.codingKey {
            result.append(key)
            encoder = ownerEncoder
        }
        
        if let rootCodingPath {
            result.append(contentsOf: rootCodingPath.reversed())
        }

        return result.reversed()
    }
    
    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        encoderContext.userInfo
    }

    // MARK: - Initialization
    
    public init(encoderContext: Value.EncoderContext, codingPath: [any CodingKey]) {
        self.encoderContext = encoderContext
        self.rootCodingPath = codingPath
    }

    internal init(ownerEncoder: AdaptorEncoder<Value>?, encoderContext: Value.EncoderContext, codingKey: (any CodingKey)?) {
        self.encoderContext = encoderContext
        self.ownerEncoder = ownerEncoder
        self.codingKey = codingKey
    }

    // MARK: - Encoder Methods
    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        if let dict {
            let container = KeyedContainer<Key>(referencing: self, wrapping: dict)
            return KeyedEncodingContainer(container)
        }
        if let object = self.singleValue?.convertedToObjectRef() {
            self.singleValue = nil
            self.dict = object

            let container = KeyedContainer<Key>(referencing: self, wrapping: object)
            return KeyedEncodingContainer(container)
        }

        guard self.singleValue == nil, self.array == nil else {
            preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
        }

        let newDict = Future.RefDictionary()
        self.dict = newDict
        let container = KeyedContainer<Key>(referencing: self, wrapping: newDict)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        if let array {
            return UnkeyedContainer(referencing: self, wrapping: array)
        }
        if let array = self.singleValue?.convertedToArrayRef() {
            self.singleValue = nil
            self.array = array

            return UnkeyedContainer(referencing: self, wrapping: array)
        }

        guard self.singleValue == nil, self.dict == nil else {
            preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
        }

        let newArray = Future.RefArray()
        self.array = newArray
        return UnkeyedContainer(referencing: self, wrapping: newArray)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

extension AdaptorEncoder {
    func wrap(_ dict: [String : Encodable], for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Value? {
        var result = [String: Value]()
        result.reserveCapacity(dict.count)

        let encoder = AdaptorEncoder(ownerEncoder: self, encoderContext: self.encoderContext, codingKey: additionalKey)
        for (key, value) in dict {
            encoder.codingKey = _CodingKey(stringValue: key)
            result[key] = try encoder.wrap(value)
        }

        return .init(result)
    }

    func wrap(_ value: Encodable, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Value {
        return try self.wrapGeneric(value, for: additionalKey) ?? .init([:])
    }

    func wrapGeneric<T: Encodable>(_ encodable: T, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Value? {
        return try self.context.withEncoder {
            try Value(from: encodable, context: .init(_encoder: $0, partialCodingPath: [], currentCodingKey: additionalKey))
        }
    }

    @inline(__always)
    func _wrapGeneric(_ encode: (AdaptorEncoder<Value>) throws -> Value, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Value {
        var encoder = getEncoder(for: additionalKey)
        defer {
            returnEncoder(&encoder)
        }
        return try encode(encoder)
    }

    @inline(__always)
    func getEncoder(for additionalKey: CodingKey?) -> AdaptorEncoder<Value> {
        if let additionalKey {
            if let takenEncoder = sharedSubEncoder {
                self.sharedSubEncoder = nil
                takenEncoder.codingKey = additionalKey
                takenEncoder.ownerEncoder = self
                return takenEncoder
            }
            return AdaptorEncoder<Value>(ownerEncoder: self, encoderContext: self.encoderContext, codingKey: additionalKey)
        }

        return self
    }

    // TODO: There's some strangeness with multiple sub-encoders being created for doubles nested in arrays. Figure it out.
    @inline(__always)
    func returnEncoder(_ encoder: inout AdaptorEncoder<Value>) {
        if encoder !== self, sharedSubEncoder == nil, isKnownUniquelyReferenced(&encoder) {
            encoder.codingKey = nil
            encoder.ownerEncoder = nil // Prevent retain cycle.
            encoder.singleValue = nil
            encoder.array = nil
            encoder.dict = nil
            sharedSubEncoder = encoder
        }
    }

}

extension AdaptorEncoder {
    struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        private let encoder: AdaptorEncoder<Value>

        private let reference: AdaptorEncoderFuture<Value>.RefDictionary
        private let partialCodingPath: [any CodingKey]

        /// The path of coding keys taken to get to this point in encoding.
        public var codingPath: [CodingKey] {
            encoder.codingPath + partialCodingPath
        }
        
        internal var context: AdaptorEncodableValueContext<Value> {
            .init(_encoder: self.encoder, partialCodingPath: partialCodingPath, currentCodingKey: nil)
        }

        // MARK: - Initialization

        /// Initializes `self` with the given references.
        init(referencing encoder: AdaptorEncoder<Value>, partialCodingPath: [any CodingKey] = [], wrapping ref: AdaptorEncoderFuture<Value>.RefDictionary) {
            self.encoder = encoder
            self.partialCodingPath = partialCodingPath
            self.reference = ref
        }

        // MARK: - Coding Path Operations

        private func _converted(_ key: CodingKey) -> String {
            key.stringValue
        }

        // MARK: - KeyedEncodingContainerProtocol Methods

        public mutating func encodeNil(forKey key: Key) throws {
            reference.set(.null, for: _converted(key))
        }
        public mutating func encode(_ value: Bool, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: Int, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: Int8, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: Int16, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: Int32, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: Int64, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public mutating func encode(_ value: Int128, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: UInt, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: UInt8, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: UInt16, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: UInt32, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: UInt64, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public mutating func encode(_ value: UInt128, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }
        public mutating func encode(_ value: String, forKey key: Key) throws {
            reference.set(try .init(value, context: context), for: _converted(key))
        }

        public mutating func encode(_ value: Float, forKey key: Key) throws {
            let wrapped = try Value(value, context: context)
            reference.set(wrapped, for: _converted(key))
        }

        public mutating func encode(_ value: Double, forKey key: Key) throws {
            let wrapped = try Value(value, context: context)
            reference.set(wrapped, for: _converted(key))
        }

        public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
            let wrapped = try self.encoder.wrap(value, for: key)
            reference.set(wrapped, for: _converted(key))
        }

        public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
            let containerKey = _converted(key)
            let nestedRef: AdaptorEncoderFuture<Value>.RefDictionary
            if let existingRef = self.reference.dict[containerKey] {
                if let dictionary = existingRef.dictionary {
                    // Was encoded as an object ref previously. We can just use it again.
                    nestedRef = dictionary
                } else if case .value(let value) = existingRef,
                          let convertedObject = value.convertedToObjectRef() {
                    // Was encoded as an object *value* previously. We need to convert it back to a reference before we can use it.
                    nestedRef = convertedObject
                    self.reference.dict[containerKey] = .nestedDictionary(convertedObject)
                } else {
                    preconditionFailure(
                        "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key"
                    )
                }
            } else {
                nestedRef = self.reference.setObject(for: containerKey)
            }

            let nestedCodingPath = self.partialCodingPath + [key]
            let container = KeyedContainer<NestedKey>(referencing: self.encoder, partialCodingPath: nestedCodingPath, wrapping: nestedRef)
            return KeyedEncodingContainer(container)
        }

        public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let containerKey = _converted(key)
            let nestedRef: AdaptorEncoderFuture<Value>.RefArray
            if let existingRef = self.reference.dict[containerKey] {
                if let array = existingRef.array {
                    // Was encoded as an array ref previously. We can just use it again.
                    nestedRef = array
                } else if case .value(let value) = existingRef,
                          let convertedArray = value.convertedToArrayRef() {
                    // Was encoded as an array *value* previously. We need to convert it back to a reference before we can use it.
                    nestedRef = convertedArray
                    self.reference.dict[containerKey] = .nestedArray(convertedArray)
                } else {
                    preconditionFailure(
                        "Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(containerKey)\" is invalid: keyed container/single value already encoded for this key"
                    )
                }
            } else {
                nestedRef = self.reference.setArray(for: containerKey)
            }

            let nestedCodingPath = self.partialCodingPath + [key]
            return UnkeyedContainer(referencing: self.encoder, partialCodingPath: nestedCodingPath, wrapping: nestedRef)
        }

        public mutating func superEncoder() -> Encoder {
            return AdaptorReferencingEncoder(referencing: self.encoder, key: _CodingKey.super, convertedKey: _converted(_CodingKey.super), wrapping: self.reference)
        }

        public mutating func superEncoder(forKey key: Key) -> Encoder {
            return AdaptorReferencingEncoder(referencing: self.encoder, key: key, convertedKey: _converted(key), wrapping: self.reference)
        }

    }
}

extension AdaptorEncoder {
    struct UnkeyedContainer: UnkeyedEncodingContainer {
        /// A reference to the encoder we're writing to.
        private let encoder: AdaptorEncoder<Value>

        private let reference: AdaptorEncoderFuture<Value>.RefArray
        private let partialCodingPath: [any CodingKey]

        /// The path of coding keys taken to get to this point in encoding.
        public var codingPath: [CodingKey] {
            encoder.codingPath + partialCodingPath
        }

        /// The number of elements encoded into the container.
        public var count: Int {
            self.reference.array.count
        }
        
        internal var context: AdaptorEncodableValueContext<Value> {
            .init(_encoder: self.encoder, partialCodingPath: partialCodingPath, currentCodingKey: nil)
        }

        // MARK: - Initialization

        /// Initializes `self` with the given references.
        init(referencing encoder: AdaptorEncoder<Value>, partialCodingPath: [any CodingKey] = [], wrapping ref: AdaptorEncoderFuture<Value>.RefArray) {
            self.encoder = encoder
            self.partialCodingPath = partialCodingPath
            self.reference = ref
        }

        // MARK: - UnkeyedEncodingContainer Methods

        public mutating func encodeNil()             throws { self.reference.append(.null) }
        public mutating func encode(_ value: Bool)   throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: Int)    throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: Int8)   throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: Int16)  throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: Int32)  throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: Int64)  throws { self.reference.append(try .init(value, context: context)) }
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public mutating func encode(_ value: Int128)  throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: UInt)   throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: UInt8)  throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: UInt16) throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: UInt32) throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: UInt64) throws { self.reference.append(try .init(value, context: context)) }
        @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
        public mutating func encode(_ value: UInt128)  throws { self.reference.append(try .init(value, context: context)) }
        public mutating func encode(_ value: String) throws { self.reference.append(try .init(value, context: context)) }

        public mutating func encode(_ value: Float)  throws {
            self.reference.append(try .init(value, context: context))
        }

        public mutating func encode(_ value: Double) throws {
            self.reference.append(try .init(value, context: context))
        }

        public mutating func encode<T : Encodable>(_ value: T) throws {
            let wrapped = try self.encoder.wrap(value, for: _CodingKey(index: self.count))
            self.reference.append(wrapped)
        }

        public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
            let index = self.count
            let nestedRef = self.reference.appendObject()
            let nestedCodingPath = self.partialCodingPath + [_CodingKey(index: index)]
            let container = KeyedContainer<NestedKey>(referencing: self.encoder, partialCodingPath: nestedCodingPath, wrapping: nestedRef)
            return KeyedEncodingContainer(container)
        }

        public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let index = self.count
            let nestedRef = self.reference.appendArray()
            let nestedCodingPath = self.partialCodingPath + [_CodingKey(index: index)]
            return UnkeyedContainer(referencing: self.encoder, partialCodingPath: nestedCodingPath, wrapping: nestedRef)
        }

        public mutating func superEncoder() -> Encoder {
            return AdaptorReferencingEncoder(referencing: self.encoder, at: self.reference.array.count, wrapping: self.reference)
        }

    }
}

extension AdaptorEncoder: SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    private func assertCanEncodeNewValue() {
        precondition(self.singleValue == nil, "Attempt to encode value through single value container when previously value already encoded.")
    }
    
    private var context: AdaptorEncodableValueContext<Value> {
        .init(_encoder: self, partialCodingPath: [], currentCodingKey: codingKey)
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.singleValue = .null
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func encode(_ value: Int128) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func encode(_ value: UInt128) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.singleValue = try .init(value, context: context)
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        let wrapped = try Value(value, context: context)
        self.singleValue = wrapped
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        let wrapped = try Value(value, context: context)
        self.singleValue = wrapped
    }

    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.singleValue = try self.wrap(value)
    }
}

private class AdaptorReferencingEncoder<Value: AdaptorEncodableValue> : AdaptorEncoder<Value> {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(AdaptorEncoderFuture<Value>.RefArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(AdaptorEncoderFuture<Value>.RefDictionary, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    let encoder: AdaptorEncoder<Value>

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(referencing encoder: AdaptorEncoder<Value>, at index: Int, wrapping ref: AdaptorEncoderFuture<Value>.RefArray) {
        self.encoder = encoder
        self.reference = .array(ref, index)
        super.init(ownerEncoder: encoder, encoderContext: encoder.encoderContext, codingKey: _CodingKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(referencing encoder: AdaptorEncoder<Value>, key: CodingKey, convertedKey: String, wrapping dictionary: AdaptorEncoderFuture<Value>.RefDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, convertedKey)
        super.init(ownerEncoder: encoder, encoderContext: encoder.encoderContext, codingKey: key)
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value = self.encodedValue

        switch self.reference {
        case .array(let arrayRef, let index):
            arrayRef.insert(value, at: index)
        case .dictionary(let dictionaryRef, let key):
            dictionaryRef.set(value, for: key)
        }
    }
}

enum AdaptorEncoderFuture<Value: AdaptorEncodableValue> {
    case value(Value)
    case nestedArray(RefArray)
    case nestedDictionary(RefDictionary)

    var dictionary: RefDictionary? {
        switch self {
        case .nestedDictionary(let obj): obj
        default: nil
        }
    }

    var array: RefArray? {
        switch self {
        case .nestedArray(let array): array
        default: nil
        }
    }

    class RefArray {
        private(set) var array: [AdaptorEncoderFuture] = []

        init() {
            self.array.reserveCapacity(10)
        }

        init(array: [AdaptorEncoderFuture]) {
            self.array = array
        }

        @inline(__always) func append(_ element: Value) {
            self.array.append(.value(element))
        }

        @inline(__always) func insert(_ element: Value, at index: Int) {
            self.array.insert(.value(element), at: index)
        }

        @inline(__always) func appendArray() -> RefArray {
            let array = RefArray()
            self.array.append(.nestedArray(array))
            return array
        }

        @inline(__always) func appendObject() -> RefDictionary {
            let object = RefDictionary()
            self.array.append(.nestedDictionary(object))
            return object
        }

        var values: [Value] {
            self.array.map { (future) -> Value in
                switch future {
                case .value(let value):
                    return value
                case .nestedArray(let array):
                    return .init(array.values)
                case .nestedDictionary(let object):
                    return .init(object.values)
                }
            }
        }
    }

    class RefDictionary {
        var dict: [String: AdaptorEncoderFuture] = [:]

        init() {
            self.dict.reserveCapacity(4)
        }

        init(dict: [String: AdaptorEncoderFuture]) {
            self.dict = dict
        }

        @inline(__always) func set(_ value: Value, for key: String) {
            self.dict[key] = .value(value)
        }

        @inline(__always) func setArray(for key: String) -> RefArray {
            switch self.dict[key] {
            case .nestedDictionary:
                preconditionFailure("For key \"\(key)\" a keyed container has already been created.")
            case .nestedArray(let array):
                return array
            case .none, .value:
                let array = RefArray()
                dict[key] = .nestedArray(array)
                return array
            }
        }

        @inline(__always) func setObject(for key: String) -> RefDictionary {
            switch self.dict[key] {
            case .nestedDictionary(let object):
                return object
            case .nestedArray:
                preconditionFailure("For key \"\(key)\" a unkeyed container has already been created.")
            case .none, .value:
                let object = RefDictionary()
                dict[key] = .nestedDictionary(object)
                return object
            }
        }

        var values: [String: Value] {
            self.dict.mapValues { (future) -> Value in
                switch future {
                case .value(let value):
                    return value
                case .nestedArray(let array):
                    return .init(array.values)
                case .nestedDictionary(let object):
                    return .init(object.values)
                }
            }
        }
    }
}

extension AdaptorEncodableValue {
    func convertedToObjectRef() -> AdaptorEncoderFuture<Self>.RefDictionary? {
        guard let dict = self.dictionary else {
            return nil
        }
        return .init(dict: .init(uniqueKeysWithValues: dict.map { ($0.key, .value($0.value)) }))
    }

    func convertedToArrayRef() -> AdaptorEncoderFuture<Self>.RefArray? {
        guard let array = self.array else {
            return nil
        }
        return .init(array: array.map { .value($0) })
    }
}
