//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

private enum Base64Error: Error {
    case invalidElementCount
    case cannotDecode
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Data {

    // MARK: - Init from base64

    /// Initialize a `Data` from a Base-64 encoded String using the given options.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    /// - parameter base64String: The string to parse.
    /// - parameter options: Encoding options. Default value is `[]`.
    public init?(base64Encoded base64String: __shared String, options: Base64DecodingOptions = []) {
#if FOUNDATION_FRAMEWORK
        if let d = NSData(base64Encoded: base64String, options: NSData.Base64DecodingOptions(rawValue: options.rawValue)) {
            self.init(referencing: d)
        } else {
            return nil
        }
#else
        var encoded = base64String
        let decoded = encoded.withUTF8 {
            // String won't pass an empty buffer with a `nil` `baseAddress`.
            Data(decodingBase64: BufferView(unsafeBufferPointer: $0)!, options: options)
        }
        guard let decoded else { return nil }
        self = decoded
#endif
    }

    /// Initialize a `Data` from a Base-64, UTF-8 encoded `Data`.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    ///
    /// - parameter base64Data: Base-64, UTF-8 encoded input data.
    /// - parameter options: Decoding options. Default value is `[]`.
    public init?(base64Encoded base64Data: __shared Data, options: Base64DecodingOptions = []) {
#if FOUNDATION_FRAMEWORK
        if let d = NSData(base64Encoded: base64Data, options: NSData.Base64DecodingOptions(rawValue: options.rawValue)) {
            self.init(referencing: d)
        } else {
            return nil
        }
#else
        let decoded = base64Data.withBufferView {
            Data(decodingBase64: $0, options: options)
        }
        guard let decoded else { return nil }
        self = decoded
#endif
    }

    init?(decodingBase64 bytes: borrowing BufferView<UInt8>, options: Base64DecodingOptions = []) {
        guard bytes.count.isMultiple(of: 4) || options.contains(.ignoreUnknownCharacters)
        else { return nil }

        // Every 4 valid ASCII bytes maps to 3 output bytes: (bytes.count * 3)/4
        let capacity = (bytes.count * 3) >> 2
        // A non-trapping version of the calculation goes like this:
        // let (q, r) = bytes.count.quotientAndRemainder(dividingBy: 4)
        // let capacity = (q * 3) + (r==0 ? 0 : r-1)
        let decoded = try? Data(
            capacity: capacity,
            initializingWith: { //FIXME: should work with borrowed `bytes`
                [bytes = copy bytes] in
                try Data.base64DecodeBytes(bytes, &$0, options: options)
            }
        )
        guard let decoded else { return nil }
        self = decoded
    }

    // MARK: - Create base64

    /// Returns a Base-64 encoded string.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded string.
    public func base64EncodedString(options: Base64EncodingOptions = []) -> String {
        Base64.encodeToString(bytes: self, options: options)
    }

    /// Returns a Base-64 encoded `Data`.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded data.
    public func base64EncodedData(options: Base64EncodingOptions = []) -> Data {
        Base64.encodeToData(bytes: self, options: options)
    }

    // MARK: - Internal Helpers

    /**
     This method decodes Base64-encoded data.

     If the input contains any bytes that are not valid Base64 characters,
     this will throw a `Base64Error`.

     - parameter bytes:      The Base64 bytes
     - parameter output:     An OutputBuffer to be filled with decoded bytes
     - parameter options:    Options for handling invalid input
     - throws:               When decoding fails
     */
    static func base64DecodeBytes(
        _ bytes: borrowing BufferView<UInt8>, _ output: inout OutputBuffer<UInt8>, options: Base64DecodingOptions = []
    ) throws {
        guard bytes.count.isMultiple(of: 4) || options.contains(.ignoreUnknownCharacters)
        else { throw Base64Error.invalidElementCount }

        // This table maps byte values 0-127, input bytes >127 are always invalid.
        // Map the ASCII characters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" -> 0...63
        // Map '=' (ASCII 61) to 0x40.
        // All other values map to 0x7f. This allows '=' and invalid bytes to be checked together by testing bit 6 (0x40).
        let base64Decode: StaticString = """
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\u{3e}\u{7f}\u{7f}\u{7f}\u{3f}\
\u{34}\u{35}\u{36}\u{37}\u{38}\u{39}\u{3a}\u{3b}\u{3c}\u{3d}\u{7f}\u{7f}\u{7f}\u{40}\u{7f}\u{7f}\
\u{7f}\u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\u{08}\u{09}\u{0a}\u{0b}\u{0c}\u{0d}\u{0e}\
\u{0f}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}\
\u{7f}\u{1a}\u{1b}\u{1c}\u{1d}\u{1e}\u{1f}\u{20}\u{21}\u{22}\u{23}\u{24}\u{25}\u{26}\u{27}\u{28}\
\u{29}\u{2a}\u{2b}\u{2c}\u{2d}\u{2e}\u{2f}\u{30}\u{31}\u{32}\u{33}\u{7f}\u{7f}\u{7f}\u{7f}\u{7f}
"""
        assert(base64Decode.isASCII)
        assert(base64Decode.utf8CodeUnitCount == 128)
        assert(base64Decode.hasPointerRepresentation)

        let ignoreUnknown = options.contains(.ignoreUnknownCharacters)

        var currentByte: UInt8 = 0
        var validCharacterCount = 0
        var paddingCount = 0
        var index = 0

        for base64Char in bytes {
            var value: UInt8 = 0

            var invalid = false
            if base64Char >= base64Decode.utf8CodeUnitCount {
                invalid = true
            } else {
                value = base64Decode.utf8Start[Int(base64Char)]
                if value & 0x40 == 0x40 {       // Input byte is either '=' or an invalid value.
                    if value == 0x7f {
                        invalid = true
                    } else if value == 0x40 {   // '=' padding at end of input.
                        paddingCount += 1
                        continue
                    }
                }
            }

            if invalid {
                if ignoreUnknown {
                    continue
                } else {
                    throw Base64Error.cannotDecode
                }
            }
            validCharacterCount += 1

            // Padding found in the middle of the sequence is invalid.
            if paddingCount > 0 {
                throw Base64Error.cannotDecode
            }

            switch index {
            case 0:
                currentByte = (value << 2)
            case 1:
                currentByte |= (value >> 4)
                output.appendElement(currentByte)
                currentByte = (value << 4)
            case 2:
                currentByte |= (value >> 2)
                output.appendElement(currentByte)
                currentByte = (value << 6)
            case 3:
                currentByte |= value
                output.appendElement(currentByte)
                index = -1
            default:
                fatalError("Invalid state")
            }

            index += 1
        }

        guard (validCharacterCount + paddingCount) % 4 == 0 else {
            // Invalid character count of valid input characters.
            throw Base64Error.cannotDecode
        }
    }
}

// This base64 implementation is heavily inspired by:
//
// https://github.com/lemire/fastbase64/blob/master/src/chromiumbase64.c
// https://github.com/client9/stringencoders/blob/master/src/modp_b64.c
//
// See NOTICE.txt for Licenses

enum Base64 {}

// MARK: - Encoding -

extension Base64 {
    static let encodePaddingCharacter: UInt8 = 61

    static let encoding0: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "B"), UInt8(ascii: "B"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "C"),
        UInt8(ascii: "C"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "D"), UInt8(ascii: "D"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"), UInt8(ascii: "E"),
        UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "G"), UInt8(ascii: "G"), UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "H"),
        UInt8(ascii: "H"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "I"), UInt8(ascii: "I"), UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "L"), UInt8(ascii: "L"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "M"),
        UInt8(ascii: "M"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "N"), UInt8(ascii: "N"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"), UInt8(ascii: "O"),
        UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "Q"), UInt8(ascii: "Q"), UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "R"),
        UInt8(ascii: "R"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "S"), UInt8(ascii: "S"), UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "V"), UInt8(ascii: "V"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "W"),
        UInt8(ascii: "W"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "X"), UInt8(ascii: "X"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"), UInt8(ascii: "Y"),
        UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "a"), UInt8(ascii: "a"), UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "b"),
        UInt8(ascii: "b"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "c"), UInt8(ascii: "c"), UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "f"), UInt8(ascii: "f"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "g"),
        UInt8(ascii: "g"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "h"), UInt8(ascii: "h"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"), UInt8(ascii: "i"),
        UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "k"), UInt8(ascii: "k"), UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "l"),
        UInt8(ascii: "l"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "m"), UInt8(ascii: "m"), UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "p"), UInt8(ascii: "p"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "q"),
        UInt8(ascii: "q"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "r"), UInt8(ascii: "r"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"), UInt8(ascii: "s"),
        UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "u"), UInt8(ascii: "u"), UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "v"),
        UInt8(ascii: "v"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "w"), UInt8(ascii: "w"), UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "z"), UInt8(ascii: "z"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "0"),
        UInt8(ascii: "0"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "1"), UInt8(ascii: "1"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"), UInt8(ascii: "2"),
        UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "4"), UInt8(ascii: "4"), UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "5"),
        UInt8(ascii: "5"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "6"), UInt8(ascii: "6"), UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "+"),
        UInt8(ascii: "+"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "/"), UInt8(ascii: "/"), UInt8(ascii: "/"),
    ]

    static let encoding1: [UInt8] = [
        UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"),
        UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"),
        UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"),
        UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"),
        UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"),
        UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"),
        UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"),
        UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"),
        UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"),
        UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"),
        UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"),
        UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"),
        UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"), UInt8(ascii: "B"),
        UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"), UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"),
        UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "R"), UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"),
        UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"),
        UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "l"), UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"),
        UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"), UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"),
        UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "5"), UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"),
        UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "A"), UInt8(ascii: "B"), UInt8(ascii: "C"), UInt8(ascii: "D"), UInt8(ascii: "E"), UInt8(ascii: "F"), UInt8(ascii: "G"), UInt8(ascii: "H"),
        UInt8(ascii: "I"), UInt8(ascii: "J"), UInt8(ascii: "K"), UInt8(ascii: "L"), UInt8(ascii: "M"), UInt8(ascii: "N"), UInt8(ascii: "O"), UInt8(ascii: "P"), UInt8(ascii: "Q"), UInt8(ascii: "R"),
        UInt8(ascii: "S"), UInt8(ascii: "T"), UInt8(ascii: "U"), UInt8(ascii: "V"), UInt8(ascii: "W"), UInt8(ascii: "X"), UInt8(ascii: "Y"), UInt8(ascii: "Z"), UInt8(ascii: "a"), UInt8(ascii: "b"),
        UInt8(ascii: "c"), UInt8(ascii: "d"), UInt8(ascii: "e"), UInt8(ascii: "f"), UInt8(ascii: "g"), UInt8(ascii: "h"), UInt8(ascii: "i"), UInt8(ascii: "j"), UInt8(ascii: "k"), UInt8(ascii: "l"),
        UInt8(ascii: "m"), UInt8(ascii: "n"), UInt8(ascii: "o"), UInt8(ascii: "p"), UInt8(ascii: "q"), UInt8(ascii: "r"), UInt8(ascii: "s"), UInt8(ascii: "t"), UInt8(ascii: "u"), UInt8(ascii: "v"),
        UInt8(ascii: "w"), UInt8(ascii: "x"), UInt8(ascii: "y"), UInt8(ascii: "z"), UInt8(ascii: "0"), UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "3"), UInt8(ascii: "4"), UInt8(ascii: "5"),
        UInt8(ascii: "6"), UInt8(ascii: "7"), UInt8(ascii: "8"), UInt8(ascii: "9"), UInt8(ascii: "+"), UInt8(ascii: "/"),
    ]

    static func encodeToBytes<Buffer: Collection>(bytes: Buffer, options: Data.Base64EncodingOptions)
        -> [UInt8] where Buffer.Element == UInt8
    {
        let newCapacity = self.encodeComputeCapacity(bytes: bytes.count, options: options)

        if let result = bytes.withContiguousStorageIfAvailable({ input -> [UInt8] in
            [UInt8](unsafeUninitializedCapacity: newCapacity) { buffer, length in
                Self._encode(input: input, buffer: buffer, length: &length, options: options)
            }
        }) {
            return result
        }

        return self.encodeToBytes(bytes: Array(bytes), options: options)
    }

    static func encodeToString<Buffer: Collection>(bytes: Buffer, options: Data.Base64EncodingOptions = [])
        -> String where Buffer.Element == UInt8
    {
        let newCapacity = self.encodeComputeCapacity(bytes: bytes.count, options: options)

        if #available(OSX 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            if let result = bytes.withContiguousStorageIfAvailable({ input -> String in
                String(unsafeUninitializedCapacity: newCapacity) { buffer -> Int in
                    var length = newCapacity
                    Self._encode(input: input, buffer: buffer, length: &length, options: options)
                    return length
                }
            }) {
                return result
            }

            return self.encodeToString(bytes: Array(bytes), options: options)
        } else {
            let bytes: [UInt8] = self.encodeToBytes(bytes: bytes, options: options)
            return String(decoding: bytes, as: Unicode.UTF8.self)
        }
    }

    static func encodeToData<Buffer: Collection>(bytes: Buffer, options: Data.Base64EncodingOptions = [])
        -> Data where Buffer.Element == UInt8
    {
        let newCapacity = self.encodeComputeCapacity(bytes: bytes.count, options: options)

        if let result = bytes.withContiguousStorageIfAvailable({ input -> Data in
            var data = Data(count: newCapacity) // initialized with zeroed buffer
            _ = data.withUnsafeMutableBytes { rawBuffer in
                rawBuffer.withMemoryRebound(to: UInt8.self) { buffer in
                    var length = newCapacity
                    Self._encode(input: input, buffer: buffer, length: &length, options: options)
                    return length
                }
            }
            return data
        }) {
            return result
        }

        return self.encodeToData(bytes: Array(bytes), options: options)
    }

    @usableFromInline
    static func _encode(input: UnsafeBufferPointer<UInt8>, buffer: UnsafeMutableBufferPointer<UInt8>, length: inout Int, options: Data.Base64EncodingOptions) {
        if options.contains(.lineLength64Characters) || options.contains(.lineLength76Characters) {
            return self._encodeWithLineBreaks(input: input, buffer: buffer, length: &length, options: options)
        }

        let omitPaddingCharacter = false // options.contains(.omitPaddingCharacter)

        Self.withUnsafeEncodingTablesAsBufferPointers(options: options) { e0, e1 in
            let to = input.count / 3 * 3
            var outIndex = 0
            for index in stride(from: 0, to: to, by: 3) {
                let i1 = input[index]
                let i2 = input[index &+ 1]
                let i3 = input[index &+ 2]
                buffer[outIndex] = e0[Int(i1)]
                buffer[outIndex &+ 1] = e1[Int(((i1 & 0x03) &<< 4) | ((i2 &>> 4) & 0x0F))]
                buffer[outIndex &+ 2] = e1[Int(((i2 & 0x0F) &<< 2) | ((i3 &>> 6) & 0x03))]
                buffer[outIndex &+ 3] = e1[Int(i3)]
                outIndex += 4
            }

            if to < input.count {
                let index = to

                let i1 = input[index]
                let i2 = index &+ 1 < input.count ? input[index &+ 1] : nil
                let i3 = index &+ 2 < input.count ? input[index &+ 2] : nil

                buffer[outIndex] = e0[Int(i1)]

                if let i2 = i2, let i3 = i3 {
                    buffer[outIndex &+ 1] = e1[Int(((i1 & 0x03) &<< 4) | ((i2 &>> 4) & 0x0F))]
                    buffer[outIndex &+ 2] = e1[Int(((i2 & 0x0F) &<< 2) | ((i3 &>> 6) & 0x03))]
                    buffer[outIndex &+ 3] = e1[Int(i3)]
                    outIndex += 4
                } else if let i2 = i2 {
                    buffer[outIndex &+ 1] = e1[Int(((i1 & 0x03) &<< 4) | ((i2 &>> 4) & 0x0F))]
                    buffer[outIndex &+ 2] = e1[Int((i2 & 0x0F) &<< 2)]
                    outIndex += 3
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        outIndex &+= 1
                    }
                } else {
                    buffer[outIndex &+ 1] = e1[Int((i1 & 0x03) << 4)]
                    outIndex &+= 2
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        buffer[outIndex &+ 1] = Self.encodePaddingCharacter
                        outIndex &+= 2
                    }
                }
            }

            length = outIndex
        }
    }

    static func _encodeWithLineBreaks(
        input: UnsafeBufferPointer<UInt8>,
        buffer: UnsafeMutableBufferPointer<UInt8>,
        length: inout Int,
        options: Data.Base64EncodingOptions
    ) {
        let omitPaddingCharacter = false

        assert(options.contains(.lineLength64Characters) || options.contains(.lineLength76Characters))

        let lineLength = if options.contains(.lineLength64Characters) {
            48
        } else {
            57
        }

        let lines = input.count / lineLength

        let separatorByte1: UInt8
        let separatorByte2: UInt8?

        switch (options.contains(.endLineWithCarriageReturn), options.contains(.endLineWithLineFeed)) {
        case (true, true), (false, false):
            separatorByte1 = UInt8(ascii: "\r")
            separatorByte2 = UInt8(ascii: "\n")
        case (true, false):
            separatorByte1 = UInt8(ascii: "\r")
            separatorByte2 = nil
        case (false, true):
            separatorByte1 = UInt8(ascii: "\n")
            separatorByte2 = nil
        }

        Self.withUnsafeEncodingTablesAsBufferPointers(options: options) { e0, e1 in
            var outIndex = 0
            for lineInputIndex in stride(from: 0, to: lines * lineLength, by: lineLength) {
                for index in stride(from: lineInputIndex, to: lineInputIndex + lineLength, by: 3) {
                    let i1 = input[index]
                    let i2 = input[index + 1]
                    let i3 = input[index + 2]
                    buffer[outIndex] = e0[Int(i1)]
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
                    buffer[outIndex + 3] = e1[Int(i3)]
                    outIndex += 4
                }

                buffer[outIndex] = separatorByte1
                outIndex += 1
                if let separatorByte2 {
                    buffer[outIndex] = separatorByte2
                    outIndex += 1
                }
            }

            let to = input.count / 3 * 3
            for index in stride(from: lines * lineLength, to: to, by: 3) {
                    let i1 = input[index]
                    let i2 = input[index + 1]
                    let i3 = input[index + 2]
                    buffer[outIndex] = e0[Int(i1)]
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
                    buffer[outIndex + 3] = e1[Int(i3)]
                    outIndex += 4
            }

            if to < input.count {
                let index = to

                let i1 = input[index]
                let i2 = index + 1 < input.count ? input[index + 1] : nil
                let i3 = index + 2 < input.count ? input[index + 2] : nil

                buffer[outIndex] = e0[Int(i1)]

                if let i2 = i2, let i3 = i3 {
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
                    buffer[outIndex + 3] = e1[Int(i3)]
                    outIndex += 4
                } else if let i2 = i2 {
                    buffer[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
                    buffer[outIndex + 2] = e1[Int((i2 & 0x0F) << 2)]
                    outIndex += 3
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        outIndex += 1
                    }
                } else {
                    buffer[outIndex + 1] = e1[Int((i1 & 0x03) << 4)]
                    outIndex += 2
                    if !omitPaddingCharacter {
                        buffer[outIndex] = Self.encodePaddingCharacter
                        buffer[outIndex + 1] = Self.encodePaddingCharacter
                        outIndex += 2
                    }
                }
            }

            length = outIndex
        }
    }

    static func encodeComputeCapacity(bytes: Int, options: Data.Base64EncodingOptions) -> Int {
        let capacityWithoutBreaks = ((bytes + 2) / 3) * 4

        guard options.contains(.lineLength64Characters) || options.contains(.lineLength76Characters) else {
            return capacityWithoutBreaks
        }

        let seperatorBytes = switch (options.contains(.endLineWithCarriageReturn), options.contains(.endLineWithLineFeed)) {
        case (true, true), (false, false): 2
        case (true, false), (false, true): 1
        }

        let lineLength = options.contains(.lineLength64Characters) ? 64 : 76
        let lineBreaks = capacityWithoutBreaks / lineLength
        let lineBreakCapacity = lineBreaks * seperatorBytes
        return capacityWithoutBreaks + lineBreakCapacity
    }

    static func withUnsafeEncodingTablesAsBufferPointers<R>(options: Data.Base64EncodingOptions, _ body: (UnsafeBufferPointer<UInt8>, UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R {
        let encoding0 = Self.encoding0
        let encoding1 = Self.encoding1

        assert(encoding0.count == 256)
        assert(encoding1.count == 256)

        return try encoding0.withUnsafeBufferPointer { e0 -> R in
            try encoding1.withUnsafeBufferPointer { e1 -> R in
                try body(e0, e1)
            }
        }
    }
}
