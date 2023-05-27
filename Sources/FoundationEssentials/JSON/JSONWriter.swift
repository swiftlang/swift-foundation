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

extension String {
    
    // Ideally we'd entirely de-duplicate this code with serializeString()'s, but at the moment there's a noticeable performance regression when doing so.
    func serializedForJSON(withoutEscapingSlashes: Bool) -> String {
        var bytes = [UInt8]()
        bytes.reserveCapacity(self.utf8.count + 2)
        bytes.append(._quote)
        
        self.withCString {
            $0.withMemoryRebound(to: UInt8.self, capacity: 1) {
                var cursor = $0
                var mark = cursor
                while cursor.pointee != 0 {
                    let escapeString: String
                    switch cursor.pointee {
                    case ._quote:
                        escapeString = "\\\""
                        break
                    case ._backslash:
                        escapeString = "\\\\"
                        break
                    case ._slash where !withoutEscapingSlashes:
                        escapeString = "\\/"
                        break
                    case 0x8:
                        escapeString = "\\b"
                        break
                    case 0xc:
                        escapeString = "\\f"
                        break
                    case ._newline:
                        escapeString = "\\n"
                        break
                    case ._return:
                        escapeString = "\\r"
                        break
                    case ._tab:
                        escapeString = "\\t"
                        break
                    case 0x0...0xf:
                        escapeString = "\\u000\(String(cursor.pointee, radix: 16))"
                        break
                    case 0x10...0x1f:
                        escapeString = "\\u00\(String(cursor.pointee, radix: 16))"
                        break
                    default:
                        // Accumulate this byte
                        cursor += 1
                        continue
                    }
                    
                    // Append accumulated bytes
                    if cursor > mark {
                        bytes.append(contentsOf: UnsafeBufferPointer(start: mark, count: cursor-mark))
                    }
                    bytes.append(contentsOf: escapeString.utf8)
                    
                    cursor += 1
                    mark = cursor // Start accumulating bytes starting after this escaped byte.
                }
                
                // Append accumulated bytes
                if cursor > mark {
                    bytes.append(contentsOf: UnsafeBufferPointer(start: mark, count: cursor-mark))
                }
            }
        }
        bytes.append(._quote)
        
        return String(unsafeUninitializedCapacity: bytes.count) {
            _ = $0.initialize(from: bytes)
            return bytes.count
        }
    }
}

extension JSONReference {
    static func number(from num: any (FixedWidthInteger & CustomStringConvertible)) -> JSONReference {
        .number(num.description)
    }

    static func number<T: BinaryFloatingPoint & CustomStringConvertible>(from float: T, with options: JSONEncoder.NonConformingFloatEncodingStrategy, for codingPathNode: _JSONCodingPathNode, _ additionalKey: (some CodingKey)? = Optional<_JSONKey>.none) throws -> JSONReference {
        guard !float.isNaN, !float.isInfinite else {
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

            let path = codingPathNode.path(with: additionalKey)
            throw EncodingError.invalidValue(float, .init(
                codingPath: path,
                debugDescription: "Unable to encode \(T.self).\(float) directly in JSON."
            ))
        }

        var string = float.description
        if string.hasSuffix(".0") {
            string.removeLast(2)
        }
        return .number(string)
    }
}

internal struct JSONWriter {

    // Structures with container nesting deeper than this limit are not valid.
    private static let maximumRecursionDepth = 512

    private var indent = 0
    private let pretty: Bool
    private let sortedKeys: Bool
    private let withoutEscapingSlashes: Bool

    var data = Data()

    init(options: WritingOptions) {
        pretty = options.contains(.prettyPrinted)
#if FOUNDATION_FRAMEWORK
        sortedKeys = options.contains(.sortedKeys)
#else
        sortedKeys = false
#endif
        withoutEscapingSlashes = options.contains(.withoutEscapingSlashes)
        data = Data()
    }

    mutating func serializeJSON(_ value: JSONReference, depth: Int = 0) throws {
        switch value.backing {
        case .string(let str):
            try serializeString(str)
        case .bool(let boolValue):
            writer(boolValue.description)
        case .number(let numberStr):
            writer(numberStr)
        case .array(let array):
            try serializeArray(array, depth: depth + 1)
        case .nonPrettyDirectArray(let arrayRepresentation):
            writer(arrayRepresentation)
        case .directArray(let strings):
            try serializeStringArray(strings, depth: depth + 1)
        case .object(let object):
            try serializeObject(object, depth: depth + 1)
        case .null:
            serializeNull()
        }
    }

    @inline(__always)
    mutating func writer(_ string: StaticString) {
        string.withUTF8Buffer {
            data.append($0.baseAddress.unsafelyUnwrapped, count: $0.count)
        }
    }

    @inline(__always)
    mutating func writer(_ string: String) {
        var localString = string
        localString.withUTF8 {
            data.append($0.baseAddress.unsafelyUnwrapped, count: $0.count)
        }
    }

    @inline(__always)
    mutating func writer(ascii: UInt8) {
        data.append(ascii)
    }

    @inline(__always)
    mutating func writer(pointer: UnsafePointer<UInt8>, count: Int) {
        data.append(pointer, count: count)
    }

    mutating func serializeString(_ str: String) throws {
        writer("\"")

        str.withCString {
            $0.withMemoryRebound(to: UInt8.self, capacity: 1) {
                var cursor = $0
                var mark = cursor
                while cursor.pointee != 0 {
                    let escapeString: String
                    switch cursor.pointee {
                    case ._quote:
                        escapeString = "\\\""
                        break
                    case ._backslash:
                        escapeString = "\\\\"
                        break
                    case ._slash where !withoutEscapingSlashes:
                        escapeString = "\\/"
                        break
                    case 0x8:
                        escapeString = "\\b"
                        break
                    case 0xc:
                        escapeString = "\\f"
                        break
                    case ._newline:
                        escapeString = "\\n"
                        break
                    case ._return:
                        escapeString = "\\r"
                        break
                    case ._tab:
                        escapeString = "\\t"
                        break
                    case 0x0...0xf:
                        escapeString = "\\u000\(String(cursor.pointee, radix: 16))"
                        break
                    case 0x10...0x1f:
                        escapeString = "\\u00\(String(cursor.pointee, radix: 16))"
                        break
                    default:
                        // Accumulate this byte
                        cursor += 1
                        continue
                    }

                    // Append accumulated bytes
                    if cursor > mark {
                        writer(pointer: mark, count: cursor-mark)
                    }
                    writer(escapeString)

                    cursor += 1
                    mark = cursor // Start accumulating bytes starting after this escaped byte.
                }

                // Append accumulated bytes
                if cursor > mark {
                    writer(pointer: mark, count: cursor-mark)
                }
            }
        }
        writer("\"")
    }

    mutating func serializeArray(_ array: [JSONReference], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer("[")
        if pretty {
            writer("\n")
            incIndent()
        }

        var first = true
        for elem in array {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
            } else {
                writer(",")
            }
            if pretty {
                writeIndent()
            }
            try serializeJSON(elem, depth: depth)
        }
        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("]")
    }
    
    mutating func serializeStringArray(_ array: [String], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer("[")
        if pretty {
            writer("\n")
            incIndent()
        }

        var first = true
        for elem in array {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
            } else {
                writer(",")
            }
            if pretty {
                writeIndent()
            }
            writer(elem)
        }
        if pretty {
            writer("\n")
            decAndWriteIndent()
        }
        writer("]")
    }

    mutating func serializeObject(_ dict: [String:JSONReference], depth: Int) throws {
        guard depth < Self.maximumRecursionDepth else {
            throw JSONError.tooManyNestedArraysOrDictionaries()
        }

        writer("{")
        if pretty {
            writer("\n")
            incIndent()
            if dict.count > 0 {
                writeIndent()
            }
        }

        var first = true

        func serializeObjectElement(key: String, value: JSONReference, depth: Int) throws {
            if first {
                first = false
            } else if pretty {
                writer(",\n")
                writeIndent()
            } else {
                writer(",")
            }
            try serializeString(key)
            pretty ? writer(" : ") : writer(":")
            try serializeJSON(value, depth: depth)
        }

        if sortedKeys {
            let elems = dict.sorted(by: { a, b in
                let options: String.CompareOptions = [.numeric, .caseInsensitive, .forcedOrdering]
                let range: Range<String.Index>  = a.key.startIndex..<a.key.endIndex
                #if FOUNDATION_FRAMEWORK
                let locale = NSLocale.system
                return a.key.compare(b.key, options: options, range: range, locale: locale) == .orderedAscending
                #else
                return a.key.compare(b.key, options: options, range: range) == .orderedAscending
                #endif // FOUNDATION_FRAMEWORK
            })
            for elem in elems {
                try serializeObjectElement(key: elem.key, value: elem.value, depth: depth)
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

    mutating func serializeNull() {
        writer("null")
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

// MARK: - WritingOptions
extension JSONWriter {
#if FOUNDATION_FRAMEWORK
    typealias WritingOptions = JSONSerialization.WritingOptions
#else
    struct WritingOptions : OptionSet, Sendable {
        let rawValue: UInt

        init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Specifies that the output uses white space and indentation to make the resulting data more readable.
        static let prettyPrinted = WritingOptions(rawValue: 1 << 0)
        /// Specifies that the output sorts keys in lexicographic order.
        static let sortedKeys = WritingOptions(rawValue: 1 << 1)
        /// Specifies that the parser should allow top-level objects that aren’t arrays or dictionaries.
        static let fragmentsAllowed = WritingOptions(rawValue: 1 << 2)
        /// Specifies that the output doesn’t prefix slash characters with escape characters.
        static let withoutEscapingSlashes = WritingOptions(rawValue: 1 << 3)
    }
#endif // FOUNDATION_FRAMEWORK
}
