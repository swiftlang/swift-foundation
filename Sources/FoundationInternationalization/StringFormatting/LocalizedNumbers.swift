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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if !NO_PROCESS
let disableLocalizedFormatting = ProcessInfo.processInfo.environment["CFStringDisableLocalizedNumberFormatting"] != nil
#else
let disableLocalizedFormatting = false
#endif

// Equivalent to `CFNumberFormatterPadPosition`, since ICU skeletons (and therefore format styles) don't support padding
private enum PaddingPosition {
    case beforePrefix
    case afterPrefix
    case afterSuffix
}

#if !FOUNDATION_FRAMEWORK && !hasFeature(Embedded)
@_dynamicReplacement(for: formatLocalizedNumber(spec:mainArg:width:precision:locale:into:))
#endif
func formatLocalizedNumber_localized(spec: ParsedFormatSpec, mainArg: _VarArgs.Argument, width: Int32?, precision: Int32?, locale: Locale, into output: inout some StringBuilder & ~Copyable) -> Bool {
    #if ICU
    guard !disableLocalizedFormatting else {
        return false
    }

    switch spec.kind {
    case .integer(let flags):
        assert(!flags.style.isEmpty)
        let formatted = formatLocalizedInteger(mainArg.integerValue, flags: flags, justification: spec.justification, width: width, precision: precision, locale: locale)
        output._append(copying: formatted.utf8.span.bytes, encoding: .utf8, source: .number(mainArg.integerValue, for: spec))
    case .double(let flags):
        assert(!flags.style.isEmpty)
        let formatted = formatLocalizedFloatingPoint(mainArg.doubleValue, flags: flags, justification: spec.justification, width: width, precision: precision, locale: locale)
        output._append(copying: formatted.utf8.span.bytes, encoding: .utf8, source: .number(mainArg.doubleValue, for: spec))
    default:
        preconditionFailure("Unexpected kind \(spec.kind) for localized number spec")
    }

    return true
    #else
    return false
    #endif
}

#if ICU

// %d, %i, %u
private func formatLocalizedInteger(_ value: Int64, flags: ParsedFormatSpec.NumericFlags, justification: ParsedFormatSpec.Justification, width: Int32?, precision: Int32?, locale: Locale) -> String {
    // A precision is the minimum number of digits, which takes priority over the width for zero padding
    let padZero = precision != nil || justification == .zeroPadding
    let widthValue = Int(precision ?? width ?? 0)
    let paddingPosition: PaddingPosition = if precision != nil {
        .afterPrefix
    } else if justification == .leftJustified {
        .afterSuffix
    } else if padZero {
        .afterPrefix
    } else {
        .beforePrefix
    }

    let minimumIntegerDigits = (padZero && widthValue > 0) ? widthValue : nil

    // Negative values never display a "+", even for %u which formats the unsigned bit pattern
    let sign: NumberFormatStyleConfiguration.SignDisplayStrategy = (flags.sign == .alwaysDisplaySign && value >= 0) ? .always() : .automatic

    func format<V: BinaryInteger>(_ value: V) -> String {
        var style = IntegerFormatStyle<V>(locale: locale).sign(strategy: sign)
        if let minimumIntegerDigits {
            style = style.precision(.integerLength(minimumIntegerDigits...))
        }
        let formatted = style.format(value)
        return pad(formatted, toWidth: widthValue, with: " ", at: paddingPosition) {
            (value < 0 || sign == .always()) ? prefixLength(of: formatted, unsigned: style.sign(strategy: .never).format(value)) : 0
        }
    }

    var result = flags.style.contains(.unsigned) ? format(UInt64(bitPattern: value)) : format(value)

    // When the precision determined the zero padding, the width is applied afterwards with spaces
    if precision != nil, let width, result.utf16.count < width {
        let padding = String(repeating: " ", count: Int(width) - result.utf16.count)
        result = justification == .leftJustified ? result + padding : padding + result
    }
    return result
}

// %f, %e, %g
private func formatLocalizedFloatingPoint(_ value: Double, flags: ParsedFormatSpec.NumericFlags, justification: ParsedFormatSpec.Justification, width: Int32?, precision: Int32?, locale: Locale) -> String {
    var precision = Int(precision ?? 6)

    let alwaysShowSign = flags.sign == .alwaysDisplaySign && !(value < 0)
    let widthValue = Int(width ?? 0)
    let paddingPosition: PaddingPosition = if justification == .leftJustified {
        .afterSuffix
    } else if justification == .zeroPadding {
        .afterPrefix
    } else {
        .beforePrefix
    }

    // Zero padding pads with spaces after the sign, except for %g which pads with (unlocalized) "0" characters
    var paddingCharacter: Character = " "

    var style = FloatingPointFormatStyle<Double>(locale: locale).sign(strategy: alwaysShowSign ? .always() : .automatic)
    switch flags.style {
    case .decimal:
        style = style.precision(.fractionLength(precision))
    case .scientific:
        style = style.notation(.printfScientific).precision(.significantDigits(precision + 1))
    case [.decimal, .scientific]:
        // A precision of 0 is treated as a precision of 1 for %g
        precision = Swift.max(precision, 1)

        style = style.precision(.significantDigits(1...precision))

        // Scientific notation is used when the exponent after rounding is less than -4 or at least the precision
        if usesScientificNotation(value, precision: precision) {
            style = style.notation(.printfScientific)
        }

        if justification == .zeroPadding {
            paddingCharacter = "0"
        }
    default:
        preconditionFailure("Unexpected numeric format style \(flags.style) for floating point value")
    }

    let formatted = style.format(value)
    return pad(formatted, toWidth: widthValue, with: paddingCharacter, at: paddingPosition) {
        (alwaysShowSign || value.sign == .minus) ? prefixLength(of: formatted, unsigned: style.sign(strategy: .never).format(value)) : 0
    }
}

/// Whether the exponent of `value` after rounding to `precision` significant digits is less than -4 or at least `precision`
///
/// Rather than formatting, this compares against the smallest values that round up to 10^precision and 10^-4. Both bounds are exact (or the nearest Double to an exact decimal tie), so this matches the half-even rounding of the shortest representation used when formatting.
private func usesScientificNotation(_ value: Double, precision: Int) -> Bool {
    guard value.isFinite && value != 0 else {
        return false
    }
    // e.g. 999999.5 rounds to 1E6 with a precision of 6
    let upperBound = powerOfTen(precision) - 0.5
    // e.g. 0.00009999995 rounds to 1E-4 with a precision of 6. With a precision above 15, no Double is between this bound and 1E-4.
    let lowerBound = precision <= 15 ? (2 * powerOfTen(precision) - 1) / (2 * powerOfTen(precision + 4)) : 1E-4
    return value.magnitude >= upperBound || value.magnitude < lowerBound
}

/// 10^exponent rounded to the nearest Double for exponents up to 44. Beyond that (far more precision than a Double can represent), values within a few ulps of 10^precision may use either notation.
private func powerOfTen(_ exponent: Int) -> Double {
    guard exponent <= 308 else {
        return .infinity
    }
    guard exponent <= 22 else {
        // Both factors are exact, so the product is correctly rounded
        return 1E22 * powerOfTen(exponent - 22)
    }
    var result = 1.0
    for _ in 0 ..< exponent {
        result *= 10
    }
    return result
}

// Mirrors ICU's padding to `kCFNumberFormatterFormatWidthKey`, which counts unicode scalars
private func pad(_ formatted: String, toWidth width: Int, with character: Character, at position: PaddingPosition, prefixLength: () -> Int) -> String {
    let count = width - formatted.unicodeScalars.count
    guard count > 0 else {
        return formatted
    }
    let padding = String(repeating: character, count: count)
    switch position {
    case .beforePrefix:
        return padding + formatted
    case .afterSuffix:
        return formatted + padding
    case .afterPrefix:
        var result = formatted
        let index = result.unicodeScalars.index(result.unicodeScalars.startIndex, offsetBy: prefixLength())
        result.unicodeScalars.insert(contentsOf: padding.unicodeScalars, at: index)
        return result
    }
}

/// The number of leading unicode scalars (the sign) in `formatted` that aren't present when formatting the same value without a sign. Only needed when a sign is displayed, since there is no prefix otherwise.
private func prefixLength(of formatted: String, unsigned: String) -> Int {
    let length = formatted.unicodeScalars.count - unsigned.unicodeScalars.count
    guard length > 0, formatted.unicodeScalars.reversed().starts(with: unsigned.unicodeScalars.reversed()) else {
        return 0
    }
    return length
}

#endif
