//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal // NOTE: internal because BufferView is internal, `parseError` below is `package`
func parseError(
    _ value: BufferView<UInt8>, exampleFormattedString: String?, extendedDescription: String? = nil
) -> CocoaError {
    // TODO: change to UTF8Span, and prototype string append and interpolation taking UTF8Span
    parseError(String(decoding: value, as: UTF8.self), exampleFormattedString: exampleFormattedString, extendedDescription: extendedDescription)
}

package func parseError(_ value: String, exampleFormattedString: String?, extendedDescription: String? = nil) -> CocoaError {
    let errorStr: String
    if let exampleFormattedString = exampleFormattedString {
        errorStr = "Cannot parse \(value)\(extendedDescription.map({ ": \($0)." }) ?? ".") String should adhere to the preferred format of the locale, such as \(exampleFormattedString)."
    } else {
        errorStr = "Cannot parse \(value)\(extendedDescription.map({ ": \($0)." }) ?? ".")"
    }
    return CocoaError(CocoaError.formatting, userInfo: [ NSDebugDescriptionErrorKey: errorStr ])
}

func isASCIIDigit(_ x: UInt8) -> Bool {
    x >= UInt8(ascii: "0") && x <= UInt8(ascii: "9")
}

extension BufferViewIterator<UInt8> {
    mutating func expectCharacter(_ expected: UInt8, input: BufferView<UInt8>, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws {
        guard let parsed = next(), parsed == expected else {
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
    }
    
    mutating func expectOneOrMoreCharacters(_ expected: UInt8, input: BufferView<UInt8>, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws {
        guard let parsed = next(), parsed == expected else {
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
        
        while let parsed = peek(), parsed == expected {
            advance()
        }
    }
    
    mutating func expectZeroOrMoreCharacters(_ expected: UInt8) {
        while let parsed = peek(), parsed == expected {
            advance()
        }
    }
            
    mutating func digits(minDigits: Int? = nil, maxDigits: Int? = nil, nanoseconds: Bool = false, input: BufferView<UInt8>, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws -> Int {
        // Consume all leading zeros, parse until we no longer see a digit
        var result = 0
        var count = 0
        // Cap at 10 digits max to avoid overflow
        let max = min(maxDigits ?? 10, 10)
        while let next = peek(), isASCIIDigit(next) {
            let digit = Int(next - UInt8(ascii: "0"))
            result *= 10
            result += digit
            advance()
            count += 1
            if count >= max { break }
        }
        
        guard count > 0 else {
            // No digits actually found
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
        
        if let minDigits, count < minDigits {
            // Too few digits found
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
        
        if nanoseconds {
            // Keeps us in the land of integers
            if count == 1 { return result * 100_000_000 }
            if count == 2 { return result * 10_000_000 }
            if count == 3 { return result * 1_000_000 }
            if count == 4 { return result * 100_000 }
            if count == 5 { return result * 10_000 }
            if count == 6 { return result * 1_000 }
            if count == 7 { return result * 100 }
            if count == 8 { return result * 10 }
            if count == 9 { return result }
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }

        return result
    }
    

}

// Formatting helpers
extension OutputBuffer<CChar> {
    static let asciiZero = CChar(48)

    mutating func append(_ i: Int, zeroPad: Int) {
        if i < 10 {
            if zeroPad - 1 > 0 {
                for _ in 0..<zeroPad-1 { appendElement(Self.asciiZero) }
            }
            appendElement(Self.asciiZero + CChar(i))
        } else if i < 100 {
            if zeroPad - 2 > 0 {
                for _ in 0..<zeroPad-2 { appendElement(Self.asciiZero) }
            }
            let (tens, ones) = i.quotientAndRemainder(dividingBy: 10)
            appendElement(Self.asciiZero + CChar(tens))
            appendElement(Self.asciiZero + CChar(ones))
        } else if i < 1000 {
            if zeroPad - 3 > 0 {
                for _ in 0..<zeroPad-3 { appendElement(Self.asciiZero) }
            }
            let (hundreds, remainder) = i.quotientAndRemainder(dividingBy: 100)
            let (tens, ones) = remainder.quotientAndRemainder(dividingBy: 10)
            appendElement(Self.asciiZero + CChar(hundreds))
            appendElement(Self.asciiZero + CChar(tens))
            appendElement(Self.asciiZero + CChar(ones))
        } else if i < 10000 {
            if zeroPad - 4 > 0 {
                for _ in 0..<zeroPad-4 { appendElement(Self.asciiZero) }
            }
            let (thousands, remainder) = i.quotientAndRemainder(dividingBy: 1000)
            let (hundreds, remainder2) = remainder.quotientAndRemainder(dividingBy: 100)
            let (tens, ones) = remainder2.quotientAndRemainder(dividingBy: 10)
            appendElement(Self.asciiZero + CChar(thousands))
            appendElement(Self.asciiZero + CChar(hundreds))
            appendElement(Self.asciiZero + CChar(tens))
            appendElement(Self.asciiZero + CChar(ones))
        } else {
            // Special case - we don't do zero padding
            var desc = i.numericStringRepresentation
            desc.withUTF8 {
                $0.withMemoryRebound(to: CChar.self) { buf in
                    append(fromContentsOf: buf)
                }
            }
        }
    }

    
}

