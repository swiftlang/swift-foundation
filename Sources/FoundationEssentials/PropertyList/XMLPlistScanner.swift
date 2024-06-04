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

internal import _FoundationCShims

private let plistBytes : StaticString = "plist"
private let arrayBytes : StaticString = "array"
private let dictBytes : StaticString = "dict"
private let keyBytes : StaticString = "key"
private let stringBytes : StaticString = "string"
private let dataBytes : StaticString = "data"
private let dateBytes : StaticString = "date"
private let realBytes : StaticString = "real"
private let integerBytes : StaticString = "integer"
private let trueBytes : StaticString = "true"
private let falseBytes : StaticString = "false"

private let docType : StaticString = "DOCTYPE"
private let cdSect : StaticString = "<![CDATA["
private let cfuid : StaticString = "CF$UID"

enum XMLPlistTag {
    case plist
    case array
    case dict
    case key
    case string
    case data
    case date
    case real
    case integer
    case `true`
    case `false`

    @inline(__always)
    func withTagUTF8<T>( _ handler: (_ bytePtr: UnsafePointer<UInt8>, _ length: Int) -> T ) -> T {
        switch self {
            case .plist:
                return handler(plistBytes.utf8Start, plistBytes.utf8CodeUnitCount)
            case .array:
                return handler(arrayBytes.utf8Start, arrayBytes.utf8CodeUnitCount)
            case .dict:
                return handler(dictBytes.utf8Start, dictBytes.utf8CodeUnitCount)
            case .key:
                return handler(keyBytes.utf8Start, keyBytes.utf8CodeUnitCount)
            case .string:
                return handler(stringBytes.utf8Start, stringBytes.utf8CodeUnitCount)
            case .data:
                return handler(dataBytes.utf8Start, dataBytes.utf8CodeUnitCount)
            case .date:
                return handler(dateBytes.utf8Start, dateBytes.utf8CodeUnitCount)
            case .real:
                return handler(realBytes.utf8Start, realBytes.utf8CodeUnitCount)
            case .integer:
                return handler(integerBytes.utf8Start, integerBytes.utf8CodeUnitCount)
            case .true:
                return handler(trueBytes.utf8Start, trueBytes.utf8CodeUnitCount)
            case .false:
                return handler(falseBytes.utf8Start, falseBytes.utf8CodeUnitCount)
        }
    }

    @inline(__always)
    var tagLength : Int {
        switch self {
            case .plist: return plistBytes.utf8CodeUnitCount
            case .array: return arrayBytes.utf8CodeUnitCount
            case .dict: return dictBytes.utf8CodeUnitCount
            case .key: return keyBytes.utf8CodeUnitCount
            case .string: return stringBytes.utf8CodeUnitCount
            case .data: return dataBytes.utf8CodeUnitCount
            case .date: return dateBytes.utf8CodeUnitCount
            case .real: return realBytes.utf8CodeUnitCount
            case .integer: return integerBytes.utf8CodeUnitCount
            case .true: return trueBytes.utf8CodeUnitCount
            case .false: return falseBytes.utf8CodeUnitCount
        }
    }

    var tagName: StaticString {
        switch self {
            case .plist: return plistBytes
            case .array: return arrayBytes
            case .dict: return dictBytes
            case .key: return keyBytes
            case .string: return stringBytes
            case .data: return dataBytes
            case .date: return dateBytes
            case .real: return realBytes
            case .integer: return integerBytes
            case .true: return trueBytes
            case .false: return falseBytes
        }
    }
}

typealias XMLPlistMapOffset = Int

class XMLPlistMap : PlistDecodingMap {
    enum TypeDescriptor : Int {
        case string  // [marker, count, sourceByteOffset]
        case key     // [marker, count, sourceByteOffset]
        case real    // [marker, count, sourceByteOffset]
        case integer // [marker, count, sourceByteOffset]
        case data    // [marker, count, sourceByteOffset]
        case date    // [marker, count, sourceByteOffset]
        case `true`  // [marker]
        case `false` // [marker]

        case array   // [marker, nextSiblingOffset, count, <keys and values>, .collectionEnd]
        case dict    // [marker, nextSiblingOffset, count, <values>, .collectionEnd]
        case collectionEnd

        case nullSentinel // [marker]
        case simpleString // [marker, count, sourceByteOffset]
        case simpleKey    // [marker, count, sourceByteOffset]

        @inline(__always)
        var mapMarker : Int {
            rawValue
        }

        init(_ tag: XMLPlistTag) {
            switch tag {
            case .string: self = .string
            case .key: self = .key
            case .real: self = .real
            case .integer: self = .integer
            case .data: self = .data
            case .date: self = .date
            case .true: self = .true
            case .false: self = .false
            case .array: self = .array
            case .dict: self = .dict
            case .plist: fatalError("Type descriptor not applicable to <plist> tag")
            }
        }
    }

    internal indirect enum Value {
        case string(Region, isKey: Bool, isSimple: Bool)
        case array(startOffset: Int, count: Int)
        case dict(startOffset: Int, count: Int)
        case data(Region)
        case date(Region)
        case boolean(Bool)
        case real(Region)
        case integer(Region)
        case null
        
        case uid // UNUSED by PropertyListDecoder.
    }

    struct Region {
        let startOffset: Int
        let count: Int
    }
    
    @inline(__always)
    static var nullValue: Value { .null }

    let mapBuffer : [Int]
    var dataLock : LockedState<(buffer: BufferView<UInt8>, allocation: UnsafeRawPointer?)>

    init(mapBuffer: [Int], dataBuffer: BufferView<UInt8>) {
        self.mapBuffer = mapBuffer
        self.dataLock = .init(initialState: (buffer: dataBuffer, allocation: nil))
    }

    deinit {
        dataLock.withLock {
            if let allocatedPointer = $0.allocation {
                precondition($0.buffer.startIndex == BufferViewIndex(rawValue: allocatedPointer))
                allocatedPointer.deallocate()
            }
        }
    }

    var topObject : Value {
        loadValue(at: 0)!
    }
    
    @inline(__always)
    func value(from reference: Value) throws -> Value {
        return reference
    }

    @inline(__always)
    func withBuffer<T>(
      for region: Region, perform closure: @Sendable (_ jsonBytes: BufferView<UInt8>, _ fullSource: BufferView<UInt8>) throws -> T
    ) rethrows -> T {
        try dataLock.withLock {
            return try closure($0.buffer[region], $0.buffer)
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

    func loadValue(at mapOffset: XMLPlistMapOffset) -> Value? {
        let marker = mapBuffer[mapOffset]
        switch TypeDescriptor(rawValue: marker) {
        case .array:
            let count = mapBuffer[mapOffset + 2]
            let objsOffset = mapOffset + 3
            return .array(startOffset: objsOffset, count: count)
        case .dict:
            let count = mapBuffer[mapOffset + 2]
            let objsOffset = mapOffset + 3
            
            // NSKeyedArchiver UIDs are encoded as single element dictionaries with a key of "CF$UID". This is the best time to detect those and return the correct value so that clients aren't tricked into decoding these as [String:Int32].
            if detectUID(dictionaryReferenceCount: count, objectOffset: objsOffset) {
                return .uid
            }
            
            return .dict(startOffset: objsOffset, count: count)
        case .key, .string, .simpleKey, .simpleString:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            let isKey = marker == TypeDescriptor.key.mapMarker || marker == TypeDescriptor.simpleKey.mapMarker
            let isSimple = marker == TypeDescriptor.simpleKey.mapMarker || marker == TypeDescriptor.simpleString.mapMarker
            return .string(.init(startOffset: dataOffset, count: length), isKey: isKey, isSimple: isSimple)
        case .data:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .data(.init(startOffset: dataOffset, count: length))
        case .date:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .date(.init(startOffset: dataOffset, count: length))
        case .real:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .real(.init(startOffset: dataOffset, count: length))
        case .integer:
            let length = mapBuffer[mapOffset + 1]
            let dataOffset = mapBuffer[mapOffset + 2]
            return .integer(.init(startOffset: dataOffset, count: length))
        case .true:
            return .boolean(true)
        case .false:
            return .boolean(false)
        case .nullSentinel:
            return .null
        case .collectionEnd:
            return nil
        case .none:
            fatalError("Invalid plist tag value in mapping: \(marker))")
        }
    }
    
    private func detectUID(dictionaryReferenceCount count: Int, objectOffset objsOffset: XMLPlistMapOffset) -> Bool {
        if count == 2,
           mapBuffer[objsOffset] == TypeDescriptor.simpleKey.mapMarker,
           mapBuffer[objsOffset + 1] == cfuid.utf8CodeUnitCount {
            
            // OK, we've peeked enough into this first key to justify loading and examining the entire value.
            if case let .string(region, _, _) = loadValue(at: objsOffset) {
                return self.withBuffer(for: region) { bufferView, _ in
                    bufferView.withUnsafeRawPointer { ptr, _ in
                        cfuid.withUTF8Buffer { cfuidBuf in
                            memcmp(ptr, cfuidBuf.baseAddress!, cfuid.utf8CodeUnitCount) == 0
                        }
                    }
                }
            }
        }
        return false
    }

    func offset(after previousValueOffset: XMLPlistMapOffset) -> XMLPlistMapOffset {
        let marker = mapBuffer[previousValueOffset]
        let type = TypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString, .key, .simpleKey, .real, .integer, .data, .date:
            return previousValueOffset + 3 // Skip marker, length, and data offset
        case .true, .false, .nullSentinel:
            return previousValueOffset + 1 // Skip only the marker.
        case .dict, .array:
            // The collection records the offset to the next sibling
            return mapBuffer[previousValueOffset + 1]
        case .collectionEnd:
            fatalError("Attempt to find next object past the end of collection at offset \(previousValueOffset))")
        case .none:
            fatalError("Invalid XML value type code in mapping: \(marker))")
        }
    }

    struct ArrayIterator: PlistArrayIterator {
        var currentOffset: Int
        let map : XMLPlistMap

        mutating func next() -> XMLPlistMap.Value? {
            guard let next = peek() else {
                return nil
            }
            advance()
            return next
        }

        func peek() -> XMLPlistMap.Value? {
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

    struct DictionaryIterator: PlistDictionaryIterator {
        var currentOffset: Int
        let map : XMLPlistMap

        mutating func next() -> (key: XMLPlistMap.Value, value: XMLPlistMap.Value)? {
            let keyOffset = currentOffset
            guard let key = map.loadValue(at: currentOffset) else {
                return nil
            }
            let valueOffset = map.offset(after: keyOffset)
            guard let value = map.loadValue(at: valueOffset) else {
                preconditionFailure("XMLPlistMap object constructed incorrectly. No value found for key")
            }
            currentOffset = map.offset(after: valueOffset)
            return (key, value)
        }
    }

    func makeDictionaryIterator(from offset: Int) -> DictionaryIterator {
        return .init(currentOffset: offset, map: self)
    }
}

internal let dataDecodeTable =
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

extension XMLPlistMap.Value {
    func dataValue(in map: XMLPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Data {
        guard case let .data(region) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Data.self, reality: self)
        }

        return try map.withBuffer(for: region) { buffer, fullSource in
            var reader = BufferReader(bytes: buffer, fullSource: fullSource)

            var numEq = 0
            var acc = 0
            var cntr = 0
            var bytes = [UInt8]()
            while let c = reader.peek() {
                if c == ._openangle {
                    break
                } else if c == ._equal {
                    numEq += 1
                } else if isspace(Int32(c)) != 0 {
                    numEq = 0
                }

                guard c < dataDecodeTable.count else {
                    throw DecodingError._dataCorrupted("Could not interpret <data> on line \(reader.lineNumber) (invalid character \(String(c, radix: 16, uppercase: true))", for: codingPathNode, additionalKey)
                }

                let decoded = dataDecodeTable[Int(c)]
                guard decoded >= 0 else {
                    reader.advance()
                    continue
                }

                cntr += 1
                acc = acc << 6 + decoded

                if 0 == (cntr & 0x3) {
                    let byte1 = UInt8(truncatingIfNeeded: acc >> 16)
                    let byte2 = UInt8(truncatingIfNeeded: acc >> 8)
                    let byte3 = UInt8(truncatingIfNeeded: acc)
                    if _fastPath(numEq == 0) {
                        bytes.append(contentsOf: [byte1, byte2, byte3])
                    } else if numEq == 1 {
                        bytes.append(contentsOf: [byte1, byte2])
                    } else {
                        bytes.append(byte1)
                    }
                }
                reader.advance()
            }
            return Data(bytes)
        }
    }

    // YYYY '-' MM '-' DD 'T' hh ':' mm ':' ss 'Z'
    // NOTE: The DTD claims that smaller units can be omitted, but the old C implementation doesn't accept this.
    func dateValue(in map: XMLPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> Date {
        guard case let .date(region) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Date.self, reality: self)
        }

        return try map.withBuffer(for: region) { buffer, fullSource in
            var reader = BufferReader(bytes: buffer, fullSource: fullSource)

            var badForm = false
            var yearIsNegative = false

            func read2DigitNumber() -> Int? {
                guard let (ch1, ch2) = reader.peek() else {
                    return nil
                }
                reader.advance(2)

                guard let dig1 = ch1.digitValue,
                      let dig2 = ch2.digitValue else {
                    return nil
                }

                return dig1 &* 10 + dig2
            }

            if reader.peek() == ._minus {
                yearIsNegative = true
                reader.advance()
            }

            var year = 0
            while let ch = reader.peek(),
                  let curDigit = ch.digitValue {
                let overflow: Bool
                let overflow2: Bool
                (year, overflow) = year.multipliedReportingOverflow(by: 10)
                (year, overflow2) = year.addingReportingOverflow(curDigit)
                reader.advance()

                guard !overflow, !overflow2 else {
                    badForm = true
                    break
                }
            }
            if reader.peek() != ._minus {
                badForm = true
            } else {
                reader.advance()
            }

            let month : Int
            if !badForm, let m = read2DigitNumber(), reader.peek() == ._minus {
                month = m
            } else {
                badForm = true
                month = -1
            }
            if !badForm { reader.advance() }

            let day : Int
            if !badForm, let d = read2DigitNumber(), reader.peek() == UInt8(ascii: "T") {
                day = d
            } else {
                badForm = true
                day = -1
            }
            if !badForm { reader.advance() }

            let hour : Int
            if !badForm, let h = read2DigitNumber(), reader.peek() == ._colon {
                hour = h
            } else {
                badForm = true
                hour = -1
            }
            if !badForm { reader.advance() }

            let minute : Int
            if !badForm, let m = read2DigitNumber(), reader.peek() == ._colon {
                minute = m
            } else {
                badForm = true
                minute = -1
            }
            if !badForm { reader.advance() }

            let second : Int
            if !badForm, let s = read2DigitNumber(), reader.peek() == UInt8(ascii: "Z") {
                second = s
            } else {
                badForm = true
                second = -1
            }
            if !badForm { reader.advance() }

            guard !badForm else {
                throw DecodingError._dataCorrupted("Could not interpret <date> at line \(reader.lineNumber)", for: codingPathNode, additionalKey)
            }

            if let ch = reader.peek() {
                // This really shouldn't ever happen, given how this subrange was calculated, but just in case.
                throw DecodingError._dataCorrupted("Encountered unexpected character \(Character(UnicodeScalar(ch))) at line \(reader.lineNumber) while parsing date", for: codingPathNode, additionalKey)
            }

            var c = Calendar(identifier: .iso8601)
            c.timeZone = .gmt

            let dc = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
            if let date = c.date(from: dc) {
                return date
            } else {
                return Date(gregorianYear: Int64(yearIsNegative ? -year : year), month: Int8(month), day: Int8(day), hour: Int8(hour), minute: Int8(minute), second: Double(second))
            }
        }
    }

    internal func _skipIntegerWhitespace(_ reader: inout BufferReader) {
        while let byte1 = reader.peek() {
            // Integer parsing has historically had a very inclusive whitespace check.
            // We consider some additional values from 0x0 to 0x21 and 0x7E to 0xA1 as whitespace, for compatibility
            if byte1 < 0x21 || (byte1 > 0x7E && byte1 < 0xA1) {
                reader.advance()
                continue
            }
            let (scalar, length) = reader.remainingBuffer._decodeScalar()
            if let scalar, scalar.properties.isWhitespace {
                reader.advance(length)
                continue
            } else {
                break
            }
        }
    }

    internal func _parseXMLPlistInteger<Result: FixedWidthInteger>(_ reader: inout BufferReader) -> Result? {
        guard _fastPath(!reader.isAtEnd) else { return nil }

        // XMLPlist integers allow whitespace in between the +/- and the rest of the integer.
        let first = reader.peek()
        var isNegative = false
        if first == ._minus {
            reader.advance()
            isNegative = true
            _skipIntegerWhitespace(&reader)
        } else if first == ._plus {
            reader.advance()
            _skipIntegerWhitespace(&reader)
        }

        let isHex: Bool
        if let (zeroChar, xChar) = reader.peek() {
            isHex = zeroChar == UInt8(ascii: "0") && (xChar == UInt8(ascii: "x") || xChar == UInt8(ascii: "X"))
            if isHex {
                reader.advance(2)
            }
        } else {
            isHex = false
        }

        // Trust the caller regarding whether this is valid hex data.
        if isHex {
            return _parseHexIntegerDigits(reader.remainingBuffer, isNegative: isNegative)
        } else {
            return _parseIntegerDigits(reader.remainingBuffer, isNegative: isNegative)
        }
    }

    func integerValue<T: FixedWidthInteger>(in map: XMLPlistMap, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        if case .real = self {
            let double = try self.realValue(in: map, as: Double.self, for: codingPathNode, additionalKey)
            guard let integer = T(exactly: double) else {
                throw DecodingError._dataCorrupted("Parsed property list number <\(double)> does not fit in \(type).", for: codingPathNode, additionalKey)
            }
            return integer
        }

        guard case let .integer(region) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: type, reality: self)
        }

        return try map.withBuffer(for: region) { buffer, fullSource in
            var reader = BufferReader(bytes: buffer, fullSource: fullSource)

            // decimal_constant         S*(-|+)?S*[0-9]+        (S == space)
            // hex_constant        S*(-|+)?S*0[xX][0-9a-fA-F]+    (S == space)

            _skipIntegerWhitespace(&reader)

            guard !reader.isAtEnd else {
                throw DecodingError._dataCorrupted("Encountered empty <integer> on line \(reader.lineNumber)", for: codingPathNode, additionalKey)
            }

            guard let value: T = _parseXMLPlistInteger(&reader) else {
                throw DecodingError._dataCorrupted("Invalid <integer> value on line \(reader.lineNumber)", for: codingPathNode, additionalKey)
            }
            return value
        }
    }
    
    private static func parseSpecialRealValue<T: BinaryFloatingPoint>(_ bytes: BufferView<UInt8>, fullSource: BufferView<UInt8>, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T? {
        let specialValue: T? = try bytes.withUnsafeBufferPointer { buf in
            switch (buf.first, buf.count) {
            case (UInt8(ascii: "n"), 3), (UInt8(ascii: "N"), 3):
                if (buf[1] == UInt8(ascii: "a") || buf[1] == UInt8(ascii: "A")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")) {
                    return .nan
                }
            case (UInt8(ascii: "+"), 9):
                if _stringshims_strncasecmp_l(buf.baseAddress, "+infinity", 9, nil) == 0 {
                    return .infinity
                }
            case (UInt8(ascii: "+"), 4):
                if (buf[1] == UInt8(ascii: "i") || buf[1] == UInt8(ascii: "I")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")),
                   (buf[3] == UInt8(ascii: "f") || buf[3] == UInt8(ascii: "F")) {
                    return .infinity
                }
            case (UInt8(ascii: "-"), 9):
                if _stringshims_strncasecmp_l(buf.baseAddress, "-infinity", 9, nil) == 0 {
                    return .infinity * -1
                }
            case (UInt8(ascii: "-"), 4):
                if (buf[1] == UInt8(ascii: "i") || buf[1] == UInt8(ascii: "I")),
                   (buf[2] == UInt8(ascii: "n") || buf[2] == UInt8(ascii: "N")),
                   (buf[3] == UInt8(ascii: "f") || buf[3] == UInt8(ascii: "F")) {
                    return .infinity * -1
                }
            case (UInt8(ascii: "i"), 8), (UInt8(ascii: "I"), 8):
                if _stringshims_strncasecmp_l(buf.baseAddress, "infinity", 8, nil) == 0 {
                    return .infinity
                }
            case (.none, 0):
                let reader = BufferReader(bytes: bytes, fullSource: fullSource)
                throw DecodingError._dataCorrupted("Encountered misformatted real on line \(reader.lineNumber)", for: codingPathNode, additionalKey)
            default:
                break
            }
            return nil
        }
        return specialValue
    }
    
    private static func rejectHexadecimalValues(_ bytes: BufferView<UInt8>, fullSource: BufferView<UInt8>, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws {
        var looksLikeHex = false
        Loop:
        for byte in bytes {
            switch byte {
            case ._plus, ._minus, ._space, ._tab, ._newline, ._return, UInt8(ascii: "0"): // Skip all these.
                continue
            case UInt8(ascii: "x"), UInt8(ascii: "X"):
                looksLikeHex = true
                break Loop
            default:
                // We haven't found an "x" before this. We're past the point where a valid "0x" can be found. Let strtod reject it.
                break Loop
            }
        }
        guard !looksLikeHex else {
            let reader = BufferReader(bytes: bytes, fullSource: fullSource)
            throw DecodingError._dataCorrupted("Encountered misformatted real on line \(reader.lineNumber)", for: codingPathNode, additionalKey)
        }
    }
    
    func realValue<T: BinaryFloatingPoint>(in map: XMLPlistMap, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)?) throws -> T {
        if case .integer = self {
            if let uintValue = try? self.integerValue(in: map, as: UInt64.self, for: codingPathNode, additionalKey) {
                return T(uintValue)
            }
            let intValue = try self.integerValue(in: map, as: Int64.self, for: codingPathNode, additionalKey)
            return T(intValue)
        }

        guard case let .real(region) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: type, reality: self)
        }
        
        return try map.withBuffer(for: region) { bytes, fullSource in
            // NOTE: The historical XML plist parsing code used to parse the contents of a <real> tag exactly like a string, CDATA sections and all, and then convert that parsed string to a real value. We no longer do that, because it's wrong.
            
            // Try parsing special values that XML plist accepts that strto* does not.
            if let specialValue: T = try Self.parseSpecialRealValue(bytes, fullSource: fullSource, for: codingPathNode, additionalKey) {
                return specialValue
            }

            // strto* accepts hexadecimal values, where are not valid in plist. We check for and reject these.
            try Self.rejectHexadecimalValues(bytes, fullSource: fullSource, for: codingPathNode, additionalKey)
            
            return try bytes.withUnsafePointer { ptr, count in
                var parseEndPtr : UnsafeMutablePointer<CChar>?
                let res : T
                if MemoryLayout<T>.size == MemoryLayout<Float>.size {
                    res = T(_stringshims_strtof_l(ptr, &parseEndPtr, nil))
                } else if MemoryLayout<T>.size == MemoryLayout<Double>.size {
                    res = T(_stringshims_strtod_l(ptr, &parseEndPtr, nil))
                } else {
                    preconditionFailure("Only Float and Double are currently supported by PropertyListDecoder, not \(type))")
                }
                guard ptr.advanced(by: count) == parseEndPtr! else {
                    let reader = BufferReader(bytes: bytes, fullSource: fullSource)
                    throw DecodingError._dataCorrupted("Encountered misformatted real on line \(reader.lineNumber)", for: codingPathNode, additionalKey)
                }
                return res
            }
        }
    }
}

extension XMLPlistMap.Value: DecodingErrorValueTypeDebugStringConvertible {
    var debugDataTypeDescription: String {
        switch self {
        case .string: return "a string"
        case .integer: return "an integer"
        case .real: return "a real number"
        case .array: return "an array"
        case .dict: return "a dictionary"
        case .boolean: return "a boolean"
        case .data: return "a data value"
        case .date: return "a date"
        case .null: return "a null value"
        case .uid: return "an NSKeyedArchiver UID"
        }
    }
}

internal struct XMLPlistScanner {
    var reader : BufferReader
    var partialMapData = PartialMapData()

    struct PartialMapData {
        var mapData : [Int] = []
        var prevMapDataSize = 0

        mutating func resizeIfNecessary(with reader: BufferReader) {
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
            }
        }

        mutating func recordStartCollection(tagType: XMLPlistMap.TypeDescriptor, with reader: BufferReader) -> Int {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)

            // Reserve space for the next object index and object count.
            let startIdx = mapData.count
            mapData.append(contentsOf: [0, 0])
            return startIdx
        }

        mutating func recordEndCollection(count: Int, atStartOffset startOffset: Int, with reader: BufferReader) {
            resizeIfNecessary(with: reader)

            mapData.append(XMLPlistMap.TypeDescriptor.collectionEnd.mapMarker)

            let nextValueOffset = mapData.count
            mapData.withUnsafeMutableBufferPointer {
                $0[startOffset] = nextValueOffset
                $0[startOffset + 1] = count
            }
        }

        mutating func recordEmptyCollection(tagType: XMLPlistMap.TypeDescriptor, with reader: BufferReader) {
            resizeIfNecessary(with: reader)

            let nextValueOffset = mapData.count + 4
            mapData.append(contentsOf: [tagType.mapMarker, nextValueOffset, 0, XMLPlistMap.TypeDescriptor.collectionEnd.mapMarker])
        }

        mutating func record(tagType: XMLPlistMap.TypeDescriptor, count: Int, dataOffset: Int, with reader: BufferReader) {
            resizeIfNecessary(with: reader)

            mapData.append(contentsOf: [tagType.mapMarker, count, dataOffset])
        }

        mutating func record(tagType: XMLPlistMap.TypeDescriptor, with reader: BufferReader) {
            resizeIfNecessary(with: reader)

            mapData.append(tagType.mapMarker)
        }
    }

    init(buffer: BufferView<UInt8>) {
        self.reader = BufferReader(bytes: buffer)
    }

    static func detectPossibleXMLPlist(for buffer: BufferView<UInt8>) -> Bool {
        var scanner = XMLPlistScanner(buffer: buffer)
        scanner.skipWhitespace()
        return scanner.reader.peek() == ._openangle
    }

    mutating func scanUpToNextValue(for tag: XMLPlistTag) throws -> Bool {
        while !reader.isAtEnd {
            skipWhitespace()
            guard let shouldBeOpenAngle = reader.read() else {
                throw XMLPlistError.unexpectedEndOfFile()
            }
            guard shouldBeOpenAngle == ._openangle else {
                throw XMLPlistError.unexpectedCharacter(shouldBeOpenAngle, line: reader.lineNumber, context: "while looking for open tag")
            }
            
            switch reader.peek() {
            case .none:
                throw XMLPlistError.unexpectedEndOfFile()
            case UInt8._question:
                // Processing instruction
                try skipXMLProcessingInstruction()
            case UInt8._exclamation:
                // Could be a comment
                guard let (_, ch2, ch3) = reader.peek() else {
                    throw XMLPlistError.unexpectedEndOfFile()
                }
                guard ch2 == UInt8(ascii: "-"), ch3 == UInt8(ascii: "-") else {
                    let badChar = ch2 == UInt8(ascii: "-") ? ch3 : ch2
                    throw XMLPlistError.unexpectedCharacter(badChar, line: reader.lineNumber, context: "in comment")
                }
                reader.advance(3) // Advance past !--
                try skipXMLComment()
            case UInt8._forwardslash:
                // We got to the end tag for the element whose content we're parsing
                reader.advance(-1) // Back off to the '<'
                return false
            default:
                return true
            }
        }

        throw XMLPlistError.unexpectedEndOfFile(context: "while looking for close tag for \(tag.tagName)")
    }

    // Returns false when we hit an end tag.
    mutating func scanAnyValue(for tag: XMLPlistTag) throws -> Bool {
        guard try scanUpToNextValue(for: tag) else {
            return false
        }
        try scanXMLElement()
        return true
    }

    mutating func scanKey() throws -> Bool {
        guard try scanUpToNextValue(for: .dict) else {
            return false
        }
        let (tag, _) = try peekXMLElement()
        guard tag == .key else {
            throw XMLPlistError.other("Non key string used as key in dictionary")
        }
        // Apparently empty keys are allowed by the original implementation.
        try scanString(asKey: true)
        try checkForCloseTag(.key)
        return true
    }

    @inline(__always)
    func matches(tag: XMLPlistTag, at location: BufferViewIndex<UInt8>, until endIdx : BufferViewIndex<UInt8>) -> Bool {
        tag.withTagUTF8 { ptr, len in
            if location.distance(to: endIdx) < len { return false }
            return reader.string(at: location, matches: ptr, length: len)
        }
    }
    
    func determineTag() throws -> XMLPlistTag? {
        let marker = reader.readIndex
        switch reader.char(at: marker) {
        case UInt8(ascii: "a"): // Array
            if matches(tag: .array, at: marker, until: reader.endIndex) {
                return .array
            }
        case UInt8(ascii: "d"): // Dictionary, data, or date
            if matches(tag: .dict, at: marker, until: reader.endIndex) {
                return .dict
            } else if matches(tag: .data, at: marker, until: reader.endIndex) {
                return .data
            } else if matches(tag: .date, at: marker, until: reader.endIndex) {
                return .date
            }
        case UInt8(ascii: "f"): // false (boolean)
            if matches(tag: .false, at: marker, until: reader.endIndex) {
                return .false
            }
        case UInt8(ascii: "i"): // integer
            if matches(tag: .integer, at: marker, until: reader.endIndex) {
                return .integer
            }
        case UInt8(ascii: "k"): // Key of a dictionary
            if matches(tag: .key, at: marker, until: reader.endIndex) {
                return .key
            }
        case UInt8(ascii: "p"): // Plist
            if matches(tag: .plist, at: marker, until: reader.endIndex) {
                return .plist
            }
        case UInt8(ascii: "r"): // real
            if matches(tag: .real, at: marker, until: reader.endIndex) {
                return .real
            }
        case UInt8(ascii: "s"): // String
            if matches(tag: .string, at: marker, until: reader.endIndex) {
                return .string
            }
        case UInt8(ascii: "t"): // true (boolean)
            if matches(tag: .true, at: marker, until: reader.endIndex) {
                return .true
            }
        case ._space, ._tab, ._newline, ._return, ._closeangle:
            throw XMLPlistError.malformedTag(line: reader.lineNumber)
        default:
            break
        }
        return nil
    }

    mutating func peekXMLElement() throws -> (XMLPlistTag, isEmpty: Bool) {
        guard let tag = try determineTag() else {
            let badTagStart = reader.readIndex
            while let ch = reader.read(), ch != ._closeangle { }
            let badTagEnd = reader.readIndex
            let markerStr = String._tryFromUTF8(reader.fullBuffer[badTagStart..<badTagEnd]) ?? "<unparseable>"
            throw XMLPlistError.other("Encountered unknown tag \(markerStr) on line \(reader.lineNumber)")
        }
        
        reader.advance(tag.tagLength)

        while let ch = reader.read(), ch != ._closeangle { }
        if reader.isAtEnd {
            throw XMLPlistError.malformedTag(line: reader.lineNumber)
        }

        // Check for a `/` preceeding the `>`.
        let isEmpty = reader.char(at: reader.fullBuffer.index(reader.readIndex, offsetBy: -2)) == ._forwardslash
        return (tag, isEmpty)
    }

    mutating func scanXMLElement() throws {
        let (tag, isEmpty) = try peekXMLElement()
        switch tag {
        case .plist:
            if isEmpty {
                throw XMLPlistError.unexpectedEmptyTag(tag, line: reader.lineNumber)
            }
            return try scanPlist()
        case .array:
            if isEmpty {
                partialMapData.recordEmptyCollection(tagType: .array, with: reader)
            } else {
                try scanArray()
            }
        case .dict:
            if isEmpty {
                partialMapData.recordEmptyCollection(tagType: .dict, with: reader)
            } else {
                try scanDict()
            }
        case .key, .string:
            let isKey = tag == .key
            if isEmpty {
                partialMapData.record(tagType: isKey ? .simpleKey : .simpleString, count: 0, dataOffset: 0, with: reader)
                return
            }
            try scanString(asKey: isKey)
            try checkForCloseTag(tag)
        case .data, .date, .real, .integer:
            guard !isEmpty else {
                throw XMLPlistError.unexpectedEmptyTag(tag, line: reader.lineNumber)
            }
            let (start, end) = try scanThroughCloseTag(tag)
            partialMapData.record(tagType: .init(tag), count: start.distance(to: end), dataOffset: reader.byteOffset(at: start), with: reader)
        case .true, .false:
            if !isEmpty {
                try checkForCloseTag(tag)
            }
            partialMapData.record(tagType: .init(tag), with: reader)
        }
    }

    // Note: this whitespace detection has not historically considered all possible Unicode white space code points.
    mutating func skipWhitespace() {
        reader.readIndex = indexOfEndOfWhitespaceBytes(after: reader.readIndex)
    }

    // Note: this whitespace detection has not historically considered all possible Unicode white space code points.
    func indexOfEndOfWhitespaceBytes(after index: BufferViewIndex<UInt8>) -> BufferViewIndex<UInt8> {
        var idx = index
        while idx < reader.endIndex {
            switch reader.char(at: idx) {
            case ._space, ._tab, ._newline, ._return:
                reader.advance(&idx)
            default:
                return idx
            }
        }
        return idx
    }

    // readIndex should be set to the first character after "<?"
    mutating func skipXMLProcessingInstruction() throws {
        let begin = reader.readIndex
        let end = reader.endIndex.advanced(by: -2) // Looking for "?>" so we need at least 2 characters
        while reader.readIndex < end {
            if reader.string(at: reader.readIndex, matches: "?>") {
                reader.advance(2)
                return
            }
            reader.advance()
        }
        reader.readIndex = begin
        throw XMLPlistError.unexpectedEndOfFile(context: "while parsing the processing instruction begun on line \(reader.lineNumber)")
    }

    // readIndex should be just past "<!--"
    mutating func skipXMLComment() throws {
        var idx = reader.readIndex
        let end = reader.endIndex.advanced(by: -3) // Need at least 3 characters to compare against
        while idx <= end {
            if reader.string(at: idx, matches: "-->") {
                reader.readIndex = idx.advanced(by: 3)
                return
            }
            reader.advance(&idx)
        }
        throw XMLPlistError.other("Unterminated comment started on line \(reader.lineNumber)")
    }

    // readIndex should be immediately after the "<!"
    mutating func skipDTD() throws {
        // First parse "DOCTYPE"
        guard reader.hasBytes(docType.utf8CodeUnitCount) && reader.string(at: reader.readIndex, matches: docType.utf8Start, length: docType.utf8CodeUnitCount) else {
            throw XMLPlistError.other("Malformed DTD on line \(reader.lineNumber)")
        }

        reader.advance(docType.utf8CodeUnitCount)
        skipWhitespace()

        // Look for either the beginning of a complex DTD or the end of the DOCTYPE structure
        while let ch = reader.read() {
            if ch == ._openbracket { // inline DTD
                // XML plist parsing has never attempted to parse inline DTDs and has always treated it as invalid syntax.
                throw XMLPlistError.unexpectedCharacter(ch, line: reader.lineNumber, context: "while parsing DTD")
            }
            if ch == ._closeangle { // End of the DTD
                return
            }
        }
        throw XMLPlistError.unexpectedEndOfFile(context: "while parsing DTD")
    }

    static func parseString(with reader: inout BufferReader, generate: Bool = false) throws -> (start: BufferViewIndex<UInt8>, end: BufferViewIndex<UInt8>, String, isNull: Bool, isSimple: Bool) {
        // Create a local sub-buffer to avoid cost of write-backs to self during this loop.
        let start = reader.readIndex
        if reader.hasBytes(_plistNull.utf8CodeUnitCount), reader.string(at: reader.readIndex, matches: _plistNull) {
            reader.advance(_plistNull.utf8CodeUnitCount)
            return (start, reader.readIndex, "", isNull: true, isSimple: true)
        }

        var mark = start
        var accumulatedString : String?

        ReadLoop:
        while let ch = reader.peek() {
            switch ch {
            case ._openangle:
                guard let (_, couldBeExclamation) = reader.peek(),
                      couldBeExclamation == ._exclamation else {
                    // This is either EOF, which is handled later, or the close tag of the string.
                    break ReadLoop
                }

                // "<!" Looks like a CDSect.

                // Accumulate enumerated section so far.
                if accumulatedString == nil {
                    if generate {
                        accumulatedString = String._tryFromUTF8(reader.fullBuffer[mark ..< reader.readIndex])
                        if accumulatedString == nil {
                            throw XMLPlistError.cannotConvertToUTF8
                        }
                    }
                } else {
                    guard let newSubstring = String._tryFromUTF8(reader.fullBuffer[mark ..< reader.readIndex]) else {
                        throw XMLPlistError.cannotConvertToUTF8
                    }
                    accumulatedString! += newSubstring
                }

                try parseCDSect_pl(reader: &reader, string: &accumulatedString)
                mark = reader.readIndex
            case ._ampersand:
                // Looks like an entity reference.
                // Accumulate enumerated section so far.
                if accumulatedString == nil {
                    if generate {
                        accumulatedString = String._tryFromUTF8(reader.fullBuffer[mark ..< reader.readIndex])
                        if accumulatedString == nil {
                            throw XMLPlistError.cannotConvertToUTF8
                        }
                    }
                } else {
                    guard let newSubstring = String._tryFromUTF8(reader.fullBuffer[mark ..< reader.readIndex]) else {
                        throw XMLPlistError.cannotConvertToUTF8
                    }
                    accumulatedString! += newSubstring
                }

                try parseEntityReference(reader: &reader, string: &accumulatedString)
                mark = reader.readIndex
            default:
                reader.advance()
            }
        }

        if generate {
            if accumulatedString == nil {
                guard let string = String._tryFromUTF8(reader.fullBuffer[start ..< reader.readIndex]) else {
                    throw XMLPlistError.cannotConvertToUTF8
                }
                return (start, reader.readIndex, string, isNull: false, isSimple: true)
            } else {
                if reader.readIndex > mark {
                    guard let newSubstring = String._tryFromUTF8(reader.fullBuffer[mark ..< reader.readIndex]) else {
                        throw XMLPlistError.cannotConvertToUTF8
                    }
                    accumulatedString! += newSubstring
                }
                return (start, reader.readIndex, accumulatedString.unsafelyUnwrapped, isNull: false, isSimple: false)
            }
        } else {
            // If we've never moved the mark up from the start position to handle a CDSect or entity reference, then it's a "simple" string.
            let isSimple = mark == start

            // The caller doesn't want the string yet. Pass back an empty string so we don't have to use optionals.
            return (start, reader.readIndex, "", isNull: false, isSimple)
        }
    }

    mutating func scanString(asKey: Bool = false) throws {
        var localReader = self.reader
        let (start, end, _, isNull, isSimple) = try XMLPlistScanner.parseString(with: &localReader, generate: false) // If we always realize the string keys as we create a keyed decoding container, then we don't need to create the string here.

        self.reader = localReader

        if isNull {
            partialMapData.record(tagType: .nullSentinel, with: reader)
        } else {
            let tagType: XMLPlistMap.TypeDescriptor
            switch (asKey, isSimple) {
            case (true, true):
                tagType = .simpleKey
            case (true, false):
                tagType = .key
            case (false, true):
                tagType = .simpleString
            case (false, false):
                tagType = .string
            }
            partialMapData.record(tagType: tagType, count: start.distance(to: end), dataOffset: reader.byteOffset(at: start), with: reader)
        }
    }

    static func parseCDSect_pl(reader: inout BufferReader, string: inout String?) throws {
        guard reader.hasBytes(cdSect.utf8CodeUnitCount) else {
            throw XMLPlistError.unexpectedEndOfFile()
        }
        guard reader.string(at: reader.readIndex, matches: cdSect.utf8Start, length: cdSect.utf8CodeUnitCount) else {
            throw XMLPlistError.other("Encountered improper CDATA opening at line \(reader.lineNumber)")
        }
        reader.advance(cdSect.utf8CodeUnitCount)
        let begin = reader.readIndex // Marks the first character of the CDATA content
        let end = reader.endIndex.advanced(by: -2) // So we can safely look 2 characters beyond p
        while reader.readIndex < end {
            if reader.string(at: reader.readIndex, matches: "]]>") {
                // Found the end!
                // TODO: CDATA sections should only contain valid XML character values. The original implementation allowed arbitrary data interpreted as UTF-8, as does this. Control characters and other arbitrary binary data (which might be interpreted successfully as UTF-8) is supposed to be rejected.
                if string != nil {
                    guard let sectionString = String._tryFromUTF8(reader.fullBuffer[begin ..< reader.readIndex]) else {
                        throw XMLPlistError.cannotConvertToUTF8
                    }
                    string!.append(sectionString)
                }
                reader.advance(3)
                return
            }
            reader.advance()
        }
        // Never found the end mark
        reader.readIndex = begin
        throw XMLPlistError.unexpectedEndOfFile()
    }

    // Only legal references are {lt, gt, amp, apos, quote, #ddd, #xAAA}
    static func parseEntityReference(reader: inout BufferReader, string: inout String?) throws {
        reader.advance() // move past the '&';
        let len = reader.readIndex.distance(to: reader.endIndex)
        guard len > 0 else {
            throw XMLPlistError.unexpectedEndOfFile()
        }

        var parsedScalar : UnicodeScalar
        switch reader.peek() {
        case UInt8(ascii: "l"), UInt8(ascii: "g"): // "lt", "gt"
            guard let (ch1, ch2, ch3) = reader.peek(),
                  ch2 == UInt8(ascii: "t"), ch3 == ._semicolon else {
                throw XMLPlistError.unknownEscape(line: reader.lineNumber)
            }
            parsedScalar = UnicodeScalar((ch1 == UInt8(ascii: "l")) ? ._openangle : ._closeangle)
            reader.advance(3)
        case UInt8(ascii: "a"): // "apos" or "amp"
            guard len >= 4 else { // Not enough characters for either conversion
                throw XMLPlistError.unexpectedEndOfFile()
            }
            if reader.string(at: reader.readIndex.advanced(by: 1), matches: "mp;") {
                parsedScalar = UnicodeScalar(._ampersand)
                reader.advance(4)
                break
            } else if len > 4, reader.string(at: reader.readIndex.advanced(by: 1), matches: "pos;") {
                parsedScalar = UnicodeScalar(._singleQuote)
                reader.advance(5)
                break
            }
            throw XMLPlistError.unknownEscape(line: reader.lineNumber)
        case UInt8(ascii: "q"): // "quote"
            guard len >= 5, reader.string(at: reader.readIndex.advanced(by: 1), matches: "uot;") else {
                throw XMLPlistError.unknownEscape(line: reader.lineNumber)
            }
            parsedScalar = UnicodeScalar(._quote)
            reader.advance(5)
        case UInt8(ascii: "#"):
            reader.advance()
            parsedScalar = try parseNumericEntityReference(reader: &reader, string: &string)
        default:
            throw XMLPlistError.unknownEscape(line: reader.lineNumber)
        }
        string?.unicodeScalars.append(parsedScalar)
    }
    
    static func parseNumericEntityReference(reader: inout BufferReader, string: inout String?) throws -> UnicodeScalar {
        var isHex = false
        if reader.peek() == UInt8(ascii: "x") {
            isHex = true
            reader.advance()
        }

        var num = UInt32(0)
        var numberOfCharactersSoFar = 0
        while let ch = reader.read() {
            numberOfCharactersSoFar += 1

            if ch == ._semicolon {
                guard let scalar = UnicodeScalar(num) else {
                    throw XMLPlistError.other("Encountered unparseable Unicode sequence at line \(reader.lineNumber) while parsing data (input did not result in a real string)")
                }
                return scalar
            } else if numberOfCharactersSoFar > 8 {
                // Note: This restriction of eight characters per numerical entity reference is historical. It is ignorant of the possibility of leading zeroes resulting in a very long number still resulting in a valid character reference.
                throw XMLPlistError.other("Encountered unparseable Unicode sequence at line \(reader.lineNumber) while parsing data (too large of a value for a Unicode sequence)")
            }

            // Overflow is not a concern since we limit the input to 8 characters.
            if !isHex {
                num = num &* 10
            } else {
                num = num &<< 4
            }

            if let digit = ch.digitValue {
                num = num &+ UInt32(digit)
            } else if !isHex {
                throw XMLPlistError.unexpectedCharacter(ch, line: reader.lineNumber, context: "while parsing decimal entity")
            } else if let hexValue = ch.hexDigitValue {
                num = num &+ UInt32(hexValue)
            } else {
                throw XMLPlistError.unexpectedCharacter(ch, line: reader.lineNumber, context: "while parsing hexadecimal entity")
            }
        }
        throw XMLPlistError.unexpectedEndOfFile()
    }
        
    mutating func scanArray() throws  {
        var count = 0
        let startOffset = partialMapData.recordStartCollection(tagType: .array, with: reader)
        defer {
            partialMapData.recordEndCollection(count: count, atStartOffset: startOffset, with: reader)
        }
        while !reader.isAtEnd, try scanAnyValue(for: .array) {
            count += 1
        }
        try checkForCloseTag(.array)
    }

    mutating func scanDict() throws {
        var count = 0
        let startOffset = partialMapData.recordStartCollection(tagType: .dict, with: reader)
        defer {
            partialMapData.recordEndCollection(count: count, atStartOffset: startOffset, with: reader)
        }
        while !reader.isAtEnd {
            guard try scanKey() else {
                break // Reached the end of the dict tag.
            }
            guard try scanAnyValue(for: .dict) else {
                throw XMLPlistError.other("Value missing for key inside <dict> at line \(reader.lineNumber)")
            }
            count += 2
        }
        try checkForCloseTag(.dict)
    }

    mutating func scanPlist() throws {
        guard try scanAnyValue(for: .plist) else {
            throw XMLPlistError.unexpectedEmptyTag(.plist, line: reader.lineNumber)
        }

        let save = reader.readIndex // Save this in case the next step fails
        if try scanAnyValue(for: .plist) {
            // Got an extra object
            reader.readIndex = save
            throw XMLPlistError.other("Encountered unexpected element at line \(reader.lineNumber) (plist can only include one object)")
        }
        try checkForCloseTag(.plist)
    }

    mutating func scanXMLPropertyList() throws -> XMLPlistMap {
        while !reader.isAtEnd {
            skipWhitespace()
            guard let shouldBeOpenAngle = reader.read() else {
                throw XMLPlistError.other("No XML content found")
            }
            guard shouldBeOpenAngle == ._openangle else {
                throw XMLPlistError.unexpectedCharacter(shouldBeOpenAngle, line: reader.lineNumber)
            }
            switch reader.peek() {
            case .none:
                throw XMLPlistError.unexpectedEndOfFile()
            case UInt8._exclamation:
                // Comment or DTD
                if let (_, ch2, ch3) = reader.peek(),
                   ch2 == ._minus,
                   ch3 == ._minus {
                    // Skip `--` and set the cursor 1 past the two dashes
                    reader.advance(3)
                    try skipXMLComment()
                } else {
                    reader.advance()
                    try skipDTD()
                }
            case UInt8._question:
                // Processing instruction
                reader.advance()
                try skipXMLProcessingInstruction()
            default:
                try scanXMLElement()
                return XMLPlistMap(mapBuffer: partialMapData.mapData, dataBuffer: self.reader.bytes)
            }
        }
        throw XMLPlistError.unexpectedEndOfFile()
    }

    mutating func scanThroughCloseTag(_ tag: XMLPlistTag) throws -> (start: BufferViewIndex<UInt8>, end: BufferViewIndex<UInt8>) {
        let start = reader.readIndex
        while let ch = reader.peek(), ch != ._openangle {
            reader.advance()
        }
        let end = reader.readIndex
        try checkForCloseTag(tag)
        return (start, end)
    }

    mutating func checkForCloseTag(_ tag: XMLPlistTag) throws {
        // 3 includes the </ and > characters.
        guard reader.hasBytes(tag.tagLength + 3) else {
            throw XMLPlistError.unexpectedEndOfFile()
        }
        let (shouldBeOpenAngle, shouldBeSlash) = reader.peek()!
        guard shouldBeOpenAngle == ._openangle && shouldBeSlash == ._forwardslash else {
            let badChar = (shouldBeOpenAngle != ._openangle) ? shouldBeOpenAngle : shouldBeSlash
            throw XMLPlistError.unexpectedCharacter(badChar, line: reader.lineNumber, context: "while looking for close tag for \(tag.tagName)")
        }
        // Check past the </
        let pastOpenBracketIndex = reader.readIndex.advanced(by: 2)
        guard matches(tag: tag, at: pastOpenBracketIndex, until: reader.endIndex) else {
            throw XMLPlistError.other("Close tag on line \(reader.lineNumber) does not match open tag \(tag.tagName)")
        }
        let indexAfterWhitespace = indexOfEndOfWhitespaceBytes(after: pastOpenBracketIndex.advanced(by: tag.tagLength))
        guard indexAfterWhitespace < reader.endIndex else {
            throw XMLPlistError.unexpectedEndOfFile()
        }
        let expectedCloseAngle = reader.char(at: indexAfterWhitespace)
        guard expectedCloseAngle == ._closeangle else {
            throw XMLPlistError.unexpectedCharacter(expectedCloseAngle, line: reader.lineNumber, context: "while looking for close tag for \(tag.tagName)")
        }
        // Advance past the end of the > character.
        reader.readIndex = indexAfterWhitespace.advanced(by: 1)
    }
}

enum XMLPlistError: Swift.Error, Equatable {
    case unexpectedEndOfFile(context: String? = nil)
    case malformedTag(line: Int)
    case unexpectedEmptyTag(XMLPlistTag, line: Int)
    case unexpectedCharacter(UInt8, line: Int, context: String? = nil)
    case unknownEscape(line: Int)
    case cannotConvertToUTF8
    case other(String)

    var debugDescription : String {
        switch self {
        case .unexpectedEndOfFile(let context):
            if let context {
                return "Encountered unexpected EOF " + context
            } else {
                return "Encountered unexpected EOF"
            }
        case let .malformedTag(line):
            return "Malformed tag on line \(line)"
        case let .unexpectedEmptyTag(tag, line):
            return "Encountered empty <\(tag.tagName)> on line \(line)"
        case let .unexpectedCharacter(ascii, line, context):
            if let context {
                return "Encountered unexpected character \(Character(UnicodeScalar(ascii))) on line \(line) " + context
            } else {
                return "Encountered unexpected character \(Character(UnicodeScalar(ascii))) on line \(line)"
            }
        case let .unknownEscape(line):
            return "Encountered unknown ampersand-escape sequence at line \(line)"
        case .cannotConvertToUTF8:
            return "Unable to convert string to correct encoding"
        case let .other(description):
            return description
        }
    }

    var cocoaError: CocoaError {
        .init(.propertyListReadCorrupt, userInfo: [
            NSDebugDescriptionErrorKey : self.debugDescription
        ])
    }
}

extension BufferView<UInt8> {
    // TODO: Here temporarily until it can be moved to CodableUtilities.swift on the FoundationPreview size
    internal subscript(region: XMLPlistMap.Region) -> BufferView {
        slice(from: region.startOffset, count: region.count)
    }

    internal subscript(unchecked region: XMLPlistMap.Region) -> BufferView {
        uncheckedSlice(from: region.startOffset, count: region.count)
    }
}
