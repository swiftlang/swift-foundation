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
@_implementationOnly @_spi(Unstable) import CollectionsInternal
#else
import _RopeModule
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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol EncodableAttributedStringKey : AttributedStringKey {
    static func encode(_ value: Value, to encoder: Encoder) throws
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol DecodableAttributedStringKey : AttributedStringKey {
    static func decode(from decoder: Decoder) throws -> Value
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias CodableAttributedStringKey = EncodableAttributedStringKey & DecodableAttributedStringKey

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension EncodableAttributedStringKey where Value : Encodable {
    static func encode(_ value: Value, to encoder: Encoder) throws { try value.encode(to: encoder) }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension DecodableAttributedStringKey where Value : Decodable {
    static func decode(from decoder: Decoder) throws -> Value { return try Value.init(from: decoder) }
}


@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol MarkdownDecodableAttributedStringKey : AttributedStringKey {
    static func decodeMarkdown(from decoder: Decoder) throws -> Value
    static var markdownName: String { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension MarkdownDecodableAttributedStringKey {
    static var markdownName: String { name }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension MarkdownDecodableAttributedStringKey where Self : DecodableAttributedStringKey {
    static func decodeMarkdown(from decoder: Decoder) throws -> Value { try Self.decode(from: decoder) }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension EncodableAttributedStringKey where Value : NSSecureCoding & NSObject {
    static func encode(_ value: Value, to encoder: Encoder) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension DecodableAttributedStringKey where Value : NSSecureCoding & NSObject {
    static func decode(from decoder: Decoder) throws -> Value {
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
public extension AttributeScope {
    static var encodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
    static var decodingConfiguration: AttributeScopeCodableConfiguration { AttributeScopeCodableConfiguration(Self.self) }
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
        if self._guts.runs.count == 0 || (self._guts.runs.count == 1 && self._guts.runs[0].attributes.isEmpty) {
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

        var currentIndex = self.startIndex
        for run in self._guts.runs {
            let currentEndIndex = self._guts.utf8Index(currentIndex, offsetBy: run.length)
            let range = (currentIndex ..< currentEndIndex)._bstringRange
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
                    try K.encode(attributes[K.self]!, to: attributeEncoder)
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
        var runs = [_InternalRun]()
        var hasConstrainedAttributes = false
        if let containerCount = runsContainer.count {
            runs.reserveCapacity(containerCount / 2)
        }
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
                runs[runs.count - 1].length += substring.utf8.count
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
        self.init(Guts(string: string, runs: runs))
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
                    attributes[K.self] = try K.decode(from: try attributesContainer.superDecoder(forKey: key))
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
public extension CodableConfiguration where ConfigurationProvider : AttributeScope {
    init(wrappedValue: T, from keyPath: KeyPath<AttributeScopes, ConfigurationProvider.Type>) {
        self.wrappedValue = wrappedValue
    }
}
