//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// A type that parses an input representation, such as a formatted string, into a provided data type.
///
/// A ``ParseStrategy`` allows you to convert a formatted representation into a data type, using one of two approaches:
///
/// - Initialize the data type by calling an initializer of that type that takes a formatted instance and a parse strategy as parameters. For example, you can create a ``Decimal`` from a formatted string with the initializer ``Decimal/init(_:format:lenient:)-6fk71``.
/// - Create a parse strategy and call its ``parse(_:)`` method on one or more formatted instances.
///
/// ``ParseStrategy`` is closely related to ``FormatStyle``, which provides the opposite conversion: from data type to formatted representation. To use a parse strategy, you create a ``FormatStyle`` to define the representation you expect, then access the style's `parseStrategy` property to get a strategy instance.
///
/// The following example creates a ``Decimal/FormatStyle/Currency`` format style that uses US dollars and US English number-formatting conventions. It then creates a ``Decimal`` instance by providing a formatted string to parse and the format style's ``Decimal/FormatStyle/Currency/parseStrategy``.
///
/// ```swift
/// let style = Decimal.FormatStyle.Currency(code: "USD",
/// locale: Locale(identifier: "en_US"))
/// let parsed = try? Decimal("$12,345.67",
/// strategy: style.parseStrategy) // 12345.67
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol ParseStrategy : Codable, Hashable {

    /// The input type parsed by this strategy.
    ///
    /// Conforming types provide a value for this associated type to declare the type of values they parse.
    associatedtype ParseInput

    /// The output type returned by this strategy.
    ///
    /// Conforming types provide a value for this associated type to declare the type of values they return.
    associatedtype ParseOutput

    /// Parses a value, using this strategy.
    ///
    /// This method throws an error if the parse strategy can't parse `value`.
    ///
    /// - Parameter value: A value whose type matches the strategy's ``ParseStrategy/ParseInput`` type.
    /// - Returns: A parsed value of the type declared by ``ParseStrategy/ParseOutput``.
    func parse(_ value: ParseInput) throws -> ParseOutput
}
