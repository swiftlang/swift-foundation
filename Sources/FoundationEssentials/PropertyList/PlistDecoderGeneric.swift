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

protocol PlistDecodingMap: AnyObject {
    associatedtype Value
    associatedtype ContainedValueReference
    
    associatedtype DictionaryIterator: PlistDictionaryIterator<ContainedValueReference>
    associatedtype ArrayIterator: PlistArrayIterator<ContainedValueReference>

    static var nullValue: Value { get }
    
    func copyInBuffer()
    var topObject: Value { get throws }
    
    @inline(__always)
    func value(from reference: ContainedValueReference) throws -> Value
}

protocol PlistDictionaryIterator<ValueReference> {
    associatedtype ValueReference
    mutating func next() throws -> (key: ValueReference, value: ValueReference)?
}

protocol PlistArrayIterator<ValueReference> {
    associatedtype ValueReference
    mutating func next() -> ValueReference?
}

protocol PlistDecodingFormat {
    associatedtype Map : PlistDecodingMap
    
    static func container<Key: CodingKey>(keyedBy type: Key.Type, for value: Map.Value, referencing: _PlistDecoder<Self>, codingPathNode: _CodingPathNode) throws -> KeyedDecodingContainer<Key>
    static func unkeyedContainer(for value: Map.Value, referencing: _PlistDecoder<Self>, codingPathNode: _CodingPathNode) throws -> UnkeyedDecodingContainer
    
    @inline(__always)
    static func valueIsNull(_ mapValue: Map.Value) -> Bool
    
    static func unwrapBool(from mapValue: Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Bool
    static func unwrapDate(from mapValue: Map.Value, in: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date
    static func unwrapData(from mapValue: Map.Value, in: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data
    static func unwrapString(from mapValue: Map.Value, in: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> String
    static func unwrapFloatingPoint<T: BinaryFloatingPoint>(from mapValue: Map.Value, in: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T
    static func unwrapFixedWidthInteger<T: FixedWidthInteger>(from mapValue: Map.Value, in: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T
}

internal protocol _PlistDecoderEntryPointProtocol {
    func decode<T: Decodable>(_ type: T.Type) throws -> T
    func decode<T: DecodableWithConfiguration>(_ type: T.Type, configuration: T.DecodingConfiguration) throws -> T
}

internal class _PlistDecoder<Format: PlistDecodingFormat> : Decoder, _PlistDecoderEntryPointProtocol {
    // MARK: Properties

    /// The decoder's storage.
    internal var storage: _PlistDecodingStorage<Format.Map.Value>

    /// The decoder's xml plist map info.
    internal var map : Format.Map

    /// Options set on the top-level decoder.
    fileprivate let options: PropertyListDecoder._Options

    /// The path to the current point in encoding.
    fileprivate var codingPathNode: _CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    /// Contextual user-provided information for use during encoding.
    var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }
    
    // MARK: - Initialization

    /// Initializes `self` with the given top-level container and options.
    internal init(referencing map: Format.Map, options: PropertyListDecoder._Options, codingPathNode: _CodingPathNode) throws {
        self.storage = _PlistDecodingStorage<Format.Map.Value>()
        self.map = map
        self.storage.push(container: try map.topObject) // This is something the old implementation did and apps started relying on. Weird.
        self.codingPathNode = codingPathNode
        self.options = options
    }
    
    // This _XMLPlistDecoder may have multiple references if an init(from: Decoder) implementation allows the Decoder (this object) to escape, or if a container escapes.
    // The XMLPlistMap might have multiple references if a superDecoder, which creates a different _XMLPlistDecoder instance but references the same XMLPlistMap, is allowed to escape.
    // In either case, we need to copy-in the input buffer since it's about to go out of scope.
    func takeOwnershipOfBackingDataIfNeeded(selfIsUniquelyReferenced: Bool) {
        if !selfIsUniquelyReferenced || !isKnownUniquelyReferenced(&map) {
            map.copyInBuffer()
        }
    }
    
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try Format.container(keyedBy: type, for: storage.topContainer, referencing: self, codingPathNode: codingPathNode)
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try Format.unkeyedContainer(for: storage.topContainer, referencing: self, codingPathNode: codingPathNode)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
         self
    }
}

extension _PlistDecoder {
    // MARK: Special case handling

    @inline(__always)
    func checkNotNull<T>(_ value: Format.Map.Value, expectedType: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws {
        if Format.valueIsNull(value) {
            throw DecodingError.valueNotFound(expectedType, DecodingError.Context(
                codingPath: codingPathNode.path(byAppending: additionalKey),
                debugDescription: "Found null value instead"
            ))
        }
    }

    @inline(__always)
    func with<T>(value: Format.Map.Value, path: _CodingPathNode?, perform closure: () throws -> T) rethrows -> T {
        let oldPath = self.codingPathNode
        if let path {
            self.codingPathNode = path
        }
        storage.push(container: value)

        defer {
            if path != nil {
                self.codingPathNode = oldPath
            }
            storage.popContainer()
        }

        return try closure()
    }

    fileprivate func unwrapGeneric<T: Decodable>(_ mapValue: Format.Map.Value, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T {
        if type == Date.self {
            return try self.unwrapDate(from: mapValue, for: codingPathNode, additionalKey) as! T
        }
        if type == Data.self {
            return try self.unwrapData(from: mapValue, for: codingPathNode, additionalKey) as! T
        }
        return try self.with(value: mapValue, path: codingPathNode.appending(additionalKey)) {
            try type.init(from: self)
        }
    }
    
    fileprivate func unwrapGeneric<T: DecodableWithConfiguration>(_ mapValue: Format.Map.Value, as type: T.Type, configuration: T.DecodingConfiguration, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T {
        try self.with(value: mapValue, path: codingPathNode.appending(additionalKey)) {
            try type.init(from: self, configuration: configuration)
        }
    }
    
    fileprivate func unwrapBool(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Bool {
        try checkNotNull(mapValue, expectedType: Bool.self, for: codingPathNode, additionalKey)
        return try Format.unwrapBool(from: mapValue, for: codingPathNode, additionalKey)
    }
    
    private func unwrapDate(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Date {
        try checkNotNull(mapValue, expectedType: Date.self, for: codingPathNode, additionalKey)
        return try Format.unwrapDate(from: mapValue, in: map, for: codingPathNode, additionalKey)
    }

    private func unwrapData(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Data {
        try checkNotNull(mapValue, expectedType: Data.self, for: codingPathNode, additionalKey)
        return try Format.unwrapData(from: mapValue, in: map, for: codingPathNode, additionalKey)
    }

    fileprivate func unwrapString(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> String {
        try checkNotNull(mapValue, expectedType: String.self, for: codingPathNode, additionalKey)
        return try Format.unwrapString(from: mapValue, in: map, for: codingPathNode, additionalKey)
    }

    fileprivate func unwrapFloatingPoint<T: BinaryFloatingPoint>(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T {
        try checkNotNull(mapValue, expectedType: T.self, for: codingPathNode, additionalKey)
        return try Format.unwrapFloatingPoint(from: mapValue, in: map, for: codingPathNode, additionalKey)
    }

    fileprivate func unwrapFixedWidthInteger<T: FixedWidthInteger>(from mapValue: Format.Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T
    {
        try checkNotNull(mapValue, expectedType: T.self, for: codingPathNode, additionalKey)
        return try Format.unwrapFixedWidthInteger(from: mapValue, in: map, for: codingPathNode, additionalKey)
    }
}

extension _PlistDecoder : SingleValueDecodingContainer {
    // MARK: SingleValueDecodingContainer Methods
    
    public func decodeNil() -> Bool {
        return Format.valueIsNull(storage.topContainer)
    }
    
    public func decode(_ type: Bool.Type) throws -> Bool {
        try unwrapBool(from: storage.topContainer, for: codingPathNode)
    }
    
    public func decode(_ type: Int.Type) throws -> Int {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Int8.Type) throws -> Int8 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Int16.Type) throws -> Int16 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Int32.Type) throws -> Int32 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Int64.Type) throws -> Int64 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: UInt.Type) throws -> UInt {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: UInt8.Type) throws -> UInt8 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: UInt16.Type) throws -> UInt16 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: UInt32.Type) throws -> UInt32 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: UInt64.Type) throws -> UInt64 {
        try unwrapFixedWidthInteger(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Float.Type) throws -> Float {
        try unwrapFloatingPoint(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: Double.Type) throws -> Double {
        try unwrapFloatingPoint(from: storage.topContainer, for: codingPathNode)
    }

    public func decode(_ type: String.Type) throws -> String {
        try unwrapString(from: storage.topContainer, for: codingPathNode)
    }

    public func decode<T : Decodable>(_ type: T.Type) throws -> T {
        try unwrapGeneric(self.storage.topContainer, as: type, for: codingPathNode)
    }
}

extension _PlistDecoder {
    internal func decode<T>(_ type: T.Type, configuration: T.DecodingConfiguration) throws -> T where T : DecodableWithConfiguration {
        try unwrapGeneric(self.storage.topContainer, as: type, configuration: configuration, for: codingPathNode)
    }
}

// MARK: Decoding Containers

internal struct _PlistKeyedDecodingContainer<Key : CodingKey, Format: PlistDecodingFormat> : KeyedDecodingContainerProtocol {

    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: _PlistDecoder<Format>

    /// A reference to the container we're reading from.
    private let container: [String:Format.Map.ContainedValueReference]

    /// A reference to the key this container was created with, and the parent container. Used for lazily generating the full codingPath.
    fileprivate let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in decoding.
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    // MARK: - Initialization

    static func stringify(iterator: Format.Map.DictionaryIterator, count: Int, using decoder: _PlistDecoder<Format>, codingPathNode: _CodingPathNode) throws -> [String:Format.Map.ContainedValueReference] {
        var result = [String:Format.Map.ContainedValueReference]()
        result.reserveCapacity(count / 2)

        var iter = iterator
        while let (keyRef, valueRef) = try iter.next() {
            let keyValue = try decoder.map.value(from: keyRef)
            let key = try decoder.unwrapString(from: keyValue, for: codingPathNode)
            result[key] = valueRef
        }
        return result
    }

    /// Initializes `self` by referencing the given decoder and container.
    internal init(referencing decoder: _PlistDecoder<Format>, codingPathNode: _CodingPathNode, iterator: Format.Map.DictionaryIterator, count: Int) throws {
        self.decoder = decoder
        self.container = try Self.stringify(iterator: iterator, count: count, using: decoder, codingPathNode: codingPathNode)
        self.codingPathNode = codingPathNode
    }

    // MARK: - KeyedDecodingContainerProtocol Methods

    var allKeys: [Key] {
        // These keys have been validated, and should definitely succeed in decoding.
        return self.container.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        return self.container[key.stringValue] != nil
    }

    @inline(__always)
    func getValueIfPresent<T>(for key: Key, type: T) throws -> Format.Map.Value? {
        guard let ref = self.container[key.stringValue] else {
            return nil
        }
        return try decoder.map.value(from: ref)
    }

    @inline(__always)
    func getValue<T>(for key: Key, type: T) throws -> Format.Map.Value {
        guard let value = try getValueIfPresent(for: key, type: type) else {
            throw errorForMissingValue(key: key, type: type)
        }
        return value
    }
    
    @inline(never)
    func errorForMissingValue<T>(key: Key, type: T) -> DecodingError {
        let description: String
        if T.self is any KeyedDecodingContainerProtocol {
            description = "Cannot get nested keyed container -- no value found for key \"\(key.stringValue)\""
        } else if T.self is any UnkeyedDecodingContainer {
            description = "Cannot get nested unkeyed container -- no value found for key \"\(key.stringValue)\""
        } else {
            description = "No value associated with key \(key) (\"\(key.stringValue)\")."
        }
        return DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPathNode.path, debugDescription: description))
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        let value = try getValue(for: key, type: Optional<Any>.self)
        return Format.valueIsNull(value)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let value = try getValue(for: key, type: Bool.self)
        return try decoder.unwrapBool(from: value, for: codingPathNode, key)
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        guard let value = try getValueIfPresent(for: key, type: Bool.self),
              !Format.valueIsNull(value)
        else {
            return nil
        }
        return try decoder.unwrapBool(from: value, for: codingPathNode, key)
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeFixedWidthInteger(key: key)
    }

    func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
        try decodeFixedWidthIntegerIfPresent(key: key)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        try decodeFloatingPoint(key: key)
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
        try decodeFloatingPointIfPresent(key: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodeFloatingPoint(key: key)
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        try decodeFloatingPointIfPresent(key: key)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let value = try getValue(for: key, type: String.self)
        return try decoder.unwrapString(from: value, for: codingPathNode, key)
    }

    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        guard let value = try getValueIfPresent(for: key, type: String.self),
              !Format.valueIsNull(value)
        else {
            return nil
        }
        return try decoder.unwrapString(from: value, for: codingPathNode, key)
    }

    func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let value = try getValue(for: key, type: type)
        return try decoder.unwrapGeneric(value, as: type, for: self.codingPathNode, key)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard let value = try getValueIfPresent(for: key, type: type),
              !Format.valueIsNull(value)
        else {
            return nil
        }
        return try decoder.unwrapGeneric(value, as: type, for: codingPathNode, key)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try getValue(for: key, type: _PlistKeyedDecodingContainer<Key, Format>.self)
        return try self.decoder.with(value: value, path: self.codingPathNode.appending(key)) {
            try self.decoder.container(keyedBy: type)
        }
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let value = try getValue(for: key, type: _PlistUnkeyedDecodingContainer<Format>.self)
        return try self.decoder.with(value: value, path: self.codingPathNode.appending(key)) {
            try self.decoder.unkeyedContainer()
        }
    }

    private func _superDecoder(forKey key: __owned CodingKey) throws -> Decoder {
        let value: Format.Map.Value
        if let ref = self.container[key.stringValue] {
            value = try decoder.map.value(from: ref)
        } else {
            value = Format.Map.nullValue
        }
        let decoder = try _PlistDecoder<Format>(referencing: self.decoder.map, options: self.decoder.options, codingPathNode: self.codingPathNode.appending(key))
        decoder.storage.push(container: value)
        return decoder
    }

    func superDecoder() throws -> Decoder {
        return try _superDecoder(forKey: _CodingKey.super)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        return try _superDecoder(forKey: key)
    }

    @inline(__always) private func decodeFixedWidthInteger<T: FixedWidthInteger>(key: Self.Key) throws -> T {
        let value = try getValue(for: key, type: T.self)
        return try decoder.unwrapFixedWidthInteger(from: value, for: codingPathNode, key)
    }

    @inline(__always) private func decodeFloatingPoint<T: BinaryFloatingPoint>(key: Self.Key) throws -> T {
        let value = try getValue(for: key, type: T.self)
        return try decoder.unwrapFloatingPoint(from: value, for: codingPathNode, key)
    }

    @inline(__always) private func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger>(key: Self.Key) throws -> T? {
        guard let value = try getValueIfPresent(for: key, type: T.self),
              !Format.valueIsNull(value)
        else {
            return nil
        }
        return try decoder.unwrapFixedWidthInteger(from: value, for: codingPathNode, key)
    }

    @inline(__always) private func decodeFloatingPointIfPresent<T: BinaryFloatingPoint>(key: Self.Key) throws -> T? {
        guard let value = try getValueIfPresent(for: key, type: T.self),
              !Format.valueIsNull(value)
        else {
            return nil
        }
        return try decoder.unwrapFloatingPoint(from: value, for: codingPathNode, key)
    }
}

struct _PlistUnkeyedDecodingContainer<Format : PlistDecodingFormat> : UnkeyedDecodingContainer {
    // MARK: Properties

    /// A reference to the decoder we're reading from.
    private let decoder: _PlistDecoder<Format>

    /// An iterator from which we can extract the values contained by the underlying array.
    private var arrayIterator: Format.Map.ArrayIterator

    /// An object preemptively pulled from the iterator.
    private var peekedValue: Format.Map.Value?

    /// The number of objects in the underlying array.
    let count: Int?

    /// The index of the element we're about to decode.
    var currentIndex: Int = 0

    /// A reference to the key this container was created with, and the parent container. Used for lazily generating the full codingPath.
    fileprivate let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in decoding.
    @inline(__always)
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    @inline(__always)
    var currentIndexKey : _CodingKey {
        .init(index: currentIndex)
    }

    // MARK: - Initialization

    /// Initializes `self` by referencing the given decoder and container.
    internal init(referencing decoder: _PlistDecoder<Format>, codingPathNode: _CodingPathNode, iterator: Format.Map.ArrayIterator, count: Int) {
        self.decoder = decoder
        self.codingPathNode = codingPathNode
        self.count = count
        self.arrayIterator = iterator
    }

    // MARK: - UnkeyedDecodingContainer Methods

    var isAtEnd: Bool {
        return self.currentIndex >= self.count.unsafelyUnwrapped
    }

    @inline(__always)
    private mutating func advanceToNextValue() {
        currentIndex &+= 1
        peekedValue = nil
    }

    @inline(__always)
    private mutating func peekNextValueIfPresent<T>(ofType type: T.Type) throws -> Format.Map.Value? {
        if let value = peekedValue {
            return value
        }
        guard let nextRef = arrayIterator.next() else {
            return nil
        }
        let nextValue = try decoder.map.value(from: nextRef)
        peekedValue = nextValue
        return nextValue
    }

    @inline(__always)
    private mutating func peekNextValue<T>(ofType type: T.Type) throws -> Format.Map.Value {
        guard let nextValue = try peekNextValueIfPresent(ofType: type) else {
            throw errorForEndOfContainer(type: type)
        }
        return nextValue
    }

    @inline(never)
    private func errorForEndOfContainer<T>(type: T.Type) -> DecodingError {
        var message = "Unkeyed container is at end."
        if T.self == (any UnkeyedDecodingContainer).self {
            message = "Cannot get nested unkeyed container -- unkeyed container is at end."
        }
        if T.self == Decoder.self {
            message = "Cannot get superDecoder() -- unkeyed container is at end."
        }

        var path = self.codingPath
        path.append(_CodingKey(index: self.currentIndex))

        return DecodingError.valueNotFound(
            type,
            .init(codingPath: path,
                  debugDescription: message,
                  underlyingError: nil))
    }

    mutating func decodeNil() throws -> Bool {
        let value = try self.peekNextValue(ofType: Never.self)
        if Format.valueIsNull(value) {
            advanceToNextValue()
            return true
        } else {
            // The protocol states:
            //   If the value is not null, does not increment currentIndex.
            return false
        }
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        let value = try self.peekNextValue(ofType: Bool.self)
        let result = try self.decoder.unwrapBool(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
        guard let value = try self.peekNextValueIfPresent(ofType: Bool.self) else {
            return nil
        }
        let result = Format.valueIsNull(value) ? nil: try self.decoder.unwrapBool(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    mutating func decode(_ type: String.Type) throws -> String {
        let value = try self.peekNextValue(ofType: String.self)
        let string = try decoder.unwrapString(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return string
    }

    mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
        guard let value = try self.peekNextValueIfPresent(ofType: String.self) else {
            return nil
        }
        let result = Format.valueIsNull(value) ? nil: try self.decoder.unwrapString(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    mutating func decode(_: Double.Type) throws -> Double {
        try decodeFloatingPoint()
    }

    mutating func decodeIfPresent(_: Double.Type) throws -> Double? {
        try decodeFloatingPointIfPresent()
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try decodeFloatingPoint()
    }

    mutating func decodeIfPresent(_: Float.Type) throws -> Float? {
        try decodeFloatingPointIfPresent()
    }

    mutating func decode(_: Int.Type) throws -> Int {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: Int.Type) throws -> Int? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: Int8.Type) throws -> Int8? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: Int16.Type) throws -> Int16? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: Int32.Type) throws -> Int32? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: Int64.Type) throws -> Int64? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: UInt.Type) throws -> UInt? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: UInt8.Type) throws -> UInt8? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: UInt16.Type) throws -> UInt16? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: UInt32.Type) throws -> UInt32? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeFixedWidthInteger()
    }

    mutating func decodeIfPresent(_: UInt64.Type) throws -> UInt64? {
        try decodeFixedWidthIntegerIfPresent()
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try self.peekNextValue(ofType: type)
        let result = try decoder.unwrapGeneric(value, as: type, for: codingPathNode, currentIndexKey)

        advanceToNextValue()
        return result
    }

    mutating func decodeIfPresent<T: Decodable>(_ type: T.Type) throws -> T? {
        guard let value = try self.peekNextValueIfPresent(ofType: T.self) else {
            return nil
        }
        let result: T? = Format.valueIsNull(value) ? nil : try self.decoder.unwrapGeneric(value, as: type, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try self.peekNextValue(ofType: KeyedDecodingContainer<NestedKey>.self)
        let container = try decoder.with(value: value, path: codingPathNode.appending(currentIndexKey)) {
            try decoder.container(keyedBy: type)
        }

        advanceToNextValue()
        return container
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let value = try self.peekNextValue(ofType: UnkeyedDecodingContainer.self)
        let container = try decoder.with(value: value, path: codingPathNode.appending(currentIndexKey)) {
            try decoder.unkeyedContainer()
        }

        advanceToNextValue()
        return container
    }

    mutating func superDecoder() throws -> Decoder {
        let value = try self.peekNextValue(ofType: UnkeyedDecodingContainer.self)
        let decoder = try _PlistDecoder<Format>(referencing: self.decoder.map, options: self.decoder.options, codingPathNode: self.codingPathNode.appending(index: self.currentIndex))
        decoder.storage.push(container: value)
        advanceToNextValue()
        return decoder
    }

    @inline(__always) private mutating func decodeFixedWidthInteger<T: FixedWidthInteger>() throws -> T {
        let value = try self.peekNextValue(ofType: T.self)
        let result: T = try self.decoder.unwrapFixedWidthInteger(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    @inline(__always) private mutating func decodeFloatingPoint<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>() throws -> T {
        let value = try self.peekNextValue(ofType: T.self)
        let result: T = try self.decoder.unwrapFloatingPoint(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    @inline(__always) private mutating func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger>() throws -> T? {
        guard let value = try self.peekNextValueIfPresent(ofType: T.self) else {
            return nil
        }
        let result: T? = Format.valueIsNull(value) ? nil : try self.decoder.unwrapFixedWidthInteger(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }

    @inline(__always) private mutating func decodeFloatingPointIfPresent<T: PrevalidatedJSONNumberBufferConvertible & BinaryFloatingPoint>() throws -> T? {
        guard let value = try self.peekNextValueIfPresent(ofType: T.self) else {
            return nil
        }
        let result: T? = Format.valueIsNull(value) ? nil : try self.decoder.unwrapFloatingPoint(from: value, for: codingPathNode, currentIndexKey)
        advanceToNextValue()
        return result
    }
}

