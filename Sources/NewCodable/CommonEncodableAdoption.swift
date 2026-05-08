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

// MARK: CommonEncodable primitive types

extension String: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeString(self)
    }
}

extension Int: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int8: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int16: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int32: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int64: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Int128: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt8: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt16: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt32: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt64: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension UInt128: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Float: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Double: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Bool: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(self)
    }
}

extension Dictionary: CommonEncodable where Key: CodingStringKeyRepresentable, Value: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeDictionary(self)
    }
}

extension Array: CommonEncodable where Element: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(self)
    }
}

extension Optional: CommonEncodable where Wrapped: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        switch self {
        case .none: try encoder.encodeNil()
        case .some(let wrapped): try wrapped.encode(to: &encoder)
        }
    }
}

// MARK: RawRepresentable extension

extension RawRepresentable where Self: CommonEncodable, RawValue: CommonEncodable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encode(rawValue)
    }
}

// MARK: stdlib adoptions

extension InlineArray: CommonEncodable where Element: CommonEncodable & ~Copyable {
    @inline(__always)
    @_alwaysEmitIntoClient
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: count) { arrayEncoder throws(CodingError.Encoding) in
            for i in indices {
                try arrayEncoder.encode(self[i])
            }
        }
    }
}

extension Range: CommonEncodable where Bound: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 2) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(lowerBound)
            try arrayEncoder.encode(upperBound)
        }
    }
}

extension PartialRangeUpTo: CommonEncodable where Bound: CommonEncodable {
    public func encode(to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        try encoder.encodeArray(elementCount: 1) { arrayEncoder throws(CodingError.Encoding) in
            try arrayEncoder.encode(upperBound)
        }
    }
}

// TODO: Etc.
