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
import Glibc
#endif


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
                let consumedBytes = reader.byteOffset(at: reader.readPtr)
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

    init(bytes: UnsafeBufferPointer<UInt8>, options: Options) {
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

        // parse first value or end immediatly
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

        // parse first value or end immediatly
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
        let quoteStart = reader.readPtr
        var isSimple = false
        try reader.skipUTF8StringTillNextUnescapedQuote(isSimple: &isSimple, quote: quote)
        let stringStart = quote != nil ? quoteStart + 1 : quoteStart
        let end = reader.readPtr

        // skipUTF8StringTillNextUnescapedQuote will have either thrown an error, or already peek'd the quote.
        if let quote {
            let shouldBeQuote = reader.read()
            precondition(shouldBeQuote == quote)
        }

        // skip initial quote
        return partialMap.record(tagType: isSimple ? .simpleString : .string, count: end - stringStart, dataOffset: reader.byteOffset(at: stringStart), with: reader)
    }

    mutating func scanNumber() throws {
        let start = reader.readPtr
        reader.skipNumber()
        let end = reader.readPtr
        return partialMap.record(tagType: .number, count: end - start, dataOffset: reader.byteOffset(at: start), with: reader)
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
        let bytes: UnsafeBufferPointer<UInt8>
        private(set) var readPtr : UnsafePointer<UInt8>
        private let endPtr : UnsafePointer<UInt8>

        @inline(__always)
        func checkRemainingBytes(_ count: Int) -> Bool {
            return endPtr - readPtr >= count
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
            .sourceLocation(at: readPtr + offset, docStart: bytes.baseAddress.unsafelyUnwrapped)
        }

        @inline(__always)
        var isEOF: Bool {
            readPtr == endPtr
        }

        @inline(__always)
        func byteOffset(at ptr: UnsafePointer<UInt8>) -> Int {
            ptr - bytes.baseAddress.unsafelyUnwrapped
        }

        init(bytes: UnsafeBufferPointer<UInt8>) {
            self.bytes = bytes
            self.readPtr = bytes.baseAddress.unsafelyUnwrapped
            self.endPtr = self.readPtr + bytes.count
        }

        @inline(__always)
        mutating func read() -> UInt8? {
            guard !isEOF else {
                return nil
            }

            defer { self.readPtr += 1 }

            return readPtr.pointee
        }

        @inline(__always)
        func peek(offset: Int = 0) -> UInt8? {
            precondition(offset >= 0)
            guard checkRemainingBytes(offset + 1) else {
                return nil
            }

            return (self.readPtr + offset).pointee
        }

        // These UTF-8 decoding functions are cribbed and specialized from the stdlib.

        @inline(__always)
        internal func _utf8ScalarLength(_ x: UInt8) -> Int? {
            guard !UTF8.isContinuation(x) else { return nil }
            if UTF8.isASCII(x) { return 1 }
            return (~x).leadingZeroBitCount
        }

        @inline(__always)
        internal func _continuationPayload(_ x: UInt8) -> UInt32 {
            return UInt32(x & 0x3F)
        }

        @inline(__always)
        internal func _decodeUTF8(_ x: UInt8) -> Unicode.Scalar? {
            guard UTF8.isASCII(x) else { return nil }
            return Unicode.Scalar(x)
        }

        @inline(__always)
        internal func _decodeUTF8(_ x: UInt8, _ y: UInt8) -> Unicode.Scalar? {
            assert(_utf8ScalarLength(x) == 2)
            guard UTF8.isContinuation(y) else { return nil }
            let x = UInt32(x)
            let value = ((x & 0b0001_1111) &<< 6) | _continuationPayload(y)
            return Unicode.Scalar(value).unsafelyUnwrapped
        }

        @inline(__always)
        internal func _decodeUTF8(
          _ x: UInt8, _ y: UInt8, _ z: UInt8
        ) -> Unicode.Scalar? {
            assert(_utf8ScalarLength(x) == 3)
            guard UTF8.isContinuation(y), UTF8.isContinuation(z) else { return nil }
            let x = UInt32(x)
            let value = ((x & 0b0000_1111) &<< 12)
            | (_continuationPayload(y) &<< 6)
            | _continuationPayload(z)
            return Unicode.Scalar(value).unsafelyUnwrapped
        }

        @inline(__always)
        internal func _decodeUTF8(
          _ x: UInt8, _ y: UInt8, _ z: UInt8, _ w: UInt8
        ) -> Unicode.Scalar? {
            assert(_utf8ScalarLength(x) == 4)
            guard UTF8.isContinuation(y), UTF8.isContinuation(z), UTF8.isContinuation(w) else { return nil }
            let x = UInt32(x)
            let value = ((x & 0b0000_1111) &<< 18)
            | (_continuationPayload(y) &<< 12)
            | (_continuationPayload(z) &<< 6)
            | _continuationPayload(w)
            return Unicode.Scalar(value).unsafelyUnwrapped
        }

        internal func _decodeScalar(
          _ utf8: UnsafeBufferPointer<UInt8>, startingAt i: Int
        ) -> (Unicode.Scalar?, scalarLength: Int) {
            let cu0 = utf8[i]
            guard let len = _utf8ScalarLength(cu0), checkRemainingBytes(len) else { return (nil, 0) }
            switch len {
            case 1: return (_decodeUTF8(cu0), len)
            case 2: return (_decodeUTF8(cu0, utf8[i &+ 1]), len)
            case 3: return (_decodeUTF8(cu0, utf8[i &+ 1], utf8[i &+ 2]), len)
            case 4:
                return (_decodeUTF8(
                    cu0,
                    utf8[i &+ 1],
                    utf8[i &+ 2],
                    utf8[i &+ 3]),
                        len)
            default: fatalError()
            }
        }

        func peekU32() throws -> (UnicodeScalar, Int)? {
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
                    var ptr = readPtr + 2 // Skip \u
                    let u16 = try JSONScanner.parseUnicodeHexSequence(cursor: &ptr, end: endPtr, docStart: bytes.baseAddress.unsafelyUnwrapped, allowNulls: false)
                    guard let scalar = UnicodeScalar(u16) else {
                        throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: sourceLocation, unicodeScalarValue: UInt32(u16))
                    }
                    return (scalar, 6)
                case UInt8(ascii: "x"):
                    try requireRemainingBytes(4) // 4 byets for \, x, and 2 hex digits
                    var ptr = readPtr + 2 // Skip \x
                    let u8 = try JSON5Scanner.parseTwoByteUnicodeHexSequence(cursor: &ptr, end: endPtr, docStart: bytes.baseAddress.unsafelyUnwrapped)
                    return (UnicodeScalar(u8), 4)
                default:
                    throw JSONError.unexpectedCharacter(ascii: char, location: sourceLocation(atOffset: 1))
                }
            }

            let (scalar, length) = _decodeScalar(self.bytes, startingAt: readPtr - self.bytes.baseAddress.unsafelyUnwrapped)
            guard let scalar else {
                throw JSONError.cannotConvertInputStringDataToUTF8(location: sourceLocation)
            }
            return (scalar, length)
        }

        @inline(__always)
        mutating func moveReaderIndex(forwardBy offset: Int) {
            self.readPtr += offset
        }

        static let whitespaceBitmap: UInt64 = 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab | 1 << UInt8._verticalTab | 1 << UInt8._formFeed

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            var ptr = self.readPtr
            while ptr < endPtr {
                let ascii = ptr.pointee
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    ptr += 1
                    continue
                } else if ascii == ._nbsp {
                    ptr += 1
                    continue
                } else if ascii == ._slash {
                    guard try consumePossibleComment(from: &ptr) else {
                        self.readPtr = ptr
                        return ascii
                    }
                    continue
                } else {
                    self.readPtr = ptr
                    return ascii
                }
            }

            throw JSONError.unexpectedEndOfFile
        }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace(allowingEOF: Bool) throws -> UInt8? {
            var ptr = self.readPtr
            while ptr < endPtr {
                let ascii = ptr.pointee
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    ptr += 1
                    continue
                } else if ascii == ._nbsp {
                    ptr += 1
                    continue
                } else if ascii == ._slash {
                    guard try consumePossibleComment(from: &ptr) else {
                        self.readPtr = ptr
                        return ascii
                    }
                    continue
                } else {
                    self.readPtr = ptr
                    return ascii
                }
            }
            guard allowingEOF else {
                throw JSONError.unexpectedEndOfFile
            }
            return nil
        }

        @inline(__always)
        func consumePossibleComment(from ptr: inout UnsafePointer<UInt8>) throws -> Bool {
            // ptr still points to the first /
            guard ptr + 1 < endPtr else {
                return false
            }

            switch (ptr + 1).pointee {
            case ._slash:
                ptr += 2
                consumeSingleLineComment(from: &ptr)
                return true
            case ._asterisk:
                ptr += 2
                try consumeMultiLineComment(from: &ptr)
                return true
            default:
                return false
            }
        }

        @inline(__always)
        func consumeSingleLineComment(from ptr: inout UnsafePointer<UInt8>) {
            // No need to bother getting fancy about CR-LF. These only get called in the process of skipping whitespace, and a trailing LF will be picked up by that. We also don't track line number information during nominal parsing.
            var localPtr = ptr
            while localPtr < endPtr {
                let ascii = localPtr.pointee
                switch ascii {
                case ._newline, ._return:
                    ptr = localPtr + 1
                    return
                default:
                    localPtr += 1
                    continue
                }
            }
            ptr = endPtr
            // Reaching EOF is fine.
        }

        @inline(__always)
        func consumeMultiLineComment(from ptr: inout UnsafePointer<UInt8>) throws {
            var localPtr = ptr
            while (localPtr+1) < endPtr {
                switch (localPtr.pointee, (localPtr+1).pointee) {
                case (._asterisk, ._slash):
                    ptr = localPtr + 2
                    return
                case (_, ._asterisk):
                    // Check the next asterisk.
                    localPtr += 1
                    continue
                default:
                    // We don't need to check the second byte again.
                    localPtr += 2
                    continue
                }
            }
            ptr = endPtr
            throw JSONError.unterminatedBlockComment
        }

        @inline(__always)
        mutating func readExpectedString(_ str: StaticString, typeDescriptor: String) throws {
            try requireRemainingBytes(str.utf8CodeUnitCount)
            guard memcmp(readPtr, str.utf8Start, str.utf8CodeUnitCount) == 0 else {
                // Figure out the exact character that is wrong.
                var badOffset = 0
                for i in 0 ..< str.utf8CodeUnitCount {
                    if (readPtr + i).pointee != (str.utf8Start + i).pointee {
                        badOffset = i
                        break
                    }
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

        mutating func skipUTF8StringTillNextUnescapedQuote(isSimple: inout Bool, quote: UInt8?) throws {
            if let quote {
                // Skip the open quote.
                guard let shouldBeQuote = self.read() else {
                    throw JSONError.unexpectedEndOfFile
                }
                guard shouldBeQuote == quote else {
                    throw JSONError.unexpectedCharacter(ascii: shouldBeQuote, location: sourceLocation)
                }

                // If there aren't any escapes, then this is a simple case and we can exit early.
                if try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter(quote: quote) == quote {
                    isSimple = true
                    return
                }

                isSimple = false

                while let byte = self.peek() {
                    // Checking for invalid control characters deferred until parse time.
                    switch byte {
                    case quote:
                        return
                    case ._backslash:
                        try skipEscapeSequence(quote: quote)
                    default:
                        moveReaderIndex(forwardBy: 1)
                        continue
                    }
                }
                throw JSONError.unexpectedEndOfFile
            } else {
                if try skipUTF8StringTillEndOfUnquotedKey(orEscapeSequence: true) == UnicodeScalar(._backslash) {
                    // The presence of a backslash means this isn't a "simple" key. Continue skipping until we reach the end of the key, this time ignoring backslashes.
                    isSimple = false
                    try skipUTF8StringTillEndOfUnquotedKey(orEscapeSequence: false)
                } else {
                    // No backslashes. The string can be decoded directly as UTF8.
                    isSimple = true
                }
            }
        }

        private mutating func skipEscapeSequence(quote: UInt8) throws {
            let firstChar = self.read()
            precondition(firstChar == ._backslash, "Expected to have an backslash first")

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
            // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
            // https://tools.ietf.org/html/rfc8259#section-7
            try requireRemainingBytes(4)

            // We'll validate the actual characters following the '\u' escape during parsing. Just make sure that the string doesn't end prematurely.
            guard readPtr.pointee != quote,
                  (readPtr+1).pointee != quote,
                  (readPtr+2).pointee != quote,
                  (readPtr+3).pointee != quote
            else {
                let hexString = String(decoding: UnsafeBufferPointer(start: readPtr, count: 4), as: UTF8.self)
                throw JSONError.invalidHexDigitSequence(hexString, location: sourceLocation)
            }
            self.moveReaderIndex(forwardBy: 4)
        }

        private mutating func skipTwoByteUnicodeHexSequence(quote: UInt8) throws {
            try requireRemainingBytes(2)

            // We'll validate the actual characters following the '\u' escape during parsing. Just make sure that the string doesn't end prematurely.
            guard readPtr.pointee != quote,
                  (readPtr+1).pointee != quote
            else {
                let hexString = String(decoding: UnsafeBufferPointer(start: readPtr, count: 2), as: UTF8.self)
                throw JSONError.invalidHexDigitSequence(hexString, location: sourceLocation)
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

    static func stringValue(from jsonBytes: UnsafeBufferPointer<UInt8>, docStart: UnsafePointer<UInt8>) throws -> String {
        let stringStartPtr = jsonBytes.baseAddress.unsafelyUnwrapped
        let stringEndPtr = stringStartPtr + jsonBytes.count

        // Assume easy path first -- no escapes, no characters requiring escapes.
        var cursor = stringStartPtr
        while cursor < stringEndPtr {
            let byte = cursor.pointee
            if byte != ._backslash && _fastPath(byte & 0xe0 != 0) {
                cursor += 1
            } else {
                break
            }
        }
        if cursor == stringEndPtr {
            // We went through all the characters! Easy peasy.
            guard let result = String._tryFromUTF8(jsonBytes) else {
                throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: stringStartPtr, docStart: docStart))
            }
            return result
        }
        return try _slowpath_stringValue(from: cursor, stringStartPtr: stringStartPtr, stringEndPtr: stringEndPtr, docStart: docStart)
    }

    static func _slowpath_stringValue(from prevCursor: UnsafePointer<UInt8>, stringStartPtr: UnsafePointer<UInt8>, stringEndPtr: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) throws -> String {
        var cursor = prevCursor
        var chunkStart = cursor
        guard var output = String._tryFromUTF8(UnsafeBufferPointer(start: stringStartPtr, count: cursor - stringStartPtr)) else {
            throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: chunkStart, docStart: docStart))
        }

        // A reasonable guess as to the resulting capacity of the string is 1/4 the length of the remaining buffer. With this scheme, input full of 4 byte UTF-8 sequences won't waste a bunch of extra capacity and predominantly 1 byte UTF-8 sequences will only need to resize the buffer 1x or 2x.
        output.reserveCapacity(output.underestimatedCount + (stringEndPtr - cursor) / 4)

        while cursor < stringEndPtr {
            let byte = cursor.pointee
            switch byte {
            case ._backslash:
                guard let stringChunk = String._tryFromUTF8(UnsafeBufferPointer(start: chunkStart, count: cursor - chunkStart)) else {
                    throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: chunkStart, docStart: docStart))
                }
                output += stringChunk

                // Advance past the backslash
                cursor += 1

                try parseEscapeSequence(into: &output, cursor: &cursor, end: stringEndPtr, docStart: docStart)
                chunkStart = cursor

            default:
                guard _fastPath(byte & 0xe0 != 0) else {
                    // All Unicode characters may be placed within the quotation marks, except for the characters that must be escaped: quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).
                    throw JSONError.unescapedControlCharacterInString(ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
                }

                cursor += 1
                continue
            }
        }

        guard let stringChunk = String._tryFromUTF8(UnsafeBufferPointer(start: chunkStart, count: cursor - chunkStart)) else {
            throw JSONError.cannotConvertInputStringDataToUTF8(location: .sourceLocation(at: chunkStart, docStart: docStart))
        }
        output += stringChunk

        return output
    }

    private static func parseEscapeSequence(into string: inout String, cursor: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
        precondition(end > cursor, "Scanning should have ensured that all escape sequences are valid shape")

        let ascii = cursor.pointee
        cursor += 1
        switch ascii {
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
            if cursor < end, cursor.pointee == ._newline {
                cursor += 1
                string.append("\r\n")
            } else {
                string.append("\r")
            }
        case UInt8(ascii:"u"):
            try JSONScanner.parseUnicodeSequence(into: &string, cursor: &cursor, end: end, docStart: docStart, allowNulls: false)
        case UInt8(ascii:"x"):
            let scalar = UnicodeScalar(try parseTwoByteUnicodeHexSequence(cursor: &cursor, end: end, docStart: docStart))
            string.unicodeScalars.append(scalar)
        default:
            throw JSONError.unexpectedEscapedCharacter(ascii: ascii, location: .sourceLocation(at: cursor, docStart: docStart))
        }
    }

    private static func parseTwoByteUnicodeHexSequence(cursor: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) throws -> UInt8 {
        precondition(end - cursor >= 2, "Scanning should have ensured that all escape sequences are valid shape")

        guard let first = cursor.pointee.hexDigitValue,
              let second = (cursor+1).pointee.hexDigitValue
        else {
            let hexString = String(decoding: UnsafeBufferPointer(start: cursor, count: 2), as: Unicode.UTF8.self)
            throw JSONError.invalidHexDigitSequence(hexString, location: .sourceLocation(at: cursor, docStart: docStart))
        }
        let result = UInt8(first) << 4 | UInt8(second)
        guard result != 0 else {
            throw JSONError.invalidEscapedNullValue(location: .sourceLocation(at: cursor, docStart: docStart))
        }
        cursor += 2
        return result
    }

    // MARK: Numbers

    static func validateLeadingZero(in jsonBytes: UnsafeBufferPointer<UInt8>, following cursor: inout UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>, isHex: inout Bool) throws {
        let endPtr = jsonBytes.baseAddress.unsafelyUnwrapped + jsonBytes.count

        // Leading zeros are very restricted.
        let next = cursor+1
        if next == endPtr {
            // Yep, this is valid.
            return
        }
        switch next.pointee {
        case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
            // We need to parse the fractional part.
            break
        case UInt8(ascii: "x"), UInt8(ascii: "X"):
            // We have to further validate that there is another digit following this one.
            let firstHexDigitPtr = cursor+2
            guard firstHexDigitPtr <= endPtr else {
                throw JSONError.unexpectedCharacter(context: "in number", ascii: next.pointee, location: .sourceLocation(at: next, docStart: docStart))
            }
            guard firstHexDigitPtr.pointee.isValidHexDigit else {
                throw JSONError.unexpectedCharacter(context: "in number", ascii: (cursor+2).pointee, location: .sourceLocation(at: firstHexDigitPtr, docStart: docStart))
            }
            isHex = true
            cursor += 2
        case _asciiNumbers:
            throw JSONError.numberWithLeadingZero(location: .sourceLocation(at: next, docStart: docStart))
        default:
            throw JSONError.unexpectedCharacter(context: "in number", ascii: next.pointee, location: .sourceLocation(at: next, docStart: docStart))
        }
    }

    static func validateInfinity(from jsonBytes: UnsafeBufferPointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
        guard jsonBytes.count >= _json5Infinity.utf8CodeUnitCount else {
            throw JSONError.invalidSpecialValue(expected: "Infinity", location: .sourceLocation(at: jsonBytes.baseAddress.unsafelyUnwrapped, docStart: docStart))
        }
        guard strncmp(jsonBytes.baseAddress, _json5Infinity.utf8Start, _json5Infinity.utf8CodeUnitCount) == 0 else {
            throw JSONError.invalidSpecialValue(expected: "Infinity", location: .sourceLocation(at: jsonBytes.baseAddress.unsafelyUnwrapped, docStart: docStart))
        }
    }

    static func validateNaN(from jsonBytes: UnsafeBufferPointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
        guard jsonBytes.count >= _json5NaN.utf8CodeUnitCount else {
            throw JSONError.invalidSpecialValue(expected: "NaN", location: .sourceLocation(at: jsonBytes.baseAddress.unsafelyUnwrapped, docStart: docStart))
        }
        guard strncmp(jsonBytes.baseAddress, _json5NaN.utf8Start, _json5NaN.utf8CodeUnitCount) == 0 else {
            throw JSONError.invalidSpecialValue(expected: "NaN", location: .sourceLocation(at: jsonBytes.baseAddress.unsafelyUnwrapped, docStart: docStart))
        }
    }

    static func validateLeadingDecimal(from jsonBytes: UnsafeBufferPointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
        let cursor = jsonBytes.baseAddress.unsafelyUnwrapped
        guard jsonBytes.count > 1 else {
            throw JSONError.unexpectedCharacter(ascii: cursor.pointee, location: .sourceLocation(at: cursor, docStart: docStart))
        }
        guard case _asciiNumbers = (cursor+1).pointee else {
            throw JSONError.unexpectedCharacter(context: "after '.' in number", ascii: (cursor+1).pointee, location: .sourceLocation(at: cursor+1, docStart: docStart))
        }
    }

    // Returns the pointer at which the number's digits begin. If there are no digits, the function throws.
    static func prevalidateJSONNumber(from jsonBytes: UnsafeBufferPointer<UInt8>, docStart: UnsafePointer<UInt8>) throws -> (UnsafePointer<UInt8>, isHex: Bool, isSpecialDoubleValue: Bool) {
        // Just make sure we (A) don't have a leading zero, and (B) We have at least one digit.
        guard !jsonBytes.isEmpty else {
            preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
        }
        var cursor = jsonBytes.baseAddress.unsafelyUnwrapped
        let endPtr = cursor + jsonBytes.count
        let digitsBeginPtr : UnsafePointer<UInt8>
        var isHex = false
        var isSpecialValue = false
        switch cursor.pointee {
        case UInt8(ascii: "0"):
            try validateLeadingZero(in: jsonBytes, following: &cursor, docStart: docStart, isHex: &isHex)
            digitsBeginPtr = cursor
        case UInt8(ascii: "1") ... UInt8(ascii: "9"):
            digitsBeginPtr = cursor
        case UInt8(ascii: "-"), UInt8(ascii: "+"):
            cursor += 1
            guard cursor < endPtr else {
                throw JSONError.unexpectedCharacter(context: "at end of number", ascii: cursor.pointee, location: .sourceLocation(at: endPtr-1, docStart: docStart))
            }
            switch cursor.pointee {
            case UInt8(ascii: "0"):
                try validateLeadingZero(in: jsonBytes, following: &cursor, docStart: docStart, isHex: &isHex)
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                // Good, we need at least one digit following the '-'
                break
            case UInt8(ascii: "I"):
                let offsetBuffer = UnsafeBufferPointer(rebasing: jsonBytes.suffix(from: 1))
                try validateInfinity(from: offsetBuffer, docStart: docStart)
                isSpecialValue = true
            case UInt8(ascii: "N"):
                let offsetBuffer = UnsafeBufferPointer(rebasing: jsonBytes.suffix(from: 1))
                try validateNaN(from: offsetBuffer, docStart: docStart)
                isSpecialValue = true
            case UInt8(ascii: "."):
                let offsetBuffer = UnsafeBufferPointer(rebasing: jsonBytes.suffix(from: 1))
                try validateLeadingDecimal(from: offsetBuffer, docStart: docStart)
            default:
                // Any other character is invalid.
                throw JSONError.unexpectedCharacter(context: "after '\(String(UnicodeScalar(cursor.pointee)))' in number", ascii: cursor.pointee, location: .sourceLocation(at: cursor, docStart: docStart))
            }
            digitsBeginPtr = cursor
        case UInt8(ascii: "I"):
            try validateInfinity(from: jsonBytes, docStart: docStart)
            digitsBeginPtr = cursor
            isSpecialValue = true
        case UInt8(ascii: "N"):
            try validateNaN(from: jsonBytes, docStart: docStart)
            digitsBeginPtr = cursor
            isSpecialValue = true
        case UInt8(ascii: "."):
            // Leading decimals MUST be followed by a number, unlike trailing deciamls.
            try validateLeadingDecimal(from: jsonBytes, docStart: docStart)
            digitsBeginPtr = cursor
        default:
            preconditionFailure("Why was this function called, if there is no 0...9 or +/-")
        }

        // Explicitly exclude a trailing 'e'. JSON5 and strtod both disallow it, but Decimal unfortunately accepts it so we need to prevent it in advance.
        switch jsonBytes.last.unsafelyUnwrapped {
        case UInt8(ascii: "e"), UInt8(ascii: "E"):
            throw JSONError.unexpectedCharacter(context: "at end of number", ascii: jsonBytes.last.unsafelyUnwrapped, location: .sourceLocation(at: endPtr-1, docStart: docStart))
        default:
            break
        }

        return (digitsBeginPtr, isHex, isSpecialValue)
    }

    // This function is intended to be called after prevalidateJSONNumber() (which provides the digitsBeginPtr) and after parsing fails. It will provide more useful information about the invalid input.
    static func validateNumber(from jsonBytes: UnsafeBufferPointer<UInt8>, withDigitsBeginningAt digitsBeginPtr: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
        enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        var cursor = jsonBytes.baseAddress.unsafelyUnwrapped
        let endPtr = cursor + jsonBytes.count

        // Any checks performed during pre-validation can be skipped. Proceed to the beginning of the actual number contents.
        if jsonBytes[0] == UInt8(ascii: "+") || jsonBytes[0] == UInt8(ascii: "-") {
            cursor += 1
        }

        if endPtr - cursor >= 2, strncasecmp_l(cursor, "0x", 2, nil) == 0 {
            cursor += 2

            while cursor < endPtr {
                if cursor.pointee.isValidHexDigit {
                    cursor += 1
                } else {
                    throw JSONError.unexpectedCharacter(context: "in hex number", ascii: cursor.pointee, location: .sourceLocation(at: cursor, docStart: docStart))
                }
            }
            return
        }

        var pastControlChar: ControlCharacter = .operand
        var numbersSinceControlChar = 0

        // parse everything else
        while cursor < endPtr {
            let byte = cursor.pointee
            switch byte {
            case _asciiNumbers:
                numbersSinceControlChar += 1
            case UInt8(ascii: "."):
                guard pastControlChar == .operand else {
                    throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
                }

                pastControlChar = .decimalPoint
                numbersSinceControlChar = 0

            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                guard (pastControlChar == .operand && numbersSinceControlChar > 0) || pastControlChar == .decimalPoint
                else {
                    throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
                }

                pastControlChar = .exp
                numbersSinceControlChar = 0
            case UInt8(ascii: "+"), UInt8(ascii: "-"):
                guard numbersSinceControlChar == 0, pastControlChar == .exp else {
                    throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
                }

                pastControlChar = .expOperator
                numbersSinceControlChar = 0
            default:
                throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
            }
            cursor += 1
        }

        // prevalidateJSONNumber() already checks for trailing `e`/`E` characters.
    }
}

internal func _parseJSONHexIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: UnsafeBufferPointer<UInt8>, isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8, _A = 65 as UInt8, _a = 97 as UInt8

    let numericalUpperBound = _0 &+ 10
    let uppercaseUpperBound = _A &+ 6
    let lowercaseUpperBound = _a &+ 6
    let multiplicand: Result = 16

    var result = 0 as Result
    for digit in codeUnits {
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

internal func _parseJSON5Integer<Result: FixedWidthInteger>(_ codeUnits: UnsafeBufferPointer<UInt8>, isHex: Bool) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _plus = 43 as UInt8, _minus = 45 as UInt8

    let first = codeUnits[0]
    var isNegative = false
    var digitsToParse = codeUnits
    if first == _minus {
        digitsToParse = UnsafeBufferPointer(rebasing: digitsToParse.suffix(from: 1))
        isNegative = true
    } else if first == _plus {
        digitsToParse = UnsafeBufferPointer(rebasing: digitsToParse.suffix(from: 1))
    }

    // Trust the caller regarding whether this is valid hex data.
    if isHex {
        digitsToParse = UnsafeBufferPointer(rebasing: digitsToParse.suffix(from: 2))
        return _parseJSONHexIntegerDigits(digitsToParse, isNegative: isNegative)
    } else {
        return _parseIntegerDigits(codeUnits, isNegative: isNegative)
    }
}

extension FixedWidthInteger {
    init?(prevalidatedJSON5Buffer buffer: UnsafeBufferPointer<UInt8>, isHex: Bool) {
        guard let val : Self = _parseJSON5Integer(buffer, isHex: isHex) else {
            return nil
        }
        self = val
    }
}

internal extension UInt8 {
    static let _verticalTab = UInt8(0x0b)
    static let _formFeed = UInt8(0x0c)
    static let _nbsp = UInt8(0xa0)
    static let _asterisk = UInt8(ascii: "*")
    static let _slash = UInt8(ascii: "/")
    static let _singleQuote = UInt8(ascii: "'")
    static let _dollar = UInt8(ascii: "$")
    static let _underscore = UInt8(ascii: "_")
}

let _json5Infinity: StaticString = "Infinity"
let _json5NaN: StaticString = "NaN"

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
