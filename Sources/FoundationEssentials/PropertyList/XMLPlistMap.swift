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


typealias XMLPlistMapOffset = Int

/// Record marker for one value in an `XMLPlistMap`'s record buffer. Declared at file scope rather than nested in `XMLPlistMap` because that type is generic over its record storage, and a nested type of a generic type can't be referenced without spelling the generic arguments.
internal enum XMLPlistMapTypeDescriptor: Int {
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

    /// An NSKeyedArchiver UID.
    case uid          // [marker, count, sourceByteOffset]

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

/// Byte range of a value's payload within the source property list.
internal struct XMLPlistMapRegion {
    let startOffset: Int
    let count: Int
}

/// One record loaded out of an `XMLPlistMap`.
internal indirect enum XMLPlistMapValue {
    case string(XMLPlistMapRegion, isKey: Bool, isSimple: Bool)
    case array(startOffset: Int, count: Int)
    case dict(startOffset: Int, count: Int)
    case data(XMLPlistMapRegion)
    case date(XMLPlistMapRegion)
    case boolean(Bool)
    case real(XMLPlistMapRegion)
    case integer(XMLPlistMapRegion)
    case null

    case uid // UNUSED by PropertyListDecoder.
}

enum XMLPlistError: Swift.Error, Equatable {
    case unexpectedEndOfFile(context: String? = nil)
    case malformedTag(line: Int)
    case unexpectedEmptyTag(XMLPlistTag, line: Int)
    case unexpectedCharacter(UInt8, line: Int, context: String? = nil)
    case unknownEscape(line: Int)
    case cannotConvertToUTF8
    /// A record whose marker was recognized, but wasn't the type the caller expected.
    case typeMismatch(expected: String, actual: XMLPlistMapTypeDescriptor)
    /// A record of the expected type whose payload didn't parse. The label names the value kind (`"integer"`, `"date"`, …).
    case corruptedValue(String)
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
        case let .typeMismatch(expected, actual):
            return "Type mismatch: expected \(expected), got \(actual)"
        case let .corruptedValue(label):
            return "Corrupt \(label) value"
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

/// Flat record buffer describing the structure of a parsed XML property list. Owns its records; an `XMLPlistLegacyDecodingDocument` couples this with the underlying byte buffer (legacy path), while `XMLPlistDecodingDocument` couples it with a `Data` (primitive path).
internal struct XMLPlistMap<Records: MapRecordStorage & ~Copyable>: ~Copyable {
    typealias TypeDescriptor = XMLPlistMapTypeDescriptor
    typealias Region = XMLPlistMapRegion
    typealias Value = XMLPlistMapValue

    let records: Records

    init(records: consuming Records) {
        self.records = records
    }

    func loadValue(at mapOffset: XMLPlistMapOffset) -> Value? {
        let marker = records[mapOffset]
        switch TypeDescriptor(rawValue: marker) {
        case .array:
            let count = records[mapOffset + 2]
            let objsOffset = mapOffset + 3
            return .array(startOffset: objsOffset, count: count)
        case .dict:
            let count = records[mapOffset + 2]
            let objsOffset = mapOffset + 3
            return .dict(startOffset: objsOffset, count: count)
        case .key, .string, .simpleKey, .simpleString:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            let isKey = marker == TypeDescriptor.key.mapMarker || marker == TypeDescriptor.simpleKey.mapMarker
            let isSimple = marker == TypeDescriptor.simpleKey.mapMarker || marker == TypeDescriptor.simpleString.mapMarker
            return .string(.init(startOffset: dataOffset, count: length), isKey: isKey, isSimple: isSimple)
        case .data:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .data(.init(startOffset: dataOffset, count: length))
        case .date:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .date(.init(startOffset: dataOffset, count: length))
        case .real:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .real(.init(startOffset: dataOffset, count: length))
        case .integer:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .integer(.init(startOffset: dataOffset, count: length))
        case .true:
            return .boolean(true)
        case .false:
            return .boolean(false)
        case .nullSentinel:
            return .null
        case .uid:
            return .uid
        case .collectionEnd:
            return nil
        case .none:
            fatalError("Invalid plist tag value in mapping: \(marker))")
        }
    }

    func offset(after previousValueOffset: XMLPlistMapOffset) -> XMLPlistMapOffset {
        let marker = records[previousValueOffset]
        let type = TypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString, .key, .simpleKey, .real, .integer, .data, .date, .uid:
            return previousValueOffset + 3 // Skip marker, length, and data offset
        case .true, .false, .nullSentinel:
            return previousValueOffset + 1 // Skip only the marker.
        case .dict, .array:
            // The collection records the offset to the next sibling
            return records[previousValueOffset + 1]
        case .collectionEnd:
            fatalError("Attempt to find next object past the end of collection at offset \(previousValueOffset))")
        case .none:
            fatalError("Invalid XML value type code in mapping: \(marker))")
        }
    }
}
