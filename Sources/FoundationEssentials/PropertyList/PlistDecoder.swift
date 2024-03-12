//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal import _CShims

//===----------------------------------------------------------------------===//
// Plist Decoder
//===----------------------------------------------------------------------===//

/// `PropertyListDecoder` facilitates the decoding of property list values into semantic `Decodable` types.
// NOTE: older overlays had Foundation.PropertyListDecoder as the ObjC
// name. The two must coexist, so it was renamed. The old name must not
// be used in the new runtime. _TtC10Foundation20_PropertyListDecoder
// is the mangled name for Foundation._PropertyListDecoder.
#if FOUNDATION_FRAMEWORK
@_objcRuntimeName(_TtC10Foundation20_PropertyListDecoder)
#endif
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
open class PropertyListDecoder {
#if FOUNDATION_FRAMEWORK
    public typealias PropertyListFormat = PropertyListSerialization.PropertyListFormat
#else
    public enum PropertyListFormat : UInt, Sendable  {
        case xml
        case binary
        case openStep
    }
#endif
    // MARK: Options

    /// Contextual user-provided information for use during decoding.
    open var userInfo: [CodingUserInfoKey : Any] {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.userInfo
        }
        _modify {
            optionsLock.lock()
            var value = options.userInfo
            defer {
                options.userInfo = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.userInfo = newValue
        }
    }

    /// Options set on the top-level encoder to pass down the decoding hierarchy.
    internal struct _Options {
        var userInfo: [CodingUserInfoKey : Any] = [:]
    }

    /// The options set on the top-level decoder.
    fileprivate var options = _Options()
    fileprivate let optionsLock = LockedState<Void>()

    // MARK: - Constructing a Property List Decoder

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Decoding Values

    /// Decodes a top-level value of the given type from the given property list representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not a valid property list.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T : Decodable>(_ type: T.Type, from data: Data) throws -> T {
        var format: PropertyListDecoder.PropertyListFormat = .binary
        return try decode(type, from: data, format: &format)
    }

    /// Decodes a top-level value of the given type from the given property list representation.
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter data: The data to decode from.
    /// - parameter format: The parsed property list format.
    /// - returns: A value of the requested type along with the detected format of the property list.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not a valid property list.
    /// - throws: An error if any value throws an error during decoding.
    open func decode<T : Decodable>(_ type: T.Type, from data: Data, format: inout PropertyListDecoder.PropertyListFormat) throws -> T {
        try _decode({
            try $0.decode(type)
        }, from: data, format: &format)
    }
    
    @available(FoundationPreview 0.1, *)
    open func decode<T : DecodableWithConfiguration>(_ type: T.Type, from data: Data, configuration: T.DecodingConfiguration) throws -> T {
        var format: PropertyListDecoder.PropertyListFormat = .binary
        return try decode(type, from: data, format: &format, configuration: configuration)
    }
    
    @available(FoundationPreview 0.1, *)
    open func decode<T, C>(_ type: T.Type, from data: Data, configuration: C.Type) throws -> T where T : DecodableWithConfiguration, C : DecodingConfigurationProviding, T.DecodingConfiguration == C.DecodingConfiguration {
        try decode(type, from: data, configuration: C.decodingConfiguration)
    }
    
    @available(FoundationPreview 0.1, *)
    open func decode<T, C>(_ type: T.Type, from data: Data, format: inout PropertyListDecoder.PropertyListFormat, configuration: C.Type) throws -> T where T : DecodableWithConfiguration, C: DecodingConfigurationProviding, T.DecodingConfiguration == C.DecodingConfiguration {
        try decode(type, from: data, format: &format, configuration: C.decodingConfiguration)
    }
    
    @available(FoundationPreview 0.1, *)
    open func decode<T : DecodableWithConfiguration>(_ type: T.Type, from data: Data, format: inout PropertyListDecoder.PropertyListFormat, configuration: T.DecodingConfiguration) throws -> T {
        try _decode({
            try $0.decode(type, configuration: configuration)
        }, from: data, format: &format)
    }
    
    private func _decode<T>(_ doDecode: (any _PlistDecoderEntryPointProtocol) throws -> T, from data: Data, format: inout PropertyListDecoder.PropertyListFormat) throws -> T {
        return try Self.detectFormatAndConvertEncoding(for: data, binaryPlist: { utf8Buffer in
            var decoder: _PlistDecoder<_BPlistDecodingFormat>
            do {
                let map = try BPlistScanner.scanBinaryPropertyList(from: utf8Buffer)
                decoder = try _PlistDecoder(referencing: map, options: self.options, codingPathNode: .root)
            } catch let error as BPlistError {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The given data was not a valid property list.", underlyingError: error.cocoaError))
            }
            let result = try doDecode(decoder)

            let uniquelyReferenced = isKnownUniquelyReferenced(&decoder)
            decoder.takeOwnershipOfBackingDataIfNeeded(selfIsUniquelyReferenced: uniquelyReferenced)

            format = .binary
            return result
        }, xml: { utf8Buffer in
            var decoder: _PlistDecoder<_XMLPlistDecodingFormat>
            do {
                var scanInfo = XMLPlistScanner(buffer: utf8Buffer)
                let map = try scanInfo.scanXMLPropertyList()
                decoder = try _PlistDecoder(referencing: map, options: self.options, codingPathNode: .root)
            } catch let error as XMLPlistError {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The given data was not a valid property list.", underlyingError: error.cocoaError))
            }
            let result = try doDecode(decoder)

            let uniquelyReferenced = isKnownUniquelyReferenced(&decoder)
            decoder.takeOwnershipOfBackingDataIfNeeded(selfIsUniquelyReferenced: uniquelyReferenced)

            format = .xml
            return result
        }, openstep: { utf16View in
#if FOUNDATION_FRAMEWORK
            let value: Any
            do {
                value = try __ParseOldStylePropertyList(utf16: utf16View)
            } catch let error as OpenStepPlistError {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The given data was not a valid property list.", underlyingError: error.cocoaError))
            }
            let decoder = __PlistDictionaryDecoder(referencing: value, at: [], options: options)
            format = .openStep
            return try doDecode(decoder)
#else
            // Unsupported until __PlistDictionaryDecoder is available
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The openStep format is unsupported on this platform."))
#endif
        })
    }
    
    @inline(__always)
    private static func findXMLTagOpening(in buffer: BufferView<UInt8>) -> BufferView<UInt8>.Index? {
        buffer.withUnsafeRawPointer { bufPtr, bufCount in
            guard bufCount >= 5 && strncmp(bufPtr, "<?xml", 5) == 0 else {
                return nil
            }
            return buffer.index(buffer.startIndex, offsetBy: 5)
        }
    }
    
    @inline(__always)
    private static func findEncodingLocation(in buffer: BufferView<UInt8>) throws -> BufferView<UInt8>.Index? {
        var idx = buffer.startIndex
        let endIdx = buffer.endIndex
        
        while idx < endIdx {
            let ch = buffer[unchecked: idx]
            
            // Looks like the end of the <?xml...> tag. No explicit encoding found.
            if ch == UInt8(ascii: "?") || ch == UInt8(ascii: ">") {
                return nil
            }

            let subBuffer = buffer[idx...]
            let match = try subBuffer.withUnsafeRawPointer { bufPtr, bufCount -> BufferView<UInt8>.Index? in
                guard bufCount > 9 else {
                    throw DecodingError._dataCorrupted("End of buffer while looking for encoding name", for: .root)
                }
                if strncmp(bufPtr, "encoding=", 9) == 0 {
                    return buffer.index(idx, offsetBy: 9)
                }
                return nil
            }
            if let match {
                return match
            } else {
                buffer.formIndex(after: &idx)
            }
        }
        
        // Reached of the input without finding 'encoding'
        return nil
    }
    
    private static func readQuotedEncoding(in buffer: BufferView<UInt8>) throws -> String.Encoding {
        guard let quote = buffer.first,
              quote == UInt8(ascii: "'") || quote == UInt8(ascii: "\"") else {
            return .utf8
        }

        // Move past the quote character
        let baseIdx = buffer.index(after: buffer.startIndex)
        
        let endIdx = buffer.endIndex
        var idx = baseIdx
        while idx < endIdx && buffer[unchecked: idx] != quote {
            buffer.formIndex(after: &idx)
        }
        
        return try buffer[unchecked: baseIdx..<idx].withUnsafePointer { ptr, encodingLength in
            if encodingLength == 5, _stringshims_strncasecmp_l(ptr, "utf-8", 5, nil) == 0 {
                return .utf8
            }
            
#if FOUNDATION_FRAMEWORK
            guard let encodingName = String(bytes: UnsafeBufferPointer(start: ptr, count: encodingLength), encoding: .isoLatin1) else {
                throw DecodingError._dataCorrupted("Encountered unknown encoding", for: .root)
            }
            let enc = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            guard enc != kCFStringEncodingInvalidId else {
                throw DecodingError._dataCorrupted("Encountered unknown encoding \(encodingName)", for: .root)
            }

            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(enc))
#else
            // TODO: For now, FoundationEssentials only has support for utf-8.
            throw DecodingError._dataCorrupted("Encountered unknown encoding", for: .root)
#endif
        }

    }
    
    private static func scanForExplicitXMLEncoding(in buffer: BufferView<UInt8>) throws -> String.Encoding {
        // Scan for the <?xml.... ?> opening
        guard let postOpeningIdx = findXMLTagOpening(in: buffer) else {
            return .utf8
        }
        
        // Found "<?xml"; now we scan for "encoding"
        guard let postEncodingIdx = try findEncodingLocation(in: buffer[postOpeningIdx...]) else {
            return .utf8
        }
        
        // Read the quoted encoding value and convert it into a String.Encoding.
        return try readQuotedEncoding(in: buffer[postEncodingIdx...])
    }

    static func detectEncoding(of buffer: BufferView<UInt8>) throws -> (encoding: String.Encoding, bomLength: Int) {
        // Try detecting BOM first.
        let length = buffer.count
        let byte0 = (length > 0) ? buffer[uncheckedOffset: 0] : nil
        let byte1 = (length > 1) ? buffer[uncheckedOffset: 1] : nil
        let byte2 = (length > 2) ? buffer[uncheckedOffset: 2] : nil
        let byte3 = (length > 3) ? buffer[uncheckedOffset: 3] : nil
        switch (byte0, byte1, byte2, byte3) {
        case (0, 0, 0xFE, 0xFF):
            return (.utf32BigEndian, 4)
        case (0xFE, 0xFF, 0, 0):
            return (.utf32LittleEndian, 4)
        case (0xFE, 0xFF, _, _):
            return (.utf16BigEndian, 2)
        case (0xFF, 0xFE, _, _):
            return (.utf16LittleEndian, 2)
        case (0xEF, 0xBB, 0xBF, _):
            return (.utf8, 3)
        default:
            return try (scanForExplicitXMLEncoding(in: buffer), bomLength: 0)
        }
    }

    static func detectFormatAndConvertEncoding<T>(for data: Data,
                                                  binaryPlist: (BufferView<UInt8>) throws -> T,
                                                  xml: (BufferView<UInt8>) throws -> T,
                                                  openstep: (String.UTF16View) throws -> T) rethrows -> T {
        try data.withBufferView { buffer in
            
            // Binary plist always begins with the same literal bytes, which isn't valid in any of the other formats.
            if BPlistScanner.hasBPlistMagic(in: buffer) {
                return try binaryPlist(buffer)
            }
            
            // Try to deduce the text encoding of the file so that we can determine if it's XML or not.
            let (encoding, bomLength) = try detectEncoding(of: buffer)
            let postBOMIndex = buffer.index(buffer.startIndex, offsetBy: bomLength)
            let postBOMBuffer = buffer[unchecked: postBOMIndex...]
            
            var result: T?
            try Self.withUTF8Representation(of: postBOMBuffer, sourceEncoding: encoding) { utf8Buffer in
                if XMLPlistScanner.detectPossibleXMLPlist(for: utf8Buffer) {
                    result = try xml(utf8Buffer)
                }
            }
            if let result {
                return result
            }
            
            // If it doesn't appear to be XML or binary, then we assume it's an OpenStep plist and try to parse it with that format.
            return try Self.withUTF16Representation(of: postBOMBuffer, sourceEncoding: encoding) { utf16View in
                try openstep(utf16View)
            }
        }
    }

    static func withUTF8Representation<T>(of buffer: BufferView<UInt8>, sourceEncoding: String.Encoding, _ closure: (BufferView<UInt8>) throws -> T ) throws -> T {
        if sourceEncoding == .utf8 {
            return try closure(buffer)
        } else {
            // TODO: This FOUNDATION_FRAMEWORK-only initializer cannot be used by FoundationPreview. Only UTF-8 encoded xml plists are supported there right now. (See readQuotedEncoding(in:).)
            guard var string = String(bytes: buffer, encoding: sourceEncoding) else {
                throw DecodingError._dataCorrupted("Cannot convert input to UTF-8", for: .root)
            }
            return try string.withUTF8 {
                try closure(BufferView(unsafeBufferPointer: $0)!)
            }
        }
    }

    static func withUTF16Representation<T>(of buffer: BufferView<UInt8>, sourceEncoding: String.Encoding, _ closure: (String.UTF16View) throws -> T ) throws -> T {
        // If we were careful with endianness, we could avoid some copies here.
        guard let string = String(bytes: buffer, encoding: sourceEncoding) else {
            throw DecodingError._dataCorrupted("Cannot convert input to UTF-16", for: .root)
        }
        return try closure(string.utf16)
    }

#if FOUNDATION_FRAMEWORK
    // __PlistDictionaryDecoder is only available in the framework for now
    
    /// Decodes a top-level value of the given type from the given property list container (top-level array or dictionary).
    ///
    /// - parameter type: The type of the value to decode.
    /// - parameter container: The top-level plist container.
    /// - returns: A value of the requested type.
    /// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not a valid property list.
    /// - throws: An error if any value throws an error during decoding.
    internal func decode<T : Decodable>(_ type: T.Type, fromTopLevel container: Any) throws -> T {
        let decoder = __PlistDictionaryDecoder(referencing: container, options: self.options)
        guard let value = try decoder.unbox(container, as: type) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
        }

        return value
    }
    
    internal func decode<T : DecodableWithConfiguration>(_ type: T.Type, fromTopLevel container: Any, configuration: T.DecodingConfiguration) throws -> T {
        let decoder = __PlistDictionaryDecoder(referencing: container, options: self.options)
        guard let value = try decoder.unbox(container, as: type, configuration: configuration) else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
        }

        return value
    }
#endif
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension PropertyListDecoder : @unchecked Sendable {}
