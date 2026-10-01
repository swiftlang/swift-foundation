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

// `JSONPrimitive` is the JSON analog of `XMLPlistPrimitive` / `BPlistPrimitive`: a `~Escapable` cursor into a single node of a structurally-parsed JSON payload that allows faster access to random elements within it.

internal enum JSONTypeMarker: Sendable, Equatable {
    case string
    case number
    case null
    case `true`
    case `false`
    case object
    case array
}

internal enum JSONPrimitiveError: Error, Sendable {
    /// The scanner produced a marker for this offset, but it wasn't the one the caller expected.
    case typeMismatch(expected: String, actual: JSONTypeMarker?)
    /// The primitive at this offset carried a recognizable type but its payload didn't parse successfully.
    case corruptedValue(String)
    /// The marker at this offset didn't correspond to any known `JSONMapTypeDescriptor`.
    case invalidMarker
    /// Sentinel for leaf decoders that haven't been implemented for this format variant.
    case notImplemented
}

internal struct JSONPrimitive: ~Escapable, ~Sendable {

    /// Borrowed reference to the parsed JSON map.
    let map: Ref<JSONMap<UniqueMapRecords>>

    /// The source JSON bytes, borrowed from the document's data lock.
    let jsonBytes: RawSpan

    /// Offset into `map.value.records` of this primitive's marker slot.
    let mapOffset: Int

    @_lifetime(borrow map, copy jsonBytes)
    init(map: borrowing JSONMap<UniqueMapRecords>, jsonBytes: RawSpan, mapOffset: Int) {
        self = .init(mapRef: Ref(map), jsonBytes: jsonBytes, mapOffset: mapOffset)
    }

    @_lifetime(copy mapRef, copy jsonBytes)
    init(mapRef: consuming Ref<JSONMap<UniqueMapRecords>>, jsonBytes: RawSpan, mapOffset: Int) {
        self.map = mapRef
        self.jsonBytes = jsonBytes
        self.mapOffset = mapOffset
    }

    @inline(__always)
    fileprivate var rawDescriptor: JSONMapTypeDescriptor? {
        JSONMapTypeDescriptor(rawValue: map.value.records[mapOffset])
    }

    var type: JSONTypeMarker? {
        switch rawDescriptor {
        case .string, .simpleString: return .string
        case .number, .numberContainingExponent: return .number
        case .null: return .null
        case .true: return .true
        case .false: return .false
        case .object: return .object
        case .array: return .array
        case .collectionEnd, .none: return nil
        }
    }

    @inline(__always)
    fileprivate var stringHasEscapes: Bool {
        rawDescriptor == .string
    }

    @inline(__always)
    fileprivate var numberContainsExponent: Bool {
        rawDescriptor == .numberContainingExponent
    }

    /// Construct a sibling primitive at a different map offset, sharing this primitive's `map` and `jsonBytes`.
    @_lifetime(copy self)
    func sibling(atMapOffset offset: Int) -> JSONPrimitive {
        precondition(offset >= 0)
        return JSONPrimitive(mapRef: map, jsonBytes: jsonBytes, mapOffset: offset)
    }

    // MARK: - Convenience type checks

    var isNull: Bool { rawDescriptor == .null }

    var isStringType: Bool {
        let m = rawDescriptor
        return m == .string || m == .simpleString
    }

    var boolValue: Bool {
        get throws {
            switch rawDescriptor {
            case .true:  return true
            case .false: return false
            default: throw JSONPrimitiveError.typeMismatch(expected: "boolean", actual: type)
            }
        }
    }

    // MARK: - Scalar byte spans

    /// Source byte offset + length for the current scalar record. Layout: `[marker, count, sourceByteOffset]`. Only valid when `type == .string` or `type == .number`.
    @inline(__always)
    fileprivate var scalarRegion: (offset: Int, count: Int) {
        let count = map.value.records[mapOffset &+ 1]
        let offset = map.value.records[mapOffset &+ 2]
        return (offset, count)
    }

    /// Source-byte span for a `.string` primitive (raw bytes before escape processing), plus a flag indicating whether the source bytes are already usable directly (no `\`-escapes to process).
    var stringBytes: (bytes: Span<UInt8>, hasEscapes: Bool) {
        @_lifetime(copy self)
        get throws {
            guard type == .string else {
                throw JSONPrimitiveError.typeMismatch(expected: "string", actual: type)
            }
            let region = scalarRegion
            let slice = jsonBytes.extracting(unchecked: region.offset ..< region.offset &+ region.count)
            return (Span(viewing: slice), stringHasEscapes)
        }
    }

    /// Source-byte span for a `.number` primitive, plus whether the number's textual representation includes an exponent.
    var numberBytes: (bytes: Span<UInt8>, containsExponent: Bool) {
        @_lifetime(copy self)
        get throws {
            guard type == .number else {
                throw JSONPrimitiveError.typeMismatch(expected: "number", actual: type)
            }
            let region = scalarRegion
            let slice = jsonBytes.extracting(unchecked: region.offset ..< region.offset &+ region.count)
            return (Span(viewing: slice), numberContainsExponent)
        }
    }

    // MARK: - Array

    /// Iterator over the children of a `.array` primitive.
    internal struct ArrayIterator: ~Escapable, ~Sendable {
        let map: Ref<JSONMap<UniqueMapRecords>>
        let jsonBytes: RawSpan
        let count: Int
        var currentOffset: Int
        var elementsRemaining: Int

        @_lifetime(copy mapRef, copy jsonBytes)
        init(mapRef: Ref<JSONMap<UniqueMapRecords>>, jsonBytes: RawSpan, startOffset: Int, count: Int) {
            self.map = mapRef
            self.jsonBytes = jsonBytes
            self.count = count
            self.currentOffset = startOffset
            self.elementsRemaining = count
        }

        @_lifetime(copy self)
        mutating func next() -> JSONPrimitive? {
            guard elementsRemaining > 0 else { return nil }
            let child = JSONPrimitive(mapRef: map, jsonBytes: jsonBytes, mapOffset: currentOffset)
            currentOffset = map.value.offset(after: currentOffset)
            elementsRemaining &-= 1
            return child
        }
    }

    var arrayIterator: ArrayIterator {
        @_lifetime(copy self)
        get throws {
            guard type == .array else {
                throw JSONPrimitiveError.typeMismatch(expected: "array", actual: type)
            }
            let count = map.value.records[mapOffset &+ 2]
            let start = mapOffset &+ 3
            return ArrayIterator(mapRef: map, jsonBytes: jsonBytes, startOffset: start, count: count)
        }
    }

    // MARK: - Object (dictionary)

    /// Iterator over key-value pairs of an `.object` primitive, in source order. `KeyValuePair` records offsets; primitive views are constructed on demand via `key(of:)` / `value(of:)`.
    internal struct DictionaryIterator: ~Escapable, ~Sendable {
        let map: Ref<JSONMap<UniqueMapRecords>>
        let jsonBytes: RawSpan
        let count: Int
        var currentOffset: Int
        var pairsRemaining: Int

        internal struct KeyValuePair {
            let keyOffset: Int
            let valueOffset: Int
        }

        @_lifetime(copy mapRef, copy jsonBytes)
        init(mapRef: Ref<JSONMap<UniqueMapRecords>>, jsonBytes: RawSpan, startOffset: Int, count: Int) {
            self.map = mapRef
            self.jsonBytes = jsonBytes
            self.count = count
            self.currentOffset = startOffset
            self.pairsRemaining = count
        }

        mutating func next() -> KeyValuePair? {
            guard pairsRemaining > 0 else { return nil }
            let keyOffset = currentOffset
            let valueOffset = map.value.offset(after: keyOffset)
            currentOffset = map.value.offset(after: valueOffset)
            pairsRemaining &-= 1
            return KeyValuePair(keyOffset: keyOffset, valueOffset: valueOffset)
        }

        @_lifetime(copy self)
        func key(of pair: KeyValuePair) -> JSONPrimitive {
            JSONPrimitive(mapRef: map, jsonBytes: jsonBytes, mapOffset: pair.keyOffset)
        }

        @_lifetime(copy self)
        func value(of pair: KeyValuePair) -> JSONPrimitive {
            JSONPrimitive(mapRef: map, jsonBytes: jsonBytes, mapOffset: pair.valueOffset)
        }
    }

    var dictionaryIterator: DictionaryIterator {
        @_lifetime(copy self)
        get throws {
            guard type == .object else {
                throw JSONPrimitiveError.typeMismatch(expected: "object", actual: type)
            }
            let pairs = map.value.records[mapOffset &+ 2] &>> 1
            let start = mapOffset &+ 3
            return DictionaryIterator(mapRef: map, jsonBytes: jsonBytes, startOffset: start, count: pairs)
        }
    }

    // MARK: - Leaf decoders

    /// Decode the source bytes of a `.string` primitive into a Swift `String`.
    func decodeStringValue(json5Mode: Bool = false) throws -> String {
        let (bytes, hasEscapes) = try self.stringBytes
        return try Self.decodeStringPayload(bytes: bytes, hasEscapes: hasEscapes, json5Mode: json5Mode)
    }
    
    internal static func decodeStringPayload(bytes: borrowing Span<UInt8>, hasEscapes: Bool, json5Mode: Bool) throws -> String {
        if !hasEscapes {
            // RFC-8259 forbids unescaped control characters (0x00-0x1F) inside string literals. Scanner leniency means we validate here.
            // TODO: the pre-scan for control chars is an additional O(n) cost before we validate UTF-8; it'd be nice to merge this with either the scanner pass or the UTF8 validation pass.
            for byte in bytes where byte < 0x20 {
                throw JSONPrimitiveError.corruptedValue("string: unescaped control character")
            }
            guard let utf8 = try? UTF8Span(validating: copy bytes) else {
                throw JSONPrimitiveError.corruptedValue("string: invalid UTF-8")
            }
            return String(copying: utf8)
        }
        // Every escape sequence shrinks the byte count (single-byte escapes 2→1; `\uXXXX` ≤3 UTF-8 for 6 source; surrogate pair 4 UTF-8 for 12 source), so `bytes.count` is a safe upper bound on the output.
        let bytesCopy = copy bytes
        return try withTemporaryAllocation(of: UInt8.self, capacity: bytesCopy.count) { out throws in
            try decodeEscapedString(source: bytesCopy, json5Mode: json5Mode, into: &out)
            guard let utf8 = try? UTF8Span(validating: out.span) else {
                throw JSONPrimitiveError.corruptedValue("string: invalid UTF-8")
            }
            return String(copying: utf8)
        }
    }

    /// Slow-path escape decoder. `source` covers the string's contents (no surrounding quotes). Callers must supply an `out` with capacity ≥ `source.count`.
    internal static func decodeEscapedString(source: borrowing Span<UInt8>, json5Mode: Bool, into out: inout OutputSpan<UInt8>) throws {
        @inline(__always)
        func append(_ scalar: Unicode.Scalar, to out: inout OutputSpan<UInt8>) {
            UTF8.encode(scalar) { out.append($0) }
        }
        let count = source.count
        var readIdx = 0
        while readIdx < count {
            let c = source[readIdx]
            if c != ._backslash {
                if c < ._asciiFirstPrintable {
                    throw JSONPrimitiveError.corruptedValue("string: unescaped control character")
                }
                out.append(c)
                readIdx &+= 1
                continue
            }
            guard readIdx &+ 1 < count else {
                throw JSONPrimitiveError.corruptedValue("string: unterminated escape")
            }
            let escaped = source[readIdx &+ 1]
            switch escaped {
            case ._quote: out.append(._quote); readIdx &+= 2
            case ._backslash: out.append(._backslash); readIdx &+= 2
            case ._forwardslash: out.append(._forwardslash); readIdx &+= 2
            case UInt8(ascii: "b"): out.append(0x08); readIdx &+= 2
            case UInt8(ascii: "f"): out.append(0x0C); readIdx &+= 2
            case UInt8(ascii: "n"): out.append(0x0A); readIdx &+= 2
            case UInt8(ascii: "r"): out.append(0x0D); readIdx &+= 2
            case UInt8(ascii: "t"): out.append(0x09); readIdx &+= 2
            case UInt8(ascii: "u"):
                guard readIdx &+ 6 <= count else {
                    throw JSONPrimitiveError.corruptedValue("string: truncated \\u escape")
                }
                let unit = try parseHex4(source: source, at: readIdx &+ 2)
                if UTF16.isLeadSurrogate(unit) {
                    guard readIdx &+ 12 <= count,
                          source[readIdx &+ 6] == ._backslash,
                          source[readIdx &+ 7] == UInt8(ascii: "u") else {
                        throw JSONPrimitiveError.corruptedValue("string: high surrogate without low surrogate")
                    }
                    let trail = try parseHex4(source: source, at: readIdx &+ 8)
                    guard UTF16.isTrailSurrogate(trail) else {
                        throw JSONPrimitiveError.corruptedValue("string: invalid surrogate pair")
                    }
                    append(Self.scalar(lead: unit, trail: trail), to: &out)
                    readIdx &+= 12
                } else if UTF16.isTrailSurrogate(unit) {
                    // For compatibility, treat an isolated low surrogate as a bare UTF-16 code unit and emit U+FFFD.
                    append(Unicode.Scalar(0xFFFD)!, to: &out)
                    readIdx &+= 6
                } else {
                    if json5Mode && unit == 0 {
                        throw JSONPrimitiveError.corruptedValue("string: \\u0000 escape not allowed in JSON5")
                    }
                    // Both surrogate halves are handled above, so this always succeeds.
                    let scalar = Unicode.Scalar(unit)!
                    append(scalar, to: &out)
                    readIdx &+= 6
                }
            // JSON5-only escapes. Strict scanner rejects; JSON5 scanner accepts.
            case UInt8(ascii: "x") where json5Mode:
                // \xXX: 2 hex digits, one Latin-1 byte. `\x00` rejected.
                guard readIdx &+ 4 <= count else {
                    throw JSONPrimitiveError.corruptedValue("string: truncated \\x escape")
                }
                let hi = try parseHexNibble(source[readIdx &+ 2])
                let lo = try parseHexNibble(source[readIdx &+ 3])
                let value = (hi &<< 4) | lo
                guard value != 0 else {
                    throw JSONPrimitiveError.corruptedValue("string: \\x00 escape not allowed")
                }
                append(Unicode.Scalar(value), to: &out)
                readIdx &+= 4
            case UInt8(ascii: "'") where json5Mode:
                out.append(UInt8(ascii: "'"))
                readIdx &+= 2
            case UInt8(ascii: "0"):
                throw JSONPrimitiveError.corruptedValue("string: \\0 escape not allowed")
            case ._newline where json5Mode:
                // Line continuation: drop both the backslash and the newline.
                readIdx &+= 2
            case ._return where json5Mode:
                // Line continuation. Skip an optional trailing LF.
                readIdx &+= 2
                if readIdx < count && source[readIdx] == ._newline {
                    readIdx &+= 1
                }
            default:
                throw JSONPrimitiveError.corruptedValue("string: invalid escape sequence")
            }
        }
    }

    /// Parse a single ASCII hex digit into its 0..15 value.
    @inline(__always)
    private static func parseHexNibble(_ c: UInt8) throws -> UInt8 {
        switch c {
        case _asciiNumbers: return c &- _asciiNumbers.lowerBound
        case _hexCharsUpper: return c &- _hexCharsUpper.lowerBound &+ 10
        case _hexCharsLower: return c &- _hexCharsLower.lowerBound &+ 10
        default:
            throw JSONPrimitiveError.corruptedValue("string: non-hex digit in \\x escape")
        }
    }

    /// Parse 4 ASCII hex digits from `source` starting at `start` into a `UInt16` code unit.
    @inline(__always)
    private static func parseHex4(source: borrowing Span<UInt8>, at start: Int) throws -> UInt16 {
        var value: UInt16 = 0
        for i in 0..<4 {
            let c = source[start &+ i]
            let digit: UInt16
            switch c {
            case _asciiNumbers: digit = UInt16(c &- _asciiNumbers.lowerBound)
            case _hexCharsUpper: digit = UInt16(c &- _hexCharsUpper.lowerBound &+ 10)
            case _hexCharsLower: digit = UInt16(c &- _hexCharsLower.lowerBound &+ 10)
            default:
                throw JSONPrimitiveError.corruptedValue("string: non-hex digit in \\u escape")
            }
            value = (value &<< 4) | digit
        }
        return value
    }

    /// Combine a UTF-16 surrogate pair into the scalar it encodes. Both halves must already be known to be lead/trail surrogates, which puts the result in 0x10000...0x10FFFF.
    @inline(__always)
    private static func scalar(lead: UInt16, trail: UInt16) -> Unicode.Scalar {
        let value = 0x10000 &+ ((UInt32(lead) &- 0xD800) &<< 10) &+ (UInt32(trail) &- 0xDC00)
        return Unicode.Scalar(value).unsafelyUnwrapped
    }

    /// The result of decoding a `.number` primitive. Mirrors `_NSJSONReader`'s number parser so both the `NSNumber`-producing and `Codable` consumers can reproduce legacy behavior.
    ///
    /// `.double` is always finite: overflow to `±infinity` and underflow to zero are rejected before returning. `.positiveInfinity` / `.negativeInfinity` / `.notANumber` mean that, with JSON5 mode enabled, the source contained `Infinity` / `-Infinity` / `NaN`. `.decimalString` means the literal needs more precision than `Int64`, `UInt64` or `Double` can hold, so the consumer should decode the source bytes itself.
    struct DecodedNumber {
        enum Value {
            case int64(Int64)
            case uint64(UInt64)
            case double(Double)
            case positiveInfinity
            case negativeInfinity
            case notANumber
            case decimalString
        }
        let value: Value
    }

    /// Decode the source bytes of a `.number` primitive into a concrete Swift numeric value.
    func decodeNumberValue(json5Mode: Bool = false) throws -> DecodedNumber {
        let nb = try numberBytes
        guard nb.bytes.count > 0 else {
            throw JSONPrimitiveError.corruptedValue("number: empty")
        }
        return try Self.decodeNumberBytes(nb.bytes, containsExponent: nb.containsExponent, json5Mode: json5Mode, source: Span(viewing: jsonBytes))
    }

    /// Number of mantissa digits `strtod` can round-trip. Matches `DBL_DECIMAL_DIG`.
    private static var doubleLosslessDigits: Int { 17 }

    /// Offset of the first byte after any leading sign, and whether that sign was `-`.
    private struct NumberSign {
        var digitStart: Int
        var isNegative: Bool
    }

    @inline(__always)
    private static func numberSign(of bytes: borrowing Span<UInt8>, json5Mode: Bool) throws -> NumberSign {
        switch bytes[0] {
        case ._minus:
            return NumberSign(digitStart: 1, isNegative: true)
        case ._plus:
            guard json5Mode else {
                throw JSONPrimitiveError.corruptedValue("number: leading '+' not allowed in strict JSON")
            }
            return NumberSign(digitStart: 1, isNegative: false)
        default:
            return NumberSign(digitStart: 0, isNegative: false)
        }
    }

    /// Reject octal-like leading zeros (`00`, `01`, `-01`). A lone `0` is fine, as is `0` introducing a fraction, an exponent, or a JSON5 hex literal.
    @inline(__always)
    private static func checkNoLeadingZero(_ bytes: borrowing Span<UInt8>, from digitStart: Int, allowingHex: Bool) throws {
        guard bytes.count > digitStart &+ 1, bytes[digitStart] == UInt8(ascii: "0") else { return }
        let next = bytes[digitStart &+ 1]
        if next == ._period || next == ._e || next == ._E {
            return
        }
        if allowingHex, next == UInt8(ascii: "x") || next == UInt8(ascii: "X") {
            return
        }
        throw JSONPrimitiveError.corruptedValue("number: leading zero")
    }

    /// Strict JSON requires a digit immediately after any sign. JSON5 doesn't (`-.5` == -0.5).
    @inline(__always)
    private static func checkDigitAfterSign(_ bytes: borrowing Span<UInt8>, from digitStart: Int) throws {
        guard digitStart < bytes.count else {
            throw JSONPrimitiveError.corruptedValue("number: sign without digits")
        }
        let first = bytes[digitStart]
        guard _asciiNumbers.contains(first) else {
            throw JSONPrimitiveError.corruptedValue("number: '\(Character(UnicodeScalar(first)))' where a digit was expected")
        }
    }

    /// JSON5 spells infinity and NaN out longhand.
    @inline(__always)
    private static func json5NamedLiteral(_ bytes: borrowing Span<UInt8>, from digitStart: Int, isNegative: Bool) -> DecodedNumber? {
        let tail = bytes.extracting(digitStart ..< bytes.count)
        if tail.equals("Infinity") {
            return DecodedNumber(value: isNegative ? .negativeInfinity : .positiveInfinity)
        }
        if tail.equals("NaN") {
            return DecodedNumber(value: .notANumber)
        }
        return nil
    }

    /// JSON5 `0xHHHH`, after any sign. Returns nil when this isn't a hex literal.
    private static func json5HexLiteral(_ bytes: borrowing Span<UInt8>, from digitStart: Int, isNegative: Bool) throws -> DecodedNumber? {
        let count = bytes.count
        guard count &- digitStart >= 3, bytes[digitStart] == UInt8(ascii: "0") else { return nil }
        let marker = bytes[digitStart &+ 1]
        guard marker == UInt8(ascii: "x") || marker == UInt8(ascii: "X") else { return nil }

        var value: UInt64 = 0
        var overflow = false
        for i in (digitStart &+ 2) ..< count {
            let c = bytes[i]
            let digit: UInt64
            switch c {
            case _asciiNumbers: digit = UInt64(c &- _asciiNumbers.lowerBound)
            case _hexCharsUpper: digit = UInt64(c &- _hexCharsUpper.lowerBound &+ 10)
            case _hexCharsLower: digit = UInt64(c &- _hexCharsLower.lowerBound &+ 10)
            default:
                throw JSONPrimitiveError.corruptedValue("number: non-hex digit in JSON5 hex literal")
            }
            let mul = value.multipliedReportingOverflow(by: 16)
            if mul.overflow { overflow = true; break }
            let add = mul.partialValue.addingReportingOverflow(digit)
            if add.overflow { overflow = true; break }
            value = add.partialValue
        }
        if !overflow {
            if !isNegative {
                return DecodedNumber(value: .uint64(value))
            }
            if value <= UInt64(Int64.max) {
                return DecodedNumber(value: .int64(-Int64(value)))
            }
            if value == UInt64(Int64.max) &+ 1 {
                return DecodedNumber(value: .int64(Int64.min))
            }
        }
        throw JSONPrimitiveError.corruptedValue("number: JSON5 hex literal too large")
    }

    /// Integer fast path. Returns nil when a `.` shows the literal is really fractional, so the caller falls through to `strtod`. Overflow isn't an error: the digits just need more range than `Int64`/`UInt64` offers.
    private static func integerLiteral(_ bytes: borrowing Span<UInt8>, sign: NumberSign) throws -> DecodedNumber? {
        guard sign.digitStart < bytes.count else {
            throw JSONPrimitiveError.corruptedValue("number: no digits")
        }
        // Accumulate signed when negative so `-9223372036854775808` lands on `Int64.min` rather than overflowing.
        let stopper: UInt8
        if sign.isNegative {
            switch Int64.scanDecimalDigits(of: bytes, from: sign.digitStart, isNegative: true) {
            case .value(let signed): return DecodedNumber(value: .int64(signed))
            case .overflow: return DecodedNumber(value: .decimalString)
            case .nonDigit(let byte, _): stopper = byte
            }
        } else {
            switch UInt64.scanDecimalDigits(of: bytes, from: sign.digitStart) {
            case .value(let value): return DecodedNumber(value: .uint64(value))
            case .overflow: return DecodedNumber(value: .decimalString)
            case .nonDigit(let byte, _): stopper = byte
            }
        }
        // The JSON5 scanner is permissive and can hand over leftover `Inf`/`Na` prefixes or unquoted identifiers misclassified as numbers, so anything but `.` here is garbage.
        guard stopper == ._period else {
            throw JSONPrimitiveError.corruptedValue("number: non-digit in integer literal")
        }
        return nil
    }

    /// `strtod` happily consumes `1e` or `1.` and returns garbage, so reject truncated literals first. A trailing `.` is invalid in strict JSON but legal in JSON5 (`5.` == 5.0), and strict JSON also requires a digit immediately before `e`/`E` (`1.e2` is invalid).
    ///
    /// Kept separate from `mantissaDigitCount` deliberately. Fusing the two into one walk measured slower in Release: this scan only runs for strict JSON with an exponent, and the extra per-byte bookkeeping a combined loop needs costs more than the walk it saves. See `.claude/notes/json-number-divergences.md`.
    private static func checkFractionalSyntax(_ bytes: borrowing Span<UInt8>, from digitStart: Int, containsExponent: Bool, json5Mode: Bool) throws {
        let count = bytes.count
        let last = bytes[count &- 1]
        if last == ._e || last == ._E || last == ._plus || last == ._minus {
            throw JSONPrimitiveError.corruptedValue("number: trailing sign/exponent without digits")
        }
        guard !json5Mode else { return }
        if last == ._period {
            throw JSONPrimitiveError.corruptedValue("number: trailing decimal without digits")
        }
        guard containsExponent else { return }
        for i in digitStart ..< count {
            let c = bytes[i]
            if c == ._e || c == ._E {
                // `checkDigitAfterSign` already rejected a leading `e`, so `i > digitStart` here; the guard keeps a future reordering from indexing off the front.
                guard i > digitStart, _asciiNumbers.contains(bytes[i &- 1]) else {
                    throw JSONPrimitiveError.corruptedValue("number: '\(Character(UnicodeScalar(c)))' must be preceded by a digit")
                }
                return
            }
        }
    }

    /// Mantissa digits, ignoring leading zeros and anything from `e`/`E` onward.
    @inline(__always)
    private static func mantissaDigitCount(_ bytes: borrowing Span<UInt8>, from digitStart: Int) -> Int {
        var digits = 0
        var sawNonZero = false
        for i in digitStart ..< bytes.count {
            let c = bytes[i]
            if c == ._e || c == ._E { break }
            guard _asciiNumbers.contains(c) else { continue }
            if c != UInt8(ascii: "0") || sawNonZero {
                sawNonZero = true
                digits &+= 1
            }
        }
        return digits
    }

    /// Distinguish a literal zero (`0`, `0.0`, `0e5`) from a `strtod` underflow-to-zero (`2.01e-1234`). A non-zero digit in the mantissa means `strtod` rounded a non-zero value down; digits after `e`/`E` are exponent-only and don't count.
    ///
    /// Only reached when `strtod` returned zero, so folding it into the mantissa walk would pay per-byte bookkeeping on every number to save a walk on a path almost nothing takes. Covered by `test_underflowToZero`.
    @inline(__always)
    private static func isTrueZero(_ bytes: borrowing Span<UInt8>) -> Bool {
        for b in bytes {
            if b >= UInt8(ascii: "1") && b <= UInt8(ascii: "9") { return false }
            if b == ._e || b == ._E { return true }
        }
        return true
    }

    /// Parse via `strtod_l`, which needs a `char *` terminating on NUL or a non-numeric byte. When the document already has a non-numeric byte right after `bytes` — the common case for a nested number — it can read in place; a number that ends the document is copied into a NUL-terminated scratch.
    private static func parseDouble(_ bytes: borrowing Span<UInt8>, source: borrowing Span<UInt8>) throws -> Double {
        let count = bytes.count

        @inline(__always)
        func parseWithStrtod(_ cstr: UnsafePointer<UInt8>) -> Double? {
            var end: UnsafeMutablePointer<CChar>? = nil
            let parsed = Platform.strtod_clocale(cstr, &end)
            let consumed: Int = end.map { UnsafeRawPointer($0) - UnsafeRawPointer(cstr) } ?? 0
            // Deliberately not consulting `errno`: zeroing it before the call and reading it after is surprisingly expensive. Overflow shows up as a non-finite result; underflow is caught by `isTrueZero` below.
            guard consumed == count, parsed.isFinite else { return nil }
            return parsed
        }

        let parsed: Double?
        if !source.spanIsTerminated(by: bytes) {
            parsed = bytes.withUnsafeBufferPointer { parseWithStrtod($0.baseAddress!) }
        } else {
            parsed = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: count &+ 1) { buf -> Double? in
                for i in 0 ..< count {
                    buf[i] = bytes[i]
                }
                buf[count] = 0
                return parseWithStrtod(UnsafePointer(buf.baseAddress!))
            }
        }
        guard let parsed else {
            throw JSONPrimitiveError.corruptedValue("number: invalid literal")
        }
        if parsed == 0, !isTrueZero(bytes) {
            throw JSONPrimitiveError.corruptedValue("number: underflows Double")
        }
        return parsed
    }

    /// Decode `bytes` as a JSON (or JSON5) number.
    internal static func decodeNumberBytes(_ bytes: borrowing Span<UInt8>, containsExponent: Bool, json5Mode: Bool, source: borrowing Span<UInt8>) throws -> DecodedNumber {
        guard bytes.count > 0 else {
            throw JSONPrimitiveError.corruptedValue("number: empty")
        }

        let sign = try numberSign(of: bytes, json5Mode: json5Mode)
        if !json5Mode {
            try checkDigitAfterSign(bytes, from: sign.digitStart)
            try checkNoLeadingZero(bytes, from: sign.digitStart, allowingHex: false)
        } else if !containsExponent {
            // A JSON5 literal with an exponent skips this, matching the legacy reader.
            try checkNoLeadingZero(bytes, from: sign.digitStart, allowingHex: true)
        }

        if json5Mode {
            if let named = json5NamedLiteral(bytes, from: sign.digitStart, isNegative: sign.isNegative) {
                return named
            }
            if let hex = try json5HexLiteral(bytes, from: sign.digitStart, isNegative: sign.isNegative) {
                return hex
            }
        }

        // The scanner already told us whether there's an exponent; if there is, this can't be an integer.
        if !containsExponent, let integer = try integerLiteral(bytes, sign: sign) {
            return integer
        }

        try checkFractionalSyntax(bytes, from: sign.digitStart, containsExponent: containsExponent, json5Mode: json5Mode)

        // `strtod` silently truncates mantissas longer than `Double` can represent, so hand those to the caller as source bytes instead, delegating responsibility of how to interpret them.
        if mantissaDigitCount(bytes, from: sign.digitStart) > doubleLosslessDigits {
            return DecodedNumber(value: .decimalString)
        }

        return DecodedNumber(value: .double(try parseDouble(bytes, source: source)))
    }
}
#endif // FOUNDATION_FRAMEWORK || !os(macOS)
