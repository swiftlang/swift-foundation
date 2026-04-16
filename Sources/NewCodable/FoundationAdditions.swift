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
#elseif canImport(Foundation)
import Foundation
#endif

internal extension Data {
    init(_copying span: RawSpan) {
        self = span.withUnsafeBytes {
            Data($0)
        }
    }
}

// TODO: Move to Foundation + JSON cross-module import.

extension NewJSONDecoder {
    @_alwaysEmitIntoClient
    public func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T {
        try self.decode(type, from: data.bytes)
    }

    @_disfavoredOverload
    @_alwaysEmitIntoClient
    public func decode<T: CommonDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T {
        try self.decode(type, from: data.bytes)
    }
}

extension NewJSONEncoder {
    public func encode(_ value: borrowing some JSONEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        let bytes: GrowableEncodingBytes = try self.encode(value)

        let (storage, count) = bytes.deconstruct()
        guard let pointer = storage.baseAddress else { return Data() }
        return Data(bytesNoCopy: pointer, count: count, deallocator: .custom({ptr, _ in ptr.deallocate() }))
    }

    public func encode(_ value: borrowing some JSONEncodable & CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        @_transparent func asJSON<TAsJSON: JSONEncodable & ~Copyable>(_ value: borrowing TAsJSON) throws(CodingError.Encoding) -> Data {
            try self.encode(value)
        }
        return try asJSON(value)
    }

    public func encode(_ value: borrowing some CommonEncodable & ~Copyable) throws(CodingError.Encoding) -> Data {
        let bytes: GrowableEncodingBytes = try self.encode(value)

        let (storage, count) = bytes.deconstruct()
        guard let pointer = storage.baseAddress else { return Data() }
        return Data(bytesNoCopy: pointer, count: count, deallocator: .custom({ptr, _ in ptr.deallocate() }))
    }
}

extension Data: JSONDecodable {
    public static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        try decoder.decodeBytes(visitor: Visitor())
    }
}

extension Date: JSONDecodable {
    public static func decode(from decoder: inout some (JSONDecoderProtocol & ~Escapable)) throws(CodingError.Decoding) -> Self {
        let interval = try decoder.decode(TimeInterval.self)
        return .init(timeIntervalSinceReferenceDate: interval)
    }
}

extension Data: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeBytes(self.bytes)
    }
}

extension Date: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self.timeIntervalSinceReferenceDate)
    }
}

// MARK: CommonCodable Adoption

extension Date: CommonDecodable {
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self {
        let interval = try decoder.decode(TimeInterval.self)
        return .init(timeIntervalSinceReferenceDate: interval)
    }
}

extension Data: CommonDecodable {
    struct Visitor: DecodingBytesVisitor {
        typealias DecodedValue = Data
        func visitBytes(_ span: RawSpan) throws(CodingError.Decoding) -> DecodedValue {
            span.withUnsafeBytes {
                Data($0)
            }
        }

        func visitBytes(_ array: [UInt8]) throws(CodingError.Decoding) -> DecodedValue {
            Data(array)
        }
    }

    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self {
        try decoder.decodeBytes(visitor: Visitor())
    }
}

extension Date: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self.timeIntervalSinceReferenceDate)
    }
}

extension Data: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeBytes(self.bytes)
    }
}

// Building blocks for Date/Data strategy implementations.

//extension JSONParserDecoder {
//    internal struct Base64Visitor: DecodingStringVisitor {
//        public typealias DecodedValue = Data
//        public func visitString(_ string: String) throws(CodingError.Decoding) -> Data {
//            guard let result = Data(base64Encoded: string) else {
//                throw CodingError.dataCorrupted(debugDescription: "Invalid base64 encoded string")
//            }
//            return result
//        }
//        public func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> Data {
//            // TODO: No-copy
//            guard let result = Data(base64Encoded: Data(_copying: buffer.span.bytes)) else {
//                throw CodingError.dataCorrupted(debugDescription: "Invalid base64 encoded string")
//            }
//            return result
//        }
//        public init() { }
//    }
//
//    internal enum DateNumberVisitor: DecodingNumberVisitor {
//        typealias DecodedValue = Date
//
//        case referenceDate
//        case secondsSince1970
//        case msSince1970
//
//        func visit(_ integer: Int64) throws(CodingError.Decoding) -> Date {
//            switch self {
//            case .referenceDate:
//                Date(timeIntervalSinceReferenceDate: TimeInterval(integer))
//            case .secondsSince1970:
//                Date(timeIntervalSince1970: TimeInterval(integer))
//            case .msSince1970:
//                Date(timeIntervalSince1970: TimeInterval(integer) / 1000.0)
//            }
//        }
//        func visit(_ integer: UInt64) throws(CodingError.Decoding) -> Date {
//            switch self {
//            case .referenceDate:
//                Date(timeIntervalSinceReferenceDate: TimeInterval(integer))
//            case .secondsSince1970:
//                Date(timeIntervalSince1970: TimeInterval(integer))
//            case .msSince1970:
//                Date(timeIntervalSince1970: TimeInterval(integer) / 1000.0)
//            }
//        }
//        func visit(_ double: Double) throws(CodingError.Decoding) -> Date {
//            switch self {
//            case .referenceDate:
//                Date(timeIntervalSinceReferenceDate: TimeInterval(double))
//            case .secondsSince1970:
//                Date(timeIntervalSince1970: TimeInterval(double))
//            case .msSince1970:
//                Date(timeIntervalSince1970: TimeInterval(double) / 1000.0)
//            }
//        }
//    }
//
//    internal enum DateStringVistior: DecodingStringVisitor {
//        typealias DecodedValue = Date
//
//        case iso8601
//        case formatted(any ParseStrategy)
//
//        // TODO: I'd probably prefer the default to be the other way in this case. Or maybe they both need defaults?
//
//        func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> Date {
//            // TODO: Inefficient.
//            return try visitString(String(copying: buffer))
//        }
//
//        // TODO: opening the existential here unhappily, since ParseStrategy doesn't have primary associated types.
//        func useParseStrategy<S: ParseStrategy>(_ strategy: S, on input: String) throws(CodingError.Decoding) -> Date {
//            do {
//                return try strategy.parse(input as! S.ParseInput) as! Date
//            } catch {
//                fatalError("TODO: Convert/wrap error")
//            }
//        }
//
//        func visitString(_ string: String) throws(CodingError.Decoding) -> Date {
//            switch self {
//            case .iso8601:
//                guard let date = try? Date.ISO8601FormatStyle().parse(string) else {
//                    throw CodingError.dataCorrupted(debugDescription: "IS08601 date parsing failed")
//                }
//                return date
//            case .formatted(let parseStrategy):
//                return try self.useParseStrategy(parseStrategy, on: string)
//            }
//        }
//    }
//}
