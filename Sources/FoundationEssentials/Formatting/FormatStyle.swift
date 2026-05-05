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

/// A type that converts a given data type into a representation in another type, such as a string.
///
/// Types conforming to the `FormatStyle` protocol take their input type and produce formatted
/// instances of their output type. The formatting process accounts for locale-specific conventions,
/// like grouping and separators for numbers, and presentation of units for measurements. The format
/// styles Foundation provides produce their output as `String` or `AttributedString` instances. You
/// can also create custom styles that format their output as any type, like XML or JSON `Data` or
/// an image.
///
/// There are two basic approaches to using a `FormatStyle`:
///
/// - Create an instance of a type that conforms to `FormatStyle` and apply it to one or more
///   instances of the input type, by calling the style's ``format(_:)`` method. Use this when you
///   want to customize a style once and apply it repeatedly to many instances.
/// - Pass an instance of a type that conforms to `FormatStyle` to the data type's `formatted(_:)`
///   method, which takes the style as a parameter. Use this for one-off formatting scenarios, or
///   when you want to apply different format styles to the same data value. For the simplest cases,
///   most types that support formatting also have a no-argument `formatted()` method that applies a
///   locale-appropriate default format style.
///
/// Foundation provides format styles for integers (`IntegerFormatStyle`), floating-point numbers
/// (`FloatingPointFormatStyle`), decimals (`Decimal.FormatStyle`), measurements
/// (`Measurement.FormatStyle`), arrays (`ListFormatStyle`), and more. The numeric format styles
/// also provide supporting format styles to format currency and percent values, like
/// `IntegerFormatStyle.Currency` and `Decimal.FormatStyle.Percent`.
///
/// ### Modifying a format style
///
/// Format styles include modifier methods that return a new format style with an adjusted behavior.
/// The following example creates an `IntegerFormatStyle`, then applies modifiers to round values
/// down to the nearest 1,000 and applies formatting appropriate to the `fr_FR` locale:
///
/// ```swift
/// let style = IntegerFormatStyle<Int>()
///     .rounded(rule: .down, increment: 1000)
///     .locale(Locale(identifier: "fr_FR"))
/// let rounded = 123456789.formatted(style) // "123 456 000"
/// ```
///
/// Foundation caches identical instances of a customized format style, so you don't need to pass
/// format style instances around unrelated parts of your app's source code.
///
/// ### Accessing static instances
///
/// Types that conform to `FormatStyle` typically extend the base protocol with type properties or
/// type methods to provide convenience instances. These are available for use in a data type's
/// `formatted(_:)` method when the format style's input type matches the data type. For example,
/// the various numeric format styles define `number` properties with generic constraints to match
/// the different numeric types (`Double`, `Int`, `Float16`, and so on).
///
/// To see how this works, consider this example of a default formatter for an `Int` value. Because
/// `123456789` is a `BinaryInteger`, its `formatted(_:)` method accepts an `IntegerFormatStyle`
/// parameter. The following example shows the style's default behavior in the `en_US` locale.
///
/// ```swift
/// let formatted = 123456789.formatted(IntegerFormatStyle()) // "123,456,789"
/// ```
///
/// `IntegerFormatStyle` extends `FormatStyle` with multiple type properties called `number`, each
/// of which is an `IntegerFormatStyle` instance; these properties differ by which
/// `BinaryInteger`-conforming type they take as input. Since one of these statically-defined
/// properties takes `Int` as its input, you can use this type property instead of instantiating a
/// new format style instance. Using dot notation to access this property on the inferred
/// `FormatStyle` makes the call point much easier to read, as seen here:
///
/// ```swift
/// let formatted = 123456789.formatted(.number) // "123,456,789"
/// ```
///
/// Furthermore, since you can customize these statically-accessed format style instances, you can
/// rewrite the example from the previous section without instantiating a new `IntegerFormatStyle`,
/// like this:
///
/// ```swift
/// let rounded = 123456789.formatted(.number
///     .rounded(rule: .down, increment: 1000)
///     .locale(Locale(identifier: "fr_FR"))) // "123 456 000"
/// ```
///
/// ### Parsing with a format style
///
/// To perform the opposite conversion — from formatted output type to input data type — some
/// format styles provide a corresponding `ParseStrategy` type. These format styles typically expose
/// an instance of this type as a variable, called `parseStrategy`.
///
/// You can use a `ParseStrategy` one of two ways:
///
/// - Initialize the data type by calling an initializer of that type that takes a formatted
///   instance and a parse strategy as parameters. For example, you can create a `Decimal` from a
///   formatted string with the initializer `Decimal.init(_:format:lenient:)`.
/// - Create a parse strategy and call its `parse(_:)` method on one or more formatted instances.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol FormatStyle<FormatInput, FormatOutput> : Codable, Hashable {

    /// The type this format style accepts as input.
    ///
    /// Swift type inference uses this value to determine which static accessors are available at a
    /// given call point. For example, when you format an `Int32`, you can use the static `number`
    /// property that provides a `IntegerFormatStyle<Int32>`, as seen in the following example. This
    /// works because the style's input type `IntegerFormatStyle.FormatInput` is a `BinaryInteger`
    /// generically constrained to the `Int32` type.
    ///
    /// ```swift
    /// let perihelionDistanceToSunInKm: Int32 = 147098291
    /// perihelionDistanceToSunInKm.formatted(.number
    ///     .notation(.scientific)) // "1.470983E8"
    /// ```
    associatedtype FormatInput

    /// The type this format style produces as output.
    ///
    /// Conforming types in Foundation define this type as either `String` or `AttributedString`.
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

    /// Modifies the format style to use the specified locale.
    ///
    /// Use this format style to change the locale used by an existing format style.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: A format style modified to use the provided locale.
    func locale(_ locale: Locale) -> Self
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FormatStyle {
    public func locale(_ locale: Locale) -> Self {
        return self
    }
}
