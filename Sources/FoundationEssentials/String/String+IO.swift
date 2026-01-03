//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

internal import _FoundationCShims

fileprivate let stringEncodingAttributeName = "com.apple.TextEncoding"

#if !FOUNDATION_FRAMEWORK
@_spi(SwiftCorelibsFoundation)
dynamic public func _cfMakeStringFromBytes(_ bytes: UnsafeBufferPointer<UInt8>, encoding: UInt) -> String? {
    // Provide swift-corelibs-foundation with an entry point to convert some bytes into a String
    return nil
}

dynamic package func _icuMakeStringFromBytes(_ bytes: UnsafeBufferPointer<UInt8>, encoding: String.Encoding) -> String? {
    // Concrete implementation is provided by FoundationInternationalization.
    return nil
}
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
    /// Returns a `String` initialized by converting given `data` into
    /// Unicode characters using a given `encoding`.
    public init?(data: __shared Data, encoding: Encoding) {
        guard let s = String(bytes: data, encoding: encoding) else {
            return nil
        }
        self = s
    }
    
    /// Creates a new string equivalent to the given bytes interpreted in the specified encoding.
    /// Note: This API does not interpret embedded nulls as termination of the string. Use `String?(validatingCString:)` instead for null-terminated C strings.
    /// - Parameters:
    ///   - bytes: A sequence of bytes to interpret using `encoding`.
    ///   - encoding: The encoding to use to interpret `bytes`.
    public init?<S: Sequence>(bytes: __shared S, encoding: Encoding)
        where S.Iterator.Element == UInt8
    {
        switch encoding {
        case .ascii, .nonLossyASCII:
            func makeString(buffer: UnsafeBufferPointer<UInt8>) -> String? {
                return String(_validating: buffer, as: Unicode.ASCII.self)
            }

            if let string = bytes.withContiguousStorageIfAvailable(makeString) ?? Array(bytes).withUnsafeBufferPointer(makeString) {
                self = string
            } else {
#if FOUNDATION_FRAMEWORK
                // Compatibility path: for callers that expect this API to perform null termination (it does not, it uses the full length of the sequence), NSString would happily return a value with embedded null values, even if it has garbage after the null byte. This sometimes worked, if the result was only inspected at the start, e.g. using prefix functions.
                if Self.compatibility1 {
                    let fromNSString : String? = Array(bytes).withUnsafeBufferPointer { bytes in
                        if let ns = NSString(bytes: bytes.baseAddress.unsafelyUnwrapped, length: bytes.count, encoding: encoding.rawValue) {
                            return String._unconditionallyBridgeFromObjectiveC(ns)
                        } else {
                            return nil
                        }
                    }
                    
                    if let fromNSString {
                        self = fromNSString
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
#else
                // String is not valid ASCII
                return nil
#endif

            }
        case .utf8:
            func makeString(buffer: UnsafeBufferPointer<UInt8>) -> String? {
                var buffer = buffer
                if buffer.starts(with: [0xEF, 0xBB, 0xBF]) {
                    buffer = UnsafeBufferPointer(rebasing: buffer.suffix(from: 3))
                }
                if let string = String._tryFromUTF8(buffer) {
                    return string
                }

                return String(_validating: buffer, as: UTF8.self)
            }

            if let string = bytes.withContiguousStorageIfAvailable(makeString) ?? Array(bytes).withUnsafeBufferPointer(makeString) {
                self = string
            } else {
                // String is not valid UTF8
#if FOUNDATION_FRAMEWORK && os(macOS)
                // Allow for invalid UTF8 to be repaired in compatibility cases
                if Self.compatibility2 {
                    self = String(decoding: Array(bytes), as: UTF8.self)
                } else {
                    return nil
                }

#else
                return nil
#endif
            }
        case .utf16BigEndian, .utf16LittleEndian, .utf16:
            // See also the package extension String?(_utf16:), which does something similar to this without the swapping of big/little.
            let e = Endianness(encoding)
            let maybe = bytes.withContiguousStorageIfAvailable { buffer -> String? in
                withUnsafeTemporaryAllocation(of: UTF8.CodeUnit.self, capacity: buffer.count * 3) { contents in
                    let s = UTF16EndianAdaptor(buffer, endianness: e)
                    var count = 0
                    let error = transcode(s.makeIterator(), from: UTF16.self, to: UTF8.self, stoppingOnError: true) { codeUnit in
                        contents[count] = codeUnit
                        count += 1
                    }
                    
                    guard !error else {
                        return nil
                    }
                    
                    // Unfortunately no way to skip the validation inside String at this time
                    return String._tryFromUTF8(UnsafeBufferPointer(rebasing: contents[..<count]))
                }
            }
            
            if let maybe, let maybe {
                self = maybe
            } else if let result = String(_validating: UTF16EndianAdaptor(bytes, endianness: e), as: UTF16.self) {
                self = result
            } else {
                return nil
            }
        case .utf32BigEndian, .utf32LittleEndian, .utf32:
            let e = Endianness(encoding)
            let maybe = bytes.withContiguousStorageIfAvailable { buffer -> String? in
                withUnsafeTemporaryAllocation(of: UTF8.CodeUnit.self, capacity: buffer.count * 3) { contents in
                    let s = UTF32EndianAdaptor(buffer, endianness: e)
                    var count = 0
                    let error = transcode(s.makeIterator(), from: UTF32.self, to: UTF8.self, stoppingOnError: true) { codeUnit in
                        contents[count] = codeUnit
                        count += 1
                    }
                    
                    guard !error else {
                        return nil
                    }
                    
                    // Unfortunately no way to skip the validation inside String at this time
                    return String._tryFromUTF8(UnsafeBufferPointer(rebasing: contents[..<count]))
                }
            }
            
            if let maybe, let maybe {
                self = maybe
            } else if let result = String(_validating: UTF32EndianAdaptor(bytes, endianness: e), as: UTF32.self) {
                self = result
            } else {
                return nil
            }
        #if !FOUNDATION_FRAMEWORK
        case .isoLatin1:
            // ISO Latin 1 bytes are always valid since it's an 8-bit encoding that maps scalars 0x0 through 0xFF
            // Simply extend each byte to 16 bits and decode as UTF-16
            self.init(decoding: bytes.lazy.map { UInt16($0) }, as: UTF16.self)
        case .macOSRoman:
            func buildString(_ bytes: UnsafeBufferPointer<UInt8>) -> String {
                String(unsafeUninitializedCapacity: bytes.count * 3) { buffer in
                    var next = 0
                    for byte in bytes {
                        if Unicode.ASCII.isASCII(byte) {
                            buffer.initializeElement(at: next, to: byte)
                            next += 1
                        } else {
                            next = buffer.suffix(from: next).initialize(fromContentsOf: byte.macRomanNonASCIIAsUTF8)
                        }
                    }
                    return next
                }
            }
            self = bytes.withContiguousStorageIfAvailable(buildString) ?? Array(bytes).withUnsafeBufferPointer(buildString)
        case .japaneseEUC:
            // Here we catch encodings that are supported by Foundation Framework
            // but are not supported by corelibs-foundation.
            // We delegate conversion to ICU.
            guard let string = (
                bytes.withContiguousStorageIfAvailable({ _icuMakeStringFromBytes($0, encoding: encoding) }) ??
                Array(bytes).withUnsafeBufferPointer({ _icuMakeStringFromBytes($0, encoding: encoding) })
            ) else {
                return nil
            }
            self = string
        #endif
        default:
#if FOUNDATION_FRAMEWORK
            // In the framework, we can fall back to NS/CFString to handle more esoteric encodings.
            func makeNSString(bytes: UnsafeBufferPointer<UInt8>) -> String? {
                if let ns = NSString(bytes: bytes.baseAddress.unsafelyUnwrapped, length: bytes.count, encoding: encoding.rawValue) {
                    return String._unconditionallyBridgeFromObjectiveC(ns)
                } else {
                    return nil
                }
            }
            if let string = (bytes.withContiguousStorageIfAvailable(makeNSString) ??
                             Array(bytes).withUnsafeBufferPointer(makeNSString)) {
                self = string
            } else {
                return nil
            }
#else
            if let string = (bytes.withContiguousStorageIfAvailable({ _cfMakeStringFromBytes($0, encoding: encoding.rawValue) }) ??
                             Array(bytes).withUnsafeBufferPointer({ _cfMakeStringFromBytes($0, encoding: encoding.rawValue) })) {
                self = string
            } else {
                return nil
            }
#endif
        }
    }


#if !NO_FILESYSTEM
    /// Produces a string created by reading data from the file at a given path interpreted using a given encoding.
    public init(contentsOfFile path: __shared String, encoding enc: Encoding) throws {
        let data = try Data(contentsOfFile: path)
        guard let str = String(data: data, encoding: enc) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self = str
    }
    
    /// Produces a string created by reading data from a given URL interpreted using a given encoding.
    public init(contentsOf url: __shared URL, encoding enc: Encoding) throws {
        let data = try Data(contentsOf: url)
        guard let str = String(data: data, encoding: enc) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self = str
    }

    /// Produces a string created by reading data from the file at a given path and returns by reference the encoding used to interpret the file.
    public init(contentsOfFile path: __shared String, usedEncoding: inout Encoding) throws {
        self = try String(contentsOfFileOrPath: .path(path), usedEncoding: &usedEncoding)
    }

    /// Produces a string created by reading data from a given URL and returns by reference the encoding used to interpret the data.
    public init(contentsOf url: __shared URL, usedEncoding: inout Encoding) throws {
        self = try String(contentsOfFileOrPath: .url(url), usedEncoding: &usedEncoding)
    }
    
    internal init(contentsOfFileOrPath path: PathOrURL, usedEncoding: inout Encoding) throws {
        var attrs: [String : Data] = [:]
        let data = try readDataFromFile(path: path, reportProgress: false, maxLength: nil, options: [], attributesToRead: [stringEncodingAttributeName], attributes: &attrs)
        if let encodingAttributeData = attrs[stringEncodingAttributeName], let extendedAttributeEncoding = encodingFromDataForExtendedAttribute(encodingAttributeData) {
            guard let str = String(data: data, encoding: extendedAttributeEncoding) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            usedEncoding = extendedAttributeEncoding
            self = str
        } else {
            guard let str = String(dataOfUnknownEncoding: data, usedEncoding: &usedEncoding) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            self = str
        }
    }
#endif
}

extension String {
    internal init?(dataOfUnknownEncoding data: Data, usedEncoding: inout Encoding) {
        let len = data.count
        let encoding: Encoding
        if len >= 4 && (
            (data[0] == 0xFF && data[1] == 0xFE && data[2] == 0x00 && data[3] == 0x00) ||
            (data[0] == 0x00 && data[1] == 0x00 && data[3] == 0xFE && data[4] == 0xFF)) {
            // Looks like UTF32
            encoding = .utf32
        } else if len >= 2 {
            if ((len & 1) == 0) && ((data[0] == 0xfe && data[1] == 0xff) || (data[0] == 0xff && data[1] == 0xfe)) {
                // Looks like Unicode
                encoding = .unicode
            } else {
                // Fallback
                encoding = .utf8
            }
        } else {
            // Fallback, short string
            encoding = .utf8
        }
        
        guard let str = String(data: data, encoding: encoding) else {
            return nil
        }
        
        usedEncoding = encoding
        self = str
    }
}

internal func encodingFromDataForExtendedAttribute(_ value: Data) -> String.Encoding? {
    guard let str = String(data: value, encoding: .utf8) else {
        return nil
    }
    
    // First look for the integer at the end
    var foundEncoding: String.Encoding?
    let colonIndex = str.firstIndex(of: ";")
    
    if let colonIndex {
        let next = str.index(after: colonIndex)
        if next < str.endIndex {
            let rest = str[next..<str.endIndex]
            if let enc = UInt(rest) {
#if FOUNDATION_FRAMEWORK
                if CFStringIsEncodingAvailable(CFStringEncoding(enc)) {
                    foundEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(enc)))
                }
#else
                foundEncoding = switch enc {
                case 0x0: .macOSRoman
                case 0x0201: .isoLatin1
                case 0x0600: .ascii
                case 0x08000100: .utf8
                case 0x0100: .utf16
                case 0x10000100: .utf16BigEndian
                case 0x14000100: .utf16LittleEndian
                case 0x0c000100: .utf32
                case 0x18000100: .utf32BigEndian
                case 0x1c000100: .utf32LittleEndian
                default: nil
                }
#endif
            }
        }
    }
    
    if foundEncoding != nil {
        return foundEncoding
    }
    
    // If the number didn't work out, look for the name
    let namePart : Substring
    if let colonIndex {
        namePart = str[str.startIndex..<colonIndex]
    } else {
        namePart = str[str.startIndex..<str.endIndex]
    }
    
    if !namePart.isEmpty {
#if FOUNDATION_FRAMEWORK
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(String(namePart) as CFString)
        if cfEncoding != kCFStringEncodingInvalidId {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
#else
        switch namePart {
        case "us-ascii": return .ascii
        case "utf-8": return .utf8
        case "utf-16": return .utf16
        case "utf-16be": return .utf16BigEndian
        case "utf-16le": return .utf16LittleEndian
        case "utf-32": return .utf32
        case "utf-32be": return .utf32BigEndian
        case "utf-32le": return .utf32LittleEndian
        case "iso-8859-1": return .isoLatin1
        case "macintosh": return .macOSRoman
        default: return nil // Unknown encoding value
        }
#endif
    }
    
    return nil
}

internal func extendedAttributeData(for encoding: String.Encoding) -> Data? {
#if FOUNDATION_FRAMEWORK
    let cfEncoding = CFStringConvertNSStringEncodingToEncoding(encoding.rawValue)
    guard cfEncoding != kCFStringEncodingInvalidId else {
        return nil
    }
    
    let encodingName = CFStringConvertEncodingToIANACharSetName(cfEncoding)
#else
    let cfEncoding : UInt? = switch encoding {
    case .macOSRoman: 0x0
    case .isoLatin1: 0x0201
    case .ascii: 0x0600
    case .utf8: 0x08000100
    case .utf16: 0x0100
    case .utf16BigEndian: 0x10000100
    case .utf16LittleEndian: 0x14000100
    case .utf32: 0x0c000100
    case .utf32BigEndian: 0x18000100
    case .utf32LittleEndian: 0x1c000100
    default: nil
    }
    
    guard let cfEncoding else {
        return nil
    }
    
    let encodingName : String? = switch encoding {
    case .ascii: "us-ascii"
    case .utf8: "utf-8"
    case .utf16: "utf-16"
    case .utf16BigEndian: "utf-16be"
    case .utf16LittleEndian: "utf-16le"
    case .utf32: "utf-32"
    case .utf32BigEndian: "utf-32be"
    case .utf32LittleEndian: "utf-32le"
    case .macOSRoman: "macintosh"
    case .isoLatin1: "iso-8859-1"
    default: nil
    }
#endif
    if let encodingName {
        return "\(encodingName);\(cfEncoding)".data(using: .utf8)
    }
    
    return ";\(cfEncoding)".data(using: .utf8)
}

// MARK: - Writing

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension StringProtocol {
#if !NO_FILESYSTEM
    /// Writes the contents of the `String` to a file at a given path using a given encoding.
    public func write<T : StringProtocol>(toFile path: T, atomically useAuxiliaryFile: Bool, encoding enc: String.Encoding) throws {
        guard let data = data(using: enc) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        
        let attributes : [String : Data]
        if let extendedAttributeData = extendedAttributeData(for: enc) {
            attributes = [stringEncodingAttributeName : extendedAttributeData]
        } else {
            attributes = [:]
        }

#if os(WASI)
        guard !useAuxiliaryFile else { throw CocoaError(.featureUnsupported) }
        let options : Data.WritingOptions = []
#else
        let options : Data.WritingOptions = useAuxiliaryFile ? [.atomic] : []
#endif

        try writeToFile(path: .path(String(path)), buffer: data.bytes, options: options, attributes: attributes, reportProgress: false)
    }

    /// Writes the contents of the `String` to the URL specified by url using the specified encoding.
    public func write(to url: URL, atomically useAuxiliaryFile: Bool, encoding enc: String.Encoding) throws {
        guard let data = data(using: enc) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        let attributes : [String : Data]
        if let extendedAttributeData = extendedAttributeData(for: enc) {
            attributes = [stringEncodingAttributeName : extendedAttributeData]
        } else {
            attributes = [:]
        }

#if os(WASI)
        guard !useAuxiliaryFile else { throw CocoaError(.featureUnsupported) }
        let options : Data.WritingOptions = []
#else
        let options : Data.WritingOptions = useAuxiliaryFile ? [.atomic] : []
#endif

        try writeToFile(path: .url(url), buffer: data.bytes, options: options, attributes: attributes, reportProgress: false)
    }
#endif
}

// TODO: This is part of the stdlib as of 5.11. This is a copy to support building on previous Swift stdlib versions, but should be replaced with the stdlib one as soon as possible.
extension String {
    internal init?<Encoding: Unicode.Encoding>(_validating codeUnits: some Sequence<Encoding.CodeUnit>, as encoding: Encoding.Type) {
        var transcoded: [UTF8.CodeUnit] = []
        transcoded.reserveCapacity(codeUnits.underestimatedCount)
        var isASCII = true
        let error = transcode(
            codeUnits.makeIterator(),
            from: Encoding.self,
            to: UTF8.self,
            stoppingOnError: true,
            into: {
                uint8 in
                transcoded.append(uint8)
                if isASCII && (uint8 & 0x80) == 0x80 { isASCII = false }
            }
        )
        if error { return nil }
        let res = transcoded.withUnsafeBufferPointer{
            String._tryFromUTF8($0)
        }
        if let res { self = res } else { return nil }
    }
}
