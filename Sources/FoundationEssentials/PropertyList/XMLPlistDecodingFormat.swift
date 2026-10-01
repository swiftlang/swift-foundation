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


#if FOUNDATION_FRAMEWORK || !os(macOS)

/// `PlistDecodingFormat` conformer plugging `XMLPlistDecodingDocument` into the generic `_PlistDecoder<Format>` machinery. Errors thrown by the primitive layer (`XMLPlistError`) are translated to `DecodingError` at the boundary via `_translatePrimitiveError`.
@available(anyAppleOS 26.0, *)
struct XMLPlistDecodingFormat: PlistDecodingFormat {
    typealias Document = XMLPlistDecodingDocument

    /// Build a `.typeMismatch` `DecodingError` whose message reports the actual primitive type at `scope` (reconstituted via `document.withPrimitive`), matching the legacy `XMLPlistMapValue` output.
    @inline(__always)
    static func _typeMismatchError(document: XMLPlistDecodingDocument, scope: XMLPlistPrimitiveScope, path: [CodingKey], expectation: Any.Type) -> DecodingError {
        let reality = document.withPrimitive(for: scope) { $0.debugDataTypeDescription }
        return .typeMismatch(expectation, .init(codingPath: path, debugDescription: "Expected to decode \(expectation) but found \(reality) instead."))
    }

    static func container<Key>(keyedBy type: Key.Type, for value: XMLPlistPrimitiveScope, referencing decoder: _PlistDecoder<XMLPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = try _translatePrimitiveError(document: decoder.document, scope: value, codingPathNode: codingPathNode, additionalKey: _CodingKey?.none, expectation: [String : Any].self) {
            try decoder.document.withPrimitive(for: value) { primitive in
                let primitiveIter = try primitive.dictionaryIterator
                let iter = XMLPlistDecodingDocument.DictionaryIterator(primitiveIter)
                return try _PlistKeyedDecodingContainer<Key, Self>(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: primitiveIter.count &* 2)
            }
        }
        return KeyedDecodingContainer(container)
    }

    static func unkeyedContainer(for value: XMLPlistPrimitiveScope, referencing decoder: _PlistDecoder<XMLPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> UnkeyedDecodingContainer {
        let firstChild: (offset: XMLPlistMapOffset, count: Int) = try _translatePrimitiveError(document: decoder.document, scope: value, codingPathNode: codingPathNode, additionalKey: _CodingKey?.none, expectation: [Any].self) {
            try decoder.document.withPrimitive(for: value) { primitive in
                let primitiveIter = try primitive.arrayIterator
                return (primitiveIter.currentOffset, primitiveIter.count)
            }
        }
        let iter = XMLPlistDecodingDocument.ArrayIterator(document: decoder.document, nextChildOffset: firstChild.offset, elementsRemaining: firstChild.count)
        return _PlistUnkeyedDecodingContainer(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: firstChild.count)
    }

    @inline(__always)
    static func valueIsNull(_ mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument) -> Bool {
        document.withPrimitive(for: mapValue) { $0.isNull }
    }

    static func unwrapBool(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Bool {
        do {
            return try document.withPrimitive(for: mapValue) { try $0.boolValue }
        } catch {
            throw _typeMismatchError(document: document, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: Bool.self)
        }
    }

    static func unwrapDate(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date {
        try _translatePrimitiveError(document: document, scope: mapValue, codingPathNode: codingPathNode, additionalKey: additionalKey, expectation: Date.self) {
            try document.withPrimitive(for: mapValue) { try $0.decodeDate() }
        }
    }

    static func unwrapData(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data {
        try _translatePrimitiveError(document: document, scope: mapValue, codingPathNode: codingPathNode, additionalKey: additionalKey, expectation: Data.self) {
            try document.withPrimitive(for: mapValue) { try $0.decodeData() }
        }
    }

    static func unwrapString(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> String {
        try _translatePrimitiveError(document: document, scope: mapValue, codingPathNode: codingPathNode, additionalKey: additionalKey, expectation: String.self) {
            try document.withPrimitive(for: mapValue) { try $0.decodeString() }
        }
    }

    static func unwrapFloatingPoint<T: BinaryFloatingPoint & Sendable>(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        try _translatePrimitiveError(document: document, scope: mapValue, codingPathNode: codingPathNode, additionalKey: additionalKey, expectation: T.self) {
            try document.withPrimitive(for: mapValue) { try $0.decodeReal(as: T.self) }
        }
    }

    static func unwrapFixedWidthInteger<T: FixedWidthInteger & Sendable>(from mapValue: XMLPlistPrimitiveScope, in document: XMLPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        try _translatePrimitiveError(document: document, scope: mapValue, codingPathNode: codingPathNode, additionalKey: additionalKey, expectation: T.self) {
            try document.withPrimitive(for: mapValue) { try $0.decodeInteger(as: T.self) }
        }
    }

    /// Translate `XMLPlistError` thrown by a primitive-level decoder into the appropriate `DecodingError` variant.
    private static func _translatePrimitiveError<T>(document: XMLPlistDecodingDocument, scope: XMLPlistPrimitiveScope, codingPathNode: _CodingPathNode, additionalKey: (some CodingKey)?, expectation: Any.Type, _ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let e as XMLPlistError {
            switch e {
            case .typeMismatch:
                throw _typeMismatchError(document: document, scope: scope, path: codingPathNode.path(byAppending: additionalKey), expectation: expectation)
            case .corruptedValue(let label):
                throw DecodingError._dataCorrupted("Corrupt <\(label)> value", for: codingPathNode, additionalKey)
            case .unexpectedEndOfFile, .malformedTag, .unexpectedEmptyTag, .unexpectedCharacter,
                 .unknownEscape, .cannotConvertToUTF8, .other:
                // Structural / encoding failures. Not type confusion, so report the error's own description.
                throw DecodingError._dataCorrupted(e.debugDescription, for: codingPathNode, additionalKey)
            }
        }
    }
}

#endif  // FOUNDATION_FRAMEWORK || !os(macOS)
