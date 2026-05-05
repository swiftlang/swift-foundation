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

// MARK: - PassthroughStrategy

/// A strategy that delegates to the value's own `CommonCodable` conformance.
///
/// This is the equivalent of serde_with's `_` (Same) — it means "use the
/// default coding behavior." Useful as a slot-filler when composing with
/// other combinators:
///
///     @CodableBy(.dictionary(key: .losslessStringConversion, value: .passthrough))
///     let scores: [(Int, MyStruct)]
///
public struct PassthroughCodingStrategy<Value: CommonEncodable & CommonDecodable>: CommonCodingStrategy, JSONCodingStrategy {
    public init() {}

    public func encode(_ value: borrowing Value, to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(value)
    }

    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Value {
        try decoder.decode(Value.self)
    }
}

// MARK: - ArrayElementStrategy

/// A strategy that encodes/decodes an `Array` by applying an inner strategy
/// to each element.
///
/// This is the combinator equivalent of serde_with's `Vec<A>` — it applies
/// the adapter `A` element-wise:
///
///     @CodableBy(.array(.dateFormat(.iso8601)))
///     let timestamps: [Date]
///
///     @CodableBy(.array(.base64))
///     let attachments: [Data]
///
public struct ArrayElementCodingStrategy<Element: CommonCodingStrategy>: CommonCodingStrategy, JSONCodingStrategy where Element.Value: Copyable {
    public typealias Value = [Element.Value]

    private let elementStrategy: Element

    public init(_ elementStrategy: Element) {
        self.elementStrategy = elementStrategy
    }

    public func encode(_ value: borrowing [Element.Value], to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        let strategy = elementStrategy
        try encoder.encodeArray(elementCount: value.count) { arrayEncoder throws(CodingError.Encoding) in
            for index in value.indices {
                try arrayEncoder.encodeElement { elementEncoder throws(CodingError.Encoding) in
                    try elementEncoder.encode(value[index], using: strategy)
                }
            }
        }
    }

    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> [Element.Value] {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            var result = [Element.Value]()
            if let hint = arrayDecoder.sizeHint {
                result.reserveCapacity(hint)
            }
            while let element = try arrayDecoder.decodeNext({ elementDecoder throws(CodingError.Decoding) in
                try elementDecoder.decode(using: elementStrategy)
            }) {
                result.append(element)
            }
            return result
        }
    }
}

// MARK: - DictionaryPairsCodingStrategy

/// A strategy that encodes a sequence of key-value pairs as a dictionary/map,
/// applying separate strategies to keys and values.
///
/// This is the combinator equivalent of serde_with's `Map<K, V>` — it can
/// transform the serialized shape (e.g., `[(K, V)]` becomes a JSON object):
///
///     @CodableBy(.dictionary(key: .losslessStringConversion, value: .passthrough))
///     let scores: [(Int, String)]
///     // Encodes as: {"1": "Alice", "2": "Bob"}
///
/// The key strategy must produce/consume `String` values, since most
/// serialization formats require string-typed dictionary keys.
public struct DictionaryPairsCodingStrategy<KeyStrategy: CommonCodingStrategy, ValueStrategy: CommonCodingStrategy>: CommonCodingStrategy, JSONCodingStrategy where KeyStrategy.Value: Hashable & Copyable, ValueStrategy.Value: Copyable {
    public typealias Value = [(KeyStrategy.Value, ValueStrategy.Value)]

    private let keyStrategy: KeyStrategy
    private let valueStrategy: ValueStrategy

    public init(key: KeyStrategy, value: ValueStrategy) {
        self.keyStrategy = key
        self.valueStrategy = value
    }

    public func encode(_ value: borrowing [(KeyStrategy.Value, ValueStrategy.Value)], to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        let kStrategy = keyStrategy
        let vStrategy = valueStrategy
        try encoder.encodeDictionary(elementCount: value.count) { dictEncoder throws(CodingError.Encoding) in
            for index in value.indices {
                let (k, v) = value[index]
                try dictEncoder.encodeKey { keyEncoder throws(CodingError.Encoding) in
                    try keyEncoder.encode(k, using: kStrategy)
                } valueEncoder: { valueEncoder throws(CodingError.Encoding) in
                    try valueEncoder.encode(v, using: vStrategy)
                }
            }
        }
    }

    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> [(KeyStrategy.Value, ValueStrategy.Value)] {
        try decoder.decodeDictionary { dictDecoder throws(CodingError.Decoding) in
            var result = [(KeyStrategy.Value, ValueStrategy.Value)]()

            var key: KeyStrategy.Value? = nil
            try dictDecoder.decodeEachKey { keyDecoder throws(CodingError.Decoding) in
                key = try keyDecoder.decode(using: keyStrategy)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                let value = try valueDecoder.decode(using: valueStrategy)
                result.append((key!, value))
            }

            return result
        }
    }
}

// MARK: - DictionaryCodingStrategy

/// A strategy that encodes/decodes a Swift `Dictionary` by applying separate
/// strategies to each key and value.
///
/// Unlike `DictionaryPairsCodingStrategy` (which operates on `[(K, V)]` tuples),
/// this strategy works directly with `Dictionary<K, V>`:
///
///     @CodableBy(.dictionary(key: .losslessStringConversion, value: .passthrough))
///     let scores: [Int: String]
///     // Encodes as: {"1": "Alice", "2": "Bob"}
///
///     @CodableBy(.dictionary(key: .losslessStringConversion, value: .array(.dateFormat(.iso8601))))
///     let schedule: [UInt8: [Date]]
///     // Encodes as: {"1": ["2026-02-14T10:00:00Z"], "42": ["2026-11-11T11:11:00Z"]}
///
public struct DictionaryCodingStrategy<KeyStrategy: CommonCodingStrategy, ValueStrategy: CommonCodingStrategy>: CommonCodingStrategy, JSONCodingStrategy where KeyStrategy.Value: Hashable & Copyable, ValueStrategy.Value: Copyable {
    public typealias Value = [KeyStrategy.Value: ValueStrategy.Value]

    private let keyStrategy: KeyStrategy
    private let valueStrategy: ValueStrategy

    public init(key: KeyStrategy, value: ValueStrategy) {
        self.keyStrategy = key
        self.valueStrategy = value
    }

    public func encode(_ value: borrowing [KeyStrategy.Value: ValueStrategy.Value], to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        let kStrategy = keyStrategy
        let vStrategy = valueStrategy
        try encoder.encodeDictionary(elementCount: value.count) { dictEncoder throws(CodingError.Encoding) in
            for index in value.indices {
                let k = value.keys[index]
                let v = value.values[index]
                try dictEncoder.encodeKey { keyEncoder throws(CodingError.Encoding) in
                    try keyEncoder.encode(k, using: kStrategy)
                } valueEncoder: { valueEncoder throws(CodingError.Encoding) in
                    try valueEncoder.encode(v, using: vStrategy)
                }
            }
        }
    }

    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> [KeyStrategy.Value: ValueStrategy.Value] {
        try decoder.decodeDictionary { dictDecoder throws(CodingError.Decoding) in
            var result = [KeyStrategy.Value: ValueStrategy.Value]()

            var key: KeyStrategy.Value? = nil
            try dictDecoder.decodeEachKey { keyDecoder throws(CodingError.Decoding) in
                key = try keyDecoder.decode(using: keyStrategy)
            } andValue: { valueDecoder throws(CodingError.Decoding) in
                let value = try valueDecoder.decode(using: valueStrategy)
                result[key!] = value
            }

            return result
        }
    }
}

// MARK: - LosslessStringCodingStrategy

/// A strategy that encodes/decodes a value as a string using its
/// `LosslessStringConvertible` conformance.
///
/// This is analogous to serde_with's `DisplayFromStr` — encode via
/// `description`, decode via `init?(_ description:)`:
///
///     @CodableBy(.losslessStringConversion)
///     let port: UInt16
///     // Encodes as: "8080"
///
///     @CodableBy(.dictionary(key: .losslessStringConversion, value: .passthrough))
///     let lookup: [(Int, String)]
///     // Encodes as: {"42": "answer", "7": "lucky"}
///
public struct LosslessStringCodingStrategy<Value: LosslessStringConvertible>: CommonCodingStrategy, JSONCodingStrategy {
    public init() {}

    public func encode(_ value: borrowing Value, to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeString(value.description)
    }

    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Value {
        let string = try decoder.decode(String.self)
        guard let value = Value(string) else {
            throw CodingError.dataCorrupted(debugDescription: "Failed to convert '\(string)' to \(Value.self) via LosslessStringConvertible")
        }
        return value
    }
}

// MARK: - Convenience static members

extension CommonCodingStrategy {
    /// Apply an inner strategy element-wise to an array.
    public static func array<S: CommonCodingStrategy>(_ elementStrategy: S) -> ArrayElementCodingStrategy<S> where Self == ArrayElementCodingStrategy<S> {
        .init(elementStrategy)
    }

    /// Encode a sequence of pairs as a dictionary, with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryPairsCodingStrategy<K, V> where Self == DictionaryPairsCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Encode/decode a `Dictionary` with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryCodingStrategy<K, V> where Self == DictionaryCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Use the value's own `CommonCodable` conformance (the identity/passthrough strategy).
    public static func passthrough<T: CommonEncodable & CommonDecodable>() -> PassthroughCodingStrategy<T> where Self == PassthroughCodingStrategy<T> {
        .init()
    }

    /// Encode/decode a value as a string using `LosslessStringConvertible`.
    public static func losslessStringConversion<T: LosslessStringConvertible>() -> LosslessStringCodingStrategy<T> where Self == LosslessStringCodingStrategy<T> {
        .init()
    }
}

extension CommonEncodingStrategy {
    /// Apply an inner strategy element-wise to an array.
    public static func array<S: CommonEncodingStrategy>(_ elementStrategy: S) -> ArrayElementCodingStrategy<S> where Self == ArrayElementCodingStrategy<S> {
        .init(elementStrategy)
    }

    /// Encode a sequence of pairs as a dictionary, with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryPairsCodingStrategy<K, V> where Self == DictionaryPairsCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Encode/decode a `Dictionary` with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryCodingStrategy<K, V> where Self == DictionaryCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Use the value's own `CommonCodable` conformance (the identity/passthrough strategy).
    public static func passthrough<T: CommonEncodable & CommonDecodable>() -> PassthroughCodingStrategy<T> where Self == PassthroughCodingStrategy<T> {
        .init()
    }

    /// Encode/decode a value as a string using `LosslessStringConvertible`.
    public static func losslessStringConversion<T: LosslessStringConvertible>() -> LosslessStringCodingStrategy<T> where Self == LosslessStringCodingStrategy<T> {
        .init()
    }
}

extension CommonDecodingStrategy {
    /// Apply an inner strategy element-wise to an array.
    public static func array<S: CommonDecodingStrategy>(_ elementStrategy: S) -> ArrayElementCodingStrategy<S> where Self == ArrayElementCodingStrategy<S> {
        .init(elementStrategy)
    }

    /// Encode a sequence of pairs as a dictionary, with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryPairsCodingStrategy<K, V> where Self == DictionaryPairsCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Encode/decode a `Dictionary` with separate strategies for keys and values.
    public static func dictionary<K: CommonCodingStrategy, V: CommonCodingStrategy>(key: K, value: V) -> DictionaryCodingStrategy<K, V> where Self == DictionaryCodingStrategy<K, V>, K.Value: Hashable & Copyable, V.Value: Copyable {
        .init(key: key, value: value)
    }

    /// Use the value's own `CommonCodable` conformance (the identity/passthrough strategy).
    public static func passthrough<T: CommonEncodable & CommonDecodable>() -> PassthroughCodingStrategy<T> where Self == PassthroughCodingStrategy<T> {
        .init()
    }

    /// Encode/decode a value as a string using `LosslessStringConvertible`.
    public static func losslessStringConversion<T: LosslessStringConvertible>() -> LosslessStringCodingStrategy<T> where Self == LosslessStringCodingStrategy<T> {
        .init()
    }
}

