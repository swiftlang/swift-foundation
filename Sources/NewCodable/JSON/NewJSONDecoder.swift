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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
import WASILibc
#endif

public struct NewJSONDecoder {
    @usableFromInline
    internal var options: Options
    
    public struct Options {
        
        /// The strategy to use for decoding `Date` values.
        public struct DateDecodingStrategy : Sendable {
            internal enum _Storage: @unchecked Sendable {
                case deferredToDate
                case secondsSince1970
                case millisecondsSince1970
                case iso8601
                case formatted(any ParseStrategy)
            }
            internal let storage: _Storage
            
            /// Defer to `Date` for decoding. This is the default strategy.
            public static var deferredToDate: Self {
                .init(storage: .deferredToDate)
            }
            
            /// Decode the `Date` as a UNIX timestamp from a JSON number.
            public static var secondsSince1970: Self {
                .init(storage: .secondsSince1970)
            }
            
            /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
            public static var millisecondsSince1970: Self {
                .init(storage: .millisecondsSince1970)
            }
            
            /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
            public static var iso8601: Self {
                .init(storage: .iso8601)
            }
            
            /// Decode the `Date` as a string parsed by the given strategy.
            public static func formatted<S: ParseStrategy & Sendable>(_ style: S) -> Self where S.ParseInput == String, S.ParseOutput == Date {
                .init(storage: .formatted(style))
            }
        }
        
        /// The strategy to use for decoding `Data` values.
        public enum DataDecodingStrategy : Sendable {
            
            /// Defer to `Data` for decoding.
            case deferredToData
            
            /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
            case base64
        }
        
        /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
        public enum NonConformingFloatDecodingStrategy : Sendable {
            /// Throw upon encountering non-conforming values. This is the default strategy.
            case `throw`
            
            /// Decode the values using the given representation strings.
            case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
        }
        
        var assumesTopLevelDictionary = false // TODO: Unimplemented
        internal var dataDecodingStrategy: DataDecodingStrategy
        internal var dateDecodingStrategy: DateDecodingStrategy
        internal var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy
        
        public init(assumesTopLevelDictionary: Bool = false,
                    dataDecodingStrategy: DataDecodingStrategy = .base64,
                    dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
                    nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw) {
            self.assumesTopLevelDictionary = assumesTopLevelDictionary
            self.dataDecodingStrategy = dataDecodingStrategy
            self.dateDecodingStrategy = dateDecodingStrategy
            self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        }
    }
    
    public init(options: Options = .init()) {
        self.options = options
    }
    
    @usableFromInline
    internal func _decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from data: Data, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(span: data.span.bytes, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }
    
    @inlinable
    public func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T {
        try _decode(type, from: data) { inner throws(CodingError.Decoding) in
            try inner.decode(type)
        }
    }

    @usableFromInline
    internal func _decode<T: CommonDecodable>(_ type: T.Type, from data: Data, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(span: data.span.bytes, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }

    @_disfavoredOverload
    @inlinable
    public func decode<T: CommonDecodable>(_ type: T.Type, from data: Data) throws(CodingError.Decoding) -> T {
        try _decode(type, from: data) { parserDecoder throws(CodingError.Decoding) in
            try parserDecoder.decode(type)
        }
    }
}

@usableFromInline
protocol PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: borrowing RawSpan)
}

extension Double : PrevalidatedJSONNumberBufferConvertible {
    @usableFromInline
    init?(prevalidatedBuffer buffer: borrowing RawSpan) {
        let decodedValue = buffer.withUnsafeBytes { buff -> Double? in
            // TODO: Trying to diagnose why floating point parsing is failing w
//            if let str = String._tryFromUTF8(buff.bindMemory(to: UInt8.self)) {
//                print("Parsing: \(str) from baseAddress \(buff.baseAddress!)")
//            }
            
            var endPtr: UnsafeMutablePointer<CChar>? = nil
            // TODO: strtoX_l everywhere.
            let decodedValue = strtod(buff.baseAddress!, &endPtr)
            if let endPtr {
                if buff.baseAddress!.advanced(by: buff.count) == endPtr {
                    return decodedValue
                }
//                else {
//                    print("Got value: \(decodedValue) but failing prevalidatedBuffer because of bad pointer. Expected \(buff.baseAddress!.advanced(by: buff.count)) vs \(endPtr)")
//                }
                return nil
            } else {
                return nil
            }
        }
        guard let decodedValue else { return nil }
        self = decodedValue
    }
}

extension Float : PrevalidatedJSONNumberBufferConvertible {
    @usableFromInline
    init?(prevalidatedBuffer buffer: RawSpan) {
        let decodedValue = buffer.withUnsafeBytes { buff -> Float? in
            var endPtr: UnsafeMutablePointer<CChar>? = nil
            let decodedValue = strtof(buff.baseAddress!, &endPtr)
            if let endPtr, buff.baseAddress!.advanced(by: buff.count) == endPtr {
                return decodedValue
            } else {
                return nil
            }
        }
        guard let decodedValue else { return nil }
        self = decodedValue
    }
}

extension NewJSONDecoder.Options.DateDecodingStrategy {
//    @_specialize(where D == JSONParserDecoder)
//    @_specialize(where D == JSONPrimitiveDecoder)
    func decodeDate<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Date {
        switch self.storage {
        case .deferredToDate:
            let timeInterval = try decoder.decode(TimeInterval.self)
            return .init(timeIntervalSinceReferenceDate: timeInterval)
        case .secondsSince1970:
            let timeInterval = try decoder.decode(TimeInterval.self)
            return .init(timeIntervalSince1970: timeInterval)
        case .millisecondsSince1970:
            let timeInterval = try decoder.decode(TimeInterval.self)
            return .init(timeIntervalSince1970: timeInterval / 1000.0)
        case .iso8601:
            return try decoder.decodeString(JSONParserDecoder.DateStringVistior.iso8601)
        case .formatted(let strategy):
            return try decoder.decodeString(JSONParserDecoder.DateStringVistior.formatted(strategy))
        }
    }
}

extension NewJSONDecoder.Options.DataDecodingStrategy {
//    @_specialize(where D == JSONParserDecoder)
//    @_specialize(where D == JSONPrimitiveDecoder)
    func decodeData<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Data {
        switch self {
        case .deferredToData:
            let array = try decoder.decode([UInt8].self)
            return Data(array)
        case .base64:
            return try decoder.decodeString(JSONParserDecoder.Base64Visitor())
        }
    }
}

extension NewJSONDecoder.Options.DateDecodingStrategy {
    func decode(from decoder: AdaptorDecoder<JSONPrimitive>) throws(CodingError.Decoding) -> Date {
        do {
            switch storage {
            case .deferredToDate:
                return try Date(from: decoder)
            case .secondsSince1970:
                let timeInterval = try decoder.decode(TimeInterval.self)
                return try JSONParserDecoder.DateNumberVisitor.secondsSince1970.visit(timeInterval)
            case .millisecondsSince1970:
                let timeIntervalMS = try decoder.decode(TimeInterval.self)
                return try JSONParserDecoder.DateNumberVisitor.msSince1970.visit(timeIntervalMS)
            case .iso8601:
                let string = try decoder.decode(String.self)
                return try JSONParserDecoder.DateStringVistior.iso8601.visitString(string)
            case .formatted(let strategy):
                let string = try decoder.decode(String.self)
                return try JSONParserDecoder.DateStringVistior.formatted(strategy).visitString(string)
            }
        } catch {
            fatalError("TODO: Better error handling/translation")
        }
    }
}

extension NewJSONEncoder.Options.DateEncodingStrategy {
    func jsonValue(for date: Date, context: AdaptorEncodableValueContext<JSONPrimitive>) throws(CodingError.Encoding) -> JSONPrimitive {
        do {
            switch self.storage {
            case .millisecondsSince1970:
                let value = 1000.0 * date.timeIntervalSince1970
                return try .init(value, context: context)
            case .secondsSince1970:
                return try .init(date.timeIntervalSince1970, context: context)
            case .iso8601:
                let string = date.formatted(.iso8601)
                return .string(string)
            case .formatted(let style):
                let string = date.formatted(style)
                return.string(string)
            case .deferredToDate:
                return try context.withEncoder {
                    try date.encode(to: $0)
                    return $0.encodedValue
                }
            }
        } catch {
            fatalError("TODO: better error handling/translation")
        }
    }
}
