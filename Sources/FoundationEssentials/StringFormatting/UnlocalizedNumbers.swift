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

internal import _FoundationCShims

private func copyStrippingPositions<T: StringCodeUnit>(format: Span<T>, into output: inout OutputSpan<CChar>) {
    assert(format.first == T(UInt8(ascii: "%")))
    for i in format.indices {
        let ch = format[i]
        if ch == T(UInt8(ascii: "$")) {
            let lastNonDigitIdx = output.span.lastIndex { possibleNumber in
                possibleNumber < UInt8(ascii: "0") || possibleNumber > UInt8(ascii: "9")
            }
            // lastNonDigitIdx is guaranteed to be non-nil because the format string always starts with a %
            output.removeLast(output.count - lastNonDigitIdx! - 1)
        } else {
            // We know that the format string must be all ASCII, but if it's in UTF-16 format we need to manually truncate each double-byte to a single byte
            output.append(CChar(truncatingIfNeeded: ch))
        }
    }
    output.append(0)
}

func formatUnlocalizedNumber(
    _ spec: ParsedFormatSpec,
    format: StringContents,
    value: _VarArgs.Argument,
    widthArg: Int32?,
    resolvedWidth: Int32?,
    precisionArg: Int32?,
    resolvedPrecision: Int32?,
    decimalSeparator: String?,
    into output: inout some StringBuilder & ~Copyable
) {
    switch format.encoding {
    case .utf8, .ascii:
        formatUnlocalizedNumber(spec, format: Span<UInt8>(viewing: format.bytes), value: value, widthArg: widthArg, resolvedWidth: resolvedWidth, precisionArg: precisionArg, resolvedPrecision: resolvedPrecision, decimalSeparator: decimalSeparator, into: &output)
    case .utf16:
        formatUnlocalizedNumber(spec, format: Span<UInt16>(viewing: format.bytes), value: value, widthArg: widthArg, resolvedWidth: resolvedWidth, precisionArg: precisionArg, resolvedPrecision: resolvedPrecision, decimalSeparator: decimalSeparator, into: &output)
    }
}

private var UNLOCALIZED_NUMBER_MAX_SIZE: Int { 512 }

private func formatUnlocalizedNumber<T: StringCodeUnit>(
    _ spec: ParsedFormatSpec,
    format: Span<T>,
    value: _VarArgs.Argument,
    widthArg: Int32?,
    resolvedWidth: Int32?,
    precisionArg: Int32?,
    resolvedPrecision: Int32?,
    decimalSeparator: String?,
    into output: inout some StringBuilder & ~Copyable
) {
    withTemporaryAllocation(of: CChar.self, capacity: format.count + 1) { nullTerminatedFormat in
        copyStrippingPositions(format: format, into: &nullTerminatedFormat)
        withTemporaryAllocation(of: CChar.self, capacity: UNLOCALIZED_NUMBER_MAX_SIZE + Int(resolvedWidth ?? 0) + Int(resolvedPrecision ?? 0)) { tempOutput in
            nullTerminatedFormat.span.withUnsafeBufferPointer { formatBuffer in
                var number: (any CVarArg)?
                tempOutput.withUnsafeMutableBufferPointer { outputBuffer, initialized in
                    let destination = outputBuffer.extracting(droppingFirst: initialized)
                    let format = formatBuffer.baseAddress!
                    let hasWidth = widthArg != nil
                    let hasPrecision = precisionArg != nil
                    let width = widthArg ?? 0
                    let precision = precisionArg ?? 0
                    let result: Int32
                    switch value {
                    case .integer(let integer):
                        result = _stringformatshims_snprintf_int64(destination.baseAddress, destination.count, format, hasWidth, width, hasPrecision, precision, integer)
                        number = integer
                    case .pointer(let pointer):
                        result = _stringformatshims_snprintf_int64(destination.baseAddress, destination.count, format, hasWidth, width, hasPrecision, precision, Int64(Int(bitPattern: pointer)))
                    case .double(let double):
                        result = _stringformatshims_snprintf_double(destination.baseAddress, destination.count, format, hasWidth, width, hasPrecision, precision, double)
                        number = double
#if !(os(Windows) || os(Android)) && (arch(i386) || arch(x86_64))
                    case .longDouble(let longDouble):
                        result = _stringformatshims_snprintf_long_double(destination.baseAddress, destination.count, format, hasWidth, width, hasPrecision, precision, longDouble)
                        number = longDouble
#endif
                    }
                    if result >= 0 && result < destination.count {
                        // Note: CoreFoundation historical truncated at the first null byte, which is not correct when a null byte is intentional (i.e. %c with a argument of 0)
                        initialized += Int(result)
                    }
                }
                var encoding = String.Encoding.ascii
                // Localize the decimal separator if necessary. This is possible for hexadecimal floats (which don't use format styles but should have localized decimal separators)
                if case .double(_) = spec.kind, let decimalSeparator, let decimalIdx = tempOutput.span.firstIndex(of: CChar(UInt8(ascii: "."))) {
                    tempOutput.withUnsafeMutableBufferPointer { buffer, initialized in
                        let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
                        var raw = OutputRawSpan(buffer: rawBuffer, initializedCount: initialized)
                        raw._replaceSubrange(decimalIdx ..< decimalIdx + 1, copying: decimalSeparator.utf8.span.bytes)
                        initialized = raw.finalize(for: rawBuffer)
                    }
                    if (!decimalSeparator.utf8Span.isKnownASCII) {
                        // If the decimal separator is not known to be ASCII, treat the whole string as UTF-8 to support non-ASCII separators
                        encoding = .utf8
                    }
                } else if case .integer(let flags) = spec.kind, flags.size == .char {
                    // CoreFoundation historically treats %c output using the 8-bit encoding. However, even when the 8-bit encoding is ASCII, it still accepted non-ASCII characters effectively treating them as ISO Latin-1, so use ISO Latin-1 instead when the 8-bit encoding is ASCII
                    if String.Encoding.eightBit == .ascii {
                        encoding = .isoLatin1
                    } else {
                        encoding = String.Encoding.eightBit
                    }
                }
                let source: StringBuilderSource = if let number {
                    .number(number, for: spec)
                } else {
                    .other(for: spec)
                }
                output._append(copying: tempOutput.span.bytes, encoding: encoding, source: source)
            }
        }
    }
}
