//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
@preconcurrency import Glibc
#endif

internal import _FoundationCShims

internal struct JSON5Scanner {
    let options: Options
    var reader: DocumentReader
    var depth: Int = 0
    var partialMap = JSONPartialMapData()

    internal struct Options {
        var assumesTopLevelDictionary = false
    }

    struct JSONPartialMapData {
        var mapData: [Int] = []
        var prevMapDataSize = 0

        mutating func resizeIfNecessary(with reader: DocumentReader) {
            let currentCount = mapData.count
            if currentCount > 0, currentCount.isMultiple(of: 2048) {
                // Time to predict how big these arrays are going to be based on the current rate of consumption per processed bytes.
                // total objects = (total bytes / current bytes) * current objects
                let totalBytes = reader.bytes.count
                let consumedBytes = reader.byteOffset(at: reader.readIndex)
                let ratio = (Double(totalBytes) / Double(consumedBytes))
                let totalExpectedMapSize = Int( Double(mapData.count) * ratio )
                if prevMapDataSize == 0 || Double(totalExpectedMapSize) / Double(prevMapDataSize) > 1.25 {
                    mapData.reserveCapacity(totalExpectedMapSize)
                    prevMapDataSize = totalExpectedMapSize
                }

                //            print("Ratio is \(ratio). Reserving \(totalExpectedObjects) objects and \(totalExpectedMapSize) scratch space")
            }
        }

        mutating func recordStartCollection(tagType: JSONMap.TypeDescriptor, with reader: DocumentReader) -> Int {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)

            // Reserve space for the next object index and object count.
            let startIdx = mapData.count
            mapData.append(contentsOf: [0, 0])
            return startIdx
        }

        mutating func recordEndCollection(count: Int, atStartOffset startOffset: Int, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(JSONMap.TypeDescriptor.collectionEnd.rawValue)

            let nextValueOffset = mapData.count
            mapData.withUnsafeMutableBufferPointer {
                $0[startOffset] = nextValueOffset
                $0[startOffset &+ 1] = count
            }
        }

        mutating func recordEmptyCollection(tagType: JSONMap.TypeDescriptor, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            let nextValueOffset = mapData.count + 4
            mapData.append(contentsOf: [tagType.mapMarker, nextValueOffset, 0, JSONMap.TypeDescriptor.collectionEnd.mapMarker])
        }

        mutating func record(tagType: JSONMap.TypeDescriptor, count: Int, dataOffset: Int, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(contentsOf: [tagType.mapMarker, count, dataOffset])
        }

        mutating func record(tagType: JSONMap.TypeDescriptor, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)
        }
    }

    init(bytes: BufferView<UInt8>, options: Options) {
        self.options = options
        self.reader = DocumentReader(bytes: bytes)
    }

    mutating func scan() throws -> JSONMap {
        if options.assumesTopLevelDictionary {
            switch try reader.consumeWhitespace(allowingEOF: true) {
            case ._openbrace?:
                // If we've got the open brace anyway, just do a normal object scan.
                try self.scanObject()
            default:
                try self.scanObject(withoutBraces: true)
            }
        } else {
            try self.scanValue()
        }
#if DEBUG
        defer {
            guard self.depth == 0 else {
                preconditionFailure("Expected to end parsing with a depth of 0")
            }
        }
#endif

        // ensure only white space is remaining
        if let char = try reader.consumeWhitespace(allowingEOF: true) {
            throw JSONError.unexpectedCharacter(context: "after top-level value", ascii: char, location: reader.sourceLocation)
        }

        return JSONMap(mapBuffer: partialMap.mapData, dataBuffer: self.reader.bytes)
    }

    // MARK: Generic Value Scanning

    mutating func scanValue() throws {
        let byte = try reader.consumeWhitespace()
        switch byte {
        case ._quote:
            try scanString(withQuote: ._quote)
        case ._singleQuote:
            try scanString(withQuote: ._singleQuote)
        case ._openbrace:
            try scanObject()
        case ._openbracket:
            try scanArray()
        case UInt8(ascii: "f"), UInt8(ascii: "t"):
            try scanBool()
        case UInt8(ascii: "n"):
            try scanNull()
        case UInt8(ascii: "-"), UInt8(ascii: "+"), _asciiNumbers, UInt8(ascii: "N"), UInt8(ascii: "I"), UInt8(ascii: "."):
            try scanNumber()
        case ._space, ._return, ._newline, ._tab:
            preconditionFailure("Expected that all white space is consumed")
        default:
            throw JSONError.unexpectedCharacter(ascii: byte, location: reader.sourceLocation)
        }
    }


    // MARK: - Scan Array -

    mutating func scanArray() throws {
        let firstChar = reader.read()
        precondition(firstChar == ._openbracket)
        guard self.depth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: reader.sourceLocation(atOffset: -1))
        }
        self.depth &+= 1
        defer { depth &-= 1 }

        // parse first value or end immediately
        switch try reader.consumeWhitespace() {
        case ._space, ._return, ._newline, ._tab:
            preconditionFailure("Expected that all white space is consumed")
        case ._closebracket:
            // if the first char after whitespace is a closing bracket, we found an empty array
            reader.moveReaderIndex(forwardBy: 1)
            return partialMap.recordEmptyCollection(tagType: .array, with: reader)
        default:
            break
        }

        var count = 0
        let startOffset = partialMap.recordStartCollection(tagType: .array, with: reader)
        defer {
            partialMap.recordEndCollection(count: count, atStartOffset: startOffset, with: reader)
        }

        ScanValues:
        while true {
            try scanValue()
            count &+= 1

            // consume the whitespace after the value before the comma
            let ascii = try reader.consumeWhitespace()
            switch ascii {
            case ._space, ._return, ._newline, ._tab:
                preconditionFailure("Expected that all white space is consumed")
            case ._closebracket:
                reader.moveReaderIndex(forwardBy: 1)
                break ScanValues
            case ._comma:
                // consume the comma
                reader.moveReaderIndex(forwardBy: 1)
                // consume the whitespace before the next value
                if try reader.consumeWhitespace() == ._closebracket {
                    // the foundation json implementation does support trailing commas
                    reader.moveReaderIndex(forwardBy: 1)
                    break ScanValues
                }
                continue
            default:
                throw JSONError.unexpectedCharacter(context: "in array", ascii: ascii, location: reader.sourceLocation)
            }
        }
    }

    // MARK: - Scan Object -

    mutating func scanObject() throws {
        let firstChar = self.reader.read()
        precondition(firstChar == ._openbrace)
        guard self.depth < 512 else {
            throw JSONError.tooManyNestedArraysOrDictionaries(location: reader.sourceLocation(atOffset: -1))
        }
        try scanObject(withoutBraces: false)
    }

    @inline(never)
    mutating func _scanObjectLoop(withoutBraces: Bool, count: inout Int, done: inout Bool) throws {
        try scanKey()

        let colon = try reader.consumeWhitespace()
        guard colon == ._colon else {
            throw JSONError.unexpectedCharacter(context: "in object", ascii: colon, location: reader.sourceLocation)
        }
        reader.moveReaderIndex(forwardBy: 1)

        try self.scanValue()
        count &+= 2

        let commaOrBrace = try reader.consumeWhitespace(allowingEOF: withoutBraces)
        switch commaOrBrace {
        case ._comma?:
            reader.moveReaderIndex(forwardBy: 1)
            switch try reader.consumeWhitespace(allowingEOF: withoutBraces) {
            case ._closebrace?:
                if withoutBraces {
                    throw JSONError.unexpectedCharacter(ascii: ._closebrace, location: reader.sourceLocation)
                }

                // the foundation json implementation does support trailing commas
                reader.moveReaderIndex(forwardBy: 1)
                done = true
            case .none:
                done = true
            default:
                return
            }
        case ._closebrace?:
            if withoutBraces {
                throw JSONError.unexpectedCharacter(ascii: ._closebrace, location: reader.sourceLocation)
            }
            reader.moveReaderIndex(forwardBy: 1)
            done = true
        case .none:
            // If withoutBraces was false, then reaching EOF here would have thrown.
            precondition(withoutBraces == true)
            done = true

        default:
            throw JSONError.unexpectedCharacter(context: "in object", ascii: commaOrBrace.unsafelyUnwrapped, location: reader.sourceLocation)
        }
    }

    mutating func scanObject(withoutBraces: Bool) throws {
        self.depth &+= 1
        defer { depth &-= 1 }

        // parse first value or end immediately
        switch try reader.consumeWhitespace(allowingEOF: withoutBraces) {
        case ._closebrace?:
            if withoutBraces {
                throw JSONError.unexpectedCharacter(ascii: ._closebrace, location: reader.sourceLocation)
            }

            // if the first char after whitespace is a closing bracket, we found an empty object
            self.reader.moveReaderIndex(forwardBy: 1)
            return partialMap.recordEmptyCollection(tagType: .object, with: reader)
        case .none:
            // If withoutBraces was false, then reaching EOF here would have thrown.
            precondition(withoutBraces == true)
            return partialMap.recordEmptyCollection(tagType: .object, with: reader)
        default:
            break
        }

        var count = 0
        let startOffset = partialMap.recordStartCollection(tagType: .object, with: reader)
        defer {
            partialMap.recordEndCollection(count: count, atStartOffset: startOffset, with: reader)
        }

        var done = false
        while !done {
            try _scanObjectLoop(withoutBraces: withoutBraces, count: &count, done: &done)
        }
    }

    mutating func scanKey() throws {
        guard let firstChar = reader.peek() else {
            throw JSONError.unexpectedEndOfFile
        }

        switch firstChar {
        case ._quote:
            try scanString(withQuote: ._quote)
        case ._singleQuote:
            try scanString(withQuote: ._singleQuote)
        case _hexCharsUpper, _hexCharsLower, ._dollar, ._underscore, ._backslash:
            try scanString(withQuote: nil)
        default:
            // Validate that the initial character is within the rules specified by JSON5.
            guard let (unicodeScalar, _) = try reader.peekU32() else {
                throw JSONError.unexpectedEndOfFile
            }
            guard unicodeScalar.isJSON5UnquotedKeyStartingCharacter else {
                throw JSONError.unexpectedCharacter(context: "at beginning of JSON5 unquoted key", ascii: firstChar, location: reader.sourceLocation)
            }
            try scanString(withQuote: nil)
        }
    }

    mutating func scanString(withQuote quote: UInt8?) throws {
        var isSimple = false
        let start = try reader.skipUTF8StringTillNextUnescapedQuote(isSimple: &isSimple, quote: quote)
        let end = reader.readIndex

        // skipUTF8StringTillNextUnescapedQuote will have either thrown an error, or already peek'd the quote.
        if let quote {
            let shouldBeQuote = reader.read()
            precondition(shouldBeQuote == quote)
        }

        // skip initial quote
        return partialMap.record(tagType: isSimple ? .simpleString : .string, count: reader.distance(from: start, to: end), dataOffset: reader.byteOffset(at: start), with: reader)
    }

    mutating func scanNumber() throws {
        let start = reader.readIndex
        reader.skipNumber()
        let end = reader.readIndex
        return partialMap.record(tagType: .number, count: reader.distance(from: start, to: end), dataOffset: reader.byteOffset(at: start), with: reader)
    }

    mutating func scanBool() throws {
        if try reader.readBool() {
            return partialMap.record(tagType: .true, with: reader)
        } else {
            return partialMap.record(tagType: .false, with: reader)
        }
    }

    mutating func scanNull() throws {
        try reader.readNull()
        return partialMap.record(tagType: .null, with: reader)
    }

}

extension JSON5Scanner {

    struct DocumentReader {
        let bytes: BufferView<UInt8>
        private(set) var readIndex : BufferViewIndex<UInt8>
        private let endIndex : BufferViewIndex<UInt8>

        @inline(__always)
        func checkRemainingBytes(_ count: Int) -> Bool {
            bytes.distance(from: readIndex, to: endIndex) >= count
        }

        @inline(__always)
        func requireRemainingBytes(_ count: Int) throws {
            guard checkRemainingBytes(count) else {
                throw JSONError.unexpectedEndOfFile
            }
        }

        var sourceLocation : JSONError.SourceLocation {
            self.sourceLocation(atOffset: 0)
        }

        func sourceLocation(atOffset offset: Int) -> JSONError.SourceLocation {
            .sourceLocation(at: readIndex.advanced(by: offset), fullSource: bytes)
        }

        @inline(__always)
        var isEOF: Bool {
            readIndex == endIndex
        }

        @inline(__always)
        func byteOffset(at index: BufferViewIndex<UInt8>) -> Int {
            bytes.distance(from: bytes.startIndex, to:  index)
        }

        init(bytes: BufferView<UInt8>) {
            self.bytes = bytes
            self.readIndex = bytes.startIndex
            self.endIndex = bytes.endIndex
        }

        @inline(__always)
        mutating func read() -> UInt8? {
            guard !isEOF else {
                return nil
            }

            defer { bytes.formIndex(after: &readIndex) }

            return bytes[unchecked: readIndex]
        }

        @inline(__always)
        func peek(offset: Int = 0) -> UInt8? {
            precondition(offset >= 0)
            assert(bytes.startIndex <= readIndex)
            let peekIndex = bytes.index(readIndex, offsetBy: offset)
            guard peekIndex < endIndex else {
                return nil
            }

            return bytes[unchecked: peekIndex]
        }

        func peekU32() throws -> (scalar: UnicodeScalar, length: Int)? {
            guard let firstChar = peek() else {
                return nil
            }

            // This might be an escaped character.
            if firstChar == ._backslash {
                guard let char = peek(offset: 1) else {
                    throw JSONError.unexpectedEndOfFile
                }

                switch char {
                case UInt8(ascii: "u"):
                    try requireRemainingBytes(6) // 6 bytes for \, u, and 4 hex digits
                    let remaining = bytes.suffix(from: bytes.index(readIndex, offsetBy: 2)) // Skip \u
                    let (u16, _) = try JSONScanner.parseUnicodeHexSequence(from: remaining, fullSource: bytes, allowNulls: false)
                    guard let scalar = UnicodeScalar(u16) else {
                        throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: sourceLocation, unicodeScalarValue: UInt32(u16))
                    }
                    return (scalar, 6)
                case UInt8(ascii: "x"):
                    try requireRemainingBytes(4) // 4 bytes for \, x, and 2 hex digits
                    let remaining = bytes.suffix(from: bytes.index(readIndex, offsetBy: 2)) // Skip \x
                    let (u8, _) = try JSON5Scanner.parseTwoByteUnicodeHexSequence(from: remaining, fullSource: bytes)
                    return (UnicodeScalar(u8), 4)
                default:
                    throw JSONError.unexpectedCharacter(ascii: char, location: sourceLocation(atOffset: 1))
                }
            }

            let (scalar, length) = bytes[unchecked: readIndex..<endIndex]._decodeScalar()
            guard let scalar else {
                throw JSONError.cannotConvertInputStringDataToUTF8(location: sourceLocation)
            }
            return (scalar, length)
        }

        @inline(__always)
        mutating func moveReaderIndex(forwardBy offset: Int) {
            bytes.formIndex(&readIndex, offsetBy: offset)
        }

        @inline(__always)
        func distance(from start: BufferViewIndex<UInt8>, to end: BufferViewIndex<UInt8>) -> Int {
            bytes.distance(from: start, to: end)
        }

        static var whitespaceBitmap: UInt64 { 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab | 1 << UInt8._verticalTab | 1 << UInt8._formFeed }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            assert(bytes.startIndex <= readIndex)
            var index = readIndex
            while index < endIndex {
                let ascii = bytes[unchecked: index]
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    bytes.formIndex(after: &index)
                    continue
                } else if ascii == ._nbsp {
                    bytes.formIndex(after: &index)
                    continue
                } else if ascii == ._slash {
                    guard try consumePossibleComment(from: &index) else {
                        self.readIndex = index
                        return ascii
                    }
                    continue
                } else {
                    self.readIndex = index
                    return ascii
                }
            }

            throw JSONError.unexpectedEndOfFile
        }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace(allowingEOF: Bool) throws -> UInt8? {
            assert(bytes.startIndex <= readIndex)
            var index = readIndex
            while index < endIndex {
                let ascii = bytes[unchecked: index]
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    bytes.formIndex(after: &index)
                    continue
                } else if ascii == ._nbsp {
                    bytes.formIndex(after: &index)
                    continue
                } else if ascii == ._slash {
                    guard try consumePossibleComment(from: &index) else {
                        self.readIndex = index
                        return ascii
                    }
                    continue
                } else {
                    self.readIndex = index
                    return ascii
                }
            }
            guard allowingEOF else {
                throw JSONError.unexpectedEndOfFile
            }
            return nil
        }

        @inline(__always)
        func consumePossibleComment(from index: inout BufferViewIndex<UInt8>) throws -> Bool {
            // ptr still points to the first /
            let second = bytes.index(after: index)
            guard second < endIndex else {
                return false
            }

            switch bytes[unchecked: second] {
            case ._slash:
                bytes.formIndex(&index, offsetBy: 2)
                consumeSingleLineComment(from: &index)
                return true
            case ._asterisk:
                bytes.formIndex(&index, offsetBy: 2)
                try consumeMultiLineComment(from: &index)
                return true
            default:
                return false
            }
        }

        @inline(__always)
        func consumeSingleLineComment(from index: inout BufferViewIndex<UInt8>) {
            // No need to bother getting fancy about CR-LF. These only get called in the process of skipping whitespace, and a trailing LF will be picked up by that. We also don't track line number information during nominal parsing.
            assert(bytes.startIndex <= index)
            var local = index
            while local < endIndex {
                let ascii = bytes[unchecked: local]
                switch ascii {
                case ._newline, ._return:
                    index = bytes.index(after: local)
                    return
                default:
                    bytes.formIndex(after: &local)
                    continue
                }
            }
            index = endIndex
            // Reaching EOF is fine.
        }

        @inline(__always)
        func consumeMultiLineComment(from index: inout BufferViewIndex<UInt8>) throws {
            assert(bytes.startIndex <= index)
            var nextIndex = bytes.index(after: index)
            while nextIndex < endIndex {
                switch (bytes[unchecked: index], bytes[unchecked: nextIndex]) {
                case (._asterisk, ._slash):
                    bytes.formIndex(&index, offsetBy: 2)
                    return
                case (_, ._asterisk):
                    // Check the next asterisk.
                    bytes.formIndex(&index, offsetBy: 1)
                default:
                    // We don't need to check the second byte again.
                    bytes.formIndex(&index, offsetBy: 2)
                }
                nextIndex = bytes.index(after: index)
            }
            index = endIndex
            throw JSONError.unterminatedBlockComment
        }

        @inline(__always)
        mutating func readExpectedString(_ str: StaticString, typeDescriptor: String) throws {
            let cmp = try bytes[unchecked: readIndex..<endIndex].withUnsafeRawPointer { ptr, count in
                if count < str.utf8CodeUnitCount { throw JSONError.unexpectedEndOfFile }
                return memcmp(ptr, str.utf8Start, str.utf8CodeUnitCount)
            }
            guard cmp == 0 else {
                // Figure out the exact character that is wrong.
                let badOffset = str.withUTF8Buffer {
                    for (i, (a, b)) in zip($0, bytes[readIndex..<endIndex]).enumerated() {
                        if a != b { return i }
                    }
                    return 0 // should be unreachable
                }
                throw JSONError.unexpectedCharacter(context: "in expected \(typeDescriptor) value", ascii: self.peek(offset: badOffset).unsafelyUnwrapped, location: sourceLocation(atOffset: badOffset))
            }

            // If all looks good, advance past the string.
            self.moveReaderIndex(forwardBy: str.utf8CodeUnitCount)
        }

        @inline(__always)
        mutating func readBool() throws -> Bool {
            switch self.read() {
            case UInt8(ascii: "t"):
                try readExpectedString("rue", typeDescriptor: "boolean")
                return true
            case UInt8(ascii: "f"):
                try readExpectedString("alse", typeDescriptor: "boolean")
                return false
            default:
                preconditionFailure("Expected to have `t` or `f` as first character")
            }
        }

        @inline(__always)
        mutating func readNull() throws {
            try readExpectedString("null", typeDescriptor: "null")
        }

        // MARK: - Private Methods -

        // MARK: String

        mutating func skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter(quote: UInt8) throws -> UInt8 {
            while let byte = self.peek() {
                switch byte {
                case quote, ._backslash:
                    return byte
                default:
                    // Any control characters in the 0-31 range are invalid. Any other characters will have at least one bit in a 0xe0 mask.
                    guard _fastPath(byte & 0xe0 != 0) else {
                        return byte
                    }
                    self.moveReaderIndex(forwardBy: 1)
                }
            }
            throw JSONError.unexpectedEndOfFile
        }

        @discardableResult
        mutating func skipUTF8StringTillEndOfUnquotedKey(orEscapeSequence stopOnEscapeSequence: Bool) throws -> UnicodeScalar {
            while let (scalar, len) = try peekU32() {
                if scalar.isJSON5UnquotedKeyCharacter {
                    moveReaderIndex(forwardBy: len)
                } else {
                    return scalar
                }
            }
            throw JSONError.unexpectedEndOfFile
        }

        mutating func skipUTF8StringTillNextUnescapedQuote(isSimple: inout Bool, quote: UInt8?) throws -> BufferViewIndex<UInt8> {
            if let quote {
                // Skip the open quote.
                guard let shouldBeQuote = self.read() else {
                    throw JSONError.unexpectedEndOfFile
                }
                guard shouldBeQuote == quote else {
                    throw JSONError.unexpectedCharacter(ascii: shouldBeQuote, location: sourceLocation)
                }
                let firstNonQuote = readIndex

                // If there aren't any escapes, then this is a simple case and we can exit early.
                if try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter(quote: quote) == quote {
                    isSimple = true
                    return firstNonQuote
                }

                isSimple = false

                while let byte = self.peek() {
                    // Checking for invalid control characters deferred until parse time.
                    switch byte {
                    case quote:
                        return firstNonQuote
                    case ._backslash:
                        try skipEscapeSequence(quote: quote)
                    default:
                        moveReaderIndex(forwardBy: 1)
                        continue
                    }
                }
                throw JSONError.unexpectedEndOfFile
            } else {
                let firstNonQuote = readIndex
                if try skipUTF8StringTillEndOfUnquotedKey(orEscapeSequence: true) == UnicodeScalar(._backslash) {
                    // The presence of a backslash means this isn't a "simple" key. Continue skipping until we reach the end of the key, this time ignoring backslashes.
                    isSimple = false
                    try skipUTF8StringTillEndOfUnquotedKey(orEscapeSequence: false)
                } else {
                    // No backslashes. The string can be decoded directly as UTF8.
                    isSimple = true
                }
                return firstNonQuote
            }
        }

        private mutating func skipEscapeSequence(quote: UInt8) throws {
            let firstChar = self.read()
            precondition(firstChar == ._backslash, "Expected to have a backslash first")

            guard let ascii = self.read() else {
                throw JSONError.unexpectedEndOfFile
            }

            // Invalid escaped characters checking deferred to parse time.
            if ascii == UInt8(ascii: "u") {
                try skipUnicodeHexSequence(quote: quote)
            } else if ascii == UInt8(ascii: "x") {
                try skipTwoByteUnicodeHexSequence(quote: quote)
            }
        }

        private mutating func skipUnicodeHexSequence(quote: UInt8) throws {
            assert(quote & 0x80 == 0)
            // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
            // https://tools.ietf.org/html/rfc8259#section-7
            try requireRemainingBytes(4)

            // We'll validate the actual characters following the '\u' escape during parsing. Just make sure that the string doesn't end prematurely.
            let hs = bytes.loadUnaligned(from: readIndex, as: UInt32.self)
            guard JSONScanner.noByteMatches(quote, in: hs) else {
                throw JSONError.invalidHexDigitSequence(
                    _withUnprotectedUnsafeBytes(of: hs, { String(decoding: $0, as: UTF8.self) }),
                    location: sourceLocation
                )
            }
            self.moveReaderIndex(forwardBy: 4)
        }

        private mutating func skipTwoByteUnicodeHexSequence(quote: UInt8) throws {
            assert(quote & 0x80 == 0)
            try requireRemainingBytes(2)

            // We'll validate the actual characters following the '\x' escape during parsing. Just make sure that the string doesn't end prematurely.
            let hs = bytes.loadUnaligned(from: readIndex, as: UInt16.self)
            guard JSONScanner.noByteMatches(quote, in: UInt32(hs)) else {
                throw JSONError.invalidHexDigitSequence(
                    _withUnprotectedUnsafeBytes(of: hs, { String(decoding: $0, as: UTF8.self) }),
                    location: sourceLocation
                )
            }
            self.moveReaderIndex(forwardBy: 2)
        }

        // MARK: Numbers

        mutating func skipNumber() {
            guard let ascii = read() else {
                preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
            }
            switch ascii {
            case _asciiNumbers, UInt8(ascii: "-"), UInt8(ascii: "+"), UInt8(ascii: "I"), UInt8(ascii: "N"), UInt8(ascii: "."):
                break
            default:
                preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
            }
            while let byte = peek() {
                if _fastPath(_asciiNumbers.contains(byte)) {
                    moveReaderIndex(forwardBy: 1)
                    continue
                }
                switch byte {
                case UInt8(ascii: "."), UInt8(ascii: "+"), UInt8(ascii: "-"):
                    moveReaderIndex(forwardBy: 1)
                case _allLettersLower, _allLettersUpper:
                    // Extra permissive, to quickly allow literals like 'Infinity' and 'NaN', as well as 'e/E' for exponents and 'x/X' for hex numbers. Actual validation will be performed on parse.
                    moveReaderIndex(forwardBy: 1)
                default:
                    return
                }
            }
        }
    }
}

// MARK: - Deferred Parsing Methods -

extension JSON5Scanner {

    // MARK: String

    static func stringValue(
        from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>
    ) throws -> String {
        // Assume easy path first -- no escapes, no characters requiring escapes.
        var index = jsonBytes.startIndex
        let endIndex = jsonBytes.endIndex
        while index < endIndex {
            let byte = jsonBytes[unchecked: index]
            guard byte != ._backslash && _fastPath(byte & 0xe0 != 0) else { break }
            jsonBytes.formIndex(after: &index)
        }

        guard var output = String._tryFromUTF8(jsonBytes[unchecked: jsonBytes.startIndex..<index]) else {
            throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        if _fastPath(index == endIndex) {
            // We went through all the characters! Easy peasy.
            return output
        }

        let remainingBytes = jsonBytes[unchecked: index..<endIndex]
        try _slowpath_stringValue(from: remainingBytes, appendingTo: &output, fullSource: fullSource)
        return output
    }

    static func _slowpath_stringValue(
        from jsonBytes: BufferView<UInt8>, appendingTo output: inout String, fullSource: BufferView<UInt8>
    ) throws {
        // Continue scanning, taking into account escaped sequences and control characters
        var index = jsonBytes.startIndex
        var chunkStart = index
        while index < jsonBytes.endIndex {
            let byte = jsonBytes[unchecked: index]
            switch byte {
            case ._backslash:
                guard let stringChunk = String._tryFromUTF8(jsonBytes[unchecked: chunkStart..<index]) else {
                    throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: chunkStart, fullSource: fullSource))
                }
                output += stringChunk

                // Advance past the backslash
                jsonBytes.formIndex(after: &index)

                index = try parseEscapeSequence(from: jsonBytes.suffix(from: index), into: &output, fullSource: fullSource)
                chunkStart = index

            default:
                guard _fastPath(byte & 0xe0 != 0) else {
                    // All Unicode characters may be placed within the quotation marks, except for the characters that must be escaped: quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).
                    throw JSONError.unescapedControlCharacterInString(ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
                }

                jsonBytes.formIndex(after: &index)
                continue
            }
        }

        guard let stringChunk = String._tryFromUTF8(jsonBytes[unchecked: chunkStart..<index]) else {
            throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: chunkStart, fullSource: fullSource))
        }
        output += stringChunk
    }

    private static func parseEscapeSequence(
        from jsonBytes: BufferView<UInt8>, into string: inout String, fullSource: BufferView<UInt8>
    ) throws -> BufferViewIndex<UInt8> {
        precondition(!jsonBytes.isEmpty, "Scanning should have ensured that all escape sequences have a valid shape")
        let index = jsonBytes.startIndex
        switch jsonBytes[unchecked: index] {
        case UInt8(ascii:"\""): string.append("\"")
        case UInt8(ascii:"'"): string.append("'")
        case UInt8(ascii:"\\"): string.append("\\")
        case UInt8(ascii:"/"): string.append("/")
        case UInt8(ascii:"b"): string.append("\u{08}") // \b
        case UInt8(ascii:"f"): string.append("\u{0C}") // \f
        case UInt8(ascii:"n"): string.append("\u{0A}") // \n
        case UInt8(ascii:"r"): string.append("\u{0D}") // \r
        case UInt8(ascii:"t"): string.append("\u{09}") // \t
        case ._newline: string.append("\n")
        case ._return:
            if jsonBytes.count > 1 && jsonBytes[uncheckedOffset: 1] == ._newline {
                string.append("\r\n")
                return jsonBytes.index(index, offsetBy: 2)
            } else {
                string.append("\r")
            }
        case UInt8(ascii:"u"):
            return try JSONScanner.parseUnicodeSequence(from: jsonBytes.dropFirst(), into: &string, fullSource: fullSource, allowNulls: false)
        case UInt8(ascii:"x"):
            let (escapedByte, indexAfter) = try parseTwoByteUnicodeHexSequence(from: jsonBytes.dropFirst(), fullSource: fullSource)
            string.unicodeScalars.append(UnicodeScalar(escapedByte))
            return indexAfter
        case let ascii: // default
            throw JSONError.unexpectedEscapedCharacter(ascii: ascii, location: .sourceLocation(at: index, fullSource: fullSource))
        }
        return jsonBytes.index(after: index)
    }

    private static func parseTwoByteUnicodeHexSequence(
        from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>
    ) throws -> (scalar: UInt8, nextIndex: BufferViewIndex<UInt8>) {
        let digitBytes = jsonBytes.prefix(2)
        precondition(digitBytes.count == 2, "Scanning should have ensured that all escape sequences are valid shape")

        guard let result: UInt8 = _parseHexIntegerDigits(digitBytes, isNegative: false)
        else {
            let hexString = String(decoding: digitBytes, as: Unicode.UTF8.self)
            throw JSONError.invalidHexDigitSequence(hexString, location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        guard result != 0 else {
            throw JSONError.invalidEscapedNullValue(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        assert(digitBytes.endIndex <= jsonBytes.endIndex)
        return (result, digitBytes.endIndex)
    }

    // MARK: Numbers

    static func validateLeadingZero(
        in jsonBytes: BufferView<UInt8>, zero: BufferViewIndex<UInt8>, fullSource: BufferView<UInt8>
    ) throws -> (firstDigitIndex: BufferViewIndex<UInt8>, isHex: Bool) {
        // Leading zeros are very restricted.
        guard !jsonBytes.isEmpty else {
            // Yep, this is valid.
            return (firstDigitIndex: zero, isHex: false)
        }
        switch jsonBytes[uncheckedOffset: 0] {
        case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
            // We need to parse the fractional part.
            return (firstDigitIndex: zero, isHex: false)
        case UInt8(ascii: "x"), UInt8(ascii: "X"):
            // We have to further validate that there is another digit following this one.
            let firstHexDigitIndex = jsonBytes.index(after: jsonBytes.startIndex)
            guard firstHexDigitIndex <= jsonBytes.endIndex else {
                throw JSONError.unexpectedCharacter(context: "in number", ascii: jsonBytes[offset: 0], location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
            let maybeHex = jsonBytes[unchecked: firstHexDigitIndex]
            guard maybeHex.isValidHexDigit else {
                throw JSONError.unexpectedCharacter(context: "in number", ascii: maybeHex, location: .sourceLocation(at: firstHexDigitIndex, fullSource: fullSource))
            }
            return (firstDigitIndex: firstHexDigitIndex, isHex: true)
        case _asciiNumbers:
            throw JSONError.numberWithLeadingZero(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        case let byte: // default
            throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
    }

    static func validateInfinity(from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>) throws {
        try jsonBytes.withUnsafeRawPointer { ptr, count in
            guard count >= _json5Infinity.utf8CodeUnitCount else {
                throw JSONError.invalidSpecialValue(expected: "\(_json5Infinity)", location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
            guard strncmp(ptr, _json5Infinity.utf8Start, _json5Infinity.utf8CodeUnitCount) == 0 else {
                throw JSONError.invalidSpecialValue(expected: "\(_json5Infinity)", location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
        }
    }

    static func validateNaN(from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>) throws {
        try jsonBytes.withUnsafeRawPointer { ptr, count in
            guard count >= _json5NaN.utf8CodeUnitCount else {
                throw JSONError.invalidSpecialValue(expected: "\(_json5NaN)", location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
            guard strncmp(ptr, _json5NaN.utf8Start, _json5NaN.utf8CodeUnitCount) == 0 else {
                throw JSONError.invalidSpecialValue(expected: "\(_json5NaN)", location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
        }
    }

    static func validateLeadingDecimal(
      from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>
    ) throws {
        // Leading decimals MUST be followed by a number, unlike trailing decimals.
        guard !jsonBytes.isEmpty else {
            throw JSONError.unexpectedCharacter(ascii: UInt8(ascii: "."), location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        let nextByte = jsonBytes[unchecked: jsonBytes.startIndex]
        guard case _asciiNumbers = nextByte else {
            throw JSONError.unexpectedCharacter(context: "after '.' in number", ascii: nextByte, location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
    }

    // Returns the pointer at which the number's digits begin. If there are no digits, the function throws.
    static func prevalidateJSONNumber(
        from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>
    ) throws -> (firstDigitIndex: BufferViewIndex<UInt8>, isHex: Bool, isSpecialDoubleValue: Bool) {
        // Just make sure we (A) don't have a leading zero, and (B) We have at least one digit.
        guard !jsonBytes.isEmpty else {
            preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
        }
        var isHex = false
        var isSpecialValue = false
        let firstDigitIndex: BufferViewIndex<UInt8>
        switch jsonBytes[uncheckedOffset: 0] {
        case UInt8(ascii: "0"):
            (firstDigitIndex, isHex) = try validateLeadingZero(in: jsonBytes.dropFirst(), zero: jsonBytes.startIndex, fullSource: fullSource)
        case UInt8(ascii: "1") ... UInt8(ascii: "9"):
          firstDigitIndex = jsonBytes.startIndex
        case UInt8(ascii: "-"), UInt8(ascii: "+"):
            guard jsonBytes.count > 1 else {
                throw JSONError.unexpectedCharacter(context: "at end of number", ascii: jsonBytes[offset: 0], location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
            let second = jsonBytes.index(after: jsonBytes.startIndex)
            switch jsonBytes[unchecked: second] {
            case UInt8(ascii: "0"):
                (firstDigitIndex, isHex) = try validateLeadingZero(in: jsonBytes.dropFirst(2), zero: second, fullSource: fullSource)
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                // Good, we need at least one digit following the '-'
                firstDigitIndex = second
            case UInt8(ascii: "I"):
                try validateInfinity(from: jsonBytes.dropFirst(1), fullSource: fullSource)
                isSpecialValue = true
                firstDigitIndex = second
            case UInt8(ascii: "N"):
                try validateNaN(from: jsonBytes.dropFirst(1), fullSource: fullSource)
                isSpecialValue = true
                firstDigitIndex = second
            case UInt8(ascii: "."):
                try validateLeadingDecimal(from: jsonBytes.dropFirst(2), fullSource: fullSource)
                // A leading decimal point is part of the number to be parsed
                firstDigitIndex = second
            case let byte: // default
                // Any other character is invalid.
                throw JSONError.unexpectedCharacter(context: "after '\(String(UnicodeScalar(jsonBytes[offset: 0])))' in number", ascii: byte, location: .sourceLocation(at: second, fullSource: fullSource))
            }
        case UInt8(ascii: "I"):
            try validateInfinity(from: jsonBytes, fullSource: fullSource)
            isSpecialValue = true
            firstDigitIndex = jsonBytes.startIndex
        case UInt8(ascii: "N"):
            try validateNaN(from: jsonBytes, fullSource: fullSource)
            isSpecialValue = true
            firstDigitIndex = jsonBytes.startIndex
        case UInt8(ascii: "."):
            try validateLeadingDecimal(from: jsonBytes.dropFirst(1), fullSource: fullSource)
            // A leading decimal point is part of the number to be parsed
            firstDigitIndex = jsonBytes.startIndex
        default:
            preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
        }

        if (!isHex) {
            // Explicitly exclude a trailing 'e'. JSON5 and strtod both disallow it, but Decimal unfortunately accepts it so we need to prevent it in advance.
            let lastIndex = jsonBytes.index(before: jsonBytes.endIndex)
            let lastByte = jsonBytes[unchecked: lastIndex]
            switch lastByte {
            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                throw JSONError.unexpectedCharacter(context: "at end of number", ascii: lastByte, location: .sourceLocation(at: lastIndex, fullSource: fullSource))
            default:
                break
            }
        }

        return (firstDigitIndex, isHex, isSpecialValue)
    }

    // This function is intended to be called after prevalidateJSONNumber() (which provides the digitsBeginPtr) and after parsing fails. It will provide more useful information about the invalid input.
    static func validateNumber(
      from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>
    ) -> JSONError {
        enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        var index = jsonBytes.startIndex
        let endIndex = jsonBytes.endIndex

        // Any checks performed during pre-validation can be skipped. Proceed to the beginning of the actual number contents.
        let first = jsonBytes[index]
        if first == UInt8(ascii: "+") || first == UInt8(ascii: "-") {
            jsonBytes.formIndex(after: &index)
        }

        let cmp = jsonBytes[index..<endIndex].prefix(2).withUnsafePointer({ _stringshims_strncasecmp_clocale($0, "0x", $1) })
        if cmp == 0 {
            jsonBytes.formIndex(&index, offsetBy: 2)

            while index < endIndex {
                if jsonBytes[index].isValidHexDigit {
                    jsonBytes.formIndex(after: &index)
                } else {
                    return JSONError.unexpectedCharacter(context: "in hex number", ascii: jsonBytes[index], location: .sourceLocation(at: index, fullSource: fullSource))
                }
            }
            preconditionFailure("Invalid number expected in \(#function). Input code unit buffer contained valid input.")
        }

        //FIXME: any reason not to add a fast-path as in JSONScanner's version?

        var pastControlChar: ControlCharacter = .operand
        var digitsSinceControlChar = 0

        // parse everything else
        while index < endIndex {
            let byte = jsonBytes[index]
            switch byte {
            case _asciiNumbers:
                digitsSinceControlChar += 1
            case UInt8(ascii: "."):
                guard pastControlChar == .operand else {
                    return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
                }
                pastControlChar = .decimalPoint
                digitsSinceControlChar = 0

            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                guard (pastControlChar == .operand && digitsSinceControlChar > 0) || pastControlChar == .decimalPoint
                else {
                    return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
                }
                pastControlChar = .exp
                digitsSinceControlChar = 0

            case UInt8(ascii: "+"), UInt8(ascii: "-"):
                guard digitsSinceControlChar == 0, pastControlChar == .exp else {
                    return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
                }
                pastControlChar = .expOperator
                digitsSinceControlChar = 0

            default:
                return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
            }
            jsonBytes.formIndex(after: &index)
        }

        if digitsSinceControlChar > 0 {
            preconditionFailure("Invalid number expected in \(#function). Input code unit buffer contained valid input.")
        } else { // prevalidateJSONNumber() already checks for trailing `e`/`E` characters.
            preconditionFailure("Found trailing non-digit. Number character buffer was not validated with prevalidateJSONNumber()")
        }
    }
}

internal func _parseJSON5Integer<Result: FixedWidthInteger>(
    _ codeUnits: BufferView<UInt8>, isHex: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _plus = 43 as UInt8, _minus = 45 as UInt8

    var isNegative = false
    var digitsToParse = codeUnits
    switch codeUnits[uncheckedOffset: 0] {
    case _minus:
      isNegative = true
      fallthrough
    case _plus:
      digitsToParse = digitsToParse.dropFirst(1)
    default:
      break
    }

    // Trust the caller regarding whether this is valid hex data.
    if isHex {
        digitsToParse = digitsToParse.dropFirst(2)
        return _parseHexIntegerDigits(digitsToParse, isNegative: isNegative)
    } else {
        return _parseIntegerDigits(digitsToParse, isNegative: isNegative)
    }
}

extension FixedWidthInteger {
    init?(prevalidatedJSON5Buffer buffer: BufferView<UInt8>, isHex: Bool) {
        guard let val : Self = _parseJSON5Integer(buffer, isHex: isHex) else {
            return nil
        }
        self = val
    }
}

internal extension UInt8 {
    static var _verticalTab: UInt8 { UInt8(0x0b) }
    static var _formFeed: UInt8 { UInt8(0x0c) }
    static var _nbsp: UInt8 { UInt8(0xa0) }
    static var _asterisk: UInt8 { UInt8(ascii: "*") }
    static var _slash: UInt8 { UInt8(ascii: "/") }
    static var _singleQuote: UInt8 { UInt8(ascii: "'") }
    static var _dollar: UInt8 { UInt8(ascii: "$") }
    static var _underscore: UInt8 { UInt8(ascii: "_") }
    static var _dot: UInt8 { UInt8(ascii: ".") }
}

var _json5Infinity: StaticString { "Infinity" }
var _json5NaN: StaticString { "NaN" }

extension UnicodeScalar {

    @inline(__always)
    var isJSON5UnquotedKeyStartingCharacter : Bool {
        switch self.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .letterNumber:
            return true
        default:
            return false
        }
    }

    @inline(__always)
    var isJSON5UnquotedKeyCharacter : Bool {
        switch self.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .letterNumber:
            return true
        case .nonspacingMark, .spacingMark:
            return true
        case .decimalNumber:
            return true
        case .connectorPunctuation:
            return true
        default:
            switch self {
            case UnicodeScalar(._underscore), UnicodeScalar(._dollar), UnicodeScalar(._backslash):
                return true
            case UnicodeScalar(0x200c): // ZWNJ
                return true
            case UnicodeScalar(0x200d): // ZWJ
                return true
            default:
                return false
            }
        }
    }
}
