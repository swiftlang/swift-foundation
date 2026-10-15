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

internal struct JSONWriter: ~Copyable {

    // Structures with container nesting deeper than this limit are not valid.
    private static let maximumRecursionDepth = 512

    private var indent = 0
    private let pretty: Bool
    private let sortedKeys: Bool
    private let withoutEscapingSlashes: Bool

    var bytes = Bytes()

    init(options: JSONEncoder.OutputFormatting) {
        pretty = options.contains(.prettyPrinted)
        sortedKeys = options.contains(.sortedKeys)
        withoutEscapingSlashes = options.contains(.withoutEscapingSlashes)
    }

    consuming func makeData() -> Data {
        Data(consuming: bytes)
    }

    mutating func reserveCapacity(forSerializing value: JSONEncoderValue) {
        let estimate = estimatedSerializedByteCount(of: value)
        // Extra 1/16 for string escapes, which the estimate doesn't count
        bytes.reserveCapacity(estimate + estimate / 16)
    }

    func estimatedSerializedByteCount(of value: JSONEncoderValue, level: Int = 0) -> Int {
        switch value {
        case .string(let string):
            // String content + 2 quotes
            return string.utf8.count + 2
        case .number(let number):
            return number.utf8.count
        case .base64EncodedData(let data):
            // Base64 content (4 characters per 3 bytes, rounded up) + 2 quotes
            return (data.count + 2) / 3 * 4 + 2
        case .bool(let bool):
            return bool ? 4 : 5
        case .null:
            return 4
        case .nonPrettyDirectArray(let serialized):
            return serialized.count
        case let .directArray(elements, lengths):
            return containerOverhead(elementCount: lengths.count, level: level) + elements.count
        case .array(let array):
            var count = containerOverhead(elementCount: array.count, level: level)
            for element in array {
                count += estimatedSerializedByteCount(of: element, level: level + 1)
            }
            return count
        case .object(let object):
            var count = containerOverhead(elementCount: object.count, level: level)
            for (key, value) in object {
                // Key content + 2 quotes + ":" (or " : " when pretty)
                count += key.utf8.count + (pretty ? 5 : 3) + estimatedSerializedByteCount(of: value, level: level + 1)
            }
            return count
        }
    }

    private func containerOverhead(elementCount: Int, level: Int) -> Int {
        let separatorCount = max(elementCount - 1, 0)
        if pretty {
            // 2 brackets + 2 newlines inside them, 2 spaces per level indenting the closing bracket,
            // 2 spaces per level indenting each element, and a ",\n" between elements
            return 4 + 2 * level + elementCount * 2 * (level + 1) + 2 * separatorCount
        } else {
            // 2 brackets + a "," between elements
            return 2 + separatorCount
        }
    }

    mutating func serializeJSON(_ value: JSONEncoderValue, depth: Int = 0) throws {
        switch value {
        case .string(let str):
            serializeString(str)
        case .bool(let boolValue):
            writer(boolValue ? "true" : "false")
        case .number(let numberStr):
            writer(contentsOf: numberStr.utf8)
        case .array(let array):
            try serializeArray(array, depth: depth + 1)
        case .base64EncodedData(let data):
            writer(ascii: ._quote)
            serializeBase64Contents(data)
            writer(ascii: ._quote)
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
        let appended: Void? = sequence.withContiguousStorageIfAvailable {
            bytes.append(copying: $0.span.bytes)
        }
        if appended == nil {
            for byte in sequence {
                bytes.append(byte)
            }
        }
    }

    @inline(__always)
    mutating func writer(ascii: UInt8) {
        bytes.append(ascii)
    }

    @inline(__always)
    mutating func writer(pointer: UnsafePointer<UInt8>, count: Int) {
        bytes.append(copying: UnsafeBufferPointer(start: pointer, count: count).span.bytes)
    }

    // Shortcut for strings known not to require escapes, like numbers.
    @inline(__always)
    mutating func serializeSimpleStringContents(_ str: String) -> Int {
        let stringStart = self.bytes.count
        var mutStr = str
        mutStr.withUTF8 {
            writer(contentsOf: $0)
        }
        let length = stringStart.distance(to: self.bytes.count)
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
        let unquotedStringStart = self.bytes.count
        var mutStr = str
        mutStr.withUTF8 {
            serializeStringContents(utf8: $0)
        }
        let unquotedStringLength = unquotedStringStart.distance(to: self.bytes.count)
        return unquotedStringLength
    }

    @inline(__always)
    mutating func serializeStringContents(utf8: UnsafeBufferPointer<UInt8>) {
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
                return value &+ UInt8(ascii: "0")
            case 10 ... 15:
                return value &- 10 &+ UInt8(ascii: "a")
            default:
                preconditionFailure()
            }
        }

        var cursor = utf8.baseAddress!
        let end = utf8.baseAddress! + utf8.count
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
                writer(ascii: valueToASCII(cursor.pointee))
            case 0x10...0x1f:
                appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [._backslash, UInt8(ascii: "u"), UInt8(ascii: "0"), UInt8(ascii: "0")])
                writer(ascii: valueToASCII(cursor.pointee / 16))
                writer(ascii: valueToASCII(cursor.pointee % 16))
            default:
                // Accumulate this byte and any following bytes that are known not to need escaping
                cursor = Self.skipBytesNotNeedingEscape(from: cursor + 1, to: end, escapingSlashes: !withoutEscapingSlashes)
                continue
            }

            cursor += 1
            mark = cursor // Start accumulating bytes starting after this escaped byte.
        }

        appendAccumulatedBytes(from: mark, to: cursor, followedByContentsOf: [])
    }

    // Base64-encodes `data` into a temporary buffer, then escapes it like any other string contents
    mutating func serializeBase64Contents(_ data: Data) {
        guard !data.isEmpty else { return }
        // Encoded in chunks so that large Data is never duplicated in full. A multiple of 3 so that only the final chunk can need padding.
        let inputChunkSize = 48 * 1024
        let input = data.bytes
        withTemporaryAllocation(byteCount: Base64.encodeComputeCapacity(bytes: Swift.min(input.byteCount, inputChunkSize), options: []), alignment: 1) { output in
            var chunkStart = 0
            while chunkStart < input.byteCount {
                let chunkEnd = Swift.min(chunkStart + inputChunkSize, input.byteCount)
                output.removeAll()
                Base64._encode(input: input.extracting(chunkStart ..< chunkEnd), buffer: &output, options: [])
                output.bytes.withUnsafeBytes {
                    serializeStringContents(utf8: $0.assumingMemoryBound(to: UInt8.self))
                }
                chunkStart = chunkEnd
            }
        }
    }

    // Skips 8 bytes at a time until reaching a word that contains a byte needing escaping, then returns a pointer to that byte (or to where fewer than 8 bytes remain)
    @inline(never)
    private static func skipBytesNotNeedingEscape(from start: UnsafePointer<UInt8>, to end: UnsafePointer<UInt8>, escapingSlashes: Bool) -> UnsafePointer<UInt8> {
        var cursor = start
        while end - cursor >= MemoryLayout<UInt64>.size {
            let word = UInt64(littleEndian: UnsafeRawPointer(cursor).loadUnaligned(as: UInt64.self))
            let flags = escapeFlags(in: word, escapingSlashes: escapingSlashes)
            if flags != 0 {
                return cursor + flags.trailingZeroBitCount / 8
            }
            cursor += MemoryLayout<UInt64>.size
        }
        return cursor
    }

    // Sets the high bit of each byte in `word` that needs escaping. Bytes after the first flagged byte may be flagged spuriously, but the first flagged byte is always accurate.
    @inline(__always)
    private static func escapeFlags(in word: UInt64, escapingSlashes: Bool) -> UInt64 {
        let ones: UInt64 = 0x0101_0101_0101_0101
        let highBits: UInt64 = 0x8080_8080_8080_8080

        // High bit set for each zero byte of `x`
        @inline(__always)
        func zeroBytes(_ x: UInt64) -> UInt64 {
            (x &- ones) & ~x & highBits
        }

        // Control characters: bytes less than 0x20
        var flags = (word &- ones &* 0x20) & ~word & highBits
        flags |= zeroBytes(word ^ (ones &* UInt64(UInt8._quote)))
        flags |= zeroBytes(word ^ (ones &* UInt64(UInt8._backslash)))
        if escapingSlashes {
            flags |= zeroBytes(word ^ (ones &* UInt64(UInt8._forwardslash)))
        }
        return flags
    }

    @discardableResult
    mutating func serializeString(_ str: String) -> Int {
        writer(ascii: ._quote)
        defer {
            writer(ascii: ._quote)
        }
        return self.serializeStringContents(str) + 2 // +2 for quotes.

    }

    mutating func serializeArray(_ array: [JSONEncoderValue], depth: Int) throws {
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
    
    mutating func serializePreformattedByteArray(_ bytes: Data, _ lengths: [Int], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer(ascii: ._openbracket)
        if pretty {
            writer(ascii: ._newline)
            incIndent()
        }

        var lowerBound: Data.Index = bytes.startIndex

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

    mutating func serializeObject(_ dict: [String:JSONEncoderValue], depth: Int) throws {
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

        func serializeObjectElement(key: String, value: JSONEncoderValue, depth: Int) throws {
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
