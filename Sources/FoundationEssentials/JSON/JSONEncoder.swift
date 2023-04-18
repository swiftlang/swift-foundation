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

/// A marker protocol used to determine whether a value is a `String`-keyed `Dictionary`
/// containing `Encodable` values (in which case it should be exempt from key conversion strategies).
private protocol _JSONStringDictionaryEncodableMarker { }

extension Dictionary : _JSONStringDictionaryEncodableMarker where Key == String, Value: Encodable { }

//===----------------------------------------------------------------------===//
// JSON Encoder
//===----------------------------------------------------------------------===//

/// `JSONEncoder` facilitates the encoding of `Encodable` values into JSON.
// NOTE: older overlays had Foundation.JSONEncoder as the ObjC name.
// The two must coexist, so it was renamed. The old name must not be
// used in the new runtime. _TtC10Foundation13__JSONEncoder is the
// mangled name for Foundation.__JSONEncoder.
#if FOUNDATION_FRAMEWORK
@_objcRuntimeName(_TtC10Foundation13__JSONEncoder)
#endif
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
open class JSONEncoder {
    // MARK: Options

    /// The formatting of the output JSON data.
    public struct OutputFormatting : OptionSet, Sendable {
        /// The format's default value.
        public let rawValue: UInt

        /// Creates an OutputFormatting value with the given raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Produce human-readable JSON with indented output.
        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)

#if FOUNDATION_FRAMEWORK
        // TODO: Reenable once String.compare is implemented

        /// Produce JSON with dictionary keys sorted in lexicographic order.
        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)
#endif // FOUNDATION_FRAMEWORK

        /// By default slashes get escaped ("/" → "\/", "http://apple.com/" → "http:\/\/apple.com\/")
        /// for security reasons, allowing outputted JSON to be safely embedded within HTML/XML.
        /// In contexts where this escaping is unnecessary, the JSON is known to not be embedded,
        /// or is intended only for display, this option avoids this escaping.
        @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
        public static let withoutEscapingSlashes = OutputFormatting(rawValue: 1 << 3)
    }

    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy : Sendable {
        /// Defer to `Date` for choosing an encoding. This is the default strategy.
        case deferredToDate

        /// Encode the `Date` as a UNIX timestamp (as a JSON number).
        case secondsSince1970

        /// Encode the `Date` as UNIX millisecond timestamp (as a JSON number).
        case millisecondsSince1970

#if FOUNDATION_FRAMEWORK // TODO: Reenable once DateFormatStyle has been ported
        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)
#endif // FOUNDATION_FRAMEWORK

        /// Encode the `Date` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        @preconcurrency
        case custom(@Sendable (Date, Encoder) throws -> Void)
    }

    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy : Sendable {
        /// Defer to `Data` for choosing an encoding.
        case deferredToData

        /// Encoded the `Data` as a Base64-encoded string. This is the default strategy.
        case base64

        /// Encode the `Data` as a custom value encoded by the given closure.
        ///
        /// If the closure fails to encode a value into the given encoder, the encoder will encode an empty automatic container in its place.
        @preconcurrency
        case custom(@Sendable (Data, Encoder) throws -> Void)
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatEncodingStrategy : Sendable {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for automatically changing the value of keys before encoding.
    public enum KeyEncodingStrategy : Sendable {
        /// Use the keys specified by each type. This is the default strategy.
        case useDefaultKeys

        /// Convert from "camelCaseKeys" to "snake_case_keys" before writing a key to JSON payload.
        ///
        /// Capital characters are determined by testing membership in Unicode General Categories Lu and Lt.
        /// The conversion to lower case uses `Locale.system`, also known as the ICU "root" locale. This means the result is consistent regardless of the current user's locale and language preferences.
        ///
        /// Converting from camel case to snake case:
        /// 1. Splits words at the boundary of lower-case to upper-case
        /// 2. Inserts `_` between words
        /// 3. Lowercases the entire string
        /// 4. Preserves starting and ending `_`.
        ///
        /// For example, `oneTwoThree` becomes `one_two_three`. `_oneTwoThree_` becomes `_one_two_three_`.
        ///
        /// - Note: Using a key encoding strategy has a nominal performance cost, as each string key has to be converted.
        case convertToSnakeCase

        /// Provide a custom conversion to the key in the encoded JSON from the keys specified by the encoded types.
        /// The full path to the current encoding position is provided for context (in case you need to locate this key within the payload). The returned key is used in place of the last component in the coding path before encoding.
        /// If the result of the conversion is a duplicate key, then only one value will be present in the result.
        @preconcurrency
        case custom(@Sendable (_ codingPath: [CodingKey]) -> CodingKey)

        fileprivate static func _convertToSnakeCase(_ stringKey: String) -> String {
            guard !stringKey.isEmpty else { return stringKey }

            var words : [Range<String.Index>] = []
            // The general idea of this algorithm is to split words on transition from lower to upper case, then on transition of >1 upper case characters to lowercase
            //
            // myProperty -> my_property
            // myURLProperty -> my_url_property
            //
            // We assume, per Swift naming conventions, that the first character of the key is lowercase.
            var wordStart = stringKey.startIndex
            var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex

            // Find next uppercase character
            while let upperCaseRange = stringKey[searchRange]._rangeOfCharacter(from: BuiltInUnicodeScalarSet.uppercaseLetters, options: []) {
                let untilUpperCase = wordStart..<upperCaseRange.lowerBound
                words.append(untilUpperCase)

                // Find next lowercase character
                searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
                guard let lowerCaseRange = stringKey[searchRange]._rangeOfCharacter(from: BuiltInUnicodeScalarSet.lowercaseLetters, options: []) else {
                    // There are no more lower case letters. Just end here.
                    wordStart = searchRange.lowerBound
                    break
                }

                // Is the next lowercase letter more than 1 after the uppercase? If so, we encountered a group of uppercase letters that we should treat as its own word
                let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
                if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                    // The next character after capital is a lower case character and therefore not a word boundary.
                    // Continue searching for the next upper case for the boundary.
                    wordStart = upperCaseRange.lowerBound
                } else {
                    // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                    let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                    words.append(upperCaseRange.lowerBound..<beforeLowerIndex)

                    // Next word starts at the capital before the lowercase we just found
                    wordStart = beforeLowerIndex
                }
                searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
            }
            words.append(wordStart..<searchRange.upperBound)
            let result = words.map({ (range) in
                return stringKey[range].lowercased()
            }).joined(separator: "_")
            return result
        }
    }

    /// The output format to produce. Defaults to `[]`.
    open var outputFormatting: OutputFormatting {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.outputFormatting
        }
        _modify {
            optionsLock.lock()
            var value = options.outputFormatting
            defer {
                options.outputFormatting = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.outputFormatting = newValue
        }
    }

    /// The strategy to use in encoding dates. Defaults to `.deferredToDate`.
    open var dateEncodingStrategy: DateEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dateEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dateEncodingStrategy
            defer {
                options.dateEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dateEncodingStrategy = newValue
        }
    }

    /// The strategy to use in encoding binary data. Defaults to `.base64`.
    open var dataEncodingStrategy: DataEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.dataEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.dataEncodingStrategy
            defer {
                options.dataEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.dataEncodingStrategy = newValue
        }
    }

    /// The strategy to use in encoding non-conforming numbers. Defaults to `.throw`.
    open var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.nonConformingFloatEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.nonConformingFloatEncodingStrategy
            defer {
                options.nonConformingFloatEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.nonConformingFloatEncodingStrategy = newValue
        }
    }

    /// The strategy to use for encoding keys. Defaults to `.useDefaultKeys`.
    open var keyEncodingStrategy: KeyEncodingStrategy {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.keyEncodingStrategy
        }
        _modify {
            optionsLock.lock()
            var value = options.keyEncodingStrategy
            defer {
                options.keyEncodingStrategy = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.keyEncodingStrategy = newValue
        }
    }

    /// Contextual user-provided information for use during encoding.
    open var userInfo: [CodingUserInfoKey : Any] {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.userInfo
        }
        _modify {
            optionsLock.lock()
            var value = options.userInfo
            defer {
                options.userInfo = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.userInfo = newValue
        }
    }

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    fileprivate struct _Options {
        var outputFormatting: OutputFormatting = []
        var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
        var dataEncodingStrategy: DataEncodingStrategy = .base64
        var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw
        var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
        var userInfo: [CodingUserInfoKey : Any] = [:]
    }

    /// The options set on the top-level encoder.
    fileprivate var options = _Options()
    fileprivate let optionsLock = LockedState<Void>()

    // MARK: - Constructing a JSON Encoder

    /// Initializes `self` with default strategies.
    public init() {}


    // MARK: - Encoding Values

    /// Encodes the given top-level value and returns its JSON representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded JSON data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<T : Encodable>(_ value: T) throws -> Data {
        let encoder = __JSONEncoder(options: self.options, initialDepth: 0)

        guard let topLevel = try encoder.wrapGeneric(value, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }

        let writingOptions = JSONWriter.WritingOptions(rawValue: self.outputFormatting.rawValue).union(.fragmentsAllowed)
        do {
            var writer = JSONWriter(options: writingOptions)
            try writer.serializeJSON(topLevel)
            return writer.data
        } catch let error as JSONError {
            #if FOUNDATION_FRAMEWORK
            let underlyingError: Error? = error.nsError
            #else
            let underlyingError: Error? = nil
            #endif // FOUNDATION_FRAMEWORK
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value to JSON.", underlyingError: underlyingError))
        }
    }
}

// MARK: - __JSONEncoder

// NOTE: older overlays called this class _JSONEncoder.
// The two must coexist without a conflicting ObjC class name, so it
// was renamed. The old name must not be used in the new runtime.
private class __JSONEncoder : Encoder {
    // MARK: Properties

    /// The encoder's storage.
    var storage: _JSONEncodingStorage

    /// Options set on the top-level encoder.
    let options: JSONEncoder._Options

    var encoderCodingPathNode: _JSONCodingPathNode
    var codingPathDepth: Int

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey] {
        encoderCodingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    init(options: JSONEncoder._Options, codingPathNode: _JSONCodingPathNode = .root, initialDepth: Int) {
        self.options = options
        self.storage = _JSONEncodingStorage()
        self.encoderCodingPathNode = codingPathNode
        self.codingPathDepth = initialDepth
    }

    /// Returns whether a new element can be encoded at this coding path.
    ///
    /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
    var canEncodeNewValue: Bool {
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
        let topWritable: _JSONEncodingStorage.Writable
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topWritable = self.storage.pushKeyedContainer()
        } else {
            guard let writable = self.storage.writables.last, writable.isObject else {
                preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
            }
            topWritable = writable
        }

        let container = _JSONKeyedEncodingContainer<Key>(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topWritable)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        let topWritable: _JSONEncodingStorage.Writable
        if self.canEncodeNewValue {
            // We haven't yet pushed a container at this level; do so here.
            topWritable = self.storage.pushUnkeyedContainer()
        } else {
            guard let writable = self.storage.writables.last, writable.isArray else {
                preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
            }
            topWritable = writable
        }

        return _JSONUnkeyedEncodingContainer(referencing: self, codingPathNode: self.encoderCodingPathNode, wrapping: topWritable)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }

    // Instead of creating a new __JSONEncoder for passing to methods that take Encoder arguments, wrap the access in this method, which temporarily mutates this __JSONEncoder instance with the additional nesting depth and its coding path.
    @inline(__always)
    func with<T>(path: _JSONCodingPathNode?, perform closure: () throws -> T) rethrows -> T {
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

private struct _JSONEncodingStorage {
    // MARK: Properties

    class Writable {
        enum Entry {
            case value(JSONValue)
            case writableReference(Writable)

            @inline(__always)
            var value: JSONValue {
                switch self {
                case .value(let v):
                    return v
                case .writableReference(let writable):
                    return writable.value
                }
            }
        }

        enum Backing {
            case array([Entry])
            case object([String:Entry])
            case singleValue(JSONValue)
        }
        var backing: Backing

        @inline(__always)
        func encode(_ value: JSONValue, for key: String) {
            switch backing {
            case .object(var dict):
                // Newly encoded values ALWAYS take precedence over any collection references that might have been inserted previously.
                dict[key] = .value(value)
                self.backing = .object(dict)
            default:
                preconditionFailure("Wrong underlying JSON writable type")
            }
        }

        @inline(__always)
        func insert(_ writable: Writable, for key: String) {
            switch backing {
            case .object(var object):
                if let _ = object.updateValue(.writableReference(writable), forKey: key) {
                    preconditionFailure("Previous entry replaced by reference for key \(key)")
                }
                backing = .object(object)
            default:
                preconditionFailure("Wrong underlying JSON writable type")
            }
        }

        @inline(__always)
        func encode(_ value: JSONValue) {
            switch backing {
            case .array(var array):
                array.append(.value(value))
                backing = .array(array)
            default:
                preconditionFailure("Wrong undlying JSON writable type")
            }
        }

        @inline(__always)
        func encode(_ value: JSONValue, insertedAt index: Int) {
            switch backing {
            case .array(var array):
                array.insert(.value(value), at: index)
                backing = .array(array)
            default:
                preconditionFailure("Wrong undlying JSON writable type")
            }
        }

        @inline(__always)
        func insert(_ writable: Writable) {
            switch backing {
            case .array(var array):
                array.append(.writableReference(writable))
                backing = .array(array)
            default:
                preconditionFailure("Wrong undlying JSON writable type")
            }
        }

        @inline(__always)
        var count: Int {
            switch backing {
            case .array(let array): return array.count
            case .object(let dict): return dict.count
            case .singleValue: return 1
            }
        }

        @inline(__always)
        init(_ backing: Backing) {
            self.backing = backing
        }

        @inline(__always)
        internal var value: JSONValue {
            switch backing {
            case .object(let dict):
                var valueDict = [String:JSONValue]()
                for (key, entry) in dict {
                    valueDict[key] = entry.value
                }
                return .object(valueDict)
            case .array(let array):
                return .array(array.map(\.value))
            case .singleValue(let value):
                return value
            }
        }

        // This mutates the backing because we might need to turn an object or array value back into a Writable reference.
        @inline(__always)
        func getWritable(for key: String) -> Writable? {
            switch backing {
            case .object(var backingDict):
                switch backingDict[key] {
                case .writableReference(let writable):
                    return writable
                case .value(let value):
                    switch value {
                    case .array(let arrayValue):
                        let newWritable = Writable(.array(arrayValue.map { Entry.value($0) }))
                        backingDict[key] = .writableReference(newWritable)
                        backing = .object(backingDict)
                        return newWritable
                    case .object(let dictValue):
                        var newDict = [String:Entry](minimumCapacity: dictValue.count)
                        for (key, value) in dictValue {
                            newDict[key] = Entry.value(value)
                        }
                        let newWritable = Writable(.object(newDict))
                        backingDict[key] = .writableReference(newWritable)
                        backing = .object(backingDict)
                        return newWritable
                    default: return nil
                    }
                case .none:
                    return nil
                }
            default:
                preconditionFailure("Wrong undlying JSON writable type")
            }
        }

        @inline(__always)
        subscript (_ index: Int) -> Writable? {
            switch backing {
            case .array(let array):
                guard case let .writableReference(writable) = array[index] else {
                    return nil
                }
                return writable
            default:
                preconditionFailure("Wrong undlying JSON writable type")
            }
        }

        @inline(__always)
        var isObject: Bool {
            guard case .object = backing else {
                return false
            }
            return true
        }

        @inline(__always)
        var isArray: Bool {
            guard case .array = backing else {
                return false
            }
            return true
        }
    }

    var writables = [Writable]()

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    init() {}

    // MARK: - Modifying the Stack

    var count: Int {
        return self.writables.count
    }

    mutating func pushKeyedContainer() -> Writable {
        let object = Writable(.object([:]))
        self.writables.append(object)
        return object
    }

    mutating func pushUnkeyedContainer() -> Writable {
        let object = Writable(.array([]))
        self.writables.append(object)
        return object
    }

    mutating func push(writable: __owned Writable) {
        self.writables.append(writable)
    }

    mutating func popWritable() -> Writable {
        precondition(!self.writables.isEmpty, "Empty writable stack.")
        return self.writables.popLast().unsafelyUnwrapped
    }
}

// MARK: - Encoding Containers

private struct _JSONKeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __JSONEncoder

    private let writable: _JSONEncodingStorage.Writable
    private let codingPathNode: _JSONCodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    public var codingPath: [CodingKey] {
        codingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    init(referencing encoder: __JSONEncoder, codingPathNode: _JSONCodingPathNode, wrapping writable: _JSONEncodingStorage.Writable) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.writable = writable
    }

    // MARK: - Coding Path Operations

    private func _converted(_ key: CodingKey) -> String {
        switch encoder.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            let newKeyString = JSONEncoder.KeyEncodingStrategy._convertToSnakeCase(key.stringValue)
            return newKeyString
        case .custom(let converter):
            return converter(codingPathNode.path(with: key)).stringValue
        }
    }

    // MARK: - KeyedEncodingContainerProtocol Methods

    public mutating func encodeNil(forKey key: Key) throws {
        writable.encode(.null, for: _converted(key))
    }
    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: String, forKey key: Key) throws {
        writable.encode(self.encoder.wrap(value), for: _converted(key))
    }

    public mutating func encode(_ value: Float, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, key)
        writable.encode(wrapped, for: _converted(key))
    }

    public mutating func encode(_ value: Double, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, key)
        writable.encode(wrapped, for: _converted(key))
    }

    public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, key)
        writable.encode(wrapped, for: _converted(key))
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let containerKey = _converted(key)
        let writable: _JSONEncodingStorage.Writable
        if let existingWritable = self.writable.getWritable(for: containerKey) {
            precondition(
                existingWritable.isObject,
                "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key"
            )
            writable = existingWritable
        } else {
            writable = _JSONEncodingStorage.Writable(.object([:]))
            self.writable.insert(writable, for: containerKey)
        }

        let container = _JSONKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.pushing(key), wrapping: writable)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let containerKey = _converted(key)
        let writable: _JSONEncodingStorage.Writable
        if let existingWritable = self.writable.getWritable(for: containerKey) {
            precondition(
                existingWritable.isArray,
                "Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(containerKey)\" is invalid: keyed container/single value already encoded for this key"
            )
            writable = existingWritable
        } else {
            writable = _JSONEncodingStorage.Writable(.array([]))
            self.writable.insert(writable, for: containerKey)
        }

        return _JSONUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.pushing(key), wrapping: writable)
    }

    public mutating func superEncoder() -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, key: _JSONKey.super, convertedKey: _converted(_JSONKey.super), codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.writable)
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, key: key, convertedKey: _converted(key), codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.writable)
    }
}

private struct _JSONUnkeyedEncodingContainer : UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __JSONEncoder

    private let writable: _JSONEncodingStorage.Writable
    private let codingPathNode: _JSONCodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    public var codingPath: [CodingKey] {
        codingPathNode.path
    }

    /// The number of elements encoded into the container.
    public var count: Int {
        self.writable.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    init(referencing encoder: __JSONEncoder, codingPathNode: _JSONCodingPathNode, wrapping writable: _JSONEncodingStorage.Writable) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.writable = writable
    }

    // MARK: - UnkeyedEncodingContainer Methods

    public mutating func encodeNil()             throws { self.writable.encode(.null) }
    public mutating func encode(_ value: Bool)   throws { self.writable.encode(.bool(value)) }
    public mutating func encode(_ value: Int)    throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int8)   throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int16)  throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int32)  throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int64)  throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt)   throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt8)  throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt16) throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt32) throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt64) throws { self.writable.encode(self.encoder.wrap(value)) }
    public mutating func encode(_ value: String) throws { self.writable.encode(self.encoder.wrap(value)) }

    public mutating func encode(_ value: Float)  throws {
        self.writable.encode(try JSONValue.number(from: value, with: encoder.options.nonConformingFloatEncodingStrategy, for: self.encoder.encoderCodingPathNode, _JSONKey(index: self.count)))
    }

    public mutating func encode(_ value: Double) throws {
        self.writable.encode(try JSONValue.number(from: value, with: encoder.options.nonConformingFloatEncodingStrategy, for: self.encoder.encoderCodingPathNode, _JSONKey(index: self.count)))
    }

    public mutating func encode<T : Encodable>(_ value: T) throws {
        let wrapped = try self.encoder.wrap(value, for: self.encoder.encoderCodingPathNode, _JSONKey(index: self.count))
        self.writable.encode(wrapped)
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let key = _JSONKey(index: self.count)
        let writable = _JSONEncodingStorage.Writable(.object([:]))
        self.writable.insert(writable)
        let container = _JSONKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.pushing(key), wrapping: writable)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = _JSONKey(index: self.count)
        let writable = _JSONEncodingStorage.Writable(.array([]))
        self.writable.insert(writable)
        return _JSONUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.pushing(key), wrapping: writable)
    }

    public mutating func superEncoder() -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, at: self.writable.count, codingPathNode: self.encoder.encoderCodingPathNode, wrapping: self.writable)
    }
}

extension __JSONEncoder : SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    private func assertCanEncodeNewValue() {
        precondition(self.canEncodeNewValue, "Attempt to encode value through single value container when previously value already encoded.")
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(.null)))
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(.bool(value))))
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.storage.push(writable: .init(.singleValue(wrap(value))))
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        let wrapped = try self.wrap(value, for: self.encoderCodingPathNode)
        self.storage.push(writable: .init(.singleValue(wrapped)))
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        let wrapped = try self.wrap(value, for: self.encoderCodingPathNode)
        self.storage.push(writable: .init(.singleValue(wrapped)))
    }

    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        try self.storage.push(writable: .init(.singleValue(self.wrap(value, for: self.encoderCodingPathNode))))
    }
}

// MARK: - Concrete Value Representations

private extension __JSONEncoder {
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    @inline(__always) func wrap(_ value: Bool)   -> JSONValue { JSONValue.bool(value) }
    @inline(__always) func wrap(_ value: Int)    -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: Int8)   -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: Int16)  -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: Int32)  -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: Int64)  -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: UInt)   -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: UInt8)  -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: UInt16) -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: UInt32) -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: UInt64) -> JSONValue { JSONValue.number(from: value) }
    @inline(__always) func wrap(_ value: String) -> JSONValue { .string(value) }

    @inline(__always)
    func wrap(_ float: Float, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue {
        try JSONValue.number(from: float, with: self.options.nonConformingFloatEncodingStrategy, for: codingPathNode, additionalKey)
    }

    @inline(__always)
    func wrap(_ double: Double, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue {
        try JSONValue.number(from: double, with: self.options.nonConformingFloatEncodingStrategy, for: codingPathNode, additionalKey)
    }

    func wrap(_ date: Date, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue {
        switch self.options.dateEncodingStrategy {
        case .deferredToDate:
            // Dates encode as single-value objects; this can't both throw and push a container, so no need to catch the error.
            try self.with(path: codingPathNode.pushing(additionalKey)) {
                try date.encode(to: self)
            }
            return self.storage.popWritable().value

        case .secondsSince1970:
            return try JSONValue.number(from: date.timeIntervalSince1970, with: .throw, for: codingPathNode, additionalKey)

        case .millisecondsSince1970:
            return try JSONValue.number(from: 1000.0 * date.timeIntervalSince1970, with: .throw, for: codingPathNode, additionalKey)

#if FOUNDATION_FRAMEWORK
        case .iso8601:
            return self.wrap(date.formatted(.iso8601))

        case .formatted(let formatter):
            return self.wrap(formatter.string(from: date))
#endif

        case .custom(let closure):
            let depth = self.storage.count
            do {
                try self.with(path: codingPathNode.pushing(additionalKey)) {
                    try closure(date, self)
                }
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                if self.storage.count > depth {
                    let _ = self.storage.popWritable()
                }

                throw error
            }

            guard self.storage.count > depth else {
                // The closure didn't encode anything. Return the default keyed container.
                return .object([:])
            }

            // We can pop because the closure encoded something.
            return self.storage.popWritable().value
        }
    }

    func wrap(_ data: Data, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue {
        switch self.options.dataEncodingStrategy {
        case .deferredToData:
            let depth = self.storage.count
            do {
                try self.with(path: codingPathNode.pushing(additionalKey)) {
                    try data.encode(to: self)
                }
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                // This shouldn't be possible for Data (which encodes as an array of bytes), but it can't hurt to catch a failure.
                if self.storage.count > depth {
                    let _ = self.storage.popWritable()
                }

                throw error
            }

            return self.storage.popWritable().value

        case .base64:
            return self.wrap(data.base64EncodedString())

        case .custom(let closure):
            let depth = self.storage.count
            do {
                try self.with(path: codingPathNode.pushing(additionalKey)) {
                    try closure(data, self)
                }
            } catch {
                // If the value pushed a container before throwing, pop it back off to restore state.
                if self.storage.count > depth {
                    let _ = self.storage.popWritable()
                }

                throw error
            }

            guard self.storage.count > depth else {
                // The closure didn't encode anything. Return the default keyed container.
                return .object([:])
            }

            // We can pop because the closure encoded something.
            return self.storage.popWritable().value
        }
    }

    func wrap(_ dict: [String : Encodable], for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue? {
        let depth = self.storage.count
        let result = self.storage.pushKeyedContainer()
        let rootPath = codingPathNode.pushing(additionalKey)
        do {
            for (key, value) in dict {
                result.encode(try wrap(value, for: rootPath, _JSONKey(stringValue: key)), for: key)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth {
                let _ = self.storage.popWritable()
            }

            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }

        return self.storage.popWritable().value
    }

    func wrap(_ value: Encodable, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue {
        return try self.wrapGeneric(value, for: codingPathNode, additionalKey) ?? JSONValue.object([:])
    }

    func wrapGeneric(_ value: Encodable, for node: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = _JSONKey?.none) throws -> JSONValue? {
        switch value {
        case let date as Date:
            // Respect Date encoding strategy
            return try self.wrap(date, for: node, additionalKey)
        case let data as Data:
            // Respect Data encoding strategy
            return try self.wrap(data, for: node, additionalKey)
#if FOUNDATION_FRAMEWORK // TODO: Reenable once URL and Decimal are moved
        case let url as URL:
            // Encode URLs as single strings.
            return self.wrap(url.absoluteString)
        case let decimal as Decimal:
            return JSONValue.number(decimal.description)
#endif // FOUNDATION_FRAMEWORK
        case let dict as _JSONStringDictionaryEncodableMarker:
            return try self.wrap(dict as! [String : Encodable], for: node, additionalKey)
        default:
            break
        }

        // The value should request a container from the __JSONEncoder.
        let depth = self.storage.count
        do {
            try self.with(path: node.pushing(additionalKey)) {
                try value.encode(to: self)
            }
        } catch {
            // If the value pushed a container before throwing, pop it back off to restore state.
            if self.storage.count > depth {
                let _ = self.storage.popWritable()
            }

            throw error
        }

        // The top container should be a new container.
        guard self.storage.count > depth else {
            return nil
        }

        return self.storage.popWritable().value
    }
}

// MARK: - __JSONReferencingEncoder

/// __JSONReferencingEncoder is a special subclass of __JSONEncoder which has its own storage, but references the contents of a different encoder.
/// It's used in superEncoder(), which returns a new encoder for encoding a superclass -- the lifetime of the encoder should not escape the scope it's created in, but it doesn't necessarily know when it's done being used (to write to the original container).
// NOTE: older overlays called this class _JSONReferencingEncoder.
// The two must coexist without a conflicting ObjC class name, so it
// was renamed. The old name must not be used in the new runtime.
private class __JSONReferencingEncoder : __JSONEncoder {
    // MARK: Reference types.

    /// The type of container we're referencing.
    private enum Reference {
        /// Referencing a specific index in an array container.
        case array(_JSONEncodingStorage.Writable, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(_JSONEncodingStorage.Writable, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    let encoder: __JSONEncoder

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(referencing encoder: __JSONEncoder, at index: Int, codingPathNode: _JSONCodingPathNode, wrapping writable: _JSONEncodingStorage.Writable) {
        self.encoder = encoder
        self.reference = .array(writable, index)
        super.init(options: encoder.options, codingPathNode: codingPathNode.pushing(_JSONKey(index: index)), initialDepth: codingPathNode.depth)
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(referencing encoder: __JSONEncoder, key: CodingKey, convertedKey: String, codingPathNode: _JSONCodingPathNode, wrapping dictionary: _JSONEncodingStorage.Writable) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, convertedKey)
        super.init(options: encoder.options, codingPathNode: codingPathNode.pushing(key), initialDepth: codingPathNode.depth)
    }

    // MARK: - Coding Path Operations

    override var canEncodeNewValue: Bool {
        // With a regular encoder, the storage and coding path grow together.
        // A referencing encoder, however, inherits its parents coding path, as well as the key it was created for.
        // We have to take this into account.
        return self.storage.count == self.codingPath.count - self.encoder.codingPath.count - 1
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value: JSONValue
        switch self.storage.count {
        case 0: value = .object([:])
        case 1: value = self.storage.popWritable().value
        default: fatalError("Referencing encoder deallocated with multiple containers on stack.")
        }

        switch self.reference {
        case .array(let arrayRef, let index):
            arrayRef.encode(value, insertedAt: index)
        case .dictionary(let dictionaryRef, let key):
            dictionaryRef.encode(value, for: key)
        }
    }
}

// MARK: - Shared Key Types
internal struct _JSONKey: CodingKey {
    enum Rep {
        case string(String)
        case int(Int)
        case index(Int)
        case both(String, Int)
    }
    let rep : Rep

    public init?(stringValue: String) {
        self.rep = .string(stringValue)
    }

    public init?(intValue: Int) {
        self.rep = .int(intValue)
    }

    internal init(index: Int) {
        self.rep = .index(index)
    }

    public init(stringValue: String, intValue: Int?) {
        if let intValue {
            self.rep = .both(stringValue, intValue)
        } else {
            self.rep = .string(stringValue)
        }
    }

    var stringValue: String {
        switch rep {
        case let .string(str): return str
        case let .int(int): return "\(int)"
        case let .index(index): return "Index \(index)"
        case let .both(str, _): return str
        }
    }

    var intValue: Int? {
        switch rep {
        case .string: return nil
        case let .int(int): return int
        case let .index(index): return index
        case let .both(_, int): return int
        }
    }

    internal static let `super` = _JSONKey(stringValue: "super")!
}

//===----------------------------------------------------------------------===//
// Coding Path Node
//===----------------------------------------------------------------------===//

// This construction allows overall fewer and smaller allocations as the coding path is modified.
internal enum _JSONCodingPathNode {
    case root
    indirect case node(CodingKey, _JSONCodingPathNode)

    var path : [CodingKey] {
        switch self {
        case .root:
            return []
        case let .node(key, parent):
            return parent.path + [key]
        }
    }

    mutating func push(_ key: __owned some CodingKey) {
        self = .node(key, self)
    }

    mutating func pop() {
        guard case let .node(_, parent) = self else {
            preconditionFailure("Can't pop the root node")
        }
        self = parent
    }

    func pushing(_ key: __owned (some CodingKey)?) -> _JSONCodingPathNode {
        if let key {
            return .node(key, self)
        } else {
            return self
        }
    }

    func path(with key: __owned (some CodingKey)?) -> [CodingKey] {
        if let key {
            return self.path + [key]
        }
        return self.path
    }

    var depth : Int {
        switch self {
        case .root: return 0
        case let .node(_, parent): return parent.depth + 1
        }
    }
}

//===----------------------------------------------------------------------===//
// Error Utilities
//===----------------------------------------------------------------------===//

extension EncodingError {
    /// Returns a `.invalidValue` error describing the given invalid floating-point value.
    ///
    ///
    /// - parameter value: The value that was invalid to encode.
    /// - parameter path: The path of `CodingKey`s taken to encode this value.
    /// - returns: An `EncodingError` with the appropriate path and debug description.
    fileprivate static func _invalidFloatingPointValue<T : FloatingPoint>(_ value: T, at codingPath: [CodingKey]) -> EncodingError {
        let valueDescription: String
        if value == T.infinity {
            valueDescription = "\(T.self).infinity"
        } else if value == -T.infinity {
            valueDescription = "-\(T.self).infinity"
        } else {
            valueDescription = "\(T.self).nan"
        }

        let debugDescription = "Unable to encode \(valueDescription) directly in JSON. Use JSONEncoder.NonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded."
        return .invalidValue(value, EncodingError.Context(codingPath: codingPath, debugDescription: debugDescription))
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension JSONEncoder : @unchecked Sendable {}
