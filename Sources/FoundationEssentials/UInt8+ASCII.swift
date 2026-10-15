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
    internal static var _slash: UInt8 { UInt8(ascii: "/") }

    internal static var _equal: UInt8 { UInt8(ascii: "=") }
    internal static var _minus: UInt8 { UInt8(ascii: "-") }
    internal static var _plus: UInt8 { UInt8(ascii: "+") }
    internal static var _question: UInt8 { UInt8(ascii: "?") }
    internal static var _exclamation: UInt8 { UInt8(ascii: "!") }
    internal static var _ampersand: UInt8 { UInt8(ascii: "&") }
    internal static var _pipe: UInt8 { UInt8(ascii: "|") }
    internal static var _percent: UInt8 { UInt8(ascii: "%") }
    internal static var _period: UInt8 { UInt8(ascii: ".") }
    internal static var _dot: UInt8 { UInt8(ascii: ".") }
    internal static var _e: UInt8 { UInt8(ascii: "e") }
    internal static var _E: UInt8 { UInt8(ascii: "E") }

    internal static var _verticalTab: UInt8 { UInt8(0x0b) }
    internal static var _formFeed: UInt8 { UInt8(0x0c) }
    internal static var _nbsp: UInt8 { UInt8(0xa0) }
    internal static var _asterisk: UInt8 { UInt8(ascii: "*") }
    internal static var _singleQuote: UInt8 { UInt8(ascii: "'") }
    internal static var _dollar: UInt8 { UInt8(ascii: "$") }
    internal static var _underscore: UInt8 { UInt8(ascii: "_") }

    /// One past the last ASCII control-character code point.
    internal static var _asciiFirstPrintable: UInt8 { 0x20 }

    internal var digitValue: Int? {
        guard _asciiNumbers.contains(self) else { return nil }
        return Int(self &- UInt8(ascii: "0"))
    }

    internal var isLetter: Bool? {
        return (0x41 ... 0x5a) ~= self || (0x61 ... 0x7a) ~= self
    }

    /// Equivalent to `isspace()` in the C locale: space, `\t`, `\n`, `\v`, `\f`, `\r`.
    internal var isASCIIWhitespace: Bool {
        return self == ._space || (UInt8(ascii: "\t") ... UInt8(ascii: "\r")) ~= self
    }
}

package extension UTF8.CodeUnit {
    static let newline: Self = 0x0A
    static let carriageReturn: Self = 0x0D
}

internal var _asciiNumbers: ClosedRange<UInt8> { UInt8(ascii: "0") ... UInt8(ascii: "9") }
internal var _hexCharsUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "F") }
internal var _hexCharsLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "f") }
package var _allLettersUpper: ClosedRange<UInt8> { UInt8(ascii: "A") ... UInt8(ascii: "Z") }
package var _allLettersLower: ClosedRange<UInt8> { UInt8(ascii: "a") ... UInt8(ascii: "z") }

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
