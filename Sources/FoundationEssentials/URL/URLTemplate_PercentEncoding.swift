//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension String {
    /// Convert to NFC and percent-escape.
    func normalizedAddingPercentEncoding(
        withAllowedCharacters allowed: URL.Template.Expression.Operator.AllowedCharacters
    ) -> String {
        return withContiguousNFCAndOutputBuffer(allowed: allowed) { input -> String in
            switch input {
            case .noConversionNorEncodedNeeded: return self
            case .needsEncoding(input: let inputBuffer, outputCount: let outputCount):
                switch allowed {
                case .unreserved:
                    return addingPercentEncodingToNFC(
                        input: inputBuffer,
                        outputCount: outputCount,
                        allowed: allowed
                    )
                case .unreservedReserved:
                    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: outputCount + 1) { outputBuffer -> String in
                        addPercentEscapesForUnreservedReserved(
                            inputBuffer: inputBuffer,
                            outputBuffer: outputBuffer
                        )
                    }
                }
            }
        }
    }
}

/// For the `unreserved / reserved / pct-encoded` case, create a String by percent encoding the NFC input as needed.
private func addPercentEscapesForUnreservedReserved(
    inputBuffer: UnsafeBufferPointer<UTF8.CodeUnit>,
    outputBuffer: UnsafeMutableBufferPointer<UTF8.CodeUnit>
) -> String {
    let allowed = URL.Template.Expression.Operator.AllowedCharacters.unreservedReserved

    var remainingInput = inputBuffer[...]
    var outputIndex = 0

    func write(_ a: UInt8) {
        outputBuffer[outputIndex] = a
        outputIndex += 1
    }

    while let next = remainingInput.popFirst() {
        // Any (valid) existing escape sequences need to be copied to the output verbatim.
        // But any `%` that are not part of a valid escape sequence, need to be encoded.
        guard next != UInt8(ascii: "%") || remainingInput.count < 2 else {
            // Is this a valid escape sequence?
            if remainingInput[remainingInput.startIndex].isValidHexDigit && remainingInput[remainingInput.startIndex + 1].isValidHexDigit {
                write(next)
            } else {
                write(UInt8(ascii: "%"))
                write(UInt8(ascii: "2"))
                write(UInt8(ascii: "5"))
            }
            continue
        }
        if allowed.isAllowedCodeUnit(next) {
            write(next)
        } else {
            write(UInt8(ascii: "%"))
            write(hexToAscii(next >> 4))
            write(hexToAscii(next & 0xf))
        }
    }

    return String(decoding: outputBuffer[..<outputIndex], as: UTF8.self)
}

private func addingPercentEncodingToNFC(
    input inputBuffer: UnsafeBufferPointer<String.UTF8View.Element>,
    outputCount: Int,
    allowed: URL.Template.Expression.Operator.AllowedCharacters
) -> String {
    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: outputCount + 1) { outputBuffer -> String in
        var index = 0
        for v in inputBuffer {
            if allowed.isAllowedCodeUnit(v) {
                outputBuffer[index] = v
                index += 1
            } else {
                outputBuffer[index + 0] = UInt8(ascii: "%")
                outputBuffer[index + 1] = hexToAscii(v >> 4)
                outputBuffer[index + 2] = hexToAscii(v & 0xF)
                index += 3
            }
        }
        return String(decoding: outputBuffer[..<index], as: UTF8.self)
    }
}

fileprivate enum NeededConversion: Comparable {
    case none
    case encodeOnly(outputCount: Int)
    case convertAndEncode
}

fileprivate enum AllowedNFCResult {
    case noConversionNorEncodedNeeded
    case needsEncoding(input: UnsafeBufferPointer<String.UTF8View.Element>, outputCount: Int)
}

extension String {
    /// Runs the given closure with a UTF-8 buffer that is the NFC normalized version of the string.
    ///
    /// If the input is already NFC _and_ it only contains allowed characters, the given closure will
    /// be called with ``NeededConversion.noConversionNorEncodedNeeded`.
    fileprivate func withContiguousNFCAndOutputBuffer<R>(
        allowed: URL.Template.Expression.Operator.AllowedCharacters,
        _ body: (AllowedNFCResult) -> R
    ) -> R {
        // We’ll do a quick check. If the input is valid UTF-8 and bytes are less than
        // 0xcc, then it’s NFC. Since most input will be ASCII, this allows us to
        // be more efficient in those common cases.
        // At the same, we’ll do a check if there are any characters that need
        // encoding. If the input (is likely) already NFC, and nothing needs
        // percent encoding, we can just use the original input.

        func cheapCheck(utf8Buffer: some Collection<UInt8>) -> NeededConversion {
            // The number of code units that need percent encoding:
            var needsEncoding = 0
            var count = 0
            for v in utf8Buffer {
                count += 1
                switch (v < 0xcc, allowed.isAllowedCodeUnit(v)) {
                case (false, _):
                    // Input might not be NFC. Need to convert.
                    return .convertAndEncode
                case (true, false):
                    needsEncoding += 1
                case (true, true):
                    break
                }
            }
            return (needsEncoding == 0) ? .none : .encodeOnly(outputCount: count + 2 * needsEncoding)
        }

        let fastResult: R?? = utf8.withContiguousStorageIfAvailable {
            switch cheapCheck(utf8Buffer: $0) {
            case .none:
                return body(.noConversionNorEncodedNeeded)
            case .encodeOnly(outputCount: let c):
                return body(.needsEncoding(input: $0, outputCount: c))
            case .convertAndEncode:
                return nil
            }
        }
        switch fastResult {
        case .some(.some(let r)):
            return r
        case .some(.none):
            // We have a continguous UTF-8 buffer, but it’s (probably) not NFC
            break
        case .none:
            // Contiguous UTF-8 storage is not available:
            switch cheapCheck(utf8Buffer: utf8) {
            case .none:
                return body(.noConversionNorEncodedNeeded)
            case .encodeOnly(outputCount: let c):
                return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8.count) { buffer in
                    _ = buffer.initialize(from: utf8)
                    return body(.needsEncoding(input: UnsafeBufferPointer(buffer), outputCount: c))
                }
            case .convertAndEncode:
                break
            }
        }
        // Convert to NFC:
        return _nfcCodeUnits.withUnsafeBufferPointer { input in
            let outputCount = input.reduce(into: 0) {
                $0 += allowed.isAllowedCodeUnit($1) ? 1 : 3
            }
            return body(.needsEncoding(input: input, outputCount: outputCount))
        }
    }
}

extension URL.Template.Expression.Operator.AllowedCharacters {
    func isAllowedCodeUnit(_ unit: UTF8.CodeUnit) -> Bool {
        switch self {
        case .unreserved:
            return unit.isUnreservedURLCharacter
        case .unreservedReserved:
            return unit.isValidURLCharacter
        }
    }
}

private func hexToAscii(_ hex: UInt8) -> UInt8 {
    switch hex {
    case 0x0: UInt8(ascii: "0")
    case 0x1: UInt8(ascii: "1")
    case 0x2: UInt8(ascii: "2")
    case 0x3: UInt8(ascii: "3")
    case 0x4: UInt8(ascii: "4")
    case 0x5: UInt8(ascii: "5")
    case 0x6: UInt8(ascii: "6")
    case 0x7: UInt8(ascii: "7")
    case 0x8: UInt8(ascii: "8")
    case 0x9: UInt8(ascii: "9")
    case 0xA: UInt8(ascii: "A")
    case 0xB: UInt8(ascii: "B")
    case 0xC: UInt8(ascii: "C")
    case 0xD: UInt8(ascii: "D")
    case 0xE: UInt8(ascii: "E")
    case 0xF: UInt8(ascii: "F")
    default: fatalError("Invalid hex digit: \(hex)")
    }
}
