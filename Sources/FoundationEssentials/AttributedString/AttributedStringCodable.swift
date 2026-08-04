//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

// MARK: AttributedStringKey

extension Decoder {
    // FIXME: This ought to be public API in the stdlib.
    fileprivate func _dataCorruptedError(_ message: String) -> DecodingError {
        let context = DecodingError.Context(
            codingPath: self.codingPath,
            debugDescription: message)
        return DecodingError.dataCorrupted(context)
    }
}

/// A protocol that defines how an attribute key encodes its value.
///
/// Implement this protocol to make an attribute encodable. Encoding an ``AttributedString`` or ``AttributeContainer`` drops any attributes whose types don't conform to this protocol.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol EncodableAttributedStringKey : AttributedStringKey {
    /// Encodes a value to the provided encoder.
    ///
    /// This method throws an error if writing to the encoder fails.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - encoder: The encoder to write data to.
    static func encode(_ value: Value, to encoder: Encoder) throws
}

/// A protocol that defines how an attribute key decodes its value.
///
/// Implement this protocol to make an attribute decodable. Decoding an ``AttributedString`` or ``AttributeContainer`` drops any attributes whose types don't conform to this protocol.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol DecodableAttributedStringKey : AttributedStringKey {
    /// Decodes a value from the provided decoder.
    ///
    /// This method throws an error if reading from the decoder fails, or if the data read is
    /// corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Returns: The decoded value.
    static func decode(from decoder: Decoder) throws -> Value
}

/// A type alias for attribute keys that are both encodable and decodable.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias CodableAttributedStringKey = EncodableAttributedStringKey & DecodableAttributedStringKey

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension EncodableAttributedStringKey where Value : Encodable {
    /// Encodes a Swift value to the provided encoder, using a default implementation.
    ///
    /// The default implementation calls down to the value's `Encodable.encode(to:)` method.
    ///
    /// This method throws an error if writing the encoder fails.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - encoder: The encoder to write data to.
    public static func encode(_ value: Value, to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension DecodableAttributedStringKey where Value : Decodable {
    /// Decodes a Swift value from the provided decoder, using a default implementation.
    ///
    /// The default implementation calls down to the value's `Decodable.init(from:)` method.
    ///
    /// This method throws an error if reading from the decoder fails, or if the data read is
    /// corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Returns: The decoded value.
    public static func decode(from decoder: Decoder) throws -> Value {
        return try Value.init(from: decoder)
    }
}


/// A protocol that defines how an attribute key decodes a value that corresponds to Markdown syntax.
///
/// This protocol is separate from ``DecodableAttributedStringKey`` to separate explicit attributes defined by the SDK from Markdown's semantic styling attributes. You use these attributes with Apple's extended syntax for markdown: `^[text](attribute: value)`.
///
/// Using this protocol allows your markup names to differ from the names of your attributes. For example, the automatic grammar agreement feature uses markup like `^[text to inflect](inflect: true)`. This feature defines an ``AttributeScopes/FoundationAttributes/InflectionRuleAttribute`` that conforms to ``MarkdownDecodableAttributedStringKey``. The value of its ``AttributeScopes/FoundationAttributes/InflectionRuleAttribute/name`` proprerty is `NSInflect`, while its ``AttributeScopes/FoundationAttributes/InflectionRuleAttribute/markdownName-aom1``, used in actual Markdown strings like the one shown here, is `inflect`.
///
/// To define your own attributes for use with Markdown syntax, make sure your attributes conform to this protocol. The markdown parser ignores attributes that don't conform, even if you use the extended Markdown syntax.
///
/// > Tip:
/// > When creating attributed strings from Markdown-based initializers like ``AttributedString/init(markdown:options:baseURL:)-52n3u``, be sure to set the ``AttributedString/MarkdownParsingOptions/allowsExtendedAttributes`` option. If you don't include this option, the string won't parse ``MarkdownDecodableAttributedStringKey``-based attributes.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol MarkdownDecodableAttributedStringKey : AttributedStringKey {
    /// Decodes a value from the provided decoder.
    ///
    /// This method throws an error if reading from the decoder fails, or if the data read is
    /// corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Returns: The decoded value.
    static func decodeMarkdown(from decoder: Decoder) throws -> Value
    /// The Markdown name associated with an attributed string key.
    static var markdownName: String { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension MarkdownDecodableAttributedStringKey {
    /// The Markdown name associated with an attributed string key, as provided by a default
    /// implementation.
    ///
    /// The default value of this property is the value of the ``AttributedStringKey``'s
    /// ``AttributedStringKey/name``.
    public static var markdownName: String { name }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension MarkdownDecodableAttributedStringKey where Self : DecodableAttributedStringKey {
    /// Decodes a value from the provided decoder, using a default implementation.
    ///
    /// The default implementation calls ``DecodableAttributedStringKey/decode(from:)-9mpts``,
    /// inherited from ``DecodableAttributedStringKey``, meaning it uses the same decoding as
    /// non-Markdown encoding.
    ///
    /// This method throws an error if reading from the decoder fails, or if the data read is
    /// corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Returns: The decoded value.
    public static func decodeMarkdown(from decoder: Decoder) throws -> Value {
        try Self.decode(from: decoder)
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension EncodableAttributedStringKey where Value : NSSecureCoding & NSObject {
    /// Encodes an Objective-C value to the provided encoder, using a default implementation.
    ///
    /// The default implementation uses an ``NSKeyedArchiver`` on the object, then calls
    /// `Encodable.encode(to:)` on the resulting data.
    ///
    /// This method throws an error if writing to the encoder fails.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - encoder: The encoder to write data to.
    public static func encode(_ value: Value, to encoder: Encoder) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension DecodableAttributedStringKey where Value : NSSecureCoding & NSObject {
    /// Decodes an Objective-C value from the provided decoder, using a default implementation.
    ///
    /// The default implementation decodes the object as a ``Data`` instance, then uses an
    /// ``NSKeyedUnarchiver`` to unarchive the object.
    ///
    /// This method throws an error if reading from the decoder fails, or if the data read is
    /// corrupted or otherwise invalid.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Returns: The decoded object.
    public static func decode(from decoder: Decoder) throws -> Value {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        guard
            let result = try NSKeyedUnarchiver.unarchivedObject(ofClass: Value.self, from: data)
        else {
            throw decoder._dataCorruptedError("Unable to unarchive object, result was nil")
        }
        return result
    }
}
#endif // FOUNDATION_FRAMEWORK

// MARK: AttributedString CodableWithConfiguration Conformance

/// A configuration type for encoding and decoding attributed strings.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct AttributeScopeCodableConfiguration : Sendable {
    internal let attributesTable : [String : any AttributedStringKey.Type]
    
    internal init(
        _ attributesTable: [String : any AttributedStringKey.Type]
    ) {
        self.attributesTable = attributesTable
    }
    
    internal init<S: AttributeScope>(
        _ scope: S.Type
    ) {
#if FOUNDATION_FRAMEWORK
        self.attributesTable = S.attributeKeyTypes()
#else
        self.attributesTable = [:]
#endif // FOUNDATION_FRAMEWORK
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeScope {
    /// The configuration for encoding the attribute scope.
    public static var encodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
    /// The configuration for decoding the attribute scope.
    public static var decodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
}

#if FOUNDATION_FRAMEWORK
// TODO: Support AttributedString codable conformance in FoundationPreview
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString : Codable {
    public func encode(to encoder: Encoder) throws {
        let conf = AttributeScopeCodableConfiguration(_loadDefaultAttributes())
        try encode(to: encoder, configuration: conf)
    }
    
    public init(from decoder: Decoder) throws {
        let conf = AttributeScopeCodableConfiguration(_loadDefaultAttributes())
        try self.init(from: decoder, configuration: conf)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString : CodableWithConfiguration {

    private enum CodingKeys : String, CodingKey {
        case runs
        case attributeTable
    }

    private struct AttributeKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    public func encode(to encoder: Encoder, configuration: AttributeScopeCodableConfiguration) throws {
        if self._guts.runs.count == 0 || (self._guts.runs.count == 1 && self._guts.runs.first!.attributes.isEmpty) {
            var container = encoder.singleValueContainer()
            try container.encode(String(self._guts.string))
            return
        }

        var runsContainer: UnkeyedEncodingContainer
        var attributeTable = [_AttributeStorage : Int]()
        var attributeTableNextIndex = 0
        var attributeTableContainer: UnkeyedEncodingContainer?
        if self._guts.runs.count <= 10 {
            runsContainer = encoder.unkeyedContainer()
        } else {
            var topLevelContainer = encoder.container(keyedBy: CodingKeys.self)
            runsContainer = topLevelContainer.nestedUnkeyedContainer(forKey: .runs)
            attributeTableContainer = topLevelContainer.nestedUnkeyedContainer(forKey: .attributeTable)
        }

        var currentIndex = self.startIndex._value
        for run in self._guts.runs {
            let currentEndIndex = self._guts.string.utf8.index(currentIndex, offsetBy: run.length)
            let range = currentIndex ..< currentEndIndex
            let text = String(self._guts.string.unicodeScalars[range])
            try runsContainer.encode(text)

            if !run.attributes.isEmpty, var attributeTableContainer = attributeTableContainer {
                let index = attributeTable[run.attributes, default: attributeTableNextIndex]
                if index == attributeTableNextIndex {
                    try Self.encodeAttributeContainer(
                        run.attributes,
                        to: attributeTableContainer.superEncoder(),
                        configuration: configuration)
                    attributeTable[run.attributes] = index
                    attributeTableNextIndex += 1
                }
                try runsContainer.encode(index)
            } else {
                try Self.encodeAttributeContainer(
                    run.attributes,
                    to: runsContainer.superEncoder(),
                    configuration: configuration)
            }

            currentIndex = currentEndIndex
        }
    }

    fileprivate static func encodeAttributeContainer(
        _ attributes: _AttributeStorage,
        to encoder: Encoder,
        configuration: AttributeScopeCodableConfiguration
    ) throws {
        var attributesContainer = encoder.container(keyedBy: AttributeKey.self)
        for name in attributes.keys {
            if
                let attributeKeyType = configuration.attributesTable[name],
                let encodableAttributeType = attributeKeyType as? any EncodableAttributedStringKey.Type
            {
                let attributeEncoder = attributesContainer.superEncoder(forKey: AttributeKey(stringValue: name)!)
                func project<K: EncodableAttributedStringKey>(_: K.Type) throws {
                    // We must assume that the value is Sendable here because we are dynamically iterating a scope and the attribute keys do not statically declare the values are Sendable
                    try K.encode(attributes[assumingSendable: K.self]!, to: attributeEncoder)
                }
                try project(encodableAttributeType)
            } // else: the attribute was not in the provided scope or was not encodable, so drop it
        }
    }

    public init(from decoder: Decoder, configuration: AttributeScopeCodableConfiguration) throws {
        if let svc = try? decoder.singleValueContainer(), let str = try? svc.decode(String.self) {
            self.init(str)
            return
        }

        var runsContainer: UnkeyedDecodingContainer
        var attributeTable: [_AttributeStorage]?

        if let runs = try? decoder.unkeyedContainer() {
            runsContainer = runs
            attributeTable = nil
        } else {
            let topLevelContainer = try decoder.container(keyedBy: CodingKeys.self)
            runsContainer = try topLevelContainer.nestedUnkeyedContainer(forKey: .runs)
            attributeTable = try Self.decodeAttributeTable(
                from: topLevelContainer.superDecoder(forKey: .attributeTable),
                configuration: configuration)
        }

        var string: BigString = ""
        var runs = Rope<_InternalRun>()
        var hasConstrainedAttributes = false
        while !runsContainer.isAtEnd {
            let substring = try runsContainer.decode(String.self)
            var attributes: _AttributeStorage

            if let tableIndex = try? runsContainer.decode(Int.self) {
                guard let attributeTable = attributeTable else {
                    throw decoder._dataCorruptedError(
                        "Attribute table index present with no reference attribute table")
                }
                guard tableIndex >= 0 && tableIndex < attributeTable.count else {
                    throw decoder._dataCorruptedError(
                        """
                        Attribute table index \(tableIndex) is not within the bounds of \
                        the attribute table [0...\(attributeTable.count - 1)]
                        """)
                }
                attributes = attributeTable[tableIndex]
            } else {
                attributes = try Self.decodeAttributeContainer(
                    from: try runsContainer.superDecoder(),
                    configuration: configuration)
            }

            if substring.isEmpty && (runs.count > 0 || !runsContainer.isAtEnd) {
                throw decoder._dataCorruptedError(
                    "When multiple runs are present, runs with empty substrings are not allowed")
            }
            if substring.isEmpty && !attributes.isEmpty {
                throw decoder._dataCorruptedError(
                    "Runs of empty substrings cannot contain attributes")
            }

            string.append(contentsOf: substring)
            if let previous = runs.last, previous.attributes == attributes {
                let last = runs.index(before: runs.endIndex)
                runs[last].length += substring.utf8.count
            } else {
                runs.append(_InternalRun(length: substring.utf8.count, attributes: attributes))
                if !hasConstrainedAttributes {
                    hasConstrainedAttributes = attributes.hasConstrainedAttributes
                }
            }
        }
        if runs.isEmpty {
            throw decoder._dataCorruptedError("Runs container must not be empty")
        }
        self.init(Guts(string: string, runs: _InternalRuns(runs)))
        self._guts.adjustConstrainedAttributesForUntrustedRuns()
    }

    private static func decodeAttributeTable(
        from decoder: Decoder,
        configuration: AttributeScopeCodableConfiguration
    ) throws -> [_AttributeStorage] {
        var container = try decoder.unkeyedContainer()
        var table = [_AttributeStorage]()
        if let size = container.count {
            table.reserveCapacity(size)
        }
        while !container.isAtEnd {
            table.append(try decodeAttributeContainer(from: try container.superDecoder(), configuration: configuration))
        }
        return table
    }

    fileprivate static func decodeAttributeContainer(
        from decoder: Decoder,
        configuration: AttributeScopeCodableConfiguration
    ) throws -> _AttributeStorage {
        let attributesContainer = try decoder.container(keyedBy: AttributeKey.self)
        var attributes = _AttributeStorage()
        for key in attributesContainer.allKeys {
            let name = key.stringValue
            if
                let attributeKeyType = configuration.attributesTable[name],
                let decodableAttributeType = attributeKeyType as? any DecodableAttributedStringKey.Type
            {
                func project<K: DecodableAttributedStringKey>(_: K.Type) throws {
                    // We must assume that the value is Sendable here because we are dynamically iterating a scope and the attribute keys do not statically declare the values are Sendable
                    attributes[assumingSendable: K.self] = try K.decode(from: try attributesContainer.superDecoder(forKey: key))
                }
                try project(decodableAttributeType)
            }
            // else: the attribute was not in the provided scope or wasn't decodable, so drop it
        }
        return attributes
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributeContainer : CodableWithConfiguration {
    public func encode(to encoder: Encoder, configuration: AttributeScopeCodableConfiguration) throws {
        try AttributedString.encodeAttributeContainer(self.storage, to: encoder, configuration: configuration)
    }

    public init(from decoder: Decoder, configuration: AttributeScopeCodableConfiguration) throws {
        self.storage = try AttributedString.decodeAttributeContainer(from: decoder, configuration: configuration)
    }
}

#endif // FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension CodableConfiguration where ConfigurationProvider : AttributeScope {
    /// Creates a codable configuration wrapper for the given value, using given configuration provider type identified by key path.
    ///
    /// - Parameters:
    ///   - wrappedValue: The underlying value to make codable, using data from the configuration provider.
    ///   - keyPath: A key path that identifies the type of the configuration provider, which provides additional information to encode `wrappedValue`.
    public init(wrappedValue: T, from keyPath: KeyPath<AttributeScopes, ConfigurationProvider.Type>) {
        self.wrappedValue = wrappedValue
    }
}
