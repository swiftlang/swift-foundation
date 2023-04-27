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

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol EncodingConfigurationProviding {
    associatedtype EncodingConfiguration
    static var encodingConfiguration: EncodingConfiguration { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol EncodableWithConfiguration {
    associatedtype EncodingConfiguration
    func encode(to encoder: Encoder, configuration: EncodingConfiguration) throws
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol DecodingConfigurationProviding {
    associatedtype DecodingConfiguration
    static var decodingConfiguration: DecodingConfiguration { get }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol DecodableWithConfiguration {
    associatedtype DecodingConfiguration
    init(from decoder: Decoder, configuration: DecodingConfiguration) throws
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias CodableWithConfiguration = EncodableWithConfiguration & DecodableWithConfiguration

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension KeyedEncodingContainer {
    mutating func encode<T, C>(_ wrapper: CodableConfiguration<T?, C>, forKey key: Self.Key) throws {
        switch wrapper.wrappedValue {
        case .some(let val):
            try val.encode(to: self.superEncoder(forKey: key), configuration: C.encodingConfiguration)
            break
        default: break
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension KeyedDecodingContainer {
    func decode<T, C>(_: CodableConfiguration<T?, C>.Type, forKey key: Self.Key) throws -> CodableConfiguration<T?, C> {
        if self.contains(key) {
            let wrapper = try self.decode(CodableConfiguration<T, C>.self, forKey: key)
            return CodableConfiguration<T?, C>(wrappedValue: wrapper.wrappedValue)
        } else {
            return CodableConfiguration<T?, C>(wrappedValue: nil)
        }
    }

}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension KeyedEncodingContainer {

    mutating func encode<T: EncodableWithConfiguration, C: EncodingConfigurationProviding>(_ t: T, forKey key: Self.Key, configuration: C.Type) throws where T.EncodingConfiguration == C.EncodingConfiguration {
        try t.encode(to: self.superEncoder(forKey: key), configuration: C.encodingConfiguration)
    }
    mutating func encodeIfPresent<T: EncodableWithConfiguration, C: EncodingConfigurationProviding>(_ t: T?, forKey key: Self.Key, configuration: C.Type) throws where T.EncodingConfiguration == C.EncodingConfiguration {
        guard let value = t else { return }
        try self.encode(value, forKey: key, configuration: configuration)
    }

    mutating func encode<T: EncodableWithConfiguration>(_ t: T, forKey key: Self.Key, configuration: T.EncodingConfiguration) throws {
        try t.encode(to: self.superEncoder(forKey: key), configuration: configuration)
    }
    mutating func encodeIfPresent<T: EncodableWithConfiguration>(_ t: T?, forKey key: Self.Key, configuration: T.EncodingConfiguration) throws {
        guard let value = t else { return }
        try self.encode(value, forKey: key, configuration: configuration)
    }

}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension KeyedDecodingContainer {

    func decode<T: DecodableWithConfiguration, C: DecodingConfigurationProviding>(
        _: T.Type,
        forKey key: Self.Key,
        configuration: C.Type
    ) throws -> T where T.DecodingConfiguration == C.DecodingConfiguration {
        return try T(from: self.superDecoder(forKey: key), configuration: C.decodingConfiguration)
    }
    func decodeIfPresent<T: DecodableWithConfiguration, C: DecodingConfigurationProviding>(
        _: T.Type,
        forKey key: Self.Key,
        configuration: C.Type
    ) throws -> T? where T.DecodingConfiguration == C.DecodingConfiguration {
        if contains(key) {
            return try self.decode(T.self, forKey: key, configuration: configuration)
        } else {
            return nil
        }
    }

    func decode<T: DecodableWithConfiguration>(
        _: T.Type,
        forKey key: Self.Key,
        configuration: T.DecodingConfiguration
    ) throws -> T {
        return try T(from: self.superDecoder(forKey: key), configuration: configuration)
    }
    func decodeIfPresent<T: DecodableWithConfiguration>(
        _: T.Type,
        forKey key: Self.Key,
        configuration: T.DecodingConfiguration
    ) throws -> T? {
        if contains(key) {
            return try self.decode(T.self, forKey: key, configuration: configuration)
        } else {
            return nil
        }
    }

}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension UnkeyedEncodingContainer {

    mutating func encode<T: EncodableWithConfiguration, C: EncodingConfigurationProviding>(_ t: T, configuration: C.Type) throws where T.EncodingConfiguration == C.EncodingConfiguration {
        try t.encode(to: self.superEncoder(), configuration: C.encodingConfiguration)
    }

    mutating func encode<T: EncodableWithConfiguration>(_ t: T, configuration: T.EncodingConfiguration) throws {
        try t.encode(to: self.superEncoder(), configuration: configuration)
    }

}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public extension UnkeyedDecodingContainer {

    mutating func decode<T: DecodableWithConfiguration, C: DecodingConfigurationProviding>(
        _: T.Type, configuration: C.Type
    ) throws -> T where T.DecodingConfiguration == C.DecodingConfiguration {
        return try T(from: try self.superDecoder(), configuration: C.decodingConfiguration)
    }
    mutating func decodeIfPresent<T: DecodableWithConfiguration, C: DecodingConfigurationProviding>(
        _: T.Type, configuration: C.Type
    ) throws -> T? where T.DecodingConfiguration == C.DecodingConfiguration {
        if try self.decodeNil() {
            return nil
        } else {
            return try self.decode(T.self, configuration: configuration)
        }
    }

    mutating func decode<T: DecodableWithConfiguration>(
        _: T.Type, configuration: T.DecodingConfiguration
    ) throws -> T {
        return try T(from: try self.superDecoder(), configuration: configuration)
    }
    mutating func decodeIfPresent<T: DecodableWithConfiguration>(
        _: T.Type, configuration: T.DecodingConfiguration
    ) throws -> T? {
        if try self.decodeNil() {
            return nil
        } else {
            return try self.decode(T.self, configuration: configuration)
        }
    }

}

@propertyWrapper
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct CodableConfiguration<T, ConfigurationProvider>: Codable
where T: CodableWithConfiguration,
      ConfigurationProvider: EncodingConfigurationProviding & DecodingConfigurationProviding,
      ConfigurationProvider.EncodingConfiguration == T.EncodingConfiguration,
      ConfigurationProvider.DecodingConfiguration == T.DecodingConfiguration
{
    public var wrappedValue: T

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public init(wrappedValue: T, from configurationProvider: ConfigurationProvider.Type) {
        self.wrappedValue = wrappedValue
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder, configuration: ConfigurationProvider.encodingConfiguration)
    }

    public init(from decoder: Decoder) throws {
        wrappedValue = try T(from: decoder, configuration: ConfigurationProvider.decodingConfiguration)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension CodableConfiguration: Sendable where T: Sendable { }

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension CodableConfiguration: Equatable where T: Equatable { }

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension CodableConfiguration: Hashable where T: Hashable { }

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Optional: EncodableWithConfiguration where Wrapped: EncodableWithConfiguration {
    public func encode(to encoder: Encoder, configuration: Wrapped.EncodingConfiguration) throws {
        if let wrapped = self {
            try wrapped.encode(to: encoder, configuration: configuration)
        } else {
            var c = encoder.singleValueContainer()
            try c.encodeNil()
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Optional: DecodableWithConfiguration where Wrapped: DecodableWithConfiguration {
    public init(from decoder: Decoder, configuration: Wrapped.DecodingConfiguration) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = nil
        } else {
            self = try Wrapped.init(from: decoder, configuration: configuration)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Array: EncodableWithConfiguration where Element: EncodableWithConfiguration {
    public func encode(to encoder: Encoder, configuration: Element.EncodingConfiguration) throws {
        var c = encoder.unkeyedContainer()
        for e in self {
            try c.encode(e, configuration: configuration)
        }
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Array: DecodableWithConfiguration where Element: DecodableWithConfiguration {
    public init(from decoder: Decoder, configuration: Element.DecodingConfiguration) throws {
        var result = [Element]()
        var c = try decoder.unkeyedContainer()
        while !c.isAtEnd {
            try result.append(c.decode(Element.self, configuration: configuration))
        }
        self = result
    }
}
