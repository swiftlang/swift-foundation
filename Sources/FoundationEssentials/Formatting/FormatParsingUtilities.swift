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

@available(FoundationSpan 6.2, *)
func parseError(
    _ value: UTF8Span, exampleFormattedString: String?, extendedDescription: String? = nil
) -> CocoaError {
    // TODO: change to UTF8Span, and prototype string append and interpolation taking UTF8Span
    parseError(String(copying: value), exampleFormattedString: exampleFormattedString, extendedDescription: extendedDescription)
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


@available(FoundationSpan 6.2, *)
extension UTF8Span {
    // This is just an iterator style type, though for UTF8 we can
    // load scalars and Characters, presumably.
    //
    // NOTE: I'm calling this "Cursor" temporarily as "Iterator" might
    // end up being taken for other reasons.
    struct Cursor: ~Escapable {
        var span: UTF8Span
        var currentOffset: Int

        @lifetime(copy span)
        init(_ span: UTF8Span) {
            self.span = span
            self.currentOffset = 0
        }
    }

    @lifetime(copy self) // copy or borrow?
    func makeCursor() -> Cursor {
        .init(self)
    }
}

@available(FoundationSpan 6.2, *)
extension UTF8Span.Cursor {
    @lifetime(self: copy self)
    mutating func uncheckedAdvance() {
        assert(self.currentOffset < span.count)
        self.currentOffset += 1
    }

    func peek() -> UInt8? {
        guard !isEmpty else { return nil }
        return span.span[unchecked: self.currentOffset]
    }

    @lifetime(self: copy self)
    mutating func next() -> UInt8? {
        guard !isEmpty else { return nil }
        defer { uncheckedAdvance() }
        return peek()
    }

    var isEmpty: Bool { self.currentOffset >= span.count }

    @lifetime(self: copy self)
    mutating func consume(_ byte: UInt8) -> Bool {
        guard peek() == byte else {
            return false
        }
        uncheckedAdvance()
        return true
    }

}

@available(FoundationSpan 6.2, *)
extension UTF8Span.Cursor {
    // Returns the next byte if there is one and it
    // matches the predicate, otherwise false
    func peek(_ f: (UInt8) -> Bool) -> UInt8? {
        guard let b = peek(), f(b) else {
            return nil
        }
        return b
    }

    @lifetime(self: copy self)
    mutating func matchByte(_ expected: UInt8) -> Bool {
        if peek() == expected {
            uncheckedAdvance()
            return true
        }
        return false
    }

    @lifetime(self: copy self)
    mutating func matchPredicate(_ f: (UInt8) -> Bool) -> UInt8? {
        guard let b = peek(f) else {
            return nil
        }
        uncheckedAdvance()
        return b
    }

    /**
     NOTE: We want a `match(anyOf:)` operation that takes an Array or Set
     literal (or String literal, clearly delineated to mean ASCII), but is guaranteed not to actually materialize a  runtime managed object.

     For example, that would handle this pattern from ISO8601:
     ```
        if let next = it.peek(), (next == UInt8(ascii: "+") || next == UInt8(ascii: "-")) {
            if next == UInt8(ascii: "+") { positive = true }
            else { positive = false }
            it.uncheckedAdvance()
     ```
     */

    @lifetime(self: copy self)
    @discardableResult
    mutating func matchZeroOrMore(_ expected: UInt8) -> Int {
        var count = 0
        while matchByte(expected) {
            count += 1
        }
        return count
    }

    @lifetime(self: copy self)
    @discardableResult
    mutating func matchOneOrMore(_ expected: UInt8) -> Int? {
        let c = matchZeroOrMore(expected)
        return c == 0 ? nil : c
    }

    // TODO: I think it would be cleaner to separate out
    // nanosecond handling here...
    @lifetime(self: copy self)
    mutating func parseNumber(minDigits: Int? = nil, maxDigits: Int? = nil, nanoseconds: Bool = false) -> Int? {
        // Consume all leading zeros, parse until we no longer see a digit
        var result = 0
        var count = 0
        // Cap at 10 digits max to avoid overflow
        let max = min(maxDigits ?? 10, 10)
        while let next = peek(), isASCIIDigit(next) {
            let digit = Int(next - UInt8(ascii: "0"))
            result *= 10
            result += digit
            uncheckedAdvance()
            count += 1
            if count >= max { break }
        }

        guard count > 0 else {
            // No digits actually found
            return nil
        }

        if let minDigits, count < minDigits {
            // Too few digits found
            return nil
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
            return nil
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

