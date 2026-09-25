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

#if FOUNDATION_FRAMEWORK || !os(macOS)

// MARK: - JSONDecoderImpl

@available(anyAppleOS 26.0, *)
internal class JSONDecoderImpl {
    
    /// Shared decoding state for a JSON payload on the primitive-decoder path. One instance per `JSONDecoder.decode(_:)` call; all `JSONDecoderImpl` instances spawned during that call (root, super-decoders, and any sub-scoped decoders) hold the same document via ARC.
    @available(anyAppleOS 26.0, *)
    internal final class Document {
        let userInfo: [CodingUserInfoKey: Any]

        /// The source bytes. Points into the caller's buffer at init; once `copyInBuffer()` fires, points into `ownedAllocation` instead.
        var bytes: UnsafeRawBufferPointer

        /// Non-nil iff `bytes` points into a copy this class allocated (via `copyInBuffer()`). `deinit` deallocates it.
        private var ownedAllocation: UnsafeMutableRawBufferPointer?

        /// The parsed structural map (marker + offset buffer).
        var map: JSONMap<UniqueMapRecords>

        /// Options captured at decode start.
        let options: JSONDecoder._Options

        init(userInfo: [CodingUserInfoKey: Any], bytes: UnsafeRawBufferPointer, map: consuming JSONMap<UniqueMapRecords>, options: JSONDecoder._Options) {
            self.userInfo = userInfo
            self.bytes = bytes
            self.ownedAllocation = nil
            self.map = map
            self.options = options
        }

        deinit {
            if let owned = ownedAllocation {
                owned.deallocate()
            }
        }

        /// Reconstitute the `JSONPrimitive` for `scope` over a `RawSpan` opened from the document's byte pointer.
        @inline(__always)
        func withPrimitive<R>(for scope: JSONPrimitiveScope, _ body: (borrowing JSONPrimitive) throws -> R) throws -> R {
            let span = unsafe RawSpan(_unsafeStart: bytes.baseAddress!, byteCount: bytes.count)
            return try scope.withReconstituted(in: map, bytes: span, body)
        }

        /// Copy the source bytes into a fresh owned allocation, and switch `bytes` to point at that copy. Idempotent.
        func copyInBuffer() {
            guard ownedAllocation == nil else { return }
            let count = bytes.count
            // +1 for a trailing NUL byte so C-string-consuming parsers (strtod) can't overrun.
            let copy = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
            copy.copyMemory(from: bytes)
            self.ownedAllocation = copy
            self.bytes = UnsafeRawBufferPointer(start: copy.baseAddress, count: count)
        }
    }

    /// Shared decoding state (bytes, map, options, userInfo).
    var document: Document

    /// The active scope stack; `topValue` is the currently-decoding scope.
    var values: UniqueArray<JSONPrimitiveScope>

    var codingPathNode: _CodingPathNode
    public var codingPath: [CodingKey] {
        codingPathNode.path
    }

    var userInfo: [CodingUserInfoKey: Any] { document.userInfo }
    var options: JSONDecoder._Options { document.options }

    var topValue: JSONPrimitiveScope { self.values[self.values.count - 1] }

    func push(value: JSONPrimitiveScope) {
        self.values.append(value)
    }

    func popValue() {
        _ = self.values.popLast()
    }

    init(document: Document, scope: JSONPrimitiveScope = .top, codingPathNode: _CodingPathNode) {
        self.document = document
        self.codingPathNode = codingPathNode
        self.values = UniqueArray()
        self.values.append(scope)
    }

    /// Forwards to `document.withPrimitive`. Kept at the decoder level to save `.document` at every call site in the extensions.
    @inline(__always)
    func withPrimitive<R>(for scope: JSONPrimitiveScope, _ body: (borrowing JSONPrimitive) throws -> R) throws -> R {
        try document.withPrimitive(for: scope, body)
    }

    // This instance may have multiple references if an init(from: Decoder) implementation allows the Decoder (this object) to escape, or if a container escapes.
    // If the caller's buffer is about to fall out of scope, copy it in. Two conditions to check: `self` might be unique, but `document` might still be shared with a sub-decoder that escaped.
    func takeOwnershipOfBackingDataIfNeeded(selfIsUniquelyReferenced: Bool) {
        if !selfIsUniquelyReferenced || !isKnownUniquelyReferenced(&document) {
            document.copyInBuffer()
        }
    }
}

// MARK: - Type inspection helpers

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    /// Human-readable name for the JSON value at `scope`, for error messages.
    func debugDataTypeDescription(for scope: JSONPrimitiveScope) -> String {
        (try? withPrimitive(for: scope) { primitive -> String in
            switch primitive.type {
            case .string: return "a string"
            case .number: return "number"
            case .true, .false: return "bool"
            case .null: return "null"
            case .object: return "a dictionary"
            case .array: return "an array"
            case .none: return "invalid"
            }
        }) ?? "invalid"
    }

    /// True when the value at `scope` is JSON null. Used by `checkNotNull` and `decodeNil`.
    @inline(__always)
    func isNull(_ scope: JSONPrimitiveScope) -> Bool {
        return (try? withPrimitive(for: scope) { $0.isNull }) ?? false
    }
}

// MARK: - Error construction + not-null guard

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    @inline(__always)
    func checkNotNull<T>(_ scope: JSONPrimitiveScope, expectedType: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws {
        if isNull(scope) {
            throw DecodingError.valueNotFound(expectedType, DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Cannot get value of type \(expectedType) -- found null value instead"))
        }
    }

    func createTypeMismatchError(type: Any.Type, for path: [CodingKey], value scope: JSONPrimitiveScope) -> DecodingError {
        DecodingError.typeMismatch(type, .init(codingPath: path, debugDescription: "Expected to decode \(type) but found \(debugDataTypeDescription(for: scope)) instead."))
    }

    /// Push `scope` and update the coding path (if non-nil), invoke `closure`, then pop and restore. Used for `unwrap<T: Decodable>` where the callee is a user's `init(from: Decoder)` that will pull the value back through `self` as a `SingleValueDecodingContainer` or open a nested container.
    @inline(__always)
    func with<T>(value scope: JSONPrimitiveScope, path: _CodingPathNode?, perform closure: () throws -> T) rethrows -> T {
        let oldPath = self.codingPathNode
        if let path {
            self.codingPathNode = path
        }
        self.push(value: scope)
        defer {
            if path != nil {
                self.codingPathNode = oldPath
            }
            self.popValue()
        }
        return try closure()
    }
}

// MARK: - Leaf unwraps

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    func unwrapBool(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> Bool {
        try checkNotNull(scope, expectedType: Bool.self, for: codingPathNode, additionalKey)
        return try withPrimitive(for: scope) { primitive in
            do {
                return try primitive.boolValue
            } catch {
                throw createTypeMismatchError(type: Bool.self, for: codingPathNode.path(byAppending: additionalKey), value: scope)
            }
        }
    }

    func unwrapString(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> String {
        try checkNotNull(scope, expectedType: String.self, for: codingPathNode, additionalKey)
        return try withPrimitive(for: scope) { primitive in
            guard primitive.type == .string else {
                throw createTypeMismatchError(type: String.self, for: codingPathNode.path(byAppending: additionalKey), value: scope)
            }
            return try primitive.decodeStringValue(json5Mode: options.json5)
        }
    }

    func unwrapFloatingPoint<T: BinaryFloatingPoint & Sendable>(
        from scope: JSONPrimitiveScope,
        as type: T.Type,
        for codingPathNode: _CodingPathNode,
        _ additionalKey: (some CodingKey)? = nil
    ) throws -> T {
        try checkNotNull(scope, expectedType: type, for: codingPathNode, additionalKey)
        return try withPrimitive(for: scope) { primitive -> T in
            switch primitive.type {
            case .number:
                let decoded = try primitive.decodeNumberValue(json5Mode: options.json5)
                switch decoded.value {
                case .double(let d):
                    return T(d)
                case .positiveInfinity:
                    return T.infinity
                case .negativeInfinity:
                    return -T.infinity
                case .notANumber:
                    return T.nan
                case .int64(let i):
                    guard let v = T(exactly: i) else {
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(i)")
                    }
                    return v
                case .uint64(let u):
                    guard let v = T(exactly: u) else {
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(u)")
                    }
                    return v
                case .decimalString:
                    let numberBytes = try primitive.numberBytes.bytes
                    #if !NO_JSON_FOUNDATION_SPECIALIZATION
                    // Value has too many significant digits for a lossless Double parse. Detour through `Decimal` and take the nearest approximation.
                    let decimal: Decimal
                    switch Decimal._decimal(from: numberBytes, matchEntireString: true) {
                    case .success(let result, _): decimal = result
                    case .overlargeValue:
                        let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                        throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                    case .parseFailure:
                        throw DecodingError.dataCorrupted(.init(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Number could not be parsed as Decimal"))
                    }
                    return T((decimal as NSDecimalNumber).doubleValue)
                    #else
                    // Without the `Decimal` detour there is no way to narrow the value further.
                    let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                    #endif
                }
            case .string:
                if case .convertFromString(let posInfString, let negInfString, let nanString) = options.nonConformingFloatDecodingStrategy {
                    let sb = try primitive.stringBytes
                    // Only accept the simple case: bytes are literal (no escapes) and match one of the sentinel strings byte-for-byte.
                    if !sb.hasEscapes {
                        let result: T? = sb.bytes.withUnsafeBufferPointer { buf -> T? in
                            var posInfString = posInfString
                            var negInfString = negInfString
                            var nanString = nanString
                            let ptr = buf.baseAddress!
                            let count = buf.count
                            func bytesAreEqual(_ b: UnsafeBufferPointer<UInt8>) -> Bool {
                                count == b.count && Platform.memcmp(ptr, b.baseAddress!, b.count) == 0
                            }
                            if posInfString.withUTF8(bytesAreEqual(_:)) { return T.infinity }
                            if negInfString.withUTF8(bytesAreEqual(_:)) { return -T.infinity }
                            if nanString.withUTF8(bytesAreEqual(_:)) { return T.nan }
                            return nil
                        }
                        if let result { return result }
                    }
                }
                throw createTypeMismatchError(type: type, for: codingPathNode.path(byAppending: additionalKey), value: scope)
            default:
                throw createTypeMismatchError(type: type, for: codingPathNode.path(byAppending: additionalKey), value: scope)
            }
        }
    }

    func unwrapFixedWidthInteger<T: FixedWidthInteger & Sendable>(
        from scope: JSONPrimitiveScope,
        as type: T.Type,
        for codingPathNode: _CodingPathNode,
        _ additionalKey: (some CodingKey)? = nil
    ) throws -> T {
        try checkNotNull(scope, expectedType: type, for: codingPathNode, additionalKey)
        return try withPrimitive(for: scope) { primitive -> T in
            guard primitive.type == .number else {
                throw createTypeMismatchError(type: type, for: codingPathNode.path(byAppending: additionalKey), value: scope)
            }
            let decoded = try primitive.decodeNumberValue(json5Mode: options.json5)
            switch decoded.value {
            case .int64(let i):
                guard let v = T(exactly: i) else {
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(i)")
                }
                return v
            case .uint64(let u):
                guard let v = T(exactly: u) else {
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(u)")
                }
                return v
            case .double(let d):
                // Try lossless double-to-integer coercion (rejects fractional values). `.double` is always finite here — Infinity / NaN arrive as their own cases below.
                guard let v = T(exactly: d) else {
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(d)")
                }
                return v
            case .positiveInfinity:
                throw JSONError.numberIsNotRepresentableInSwift(parsed: "Infinity")
            case .negativeInfinity:
                throw JSONError.numberIsNotRepresentableInSwift(parsed: "-Infinity")
            case .notANumber:
                throw JSONError.numberIsNotRepresentableInSwift(parsed: "NaN")
            case .decimalString:
                // Wide integers (Int128/UInt128 range beyond Int64/UInt64) and overlong integer literals arrive here.
                let numberBytes = try primitive.numberBytes.bytes
                // `Decimal` holds only 38 significant digits, so it can't round-trip the full Int128/UInt128 range. Accumulate the digits directly into `T` first; `decodeNumberBytes` has already rejected anything that isn't a plain integer literal.
                let isNegative = numberBytes.count > 0 && numberBytes[0] == ._minus
                let digitStart = (isNegative || (numberBytes.count > 0 && numberBytes[0] == ._plus)) ? 1 : 0
                if case .value(let v) = T.scanDecimalDigits(of: numberBytes, from: digitStart, isNegative: isNegative) {
                    return v
                }
                #if !NO_JSON_FOUNDATION_SPECIALIZATION
                let decimal: Decimal
                switch Decimal._decimal(from: numberBytes, matchEntireString: true) {
                case .success(let result, _): decimal = result
                case .overlargeValue:
                    let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                case .parseFailure:
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Number could not be parsed as Decimal"))
                }
                guard let v = T(exactly: decimal) else {
                    let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                }
                return v
                #else
                // Without the `Decimal` detour there is no way to narrow the value further.
                let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                #endif
            }
        }
    }

    #if !NO_JSON_FOUNDATION_SPECIALIZATION
    func unwrapDate(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> Date {
        try checkNotNull(scope, expectedType: Date.self, for: codingPathNode, additionalKey)

        switch options.dateDecodingStrategy {
        case .deferredToDate:
            return try with(value: scope, path: codingPathNode.appending(additionalKey)) {
                try Date(from: self)
            }
        case .secondsSince1970:
            let double: Double = try unwrapFloatingPoint(from: scope, as: Double.self, for: codingPathNode, additionalKey)
            return Date(timeIntervalSince1970: double)
        case .millisecondsSince1970:
            let double: Double = try unwrapFloatingPoint(from: scope, as: Double.self, for: codingPathNode, additionalKey)
            return Date(timeIntervalSince1970: double / 1000.0)
        case .iso8601:
            let string = try unwrapString(from: scope, for: codingPathNode, additionalKey)
            guard let date = try? Date.ISO8601FormatStyle().parse(string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.codingPath, debugDescription: "Expected date string to be ISO8601-formatted."))
            }
            return date
#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
        case .formatted(let formatter):
            let string = try unwrapString(from: scope, for: codingPathNode, additionalKey)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Date string does not match format expected by formatter."))
            }
            return date
#endif
        case .custom(let closure):
            return try with(value: scope, path: codingPathNode.appending(additionalKey)) {
                try closure(self)
            }
        }
    }
    #endif

    func unwrapData(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> Data {
        try checkNotNull(scope, expectedType: Data.self, for: codingPathNode, additionalKey)

        switch options.dataDecodingStrategy {
        case .deferredToData:
            return try with(value: scope, path: codingPathNode.appending(additionalKey)) {
                try Data(from: self)
            }
        case .base64:
            let string = try unwrapString(from: scope, for: codingPathNode, additionalKey)
            guard let data = Data(base64Encoded: string) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Encountered Data is not valid Base64."))
            }
            return data
        case .custom(let closure):
            return try with(value: scope, path: codingPathNode.appending(additionalKey)) {
                try closure(self)
            }
        }
    }

    #if !NO_JSON_FOUNDATION_SPECIALIZATION
    func unwrapURL(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> URL {
        try checkNotNull(scope, expectedType: URL.self, for: codingPathNode, additionalKey)
        let string = try unwrapString(from: scope, for: codingPathNode, additionalKey)
        guard let url = URL(string: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Invalid URL string."))
        }
        return url
    }

    func unwrapDecimal(from scope: JSONPrimitiveScope, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> Decimal {
        try checkNotNull(scope, expectedType: Decimal.self, for: codingPathNode, additionalKey)
        return try withPrimitive(for: scope) { primitive -> Decimal in
            guard primitive.type == .number else {
                throw DecodingError.typeMismatch(Decimal.self, DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: ""))
            }
            let decoded = try primitive.decodeNumberValue(json5Mode: options.json5)
            switch decoded.value {
            case .int64(let i):
                guard let d = Decimal(exactly: i) else {
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(i)")
                }
                return d
            case .uint64(let u):
                guard let d = Decimal(exactly: u) else {
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: "\(u)")
                }
                return d
            case .positiveInfinity, .negativeInfinity, .notANumber:
                // Decimal doesn't represent Infinity/NaN; match the legacy behavior of returning `Decimal.quietNaN`.
                return Decimal.quietNaN
            case .double, .decimalString:
                // Parse from the source bytes rather than converting the `Double`.
                let numberBytes = try primitive.numberBytes.bytes
                switch Decimal._decimal(from: numberBytes, matchEntireString: true) {
                case .success(let result, _): return result
                case .overlargeValue:
                    let src = numberBytes.withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
                    throw JSONError.numberIsNotRepresentableInSwift(parsed: src)
                case .parseFailure:
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Number could not be parsed as Decimal"))
                }
            }
        }
    }
    #endif

    func unwrap<T: Decodable>(_ scope: JSONPrimitiveScope, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> T {
        if type == Data.self {
            return try unwrapData(from: scope, for: codingPathNode, additionalKey) as! T
        }
        #if !NO_JSON_FOUNDATION_SPECIALIZATION
        if type == Date.self {
            return try unwrapDate(from: scope, for: codingPathNode, additionalKey) as! T
        }
        if type == URL.self {
            return try unwrapURL(from: scope, for: codingPathNode, additionalKey) as! T
        }
        if type == Decimal.self {
            return try unwrapDecimal(from: scope, for: codingPathNode, additionalKey) as! T
        }
        #endif
        if !options.keyDecodingStrategy.isDefault, T.self is _JSONStringDictionaryDecodableMarker.Type {
            return try unwrapDictionary(from: scope, as: type, for: codingPathNode, additionalKey)
        }
        return try with(value: scope, path: codingPathNode.appending(additionalKey)) {
            try type.init(from: self)
        }
    }

    func unwrap<T: DecodableWithConfiguration>(_ scope: JSONPrimitiveScope, as type: T.Type, configuration: T.DecodingConfiguration, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> T {
        try with(value: scope, path: codingPathNode.appending(additionalKey)) {
            try type.init(from: self, configuration: configuration)
        }
    }

}

// MARK: - Decoder conformance

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl: Decoder {

    func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try checkNotNull(topValue, expectedType: [String: Any].self, for: codingPathNode, _CodingKey?.none)
        return try withPrimitive(for: topValue) { primitive in
            guard primitive.type == .object else {
                throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPath, debugDescription: "Expected to decode \([String: Any].self) but found \(debugDataTypeDescription(for: topValue)) instead."))
            }
            let container = try KeyedContainer_Primitive<Key>(impl: self, codingPathNode: codingPathNode, object: primitive)
            return KeyedDecodingContainer(container)
        }
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try checkNotNull(topValue, expectedType: [Any].self, for: codingPathNode, _CodingKey?.none)
        let (firstChildOffset, totalCount) = try withPrimitive(for: topValue) { primitive -> (Int, Int) in
            guard primitive.type == .array else {
                throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "Expected to decode \([Any].self) but found \(debugDataTypeDescription(for: topValue)) instead."))
            }
            let iterator = try! primitive.arrayIterator
            return (iterator.currentOffset, iterator.count)
        }
        return UnkeyedContainer_Primitive(impl: self, codingPathNode: codingPathNode, firstChildOffset: firstChildOffset, totalCount: totalCount)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }
}

// MARK: - SingleValueDecodingContainer

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl: SingleValueDecodingContainer {

    func decodeNil() -> Bool {
        isNull(topValue)
    }

    func decode(_: Bool.Type) throws -> Bool {
        try unwrapBool(from: topValue, for: codingPathNode, _CodingKey?.none)
    }

    func decode(_: String.Type) throws -> String {
        try unwrapString(from: topValue, for: codingPathNode, _CodingKey?.none)
    }

    func decode(_: Double.Type) throws -> Double { try decodeFloatingPoint() }
    func decode(_: Float.Type) throws -> Float { try decodeFloatingPoint() }

    func decode(_: Int.Type) throws -> Int { try decodeFixedWidthInteger() }
    func decode(_: Int8.Type) throws -> Int8 { try decodeFixedWidthInteger() }
    func decode(_: Int16.Type) throws -> Int16 { try decodeFixedWidthInteger() }
    func decode(_: Int32.Type) throws -> Int32 { try decodeFixedWidthInteger() }
    func decode(_: Int64.Type) throws -> Int64 { try decodeFixedWidthInteger() }
    func decode(_: Int128.Type) throws -> Int128 { try decodeFixedWidthInteger() }
    func decode(_: UInt.Type) throws -> UInt { try decodeFixedWidthInteger() }
    func decode(_: UInt8.Type) throws -> UInt8 { try decodeFixedWidthInteger() }
    func decode(_: UInt16.Type) throws -> UInt16 { try decodeFixedWidthInteger() }
    func decode(_: UInt32.Type) throws -> UInt32 { try decodeFixedWidthInteger() }
    func decode(_: UInt64.Type) throws -> UInt64 { try decodeFixedWidthInteger() }
    func decode(_: UInt128.Type) throws -> UInt128 { try decodeFixedWidthInteger() }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try unwrap(topValue, as: type, for: codingPathNode, _CodingKey?.none)
    }

    @inline(__always)
    private func decodeFixedWidthInteger<T: FixedWidthInteger & Sendable>() throws -> T {
        try unwrapFixedWidthInteger(from: topValue, as: T.self, for: codingPathNode, _CodingKey?.none)
    }

    @inline(__always)
    private func decodeFloatingPoint<T: BinaryFloatingPoint & Sendable>() throws -> T {
        try unwrapFloatingPoint(from: topValue, as: T.self, for: codingPathNode, _CodingKey?.none)
    }
}

// MARK: - Dictionary specialization (for KeyDecodingStrategy carve-out)

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    /// Called only when the top-level `T` is a `[String: Decodable]` and a non-default `KeyDecodingStrategy` is set. The keys inserted into the returned dictionary are the raw JSON strings; the key-conversion strategy is intentionally skipped for `[String: T]` payloads, matching documented behavior.
    fileprivate func unwrapDictionary<T: Decodable>(from scope: JSONPrimitiveScope, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = nil) throws -> T {
        try checkNotNull(scope, expectedType: [String: Any].self, for: codingPathNode, additionalKey)
        guard let dictType = type as? (_JSONStringDictionaryDecodableMarker & Decodable).Type else {
            preconditionFailure("Must only be called if T implements _JSONStringDictionaryDecodableMarker")
        }

        // Materialize (key, valueScope) pairs first so the value-unwrap loop below is not nested inside `withPrimitive`; some value unwraps recurse into `container(keyedBy:)` / `unkeyedContainer()`, which themselves reopen the byte pointer.
        let pairs: [(String, JSONPrimitiveScope)] = try withPrimitive(for: scope) { primitive in
            guard primitive.type == .object else {
                throw DecodingError.typeMismatch([String: Any].self, .init(codingPath: codingPathNode.path(byAppending: additionalKey), debugDescription: "Expected to decode \([String: Any].self) but found \(debugDataTypeDescription(for: scope)) instead."
                ))
            }
            var pairs: [(String, JSONPrimitiveScope)] = []
            var iter = try primitive.dictionaryIterator
            pairs.reserveCapacity(iter.count)
            while let pair = iter.next() {
                let keyPrimitive = iter.key(of: pair)
                guard keyPrimitive.type == .string else {
                    throw createTypeMismatchError(type: String.self, for: codingPathNode.path(byAppending: additionalKey), value: JSONPrimitiveScope(keyPrimitive))
                }
                let key = try keyPrimitive.decodeStringValue(json5Mode: options.json5)
                pairs.append((key, JSONPrimitiveScope(mapOffset: pair.valueOffset)))
            }
            return pairs
        }

        let dictCodingPathNode = codingPathNode.appending(additionalKey)
        var result = [String: Any]()
        result.reserveCapacity(pairs.count)
        for (key, valueScope) in pairs {
            let value = try unwrap(valueScope, as: dictType.elementType, for: dictCodingPathNode, _CodingKey(stringValue: key)!)
            result[key]._setIfNil(to: value)
        }
        return result as! T
    }
}

// MARK: - KeyedContainer_Primitive

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    struct KeyedContainer_Primitive<K: CodingKey>: KeyedDecodingContainerProtocol {
        typealias Key = K

        let impl: JSONDecoderImpl
        let codingPathNode: _CodingPathNode
        let dictionary: [String: JSONPrimitiveScope]

        /// Walk an `.object` primitive and fold its keys through the active `KeyDecodingStrategy`, producing a `[String: JSONPrimitiveScope]` map. Duplicate keys after conversion keep the first-seen value (via `_setIfNilPrim`).
        static func stringify(object primitive: borrowing JSONPrimitive, using impl: JSONDecoderImpl, codingPathNode: _CodingPathNode, keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy) throws -> [String: JSONPrimitiveScope] {
            var result = [String: JSONPrimitiveScope]()
            var iter = try primitive.dictionaryIterator
            result.reserveCapacity(iter.count)

            switch keyDecodingStrategy {
            case .useDefaultKeys:
                while let pair = iter.next() {
                    let keyPrimitive = iter.key(of: pair)
                    guard keyPrimitive.type == .string else {
                        throw impl.createTypeMismatchError(type: String.self, for: codingPathNode.path, value: JSONPrimitiveScope(keyPrimitive))
                    }
                    let key = try keyPrimitive.decodeStringValue(json5Mode: impl.options.json5)
                    result[key]._setIfNil(to: JSONPrimitiveScope(mapOffset: pair.valueOffset))
                }
            #if !NO_JSON_FOUNDATION_SPECIALIZATION
            case .convertFromSnakeCase:
                while let pair = iter.next() {
                    let keyPrimitive = iter.key(of: pair)
                    guard keyPrimitive.type == .string else {
                        throw impl.createTypeMismatchError(type: String.self, for: codingPathNode.path, value: JSONPrimitiveScope(keyPrimitive))
                    }
                    let key = try keyPrimitive.decodeStringValue(json5Mode: impl.options.json5)
                    result[JSONDecoder.KeyDecodingStrategy._convertFromSnakeCase(key)]._setIfNil(to: JSONPrimitiveScope(mapOffset: pair.valueOffset))
                }
            #endif
            case .custom(let converter):
                let codingPathForCustomConverter = codingPathNode.path
                while let pair = iter.next() {
                    let keyPrimitive = iter.key(of: pair)
                    guard keyPrimitive.type == .string else {
                        throw impl.createTypeMismatchError(type: String.self, for: codingPathNode.path, value: JSONPrimitiveScope(keyPrimitive))
                    }
                    let key = try keyPrimitive.decodeStringValue(json5Mode: impl.options.json5)
                    var pathForKey = codingPathForCustomConverter
                    pathForKey.append(_CodingKey(stringValue: key)!)
                    result[converter(pathForKey).stringValue]._setIfNil(to: JSONPrimitiveScope(mapOffset: pair.valueOffset))
                }
            }
            return result
        }

        init(impl: JSONDecoderImpl, codingPathNode: _CodingPathNode, object primitive: borrowing JSONPrimitive) throws {
            self.impl = impl
            self.codingPathNode = codingPathNode
            self.dictionary = try Self.stringify(object: primitive, using: impl, codingPathNode: codingPathNode, keyDecodingStrategy: impl.options.keyDecodingStrategy)
        }

        public var codingPath: [CodingKey] { codingPathNode.path }

        var allKeys: [K] {
            dictionary.keys.compactMap { K(stringValue: $0) }
        }

        func contains(_ key: K) -> Bool {
            dictionary.keys.contains(key.stringValue)
        }

        func decodeNil(forKey key: K) throws -> Bool {
            impl.isNull(try getValue(forKey: key))
        }

        func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
            try impl.unwrapBool(from: try getValue(forKey: key), for: codingPathNode, key)
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
            guard let value = getValueIfPresent(forKey: key), !impl.isNull(value) else { return nil }
            return try impl.unwrapBool(from: value, for: codingPathNode, key)
        }

        func decode(_ type: String.Type, forKey key: K) throws -> String {
            try impl.unwrapString(from: try getValue(forKey: key), for: codingPathNode, key)
        }

        func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
            guard let value = getValueIfPresent(forKey: key), !impl.isNull(value) else { return nil }
            return try impl.unwrapString(from: value, for: codingPathNode, key)
        }

        func decode(_: Double.Type, forKey key: K) throws -> Double { try decodeFloatingPoint(key: key) }
        func decodeIfPresent(_: Double.Type, forKey key: K) throws -> Double? { try decodeFloatingPointIfPresent(key: key) }
        func decode(_: Float.Type, forKey key: K) throws -> Float { try decodeFloatingPoint(key: key) }
        func decodeIfPresent(_: Float.Type, forKey key: K) throws -> Float? { try decodeFloatingPointIfPresent(key: key) }

        func decode(_: Int.Type, forKey key: K) throws -> Int { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int.Type, forKey key: K) throws -> Int? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: Int8.Type, forKey key: K) throws -> Int8 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int8.Type, forKey key: K) throws -> Int8? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: Int16.Type, forKey key: K) throws -> Int16 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int16.Type, forKey key: K) throws -> Int16? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: Int32.Type, forKey key: K) throws -> Int32 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int32.Type, forKey key: K) throws -> Int32? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: Int64.Type, forKey key: K) throws -> Int64 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int64.Type, forKey key: K) throws -> Int64? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: Int128.Type, forKey key: K) throws -> Int128 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: Int128.Type, forKey key: K) throws -> Int128? { try decodeFixedWidthIntegerIfPresent(key: key) }

        func decode(_: UInt.Type, forKey key: K) throws -> UInt { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt.Type, forKey key: K) throws -> UInt? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: UInt8.Type, forKey key: K) throws -> UInt8 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt8.Type, forKey key: K) throws -> UInt8? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: UInt16.Type, forKey key: K) throws -> UInt16 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt16.Type, forKey key: K) throws -> UInt16? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: UInt32.Type, forKey key: K) throws -> UInt32 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt32.Type, forKey key: K) throws -> UInt32? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: UInt64.Type, forKey key: K) throws -> UInt64 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt64.Type, forKey key: K) throws -> UInt64? { try decodeFixedWidthIntegerIfPresent(key: key) }
        func decode(_: UInt128.Type, forKey key: K) throws -> UInt128 { try decodeFixedWidthInteger(key: key) }
        func decodeIfPresent(_: UInt128.Type, forKey key: K) throws -> UInt128? { try decodeFixedWidthIntegerIfPresent(key: key) }

        func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
            try impl.unwrap(try getValue(forKey: key), as: type, for: codingPathNode, key)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
            guard let value = getValueIfPresent(forKey: key), !impl.isNull(value) else { return nil }
            return try impl.unwrap(value, as: type, for: codingPathNode, key)
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try getValue(forKey: key)
            return try impl.with(value: value, path: codingPathNode.appending(key)) {
                try impl.container(keyedBy: type)
            }
        }

        func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
            let value = try getValue(forKey: key)
            return try impl.with(value: value, path: codingPathNode.appending(key)) {
                try impl.unkeyedContainer()
            }
        }

        func superDecoder() throws -> Decoder {
            decoderForKeyNoThrow(_CodingKey.super)
        }

        func superDecoder(forKey key: K) throws -> Decoder {
            decoderForKeyNoThrow(key)
        }

        private func decoderForKeyNoThrow(_ key: some CodingKey) -> Decoder {
            let childPathNode = codingPathNode.appending(key)
            guard let scope = try? getValue(forKey: key) else {
                return _MissingKeyDecoder(codingPath: childPathNode.path, userInfo: impl.userInfo, boolReportsTypeMismatch: true)
            }
            return JSONDecoderImpl(document: impl.document, scope: scope, codingPathNode: childPathNode)
        }

        @inline(__always)
        private func getValue(forKey key: some CodingKey) throws -> JSONPrimitiveScope {
            guard let value = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
            }
            return value
        }

        @inline(__always)
        private func getValueIfPresent(forKey key: some CodingKey) -> JSONPrimitiveScope? {
            dictionary[key.stringValue]
        }

        @inline(__always)
        private func decodeFixedWidthInteger<T: FixedWidthInteger & Sendable>(key: Self.Key) throws -> T {
            try impl.unwrapFixedWidthInteger(from: try getValue(forKey: key), as: T.self, for: codingPathNode, key)
        }

        @inline(__always)
        private func decodeFloatingPoint<T: BinaryFloatingPoint & Sendable>(key: K) throws -> T {
            try impl.unwrapFloatingPoint(from: try getValue(forKey: key), as: T.self, for: codingPathNode, key)
        }

        @inline(__always)
        private func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger & Sendable>(key: Self.Key) throws -> T? {
            guard let value = getValueIfPresent(forKey: key), !impl.isNull(value) else { return nil }
            return try impl.unwrapFixedWidthInteger(from: value, as: T.self, for: codingPathNode, key)
        }

        @inline(__always)
        private func decodeFloatingPointIfPresent<T: BinaryFloatingPoint & Sendable>(key: K) throws -> T? {
            guard let value = getValueIfPresent(forKey: key), !impl.isNull(value) else { return nil }
            return try impl.unwrapFloatingPoint(from: value, as: T.self, for: codingPathNode, key)
        }
    }
}

// MARK: - Optional helper

extension Optional {
    fileprivate mutating func _setIfNil(to value: Wrapped) {
        guard _fastPath(self == nil) else { return }
        self = value
    }
}

// MARK: - UnkeyedContainer_Primitive

@available(anyAppleOS 26.0, *)
extension JSONDecoderImpl {

    struct UnkeyedContainer_Primitive: UnkeyedDecodingContainer {
        let impl: JSONDecoderImpl
        let codingPathNode: _CodingPathNode

        /// Map offset of the first child scope. Fixed once the container is created.
        let firstChildOffset: Int

        /// Total number of children in the source array.
        let totalCount: Int

        /// Cursor: map offset of the *next* child to be decoded.
        private var nextChildOffset: Int

        var count: Int? { totalCount }
        var currentIndex: Int = 0
        var isAtEnd: Bool { currentIndex >= totalCount }

        var codingPath: [CodingKey] { codingPathNode.path }

        init(impl: JSONDecoderImpl, codingPathNode: _CodingPathNode, firstChildOffset: Int, totalCount: Int) {
            self.impl = impl
            self.codingPathNode = codingPathNode
            self.firstChildOffset = firstChildOffset
            self.totalCount = totalCount
            self.nextChildOffset = firstChildOffset
        }

        @inline(__always)
        var currentIndexKey: _CodingKey { .init(index: currentIndex) }

        @inline(__always)
        var currentCodingPath: [CodingKey] {
            codingPathNode.path(byAppendingIndex: currentIndex)
        }

        @inline(__always)
        private mutating func advanceToNextValue() {
            guard currentIndex < totalCount else {
                return
            }
            nextChildOffset = impl.document.map.offset(after: nextChildOffset)
            currentIndex &+= 1
        }

        // MARK: peek helpers

        @inline(__always)
        private func peekNextValueIfPresent() -> JSONPrimitiveScope? {
            guard currentIndex < totalCount else { return nil }
            return JSONPrimitiveScope(mapOffset: nextChildOffset)
        }

        @inline(__always)
        private func peekNextValue<T>(ofType type: T.Type) throws -> JSONPrimitiveScope {
            guard let next = peekNextValueIfPresent() else {
                var message = "Unkeyed container is at end."
                if T.self == UnkeyedDecodingContainer.self {
                    message = "Cannot get nested unkeyed container -- unkeyed container is at end."
                }
                if T.self == Decoder.self {
                    message = "Cannot get superDecoder() -- unkeyed container is at end."
                }
                throw DecodingError.valueNotFound(type, .init(codingPath: currentCodingPath, debugDescription: message, underlyingError: nil))
            }
            return next
        }

        // MARK: decodeNil

        mutating func decodeNil() throws -> Bool {
            let value = try peekNextValue(ofType: Never.self)
            if impl.isNull(value) {
                advanceToNextValue()
                return true
            }
            // Per protocol: do not advance if the value is not null.
            return false
        }

        // MARK: Bool / String

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let value = try peekNextValue(ofType: type)
            let result = try impl.unwrapBool(from: value, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
            let value = peekNextValueIfPresent()
            let result: Bool?
            switch value {
            case .none: result = nil
            case .some(let v) where impl.isNull(v): result = nil
            case .some(let v): result = try impl.unwrapBool(from: v, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        mutating func decode(_ type: String.Type) throws -> String {
            let value = try peekNextValue(ofType: type)
            let result = try impl.unwrapString(from: value, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
            let value = peekNextValueIfPresent()
            let result: String?
            switch value {
            case .none: result = nil
            case .some(let v) where impl.isNull(v): result = nil
            case .some(let v): result = try impl.unwrapString(from: v, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        // MARK: Numbers

        mutating func decode(_: Double.Type) throws -> Double { try decodeFloatingPoint() }
        mutating func decodeIfPresent(_: Double.Type) throws -> Double? { try decodeFloatingPointIfPresent() }
        mutating func decode(_: Float.Type) throws -> Float { try decodeFloatingPoint() }
        mutating func decodeIfPresent(_: Float.Type) throws -> Float? { try decodeFloatingPointIfPresent() }

        mutating func decode(_: Int.Type) throws -> Int { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int.Type) throws -> Int? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: Int8.Type) throws -> Int8 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int8.Type) throws -> Int8? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: Int16.Type) throws -> Int16 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int16.Type) throws -> Int16? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: Int32.Type) throws -> Int32 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int32.Type) throws -> Int32? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: Int64.Type) throws -> Int64 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int64.Type) throws -> Int64? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: Int128.Type) throws -> Int128 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: Int128.Type) throws -> Int128? { try decodeFixedWidthIntegerIfPresent() }

        mutating func decode(_: UInt.Type) throws -> UInt { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt.Type) throws -> UInt? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: UInt8.Type) throws -> UInt8 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt8.Type) throws -> UInt8? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: UInt16.Type) throws -> UInt16 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt16.Type) throws -> UInt16? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: UInt32.Type) throws -> UInt32 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt32.Type) throws -> UInt32? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: UInt64.Type) throws -> UInt64 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt64.Type) throws -> UInt64? { try decodeFixedWidthIntegerIfPresent() }
        mutating func decode(_: UInt128.Type) throws -> UInt128 { try decodeFixedWidthInteger() }
        mutating func decodeIfPresent(_: UInt128.Type) throws -> UInt128? { try decodeFixedWidthIntegerIfPresent() }

        // MARK: Generic

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            let value = try peekNextValue(ofType: type)
            let result = try impl.unwrap(value, as: type, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        mutating func decodeIfPresent<T: Decodable>(_ type: T.Type) throws -> T? {
            let value = peekNextValueIfPresent()
            let result: T?
            switch value {
            case .none: result = nil
            case .some(let v) where impl.isNull(v): result = nil
            case .some(let v): result = try impl.unwrap(v, as: type, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        // MARK: Nested containers + superDecoder

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            let value = try peekNextValue(ofType: KeyedDecodingContainer<NestedKey>.self)
            let container = try impl.with(value: value, path: codingPathNode.appending(index: currentIndex)) {
                try impl.container(keyedBy: type)
            }
            advanceToNextValue()
            return container
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let value = try peekNextValue(ofType: UnkeyedDecodingContainer.self)
            let container = try impl.with(value: value, path: codingPathNode.appending(index: currentIndex)) {
                try impl.unkeyedContainer()
            }
            advanceToNextValue()
            return container
        }

        mutating func superDecoder() throws -> Decoder {
            let value = try peekNextValue(ofType: Decoder.self)
            let child = JSONDecoderImpl(document: impl.document, scope: value, codingPathNode: codingPathNode.appending(index: currentIndex))
            advanceToNextValue()
            return child
        }

        // MARK: Private number helpers

        @inline(__always)
        private mutating func decodeFixedWidthInteger<T: FixedWidthInteger & Sendable>() throws -> T {
            let value = try peekNextValue(ofType: T.self)
            let result = try impl.unwrapFixedWidthInteger(from: value, as: T.self, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        @inline(__always)
        private mutating func decodeFloatingPoint<T: BinaryFloatingPoint & Sendable>() throws -> T {
            let value = try peekNextValue(ofType: T.self)
            let result = try impl.unwrapFloatingPoint(from: value, as: T.self, for: codingPathNode, currentIndexKey)
            advanceToNextValue()
            return result
        }

        @inline(__always)
        private mutating func decodeFixedWidthIntegerIfPresent<T: FixedWidthInteger & Sendable>() throws -> T? {
            let value = peekNextValueIfPresent()
            let result: T?
            switch value {
            case .none: result = nil
            case .some(let v) where impl.isNull(v): result = nil
            case .some(let v): result = try impl.unwrapFixedWidthInteger(from: v, as: T.self, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }

        @inline(__always)
        private mutating func decodeFloatingPointIfPresent<T: BinaryFloatingPoint & Sendable>() throws -> T? {
            let value = peekNextValueIfPresent()
            let result: T?
            switch value {
            case .none: result = nil
            case .some(let v) where impl.isNull(v): result = nil
            case .some(let v): result = try impl.unwrapFloatingPoint(from: v, as: T.self, for: codingPathNode, currentIndexKey)
            }
            advanceToNextValue()
            return result
        }
    }
}

#endif  // FOUNDATION_FRAMEWORK || !os(macOS)
