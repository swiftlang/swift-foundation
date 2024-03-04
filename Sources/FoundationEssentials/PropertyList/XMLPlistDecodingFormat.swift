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

// MARK: - _XMLPlistDecodingFormat

internal struct _XMLPlistDecodingFormat : PlistDecodingFormat {
    typealias Map = XMLPlistMap
    
    static func container<Key: CodingKey>(keyedBy type: Key.Type, for value: Map.Value, referencing decoder: _PlistDecoder<Self>, codingPathNode: _CodingPathNode) throws -> KeyedDecodingContainer<Key> {
        switch value {
        case let .dict(startOffset, count):
            let iterator = decoder.map.makeDictionaryIterator(from: startOffset)
            let container = try _PlistKeyedDecodingContainer<Key, _XMLPlistDecodingFormat>(referencing: decoder, codingPathNode: codingPathNode, iterator: iterator, count: count)
            return KeyedDecodingContainer(container)
        case .null:
            throw DecodingError.valueNotFound([String: Any].self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot get keyed decoding container -- found null value instead"))
        default:
            throw DecodingError._typeMismatch(at: decoder.codingPath, expectation: [String : Any].self, reality: value)
        }
    }

    static func unkeyedContainer(for value: Map.Value, referencing decoder: _PlistDecoder<Self>, codingPathNode: _CodingPathNode) throws -> UnkeyedDecodingContainer {
        switch value {
        case let .array(startOffset, count):
            let iterator = decoder.map.makeArrayIterator(from: startOffset)
            return _PlistUnkeyedDecodingContainer(referencing: decoder, codingPathNode: codingPathNode, iterator: iterator, count: count)
        case .null:
            throw DecodingError.valueNotFound([Any].self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot get unkeyed decoding container -- found null value instead"))
        default:
            throw DecodingError._typeMismatch(at: decoder.codingPath, expectation: [Any].self, reality: value)
        }
    }
    
    @inline(__always)
    static func valueIsNull(_ mapValue: Map.Value) -> Bool {
        guard case .null = mapValue else {
            return false
        }
        return true
    }
    
    static func unwrapBool(from mapValue: Map.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Bool {
        guard case let .boolean(value) = mapValue else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Bool.self, reality: mapValue)
        }
        return value
    }
    
    static func unwrapDate(from mapValue: Map.Value, in map: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date {
        return try mapValue.dateValue(in: map, for: codingPathNode, additionalKey)
    }
    
    static func unwrapData(from mapValue: Map.Value, in map: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data {
        return try mapValue.dataValue(in: map, for: codingPathNode, additionalKey)
    }
    
    static func unwrapString(from mapValue: Map.Value, in map: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> String {
        guard case let .string(region, _, isSimple) = mapValue else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: String.self, reality: mapValue)
        }
        return try map.withBuffer(for: region) { buffer, fullSource in
            if isSimple {
                guard let string = String._tryFromUTF8(buffer) else {
                    let reader = BufferReader(bytes: buffer, fullSource: fullSource)
                    throw DecodingError._dataCorrupted("Unable to convert string to correct encoding at line \(reader.lineNumber)", for: codingPathNode.appending(additionalKey))
                }
                return string
            } else {
                var reader = BufferReader(bytes: buffer, fullSource: fullSource)
                return try XMLPlistScanner.parseString(with: &reader, generate: true).2
            }
        }
    }
    
    static func unwrapFloatingPoint<T: BinaryFloatingPoint>(from mapValue: Map.Value, in map: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        try mapValue.realValue(in: map, as: T.self, for: codingPathNode, additionalKey)
    }
    
    static func unwrapFixedWidthInteger<T: FixedWidthInteger>(from mapValue: Map.Value, in map: Map, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        try mapValue.integerValue(in: map, as: T.self, for: codingPathNode, additionalKey)
    }
}
