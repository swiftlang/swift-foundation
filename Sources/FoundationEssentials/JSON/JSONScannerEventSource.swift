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

// MARK: - JSONScannerMode

/// Compile-time selector of the desired mode for `JSONScannerEventSource`.
/// In the absence of boolean literal generics, this protocol enables compile-time specialization and code elimination for JSON5-specific scanning code that isn't necessary in "strict" mode. This optimizes performance by eliminating unwanted checks and branches.
protocol JSONScannerMode {
    static var allowsJSON5: Bool { get }
}
enum StrictJSONMode: JSONScannerMode { static var allowsJSON5: Bool { false } }
enum JSON5Mode: JSONScannerMode { static var allowsJSON5: Bool { true } }

// MARK: - JSONEventScannerFrame

/// Per-container source state. Only tracks whether the current container has scanned a child yet (used to decide whether to consume a leading `,` or matching close).
internal struct JSONEventScannerFrame {
    var hasScannedChild: Bool = false
}

// MARK: - JSONScannerEventSource

/// `ParseEventSource` that walks a JSON byte buffer and emits events into an `IterativeParsingDriver`. JSON5 vs strict JSON is a compile-time distinction via the `Mode` type parameter; the two specializations share source but produce independent, tightly-optimized code.
struct JSONScannerEventSource<Mode: JSONScannerMode>: ParseEventSource<NullFilter>, ~Copyable, ~Escapable {
    typealias Vocabulary = JSONVocabulary
    typealias Frame = JSONEventScannerFrame

    struct Options {
        var assumesTopLevelDictionary: Bool = false
    }

    let sourceBytes: Span<UInt8>
    let options: Options
    var readOffset: Int
    /// True when an implicit top-level object was opened (no `{` in the source, `assumesTopLevelDictionary` set). Enables EOF as an implicit `}`.
    var topLevelWithoutBraces: Bool

    @_lifetime(copy sourceBytes)
    init(sourceBytes: Span<UInt8>, options: Options = Options()) {
        self.sourceBytes = sourceBytes
        self.options = options
        self.readOffset = 0
        self.topLevelWithoutBraces = false
    }

    // MARK: - ParseEventSource

    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        if options.assumesTopLevelDictionary {
            // A document that doesn't literally start with `{` is treated as an implicit top-level object.
            switch try consumeWhitespaceAllowingEOF() {
            case ._openbrace:
                try scanOneValue(into: &channel)
            default:
                topLevelWithoutBraces = true
                try openImplicitTopLevelObject(into: &channel)
            }
        } else {
            try scanOneValue(into: &channel)
        }
    }

    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == JSONVocabulary {
        assert(filter.state == .matchesAll)
        
        let isKeyed = channel.isTopKeyed
        var frame = channel.topSourceState
        let allowEOF = isKeyed && channel.stackDepth == 1 && topLevelWithoutBraces

        if frame.hasScannedChild {
            // Second+ child: consume `,` or matching close (trailing-comma tolerant).
            var delimiter = try consumeWhitespaceMaybeEOF(allowingEOF: allowEOF)
            let sawComma = (delimiter == ._comma)
            if sawComma {
                readOffset &+= 1
                delimiter = try consumeWhitespaceMaybeEOF(allowingEOF: allowEOF)
            }
            switch delimiter {
            case ._closebracket where !isKeyed:
                readOffset &+= 1
                return false
            case ._closebrace where isKeyed && !allowEOF:
                readOffset &+= 1
                return false
            case ._closebrace where isKeyed && allowEOF:
                throw makeUnexpectedCharacter(context: nil, ascii: ._closebrace, atOffset: 0)
            case nil:
                assert(allowEOF, "consumeWhitespace(allowingEOF:) would have thrown")
                return false
            default:
                if !sawComma {
                    let context = isKeyed ? "in object" : "in array"
                    throw makeUnexpectedCharacter(context: context, ascii: delimiter!, atOffset: 0)
                }
                // Fall through and scan the next child.
            }
        }
        // First-child path: the empty-container short-circuit happened in pushArray/pushObject before this frame was pushed.

        if isKeyed {
            try scanKey(into: &channel)
            let colon = try consumeWhitespace()
            guard colon == ._colon else {
                throw makeUnexpectedCharacter(context: "in object", ascii: colon, atOffset: 0)
            }
            readOffset &+= 1
        }

        // Set hasScannedChild BEFORE scanOneValue: a nested value may push and displace the top, and the parent's flag must be set for its next advanceTopFrame iteration.
        frame.hasScannedChild = true
        channel.topSourceState = frame

        try scanOneValue(into: &channel)
        return true
    }

    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        if channel.isTopKeyed {
            try channel.endKeyedContainer()
        } else {
            try channel.endUnkeyedContainer()
        }
    }

    mutating func finish() throws {
        try checkTrailingWhitespace()
    }

    // MARK: - Push / open

    private mutating func openImplicitTopLevelObject<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        // Empty document + assumesTopLevelDictionary: emit empty object at top level; no frame pushed.
        switch try consumeWhitespaceAllowingEOF() {
        case nil:
            try channel.emitEmptyKeyedContainer()
            return
        case ._closebrace:
            throw makeUnexpectedCharacter(context: nil, ascii: ._closebrace, atOffset: 0)
        default:
            break
        }
        try channel.beginKeyedContainer(cacheKey: nil, sourceState: JSONEventScannerFrame())
    }

    /// Scan one JSON value, leaf or container.
    private mutating func scanOneValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let byte = try consumeWhitespace()
        switch byte {
        case ._quote:
            try scanStringLeaf(quote: ._quote, into: &channel)
        case ._openbrace:
            try pushObject(into: &channel)
        case ._openbracket:
            try pushArray(into: &channel)
        case UInt8(ascii: "t"), UInt8(ascii: "f"):
            try scanBool(into: &channel)
        case UInt8(ascii: "n"):
            try scanNull(into: &channel)
        case UInt8(ascii: "-"), _asciiNumbers:
            try scanNumber(into: &channel)
        // JSON5 additions:
        case ._singleQuote where Mode.allowsJSON5:
            try scanStringLeaf(quote: ._singleQuote, into: &channel)
        case UInt8(ascii: "+") where Mode.allowsJSON5,
             UInt8(ascii: ".") where Mode.allowsJSON5,
             UInt8(ascii: "I") where Mode.allowsJSON5,
             UInt8(ascii: "N") where Mode.allowsJSON5:
            try scanNumber(into: &channel)
        default:
            throw makeUnexpectedCharacter(context: nil, ascii: byte, atOffset: 0)
        }
    }

    private mutating func pushArray<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        guard channel.stackDepth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: sourceLocation(atOffset: 0))
        }
        readOffset &+= 1 // consume '['
        // Empty-array short-circuit: matching close right after the opening bracket (skipping whitespace).
        switch try consumeWhitespace() {
        case ._closebracket:
            readOffset &+= 1
            try channel.emitEmptyUnkeyedContainer()
            return
        default:
            break
        }
        try channel.beginUnkeyedContainer(cacheKey: nil, sourceState: JSONEventScannerFrame())
    }

    private mutating func pushObject<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        guard channel.stackDepth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: sourceLocation(atOffset: 0))
        }
        readOffset &+= 1 // consume '{'
        switch try consumeWhitespace() {
        case ._closebrace:
            readOffset &+= 1
            try channel.emitEmptyKeyedContainer()
            return
        default:
            break
        }
        try channel.beginKeyedContainer(cacheKey: nil, sourceState: JSONEventScannerFrame())
    }

    // MARK: - Leaf scanning

    private mutating func scanKey<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        // Skip leading whitespace to reach the opening quote (or, in JSON5, an unquoted-key start byte).
        let first = try consumeWhitespace()
        let quote: UInt8
        switch first {
        case ._quote:
            quote = ._quote
        case ._singleQuote where Mode.allowsJSON5:
            quote = ._singleQuote
        default:
            if Mode.allowsJSON5 {
                try scanUnquotedKey(firstByte: first, into: &channel)
                return
            }
            throw makeUnexpectedCharacter(context: "in object", ascii: first, atOffset: 0)
        }
        let (byteOffset, byteCount, hasEscapes) = try skipQuotedString(quote: quote)
        let slice = sourceBytes.extracting(unchecked: byteOffset ..< byteOffset &+ byteCount)
        let key = JSONKeyView(bytes: slice, hasEscapes: hasEscapes, source: sourceBytes)
        try channel.parkKey(key)
    }

    /// JSON5 unquoted key at the current read offset. `firstByte` is already peeked (not consumed).
    private mutating func scanUnquotedKey<Sink: ParseEventSink & ~Copyable>(firstByte: UInt8, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        // First scalar must satisfy the stricter `isJSON5UnquotedKeyStartingCharacter` set (letters + `Nl`, minus decimal digits and connector punctuation). `$` / `_` / `\` are always accepted.
        let start = readOffset
        var sawEscape = false
        guard let firstEntry = try peekJSON5KeyScalar() else {
            throw JSONError.unexpectedEndOfFile
        }
        switch firstByte {
        case UInt8(ascii: "$"), UInt8(ascii: "_"), ._backslash:
            break
        default:
            guard firstEntry.scalar.isJSON5UnquotedKeyStartingCharacter else {
                throw makeUnexpectedCharacter(context: "at beginning of JSON5 unquoted key", ascii: firstByte, atOffset: 0)
            }
        }
        if firstEntry.isEscape { sawEscape = true }
        readOffset &+= firstEntry.length

        while let entry = try peekJSON5KeyScalar() {
            if entry.scalar.isJSON5UnquotedKeyCharacter {
                if entry.isEscape { sawEscape = true }
                readOffset &+= entry.length
            } else {
                break
            }
        }
        let byteCount = readOffset &- start
        let slice = sourceBytes.extracting(unchecked: start ..< start &+ byteCount)
        try channel.parkKey(JSONKeyView(bytes: slice, hasEscapes: sawEscape, source: sourceBytes))
    }

    /// Peek the scalar at `readOffset`. Decodes `\uXXXX` and `\xHH` escapes (returned with `isEscape: true` and full byte length including the backslash). `nil` at EOF.
    private mutating func peekJSON5KeyScalar() throws -> (scalar: UnicodeScalar, length: Int, isEscape: Bool)? {
        guard let firstChar = peek() else { return nil }
        if firstChar == ._backslash {
            guard let next = peek(offset: 1) else {
                throw JSONError.unexpectedEndOfFile
            }
            switch next {
            case UInt8(ascii: "u"):
                // `\uXXXX`: 6 bytes total.
                guard sourceBytes.count &- readOffset >= 6 else {
                    throw JSONError.unexpectedEndOfFile
                }
                var hex: UInt16 = 0
                for i in 0..<4 {
                    let b = sourceBytes[readOffset &+ 2 &+ i]
                    guard let d = b.hexDigitValue else {
                        throw JSONError.invalidHexDigitSequence(String(decoding: [b], as: UTF8.self), location: sourceLocation(atOffset: 2 &+ i))
                    }
                    hex = (hex << 4) | UInt16(d)
                }
                guard hex != 0, let scalar = UnicodeScalar(UInt32(hex)) else {
                    throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: sourceLocation(atOffset: 2), unicodeScalarValue: UInt32(hex))
                }
                return (scalar, 6, true)
            case UInt8(ascii: "x"):
                // `\xHH`: 4 bytes total.
                guard sourceBytes.count &- readOffset >= 4 else {
                    throw JSONError.unexpectedEndOfFile
                }
                var hex: UInt8 = 0
                for i in 0..<2 {
                    let b = sourceBytes[readOffset &+ 2 &+ i]
                    guard let d = b.hexDigitValue else {
                        throw JSONError.invalidHexDigitSequence(String(decoding: [b], as: UTF8.self), location: sourceLocation(atOffset: 2 &+ i))
                    }
                    hex = (hex << 4) | d
                }
                return (UnicodeScalar(hex), 4, true)
            default:
                throw makeUnexpectedCharacter(context: "in escape sequence", ascii: next, atOffset: 1)
            }
        }
        // ASCII fast path.
        if firstChar < 0x80 {
            return (UnicodeScalar(firstChar), 1, false)
        }
        // Multi-byte UTF-8 decode.
        return try decodeUTF8ScalarAtReadOffset(firstByte: firstChar)
    }

    /// Decode a multi-byte UTF-8 scalar starting at `readOffset`. `firstByte` was already peeked (but not consumed).
    private func decodeUTF8ScalarAtReadOffset(firstByte: UInt8) throws -> (scalar: UnicodeScalar, length: Int, isEscape: Bool) {
        // Determine the scalar length from the leading byte.
        let len: Int
        switch firstByte {
        case 0xC0...0xDF: len = 2
        case 0xE0...0xEF: len = 3
        case 0xF0...0xF7: len = 4
        default:
            throw makeUnexpectedCharacter(context: "in UTF-8 sequence", ascii: firstByte, atOffset: 0)
        }
        guard sourceBytes.count &- readOffset >= len else {
            throw JSONError.unexpectedEndOfFile
        }
        var value: UInt32
        switch len {
        case 2:
            let b1 = sourceBytes[readOffset &+ 1]
            guard b1 & 0xC0 == 0x80 else {
                throw makeUnexpectedCharacter(context: "in UTF-8 sequence", ascii: b1, atOffset: 1)
            }
            value = (UInt32(firstByte) & 0x1F) << 6 | UInt32(b1 & 0x3F)
        case 3:
            let b1 = sourceBytes[readOffset &+ 1]
            let b2 = sourceBytes[readOffset &+ 2]
            guard b1 & 0xC0 == 0x80, b2 & 0xC0 == 0x80 else {
                throw makeUnexpectedCharacter(context: "in UTF-8 sequence", ascii: b1, atOffset: 1)
            }
            value = (UInt32(firstByte) & 0x0F) << 12 | (UInt32(b1 & 0x3F) << 6) | UInt32(b2 & 0x3F)
        default: // 4
            let b1 = sourceBytes[readOffset &+ 1]
            let b2 = sourceBytes[readOffset &+ 2]
            let b3 = sourceBytes[readOffset &+ 3]
            guard b1 & 0xC0 == 0x80, b2 & 0xC0 == 0x80, b3 & 0xC0 == 0x80 else {
                throw makeUnexpectedCharacter(context: "in UTF-8 sequence", ascii: b1, atOffset: 1)
            }
            value = (UInt32(firstByte) & 0x07) << 18 | (UInt32(b1 & 0x3F) << 12) | (UInt32(b2 & 0x3F) << 6) | UInt32(b3 & 0x3F)
        }
        guard let scalar = UnicodeScalar(value) else {
            throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: sourceLocation(atOffset: 0), unicodeScalarValue: value)
        }
        return (scalar, len, false)
    }

    private mutating func scanStringLeaf<Sink: ParseEventSink & ~Copyable>(quote: UInt8, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let (byteOffset, byteCount, hasEscapes) = try skipQuotedString(quote: quote)
        let slice = sourceBytes.extracting(unchecked: byteOffset ..< byteOffset &+ byteCount)
        try channel.emitScalar(JSONScalar.string(bytes: slice, hasEscapes: hasEscapes, source: sourceBytes))
    }

    private mutating func scanNumber<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let startOffset = readOffset
        var containsExponent = false
        let hitEOF = try skipNumber(containsExponent: &containsExponent)
        let byteCount = readOffset &- startOffset
        let slice = sourceBytes.extracting(unchecked: startOffset ..< startOffset &+ byteCount)
        try channel.emitScalar(JSONScalar.number(bytes: slice, containsExponent: containsExponent, source: sourceBytes))
    }

    private mutating func scanBool<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let first = try readByteOrEOF()
        switch first {
        case UInt8(ascii: "t"):
            try expectLiteralTail("rue", context: "boolean")
            try channel.emitScalar(JSONScalar.bool(true))
        case UInt8(ascii: "f"):
            try expectLiteralTail("alse", context: "boolean")
            try channel.emitScalar(JSONScalar.bool(false))
        default:
            preconditionFailure("scanBool: expected 't' or 'f' as first character")
        }
    }

    private mutating func scanNull<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == JSONVocabulary {
        let first = try readByteOrEOF()
        precondition(first == UInt8(ascii: "n"), "scanNull: expected 'n' as first character")
        try expectLiteralTail("ull", context: "null")
        try channel.emitNull()
    }

    // MARK: - Trailing whitespace

    private mutating func checkTrailingWhitespace() throws {
        if let byte = try consumeWhitespaceAllowingEOF() {
            throw makeUnexpectedCharacter(context: "after top-level value", ascii: byte, atOffset: 0)
        }
    }

    // MARK: - Byte-level helpers

    @inline(__always)
    private func peek(offset: Int = 0) -> UInt8? {
        assert(offset >= 0, "peek(offset:) requires a non-negative offset")
        let idx = readOffset &+ offset
        guard idx < sourceBytes.count else { return nil }
        return sourceBytes[idx]
    }

    @inline(__always)
    private mutating func readByteOrEOF() throws -> UInt8 {
        guard readOffset < sourceBytes.count else { throw JSONError.unexpectedEndOfFile }
        let b = sourceBytes[readOffset]
        readOffset &+= 1
        return b
    }

    // Static stored properties aren't allowed in generic types. Computed properties on constant expressions fold to the same immediates under `-O`.
    private static var strictWhitespaceBitmap: UInt64 { 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab }
    /// JSON5 adds `\v` and `\f`; NBSP (0xA0) sits outside the 0...63 range and takes a separate branch.
    private static var json5WhitespaceBitmap: UInt64 { strictWhitespaceBitmap | 1 << UInt8._verticalTab | 1 << UInt8._formFeed }

    @discardableResult
    @inline(__always)
    private mutating func consumeWhitespace() throws -> UInt8 {
        if let byte = try consumeWhitespaceAllowingEOF() {
            return byte
        }
        throw JSONError.unexpectedEndOfFile
    }

    @discardableResult
    @inline(__always)
    private mutating func consumeWhitespaceAllowingEOF() throws -> UInt8? {
        let bitmap = Mode.allowsJSON5 ? Self.json5WhitespaceBitmap : Self.strictWhitespaceBitmap
        while readOffset < sourceBytes.count {
            let b = sourceBytes[readOffset]
            if bitmap & (1 << UInt64(b)) != 0 {
                readOffset &+= 1
                continue
            }
            if Mode.allowsJSON5 {
                if b == ._nbsp {
                    readOffset &+= 1
                    continue
                }
                if b == ._forwardslash {
                    if try consumePossibleComment() {
                        continue
                    }
                    return b
                }
            }
            return b
        }
        return nil
    }

    @inline(__always)
    private mutating func consumeWhitespaceMaybeEOF(allowingEOF: Bool) throws -> UInt8? {
        if allowingEOF {
            return try consumeWhitespaceAllowingEOF()
        }
        return try consumeWhitespace()
    }

    /// `readOffset` is at `/` (JSON5 mode). Consumes `//...` or `/*...*/` and returns `true`; on a non-comment byte after `/`, leaves `readOffset` and returns `false`.
    private mutating func consumePossibleComment() throws -> Bool {
        precondition(Mode.allowsJSON5)
        precondition(peek() == ._forwardslash)
        guard let next = peek(offset: 1) else { return false }
        switch next {
        case ._forwardslash:
            // Line comment: consume through the next CR / LF, or EOF.
            readOffset &+= 2
            while let b = peek() {
                readOffset &+= 1
                if b == ._newline || b == ._return {
                    return true
                }
            }
            return true
        case ._asterisk:
            // Block comment: consume through `*/`. Unterminated throws.
            readOffset &+= 2
            while readOffset < sourceBytes.count {
                let b = sourceBytes[readOffset]
                readOffset &+= 1
                if b == ._asterisk, peek() == ._forwardslash {
                    readOffset &+= 1
                    return true
                }
            }
            throw JSONError.unterminatedBlockComment
        default:
            return false
        }
    }

    /// Skip a `"..."` (or `'...'` in JSON5 mode) string. `quote` is the byte the caller peeked. Returns `(byteOffset, byteCount, hasEscapes)` over the interior bytes (no quotes).
    private mutating func skipQuotedString(quote: UInt8) throws -> (byteOffset: Int, byteCount: Int, hasEscapes: Bool) {
        guard readOffset < sourceBytes.count else {
            throw JSONError.unexpectedEndOfFile
        }
        let openQuote = sourceBytes[readOffset]
        guard openQuote == quote else {
            throw makeUnexpectedCharacter(context: nil, ascii: openQuote, atOffset: 0)
        }
        readOffset &+= 1
        let contentStart = readOffset

        // Fast path: no escapes, no invalid control characters.
        if try skipUTF8UntilQuoteOrBackslashOrInvalid(quote: quote) == quote {
            let contentEnd = readOffset
            readOffset &+= 1 // consume closing quote
            return (contentStart, contentEnd &- contentStart, false)
        }

        // Slow path: escapes or invalid-control-char.
        while let byte = peek() {
            switch byte {
            case quote:
                let contentEnd = readOffset
                readOffset &+= 1
                return (contentStart, contentEnd &- contentStart, true)
            case ._backslash:
                try skipEscapeSequence(quote: quote)
            default:
                readOffset &+= 1
                continue
            }
        }
        throw JSONError.unexpectedEndOfFile
    }

    /// Advance to `quote`, `\`, an invalid control char, or EOF. Returns the byte stopped at (without consuming). Throws on EOF.
    private mutating func skipUTF8UntilQuoteOrBackslashOrInvalid(quote: UInt8) throws -> UInt8 {
        while let byte = peek() {
            if byte == quote || byte == ._backslash {
                return byte
            }
            // Any control character in 0x00...0x1f fails the `& 0xe0 != 0` fast check.
            guard _fastPath(byte & 0xe0 != 0) else { return byte }
            readOffset &+= 1
        }
        throw JSONError.unexpectedEndOfFile
    }

    private mutating func skipEscapeSequence(quote: UInt8) throws {
        let backslash = try readByteOrEOF()
        precondition(backslash == ._backslash)
        let ascii = try readByteOrEOF()
        // Validation deferred to decode time; this just advances past the escape. `\uXXXX` and `\xHH` need byte-count checks to avoid overrunning; `\<CR><LF>` consumes both bytes as one continuation.
        switch ascii {
        case UInt8(ascii: "u"):
            try skipUnicodeHexSequence(quote: quote)
        case UInt8(ascii: "x") where Mode.allowsJSON5:
            try skipTwoByteHexSequence(quote: quote)
        case ._return where Mode.allowsJSON5:
            // `\<CR>` or `\<CRLF>`: swallow the optional LF.
            if peek() == ._newline {
                readOffset &+= 1
            }
        default:
            break
        }
    }

    private mutating func skipUnicodeHexSequence(quote: UInt8) throws {
        guard sourceBytes.count &- readOffset >= 4 else {
            throw JSONError.unexpectedEndOfFile
        }
        // Hitting the closing quote here means the hex sequence was truncated. Full digit validation deferred to decode.
        for i in 0..<4 {
            if sourceBytes[readOffset &+ i] == quote {
                var preview: [UInt8] = []
                preview.reserveCapacity(4)
                for j in 0..<4 { preview.append(sourceBytes[readOffset &+ j]) }
                let s = String(decoding: preview, as: UTF8.self)
                throw JSONError.invalidHexDigitSequence(s, location: sourceLocation(atOffset: 0))
            }
        }
        readOffset &+= 4
    }

    private mutating func skipTwoByteHexSequence(quote: UInt8) throws {
        guard sourceBytes.count &- readOffset >= 2 else {
            throw JSONError.unexpectedEndOfFile
        }
        for i in 0..<2 {
            if sourceBytes[readOffset &+ i] == quote {
                var preview: [UInt8] = []
                preview.reserveCapacity(2)
                for j in 0..<2 { preview.append(sourceBytes[readOffset &+ j]) }
                let s = String(decoding: preview, as: UTF8.self)
                throw JSONError.invalidHexDigitSequence(s, location: sourceLocation(atOffset: 0))
            }
        }
        readOffset &+= 2
    }

    /// Advance through a JSON number. Sets `containsExponent` on `e`/`E`. In JSON5 mode also accepts `+`/`.`/`I`/`N` as leading bytes and consumes ASCII letters so tokens like `Infinity`, `NaN`, `0x1F` capture as one span; the sink's number decoder does the real validation. Returns `true` iff scanning stopped at EOF rather than a trailing non-numeric byte.
    private mutating func skipNumber(containsExponent: inout Bool) throws -> Bool {
        let first = try readByteOrEOF()
        switch first {
        case _asciiNumbers, UInt8(ascii: "-"):
            break
        case UInt8(ascii: "+") where Mode.allowsJSON5,
             UInt8(ascii: ".") where Mode.allowsJSON5,
             UInt8(ascii: "I") where Mode.allowsJSON5,
             UInt8(ascii: "N") where Mode.allowsJSON5:
            break
        default:
            preconditionFailure("skipNumber: unexpected first byte")
        }
        while let byte = peek() {
            if _fastPath(_asciiNumbers.contains(byte)) {
                readOffset &+= 1
                continue
            }
            switch byte {
            case UInt8(ascii: "."), UInt8(ascii: "+"), UInt8(ascii: "-"):
                readOffset &+= 1
            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                readOffset &+= 1
                containsExponent = true
            case _allLettersLower where Mode.allowsJSON5,
                 _allLettersUpper where Mode.allowsJSON5:
                // Sweep up `Infinity`, `NaN`, hex-digit tails. Validated by the sink.
                readOffset &+= 1
            default:
                return false
            }
        }
        return true
    }

    private mutating func expectLiteralTail(_ tail: StaticString, context: String) throws {
        // `StaticString.withUTF8Buffer` takes a non-throwing closure, so find the mismatch inside and throw outside.
        let need = tail.utf8CodeUnitCount
        guard sourceBytes.count &- readOffset >= need else {
            throw JSONError.unexpectedEndOfFile
        }
        var mismatchIndex = -1
        tail.withUTF8Buffer { tailBytes in
            for i in 0..<need {
                if sourceBytes[readOffset &+ i] != tailBytes[i] {
                    mismatchIndex = i
                    return
                }
            }
        }
        if mismatchIndex >= 0 {
            // Advance to the mismatched byte so the error location is accurate.
            readOffset &+= mismatchIndex
            let bad = sourceBytes[readOffset]
            throw makeUnexpectedCharacter(context: "in expected \(context) value", ascii: bad, atOffset: 0)
        }
        readOffset &+= need
    }

    // MARK: - Error construction

    private func makeUnexpectedCharacter(context: String?, ascii: UInt8, atOffset offset: Int) -> JSONError {
        .unexpectedCharacter(context: context, ascii: ascii, location: sourceLocation(atOffset: offset))
    }

    /// Source location for `readOffset + offset`. Line / column walk is O(offset). Caller must pass a non-negative offset.
    private func sourceLocation(atOffset offset: Int) -> JSONError.SourceLocation {
        assert(offset >= 0, "sourceLocation(atOffset:) requires a non-negative offset")
        let absolute = readOffset &+ offset
        var line = 1
        var col = 0
        var i = 0
        let end = Swift.min(absolute &+ 1, sourceBytes.count)
        while i < end {
            let b = sourceBytes[i]
            switch b {
            case ._return:
                let next = i &+ 1
                if next <= absolute, next < sourceBytes.count, sourceBytes[next] == ._newline {
                    i = next
                }
                line &+= 1
                col = 0
            case ._newline:
                line &+= 1
                col = 0
            default:
                col &+= 1
            }
            i &+= 1
        }
        return JSONError.SourceLocation(line: line, column: col, index: absolute)
    }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
