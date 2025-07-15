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
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

#if canImport(CRT)
import CRT
#endif

private struct _ParseInfo {
    let utf16 : String.UTF16View
    var curr : String.UTF16View.Index
    var err: Error?

    mutating func advance() {
        curr = utf16.index(after: curr)
    }

    mutating func retreat() {
        curr = utf16.index(before: curr)
    }

    var currChar : UInt16 {
        utf16[curr]
    }

    var isAtEnd : Bool {
        curr >= utf16.endIndex
    }
}

internal func __ParseOldStylePropertyList(utf16: String.UTF16View) throws -> Any {
    let length = utf16.count
    guard length > 0 else {
        throw OpenStepPlistError("Conversion of string failed. The string is empty.")
    }

    var parseInfo = _ParseInfo(utf16: utf16, curr: utf16.startIndex)

    guard advanceToNonSpace(&parseInfo) else {
        return [String:Any]()
    }

    var result = parsePlistObject(&parseInfo, requireObject: true, depth: 0)
    if result != nil {
        if advanceToNonSpace(&parseInfo) {
            if result is String {
                // Reset info and keep parsing
                parseInfo = _ParseInfo(utf16: utf16, curr: utf16.startIndex)
                result = parsePlistDictContent(&parseInfo, depth: 0)
            } else {
                parseInfo.err = OpenStepPlistError("Junk after plist at line \(lineNumberStrings(parseInfo))")
                result = nil
            }
        }
    }
    guard let result else {
        throw parseInfo.err ?? OpenStepPlistError("Unknown error parsing property list around line \(lineNumberStrings(parseInfo))")
    }
    return result
}

private func parsePlistObject(_ pInfo: inout _ParseInfo, requireObject: Bool, depth: UInt32) -> Any? {
    guard depthIsValid(&pInfo, depth: depth) else {
        return nil
    }

    guard advanceToNonSpace(&pInfo) else {
        if requireObject {
            pInfo.err = OpenStepPlistError("Unexpected EOF while parsing plist")
        }
        return nil
    }

    let ch = pInfo.currChar
    pInfo.advance()
    if ch == UInt16(ascii: "{") {
        return parsePlistDict(&pInfo, depth: depth)
    } else if ch == UInt16(ascii: "(") {
        return parsePlistArray(&pInfo, depth: depth)
    } else if ch == UInt16(ascii: "<") {
        return parsePlistData(&pInfo)
    } else if ch == UInt16(ascii: "'") || ch == UInt16(ascii: "\"") {
        return parseQuotedPlistString(&pInfo, quote: ch)
    } else if isValidUnquotedStringCharacter(ch) {
        pInfo.retreat()
        return parseUnquotedPlistString(&pInfo)
    } else {
        pInfo.retreat() // Must back off the character we just read
        if requireObject {
            pInfo.err = OpenStepPlistError("Unexpected character '0x\(String(ch, radix: 16))' at line \(lineNumberStrings(pInfo))")
        }
        return nil
    }
}

private func parsePlistDict(_ pInfo: inout _ParseInfo, depth: UInt32) -> [String:Any]? {
    guard let dict = parsePlistDictContent(&pInfo, depth: depth) else {
        return nil
    }
    guard advanceToNonSpace(&pInfo) && pInfo.currChar == UInt16(ascii: "}") else {
        pInfo.err = OpenStepPlistError("Expected terminating '}' for dictionary at line \(lineNumberStrings(pInfo))")
        return nil
    }
    pInfo.advance()
    return dict
}

private func parsePlistDictContent(_ pInfo: inout _ParseInfo, depth: UInt32) -> [String:Any]? {
    var dict = [String:Any]()

    while let key = parsePlistString(&pInfo, requireObject: false) {
        guard advanceToNonSpace(&pInfo) else {
            pInfo.err = OpenStepPlistError("Missing ';' on line \(lineNumberStrings(pInfo))")
            return nil
        }

        var value : Any
        if pInfo.currChar == UInt16(ascii: ";") {
            /* This is a strings file using the shortcut format */
            /* although this check here really applies to all plists. */
            value = key
        } else if pInfo.currChar == UInt16(ascii: "=") {
            pInfo.advance()
            guard let v = parsePlistObject(&pInfo, requireObject: true, depth: depth + 1) else {
                return nil
            }
            value = v
        } else {
            pInfo.err = OpenStepPlistError("Expected ';' or '=' ")
            return nil
        }

        dict[key] = value

        guard advanceToNonSpace(&pInfo) && pInfo.currChar == UInt16(ascii: ";") else {
            pInfo.err = OpenStepPlistError("Missing ';' on line \(lineNumberStrings(pInfo))")
            return nil
        }

        pInfo.advance()
    }

    // this is a success path, so clear errors (NOTE: this seems weird, but is historical)
    pInfo.err = nil

    return dict
}

private func parsePlistArray(_ pInfo: inout _ParseInfo, depth: UInt32) -> [Any]? {
    var array = [Any]()

    while let obj = parsePlistObject(&pInfo, requireObject: false, depth: depth + 1) {
        array.append(obj)

        guard advanceToNonSpace(&pInfo) else {
            pInfo.err = OpenStepPlistError("Expected ',' for array at line \(lineNumberStrings(pInfo))")
            return nil
        }

        guard pInfo.currChar == UInt16(ascii: ",") else {
            break
        }

        pInfo.advance()
    }

    guard advanceToNonSpace(&pInfo) && pInfo.currChar == UInt16(ascii: ")") else {
        pInfo.err = OpenStepPlistError("Expected terminating ')' for array at line \(lineNumberStrings(pInfo))")
        return nil
    }

    // this is a success path, so clear errors (NOTE: this seems weird, but is historical)
    pInfo.err = nil

    pInfo.advance() // consume the )
    return array
}

private func parsePlistString(_ pInfo: inout _ParseInfo, requireObject: Bool) -> String? {
    guard advanceToNonSpace(&pInfo) else {
        if requireObject {
            pInfo.err = OpenStepPlistError("Unexpected EOF while parsing string")
        }
        return nil
    }

    let ch = pInfo.currChar
    if ch == UInt16(ascii: "'") || ch == UInt16(ascii: "\"") {
        pInfo.advance()
        return parseQuotedPlistString(&pInfo, quote: ch)
    } else if isValidUnquotedStringCharacter(ch) {
        return parseUnquotedPlistString(&pInfo)
    } else {
        if requireObject {
            pInfo.err = OpenStepPlistError("Invalid string character at line \(lineNumberStrings(pInfo))")
        }
        return nil
    }
}

private func parseQuotedPlistString(_ pInfo: inout _ParseInfo, quote: UInt16) -> String? {
    var result : String?
    let startMark = pInfo.curr
    var mark = startMark
    while !pInfo.isAtEnd {
        let ch = pInfo.currChar
        if ch == quote {
            break
        }
        if ch == UInt16(ascii: "\\") {
            if result == nil {
                result = String()
            }
            result! += String(pInfo.utf16[mark ..< pInfo.curr])!
            pInfo.advance()

            if pInfo.isAtEnd {
                pInfo.err = OpenStepPlistError("Unterminated backslash sequence on line \(lineNumberStrings(pInfo))")
                return nil
            }
            
            guard let scalar = UnicodeScalar(getSlashedChar(&pInfo)) else {
                pInfo.err = OpenStepPlistError("Invalid character on line \(lineNumberStrings(pInfo))")
                return nil
            }
            
            result!.unicodeScalars.append(scalar)
            mark = pInfo.curr
        } else {
            pInfo.advance()
        }
    }
    if pInfo.isAtEnd {
        pInfo.curr = startMark
        pInfo.err = OpenStepPlistError("Unterminated quoted string starting on line \(lineNumberStrings(pInfo))")
        return nil
    }
    if result == nil {
        result = String(pInfo.utf16[mark ..< pInfo.curr])!
    } else if mark != pInfo.curr {
        result! += String(pInfo.utf16[mark ..< pInfo.curr])!
    }

    pInfo.advance() // Advance past the quote character before returning.

    // this is a success path, so clear errors (NOTE: this seems weird, but is historical)
    pInfo.err = nil
    return result
}

private func parseUnquotedPlistString(_ pInfo: inout _ParseInfo) -> String? {
    let mark = pInfo.curr
    while !pInfo.isAtEnd && isValidUnquotedStringCharacter(pInfo.currChar) {
        pInfo.advance()
    }
    if pInfo.curr != mark {
        return String(pInfo.utf16[mark ..< pInfo.curr])!
    }
    pInfo.err = OpenStepPlistError("Unexpected EOF while parsing string")
    return nil
}

private let octalCharRange = UInt16(ascii: "0") ... UInt16(ascii: "7")

private func parseOctal(startingWith ch: UInt16, _ pInfo: inout _ParseInfo) -> UInt16 {
    var num = UInt8( ch &- octalCharRange.lowerBound )

    /* three digits maximum to avoid reading \000 followed by 5 as \5 ! */
    // We've already read the first character here, so repeat at most two more times.
    for _ in 0 ..< 2 {
        // Hitting the end of the plist is not a meaningful error here.
        // We parse the characters we have and allow the parent context (parseQuotedPlistString, the only current call site of getSlashedChar) to produce a more meaningful error message (e.g. it will at least expect a close quote after this character).
        if pInfo.isAtEnd {
            break
        }

        let ch2 = pInfo.currChar
        if octalCharRange ~= ch2 {
            // Note: Like the previous implementation, this `num` value is UInt8, which is smaller than the largest value that can be represented by a three digit octal (0777 = 511). Since this code is compatibility-only, we maintain the truncation behavior that existed with the prior implementation.
            num = (num << 3) &+ (UInt8(ch2) &- UInt8(octalCharRange.lowerBound))
            pInfo.advance()
        } else {
            // Non-octal characters are not explicitly an error either: "\05" is a valid character which evaluates to 005. (We read a '0', a '5', and then a '"'; we can't bail on seeing '"' though.)
            // Is this an ambiguous format? Probably. But it has to remain this way for backwards compatibility.
            // See <rdar://problem/34321354>
            break
        }
    }

    return .init(nextStep: num)
}

private func parseU16Scalar(_ pInfo: inout _ParseInfo) -> UInt16 {
    var num : UInt16 = 0
    var numDigits = 4
    while !pInfo.isAtEnd && numDigits > 0 {
        let ch2 = pInfo.currChar
        if ch2 < 128 && isxdigit(Int32(ch2)) != 0 {
            pInfo.advance()
            num = num << 4
            if ch2 <= UInt16(ascii: "9") {
                num += (ch2 &- UInt16(ascii: "0"))
            } else if ch2 <= UInt16(ascii: "F") {
                num += (ch2 &- UInt16(ascii: "A") &+ 10)
            } else {
                num += (ch2 &- UInt16(ascii: "a") &+ 10)
            }
        }
        numDigits -= 1
    }
    return num
}

private func getSlashedChar(_ pInfo: inout _ParseInfo) -> UInt16 {
    let ch = pInfo.currChar
    pInfo.advance()
    switch ch {
    case octalCharRange:
        return parseOctal(startingWith: ch, &pInfo)
    case UInt16(ascii: "U"):
        return parseU16Scalar(&pInfo)
    case UInt16(ascii: "a"): return UInt16(ascii: "\u{7}")
    case UInt16(ascii: "b"): return UInt16(ascii: "\u{8}")
    case UInt16(ascii: "f"): return UInt16(ascii: "\u{12}")
    case UInt16(ascii: "n"): return UInt16(ascii: "\n")
    case UInt16(ascii: "r"): return UInt16(ascii: "\r")
    case UInt16(ascii: "t"): return UInt16(ascii: "\t")
    case UInt16(ascii: "v"): return UInt16(ascii: "\u{11}")
    default:
        return ch
    }
}

private func isValidUnquotedStringCharacter(_ x: UInt16) -> Bool {
    switch x {
        case UInt16(ascii: "a") ... UInt16(ascii: "z"):
            return true
        case UInt16(ascii: "A") ... UInt16(ascii: "Z"):
            return true
        case UInt16(ascii: "0") ... UInt16(ascii: "9"):
            return true
        case UInt16(ascii: "_"), UInt16(ascii: "$"), UInt16(ascii: "/"), UInt16(ascii: ":"), UInt16(ascii: "."), UInt16(ascii: "-"):
            return true
        default:
            return false
    }
}

private func parsePlistData(_ pInfo: inout _ParseInfo) -> Data? {
    var result = Data()

    while true {
        let NUM_BYTES = 400
        let numBytesRead = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: NUM_BYTES) { buffer in
            let numBytesRead = getDataBytes(&pInfo, bytes: buffer)
            if numBytesRead > 0 {
                let subBuffer = buffer[0 ..< numBytesRead]
                result.append(contentsOf: subBuffer)
            }
            return numBytesRead
        }
        guard numBytesRead > 0 else {
            if numBytesRead == -2 {
                pInfo.err = OpenStepPlistError("Malformed data byte group at line  \(lineNumberStrings(pInfo)); uneven length")
                return nil
            } else if numBytesRead < 0 {
                pInfo.err = OpenStepPlistError("Malformed data byte group at line  \(lineNumberStrings(pInfo)); invalid hex")
                return nil
            }
            break
        }
    }

    // this is a success path, so clear errors (NOTE: this seems weird, but is historical)
    pInfo.err = nil

    guard !pInfo.isAtEnd && pInfo.currChar == UInt16(ascii: ">") else {
        pInfo.err = OpenStepPlistError("Expected terminating '>' for data at line  \(lineNumberStrings(pInfo))")
        return nil
    }

    pInfo.advance() // Move past '>'
    return result
}

private func getDataBytes(_ pInfo: inout _ParseInfo, bytes: UnsafeMutableBufferPointer<UInt8>) -> Int {
    var numBytesRead = 0
    while !pInfo.isAtEnd && numBytesRead < bytes.count {
        let ch1 = pInfo.currChar
        if ch1 == UInt16(ascii: ">") { // Meaning we're done
            return numBytesRead
        }

        func fromHexDigit(ch: UInt16) -> UInt8? {
            guard let ch = UInt8(exactly: ch) else {
                return nil
            }
            if isdigit(Int32(ch)) != 0 {
                return ch &- UInt8(ascii: "0")
            }
            if (ch >= UInt8(ascii: "a")) && (ch <= UInt8(ascii: "f")) {
                return ch &- UInt8(ascii: "a") &+ 10
            }
            if (ch >= UInt8(ascii: "A")) && (ch <= UInt8(ascii: "F")) {
                return ch &- UInt8(ascii: "A") &+ 10
            }
            return nil
        }

        if let first = fromHexDigit(ch: ch1) {
            pInfo.advance()
            if pInfo.isAtEnd {
                return -2 // Error: uneven number of hex digits
            }

            let ch2 = pInfo.currChar
            guard let second = fromHexDigit(ch: ch2) else {
                return -2 // Error: uneven number of hex digits
            }

            bytes[numBytesRead] = (first << 4) + second
            numBytesRead += 1
            pInfo.advance()
        } else if ch1 == UInt16(ascii: " ") || ch1 == UInt16(ascii: "\n") || ch1 == UInt16(ascii: "\r") || ch1 == 0x2028 || ch1 == 0x2029 {
            pInfo.advance()
        } else {
            return -1 // Error: unexpected character
        }
    }
    return numBytesRead
}

// Returns true if the advance found something before the end of the buffer, false otherwise
// AFTER-INVARIANT: pInfo->curr <= pInfo->end
//                  However result will be false when pInfo->curr == pInfo->end
private func advanceToNonSpace(_ pInfo: inout _ParseInfo) -> Bool {
    while !pInfo.isAtEnd {
        let ch2 = pInfo.currChar
        pInfo.advance()

        switch ch2 {
            case 0x9, 0xa, 0xb, 0xc, 0xd: continue // tab, newline, vt, form feed, carriage return
            case UInt16(ascii: " "), 0x2028, 0x2029: continue // space and Unicode line sep, para sep
            case UInt16(ascii: "/"):
                if pInfo.isAtEnd {
                    // whoops; back up and return
                    pInfo.retreat()
                    return true
                } else if pInfo.currChar == UInt16(ascii: "/") {
                    pInfo.advance()

                    var atEndOfLine = false
                    while !pInfo.isAtEnd && !atEndOfLine { // go to end of comment line
                        switch pInfo.currChar {
                            case UInt16(ascii: "\n"), UInt16(ascii: "\r"), 0x2028, 0x2029:
                                atEndOfLine = true
                            default:
                                pInfo.advance()
                        }
                    }
                } else if pInfo.currChar == UInt16(ascii: "*") { // handle /* ... */
                    pInfo.advance()

                    while !pInfo.isAtEnd {
                        let ch3 = pInfo.currChar
                        pInfo.advance()
                        if ch3 == UInt16(ascii: "*") && !pInfo.isAtEnd && pInfo.currChar == UInt16(ascii: "/") {
                            pInfo.advance() // advance past the '/'
                            break
                        }
                    }
                } else { // this looked like the start of a comment, but wasn't
                    pInfo.retreat()
                    return true
                }
            default: // this didn't look like a comment, we've found non-whitespace
                pInfo.retreat()
                return true
        }
    }
    return false
}

// when this returns yes, pInfo.err will be set
private func depthIsValid(_ pInfo: inout _ParseInfo, depth: UInt32) -> Bool {
    let MAX_DEPTH = 512
    if depth <= MAX_DEPTH {
        return true
    }
    pInfo.err = OpenStepPlistError("Too many nested arrays or dictionaries at line \(lineNumberStrings(pInfo))")
    return false
}


private func lineNumberStrings(_ pInfo: _ParseInfo) -> Int {
    var p = pInfo.utf16.startIndex
    var count = 1
    while p < pInfo.utf16.endIndex && p < pInfo.curr {
        if pInfo.utf16[p] == UInt16(ascii: "\r") {
            count += 1

            let nextIdx = pInfo.utf16.index(after: p)
            if nextIdx < pInfo.utf16.endIndex && nextIdx < pInfo.curr && pInfo.utf16[nextIdx] == UInt16("\n") {
                p = nextIdx
            }
        } else if pInfo.utf16[p] == UInt16(ascii: "\n") {
            count += 1
        }
        p = pInfo.utf16.index(after: p)
    }
    return count
}

private extension UInt16 {
    init(ascii: UnicodeScalar) {
        self = UInt16(UInt8(ascii: ascii))
    }
}

internal struct OpenStepPlistError: Swift.Error, Equatable {
    var debugDescription : String
    init(_ desc: String) {
        self.debugDescription = desc
    }

    var cocoaError: CocoaError {
        .init(.propertyListReadCorrupt, userInfo: [
            NSDebugDescriptionErrorKey : self.debugDescription
        ])
    }
}
