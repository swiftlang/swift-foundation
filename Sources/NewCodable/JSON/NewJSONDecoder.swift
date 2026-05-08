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
        /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
        public enum NonConformingFloatDecodingStrategy : Sendable {
            /// Throw upon encountering non-conforming values. This is the default strategy.
            case `throw`
            
            /// Decode the values using the given representation strings.
            case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
        }
        
        var assumesTopLevelDictionary = false // TODO: Unimplemented
        internal var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy
        
        public init(assumesTopLevelDictionary: Bool = false,
                    nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw) {
            self.assumesTopLevelDictionary = assumesTopLevelDictionary
            self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        }
    }
    
    public init(options: Options = .init()) {
        self.options = options
    }
    
    // TODO: RawSpan-taking functions need to detect Unicode encoding (including BOM) and convert to UTF-8, if necessary.
    @usableFromInline
    internal func _decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from bytes: RawSpan, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(unvalidatedUTF8Span: bytes, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }
    
    @inlinable
    public func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from bytes: RawSpan) throws(CodingError.Decoding) -> T {
        try _decode(type, from: bytes) { inner throws(CodingError.Decoding) in
            try inner.decode(type)
        }
    }

    @usableFromInline
    internal func _decode<T: CommonDecodable>(_ type: T.Type, from bytes: RawSpan, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(unvalidatedUTF8Span: bytes, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }

    @_disfavoredOverload
    @inlinable
    public func decode<T: CommonDecodable>(_ type: T.Type, from bytes: RawSpan) throws(CodingError.Decoding) -> T {
        try _decode(type, from: bytes) { parserDecoder throws(CodingError.Decoding) in
            try parserDecoder.decode(type)
        }
    }
    
    @usableFromInline
    internal func _decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from utf8: UTF8Span, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(utf8: utf8, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }
    
    @inlinable
    public func decode<T: JSONDecodable & ~Copyable>(_ type: T.Type, from utf8: UTF8Span) throws(CodingError.Decoding) -> T {
        try _decode(type, from: utf8) { inner throws(CodingError.Decoding) in
            try inner.decode(type)
        }
    }

    @usableFromInline
    internal func _decode<T: CommonDecodable>(_ type: T.Type, from utf8: UTF8Span, closure: (inout JSONParserDecoder) throws(CodingError.Decoding) -> T) throws(CodingError.Decoding) -> T {
        var node = JSONParserDecoder.CodingPathNode.root
        return try withUnsafeMutablePointer(to: &node) { ptr throws(CodingError.Decoding) in
            let localOptions = self.options
            let parserState = JSONParserDecoder.ParserState(utf8: utf8, options: localOptions&, topCodingPathNode: ptr)
            var inner = JSONParserDecoder(state: parserState)
            let result = try closure(&inner)
            try inner._finishDecode()
            return result
        }
    }

    @_disfavoredOverload
    @inlinable
    public func decode<T: CommonDecodable>(_ type: T.Type, from utf8: UTF8Span) throws(CodingError.Decoding) -> T {
        try _decode(type, from: utf8) { parserDecoder throws(CodingError.Decoding) in
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
