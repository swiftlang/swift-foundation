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


@frozen
@usableFromInline
enum BlackHoleDecodable {
    case blackhole
}

extension BlackHoleDecodable: JSONDecodable {
    @usableFromInline
    static func decode<D>(from decoder: inout D) throws(CodingError.Decoding) -> BlackHoleDecodable where D : JSONDecoderProtocol, D : ~Escapable {
        try decoder.decodeAny(BlackHoleVisitor())
    }
}

@frozen
@usableFromInline
struct BlackHoleVisitor: JSONDecodingVisitor {
    @usableFromInline
    typealias DecodedValue = BlackHoleDecodable
        
    @usableFromInline
    func visit(decoder: inout some JSONDictionaryDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue {
        try decoder.decodeEachField { _ in
            // Do nothing.
        } andValue: { valueDecoder throws(CodingError.Decoding) in
            _ = try valueDecoder.decode(BlackHoleDecodable.self)
        }
        
        return .blackhole
    }
    
    @usableFromInline
    func visit(decoder: inout some JSONArrayDecoder & ~Escapable) throws(CodingError.Decoding) -> DecodedValue {
        try decoder.decodeEachElement { valueDecoder throws(CodingError.Decoding) in
            _ = try valueDecoder.decode(BlackHoleDecodable.self)
        }
        
        return .blackhole
    }
    
    @inlinable func visit<T: FixedWidthInteger>(_ integer: T) throws(CodingError.Decoding) -> BlackHoleDecodable { .blackhole }
    @inlinable func visit<T: BinaryFloatingPoint>(_ number: T) throws(CodingError.Decoding) -> BlackHoleDecodable { .blackhole }
    
    @usableFromInline
    var prefersArbitraryPrecisionNumbers: Bool { true }
    
    @usableFromInline
    func visitArbitraryPrecisionNumber(_ span: UTF8Span) throws(CodingError.Decoding) -> DecodedValue {
        .blackhole
    }
    
    @usableFromInline
    func visitArbitraryPrecisionNumber(_ string: String) throws(CodingError.Decoding) -> DecodedValue {
        .blackhole
    }
    
    @inlinable func visitUTF8Bytes(_ buffer: UTF8Span) throws(CodingError.Decoding) -> BlackHoleDecodable { .blackhole }
    @inlinable func visitString(_ string: String) throws(CodingError.Decoding) -> BlackHoleDecodable { .blackhole }
    
    @inlinable
    func visit(_ bool: Bool) throws(CodingError.Decoding) -> BlackHoleDecodable {
        .blackhole
    }
    
    @inlinable
    func visitNone() throws(CodingError.Decoding) -> BlackHoleDecodable {
        .blackhole
    }
}
