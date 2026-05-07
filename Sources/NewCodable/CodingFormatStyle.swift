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

/// A type that converts a value into a representation in another type using a
/// locale-independent format.
///
/// `CodingFormatStyle` is the coding counterpart of Foundation's `FormatStyle`.
/// While `FormatStyle` is designed for human-facing presentation and adapts its
/// output to the user's locale (e.g. grouping separators, decimal points,
/// measurement units), `CodingFormatStyle` produces output that is
/// deterministic and locale-independent. This makes it suitable for data
/// interchange, serialization, and wire formats where both encoder and decoder
/// must agree on a single, stable representation regardless of locale.
///
/// ### Using with coding strategies
///
/// `CodingFormatStyle` is most commonly used through
/// ``StringFormattedCodingStrategy``, which wraps a
/// ``CodingParseableFormatStyle`` to encode a value as a formatted string and
/// decode it back using the style's ``CodingParseableFormatStyle/parseStrategy``.
/// The `.dateFormat(_:)` strategy and `CodingStrategySyntax` shorthand makes this concise:
///
/// ```swift
/// @CodableBy(.dateFormat(.iso8601))
/// var createdAt: Date
/// ```
public protocol CodingFormatStyle {
    /// The type of value this format style accepts as input.
    associatedtype FormatInput

    /// The type of representation this format style produces as output.
    associatedtype FormatOutput
    
    /// Formats a value, using this style.
    ///
    /// Use this method when you want to create a single style instance, and then use it to format
    /// multiple values.
    ///
    /// - Parameter value: The value to format.
    /// - Returns: A representation of `value`, in the ``FormatOutput`` type, formatted according to
    ///   the style's configuration.
    func format(_ value: FormatInput) -> FormatOutput
}

/// A type that parses a formatted representation back into a value, using a
/// locale-independent format.
///
/// `CodingFormatParseStrategy` is the coding counterpart of Foundation's
/// `ParseStrategy`. It performs the inverse of ``CodingFormatStyle/format(_:)``
/// — given a formatted representation (such as a `String`), it produces the
/// original value.
///
/// Like ``CodingFormatStyle``, this protocol is designed for locale-independent
/// formats used in data interchange. The parse logic must not depend on any
/// ambient locale; the same input must always produce the same output.
///
/// ### Error handling
///
/// Unlike Foundation's `ParseStrategy`, which throws `any Error`,
/// `CodingFormatParseStrategy` throws ``CodingError/Decoding``. This allows
/// parse failures to integrate directly with the coding error hierarchy,
/// providing structured diagnostics when a value cannot be decoded.
///
/// Types that conform to both `ParseStrategy` and `CodingFormatParseStrategy`
/// receive a default implementation of ``parse(_:)`` that forwards to
/// `ParseStrategy.parse(_:)` and wraps any thrown error in a
/// ``CodingError/Decoding`` value.
///
/// ### Conforming to CodingFormatParseStrategy
///
/// Implement ``parse(_:)`` to convert `ParseInput` into `ParseOutput`, throwing
/// ``CodingError/Decoding`` if the input is malformed:
///
/// ```swift
/// struct MyParseStrategy: CodingFormatParseStrategy {
///     func parse(_ value: String) throws(CodingError.Decoding) -> MyValue {
///         guard let result = MyValue(rawString: value) else {
///             throw CodingError.dataCorrupted(
///                 debugDescription: "Invalid MyValue: \(value)")
///         }
///         return result
///     }
/// }
/// ```
public protocol CodingFormatParseStrategy : Codable, Hashable {
    /// The type of formatted representation this strategy accepts as input.
    associatedtype ParseInput

    /// The type of value this strategy produces as output.
    associatedtype ParseOutput

    /// Parses a value, using this strategy.
    ///
    /// This method throws an error if the parse strategy can't parse `value`.
    ///
    /// - Parameter value: A value whose type matches the strategy's ``ParseInput`` type.
    /// - Returns: A parsed value of the type declared by ``ParseOutput``.
    func parse(_ value: ParseInput) throws(CodingError.Decoding) -> ParseOutput
}

/// A ``CodingFormatStyle`` that can also parse its output back into the
/// original value.
///
/// `CodingParseableFormatStyle` combines formatting and parsing into a single
/// type, enabling round-trip conversion between a value and its serialized
/// representation. It is the coding counterpart of Foundation's
/// `ParseableFormatStyle`.
///
/// A conforming type must provide a ``parseStrategy`` whose input and output
/// types mirror the format style's output and input types, respectively:
///
/// - `Strategy.ParseInput == FormatOutput` — the parse strategy accepts the
///   formatted representation.
/// - `Strategy.ParseOutput == FormatInput` — the parse strategy produces the
///   original value.
///
/// This constraint ensures that ``CodingFormatStyle/format(_:)`` and
/// ``CodingFormatParseStrategy/parse(_:)`` are true inverses.
///
/// ### Usage with StringFormattedCodingStrategy
///
/// ``StringFormattedCodingStrategy`` requires its generic parameter to be a
/// `CodingParseableFormatStyle` whose `FormatOutput` is `String`. This allows
/// it to encode a value as a formatted string and decode it by parsing that
/// string back:
///
/// ```swift
/// // ISO 8601 dates stored as strings in JSON:
/// @CodableBy(.dateFormat(.iso8601))
/// var timestamp: Date
///
/// // HTTP-date format (RFC 7231):
/// @CodableBy(.dateFormat(.http))
/// var lastModified: Date
/// ```
public protocol CodingParseableFormatStyle: CodingFormatStyle {
    /// The parse strategy type that can convert this style's output back into
    /// its input.
    associatedtype Strategy: CodingFormatParseStrategy where Strategy.ParseInput == FormatOutput, Strategy.ParseOutput == FormatInput

    /// A ``CodingFormatParseStrategy`` that can parse this format style's
    /// output back into its input type.
    var parseStrategy: Strategy { get }
}
