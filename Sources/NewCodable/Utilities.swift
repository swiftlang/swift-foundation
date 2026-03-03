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


//===----------------------------------------------------------------------===//
// Shared Key Type
//===----------------------------------------------------------------------===//

@usableFromInline
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

    @usableFromInline
    var stringValue: String {
        switch self {
        case let .string(str): return str
        case let .int(int): return "\(int)"
        case let .index(index): return "Index \(index)"
        case let .both(str, _): return str
        }
    }

    @usableFromInline
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

    @_alwaysEmitIntoClient @inlinable internal static var _space: UInt8 { UInt8(ascii: " ") }
    @_alwaysEmitIntoClient @inlinable internal static var _return: UInt8 { UInt8(ascii: "\r") }
    @_alwaysEmitIntoClient @inlinable internal static var _newline: UInt8 { UInt8(ascii: "\n") }
    @_alwaysEmitIntoClient @inlinable internal static var _tab: UInt8 { UInt8(ascii: "\t") }

    @_alwaysEmitIntoClient @inlinable internal static var _colon: UInt8 { UInt8(ascii: ":") }
    @_alwaysEmitIntoClient @inlinable internal static var _semicolon: UInt8 { UInt8(ascii: ";") }
    @_alwaysEmitIntoClient @inlinable internal static var _comma: UInt8 { UInt8(ascii: ",") }

    @_alwaysEmitIntoClient @inlinable internal static var _openbrace: UInt8 { UInt8(ascii: "{") }
    @_alwaysEmitIntoClient @inlinable internal static var _closebrace: UInt8 { UInt8(ascii: "}") }

    @_alwaysEmitIntoClient @inlinable internal static var _openbracket: UInt8 { UInt8(ascii: "[") }
    @_alwaysEmitIntoClient @inlinable internal static var _closebracket: UInt8 { UInt8(ascii: "]") }

    @_alwaysEmitIntoClient @inlinable internal static var _openangle: UInt8 { UInt8(ascii: "<") }
    @_alwaysEmitIntoClient @inlinable internal static var _closeangle: UInt8 { UInt8(ascii: ">") }

    @_alwaysEmitIntoClient @inlinable internal static var _quote: UInt8 { UInt8(ascii: "\"") }
    @_alwaysEmitIntoClient @inlinable internal static var _backslash: UInt8 { UInt8(ascii: "\\") }
    @_alwaysEmitIntoClient @inlinable internal static var _forwardslash: UInt8 { UInt8(ascii: "/") }

    @_alwaysEmitIntoClient @inlinable internal static var _equal: UInt8 { UInt8(ascii: "=") }
    @_alwaysEmitIntoClient @inlinable internal static var _minus: UInt8 { UInt8(ascii: "-") }
    @_alwaysEmitIntoClient @inlinable internal static var _plus: UInt8 { UInt8(ascii: "+") }
    @_alwaysEmitIntoClient @inlinable internal static var _question: UInt8 { UInt8(ascii: "?") }
    @_alwaysEmitIntoClient @inlinable internal static var _exclamation: UInt8 { UInt8(ascii: "!") }
    @_alwaysEmitIntoClient @inlinable internal static var _ampersand: UInt8 { UInt8(ascii: "&") }
    @_alwaysEmitIntoClient @inlinable internal static var _pipe: UInt8 { UInt8(ascii: "|") }
    @_alwaysEmitIntoClient @inlinable internal static var _period: UInt8 { UInt8(ascii: ".") }
    @_alwaysEmitIntoClient @inlinable internal static var _e: UInt8 { UInt8(ascii: "e") }
    @_alwaysEmitIntoClient @inlinable internal static var _E: UInt8 { UInt8(ascii: "E") }

    @_alwaysEmitIntoClient @inlinable internal static var _verticalTab: UInt8 { UInt8(0x0b) }
    @_alwaysEmitIntoClient @inlinable internal static var _formFeed: UInt8 { UInt8(0x0c) }
    @_alwaysEmitIntoClient @inlinable internal static var _nbsp: UInt8 { UInt8(0xa0) }
    @_alwaysEmitIntoClient @inlinable internal static var _asterisk: UInt8 { UInt8(ascii: "*") }
    @_alwaysEmitIntoClient @inlinable internal static var _slash: UInt8 { UInt8(ascii: "/") }
    @_alwaysEmitIntoClient @inlinable internal static var _singleQuote: UInt8 { UInt8(ascii: "'") }
    @_alwaysEmitIntoClient @inlinable internal static var _dollar: UInt8 { UInt8(ascii: "$") }
    @_alwaysEmitIntoClient @inlinable internal static var _underscore: UInt8 { UInt8(ascii: "_") }
    @_alwaysEmitIntoClient @inlinable internal static var _dot: UInt8 { UInt8(ascii: ".") }

    @_alwaysEmitIntoClient @inlinable internal var digitValue: Int? {
        guard _asciiNumbers.contains(self) else { return nil }
        return Int(self &- UInt8(ascii: "0"))
    }

    @_alwaysEmitIntoClient @inlinable internal var isLetter: Bool? {
        return (0x41 ... 0x5a) ~= self || (0x61 ... 0x7a) ~= self
    }
}


@_alwaysEmitIntoClient @inlinable internal var _asciiNumbers: ClosedRange<UInt8> { UInt8(ascii: "0") ... UInt8(ascii: "9") }
@_alwaysEmitIntoClient @inlinable internal var _hexCharsUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "F") }
@_alwaysEmitIntoClient @inlinable internal var _hexCharsLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "f") }
@_alwaysEmitIntoClient @inlinable internal var _allLettersUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "Z") }
@_alwaysEmitIntoClient @inlinable internal var _allLettersLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "z") }

extension UInt8 {
    @inlinable internal var hexDigitValue: UInt8? {
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

    @inlinable internal var isValidHexDigit: Bool {
        switch self {
        case _asciiNumbers, _hexCharsUpper, _hexCharsLower:
            return true
        default:
            return false
        }
    }
}
