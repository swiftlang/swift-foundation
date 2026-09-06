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
    mutating func expectCharacter(_ expected: UInt8, input: String, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws {
        guard let parsed = next(), parsed == expected else {
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
    }
    
    mutating func expectOneOrMoreCharacters(_ expected: UInt8, input: String, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws {
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
            
    mutating func digits(minDigits: Int? = nil, maxDigits: Int? = nil, nanoseconds: Bool = false, input: String, range: Range<Int>?, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws -> Int {
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

        if let range, !range.contains(result) {
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
        
        return result
    }
    
    mutating func digits(minDigits: Int? = nil, maxDigits: Int? = nil, nanoseconds: Bool = false, input: String, calendar: Calendar, component: Calendar.Component, onFailure: @autoclosure () -> (String), extendedDescription: String? = nil) throws -> Int {
        
        let result = try digits(minDigits: minDigits, maxDigits: maxDigits, nanoseconds: nanoseconds, input: input, range: nil, onFailure: onFailure(), extendedDescription: extendedDescription)
        
        guard calendar.maximumRange(of: component)!.contains(result) else {
            throw parseError(input, exampleFormattedString: onFailure(), extendedDescription: extendedDescription)
        }
        
        return result
    }
}

// Formatting helpers
extension OutputSpan<UTF8.CodeUnit> {
    static let asciiZero = UInt8(48)

    mutating func append(_ i: Int, zeroPad: Int) {
        if i < 10 {
            if zeroPad - 1 > 0 {
                for _ in 0..<zeroPad-1 { self.append(Self.asciiZero) }
            }
            self.append(Self.asciiZero + UInt8(i))
        } else if i < 100 {
            if zeroPad - 2 > 0 {
                for _ in 0..<zeroPad-2 { self.append(Self.asciiZero) }
            }
            let (tens, ones) = i.quotientAndRemainder(dividingBy: 10)
            self.append(Self.asciiZero + UInt8(tens))
            self.append(Self.asciiZero + UInt8(ones))
        } else if i < 1000 {
            if zeroPad - 3 > 0 {
                for _ in 0..<zeroPad-3 { self.append(Self.asciiZero) }
            }
            let (hundreds, remainder) = i.quotientAndRemainder(dividingBy: 100)
            let (tens, ones) = remainder.quotientAndRemainder(dividingBy: 10)
            self.append(Self.asciiZero + UInt8(hundreds))
            self.append(Self.asciiZero + UInt8(tens))
            self.append(Self.asciiZero + UInt8(ones))
        } else if i < 10000 {
            if zeroPad - 4 > 0 {
                for _ in 0..<zeroPad-4 { self.append(Self.asciiZero) }
            }
            let (thousands, remainder) = i.quotientAndRemainder(dividingBy: 1000)
            let (hundreds, remainder2) = remainder.quotientAndRemainder(dividingBy: 100)
            let (tens, ones) = remainder2.quotientAndRemainder(dividingBy: 10)
            self.append(Self.asciiZero + UInt8(thousands))
            self.append(Self.asciiZero + UInt8(hundreds))
            self.append(Self.asciiZero + UInt8(tens))
            self.append(Self.asciiZero + UInt8(ones))
        } else {
            // Special case - we don't do zero padding
            var desc = i.numericStringRepresentation
            self._append(copying: desc.utf8SpanMakingContiguous.span)
        }
    }

    
}

