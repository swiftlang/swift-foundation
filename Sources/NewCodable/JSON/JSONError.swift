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


@usableFromInline
enum JSONError: Swift.Error, Equatable {
    @usableFromInline
    typealias SourceLocation = CodingError._Decoding.SourceLocation
    
    case cannotConvertEntireInputDataToUTF8
    case cannotConvertInputStringDataToUTF8(location: SourceLocation)
    case unexpectedCharacter(context: String? = nil, ascii: UInt8, location: SourceLocation)
    case unexpectedEndOfFile
    case tooManyNestedArraysOrDictionaries(location: SourceLocation? = nil)
    case invalidHexDigitSequence(String, location: SourceLocation)
    case invalidEscapedNullValue(location: SourceLocation)
    case invalidSpecialValue(expected: String, location: SourceLocation)
    case unexpectedEscapedCharacter(ascii: UInt8, location: SourceLocation)
    case unescapedControlCharacterInString(ascii: UInt8, location: SourceLocation)
    case expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location: SourceLocation)
    case couldNotCreateUnicodeScalarFromUInt32(location: SourceLocation, unicodeScalarValue: UInt32)
    case numberWithLeadingZero(location: SourceLocation)
    case numberIsNotRepresentableInSwift(parsed: String)
    case singleFragmentFoundButNotAllowed

    // JSON5

    case unterminatedBlockComment

    @usableFromInline
    var debugDescription : String {
        switch self {
        case .cannotConvertEntireInputDataToUTF8:
            return "Unable to convert data to a string using the detected encoding. The data may be corrupt."
        case let .cannotConvertInputStringDataToUTF8(location):
            return "Unable to convert data to a string around \(location)"
        case let .unexpectedCharacter(context, ascii, location):
            if let context {
                return "Unexpected character '\(String(UnicodeScalar(ascii)))' \(context) around \(location)."
            } else {
                return "Unexpected character '\(String(UnicodeScalar(ascii)))' around \(location)."
            }
        case .unexpectedEndOfFile:
            return "Unexpected end of file"
        case .tooManyNestedArraysOrDictionaries(let location):
            if let location {
                return "Too many nested arrays or dictionaries around \(location)."
            } else {
                return "Too many nested arrays or dictionaries."
            }
        case let .invalidHexDigitSequence(hexSequence, location):
            return "Invalid hex digit in unicode escape sequence '\(hexSequence)' around \(location)."
        case let .invalidEscapedNullValue(location):
            return "Unsupported escaped null around \(location)."
        case let .invalidSpecialValue(expected, location):
            return "Invalid \(expected) value around \(location)."
        case let .unexpectedEscapedCharacter(ascii, location):
            return "Invalid escape sequence '\(String(UnicodeScalar(ascii)))' around \(location)."
        case let .unescapedControlCharacterInString(ascii, location):
            return "Unescaped control character '0x\(String(ascii, radix: 16))' around \(location)."
        case let .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location):
            return "Missing low code point in surrogate pair around \(location)."
        case let .couldNotCreateUnicodeScalarFromUInt32(location, unicodeScalarValue):
            return "Invalid unicode scalar value '0x\(String(unicodeScalarValue, radix: 16))' around \(location)."
        case let .numberWithLeadingZero(location):
            return "Number with leading zero around \(location)."
        case let .numberIsNotRepresentableInSwift(parsed):
            return "Number \(parsed) is not representable in Swift."
        case .singleFragmentFoundButNotAllowed:
            return "JSON input did not start with array or object as required by options."

        // JSON5

        case .unterminatedBlockComment:
            return "Unterminated block comment"
        }
    }

    @usableFromInline
    var sourceLocation: SourceLocation? {
        switch self {
        case let .cannotConvertInputStringDataToUTF8(location), let .unexpectedCharacter(_, _, location):
            return location
        case let .tooManyNestedArraysOrDictionaries(location):
            return location
        case let .invalidHexDigitSequence(_, location), let .invalidEscapedNullValue(location), let .invalidSpecialValue(_, location):
            return location
        case let .unexpectedEscapedCharacter(_, location), let .unescapedControlCharacterInString(_, location), let .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(location):
            return location
        case let .couldNotCreateUnicodeScalarFromUInt32(location, _), let .numberWithLeadingZero(location):
            return location
        default:
            return nil
        }
    }

#if FOUNDATION_FRAMEWORK
    @usableFromInline
    var nsError: NSError {
        var userInfo : [String: Any] = [
            NSDebugDescriptionErrorKey : self.debugDescription
        ]
        if let location = self.sourceLocation {
            userInfo["NSJSONSerializationErrorIndex"] = location.index
        }
        return .init(domain: NSCocoaErrorDomain, code: CocoaError.propertyListReadCorrupt.rawValue, userInfo: userInfo)
    }
#endif // FOUNDATION_FRAMEWORK
}

extension JSONError {
    @usableFromInline
    func at(_ path: CodingPath) -> CodingError.Decoding {
        let (description, location) = Self.extractJSONErrorInfo(from: self)
        
        // TODO: Fix underlyingError
        return CodingError.dataCorrupted(at: path, debugDescription: description, underlyingError: nil, sourceLocation: location)
    }
    
    @usableFromInline
    func at(_ path: CodingPath, encodingValueDescription: String) -> CodingError.Encoding {
        let (description, _) = Self.extractJSONErrorInfo(from: self)
        
        // TODO: Fix underlyingError
        return CodingError._Encoding.init(kind: .invalidValue(valueDescription: encodingValueDescription), codingPath: path, debugDescription: description)
    }
    
    private static func extractJSONErrorInfo(from jsonError: JSONError) -> (String, CodingError._Decoding.SourceLocation?) {
        switch jsonError {
        case .cannotConvertEntireInputDataToUTF8:
            return ("Data conversion failure", nil)
        case .cannotConvertInputStringDataToUTF8(let location):
            return ("Data conversion failure", location)
        case .unexpectedCharacter(let context, let ascii, let location):
            let desc = "Unexpected character '\(String(UnicodeScalar(ascii)))'" + (context.map { " (\($0))" } ?? "")
            return (desc, location)
        case .unexpectedEndOfFile:
            return ("Unexpected end of file", nil)
        case .tooManyNestedArraysOrDictionaries(let location):
            return ("Too many nested containers", location)
        case .invalidHexDigitSequence(let sequence, let location):
            return ("Invalid hex sequence '\(sequence)'", location)
        case .invalidEscapedNullValue(let location):
            return ("Invalid escape sequence (null)", location)
        case .invalidSpecialValue(let expected, let location):
            return ("Invalid \(expected) value", location)
        case .unexpectedEscapedCharacter(let ascii, let location):
            return ("Invalid escape sequence '\(String(UnicodeScalar(ascii)))'", location)
        case .unescapedControlCharacterInString(let ascii, let location):
            return ("Unescaped control character '0x\(String(ascii, radix: 16))'", location)
        case .expectedLowSurrogateUTF8SequenceAfterHighSurrogate(let location):
            return ("Invalid UTF-8 sequence (surrogate pair)", location)
        case .couldNotCreateUnicodeScalarFromUInt32(let location, let value):
            return ("Invalid unicode scalar value '0x\(String(value, radix: 16))'", location)
        case .numberWithLeadingZero(let location):
            return ("Invalid number: leading zero", location)
        case .numberIsNotRepresentableInSwift(let parsed):
            return ("Invalid number: \(parsed)", nil)
        case .singleFragmentFoundButNotAllowed:
            return ("Invalid JSON structure (single fragment not allowed)", nil)
        case .unterminatedBlockComment:
            return ("Unterminated comment", nil)
        }
    }
}
