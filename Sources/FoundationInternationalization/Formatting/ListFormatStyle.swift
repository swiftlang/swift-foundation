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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/// A type that formats lists of items with a separator and conjunction appropriate for a given locale.
///
/// A list format style creates human readable text from a `Sequence` of values. Customize the formatting behavior
/// of the list using the ``width``, ``listType``, and ``locale`` properties. The system automatically caches unique
/// configurations of ``ListFormatStyle`` to enhance performance.
///
/// Use either `formatted()` or `formatted(_:)`, both instance methods of `Sequence`, to create a string
/// representation of the items.
///
/// The `formatted()` method applies the default list format style to a sequence of strings. For example:
///
/// ```swift
/// ["Kristin", "Paul", "Ana", "Bill"].formatted()
/// // Kristin, Paul, Ana, and Bill
/// ```
///
/// You can customize a list's `type` and `width` properties.
///
/// - The ``listType`` property specifies the semantics of the list.
/// - The ``width`` property determines the size of the returned string.
///
/// The `formatted(_:)` method applies a custom list format style. You can use the static factory method
/// `list(type:width:)` to create a custom list format style as a parameter to the method.
///
/// This example formats a sequence with a ``ListType/and`` list type and ``Width/short`` width:
///
/// ```swift
/// ["Kristin", "Paul", "Ana", "Bill"].formatted(.list(type: .and, width: .short))
/// // Kristin, Paul, Ana, & Bill
/// ```
///
/// You can provide a member format style to transform each list element to a string in applications where the
/// elements aren't already strings. For example, the following code sample uses an `IntegerFormatStyle` to convert
/// a range of integer values into a list:
///
/// ```swift
/// (5201719 ... 5201722).formatted(.list(memberStyle: IntegerFormatStyle(), type: .or, width: .standard))
/// // For locale: en_US: 5,201,719, 5,201,720, 5,201,721, or 5,201,722
/// // For locale: fr_CA: 5 201 719, 5 201 720, 5 201 721, ou 5 201 722
/// ```
///
/// > Note:
/// > The generated string is locale-dependent and incorporates linguistic and cultural conventions of the user.
///
/// You can create and reuse a list format style instance to format similar sequences. For example:
///
/// ```swift
/// let percentStyle = ListFormatStyle<FloatingPointFormatStyle.Percent, StrideThrough<Double>>(memberStyle: .percent)
/// stride(from: 7.5, through: 9.0, by: 0.5).formatted(percentStyle)
/// // 7.5%, 8%, 8.5%, and 9%
/// stride(from: 89.0, through: 95.0, by: 2.0).formatted(percentStyle)
/// // 89%, 91%, 93%, and 95%
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ListFormatStyle<Style: FormatStyle, Base: Sequence>: FormatStyle where Base.Element == Style.FormatInput, Style.FormatOutput == String {
    private(set) var memberStyle: Style
    /// The size of the list.
    ///
    /// The `width` property controls the size of the list. The ``locale`` determines the formatting and
    /// abbreviation of the string for the given `width`.
    ///
    /// For example, for English:
    ///
    /// ```swift
    /// ["One", "Two", "Three"].formatted(.list(type: .and, width: .standard))
    /// // "One, Two, and Three"
    ///
    /// ["One", "Two", "Three"].formatted(.list(type: .and, width: .short))
    /// // "One, Two, & Three"
    ///
    /// ["One", "Two", "Three"].formatted(.list(type: .and, width: .narrow))
    /// // "One, Two, Three"
    /// ```
    ///
    /// The default value is ``Width/standard``.
    public var width: Width
    /// The type of the list.
    ///
    /// The list type determines the semantics used in the return string.
    ///
    /// For example, for en\_US:
    ///
    /// ```swift
    /// ["One", "Two", "Three"].formatted(.list(type: .and))
    /// // "One, Two, and Three"
    ///
    /// ["One", "Two", "Three"].formatted(.list(type: .or))
    /// // "One, Two, or Three"
    /// ```
    ///
    /// The default value is ``ListType/and``.
    public var listType: ListType
    /// The locale to use when formatting items in the list.
    ///
    /// A `Locale` instance is typically used to provide, format, and interpret information about and according to
    /// the user's customs and preferences.
    ///
    /// Examples include ISO region and language codes, currency code, calendar, system of measurement, and decimal
    /// separator.
    ///
    /// The default value is `Locale.autoupdatingCurrent`. If you set this property to `nil`, the formatter resets
    /// to using `autoupdatingCurrent`.
    public var locale: Locale

    /// Creates an instance using the provided format style.
    ///
    /// The input type of `memberStyle` must match the type of an element
    /// in the sequence. The output type is a string.
    ///
    /// The following example uses a `FloatingPointFormatStyle.Descriptive`
    /// member style to spell out a list:
    ///
    /// ```swift
    /// [-3.0, 9.0, 11.6].formatted(.list(memberStyle: .descriptive, type: .and))
    /// // minus three, nine, and eleven point six
    /// ```
    ///
    /// - Parameter memberStyle: The format style applied to elements of the sequence.
    public init(memberStyle: Style) {
        self.memberStyle = memberStyle
        self.width = .standard
        self.listType = .and
        self.locale = .autoupdatingCurrent
    }

    /// Creates a locale-aware string representation of the value.
    ///
    /// Once you create a style, you can use it to format similar sequences
    /// multiple times. For example:
    ///
    /// ```swift
    /// let percentStyle = ListFormatStyle<IntegerFormatStyle.Percent, [Int]>(memberStyle: .percent)
    /// percentStyle.format([92, 98]) // 92% and 98%
    /// percentStyle.format([67, 72, 99]) // 67%, 72%, and 99%
    /// ```
    ///
    /// - Parameter value: The sequence of elements to format.
    /// - Returns: A string representation of the provided sequence.
    public func format(_ value: Base) -> String {
        let formatter = ICUListFormatter.formatter(for: self)
        return formatter.format(strings: value.map(memberStyle.format(_:)))
    }

    /// The type representing the width of a list.
    ///
    /// The possible values of a ``ListFormatStyle/width`` are `standard`, `short`, and `narrow`.
    public enum Width: Int, Codable, Sendable {
        /// Specifies a standard list style.
        ///
        /// This width creates a list like `One, Two, and Three` in U.S. English.
        case standard
        /// Specifies a short list style.
        ///
        /// This width creates a list like `One, Two, & Three` in U.S. English.
        case short
        /// Specifies a narrow list style, the shortest list style.
        ///
        /// This width creates a list like `One, Two, Three` in U.S. English.
        case narrow
    }

    /// A type that describes whether the returned list contains cumulative or alternative elements.
    ///
    /// The possible values of a ``ListFormatStyle/listType`` are `and` and `or`.
    public enum ListType: Int, Codable, Sendable {
        /// Specifies an *and* list type.
        ///
        /// This creates a list like `One, Two, and Three` in U.S. English.
        case and
        /// Specifies an *or* list type.
        ///
        /// This creates a list like `One, Two, or Three` in U.S. English.
        case or
    }

    /// Modifies the list format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to use when formatting items in the list.
    /// - Returns: A list format style with the provided locale.
    public func locale(_ locale: Locale) -> Self {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension ListFormatStyle : Sendable where Style : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct StringStyle: FormatStyle, Sendable {
    public func format(_ value: String) -> String { value }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Sequence {
    func formatted<S: FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == Self {
        return style.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Swift.Sequence where Element == String {
    func formatted() -> String {
        return self.formatted(ListFormatStyle(memberStyle: StringStyle()))
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    /// Returns a format style to format a list of items.
    ///
    /// Use the dot-notation form of this type method when the call point allows the use of
    /// ``ListFormatStyle``. You typically do this when calling the `formatted` method of
    /// `Sequence`.
    ///
    /// The following example creates an array of integers, then uses the list format style
    /// provided by this method to format the items. By using a currency ``IntegerFormatStyle``,
    /// the list format style expresses each member as US dollars.
    ///
    /// ```swift
    /// let items: [Int] = [100, 1000, 10000, 100000, 1000000]
    /// let formatted = items.formatted(
    ///     .list(memberStyle: .currency(code: "USD"),
    ///           type: .and)
    ///     .locale(Locale(identifier: "en_US"))) // "$100.00, $1,000.00, $10,000.00, $100,000.00, and $1,000,000.00"
    /// ```
    ///
    /// - Parameters:
    ///   - memberStyle: The format style to apply to each item in the list.
    ///   - type: The list type to apply, such as cumulative (``ListFormatStyle/ListType/and``)
    ///     or alternative (``ListFormatStyle/ListType/or``) elements.
    ///   - width: The width to use when formatting, such as ``ListFormatStyle/Width/standard``
    ///     or ``ListFormatStyle/Width/narrow``.
    /// - Returns: A list format style that formats an array as a textual list of items.
    static func list<MemberStyle, Base>(memberStyle: MemberStyle, type: Self.ListType, width: Self.Width = .standard) -> Self where Self == ListFormatStyle<MemberStyle, Base> {
        var style = ListFormatStyle<MemberStyle, Base>(memberStyle: memberStyle)
        style.width = width
        style.listType = type
        return style
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    /// Returns a format style to format a list of strings.
    ///
    /// Use the dot-notation form of this type method when the call point allows the use of
    /// ``ListFormatStyle``, and the `Sequence` element type is `String`. You typically do this
    /// when calling the `formatted` method of `Sequence`.
    ///
    /// The following example creates an array of strings, then uses the list format style
    /// provided by this method to format the items.
    ///
    /// ```swift
    /// let items = ["Atlantic", "Pacific", "Indian", "Arctic", "Southern"]
    /// let formatted = items.formatted(
    ///     .list(type:.and)
    ///     .locale(Locale(identifier: "en_US"))) // "Atlantic, Pacific, Indian, Arctic, and Southern"
    /// ```
    ///
    /// - Parameters:
    ///   - type: The list type to apply, such as cumulative (``ListFormatStyle/ListType/and``)
    ///     or alternative (``ListFormatStyle/ListType/or``) elements.
    ///   - width: The width to use when formatting, such as ``ListFormatStyle/Width/standard``
    ///     or ``ListFormatStyle/Width/narrow``.
    /// - Returns: A list format style that formats a string array as a textual list of items.
    static func list<Base>(type: Self.ListType, width: Self.Width = .standard) -> Self where Self == ListFormatStyle<StringStyle, Base> {
        var style = ListFormatStyle<StringStyle, Base>(memberStyle: StringStyle())
        style.width = width
        style.listType = type
        return style
    }
}
