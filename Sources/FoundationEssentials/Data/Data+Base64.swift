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
    public init?(
        base64Encoded base64String: consuming String,
        options: Base64DecodingOptions = []
    ) {
        do {
            self = try base64String.withUTF8 {
                // String won't pass an empty buffer with a `nil` `baseAddress`.
                try Data(
                    decodingBase64: BufferView(unsafeBufferPointer: $0)!,
                    options: options
                )
            }
        }
        catch {
            precondition(error is Base64Error)
            return nil
        }
    }


    /// Initialize a `Data` from a Base-64, UTF-8 encoded `Data`.
    ///
    /// Returns nil when the input is not recognized as valid Base-64.
    ///
    /// - parameter base64Data: Base-64, UTF-8 encoded input data.
    /// - parameter options: Decoding options. Default value is `[]`.
    public init?(
        base64Encoded base64Data: borrowing Data,
        options: Base64DecodingOptions = []
    ) {
        do {
            self = try base64Data.withBufferView {
                try Data(decodingBase64: $0, options: options)
            }
        }
        catch {
            precondition(error is Base64Error)
            return nil
        }
    }

    private init(decodingBase64 bytes: borrowing BufferView<UInt8>, options: Base64DecodingOptions = []) throws {
        if !bytes.count.isMultiple(of: 4) &&
           !options.contains(.ignoreUnknownCharacters) {
            throw Base64Error.invalidElementCount
        }

        // Every 4 valid ASCII bytes maps to 3 output bytes: (bytes.count * 3)/4
        let capacity = (bytes.count * 3) >> 2
        // A non-trapping version of the calculation goes like this:
        // let (q, r) = bytes.count.quotientAndRemainder(dividingBy: 4)
        // let capacity = (q * 3) + (r==0 ? 0 : r-1)
        self = try Data(
            capacity: capacity,
            initializingWith: { //FIXME: should work with borrowed `bytes`
                [bytes = copy bytes] in
                try Data.base64DecodeBytes(bytes, &$0, options: options)
            }
        )
    }

    // MARK: - Create base64

    /// Returns a Base-64 encoded string.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded string.
    public func base64EncodedString(options: Base64EncodingOptions = []) -> String {
        if self.isEmpty { return "" }

        return self.withBufferView { inputBuffer in
            let capacity = Self.estimateBase64Size(length: self.count)
            return String(utf8Capacity: capacity) {
                Self.base64EncodeBytes(inputBuffer, &$0, options: options)
            }
        }
    }

    /// Returns a Base-64 encoded `Data`.
    ///
    /// - parameter options: The options to use for the encoding. Default value is `[]`.
    /// - returns: The Base-64 encoded data.
    public func base64EncodedData(options: Base64EncodingOptions = []) -> Data {
        let dataLength = self.count
        if dataLength == 0 { return Data() }

        return self.withBufferView { inputBuffer in
            let capacity = Self.estimateBase64Size(length: dataLength)
            return Data(capacity: capacity) {
                Self.base64EncodeBytes(inputBuffer, &$0, options: options)
            }
        }
    }

    // MARK: - Internal Helpers

    static func estimateBase64Size(length: Int) -> Int {
        // Worst case allow for 64bytes + \r\n per line  48 input bytes => 66 output bytes
        return ((length + 47) * 66) / 48
    }

    /**
     Padding character used when the number of bytes to encode is not divisible by 3
     */
    static let base64Padding : UInt8 = 61 // =

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
        _ bytes: borrowing BufferView<UInt8>,
        _ output: inout OutputBuffer<UInt8>,
        options: Base64DecodingOptions = []
    ) throws {

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

    /**
     This method encodes data in Base64.

     - parameter dataBuffer: A BufferView of the bytes to encode
     - parameter options:    Options for formatting the result
     - parameter buffer:     The buffer to write the bytes into
     */
    static func base64EncodeBytes(_ dataBuffer: BufferView<UInt8>, _ buffer: inout OutputBuffer<UInt8>, options: Base64EncodingOptions = []) {
        // Use a StaticString for lookup of values 0-63 -> ASCII values
        let base64Chars = StaticString("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        assert(base64Chars.utf8CodeUnitCount == 64)
        assert(base64Chars.hasPointerRepresentation)
        assert(base64Chars.isASCII)
        let base64CharsPtr = base64Chars.utf8Start

        let lineLength: Int
        var currentLineCount = 0
        let separatorByte1: UInt8
        var separatorByte2: UInt8?

        if options.isEmpty {
            lineLength = 0
            separatorByte1 = 0
        } else {
            if options.contains(.lineLength64Characters) {
                lineLength = 64
            } else if options.contains(.lineLength76Characters) {
                lineLength = 76
            } else {
                lineLength = 0
            }

            switch (options.contains(.endLineWithCarriageReturn), options.contains(.endLineWithLineFeed)) {
            case (true, true), (false, false):
                separatorByte1 = UInt8(ascii: "\r")
                separatorByte2 = UInt8(ascii: "\n")
            case (true, false):
                separatorByte1 = UInt8(ascii: "\r")
            case (false, true):
                separatorByte1 = UInt8(ascii: "\n")
            }
        }

        func lookupBase64Value(_ value: UInt16) -> UInt32 {
            let byte = base64CharsPtr[Int(value & 63)]
            return UInt32(byte)
        }

        // Read three bytes at a time, which convert to 4 ASCII characters, allowing for byte2 and byte3 being nil

        var inputIndex = 0
        var bytesLeft = dataBuffer.count

        while bytesLeft > 0 {

            let byte1 = dataBuffer[offset: inputIndex]

            // outputBytes is a UInt32 to allow 4 bytes to be written out at once.
            var outputBytes = lookupBase64Value(UInt16(byte1 >> 2))

            if bytesLeft > 2 {
                // This is the main loop converting 3 bytes at a time.
                let byte2 = dataBuffer[offset: inputIndex + 1]
                let byte3 = dataBuffer[offset: inputIndex + 2]
                var value = UInt16(byte1 & 0x3) << 8
                value |= UInt16(byte2)

                let outputByte2 = lookupBase64Value(value >> 4)
                outputBytes |= (outputByte2 << 8)
                value = (value << 8) | UInt16(byte3)

                let outputByte3 = lookupBase64Value(value >> 6)
                outputBytes |= (outputByte3 << 16)

                let outputByte4 = lookupBase64Value(value)
                outputBytes |= (outputByte4 << 24)
                inputIndex += 3
            } else {
                // This runs once at the end of there were 1 or 2 bytes left, byte1 having already been read.
                // Read byte2 or 0 if there isnt another byte
                let byte2 = bytesLeft == 1 ? 0 : dataBuffer[offset: inputIndex + 1]
                var value = UInt16(byte1 & 0x3) << 8
                value |= UInt16(byte2)

                let outputByte2 = lookupBase64Value(value >> 4)
                outputBytes |= (outputByte2 << 8)

                let outputByte3 = bytesLeft == 1 ? UInt32(self.base64Padding) : lookupBase64Value(value << 2)
                outputBytes |= (outputByte3 << 16)
                outputBytes |= (UInt32(self.base64Padding) << 24)
                inputIndex += bytesLeft
                assert(inputIndex == dataBuffer.count)
            }

            // The lowest byte of outputBytes needs to be stored at the lowest address, so make sure
            // the bytes are in the correct order on big endian CPUs.
            buffer.appendBytes(of: outputBytes.littleEndian, as: UInt32.self)
            bytesLeft = dataBuffer.count - inputIndex

            if lineLength != 0 {
                // Add required EOL markers.
                currentLineCount += 4
                assert(currentLineCount <= lineLength)

                if currentLineCount == lineLength && bytesLeft > 0 {
                    buffer.appendElement(separatorByte1)

                    if let separatorByte2 {
                        buffer.appendElement(separatorByte2)
                    }
                    currentLineCount = 0
                }
            }
        }
    }
}

