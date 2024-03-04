//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// MARK: - __PlistDictionaryEncoder

internal class __PlistDictionaryEncoder : Encoder {
    
    internal static func encodeToTopLevelContainer<Value : Encodable>(_ value: Value) throws -> Any {
        let encoder = __PlistDictionaryEncoder(options: .init())
        guard let topLevel = try encoder.boxGeneric(value, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) did not encode any values."))
        }

        return topLevel
    }
    
    // MARK: Properties

    /// The encoder's storage.
    fileprivate var storage: _PlistDictionaryEncodingStorage

    /// Options set on the top-level encoder.
    fileprivate let options: PropertyListEncoder._Options
    
    internal var encoderCodingPathNode: _CodingPathNode
    fileprivate var codingPathDepth: Int

    /// The path to the current point in encoding.
    var codingPath: [CodingKey] {
        encoderCodingPathNode.path
    }

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    fileprivate init(options: PropertyListEncoder._Options, codingPathNode: _CodingPathNode = .root, initialDepth: Int = 0) {
        self.options = options
        self.storage = _PlistDictionaryEncodingStorage()
        self.encoderCodingPathNode = codingPathNode
        self.codingPathDepth = initialDepth
    }

    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    fileprivate var canEncodeNewValue: Bool {
        // Every time a new value gets encoded, the key it's encoded for is pushed onto the coding path (even if it's a nil key from an unkeyed container).
        // At the same time, every time a container is requested, a new value gets pushed onto the storage stack.
        // If there are more values on the storage stack than on the coding path, it means the value is requesting more than one container, which violates the precondition.
        //
        // This means that anytime something that can request a new container goes onto the stack, we MUST push a key onto the coding path.
        // Things which will not request containers do not need to have the coding path extended for them (but it doesn't matter if it is, because they will not reach here).
        return self.storage.count == self.codingPathDepth
    }

    // MARK: - Encoder Methods
    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        let topContainer: NSMutableDictionary
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushKeyedContainer()
        } else {
            guard let dict = self.storage.containers.last as? NSMutableDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }

            topContainer = dict
        }

        let container = _PlistDictionaryKeyedEncodingContainer<Key>(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topContainer)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topContainer: NSMutableArray
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topContainer = self.storage.pushUnkeyedContainer()
        } else {
            guard let container = self.storage.containers.last as? NSMutableArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }

            topContainer = container
        }

        return _PlistDictionaryUnkeyedEncodingContainer(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topContainer)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
    
    // Instead of creating a new __PlistEncoder for passing to methods that take Encoder arguments, wrap the access in this method, which temporarily mutates this __PlistEncoder instance with the additional nesting depth and its coding path.
    @inline(__always)
    func with<T>(path: _CodingPathNode?, perform closure: () throws -> T) rethrows -> T {
        let oldPath = self.encoderCodingPathNode
        let oldDepth = self.codingPathDepth
        if let path {
            self.encoderCodingPathNode = path
            self.codingPathDepth = path.depth
        }

        defer {
            if path != nil {
                self.encoderCodingPathNode = oldPath
                self.codingPathDepth = oldDepth
            }
        }

        return try closure()
    }
}

// MARK: - Encoding Storage and Containers

fileprivate struct _PlistDictionaryEncodingStorage {
    // MARK: Properties

    /// The container stack.
    fileprivate var containers = ContiguousArray<NSObject>()

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return self.containers.count
    }

    fileprivate mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }

    fileprivate mutating func push(container: __owned NSObject) {
        self.containers.append(container)
    }

    fileprivate mutating func popContainer() -> NSObject {
        precondition(!self.containers.isEmpty, "Empty container stack.")
        return self.containers.popLast()!
    }
}

// MARK: - Encoding Containers

internal struct _PlistDictionaryKeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistDictionaryEncoder

    /// A reference to the container we're writing to.
    private let container: NSMutableDictionary
    
    private let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: __PlistDictionaryEncoder, codingPathNode: _CodingPathNode, wrapping container: NSMutableDictionary) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.container = container
    }

    // MARK: - KeyedEncodingContainerProtocol Methods

    public mutating func encodeNil(forKey key: Key) throws {
        self.container[key.stringValue] = _plistNullNSString
    }
    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Int, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: String, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Float, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }
    public mutating func encode(_ value: Double, forKey key: Key) throws {
        self.container[key.stringValue] = self.encoder.box(value)
    }

    public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        let boxed = try self.encoder.box(value, for: self.encoder.encoderCodingPathNode, key)
        self.container[key.stringValue] = boxed
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let containerKey = key.stringValue
        let dictionary: NSMutableDictionary
        if let existingContainer = self.container[containerKey] {
            precondition(
                existingContainer is NSMutableDictionary,
                "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key"
            )
            dictionary = existingContainer as! NSMutableDictionary
        } else {
            dictionary = NSMutableDictionary()
            self.container[containerKey] = dictionary
        }
        
        let container = _PlistDictionaryKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let containerKey = key.stringValue
        let array: NSMutableArray
        if let existingContainer = self.container[containerKey] {
            precondition(
                existingContainer is NSMutableArray,
                "Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(containerKey)\" is invalid: keyed container/single value already encoded for this key"
            )
            array = existingContainer as! NSMutableArray
        } else {
            array = NSMutableArray()
            self.container[containerKey] = array
        }

        return _PlistDictionaryUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
        return __PlistDictionaryReferencingEncoder(referencing: self.encoder, at: _CodingKey.super, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.container)
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return __PlistDictionaryReferencingEncoder(referencing: self.encoder, at: key, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.container)
    }
}

internal struct _PlistDictionaryUnkeyedEncodingContainer : UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistDictionaryEncoder

    /// A reference to the container we're writing to.
    private let container: NSMutableArray

    /// The path of coding keys taken to get to this point in encoding.
    private let codingPathNode: _CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    /// The number of elements encoded into the container.
    public var count: Int {
        self.container.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: __PlistDictionaryEncoder, codingPathNode: _CodingPathNode, wrapping container: NSMutableArray) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.container = container
    }

    // MARK: - UnkeyedEncodingContainer Methods

    public mutating func encodeNil()             throws { self.container.add(_plistNullNSString) }
    public mutating func encode(_ value: Bool)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int)    throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int8)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int16)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int32)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Int64)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt)   throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt8)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt16) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt32) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: UInt64) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Float)  throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: Double) throws { self.container.add(self.encoder.box(value)) }
    public mutating func encode(_ value: String) throws { self.container.add(self.encoder.box(value)) }

    public mutating func encode<T : Encodable>(_ value: T) throws {
        let boxed = try self.encoder.box(value, for: self.encoder.encoderCodingPathNode, _CodingKey(index: self.count))
        self.container.add(boxed)
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let key = _CodingKey(index: self.count)
        let dictionary = NSMutableDictionary()
        self.container.add(dictionary)
        let container = _PlistDictionaryKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: dictionary)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = _CodingKey(index: self.count)
        let array = NSMutableArray()
        self.container.add(array)
        return _PlistDictionaryUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: array)
    }

    public mutating func superEncoder() -> Encoder {
        return __PlistDictionaryReferencingEncoder(referencing: self.encoder, at: self.container.count, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.container)
    }
}

extension __PlistDictionaryEncoder : SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    private func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(container: _plistNullNSString)
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        self.storage.push(container: self.box(value))
    }

    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        try self.storage.push(container: self.box(value, for: self.encoderCodingPathNode))
    }
}

// MARK: - Concrete Value Representations

extension __PlistDictionaryEncoder {

    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    @inline(__always) internal func box(_ value: Bool)   -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Int)    -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Int8)   -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Int16)  -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Int32)  -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Int64)  -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: UInt)   -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: UInt8)  -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: UInt16) -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: UInt32) -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: UInt64) -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Float)  -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: Double) -> NSObject { NSNumber(value: value) }
    @inline(__always) internal func box(_ value: String) -> NSObject { NSString(string: value) }

    func box(_ value: Encodable, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> NSObject {
        return try self.boxGeneric(value, for: codingPathNode, additionalKey) ?? NSDictionary()
    }
    
    fileprivate func boxGeneric<T : Encodable>(_ value: T, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> NSObject? {
        switch T.self {
        case is Date.Type:
            return value as! NSDate
        case is Data.Type:
            return value as! NSData
        default:
            return try _boxGeneric({
                try value.encode(to: $0)
            }, for: node, additionalKey)
        }
    }
    
    fileprivate func boxGeneric<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> NSObject? {
        try _boxGeneric({
            try value.encode(to: $0, configuration: configuration)
        }, for: node, additionalKey)
    }
    
    func _boxGeneric(_ encode: (__PlistDictionaryEncoder) throws -> Void, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> NSObject? {
        // The value should request a container from the __PlistENcoder.
        let depth = self.storage.count
        do {
            try self.with(path: node.appending(additionalKey)) {
                try encode(self)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth {
                let _ = self.storage.popContainer()
            }

            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }

        return self.storage.popContainer()
    }
}

// MARK: - __PlistDictionaryReferencingEncoder

/// __PlistDictionaryReferencingEncoder is a special subclass of __PlistDictionaryEncoder which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
internal class __PlistDictionaryReferencingEncoder : __PlistDictionaryEncoder {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(NSMutableArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(NSMutableDictionary, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    private let encoder: __PlistDictionaryEncoder

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    internal init(referencing encoder: __PlistDictionaryEncoder, at index: Int, codingPathNode: _CodingPathNode, wrapping array: NSMutableArray) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPathNode: codingPathNode.appending(_CodingKey(index: index)), initialDepth: codingPathNode.depth)
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    internal init(referencing encoder: __PlistDictionaryEncoder, at key: CodingKey, codingPathNode: _CodingPathNode, wrapping dictionary: NSMutableDictionary) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, key.stringValue)
        super.init(options: encoder.options, codingPathNode: codingPathNode.appending(key), initialDepth: codingPathNode.depth)
    }

    // MARK: - Coding Path Operations

    fileprivate override var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value: Any
        switch self.storage.count {
        case 0: value = NSDictionary()
        case 1: value = self.storage.popContainer()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let array, let index):
            array.insert(value, at: index)

        case .dictionary(let dictionary, let key):
            dictionary[NSString(string: key)] = value
        }
    }
}

internal let _plistNullNSString = NSString(string: _plistNullString)
