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

//===----------------------------------------------------------------------===//
// Plist Encoder
//===----------------------------------------------------------------------===//

/// `PropertyListEncoder` facilitates the encoding of `Encodable` values into property lists.
// NOTE: older overlays had Foundation.PropertyListEncoder as the ObjC
// name. The two must coexist, so it was renamed. The old name must not
// be used in the new runtime. _TtC10Foundation20_PropertyListEncoder
// is the mangled name for Foundation._PropertyListEncoder.
#if FOUNDATION_FRAMEWORK
@_objcRuntimeName(_TtC10Foundation20_PropertyListEncoder)
#endif
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
open class PropertyListEncoder {

    // MARK: - Options

    /// The output format to write the property list data in. Defaults to `.binary`.
    open var outputFormat: PropertyListDecoder.PropertyListFormat {
        get {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            return options.outputFormat
        }
        _modify {
            optionsLock.lock()
            var value = options.outputFormat
            defer {
                options.outputFormat = value
                optionsLock.unlock()
            }
            yield &value
        }
        set {
            optionsLock.lock()
            defer { optionsLock.unlock() }
            options.outputFormat = newValue
        }
    }

    /// Contextual user-provided information for use during encoding.
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

    /// Options set on the top-level encoder to pass down the encoding hierarchy.
    internal struct _Options {
        var outputFormat: PropertyListDecoder.PropertyListFormat = .binary
        var userInfo: [CodingUserInfoKey : Any] = [:]
    }

    /// The options set on the top-level encoder.
    fileprivate var options: _Options = _Options()
    fileprivate let optionsLock = LockedState<Void>()

    // MARK: - Constructing a Property List Encoder

    /// Initializes `self` with default strategies.
    public init() {}

    // MARK: - Encoding Values

    /// Encodes the given top-level value and returns its property list representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new `Data` value containing the encoded property list data.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    open func encode<Value : Encodable>(_ value: Value) throws -> Data {
        let format = self.outputFormat
        do {
            switch format {
            case .binary:
                return try _encodeBPlist(value)
            case .xml:
                return try _encodeXML(value)
            case .openStep:
                throw CocoaError(.propertyListWriteInvalid, userInfo: [NSDebugDescriptionErrorKey:"Property list format .openStep not supported for writing"])
#if FOUNDATION_FRAMEWORK
            @unknown default:
                throw CocoaError(.propertyListWriteInvalid, userInfo: [NSDebugDescriptionErrorKey:"Unknown property list format \(format)"])
#endif
            }
        } catch {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value as a property list", underlyingError: error))
        }
    }
    
    fileprivate func _encodeBPlist<Value: Encodable>(_ value: Value) throws -> Data {
        let topLevel = try encodeToTopLevelContainerBPlist(value)
          
        if topLevel.isBool {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as boolean property list fragment."))
        } else if topLevel.isNumber {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as number property list fragment."))
        } else if topLevel.isString {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as string property list fragment."))
        } else if topLevel.isDate {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as date property list fragment."))
        }
        
        var writer = _BPlistEncodingFormat.Writer()
        return try writer.serializePlist(topLevel)
    }
    
    fileprivate func _encodeXML<Value: Encodable>(_ value: Value) throws -> Data {
        let topLevel = try encodeToTopLevelContainerXML(value)
          
        if topLevel.isBool {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as boolean property list fragment."))
        } else if topLevel.isNumber {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as number property list fragment."))
        } else if topLevel.isString {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as string property list fragment."))
        } else if topLevel.isDate {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) encoded as date property list fragment."))
        }
        
        var writer = _XMLPlistEncodingFormat.Writer()
        return try writer.serializePlist(topLevel)
    }
    
    @available(FoundationPreview 0.1, *)
    open func encode<T : EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration) throws -> Data {
        let format = self.outputFormat
        do {
            switch format {
            case .binary:
                return try _encodeBPlist(value, configuration: configuration)
            case .xml:
                return try _encodeXML(value, configuration: configuration)
            case .openStep:
                throw CocoaError(.propertyListWriteInvalid, userInfo: [NSDebugDescriptionErrorKey:"Property list format .openStep not supported for writing"])
#if FOUNDATION_FRAMEWORK
            @unknown default:
                throw CocoaError(.propertyListWriteInvalid, userInfo: [NSDebugDescriptionErrorKey:"Unknown property list format \(format)"])
#endif
            }
        } catch {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [], debugDescription: "Unable to encode the given top-level value as a property list", underlyingError: error))
        }
    }
    
    fileprivate func _encodeBPlist<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration) throws -> Data {
        let topLevel = try encodeToTopLevelContainerBPlist(value, configuration: configuration)
        var writer = _BPlistEncodingFormat.Writer()
        return try writer.serializePlist(topLevel)
    }
    
    fileprivate func _encodeXML<T: EncodableWithConfiguration>(_ value: T, configuration: T.EncodingConfiguration) throws -> Data {
        let topLevel = try encodeToTopLevelContainerXML(value, configuration: configuration)
        var writer = _XMLPlistEncodingFormat.Writer()
        return try writer.serializePlist(topLevel)
    }
    
    @available(FoundationPreview 0.1, *)
    open func encode<T, C>(_ value: T, configuration: C.Type) throws -> Data where T : EncodableWithConfiguration, C : EncodingConfigurationProviding, T.EncodingConfiguration == C.EncodingConfiguration {
        try encode(value, configuration: C.encodingConfiguration)
    }

    /// Encodes the given top-level value and returns its plist-type representation.
    ///
    /// - parameter value: The value to encode.
    /// - returns: A new top-level array or dictionary representing the value.
    /// - throws: `EncodingError.invalidValue` if a non-conforming floating-point value is encountered during encoding, and the encoding strategy is `.throw`.
    /// - throws: An error if any value throws an error during encoding.
    internal func encodeToTopLevelContainerBPlist<Value : Encodable>(_ value: Value) throws -> _BPlistEncodingFormat.Reference {
        let encoder = __PlistEncoderBPlist(options: self.options)
        guard let topLevel = try encoder.wrapGeneric(value, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) did not encode any values."))
        }

        return topLevel
    }
    
    internal func encodeToTopLevelContainerXML<Value : Encodable>(_ value: Value) throws -> _XMLPlistEncodingFormat.Reference {
        let encoder = __PlistEncoderXML(options: self.options)
        guard let topLevel = try encoder.wrapGeneric(value, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) did not encode any values."))
        }

        return topLevel
    }
    
    internal func encodeToTopLevelContainerBPlist<Value: EncodableWithConfiguration>(_ value: Value, configuration: Value.EncodingConfiguration) throws -> _BPlistEncodingFormat.Reference {
        let encoder = __PlistEncoderBPlist(options: self.options)
        guard let topLevel = try encoder.wrapGeneric(value, configuration: configuration, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) did not encode any values."))
        }

        return topLevel
    }
    
    internal func encodeToTopLevelContainerXML<Value : EncodableWithConfiguration>(_ value: Value, configuration: Value.EncodingConfiguration) throws -> _XMLPlistEncodingFormat.Reference {
        let encoder = __PlistEncoderXML(options: self.options)
        guard let topLevel = try encoder.wrapGeneric(value, configuration: configuration, for: .root) else {
            throw EncodingError.invalidValue(value,
                                             EncodingError.Context(codingPath: [],
                                                                   debugDescription: "Top-level \(Value.self) did not encode any values."))
        }

        return topLevel
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension PropertyListEncoder : @unchecked Sendable {}
