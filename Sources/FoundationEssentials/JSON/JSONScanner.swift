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

/*
 A JSONMap is created by a JSON scanner to describe the values found in a JSON payload, including their size, location, and contents, without copying any of the non-structural data. It is used by the JSONDecoder, which will fully parse only those values that are required to decode the requested Decodable types.

 To minimize the number of allocations required during scanning, the map's contents are implemented using a array of integers, whose values are a serialization of the JSON payload's full structure. Each type has its own unique marker value, which is followed by zero or more other integers that describe that contents of that type, if any.

 Due to the complexity and additional allocations required to parse JSON string values into Swift Strings or JSON number values into the requested integer or floating-point types, their map contents are captured as lengths of bytes and byte offsets into the input. This allows the full parsing to occur at decode time, or to be skipped if the value is not desired. A partial, imperfect parsing is performed by the scanner, simply "skipping" characters which are valid in their given contexts without interpeting or further validating them relative to the other inputs. This incomplete scanning process does however guarnatee that the structure of the JSON input is correctly interpreted.

 The JSONMap representation of JSON arrays and objects is a sequence of integers that is delimited by their starting marker and a shared "collection end" marker. Their contents are nested in between those two markers. To facilitate skipping over unwanted elements of a collection, which is especially useful for JSON objects, the map encodes the offset in the map array to the next object after the end of the collection.

 For instance, a JSON payload such as the following:

 ```
 {"array":[1,2,3],"number":42}
 ```

 will be scanned into a map buffer looking like this:

 ```
 Key:
 <OM> == Object Marker
 <AM> == Array Marker
 <SS> == Simple String (a variant of String that can has no escpaes and can be passed directly to a UTF-8 parser)
 <NM> == Number Marker
 <CE> == Collection End
 (See JSONMap.TypeDescriptor comments below for more details)

 Map offset:        0,  1, 2,    3, 4, 5,    6,  7, 8,    9, 10, 11,   12  13, 14,   15  16, 17,   18,   19, 20, 21,   22, 23, 24,   25
 Map contents: [ <OM>, 26, 2, <SS>, 5, 2, <AM>, 19, 3, <NM>,  1, 10, <NM>,  1, 12, <NM>,  1, 14, <CE>, <SS>,  6, 18, <NM>,  2, 26, <CE> ]
 Description:           |     -- key2 --  ------------------------- value1 --------------------------  --- key2 ---  -- value2 --
                        |              |         |  --arr elm 0-  --arr elm 0-  --arr elm 0-
                        |              > Byte offset from the beginning of the input to the contents of the string
                        |                        > Offset to the next entry after this array, which is key2
                        > Offset to next entry after this object, which is the endIndex of the array, as this is the top level value

 A Decodable type that wishes only to decode the "number" key of this object as an Int will be able to entirely skip the decoding of the "array" value by doing the following.
 1. Find the type of the value at index 0 (object), and its size at index 2.
 2. Begin parsing keys at index 3. It decodes the string, and finds "array", which is not a match for "number".
 3. Skip the key's value by finding its type (array), and then its nextSiblingOffset index (19)
 4. Parse the next key at index 4. It decodes the string and finds "number", which is a match.
 5. Decode the value by findings its type (number), its length (2) and the byte offset from the beginning of the input (26).
 6. Pass that byte offset + length into the number parser to produce the correspomding Swift Int value.
*/

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif // canImport(Darwin)

internal class JSONMap {
    enum TypeDescriptor : Int {
        case string  // [marker, count, sourceByteOffset]
        case number  // [marker, count, sourceByteOffset]
        case null    // [marker]
        case `true`  // [marker]
        case `false` // [marker]

        case object  // [marker, nextSiblingOffset, count, <keys and values>, .collectionEnd]
        case array   // [marker, nextSiblingOffset, count, <values>, .collectionEnd]
        case collectionEnd

        case simpleString // [marker, count, sourceByteOffset]
        case numberContainingExponent // [marker, count, sourceByteOffset]

        @inline(__always)
        var mapMarker: Int {
            self.rawValue
        }
    }

    struct Region {
        let startOffset: Int
        let count: Int
    }

    enum Value {
        case string(Region, isSimple: Bool)
        case number(Region, containsExponent: Bool)
        case bool(Bool)
        case null

        case object(Region)
        case array(Region)
    }

    let mapBuffer : [Int]
    var dataLock : LockedState<(buffer: UnsafeBufferPointer<UInt8>, owned: Bool)>

    init(mapBuffer: [Int], dataBuffer: UnsafeBufferPointer<UInt8>) {
        self.mapBuffer = mapBuffer
        self.dataLock = .init(initialState: (buffer: dataBuffer, owned: false))
    }

    func copyInBuffer() {
        dataLock.withLock { state in
            guard !state.owned else {
                return
            }

            // Allocate an additional byte to ensure we have a trailing NUL byte which is important for cases like a floating point number fragment.
            let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: state.buffer.count + 1)
            let (_, lastIndex) = buffer.initialize(from: state.buffer)
            buffer[lastIndex] = 0
            
            state = (buffer: UnsafeBufferPointer(buffer), owned: true)
        }
    }


    @inline(__always)
    func withBuffer<T>(for region: Region, perform closure: (UnsafeBufferPointer<UInt8>, UnsafePointer<UInt8>) throws -> T) rethrows -> T {
        try dataLock.withLock {
            let start = $0.buffer.baseAddress.unsafelyUnwrapped
            let buffer = UnsafeBufferPointer<UInt8>(start: start.advanced(by: region.startOffset), count: region.count)
            return try closure(buffer, start)
        }
    }

    deinit {
        dataLock.withLock {
            if $0.owned {
                $0.buffer.deallocate()
            }
        }
    }

    func loadValue(at mapOffset: Int) -> Value? {
        let marker = mapBuffer[mapOffset]
        let type = JSONMap.TypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .string(.init(startOffset: dataOffset, count: length), isSimple: type == .simpleString)
        case .number, .numberContainingExponent:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .number(.init(startOffset: dataOffset, count: length), containsExponent: type == .numberContainingExponent)
        case .object:
            // Skip the offset to the next sibling value.
            let count = mapBuffer[mapOffset + 2]
            return .object(.init(startOffset: mapOffset + 3, count: count))
        case .array:
            // Skip the offset to the next sibling value.
            let count = mapBuffer[mapOffset + 2]
            return .array(.init(startOffset: mapOffset + 3, count: count))
        case .null:
            return .null
        case .true:
            return .bool(true)
        case .false:
            return .bool(false)
        case .collectionEnd:
            return nil
        default:
            fatalError("Invalid JSON value type code in mapping: \(marker))")
        }
    }

    func offset(after previousValueOffset: Int) -> Int {
        let marker = mapBuffer[previousValueOffset]
        let type = JSONMap.TypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString, .number, .numberContainingExponent:
            return previousValueOffset + 3 // Skip marker, length, and data offset
        case .null, .true, .false:
            return previousValueOffset + 1 // Skip only the marker.
        case .object, .array:
            // The collection records the offset to the next sibling.
            return mapBuffer[previousValueOffset + 1]
        case .collectionEnd:
            fatalError("Attempt to find next object past the end of collection at offset \(previousValueOffset))")
        default:
            fatalError("Invalid JSON value type code in mapping: \(marker))")
        }
    }

    struct ArrayIterator {
        var currentOffset: Int
        let map : JSONMap

        mutating func next() -> JSONMap.Value? {
            guard let next = peek() else {
                return nil
            }
            advance()
            return next
        }

        func peek() -> JSONMap.Value? {
            guard let next = map.loadValue(at: currentOffset) else {
                return nil
            }
            return next
        }

        mutating func advance() {
            currentOffset = map.offset(after: currentOffset)
        }
    }

    func makeArrayIterator(from offset: Int) -> ArrayIterator {
        return .init(currentOffset: offset, map: self)
    }

    struct ObjectIterator {
        var currentOffset: Int
        let map : JSONMap

        mutating func next() -> (key: JSONMap.Value, value: JSONMap.Value)? {
            let keyOffset = currentOffset
            guard let key = map.loadValue(at: currentOffset) else {
                return nil
            }
            let valueOffset = map.offset(after: keyOffset)
            guard let value = map.loadValue(at: valueOffset) else {
                preconditionFailure("JSONMap object constructed incorrectly. No value found for key")
            }
            currentOffset = map.offset(after: valueOffset)
            return (key, value)
        }
    }

    func makeObjectIterator(from offset: Int) -> ObjectIterator {
        return .init(currentOffset: offset, map: self)
    }
}

extension JSONMap.Value {
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
                $0[startOffset + 1] = count
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

        let map = JSONMap(mapBuffer: partialMap.mapData, dataBuffer: self.reader.bytes)

        // If the input contains only a number, we have to copy the input into a form that is guaranteed to have a trailing NUL byte so that strtod doesn't perform a buffer overrun.
        if case .number = map.loadValue(at: 0)! {
            map.copyInBuffer()
        }

        return map
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

    mutating func scanString() throws {
        let quoteStart = reader.readPtr
        var isSimple = false
        try reader.skipUTF8StringTillNextUnescapedQuote(isSimple: &isSimple)
        let stringStart = quoteStart + 1
        let end = reader.readPtr

        // skipUTF8StringTillNextUnescapedQuote will have either thrown an error, or already peek'd the quote.
        let shouldBePostQuote = reader.read()
        precondition(shouldBePostQuote == ._quote)

        // skip initial quote
        return partialMap.record(tagType: isSimple ? .simpleString : .string, count: end - stringStart, dataOffset: reader.byteOffset(at: stringStart), with: reader)
    }

    mutating func scanNumber() throws {
        let start = reader.readPtr
        var containsExponent = false
        reader.skipNumber(containsExponent: &containsExponent)
        let end = reader.readPtr
        return partialMap.record(tagType: containsExponent ? .numberContainingExponent : .number, count: end - start, dataOffset: reader.byteOffset(at: start), with: reader)
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

        @inline(__always)
        mutating func moveReaderIndex(forwardBy offset: Int) {
            self.readPtr += offset
        }

        static var whitespaceBitmap: UInt64 { 1 << UInt8._space | 1 << UInt8._return | 1 << UInt8._newline | 1 << UInt8._tab }

        @inline(__always)
        @discardableResult
        mutating func consumeWhitespace() throws -> UInt8 {
            var ptr = self.readPtr
            while ptr < endPtr {
                let ascii = ptr.pointee
                if Self.whitespaceBitmap & (1 << ascii) != 0 {
                    ptr += 1
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

        mutating func skipUTF8StringTillNextUnescapedQuote(isSimple: inout Bool) throws {
            // Skip the open quote.
            guard let shouldBeQuote = self.read() else {
                throw JSONError.unexpectedEndOfFile
            }
            guard shouldBeQuote == ._quote else {
                throw JSONError.unexpectedCharacter(ascii: shouldBeQuote, location: sourceLocation)
            }

            // If there aren't any escapes, then this is a simple case and we can exit early.
            if try skipUTF8StringTillQuoteOrBackslashOrInvalidCharacter() == ._quote {
                isSimple = true
                return
            }

            while let byte = self.peek() {
                // Checking for invalid control characters deferred until parse time.
                switch byte {
                case ._quote:
                    isSimple = false
                    return
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
            precondition(firstChar == ._backslash, "Expected to have an backslash first")

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
            guard readPtr.pointee != ._quote,
                  (readPtr+1).pointee != ._quote,
                  (readPtr+2).pointee != ._quote,
                  (readPtr+3).pointee != ._quote
            else {
                let hexString = String(decoding: UnsafeBufferPointer(start: readPtr, count: 4), as: UTF8.self)
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
}

// MARK: - Deferred Parsing Methods -

extension JSONScanner {

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
        case UInt8(ascii:"\\"): string.append("\\")
        case UInt8(ascii:"/"): string.append("/")
        case UInt8(ascii:"b"): string.append("\u{08}") // \b
        case UInt8(ascii:"f"): string.append("\u{0C}") // \f
        case UInt8(ascii:"n"): string.append("\u{0A}") // \n
        case UInt8(ascii:"r"): string.append("\u{0D}") // \r
        case UInt8(ascii:"t"): string.append("\u{09}") // \t
        case UInt8(ascii:"u"):
            try parseUnicodeSequence(into: &string, cursor: &cursor, end: end, docStart: docStart)
        default:
            throw JSONError.unexpectedEscapedCharacter(ascii: ascii, location: .sourceLocation(at: cursor, docStart: docStart))
        }
    }

    // Shared with JSON5, which requires allowNulls = false for compatibility.
    internal static func parseUnicodeSequence(into string: inout String, cursor: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>, allowNulls: Bool = true) throws {
        // we build this for utf8 only for now.
        let bitPattern = try parseUnicodeHexSequence(cursor: &cursor, end: end, docStart: docStart, allowNulls: allowNulls)

        // check if lead surrogate
        if UTF16.isLeadSurrogate(bitPattern) {
            // if we have a lead surrogate we expect a trailing surrogate next
            let leadSurrogateBitPattern = bitPattern
            guard end - cursor >= 2 else {
                throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: cursor, docStart: docStart))
            }
            let escapeChar = cursor.pointee
            let uChar = (cursor+1).pointee
            guard escapeChar == ._backslash, uChar == UInt8(ascii: "u") else {
                throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: cursor, docStart: docStart))
            }
            cursor += 2

            let trailSurrogateBitPattern = try parseUnicodeHexSequence(cursor: &cursor, end: end, docStart: docStart)
            guard UTF16.isTrailSurrogate(trailSurrogateBitPattern) else {
                throw JSONError.expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: .sourceLocation(at: cursor-6, docStart: docStart))
            }

            let encodedScalar = UTF16.EncodedScalar([leadSurrogateBitPattern, trailSurrogateBitPattern])
            let unicode = UTF16.decode(encodedScalar)
            string.unicodeScalars.append(unicode)
        } else {
            guard let unicode = Unicode.Scalar(bitPattern) else {
                throw JSONError.couldNotCreateUnicodeScalarFromUInt32(location: .sourceLocation(at: cursor-6, docStart: docStart), unicodeScalarValue: UInt32(bitPattern))
            }
            string.unicodeScalars.append(unicode)
        }
    }

    internal static func parseUnicodeHexSequence(cursor: inout UnsafePointer<UInt8>, end: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>, allowNulls: Bool = true) throws -> UInt16 {
        precondition(end - cursor >= 4, "Scanning should have ensured that all escape sequences are valid shape")

        guard let first = cursor.pointee.hexDigitValue,
              let second = (cursor+1).pointee.hexDigitValue,
              let third = (cursor+2).pointee.hexDigitValue,
              let fourth = (cursor+3).pointee.hexDigitValue
        else {
            let hexString = String(decoding: UnsafeBufferPointer(start: cursor, count: 4), as: Unicode.UTF8.self)
            throw JSONError.invalidHexDigitSequence(hexString, location: .sourceLocation(at: cursor, docStart: docStart))
        }
        let firstByte = UInt16(first) << 4 | UInt16(second)
        let secondByte = UInt16(third) << 4 | UInt16(fourth)

        let result = UInt16(firstByte) << 8 | UInt16(secondByte)
        guard allowNulls || result != 0 else {
            throw JSONError.invalidEscapedNullValue(location: .sourceLocation(at: cursor, docStart: docStart))
        }
        cursor += 4
        return result
    }


    // MARK: Numbers

    static func validateLeadingZero(in jsonBytes: UnsafeBufferPointer<UInt8>, following cursor: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) throws {
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
        case _asciiNumbers:
            throw JSONError.numberWithLeadingZero(location: .sourceLocation(at: next, docStart: docStart))
        default:
            throw JSONError.unexpectedCharacter(context: "in number", ascii: next.pointee, location: .sourceLocation(at: next, docStart: docStart))
        }
    }

    // Returns the pointer at which the number's digits begin. If there are no digits, the function throws.
    static func prevalidateJSONNumber(from jsonBytes: UnsafeBufferPointer<UInt8>, hasExponent: Bool, docStart: UnsafePointer<UInt8>) throws -> UnsafePointer<UInt8> {
        // Just make sure we (A) don't have a leading zero, and (B) We have at least one digit.
        guard !jsonBytes.isEmpty else {
            preconditionFailure("Why was this function called, if there is no 0...9 or -")
        }
        let startPtr = jsonBytes.baseAddress.unsafelyUnwrapped
        let endPtr = startPtr + jsonBytes.count
        let digitsBeginPtr : UnsafePointer<UInt8>
        switch startPtr.pointee {
        case UInt8(ascii: "0"):
            try validateLeadingZero(in: jsonBytes, following: startPtr, docStart: docStart)
            digitsBeginPtr = startPtr
        case UInt8(ascii: "1") ... UInt8(ascii: "9"):
            digitsBeginPtr = startPtr
        case UInt8(ascii: "-"):
            let next = startPtr+1
            guard next < endPtr else {
                throw JSONError.unexpectedCharacter(context: "at end of number", ascii: startPtr.pointee, location: .sourceLocation(at: endPtr-1, docStart: docStart))
            }
            switch next.pointee {
            case UInt8(ascii: "0"):
                try validateLeadingZero(in: jsonBytes, following: next, docStart: docStart)
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                // Good, we need at least one digit following the '-'
                break
            default:
                // Any other character is invalid.
                throw JSONError.unexpectedCharacter(context: "after '-' in number", ascii: startPtr.pointee, location: .sourceLocation(at: next, docStart: docStart))
            }
            digitsBeginPtr = next
        default:
            preconditionFailure("Why was this function called, if there is no 0...9 or -")
        }

        // If the number was found to have an exponent, we have to guarantee that there are digits preceding it, which is a JSON requirement. If we don't, then our floating point parser, which is tolerant of that construction, will succeed and not produce the required error.
        if hasExponent {
            var cursor = digitsBeginPtr+1
            while cursor < endPtr {
                switch cursor.pointee {
                case UInt8(ascii: "e"), UInt8(ascii: "E"):
                    guard case _asciiNumbers = (cursor-1).pointee else {
                        throw JSONError.unexpectedCharacter(context: "in number", ascii: cursor.pointee, location: .sourceLocation(at: cursor, docStart: docStart))
                    }
                    // We're done iterating.
                    cursor = endPtr
                default:
                    cursor += 1
                }
            }
        }

        switch jsonBytes.last.unsafelyUnwrapped {
        case _asciiNumbers:
            break // In JSON, all numbers must end with a digit.
        default:
            throw JSONError.unexpectedCharacter(context: "at end of number", ascii: jsonBytes.last.unsafelyUnwrapped, location: .sourceLocation(at: endPtr-1, docStart: docStart))
        }
        return digitsBeginPtr
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

        cursor = digitsBeginPtr + 1

        // Fast-path, assume all digits.
        while cursor < endPtr {
            let byte = cursor.pointee
            if _asciiNumbers.contains(byte) {
                cursor += 1
            } else {
                break
            }
        }
        if cursor == endPtr {
            // They were all digits. We're done!
            // TODO: This should preconditionFailure() I think. Same for regular JSON.
            return
        }

        var pastControlChar: ControlCharacter = .operand
        var numbersSinceControlChar = cursor - digitsBeginPtr

        // parse everything else
        while cursor < endPtr {
            let byte = cursor.pointee
            switch byte {
            case UInt8(ascii: "0"):
                numbersSinceControlChar += 1
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                numbersSinceControlChar += 1
            case UInt8(ascii: "."):
                guard numbersSinceControlChar > 0, pastControlChar == .operand else {
                    throw JSONError.unexpectedCharacter(context: "in number", ascii: byte, location: .sourceLocation(at: cursor, docStart: docStart))
                }

                pastControlChar = .decimalPoint
                numbersSinceControlChar = 0

            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                guard numbersSinceControlChar > 0,
                      pastControlChar == .operand || pastControlChar == .decimalPoint
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

        guard numbersSinceControlChar > 0 else {
            preconditionFailure("Found trailing non-digit. Number character buffer was not validated with prevalidateJSONNumber()")
        }
    }
}

// Protocol conformed to by the numeric types we parse. For each of them, the
protocol PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: UnsafeBufferPointer<UInt8>)
}

extension Double : PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: UnsafeBufferPointer<UInt8>) {
        let bufferEnd = buffer.baseAddress.unsafelyUnwrapped + buffer.count
        var endPtr : UnsafeMutablePointer<CChar>? = nil
        let result = withUnsafeMutablePointer(to: &endPtr) {
            strtod_l(buffer.baseAddress, $0, nil)
        }
        guard let endPtr, endPtr == bufferEnd else {
            return nil
        }
        self = result
    }
}

extension Float : PrevalidatedJSONNumberBufferConvertible {
    init?(prevalidatedBuffer buffer: UnsafeBufferPointer<UInt8>) {
        let bufferEnd = buffer.baseAddress.unsafelyUnwrapped + buffer.count
        var endPtr : UnsafeMutablePointer<CChar>? = nil
        let result = withUnsafeMutablePointer(to: &endPtr) {
            strtof_l(buffer.baseAddress, $0, nil)
        }
        guard let endPtr, endPtr == bufferEnd else {
            return nil
        }
        self = result
    }
}

@_alwaysEmitIntoClient
internal func _parseIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: UnsafeBufferPointer<UInt8>, isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8

    let numericalUpperBound: UInt8 = _0 &+ 10
    let multiplicand : Result = 10
    var result : Result = 0

    var iter = codeUnits.makeIterator()
    while let digit = iter.next() {
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

@_alwaysEmitIntoClient
internal func _parseInteger<Result: FixedWidthInteger>(_ codeUnits: UnsafeBufferPointer<UInt8>) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _plus = 43 as UInt8, _minus = 45 as UInt8

    let first = codeUnits[0]
    if first == _minus {
        return _parseIntegerDigits(UnsafeBufferPointer(rebasing: codeUnits[1...]), isNegative: true)
    }
    if first == _plus {
        return _parseIntegerDigits(UnsafeBufferPointer(rebasing: codeUnits[1...]), isNegative: false)
    }
    return _parseIntegerDigits(codeUnits, isNegative: false)
}

extension FixedWidthInteger {
    init?(prevalidatedBuffer buffer: UnsafeBufferPointer<UInt8>) {
        guard let val : Self = _parseInteger(buffer) else {
            return nil
        }
        self = val
    }
}

extension UInt8 {

    internal static var _space: UInt8 { UInt8(ascii: " ") }
    internal static var _return: UInt8 { UInt8(ascii: "\r") }
    internal static var _newline: UInt8 { UInt8(ascii: "\n") }
    internal static var _tab: UInt8 { UInt8(ascii: "\t") }

    internal static var _colon: UInt8 { UInt8(ascii: ":") }
    internal static var _comma: UInt8 { UInt8(ascii: ",") }

    internal static var _openbrace: UInt8 { UInt8(ascii: "{") }
    internal static var _closebrace: UInt8 { UInt8(ascii: "}") }

    internal static var _openbracket: UInt8 { UInt8(ascii: "[") }
    internal static var _closebracket: UInt8 { UInt8(ascii: "]") }

    internal static var _quote: UInt8 { UInt8(ascii: "\"") }
    internal static var _backslash: UInt8 { UInt8(ascii: "\\") }

}

internal var _asciiNumbers: ClosedRange<UInt8> { UInt8(ascii: "0") ... UInt8(ascii: "9") }
internal var _hexCharsUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "F") }
internal var _hexCharsLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "f") }
internal var _allLettersUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "Z") }
internal var _allLettersLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "z") }

extension UInt8 {
    internal var hexDigitValue: UInt8? {
        switch self {
        case _asciiNumbers:
            return self - _asciiNumbers.lowerBound
        case _hexCharsUpper:
            // uppercase letters
            return self - _hexCharsUpper.lowerBound &+ 10
        case _hexCharsLower:
            // lowercase letters
            return self - _hexCharsLower.lowerBound &+ 10
        default:
            return nil
        }
    }

    internal var isValidHexDigit: Bool {
        switch self {
        case _asciiNumbers, _hexCharsUpper, _hexCharsLower:
            return true
        default:
            return false
        }
    }
}

enum JSONError: Swift.Error, Equatable {
    struct SourceLocation: Equatable {
        let line: Int
        let column: Int
        let index: Int

        static func sourceLocation(at location: UnsafePointer<UInt8>, docStart: UnsafePointer<UInt8>) -> SourceLocation {
            precondition(docStart <= location)
            var cursor = docStart
            var line = 1
            var col = 0
            while cursor <= location {
                switch cursor.pointee {
                case ._return:
                    if cursor+1 <= location, cursor.pointee == ._newline {
                        cursor += 1
                    }
                    line += 1
                    col = 0
                case ._newline:
                    line += 1
                    col = 0
                default:
                    col += 1
                }
                cursor += 1
            }
            return SourceLocation(line: line, column: col, index: location - docStart)
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
