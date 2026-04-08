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

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

/// An internal enum representing all the types that `CommonDecoder` supports.
/// This serves as the `DecodedValue` type for bridging between CommonDecoder and standard Decodable.
internal enum CommonElement {
    case bool(Bool)
    case int64(Int64)
    case uint64(UInt64)
    case int128(Int128)
    case uint128(UInt128)
    case double(Double)
    case string(String)
    case bytes([UInt8])
    case null
    case dictionary([(key: String, value: CommonElement)])
    case array([CommonElement])
}

/// A visitor that adapts decoded values for use with standard `Decodable` types.
///
/// This visitor captures raw values from `decodeAny` as `CommonElement` values
/// and then converts them to `AdaptorDecoder` for standard decoding.
internal struct CommonElementVisitor: CommonDecodingVisitor {
    typealias DecodedValue = CommonElement
    
    init() {}
    
    func visit(_ value: Bool) throws(CodingError.Decoding) -> CommonElement {
        return .bool(value)
    }
    
    func visit(_ value: Int) throws(CodingError.Decoding) -> CommonElement {
        return .int64(Int64(value))
    }
    
    func visit(_ value: Int8) throws(CodingError.Decoding) -> CommonElement {
        return .int64(Int64(value))
    }
    
    func visit(_ value: Int16) throws(CodingError.Decoding) -> CommonElement {
        return .int64(Int64(value))
    }
    
    func visit(_ value: Int32) throws(CodingError.Decoding) -> CommonElement {
        return .int64(Int64(value))
    }
    
    func visit(_ value: Int64) throws(CodingError.Decoding) -> CommonElement {
        return .int64(value)
    }
    
    func visit(_ value: Int128) throws(CodingError.Decoding) -> CommonElement {
        return .int128(value)
    }
    
    func visit(_ value: UInt) throws(CodingError.Decoding) -> CommonElement {
        return .uint64(UInt64(value))
    }
    
    func visit(_ value: UInt8) throws(CodingError.Decoding) -> CommonElement {
        return .uint64(UInt64(value))
    }
    
    func visit(_ value: UInt16) throws(CodingError.Decoding) -> CommonElement {
        return .uint64(UInt64(value))
    }
    
    func visit(_ value: UInt32) throws(CodingError.Decoding) -> CommonElement {
        return .uint64(UInt64(value))
    }
    
    func visit(_ value: UInt64) throws(CodingError.Decoding) -> CommonElement {
        return .uint64(value)
    }
    
    func visit(_ value: UInt128) throws(CodingError.Decoding) -> CommonElement {
        return .uint128(value)
    }
    
    func visit(_ value: Float) throws(CodingError.Decoding) -> CommonElement {
        return .double(Double(value))
    }
    
    func visit(_ value: Double) throws(CodingError.Decoding) -> CommonElement {
        return .double(value)
    }
    
    func visitString(_ value: String) throws(CodingError.Decoding) -> CommonElement {
        return .string(value)
    }
    
    func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> CommonElement {
        // Convert UTF8Span to String using the proper API
        let string = String(copying: buffer)
        return .string(string)
    }
    
    func visitBytes(_ array: [UInt8]) throws(CodingError.Decoding) -> CommonElement {
        return .bytes(array)
    }
    
    func visit(decoder: inout some CommonStructDecoder & ~Escapable) throws(CodingError.Decoding) -> CommonElement {
        var result: [(key: String, value: CommonElement)] = []
        
        try decoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
            let elementVisitor = CommonElementVisitor()
            let element = try valueDecoder.decodeAny(elementVisitor)
            result.append((key: key, value: element))
            return false
        }
        
        return .dictionary(result)
    }
    
    func visit(decoder: inout some CommonArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> CommonElement {
        var result: [CommonElement] = []
        
        try decoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
            let elementVisitor = CommonElementVisitor()
            let element = try elementDecoder.decodeAny(elementVisitor)
            result.append(element)
        }
        
        return .array(result)
    }
    
    func visitNone() throws(CodingError.Decoding) -> CommonElement {
        return .null
    }
}

extension CommonElement: AdaptableDecodableValue {
    typealias ArrayIterator = Array<CommonElement>.Iterator
    
    func decodeNil(context: AdaptorDecodableValueContext<CommonElement>) -> Bool {
        if case .null = self {
            return true
        }
        return false
    }
    
    func decode(_ type: Bool.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Bool {
        if case .bool(let value) = self {
            return value
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected Bool but found \(self)")
    }
    
    func decode(_ type: Int.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int {
        switch self {
        case .int64(let value):
            guard let result = Int(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as Int")
            }
            return result
        case .uint64(let value):
            guard let result = Int(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as Int")
            }
            return result
        case .int128(let value):
            guard let result = Int(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as Int")
            }
            return result
        case .uint128(let value):
            guard let result = Int(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Int8.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int8 {
        switch self {
        case .int64(let value):
            guard let result = Int8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as Int8")
            }
            return result
        case .uint64(let value):
            guard let result = Int8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as Int8")
            }
            return result
        case .int128(let value):
            guard let result = Int8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as Int8")
            }
            return result
        case .uint128(let value):
            guard let result = Int8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int8")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Int16.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int16 {
        switch self {
        case .int64(let value):
            guard let result = Int16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as Int16")
            }
            return result
        case .uint64(let value):
            guard let result = Int16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as Int16")
            }
            return result
        case .int128(let value):
            guard let result = Int16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as Int16")
            }
            return result
        case .uint128(let value):
            guard let result = Int16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int16")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Int32.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int32 {
        switch self {
        case .int64(let value):
            guard let result = Int32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as Int32")
            }
            return result
        case .uint64(let value):
            guard let result = Int32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as Int32")
            }
            return result
        case .int128(let value):
            guard let result = Int32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as Int32")
            }
            return result
        case .uint128(let value):
            guard let result = Int32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int32")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Int64.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int64 {
        switch self {
        case .int64(let value):
            return value
        case .uint64(let value):
            guard let result = Int64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as Int64")
            }
            return result
        case .int128(let value):
            guard let result = Int64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as Int64")
            }
            return result
        case .uint128(let value):
            guard let result = Int64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int64")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Int128.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Int128 {
        switch self {
        case .int64(let value):
            return Int128(value)
        case .uint64(let value):
            return Int128(value)
        case .int128(let value):
            return value
        case .uint128(let value):
            guard let result = Int128(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as Int128")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt {
        switch self {
        case .int64(let value):
            guard let result = UInt(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt")
            }
            return result
        case .uint64(let value):
            guard let result = UInt(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as UInt")
            }
            return result
        case .int128(let value):
            guard let result = UInt(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt")
            }
            return result
        case .uint128(let value):
            guard let result = UInt(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as UInt")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt8.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt8 {
        switch self {
        case .int64(let value):
            guard let result = UInt8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt8")
            }
            return result
        case .uint64(let value):
            guard let result = UInt8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as UInt8")
            }
            return result
        case .int128(let value):
            guard let result = UInt8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt8")
            }
            return result
        case .uint128(let value):
            guard let result = UInt8(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as UInt8")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt16.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt16 {
        switch self {
        case .int64(let value):
            guard let result = UInt16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt16")
            }
            return result
        case .uint64(let value):
            guard let result = UInt16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as UInt16")
            }
            return result
        case .int128(let value):
            guard let result = UInt16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt16")
            }
            return result
        case .uint128(let value):
            guard let result = UInt16(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as UInt16")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt32.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt32 {
        switch self {
        case .int64(let value):
            guard let result = UInt32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt32")
            }
            return result
        case .uint64(let value):
            guard let result = UInt32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt64 value \(value) cannot be represented as UInt32")
            }
            return result
        case .int128(let value):
            guard let result = UInt32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt32")
            }
            return result
        case .uint128(let value):
            guard let result = UInt32(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as UInt32")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt64.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt64 {
        switch self {
        case .int64(let value):
            guard let result = UInt64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt64")
            }
            return result
        case .uint64(let value):
            return value
        case .int128(let value):
            guard let result = UInt64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt64")
            }
            return result
        case .uint128(let value):
            guard let result = UInt64(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "UInt128 value \(value) cannot be represented as UInt64")
            }
            return result
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: UInt128.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> UInt128 {
        switch self {
        case .int64(let value):
            guard let result = UInt128(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int64 value \(value) cannot be represented as UInt128")
            }
            return result
        case .uint64(let value):
            return UInt128(value)
        case .int128(let value):
            guard let result = UInt128(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Int128 value \(value) cannot be represented as UInt128")
            }
            return result
        case .uint128(let value):
            return value
        default:
            throw CodingError.dataCorrupted(debugDescription: "Expected integer but found \(self)")
        }
    }
    
    func decode(_ type: Float.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Float {
        if case .double(let value) = self {
            guard let result = Float(exactly: value) else {
                throw CodingError.dataCorrupted(debugDescription: "Double value \(value) cannot be represented as Float")
            }
            return result
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected Double but found \(self)")
    }
    
    func decode(_ type: Double.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> Double {
        if case .double(let value) = self {
            return value
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected Double but found \(self)")
    }
    
    func decode(_ type: String.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> String {
        if case .string(let value) = self {
            return value
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected String but found \(self)")
    }
    
    func decode<U: Decodable>(_ type: U.Type, context: AdaptorDecodableValueContext<CommonElement>) throws -> U {
        // For generic Decodable types, we need to recursively create an AdaptorDecoder
        let decoder = AdaptorDecoder(value: self, decoderContext: context.decoderContext, codingPath: context.codingPath)
        do {
            return try U(from: decoder)
        } catch {
            // Convert any error to CodingError.unsupportedDecodingType
            throw CodingError.dataCorrupted(debugDescription: "Failed to decode \(U.self): \(error)")
        }
    }
    
    func makeDictionary(context: AdaptorDecodableValueContext<CommonElement>) throws -> [String : CommonElement] {
        if case .dictionary(let keyValuePairs) = self {
            var result: [String: CommonElement] = [:]
            for pair in keyValuePairs {
                result[pair.key] = pair.value
            }
            return result
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected dictionary but found \(self)")
    }
    
    func makeArrayIterator(context: AdaptorDecodableValueContext<CommonElement>) throws -> (Array<CommonElement>.Iterator, countHint: Int?) {
        if case .array(let elements) = self {
            return (elements.makeIterator(), elements.count)
        }
        throw CodingError.dataCorrupted(debugDescription: "Expected array but found \(self)")
    }
}
