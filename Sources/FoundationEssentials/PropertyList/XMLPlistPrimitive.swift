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

// Low-level cursor over a single node in a structurally-parsed XML property list, providing fast random access to its fields.

// TODO: We still potentially need XMLPlistResult

// MARK: - XMLPropertyList

/// Top-level entry for producing `XMLPlistPrimitive`s from a raw XML property list buffer.
internal struct XMLPropertyList: ~Escapable, ~Copyable, ~Sendable {
    let map: XMLPlistMap<UniqueMapRecords>
    let sourceBytes: RawSpan

    /// Run the iterative XML scanner over `sourceBytes` and produce a property list.
    @_lifetime(copy sourceBytes)
    init(_ sourceBytes: RawSpan) throws {
        let sourceSpan = Span<UInt8>(viewing: sourceBytes)
        let source = XMLPlistScannerEventSource(sourceBytes: sourceSpan)
        let sink = XMLPlistMapBuildingSink(sourceBytes: sourceSpan)
        self.map = try IterativeParsingDriver(sink: sink).run(source: source)
        self.sourceBytes = sourceBytes
    }

    var topLevelPrimitive: XMLPlistPrimitive {
        @_lifetime(borrow self)
        get { XMLPlistPrimitive(map: map, sourceBytes: sourceBytes, mapOffset: 0) }
    }
}

// MARK: - XMLPlistPrimitive

/// Unified type marker for `XMLPlistPrimitive`. Merges scanner-internal string variants into a single `.string` case.
internal enum XMLPlistTypeMarker: Sendable, Equatable {
    case null
    case `true`
    case `false`
    case integer
    case real
    case date
    case data
    case string
    case array
    case dict
    /// A `<dict>` whose single entry has key `CF$UID` and an integer value; the encoding NSKeyedArchiver uses for UIDs in XML plists.
    case uid
}

internal struct XMLPlistPrimitive: ~Escapable, ~Sendable {
    let map: Ref<XMLPlistMap<UniqueMapRecords>>
    let sourceBytes: RawSpan
    let mapOffset: XMLPlistMapOffset

    @_lifetime(borrow map, copy sourceBytes)
    init(map: borrowing XMLPlistMap<UniqueMapRecords>, sourceBytes: RawSpan, mapOffset: XMLPlistMapOffset) {
        self = .init(mapRef: Ref(map), sourceBytes: sourceBytes, mapOffset: mapOffset)
    }

    @_lifetime(copy mapRef, copy sourceBytes)
    init(mapRef: consuming Ref<XMLPlistMap<UniqueMapRecords>>, sourceBytes: RawSpan, mapOffset: XMLPlistMapOffset) {
        self.map = mapRef
        self.sourceBytes = sourceBytes
        self.mapOffset = mapOffset
    }

    /// Derive a sibling primitive at a different map offset, sharing this primitive's `map` and `sourceBytes`.
    @_lifetime(copy self)
    func sibling(atMapOffset offset: XMLPlistMapOffset) -> XMLPlistPrimitive {
        assert(offset >= 0)
        return XMLPlistPrimitive(mapRef: map, sourceBytes: sourceBytes, mapOffset: offset)
    }

    // MARK: Type / value

    /// The scanner's raw type descriptor for this record slot.
    @inline(__always)
    fileprivate var rawDescriptor: XMLPlistMapTypeDescriptor {
        XMLPlistMapTypeDescriptor(rawValue: map.value.records[mapOffset])!
    }

    /// Byte range (into `sourceBytes`) for scalar records that carry a source-byte span (`.string`/`.simpleString`/`.key`/`.simpleKey`/`.integer`/`.real`/`.date`/`.data`). Layout: `[marker, count, sourceByteOffset]`, three slots per record.
    @inline(__always)
    fileprivate var sourceRegion: (offset: Int, count: Int) {
        let count = map.value.records[mapOffset &+ 1]
        let offset = map.value.records[mapOffset &+ 2]
        return (offset, count)
    }

    /// Materialize the source-byte span for a scalar record.
    @inline(__always)
    @_lifetime(copy self)
    fileprivate func sourceRegionSpan() -> Span<UInt8> {
        let region = sourceRegion
        return Span(viewing: sourceBytes.extracting(unchecked: region.offset ..< region.offset &+ region.count))
    }

    /// The whole document, as a `Span`. Leaf decoders take this so they can report positions (see `XMLSpanReader.lineNumber`).
    @inline(__always)
    fileprivate var documentSpan: Span<UInt8> {
        @_lifetime(copy self)
        get { Span(viewing: sourceBytes) }
    }

    /// Unified type. Merges `.string`/`.simpleString`/`.key`/`.simpleKey` into `.string`.
    var type: XMLPlistTypeMarker? {
        switch rawDescriptor {
        case .string, .simpleString, .key, .simpleKey: return .string
        case .real: return .real
        case .integer: return .integer
        case .data: return .data
        case .date: return .date
        case .true: return .true
        case .false: return .false
        case .array: return .array
        case .dict: return .dict
        case .uid: return .uid
        case .nullSentinel: return .null
        case .collectionEnd: return nil
        }
    }

    var isNull: Bool { rawDescriptor == .nullSentinel }

    /// String rendering of this primitive's type for `DecodingError` messages. Matches `XMLPlistMapValue.debugDataTypeDescription`.
    var debugDataTypeDescription: String {
        switch type {
        case .null: return "a null value"
        case .true, .false: return "a boolean"
        case .integer: return "an integer"
        case .real: return "a real number"
        case .date: return "a date"
        case .data: return "a data value"
        case .string: return "a string"
        case .array: return "an array"
        case .dict: return "a dictionary"
        case .uid: return "an NSKeyedArchiver UID"
        case .none: return "an invalid XML plist value"
        }
    }

    var isStringType: Bool {
        switch rawDescriptor {
        case .string, .simpleString, .key, .simpleKey: return true
        default: return false
        }
    }

    /// True when this string primitive contains no XML escapes / CDATA blocks and so its source bytes can be used directly. Only meaningful when `isStringType`.
    var isSimpleString: Bool {
        let m = rawDescriptor
        return m == .simpleString || m == .simpleKey
    }

    var boolValue: Bool {
        get throws {
            switch rawDescriptor {
            case .true: return true
            case .false: return false
            default:
                throw XMLPlistError.typeMismatch(expected: "boolean", actual: rawDescriptor)
            }
        }
    }

    // MARK: Scalar byte spans

    /// Source-byte span for an `<integer>` value plus its byte offset in `sourceBytes`. Map-building sinks record the offset; tree sinks ignore it.
    var integerBytes: Span<UInt8> {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .integer else {
                throw XMLPlistError.typeMismatch(expected: "integer", actual: rawDescriptor)
            }
            return sourceRegionSpan()
        }
    }

    /// Source-byte span for a `<real>` value plus its byte offset.
    var realBytes: Span<UInt8> {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .real else {
                throw XMLPlistError.typeMismatch(expected: "real", actual: rawDescriptor)
            }
            return sourceRegionSpan()
        }
    }

    /// Source-byte span for a `<date>` value plus its byte offset.
    var dateBytes: Span<UInt8> {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .date else {
                throw XMLPlistError.typeMismatch(expected: "date", actual: rawDescriptor)
            }
            return sourceRegionSpan()
        }
    }

    /// Source-byte span for a `<data>` value (base64-encoded ASCII) plus its byte offset.
    var dataBytes: Span<UInt8> {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .data else {
                throw XMLPlistError.typeMismatch(expected: "data", actual: rawDescriptor)
            }
            return sourceRegionSpan()
        }
    }

    /// Source-byte span for a `<string>`/`<key>` value plus a flag indicating whether the bytes are already usable directly (no XML escapes or CDATA blocks). Positions within the document are derived from `sourceBytes`; see `Span.sourceByteRange(of:)`.
    var stringBytes: (bytes: Span<UInt8>, isSimple: Bool) {
        @_lifetime(copy self)
        get throws {
            guard isStringType else {
                throw XMLPlistError.typeMismatch(expected: "string", actual: rawDescriptor)
            }
            return (sourceRegionSpan(), isSimpleString)
        }
    }

    // MARK: Array iterator

    /// Iterator over the children of a `.array` primitive. Walks the inline records via record-length arithmetic.
    internal struct ArrayIterator: ~Escapable, ~Sendable {
        let map: Ref<XMLPlistMap<UniqueMapRecords>>
        let sourceBytes: RawSpan
        let count: Int
        var currentOffset: XMLPlistMapOffset
        var elementsRemaining: Int

        @_lifetime(copy mapRef, copy sourceBytes)
        init(mapRef: Ref<XMLPlistMap<UniqueMapRecords>>, sourceBytes: RawSpan, startOffset: XMLPlistMapOffset, count: Int) {
            self.map = mapRef
            self.sourceBytes = sourceBytes
            self.count = count
            self.currentOffset = startOffset
            self.elementsRemaining = count
        }

        @_lifetime(copy self)
        mutating func next() -> XMLPlistPrimitive? {
            guard elementsRemaining > 0 else { return nil }
            let child = XMLPlistPrimitive(mapRef: map, sourceBytes: sourceBytes, mapOffset: currentOffset)
            currentOffset = _nextMapOffset(after: currentOffset, in: map.value)
            elementsRemaining &-= 1
            return child
        }
    }

    var arrayIterator: ArrayIterator {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .array else {
                throw XMLPlistError.typeMismatch(expected: "array", actual: rawDescriptor)
            }
            let count = map.value.records[mapOffset &+ 2]
            let start = mapOffset &+ 3
            return ArrayIterator(mapRef: map, sourceBytes: sourceBytes, startOffset: start, count: count)
        }
    }

    // MARK: Dictionary iterator

    /// Iterator over key-value pairs of a `.dict` primitive. Emits pairs in source order. `KeyValuePair` is a bare `(keyOffset, valueOffset)` record; primitive views are constructed on demand so they share a single lifetime tied to the enclosing iterator.
    internal struct DictionaryIterator: ~Escapable, ~Sendable {
        let map: Ref<XMLPlistMap<UniqueMapRecords>>
        let sourceBytes: RawSpan
        let count: Int
        var currentOffset: XMLPlistMapOffset
        var pairsRemaining: Int

        internal struct KeyValuePair {
            let keyOffset: XMLPlistMapOffset
            let valueOffset: XMLPlistMapOffset
        }

        @_lifetime(copy mapRef, copy sourceBytes)
        init(mapRef: Ref<XMLPlistMap<UniqueMapRecords>>, sourceBytes: RawSpan, startOffset: XMLPlistMapOffset, count: Int) {
            self.map = mapRef
            self.sourceBytes = sourceBytes
            self.count = count
            self.currentOffset = startOffset
            self.pairsRemaining = count
        }

        mutating func next() -> KeyValuePair? {
            guard pairsRemaining > 0 else { return nil }
            let keyOffset = currentOffset
            let valueOffset = _nextMapOffset(after: keyOffset, in: map.value)
            currentOffset = _nextMapOffset(after: valueOffset, in: map.value)
            pairsRemaining &-= 1
            return KeyValuePair(keyOffset: keyOffset, valueOffset: valueOffset)
        }

        /// Build the key primitive for a pair returned by `next()`.
        @_lifetime(copy self)
        func key(of pair: KeyValuePair) -> XMLPlistPrimitive {
            XMLPlistPrimitive(mapRef: map, sourceBytes: sourceBytes, mapOffset: pair.keyOffset)
        }

        /// Build the value primitive for a pair returned by `next()`.
        @_lifetime(copy self)
        func value(of pair: KeyValuePair) -> XMLPlistPrimitive {
            XMLPlistPrimitive(mapRef: map, sourceBytes: sourceBytes, mapOffset: pair.valueOffset)
        }
    }

    var dictionaryIterator: DictionaryIterator {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .dict else {
                throw XMLPlistError.typeMismatch(expected: "dict", actual: rawDescriptor)
            }
            let pairs = map.value.records[mapOffset &+ 2] &>> 1
            let start = mapOffset &+ 3
            return DictionaryIterator(mapRef: map, sourceBytes: sourceBytes, startOffset: start, count: pairs)
        }
    }

    // MARK: UID

    /// Source-byte span for a `.uid` value's integer payload.
    var uidBytes: Span<UInt8> {
        @_lifetime(copy self)
        get throws {
            guard rawDescriptor == .uid else {
                throw XMLPlistError.typeMismatch(expected: "UID", actual: rawDescriptor)
            }
            return sourceRegionSpan()
        }
    }

    /// Decode a `.uid` primitive's integer payload.
    var uidValue: UInt32 {
        get throws {
            let span = try uidBytes
            do {
                let raw: UInt64 = try decodeXMLInteger(from: span, source: documentSpan)
                guard raw <= UInt64(UInt32.max) else {
                    throw XMLPlistError.corruptedValue("UID")
                }
                return UInt32(raw)
            } catch {
                throw XMLPlistError.corruptedValue("UID")
            }
        }
    }

    // MARK: Leaf decoding

    /// Decode this `.integer` primitive as `T`. Accepts leading whitespace, optional sign, decimal or hex. `.real`-typed primitives are accepted by rounding the parsed double to `T` via `T(exactly:)`.
    func decodeInteger<T: FixedWidthInteger & Sendable>(as type: T.Type = T.self) throws -> T {
        switch rawDescriptor {
        case .integer:
            return try decodeXMLInteger(from: try integerBytes, source: documentSpan)
        case .real:
            let d: Double = try decodeXMLReal(from: try realBytes, source: documentSpan)
            guard let v = T(exactly: d) else {
                throw XMLPlistError.corruptedValue("integer")
            }
            return v
        default:
            throw XMLPlistError.typeMismatch(expected: "integer", actual: rawDescriptor)
        }
    }

    /// Decode this `.real` primitive as `T`. `.integer`-typed primitives are accepted by promoting through `UInt64`/`Int64`.
    func decodeReal<T: BinaryFloatingPoint & Sendable>(as type: T.Type = T.self) throws -> T {
        switch rawDescriptor {
        case .real:
            return try decodeXMLReal(from: try realBytes, source: documentSpan)
        case .integer:
            if let u = try? decodeXMLInteger(from: try integerBytes, source: documentSpan) as UInt64 {
                return T(u)
            }
            let i: Int64 = try decodeXMLInteger(from: try integerBytes, source: documentSpan)
            return T(i)
        default:
            throw XMLPlistError.typeMismatch(expected: "real", actual: rawDescriptor)
        }
    }

    /// Decode this `.date` primitive to a `Date`.
    func decodeDate() throws -> Date {
        try decodeXMLDate(from: try dateBytes, source: documentSpan)
    }

    /// Decode this `.data` primitive to a `Data`.
    func decodeData() throws -> Data {
        let bytes = try dataBytes
        let cap = xmlDataDecodedMaxCount(from: bytes)
        return try Data(capacity: cap) { outputSpan throws in
            try decodeXMLData(from: bytes, into: &outputSpan, source: documentSpan)
        }
    }

    /// Decode this string primitive to a Swift `String`, handling XML escapes and CDATA blocks for non-simple strings.
    func decodeString() throws -> String {
        let (bytes, isSimple) = try stringBytes
        return try _decodeXMLString(from: bytes, isSimple: isSimple, source: documentSpan)
    }
}

// MARK: - Map navigation

// Advance one record in `map.records`.
@inline(__always)
internal func _nextMapOffset(after previousValueOffset: XMLPlistMapOffset, in map: borrowing XMLPlistMap<UniqueMapRecords>) -> XMLPlistMapOffset {
    let marker = map.records[previousValueOffset]
    switch XMLPlistMapTypeDescriptor(rawValue: marker) {
    case .string, .simpleString, .key, .simpleKey, .real, .integer, .data, .date, .uid:
        return previousValueOffset &+ 3
    case .true, .false, .nullSentinel:
        return previousValueOffset &+ 1
    case .dict, .array:
        // The collection records the offset to its next sibling.
        return map.records[previousValueOffset &+ 1]
    case .collectionEnd:
        fatalError("Attempt to find next object past the end of collection at offset \(previousValueOffset)")
    case .none:
        fatalError("Invalid XML value type code in mapping: \(marker)")
    }
}

// MARK: - Leaf decoders

/// The CF$UID key name used in NSKeyedArchiver's XML-plist UID encoding.
internal let CFUIDKeyName: StaticString = "CF$UID"

extension XMLPlistKeyView {
    /// True when this key is exactly `CF$UID`. Deliberately lives beside `CFUIDKeyName` rather than on the vocabulary type in `Codable/`: DriverKit's `INCLUDED_SOURCE_FILE_NAMES` allowlist compiles `Codable/` (for JSONEncoder/Decoder) without `PropertyList/` or `String/`, so a reference from there to either would not resolve.
    var isCFUIDKey: Bool {
        !hasEscapes && bytes.count == CFUIDKeyName.utf8CodeUnitCount && bytes.starts(with: CFUIDKeyName)
    }
}

/// Base64 decode table.
private let xmlDataDecodeTable: InlineArray<_, Int> =
[
    /* 000 */ -1, -1, -1, -1, -1, -1, -1, -1,
    /* 010 */ -1, -1, -1, -1, -1, -1, -1, -1,
    /* 020 */ -1, -1, -1, -1, -1, -1, -1, -1,
    /* 030 */ -1, -1, -1, -1, -1, -1, -1, -1,
    /* ' ' */ -1, -1, -1, -1, -1, -1, -1, -1,
    /* '(' */ -1, -1, -1, 62, -1, -1, -1, 63,
    /* '0' */ 52, 53, 54, 55, 56, 57, 58, 59,
    /* '8' */ 60, 61, -1, -1, -1,  0, -1, -1,
    /* '@' */ -1,  0,  1,  2,  3,  4,  5,  6,
    /* 'H' */  7,  8,  9, 10, 11, 12, 13, 14,
    /* 'P' */ 15, 16, 17, 18, 19, 20, 21, 22,
    /* 'X' */ 23, 24, 25, -1, -1, -1, -1, -1,
    /* '`' */ -1, 26, 27, 28, 29, 30, 31, 32,
    /* 'h' */ 33, 34, 35, 36, 37, 38, 39, 40,
    /* 'p' */ 41, 42, 43, 44, 45, 46, 47, 48,
    /* 'x' */ 49, 50, 51, -1, -1, -1, -1, -1
]

/// Parser for a  portion of an XML plist document captured by span. Parses leaf values.
struct XMLPlistSpanReader: ~Escapable, ~Sendable {
    let bytes: Span<UInt8>
    var index: Int
    // The whole document `bytes` came from, used only to compute line numbers for diagnostics.
    let source: Span<UInt8>

    @_lifetime(copy bytes, copy source)
    init(_ bytes: Span<UInt8>, source: Span<UInt8>) {
        self.bytes = bytes
        self.index = 0
        self.source = source
    }

    @inline(__always)
    var end: Int { bytes.count }

    /// 1-based line number of the cursor within the document. Computed on-demand from the beginning of the source to the current `index`.
    var lineNumber: Int {
        let cursor = source.sourceByteOffset(of: bytes) &+ Swift.min(index, end)
        var count = 1
        var i = 0
        while i < cursor {
            if source[i] == ._return {
                count &+= 1
                // A `\r\n` pair is one line break; skip the `\n` so it isn't counted again.
                let next = i &+ 1
                if next < cursor && source[next] == ._newline {
                    i = next
                }
            } else if source[i] == ._newline {
                count &+= 1
            }
            i &+= 1
        }
        return count
    }

    @inline(__always)
    var isAtEnd: Bool { index >= end }

    @inline(__always)
    var remainingCount: Int { end &- index }

    /// The byte `delta` positions past the cursor, or `nil` when that lands at or past the end.
    @inline(__always)
    func peek(offset delta: Int = 0) -> UInt8? {
        let at = index &+ delta
        return at < end ? bytes[at] : nil
    }

    @_disfavoredOverload
    @inline(__always)
    func peek() -> (UInt8, UInt8)? {
        (index &+ 1) < end ? (bytes[index], bytes[index &+ 1]) : nil
    }

    @_disfavoredOverload
    @inline(__always)
    func peek() -> (UInt8, UInt8, UInt8)? {
        (index &+ 2) < end ? (bytes[index], bytes[index &+ 1], bytes[index &+ 2]) : nil
    }

    @inline(__always)
    mutating func advance() {
        index &+= 1
    }

    @inline(__always)
    mutating func advance(_ n: Int) {
        index &+= n
    }

    @inline(__always)
    mutating func read() -> UInt8? {
        guard index < end else { return nil }
        let b = bytes[index]
        index &+= 1
        return b
    }

    /// True if the `s.utf8CodeUnitCount` bytes at `offset` — the cursor, by default — equal `s`. Bounds-checked.
    @inline(__always)
    func matches(_ s: StaticString, at offset: Int? = nil) -> Bool {
        let start = offset ?? index
        let n = s.utf8CodeUnitCount
        guard start >= 0, start &+ n <= bytes.count else { return false }
        return s.withUTF8Buffer { needle -> Bool in
            for k in 0 ..< n where bytes[start &+ k] != needle[k] {
                return false
            }
            return true
        }
    }

    /// True if the bytes at `offset` — the cursor, by default — are `tag`'s name. Does not check that a tag-name terminator follows. Bounds-checked.
    @inline(__always)
    func matches(tag: XMLPlistTag, at offset: Int? = nil) -> Bool {
        matches(tag.tagName, at: offset)
    }

    /// Consume the byte at the cursor, which must be `expected`. Throws naming `closingTag` when one is supplied.
    @inline(__always)
    mutating func consumeExpectedByte(_ expected: UInt8, closingTag: XMLPlistTag? = nil) throws {
        guard let byte = peek() else {
            throw XMLPlistError.unexpectedEndOfFile(context: closingTag.map { "while looking for close tag for \($0.tagName)" })
        }
        guard byte == expected else {
            throw XMLPlistError.unexpectedCharacter(byte, line: lineNumber, context: closingTag.map { "while looking for close tag for \($0.tagName)" })
        }
        advance()
    }

    /// Skip XML structural whitespace.
    @inline(__always)
    mutating func skipWhitespace() {
        while let byte = peek() {
            switch byte {
            case ._space, ._tab, ._newline, ._return:
                advance()
            default:
                return
            }
        }
    }

    /// Advance until the bytes at the cursor match `literal`, then consume through the match. Throws on EOF without a match.
    @inline(__always)
    mutating func skipUntilAndPast(_ literal: StaticString) throws {
        let len = literal.utf8CodeUnitCount
        while remainingCount >= len {
            if matches(literal) {
                advance(len)
                return
            }
            // TODO: This could be much more efficient.
            advance()
        }
        throw XMLPlistError.unexpectedEndOfFile()
    }

    /// Decode one UTF-8 scalar starting at the current index without advancing. Returns `nil` when the leading byte is a continuation or the buffer is too short for the encoded length.
    @inline(__always)
    func decodeScalar() -> (Unicode.Scalar?, scalarLength: Int) {
        guard index < end else { return (nil, 0) }
        let cu0 = bytes[index]
        guard !UTF8.isContinuation(cu0) else { return (nil, 0) }
        let len: Int
        if UTF8.isASCII(cu0) {
            len = 1
        } else {
            len = (~cu0).leadingZeroBitCount
        }
        guard len >= 1, end &- index >= len else { return (nil, 0) }
        switch len {
        case 1:
            return (Unicode.Scalar(cu0), 1)
        case 2:
            let y = bytes[index &+ 1]
            guard UTF8.isContinuation(y) else { return (nil, 0) }
            let value = (UInt32(cu0) & 0b0001_1111) &<< 6 | (UInt32(y) & 0x3F)
            return (Unicode.Scalar(value), 2)
        case 3:
            let y = bytes[index &+ 1], z = bytes[index &+ 2]
            guard UTF8.isContinuation(y), UTF8.isContinuation(z) else { return (nil, 0) }
            let value = ((UInt32(cu0) & 0b0000_1111) &<< 12)
                | ((UInt32(y) & 0x3F) &<< 6)
                | (UInt32(z) & 0x3F)
            return (Unicode.Scalar(value), 3)
        case 4:
            let y = bytes[index &+ 1], z = bytes[index &+ 2], w = bytes[index &+ 3]
            guard UTF8.isContinuation(y), UTF8.isContinuation(z), UTF8.isContinuation(w) else { return (nil, 0) }
            let value = ((UInt32(cu0) & 0b0000_0111) &<< 18)
                | ((UInt32(y) & 0x3F) &<< 12)
                | ((UInt32(z) & 0x3F) &<< 6)
                | (UInt32(w) & 0x3F)
            return (Unicode.Scalar(value), 4)
        default:
            return (nil, 0)
        }
    }

    mutating func skipIntegerWhitespace() {
        while let byte1 = self.peek() {
            // Integer parsing has historically had a very inclusive whitespace check.
            // We consider some additional values from 0x0 to 0x21 and 0x7E to 0xA1 as whitespace, for compatibility.
            if byte1 < 0x21 || (byte1 > 0x7E && byte1 < 0xA1) {
                self.advance()
                continue
            }
            let (scalar, length) = self.decodeScalar()
            if let scalar, scalar.properties.isWhitespace {
                self.advance(length)
                continue
            } else {
                break
            }
        }
    }

    /// Parses an XML integer into the desired integer type. Returns `nil` if the value cannot be represented in that type.
    mutating func parseInteger<Result: FixedWidthInteger>() -> Result? {
        guard _fastPath(!self.isAtEnd) else { return nil }

        let first = self.peek()
        var isNegative = false
        if first == ._minus {
            self.advance()
            isNegative = true
            skipIntegerWhitespace()
        } else if first == ._plus {
            self.advance()
            skipIntegerWhitespace()
        }

        let isHex: Bool
        if let (zeroChar, xChar) = self.peek() {
            isHex = zeroChar == UInt8(ascii: "0") && (xChar == UInt8(ascii: "x") || xChar == UInt8(ascii: "X"))
            if isHex {
                self.advance(2)
            }
        } else {
            isHex = false
        }

        if isHex {
            return parseHexDigits(isNegative: isNegative)
        } else {
            return parseDecimalDigits(isNegative: isNegative)
        }
    }

    private mutating func parseDecimalDigits<Result: FixedWidthInteger>(isNegative: Bool) -> Result? {
        guard _fastPath(!self.isAtEnd) else { return nil }

        let _0 = UInt8(ascii: "0")
        let numericalUpperBound: UInt8 = _0 &+ 10
        let multiplicand: Result = 10
        var result: Result = 0

        while let digit = self.read() {
            let digitValue: Result
            if _fastPath(digit >= _0 && digit < numericalUpperBound) {
                digitValue = Result(truncatingIfNeeded: digit &- _0)
            } else {
                return nil
            }
            let overflow1: Bool
            (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
            let overflow2: Bool
            (result, overflow2) = isNegative
                ? result.subtractingReportingOverflow(digitValue)
                : result.addingReportingOverflow(digitValue)
            guard _fastPath(!overflow1 && !overflow2) else { return nil }
        }
        return result
    }

    private mutating func parseHexDigits<Result: FixedWidthInteger>(isNegative: Bool) -> Result? {
        guard _fastPath(!self.isAtEnd) else { return nil }

        let _0 = UInt8(ascii: "0"), _A = UInt8(ascii: "A"), _a = UInt8(ascii: "a")
        let numericalUpperBound = _0 &+ 10
        let uppercaseUpperBound = _A &+ 6
        let lowercaseUpperBound = _a &+ 6
        let multiplicand: Result = 16
        var result: Result = 0

        while let digit = self.read() {
            let digitValue: Result
            if _fastPath(digit >= _0 && digit < numericalUpperBound) {
                digitValue = Result(truncatingIfNeeded: digit &- _0)
            } else if _fastPath(digit >= _A && digit < uppercaseUpperBound) {
                digitValue = Result(truncatingIfNeeded: digit &- _A &+ 10)
            } else if _fastPath(digit >= _a && digit < lowercaseUpperBound) {
                digitValue = Result(truncatingIfNeeded: digit &- _a &+ 10)
            } else {
                return nil
            }
            let overflow1: Bool
            (result, overflow1) = result.multipliedReportingOverflow(by: multiplicand)
            let overflow2: Bool
            (result, overflow2) = isNegative
                ? result.subtractingReportingOverflow(digitValue)
                : result.addingReportingOverflow(digitValue)
            guard _fastPath(!overflow1 && !overflow2) else { return nil }
        }
        return result
    }

    /// Read two ASCII digits and return their decimal value, advancing the cursor past both bytes on success.
    mutating func read2DigitNumber() -> Int? {
        guard let (ch1, ch2) = self.peek() else { return nil }
        self.advance(2)
        guard let dig1 = ch1.digitValue, let dig2 = ch2.digitValue else { return nil }
        return dig1 &* 10 + dig2
    }

    /// Walks the string payload, decoding entity refs and CDATA sections into `out` as UTF-8.
    mutating func parseXMLString(into out: inout OutputSpan<UInt8>) throws {
        var mark = self.index

        ReadLoop:
        while let ch = self.peek() {
            switch ch {
            case ._openangle: // Check for the start of a CDATA section, or a closing tag.
                guard let (_, couldBeExclamation) = self.peek(),
                      couldBeExclamation == ._exclamation else {
                    break ReadLoop
                }
                flushBytes(mark: mark, out: &out)
                try parseCDATASection(into: &out)
                mark = self.index
            case ._ampersand:
                flushBytes(mark: mark, out: &out)
                try parseEntityReferenceIntoBytes(out: &out)
                mark = self.index
            default:
                self.advance()
            }
        }

        if self.index > mark {
            flushBytes(mark: mark, out: &out)
        }
    }

    /// Append the raw byte run `[mark, self.index)` to `out`. Scanner guarantees the range is valid UTF-8 (it's a slice of the original document that hasn't crossed an entity/CDATA boundary).
    @inline(__always)
    private func flushBytes(mark: Int, out: inout OutputSpan<UInt8>) {
        let count = self.index &- mark
        guard count > 0 else { return }
        for i in 0 ..< count {
            out.append(self.bytes[mark &+ i])
        }
    }

    private var xmlCDATAOpeningMarker: StaticString { "<![CDATA[" }

    /// Consume `<![CDATA[…]]>` and append the payload to `out`.
    private mutating func parseCDATASection(into out: inout OutputSpan<UInt8>) throws {
        guard self.matches(xmlCDATAOpeningMarker) else {
            throw XMLPlistError.corruptedValue("string")
        }
        self.advance(xmlCDATAOpeningMarker.utf8CodeUnitCount)
        let begin = self.index
        let end = self.bytes.count &- 2
        while self.index < end {
            if self.matches("]]>") {
                for i in begin ..< self.index {
                    out.append(self.bytes[i])
                }
                self.advance(3)
                return
            }
            self.advance()
        }
        throw XMLPlistError.corruptedValue("string")
    }

    /// Parse an XML entity reference and append its UTF-8 encoding to `out`. Mirrors `_xmlParseEntityReference` but emits bytes rather than appending a `UnicodeScalar` to a `String`.
    private mutating func parseEntityReferenceIntoBytes(out: inout OutputSpan<UInt8>) throws {
        self.advance()  // move past '&'
        let len = self.remainingCount
        guard len > 0 else {
            throw XMLPlistError.unknownEscape(line: self.lineNumber)
        }

        let parsedScalar: UnicodeScalar
        switch self.peek() {
        case UInt8(ascii: "l"), UInt8(ascii: "g"):
            guard let (ch1, ch2, ch3) = self.peek(),
                  ch2 == UInt8(ascii: "t"), ch3 == ._semicolon else {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }
            parsedScalar = UnicodeScalar((ch1 == UInt8(ascii: "l")) ? ._openangle : ._closeangle)
            self.advance(3)
        case UInt8(ascii: "a"):
            guard len >= 4 else {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }
            if matches("mp;", at: self.index &+ 1) {
                parsedScalar = UnicodeScalar(._ampersand)
                self.advance(4)
            } else if len > 4, matches("pos;", at: self.index &+ 1) {
                parsedScalar = UnicodeScalar(UInt8(ascii: "'"))
                self.advance(5)
            } else {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }
        case UInt8(ascii: "q"):
            guard len >= 5, matches("uot;", at: self.index &+ 1) else {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }
            parsedScalar = UnicodeScalar(._quote)
            self.advance(5)
        case UInt8(ascii: "#"):
            self.advance()
            parsedScalar = try parseNumericEntityReference()
        default:
            throw XMLPlistError.unknownEscape(line: self.lineNumber)
        }

        // Encode the scalar as UTF-8 into `out`. UnicodeScalar.utf8 yields 1–4 bytes.
        for byte in parsedScalar.utf8 {
            out.append(byte)
        }
    }

    /// Parse the digits following `&#` up to `;` and return the scalar.
    private mutating func parseNumericEntityReference() throws -> UnicodeScalar {
        var isHex = false
        if self.peek() == UInt8(ascii: "x") {
            isHex = true
            self.advance()
        }

        var num = UInt32(0)
        var numberOfCharactersSoFar = 0
        while let ch = self.read() {
            numberOfCharactersSoFar += 1

            if ch == ._semicolon {
                guard let scalar = UnicodeScalar(num) else {
                    throw XMLPlistError.unknownEscape(line: self.lineNumber)
                }
                return scalar
            } else if numberOfCharactersSoFar > 8 {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }

            if !isHex {
                num = num &* 10
            } else {
                num = num &<< 4
            }

            if let digit = ch.digitValue {
                num = num &+ UInt32(digit)
            } else if !isHex {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            } else if let hexValue = ch.hexDigitValue {
                num = num &+ UInt32(hexValue)
            } else {
                throw XMLPlistError.unknownEscape(line: self.lineNumber)
            }
        }
        throw XMLPlistError.unknownEscape(line: self.lineNumber)
    }

    /// Parse the XML-plist real values that `strto*` does not: `nan`, `+/-infinity`, `+/-inf`.
    func parseSpecialReal<T: BinaryFloatingPoint>() throws -> T? {
        try bytes.withUnsafeBufferPointer { buf -> T? in
            switch (buf.first, buf.count) {
            case (UInt8(ascii: "n"), 3), (UInt8(ascii: "N"), 3):
                if (buf[1] == UInt8(ascii: "a") || buf[1] == UInt8(ascii: "A")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")) {
                    return .nan
                }
            case (UInt8(ascii: "+"), 9):
                if Platform.strncasecmp_clocale(buf.baseAddress!, "+infinity", 9) == 0 {
                    return .infinity
                }
            case (UInt8(ascii: "+"), 4):
                if (buf[1] == UInt8(ascii: "i") || buf[1] == UInt8(ascii: "I")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")),
                   (buf[3] == UInt8(ascii: "f") || buf[3] == UInt8(ascii: "F")) {
                    return .infinity
                }
            case (UInt8(ascii: "-"), 9):
                if Platform.strncasecmp_clocale(buf.baseAddress!, "-infinity", 9) == 0 {
                    return .infinity * -1
                }
            case (UInt8(ascii: "-"), 4):
                if (buf[1] == UInt8(ascii: "i") || buf[1] == UInt8(ascii: "I")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")),
                   (buf[3] == UInt8(ascii: "f") || buf[3] == UInt8(ascii: "F")) {
                    return .infinity * -1
                }
            case (UInt8(ascii: "i"), 8), (UInt8(ascii: "I"), 8):
                if Platform.strncasecmp_clocale(buf.baseAddress!, "infinity", 8) == 0 {
                    return .infinity
                }
            case (.none, 0):
                throw XMLPlistError.corruptedValue("real")
            default:
                break
            }
            return nil
        }
    }

    /// `strto*` accepts hexadecimal values, which are not valid in plist. Reject them up front.
    func rejectHexReal() throws {
        var looksLikeHex = false
        let count = bytes.count
        Loop:
        for i in 0 ..< count {
            let byte = bytes[i]
            switch byte {
            case ._plus, ._minus, ._space, ._tab, ._newline, ._return, UInt8(ascii: "0"):
                continue
            case UInt8(ascii: "x"), UInt8(ascii: "X"):
                looksLikeHex = true
                break Loop
            default:
                break Loop
            }
        }
        guard !looksLikeHex else {
            throw XMLPlistError.corruptedValue("real")
        }
    }

    /// Decode an XML `<real>` payload.
    func parseReal<T: BinaryFloatingPoint>() throws -> T {
        if let special: T = try parseSpecialReal() {
            return special
        }
        try rejectHexReal()

        return try bytes.withUnsafeBufferPointer { buf -> T in
            guard let ptr = buf.baseAddress else {
                throw XMLPlistError.corruptedValue("real")
            }
            var parseEndPtr: UnsafeMutablePointer<CChar>?
            let res: T
            if MemoryLayout<T>.size == MemoryLayout<Float>.size {
                res = T(Platform.strtof_clocale(ptr, &parseEndPtr))
            } else if MemoryLayout<T>.size == MemoryLayout<Double>.size {
                res = T(Platform.strtod_clocale(ptr, &parseEndPtr))
            } else {
                preconditionFailure("Only Float and Double are supported, not \(T.self)")
            }
            guard UnsafeRawPointer(ptr.advanced(by: buf.count)) == UnsafeRawPointer(parseEndPtr!) else {
                throw XMLPlistError.corruptedValue("real")
            }
            return res
        }
    }

    /// Decode an XML `<date>` payload.
    mutating func parseDate() throws -> Date {
        var badForm = false
        var yearIsNegative = false

        if self.peek() == ._minus {
            yearIsNegative = true
            self.advance()
        }

        var year = 0
        while let ch = self.peek(), let curDigit = ch.digitValue {
            let overflow: Bool
            let overflow2: Bool
            (year, overflow) = year.multipliedReportingOverflow(by: 10)
            (year, overflow2) = year.addingReportingOverflow(curDigit)
            self.advance()
            guard !overflow, !overflow2 else {
                badForm = true
                break
            }
        }
        if self.peek() != ._minus { badForm = true } else { self.advance() }

        let month: Int
        if !badForm, let m = self.read2DigitNumber(), self.peek() == ._minus {
            month = m
        } else {
            badForm = true
            month = -1
        }
        if !badForm { self.advance() }

        let day: Int
        if !badForm, let d = self.read2DigitNumber(), self.peek() == UInt8(ascii: "T") {
            day = d
        } else {
            badForm = true
            day = -1
        }
        if !badForm { self.advance() }

        let hour: Int
        if !badForm, let h = self.read2DigitNumber(), self.peek() == ._colon {
            hour = h
        } else {
            badForm = true
            hour = -1
        }
        if !badForm { self.advance() }

        let minute: Int
        if !badForm, let mn = self.read2DigitNumber(), self.peek() == ._colon {
            minute = mn
        } else {
            badForm = true
            minute = -1
        }
        if !badForm { self.advance() }

        let second: Int
        if !badForm, let s = self.read2DigitNumber(), self.peek() == UInt8(ascii: "Z") {
            second = s
        } else {
            badForm = true
            second = -1
        }
        if !badForm { self.advance() }

        guard !badForm else {
            throw XMLPlistError.corruptedValue("date")
        }
        if self.peek() != nil {
            throw XMLPlistError.corruptedValue("date")
        }

        let dc = DateComponents(year: yearIsNegative ? -year : year, month: month, day: day, hour: hour, minute: minute, second: second)
        if let date = Calendar.sufficientlyProlepticISO8601Calendar.date(from: dc) {
            return date
        }
        return Date(gregorianYear: Int64(yearIsNegative ? -year : year), month: Int8(month), day: Int8(day), hour: Int8(hour), minute: Int8(minute), second: Double(second))
    }

    /// Decode an XML `<data>` (base64) payload directly into `out`, which must have room for at least `xmlDataDecodedMaxCount(from:)` bytes of headroom. Consumes bytes from `span` until either the span is exhausted or a `<` is seen (start of the closing tag). Whitespace and non-base64 bytes are skipped.
    func decodeBase64(into out: inout OutputRawSpan) throws {
        let tableSpan = xmlDataDecodeTable.span
        var numEq = 0
        var acc = 0
        var cntr = 0
        let count = bytes.count
        var i = 0
        while i < count {
            let c = bytes[i]
            if c == ._openangle {
                break
            } else if c == ._equal {
                numEq += 1
            } else if !c.isASCIIWhitespace {
                numEq = 0
            }
            guard c < tableSpan.count else {
                throw XMLPlistError.corruptedValue("data")
            }
            let decoded = tableSpan[Int(c)]
            guard decoded >= 0 else {
                i &+= 1
                continue
            }
            cntr += 1
            acc = acc << 6 + decoded
            if 0 == (cntr & 0x3) {
                let byte1 = UInt8(truncatingIfNeeded: acc >> 16)
                let byte2 = UInt8(truncatingIfNeeded: acc >> 8)
                let byte3 = UInt8(truncatingIfNeeded: acc)
                if _fastPath(numEq == 0) {
                    let tmp: InlineArray = [byte1, byte2, byte3]
                    out._append(copying: tmp.span.bytes)
                } else if numEq == 1 {
                    let tmp: InlineArray = [byte1, byte2]
                    out._append(copying: tmp.span.bytes)
                } else {
                    out.append(byte1)
                }
            }
            i &+= 1
        }
    }
}

/// Decode an XML `<integer>` payload.
internal func decodeXMLInteger<T: FixedWidthInteger>(from span: borrowing Span<UInt8>, source: borrowing Span<UInt8>) throws -> T {
    let bytesCopy = copy span
    let sourceCopy = copy source
    var reader = XMLPlistSpanReader(bytesCopy, source: sourceCopy)

    reader.skipIntegerWhitespace()
    guard !reader.isAtEnd else {
        throw XMLPlistError.corruptedValue("integer")
    }
    guard let v: T = reader.parseInteger() else {
        throw XMLPlistError.corruptedValue("integer")
    }
    return v
}

/// Decode an XML `<real>` payload.
internal func decodeXMLReal<T: BinaryFloatingPoint>(from span: borrowing Span<UInt8>, source: borrowing Span<UInt8>) throws -> T {
    let reader = XMLPlistSpanReader(copy span, source: copy source)
    return try reader.parseReal()
}

/// Decode an XML `<date>` payload.
internal func decodeXMLDate(from span: borrowing Span<UInt8>, source: borrowing Span<UInt8>) throws -> Date {
    var reader = XMLPlistSpanReader(copy span, source: copy source)
    return try reader.parseDate()
}

/// Decode an XML `<data>` (base64) payload directly into `out`, which must have room for at least `xmlDataDecodedMaxCount(from:)` bytes of headroom.
internal func decodeXMLData(from span: borrowing Span<UInt8>, into out: inout OutputRawSpan, source: borrowing Span<UInt8>) throws {
    let reader = XMLPlistSpanReader(copy span, source: copy source)
    try reader.decodeBase64(into: &out)
}

/// Upper bound on decoded output bytes for `decodeXMLData`. Includes 2 bytes of slack for trailing-group bookkeeping.
@inline(__always)
internal func xmlDataDecodedMaxCount(from span: borrowing Span<UInt8>) -> Int {
    return ((span.count &+ 3) / 4) &* 3 &+ 2
}

/// Decode an XML `<string>` / `<key>` payload as a `Swift.String`, resolving entity refs and CDATA.
internal func _decodeXMLString(from span: borrowing Span<UInt8>, isSimple: Bool, source: borrowing Span<UInt8>) throws -> String {
    let bytes = copy span
    if isSimple {
        do {
            let utf8Span = try UTF8Span(validating: bytes)
            return String(copying: utf8Span)
        } catch {
            throw XMLPlistError.cannotConvertToUTF8
        }
    }

    // Non-simple strings: escape-decode into a temporary scratch buffer, then construct a String from those bytes. Decoded output is always <= input byte count.
    // TODO: Replace this with something equivalent to a variant of `String.init(unsafeUninitializedCapacity:initializingUTF8With:)` that validates instead of repairs.
    let cap = bytes.count
    return try withTemporaryAllocation(of: UInt8.self, capacity: cap) { outputSpan throws in
        var reader = XMLPlistSpanReader(bytes, source: copy source)
        try reader.parseXMLString(into: &outputSpan)

        do {
            let utf8Span = try UTF8Span(validating: outputSpan.span)
            return String(copying: utf8Span)
        } catch {
            throw XMLPlistError.cannotConvertToUTF8
        }
    }

}

#endif // FOUNDATION_FRAMEWORK || !os(macOS)
