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

#if !NO_JSON_FOUNDATION_SPECIALIZATION
internal import Synchronization
#endif

internal class JSONDocument {
    let map: JSONMap<ArrayMapRecords>
    let dataLock : Mutex<(buffer: BufferView<UInt8>, allocation: UnsafeRawPointer?)>

    init(map: consuming JSONMap<ArrayMapRecords>, dataBuffer: BufferView<UInt8>) {
        self.map = map
        self.dataLock = .init((buffer: dataBuffer, allocation: nil))
        // If the top-level value is a number, ensure a trailing NUL byte is available so strtod can't overrun.
        if case .number = self.map.loadValue(at: 0) {
            self.copyInBuffer()
        }
    }

    func copyInBuffer() {
        dataLock.withLock { state in
            guard state.allocation == nil else {
                return
            }

            // Allocate an additional byte to ensure we have a trailing NUL byte which is important for cases like a floating point number fragment.
            let (p, c) = state.buffer.withUnsafeRawPointer {
                pointer, capacity -> (UnsafeRawPointer, Int) in
                let raw = UnsafeMutableRawPointer.allocate(byteCount: capacity+1, alignment: 1)
                raw.copyMemory(from: pointer, byteCount: capacity)
                raw.storeBytes(of: UInt8.zero, toByteOffset: capacity, as: UInt8.self)
                return (.init(raw), capacity+1)
            }

            state = (buffer: .init(unsafeBaseAddress: p, count: c), allocation: p)
        }
    }


    @inline(__always)
    func withBuffer<T: ~Copyable, E>(
      for region: JSONMapRegion, perform closure: (_ jsonBytes: BufferView<UInt8>, _ fullSource: BufferView<UInt8>) throws(E) -> sending T
    ) throws(E) -> sending T {
        try dataLock.withLock { state throws(E) in
            return try closure(state.buffer[region], state.buffer)
        }
    }

    deinit {
        dataLock.withLock {
            if let allocatedPointer = $0.allocation {
                precondition($0.buffer.startIndex == BufferViewIndex(rawValue: allocatedPointer))
                allocatedPointer.deallocate()
            }
        }
    }

    func loadValue(at mapOffset: Int) -> JSONMapValue? {
        map.loadValue(at: mapOffset)
    }

    func offset(after previousValueOffset: Int) -> Int {
        map.offset(after: previousValueOffset)
    }

    struct ArrayIterator {
        var currentOffset: Int
        let document : JSONDocument

        mutating func next() -> JSONMapValue? {
            guard let next = peek() else {
                return nil
            }
            advance()
            return next
        }

        func peek() -> JSONMapValue? {
            guard let next = document.loadValue(at: currentOffset) else {
                return nil
            }
            return next
        }

        mutating func advance() {
            currentOffset = document.offset(after: currentOffset)
        }
    }

    func makeArrayIterator(from offset: Int) -> ArrayIterator {
        return .init(currentOffset: offset, document: self)
    }

    struct ObjectIterator {
        var currentOffset: Int
        let document : JSONDocument

        mutating func next() -> (key: JSONMapValue, value: JSONMapValue)? {
            let keyOffset = currentOffset
            guard let key = document.loadValue(at: currentOffset) else {
                return nil
            }
            let valueOffset = document.offset(after: keyOffset)
            guard let value = document.loadValue(at: valueOffset) else {
                preconditionFailure("JSONDocument object constructed incorrectly. No value found for key")
            }
            currentOffset = document.offset(after: valueOffset)
            return (key, value)
        }
    }

    func makeObjectIterator(from offset: Int) -> ObjectIterator {
        return .init(currentOffset: offset, document: self)
    }
}

extension JSONMapValue {
    var debugDataTypeDescription : String {
        switch self {
        case .string: return "a string"
        case .number: return "number"
        case .bool: return "bool"
        case .null: return "null"
        case .object: return "a dictionary"
        case .array: return "an array"
        }
    }
}



internal struct JSONScanner {
    let options: Options
    var reader: DocumentReader
    var depth: Int = 0
    var partialMap = JSONPartialMapData()
    
    // True if any scanned number extends to the last byte of the input.
    var numberExtendsToEndOfBuffer: Bool = false

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

        mutating func recordStartCollection(tagType: JSONMapTypeDescriptor, with reader: DocumentReader) -> Int {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)

            // Reserve space for the next object index and object count.
            let startIdx = mapData.count
            mapData.append(contentsOf: [0, 0])
            return startIdx
        }

        mutating func recordEndCollection(count: Int, atStartOffset startOffset: Int, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(JSONMapTypeDescriptor.collectionEnd.rawValue)

            let nextValueOffset = mapData.count
            mapData.withUnsafeMutableBufferPointer {
                $0[startOffset] = nextValueOffset
                $0[startOffset + 1] = count
            }
        }

        mutating func recordEmptyCollection(tagType: JSONMapTypeDescriptor, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            let nextValueOffset = mapData.count + 4
            mapData.append(contentsOf: [tagType.mapMarker, nextValueOffset, 0, JSONMapTypeDescriptor.collectionEnd.mapMarker])
        }

        mutating func record(tagType: JSONMapTypeDescriptor, count: Int, dataOffset: Int, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(contentsOf: [tagType.mapMarker, count, dataOffset])
        }

        mutating func record(tagType: JSONMapTypeDescriptor, with reader: DocumentReader) {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)
        }
    }

    init(bytes: BufferView<UInt8>, options: Options) {
        self.options = options
        self.reader = DocumentReader(bytes: bytes)
    }

    mutating func scan() throws -> JSONMap<ArrayMapRecords> {
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
        var whitespace = 0
        while let next = reader.peek(offset: whitespace) {
            switch next {
            case ._space, ._tab, ._return, ._newline:
                whitespace += 1
                continue
            default:
                throw JSONError.unexpectedCharacter(context: "after top-level value", ascii: next, location: reader.sourceLocation(atOffset: whitespace))
            }
        }

        return JSONMap(records: .init(partialMap.mapData))
    }

    // MARK: Generic Value Scanning

    mutating func scanValue() throws {
        let byte = try reader.consumeWhitespace()
        switch byte {
        case ._quote:
            try scanString()
        case ._openbrace:
            try scanObject()
        case ._openbracket:
            try scanArray()
        case UInt8(ascii: "f"), UInt8(ascii: "t"):
            try scanBool()
        case UInt8(ascii: "n"):
            try scanNull()
        case UInt8(ascii: "-"), _asciiNumbers:
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
            throw JSONError.tooManyNestedArraysOrDictionaries(location: reader.sourceLocation(atOffset: 1))
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
            count += 1

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
        try scanString()

        let colon = try reader.consumeWhitespace()
        guard colon == ._colon else {
            throw JSONError.unexpectedCharacter(context: "in object", ascii: colon, location: reader.sourceLocation)
        }
        reader.moveReaderIndex(forwardBy: 1)

        try self.scanValue()
        count += 2

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

    mutating func scanString() throws {
        var isSimple = false
        let start = try reader.skipUTF8StringTillNextUnescapedQuote(isSimple: &isSimple)
        let end = reader.readIndex

        // skipUTF8StringTillNextUnescapedQuote will have either thrown an error, or already peek'd the quote.
        let shouldBePostQuote = reader.read()
        precondition(shouldBePostQuote == ._quote)

        // skip initial quote
        return partialMap.record(tagType: isSimple ? .simpleString : .string, count: reader.distance(from: start, to: end), dataOffset: reader.byteOffset(at: start), with: reader)
    }

    mutating func scanNumber() throws {
        let start = reader.readIndex
        var containsExponent = false
        reader.skipNumber(containsExponent: &containsExponent)
        let end = reader.readIndex
        if reader.isEOF {
            numberExtendsToEndOfBuffer = true
        }
        return partialMap.record(tagType: containsExponent ? .numberContainingExponent : .number, count: reader.distance(from: start, to: end), dataOffset: reader.byteOffset(at: start), with: reader)
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

extension JSONScanner {

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
            .sourceLocation(at: bytes.index(readIndex, offsetBy: offset), fullSource: bytes)
        }

        @inline(__always)
        var isEOF: Bool {
            readIndex == endIndex
        }

        @inline(__always)
        func byteOffset(at index: BufferViewIndex<UInt8>) -> Int {
            bytes.distance(from: bytes.startIndex, to: index)
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

        @inline(__always)
        mutating func moveReaderIndex(forwardBy offset: Int) {
          bytes.formIndex(&readIndex, offsetBy: offset)
        }

        @inline(__always)
        func distance(from start: BufferViewIndex<UInt8>, to end: BufferViewIndex<UInt8>) -> Int {
            bytes.distance(from: start, to: end)
        }

        static var whitespaceBitmap: UInt64 { 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            assert(bytes.startIndex <= readIndex)
            while readIndex < endIndex {
                let ascii = bytes[unchecked: readIndex]
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    bytes.formIndex(after: &readIndex)
                    continue
                } else {
                    return ascii
                }
            }

            throw JSONError.unexpectedEndOfFile
        }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace(allowingEOF: Bool) throws -> UInt8? {
            assert(bytes.startIndex <= readIndex)
            while readIndex < endIndex {
                let ascii = bytes[unchecked: readIndex]
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    bytes.formIndex(after: &readIndex)
                    continue
                } else {
                    return ascii
                }
            }
            guard allowingEOF else {
                throw JSONError.unexpectedEndOfFile
            }
            return nil
        }

        @inline(__always)
        mutating func readExpectedString(_ str: StaticString, typeDescriptor: String) throws {
            let cmp = try bytes[unchecked: readIndex..<endIndex].withUnsafeRawPointer { ptr, count in
                if count < str.utf8CodeUnitCount { throw JSONError.unexpectedEndOfFile }
                return Platform.memcmp(ptr, str.utf8Start, str.utf8CodeUnitCount)
            }
            guard cmp == 0 else {
                // Figure out the exact character that is wrong.
                let badOffset = str.withUTF8Buffer {
                    for (i, (a, b)) in zip($0, bytes[readIndex..<endIndex]).enumerated() {
                        if a != b { return i }
                    }
                    return 0 // should be unreachable
                }
                self.moveReaderIndex(forwardBy: badOffset)
                throw JSONError.unexpectedCharacter(context: "in expected \(typeDescriptor) value", ascii: self.peek()!, location: sourceLocation)
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

        mutating func skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter() throws -> UInt8 {
            while let byte = self.peek() {
                switch byte {
                case ._quote, ._backslash:
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

        mutating func skipUTF8StringTillNextUnescapedQuote(isSimple: inout Bool) throws -> BufferViewIndex<UInt8> {
            // Skip the open quote.
            guard let shouldBeQuote = self.read() else {
                throw JSONError.unexpectedEndOfFile
            }
            guard shouldBeQuote == ._quote else {
                throw JSONError.unexpectedCharacter(ascii: shouldBeQuote, location: sourceLocation)
            }
            let firstNonQuote = readIndex

            // If there aren't any escapes, then this is a simple case and we can exit early.
            if try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter() == ._quote {
                isSimple = true
                return firstNonQuote
            }

            while let byte = self.peek() {
                // Checking for invalid control characters deferred until parse time.
                switch byte {
                case ._quote:
                    isSimple = false
                    return firstNonQuote
                case ._backslash:
                    try skipEscapeSequence()
                default:
                    moveReaderIndex(forwardBy: 1)
                    continue
                }
            }
            throw JSONError.unexpectedEndOfFile
        }

        private mutating func skipEscapeSequence() throws {
            let firstChar = self.read()
            precondition(firstChar == ._backslash, "Expected to have a backslash first")

            guard let ascii = self.read() else {
                throw JSONError.unexpectedEndOfFile
            }

            // Invalid escaped characters checking deferred to parse time.
            if ascii == UInt8(ascii: "u") {
                try skipUnicodeHexSequence()
            }
        }

        private mutating func skipUnicodeHexSequence() throws {
            // As stated in RFC-8259 an escaped unicode character is 4 HEXDIGITs long
            // https://tools.ietf.org/html/rfc8259#section-7
            try requireRemainingBytes(4)

            // We'll validate the actual characters following the '\u' escape during parsing. Just make sure that the string doesn't end prematurely.
            let hs = bytes.loadUnaligned(from: readIndex, as: UInt32.self)
            guard JSONScanner.noByteMatches(UInt8(ascii: "\""), in: hs) else {
                let hexString = _withUnprotectedUnsafeBytes(of: hs) { String(decoding: $0, as: UTF8.self) }
                throw JSONError.invalidHexDigitSequence(hexString, location: sourceLocation)
            }
            self.moveReaderIndex(forwardBy: 4)
        }

        // MARK: Numbers

        mutating func skipNumber(containsExponent: inout Bool) {
            guard let ascii = read() else {
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }
            switch ascii {
            case _asciiNumbers, UInt8(ascii: "-"):
                break
            default:
                preconditionFailure("Why was this function called, if there is no 0...9 or -")
            }
            while let byte = peek() {
                if _fastPath(_asciiNumbers.contains(byte)) {
                    moveReaderIndex(forwardBy: 1)
                    continue
                }
                switch byte {
                case UInt8(ascii: "."), UInt8(ascii: "+"), UInt8(ascii: "-"):
                    moveReaderIndex(forwardBy: 1)
                case UInt8(ascii: "e"), UInt8(ascii: "E"):
                    moveReaderIndex(forwardBy: 1)
                    containsExponent = true
                default:
                    return
                }
            }
        }
    }

    @inline(__always)
    internal static func noByteMatches(_ asciiByte: UInt8, in hexString: UInt32) -> Bool {
        assert(asciiByte & 0x80 == 0)
        // Copy asciiByte of interest to mask.
        let t0 = UInt32(0x01010101) &* UInt32(asciiByte)
        // xor input and mask, then locate potential matches.
        let t1 = ((hexString ^ t0) & 0x7f7f7f7f) &+ 0x7f7f7f7f
        // Positions with matches are 0x7f.
        // Positions with non-matching ascii bytes have their MSB set.
        // Positions with non-ascii bytes do not have their MSB set.
        // Eliminate non-ascii bytes with a bitwise-or of t1 with the input,
        // then select the positions whose MSB is not set.
        let t2 = ((hexString | t1) & 0x80808080) ^ 0x80808080
        // There is no match when no bit is set.
        return t2 == 0
    }
}

// MARK: - Deferred Parsing Methods -

extension JSONScanner {

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
      precondition(!jsonBytes.isEmpty, "Scanning should have ensured that all escape sequences are valid shape")
        switch jsonBytes[unchecked: jsonBytes.startIndex] {
        case UInt8(ascii:"\""): string.append("\"")
        case UInt8(ascii:"\\"): string.append("\\")
        case UInt8(ascii:"/"): string.append("/")
        case UInt8(ascii:"b"): string.append("\u{08}") // \b
        case UInt8(ascii:"f"): string.append("\u{0C}") // \f
        case UInt8(ascii:"n"): string.append("\u{0A}") // \n
        case UInt8(ascii:"r"): string.append("\u{0D}") // \r
        case UInt8(ascii:"t"): string.append("\u{09}") // \t
        case UInt8(ascii:"u"):
            return try parseUnicodeSequence(from: jsonBytes.dropFirst(), into: &string, fullSource: fullSource)
        case let ascii: // default
            throw JSONError.unexpectedEscapedCharacter(ascii: ascii, location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        return jsonBytes.index(after: jsonBytes.startIndex)
    }

    // Shared with JSON5, which requires allowNulls = false for compatibility.
    internal static func parseUnicodeSequence(
        from jsonBytes: BufferView<UInt8>, into string: inout String, fullSource: BufferView<UInt8>, allowNulls: Bool = true
    ) throws -> BufferViewIndex<UInt8> {
        // we build this for utf8 only for now.
        let (bitPattern, index1) = try parseUnicodeHexSequence(from: jsonBytes, fullSource: fullSource, allowNulls: allowNulls)

        // check if lead surrogate
        if UTF16.isLeadSurrogate(bitPattern) {
            // if we have a lead surrogate we expect a trailing surrogate next
            let leadingSurrogateBitPattern = bitPattern
            var trailingBytes = jsonBytes.suffix(from: index1)
            guard trailingBytes.count >= 2 else {
                throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: index1, fullSource: fullSource))
            }
            guard trailingBytes[uncheckedOffset: 0] == ._backslash,
                  trailingBytes[uncheckedOffset: 1] == UInt8(ascii: "u")
            else {
                throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: index1, fullSource: fullSource))
            }
            trailingBytes = trailingBytes.dropFirst(2)

          let (trailingSurrogateBitPattern, index2) = try parseUnicodeHexSequence(from: trailingBytes, fullSource: fullSource, allowNulls: true)
            guard UTF16.isTrailSurrogate(trailingSurrogateBitPattern) else {
              throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: trailingBytes.startIndex, fullSource: fullSource))
            }

            let encodedScalar = UTF16.EncodedScalar([leadingSurrogateBitPattern, trailingSurrogateBitPattern])
            let unicode = UTF16.decode(encodedScalar)
            string.unicodeScalars.append(unicode)
            return index2
        } else {
            guard let unicode = Unicode.Scalar(bitPattern) else {
                throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource), unicodeScalarValue: UInt32(bitPattern))
            }
            string.unicodeScalars.append(unicode)
            return index1
        }
    }

    internal static func parseUnicodeHexSequence(
        from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>, allowNulls: Bool = true
    ) throws -> (scalar: UInt16, nextIndex: BufferViewIndex<UInt8>) {
        let digitBytes = jsonBytes.prefix(4)
        precondition(digitBytes.count == 4, "Scanning should have ensured that all escape sequences are valid shape")

        guard let result: UInt16 = _parseHexIntegerDigits(digitBytes, isNegative: false)
        else {
            let hexString = String(decoding: digitBytes, as: Unicode.UTF8.self)
            throw JSONError.invalidHexDigitSequence(hexString, location: .sourceLocation(at: digitBytes.startIndex, fullSource: fullSource))
        }
        guard allowNulls || result != 0 else {
            throw JSONError.invalidEscapedNullValue(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
        assert(digitBytes.endIndex <= jsonBytes.endIndex)
        return (result, digitBytes.endIndex)
    }


    // MARK: Numbers

    static func validateLeadingZero(in jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>) throws {
        // Leading zeros are very restricted.
        if jsonBytes.isEmpty {
            // Yep, this is valid.
            return
        }
        switch jsonBytes[uncheckedOffset: 0] {
        case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
            // This is valid after a leading zero.
            return
        case _asciiNumbers:
            throw JSONError.numberWithLeadingZero(location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        case let byte: // default
            throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
        }
    }

    // Returns the pointer at which the number's digits begin. If there are no digits, the function throws.
    static func prevalidateJSONNumber(
        from jsonBytes: BufferView<UInt8>, hasExponent: Bool, fullSource: BufferView<UInt8>
    ) throws -> BufferViewIndex <UInt8> {
        // Just make sure we (A) don't have a leading zero, and (B) We have at least one digit.
        guard !jsonBytes.isEmpty else {
            preconditionFailure("Why was this function called, if there is no 0...9 or -")
        }
        let firstDigitIndex : BufferViewIndex<UInt8>
        switch jsonBytes[uncheckedOffset: 0] {
        case UInt8(ascii: "0"):
            try validateLeadingZero(in: jsonBytes.dropFirst(1), fullSource: fullSource)
            firstDigitIndex = jsonBytes.startIndex
        case UInt8(ascii: "1") ... UInt8(ascii: "9"):
            firstDigitIndex = jsonBytes.startIndex
        case UInt8(ascii: "-"):
            guard jsonBytes.count > 1 else {
                throw JSONError.unexpectedCharacter(context: "at end of number", ascii: UInt8(ascii: "-"), location: .sourceLocation(at: jsonBytes.startIndex, fullSource: fullSource))
            }
            switch jsonBytes[uncheckedOffset: 1] {
            case UInt8(ascii: "0"):
                try validateLeadingZero(in: jsonBytes.dropFirst(2), fullSource: fullSource)
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                // Good, we need at least one digit following the '-'
                break
            case let byte: // default
                // Any other character is invalid.
                throw JSONError.unexpectedCharacter(context: "after '-' in number", ascii: byte, location: .sourceLocation(at: jsonBytes.index(after: jsonBytes.startIndex), fullSource: fullSource))
            }
            firstDigitIndex = jsonBytes.index(after: jsonBytes.startIndex)
        default:
            preconditionFailure("Why was this function called, if there is no 0...9 or -")
        }

        // If the number was found to have an exponent, we have to guarantee that there are digits preceding it, which is a JSON requirement. If we don't, then our floating point parser, which is tolerant of that construction, will succeed and not produce the required error.
        if hasExponent {
            var index = jsonBytes.index(after: firstDigitIndex)
            exponentLoop: while index < jsonBytes.endIndex {
                switch jsonBytes[unchecked: index] {
                case UInt8(ascii: "e"), UInt8(ascii: "E"):
                    let previous = jsonBytes.index(before: index)
                    guard case _asciiNumbers = jsonBytes[unchecked: previous] else {
                        throw JSONError.unexpectedCharacter(context: "in number", ascii: jsonBytes[index], location: .sourceLocation(at: index, fullSource: fullSource))
                    }
                    // We're done iterating.
                    break exponentLoop
                default:
                    jsonBytes.formIndex(after: &index)
                }
            }
        }

        let lastIndex = jsonBytes.index(before: jsonBytes.endIndex)
        assert(lastIndex >= jsonBytes.startIndex)
        switch jsonBytes[unchecked: lastIndex] {
        case _asciiNumbers:
            break // In JSON, all numbers must end with a digit.
        case let lastByte: // default
            throw JSONError.unexpectedCharacter(context: "at end of number", ascii: lastByte, location: .sourceLocation(at: lastIndex, fullSource: fullSource))
        }
        return firstDigitIndex
    }

    // This function is intended to be called after prevalidateJSONNumber() (which provides the digitsBeginPtr) and after parsing fails. It will provide more useful information about the invalid input.
  static func validateNumber(from jsonBytes: BufferView<UInt8>, fullSource: BufferView<UInt8>) -> JSONError {
        enum ControlCharacter {
            case operand
            case decimalPoint
            case exp
            case expOperator
        }

        var index = jsonBytes.startIndex
        let endIndex = jsonBytes.endIndex
        // Fast-path, assume all digits.
        while index < endIndex {
            guard _asciiNumbers.contains(jsonBytes[index]) else { break }
            jsonBytes.formIndex(after: &index)
        }

        var pastControlChar: ControlCharacter = .operand
        var digitsSinceControlChar = jsonBytes.distance(from: jsonBytes.startIndex, to: index)

        // parse everything else
        while index < endIndex {
            let byte = jsonBytes[index]
            switch byte {
            case _asciiNumbers:
                digitsSinceControlChar += 1
            case UInt8(ascii: "."):
                guard digitsSinceControlChar > 0, pastControlChar == .operand else {
                    return JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: index, fullSource: fullSource))
                }
                pastControlChar = .decimalPoint
                digitsSinceControlChar = 0

            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                guard digitsSinceControlChar > 0,
                      pastControlChar == .operand || pastControlChar == .decimalPoint
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

// Protocol conformed to by the numeric types we parse. For each of them, the
protocol PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: BufferView<UInt8>)
}

extension Double : PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: BufferView<UInt8>) {
        let decodedValue = buffer.withUnsafePointer { nptr, count -> Double? in
            var endPtr: UnsafeMutablePointer<CChar>? = nil
            let decodedValue = Platform.strtod_clocale(nptr, &endPtr)
            if let endPtr, nptr.advanced(by: count) == endPtr {
                return decodedValue
            } else {
                return nil
            }
        }
        guard let decodedValue else { return nil }
        self = decodedValue
    }
}

extension Float : PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: BufferView<UInt8>) {
        let decodedValue = buffer.withUnsafePointer { nptr, count -> Float? in
            var endPtr: UnsafeMutablePointer<CChar>? = nil
            let decodedValue = Platform.strtof_clocale(nptr, &endPtr)
            if let endPtr, nptr.advanced(by: count) == endPtr {
                return decodedValue
            } else {
                return nil
            }
        }
        guard let decodedValue else { return nil }
        self = decodedValue
    }
}

internal func _parseInteger<Result: FixedWidthInteger>(_ codeUnits: BufferView<UInt8>) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _plus = 43 as UInt8, _minus = 45 as UInt8

    let first = codeUnits[uncheckedOffset: 0]
    if first == _minus {
        return _parseIntegerDigits(codeUnits.dropFirst(), isNegative: true)
    }
    if first == _plus {
        return _parseIntegerDigits(codeUnits.dropFirst(), isNegative: false)
    }
    return _parseIntegerDigits(codeUnits, isNegative: false)
}

extension FixedWidthInteger {
    init?(prevalidatedBuffer buffer: BufferView<UInt8>) {
        guard let val : Self = _parseInteger(buffer) else {
            return nil
        }
        self = val
    }
}

enum JSONError: Swift.Error, Equatable {
    struct SourceLocation: Equatable {
        let line: Int
        let column: Int
        let index: Int

        static func sourceLocation(
          at location: BufferViewIndex<UInt8>, fullSource: BufferView<UInt8>
        ) -> SourceLocation {
            precondition(fullSource.startIndex <= location && location <= fullSource.endIndex)
            var index = fullSource.startIndex
            var line = 1
            var col = 0
            let end = min(location.advanced(by: 1), fullSource.endIndex)
            while index < end {
                switch fullSource[index] {
                case ._return:
                    let next = fullSource.index(after: index)
                    if next <= location, fullSource[next] == ._newline {
                        index = next
                    }
                    line += 1
                    col = 0
                case ._newline:
                    line += 1
                    col = 0
                default:
                    col += 1
                }
                fullSource.formIndex(after: &index)
            }
            let offset = fullSource.distance(from: fullSource.startIndex, to: location)
            return SourceLocation(line: line, column: col, index: offset)
        }
    }

    case cannotConvertEntireInputDataToUTF8
    case cannotConvertInputStringDataToUTF8(location: SourceLocation)
    case unexpectedCharacter(context: String? = nil, ascii: UInt8, location: SourceLocation)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(location: SourceLocation? = nil)
    case invalidHexDigitSequence(String, location: SourceLocation)
    case invalidEscapedNullValue(location: SourceLocation)
    case invalidSpecialValue(expected: String, location: SourceLocation)
    case unexpectedEscapedCharacter(ascii: UInt8, location: SourceLocation)
    case unescapedControlCharacterInString(ascii: UInt8, location: SourceLocation)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: SourceLocation)
    case couldNotCreateUnicodeScalarFromUInt32(location: SourceLocation, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(location: SourceLocation)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed

    // JSON5

    case unterminatedBlockComment

    var debugDescription : String {
        switch self {
        case .cannotConvertEntireInputDataToUTF8:
            return "Unable to convert data to a string using the detected encoding. The data may be corrupt."
        case let .cannotConvertInputStringDataToUTF8(location):
            let line = location.line
            let col = location.column
            return "Unable to convert data to a string around line \(line), column \(col)."
        case let .unexpectedCharacter(context, ascii, location):
            let line = location.line
            let col = location.column
            if let context {
                return "Unexpected character '\(String(UnicodeScalar(ascii)))' \(context) around line \(line), column \(col)."
            } else {
                return "Unexpected character '\(String(UnicodeScalar(ascii)))' around line \(line), column \(col)."
            }
        case .unexpectedEndOfFile:
            return "Unexpected end of file"
        case .tooManyNestedArraysOrDictionaries(let location):
            if let location {
                let line = location.line
                let col = location.column
                return "Too many nested arrays or dictionaries around line \(line), column \(col)."
            } else {
                return "Too many nested arrays or dictionaries."
            }
        case let .invalidHexDigitSequence(hexSequence, location):
            let line = location.line
            let col = location.column
            return "Invalid hex digit in unicode escape sequence '\(hexSequence)' around line \(line), column \(col)."
        case let .invalidEscapedNullValue(location):
            let line = location.line
            let col = location.column
            return "Unsupported escaped null around line \(line), column \(col)."
        case let .invalidSpecialValue(expected, location):
            let line = location.line
            let col = location.column
            return "Invalid \(expected) value around line \(line), column \(col)."
        case let .unexpectedEscapedCharacter(ascii, location):
            let line = location.line
            let col = location.column
            return "Invalid escape sequence '\(String(UnicodeScalar(ascii)))' around line \(line), column \(col)."
        case let .unescapedControlCharacterInString(ascii, location):
            let line = location.line
            let col = location.column
            return "Unescaped control character '0x\(String(ascii, radix: 16))' around line \(line), column \(col)."
        case let .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location):
            let line = location.line
            let col = location.column
            return "Missing low code point in surrogate pair around line \(line), column \(col)."
        case let .couldNotCreateUnicodeScalarFromUInt32(location, unicodeScalarValue):
            let line = location.line
            let col = location.column
            return "Invalid unicode scalar value '0x\(String(unicodeScalarValue, radix: 16))' around line \(line), column \(col)."
        case let .numberWithLeadingZero(location):
            let line = location.line
            let col = location.column
            return "Number with leading zero around line \(line), column \(col)."
        case let .numberIsNotRepresentableInSwift(parsed):
            return "Number \(parsed) is not representable in Swift."
        case .singleFragmentFoundButNotAllowed:
            return "JSON input did not start with array or object as required by options."

        // JSON5

        case .unterminatedBlockComment:
            return "Unterminated block comment"
        }
    }

    var sourceLocation: SourceLocation? {
        switch self {
        case let .cannotConvertInputStringDataToUTF8(location), let .unexpectedCharacter(_, _, location):
            return location
        case let .tooManyNestedArraysOrDictionaries(location):
            return location
        case let .invalidHexDigitSequence(_, location), let .invalidEscapedNullValue(location), let .invalidSpecialValue(_, location):
            return location
        case let .unexpectedEscapedCharacter(_, location), let .unescapedControlCharacterInString(_, location), let .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location):
            return location
        case let .couldNotCreateUnicodeScalarFromUInt32(location, _), let .numberWithLeadingZero(location):
            return location
        default:
            return nil
        }
    }

#if FOUNDATION_FRAMEWORK
    var nsError: NSError {
        var userInfo : [String: Any] = [
            NSDebugDescriptionErrorKey : self.debugDescription
        ]
        if let location = self.sourceLocation {
            userInfo["NSJSONSerializationErrorIndex"] = location.index
        }
        return .init(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: userInfo)
    }
#endif // FOUNDATION_FRAMEWORK
}
