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

// Note: we should consolidate the encoding logic in URLParser.swift to call
// into these functions, but keep them separate for now to minimize risk while
// we test the new implementations.
#if FOUNDATION_FRAMEWORK

// Percent-encoding using a given encoding means "get the string bytes in this
// encoding, then percent-encode those bytes."

// Percent-decoding using a given encoding means "decode any percent-escapes
// into the bytes they represent, then interpret those bytes in the given
// encoding before appending to the result."

// Many CFURL percent-encoding use-cases require skipping valid percent-escapes
// that are already in the string, e.g. "%20 %20" becomes "%20%20%20". However,
// some use-cases, such as encoding a file path or path component to append,
// will encode everything, including the "%" in a valid percent-escape.

extension URLComponentAllowedMask {
    // Used to encode ";" in a path component
    static let pathNoSemicolon = Self(rawValue: 0x47fffffe87ffffff27ffffd200000000)

    // Used to encode ";" and "/" in a path component
    static let pathNoSemicolonNoSlash = Self(rawValue: 0x47fffffe87ffffff27ff7fd200000000)
}

internal struct PercentDecodingASCIIExclusionMask: RawRepresentable {
    let rawValue: UInt128

    static let none = Self(rawValue: 0)

    // Don't decode "%2F" to "/" or "%00" to "\0"
    static let posixPath = Self(rawValue: 0x800000000001)

    // Don't decode "%5C" to "\" or "%2F" to "/" or "%00" to "\0"
    static let windowsPath = Self(rawValue: 0x100000000000800000000001)

    @inline(__always)
    func contains(_ codeUnit: UInt8) -> Bool {
        return codeUnit < 128 && ((rawValue & (UInt128(1) &<< codeUnit)) != 0)
    }
}

internal enum URLEncoder {

    // MARK: Percent-encoding

    /// - Note: Inlining allows us to omit checks during iteration for
    /// `skipAlreadyEncoded: false` and `checkBounds: false`.
    @inline(__always)
    private static func _percentEncode(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>,
        component allowedMask: URLComponentAllowedMask,
        skipAlreadyEncoded: Bool,
        checkBounds: Bool
    ) -> Int? {
        var writeIndex = 0
        var readIndex = 0
        while readIndex < input.count {
            let byte = input[readIndex]
            if allowedMask.contains(byte) {
                guard !checkBounds || writeIndex < output.count else { return nil }
                // Write the allowed byte
                output[writeIndex] = byte
                writeIndex += 1
                readIndex += 1
            } else if skipAlreadyEncoded, byte == UInt8(ascii: "%"),
                      readIndex + 2 < input.count,
                      input[readIndex + 1].isValidHexDigit,
                      input[readIndex + 2].isValidHexDigit {
                guard !checkBounds || writeIndex + 2 < output.count else { return nil }
                // Copy the valid percent-escape to the output buffer
                writeIndex = output[writeIndex...].initialize(
                    fromContentsOf: input[readIndex...(readIndex + 2)]
                )
                readIndex += 3
            } else {
                guard !checkBounds || writeIndex < output.count else { return nil }
                // Percent-encode this unallowed byte
                writeIndex = output[writeIndex...].initialize(fromContentsOf: [
                    UInt8(ascii: "%"),
                    hexToAscii(byte >> 4),
                    hexToAscii(byte & 0xF)
                ])
                readIndex += 1
            }
        }
        return writeIndex
    }

    /// Percent-encodes bytes from `input` that are not allowed in `component`,
    /// writing the result to `output`. When `skipAlreadyEncoded` is `true`,
    /// this function preserves valid percent-escape sequences in `input` and
    /// does not re-encode the `%` character.
    ///
    /// - Warning: Requires `output.count >= 3 * input.count` (worst case:
    ///   every byte becomes `%XX`). **No bounds checking is performed.**
    /// - Returns: The number of bytes written to `output`.
    static func percentEncodeUnchecked(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>,
        component: URLComponentAllowedMask,
        skipAlreadyEncoded: Bool
    ) -> Int {
        assert(output.count >= 3 * input.count)
        return _percentEncode(
            input: input,
            output: output,
            component: component,
            skipAlreadyEncoded: skipAlreadyEncoded,
            checkBounds: false
        )! // checkBounds: false never returns nil
    }

    /// Percent-encodes bytes from `input` that are not allowed in `component`,
    /// writing the result to `output`. When `skipAlreadyEncoded` is `true`,
    /// this function preserves valid percent-escape sequences in `input` and
    /// does not re-encode the `%` character.
    ///
    /// - Note: This function checks the bounds of `output` on every iteration
    ///   to ensure there's enough space to write.
    /// - Returns: The number of bytes written to `output`, or `nil` if the
    ///   `output` buffer was too small.
    static func percentEncode(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>,
        component: URLComponentAllowedMask,
        skipAlreadyEncoded: Bool
    ) -> Int? {
        return _percentEncode(
            input: input,
            output: output,
            component: component,
            skipAlreadyEncoded: skipAlreadyEncoded,
            checkBounds: true
        )
    }

    @_lifetime(output: copy output)
    static func percentEncode(
        input: borrowing Span<UInt8>,
        output: inout OutputSpan<UInt8>,
        component allowedSet: URLComponentAllowedSet
    ) -> Bool {
        for i in input.indices {
            let byte = input[i]
            if allowedSet.contains(byte) {
                guard !output.isFull else { return false }
                // Write the allowed byte
                output.append(byte)
            } else {
                guard output.freeCapacity >= 3 else { return false }
                // Percent-encode this unallowed byte
                output.append(UInt8(ascii: "%"))
                output.append(hexToAscii(byte >> 4))
                output.append(hexToAscii(byte & 0xF))
            }
        }
        return true
    }

    /// Percent-encodes bytes from `input` that are not allowed in `component`,
    /// writing the result to `output`. This function preserves valid percent-
    /// escape sequences in `input` and does not re-encode the `%` character.
    ///
    /// - Note: This function checks the remaining capacity of `output` on every
    ///   iteration to ensure there's enough space to write.
    /// - Returns: `true` on success, `false` if `output` was too small.
    @_lifetime(output: copy output)
    static func addPercentEscapes(
        input: borrowing Span<UInt8>,
        output: inout OutputSpan<UInt8>,
        component allowedMask: URLComponentAllowedMask
    ) -> Bool {
        var readIndex = input.indices.startIndex
        while readIndex < input.indices.endIndex {
            let byte = input[readIndex]
            if allowedMask.contains(byte) {
                guard !output.isFull else { return false }
                // Write the allowed byte
                output.append(byte)
                readIndex += 1
            } else if byte == UInt8(ascii: "%"),
                      readIndex + 2 < input.count,
                      input[readIndex + 1].isValidHexDigit,
                      input[readIndex + 2].isValidHexDigit {
                guard output.freeCapacity >= 3 else { return false }
                // Copy the valid percent-escape to the output buffer
                output.append(UInt8(ascii: "%"))
                output.append(input[readIndex + 1])
                output.append(input[readIndex + 2])
                readIndex += 3
            } else {
                guard output.freeCapacity >= 3 else { return false }
                // Percent-encode this unallowed byte
                output.append(UInt8(ascii: "%"))
                output.append(hexToAscii(byte >> 4))
                output.append(hexToAscii(byte & 0xF))
                readIndex += 1
            }
        }
        return true
    }

    // MARK: Percent-decoding

    /// - Note: Inlining allows us to omit checks during iteration for
    /// `checkBounds: false` and `excludingASCII: .none`.
    @inline(__always)
    private static func _percentDecode(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>,
        excludingASCII excluding: PercentDecodingASCIIExclusionMask,
        checkBounds: Bool
    ) -> Int? {
        var writeIndex = 0
        var readIndex = 0
        while readIndex < input.count {
            guard !checkBounds || writeIndex < output.count else { return nil }
            let v = input[readIndex]
            guard v == UInt8(ascii: "%") else {
                output[writeIndex] = v
                writeIndex += 1
                readIndex += 1
                continue
            }
            guard readIndex + 2 < input.count,
                  let hex1 = asciiToHex(input[readIndex + 1]),
                  let hex2 = asciiToHex(input[readIndex + 2]) else {
                return nil
            }
            let byte = (hex1 << 4) + hex2
            if excluding.contains(byte) {
                // Don't decode, write the original percent-escape sequence
                writeIndex = output[writeIndex...].initialize(
                    fromContentsOf: input[readIndex...(readIndex + 2)]
                )
            } else {
                output[writeIndex] = byte
                writeIndex += 1
            }
            readIndex += 3
        }
        return writeIndex
    }

    /// Decodes any percent-escape sequences in `input` and writes the
    /// percent-decoded result to `output`.
    ///
    /// - Note: If the `output` buffer smaller than the `input` buffer, this
    ///   function will check the bounds of `output` on every iteration to
    ///   ensure there's enough space to write.
    ///
    /// - Returns: The number of bytes written to `output`, or `nil` if there
    ///   was an invalid escape sequence or the `output` buffer was too small.
    static func percentDecode(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>
    ) -> Int? {
        let checkBounds = output.count < input.count
        return _percentDecode(
            input: input,
            output: output,
            excludingASCII: .none,
            checkBounds: checkBounds
        )
    }

    /// Reads the `input` buffer, decodes any percent-escape sequences,
    /// and writes the percent-decoded result to the `output` buffer.
    ///
    /// - Warning: The `output` buffer must be least as big as the `input` buffer.
    /// - Returns: The number of bytes written to `output`, or `nil` if there
    ///   was an invalid escape sequence.
    static func percentDecodeUnchecked(
        input: UnsafeBufferPointer<UInt8>,
        output: UnsafeMutableBufferPointer<UInt8>
    ) -> Int? {
        return _percentDecode(
            input: input,
            output: output,
            excludingASCII: .none,
            checkBounds: false
        )
    }

    // MARK: String encoding and decoding

    /// Percent-encodes any UTF8 bytes in `string` that are not allowed
    /// in `component`, and returns the percent-encoded `String`. When
    /// `skipAlreadyEncoded` is `true`, this function preserves valid
    /// percent-escape sequences and does not re-encode the `%` character.
    ///
    /// - Returns: The percent-encoded `String`.
    static func percentEncode(
        string: String,
        component: URLComponentAllowedMask,
        skipAlreadyEncoded: Bool
    ) -> String {
        guard !string.isEmpty else {
            return string
        }
        var mut = string
        return mut.withUTF8 { buffer in
            return String(unsafeUninitializedCapacity: 3 * buffer.count) { encodedBuffer in
                return URLEncoder.percentEncodeUnchecked(
                    input: buffer,
                    output: encodedBuffer,
                    component: component,
                    skipAlreadyEncoded: skipAlreadyEncoded
                )
            }
        }
    }

    /// Gets the bytes of `string` in `encoding`, then percent-encodes any
    /// bytes that are not allowed in `component`, and returns the percent-
    /// encoded `String`.
    ///
    /// This function behaves like `CFURLCreateStringByAddingPercentEscapes()`,
    /// but does not give the option to leave invalid characters in the string.
    /// It also assumes `encoding` is a superset of ASCII, which is guaranteed
    /// to be the case for any `CFURL` since `CFURLCreateWithBytes()` returns
    /// `NULL` otherwise. It should not be called with non-ASCII supersets.
    ///
    /// - Note: Removing allowed bits from `component` is the same as adding
    ///   ASCII characters to `legalURLCharactersToBeEscaped`, but much faster.
    /// - Returns: The percent-encoded `String`, or `nil` if we fail to get the
    ///   string's bytes in the given `encoding`.
    static func percentEncode(
        string: String,
        encoding: String.Encoding,
        component: URLComponentAllowedMask,
        skipAlreadyEncoded: Bool
    ) -> String? {
        if encoding == .utf8 || encoding == .ascii {
            return percentEncode(string: string, component: component, skipAlreadyEncoded: skipAlreadyEncoded)
        }
        guard !string.isEmpty else {
            return string
        }
        guard let data = string.data(using: encoding) else {
            return nil
        }
        return data.withUnsafeBytes {
            let buffer = $0.bindMemory(to: UInt8.self)
            // Percent-encoding produces ASCII bytes for any URLComponentAllowedMask,
            // so assuming `encoding` is a superset of ASCII, we can initialize the
            // String with a UTF8 `encodedBuffer` that is all ASCII.
            return String(unsafeUninitializedCapacity: 3 * buffer.count) { encodedBuffer in
                return URLEncoder.percentEncodeUnchecked(
                    input: buffer,
                    output: encodedBuffer,
                    component: component,
                    skipAlreadyEncoded: skipAlreadyEncoded
                )
            }
        }
    }

    /// Decodes percent-escapes in `string`, interprets the decoded bytes as
    /// UTF8, and creates a new `String` from the resulting bytes.
    ///
    /// - Note: Fast path for UTF8 (default) with no characters to leave escaped.
    /// - Returns: The decoded `String`, or `nil` if the input contained
    ///   invalid percent-escapes or the decoded bytes were not valid UTF8.
    static func percentDecode(string: String) -> String? {
        guard !string.isEmpty else {
            return string
        }
        var mut = string
        return mut.withUTF8 { buffer in
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: buffer.count) { decodedBuffer -> String? in
                guard let bytesWritten = URLEncoder._percentDecode(
                    input: buffer,
                    output: decodedBuffer,
                    excludingASCII: .none,
                    checkBounds: false
                ) else {
                    return nil
                }
                let output = UnsafeBufferPointer(rebasing: decodedBuffer[..<bytesWritten])
                return String._tryFromUTF8(output)
            }
        }
    }


    /// Decodes percent-escapes in `string`, interprets the decoded bytes as
    /// UTF8, and creates a new `String` from the resulting bytes. Percent-
    /// escapes that represent ASCII characters in the `excludingASCII` mask
    /// will not be decoded and will be copied to the output as-is.
    ///
    /// - Returns: The decoded `String`, or `nil` if the input contained
    ///   invalid percent-escapes or the decoded bytes were not valid UTF8.
    static func percentDecode(
        string: String,
        excludingASCII: PercentDecodingASCIIExclusionMask
    ) -> String? {
        guard !string.isEmpty else {
            return string
        }
        var mut = string
        return mut.withUTF8 { buffer in
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: buffer.count) { decodedBuffer -> String? in
                guard let bytesWritten = URLEncoder._percentDecode(
                    input: buffer,
                    output: decodedBuffer,
                    excludingASCII: excludingASCII,
                    checkBounds: false
                ) else {
                    return nil
                }
                let output = UnsafeBufferPointer(rebasing: decodedBuffer[..<bytesWritten])
                return String._tryFromUTF8(output)
            }
        }
    }

    static func percentDecode(
        string: String,
        encoding: String.Encoding,
    ) -> String? {
        return percentDecode(string: string, encoding: encoding, excludingASCII: .none)
    }

    /// Decodes percent-escapes in `string`, interprets the decoded bytes in the
    /// given `encoding`, and creates a new `String` from the resulting bytes.
    /// Percent-escapes that represent ASCII characters in the `excludingASCII`
    /// mask will not be decoded and will be copied to the output as-is.
    ///
    /// - Note: Assumes `encoding` is a superset of ASCII.
    /// - Returns: The decoded `String`, or `nil` if the input contained
    ///   invalid percent-escapes or the decoded bytes could not be interpreted
    ///   in the given `encoding`.
    static func percentDecode(
        string: String,
        encoding: String.Encoding,
        excludingASCII excluding: PercentDecodingASCIIExclusionMask
    ) -> String? {
        if encoding == .utf8 {
            return percentDecode(string: string, excludingASCII: excluding)
        }
        var mut = string
        return mut.withUTF8 { input in
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: input.count) { output -> String? in
                var writeIndex = 0
                var readIndex = 0
                while readIndex < input.count {
                    let v = input[readIndex]
                    guard v == UInt8(ascii: "%") else {
                        output[writeIndex] = v
                        writeIndex += 1
                        readIndex += 1
                        continue
                    }

                    guard readIndex + 2 < input.count,
                          let hex1 = asciiToHex(input[readIndex + 1]),
                          let hex2 = asciiToHex(input[readIndex + 2]) else {
                        return nil
                    }

                    let byte = (hex1 << 4) + hex2
                    if excluding.contains(byte) {
                        // Assume here that `encoding` is a superset of ASCII.
                        // Don't decode, write the original percent-escape sequence
                        writeIndex = output[writeIndex...].initialize(
                            fromContentsOf: input[readIndex...(readIndex + 2)]
                        )
                        readIndex += 3
                        continue
                    }
                    // Skip past the `%XX` representing `byte`
                    readIndex += 3

                    // Special case some common, simple encodings
                    if encoding == .ascii || encoding == .isoLatin1 {
                        // For compatibility reasons, creating a string with
                        // ASCII encoding treats non-ASCII as ISOLatin1.
                        if byte < 128 {
                            output[writeIndex] = byte
                            writeIndex += 1
                        } else {
                            // Convert this ISOLatin1 byte to UTF8
                            output[writeIndex] = (0xC0 | (byte >> 6))       // 110000xx
                            output[writeIndex + 1] = (0x80 | (byte & 0x3F)) // 10xxxxxx
                            writeIndex += 2
                        }
                        continue
                    }

                    // Use the output buffer as scratch space for decoding
                    // instead of making a new allocation, then write over
                    // decoded bytes with their UTF8 representation.

                    // Save the start of the decoded bytes
                    let decodedStart = writeIndex
                    output[writeIndex] = byte
                    writeIndex += 1

                    // Write all consecutive decoded bytes into the buffer,
                    // then use String(bytes:encoding:) for conversion to UTF8.
                    while readIndex < input.count && input[readIndex] == UInt8(ascii: "%") {
                        guard readIndex + 2 < input.count,
                              let hex1 = asciiToHex(input[readIndex + 1]),
                              let hex2 = asciiToHex(input[readIndex + 2]) else {
                            return nil
                        }
                        let byte = (hex1 << 4) + hex2
                        guard !excluding.contains(byte) else {
                            // We'll write the original percent-escape sequence
                            // when we check this byte again in the outer loop.
                            break
                        }
                        output[writeIndex] = byte
                        writeIndex += 1
                        readIndex += 3
                    }
                    let bytes = output[decodedStart..<writeIndex]
                    guard let decodedString = String(bytes: bytes, encoding: encoding) else {
                        return nil
                    }
                    writeIndex = output[decodedStart...].initialize(
                        fromContentsOf: decodedString.utf8
                    )
                }
                let utf8 = UnsafeBufferPointer(rebasing: output[..<writeIndex])
                return String._tryFromUTF8(utf8)
            }
        }
    }

    static func percentDecode(
        string: String,
        encoding: String.Encoding,
        excludingScalars excluding: some Collection<UnicodeScalar>
    ) -> String? {
        var asciiMask = UInt128(0)
        var excludingIsASCII = true
        for scalar in excluding {
            guard scalar.value < 128 else {
                excludingIsASCII = false
                break
            }
            asciiMask |= (UInt128(1) &<< scalar.value)
        }
        if excludingIsASCII {
            // Note: this path is also taken when `excluding` is empty.
            let exclusionMask = PercentDecodingASCIIExclusionMask(rawValue: asciiMask)
            return percentDecode(string: string, encoding: encoding, excludingASCII: exclusionMask)
        }

        // Now for the more expensive decoding process using scalars
        let scalars = string.unicodeScalars
        var readIndex = scalars.startIndex
        let endIndex = scalars.endIndex
        var result = ""
        while readIndex != endIndex {
            guard scalars[readIndex] == "%" else {
                result.unicodeScalars.append(scalars[readIndex])
                readIndex = scalars.index(after: readIndex)
                continue
            }

            var decoded = [UInt8]()
            repeat {
                let index1 = scalars.index(after: readIndex)
                guard index1 != endIndex else {
                    return nil
                }
                let index2 = scalars.index(after: index1)
                guard index2 != endIndex else {
                    return nil
                }
                let scalar1 = scalars[index1].value
                let scalar2 = scalars[index2].value
                guard scalar1 < 128, scalar2 < 128,
                      let hex1 = asciiToHex(UInt8(truncatingIfNeeded: scalar1)),
                      let hex2 = asciiToHex(UInt8(truncatingIfNeeded: scalar2)) else {
                    return nil
                }
                let byte = (hex1 << 4) + hex2
                decoded.append(byte)
                readIndex = scalars.index(after: index2)
            } while (
                readIndex != endIndex && scalars[readIndex] == "%"
            )

            guard let decodedString = String(bytes: decoded, encoding: encoding) else {
                return nil
            }
            if decodedString.unicodeScalars.allSatisfy({ !excluding.contains($0) }) {
                result.append(decodedString)
                continue
            }
            for scalar in decodedString.unicodeScalars {
                if excluding.contains(scalar) {
                    // Copy the original percent-escape bytes for this scalar
                    guard let encodedString = percentEncode(scalar: scalar, encoding: encoding) else {
                        return nil
                    }
                    result.append(encodedString)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result
    }

    private static func percentEncode(scalar: UnicodeScalar, encoding: String.Encoding) -> String? {
        guard let data = String(scalar).data(using: encoding) else {
            return nil
        }
        return String(unsafeUninitializedCapacity: 3 * data.count) { buffer in
            var writeIndex = 0
            for byte in data {
                writeIndex = buffer[writeIndex...].initialize(fromContentsOf: [
                    UInt8(ascii: "%"),
                    hexToAscii(byte >> 4),
                    hexToAscii(byte & 0xF)
                ])
            }
            return writeIndex
        }
    }
}

#endif
