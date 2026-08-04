//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/// A structure that converts between integer values and their textual representations.
///
/// Instances of ``IntegerFormatStyle`` create localized, human-readable text from <doc://com.apple.documentation/documentation/swift/binaryinteger> numbers and parse string representations of numbers into instances of <doc://com.apple.documentation/documentation/swift/binaryinteger> types. All of the Swift standard library's integer types, such as <doc://com.apple.documentation/documentation/swift/int> and <doc://com.apple.documentation/documentation/swift/uint32>, conform to <doc://com.apple.documentation/documentation/swift/binaryinteger>, and therefore work with this format style.
///
/// ``IntegerFormatStyle`` includes two nested types, ``Percent`` and ``Currency``, for working with percentages and currencies. Each format style includes a configuration that determines how it represents numeric values, for things like grouping, displaying signs, and variant presentations like scientific notation. ``IntegerFormatStyle`` and ``Percent`` include a ``NumberFormatStyleConfiguration``, and ``Currency`` includes a ``CurrencyFormatStyleConfiguration``. You can customize numeric formatting for a style by adjusting its backing configuration. The system automatically caches unique configurations of a format style to enhance performance.
///
/// > Note:
/// > Foundation provides another format style type, ``FloatingPointFormatStyle``, for working with numbers that conform to <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint>. For Foundation's ``Decimal`` type, use ``Decimal/FormatStyle``.
///
///
///
/// ### Formatting integers
///
/// Use the <doc://com.apple.documentation/documentation/swift/binaryinteger/formatted()> method to create a string representation of an integer using the default ``IntegerFormatStyle`` configuration.
///
/// ```swift
/// let formattedDefault = 123456.formatted()
/// // formattedDefault is "123,456" in en_US locale.
/// // Other locales may use different separator and grouping behavior.
/// ```
///
///
/// You can specify a format style by providing an argument to the <doc://com.apple.documentation/documentation/swift/binaryinteger/formatted(_:)-73k3e> method. The following example shows the number `12345` represented in each of the available styles, in the `en_US` locale:
///
/// ```swift
/// let number = 123456
///
/// let formattedNumber = number.formatted(.number)
/// // formattedNumber is "123,456".
///
/// let formattedPercent = number.formatted(.percent)
/// // formattedPercent is "123,456%".
///
/// let formattedCurrency = number.formatted(.currency(code: "USD"))
/// // formattedCurrency is "$123,456.00".
/// ```
///
///
/// Each style provides methods for updating its numeric configuration, including the number of significant digits, grouping length, and more. You can specify a numeric configuration by calling as many of these methods as you need in any order you choose. The following example shows the same number with default and custom configurations:
///
/// ```swift
/// let exampleNumber = 123456
///
/// let defaultFormatting = exampleNumber.formatted(.number)
/// // defaultFormatting is "125 000" for the "fr_FR" locale
/// // defaultFormatting is "125000" for the "jp_JP" locale
/// // defaultFormatting is "125,000" for the "en_US" locale
///
/// let customFormatting = exampleNumber.formatted(
/// .number
/// .grouping(.never)
/// .sign(strategy: .always()))
/// // customFormatting is "+123456"
/// ```
///
///
///
///
/// ### Creating an integer format style instance
///
/// The previous examples use static factory methods like ``FormatStyle/number-7fxvo`` to create format styles within the call to the <doc://com.apple.documentation/documentation/swift/binaryinteger/formatted(_:)-73k3e> method. You can also create an ``IntegerFormatStyle`` instance and use it to repeatedly format different values with the ``format(_:)`` method:
///
/// ```swift
/// let percentFormatStyle = IntegerFormatStyle<Int>.Percent()
///
/// percentFormatStyle.format(50) // "50%"
/// percentFormatStyle.format(85) // "85%"
/// percentFormatStyle.format(100) // "100%"
/// ```
///
///
///
///
/// ### Parsing integers
///
/// You can use ``IntegerFormatStyle`` to parse strings into integer values. You can define the format style within the type's initializer or pass in a format style you create prior to calling the method, as shown here:
///
/// ```swift
/// let price = try? Int("$123,456",
/// format: .currency(code: "USD")) // 123456
///
/// let priceFormatStyle = IntegerFormatStyle<Int>.Currency(code: "USD")
/// let salePrice = try? Int("$120,000",
/// format: priceFormatStyle) // 120000
/// ```
///
///
///
///
/// ### Matching regular expressions
///
/// Along with parsing numeric values in strings, you can use the Swift regular expression domain-specific language to match and capture numeric substrings. The following example defines a currency format style to match and capture a currency value using US dollars and `en_US` numeric conventions. The rest of the regular expression ignores any characters prior to a `": "` sequence that precedes the currency substring.
///
/// ```swift
/// import RegexBuilder
///
/// let source = "Payment due: $123,456"
/// let matcher = Regex {
/// OneOrMore(.any)
/// ": "
/// Capture {
/// One(.localizedIntegerCurrency(code: Locale.Currency("USD"),
/// locale: Locale(identifier: "en_US")))
/// }
/// }
/// let match = source.firstMatch(of: matcher)
/// let localizedInteger = match?.1 // 123456
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct IntegerFormatStyle<Value: BinaryInteger>: Codable, Hashable, Sendable {
    public typealias Configuration = NumberFormatStyleConfiguration

    /// The locale of the format style.
    ///
    /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
    public var locale: Locale
    internal var collection: Configuration.Collection = Configuration.Collection()

    /// Creates an integer format style that uses the given locale.
    ///
    /// Create an ``IntegerFormatStyle`` when you intend to apply a given style to multiple integers.
    /// The following example creates a style that uses the `en_US` locale, which uses three-based
    /// grouping and comma separators. It then applies this style to all the integers in an array.
    ///
    /// ```swift
    /// let enUSstyle = IntegerFormatStyle<Int>(locale: Locale(identifier: "en_US"))
    /// let nums = [100, 1000, 10000, 100000, 1000000]
    /// let formattedNums = nums.map { enUSstyle.format($0) } // ["100", "1,000", "10,000", "100,000", "1,000,000"]
    /// ```
    ///
    /// To format a single integer, you can use the `BinaryInteger` instance method `formatted(_:)`,
    /// passing in an instance of ``IntegerFormatStyle``.
    ///
    /// - Parameter locale: The locale to use when formatting or parsing integers.
    ///   Defaults to `Locale.autoupdatingCurrent`.
    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    /// An attributed format style based on the integer format style.
    ///
    /// Use this modifier to create an ``IntegerFormatStyle/Attributed`` instance, which formats
    /// values as ``AttributedString`` instances. These attributed strings contain attributes from
    /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
    /// these attributes to determine which runs of the attributed string represent different
    /// parts of the formatted value.
    public var attributed: IntegerFormatStyle.Attributed {
        return IntegerFormatStyle.Attributed(style: self)
    }


    /// Modifies the format style to use the specified grouping.
    ///
    /// The following example creates a default ``IntegerFormatStyle`` for the `en_US` locale,
    /// and a second style that never uses grouping. It then applies each style to an array of
    /// integers. The formatting that the modified style applies eliminates the three-digit
    /// grouping usually performed for the `en_US` locale.
    ///
    /// ```swift
    /// let defaultStyle = IntegerFormatStyle<Int>(locale: Locale(identifier: "en_US"))
    /// let neverStyle = defaultStyle.grouping(.never)
    /// let nums = [100, 1000, 10000, 100000, 1000000]
    /// let defaultNums = nums.map { defaultStyle.format($0) } // ["100", "1,000", "10,000", "100,000", "1,000,000"]
    /// let neverNums = nums.map { neverStyle.format($0) } // ["100", "1000", "10000", "100000", "1000000"]
    /// ```
    ///
    /// - Parameter group: The grouping to apply to the format style.
    /// - Returns: An integer format style modified to use the specified grouping.
    public func grouping(_ group: Configuration.Grouping) -> Self {
        var new = self
        new.collection.group = group
        return new
    }

    /// Modifies the format style to use the specified precision.
    ///
    /// - Parameter p: The precision to apply to the format style.
    /// - Returns: An integer format style modified to use the specified precision.
    public func precision(_ p: Configuration.Precision) -> Self {
        var new = self
        new.collection.precision = p
        return new
    }

    /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
    ///
    /// - Parameter strategy: The sign display strategy to apply to the format style.
    /// - Returns: An integer format style modified to use the specified sign display strategy.
    public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
        var new = self
        new.collection.signDisplayStrategy = strategy
        return new
    }

    /// Modifies the format style to use the specified decimal separator display strategy.
    ///
    /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
    /// - Returns: An integer format style modified to use the specified decimal separator display strategy.
    public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
        var new = self
        new.collection.decimalSeparatorStrategy = strategy
        return new
    }

    /// Modifies the format style to use the specified rounding rule and increment.
    ///
    /// - Parameters:
    ///   - rule: The rounding rule to apply to the format style.
    ///   - increment: A multiple by which the formatter rounds the fractional part. The formatter
    ///     produces a value that is an even multiple of this increment. If this parameter is
    ///     `nil` (the default), the formatter doesn't apply an increment.
    /// - Returns: An integer format style modified to use the specified rounding rule and increment.
    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
        var new = self
        new.collection.rounding = rule
        if let increment = increment {
            new.collection.roundingIncrement = .integer(value: increment)
        }
        return new
    }

    /// Modifies the format style to use the specified scale.
    ///
    /// - Parameter multiplicand: The multiplicand to apply to the format style.
    /// - Returns: An integer format style modified to use the specified scale.
    public func scale(_ multiplicand: Double) -> Self {
        var new = self
        new.collection.scale = multiplicand
        return new
    }

    /// Modifies the format style to use the specified notation.
    ///
    /// - Parameter notation: The notation to apply to the format style.
    /// - Returns: An integer format style modified to use the specified notation.
    public func notation(_ notation: Configuration.Notation) -> Self {
        var new = self
        new.collection.notation = notation
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle {
    /// A format style that converts between integer percentage values and their textual representations.
    public struct Percent : Codable, Hashable, Sendable {
        public typealias Configuration = NumberFormatStyleConfiguration

        /// The locale of the format style.
        ///
        /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale
        // Specifically set scale to 1 so `42` is formatted as `42%`.
        var collection: Configuration.Collection = Configuration.Collection(scale: 1)

        /// Creates an integer percent format style that uses the given locale.
        ///
        /// - Parameter locale: The locale to use when formatting or parsing integers.
        ///   Defaults to `Locale.autoupdatingCurrent`.
        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        /// An attributed format style based on the integer percent format style.
        ///
        /// Use this modifier to create an ``IntegerFormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: IntegerFormatStyle.Attributed {
            return IntegerFormatStyle.Attributed(style: self)
        }

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified decimal separator display strategy.
        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified rounding rule and increment.
        ///
        /// - Parameters:
        ///   - rule: The rounding rule to apply to the format style.
        ///   - increment: A multiple by which the formatter rounds the fractional part. The formatter
        ///     produces a value that is an even multiple of this increment. If this parameter is
        ///     `nil` (the default), the formatter doesn't apply an increment.
        /// - Returns: An integer percent format style modified to use the specified rounding rule and increment.
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .integer(value: increment)
            }
            return new
        }

        /// Modifies the format style to use the specified scale.
        ///
        /// - Parameter multiplicand: The multiplicand to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified scale.
        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: An integer percent format style modified to use the specified notation.
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }
    }

    /// A format style that converts between integer currency values and their textual representations.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Codable, Hashable, Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration

        /// The locale of the format style.
        ///
        /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale

        /// The currency code this format style uses, such as `USD` or `EUR`.
        public let currencyCode: String

        internal var collection: Configuration.Collection

        /// Creates an integer currency format style that uses the given currency code and locale.
        ///
        /// - Parameters:
        ///   - code: The currency code to use, such as `EUR` or `JPY`.
        ///   - locale: The locale to use when formatting or parsing integers.
        ///     Defaults to `Locale.autoupdatingCurrent`.
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        /// An attributed format style based on the integer currency format style.
        ///
        /// Use this modifier to create an ``IntegerFormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: IntegerFormatStyle.Attributed {
            return IntegerFormatStyle.Attributed(style: self)
        }

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified decimal separator display strategy.
        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified rounding rule and increment.
        ///
        /// - Parameters:
        ///   - rule: The rounding rule to apply to the format style.
        ///   - increment: A multiple by which the formatter rounds the fractional part. The formatter
        ///     produces a value that is an even multiple of this increment. If this parameter is
        ///     `nil` (the default), the formatter doesn't apply an increment.
        /// - Returns: An integer currency format style modified to use the specified rounding rule and increment.
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .integer(value: increment)
            }
            return new
        }

        /// Modifies the format style to use the specified scale.
        ///
        /// - Parameter multiplicand: The multiplicand to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified scale.
        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        /// Modifies the format style to use the specified presentation.
        ///
        /// - Parameter p: A currency presentation value, such as
        ///   ``CurrencyFormatStyleConfiguration/Presentation/isoCode`` or
        ///   ``CurrencyFormatStyleConfiguration/Presentation/fullName``.
        /// - Returns: An integer currency format style modified to use the specified presentation.
        public func presentation(_ p: Configuration.Presentation) -> Self {
            var new = self
            new.collection.presentation = p
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified notation.
        @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }
    }
}

// MARK: - FormatStyle conformance

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle : FormatStyle {
    /// Returns a localized string for the given integer value.
    ///
    /// Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
    ///
    /// - Parameter value: The value to be formatted.
    /// - Returns: A localized string for the given value.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func format(_ value: Value) -> String {
        if let nf = ICUNumberFormatter.create(for: self) {
            let str: String?
            // Formatting Int64 is the fastest option -- try that first.
            if let i = Int64(exactly: value) {
                str = nf.format(i)
            } else {
                str = nf.format(value.numericStringRepresentation)
            }

            if let str {
                return str
            }
        }
        return String(value)
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: An integer format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> IntegerFormatStyle {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Percent : FormatStyle {
    /// Returns a localized string for the given value in percentage.
    ///
    /// Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
    ///
    /// - Parameter value: The value to be formatted.
    /// - Returns: A localized string for the given value in percentage.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func format(_ value: Value) -> String {
        if let nf = ICUPercentNumberFormatter.create(for: self) {
            let str: String?
            // Formatting Int64 is the fastest option -- try that first.
            if let i = Int64(exactly: value) {
                str = nf.format(i)
            } else {
                str = nf.format(value.numericStringRepresentation)
            }

            if let str {
                return str
            }
        }
        return String(value)
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: An integer percent format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> IntegerFormatStyle.Percent {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Currency : FormatStyle {
    /// Returns a localized currency string for the given value.
    ///
    /// Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
    ///
    /// - Parameter value: The value to be formatted.
    /// - Returns: A localized currency string for the given value.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func format(_ value: Value) -> String {
        if let nf = ICUCurrencyNumberFormatter.create(for: self) {
            let str: String?
            // Formatting Int64 is the fastest option -- try that first.
            if let i = Int64(exactly: value) {
                str = nf.format(i)
            } else {
                str = nf.format(value.numericStringRepresentation)
            }

            if let str {
                return str
            }
        }
        return String(value)
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: An integer currency format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> IntegerFormatStyle.Currency {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: - FormatStyle protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Currency: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Percent: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}

// MARK: - `FormatStyle` protocol membership

// MARK: Number

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int> {
    /// A style for formatting the Swift default integer type.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int16> {
    /// A style for formatting 16-bit signed integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int32> {
    /// A style for formatting 32-bit signed integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int64> {
    /// A style for formatting 64-bit signed integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int8> {
    /// A style for formatting 8-bit signed integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt> {
    /// A style for formatting the Swift unsigned integer type.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt16> {
    /// A style for formatting 16-bit unsigned integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt32> {
    /// A style for formatting 32-bit unsigned integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt64> {
    /// A style for formatting 64-bit unsigned integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt8> {
    /// A style for formatting 8-bit unsigned integers.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

// MARK: Percent


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int>.Percent {
    /// A style for formatting signed integer types in Swift as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int16>.Percent {
    /// A style for formatting 16-bit signed integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int32>.Percent {
    /// A style for formatting 32-bit signed integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int64>.Percent {
    /// A style for formatting 64-bit signed integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int8>.Percent {
    /// A style for formatting 8-bit signed integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt>.Percent {
    /// A style for formatting signed integer types in Swift as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt16>.Percent {
    /// A style for formatting 16-bit unsigned integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt32>.Percent {
    /// A style for formatting 32-bit unsigned integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt64>.Percent {
    /// A style for formatting 64-bit unsigned integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt8>.Percent {
    /// A style for formatting 8-bit unsigned integers as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``IntegerFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryInteger`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

// MARK: Currency

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    /// Returns a format style to use integer currency notation.
    ///
    /// Use the dot-notation form of this method when the call point allows the use of
    /// ``IntegerFormatStyle``. You typically do this when calling the `formatted` methods of
    /// types that conform to `BinaryInteger`.
    ///
    /// The following example creates an array of integers, then uses the currency style
    /// provided by this method to format the integers as US dollars:
    ///
    /// ```swift
    /// let nums: [Int] = [100, 1000, 10000, 100000, 1000000]
    /// let currencyNums = nums.map { $0.formatted(
    ///     .currency(code:"USD")) } // ["$100.00", "$1,000.00", "$10,000.00", "$100,000.00", "$1,000,000.00"]
    /// ```
    ///
    /// - Parameter code: The currency code to use, such as `EUR` or `JPY`. See ISO-4217 for
    ///   a list of valid codes.
    /// - Returns: An integer format style that uses the specified currency code.
    static func currency<V: BinaryInteger>(code: String) -> Self where Self == IntegerFormatStyle<V>.Currency {
        return Self(code: code)
    }
}

// MARK: - Attributed string

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle {
    /// A format style that converts integers into attributed strings.
    ///
    /// Use the ``IntegerFormatStyle/attributed`` modifier on a ``FloatingPointFormatStyle`` to create a format style of this type.
    ///
    /// The attributed strings that this format style creates contain attributes from the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use these attributes to determine which runs of the attributed string represent different parts of the formatted value.
    ///
    /// The following example finds runs of the attributed string that represent different parts of a formatted currency, and adds additional attributes like ``AttributeScopes/SwiftUIAttributes/foregroundColor`` and ``AttributeScopes/FoundationAttributes/inlinePresentationIntent``.
    ///
    /// ```swift
    /// func attributedPrice(price: Decimal) -> AttributedString {
    /// var attributedPrice = price.formatted(
    /// .currency(code: "USD")
    /// .attributed)
    ///
    /// for run in attributedPrice.runs {
    /// if run.attributes.numberSymbol == .currency ||
    /// run.attributes.numberSymbol == .decimalSeparator  {
    /// attributedPrice[run.range].foregroundColor = .red
    /// }
    /// if run.attributes.numberPart == .integer ||
    /// run.attributes.numberPart == .fraction {
    /// attributedPrice[run.range].inlinePresentationIntent = [.stronglyEmphasized]
    /// }
    /// }
    /// return attributedPrice
    /// }
    /// ```
    ///
    ///
    /// User interface frameworks like SwiftUI can use these attributes when presenting the attributed string, as seen here:
    ///
    /// ![The currency value $1,234.56, with the dollar sign and decimal separator in red, and the digits in bold.](media-4099417)
    public struct Attributed : Codable, Hashable, FormatStyle, Sendable {
        enum Style : Codable, Hashable {
            case integer(IntegerFormatStyle)
            case percent(IntegerFormatStyle.Percent)
            case currency(IntegerFormatStyle.Currency)
            
            private typealias IntegerCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias PercentCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias CurrencyCodingKeys = DefaultAssociatedValueCodingKeys1
        }

        var style: Style

        init(style: IntegerFormatStyle) {
            self.style = .integer(style)
        }

        init(style: IntegerFormatStyle.Percent) {
            self.style = .percent(style)
        }

        init(style: IntegerFormatStyle.Currency) {
            self.style = .currency(style)
        }

        /// Formats an integer, using this style.
        ///
        /// Values not representable by `Int64` are clamped.
        ///
        /// - Parameter value: The integer to format.
        /// - Returns: An attributed string representation of `value`, formatted according to the
        ///   style's configuration. The returned string contains attributes from the
        ///   ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope to
        ///   indicate runs formatted by this format style.
        public func format(_ value: Value) -> AttributedString {
            // Formatting Int64 is the fastest option -- try that first.
            let numberValue: ICUNumberFormatterBase.Value
            if let i = Int64(exactly: value) {
                numberValue = .integer(i)
            } else {
                numberValue = .numericStringRepresentation(value.numericStringRepresentation)
            }

            switch style {
            case .integer(let formatStyle):
                if let formatter = ICUNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(numberValue)
                }
            case .currency(let formatStyle):
                if let formatter = ICUCurrencyNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(numberValue)
                }
            case .percent(let formatStyle):
                if let formatter = ICUPercentNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(numberValue)
                }
            }

            // Fallback option
            return AttributedString(String(value).description)
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A format style that uses the specified locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            switch style {
            case .integer(var style):
                style.locale = locale
                new.style = .integer(style)
            case .currency(var style):
                style.locale = locale
                new.style = .currency(style)
            case .percent(var style):
                style.locale = locale
                new.style = .percent(style)
            }
            return new
        }
    }
}

// MARK: Pattern Matching

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension IntegerFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value

    /// Matches the input string within the specified bounds, beginning at the given index.
    ///
    /// Don't call this method directly. Regular expression matching and capture calls it
    /// automatically when matching substrings.
    ///
    /// - Parameters:
    ///   - input: An input string to match against.
    ///   - index: The index within `input` at which to begin searching.
    ///   - bounds: The bounds within `input` in which to search.
    /// - Returns: The upper bound where the match terminates and a matched instance, or `nil` if there isn't a match.
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        try IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension IntegerFormatStyle.Percent : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value

    /// Matches the input string within the specified bounds, beginning at the given index.
    ///
    /// Don't call this method directly. Regular expression matching and capture calls it
    /// automatically when matching substrings.
    ///
    /// - Parameters:
    ///   - input: An input string to match against.
    ///   - index: The index within `input` at which to begin searching.
    ///   - bounds: The bounds within `input` in which to search.
    /// - Returns: The upper bound where the match terminates and a matched instance, or `nil` if there isn't a match.
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        try IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension IntegerFormatStyle.Currency : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value

    /// Matches the input string within the specified bounds, beginning at the given index.
    ///
    /// Don't call this method directly. Regular expression matching and capture calls it
    /// automatically when matching substrings.
    ///
    /// - Parameters:
    ///   - input: An input string to match against.
    ///   - index: The index within `input` at which to begin searching.
    ///   - bounds: The bounds within `input` in which to search.
    /// - Returns: The upper bound where the match terminates and a matched instance, or `nil` if there isn't a match.
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        try IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == IntegerFormatStyle<Int> {
    /// Creates a regex component to match a localized integer string and capture it as a `Int`.
    /// - Parameter locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized integer string.
    public static func localizedInteger(locale: Locale) -> Self {
        IntegerFormatStyle(locale: locale)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == IntegerFormatStyle<Int>.Percent {
    /// Creates a regex component to match a localized string representing a percentage and capture it as a `Int`.
    /// - Parameter locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized string representing a percentage.
    public static func localizedIntegerPercentage(locale: Locale) -> Self {
        IntegerFormatStyle.Percent(locale: locale)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == IntegerFormatStyle<Int>.Currency {
    /// Creates a regex component to match a localized currency string and capture it as a `Int`. For example, `localizedIntegerCurrency(code: "USD", locale: Locale(identifier: "en_US"))` matches "$52,249" and captures it as 52249.
    /// - Parameters:
    ///   - code: The currency code of the currency symbol or name in the string.
    ///   - locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized currency string.
    public static func localizedIntegerCurrency(code: Locale.Currency, locale: Locale) -> Self {
        IntegerFormatStyle.Currency(code: code.identifier, locale: locale)
    }
}
