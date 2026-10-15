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


// The existence of a ValidatedBPlistObjectIndex means that the contained object index is known to be valid for the bplist metadata it was created from, and does not need to be validated again.
struct ValidatedBPlistObjectIndex: BitwiseCopyable, Hashable, Sendable {
    let val: Int

    @_transparent
    init(unchecked idx: Int) {
        self.val = idx
    }
}

// The top-level type for obtaining BPlistMetadata values from binary plist data. Lives primarily to be the concrete storage of BPlistMetadata.
internal struct BinaryPropertyList: ~Escapable, ~Copyable, ~Sendable {
    let rawTrailer: BPlistTrailer
    let metadata: BPlistMetadata
    let data: RawSpan
    
    @_lifetime(copy data)
    init(data: RawSpan, metadata: BPlistMetadata, rawTrailer: BPlistTrailer) {
        self.metadata = metadata
        self.data = data
        self.rawTrailer = rawTrailer
    }
    
    var topLevelPrimitive: BPlistPrimitive {
        @_lifetime(borrow self)
        get {
            return .init(metadata: metadata, bplistData: data, objectIndex: metadata.topObjectIndex)
        }
    }
    
    @_lifetime(copy buffer)
    init(_ buffer: RawSpan) throws {
        guard let rawTrailer = BPlistMetadata.parseTopLevelInfo(from: buffer) else {
            throw BPlistError.corruptTopLevelInfo
        }
        let metadata = try BPlistMetadata.parse(from: buffer, trailer: rawTrailer)
        self = .init(data: buffer, metadata: metadata, rawTrailer: rawTrailer)
    }

}

internal enum BPlistTypeMarker: UInt8, Sendable {
    case null = 0x00
    case `false` = 0x08
    case `true` = 0x09
    case int = 0x10
    case real = 0x20
    case date = 0x33
    case data = 0x40
    case asciiString = 0x50
    case utf16String = 0x60
    case uid = 0x80
    case array = 0xA0
    case set = 0xC0
    case dict = 0xD0
    
    init?(_ marker: UInt8) {
        switch marker & 0xf0 {
        case 0x00:
            switch (marker) {
            case Self.null.rawValue:
                self = .null
            case Self.false.rawValue:
                self = .false
            case Self.true.rawValue:
                self = .true
            default:
                return nil
            }
        case Self.int.rawValue:
            self = .int
        case Self.real.rawValue:
            self = .real
        case Self.date.rawValue & 0xf0:
            guard marker == Self.date.rawValue else {
                return nil
            }
            self = .date
        case Self.data.rawValue:
            self = .data
        case Self.asciiString.rawValue:
            self = .asciiString
        case Self.utf16String.rawValue:
            self = .utf16String
        case Self.uid.rawValue:
            self = .uid
        case Self.array.rawValue:
            self = .array
        case Self.set.rawValue:
            self = .set
        case Self.dict.rawValue:
            self = .dict
        default:
            return nil
        }
    }

    @inline(__always)
    func matches(_ actual: UInt8) -> Bool {
        switch self {
        case .null, .false, .true, .date:
            // Byte-exact markers (no low-nibble payload in the marker byte itself).
            return actual == self.rawValue
        case .int, .real, .data, .asciiString, .utf16String,
             .uid, .array, .set, .dict:
            // High-nibble markers; the low nibble carries size/count info.
            return (actual & 0xf0) == self.rawValue
        }
    }
}

typealias BPlistTrailer = (_unused0: UInt8, _unused1: UInt8, _unused2: UInt8, _unused3: UInt8, _unused4: UInt8, _sortVersion: UInt8, _offsetIntSize: UInt8, _objectRefSize: UInt8, _numObjects: UInt64, _topObject: UInt64, _offsetTableOffset: UInt64)

/// Metadata for a parsed bplist. Describes the object-offset table.
///
/// `objectOffset(for:in:)` reads directly from the caller-supplied `bplistData` without additional bounds checks. Assuming the span is the same exact one the metadata was created from, this is safe because the existence of the `ValidatedBPlistObjectIndex` proves the index is in range, and the offset-table region was fully walked and validated at parse time.
struct BPlistMetadata: Sendable {
    let topObjectIndex: ValidatedBPlistObjectIndex
    let offsetTableOffset: Int
    let objectRefSize: Int
    let offsetIntSize: Int
    let numObjects: Int

    @inline(__always)
    func objectOffset(for objectIndex: ValidatedBPlistObjectIndex, in bplistData: borrowing RawSpan) -> Int {
        assert(objectIndex.val >= 0 && objectIndex.val < numObjects, "object index \(objectIndex.val) out of range (numObjects = \(numObjects))")
        let byteOffset = offsetTableOffset &+ objectIndex.val &* offsetIntSize
        return Int(bplistData.loadBigEndianUInt64Unchecked(at: byteOffset, byteSize: offsetIntSize))
    }

    func offsetToObjectIndexReverseMapping(in bplistData: borrowing RawSpan) -> [Int: ValidatedBPlistObjectIndex] {
        var reverse: [Int: ValidatedBPlistObjectIndex] = [:]
        reverse.reserveCapacity(numObjects)
        for i in 0..<numObjects {
            let idx = ValidatedBPlistObjectIndex(unchecked: i)
            reverse[objectOffset(for: idx, in: bplistData)] = idx
        }
        return reverse
    }
}

extension BPlistMetadata {

    static func parse(from buffer: borrowing RawSpan) throws -> BPlistMetadata {
        guard let trailer = parseTopLevelInfo(from: buffer) else {
            throw BPlistError.corruptTopLevelInfo
        }
        return try parse(from: buffer, trailer: trailer)
    }

    static func parse(from buffer: borrowing RawSpan, trailer: BPlistTrailer) throws -> BPlistMetadata {
        guard let numObjects = Int(exactly: trailer._numObjects) else {
            throw BPlistError.corruptTopLevelInfo
        }
        guard let offsetTableOffset = Int(exactly: trailer._offsetTableOffset) else {
            throw BPlistError.corruptTopLevelInfo
        }
        let offsetIntSize = Int(trailer._offsetIntSize)

        // Walk every entry in the offset table to prove it's decodable and points before the offset table itself.
        var objectTableCursor = offsetTableOffset
        let endIdx = buffer.byteCount
        let maxOffset = offsetTableOffset - 1
        for _ in 0 ..< numObjects {
            guard let span = buffer.getSizedIntSpan(at: objectTableCursor, endIndex: endIdx, size: offsetIntSize) else {
                throw BPlistError.corruptTopLevelInfo
            }
            guard let decoded = Int(exactly: span.bplistIntegerValue), decoded <= maxOffset else {
                throw BPlistError.corruptTopLevelInfo
            }
            objectTableCursor &+= offsetIntSize
        }

        guard let topObject = Int(exactly: trailer._topObject), topObject < numObjects else {
            throw BPlistError.corruptTopLevelInfo
        }
        let validatedTopObject = ValidatedBPlistObjectIndex(unchecked: topObject)

        return BPlistMetadata(topObjectIndex: validatedTopObject, offsetTableOffset: offsetTableOffset, objectRefSize: Int(trailer._objectRefSize), offsetIntSize: offsetIntSize, numObjects: numObjects)
    }

    func validatedObjectIndex(raw: UInt64) throws -> ValidatedBPlistObjectIndex {
        guard let asInt = Int(exactly: raw), asInt < numObjects else {
            throw BPlistError.corruptedValue("object ref")
        }
        return .init(unchecked: asInt)
    }
    
    private static var bplistXXLen: Int { 8 }
    private static var bplistMagic: StaticString { "bplist0" }
    private static func validateBPlistMagicAndSize(in buff: RawSpan) -> Bool {
        guard buff.byteCount >= MemoryLayout<BPlistTrailer>.size + bplistXXLen + 1 else {
            return false
        }
        return Span(viewing: buff).starts(with: bplistMagic)
    }
    
    static func parseTopLevelInfo(from buff: RawSpan) -> BPlistTrailer? {
        guard validateBPlistMagicAndSize(in: buff) else {
            return nil
        }
        var trailer = buff.extracting(last: MemoryLayout<BPlistTrailer>.size).unsafeLoadUnaligned(as: BPlistTrailer.self)

        // The bplist format is big endian by definition. On a little-endian machine, the 64-bit values need to be swapped. X.bigEndian is equivalent to "convert big- to host-endianness".
        trailer._numObjects = trailer._numObjects.bigEndian
        trailer._topObject = trailer._topObject.bigEndian
        trailer._offsetTableOffset = trailer._offsetTableOffset.bigEndian

        // Don't overflow on the number of objects or offset of the table
        guard trailer._numObjects <= Int.max, trailer._offsetTableOffset <= Int.max else {
            return nil
        }

        // Must be a minimum of 1 object
        guard trailer._numObjects >= 1 else {
            return nil
        }

        // The ref to the top object must be a value in the range of 1 to the total number of objects
        guard trailer._numObjects > trailer._topObject else {
            return nil
        }

        // The offset table must be after at least 9 bytes of other data ('bplist??' + 1 byte of object table data).
        guard trailer._offsetTableOffset >= 9 else {
            return nil
        }

        // The trailer must point to a value before itself in the data.
        guard buff.byteCount - MemoryLayout<BPlistTrailer>.size > trailer._offsetTableOffset else {
            return nil
        }

        // Minimum of 1 byte for the size of integers and references in the data
        guard trailer._offsetIntSize >= 1, trailer._objectRefSize >= 1 else {
            return nil
        }

        // The total size of the offset table (number of objects * size of each int in the table) must not overflow
        let offsetTableSize : UInt64
        var overflow = false
        (offsetTableSize, overflow) = trailer._numObjects.multipliedReportingOverflow(by: UInt64(trailer._offsetIntSize))
        guard !overflow else {
            return nil
        }

        // The offset table must have at least 1 entry
        guard offsetTableSize >= 1 else {
            return nil
        }

        // Make sure the size of the offset table and data sections do not overflow
        let objectDataSize = trailer._offsetTableOffset - 8
        var tmpSum = addCheckingForOverflow(8, objectDataSize, overflow: &overflow)
        tmpSum = addCheckingForOverflow(tmpSum, offsetTableSize, overflow: &overflow)
        tmpSum = addCheckingForOverflow(tmpSum, UInt64(MemoryLayout<BPlistTrailer>.size), overflow: &overflow)
        guard !overflow else {
            return nil
        }

        // The total size of the data should be equal to the sum of offsetTableOffset + sizeof(trailer)
        guard buff.byteCount == tmpSum else {
            return nil
        }

        // The object refs must be the right size to point into the offset table. That is, if the count of objects is 260, but only 1 byte is used to store references (max value 255), something is wrong.
        if trailer._objectRefSize < 8 && 1<<(8 * trailer._objectRefSize) <= trailer._numObjects {
            return nil
        }

        // The integers used for pointers in the offset table must be able to reach as far as the start of the offset table.
        if trailer._offsetIntSize < 8 && 1<<(8 * trailer._offsetIntSize) <= trailer._offsetTableOffset {
            return nil
        }

        // We're deferring the validation of all the entries of the offsetTable to scanBinaryPropertyList() time. However, we will still check that the top object offset is valid, as has been done in __CFBinaryPlistGetTopLevelInfo.
        var (topObjectOffsetOffset, topObjectOverflow) = Int(trailer._topObject).multipliedReportingOverflow(by: Int(trailer._offsetIntSize))
        guard !topObjectOverflow else {
            return nil
        }
        (topObjectOffsetOffset, topObjectOverflow) = Int(trailer._offsetTableOffset).addingReportingOverflow(topObjectOffsetOffset)
        guard !topObjectOverflow else {
            return nil
        }
        guard buff.byteCount > topObjectOffsetOffset else {
            return nil
        }
        let topObjectOffsetIdx = topObjectOffsetOffset
        guard let topObjectOffsetSpan = buff.getSizedIntSpan(at: topObjectOffsetIdx, endIndex: buff.byteCount, size: Int(trailer._offsetIntSize)) else {
            return nil
        }
        let topObjectOffset = topObjectOffsetSpan.bplistIntegerValue
        // Must fall somewhere after bplistXX and before the beginning of the offset table.
        guard topObjectOffset >= Self.bplistXXLen, topObjectOffset < trailer._offsetTableOffset else {
            return nil
        }

        return trailer
    }
}

internal struct BPlistPrimitive: ~Escapable, ~Sendable {
    let metadata: BPlistMetadata
    let bplistData: RawSpan
    let objectIndex: ValidatedBPlistObjectIndex
    let objectOffset: Int
    /// Decoded type marker, computed once at init. `nil` when the marker byte at `objectOffset` doesn't parse.
    let type: BPlistTypeMarker?

    @_lifetime(copy bplistData)
    init(metadata: BPlistMetadata, bplistData: RawSpan, objectIndex: ValidatedBPlistObjectIndex) {
        self.metadata = metadata
        self.bplistData = bplistData
        self.objectIndex = objectIndex
        let offset = metadata.objectOffset(for: objectIndex, in: bplistData)
        self.objectOffset = offset
        self.type = BPlistTypeMarker(bplistData[offset])
    }

    @_lifetime(copy self)
    func child(at objectIndex: ValidatedBPlistObjectIndex) -> BPlistPrimitive {
        BPlistPrimitive(metadata: metadata, bplistData: bplistData, objectIndex: objectIndex)
    }

    /// Load and validate one child object index from this collection's refs region, whether it's a single contiguous array/set collection or from the keys or values section of a dictionary.
    @inline(__always)
    func validatedChildObjectIndex(atCollectionRefIndex collectionRefIndex: Int) throws -> ValidatedBPlistObjectIndex {
        let refsSpan: RawSpan
        switch self.type {
        case .array, .set:
            refsSpan = try self.arraySetSpan
        case .dict:
            refsSpan = try self.dictionarySpan
        case .none:
            throw BPlistError.invalidMarker
        case .some(let actual):
            throw BPlistError.typeMismatch(expected: "collection", actual: actual)
        }
        let refSize = metadata.objectRefSize
        // `refsSpan.byteCount` was validated as `count * refSize` (no overflow, fits in the bplist buffer) by `payloadRange` when the span was produced; see `arraySetRange` / `dictionarySpanRange`. So `collectionRefIndex * refSize + refSize` is in-bounds whenever `collectionRefIndex` is.
        guard collectionRefIndex >= 0, collectionRefIndex < refsSpan.byteCount / refSize else {
            throw BPlistError.corruptedValue("object ref")
        }
        let byteOffset = collectionRefIndex &* refSize
        let raw = refsSpan.loadBigEndianUInt64Unchecked(at: byteOffset, byteSize: refSize)
        return try metadata.validatedObjectIndex(raw: raw)
    }

    /// Load and validate one child object index by absolute byte offset into `bplistData`. The load is unchecked; caller must guarantee `[byteOffset, byteOffset + refSize)` lies within a refs region already validated by `payloadRange`. Used by the iterative decoder, which caches its frame's refs region and drives the offset itself.
    @inline(__always)
    func validatedChildObjectIndex(atByteOffset byteOffset: Int, refSize: Int) throws -> ValidatedBPlistObjectIndex {
        let raw = bplistData.loadBigEndianUInt64Unchecked(at: byteOffset, byteSize: refSize)
        return try metadata.validatedObjectIndex(raw: raw)
    }
    
    private var objectRangeEndIndex: Int {
        // The end range of valid objects is the same as the beginning of the object offset table.
        self.metadata.offsetTableOffset
    }
    
    /// Byte at `objectOffset`: the raw type marker. Prefer `self.type` for the parsed enum; this is for the paths that need the low nibble (which carries size or count parameters).
    private var markerByte: UInt8 {
        bplistData[objectOffset]
    }

    var isNull: Bool {
        type == .null
    }

    /// String rendering of this primitive's type for `DecodingError` messages. Matches `BPlistLegacyDecodingDocument.Value.debugDataTypeDescription`, plus the `"$null"` sentinel that keyed archivers use for nil.
    var debugDataTypeDescription: String {
        switch type {
        case .null: return "a null value"
        case .false, .true: return "a boolean"
        case .int: return "an integer"
        case .real: return "a real number"
        case .date: return "a date"
        case .data: return "a data value"
        case .asciiString:
            if let span = try? asciiStringSpan,
               span.count == 5,
               span[0] == UInt8(ascii: "$"), span[1] == UInt8(ascii: "n"),
               span[2] == UInt8(ascii: "u"), span[3] == UInt8(ascii: "l"),
               span[4] == UInt8(ascii: "l") {
                return "the string \"$null\""
            }
            return "a string"
        case .utf16String: return "a string"
        case .uid: return "a uid"
        case .array: return "an array"
        case .set: return "a set"
        case .dict: return "a dictionary"
        case .none: return "an invalid bplist value"
        }
    }

    var boolValue: Bool {
        get throws {
            guard let type else {
                throw BPlistError.invalidMarker
            }
            switch type {
            case .true: return true
            case .false: return false
            default: throw BPlistError.typeMismatch(expected: "boolean", actual: type)
            }
        }
    }
    
    /// Encapsulates all the data required to decode integers from bplist format.
    struct EncodedInteger: ~Escapable {
        // The span is expected to always be 8 bytes or less—historically we've never deserialized more than the last 8 bytes of an arbitrarily sized integer.
        // Since unsigned integers may be encoded as 128 bytes (with 64 high zeroes) to differentiate them from signed integers, the presence of those extra bytes is captured in `isUnsigned`.
        let span: RawSpan
        let isUnsigned: Bool

        @_lifetime(copy span)
        internal init(span: RawSpan, isUnsigned: Bool) {
            if isUnsigned {
                assert(span.byteCount == MemoryLayout<UInt64>.size)
            } else {
                assert(span.byteCount <= MemoryLayout<UInt64>.size)
            }
            self.span = span
            self.isUnsigned = isUnsigned
        }

        /// The stored bytes zero-extended to 64 bits, before any signedness interpretation.
        var rawBits: UInt64 {
            span.bplistIntegerValue
        }

        /// Decode this integer encoding into a value of type `T`.
        /// Throws `BPlistError.corruptedValue` if the encoded value cannot be represented in `T`.
        func intValue<T: FixedWidthInteger>(_ type: T.Type = Int.self) throws -> T {
            let bits = rawBits
            let result: T? = isUnsigned ? T(exactly: bits) : T(exactly: Int64(bitPattern: bits))
            guard let value = result else {
                throw BPlistError.corruptedValue("integer overflow")
            }
            return value
        }
    }

    var encodedInteger: EncodedInteger {
        @_lifetime(borrow self)
        get throws {
            guard type == .int else {
                throw BPlistError.typeMismatchOrInvalid(expected: "integer", actual: type)
            }
            let integerSize = 1 << (markerByte & 0x0f)
            guard integerSize <= 16 else {
                throw BPlistError.invalidMarker
            }
            let dataStartIdx = objectOffset + 1
            guard let span = bplistData.getSizedIntSpan(at: dataStartIdx, endIndex: objectRangeEndIndex, size: integerSize) else {
                throw BPlistError.corruptedValue("integer")
            }
            // The historical implementation has always treated integers 8 bytes or less as signed integers. Only the 16-byte form is genuinely unsigned (and only ever encodes UInt64 values > Int64.max).
            return EncodedInteger(span: span, isUnsigned: integerSize > 8)
        }
    }

    var realSpan: RawSpan {
        @_lifetime(borrow self)
        get throws {
            guard type == .real else {
                throw BPlistError.typeMismatchOrInvalid(expected: "real", actual: type)
            }

            let dataStartIdx = objectOffset + 1
            let size: Int
            switch markerByte & 0xf {
            case 2: // 4 byte real
                size = 4
            case 3: // 8 byte real
                size = 8
            default:
                throw BPlistError.invalidMarker
            }
            guard let span = bplistData.getSizedIntSpan(at: dataStartIdx, endIndex: objectRangeEndIndex, size: size) else {
                throw BPlistError.corruptedValue("real")
            }
            return span
        }
    }

    var dateValue: Double {
        get throws {
            guard type == .date else {
                throw BPlistError.typeMismatchOrInvalid(expected: "date", actual: type)
            }

            guard let span = bplistData.getSizedIntSpan(at: objectOffset + 1, endIndex: objectRangeEndIndex, size: MemoryLayout<Double>.size) else {
                throw BPlistError.corruptedValue("date")
            }
            return Double(bitPattern: UInt64(bigEndian: span.unsafeLoadUnaligned(as: UInt64.self)))
        }
    }

    /// Decoded value of a `kCFBinaryPlistMarkerUID` object.
    var uidValue: UInt32 {
        get throws {
            guard type == .uid else {
                throw BPlistError.typeMismatchOrInvalid(expected: "UID", actual: type)
            }
            let count = Int(markerByte & 0x0f) &+ 1
            guard count <= 8 else {
                throw BPlistError.corruptedValue("UID")
            }
            guard let span = bplistData.getSizedIntSpan(at: objectOffset &+ 1, endIndex: objectRangeEndIndex, size: count) else {
                throw BPlistError.corruptedValue("UID")
            }
            let raw = span.bplistIntegerValue
            guard raw <= UInt64(UInt32.max) else {
                throw BPlistError.corruptedValue("UID")
            }
            return UInt32(raw)
        }
    }
    
    /// Decode the length of a variable-length primitive (data, string, array, set, dict) and return its validated byte range within `bplistData`.
    ///
    /// - Parameter unitSize: bytes per counted element (1 for data/ASCII, 2 for UTF-16, `_objectRefSize` for array/set, `2 * _objectRefSize` for dict).
    /// - Parameter errorLabel: type name used in `BPlistError.corruptedValue` messages.
    private func payloadRange(unitSize: Int, for errorLabel: String) throws -> Range<Int> {
        var rawCount = UInt64(markerByte & 0x0f)
        var dataStartIdx = objectOffset + 1
        if rawCount == 0xf {
            rawCount = try bplistData.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for: errorLabel)
        }
        guard let count = Int(exactly: rawCount) else {
            throw BPlistError.corruptedValue(errorLabel)
        }
        let (byteCount, overflow) = count.multipliedReportingOverflow(by: unitSize)
        guard !overflow, dataStartIdx.distance(to: objectRangeEndIndex) >= byteCount else {
            throw BPlistError.corruptedValue(errorLabel)
        }
        return dataStartIdx ..< dataStartIdx &+ byteCount
    }

    var dataSpan: Span<UInt8> {
        @_lifetime(borrow self)
        get throws {
            return Span<UInt8>(viewing: bplistData.extracting(unchecked: try dataPayloadRange))
        }
    }

    /// Validated byte range of a `.data` object's payload within `bplistData`, for callers that need `(offset, count)` rather than a `Span`.
    var dataPayloadRange: Range<Int> {
        get throws {
            guard type == .data else {
                throw BPlistError.typeMismatchOrInvalid(expected: "data", actual: type)
            }
            return try payloadRange(unitSize: MemoryLayout<UInt8>.size, for: "data")
        }
    }

    var isStringType: Bool {
        switch type {
        case .utf16String, .asciiString: true
        default: false
        }
    }

    var asciiStringSpan: Span<UInt8> {
        @_lifetime(borrow self)
        get throws {
            guard type == .asciiString else {
                throw BPlistError.typeMismatchOrInvalid(expected: "ASCII string", actual: type)
            }
            let range = try payloadRange(unitSize: MemoryLayout<UInt8>.size, for: "ASCII string")
            return Span<UInt8>(viewing: bplistData.extracting(unchecked: range))
        }
    }

    var utf16BEStringSpan: RawSpan {
        @_lifetime(borrow self)
        get throws {
            guard type == .utf16String else {
                throw BPlistError.typeMismatchOrInvalid(expected: "UTF16 string", actual: type)
            }
            let range = try payloadRange(unitSize: MemoryLayout<UInt16>.size, for: "UTF16 string")
            return bplistData.extracting(unchecked: range)
        }
    }

    /// Encapsulates all the data required to decode any type of string from bplist format.
    struct EncodedString: ~Escapable {
        enum Kind {
            case ascii
            case utf16BE
        }

        let span: RawSpan
        let kind: Kind
        
        var validatedUTF8Span: UTF8Span?
        var convertedUTF16ToUTF8Storage: [UInt8]?

        @_lifetime(copy span)
        internal init(span: RawSpan, kind: Kind) {
            if kind == .utf16BE {
                assert(span.byteCount % 2 == 0)
            }
            self.span = span
            self.kind = kind
        }
        
        /// The `index`th UTF-16 code unit of a `.utf16BE` payload, byte-swapped to host order.
        @inline(__always)
        private func utf16Unit(at index: Int) -> UInt16 {
            UInt16(bigEndian: span.unsafeLoadUnaligned(fromUncheckedByteOffset: index &* 2, as: UInt16.self))
        }
        
        /// Yields a `.utf16BE` payload's code units in host order, reading straight from the source bytes. Holds a raw pointer rather than a `RawSpan` so it can satisfy `IteratorProtocol`, which requires `Escapable`; callers must keep it inside the `withUnsafeBytes` scope that produced the pointer.
        private struct UTF16BECodeUnits: IteratorProtocol {
            let base: UnsafeRawPointer
            let count: Int
            var index = 0

            mutating func next() -> UTF16.CodeUnit? {
                guard index < count else { return nil }
                let unit = unsafe base.loadUnaligned(fromByteOffset: index &* 2, as: UInt16.self)
                index &+= 1
                return UInt16(bigEndian: unit)
            }
        }

        var decodedUTF8Span: UTF8Span {
            @_lifetime(copy self)
            mutating get throws {
                if let validatedUTF8Span {
                    return validatedUTF8Span
                }

                switch kind {
                case .ascii:
                    guard let utf8 = try? UTF8Span(validating: Span<UInt8>(viewing: span)) else {
                        throw BPlistError.corruptedValue("ASCII string")
                    }
                    validatedUTF8Span = utf8
                    return utf8
                case .utf16BE:
                    var storage = [UInt8]()
                    storage.reserveCapacity(span.byteCount)
                    let hadErrors = span.withUnsafeBytes { raw in
                        let units = unsafe UTF16BECodeUnits(base: raw.baseAddress!, count: raw.count / 2)
                        return transcode(units, from: UTF16.self, to: UTF8.self, stoppingOnError: true) {
                            storage.append($0)
                        }
                    }
                    guard !hadErrors else {
                        throw BPlistError.corruptedValue("UTF16 string")
                    }
                    convertedUTF16ToUTF8Storage = storage
                    
                    // The transcoded bytes live in a heap buffer owned by `self`, so a span over them stays valid for as long as `self` does. Also, `transcode` emitted the UTF-8 encodings of validated scalars, so revalidating would be a redundant O(n) scan.
                    let transcoded = _overrideLifetime(convertedUTF16ToUTF8Storage!.span, copying: self)
                    let utf8 = UTF8Span(unchecked: transcoded, isKnownASCII: false)
                    validatedUTF8Span = utf8
                    return utf8
                }
            }
        }

        /// Decode this string encoding into a Swift `String`.
        var stringValue: String {
            get throws {
                if let validatedUTF8Span {
                    return String(copying: validatedUTF8Span)
                }
                
                switch kind {
                case .ascii:
                    let bytes = Span<UInt8>(viewing: span)
                    do {
                        return String(copying: try UTF8Span(validating: bytes))
                    } catch {
                        throw BPlistError.corruptedValue("ASCII string")
                    }
                case .utf16BE:
                    let utf16Count = span.byteCount / 2
                    let result = withUnsafeTemporaryAllocation(of: UTF16.CodeUnit.self, capacity: utf16Count) { utf16Units in
                        for i in 0..<utf16Count {
                            utf16Units[i] = utf16Unit(at: i)
                        }
                        return String(validating: utf16Units, as: UTF16.self)
                    }
                    guard let result else {
                        throw BPlistError.corruptedValue("UTF16 string")
                    }
                    return result
                }
            }
        }

        /// Returns whether this string encoding represents the same characters as `key`, without materializing a Swift `String`.
        func equals(_ key: UTF8Span) -> Bool {
            if let validatedUTF8Span {
                return key.span.withUnsafeBufferPointer { buffer in
                    validatedUTF8Span.bytesEqual(to: buffer)
                }
            }
            
            switch kind {
            case .ascii:
                let bytes = Span<UInt8>(viewing: span)
                let utf8 = key.span
                guard bytes.count == utf8.count else { return false }
                var idx = 0
                for i in 0..<bytes.count {
                    guard bytes[i] == utf8[idx] else { return false }
                    idx &+= 1
                }
                return true
            case .utf16BE:
                let utf16Count = span.byteCount / 2
                let utf8Count = key.span.count
                // Each UTF-16 code unit encodes to 1...3 UTF-8 bytes, so anything outside these bounds can't match.
                guard utf16Count <= utf8Count, utf8Count <= utf16Count &* 3 else { return false }

                if key.isKnownASCII {
                    let bytes = key.span
                    guard utf16Count == utf8Count else { return false }
                    for i in 0..<utf16Count {
                        guard utf16Unit(at: i) == UInt16(bytes[i]) else { return false }
                    }
                    return true
                }

                // Compare in UTF-16 space: re-encoding each key scalar avoids decoding (and having to validate) the payload's surrogates.
                var index = 0
                var scalars = key.makeUnicodeScalarIterator()
                while let scalar = scalars.next() {
                    for unit in scalar.utf16 {
                        guard index < utf16Count, utf16Unit(at: index) == unit else {
                            return false
                        }
                        index &+= 1
                    }
                }
                return index == utf16Count
            }
        }
        
        /// Convenience for matching Strings.
        func equals(_ key: String) -> Bool {
            return equals(key.utf8Span)
        }
        
    }

    var encodedString: EncodedString {
        @_lifetime(borrow self)
        get throws {
            guard let type else {
                throw BPlistError.invalidMarker
            }
            switch type {
            case .asciiString:
                let range = try payloadRange(unitSize: 1, for: "ASCII string")
                return EncodedString(span: bplistData.extracting(unchecked: range), kind: .ascii)
            case .utf16String:
                let range = try payloadRange(unitSize: MemoryLayout<UInt16>.size, for: "UTF16 string")
                return EncodedString(span: bplistData.extracting(unchecked: range), kind: .utf16BE)
            default:
                throw BPlistError.typeMismatch(expected: "string", actual: type)
            }
        }
    }

    /// Encapsulates all the data required to emit BPlistPrimitives for each of the child elements of a given bplist array or set.
    struct ArraySetIterator: ~Escapable {
        let range: Range<Int>
        let span: RawSpan
        let metadata: BPlistMetadata
        let fullSource: RawSpan
        let forward: Bool
        let count: Int
        let stride: Int

        // Cursor byte offset within `span`. For a forward iterator it is the offset of the next element to read; for a reverse iterator it is one past the next element.
        var position: Int

        @_lifetime(copy fullSource)
        init(uncheckedRange range: Range<Int>, of fullSource: RawSpan, metadata: BPlistMetadata, forward: Bool = true) {
            self.range = range
            self.span = fullSource.extracting(unchecked: range)

            assert(span.byteCount.isMultiple(of: Int(metadata.objectRefSize)))

            self.fullSource = fullSource
            self.metadata = metadata
            self.forward = forward

            self.stride = Int(metadata.objectRefSize)
            self.count = span.byteCount / self.stride

            self.position = forward ? 0 : span.byteCount
        }

        /// Returns a reverse iterator of the entire contents of the array or set.
        var reverseIterator: ArraySetIterator {
            @_lifetime(copy self)
            get {
                .init(uncheckedRange: range, of: fullSource, metadata: metadata, forward: false)
            }
        }

        private func _index(atByteOffset byteOffset: Int) -> UInt64 {
            span.loadBigEndianUInt64Unchecked(at: byteOffset, byteSize: self.stride)
        }

        @_lifetime(copy self)
        mutating func next() throws -> BPlistPrimitive? {
            let readOffset: Int
            if forward {
                guard position < span.byteCount else { return nil }
                readOffset = position
                position &+= stride
            } else {
                guard position > 0 else { return nil }
                position &-= stride
                readOffset = position
            }
            let objectIndex = try self.metadata.validatedObjectIndex(raw: _index(atByteOffset: readOffset))
            return BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: objectIndex)
        }

        /// Random access by index, returning nil if the requested index is out of bounds.
        @_lifetime(copy self)
        mutating func value(atIndex index: Int) throws -> BPlistPrimitive? {
            guard index >= 0, index < count else { return nil }
            let byteOffset = index &* stride
            let objectIndex = try self.metadata.validatedObjectIndex(raw: _index(atByteOffset: byteOffset))
            let result = BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: objectIndex)
            if forward {
                position = byteOffset &+ stride
            } else {
                position = byteOffset
            }
            return result
        }

        /// Resets the cursor to its starting position: the beginning for a forward iterator, or the end for a reverse iterator.
        mutating func reset() {
            position = forward ? 0 : span.byteCount
        }
    }
    
    var arraySetRange: Range<Int> {
        get throws {
            guard let type else {
                throw BPlistError.invalidMarker
            }
            guard type == .array || type == .set else {
                throw BPlistError.typeMismatch(expected: "array", actual: type)
            }
            return try payloadRange(unitSize: self.metadata.objectRefSize, for: "array")
        }
    }

    // RawSpan, because the object index size is variable.
    var arraySetSpan: RawSpan {
        @_lifetime(borrow self)
        get throws {
            return try bplistData.extracting(unchecked: arraySetRange)
        }
    }
    
    var arraySetIterator: ArraySetIterator {
        @_lifetime(copy self)
        get throws {
            return try .init(uncheckedRange: arraySetRange, of: self.bplistData, metadata: self.metadata)
        }
    }
    
    struct DictionaryIterator: ~Escapable {
        let range: Range<Int>
        let span: RawSpan
        let metadata: BPlistMetadata
        let fullSource: RawSpan
        let forward: Bool
        let count: Int
        let refSize: Int
        // Pair-index cursor. Forward: index of next pair to read. Reverse: one past the next pair (next read is `position - 1`).
        var position: Int

        @_lifetime(copy fullSource)
        init(uncheckedRange range: Range<Int>, of fullSource: RawSpan, metadata: BPlistMetadata, forward: Bool = true) {
            self.range = range
            self.span = fullSource.extracting(unchecked: range)

            let refSize = Int(metadata.objectRefSize)
            assert(span.byteCount.isMultiple(of: 2 &* refSize))

            self.fullSource = fullSource
            self.metadata = metadata
            self.forward = forward

            self.refSize = refSize
            self.count = span.byteCount / (2 &* refSize)

            self.position = forward ? 0 : count
        }

        var reverseIterator: DictionaryIterator {
            @_lifetime(copy self)
            get {
                .init(uncheckedRange: range, of: fullSource, metadata: metadata, forward: false)
            }
        }

        private func _objectIndex(atByteOffset byteOffset: Int) -> UInt64 {
            span.loadBigEndianUInt64Unchecked(at: byteOffset, byteSize: refSize)
        }

        private func _keyValueIndexes(atPairIndex pairIndex: Int) throws -> (key: ValidatedBPlistObjectIndex, value: ValidatedBPlistObjectIndex) {
            let keyOffset = pairIndex &* refSize
            let valueOffset = (count &+ pairIndex) &* refSize
            let keyIndex = try metadata.validatedObjectIndex(raw: _objectIndex(atByteOffset: keyOffset))
            let valueIndex = try metadata.validatedObjectIndex(raw: _objectIndex(atByteOffset: valueOffset))
            return (key: keyIndex, value: valueIndex)
        }

        struct KeyValuePair: ~Escapable {
            let key: BPlistPrimitive
            let value: BPlistPrimitive

            @_lifetime(copy key, copy value)
            init(key: BPlistPrimitive, value: BPlistPrimitive) {
                self.key = key
                self.value = value
            }
        }

        @_lifetime(copy self)
        mutating func next() throws -> KeyValuePair? {
            let pairIdx: Int
            if forward {
                guard position < count else { return nil }
                pairIdx = position
                position &+= 1
            } else {
                guard position > 0 else { return nil }
                position &-= 1
                pairIdx = position
            }
            let (keyIdx, valIdx) = try _keyValueIndexes(atPairIndex: pairIdx)
            return KeyValuePair(
                key: BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: keyIdx),
                value: BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: valIdx)
            )
        }

        /// Returns the value for `key` by scanning from the current cursor, wrapping if needed. On hit the cursor advances past the pair (O(1) for in-order lookups); on miss it's restored. Bounded by pair `count`.
        @_lifetime(copy self)
        mutating func value(forKey key: UTF8Span) throws -> BPlistPrimitive? {
            guard count > 0 else { return nil }
            let startPosition = position
            var checked = 0
            while checked < count {
                // Wrap if we ran past the end on a prior probe or call.
                if forward, position == count {
                    position = 0
                } else if !forward, position == 0 {
                    position = count
                }
                let probeIdx = forward ? position : position &- 1

                let (keyIdx, valIdx) = try _keyValueIndexes(atPairIndex: probeIdx)
                let keyPrim = BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: keyIdx)

                // Advance the cursor past this pair. On a match we return immediately with the cursor in this position, ready for the next sequential key.
                if forward {
                    position = probeIdx &+ 1
                } else {
                    position = probeIdx
                }

                let encoding = try keyPrim.encodedString
                if encoding.equals(key) {
                    return BPlistPrimitive(metadata: self.metadata, bplistData: self.fullSource, objectIndex: valIdx)
                }
                checked &+= 1
            }

            // Scanned every pair without a match. Leave the cursor where it started so the iterator's external state is unaffected by the miss.
            position = startPosition
            return nil
        }
        
        /// Convenience for matching Strings
        @_lifetime(copy self)
        mutating func value(forKey key: String) throws -> BPlistPrimitive? {
            return try self.value(forKey: key.utf8Span)
        }

        /// Resets the cursor to its starting position: the beginning for a forward iterator, the end for a reverse iterator.
        mutating func reset() {
            position = forward ? 0 : count
        }
    }
    
    var dictionarySpanRange: Range<Int> {
        get throws {
            guard type == .dict else {
                throw BPlistError.typeMismatchOrInvalid(expected: "dictionary", actual: type)
            }
            // Dict count is pair count; each pair is one key ref + one value ref.
            let refSize = self.metadata.objectRefSize
            return try payloadRange(unitSize: 2 &* refSize, for: "dictionary")
        }
    }

    // RawSpan, because the object index size is variable.
    var dictionarySpan: RawSpan {
        @_lifetime(borrow self)
        get throws {
            let range = try dictionarySpanRange
            return bplistData.extracting(unchecked: range)
        }
    }
    
    var dictionaryIterator: DictionaryIterator {
        @_lifetime(copy self)
        get throws {
            return try .init(uncheckedRange: dictionarySpanRange, of: self.bplistData, metadata: self.metadata)
        }
    }
}

extension RawSpan {
    @_lifetime(borrow self)
    @inline(__always)
    func getBoundsCheckedSizedIntSpan(at byteOffset: Int, byteSize: Int) -> RawSpan {
        assert(byteOffset >= 0 && byteSize >= 0,
               "negative byteOffset (\(byteOffset)) or byteSize (\(byteSize))")
        assert(byteOffset.addingReportingOverflow(byteSize).overflow == false &&
               byteOffset &+ byteSize <= self.byteCount,
               "byteOffset \(byteOffset) + byteSize \(byteSize) > self.byteCount \(self.byteCount)")

        
        switch byteSize {
        case 0...8:
            return self.extracting(unchecked: Range(uncheckedBounds: (byteOffset, byteOffset &+ byteSize)))
        default:
            // Compatibility with existing archives, which could include > 8 byte values, for which we only read the last 8 bytes.
            let significantByteIdx = byteOffset.advanced(by: byteSize &- 8)
            return self.extracting(unchecked: Range(uncheckedBounds: (significantByteIdx, significantByteIdx &+ 8)))
        }
    }

    /// Load a big-endian unsigned integer of `byteSize` bytes at `byteOffset` and return it as `UInt64`. Caller must ensure the range is valid for this span.
    @inline(__always)
    func loadBigEndianUInt64Unchecked(at byteOffset: Int, byteSize: Int) -> UInt64 {
        return getBoundsCheckedSizedIntSpan(at: byteOffset, byteSize: byteSize).bplistIntegerValue
    }

    @_lifetime(borrow self)
    @inline(__always)
    func getSizedIntSpan(at idx: Int, endIndex: Int, size: Int) -> RawSpan? {
        guard endIndex > idx, size <= endIndex &- idx else {
            return nil
        }
        return getBoundsCheckedSizedIntSpan(at: idx, byteSize: size)
    }

    func readInt(updatingIndex idx: inout Int, objectRangeEnd: Int, for type: String) throws -> UInt64 {
        guard idx < objectRangeEnd else {
            throw BPlistError.corruptedValue(type)
        }
        let marker = self[unchecked: idx]
        idx += 1
        guard BPlistTypeMarker.int.matches(marker) else {
            throw BPlistError.corruptedValue(type)
        }
        let sizeOfInteger = 1 << (marker & 0x0f)

        // integers are not required to be in the most compact possible representation, but only the last 64 bits are significant currently, which is the largest span we can get here.
        guard let span = getSizedIntSpan(at: idx, endIndex: objectRangeEnd, size: sizeOfInteger) else {
            throw BPlistError.corruptedValue(type)
        }
        idx &+= sizeOfInteger
        return span.bplistIntegerValue
    }
    
    var bplistIntegerValue: UInt64 {
        let size = self.byteCount
        switch size {
            case MemoryLayout<UInt8>.size:
                return UInt64(self.unsafeLoadUnaligned(as: UInt8.self))
            case MemoryLayout<UInt16>.size:
                return UInt64(UInt16(bigEndian: self.unsafeLoadUnaligned(as: UInt16.self)))
            case MemoryLayout<UInt32>.size:
                return UInt64(UInt32(bigEndian: self.unsafeLoadUnaligned(as: UInt32.self)))
            case MemoryLayout<UInt64>.size:
                return UInt64(bigEndian: self.unsafeLoadUnaligned(as: UInt64.self))
            case 0, 3, 5, 6, 7:
                // Compatibility with existing archives which could have non-power-of-2 size.
                var val : UInt64 = 0
                for i in 0 ..< Int(size) {
                    val = (val << 8) + UInt64(self[unchecked: i])
                }
                return val
            default:
                preconditionFailure("bplist integer spans should be limited to <= 8 bytes")
        }
    }
}

private func addCheckingForOverflow(_ a: UInt64, _ b: UInt64, overflow : inout Bool) -> UInt64 {
    if overflow { return 0 }
    let (result, over) = a.addingReportingOverflow(b)
    overflow = over
    return result
}

enum BPlistError: Swift.Error, Equatable {
    case invalidMarker
    case corruptedValue(String)
    case corruptTopLevelInfo
    case typeMismatch(expected: String, actual: BPlistTypeMarker)

    var debugDescription : String {
        switch self {
        case .invalidMarker: return "Invalid marker"
        case .corruptedValue(let type): return "Corrupt \(type) value"
        case .corruptTopLevelInfo: return "Corrupt top-level info"
        case .typeMismatch(let expected, let actual): return "Type mismatch: expected \(expected), got \(actual)"
        }
    }

    var cocoaError: CocoaError {
        .init(.propertyListReadCorrupt, userInfo: [
            NSDebugDescriptionErrorKey : self.debugDescription
        ])
    }

    /// Distinguishes "unrecognized byte" (`.invalidMarker`) from "recognized but wrong type" (`.typeMismatch`).
    @inline(never)
    static func typeMismatchOrInvalid(expected: String, actual: BPlistTypeMarker?) -> BPlistError {
        guard let actual else {
            return .invalidMarker
        }
        return .typeMismatch(expected: expected, actual: actual)
    }
}
