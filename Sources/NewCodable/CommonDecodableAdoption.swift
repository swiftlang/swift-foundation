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

// MARK: CommonDecodable primitive types

extension String: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int8: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int16: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int32: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int64: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Int128: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt8: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt16: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt32: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt64: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension UInt128: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Float: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Double: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Bool: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self)
    }
}

extension Optional: CommonDecodable where Wrapped: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        var result: Self = nil
        try decoder.decodeOptional { valueDecoder throws(CodingError.Decoding) in
            result = try valueDecoder.decode(Wrapped.self)
        }
        return result
    }
}

extension Array: CommonDecodable where Element: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self, sizeHint: 0)
    }
}

extension Dictionary: CommonDecodable where Key: CodingStringKeyRepresentable, Value: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Self {
        return try decoder.decode(Self.self, sizeHint: 0)
    }
}

// MARK: Foundation currency type adoptions

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

// MARK: RawRepresentable extension

extension RawRepresentable where Self: CommonDecodable, RawValue: CommonDecodable {
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func decode<D: CommonDecoder & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
        let rawValue = try decoder.decode(RawValue.self)
        guard let result = Self(rawValue: rawValue) else {
            throw CodingError.dataCorrupted(debugDescription: "Invalid raw value \(rawValue) for type \(Self.self)")
        }
        return result
    }
}

// MARK: stdlib adoptions

extension InlineArray: CommonDecodable where Element: CommonDecodable & ~Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> InlineArray<count, Element> {
        try .init(initializingWith: { outputSpan throws(CodingError.Decoding) in
            try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                var total = 0
                try arrayDecoder.decodeEachElement { elementDecoder throws(CodingError.Decoding) in
                    total &+= 1
                    // TODO: Error.
                    guard total <= Self.count else { throw CodingError.dataCorrupted() }
                    let element = try elementDecoder.decode(Element.self)
                    outputSpan.append(element)
                }
                // TODO: Error.
                guard total == Self.count else {
                    throw CodingError.dataCorrupted()
                }
            }
        })
    }
}

extension Range: CommonDecodable where Bound: CommonDecodable {
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Range {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            // TODO: Deal with nils
            let lowerBound = try arrayDecoder.decodeNext(Bound.self)!
            let upperBound = try arrayDecoder.decodeNext(Bound.self)!
            
            guard lowerBound <= upperBound else {
                throw CodingError.dataCorrupted(
                  debugDescription: "Cannot initialize \(Range.self) with a lowerBound (\(lowerBound)) greater than upperBound (\(upperBound))"
                )
            }
            return self.init(uncheckedBounds: (lower: lowerBound, upper: upperBound))
        }
    }
}

extension PartialRangeUpTo: CommonDecodable where Bound: CommonDecodable {
    public static func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> PartialRangeUpTo {
        try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
            // TODO: Deal with nils
            let upperBound = try arrayDecoder.decodeNext(Bound.self)!
            return .init(upperBound)
        }
    }
}
