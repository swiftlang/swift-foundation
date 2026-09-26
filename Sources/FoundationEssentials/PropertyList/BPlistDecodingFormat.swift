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

#if FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))

// MARK: - Format

/// `PlistDecodingFormat` conformer plugging `BPlistDecodingDocument` into the generic `_PlistDecoder<Format>` machinery. `Document.Value` is a scope; unwrap methods open `document.withPrimitive(for:)` to reconstitute the `BPlistPrimitive` for the closure's duration.
@available(anyAppleOS 26.0, *)
struct BPlistDecodingFormat: PlistDecodingFormat {
    typealias Document = BPlistDecodingDocument

    /// Build a `.typeMismatch` `DecodingError` whose message reports the actual primitive type at `scope` (reconstituted via `document.withPrimitive`), matching the legacy `BPlistLegacyDecodingDocument.Value` output.
    @inline(__always)
    static func _typeMismatchError(document: BPlistDecodingDocument, scope: BPlistPrimitiveScope, path: [CodingKey], expectation: Any.Type) -> DecodingError {
        let reality = document.withPrimitive(for: scope) { $0.debugDataTypeDescription }
        return .typeMismatch(expectation, .init(codingPath: path, debugDescription: "Expected to decode \(expectation) but found \(reality) instead."))
    }

    static func container<Key>(keyedBy type: Key.Type, for value: BPlistPrimitiveScope, referencing decoder: _PlistDecoder<BPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        let container = try decoder.document.withPrimitive(for: value) { primitive in
            let primitiveIter = try primitive.dictionaryIterator
            let iter = BPlistDecodingDocument.DictionaryIterator(primitiveIter)
            return try _PlistKeyedDecodingContainer<Key, Self>(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: primitiveIter.count)
        }
        return KeyedDecodingContainer(container)
    }

    static func unkeyedContainer(for value: BPlistPrimitiveScope, referencing decoder: _PlistDecoder<BPlistDecodingFormat>, codingPathNode: _CodingPathNode) throws -> UnkeyedDecodingContainer {
        let range: Range<Int> = try decoder.document.withPrimitive(for: value) { primitive in
            return try primitive.arraySetRange
        }
        let count = range.count / decoder.document.metadata.objectRefSize
        let iter = BPlistDecodingDocument.ArrayIterator(document: decoder.document, containerScope: value, range: range, position: range.lowerBound)
        return _PlistUnkeyedDecodingContainer(referencing: decoder, codingPathNode: codingPathNode, iterator: iter, count: count)
    }

    static func valueIsNull(_ mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument) -> Bool {
        // Two flavors of null in a bplist: the native null marker (0x00, rare), and the ASCII string "$null" that keyed archivers (and therefore Codable's `encodeNil`) use.
        return map.withPrimitive(for: mapValue) { primitive in
            if primitive.isNull { return true }
            guard primitive.type == .asciiString else { return false }
            guard let span = try? primitive.asciiStringSpan else { return false }
            let plistNull: StaticString = "$null"
            guard span.count == plistNull.utf8CodeUnitCount else { return false }
            return span.starts(with: plistNull)
        }
    }

    static func unwrapBool(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Bool {
        do {
            return try map.withPrimitive(for: mapValue) { try $0.boolValue }
        } catch {
            throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: Bool.self)
        }
    }

    static func unwrapDate(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date {
        do {
            let secondsSinceRef = try map.withPrimitive(for: mapValue) { try $0.dateValue }
            return Date(timeIntervalSinceReferenceDate: secondsSinceRef)
        } catch {
            throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: Date.self)
        }
    }

    static func unwrapData(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data {
        do {
            return try map.withPrimitive(for: mapValue) { primitive -> Data in
                let span = try primitive.dataSpan
                return span.withUnsafeBufferPointer { buf in
                    guard let base = buf.baseAddress else { return Data() }
                    return Data(bytes: base, count: buf.count)
                }
            }
        } catch {
            throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: Data.self)
        }
    }

    static func unwrapString(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> String {
        do {
            return try map.withPrimitive(for: mapValue) { primitive -> String in
                guard primitive.isStringType else {
                    throw BPlistError.typeMismatch(expected: "string", actual: primitive.type ?? .null)
                }
                let enc = try primitive.encodedString
                return try enc.stringValue
            }
        } catch {
            throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: String.self)
        }
    }

    static func unwrapFloatingPoint<T: BinaryFloatingPoint>(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        return try map.withPrimitive(for: mapValue) { primitive -> T in
            switch primitive.type {
            case .real:
                let span = try primitive.realSpan
                switch span.byteCount {
                case MemoryLayout<Float>.size:
                    let f = Float(bitPattern: UInt32(bigEndian: span.unsafeLoadUnaligned(as: UInt32.self)))
                    guard !f.isNaN else { return T.nan }
                    guard let r = T(exactly: f) else {
                        throw DecodingError._dataCorrupted("Property list number <\(f)> does not fit in \(T.self).", for: codingPathNode, additionalKey)
                    }
                    return r
                case MemoryLayout<Double>.size:
                    let d = Double(bitPattern: UInt64(bigEndian: span.unsafeLoadUnaligned(as: UInt64.self)))
                    guard !d.isNaN else { return T.nan }
                    guard let r = T(exactly: d) else {
                        throw DecodingError._dataCorrupted("Property list number <\(d)> does not fit in \(T.self).", for: codingPathNode, additionalKey)
                    }
                    return r
                default:
                    throw DecodingError._dataCorrupted("Unsupported bplist real byte count: \(span.byteCount)", for: codingPathNode, additionalKey)
                }
            case .int:
                // Signed-vs-unsigned interpretation matches `unwrapFixedWidthInteger` below.
                let enc = try primitive.encodedInteger
                let rawBits = enc.span.bplistIntegerValue
                if enc.isUnsigned {
                    return T(rawBits)
                }
                return T(Int64(bitPattern: rawBits))
            default:
                throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: T.self)
            }
        }
    }

    static func unwrapFixedWidthInteger<T>(from mapValue: BPlistPrimitiveScope, in map: BPlistDecodingDocument, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T where T : FixedWidthInteger {
        return try map.withPrimitive(for: mapValue) { primitive -> T in
            switch primitive.type {
            case .int:
                // Bplist integer encoding: 1/2/4-byte forms hold the value directly; the 8-byte form is `Int64(bitPattern:)`-shaped (the encoder promotes any signed int not fitting in 32 bits to full 8 bytes). Only the 16-byte (128-bit) form encodes a genuinely unsigned value larger than Int64.max.
                let enc = try primitive.encodedInteger
                let rawBits = enc.span.bplistIntegerValue
                if enc.isUnsigned {
                    guard let v = T(exactly: rawBits) else {
                        throw DecodingError._dataCorrupted("Parsed property list number <\(rawBits)> does not fit in \(T.self).", for: codingPathNode, additionalKey)
                    }
                    return v
                }
                // ≤ 8-byte encoding: reinterpret via `Int64(bitPattern:)` so e.g. -1 (whose bit pattern equals UInt64.max) is correctly rejected when narrowing to UInt64.
                let signedBits = Int64(bitPattern: rawBits)
                guard let v = T(exactly: signedBits) else {
                    throw DecodingError._dataCorrupted("Parsed property list number <\(signedBits)> does not fit in \(T.self).", for: codingPathNode, additionalKey)
                }
                return v
            case .real:
                // Coerce real → integer via Double if exact.
                let span = try primitive.realSpan
                let d: Double
                switch span.byteCount {
                case MemoryLayout<Float>.size:
                    d = Double(Float(bitPattern: UInt32(bigEndian: span.unsafeLoadUnaligned(as: UInt32.self))))
                case MemoryLayout<Double>.size:
                    d = Double(bitPattern: UInt64(bigEndian: span.unsafeLoadUnaligned(as: UInt64.self)))
                default:
                    throw DecodingError._dataCorrupted("Unsupported bplist real byte count: \(span.byteCount)", for: codingPathNode, additionalKey)
                }
                guard let v = T(exactly: d) else {
                    throw DecodingError._dataCorrupted("Property list number <\(d)> does not fit in \(T.self).", for: codingPathNode, additionalKey)
                }
                return v
            default:
                throw _typeMismatchError(document: map, scope: mapValue, path: codingPathNode.path(byAppending: additionalKey), expectation: T.self)
            }
        }
    }
}

#endif  // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
