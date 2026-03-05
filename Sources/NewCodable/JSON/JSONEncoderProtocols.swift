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

public protocol JSONEncodable: ~Copyable {
    func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding)
}

/// Types that can be encoded to JSON with a context.
public protocol JSONEncodableWithContext: ~Copyable {
    associatedtype JSONEncodingContext: ~Copyable & ~Escapable
    @_lifetime(encoder: copy encoder)
    func encode(to encoder: inout JSONDirectEncoder, context: inout JSONEncodingContext) throws(CodingError.Encoding)
}

// Convenience for Copyable contexts - allows static member syntax
extension JSONEncodableWithContext where Self: ~Copyable, JSONEncodingContext: Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    @_lifetime(encoder: copy encoder)
    public func encode(to encoder: inout JSONDirectEncoder, context: JSONEncodingContext) throws(CodingError.Encoding) {
        var mutableContext = context
        try self.encode(to: &encoder, context: &mutableContext)
    }
}

public protocol JSONOptimizedEncodingField: StaticStringEncodingField, ~Escapable {
    // TODO: Ideally we'd only allow this to be created for keys that don't require escapes, but it'd need to be constant-folded.
}

public protocol JSONOptimizedCodingField: JSONOptimizedDecodingField, JSONOptimizedEncodingField, ~Escapable { }

public extension JSONOptimizedCodingField where Self: ~Escapable {
    @_alwaysEmitIntoClient
    @inline(__always)
    func withUTF8Span<T: ~Copyable, E>(_ closure: (UTF8Span) throws(E) -> T) throws(E) -> T {
        try self.staticString.withUTF8SpanForCodable(closure)
    }
}


// Adoptions:

extension String: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeString(self)
    }
}

extension Int: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int8: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int16: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int32: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int64: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt8: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt16: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt32: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt64: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Float: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Double: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Bool: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Optional: JSONEncodable where Wrapped: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        switch self {
        case .none: try encoder.encodeNil()
        case .some(let wrapped): try wrapped.encode(to: &encoder)
        }
    }
}

extension Array: JSONEncodable where Element: JSONEncodable {
    @inlinable
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray { arrayEncoder throws(CodingError.Encoding) in
            for element in self {
                try arrayEncoder.encode(element)
            }
        }
    }
}

extension Dictionary: JSONEncodable where Key: CodingStringKeyRepresentable, Value: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Data: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Date: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

// MARK: Foundation currency type adoptions

// TODO: URL, UUID


// MARK: RawRepresentable extension

extension RawRepresentable where Self: JSONEncodable, RawValue: JSONEncodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encode(rawValue)
    }
}

// MARK: stdlib adoptions

extension InlineArray: JSONEncodable where Element: JSONEncodable & ~Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: count) { arrayEncoder throws(CodingError.Encoding) in
            for i in indices {
                try arrayEncoder.encode(self[i])
            }
        }
    }
}

extension Range: JSONEncodable where Bound: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(lowerBound)
            try arrayEncoder.encode(upperBound)
        }
    }
}

extension PartialRangeUpTo: JSONEncodable where Bound: JSONEncodable {
    public func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 1) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(upperBound)
        }
    }
}
