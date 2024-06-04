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

internal import _CShims

typealias BPlistObjectIndex = Int

private enum BPlistTypeMarker: UInt8 {
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
}

class BPlistMap : PlistDecodingMap {
    internal indirect enum Value {
        case string(Region, isAscii: Bool)
        case array([BPlistObjectIndex])
        case set([BPlistObjectIndex])
        case dict([BPlistObjectIndex:BPlistObjectIndex])
        case data(Region)
        case date(UInt64)
        case boolean(Bool)
        case real(UInt64, byteCount: Int)
        case integer(UInt64, useSignedRepresentation: Bool)
        case uid
        case nativeNull
        case sentinelNull
    }

    struct Region {
        let startOffset: Int
        let count: Int
    }

    @inline(__always)
    static var nullValue: Value { .nativeNull }

    private let trailer : BPlistTrailer
    let topObjectIndex : BPlistObjectIndex
    let objectOffsets : [UInt64]
    var dataLock : LockedState<(buffer: BufferView<UInt8>, allocation: UnsafeRawPointer?)>

    init (buffer: BufferView<UInt8>, trailer: BPlistTrailer, objectOffsets: [UInt64]) {
        self.dataLock = .init(initialState: (buffer: buffer, allocation: nil))
        self.trailer = trailer
        self.topObjectIndex = BPlistObjectIndex(trailer._topObject)
        self.objectOffsets = objectOffsets
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
    func withBuffer<T>(
      for region: Region, perform closure: @Sendable (_ jsonBytes: BufferView<UInt8>, _ fullSource: BufferView<UInt8>) throws -> T
    ) rethrows -> T {
        try dataLock.withLock {
            return try closure($0.buffer[region], $0.buffer)
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

    var topObject : Value {
        get throws {
            try self[topObjectIndex]
        }
    }

    subscript (objectIndex: BPlistObjectIndex) -> Value {
        get throws {
            return try loadValue(at: objectIndex)
        }
    }

    func loadValue(at idx: BPlistObjectIndex) throws -> Value {
        // Sendable note: We do not mutate self from within this lock
        return try dataLock.withLockUnchecked { state in
            guard Int(idx) < objectOffsets.count else {
                throw BPlistError.corruptedValue("object index")
            }
            let offset = objectOffsets[Int(idx)]
            let scanInfo = BPlistScanner(buffer: state.buffer, trailer: trailer)
            return try scanInfo.scanObject(at: offset)
        }
    }
    
    @inline(__always)
    func value(from reference: BPlistObjectIndex) throws -> Value {
        try loadValue(at: reference)
    }
    
    struct ArrayIterator: PlistArrayIterator {
        var iter: [BPlistObjectIndex].Iterator
        
        @inline(__always)
        mutating func next() -> BPlistObjectIndex? {
            iter.next()
        }
    }
    
    struct DictionaryIterator: PlistDictionaryIterator {
        var iter: [BPlistObjectIndex:BPlistObjectIndex].Iterator
        
        @inline(__always)
        mutating func next() -> (key: BPlistObjectIndex, value: BPlistObjectIndex)? {
            iter.next()
        }
    }
}

extension BPlistMap.Value {
    var isNull : Bool {
        switch self {
            case .nativeNull, .sentinelNull:
                return true
            default:
                return false
        }
    }

    func integerValue<T: BinaryInteger>(in map: BPlistMap, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T {
        if case .real = self {
            let double = try self.realValue(in: map, as: Double.self, for: codingPathNode, additionalKey)
            guard let integer = T(exactly: double) else {
                throw DecodingError._dataCorrupted("Property list number <\(double)> does not fit in \(type).", for: codingPathNode, additionalKey)
            }
            return integer
        }

        guard case let .integer(uint64BitPattern, useSignedRep) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: type, reality: self)
        }

        if !useSignedRep {
            guard let val = T(exactly: uint64BitPattern) else {
                throw DecodingError._dataCorrupted("Parsed property list number <\(uint64BitPattern)> does not fit in \(type).", for: codingPathNode, additionalKey)
            }
            return val
        }

        let numAsSint = Int64(bitPattern: uint64BitPattern)
        guard let val = T(exactly: numAsSint) else {
            throw DecodingError._dataCorrupted("Parsed property list number <\(numAsSint)> does not fit in \(type).", for: codingPathNode, additionalKey)
        }
        return val
    }

    func realValue<T: BinaryFloatingPoint>(in map: BPlistMap, as type: T.Type, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> T {
        if case .integer = self {
            if let uintValue = try? self.integerValue(in: map, as: UInt64.self, for: codingPathNode, additionalKey) {
                return T(uintValue)
            }
            let intValue = try self.integerValue(in: map, as: Int64.self, for: codingPathNode, additionalKey)
            return T(intValue)
        }

        guard case let .real(uint64BitPattern, byteCount) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: type, reality: self)
        }

        switch byteCount {
        case MemoryLayout<Float>.size:
            // We only read 4 bytes, so this coercion should never fail.
            let u32 = UInt32(uint64BitPattern)
            let float = Float(bitPattern: u32)
            guard !float.isNaN else {
                return T.nan // T(exactly: X.nan) always returns nil
            }
            guard let result = T(exactly: float) else {
                throw DecodingError._dataCorrupted("Property list number <\(float)> does not fit in \(type).", for: codingPathNode, additionalKey)
            }
            return result
        case MemoryLayout<Double>.size:
            let double = Double(bitPattern: uint64BitPattern)
            guard !double.isNaN else {
                return T.nan // T(exactly: X.nan) always returns nil
            }
            guard let result = T(exactly: double) else {
                throw DecodingError._dataCorrupted("Property list number <\(double)> does not fit in \(type).", for: codingPathNode, additionalKey)
            }
            return result
        default:
            fatalError("Impossible bplist real byte count: \(byteCount)")
        }
    }

    func dataValue(in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Data {
        guard case let .data(region) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Data.self, reality: self)
        }
        return map.withBuffer(for: region) { buffer, _ in
            return Data(bufferView: buffer)
        }
    }

    func dateValue(in map: BPlistMap, for codingPathNode: _CodingPathNode, _ additionalKey: (some CodingKey)? = _CodingKey?.none) throws -> Date {
        guard case let .date(u64Rep) = self else {
            throw DecodingError._typeMismatch(at: codingPathNode.path(byAppending: additionalKey), expectation: Date.self, reality: self)
        }
        let doubleRep = Double(bitPattern: u64Rep)
        return Date(timeIntervalSinceReferenceDate: doubleRep)
    }
}

extension BPlistMap.Value: DecodingErrorValueTypeDebugStringConvertible {
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
        case .set: return "a set"
        case .uid: return "a uid"
        case .nativeNull: return "a null value"
        case .sentinelNull: return "the string \"$null\""
        }
    }
}

fileprivate extension BufferReader {
    @inline(__always)
    func getBoundsCheckedSizedInt(at idx: BufferView<UInt8>.Index, size: Int) -> UInt64 {
        switch size {
        case 1:
            return UInt64(bytes[unchecked: idx])
        case 2:
            var val : UInt16
            val = UInt16(bytes[unchecked: idx]) << 8
            val = val | UInt16(bytes[unchecked: idx.advanced(by: 1)])
            return UInt64(val)
        case 4:
            var val : UInt32
            val = UInt32(bytes[unchecked: idx]) << 24
            val = val | UInt32(bytes[unchecked: idx.advanced(by: 1)]) << 16
            val = val | UInt32(bytes[unchecked: idx.advanced(by: 2)]) << 8
            val = val | UInt32(bytes[unchecked: idx.advanced(by: 3)])
            return UInt64(val)
        case 8:
            var val : UInt64
            val = UInt64(bytes[unchecked: idx]) << 56
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 1)]) << 48
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 2)]) << 40
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 3)]) << 32
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 4)]) << 24
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 5)]) << 16
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 6)]) << 8
            val = val | UInt64(bytes[unchecked: idx.advanced(by: 7)])
            return val
        case 0, 3, 5, 6, 7:
            // Compatibility with existing archives which could have non-power-of-2 size.
            var val : UInt64 = 0
            for i in 0 ..< Int(size) {
                val = (val << 8) + UInt64(bytes[unchecked: idx.advanced(by: i)])
            }
            return val
        default:
            // Compatibility with existing archives, which could include > 8 byte values, for which we only read the last 8 bytes.
            var val : UInt64
            let significantByteIdx = idx.advanced(by: size - 8)
            val = UInt64(bytes[unchecked: significantByteIdx]) << 56
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 1)]) << 48
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 2)]) << 40
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 3)]) << 32
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 4)]) << 24
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 5)]) << 16
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 6)]) << 8
            val = val | UInt64(bytes[unchecked: significantByteIdx.advanced(by: 7)])
            return val
        }
    }
    
    @inline(__always)
    func getSizedInt(at idx: BufferView<UInt8>.Index, endIndex: BufferView<UInt8>.Index, size: Int) -> UInt64? {
        guard size <= idx.distance(to: endIndex) else {
            return nil
        }
        return getBoundsCheckedSizedInt(at: idx, size: size)
    }
    
    func readInt(updatingIndex idx: inout BufferView<UInt8>.Index, objectRangeEnd: BufferView<UInt8>.Index, for type: String) throws -> UInt64 {
        guard idx < objectRangeEnd else {
            throw BPlistError.corruptedValue(type)
        }
        let marker = bytes[unchecked: idx]
        bytes.formIndex(after: &idx)
        guard BPlistTypeMarker(marker) == .int else {
            throw BPlistError.corruptedValue(type)
        }
        let sizeOfInteger = 1 << (marker & 0x0f)

        // integers are not required to be in the most compact possible representation, but only the last 64 bits are significant currently
        guard let result = getSizedInt(at: idx, endIndex: objectRangeEnd, size: sizeOfInteger) else {
            throw BPlistError.corruptedValue(type)
        }
        bytes.formIndex(&idx, offsetBy: sizeOfInteger)
        return result
    }
}

private func addCheckingForOverflow(_ a: UInt64, _ b: UInt64, overflow : inout Bool) -> UInt64 {
    if overflow { return 0 }
    let (result, over) = a.addingReportingOverflow(b)
    overflow = over
    return result
}

internal struct BPlistScanner {
    var reader : BufferReader
    let baseIdx : BufferView<UInt8>.Index
    let trailer : BPlistTrailer
    
    private static let bplistXXLen = 8

    static func hasBPlistMagic(in buff: BufferView<UInt8>) -> Bool {
        guard buff.count >= MemoryLayout<BPlistTrailer>.size + bplistXXLen + 1 else {
            return false
        }
        let reader = BufferReader(bytes: buff)
        guard reader.string(at: buff.startIndex, matches: "bplist0") else {
            return false
        }
        return true
    }

    static func parseTopLevelInfo(from buff: BufferView<UInt8>) -> BPlistTrailer? {
        guard hasBPlistMagic(in: buff) else {
            return nil
        }
        let trailer = buff.withUnsafePointer { buffPtr, buffCount in
            var trailer = BPlistTrailer()
            let trailerBegin = buffPtr + buffCount - MemoryLayout<BPlistTrailer>.size
            _ = withUnsafeMutableBytes(of: &trailer) {
                memmove($0.baseAddress!, trailerBegin, MemoryLayout<BPlistTrailer>.size)
            }
            
            // The bplist format is big endian by definition. On a little-endian machine, the 64-bit values need to be swapped. X.bigEndian is equivalent to "convert big- to host-endianness".
            trailer._numObjects = trailer._numObjects.bigEndian
            trailer._topObject = trailer._topObject.bigEndian
            trailer._offsetTableOffset = trailer._offsetTableOffset.bigEndian
            
            return trailer
        }

        // Don't overflow on the number of objects or offset of the table
        guard trailer._numObjects <= LONG_MAX, trailer._offsetTableOffset <= LONG_MAX else {
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
        guard buff.count - MemoryLayout<BPlistTrailer>.size > trailer._offsetTableOffset else {
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
        guard buff.count == tmpSum else {
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
        guard buff.count > topObjectOffsetOffset else {
            return nil
        }
        let reader = BufferReader(bytes: buff)
        let topObjectOffsetIdx = reader.index(offset: topObjectOffsetOffset)
        guard let topObjectOffset = reader.getSizedInt(at: topObjectOffsetIdx, endIndex: buff.endIndex, size: Int(trailer._offsetIntSize)) else {
            return nil
        }
        // Must fall somewhere after bplistXX and before the beginning of the offset table.
        guard topObjectOffset >= 8, topObjectOffset < trailer._offsetTableOffset else {
            return nil
        }

        return trailer
    }

    init(buffer: BufferView<UInt8>, trailer: BPlistTrailer) {
        self.trailer = trailer
        self.reader = BufferReader(bytes: buffer)
        self.baseIdx = buffer.startIndex
    }

    static func scanBinaryPropertyList(from buffer: BufferView<UInt8>) throws -> BPlistMap {

        guard let trailer = Self.parseTopLevelInfo(from: buffer) else {
            throw BPlistError.corruptTopLevelInfo
        }

        var objectOffsets = [UInt64]()
        let initialCapacity = min(Int(trailer._numObjects), 1024 * 256) // Enforce an arbitrary ceiling for the size we'll attempt to reserve in this array. Untrusted input shouldn't cause us to allocate insane amounts of memory so easily.
        objectOffsets.reserveCapacity(initialCapacity)

        // Ensure that all object offsets in the archive are valid. This enables us to access the buffer later without redundant bounds checking.
        let reader = BufferReader(bytes: buffer)
        var objectTableCursor = buffer.startIndex.advanced(by: Int(trailer._offsetTableOffset))
        let endIdx = buffer.endIndex
        let maxOffset = trailer._offsetTableOffset - 1
        for _ in 0 ..< trailer._numObjects {
            guard let off = reader.getSizedInt(at: objectTableCursor, endIndex: endIdx, size: Int(trailer._offsetIntSize)), off <= maxOffset else {
                throw BPlistError.corruptTopLevelInfo
            }

            objectOffsets.append(off)
            buffer.formIndex(&objectTableCursor, offsetBy: Int(trailer._offsetIntSize))
        }

        return .init(buffer: buffer, trailer: trailer, objectOffsets: objectOffsets)
    }
    
    func scanObject(at offset: UInt64) throws -> BPlistMap.Value {
        let idx = reader.index(offset: try Int(bplistSafe: offset))
        let rawMarker = reader.char(at: idx)

        let objectRangeEndIdx = baseIdx.advanced(by: Int(trailer._offsetTableOffset))

        let typeMarker = BPlistTypeMarker(rawMarker)
        switch typeMarker {
        case .null:
            return .nativeNull
        case .false:
            return .boolean(false)
        case .true:
            return .boolean(true)
        case .int:
            return try scanInteger(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .real:
            return try scanReal(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .date:
            return try scanDate(index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .data:
            return try scanData(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .asciiString:
            return try scanASCIIString(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .utf16String:
            return try scanUTF16BEString(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .uid:
            // NSKeyedArchiver UIDs are unused by PropertyListDecoder, so we don't really need to bother parsing their data.
            return .uid
        case .array, .set:
            return try scanArrayOrSet(typeMarker: typeMarker!, rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        case .dict:
            return try scanDictionary(rawTypeMarker: rawMarker, index: idx, objectRangeEndIndex: objectRangeEndIdx)
        default:
            throw BPlistError.invalidMarker
        }
    }
    
    private func scanInteger(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        let integerSize = 1 << (rawTypeMarker & 0x0f)
        guard integerSize <= 16 else {
            throw BPlistError.invalidMarker
        }
        // Anything over 8 bytes is definitely supposed to be interpreted as an unsigned value. However, only the least signifiant 8 bytes are respected. On the encoding side, for 64-bit unsigned integers, the top 8 bytes are always all zeroes. This is how we differentiate UInt64.max and Int64(-1)
        let dataStartIdx = idx.advanced(by: 1)
        guard let integer = reader.getSizedInt(at: dataStartIdx, endIndex: objectRangeEndIndex, size: integerSize) else {
            throw BPlistError.corruptedValue("integer")
        }
        return .integer(integer, useSignedRepresentation: integerSize <= MemoryLayout<UInt64>.size)
    }
    
    private func scanReal(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        let dataStartIdx = idx.advanced(by: 1)
        switch rawTypeMarker & 0xf {
        case 2: // 4 byte real
            guard let integer = reader.getSizedInt(at: dataStartIdx, endIndex: objectRangeEndIndex, size: 4) else {
                throw BPlistError.corruptedValue("real")
            }
            return .real(integer, byteCount: 4)
        case 3: // 8 byte real
            guard let integer = reader.getSizedInt(at: dataStartIdx, endIndex: objectRangeEndIndex, size: 8) else {
                throw BPlistError.corruptedValue("real")
            }
            return .real(integer, byteCount: 8)
        default:
            throw BPlistError.invalidMarker
        }
    }
    
    private func scanDate(index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        let dataStartIdx = idx.advanced(by: 1)
        guard let integer = reader.getSizedInt(at: dataStartIdx, endIndex: objectRangeEndIndex, size: 8) else {
            throw BPlistError.corruptedValue("date")
        }
        return .date(integer)
    }
    
    private func scanData(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        var count = UInt64(rawTypeMarker & 0x0f)
        var dataStartIdx = idx.advanced(by: 1)
        if count == 0xf {
            count = try reader.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for: "data")
        }
        guard dataStartIdx.distance(to: objectRangeEndIndex) >= count else {
            throw BPlistError.corruptedValue("data")
        }

        return .data(.init(startOffset: baseIdx.distance(to: dataStartIdx), count: Int(count)))
    }
    
    private func scanASCIIString(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        var count = UInt64(rawTypeMarker & 0x0f)
        var dataStartIdx = idx.advanced(by: 1)
        if count == 0xf {
            count = try reader.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for: "ASCII string")
        }
        guard dataStartIdx.distance(to: objectRangeEndIndex) >= count else {
            throw BPlistError.corruptedValue("ASCII string")
        }

        // Yes, this means that JSONDecoder does not allow recognizing an encoded string value of "$null" as a string. It will always be treated as a null value. This has always been true for JSONDecoder, despite it not being true for NSJSONSerialization.
        if count == _plistNull.utf8CodeUnitCount, reader.char(at: dataStartIdx) == UInt8(ascii: "$"), reader.string(at: dataStartIdx, matches: _plistNull) {
            return .sentinelNull
        }
        return .string(.init(startOffset: baseIdx.distance(to: dataStartIdx), count: Int(count)), isAscii: true)
    }
    
    private func scanUTF16BEString(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        var count = UInt64(rawTypeMarker & 0x0f)
        var dataStartIdx = idx.advanced(by: 1)
        if count == 0xf {
            count = try reader.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for: "UTF16 string")
        }
        guard dataStartIdx.distance(to: objectRangeEndIndex) >= count else {
            throw BPlistError.corruptedValue("UTF16 string")
        }
        let (byteCount, overflow) = count.multipliedReportingOverflow(by: 2) // 2 bytes per character
        guard !overflow else {
            throw BPlistError.corruptedValue("UTF16 string")
        }

        // We never emit "$null" as a UTF16 value in bplist, so we shouldn't need to try to detect it here.
        return .string(.init(startOffset: baseIdx.distance(to: dataStartIdx), count: Int(byteCount)), isAscii: false)
    }
    
    private func scanArrayOrSet(typeMarker: BPlistTypeMarker, rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        var count = UInt64(rawTypeMarker & 0x0f)
        var dataStartIdx = idx.advanced(by: 1)
        if count == 0xf {
            count = try reader.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for: "array")
        }
        let refSize = Int(trailer._objectRefSize)
        let (byteCount, overflow) = count.multipliedReportingOverflow(by: UInt64(refSize))
        guard !overflow, dataStartIdx.distance(to: objectRangeEndIndex) >= Int(byteCount) else {
            throw BPlistError.corruptedValue("array")
        }
        var indexCursor = dataStartIdx
        var arr = [BPlistObjectIndex]()
        
        let initialCapacity = min(count, 1024 * 256) // Enforce an arbitrary ceiling for the size we'll attempt to reserve in this array. Untrusted input shouldn't cause us to allocate insane amounts of memory so easily.
        arr.reserveCapacity(Int(initialCapacity))
        
        for _ in 0..<Int(count) {
            arr.append(try Int(bplistSafe: reader.getBoundsCheckedSizedInt(at: indexCursor, size: refSize)))
            reader.bytes.formIndex(&indexCursor, offsetBy: refSize)
        }
        return (typeMarker == .array) ? .array(arr) : .set(arr)
    }
    
    private func scanDictionary(rawTypeMarker: UInt8, index idx: BufferViewIndex<UInt8>, objectRangeEndIndex: BufferViewIndex<UInt8>) throws -> BPlistMap.Value {
        var count = UInt64(rawTypeMarker & 0x0f)
        var dataStartIdx = idx.advanced(by: 1)
        if count == 0xf {
            count = try reader.readInt(updatingIndex: &dataStartIdx, objectRangeEnd: objectRangeEndIndex, for:  "dictionary")
        }
        let (keyPlusObjectCount, overflow) = count.multipliedReportingOverflow(by: 2) // key + object per "count"
        guard !overflow else {
            throw BPlistError.corruptedValue("dictionary")
        }
        let refSize = Int(trailer._objectRefSize)
        let (byteCount, overflow2) = keyPlusObjectCount.multipliedReportingOverflow(by: UInt64(refSize))
        guard !overflow2, dataStartIdx.distance(to: objectRangeEndIndex) >= Int(byteCount) else {
            throw BPlistError.corruptedValue("dictionary")
        }
        var dict = [BPlistObjectIndex:BPlistObjectIndex](minimumCapacity: Int(count))
        let offsetFromKeyToObject = Int(count) * Int(trailer._objectRefSize)
        var keyIndexCursor = dataStartIdx
        for _ in 0..<Int(count) {
            let keyIdx = try Int(bplistSafe: reader.getBoundsCheckedSizedInt(at: keyIndexCursor, size: refSize))
            let valIdx = try Int(bplistSafe: reader.getBoundsCheckedSizedInt(at: keyIndexCursor.advanced(by: offsetFromKeyToObject), size: refSize))
            dict[keyIdx] = valIdx
            reader.bytes.formIndex(&keyIndexCursor, offsetBy: refSize)
        }
        return .dict(dict)

    }
}


extension Int {
    @inline(__always)
    init (bplistSafe val: some FixedWidthInteger) throws {
        guard let i = Int(exactly: val) else {
            throw BPlistError.corruptedValue("integer")
        }
        self = i
    }
}


enum BPlistError: Swift.Error, Equatable {
    case invalidMarker
    case corruptedValue(String)
    case corruptTopLevelInfo

    var debugDescription : String {
        switch self {
        case .invalidMarker: return "Invalid marker"
        case .corruptedValue(let type): return "Corrupt \(type) value"
        case .corruptTopLevelInfo: return "Corrupt top-level info"
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
    internal subscript(region: BPlistMap.Region) -> BufferView {
        slice(from: region.startOffset, count: region.count)
    }

    internal subscript(unchecked region: BPlistMap.Region) -> BufferView {
        uncheckedSlice(from: region.startOffset, count: region.count)
    }
}
