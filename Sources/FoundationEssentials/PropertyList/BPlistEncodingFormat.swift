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

// IMPORTANT: Any changes to __PlistEncoderBPlist and its related types should be repeated for __PlistEncoderXML.
// This code is duplicate for performance reasons, as use of `@_specialize` has not been able to completely replicate the benefits of manual duplication.

private protocol _BPlistStringDictionaryEncodableMarker { }
extension Dictionary : _BPlistStringDictionaryEncodableMarker where Key == String, Value: Encodable { }

internal import _CShims
#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

// MARK: - __PlistEncoder

internal class __PlistEncoderBPlist : Encoder {
    // MARK: Properties

    /// The encoder's storage.
    fileprivate var storage: _PlistEncodingStorageBPlist

    /// Options set on the top-level encoder.
    fileprivate let options: PropertyListEncoder._Options
    
    internal var encoderCodingPathNode: _CodingPathNode
    fileprivate var codingPathDepth: Int
    
    internal var format: _BPlistEncodingFormat

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
        self.storage = _PlistEncodingStorageBPlist()
        self.encoderCodingPathNode = codingPathNode
        self.codingPathDepth = initialDepth
        self.format = _BPlistEncodingFormat()
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
        let topRef: _BPlistEncodingFormat.Reference
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topRef = self.storage.pushKeyedContainer()
        } else {
            guard let ref = self.storage.refs.last, ref.isDictionary else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }

            topRef = ref
        }

        let container = _PlistKeyedEncodingContainerBPlist<Key>(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topRef)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topRef: _BPlistEncodingFormat.Reference
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topRef = self.storage.pushUnkeyedContainer()
        } else {
            guard let ref = self.storage.refs.last, ref.isArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }

            topRef = ref
        }

        return _PlistUnkeyedEncodingContainerBPlist(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topRef)
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

private struct _PlistEncodingStorageBPlist {
    // MARK: Properties

    /// The container stack.
    fileprivate var refs = ContiguousArray<_BPlistEncodingFormat.Reference>()

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    fileprivate init() {}

    // MARK: - Modifying the Stack

    fileprivate var count: Int {
        return self.refs.count
    }

    fileprivate mutating func pushKeyedContainer() -> _BPlistEncodingFormat.Reference {
        let dictionary = _BPlistEncodingFormat.Reference.emptyDictionary
        self.refs.append(dictionary)
        return dictionary
    }

    fileprivate mutating func pushUnkeyedContainer() -> _BPlistEncodingFormat.Reference {
        let array = _BPlistEncodingFormat.Reference.emptyArray
        self.refs.append(array)
        return array
    }

    fileprivate mutating func push(reference: __owned _BPlistEncodingFormat.Reference) {
        self.refs.append(reference)
    }

    fileprivate mutating func popReference() -> _BPlistEncodingFormat.Reference {
        precondition(!self.refs.isEmpty, "Empty container stack.")
        return self.refs.popLast()!
    }
}

// MARK: - Encoding Containers

private struct _PlistKeyedEncodingContainerBPlist<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistEncoderBPlist

    /// A reference to the container we're writing to.
    private let reference: _BPlistEncodingFormat.Reference
    
    private let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    var codingPath: [CodingKey] {
        codingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    fileprivate init(referencing encoder: __PlistEncoderBPlist, codingPathNode: _CodingPathNode, wrapping reference: _BPlistEncodingFormat.Reference) {
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
        let nestedRef: _BPlistEncodingFormat.Reference
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
        
        let container = _PlistKeyedEncodingContainerBPlist<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let containerKey = encoder.wrap(key.stringValue)
        let nestedRef: _BPlistEncodingFormat.Reference
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

        return _PlistUnkeyedEncodingContainerBPlist(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
    }

    mutating func superEncoder() -> Encoder {
        return __PlistReferencingEncoderBPlist(referencing: self.encoder, at: _CodingKey.super, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        return __PlistReferencingEncoderBPlist(referencing: self.encoder, at: key, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }
}

private struct _PlistUnkeyedEncodingContainerBPlist : UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __PlistEncoderBPlist

    /// A reference to the container we're writing to.
    private let reference: _BPlistEncodingFormat.Reference

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
    fileprivate init(referencing encoder: __PlistEncoderBPlist, codingPathNode: _CodingPathNode, wrapping reference: _BPlistEncodingFormat.Reference) {
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
        let nestedRef = _BPlistEncodingFormat.Reference.emptyDictionary
        self.reference.insert(nestedRef)
        let container = _PlistKeyedEncodingContainerBPlist<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = _CodingKey(index: self.count)
        let nestedRef = _BPlistEncodingFormat.Reference.emptyArray
        self.reference.insert(nestedRef)
        return _PlistUnkeyedEncodingContainerBPlist(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
    }

    mutating func superEncoder() -> Encoder {
        return __PlistReferencingEncoderBPlist(referencing: self.encoder, at: self.reference.count, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.reference)
    }
}

extension __PlistEncoderBPlist : SingleValueEncodingContainer {
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

extension __PlistEncoderBPlist {

    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    @inline(__always) internal func wrap(_ value: Bool)   -> _BPlistEncodingFormat.Reference { format.bool(value) }
    @inline(__always) internal func wrap(_ value: Int)    -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int8)   -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int16)  -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int32)  -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Int64)  -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt)   -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt8)  -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt16) -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt32) -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: UInt64) -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Float)  -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: Double) -> _BPlistEncodingFormat.Reference { format.number(from: value) }
    @inline(__always) internal func wrap(_ value: String) -> _BPlistEncodingFormat.Reference { format.string(value) }

    func wrap(_ value: Encodable, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _BPlistEncodingFormat.Reference {
        return try self.wrapGeneric(value, for: codingPathNode, additionalKey) ?? .emptyDictionary
    }
    
    func wrapGeneric<T : Encodable>(_ value: T, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _BPlistEncodingFormat.Reference? {
        switch T.self {
        case is Date.Type:
            return format.date(value as! Date)
        case is Data.Type:
            return format.data(value as! Data)
        case is _BPlistStringDictionaryEncodableMarker.Type:
            return try self.wrap(value as! [String : Encodable], for: node, additionalKey)
        default:
            return try _wrapGeneric({
                try value.encode(to: $0)
            }, for: node, additionalKey)
        }
    }
    
    func wrapGeneric<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _BPlistEncodingFormat.Reference? {
        try _wrapGeneric({
            try value.encode(to: $0, configuration: configuration)
        }, for: node, additionalKey)
    }
    
    func _wrapGeneric(_ encode: (__PlistEncoderBPlist) throws -> Void, for node: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _BPlistEncodingFormat.Reference? {
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
    
    func wrap(_ dict: [String : Encodable], for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> _BPlistEncodingFormat.Reference? {
        let depth = self.storage.count
        let result = self.storage.pushKeyedContainer()
        let rootPath = codingPathNode.appending(additionalKey)
        do {
            // Unfortunately, we need to sort the entries to preserve some semblance of encoding stability to avoid breaking clients that are making incorrect assumptions that bplist encoding is, in fact, stable.
            let sortedEntries = dict.sorted { pair1, pair2 in
                pair1.key < pair2.key
            }
            for (key, value) in sortedEntries {
                let keyRef = format.string(key)
                result.insert(try wrap(value, for: rootPath, _CodingKey(stringValue: key)), for: keyRef)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth {
                let _ = self.storage.popReference()
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
private class __PlistReferencingEncoderBPlist : __PlistEncoderBPlist {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(_BPlistEncodingFormat.Reference, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(_BPlistEncodingFormat.Reference, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    private let encoder: __PlistEncoderBPlist

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(referencing encoder: __PlistEncoderBPlist, at index: Int, codingPathNode: _CodingPathNode, wrapping array: _BPlistEncodingFormat.Reference) {
        self.encoder = encoder
        self.reference = .array(array, index)
        super.init(options: encoder.options, codingPathNode: codingPathNode.appending(_CodingKey(index: index)), initialDepth: codingPathNode.depth)
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(referencing encoder: __PlistEncoderBPlist, at key: CodingKey, codingPathNode: _CodingPathNode, wrapping dictionary: _BPlistEncodingFormat.Reference) {
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
        let ref: _BPlistEncodingFormat.Reference
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

struct _BPlistEncodingFormat : PlistEncodingFormat {
    final class Reference: PlistEncodingReference {
        enum Backing {
            case string(String, hash: Int, isASCII: Bool)
            case `true`
            case `false`
            case null
            
            // UInt64s have a different representation than other integers.
            case uint64(UInt64)
            case shorterOrSignedInteger(Int64)
            
            // Doubles and Floats also have different representations.
            case double(Double)
            case float(Float)

            case array(ContiguousArray<Reference>)
            // Ordered, because some clients are expecting some level of stability from binary plist encoding
#if canImport(CollectionsInternal) || canImport(OrderedCollections) || canImport(_FoundationCollections)
            case dictionary(OrderedDictionary<Reference,Reference>)
#else
            case dictionary(Dictionary<Reference,Reference>)
#endif

            case dateAsTimeInterval(Double)
            case data(Data)
        }
        
        var backing: Backing
        
        // To avoid additional hash table lookups, we'll cheat and store the binary plist objectRef index right in line with the reference.
        var bplistObjectIdx : Int
        
        init(_ backing: Backing) {
            self.backing = backing
            self.bplistObjectIdx = -1
        }

        static var emptyArray: Reference {
            .init(.array([]))
        }
        
        static var emptyDictionary: Reference {
            .init(.dictionary([:]))
        }
        
        func insert(_ ref: Reference, for key: Reference) {
            guard case .dictionary(var dict) = backing else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            backing = .null
            dict[key] = ref
            backing = .dictionary(dict)
        }
        
        func insert(_ ref: Reference, at index: Int) {
            guard case .array(var array) = backing else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            backing = .null
            array.insert(ref, at: index)
            backing = .array(array)
        }
        
        func insert(_ ref: Reference) {
            guard case .array(var array) = backing else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            backing = .null
            array.append(ref)
            backing = .array(array)
        }
        
        var count: Int {
            switch backing {
            case .array(let array): return array.count
            case .dictionary(let dict): return dict.count
            default: preconditionFailure("Wrong underlying plist reference type")
            }
        }
        
        subscript(key: Reference) -> Reference? {
            guard case .dictionary(let dict) = backing else {
                preconditionFailure("Wrong underlying plist reference type")
            }
            return dict[key]
        }
        
        var isBool: Bool {
            switch backing {
            case .true, .false: return true
            default: return false
            }
        }
        
        var isString: Bool {
            switch backing {
            case .string: return true
            case .null: return true // nulls are encoded as strings
            default: return false
            }
        }
        
        var isNumber: Bool {
            switch backing {
            case .double, .float, .uint64, .shorterOrSignedInteger:
                return true
            default:
                return false
            }
        }
        
        var isDate: Bool {
            guard case .dateAsTimeInterval = backing else { return false }
            return true
        }
        
        var isDictionary: Bool {
            guard case .dictionary = backing else { return false }
            return true
        }
        
        var isArray: Bool {
            guard case .array = backing else { return false }
            return true
        }
    }
    
    struct Writer : PlistWriting {
        enum Marker : UInt8 {
            case `false` = 0x08
            case `true` = 0x09
            case int = 0x10
            case real = 0x20
            case date = 0x33
            case data = 0x40
            case asciiString = 0x50
            case utf16String = 0x60
            case array = 0xA0
            case dict = 0xD0
        }
        
        var objectOffsets = [Int]()
        var objectRefSize: UInt8 = 0
        
        static let scratchBufferSize = 8192
        var scratchBuffer: UnsafeMutableBufferPointer<UInt8>
        var scratchUsed: Int = 0
        
        var data = Data()
        
        init() {
            scratchBuffer = UnsafeMutableBufferPointer.allocate(capacity: Self.scratchBufferSize)
        }
        
        mutating func serializePlist(_ ref: Reference) throws -> Data {
            defer {
                scratchBuffer.deallocate()
            }
            
            var objectCount = 0
            flattenPlist(ref, &objectCount)
            
            // The objectRefSize is always exactly small enough to hold to the index of the last object.
            objectRefSize = objectCount.minimumRepresentableByteSize
            
            write("bplist00")
            append(ref)
            
            // Similarly, the offsetIntSize is always exactly small enough to hold the offset to the last object.
            let lengthSoFar = currentOffset
            let tableOffset = UInt64(lengthSoFar)
            let offsetIntSize = lengthSoFar.minimumRepresentableByteSize
            
            for offset in objectOffsets {
                write(offset, byteSize: offsetIntSize)
            }
            
            let trailer = BPlistTrailer(
                _unused: (0,0,0,0,0),
                _sortVersion: 0,
                _offsetIntSize: offsetIntSize,
                _objectRefSize: objectRefSize,
                _numObjects: UInt64(objectOffsets.count).bigEndian,
                _topObject: 0,
                _offsetTableOffset: tableOffset.bigEndian)

            withUnsafeBytes(of: trailer) { trailerBuf in
                trailerBuf.withMemoryRebound(to: UInt8.self) { uint8Buf in
                    write(uint8Buf)
                }
            }
            flush()
            
            return data
        }
        
        // The goal of this function is to assign pre-order reference indexes to each object. We have to do this pass before actually writing out all the values because directories and arrays contents are encoded with the indexes of objects that are persisted *after* them (unless they were uniqued previously).
        private mutating func flattenPlist(_ ref: Reference, _ objectCount: inout Int) {
            switch ref.backing {
            case .array(let array):
                ref.bplistObjectIdx = objectCount
                objectCount += 1

                for ref in array {
                    flattenPlist(ref, &objectCount)
                }
            case .dictionary(let dict):
                ref.bplistObjectIdx = objectCount
                objectCount += 1
                
                for key in dict.keys {
                    flattenPlist(key, &objectCount)
                }
                for val in dict.values {
                    flattenPlist(val, &objectCount)
                }
            default:
                // Uniqued objects might have already been assigned an index.
                if ref.bplistObjectIdx == -1 {
                    ref.bplistObjectIdx = objectCount
                    objectCount += 1
                }
            }
        }
        
        var currentOffset : Int {
            data.count + scratchUsed
        }
        
        mutating func append(_ ref: Reference) {
            // Is it this reference's turn to be written? We may see references that were already written in the past, but we should never see future references.
            guard ref.bplistObjectIdx == objectOffsets.count else {
                assert(ref.bplistObjectIdx < objectOffsets.count)
                return
            }
            objectOffsets.append(currentOffset)
            
            switch ref.backing {
            case .null: append(_plistNullString, isASCII: true)
            case let .string(val, _, isASCII): append(val, isASCII: isASCII)
            case let .uint64(val): append(val)
            case let .shorterOrSignedInteger(val): append(val)
            case let .float(val): append(val)
            case let .double(val): append(val)
            case .true: appendTrue()
            case .false: appendFalse()
            case let .data(val): append(val)
            case let .dateAsTimeInterval(val): append(date: val)
            case let .dictionary(dict): append(dict)
            case let .array(array): append(array)
            }
        }
        
        mutating func write(_ buf: UnsafeBufferPointer<UInt8>) {
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
        
        mutating func write(_ byte: UInt8) {
            if scratchUsed == Self.scratchBufferSize {
                flush()
            }
            scratchBuffer[scratchUsed] = byte
            scratchUsed += 1
        }
        
        mutating func flush() {
            guard scratchUsed > 0 else { return }
            data.append(UnsafeBufferPointer(rebasing: scratchBuffer[..<scratchUsed]))
            scratchUsed = 0
        }
        
        mutating func write<T: FixedWidthInteger>(sizedInteger: T) {
            let bigEndian = sizedInteger.bigEndian
            withUnsafeBytes(of: bigEndian) { buf in
                buf.withMemoryRebound(to: UInt8.self) { uint8Buf in
                    write(uint8Buf)
                }
            }
        }
        
        mutating func write<T: FixedWidthInteger>(_ integer: T, byteSize: UInt8) {
            let bigEndian = integer.bigEndian
            withUnsafeBytes(of: bigEndian) { buf in
                buf.withMemoryRebound(to: UInt8.self) { uint8Buf in
                    let startingByteOffset = uint8Buf.count - Int(byteSize)
                    write(UnsafeBufferPointer(rebasing: uint8Buf[startingByteOffset...]))
                }
            }
        }
        
        mutating func write(objectRef: UInt32) {
            write(objectRef, byteSize: objectRefSize)
        }
        
        mutating func write(_ str: StaticString) {
            str.withUTF8Buffer { buf in
                self.write(buf)
            }
        }
        
        mutating func append(_ marker: Marker, count: Int) {
            var markerByte = marker.rawValue
            let separateCountInteger : Bool
            if count < 15 {
                separateCountInteger = false
                markerByte |= UInt8(count)
            } else {
                separateCountInteger = true
                markerByte |= 0xf
            }
            write(markerByte)
            if separateCountInteger {
                append(count)
            }
        }
        
        mutating func write(_ marker: Marker, subtype: UInt8 = 0) {
            var markerByte = marker.rawValue
            markerByte |= subtype
            write(markerByte)
        }
        
        mutating func append(_ str: String, isASCII: Bool) {
            if isASCII {
                var mutableStr = str
                mutableStr.withUTF8 {
                    append(.asciiString, count: $0.count)
                    write($0)
                }
                return
            }
            
            let utf16BEData = str.data(using: .utf16BigEndian)!
            append(.utf16String, count: utf16BEData.count / MemoryLayout<UInt16>.size)
            utf16BEData.withUnsafeBytes { buf in
                buf.withMemoryRebound(to: UInt8.self) { uint8Buf in
                    write(uint8Buf)
                }
            }
        }
        
        mutating func append(_ uint: UInt64) {
            // UInt64s were derived from kCFNumberSInt128Type CFNumbers, where the high bits always ended up 0.
            write(.int, subtype: 4)
            write(sizedInteger: UInt64(0))
            write(sizedInteger: uint)
        }
        
        mutating func append(_ int: Int64) {
            let asUnsigned = UInt64(bitPattern: int)
            if asUnsigned <= 0xff {
                write(.int, subtype: 0)
                write(sizedInteger: UInt8(asUnsigned))
            } else if asUnsigned <= 0xffff {
                write(.int, subtype: 1)
                write(sizedInteger: UInt16(asUnsigned))
            } else if asUnsigned <= 0xffffffff {
                write(.int, subtype: 2)
                write(sizedInteger: UInt32(asUnsigned))
            } else {
                write(.int, subtype: 3)
                write(sizedInteger: asUnsigned)
            }
        }
        
        mutating func append(_ float: Float) {
            write(.real, subtype: 2)
            write(sizedInteger: float.bitPattern)
        }
        
        mutating func append(_ double: Double) {
            write(.real, subtype: 3)
            write(sizedInteger: double.bitPattern)
        }
        
        mutating func append(_ int: Int) {
            append(Int64(int))
        }
        
        mutating func appendTrue() {
            write(Marker.true)
        }
        
        mutating func appendFalse() {
            write(Marker.false)
        }
        
        mutating func append(_ data: Data) {
            append(.data, count: data.count)
            data.withUnsafeBytes { buf in
                buf.withMemoryRebound(to: UInt8.self) { uint8Buf in
                    write(uint8Buf)
                }
            }
        }
        
        mutating func append(date dateAsTimeInterval: Double) {
            write(.date)
            write(sizedInteger: dateAsTimeInterval.bitPattern)
        }

#if canImport(CollectionsInternal) || canImport(OrderedCollections) || canImport(_FoundationCollections)
        mutating func append(_ dictionary: OrderedDictionary<Reference,Reference>) {
            // First write the indexes of the dictionary contents, then write the actual contents to the output in a pre-order traversal.
            append(.dict, count: dictionary.count)
            for key in dictionary.keys {
                let keyIdx = key.bplistObjectIdx
                write(objectRef: UInt32(keyIdx))
            }
            for val in dictionary.values {
                let valIdx = val.bplistObjectIdx
                write(objectRef: UInt32(valIdx))
            }
            
            for key in dictionary.keys {
                append(key)
            }
            for val in dictionary.values {
                append(val)
            }
        }
#else
        mutating func append(_ dictionary: Dictionary<Reference,Reference>) {
            // First write the indexes of the dictionary contents, then write the actual contents to the output in a pre-order traversal.
            append(.dict, count: dictionary.count)
            for key in dictionary.keys {
                let keyIdx = key.bplistObjectIdx
                write(objectRef: UInt32(keyIdx))
            }
            for val in dictionary.values {
                let valIdx = val.bplistObjectIdx
                write(objectRef: UInt32(valIdx))
            }

            for key in dictionary.keys {
                append(key)
            }
            for val in dictionary.values {
                append(val)
            }
        }
#endif

        mutating func append(_ array: ContiguousArray<Reference>) {
            // First write the indexes of the array contents, the write the actual contents to the output in a pre-order traversal.
            append(.array, count: array.count)
            for val in array {
                let valIdx = val.bplistObjectIdx
                write(objectRef: UInt32(valIdx))
            }
            
            for val in array {
                append(val)
            }
        }
    }
    
    let null = Reference(.null)
    let `true` = Reference(.true)
    let `false` = Reference(.false)
    
    var uniquingSet = Set<Reference>()
    var uniquingTester = Reference(.null)
    init() {
        
    }
    
    @inline(__always)
    private mutating func unique(_ backing: Reference.Backing) -> Reference {
        uniquingTester.backing = backing
        let (inserted, member) = uniquingSet.insert(uniquingTester)
        if (inserted) {
            // The set consumed the old uniquingTester. Create a new one for next time.
            uniquingTester = Reference(.null)
        }
        return member
    }
    
    mutating func string(_ str: String) -> Reference {
        // TODO: Having the ability to quickly determine if a string contains all ASCII content (especially if stored as a property of the string) would greatly improve encoding performance.
        // TODO: The string's hash code is computed up front here because otherwise it is recomputed very often while uniquing values. There might be a better way to do this.
        // TODO: Swift.String.hashValue or .hash(into:) for NSString-backed Strings is surprisingly slow because the entire contents of the string are hashed by individual -characterAtIndex: calls, as opposed to a single -getCharacters:range: call. NSString.hash is currently much faster on NSStrings so we'd prefer to call it instead. The "allASCII" state is a very poor approximation for "is this an NSString-backed-String" (because currently decoding a UTF-16 BE string from a binary plist with PropertyListDecoder results in an NSString-backed String, while ASCII strings are Swift.String). The "allASCII" state is important later for determining how we encode the string, per the bplist format.
        let backing: Reference.Backing
        let allASCII = str.utf8.allSatisfy(UTF8.isASCII)
        if allASCII {
            backing = .string(str, hash: str.hashValue, isASCII: true)
        } else {
#if FOUNDATION_FRAMEWORK
            // NSString-backed Strings are only present on Darwin in the framework build
            backing = .string(str, hash: (str as NSString).hash, isASCII: false)
#else
            backing = .string(str, hash: str.hashValue, isASCII: false)
#endif
        }
        
        return unique(backing)
    }
       
    mutating func number<T: FixedWidthInteger>(from num: T) -> Reference {
        let backing: Reference.Backing
        if T.isSigned || T.bitWidth < UInt64.bitWidth {
            backing = .shorterOrSignedInteger(Int64(num))
        } else {
            backing = .uint64(UInt64(num))
        }
        
        return unique(backing)
    }
    
    mutating func number<T: BinaryFloatingPoint>(from num: T) -> Reference {
        let backing: Reference.Backing
        if T.self == Float.self {
            backing = .float(Float(num))
        } else {
            backing = .double(Double(num))
        }
        
        return unique(backing)
    }
    
    mutating func date(_ date: Date) -> Reference {
        return unique(.dateAsTimeInterval(date.timeIntervalSinceReferenceDate))
    }
    
    mutating func data(_ data: Data) -> Reference {
        return unique(.data(data))
    }
}

extension _BPlistEncodingFormat.Reference : Hashable {
    static func == (lhs: _BPlistEncodingFormat.Reference, rhs: _BPlistEncodingFormat.Reference) -> Bool {
        switch (lhs.backing, rhs.backing) {
        case let (.string(lh, _, lhIsASCII), .string(rh, _, rhIsASCII)):
            if lhIsASCII, rhIsASCII {
                return lh == rh
            } else if !lhIsASCII && !rhIsASCII {
#if FOUNDATION_FRAMEWORK
            // NSString-backed Strings are only present on Darwin in the framework build
                return (lh as NSString) == (rh as NSString)
#else
                return lh == rh
#endif                
            } else {
                return false
            }
        case let (.uint64(lh), .uint64(rh)):
            return lh == rh
        case let (.shorterOrSignedInteger(lh), .shorterOrSignedInteger(rh)):
            return lh == rh
        case let (.double(lh), .double(rh)):
            return lh == rh || (lh.isNaN && rh.isNaN)
        case let (.float(lh), .float(rh)):
            return lh == rh || (lh.isNaN && rh.isNaN)
        case let (.dateAsTimeInterval(lh), .dateAsTimeInterval(rh)):
            return lh == rh
        case let (.data(lh), .data(rh)):
            return lh == rh
        default:
            // Any combination of mis-matched types will be treated as unequal.
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch backing {
        case let .string(_, hash, _):
            hasher.combine(hash)
        case let .uint64(val):
            hasher.combine(val)
        case let .shorterOrSignedInteger(val):
            hasher.combine(val)
        case let .double(val):
            hasher.combine(val)
        case let .float(val):
            hasher.combine(val)
        case let .dateAsTimeInterval(val):
            hasher.combine(val)
        case let .data(val):
            hasher.combine(val)
        default:
            fatalError("This type isn't meant to be uniqued and therefore doesn't implement hashing: \(backing)")
        }
    }
}

extension FixedWidthInteger {
    fileprivate var minimumRepresentableByteSize : UInt8 {
        let leadingZeroBytes = self.leadingZeroBitCount / 8
        return UInt8(self.bitWidth/8 - leadingZeroBytes)
    }
}
