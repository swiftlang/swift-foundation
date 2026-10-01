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

/// Record marker for one value in a `JSONMap`'s record buffer. Declared at file scope rather than nested in `JSONMap` because that type is generic over its record storage, and a nested type of a generic type can't be referenced without spelling the generic arguments.
internal enum JSONMapTypeDescriptor: Int {
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

/// Byte range of a value's payload within the source JSON.
internal struct JSONMapRegion {
    let startOffset: Int
    let count: Int
}

/// One record loaded out of a `JSONMap`.
internal enum JSONMapValue {
    case string(JSONMapRegion, isSimple: Bool)
    case number(JSONMapRegion, containsExponent: Bool)
    case bool(Bool)
    case null

    case object(JSONMapRegion)
    case array(JSONMapRegion)
}

/// Flat record buffer describing the structure of a parsed JSON payload, without copying any of the non-structural data. Owns its records; a `JSONDocument` couples this with the underlying byte buffer. Used by the JSON decoder, which will fully parse only those values required to decode the requested `Decodable` types.
///
/// To minimize the number of allocations required during scanning, the map's contents are implemented using an array of integers, whose values are a serialization of the JSON payload's full structure. Each type has its own unique marker value, which is followed by zero or more other integers that describe that contents of that type, if any.
///
/// Due to the complexity and additional allocations required to parse JSON string values into Swift `String`s or JSON number values into the requested integer or floating-point types, their map contents are captured as lengths of bytes and byte offsets into the input. This allows the full parsing to occur at decode time, or to be skipped if the value is not desired. A partial, imperfect parsing is performed by the scanner, simply "skipping" characters which are valid in their given contexts without interpreting or further validating them relative to the other inputs. This incomplete scanning process does however guarantee that the structure of the JSON input is correctly interpreted.
///
/// The representation of JSON arrays and objects is a sequence of integers delimited by their starting marker and a shared "collection end" marker; contents are nested in between. To facilitate skipping over unwanted elements of a collection, especially useful for JSON objects, the map encodes the offset in the record array to the next object after the end of the collection.
///
/// For instance, a JSON payload such as the following:
///
/// ```
/// {"array":[1,2,3],"number":42}
/// ```
///
/// will be scanned into a map buffer looking like this:
///
/// ```
/// Key:
/// <OM> == Object Marker
/// <AM> == Array Marker
/// <SS> == Simple String (a variant of String that has no escapes and can be passed directly to a UTF-8 parser)
/// <NM> == Number Marker
/// <CE> == Collection End
/// (See JSONMapTypeDescriptor comments below for more details)
///
/// Map offset:        0,  1, 2,    3, 4, 5,    6,  7, 8,    9, 10, 11,   12  13, 14,   15  16, 17,   18,   19, 20, 21,   22, 23, 24,   25
/// Map contents: [ <OM>, 26, 2, <SS>, 5, 2, <AM>, 19, 3, <NM>,  1, 10, <NM>,  1, 12, <NM>,  1, 14, <CE>, <SS>,  6, 18, <NM>,  2, 26, <CE> ]
/// Description:           |     -- key2 --  ------------------------- value1 --------------------------  --- key2 ---  -- value2 --
///                        |              |         |  --arr elm 0-  --arr elm 0-  --arr elm 0-
///                        |              > Byte offset from the beginning of the input to the contents of the string
///                        |                        > Offset to the next entry after this array, which is key2
///                        > Offset to next entry after this object, which is the endIndex of the array, as this is the top level value
/// ```
///
/// A `Decodable` type that wishes only to decode the "number" key of this object can entirely skip the decoding of the "array" value:
/// 1. Find the type of the value at index 0 (object), and its size at index 2.
/// 2. Begin parsing keys at index 3. Decode the string, find "array", which is not a match for "number".
/// 3. Skip the key's value by finding its type (array), and then its `nextSiblingOffset` index (19).
/// 4. Parse the next key at index 4. Decode the string and find "number", a match.
/// 5. Decode the value by finding its type (number), its length (2), and the byte offset from the beginning of the input (26).
/// 6. Pass that byte offset + length into the number parser to produce the corresponding Swift `Int` value.
internal struct JSONMap<Records: MapRecordStorage & ~Copyable>: ~Copyable {
    typealias TypeDescriptor = JSONMapTypeDescriptor
    typealias Region = JSONMapRegion
    typealias Value = JSONMapValue

    let records: Records

    init(records: consuming Records) {
        self.records = records
    }

    func loadValue(at mapOffset: Int) -> Value? {
        let marker = records[mapOffset]
        let type = JSONMapTypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .string(.init(startOffset: dataOffset, count: length), isSimple: type == .simpleString)
        case .number, .numberContainingExponent:
            let length = records[mapOffset + 1]
            let dataOffset = records[mapOffset + 2]
            return .number(.init(startOffset: dataOffset, count: length), containsExponent: type == .numberContainingExponent)
        case .object:
            // Skip the offset to the next sibling value.
            let count = records[mapOffset + 2]
            return .object(.init(startOffset: mapOffset + 3, count: count))
        case .array:
            // Skip the offset to the next sibling value.
            let count = records[mapOffset + 2]
            return .array(.init(startOffset: mapOffset + 3, count: count))
        case .null:
            return .null
        case .true:
            return .bool(true)
        case .false:
            return .bool(false)
        case .collectionEnd:
            return nil
        case .none:
            fatalError("Invalid JSON value type code in mapping: \(marker))")
        }
    }

    func offset(after previousValueOffset: Int) -> Int {
        let marker = records[previousValueOffset]
        let type = JSONMapTypeDescriptor(rawValue: marker)
        switch type {
        case .string, .simpleString, .number, .numberContainingExponent:
            return previousValueOffset + 3 // Skip marker, length, and data offset
        case .null, .true, .false:
            return previousValueOffset + 1 // Skip only the marker.
        case .object, .array:
            // The collection records the offset to the next sibling.
            return records[previousValueOffset + 1]
        case .collectionEnd:
            fatalError("Attempt to find next object past the end of collection at offset \(previousValueOffset))")
        case .none:
            fatalError("Invalid JSON value type code in mapping: \(marker))")
        }
    }
}
