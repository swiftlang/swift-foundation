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

        /// Produce JSON with dictionary keys sorted in lexicographic order.
        @available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *)
        public static let sortedKeys    = OutputFormatting(rawValue: 1 << 1)

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

        /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
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
    @preconcurrency
    open var userInfo: [CodingUserInfoKey : any Sendable] {
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
        var userInfo: [CodingUserInfoKey : any Sendable] = [:]
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
        try _encode({
            try $0.wrapGeneric(value)
        }, value: value)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    open func encode<T : EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration) throws -> Data {
        try _encode({
            try $0.wrapGeneric(value, configuration: configuration)
        }, value: value)
    }
    
    @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
    open func encode<T, C>(_ value: T, configuration: C.Type) throws -> Data where T : EncodableWithConfiguration, C : EncodingConfigurationProviding, T.EncodingConfiguration == C.EncodingConfiguration {
        try encode(value, configuration: C.encodingConfiguration)
    }
    
    private func _encode<T>(_ wrap: (__JSONEncoder) throws -> JSONEncoderValue?, value: T) throws -> Data {
        let encoder = __JSONEncoder(options: self.options, ownerEncoder: nil)

        guard let topLevel = try wrap(encoder) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }

        let writingOptions = self.outputFormatting
        do {
            var writer = JSONWriter(options: writingOptions)
            try writer.serializeJSON(topLevel)
            return Data(writer.bytes)
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
    var singleValue: JSONEncoderValue?
    var array: JSONFuture.RefArray?
    var object: JSONFuture.RefObject?

    func takeValue() -> JSONEncoderValue? {
        if let object = self.object {
            self.object = nil
            return .object(object.values)
        }
        if let array = self.array {
            self.array = nil
            return .array(array.values)
        }
        defer {
            self.singleValue = nil
        }
        return self.singleValue
    }

    /// Options set on the top-level encoder.
    fileprivate let options: JSONEncoder._Options

    var ownerEncoder: __JSONEncoder?
    var sharedSubEncoder: __JSONEncoder?
    var codingKey: (any CodingKey)?


    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey : Any] {
        return self.options.userInfo
    }

    /// The path to the current point in encoding.
    public var codingPath: [CodingKey] {
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

        return result.reversed()
    }

    // MARK: - Initialization

    /// Initializes `self` with the given top-level encoder options.
    init(options: JSONEncoder._Options, ownerEncoder: __JSONEncoder?, codingKey: (any CodingKey)? = _CodingKey?.none) {
        self.options = options
        self.ownerEncoder = ownerEncoder
        self.codingKey = codingKey
    }

    // MARK: - Encoder Methods
    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        // If an existing keyed container was already requested, return that one.
        if let object {
            let container = _JSONKeyedEncodingContainer<Key>(referencing: self, codingPathNode: .root, wrapping: object)
            return KeyedEncodingContainer(container)
        }
        if let object = self.singleValue?.convertedToObjectRef() {
            self.singleValue = nil
            self.object = object

            let container = _JSONKeyedEncodingContainer<Key>(referencing: self, codingPathNode: .root, wrapping: object)
            return KeyedEncodingContainer(container)
        }

        guard self.singleValue == nil, self.array == nil else {
            preconditionFailure("Attempt to push new keyed encoding container when already previously encoded at this path.")
        }

        let newObject = JSONFuture.RefObject()
        self.object = newObject
        let container = _JSONKeyedEncodingContainer<Key>(referencing: self, codingPathNode: .root, wrapping: newObject)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        // If an existing unkeyed container was already requested, return that one.
        if let array {
            return _JSONUnkeyedEncodingContainer(referencing: self, codingPathNode: .root, wrapping: array)
        }
        if let array = self.singleValue?.convertedToArrayRef() {
            self.singleValue = nil
            self.array = array

            return _JSONUnkeyedEncodingContainer(referencing: self, codingPathNode: .root, wrapping: array)
        }

        guard self.singleValue == nil, self.object == nil else {
            preconditionFailure("Attempt to push new unkeyed encoding container when already previously encoded at this path.")
        }

        let newArray = JSONFuture.RefArray()
        self.array = newArray
        return _JSONUnkeyedEncodingContainer(referencing: self, codingPathNode: .root, wrapping: newArray)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return self
    }
}

// MARK: - Encoding Storage and Containers

internal enum JSONEncoderValue: Equatable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    case array([JSONEncoderValue])
    case object([String: JSONEncoderValue])

    case directArray([UInt8], lengths: [Int])
    case nonPrettyDirectArray([UInt8])
}

enum JSONFuture {
    case value(JSONEncoderValue)
    case nestedArray(RefArray)
    case nestedObject(RefObject)

    var object: RefObject? {
        switch self {
        case .nestedObject(let obj): obj
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
        private(set) var array: [JSONFuture] = []

        init() {
            self.array.reserveCapacity(10)
        }

        init(array: [JSONFuture]) {
            self.array = array
        }

        @inline(__always) func append(_ element: JSONEncoderValue) {
            self.array.append(.value(element))
        }

        @inline(__always) func insert(_ element: JSONEncoderValue, at index: Int) {
            self.array.insert(.value(element), at: index)
        }

        @inline(__always) func appendArray() -> RefArray {
            let array = RefArray()
            self.array.append(.nestedArray(array))
            return array
        }

        @inline(__always) func appendObject() -> RefObject {
            let object = RefObject()
            self.array.append(.nestedObject(object))
            return object
        }

        var values: [JSONEncoderValue] {
            self.array.map { (future) -> JSONEncoderValue in
                switch future {
                case .value(let value):
                    return value
                case .nestedArray(let array):
                    return .array(array.values)
                case .nestedObject(let object):
                    return .object(object.values)
                }
            }
        }
    }

    class RefObject {
        var dict: [String: JSONFuture] = [:]

        init() {
            self.dict.reserveCapacity(4)
        }

        init(dict: [String: JSONFuture]) {
            self.dict = dict
        }

        @inline(__always) func set(_ value: JSONEncoderValue, for key: String) {
            self.dict[key] = .value(value)
        }

        @inline(__always) func setArray(for key: String) -> RefArray {
            switch self.dict[key] {
            case .nestedObject:
                preconditionFailure("For key \"\(key)\" a keyed container has already been created.")
            case .nestedArray(let array):
                return array
            case .none, .value:
                let array = RefArray()
                dict[key] = .nestedArray(array)
                return array
            }
        }

        @inline(__always) func setObject(for key: String) -> RefObject {
            switch self.dict[key] {
            case .nestedObject(let object):
                return object
            case .nestedArray:
                preconditionFailure("For key \"\(key)\" a unkeyed container has already been created.")
            case .none, .value:
                let object = RefObject()
                dict[key] = .nestedObject(object)
                return object
            }
        }

        var values: [String: JSONEncoderValue] {
            self.dict.mapValues { (future) -> JSONEncoderValue in
                switch future {
                case .value(let value):
                    return value
                case .nestedArray(let array):
                    return .array(array.values)
                case .nestedObject(let object):
                    return .object(object.values)
                }
            }
        }
    }
}

extension JSONEncoderValue {
    func convertedToObjectRef() -> JSONFuture.RefObject? {
        switch self {
        case .object(let dict):
            return .init(dict: .init(uniqueKeysWithValues: dict.map { ($0.key, .value($0.value)) }))
        default:
            return nil
        }
    }

    func convertedToArrayRef() -> JSONFuture.RefArray? {
        switch self {
        case .array(let array):
            return .init(array: array.map { .value($0) })
        default:
            return nil
        }
    }
}

extension JSONEncoderValue {
    static func number(from num: some (FixedWidthInteger & CustomStringConvertible)) -> JSONEncoderValue {
        return .number(num.description)
    }

    @inline(never)
    fileprivate static func cannotEncodeNumber<T: BinaryFloatingPoint>(_ float: T, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) -> EncodingError {
        let path = encoder.codingPath + (additionalKey.map { [$0] } ?? [])
        return EncodingError.invalidValue(float, .init(
            codingPath: path,
            debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."
        ))
    }

    @inline(never)
    fileprivate static func nonConformantNumber<T: BinaryFloatingPoint>(from float: T, with options: JSONEncoder.NonConformingFloatEncodingStrategy, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> JSONEncoderValue {
        if case .convertToString(let posInfString, let negInfString, let nanString) = options {
            switch float {
            case T.infinity:
                return .string(posInfString)
            case -T.infinity:
                return .string(negInfString)
            default:
                // must be nan in this case
                return .string(nanString)
            }
        }
        throw cannotEncodeNumber(float, encoder: encoder, additionalKey)
    }

    @inline(__always)
    fileprivate static func number<T: BinaryFloatingPoint & CustomStringConvertible>(from float: T, with options: JSONEncoder.NonConformingFloatEncodingStrategy, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)? = Optional<_CodingKey>.none) throws -> JSONEncoderValue {
        guard !float.isNaN, !float.isInfinite else {
            return try nonConformantNumber(from: float, with: options, encoder: encoder, additionalKey)
        }

        var string = float.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return .number(string)
    }

    @inline(__always)
    fileprivate static func number<T: BinaryFloatingPoint & CustomStringConvertible>(from float: T, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)? = Optional<_CodingKey>.none) throws -> JSONEncoderValue {
        try .number(from: float, with: encoder.options.nonConformingFloatEncodingStrategy, encoder: encoder, additionalKey)
    }
}


private struct _JSONEncodingStorage {
    // MARK: Properties
    var refs = [JSONFuture]()

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    init() {}

    // MARK: - Modifying the Stack

    var count: Int {
        return self.refs.count
    }

    mutating func pushKeyedContainer() -> JSONFuture.RefObject {
        let object = JSONFuture.RefObject()
        self.refs.append(.nestedObject(object))
        return object
    }

    mutating func pushUnkeyedContainer() -> JSONFuture.RefArray {
        let array = JSONFuture.RefArray()
        self.refs.append(.nestedArray(array))
        return array
    }

    mutating func push(ref: __owned JSONFuture) {
        self.refs.append(ref)
    }

    mutating func popReference() -> JSONFuture {
        precondition(!self.refs.isEmpty, "Empty reference stack.")
        return self.refs.popLast().unsafelyUnwrapped
    }
}

// MARK: - Encoding Containers

private struct _JSONKeyedEncodingContainer<K : CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K

    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __JSONEncoder

    private let reference: JSONFuture.RefObject
    private let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    public var codingPath: [CodingKey] {
        encoder.codingPath + codingPathNode.path
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    init(referencing encoder: __JSONEncoder, codingPathNode: _CodingPathNode, wrapping ref: JSONFuture.RefObject) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.reference = ref
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
            var path = codingPath
            path.append(key)
            return converter(path).stringValue
        }
    }

    // MARK: - KeyedEncodingContainerProtocol Methods

    public mutating func encodeNil(forKey key: Key) throws {
        reference.set(.null, for: _converted(key))
    }
    public mutating func encode(_ value: Bool, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int8, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int16, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int32, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: Int64, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public mutating func encode(_ value: Int128, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt8, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt16, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt32, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: UInt64, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public mutating func encode(_ value: UInt128, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }
    public mutating func encode(_ value: String, forKey key: Key) throws {
        reference.set(self.encoder.wrap(value), for: _converted(key))
    }

    public mutating func encode(_ value: Float, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: key)
        reference.set(wrapped, for: _converted(key))
    }

    public mutating func encode(_ value: Double, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: key)
        reference.set(wrapped, for: _converted(key))
    }

    public mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
        let wrapped = try self.encoder.wrap(value, for: key)
        reference.set(wrapped, for: _converted(key))
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let containerKey = _converted(key)
        let nestedRef: JSONFuture.RefObject
        if let existingRef = self.reference.dict[containerKey] {
            if let object = existingRef.object {
                // Was encoded as an object ref previously. We can just use it again.
                nestedRef = object
            } else if case .value(let value) = existingRef,
                      let convertedObject = value.convertedToObjectRef() {
                // Was encoded as an object *value* previously. We need to convert it back to a reference before we can use it.
                nestedRef = convertedObject
                self.reference.dict[containerKey] = .nestedObject(convertedObject)
            } else {
                preconditionFailure(
                    "Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key"
                )
            }
        } else {
            nestedRef = self.reference.setObject(for: containerKey)
        }

        let container = _JSONKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let containerKey = _converted(key)
        let nestedRef: JSONFuture.RefArray
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

        return _JSONUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(key), wrapping: nestedRef)
    }

    public mutating func superEncoder() -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, key: _CodingKey.super, convertedKey: _converted(_CodingKey.super), wrapping: self.reference)
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, key: key, convertedKey: _converted(key), wrapping: self.reference)
    }
}

private struct _JSONUnkeyedEncodingContainer : UnkeyedEncodingContainer {
    // MARK: Properties

    /// A reference to the encoder we're writing to.
    private let encoder: __JSONEncoder

    private let reference: JSONFuture.RefArray
    private let codingPathNode: _CodingPathNode

    /// The path of coding keys taken to get to this point in encoding.
    public var codingPath: [CodingKey] {
        encoder.codingPath + codingPathNode.path
    }

    /// The number of elements encoded into the container.
    public var count: Int {
        self.reference.array.count
    }

    // MARK: - Initialization

    /// Initializes `self` with the given references.
    init(referencing encoder: __JSONEncoder, codingPathNode: _CodingPathNode, wrapping ref: JSONFuture.RefArray) {
        self.encoder = encoder
        self.codingPathNode = codingPathNode
        self.reference = ref
    }

    // MARK: - UnkeyedEncodingContainer Methods

    public mutating func encodeNil()             throws { self.reference.append(.null) }
    public mutating func encode(_ value: Bool)   throws { self.reference.append(.bool(value)) }
    public mutating func encode(_ value: Int)    throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int8)   throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int16)  throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int32)  throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: Int64)  throws { self.reference.append(self.encoder.wrap(value)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public mutating func encode(_ value: Int128)  throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt)   throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt8)  throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt16) throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt32) throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: UInt64) throws { self.reference.append(self.encoder.wrap(value)) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public mutating func encode(_ value: UInt128)  throws { self.reference.append(self.encoder.wrap(value)) }
    public mutating func encode(_ value: String) throws { self.reference.append(self.encoder.wrap(value)) }

    public mutating func encode(_ value: Float)  throws {
        self.reference.append(try .number(from: value, encoder: encoder, _CodingKey(index: self.count)))
    }

    public mutating func encode(_ value: Double) throws {
        self.reference.append(try .number(from: value, encoder: encoder, _CodingKey(index: self.count)))
    }

    public mutating func encode<T : Encodable>(_ value: T) throws {
        let wrapped = try self.encoder.wrap(value, for: _CodingKey(index: self.count))
        self.reference.append(wrapped)
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let index = self.count
        let nestedRef = self.reference.appendObject()
        let container = _JSONKeyedEncodingContainer<NestedKey>(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(index: index), wrapping: nestedRef)
        return KeyedEncodingContainer(container)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let index = self.count
        let nestedRef = self.reference.appendArray()
        return _JSONUnkeyedEncodingContainer(referencing: self.encoder, codingPathNode: self.codingPathNode.appending(index: index), wrapping: nestedRef)
    }

    public mutating func superEncoder() -> Encoder {
        return __JSONReferencingEncoder(referencing: self.encoder, at: self.reference.array.count, wrapping: self.reference)
    }
}

extension __JSONEncoder : SingleValueEncodingContainer {
    // MARK: - SingleValueEncodingContainer Methods

    private func assertCanEncodeNewValue() {
        precondition(self.singleValue == nil, "Attempt to encode value through single value container when previously value already encoded.")
    }

    public func encodeNil() throws {
        assertCanEncodeNewValue()
        self.singleValue = .null
    }

    public func encode(_ value: Bool) throws {
        assertCanEncodeNewValue()
        self.singleValue = .bool(value)
    }

    public func encode(_ value: Int) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: Int8) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: Int16) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: Int32) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: Int64) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func encode(_ value: Int128) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: UInt) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: UInt8) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: UInt16) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: UInt32) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: UInt64) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }
    
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    public func encode(_ value: UInt128) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: String) throws {
        assertCanEncodeNewValue()
        self.singleValue = wrap(value)
    }

    public func encode(_ value: Float) throws {
        assertCanEncodeNewValue()
        let wrapped = try self.wrap(value)
        self.singleValue = wrapped
    }

    public func encode(_ value: Double) throws {
        assertCanEncodeNewValue()
        let wrapped = try self.wrap(value)
        self.singleValue = wrapped
    }

    public func encode<T : Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        self.singleValue = try self.wrap(value)
    }
}

// MARK: - Concrete Value Representations

private extension __JSONEncoder {
    /// Returns the given value boxed in a container appropriate for pushing onto the container stack.
    @inline(__always) func wrap(_ value: Bool)   -> JSONEncoderValue { .bool(value) }
    @inline(__always) func wrap(_ value: Int)    -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: Int8)   -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: Int16)  -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: Int32)  -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: Int64)  -> JSONEncoderValue { .number(from: value) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @inline(__always) func wrap(_ value: Int128)  -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: UInt)   -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: UInt8)  -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: UInt16) -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: UInt32) -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: UInt64) -> JSONEncoderValue { .number(from: value) }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    @inline(__always) func wrap(_ value: UInt128)  -> JSONEncoderValue { .number(from: value) }
    @inline(__always) func wrap(_ value: String) -> JSONEncoderValue { .string(value) }

    @inline(__always)
    func wrap(_ float: Float, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue {
        try .number(from: float, encoder: self, additionalKey)
    }

    @inline(__always)
    func wrap(_ double: Double, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue {
        try .number(from: double, encoder: self, additionalKey)
    }

    func wrap(_ date: Date, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue {
        switch self.options.dateEncodingStrategy {
        case .deferredToDate:
            var encoder = getEncoder(for: additionalKey)
            defer {
                returnEncoder(&encoder)
            }
            try date.encode(to: encoder)
            return encoder.takeValue().unsafelyUnwrapped

        case .secondsSince1970:
            return try .number(from: date.timeIntervalSince1970, with: .throw, encoder: self, additionalKey)

        case .millisecondsSince1970:
            return try .number(from: 1000.0 * date.timeIntervalSince1970, with: .throw, encoder: self, additionalKey)

        case .iso8601:
            return self.wrap(date.formatted(.iso8601))

#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
        case .formatted(let formatter):
            return self.wrap(formatter.string(from: date))
#endif

        case .custom(let closure):
            var encoder = getEncoder(for: additionalKey)
            defer {
                returnEncoder(&encoder)
            }
            try closure(date, encoder)
            return encoder.takeValue() ?? .object([:])
        }
    }

    func wrap(_ data: Data, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue {
        switch self.options.dataEncodingStrategy {
        case .deferredToData:
            var encoder = self.getEncoder(for: additionalKey)
            defer {
                returnEncoder(&encoder)
            }
            try data.encode(to: encoder)
            return encoder.takeValue().unsafelyUnwrapped

        case .base64:
            return self.wrap(data.base64EncodedString())

        case .custom(let closure):
            var encoder = getEncoder(for: additionalKey)
            defer {
                returnEncoder(&encoder)
            }
            try closure(data, encoder)
            return encoder.takeValue() ?? .object([:])
        }
    }

    func wrap(_ dict: [String : Encodable], for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue? {
        var result = [String: JSONEncoderValue]()
        result.reserveCapacity(dict.count)

        let encoder = __JSONEncoder(options: self.options, ownerEncoder: self)
        for (key, value) in dict {
            encoder.codingKey = _CodingKey(stringValue: key)
            result[key] = try encoder.wrap(value)
        }

        return .object(result)
    }

    func wrap(_ value: Encodable, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue {
        return try self.wrapGeneric(value, for: additionalKey) ?? .object([:])
    }

    func wrapGeneric<T: Encodable>(_ value: T, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue? {

        if let date = value as? Date {
            // Respect Date encoding strategy
            return try self.wrap(date, for: additionalKey)
        } else if let data = value as? Data {
            // Respect Data encoding strategy
            return try self.wrap(data, for: additionalKey)
        } else if let url = value as? URL {
            // Encode URLs as single strings.
            return self.wrap(url.absoluteString)
        } else if let decimal = value as? Decimal {
            return .number(decimal.description)
        } else if let encodable = value as? _JSONStringDictionaryEncodableMarker {
            return try self.wrap(encodable as! [String:Encodable], for: additionalKey)
        } else if let array = value as? _JSONDirectArrayEncodable {
            if options.outputFormatting.contains(.prettyPrinted) {
                let (bytes, lengths) = try array.individualElementRepresentation(encoder: self, additionalKey)
                return .directArray(bytes, lengths: lengths)
            } else {
                return .nonPrettyDirectArray(try array.nonPrettyJSONRepresentation(encoder: self, additionalKey))
            }
        }

        return try _wrapGeneric({
            try value.encode(to: $0)
        }, for: additionalKey)
    }
    
    func wrapGeneric<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration, for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue? {
        try _wrapGeneric({
            try value.encode(to: $0, configuration: configuration)
        }, for: additionalKey)
    }

    @inline(__always)
    func _wrapGeneric(_ encode: (__JSONEncoder) throws -> (), for additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> JSONEncoderValue? {
        var encoder = getEncoder(for: additionalKey)
        defer {
            returnEncoder(&encoder)
        }
        try encode(encoder)
        return encoder.takeValue()
    }

    @inline(__always)
    func getEncoder(for additionalKey: CodingKey?) -> __JSONEncoder {
        if let additionalKey {
            if let takenEncoder = sharedSubEncoder {
                self.sharedSubEncoder = nil
                takenEncoder.codingKey = additionalKey
                takenEncoder.ownerEncoder = self
                return takenEncoder
            }
            return __JSONEncoder(options: self.options, ownerEncoder: self, codingKey: additionalKey)
        }

        return self
    }

    @inline(__always)
    func returnEncoder(_ encoder: inout __JSONEncoder) {
        if encoder !== self, sharedSubEncoder == nil, isKnownUniquelyReferenced(&encoder) {
            encoder.codingKey = nil
            encoder.ownerEncoder = nil // Prevent retain cycle.
            sharedSubEncoder = encoder
        }
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
        case array(JSONFuture.RefArray, Int)

        /// Referencing a specific key in a dictionary container.
        case dictionary(JSONFuture.RefObject, String)
    }

    // MARK: - Properties

    /// The encoder we're referencing.
    let encoder: __JSONEncoder

    /// The container reference itself.
    private let reference: Reference

    // MARK: - Initialization

    /// Initializes `self` by referencing the given array container in the given encoder.
    init(referencing encoder: __JSONEncoder, at index: Int, wrapping ref: JSONFuture.RefArray) {
        self.encoder = encoder
        self.reference = .array(ref, index)
        super.init(options: encoder.options, ownerEncoder: encoder, codingKey: _CodingKey(index: index))
    }

    /// Initializes `self` by referencing the given dictionary container in the given encoder.
    init(referencing encoder: __JSONEncoder, key: CodingKey, convertedKey: String, wrapping dictionary: JSONFuture.RefObject) {
        self.encoder = encoder
        self.reference = .dictionary(dictionary, convertedKey)
        super.init(options: encoder.options, ownerEncoder: encoder, codingKey: key)
    }

    // MARK: - Deinitialization

    // Finalizes `self` by writing the contents of our storage to the referenced encoder's storage.
    deinit {
        let value = self.takeValue() ?? JSONEncoderValue.object([:])

        switch self.reference {
        case .array(let arrayRef, let index):
            arrayRef.insert(value, at: index)
        case .dictionary(let dictionaryRef, let key):
            dictionaryRef.set(value, for: key)
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

//===----------------------------------------------------------------------===//
// Special-casing Support
//===----------------------------------------------------------------------===//

/// A marker protocol used to determine whether a value is a `String`-keyed `Dictionary`
/// containing `Encodable` values (in which case it should be exempt from key conversion strategies).
private protocol _JSONStringDictionaryEncodableMarker { }

extension Dictionary : _JSONStringDictionaryEncodableMarker where Key == String, Value: Encodable { }

/// A protocol used to determine whether a value is an `Array` containing values that allow
/// us to bypass UnkeyedEncodingContainer overhead by directly encoding the contents as
/// strings as passing that down to the JSONWriter.
fileprivate protocol _JSONDirectArrayEncodable {
    @inline(__always)
    func nonPrettyJSONRepresentation(encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> [UInt8]
    @inline(__always)
    func individualElementRepresentation(encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> ([UInt8], lengths: [Int])
}
fileprivate protocol _JSONSimpleValueArrayElement {
    @inline(__always)
    func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> Int
}
extension _JSONSimpleValueArrayElement where Self: FixedWidthInteger & CustomStringConvertible {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> Int {
        return writer.serializeSimpleStringContents(description)
    }
}
extension Int : _JSONSimpleValueArrayElement { }
extension Int8 : _JSONSimpleValueArrayElement { }
extension Int16 : _JSONSimpleValueArrayElement { }
extension Int32 : _JSONSimpleValueArrayElement { }
extension Int64 : _JSONSimpleValueArrayElement { }
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension Int128 : _JSONSimpleValueArrayElement { }
extension UInt : _JSONSimpleValueArrayElement { }
extension UInt8 : _JSONSimpleValueArrayElement { }
extension UInt16 : _JSONSimpleValueArrayElement { }
extension UInt32 : _JSONSimpleValueArrayElement { }
extension UInt64 : _JSONSimpleValueArrayElement { }
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension UInt128 : _JSONSimpleValueArrayElement { }
extension String: _JSONSimpleValueArrayElement {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) -> Int {
        return writer.serializeString(self)
    }
}
extension Float: _JSONSimpleValueArrayElement {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> Int {
        switch try JSONEncoderValue.number(from: self, encoder: encoder, additionalKey) {
        case .number(let string):
            return writer.serializeSimpleStringContents(string)
        case .string(let string):
            return writer.serializeSimpleString(string)
        default:
            fatalError("Impossible JSON value type coming from number formatting")
        }
    }
}

extension Double: _JSONSimpleValueArrayElement {
    fileprivate func serializeJsonRepresentation(into writer: inout JSONWriter, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> Int {
        switch try JSONEncoderValue.number(from: self, encoder: encoder, additionalKey) {
        case .number(let string):
            return writer.serializeSimpleStringContents(string)
        case .string(let string):
            return writer.serializeSimpleString(string)
        default:
            fatalError("Impossible JSON value type coming from number formatting")
        }
    }
}

// This is not yet extended to Double & Float. That case is more complicated, given the possibility of Infinity or NaN values, which require nonConformingFloatEncodingStrategy and the ability to throw errors.

extension Array : _JSONDirectArrayEncodable where Element: _JSONSimpleValueArrayElement {
    func nonPrettyJSONRepresentation(encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> [UInt8] {
        var writer = JSONWriter(options: encoder.options.outputFormatting)

        writer.writer(ascii: ._openbracket)

        let count = count
        if count > 0 {
            _ = try self[0].serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)

            for idx in 1 ..< count {
                writer.writer(ascii: ._comma)
                _ = try self[idx].serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)
            }
        }

        writer.writer(ascii: ._closebracket)
        return writer.bytes
    }
    
    func individualElementRepresentation(encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> ([UInt8], lengths: [Int]) {
        var writer = JSONWriter(options: encoder.options.outputFormatting)
        var byteLengths = [Int]()
        byteLengths.reserveCapacity(self.count)

        for element in self {
            let length = try element.serializeJsonRepresentation(into: &writer, encoder: encoder, additionalKey)
            byteLengths.append(length)
        }

        return (writer.bytes, lengths: byteLengths)
    }
}
