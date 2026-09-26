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

// MARK: - XMLPlistScannerEventSource

/// `ParseEventSource` that walks a raw XML property list byte buffer directly, emitting begin/end/scalar/key events to an `IterativeParsingDriver`.
struct XMLPlistScannerEventSource: ParseEventSource<NullFilter>, ~Copyable, ~Escapable {
    typealias Vocabulary = XMLPlistVocabulary
    
    /// Maximum container nesting depth.
    private static var maxContainerDepth: Int { 512 }

    /// Holds the plist span and the read cursor.
    var reader: XMLPlistSpanReader
    
    /// True while parsing inside the `<plist>...</plist>` wrapper.
    var insidePlist: Bool

    @_lifetime(copy sourceBytes)
    init(sourceBytes: Span<UInt8>) {
        self.reader = XMLPlistSpanReader(sourceBytes, source: sourceBytes)
        self.insidePlist = false
    }

    // MARK: - ParseEventSource

    mutating func emitTopLevelValue<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        // Skip prologue (whitespace, `<?xml ...?>`, `<!DOCTYPE ...>`, `<!-- ... -->` comments), consuming a `<plist>` wrapper if present, then dispatch the root value tag.
        try skipPrologue()
        try reader.consumeExpectedByte(._openangle)
        let (rootTag, rootEmpty) = try readOpenTagAfterAngle()
        if rootTag == .plist {
            if rootEmpty {
                throw XMLPlistError.unexpectedEmptyTag(.plist, line: reader.lineNumber)
            }
            insidePlist = true
            // Find the actual root value inside (skipping any intermediate comments / PI / whitespace).
            guard try scanUpToNextTag() else {
                throw XMLPlistError.unexpectedEmptyTag(.plist, line: reader.lineNumber)
            }
            try reader.consumeExpectedByte(._openangle)
            let (tag, isEmpty) = try readOpenTagAfterAngle()
            try dispatchOpenTag(tag, isEmpty: isEmpty, into: &channel)
        } else {
            try dispatchOpenTag(rootTag, isEmpty: rootEmpty, into: &channel)
        }
    }

    mutating func advanceTopFrame<Sink: ParseEventSink & ~Copyable, View: FilterView & ~Copyable & ~Escapable>(into channel: inout IterativeParsingDriver<Self, Sink>, filter: borrowing View) throws -> Bool where Sink.Vocabulary == XMLPlistVocabulary {
        assert(filter.state == .matchesAll)

        // Look for the next value inside the top frame, skipping intervening whitespace, comments, and PIs. Returns false at the frame's close tag, which `finalizeTopFrame` then consumes.
        guard try scanUpToNextTag() else {
            return false
        }

        // Open tag; consume `<` and dispatch.
        try reader.consumeExpectedByte(._openangle)
        let isKeyed = channel.isTopKeyed

        if isKeyed {
            // Expect `<key>...</key>` first.
            let (tag, isEmpty) = try readOpenTagAfterAngle()
            guard tag == .key else {
                throw XMLPlistError.other("Found non-key inside <dict> at line \(reader.lineNumber)")
            }
            try emitKey(isEmpty: isEmpty, into: &channel)
            // Now expect the value tag.
            guard try scanUpToNextTag() else {
                throw XMLPlistError.other("Value missing for key inside <dict> at line \(reader.lineNumber)")
            }
            try reader.consumeExpectedByte(._openangle)
            try scanValueAtOpenTag(into: &channel)
        } else {
            try scanValueAtOpenTag(into: &channel)
        }
        return true
    }

    mutating func finalizeTopFrame<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        // `advanceTopFrame` returned false because the next non-whitespace/non-comment thing after `<` is `/`. Consume the matching close tag.
        if channel.isTopKeyed {
            try checkForCloseTag(.dict)
            try channel.endKeyedContainer()
        } else {
            try checkForCloseTag(.array)
            try channel.endUnkeyedContainer()
        }
    }

    mutating func finish() throws {
        // The <plist> tag doesn't represent an actual value, so we have to deliberately parse it here.
        if insidePlist {
            guard try !scanUpToNextTag() else {
                throw XMLPlistError.other("Encountered unexpected element at line \(reader.lineNumber) (plist can only include one object)")
            }
            try checkForCloseTag(.plist)
            insidePlist = false
        }

        // In keeping with the legacy implementation, additional garbage following the plist are NOT checked.
    }

    // MARK: - Prologue + `<plist>` handling

    /// Skip the XML prologue: leading whitespace, `<?xml ...?>` processing instructions, `<!DOCTYPE ...>` DTDs, `<!-- ... -->` comments. Positions the cursor at the first real tag's `<`.
    private mutating func skipPrologue() throws {
        while true {
            reader.skipWhitespace()
            guard let (openAngle, next) = reader.peek() else {
                throw XMLPlistError.other("No XML content found")
            }
            guard openAngle == ._openangle else {
                throw XMLPlistError.unexpectedCharacter(openAngle, line: reader.lineNumber)
            }
            switch next {
            case ._question:
                reader.advance(2)
                try reader.skipUntilAndPast("?>")
            case ._exclamation:
                reader.advance(2)
                if reader.matches("--") {
                    reader.advance(2)
                    try reader.skipUntilAndPast("-->")
                } else {
                    try skipDTD()
                }
            default:
                // First real tag. Leave `<` unconsumed for `emitTopLevelValue` to read.
                return
            }
        }
    }

    /// Emit or push a container/leaf, given that `<` + tag name + attributes + `>` (or `/>`) has already been consumed. Shared between `emitTopLevelValue` (root value) and `scanValueAtOpenTag` (nested value).
    private mutating func dispatchOpenTag<Sink: ParseEventSink & ~Copyable>(_ tag: XMLPlistTag, isEmpty: Bool, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        // Called after `<` and the open tag (name + attributes + `>`) have already been consumed. Emit / push per the tag.
        switch tag {
        case .plist:
            throw XMLPlistError.other("Nested <plist> not supported")
        case .array:
            if isEmpty {
                try channel.emitEmptyUnkeyedContainer()
            } else {
                guard channel.stackDepth < Self.maxContainerDepth else {
                    throw XMLPlistError.other("Too many nested arrays or dictionaries")
                }
                try channel.beginUnkeyedContainer(cacheKey: nil, sourceState: ())
            }
        case .dict:
            if isEmpty {
                try channel.emitEmptyKeyedContainer()
            } else {
                guard channel.stackDepth < Self.maxContainerDepth else {
                    throw XMLPlistError.other("Too many nested arrays or dictionaries")
                }
                try channel.beginKeyedContainer(cacheKey: nil, sourceState: ())
            }
        case .key, .string:
            // `<key>` in a value position is historically treated as a plain string
            if isEmpty {
                // Empty string: simpleString marker with zero bytes.
                let empty = reader.bytes.extracting(unchecked: reader.index ..< reader.index)
                try channel.emitScalar(XMLPlistScalar.string(bytes: empty, hasEscapes: false, source: reader.bytes))
            } else {
                let (offset, byteCount, isSimple) = try scanStringBytes()
                try checkForCloseTag(tag)
                let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
                try channel.emitScalar(XMLPlistScalar.string(bytes: slice, hasEscapes: !isSimple, source: reader.bytes))
            }
        case .integer:
            guard !isEmpty else { throw XMLPlistError.unexpectedEmptyTag(.integer, line: reader.lineNumber) }
            let (offset, byteCount) = try scanTypedValueBytes(closing: .integer)
            let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
            try channel.emitScalar(XMLPlistScalar.integer(bytes: slice, source: reader.bytes))
        case .real:
            guard !isEmpty else { throw XMLPlistError.unexpectedEmptyTag(.real, line: reader.lineNumber) }
            let (offset, byteCount) = try scanTypedValueBytes(closing: .real)
            let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
            try channel.emitScalar(XMLPlistScalar.real(bytes: slice, source: reader.bytes))
        case .date:
            guard !isEmpty else { throw XMLPlistError.unexpectedEmptyTag(.date, line: reader.lineNumber) }
            let (offset, byteCount) = try scanTypedValueBytes(closing: .date)
            let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
            try channel.emitScalar(XMLPlistScalar.date(bytes: slice, source: reader.bytes))
        case .data:
            guard !isEmpty else { throw XMLPlistError.unexpectedEmptyTag(.data, line: reader.lineNumber) }
            let (offset, byteCount) = try scanTypedValueBytes(closing: .data)
            let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
            try channel.emitScalar(XMLPlistScalar.data(bytes: slice, source: reader.bytes))
        case .true:
            if !isEmpty {
                try checkForCloseTag(.true)
            }
            try channel.emitScalar(XMLPlistScalar.bool(true))
        case .false:
            if !isEmpty {
                try checkForCloseTag(.false)
            }
            try channel.emitScalar(XMLPlistScalar.bool(false))
        }
    }

    /// Called from `advanceTopFrame` (array case) after we've consumed `<` and peeked that it's not a close tag. Reads the open tag (name + attrs + `>`) and dispatches.
    private mutating func scanValueAtOpenTag<Sink: ParseEventSink & ~Copyable>(into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        let (tag, isEmpty) = try readOpenTagAfterAngle()
        try dispatchOpenTag(tag, isEmpty: isEmpty, into: &channel)
    }

    // MARK: - Key scanning

    private mutating func emitKey<Sink: ParseEventSink & ~Copyable>(isEmpty: Bool, into channel: inout IterativeParsingDriver<Self, Sink>) throws where Sink.Vocabulary == XMLPlistVocabulary {
        if isEmpty {
            let empty = reader.bytes.extracting(unchecked: reader.index ..< reader.index)
            try channel.parkKey(XMLPlistKeyView(bytes: empty, hasEscapes: false, source: reader.bytes))
            return
        }
        let (offset, byteCount, isSimple) = try scanStringBytes()
        try checkForCloseTag(.key)
        let slice = reader.bytes.extracting(unchecked: offset ..< offset &+ byteCount)
        try channel.parkKey(XMLPlistKeyView(bytes: slice, hasEscapes: !isSimple, source: reader.bytes))
    }

    // MARK: - Scanning tag interiors

    /// Consume bytes up to (but not including) the next `<`. Returns (start offset, byte count); caller extracts the slice from the document. Also consumes the matching close tag. Used for `<integer>` / `<real>` / `<date>` / `<data>` where inner content is treated as an opaque byte-range.
    private mutating func scanTypedValueBytes(closing tag: XMLPlistTag) throws -> (offset: Int, byteCount: Int) {
        let start = reader.index
        while let byte = reader.peek(), byte != ._openangle {
            reader.advance()
        }
        let byteCount = reader.index &- start
        try checkForCloseTag(tag)
        return (start, byteCount)
    }

    /// Scan a `<string>` / `<key>` body up to (but not including) the closing `</string>` / `</key>`. Returns (start offset, byte count, isSimple). "isSimple" means no `&` character entities and no `<![CDATA[` sections were encountered; the sink can use the bytes directly as UTF-8.
    ///
    /// Handles CDATA sections by consuming them as part of the byte span (still bounded by the closing `</string>` / `</key>` tag) and flipping isSimple to false.
    private mutating func scanStringBytes() throws -> (offset: Int, byteCount: Int, isSimple: Bool) {
        let start = reader.index
        var isSimple = true
        while let byte = reader.peek() {
            switch byte {
            case ._openangle:
                // Check for CDATA `<![CDATA[`; that's a nested section that's still part of this string. Otherwise it's the closing tag.
                if reader.matches("!", at: reader.index &+ 1) {
                    // CDATA start; consume the whole `<![CDATA[...]]>` section.
                    isSimple = false
                    guard reader.matches(xmlCDATAOpeningMarker) else {
                        throw XMLPlistError.other("Encountered improper CDATA opening at line \(reader.lineNumber)")
                    }
                    reader.advance(xmlCDATAOpeningMarker.utf8CodeUnitCount)
                    try reader.skipUntilAndPast("]]>")
                } else {
                    // Closing tag.
                    return (start, reader.index &- start, isSimple)
                }
            case ._ampersand:
                // Character entity; skip up to and including `;`.
                isSimple = false
                reader.advance()
                while let b = reader.peek(), b != ._semicolon {
                    reader.advance()
                }
                if reader.peek() == nil {
                    throw XMLPlistError.unexpectedEndOfFile()
                }
                reader.advance() // consume `;`
            default:
                reader.advance()
            }
        }
        throw XMLPlistError.unexpectedEndOfFile()
    }

    // MARK: - Tag reading

    /// Read a tag name after we've just consumed `<`. Returns the tag and whether it was a self-closing empty tag (`<foo/>`). Advances past the closing `>`.
    private mutating func readOpenTagAfterAngle() throws -> (XMLPlistTag, isEmpty: Bool) {
        guard let firstChar = reader.peek() else {
            throw XMLPlistError.unexpectedEndOfFile()
        }
        let tag = try recognizeTag(firstChar: firstChar)
        // Advance past attributes / whitespace to the closing `>`. Track whether we saw `/` immediately before.
        var sawSlash = false
        while let b = reader.read() {
            if b == ._closeangle {
                return (tag, sawSlash)
            }
            sawSlash = (b == ._forwardslash)
        }
        throw XMLPlistError.malformedTag(line: reader.lineNumber)
    }

    private mutating func recognizeTag(firstChar: UInt8) throws -> XMLPlistTag {
        // Direct dispatch: try each candidate for the given first byte in-place, no Swift Array allocation.
        switch firstChar {
        case UInt8(ascii: "a"): if let t = tryConsumeTag(.array) { return t }
        case UInt8(ascii: "d"):
            if let t = tryConsumeTag(.dict) { return t }
            if let t = tryConsumeTag(.data) { return t }
            if let t = tryConsumeTag(.date) { return t }
        case UInt8(ascii: "f"): if let t = tryConsumeTag(.false) { return t }
        case UInt8(ascii: "i"): if let t = tryConsumeTag(.integer) { return t }
        case UInt8(ascii: "k"): if let t = tryConsumeTag(.key) { return t }
        case UInt8(ascii: "p"): if let t = tryConsumeTag(.plist) { return t }
        case UInt8(ascii: "r"): if let t = tryConsumeTag(.real) { return t }
        case UInt8(ascii: "s"): if let t = tryConsumeTag(.string) { return t }
        case UInt8(ascii: "t"): if let t = tryConsumeTag(.true) { return t }
        default:
            throw XMLPlistError.other("Encountered unknown tag on line \(reader.lineNumber)")
        }
        throw XMLPlistError.other("Encountered unknown tag on line \(reader.lineNumber)")
    }

    /// Try to consume `tag` at the cursor. Returns the tag on match (advancing past the tag name) or nil on mismatch (leaving the cursor where it was).
    @inline(__always)
    private mutating func tryConsumeTag(_ tag: XMLPlistTag) -> XMLPlistTag? {
        let len = tag.tagLength
        guard reader.matches(tag: tag) else { return nil }
        // Tag names must be delimited either by whitespace or a `>` or `/` character to be valid.
        switch reader.peek(offset: len) {
        case ._closeangle, ._forwardslash, ._space, ._tab, ._newline, ._return:
            reader.advance(len)
            return tag
        default:
            return nil
        }
    }

    /// Consume the matching close tag `</tag>` at the cursor. Advances past `>`.
    private mutating func checkForCloseTag(_ tag: XMLPlistTag) throws {
        try reader.consumeExpectedByte(._openangle, closingTag: tag)
        try reader.consumeExpectedByte(._forwardslash, closingTag: tag)
        guard reader.matches(tag: tag) else {
            throw XMLPlistError.other("Close tag on line \(reader.lineNumber) does not match open tag \(tag.tagName)")
        }
        reader.advance(tag.tagLength)
        // Allow trailing whitespace before `>` (matches reference behavior).
        reader.skipWhitespace()
        try reader.consumeExpectedByte(._closeangle, closingTag: tag)
    }

    /// Skip whitespace, XML processing instructions, and comments until we find the next value's opening `<`. Returns `false` when a close tag (`</`) is reached instead, leaving `<` unconsumed for `checkForCloseTag`. Returns `true` with the cursor positioned AT an opening `<`.
    private mutating func scanUpToNextTag() throws -> Bool {
        while !reader.isAtEnd {
            reader.skipWhitespace()
            guard let angle = reader.peek() else {
                throw XMLPlistError.unexpectedEndOfFile()
            }
            if angle != ._openangle {
                throw XMLPlistError.unexpectedCharacter(angle, line: reader.lineNumber, context: "while looking for open tag")
            }
            // Peek the byte after `<` to distinguish a PI or comment from a real tag.
            guard let (_, after) = reader.peek() else {
                throw XMLPlistError.unexpectedEndOfFile()
            }
            switch after {
            case ._question:
                // Processing instruction; skip `<?...?>`.
                reader.advance(2)
                try reader.skipUntilAndPast("?>")
            case ._exclamation:
                // Comment (or DTD, but DTD inside content is illegal; treat as comment attempt).
                guard reader.matches("<!--") else {
                    guard let ch2 = reader.peek(offset: 2) else {
                        throw XMLPlistError.unexpectedEndOfFile()
                    }
                    let badChar = ch2 == ._minus ? (reader.peek(offset: 3) ?? ch2) : ch2
                    throw XMLPlistError.unexpectedCharacter(badChar, line: reader.lineNumber, context: "in comment")
                }
                reader.advance(4)
                try reader.skipUntilAndPast("-->")
            case ._forwardslash:
                // Close tag for the element whose content we're scanning. Leave `<` unconsumed for `checkForCloseTag`.
                return false
            default:
                // Opening tag. Leave `<` unconsumed; the caller reads the tag name after it.
                return true
            }
        }
        throw XMLPlistError.unexpectedEndOfFile()
    }

    private mutating func skipDTD() throws {
        guard reader.matches("DOCTYPE") else {
            throw XMLPlistError.other("Malformed DTD on line \(reader.lineNumber)")
        }
        reader.advance(7)
        while let b = reader.read() {
            if b == ._openbracket {
                // XML plist parsing has never attempted to parse inline DTDs and has always treated it as invalid syntax.
                throw XMLPlistError.unexpectedCharacter(b, line: reader.lineNumber, context: "while parsing DTD")
            }
            if b == ._closeangle {
                return
            }
        }
        throw XMLPlistError.unexpectedEndOfFile(context: "while parsing DTD")
    }

    private var xmlCDATAOpeningMarker: StaticString { "<![CDATA[" }
}
#endif // FOUNDATION_FRAMEWORK || !(os(macOS) || os(Windows))
