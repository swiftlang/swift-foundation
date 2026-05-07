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

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

// MARK: - StringFormattedCodingStrategy

/// A `CodingStrategy` that converts values to and from `String` formats using
/// a `CodingParseableFormatStyle`.
///
/// Use the convenience static members for common formats:
///
///     @CodableBy(.dateFormat(.iso8601))
///     let createdAt: Date
///
///     @CodableBy(.dateFormat(.iso8601(.init(includingFractionalSeconds: true)))
///     let preciseTimestamp: Date
///
///     @CodableBy(.dateFormat(.iso8601.year().month().day()))
///     let dateOnly: Date
///
// TODO: Can we eventually reimplement decoding using a visitor? Or encode to an OutputStream?
public struct StringFormattedCodingStrategy<F: CodingParseableFormatStyle>: CommonCodingStrategy, JSONCodingStrategy where F.FormatOutput == String {
    private let formatStyle: F

    public init(_ formatStyle: F) {
        self.formatStyle = formatStyle
    }
    
    public func encode(_ value: borrowing F.FormatInput, to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        let string = formatStyle.format(value)
        try encoder.encodeString(string)
    }
    
    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> F.FormatInput {
        let string = try decoder.decode(String.self)
        do {
            return try formatStyle.parseStrategy.parse(string)
        } catch {
            throw CodingError.dataCorrupted(debugDescription: "Failed to parse '\(string)' using \(F.self): \(error)")
        }
    }
}

// MARK: Format Style Convenience

extension CommonCodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

extension CommonEncodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

extension CommonDecodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

// MARK: JSON Format Style Convenience

extension JSONCodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

extension JSONEncodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

extension JSONDecodingStrategy {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String {
        .init(style)
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> StringFormattedCodingStrategy<F> where Self == StringFormattedCodingStrategy<F>, F.FormatOutput == String, F.FormatInput == Date {
        .init(style)
    }
}

extension CodingFormatParseStrategy where Self: ParseStrategy {
    public func parse(_ value: ParseInput) throws(CodingError.Decoding) -> ParseOutput {
        do throws(any Error) {
            @_transparent
            func _callParseStrategy<S: ParseStrategy>(_ strategy: S, value: S.ParseInput) throws -> S.ParseOutput {
                try strategy.parse(value)
            }
            return try _callParseStrategy(self, value: value)
        } catch {
            // TODO: Proper error translation
            throw CodingError.dataCorrupted(underlyingError: .init(description: String(describing: error)))
        }
    }
}

extension Date.ISO8601FormatStyle: CodingFormatStyle, CodingFormatParseStrategy, CodingParseableFormatStyle { }
extension Date.HTTPFormatStyle: CodingFormatStyle, CodingFormatParseStrategy, CodingParseableFormatStyle { }
extension DateComponents.ISO8601FormatStyle: CodingFormatStyle, CodingFormatParseStrategy, CodingParseableFormatStyle { }
extension DateComponents.HTTPFormatStyle: CodingFormatStyle, CodingFormatParseStrategy, CodingParseableFormatStyle { }

extension CodingParseableFormatStyle where Self == Date.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return Date.ISO8601FormatStyle() }
}
extension CodingFormatStyle where Self == Date.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return Date.ISO8601FormatStyle() }
}
extension CodingFormatParseStrategy where Self == Date.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return Date.ISO8601FormatStyle() }
}

extension CodingParseableFormatStyle where Self == Date.HTTPFormatStyle {
    /// An HTTP date format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return Date.HTTPFormatStyle() }
}
extension CodingFormatStyle where Self == Date.HTTPFormatStyle {
    /// An HTTP date format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return Date.HTTPFormatStyle() }
}
extension CodingFormatParseStrategy where Self == Date.HTTPFormatStyle {
    /// An HTTP date format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return Date.HTTPFormatStyle() }
}

extension CodingParseableFormatStyle where Self == DateComponents.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return DateComponents.ISO8601FormatStyle() }
}
extension CodingFormatStyle where Self == DateComponents.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return DateComponents.ISO8601FormatStyle() }
}
extension CodingFormatParseStrategy where Self == DateComponents.ISO8601FormatStyle {
    /// An ISO 8601 format style for use with ``StringFormattedCodingStrategy``.
    public static var iso8601: Self { return DateComponents.ISO8601FormatStyle() }
}

extension CodingParseableFormatStyle where Self == DateComponents.HTTPFormatStyle {
    /// An HTTP date components format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return DateComponents.HTTPFormatStyle() }
}
extension CodingFormatStyle where Self == DateComponents.HTTPFormatStyle {
    /// An HTTP date components format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return DateComponents.HTTPFormatStyle() }
}
extension CodingFormatParseStrategy where Self == DateComponents.HTTPFormatStyle {
    /// An HTTP date components format style for use with ``StringFormattedCodingStrategy``.
    public static var http: Self { return DateComponents.HTTPFormatStyle() }
}

// MARK: - StringBase64DataCodingStrategy

/// A `CodingStrategy` that encodes `Data` values as base64 strings.
///
/// Use with `@CodableBy(.base64)`:
///
///     @CodableBy(.base64)
///     let payload: Data
///
// TODO: Can we eventually reimplement decoding using a visitor? Or encode to an OutputStream?
public struct StringBase64DataCodingStrategy: CommonCodingStrategy {
    public typealias Value = Data

    private let encodingOptions: Data.Base64EncodingOptions
    private let decodingOptions: Data.Base64DecodingOptions

    public init(
        encodingOptions: Data.Base64EncodingOptions = [],
        decodingOptions: Data.Base64DecodingOptions = []
    ) {
        self.encodingOptions = encodingOptions
        self.decodingOptions = decodingOptions
    }

    public func encode(_ value: borrowing Value, to encoder: inout some CommonEncoder & ~Copyable & ~Escapable) throws(CodingError.Encoding) {
        let string = value.base64EncodedString(options: encodingOptions)
        try encoder.encodeString(string)
    }
    
    public func decode(from decoder: inout some (CommonDecoder & ~Escapable)) throws(CodingError.Decoding) -> Value {
        let string = try decoder.decode(String.self)
        guard let data = Data(base64Encoded: string, options: decodingOptions) else {
            throw CodingError.dataCorrupted(debugDescription: "Expected base64-encoded string")
        }
        return data
    }
}

extension StringBase64DataCodingStrategy: JSONCodingStrategy {
    // TODO: Implement a JSON-specific version of this that doesn't require instantiating a String.
}

extension CommonCodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        encodingOptions: Data.Base64EncodingOptions = [],
        decodingOptions: Data.Base64DecodingOptions = []
    ) -> Self {
        .init(encodingOptions: encodingOptions, decodingOptions: decodingOptions)
    }
}

extension CommonEncodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        encodingOptions: Data.Base64EncodingOptions = [],
    ) -> Self {
        .init(encodingOptions: encodingOptions)
    }
}

extension CommonDecodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        decodingOptions: Data.Base64DecodingOptions = []
    ) -> Self {
        .init(decodingOptions: decodingOptions)
    }
}


// MARK: JSON Base64 Convenience

extension JSONCodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        encodingOptions: Data.Base64EncodingOptions = [],
        decodingOptions: Data.Base64DecodingOptions = []
    ) -> Self {
        .init(encodingOptions: encodingOptions, decodingOptions: decodingOptions)
    }
}

extension JSONEncodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        encodingOptions: Data.Base64EncodingOptions = []
    ) -> Self {
        .init(encodingOptions: encodingOptions)
    }
}

extension JSONDecodingStrategy where Self == StringBase64DataCodingStrategy {
    public static var base64: Self { .init() }

    public static func base64(
        decodingOptions: Data.Base64DecodingOptions = []
    ) -> Self {
        .init(decodingOptions: decodingOptions)
    }
}

// MARK: - CodingStrategySyntax extensions

extension CodingStrategySyntax {
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle, Input>(_ style: F, type: Input.Type) -> CodingStrategySyntax where F.FormatOutput == String, F.FormatInput == Input {
        .init()
    }
    
    /// Encode/decode a value as a string using a `CodingParseableFormatStyle`.
    public static func format<F: CodingParseableFormatStyle>(_ style: F) -> CodingStrategySyntax where F.FormatOutput == String {
        .init()
    }
    
    /// Encode/decode a date value as a string using a `CodingParseableFormatStyle`.
    public static func dateFormat<F: CodingParseableFormatStyle>(_ style: F) -> CodingStrategySyntax where F.FormatOutput == String, F.FormatInput == Date {
        .init()
    }
    
    /// Encode/decode `Data` as a base64 string.
    public static var base64: CodingStrategySyntax { .init() }

    /// Encode/decode `Data` as a base64 string with options.
    public static func base64(
        encodingOptions: Data.Base64EncodingOptions = [],
        decodingOptions: Data.Base64DecodingOptions = []
    ) -> CodingStrategySyntax {
        .init()
    }
}
