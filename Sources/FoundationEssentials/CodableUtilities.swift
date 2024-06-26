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

#if canImport(Darwin)
import Darwin
#elseif os(Android)
import Bionic
#elseif canImport(Glibc)
import Glibc
#endif

//===----------------------------------------------------------------------===//
// Coding Path Node
//===----------------------------------------------------------------------===//

// This construction allows overall fewer and smaller allocations as the coding path is modified.
internal enum _CodingPathNode : Sendable {
    case root
    indirect case node(CodingKey, _CodingPathNode, depth: Int)
    indirect case indexNode(Int, _CodingPathNode, depth: Int)

    var path : [CodingKey] {
        switch self {
        case .root:
            return []
        case let .node(key, parent, _):
            return parent.path + [key]
        case let .indexNode(index, parent, _):
            return parent.path + [_CodingKey(index: index)]
        }
    }

    @inline(__always)
    var depth: Int {
        switch self {
        case .root: return 0
        case .node(_, _, let depth), .indexNode(_, _, let depth): return depth
        }
    }

    @inline(__always)
    func appending(_ key: __owned (some CodingKey)?) -> _CodingPathNode {
        if let key {
            return .node(key, self, depth: self.depth + 1)
        } else {
            return self
        }
    }

    @inline(__always)
    func path(byAppending key: __owned (some CodingKey)?) -> [CodingKey] {
        if let key {
            return self.path + [key]
        }
        return self.path
    }

    // Specializations for indexes, commonly used by unkeyed containers.
    @inline(__always)
    func appending(index: __owned Int) -> _CodingPathNode {
        .indexNode(index, self, depth: self.depth + 1)
    }

    func path(byAppendingIndex index: __owned Int) -> [CodingKey] {
        self.path + [_CodingKey(index: index)]
    }
}

//===----------------------------------------------------------------------===//
// Shared Key Type
//===----------------------------------------------------------------------===//

internal enum _CodingKey : CodingKey {
    case string(String)
    case int(Int)
    case index(Int)
    case both(String, Int)

    @inline(__always)
    public init?(stringValue: String) {
        self = .string(stringValue)
    }

    @inline(__always)
    public init?(intValue: Int) {
        self = .int(intValue)
    }

    @inline(__always)
    internal init(index: Int) {
        self = .index(index)
    }

    @inline(__always)
    init(stringValue: String, intValue: Int?) {
        if let intValue {
            self = .both(stringValue, intValue)
        } else {
            self = .string(stringValue)
        }
    }

    var stringValue: String {
        switch self {
        case let .string(str): return str
        case let .int(int): return "\(int)"
        case let .index(index): return "Index \(index)"
        case let .both(str, _): return str
        }
    }

    var intValue: Int? {
        switch self {
        case .string: return nil
        case let .int(int): return int
        case let .index(index): return index
        case let .both(_, int): return int
        }
    }

    internal static let `super` = _CodingKey.string("super")
}


//===----------------------------------------------------------------------===//
// Character reading conveniences
//===----------------------------------------------------------------------===//

extension UInt8 {
    
    internal static var _space: UInt8 { UInt8(ascii: " ") }
    internal static var _return: UInt8 { UInt8(ascii: "\r") }
    internal static var _newline: UInt8 { UInt8(ascii: "\n") }
    internal static var _tab: UInt8 { UInt8(ascii: "\t") }

    internal static var _colon: UInt8 { UInt8(ascii: ":") }
    internal static let _semicolon = UInt8(ascii: ";")
    internal static var _comma: UInt8 { UInt8(ascii: ",") }

    internal static var _openbrace: UInt8 { UInt8(ascii: "{") }
    internal static var _closebrace: UInt8 { UInt8(ascii: "}") }

    internal static var _openbracket: UInt8 { UInt8(ascii: "[") }
    internal static var _closebracket: UInt8 { UInt8(ascii: "]") }

    internal static let _openangle = UInt8(ascii: "<")
    internal static let _closeangle = UInt8(ascii: ">")
    
    internal static var _quote: UInt8 { UInt8(ascii: "\"") }
    internal static var _backslash: UInt8 { UInt8(ascii: "\\") }
    internal static var _forwardslash: UInt8 { UInt8(ascii: "/") }

    internal static var _equal: UInt8 { UInt8(ascii: "=") }
    internal static var _minus: UInt8 { UInt8(ascii: "-") }
    internal static var _plus: UInt8 { UInt8(ascii: "+") }
    internal static var _question: UInt8 { UInt8(ascii: "?") }
    internal static var _exclamation: UInt8 { UInt8(ascii: "!") }
    internal static var _ampersand: UInt8 { UInt8(ascii: "&") }
    internal static var _pipe: UInt8 { UInt8(ascii: "|") }
    internal static var _period: UInt8 { UInt8(ascii: ".") }
    internal static var _e: UInt8 { UInt8(ascii: "e") }
    internal static var _E: UInt8 { UInt8(ascii: "E") }

    internal var digitValue: Int? {
        guard _asciiNumbers.contains(self) else { return nil }
        return Int(self &- UInt8(ascii: "0"))
    }

    internal var isLetter: Bool? {
        return (0x41 ... 0x5a) ~= self || (0x61 ... 0x7a) ~= self
    }
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

//===----------------------------------------------------------------------===//
// Date parsing conveniences
//===----------------------------------------------------------------------===//

// A narrow reproduction of deprecated CFGregorianDate functionality for property list serialization usage.
internal extension Date {
    static func isLeapYear(_ year: Int64) -> Bool {
        var y = (year + 1) % 400
        if y < 0 { y = -y }
        return 0 == (y & 3) && y != 100 && y != 200 && y != 300
    }

    static func daysInYear(_ year: Int64) -> Int16 {
        let DAYS_PER_YEAR = Int16(365)
        return DAYS_PER_YEAR &+ (isLeapYear(year) ? 1 : 0)
    }

    static func daysBeforeMonth(_ month: Int8, year: Int64) -> Int16? {
        switch month {
        case 1:  return 0
        case 2:  return 31
        case 3:  return 59  + (isLeapYear(year) ? 1 : 0)
        case 4:  return 90  + (isLeapYear(year) ? 1 : 0)
        case 5:  return 120 + (isLeapYear(year) ? 1 : 0)
        case 6:  return 151 + (isLeapYear(year) ? 1 : 0)
        case 7:  return 181 + (isLeapYear(year) ? 1 : 0)
        case 8:  return 212 + (isLeapYear(year) ? 1 : 0)
        case 9:  return 243 + (isLeapYear(year) ? 1 : 0)
        case 10: return 273 + (isLeapYear(year) ? 1 : 0)
        case 11: return 304 + (isLeapYear(year) ? 1 : 0)
        case 12: return 334 + (isLeapYear(year) ? 1 : 0)
        case 13: return 365 + (isLeapYear(year) ? 1 : 0) // Days before the end of December
        default: return nil
        }
    }
    
    static func daysAfterMonth(_ month: Int8, year: Int64) -> Int16 {
        switch month {
        case 0:  return 365 + (isLeapYear(year) ? 1 : 0)
        case 1:  return 334 + (isLeapYear(year) ? 1 : 0)
        case 2:  return 306
        case 3:  return 275
        case 4:  return 245
        case 5:  return 214
        case 6:  return 184
        case 7:  return 153
        case 8:  return 122
        case 9:  return 92
        case 10: return 61
        case 11: return 31
        default: return 0
        }
    }

    /* year arg is absolute year; Gregorian 2001 == year 0; 2001/1/1 = absolute date 0 */
    static func daysSinceReferenceDate(year: Int64, month: Int8, day: Int8) -> Double {
        let DAYS_PER_400_YEARS = 146097.0
        let num400YearChunks = year / 400 // take care of as many multiples of 400 years as possible
        var result = Double(num400YearChunks) * DAYS_PER_400_YEARS
        let remainingYears = year - num400YearChunks &* 400
        if remainingYears < 0 {
            for curYear in remainingYears ..< 0 {
                result -= Double(daysInYear(curYear))
            }
        } else {
            for curYear in 0 ..< remainingYears {
                result += Double(daysInYear(curYear))
            }
        }
        if let daysBeforeMonth = daysBeforeMonth(month, year: year) {
            result += Double(daysBeforeMonth)
        } // else, an invalid month was previded and the result is just undefined.
        result += Double(day - 1)
        return result
    }

    init(gregorianYear year: Int64, month: Int8, day: Int8, hour: Int8, minute: Int8, second: Double) {
        let SECONDS_IN_DAY = 86400.0
        let REFERENCE_YEAR = Int64(2001)
        var timeInterval = SECONDS_IN_DAY * Self.daysSinceReferenceDate(year: year - REFERENCE_YEAR, month: month, day: day)

        let SECONDS_PER_HOUR = 3600.0
        let SECONDS_PER_MINUTE = 60.0
        timeInterval += Double(hour) * SECONDS_PER_HOUR + Double(minute) * SECONDS_PER_MINUTE + Double(second)

        // No time zone considerations necessary here.

        self = Date(timeIntervalSinceReferenceDate: timeInterval)
    }
    
    // year is absolute year; Gregorian 2001 == year 0; 2001/1/1 = absolute date 0
    private static func gregorianYMD(from absolute: Int64) -> (year: Int64, month: Int8, day: Int8) {
        var absolute = absolute
        let b = absolute / 146097 // take care of as many multiples of 400 years as possible
        var y = b * 400
        
        var ydays: Int64
        absolute -= b * 146097
        while absolute < 0 {
            y -= 1
            absolute += Int64(daysAfterMonth(0, year: y))
        }
        
        // Now absolute is non-negative days to add to year
        ydays = Int64(daysAfterMonth(0, year: y))
        while ydays <= absolute {
            y += 1
            absolute -= ydays
            ydays = Int64(daysAfterMonth(0, year: y))
        }
        
        // Now we have year and days-into-year
        var m = Int8(absolute / 33 + 1) //search from the approximation
        
        // Calculations above should guarantee that 0 <= absolute < 365, meaning 1 <= m <= 12. However, m+1 may well become out of bounds.
        while let dbm = daysBeforeMonth(m + 1, year: y), dbm < absolute {
            m &+= 1
        }
        
        let d = Int8(absolute - Int64(daysBeforeMonth(m, year: y)!) + 1)
        
        return (y, m, d)
    }
}

//===----------------------------------------------------------------------===//
// Integer parsing conveniences
//===----------------------------------------------------------------------===//

internal
func _parseIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: BufferView<UInt8>, isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8

    let numericalUpperBound: UInt8 = _0 &+ 10
    let multiplicand: Result = 10
    var result: Result = 0

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

internal
func _parseHexIntegerDigits<Result: FixedWidthInteger>(
    _ codeUnits: BufferView<UInt8>, isNegative: Bool
) -> Result? {
    guard _fastPath(!codeUnits.isEmpty) else { return nil }

    // ASCII constants, named for clarity:
    let _0 = 48 as UInt8, _A = 65 as UInt8, _a = 97 as UInt8

    let numericalUpperBound = _0 &+ 10
    let uppercaseUpperBound = _A &+ 6
    let lowercaseUpperBound = _a &+ 6
    let multiplicand: Result = 16

    var result = 0 as Result
    for digit in codeUnits {
        let digitValue: Result
        if _fastPath(digit >= _0 && digit < numericalUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _0)
        } else if _fastPath(digit >= _A && digit < uppercaseUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _A &+ 10)
        } else if _fastPath(digit >= _a && digit < lowercaseUpperBound) {
            digitValue = Result(truncatingIfNeeded: digit &- _a &+ 10)
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

//===----------------------------------------------------------------------===//
// Error handling conveniences
//===----------------------------------------------------------------------===//

internal
extension DecodingError {
    static func _dataCorrupted(_ debugDescription: String, for node: _CodingPathNode, _ additionalKey: (some CodingKey)?) -> Self {
        Self.dataCorrupted(.init(codingPath: node.path(byAppending: additionalKey), debugDescription: debugDescription))
    }

    static func _dataCorrupted(_ debugDescription: String, for node: _CodingPathNode) -> Self {
        Self.dataCorrupted(.init(codingPath: node.path, debugDescription: debugDescription))
    }
}

//===----------------------------------------------------------------------===//
// Shared Plist Null Representation
//===----------------------------------------------------------------------===//

// Since plists do not support null values by default, we will encode them as "$null".
internal let _plistNull: StaticString = "$null"
internal let _plistNullString: String = String("$null")

//===----------------------------------------------------------------------===//
// Plist Decoding Storage
//===----------------------------------------------------------------------===//

internal struct _PlistDecodingStorage<T> {
    // MARK: Properties

    /// The container stack.
    internal var containers: [T] = []

    // MARK: - Initialization

    /// Initializes `self` with no containers.
    internal init() {}

    // MARK: - Modifying the Stack

    internal var count: Int {
        return self.containers.count
    }

    internal var topContainer: T {
        precondition(!self.containers.isEmpty, "Empty container stack.")
        return self.containers.last.unsafelyUnwrapped
    }

    internal mutating func push(container: __owned T) {
        self.containers.append(container)
    }

    internal mutating func popContainer() {
        precondition(!self.containers.isEmpty, "Empty container stack.")
        self.containers.removeLast()
    }
}

//===----------------------------------------------------------------------===//
// Buffer Reader
//===----------------------------------------------------------------------===//

struct BufferReader {
    let fullBuffer: BufferView<UInt8>
    let startIndex: BufferViewIndex<UInt8>
    var readIndex: BufferViewIndex<UInt8>
    let endIndex: BufferViewIndex<UInt8>

    @inline(__always)
    init(bytes: BufferView<UInt8>) {
        self.fullBuffer = bytes
        self.startIndex = bytes.startIndex
        self.readIndex = bytes.startIndex
        self.endIndex = bytes.endIndex
    }
    
    @inline(__always)
    init(bytes: BufferView<UInt8>, fullSource: BufferView<UInt8>) {
        self.fullBuffer = fullSource
        self.startIndex = bytes.startIndex
        self.readIndex = bytes.startIndex
        self.endIndex = bytes.endIndex
    }

    @inline(__always)
    var isAtEnd : Bool {
        readIndex == endIndex
    }

    @inline(__always)
    func hasBytes(_ num: Int) -> Bool {
        readIndex.advanced(by: num) <= endIndex
    }

    @inline(__always)
    func index(offset: Int) -> BufferViewIndex<UInt8> {
        readIndex.advanced(by: offset)
    }
    
    @inline(__always)
    func byteOffset(at index: BufferViewIndex<UInt8>) -> Int {
        fullBuffer.distance(from: fullBuffer.startIndex, to: index)
    }
    
    @inline(__always)
    mutating func read() -> UInt8? {
        guard !isAtEnd else {
            return nil
        }

        defer { fullBuffer.formIndex(after: &readIndex) }
        return fullBuffer[unchecked: readIndex]
    }
    
    @inline(__always)
    func peek() -> UInt8? {
        hasBytes(1) ? remainingBuffer[unchecked: readIndex] : nil
    }
    
    @_disfavoredOverload
    @inline(__always)
    func peek() -> (UInt8, UInt8)? {
        let buf = remainingBuffer
        return hasBytes(2) ? (buf[uncheckedOffset: 0],
                              buf[uncheckedOffset: 1]) : nil
    }
    
    @_disfavoredOverload
    @inline(__always)
    func peek() -> (UInt8, UInt8, UInt8)? {
        let buf = remainingBuffer
        return hasBytes(3) ? (buf[uncheckedOffset: 0],
                              buf[uncheckedOffset: 1],
                              buf[uncheckedOffset: 2]) : nil
    }

    @inline(__always)
    func char(at index: BufferViewIndex<UInt8>) -> UInt8 {
        return fullBuffer[index]
    }

    @inline(__always)
    mutating func advance(_ amt: Int = 1) {
        advance(&readIndex, by: amt)
    }
    
    @inline(__always)
    func advance(_ idx: inout BufferViewIndex<UInt8>, by amt: Int = 1) {
        fullBuffer.formIndex(&idx, offsetBy: amt)
    }

    @inline(__always)
    func string(at dataIdx: BufferViewIndex<UInt8>, matches ptr: UnsafePointer<UInt8>, length: Int) -> Bool {
        fullBuffer[dataIdx...].withUnsafeRawPointer { bufPtr, _ in
            memcmp(bufPtr, ptr, length) == 0
        }
    }

    @inline(__always)
    func string(at dataidx: BufferViewIndex<UInt8>, matches str: StaticString) -> Bool {
        string(at: dataidx, matches: str.utf8Start, length: str.utf8CodeUnitCount)
    }

    @inline(__always)
    var bytes : BufferView<UInt8> {
        fullBuffer[startIndex..<self.endIndex]
    }

    @inline(__always)
    var remainingBuffer : BufferView<UInt8> {
        fullBuffer[self.readIndex..<self.endIndex]
    }

    var lineNumber : Int {
        assert(readIndex <= endIndex)

        var count = 1
        var p = startIndex
        while p < readIndex {
            if fullBuffer[unchecked: p] == ._return {
                count += 1
                let nextIndex = p.advanced(by: 1)
                if nextIndex < readIndex && fullBuffer[unchecked: nextIndex] == ._newline {
                    p = nextIndex
                }
            } else if fullBuffer[offset: 1] == ._newline {
                count += 1
            }
            fullBuffer.formIndex(&p, offsetBy: 1)
        }
        return count
    }
}

//===----------------------------------------------------------------------===//
// UTF-8 Decoding
//===----------------------------------------------------------------------===//

// These UTF-8 decoding functions are cribbed and specialized from the stdlib.

@inline(__always)
private func _utf8ScalarLength(_ x: UInt8) -> Int? {
    guard !UTF8.isContinuation(x) else { return nil }
    if UTF8.isASCII(x) { return 1 }
    return (~x).leadingZeroBitCount
}

@inline(__always)
private func _continuationPayload(_ x: UInt8) -> UInt32 {
    return UInt32(x & 0x3F)
}

@inline(__always)
private func _decodeUTF8(_ x: UInt8) -> Unicode.Scalar? {
    guard UTF8.isASCII(x) else { return nil }
    return Unicode.Scalar(x)
}

@inline(__always)
private func _decodeUTF8(_ x: UInt8, _ y: UInt8) -> Unicode.Scalar? {
    assert(_utf8ScalarLength(x) == 2)
    guard UTF8.isContinuation(y) else { return nil }
    let x = UInt32(x)
    let value = ((x & 0b0001_1111) &<< 6) | _continuationPayload(y)
    return Unicode.Scalar(value).unsafelyUnwrapped
}

@inline(__always)
private func _decodeUTF8(
  _ x: UInt8, _ y: UInt8, _ z: UInt8
) -> Unicode.Scalar? {
    assert(_utf8ScalarLength(x) == 3)
    guard UTF8.isContinuation(y), UTF8.isContinuation(z) else { return nil }
    let x = UInt32(x)
    let value = ((x & 0b0000_1111) &<< 12)
    | (_continuationPayload(y) &<< 6)
    | _continuationPayload(z)
    return Unicode.Scalar(value).unsafelyUnwrapped
}

@inline(__always)
private func _decodeUTF8(
  _ x: UInt8, _ y: UInt8, _ z: UInt8, _ w: UInt8
) -> Unicode.Scalar? {
    assert(_utf8ScalarLength(x) == 4)
    guard UTF8.isContinuation(y), UTF8.isContinuation(z), UTF8.isContinuation(w) else { return nil }
    let x = UInt32(x)
    let value = ((x & 0b0000_1111) &<< 18)
    | (_continuationPayload(y) &<< 12)
    | (_continuationPayload(z) &<< 6)
    | _continuationPayload(w)
    return Unicode.Scalar(value).unsafelyUnwrapped
}

extension BufferView where Element == UInt8 {
    internal func _decodeScalar() -> (Unicode.Scalar?, scalarLength: Int) {
        let cu0 = self[uncheckedOffset: 0]
        guard let len = _utf8ScalarLength(cu0), self.count >= len else { return (nil, 0) }
        switch len {
        case 1:
            return (_decodeUTF8(cu0), len)
        case 2:
            return (_decodeUTF8(cu0, self[uncheckedOffset: 1]), len)
        case 3:
            return (_decodeUTF8(cu0, self[uncheckedOffset: 1], self[uncheckedOffset: 2]), len)
        case 4:
            return (_decodeUTF8(cu0, self[uncheckedOffset: 1], self[uncheckedOffset: 2], self[uncheckedOffset: 3]), len)
        default:
            fatalError()
        }
    }
}

