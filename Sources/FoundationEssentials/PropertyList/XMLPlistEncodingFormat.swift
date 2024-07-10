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

// IMPORTANT: Any changes to __PlistEncoderXML and its related types should be repeated for __PlistEncoderBPlist.
// This code is duplicate for performance reasons, as use of `@_specialize` has not been able to completely replicate the benefits of manual duplication.

internal class __PlistEncoderXML : Encoder {
    // MARK: Properties

    /// The encoder's storage.
    fileprivate var storage: _PlistEncodingStorageXML

    /// Options set on the top-level encoder.
    fileprivate let options: PropertyListEncoder._Options
    
    internal var encoderCodingPathNode: _CodingPathNode
    fileprivate var codingPathDepth: Int
    
    internal var format: _XMLPlistEncodingFormat

    /// The path to the current point in encoding.
    var codingPath: [CodingKey] {
        encoderCodingPathNode.path
    }

    /// Contextual user-provided information for use during encoding.
    var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    init(options: PropertyListEncoder._Options, codingPathNode: _CodingPathNode = .root, initialDepth: Int = 0) {
        self.options = options
        self.storage = _PlistEncodingStorageXML()
        self.encoderCodingPathNode = codingPathNode
        self.codingPathDepth = initialDepth
        self.format = _XMLPlistEncodingFormat()
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
    func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        let topRef: _XMLPlistEncodingFormat.Reference
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topRef = self.storage.pushKeyedContainer()
        } else {
            guard let ref = self.storage.refs.last, ref.isDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }

            topRef = ref
        }

        let container = _PlistKeyedEncodingContainerXML<Key>(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topRef)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topRef: _XMLPlistEncodingFormat.Reference
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topRef = self.storage.pushUnkeyedContainer()
        } else {
            guard let ref = self.storage.refs.last, ref.isArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }

            topRef = ref
        }

        return _PlistUnkeyedEncodingContainerXML(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topRef)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
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

private struct _PlistEncodingStorageXML {
    // MARK: Properties

    /// The container stack.
    fileprivate var refs = ContiguousArray<_XMLPlistEncodingFormat.Reference>()

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return self.refs.count
    }

    fileprivate mutating func pushKeyedContainer() -> _XMLPlistEncodingFormat.Reference {
        let dictionary = _XMLPlistEncodingFormat.Reference.emptyDictionary
        self.refs.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> _XMLPlistEncodingFormat.Reference {
        let array = _XMLPlistEncodingFormat.Reference.emptyArray
        self.refs.append(array)
        return array
    }

    fileprivate mutating func push(reference: __owned _XMLPlistEncodingFormat.Reference) {
        self.refs.append(reference)
    }

    fileprivate mutating func popReference() -> _XMLPlistEncodingFormat.Reference {
        precondition(!self.refs.isEmpty, "Empty container stack.")
        return self.refs.popLast()!
    }
}

// MARK: - Encoding Containers

private struct _PlistKeyedEncodingContainerXML<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistEncoderXML

    /// A reference to the container we're writing to.
    private let reference: _XMLPlistEncodingFormat.Reference
    
    private let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: __PlistEncoderXML, codingPathNode: _CodingPathNode, wrapping reference: _XMLPlistEncodingFormat.Reference) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.reference = reference
    }

    // MARK: - KeyedEncodingContainerProtocol Methods

    mutating func encodeNil(forKey key: Key) throws {
        self.reference.insert(encoder.format.null, for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Bool, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Int, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Int8, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Int16, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Int32, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Int64, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: UInt, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: String, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Float, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }
    mutating func encode(_ value: Double, forKey key: Key) throws {
        self.reference.insert(encoder.wrap(value), for: encoder.wrap(key.stringValue))
    }

    mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, key)
        reference.insert(wrapped, for: encoder.wrap(key.stringValue))
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let containerKey = encoder.wrap(key.stringValue)
        let nestedRef: _XMLPlistEncodingFormat.Reference
        if let existingRef = self.reference[containerKey] {
            precondition(
                existingRef.isDictionary,
                "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key"
            )
            nestedRef = existingRef
        } else {
            nestedRef = .emptyDictionary
            self.reference.insert(nestedRef, for: containerKey)
        }
        
        let container = _PlistKeyedEncodingContainerXML<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let containerKey = encoder.wrap(key.stringValue)
        let nestedRef: _XMLPlistEncodingFormat.Reference
        if let existingRef = self.reference[containerKey] {
            precondition(
                existingRef.isArray,
                "Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(containerKey)\" is invalid: keyed container/single value already encoded for this key"
            )
            nestedRef = existingRef
        } else {
            nestedRef = .emptyArray
            self.reference.insert(nestedRef, for: containerKey)
        }

        return _PlistUnkeyedEncodingContainerXML(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
    }

    mutating func superEncoder() -> Encoder {
        return __PlistReferencingEncoderXML(referencing: self.encoder, at: _CodingKey.super, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return __PlistReferencingEncoderXML(referencing: self.encoder, at: key, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }
}

private struct _PlistUnkeyedEncodingContainerXML : UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistEncoderXML

    /// A reference to the container we're writing to.
    private let reference: _XMLPlistEncodingFormat.Reference

    /// The path of coding keys taken to get to this point in encoding.
    private let codingPathNode: _CodingPathNode
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    /// The number of elements encoded into the container.
    var count: Int {
        self.reference.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: __PlistEncoderXML, codingPathNode: _CodingPathNode, wrapping reference: _XMLPlistEncodingFormat.Reference) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.reference = reference
    }

    // MARK: - UnkeyedEncodingContainer Methods

    mutating func encodeNil()             throws { self.reference.insert(encoder.format.null) }
    mutating func encode(_ value: Bool)   throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Int)    throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Int8)   throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Int16)  throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Int32)  throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Int64)  throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: UInt)   throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: UInt8)  throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: UInt16) throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: UInt32) throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: UInt64) throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Float)  throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: Double) throws { self.reference.insert(self.encoder.wrap(value)) }
    mutating func encode(_ value: String) throws { self.reference.insert(self.encoder.wrap(value)) }

    mutating func encode<T : Encodable>(_ value: T) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, _CodingKey(index: self.count))
        self.reference.insert(wrapped)
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let key = _CodingKey(index: self.count)
        let nestedRef = _XMLPlistEncodingFormat.Reference.emptyDictionary
        self.reference.insert(nestedRef)
        let container = _PlistKeyedEncodingContainerXML<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = _CodingKey(index: self.count)
        let nestedRef = _XMLPlistEncodingFormat.Reference.emptyArray
        self.reference.insert(nestedRef)
        return _PlistUnkeyedEncodingContainerXML(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
    }

    mutating func superEncoder() -> Encoder {
        return __PlistReferencingEncoderXML(referencing: self.encoder, at: self.reference.count, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }
}

extension __PlistEncoderXML : SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    private func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: format.null)
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        self.storage.push(reference: wrap(value))
    }

    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        try self.storage.push(reference: wrap(value, for: self.encoderCodingPathNode))
    }
}

// MARK: - Concrete Value Representations

extension __PlistEncoderXML {

    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    @inline(__always) internal func wrap(_ value: Bool)   -> _XMLPlistEncodingFormat.Reference { format.bool(value) }
    @inline(__always) internal func wrap(_ value: Int)    -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int8)   -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int16)  -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int32)  -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int64)  -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt)   -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt8)  -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt16) -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt32) -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt64) -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Float)  -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Double) -> _XMLPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: String) -> _XMLPlistEncodingFormat.Reference { format.string(value) }

    func wrap(_ value: Encodable, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _XMLPlistEncodingFormat.Reference {
        return try self.wrapGeneric(value, for: codingPathNode, additionalKey) ?? .emptyDictionary
    }
    
    func wrapGeneric<T : Encodable>(_ value: T, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _XMLPlistEncodingFormat.Reference? {
        switch T.self {
        case is Date.Type:
            return format.date(value as! Date)
        case is Data.Type:
            return format.data(value as! Data)
        default:
            return try _wrapGeneric({
                try value.encode(to: $0)
            }, for: node, additionalKey)
        }
    }
    
    func wrapGeneric<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _XMLPlistEncodingFormat.Reference? {
        try _wrapGeneric({
            try value.encode(to: $0, configuration: configuration)
        }, for: node, additionalKey)
    }
    
    func _wrapGeneric(_ encode: (__PlistEncoderXML) throws -> Void, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _XMLPlistEncodingFormat.Reference? {
        // The value should request a container from the __PlistENcoder.
        let depth = self.storage.count
        do {
            try self.with(path: node.appending(additionalKey)) {
                try encode(self)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth {
                _ = self.storage.popReference()
            }

            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }

        return self.storage.popReference()
    }
}

// MARK: - __PlistReferencingEncoder

/// __PlistReferencingEncoder is a special subclass of __PlistEncoder which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
// NOTE: older overlays called this class _PlistReferencingEncoder.
// The two must coexist without a conflicting ObjC class name, so it
// was renamed. The old name must not be used in the new runtime.
private class __PlistReferencingEncoderXML : __PlistEncoderXML {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(_XMLPlistEncodingFormat.Reference, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(_XMLPlistEncodingFormat.Reference, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    private let encoder: __PlistEncoderXML

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(referencing encoder: __PlistEncoderXML, at index: Int, codingPathNode: _CodingPathNode, wrapping array: _XMLPlistEncodingFormat.Reference) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPathNode: codingPathNode.appending(_CodingKey(index: index)), initialDepth: codingPathNode.depth)
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(referencing encoder: __PlistEncoderXML, at key: CodingKey, codingPathNode: _CodingPathNode, wrapping dictionary: _XMLPlistEncodingFormat.Reference) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, key.stringValue)
        super.init(options: encoder.options, codingPathNode: codingPathNode.appending(key), initialDepth: codingPathNode.depth)
    }

    // MARK: - Coding Path Operations

    override
    fileprivate var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let ref: _XMLPlistEncodingFormat.Reference
        switch self.storage.count {
        case 0: ref = .emptyDictionary
        case 1: ref = self.storage.popReference()
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let array, let index):
            array.insert(ref, at: index)

        case .dictionary(let dictionary, let key):
            dictionary.insert(ref, for: encoder.wrap(key))
        }
    }
}

// MARK: - Format

struct _XMLPlistEncodingFormat : PlistEncodingFormat {
    enum Reference: PlistEncodingReference {
        
        class Box<T> {
            var boxed: T
            init(_ t: T) { boxed = t }
        }
        
        case null
        case `true`
        case `false`
        case string(String)
        
        // All integers have the same method of generating their XML plist representation. By promoting them all to 64 bits, we don't have to keep track of their specific integer type, which isn't critical to the generation of their XML format.
        case unsignedInteger(UInt64)
        case signedInteger(Int64)
        
        // Floats have historically been coerced to Doubles during encoding.
        case floatingPoint(Double)
        
        case date(Date)
        case data(Data)
        
        case array(Box<ContiguousArray<Reference>>)
        case dictionary(Box<[Reference:Reference]>)

        static var emptyArray: Reference {
            .array(.init([]))
        }
        
        static var emptyDictionary: Reference {
            .dictionary(.init([:]))
        }
        
        func insert(_ ref: Reference, for key: Reference) {
            guard case .dictionary(let box) = self else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            box.boxed[key] = ref
        }
        
        func insert(_ ref: Reference, at index: Int) {
            guard case .array(let box) = self else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            box.boxed.insert(ref, at: index)
        }
        
        func insert(_ ref: Reference) {
            guard case .array(let box) = self else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            box.boxed.append(ref)
        }
        
        var count: Int {
            switch self {
            case .array(let box): return box.boxed.count
            case .dictionary(let box): return box.boxed.count
            default: preconditionFailure("Wrong underlying plist reference type")
            }
        }
        
        subscript(key: Reference) -> Reference? {
            guard case .dictionary(let box) = self else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            return box.boxed[key]
        }
        
        var isString: Bool {
            switch self {
            case .string: return true
            case .null: return true // nulls are encoded as strings
            default: return false
            }
        }
        
        var isBool: Bool {
            switch self {
            case .true, .false: return true
            default: return false
            }
        }
        
        var isNumber: Bool {
            switch self {
            case .floatingPoint, .unsignedInteger, .signedInteger:
                return true
            default:
                return false
            }
        }
        
        var isDate: Bool {
            guard case .date = self else { return false }
            return true
        }
        
        var isDictionary: Bool {
            guard case .dictionary = self else { return false }
            return true
        }
        
        var isArray: Bool {
            guard case .array = self else { return false }
            return true
        }
    }
    
    struct Writer : PlistWriting {
        
        static let header: StaticString =
"""
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">

""" // Final newline intended!
        
        static let scratchBufferSize = 8192
        var scratchBuffer: UnsafeMutableBufferPointer<UInt8>
        var scratchUsed: Int = 0
        
        var data = Data()
        
        init() {
            scratchBuffer = UnsafeMutableBufferPointer.allocate(capacity: Self.scratchBufferSize)
        }
        
        mutating func flush() {
            guard scratchUsed > 0 else { return }
            data.append(UnsafeBufferPointer(rebasing: scratchBuffer[..<scratchUsed]))
            scratchUsed = 0
        }
        
        mutating func serializePlist(_ ref: Reference) throws -> Data {
            defer {
                scratchBuffer.deallocate()
            }
            
            append(Self.header)
            append(ref)
            append("</plist>\n")
            
            flush()
            
            return data
        }
        
        mutating func append(_ buf: UnsafeBufferPointer<UInt8>) {
            let bufCount = buf.count
            guard bufCount > 0 else { return }
            
            if bufCount >= Self.scratchBufferSize {
                flush()
                data.append(buf)
                return
            }
            
            let copyCount = min(bufCount, Self.scratchBufferSize - scratchUsed)
            if copyCount == bufCount {
                let ptr = scratchBuffer.baseAddress!.advanced(by: scratchUsed)
                buf.withUnsafeBytes { rawBuf in
                    UnsafeMutableRawBufferPointer(start: ptr, count: copyCount).copyMemory(from: rawBuf)
                }
                scratchUsed += copyCount
                return
            }
            
            flush()
            data.append(buf)
        }
        
        mutating func append(_ str: StaticString) {
            str.withUTF8Buffer {
                append($0)
            }
        }
        
        mutating func append(_ ref: Reference, indentation: Int = 0) {
            appendIndents(indentation)
            
            switch ref {
            case let .string(val):
                appendOpen(.string)
                appendEscaped(val)
                appendClose(.string)
            case let .array(box):
                appendArray(box.boxed, indentation: indentation)
            case let .dictionary(box):
                appendDictionary(box.boxed, indentation: indentation)
            case let .data(val):
                appendOpen(.data, withNewLine: true)
                appendBase64(val, indentation: indentation)
                appendIndents(indentation)
                appendClose(.data)
            case let .date(date):
                appendOpen(.date)
                appendDate(date)
                appendClose(.date)
            case let .floatingPoint(val):
                appendOpen(.real)
                append(realDescription(val))
                appendClose(.real)
            case let .signedInteger(val):
                appendOpen(.integer)
                append(val.description)
                appendClose(.integer)
            case let .unsignedInteger(val):
                appendOpen(.integer)
                append(val.description)
                appendClose(.integer)
            case .true:
                appendEmpty(.true)
            case .false:
                appendEmpty(.false)
            case .null:
                appendOpen(.string)
                append(_plistNull)
                appendClose(.string)
            }
        }
        
        mutating func appendOpen(_ tag: XMLPlistTag, withNewLine: Bool = false) {
            append("<")
            append(tag.tagName)
            if (withNewLine) {
                append(">\n")
            } else {
                append(">")
            }
        }
        
        mutating func appendClose(_ tag: XMLPlistTag) {
            append("</")
            append(tag.tagName)
            append(">\n")
        }
        
        mutating func appendEmpty(_ tag: XMLPlistTag) {
            append("<")
            append(tag.tagName)
            append("/>\n")
        }
        
        mutating func appendIndents(_ count: Int) {
            var remaining = count
            while remaining >= 4 {
                append("\t\t\t\t")
                remaining -= 4
            }
            switch remaining {
            case 3:
                append("\t\t\t")
            case 2:
                append("\t\t")
            case 1:
                append("\t")
            default:
                break
            }
        }
        
        mutating func append(_ str: String) {
            var mutableStr = str
            mutableStr.withUTF8 {
                append($0)
            }
        }
        
        mutating func appendEscaped(_ str: String) {
            var mutableStr = str
            mutableStr.withUTF8 {
                var ptr = $0.baseAddress!
                let end = ptr + $0.count
                while ptr < end {
                    let subBuffer = UnsafeBufferPointer(start: ptr, count: end - ptr)
                    let nextToEscapeIdx = subBuffer.firstIndex {
                        switch $0 {
                        case ._openangle, ._closeangle, ._ampersand:
                            return true
                        default:
                            return false
                        }
                    }
                    
                    if let nextToEscapeIdx {
                        let bufferToNextEscaped = UnsafeBufferPointer(rebasing: subBuffer[..<nextToEscapeIdx])
                        append(bufferToNextEscaped)
                        appendEscaped(subBuffer[nextToEscapeIdx])
                        ptr = ptr.advanced(by: nextToEscapeIdx + 1)
                    } else {
                        append(subBuffer)
                        ptr = end
                    }
                }
            }
        }
        
        mutating func appendEscaped(_ char: UInt8) {
            switch char {
            case ._openangle:
                append("&lt;")
            case ._closeangle:
                append("&gt;")
            case ._ampersand:
                append("&amp;")
            default: fatalError("XML plist encoding doesn't escape character '\(String(UnicodeScalar(char)))'")
            }
        }
        
        fileprivate static let dataEncodeTable = [
            UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"),
            UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
            UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
            UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
            UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
            UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"),
            UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
            UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
            UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
            UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
            UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"),
            UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
            UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
            UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
            UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
            UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"),
        ]
        fileprivate static let maxB64LineLen = 76
        
        mutating func appendBase64(_ data: Data, indentation: Int) {
            // Unfortunately this base64 encoder has different formatting constraints than Data's standard encoder, so the algorithm is reimplemented here.
            
            // Enforce a maximum level of indentation, because indentation is counted against the maximum allowed line length
            let actualIndentation = min(indentation, 8)
            
            // Buffer size includes slop and carriage return
            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: Self.maxB64LineLen + 4) { tmpBuf in
                let tmpBufStart = tmpBuf.baseAddress!
                var tmpBufPtr = tmpBufStart
                
                data.withBufferView {
                    var prevByte: Int = 0
                    for (i, byte) in $0.enumerated() {
                        // 3 bytes are encoded as 4 characters
                        switch i % 3 {
                        case 0:
                            tmpBufPtr.pointee = Self.dataEncodeTable[ ((Int(byte) &>> 2) & 0x3f) ]
                            tmpBufPtr += 1
                        case 1:
                            tmpBufPtr.pointee = Self.dataEncodeTable[ ((((prevByte &<< 8) | Int(byte)) &>> 4) & 0x3f) ]
                            tmpBufPtr += 1
                        default:
                            (tmpBufPtr+0).pointee = Self.dataEncodeTable[ ((((prevByte &<< 8) | Int(byte)) &>> 6) & 0x3f) ]
                            (tmpBufPtr+1).pointee = Self.dataEncodeTable[ Int(byte) & 0x3f ]
                            tmpBufPtr += 2
                        }
                        prevByte = Int(byte)
                        
                        // Flush the line out every 76 (or fewer) chars --- indentation tabs count 8 characters against the line length
                        let curLineLen = (tmpBufPtr - tmpBufStart) + 8 * actualIndentation
                        if curLineLen >= Self.maxB64LineLen {
                            tmpBufPtr.pointee = ._newline
                            let tmpBufLen = (tmpBufPtr+1) - tmpBufStart
                            
                            // Apply indentation for this line, followed by the accumulated base64 line
                            appendIndents(actualIndentation)
                            append(UnsafeBufferPointer(rebasing: tmpBuf[..<tmpBufLen]))
                            tmpBufPtr = tmpBufStart
                        }
                    }
                    
                    switch $0.count % 3 {
                    case 0:
                        break
                    case 1:
                        (tmpBufPtr+0).pointee = Self.dataEncodeTable[ ((prevByte &<< 4) & 0x30) ]
                        (tmpBufPtr+1).pointee = ._equal
                        (tmpBufPtr+2).pointee = ._equal
                        tmpBufPtr += 3
                    default:
                        (tmpBufPtr+0).pointee = Self.dataEncodeTable[ ((prevByte &<< 2) & 0x3c) ]
                        (tmpBufPtr+1).pointee = ._equal
                        tmpBufPtr += 2
                    }
                    
                    let accumulatedB64Len = (tmpBufPtr - tmpBufStart)
                    if accumulatedB64Len > 0 {
                        tmpBufPtr.pointee = ._newline
                        appendIndents(actualIndentation)
                        append(UnsafeBufferPointer(rebasing: tmpBuf[..<(accumulatedB64Len+1)])) // include newline
                    }
                }
            }
        }
        
        func realDescription(_ val: Double) -> String {
            // Double.description does almost everything for us. It just has a different representation for infinity.
            // The old implementation is slightly different as it would format the string out to DBL_DIG + 2 decimal places, but parsers are expected to parse strings like "3.14" and "3.1400000000000001" identically.
            if !val.isFinite && !val.isNaN {
                if val > 0 {
                    return "+infinity"
                } else {
                    return "-infinity"
                }
            }
            // Historically whole-value reals (2.0, -5.0, etc) are
            // encoded without the `.0` suffix.
            // JSONEncoder also has the same behavior. See `JSONWriter.swift`
            var string = val.description
            if string.hasSuffix(".0") {
                string.removeLast(2)
            }
            return string
        }
        
        mutating func appendDate(_ date: Date) {
            var c = Calendar(identifier: .iso8601)
            c.timeZone = .gmt

            let dc = c.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: date)
            let str = Date.ISO8601FormatStyle().format(dc, appendingTimeZoneOffset: 0)
            append(str)
        }
        
        mutating func appendArray(_ array: ContiguousArray<Reference>, indentation: Int) {
            if array.isEmpty {
                appendEmpty(.array)
            } else {
                appendOpen(.array, withNewLine: true)
                for val in array {
                    append(val, indentation: indentation + 1)
                }
                appendIndents(indentation)
                appendClose(.array)
            }
        }
        
        mutating func appendDictionary(_ dictionary: [Reference:Reference], indentation: Int) {
            if dictionary.isEmpty {
                appendEmpty(.dict)
            } else {
                appendOpen(.dict, withNewLine: true)
                for (key, value) in dictionary.sorted(by: { $0.key < $1.key }) {
                    appendIndents(indentation+1)
                    appendOpen(.key)
                    appendEscaped(key.string)
                    appendClose(.key)
                    
                    append(value, indentation: indentation + 1)
                }
                appendIndents(indentation)
                appendClose(.dict)
            }
        }
    }
    
    // XML plist encoding doesn't bother to unique references
    let null = Reference.null
    let `true` = Reference.true
    let `false` = Reference.false
    
    init() {
        
    }
    
    func string(_ str: String) -> Reference {
        return .string(str)
    }
    
    func number<T: FixedWidthInteger>(from num: T) -> Reference {
        if T.isSigned {
            return .signedInteger(Int64(num))
        } else {
            return .unsignedInteger(UInt64(num))
        }
    }
    
    func number<T: BinaryFloatingPoint>(from num: T) -> Reference {
        .floatingPoint(Double(num))
    }
    
    func date(_ date: Date) -> Reference {
        .date(date)
    }
    
    func data(_ data: Data) -> Reference {
        .data(data)
    }
}

extension _XMLPlistEncodingFormat.Reference : Hashable {
    static func == (lhs: _XMLPlistEncodingFormat.Reference, rhs: _XMLPlistEncodingFormat.Reference) -> Bool {
        guard case let .string(lh) = lhs,
              case let .string(rh) = rhs else {
            fatalError("Only string references require Hashable conformance")
        }
        return lh == rh
    }
    
    func hash(into hasher: inout Hasher) {
        guard case let .string(str) = self else {
            fatalError("Only string references require Hashable conformance")
        }
        str.hash(into: &hasher)
    }
}

extension _XMLPlistEncodingFormat.Reference : Comparable {
    static func < (lhs: _XMLPlistEncodingFormat.Reference, rhs: _XMLPlistEncodingFormat.Reference) -> Bool {
        guard case let .string(lh) = lhs,
              case let .string(rh) = rhs else {
            fatalError("Only string references require Hashable conformance")
        }
        return lh < rh
    }
}

extension _XMLPlistEncodingFormat.Reference {
    var string : String {
        guard case let .string(str) = self else {
            fatalError("Wrong reference type")
        }
        return str
    }
}
