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
    fileprivate var _isValidConfigKeyCharacter: Bool {
        if self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9") {
            return true
        }
        if self >= UInt8(ascii: "a") && self <= UInt8(ascii: "z") {
            return true
        }
        if self >= UInt8(ascii: "A") && self <= UInt8(ascii: "Z") {
            return true
        }
        return self == UInt8(ascii: "_")
    }
}

package struct ParsedFormatSpec {
    package enum Kind : Equatable {
        case literal // Either %% or a non-specifier segment
        case integer(NumericFlags) // %c, %d, %i, %u, %o, %x
        case double(NumericFlags) // %a, %f, %g, %e
        case pointer // %p
        case object // %@
        case unichars // %S
        case chars // %s
        case pascalChars // %P
        case singleUnichar // %C
        case memoryWrite // %n
        case incomplete // %<EOF>
        case pluralizationNumber

        package var usesArgument: Bool {
            self != .literal && self != .incomplete && self != .pluralizationNumber
        }

        /// The kind used for the values of precision/width reference arguments
        package static var auxiliaryArgument: Self {
            .integer(NumericFlags(size: .int, style: .decimal, sign: .negativeSignOnly))
        }
    }

    package struct NumericFlags : Equatable {
        package var size: ArgumentSize
        package var style: NumericFormatStyle
        package var sign: SignOption
    }

    package enum ArgumentSize {
        case char
        case short
        case int
        case long
        case longLong
        case longDouble

        package static var pointer: Self { .long }

        package var normalizingLong: Self {
            guard self == .long else { return self }
            #if _pointerBitWidth(_64)
            return .longLong
            #elseif _pointerBitWidth(_32)
            return .int
            #endif
        }

        package var bytes: Int {
            switch self {
            case .char: 1
            case .short: 2
            case .int: 4
#if _pointerBitWidth(_32)
            case .long: 4
#elseif _pointerBitWidth(_64)
            case .long: 8
#endif
            case .longLong: 8
            case .longDouble: 16
            }
        }
    }

    package struct NumericFormatStyle: OptionSet {
        package let rawValue: UInt8

        package init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        package static let decimal = Self(rawValue: 1 << 0)
        package static let scientific = Self(rawValue: 1 << 1)
        package static let unsigned = Self(rawValue: 1 << 2)
    }

    package enum SignOption {
        case negativeSignOnly // default
        case alwaysDisplaySign // + flag
        case spaceWhenNoSign // <space> flag (overrides + flag)
    }

    package enum AuxiliaryArgument : Equatable {
        case literal(Int32)
        case reference(Int8?)
    }

    package struct ConfigArgument {
        /// The range of the key within the format string, in code units
        package var key: Range<Int>
        package var entityMarker: Bool

        package func keyString<T: StringCodeUnit>(in format: Span<T>) -> String {
            let range = key
            return String(unsafeUninitializedCapacity: range.count) { strBuffer in
                var outputBuffer = OutputSpan(buffer: strBuffer, initializedCount: 0)
                for i in range {
                    outputBuffer.append(UInt8(truncatingIfNeeded: format[i]))
                }
                return outputBuffer.count
            }
        }

        package func keyString(in format: StringContents) -> String {
            switch format.encoding {
            case .utf8, .ascii: keyString(in: Span<UInt8>(viewing: format.bytes))
            case .utf16: keyString(in: Span<UInt16>(viewing: format.bytes))
            }
        }
    }

    package enum Justification {
        case rightJustified // default
        case zeroPadding // 0 flag
        case leftJustified // - flag (overrides 0 flag)
    }

    package var kind: Kind
    package var sourceRange: Range<Int>
    package var mainArgNum: Int8?
    package var precisionArg: AuxiliaryArgument?
    package var widthArg: AuxiliaryArgument?
    package var config: ConfigArgument?
    package var justification = Justification.rightJustified
    package var percentReplacement = false

    package init(literalIn range: Range<Int>) {
        self.kind = .literal
        self.sourceRange = range
    }

    /// Creates a parsed format specification from a buffer containing format string data.
    ///
    /// This initializer parses a printf-style format specifier from the provided buffer,
    /// extracting information about the format type, flags, width, precision, and other
    /// formatting options.
    ///
    /// ## Overview
    ///
    /// The parser processes format specifiers that begin with `%` and continue until a
    /// valid format type character is encountered. It supports the full range of printf-style
    /// format specifiers including:
    ///
    /// - **Integer formats**: `%d`, `%i`, `%u`, `%o`, `%x`, `%X`, `%c`
    /// - **Floating-point formats**: `%f`, `%F`, `%e`, `%E`, `%g`, `%G`, `%a`, `%A`
    /// - **String formats**: `%s` (C strings), `%S` (Unicode strings), `%P` (Pascal strings)
    /// - **Pointer formats**: `%p`
    /// - **Object formats**: `%@` (Objective-C/Swift objects)
    /// - **Special formats**: `%%` (literal percent), configuration keys with `%#@key@`
    ///
    /// ## Format Specifier Structure
    ///
    /// A complete format specifier follows this pattern:
    /// ```
    /// %[flags][width][.precision][length][specifier]
    /// ```
    ///
    /// - **Flags**: Control alignment (`-`), sign display (`+`, ` `), padding (`0`), and other options (`#`)
    /// - **Width**: Minimum field width (number or `*` for dynamic)
    /// - **Precision**: Number of digits after decimal point for floats, or maximum characters for strings
    /// - **Length modifiers**: `h`, `hh`, `l`, `ll`, `L`, `q`, `t`, `z`, `j` to specify argument size
    /// - **Specifier**: The format type character (`d`, `f`, `s`, `@`, etc.)
    ///
    /// ## Positional Arguments
    ///
    /// The parser supports positional argument references using the `n$` syntax:
    /// - `%1$d` - Use the first argument as an integer
    /// - `%*2$.*3$4$f` - Use argument 2 for width, argument 3 for precision, argument 4 for the float value
    ///
    /// ## Configuration Keys
    ///
    /// Special configuration syntax is supported for localization and formatting:
    /// - `%#@configKey@` - References a configuration key
    /// - `%#[configKey]@` - Configuration key with entity marker
    ///
    /// ## Error Conditions
    ///
    /// The initializer throws a `CocoaError` with code `.formatting` in the following cases:
    /// - Numeric overflow when parsing width, precision, or positional argument numbers
    /// - Invalid numeric values that exceed the range of their target types (`Int8`, `Int32`, `Int64`)
    ///
    /// ## Incomplete Parsing
    ///
    /// If the buffer ends before a complete format specifier is found, the `kind` property
    /// will be set to `.incomplete`. This is not considered an error condition.
    ///
    /// - Parameters:
    ///   - buffer: A span containing the format specifier data. Must not be empty and
    ///             should start with the `%` character. The buffer elements must be
    ///             convertible to `UInt8` values representing ASCII characters.
    ///
    /// - Throws: `CocoaError` with code `.formatting` if numeric values in the format
    ///           specifier exceed their allowed ranges or cause integer overflow.
    ///
    /// - Precondition: The buffer must not be empty and should start with `%`.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let simpleFormat = "%d"
    /// let spec1 = try ParsedFormatSpec(parsingFrom: simpleFormat.utf8.span)
    /// // Results in: integer format with default flags
    ///
    /// let complexFormat = "%+-10.2f"
    /// let spec2 = try ParsedFormatSpec(parsingFrom: complexFormat.utf8.span)
    /// // Results in: double format with sign flag, left justification, width 10, precision 2
    ///
    /// let configFormat = "%#@localizedString@"
    /// let spec3 = try ParsedFormatSpec(parsingFrom: configFormat.utf8.span)
    /// // Results in: object format with configuration key "localizedString"
    /// ```
    package init<T: StringCodeUnit>(parsingFrom buffer: Span<T>, withoutPercent: Bool = false) throws(CocoaError) {
        assert(!buffer.isEmpty, "Unexpected empty buffer passed to ParsedFormatSpec(parsingFrom:)")
        self.kind = .incomplete
        self.sourceRange = 0 ..< 1
        self.config = nil
        var idx = 0
        if !withoutPercent {
            assert(buffer[idx] == UInt8(ascii: "%"), "Buffer does not start with %")
            idx += 1
        }
        defer {
            // Once we've finished parsing, set the source range to the start through what we've parsed
            sourceRange = Range(uncheckedBounds: (0, Swift.min(idx + 1, buffer.indices.endIndex)))
        }
        let endIdx = buffer.count
        var seenSharp = false
        var seenOpenBracket = false
        var seenDot = false
        var explicitSize: ArgumentSize?
        var style = NumericFormatStyle()
        var sign = SignOption.negativeSignOnly
        var configKeyStart: Span<T>.Index?
        var configKeyEnd: Span<T>.Index?

        while idx < endIdx {
            // If we're in a UTF-16 buffer with a non-ASCII character, 0xFF ensures we'll hit the default case below
            let ch = UInt8(exactly: buffer[idx]) ?? 0xFF

            // Process any in-progress config keys
            if let originalStart = configKeyStart {
                if !ch._isValidConfigKeyCharacter {
                    if ch == UInt8(ascii: "]") && seenOpenBracket {
                        configKeyEnd = idx
                    } else if ch == UInt8(ascii: "@") {
                        let end = configKeyEnd ?? idx
                        if end > originalStart {
                            kind = .object
                            config = ConfigArgument(key: originalStart ..< end, entityMarker: configKeyEnd != nil)
                        } else {
                            kind = .literal
                        }
                        return
                    } else {
                        configKeyStart = nil
                        configKeyEnd = nil
                    }
                }
                idx += 1
                continue
            }

            switch ch {
            // Config key modifiers
            case UInt8(ascii: "#"):
                seenSharp = true
            case UInt8(ascii: "["):
                if !seenOpenBracket {
                    seenOpenBracket = true
                    configKeyStart = idx + 1
                }

            // Style modifiers
            case UInt8(ascii: " "):
                if sign != .alwaysDisplaySign {
                    sign = .spaceWhenNoSign
                }
            case UInt8(ascii: "-"):
                justification = .leftJustified
            case UInt8(ascii: "+"):
                sign = .alwaysDisplaySign
            case UInt8(ascii: "0"):
                if seenDot {
                    precisionArg = .literal(0)
                } else if justification != .leftJustified {
                    justification = .zeroPadding
                }

            // Width modifiers
            case UInt8(ascii: "h"):
                if explicitSize == .short {
                    explicitSize = .char
                } else {
                    explicitSize = .short
                }
            case UInt8(ascii: "l"):
                if explicitSize == .long {
                    explicitSize = .longLong
                } else {
                    explicitSize = .long
                }
            case UInt8(ascii: "L"):
                explicitSize = .longDouble
            case UInt8(ascii: "q"):
                explicitSize = .longLong
            case UInt8(ascii: "t"), UInt8(ascii: "z"):
                explicitSize = .long
            case UInt8(ascii: "j"):
                explicitSize = .longLong

            // Numeric argument types
            case UInt8(ascii: "c"):
                let flags = NumericFlags(size: .char, style: style, sign: sign)
                kind = .integer(flags)
                return

            case UInt8(ascii: "D"), UInt8(ascii: "d"), UInt8(ascii: "i"), UInt8(ascii: "U"), UInt8(ascii: "u"):
                // We can localize all but octal or hex
                if ch == UInt8(ascii: "u") || ch == UInt8(ascii: "U") {
                    style = .unsigned
                } else {
                    style = .decimal
                }
                fallthrough
            case UInt8(ascii: "O"), UInt8(ascii: "o"), UInt8(ascii: "x"), UInt8(ascii: "X"):
                let defaultSize: ArgumentSize = ch == UInt8(ascii: "D") || ch == UInt8(ascii: "U") || ch == UInt8(ascii: "O") ? .long : .int
                let flags = NumericFlags(size: explicitSize ?? defaultSize, style: style, sign: sign)
                kind = .integer(flags)
                return

            case UInt8(ascii: "f"), UInt8(ascii: "F"), UInt8(ascii: "g"), UInt8(ascii: "G"), UInt8(ascii: "e"), UInt8(ascii: "E"):
                // We can localize all but hex float
                style = switch ch {
                case UInt8(ascii: "e"), UInt8(ascii: "E"): .scientific
                case UInt8(ascii: "f"), UInt8(ascii: "F") : .decimal
                default: [.decimal, .scientific]
                }
                if seenDot && precisionArg == nil {
                    precisionArg = .literal(0)
                }
                fallthrough
            case UInt8(ascii: "a"), UInt8(ascii: "A"):
                let flags = NumericFlags(size: explicitSize ?? .longLong, style: style, sign: sign)
                kind = .double(flags)
                return

            // Pointer argument types
            case UInt8(ascii: "n"): // Note: not handled correctly, for leopard or newer disable it further
                kind = .memoryWrite
                return
            case UInt8(ascii: "p"):
                kind = .pointer
                return
            case UInt8(ascii: "s"):
                kind = .chars
                return
            case UInt8(ascii: "S"):
                kind = .unichars
                return
            case UInt8(ascii: "C"):
                kind = .singleUnichar
                return
            case UInt8(ascii: "P"):
                kind = .pascalChars
                return
            case UInt8(ascii: "@"):
                if seenSharp {
                    seenSharp = false
                    configKeyStart = idx + 1
                } else {
                    kind = .object
                    return
                }

            // Width/Precision/Positional specifiers
            case UInt8(ascii: "1") ... UInt8(ascii: "9"):
                var num: Int64 = 0
                var overflow = false
                var current = T(ch)
                // Build up the full number, checking for overflows
                repeat {
                    let numericCurrent = UInt8(current) - UInt8(ascii: "0")
                    (num, overflow) = num.multipliedReportingOverflow(by: 10)
                    if overflow {
                        throw CocoaError.overflowError
                    }
                    (num, overflow) = num.addingReportingOverflow(Int64(numericCurrent))
                    if overflow {
                        throw CocoaError.overflowError
                    }

                    idx += 1
                    if idx < endIdx {
                        current = buffer[idx]
                    }
                } while idx < endIdx && current >= UInt8(ascii: "0") && current <= UInt8(ascii: "9")

                if idx == endIdx {
                    kind = .incomplete
                    return
                }

                if current == UInt8(ascii: "$") {
                    // Handle positional specifiers
                    guard let referenceNum = Int8(exactly: num) else {
                        throw CocoaError.overflowError
                    }
                    // Positional specifiers are always of the following order (when present):
                    //   (1) Precision
                    //   (2) Width
                    //   (3) Main
                    if precisionArg == .reference(nil) {
                        precisionArg = .reference(referenceNum)
                    } else if widthArg == .reference(nil) {
                        widthArg = .reference(referenceNum)
                    } else {
                        mainArgNum = referenceNum
                    }
                } else {
                    // Handle width/precision literals
                    guard let literal = Int32(exactly: num) else {
                        throw CocoaError.overflowError
                    }
                    if seenDot {
                        precisionArg = .literal(literal)
                    } else {
                        widthArg = .literal(literal)
                    }
                    idx -= 1 // The character at idx wasn't a '$', so reset index back to process it again in the main loop
                }
            case UInt8(ascii: "*"):
                if seenDot {
                    precisionArg = .reference(nil)
                } else {
                    widthArg = .reference(nil)
                }
            case UInt8(ascii: "."):
                seenDot = true

            default: // Including the % character
                percentReplacement = true
                kind = .literal
                return
            }
            idx += 1
        }
    }
}

extension ParsedFormatSpec.ArgumentSize : CustomStringConvertible {
    package var description: String {
        let name = switch self {
        case .char: "char"
        case .short: "short"
        case .int: "int"
        case .long: "long"
        case .longLong: "long long"
        case .longDouble: "long double"
        }
        return "\(name) (\(bytes) bytes)"
    }
}

extension ParsedFormatSpec.NumericFlags : CustomStringConvertible {
    package var description: String {
        var result = ["\(size)"]
        if !style.isEmpty {
            result.append("\(style) style")
        }
        if sign != .negativeSignOnly {
            result.append("\(sign)")
        }
        return result.joined(separator: ", ")
    }
}

extension ParsedFormatSpec.Kind : CustomStringConvertible {
    package var description: String {
        switch self {
        case .literal: "literal"
        case .integer(let flags): "integer (\(flags))"
        case .double(let flags): "integer (\(flags))"
        case .pointer: "pointer"
        case .object: "object"
        case .unichars: "unichars"
        case .chars: "chars"
        case .pascalChars: "pascal chars"
        case .singleUnichar: "single unichar"
        case .memoryWrite: "dummy"
        case .incomplete: "incomplete"
        case .pluralizationNumber: "pluralization number"
        }
    }
}

extension ParsedFormatSpec.NumericFormatStyle : CustomStringConvertible {
    package var description: String {
        var results = [String]()
        if self.contains(.unsigned) {
            results.append("unsigned")
        }
        if self.contains(.decimal) {
            results.append("decimal")
        }
        if self.contains(.scientific) {
            results.append("scientific")
        }
        return results.joined(separator: " or ")
    }
}

extension ParsedFormatSpec.AuxiliaryArgument : CustomStringConvertible {
    package var description: String {
        switch self {
        case .literal(let val):
            "\(val) literal"
        case .reference(let arg):
            if let arg {
                "argument \(arg)"
            } else {
                "implicit argument"
            }
        }
    }
}

extension ParsedFormatSpec.ConfigArgument : CustomStringConvertible {
    package var description: String {
        "\(key)\(entityMarker ? " (entity marker)" : "")"
    }
}

extension ParsedFormatSpec.Justification : CustomStringConvertible {
    package var description: String {
        switch self {
        case .rightJustified:
            "right justified"
        case .zeroPadding:
            "zero padded"
        case .leftJustified:
            "left justified"
        }
    }
}

extension ParsedFormatSpec : CustomStringConvertible {
    package var description: String {
        var result = """
                    ParsedFormatSpec(
                        kind: \(kind)
                        sourceRange: \(sourceRange)
                    """
        if kind.usesArgument {
            if let mainArgNum {
                result += "\n\tmainArgNum: \(mainArgNum)"
            } else {
                result += "\n\tmainArgNum: implicit"
            }
        }
        if let precisionArg {
            result += "\n\tprecisionArg: \(precisionArg)"
        }
        if let widthArg {
            result += "\n\twidthArg: \(widthArg)"
        }
        if let config {
            result += "\n\tconfig: \(config)"
        }
        if justification != .rightJustified {
            result += "\n\tjustification: \(justification)"
        }
        if percentReplacement {
            result += "\n\tpercentReplacement: true"
        }
        result += "\n)"
        return result
    }
}


