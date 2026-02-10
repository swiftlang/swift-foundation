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

struct _BPlistDecodingFormat : PlistDecodingFormat {
    typealias Map = BPlistMap
    
    static func container<Key>(keyedBy type: Key.Type, for value: BPlistMap.Value, referencing decoder: _PlistDecoder<_BPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        switch value {
        case let .dict(dict):
            let iter = Map.DictionaryIterator.init(iter: dict.makeIterator())
            let container = try _PlistKeyedDecodingContainer<Key, Self>(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: dict.count)
            return KeyedDecodingContainer(container)
        case .nativeNull, .sentinelNull:
            throw DecodingError.valueNotFound([String: Any].self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot get keyed decoding container -- found null value instead"))
        default:
            throw DecodingError._typeMismatch(at: decoder.codingPath, expectation: [String : Any].self, reality: value)
        }
    }
    
    static func unkeyedContainer(for value: BPlistMap.Value, referencing decoder: _PlistDecoder<_BPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> UnkeyedDecodingContainer {
        switch value {
        case let .array(array):
            let iter = Map.ArrayIterator(iter: array.makeIterator())
            return _PlistUnkeyedDecodingContainer(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: array.count)
        case .nativeNull, .sentinelNull:
            throw DecodingError.valueNotFound([Any].self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot get unkeyed decoding container -- found null value instead"))
        default:
            throw DecodingError._typeMismatch(at: decoder.codingPath, expectation: [Any].self, reality: value)
        }
    }
    
    static func valueIsNull(_ mapValue: BPlistMap.Value) -> Bool {
        switch mapValue {
        case .nativeNull, .sentinelNull: return true
        default: return false
        }
    }
    
    static func unwrapBool(from mapValue: BPlistMap.Value, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Bool {
        guard case let .boolean(value) = mapValue else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Bool.self, reality: mapValue)
        }
        return value
    }
    
    static func unwrapDate(from mapValue: BPlistMap.Value, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date {
        return try mapValue.dateValue(in: map, for: codingPathNode, additionalKey)
    }
    
    static func unwrapData(from mapValue: BPlistMap.Value, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data {
        return try mapValue.dataValue(in: map, for: codingPathNode, additionalKey)
    }
    
    static func unwrapString(from mapValue: BPlistMap.Value, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> String {
        guard case let .string(region, isAscii) = mapValue else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: String.self, reality: mapValue)
        }
        let result = map.withBuffer(for: region) { buffer, _ in
            String(bytes: buffer, encoding: isAscii ? .ascii : .utf16BigEndian)
        }
        guard let result else {
            throw DecodingError._dataCorrupted("Unable to read string", for: codingPathNode.appending(additionalKey))
        }
        return result
    }
    
    @_lifetime(borrow map)
    static func stringSpan(from mapValue: BPlistMap.Value, isAscii outIsAscii: inout Bool, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Span<UInt8> {
        guard case let .string(region, isAscii) = mapValue else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: String.self, reality: mapValue)
        }
        outIsAscii = isAscii
        return map.span(for: region)
    }
    
    static func unwrapFloatingPoint<T : BinaryFloatingPoint>(from mapValue: BPlistMap.Value, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        try mapValue.realValue(in: map, as: T.self, for: codingPathNode, additionalKey)
    }
    
    static func unwrapFixedWidthInteger<T>(from mapValue: BPlistMap.Value, in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T where T : FixedWidthInteger {
        try mapValue.integerValue(in: map, as: T.self, for: codingPathNode, additionalKey)
    }
}
