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

extension _JSONEncoderValue {
    static func number(from num: some (FixedWidthInteger & CustomStringConvertible)) -> _JSONEncoderValue {
        return .number(num.description)
    }

    @inline(never)
    static func cannotEncodeNumber<T: BinaryFloatingPoint>(_ float: T, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) -> EncodingError {
        let path = encoder.codingPath + (additionalKey.map { [$0] } ?? [])
        return EncodingError.invalidValue(float, .init(
            codingPath: path,
            debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."
        ))
    }

    @inline(never)
    static func nonConformantNumber<T: BinaryFloatingPoint>(from float: T, with options: JSONEncoder.NonConformingFloatEncodingStrategy, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)?) throws -> _JSONEncoderValue {
        if case .convertToString(let posInfString, let negInfString, let nanString) = options {
            switch float {
            case T.infinity:
                return .string(posInfString)
            case -T.infinity:
                return .string(negInfString)
            default:
                // must be nan in this case
                return .string(nanString)
            }
        }
        throw cannotEncodeNumber(float, encoder: encoder, additionalKey)
    }

    @inline(__always)
    static func number<T: BinaryFloatingPoint & CustomStringConvertible>(from float: T, with options: JSONEncoder.NonConformingFloatEncodingStrategy, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)? = Optional<_CodingKey>.none) throws -> _JSONEncoderValue {
        guard !float.isNaN, !float.isInfinite else {
            return try nonConformantNumber(from: float, with: options, encoder: encoder, additionalKey)
        }

        var string = float.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return .number(string)
    }

    @inline(__always)
    static func number<T: BinaryFloatingPoint & CustomStringConvertible>(from float: T, encoder: __JSONEncoder, _ additionalKey: (some CodingKey)? = Optional<_CodingKey>.none) throws -> _JSONEncoderValue {
        try .number(from: float, with: encoder.options.nonConformingFloatEncodingStrategy, encoder: encoder, additionalKey)
    }
}

internal struct JSONWriter {

    // Structures with container nesting deeper than this limit are not valid.
    private static let maximumRecursionDepth = 512

    private var indent = 0
    private let pretty: Bool
    private let sortedKeys: Bool
    private let withoutEscapingSlashes: Bool

    var bytes = [UInt8]()

    init(options: JSONEncoder.OutputFormatting) {
        pretty = options.contains(.prettyPrinted)
        sortedKeys = options.contains(.sortedKeys)
        withoutEscapingSlashes = options.contains(.withoutEscapingSlashes)
    }

    mutating func serializeJSON(_ value: _JSONEncoderValue, depth: Int = 0) throws {
        switch value {
        case .string(let str):
            serializeString(str)
        case .bool(let boolValue):
            writer(boolValue ? "true" : "false")
        case .number(let numberStr):
            writer(contentsOf: numberStr.utf8)
        case .array(let array):
            try serializeArray(array, depth: depth + 1)
        case .nonPrettyDirectArray(let arrayRepresentation):
            writer(contentsOf: arrayRepresentation)
        case let .directArray(bytes, lengths):
            try serializePreformattedByteArray(bytes, lengths, depth: depth + 1)
        case .object(let object):
            try serializeObject(object, depth: depth + 1)
        case .null:
            writer("null")
        }
    }

    @inline(__always)
    mutating func writer(_ string: StaticString) {
        writer(pointer: string.utf8Start, count: string.utf8CodeUnitCount)
    }

    @inline(__always)
    mutating func writer<S: Sequence>(contentsOf sequence: S) where S.Element == UInt8 {
        bytes.append(contentsOf: sequence)
    }

    @inline(__always)
    mutating func writer(ascii: UInt8) {
        bytes.append(ascii)
    }

    @inline(__always)
    mutating func writer(pointer: UnsafePointer<UInt8>, count: Int) {
        bytes.append(contentsOf: UnsafeBufferPointer(start: pointer, count: count))
    }

    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    mutating func serializeSimpleStringContents(_ str: String) -> Int {
        let stringStart = self.bytes.endIndex
        var mutStr = str
        mutStr.withUTF8 {
            writer(contentsOf: $0)
        }
        let length = stringStart.distance(to: self.bytes.endIndex)
        return length
    }

    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    mutating func serializeSimpleString(_ str: String) -> Int {
        writer(ascii: ._quote)
        defer {
            writer(ascii: ._quote)
        }
        return self.serializeSimpleStringContents(str) + 2 // +2 for quotes.
    }

    @inline(__always)
    mutating func serializeStringContents(_ str: String) -> Int {
        let unquotedStringStart = self.bytes.endIndex
        var mutStr = str
        mutStr.withUTF8 {

            @inline(__always)
            func appendAccumulatedBytes(from mark: UnsafePointer<UInt8>, to cursor: UnsafePointer<UInt8>, followedByContentsOf sequence: [UInt8]) {
                if cursor > mark {
                    writer(pointer: mark, count: cursor-mark)
                }
                writer(contentsOf: sequence)
            }

            @inline(__always)
            func valueToASCII(_ value: UInt8) -> UInt8 {
                switch value {
                case 0 ... 9:
                    return value + UInt8(ascii: "0")
                case 10 ... 15:
                    return value - 10 + UInt8(ascii: "a")
                default:
                    preconditionFailure()
                }
            }

            var cursor = $0.baseAddress!
            let end = $0.baseAddress! + $0.count
            var mark = cursor
            while cursor < end {
                switch cursor.pointee {
                case ._quote:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, ._quote])
                case ._backslash:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, ._backslash])
                case ._slash where !withoutEscapingSlashes:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, ._forwardslash])
                case 0x8:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "b")])
                case 0xc:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "f")])
                case ._newline:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "n")])
                case ._return:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "r")])
                case ._tab:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "t")])
                case 0x0...0xf:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "u"), UInt8(ascii: "0"), UInt8(ascii: "0"), UInt8(ascii: "0")])
                    writer(ascii: valueToASCII(cursor.pointee / 16))
                case 0x10...0x1f:
                    appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "u"), UInt8(ascii: "0"), UInt8(ascii: "0")])
                    writer(ascii: valueToASCII(cursor.pointee % 16))
                    writer(ascii: valueToASCII(cursor.pointee / 16))
                default:
                    // Accumulate this byte
                    cursor += 1
                    continue
                }

                cursor += 1
                mark = cursor // Start accumulating bytes starting after this escaped byte.
            }

            appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [])
        }
        let unquotedStringLength = unquotedStringStart.distance(to: self.bytes.endIndex)
        return unquotedStringLength
    }

    @discardableResult
    mutating func serializeString(_ str: String) -> Int {
        writer(ascii: ._quote)
        defer {
            writer(ascii: ._quote)
        }
        return self.serializeStringContents(str) + 2 // +2 for quotes.

    }

    mutating func serializeArray(_ array: [_JSONEncoderValue], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer(ascii: ._openbracket)
        if pretty {
            writer(ascii: ._newline)
            incIndent()
        }

        var first = true
        for elem in array {
            if first {
                first = false
            } else if pretty {
                writer(contentsOf: [._comma, ._newline])
            } else {
                writer(ascii: ._comma)
            }
            if pretty {
                writeIndent()
            }
            try serializeJSON(elem, depth: depth)
        }
        if pretty {
            writer(ascii: ._newline)
            decAndWriteIndent()
        }
        writer(ascii: ._closebracket)
    }
    
    mutating func serializePreformattedByteArray(_ bytes: [UInt8], _ lengths: [Int], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer(ascii: ._openbracket)
        if pretty {
            writer(ascii: ._newline)
            incIndent()
        }

        var lowerBound: [UInt8].Index = bytes.startIndex

        var first = true
        for length in lengths {
            if first {
                first = false
            } else if pretty {
                writer(contentsOf: [._comma, ._newline])
            } else {
                writer(ascii: ._comma)
            }
            if pretty {
                writeIndent()
            }

            // Do NOT call `serializeString` here! The input strings have already been formatted exactly as they need to be for direct JSON output, including any requisite quotes or escaped characters for strings.
            let upperBound = lowerBound + length
            writer(contentsOf: bytes[lowerBound ..< upperBound])
            lowerBound = upperBound
        }
        if pretty {
            writer(ascii: ._newline)
            decAndWriteIndent()
        }
        writer(ascii: ._closebracket)
    }

    mutating func serializeObject(_ dict: [String:_JSONEncoderValue], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer(ascii: ._openbrace)
        if pretty {
            writer(ascii: ._newline)
            incIndent()
            if dict.count > 0 {
                writeIndent()
            }
        }

        var first = true

        func serializeObjectElement(key: String, value: _JSONEncoderValue, depth: Int) throws {
            if first {
                first = false
            } else if pretty {
                writer(contentsOf: [._comma, ._newline])
                writeIndent()
            } else {
                writer(ascii: ._comma)
            }
            serializeString(key)
            pretty ? writer(contentsOf: [._space, ._colon, ._space]) : writer(ascii: ._colon)
            try serializeJSON(value, depth: depth)
        }

        if sortedKeys {
            #if FOUNDATION_FRAMEWORK
            var compatibilitySorted = false
            if JSONEncoder.compatibility1 {
                // If applicable, use the old NSString-based sorting with appropriate options
                compatibilitySorted = true
                let nsKeysAndValues = dict.map {
                    (key: $0.key as NSString, value: $0.value)
                }
                let elems = nsKeysAndValues.sorted(by: { a, b in
                    let options: String.CompareOptions = [.numeric, .caseInsensitive, .forcedOrdering]
                    let range = NSMakeRange(0, a.key.length)
                    let locale = Locale.system
                    return a.key.compare(b.key as String, options: options, range: range, locale: locale) == .orderedAscending
                })
                for elem in elems {
                    try serializeObjectElement(key: elem.key as String, value: elem.value, depth: depth)
                }
            }
            #else
            let compatibilitySorted = false
            #endif
            
            // If we didn't use the NSString-based compatibility sorting, sort lexicographically by the UTF-8 view
            if !compatibilitySorted {
                let elems = dict.sorted { a, b in
                    a.key.utf8.lexicographicallyPrecedes(b.key.utf8)
                }
                for elem in elems {
                    try serializeObjectElement(key: elem.key as String, value: elem.value, depth: depth)
                }
            }
        } else {
            for (key, value) in dict {
                try serializeObjectElement(key: key, value: value, depth: depth)
            }
        }

        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("}")
    }

    mutating func incIndent() {
        indent += 1
    }

    mutating func incAndWriteIndent() {
        indent += 1
        writeIndent()
    }

    mutating func decAndWriteIndent() {
        indent -= 1
        writeIndent()
    }

    mutating func writeIndent() {
        switch indent {
        case 0:  break
        case 1:  writer("  ")
        case 2:  writer("    ")
        case 3:  writer("      ")
        case 4:  writer("        ")
        case 5:  writer("          ")
        case 6:  writer("            ")
        case 7:  writer("              ")
        case 8:  writer("                ")
        case 9:  writer("                  ")
        case 10: writer("                    ")
        default:
            for _ in 0..<indent {
                writer("  ")
            }
        }
    }
}
