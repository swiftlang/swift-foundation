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

#if canImport(Darwin)
import Darwin
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import CRT
import WinSDK
#elseif os(WASI)
import WASILibc
#endif

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
        guard let result = try? Base64.decode(string: base64String, options: options) else {
            return nil
        }
        self = result
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
        guard let result = try? Base64.decode(data: base64Data, options: options) else {
            return nil
        }
        self = result
#endif
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

    static func _encode(input: UnsafeBufferPointer<UInt8>, buffer: UnsafeMutableBufferPointer<UInt8>, length: inout Int, options: Data.Base64EncodingOptions) {
        if options.contains(.lineLength64Characters) || options.contains(.lineLength76Characters) {
            return self._encodeWithLineBreaks(input: input, buffer: buffer, length: &length, options: options)
        }

        let omitPaddingCharacter = false

        Self.withUnsafeEncodingTablesAsBufferPointers(options: options) { (e0, e1) throws(Never) -> Void in
            let to = input.count / 3 * 3
            var outIndex = 0

            self.loopEncode(e0, e1, input: input, from: 0, to: to, output: buffer, outIndex: &outIndex)

            if to < input.count {
                let index = to

                let i1 = input[index]
                let i2 = index &+ 1 < input.count ? input[index &+ 1] : nil
                let i3 = index &+ 2 < input.count ? input[index &+ 2] : nil

                buffer[outIndex] = e0[Int(i1)]

                if let i2 = i2 {
                    buffer[outIndex &+ 1] = e1[Int(((i1 & 0x03) &<< 4) | ((i2 &>> 4) & 0x0F))]
                    if let i3 = i3 {
                        buffer[outIndex &+ 2] = e1[Int(((i2 & 0x0F) &<< 2) | ((i3 &>> 6) & 0x03))]
                        buffer[outIndex &+ 3] = e1[Int(i3)]
                        outIndex += 4
                    } else {
                        buffer[outIndex &+ 2] = e1[Int((i2 & 0x0F) &<< 2)]
                        outIndex += 3
                        if !omitPaddingCharacter {
                            buffer[outIndex] = Self.encodePaddingCharacter
                            outIndex &+= 1
                        }
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

            // first full line
            if input.count >= lineLength {
                self.loopEncode(e0, e1, input: input, from: 0, to: lineLength, output: buffer, outIndex: &outIndex)
            }

            // following full lines
            for lineInputIndex in stride(from: lineLength, to: lines * lineLength, by: lineLength) {
                buffer[outIndex] = separatorByte1
                outIndex += 1
                if let separatorByte2 {
                    buffer[outIndex] = separatorByte2
                    outIndex += 1
                }

                self.loopEncode(e0, e1, input: input, from: lineInputIndex, to: lineInputIndex + lineLength, output: buffer, outIndex: &outIndex)
            }

            // last line beginning
            if lines > 0 && lines * lineLength < input.count {
                buffer[outIndex] = separatorByte1
                outIndex += 1
                if let separatorByte2 {
                    buffer[outIndex] = separatorByte2
                    outIndex += 1
                }
            }
            let to = input.count / 3 * 3
            self.loopEncode(e0, e1, input: input, from: lines * lineLength, to: to, output: buffer, outIndex: &outIndex)

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

    private static func loopEncode(
        _ e0: UnsafeBufferPointer<UInt8>,
        _ e1: UnsafeBufferPointer<UInt8>,
        input: UnsafeBufferPointer<UInt8>,
        from: Int,
        to: Int,
        output: UnsafeMutableBufferPointer<UInt8>,
        outIndex: inout Int
    ) {
        for index in stride(from: from, to: to, by: 3) {
            let i1 = input[index]
            let i2 = input[index + 1]
            let i3 = input[index + 2]
            output[outIndex] = e0[Int(i1)]
            output[outIndex + 1] = e1[Int(((i1 & 0x03) << 4) | ((i2 >> 4) & 0x0F))]
            output[outIndex + 2] = e1[Int(((i2 & 0x0F) << 2) | ((i3 >> 6) & 0x03))]
            output[outIndex + 3] = e1[Int(i3)]
            outIndex += 4
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

    static func withUnsafeEncodingTablesAsBufferPointers<R>(options: Data.Base64EncodingOptions, _ body: (UnsafeBufferPointer<UInt8>, UnsafeBufferPointer<UInt8>) -> R) -> R {
        let encoding0 = Self.encoding0
        let encoding1 = Self.encoding1

        assert(encoding0.count == 256)
        assert(encoding1.count == 256)

        return encoding0.withUnsafeBufferPointer { e0 in
            encoding1.withUnsafeBufferPointer { e1 in
                body(e0, e1)
            }
        }
    }
}

// MARK: - Decoding -

extension Base64 {

    enum DecodingError: Error, Equatable {
        case invalidLength
        case invalidCharacter(UInt8)
        case unexpectedPaddingCharacter
        case unexpectedEnd
    }

    static func decode(string encoded: String, options: Data.Base64DecodingOptions = []) throws(DecodingError) -> Data {
        let result = encoded.utf8.withContiguousStorageIfAvailable { bufferPointer in
            // `withContiguousStorageIfAvailable` sadly does not support typed throws, so we need
            // to use Result to get the error out without allocation for the error.
            Result(catching: { () throws(DecodingError) -> Data in
                try Self._decodeToData(from: bufferPointer, options: options)
            })
        }

        if let result {
            return try result.get()
        }

        var encoded = encoded
        encoded.makeContiguousUTF8()
        return try Self.decode(string: encoded, options: options)
    }

    static func decode(data encoded: Data, options: Data.Base64DecodingOptions = []) throws(DecodingError) -> Data? {
        let result = encoded.withContiguousStorageIfAvailable { bufferPointer in
            // `withContiguousStorageIfAvailable` sadly does not support typed throws, so we need
            // to use Result to get the error out without allocation for the error.
            Result(catching: { () throws(DecodingError) -> Data in
                try Self._decodeToData(from: bufferPointer, options: options)
            })
        }

        if let result {
            return try result.get()
        }

        return try Self.decode(bytes: Array(encoded), options: options)
    }

    static func decode<Buffer: Collection>(bytes: Buffer, options: Data.Base64DecodingOptions = []) throws(DecodingError) -> Data where Buffer.Element == UInt8 {
        guard bytes.count > 0 else {
            return Data()
        }

        let result = bytes.withContiguousStorageIfAvailable { bufferPointer in
            // `withContiguousStorageIfAvailable` sadly does not support typed throws, so we need
            // to use Result to get the error out without allocation for the error.
            Result(catching: { () throws(DecodingError) -> Data in
                try Self._decodeToData(from: bufferPointer, options: options)
            })
        }

        if let result {
            return try result.get()
        }

        return try self.decode(bytes: Array(bytes), options: options)
    }

    static func _decodeToData(from inBuffer: UnsafeBufferPointer<UInt8>, options: Data.Base64DecodingOptions) throws(DecodingError) -> Data {
        guard inBuffer.count > 0 else {
            return Data()
        }

        let outputLength = ((inBuffer.count + 3) / 4) * 3

        let pointer = malloc(outputLength)
        let other = pointer?.bindMemory(to: UInt8.self, capacity: outputLength)
        let target = UnsafeMutableBufferPointer(start: other, count: outputLength)
        var length = outputLength
        if options.contains(.ignoreUnknownCharacters) {
            try Self._decodeIgnoringErrors(from: inBuffer, into: target, length: &length, options: options)
        } else {
            // for whatever reason I can see this being 10% faster for larger payloads. Maybe better
            // branch prediction?
            try self._decode(from: inBuffer, into: target, length: &length, options: options)
        }

        return Data(bytesNoCopy: pointer!, count: length, deallocator: .free)
    }

    static func _decode(
        from inBuffer: UnsafeBufferPointer<UInt8>,
        into outBuffer: UnsafeMutableBufferPointer<UInt8>,
        length: inout Int,
        options: Data.Base64DecodingOptions
    ) throws(DecodingError) {
        guard let lastNonPaddedIndex = inBuffer.lastIndex(where: { $0 != UInt8(ascii: "=") }) else {
            if inBuffer.count >= 4 {
                outBuffer[0] = 0
                length = 1
                return
            } else {
                throw DecodingError.invalidLength
            }
        }
        let base64NonPaddedLength = lastNonPaddedIndex + 1
        let bytesToParseLength = if base64NonPaddedLength % 4 == 0 {
            (base64NonPaddedLength / 4) * 4
        } else {
            (base64NonPaddedLength / 4) * 4 + 4
        }
        if bytesToParseLength > inBuffer.count {
            throw DecodingError.invalidLength
        }

        let outputLength = ((bytesToParseLength + 3) / 4) * 3
        let fullchunks = bytesToParseLength / 4 - 1

        guard outBuffer.count >= outputLength else {
            preconditionFailure("Expected the out buffer to be at least as long as outputLength")
        }

        try Self.withUnsafeDecodingTablesAsBufferPointers(options: options) { (d0, d1, d2, d3) throws(DecodingError) in
            var outIndex = 0
            if fullchunks > 0 {
                for chunk in 0 ..< fullchunks {
                    let inIndex = chunk * 4
                    let a0 = inBuffer[inIndex]
                    let a1 = inBuffer[inIndex + 1]
                    let a2 = inBuffer[inIndex + 2]
                    let a3 = inBuffer[inIndex + 3]
                    var x: UInt32 = d0[Int(a0)] | d1[Int(a1)] | d2[Int(a2)] | d3[Int(a3)]

                    if x >= Self.badCharacter {
                        // TODO: Inspect characters here better
                        throw DecodingError.invalidCharacter(inBuffer[inIndex])
                    }

                    withUnsafePointer(to: &x) { ptr in
                        ptr.withMemoryRebound(to: UInt8.self, capacity: 4) { newPtr in
                            outBuffer[outIndex] = newPtr[0]
                            outBuffer[outIndex + 1] = newPtr[1]
                            outBuffer[outIndex + 2] = newPtr[2]
                            outIndex += 3
                        }
                    }
                }
            }

            // inIndex is the first index in the last chunk
            let inIndex = fullchunks * 4
            let a0 = inBuffer[inIndex]
            let a1 = inBuffer[inIndex + 1]
            var a2: UInt8?
            var a3: UInt8?
            if inIndex + 2 < inBuffer.count, inBuffer[inIndex + 2] != Self.encodePaddingCharacter {
                a2 = inBuffer[inIndex + 2]
            }
            if inIndex + 3 < inBuffer.count, inBuffer[inIndex + 3] != Self.encodePaddingCharacter {
                a3 = inBuffer[inIndex + 3]
            }

            var x: UInt32 = d0[Int(a0)] | d1[Int(a1)] | d2[Int(a2 ?? 65)] | d3[Int(a3 ?? 65)]
            if x >= Self.badCharacter {
                // TODO: Inspect characters here better
                throw DecodingError.invalidCharacter(inBuffer[inIndex])
            }

            withUnsafePointer(to: &x) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: 4) { newPtr in
                    outBuffer[outIndex] = newPtr[0]
                    outIndex += 1
                    if a2 != nil {
                        outBuffer[outIndex] = newPtr[1]
                        outIndex += 1
                    }
                    if a3 != nil {
                        outBuffer[outIndex] = newPtr[2]
                        outIndex += 1
                    }
                }
            }

            length = outIndex
        }
    }

    static func _decodeIgnoringErrors(
        from inBuffer: UnsafeBufferPointer<UInt8>,
        into outBuffer: UnsafeMutableBufferPointer<UInt8>,
        length: inout Int,
        options: Data.Base64DecodingOptions
    ) throws(DecodingError) {
        assert(options.contains(.ignoreUnknownCharacters))

        let outputLength = ((inBuffer.count + 3) / 4) * 3
        guard outBuffer.count >= outputLength else {
            preconditionFailure("Expected the out buffer to be at least as long as outputLength")
        }

        try Self.withUnsafeDecodingTablesAsBufferPointers(options: options) { (d0, d1, d2, d3) throws(DecodingError) in
            var outIndex = 0
            var inIndex = 0

            fastLoop: while inIndex + 3 < inBuffer.count {
                let a0 = inBuffer[inIndex]
                let a1 = inBuffer[inIndex &+ 1]
                let a2 = inBuffer[inIndex &+ 2]
                let a3 = inBuffer[inIndex &+ 3]
                var x: UInt32 = d0[Int(a0)] | d1[Int(a1)] | d2[Int(a2)] | d3[Int(a3)]

                if x >= Self.badCharacter {
                    if a3 == Self.encodePaddingCharacter {
                        break // the loop
                    }

                    // error fast path. we assume that illeagal errors are at the boundary.
                    // lets skip them and then return to fast mode!
                    if !self.isValidBase64Byte(a0, options: options) {
                        if !self.isValidBase64Byte(a1, options: options) {
                            if !self.isValidBase64Byte(a2, options: options) {
                                if !self.isValidBase64Byte(a3, options: options) {
                                    inIndex &+= 4
                                    continue
                                } else {
                                    inIndex &+= 3
                                    continue
                                }
                            } else {
                                inIndex &+= 2
                                continue
                            }
                        } else {
                            inIndex &+= 1
                            continue
                        }
                    }

                    // error slow path... the first character is valid base64
                    let b0 = a0
                    var b1: UInt8? = nil
                    var b2: UInt8? = nil
                    var b3: UInt8? = nil
                    let startIndex = inIndex
                    inIndex &+= 1
                    scanForValidCharacters: while inIndex < inBuffer.count {
                        guard self.isValidBase64Byte(inBuffer[inIndex], options: options) else {
                            if inBuffer[inIndex] == Self.encodePaddingCharacter {
                                inIndex = startIndex
                                break fastLoop
                            }
                            inIndex &+= 1
                            continue scanForValidCharacters
                        }

                        defer { inIndex &+= 1 }

                        if b1 == nil {
                            b1 = inBuffer[inIndex]
                        } else if b2 == nil {
                            b2 = inBuffer[inIndex]
                        } else if b3 == nil {
                            b3 = inBuffer[inIndex]
                            break scanForValidCharacters
                        }
                    }

                    guard let b1, let b2, let b3 else {
                        throw DecodingError.invalidLength
                    }

                    x = d0[Int(b0)] | d1[Int(b1)] | d2[Int(b2)] | d3[Int(b3)]

                } else {
                    inIndex &+= 4
                }

                withUnsafePointer(to: &x) { ptr in
                    ptr.withMemoryRebound(to: UInt8.self, capacity: 4) { newPtr in
                        outBuffer[outIndex] = newPtr[0]
                        outBuffer[outIndex &+ 1] = newPtr[1]
                        outBuffer[outIndex &+ 2] = newPtr[2]
                        outIndex &+= 3
                    }
                }
            }

            if inIndex == inBuffer.count {
                // all done!
                length = outIndex
                return
            }

            guard inIndex + 3 < inBuffer.count else {
                if options.contains(.ignoreUnknownCharacters) {
                    // ensure that all remaining characters are unknown
                    while inIndex < inBuffer.count {
                        let value = inBuffer[inIndex]
                        if self.isValidBase64Byte(value, options: options) || value == Self.encodePaddingCharacter {
                            throw DecodingError.invalidCharacter(inBuffer[inIndex])
                        }
                        inIndex &+= 1
                    }
                    length = outIndex
                    return
                }
                throw DecodingError.invalidLength
            }

            let a0 = inBuffer[inIndex]
            let a1 = inBuffer[inIndex + 1]
            var a2: UInt8 = 65
            var a3: UInt8 = 65
            var padding2 = false
            var padding3 = false

            if inBuffer[inIndex + 2] == Self.encodePaddingCharacter {
                padding2 = true
            } else {
                a2 = inBuffer[inIndex + 2]
            }
            if inBuffer[inIndex + 3] == Self.encodePaddingCharacter {
                padding3 = true
            } else {
                if padding2 && self.isValidBase64Byte(inBuffer[inIndex + 3], options: options) {
                    throw DecodingError.unexpectedPaddingCharacter
                }
                a3 = inBuffer[inIndex + 3]
            }

            var x: UInt32 = d0[Int(a0)] | d1[Int(a1)] | d2[Int(a2)] | d3[Int(a3)]
            if x >= Self.badCharacter {
                var b0: UInt8? = nil
                var b1: UInt8? = nil
                var b2: UInt8? = nil
                var b3: UInt8? = nil

                scanForValidCharacters: while inIndex < inBuffer.count {
                    defer { inIndex &+= 1 }
                    let value = inBuffer[inIndex]
                    if self.isValidBase64Byte(value, options: options) {
                        if b0 == nil {
                            b0 = value
                        } else if b1 == nil {
                            b1 = value
                        } else if b2 == nil {
                            b2 = value
                        } else if b3 == nil {
                            if padding2 { throw DecodingError.unexpectedPaddingCharacter }
                            b3 = value
                            break scanForValidCharacters
                        }
                    } else if value == Self.encodePaddingCharacter {
                        guard b0 != nil, b1 != nil else {
                            throw DecodingError.invalidLength
                        }
                        if b2 == nil {
                            padding2 = true
                            b2 = 65
                        } else if b3 == nil {
                            padding3 = true
                            b3 = 65
                            break scanForValidCharacters
                        }
                    }
                }

                guard let b0, let b1, let b2, let b3 else {
                    if b0 == nil {
                        length = outIndex
                        return
                    }
                    throw DecodingError.invalidLength
                }

                x = d0[Int(b0)] | d1[Int(b1)] | d2[Int(b2)] | d3[Int(b3)]
                assert(x < Self.badCharacter)
            }

            withUnsafePointer(to: &x) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: 4) { newPtr in
                    outBuffer[outIndex] = newPtr[0]
                    outIndex += 1
                    if !padding2 {
                        outBuffer[outIndex] = newPtr[1]
                        outIndex += 1
                    }
                    if !padding3 {
                        outBuffer[outIndex] = newPtr[2]
                        outIndex += 1
                    }
                }
            }

            length = outIndex
        }
    }

    static func withUnsafeDecodingTablesAsBufferPointers<R, E: Swift.Error>(options: Data.Base64DecodingOptions, _ body: (UnsafeBufferPointer<UInt32>, UnsafeBufferPointer<UInt32>, UnsafeBufferPointer<UInt32>, UnsafeBufferPointer<UInt32>) throws(E) -> R) throws(E) -> R {
        let decoding0 = Self.decoding0
        let decoding1 = Self.decoding1
        let decoding2 = Self.decoding2
        let decoding3 = Self.decoding3

        assert(decoding0.count == 256)
        assert(decoding1.count == 256)
        assert(decoding2.count == 256)
        assert(decoding3.count == 256)

        // Workaround that `withUnsafeBufferPointer` started to support typed throws in Swift 6.1
        let result = decoding0.withUnsafeBufferPointer { d0 -> Result<R, E> in
            decoding1.withUnsafeBufferPointer { d1 -> Result<R, E> in
                decoding2.withUnsafeBufferPointer { d2 -> Result<R, E> in
                    decoding3.withUnsafeBufferPointer { d3 -> Result<R, E> in
                        Result { () throws(E) -> R in
                            try body(d0, d1, d2, d3)
                        }
                    }
                }
            }
        }

        return try result.get()
    }

    static func isValidBase64Byte(_ byte: UInt8, options: Data.Base64DecodingOptions) -> Bool {
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "a")...UInt8(ascii: "z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"):
            true

        case UInt8(ascii: "-"), UInt8(ascii: "_"):
            false // options.contains(.base64UrlAlphabet)

        case UInt8(ascii: "/"), UInt8(ascii: "+"):
            true // !options.contains(.base64UrlAlphabet)

        default:
            false
        }
    }

    static let badCharacter: UInt32 = 0x01FF_FFFF

    static let decoding0: [UInt32] = [
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0000_00F8, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_00FC,
        0x0000_00D0, 0x0000_00D4, 0x0000_00D8, 0x0000_00DC, 0x0000_00E0, 0x0000_00E4,
        0x0000_00E8, 0x0000_00EC, 0x0000_00F0, 0x0000_00F4, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_0000,
        0x0000_0004, 0x0000_0008, 0x0000_000C, 0x0000_0010, 0x0000_0014, 0x0000_0018,
        0x0000_001C, 0x0000_0020, 0x0000_0024, 0x0000_0028, 0x0000_002C, 0x0000_0030,
        0x0000_0034, 0x0000_0038, 0x0000_003C, 0x0000_0040, 0x0000_0044, 0x0000_0048,
        0x0000_004C, 0x0000_0050, 0x0000_0054, 0x0000_0058, 0x0000_005C, 0x0000_0060,
        0x0000_0064, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0000_0068, 0x0000_006C, 0x0000_0070, 0x0000_0074, 0x0000_0078,
        0x0000_007C, 0x0000_0080, 0x0000_0084, 0x0000_0088, 0x0000_008C, 0x0000_0090,
        0x0000_0094, 0x0000_0098, 0x0000_009C, 0x0000_00A0, 0x0000_00A4, 0x0000_00A8,
        0x0000_00AC, 0x0000_00B0, 0x0000_00B4, 0x0000_00B8, 0x0000_00BC, 0x0000_00C0,
        0x0000_00C4, 0x0000_00C8, 0x0000_00CC, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
    ]

    static let decoding1: [UInt32] = [
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0000_E003, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_F003,
        0x0000_4003, 0x0000_5003, 0x0000_6003, 0x0000_7003, 0x0000_8003, 0x0000_9003,
        0x0000_A003, 0x0000_B003, 0x0000_C003, 0x0000_D003, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_0000,
        0x0000_1000, 0x0000_2000, 0x0000_3000, 0x0000_4000, 0x0000_5000, 0x0000_6000,
        0x0000_7000, 0x0000_8000, 0x0000_9000, 0x0000_A000, 0x0000_B000, 0x0000_C000,
        0x0000_D000, 0x0000_E000, 0x0000_F000, 0x0000_0001, 0x0000_1001, 0x0000_2001,
        0x0000_3001, 0x0000_4001, 0x0000_5001, 0x0000_6001, 0x0000_7001, 0x0000_8001,
        0x0000_9001, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0000_A001, 0x0000_B001, 0x0000_C001, 0x0000_D001, 0x0000_E001,
        0x0000_F001, 0x0000_0002, 0x0000_1002, 0x0000_2002, 0x0000_3002, 0x0000_4002,
        0x0000_5002, 0x0000_6002, 0x0000_7002, 0x0000_8002, 0x0000_9002, 0x0000_A002,
        0x0000_B002, 0x0000_C002, 0x0000_D002, 0x0000_E002, 0x0000_F002, 0x0000_0003,
        0x0000_1003, 0x0000_2003, 0x0000_3003, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
    ]

    static let decoding2: [UInt32] = [
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0080_0F00, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x00C0_0F00,
        0x0000_0D00, 0x0040_0D00, 0x0080_0D00, 0x00C0_0D00, 0x0000_0E00, 0x0040_0E00,
        0x0080_0E00, 0x00C0_0E00, 0x0000_0F00, 0x0040_0F00, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_0000,
        0x0040_0000, 0x0080_0000, 0x00C0_0000, 0x0000_0100, 0x0040_0100, 0x0080_0100,
        0x00C0_0100, 0x0000_0200, 0x0040_0200, 0x0080_0200, 0x00C0_0200, 0x0000_0300,
        0x0040_0300, 0x0080_0300, 0x00C0_0300, 0x0000_0400, 0x0040_0400, 0x0080_0400,
        0x00C0_0400, 0x0000_0500, 0x0040_0500, 0x0080_0500, 0x00C0_0500, 0x0000_0600,
        0x0040_0600, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x0080_0600, 0x00C0_0600, 0x0000_0700, 0x0040_0700, 0x0080_0700,
        0x00C0_0700, 0x0000_0800, 0x0040_0800, 0x0080_0800, 0x00C0_0800, 0x0000_0900,
        0x0040_0900, 0x0080_0900, 0x00C0_0900, 0x0000_0A00, 0x0040_0A00, 0x0080_0A00,
        0x00C0_0A00, 0x0000_0B00, 0x0040_0B00, 0x0080_0B00, 0x00C0_0B00, 0x0000_0C00,
        0x0040_0C00, 0x0080_0C00, 0x00C0_0C00, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
    ]

    static let decoding3: [UInt32] = [
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x003E_0000, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x003F_0000,
        0x0034_0000, 0x0035_0000, 0x0036_0000, 0x0037_0000, 0x0038_0000, 0x0039_0000,
        0x003A_0000, 0x003B_0000, 0x003C_0000, 0x003D_0000, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x0000_0000,
        0x0001_0000, 0x0002_0000, 0x0003_0000, 0x0004_0000, 0x0005_0000, 0x0006_0000,
        0x0007_0000, 0x0008_0000, 0x0009_0000, 0x000A_0000, 0x000B_0000, 0x000C_0000,
        0x000D_0000, 0x000E_0000, 0x000F_0000, 0x0010_0000, 0x0011_0000, 0x0012_0000,
        0x0013_0000, 0x0014_0000, 0x0015_0000, 0x0016_0000, 0x0017_0000, 0x0018_0000,
        0x0019_0000, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x001A_0000, 0x001B_0000, 0x001C_0000, 0x001D_0000, 0x001E_0000,
        0x001F_0000, 0x0020_0000, 0x0021_0000, 0x0022_0000, 0x0023_0000, 0x0024_0000,
        0x0025_0000, 0x0026_0000, 0x0027_0000, 0x0028_0000, 0x0029_0000, 0x002A_0000,
        0x002B_0000, 0x002C_0000, 0x002D_0000, 0x002E_0000, 0x002F_0000, 0x0030_0000,
        0x0031_0000, 0x0032_0000, 0x0033_0000, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
        0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF, 0x01FF_FFFF,
    ]
}
