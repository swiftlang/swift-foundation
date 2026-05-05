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


/// A structure that converts between floating-point values and their textual representations.
///
/// Instances of ``FloatingPointFormatStyle`` create localized, human-readable text from <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint> numbers and parse string representations of numbers into instances of <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint> types. All of the Swift standard library's floating-point types, such as <doc://com.apple.documentation/documentation/swift/double>, <doc://com.apple.documentation/documentation/swift/float>, and <doc://com.apple.documentation/documentation/swift/float80>, conform to <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint>, and therefore work with this format style.
///
/// ``FloatingPointFormatStyle`` includes two nested types, ``Percent`` and ``Currency``, for working with percentages and currencies, respectively. Each format style includes a configuration that determines how it represents numeric values, for things like grouping, displaying signs, and variant presentations like scientific notation. ``FloatingPointFormatStyle`` and ``Percent`` include a ``NumberFormatStyleConfiguration``, and ``Currency`` includes a ``CurrencyFormatStyleConfiguration``. You can customize numeric formatting for a style by adjusting its backing configuration. The system automatically caches unique configurations of a format style to enhance performance.
///
/// > Note:
/// > Foundation provides another format style type, ``IntegerFormatStyle``, for working with numbers that conform to <doc://com.apple.documentation/documentation/swift/binaryinteger>. For Foundation's ``Decimal`` type, use ``Decimal/FormatStyle``.
///
/// ### Formatting floating-point values
///
/// Use the <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint/formatted()> method to create a string representation of a floating-point value using the default ``FloatingPointFormatStyle`` configuration.
///
/// ```swift
/// let formattedDefault = 12345.67.formatted()
/// // formattedDefault is "12,345.67" in the en_US locale.
/// // Other locales may use different separator and grouping behavior.
/// ```
///
///
/// You can specify a format style by providing an argument to the <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint/formatted(_:)-4ksqj> method. The following example shows the number `0.1` represented in each of the available styles, in the `en_US` locale:
///
/// ```swift
/// let number = 0.1
///
/// let formattedNumber = number.formatted(.number)
/// // formattedNumber is "0.1".
///
/// let formattedPercent = number.formatted(.percent)
/// // formattedPercent is "10%".
///
/// let formattedCurrency = number.formatted(.currency(code: "USD"))
/// // formattedCurrency is "$0.10".
/// ```
///
///
/// Each style provides methods for updating its numeric configuration, including the number of significant digits, grouping length, and more. You can specify a numeric configuration by calling as many of these methods as you need in any order you choose. The following example shows the same number with default and custom configurations:
///
/// ```swift
/// let exampleNumber = 123456.78
///
/// let defaultFormatting = exampleNumber.formatted(.number)
/// // defaultFormatting is "123 456,78" for the "fr_FR" locale.
/// // defaultFormatting is "123,456.78" for the "en_US" locale.
///
/// let customFormatting = exampleNumber.formatted(
/// .number
/// .grouping(.never)
/// .sign(strategy: .always()))
/// // customFormatting is "+123456.78"
/// ```
///
///
///
///
/// ### Creating a floating-point format style instance
///
/// The previous examples use static factory methods like ``FormatStyle/number-8c8rj`` to create format styles within the call to the <doc://com.apple.documentation/documentation/swift/binaryfloatingpoint/formatted(_:)-4ksqj> method. You can also create a ``FloatingPointFormatStyle`` instance and use it to repeatedly format different values, with the ``format(_:)`` method:
///
/// ```swift
/// let percentFormatStyle = FloatingPointFormatStyle<Double>.Percent()
///
/// percentFormatStyle.format(0.5) // "50%"
/// percentFormatStyle.format(0.855) // "85.5%"
/// percentFormatStyle.format(1.0) // "100%"
///
/// ```
///
///
///
///
/// ### Parsing floating-point values
///
/// You can use ``FloatingPointFormatStyle`` to parse strings into floating-point values. You can define the format style within the type's initializer or pass in a format style created outside the function, as shown here:
///
/// ```swift
/// let price = try? Double("$3,500.63",
/// format: .currency(code: "USD")) // 3500.63
///
/// let priceFormatStyle = FloatingPointFormatStyle<Double>.Currency(code: "USD")
/// let salePrice = try? Double("$731.67",
/// format: priceFormatStyle) // 731.67
/// ```
///
///
///
///
/// ### Matching regular expressions
///
/// Along with parsing numeric values in strings, you can use theSwift regular expression domain-specific language to match and capture numeric substrings. The following example defines a percentage format style to match a percentage value using `en_US` numeric conventions. The rest of the regular expression ignores any characters prior to a `": "` sequence that precedes the percentage substring.
///
/// ```swift
/// import RegexBuilder
/// let source = "Percentage complete: 55.1%"
/// let matcher = Regex {
/// OneOrMore(.any)
/// ": "
/// Capture {
/// One(.localizedDoublePercentage(locale: Locale(identifier: "en_US")))
/// }
/// }
/// let match = source.firstMatch(of: matcher)
/// let localizedPercentage = match?.1
/// print("\(localizedPercentage!)") // 0.551
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FloatingPointFormatStyle<Value: BinaryFloatingPoint>: Codable, Hashable, Sendable {
    /// The locale of the format style.
    ///
    /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
    public var locale: Locale

    /// Creates a floating-point format style that uses the given locale.
    ///
    /// Create a ``FloatingPointFormatStyle`` when you intend to apply a given style to multiple
    /// floating-point values. The following example creates a style that uses the `en_US` locale,
    /// which uses three-based grouping and comma separators. It then applies this style to all the
    /// `Double` values in an array.
    ///
    /// ```swift
    /// let enUSstyle = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US"))
    /// let nums = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
    /// let formattedNums = nums.map { enUSstyle.format($0) } // ["100.1", "1,000.2", "10,000.3", "100,000.4", "1,000,000.5"]
    /// ```
    ///
    /// To format a single value, you can use the `BinaryFloatingPoint` instance method `formatted(_:)`,
    /// passing in an instance of ``FloatingPointFormatStyle``.
    ///
    /// - Parameter locale: The locale to use when formatting or parsing floating-point values.
    ///   Defaults to `Locale.autoupdatingCurrent`.
    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    /// An attributed format style based on the floating-point format style.
    ///
    /// Use this modifier to create a ``FloatingPointFormatStyle/Attributed`` instance, which formats
    /// values as ``AttributedString`` instances. These attributed strings contain attributes from
    /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
    /// these attributes to determine which runs of the attributed string represent different
    /// parts of the formatted value.
    public var attributed: FloatingPointFormatStyle.Attributed {
        return FloatingPointFormatStyle.Attributed(style: self)
    }

    public typealias Configuration = NumberFormatStyleConfiguration
    internal var collection: Configuration.Collection = Configuration.Collection()

    /// Modifies the format style to use the specified grouping.
    ///
    /// - Parameter group: The grouping to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified grouping.
    public func grouping(_ group: Configuration.Grouping) -> Self {
        var new = self
        new.collection.group = group
        return new
    }

    /// Modifies the format style to use the specified precision.
    ///
    /// - Parameter p: The precision to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified precision.
    public func precision(_ p: Configuration.Precision) -> Self {
        var new = self
        new.collection.precision = p
        return new
    }

    /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
    ///
    /// - Parameter strategy: The sign display strategy to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified sign display strategy.
    public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
        var new = self
        new.collection.signDisplayStrategy = strategy
        return new
    }

    /// Modifies the format style to use the specified decimal separator display strategy.
    ///
    /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified decimal separator display strategy.
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
    /// - Returns: A floating-point format style modified to use the specified rounding rule and increment.
    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
        var new = self
        new.collection.rounding = rule
        if let increment = increment {
            new.collection.roundingIncrement = .floatingPoint(value: increment)
        }
        return new
    }

    /// Modifies the format style to use the specified scale.
    ///
    /// - Parameter multiplicand: The multiplicand to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified scale.
    public func scale(_ multiplicand: Double) -> Self {
        var new = self
        new.collection.scale = multiplicand
        return new
    }

    /// Modifies the format style to use the specified notation.
    ///
    /// - Parameter notation: The notation to apply to the format style.
    /// - Returns: A floating-point format style modified to use the specified notation.
    public func notation(_ notation: Configuration.Notation) -> Self {
        var new = self
        new.collection.notation = notation
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle {
    /// A format style that converts between floating-point percentage values and their textual representations.
    public struct Percent : Codable, Hashable, Sendable {
        /// The locale of the format style.
        ///
        /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale

        /// Creates a floating-point percent format style that uses the given locale.
        ///
        /// - Parameter locale: The locale to use when formatting or parsing floating-point values.
        ///   Defaults to `Locale.autoupdatingCurrent`.
        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        /// An attributed format style based on the floating-point percent format style.
        ///
        /// Use this modifier to create a ``FloatingPointFormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: FloatingPointFormatStyle.Attributed {
            return FloatingPointFormatStyle.Attributed(style: self)
        }

        public typealias Configuration = NumberFormatStyleConfiguration

        // Set scale to 100 so we format 0.42 as "42%" instead of "0.42%"
        var collection: Configuration.Collection = Configuration.Collection(scale: 100)

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified decimal separator display strategy.
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
        /// - Returns: A floating-point percent format style modified to use the specified rounding rule and increment.
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .floatingPoint(value: increment)
            }
            return new
        }

        /// Modifies the format style to use the specified scale.
        ///
        /// - Parameter multiplicand: The multiplicand to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified scale.
        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A floating-point percent format style modified to use the specified notation.
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }
    }

    /// A format style that converts between floating-point currency values and their textual representations.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Codable, Hashable, Sendable {
        /// The locale of the format style.
        ///
        /// Use the ``FormatStyle/locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale

        /// The currency code this format style uses, such as `USD` or `EUR`.
        public let currencyCode: String

        public typealias Configuration = CurrencyFormatStyleConfiguration
        internal var collection: Configuration.Collection

        /// Creates a floating-point currency format style that uses the given currency code and locale.
        ///
        /// - Parameters:
        ///   - code: The currency code to use, such as `EUR` or `JPY`.
        ///   - locale: The locale to use when formatting or parsing floating-point values.
        ///     Defaults to `Locale.autoupdatingCurrent`.
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        /// An attributed format style based on the floating-point currency format style.
        ///
        /// Use this modifier to create a ``FloatingPointFormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: FloatingPointFormatStyle.Attributed {
            return FloatingPointFormatStyle.Attributed(style: self)
        }

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified decimal separator display strategy.
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
        /// - Returns: A floating-point currency format style modified to use the specified rounding rule and increment.
        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .floatingPoint(value: increment)
            }
            return new
        }

        /// Modifies the format style to use the specified scale.
        ///
        /// - Parameter multiplicand: The multiplicand to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified scale.
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
        /// - Returns: A floating-point currency format style modified to use the specified presentation.
        public func presentation(_ p: Configuration.Presentation) -> Self {
            var new = self
            new.collection.presentation = p
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified notation.
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
extension FloatingPointFormatStyle : FormatStyle {
    /// Formats a floating-point value, using this style.
    ///
    /// Use this method when you want to create a single style instance and use it to format multiple
    /// floating-point values. The following example creates a style that uses the `en_US` locale,
    /// then adds the ``NumberFormatStyleConfiguration/Notation/scientific`` modifier. It applies this
    /// style to all the floating-point values in an array.
    ///
    /// ```swift
    /// let scientificStyle = FloatingPointFormatStyle<Double>(
    ///     locale: Locale(identifier: "en_US"))
    ///     .notation(.scientific)
    /// let nums = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
    /// let formattedNums = nums.map { scientificStyle.format($0) } // ["1.001E2", "1.0002E3", "1.00003E4", "1.000004E5", "1E6"]
    /// ```
    ///
    /// To format a single floating-point value, use the `BinaryFloatingPoint` instance method
    /// `formatted(_:)`, passing in an instance of ``FloatingPointFormatStyle``, or `formatted()`
    /// to use a default style.
    ///
    /// - Parameter value: The floating-point value to format.
    /// - Returns: A string representation of `value` formatted according to the style's configuration.
    public func format(_ value: Value) -> String {
        if let nf = ICUNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: A floating-point format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> FloatingPointFormatStyle {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Percent : FormatStyle {
    /// Formats a floating-point value as a percentage, using this style.
    ///
    /// - Parameter value: The floating-point value to format.
    /// - Returns: A string representation of `value` formatted as a percentage according to the style's configuration.
    public func format(_ value: Value) -> String {
        if let nf = ICUPercentNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: A floating-point percent format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> FloatingPointFormatStyle.Percent {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Currency : FormatStyle {
    /// Formats a floating-point value as a currency string, using this style.
    ///
    /// - Parameter value: The floating-point value to format.
    /// - Returns: A string representation of `value` formatted as a currency value according to the style's configuration.
    public func format(_ value: Value) -> String {
        if let nf = ICUCurrencyNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    /// Modifies the format style to use the specified locale.
    ///
    /// - Parameter locale: The locale to apply to the format style.
    /// - Returns: A floating-point currency format style modified to use the provided locale.
    public func locale(_ locale: Locale) -> FloatingPointFormatStyle.Currency {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: - ParseableFormatStyle protocol membership
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Currency: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Percent: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

// MARK: - `FormatStyle` static membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    /// A style for formatting the Swift standard double-precision floating-point type.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float> {
    /// A style for formatting the Swift standard single-precision floating-point type.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    /// A style for formatting the Swift standard double-precision floating-point type as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float>.Percent {
    /// A style for formatting the Swift standard single-precision floating-point type as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    /// Returns a format style to use floating-point currency notation.
    ///
    /// Use the dot-notation form of this method when the call point allows the use of
    /// ``FloatingPointFormatStyle``. You typically do this when calling the `formatted` methods of
    /// types that conform to `BinaryFloatingPoint`.
    ///
    /// The following example creates an array of doubles, then uses the currency style
    /// provided by this method to format the doubles as US dollars:
    ///
    /// ```swift
    /// let nums: [Double] = [100.01, 1000.02, 10000.03, 100000.04, 1000000.05]
    /// let currencyNums = nums.map { $0.formatted(
    ///     .currency(code:"USD")) } // ["$100.01", "$1,000.02", "$10,000.03", "$100,000.04", "$1,000,000.05"]
    /// ```
    ///
    /// - Parameter code: The currency code to use, such as `EUR` or `JPY`. See ISO-4217 for
    ///   a list of valid codes.
    /// - Returns: A floating-point format style that uses the specified currency code.
    @_alwaysEmitIntoClient
    static func currency<Value>(code: String) -> Self where Self == FloatingPointFormatStyle<Value>.Currency {
        return Self(code: code)
    }
}

#if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)) // Float16 is unavailable on Intel Macs
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float16> {
    /// A style for formatting 16-bit floating-point values.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float16>.Percent {
    /// A style for formatting 16-bit floating-point values as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``FloatingPointFormatStyle``.
    /// You typically do this when calling the `formatted` methods of types that conform to
    /// `BinaryFloatingPoint`.
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}
#endif

// MARK: - Attributed string

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle {
    /// A format style that converts floating-point values into attributed strings.
    ///
    /// Use the ``FloatingPointFormatStyle/attributed`` modifier on a ``FloatingPointFormatStyle``
    /// to create a format style of this type.
    ///
    /// The attributed strings that this format style creates contain attributes from the
    /// ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use these
    /// attributes to determine which runs of the attributed string represent different parts of
    /// the formatted value.
    public struct Attributed : Codable, Hashable, FormatStyle, Sendable {
        enum Style : Codable, Hashable, Sendable {
            case floatingPoint(FloatingPointFormatStyle)
            case currency(FloatingPointFormatStyle.Currency)
            case percent(FloatingPointFormatStyle.Percent)
            
            private typealias FloatingPointCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias CurrencyCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias PercentCodingKeys = DefaultAssociatedValueCodingKeys1

            var formatter: ICUNumberFormatterBase? {
                switch self {
                case .floatingPoint(let style):
                    return ICUNumberFormatter.create(for: style)
                case .currency(let style):
                    return ICUCurrencyNumberFormatter.create(for: style)
                case .percent(let style):
                    return ICUPercentNumberFormatter.create(for: style)
                }
            }
        }

        var style: Style

        init(style: FloatingPointFormatStyle) {
            self.style = .floatingPoint(style)
        }

        init(style: FloatingPointFormatStyle.Percent) {
            self.style = .percent(style)
        }

        init(style: FloatingPointFormatStyle.Currency) {
            self.style = .currency(style)
        }

        /// Formats a floating-point value, using this style.
        ///
        /// - Parameter value: The floating-point value to format.
        /// - Returns: An attributed string representation of `value`, formatted according to the
        ///   style's configuration. The returned string contains attributes from the
        ///   ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope to
        ///   indicate runs formatted by this format style.
        public func format(_ value: Value) -> AttributedString {
            switch style {
            case .floatingPoint(let formatStyle):
                if let formatter = ICUNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.floatingPoint(Double(value)))
                }
            case .currency(let formatStyle):
                if let formatter = ICUCurrencyNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.floatingPoint(Double(value)))

                }
            case .percent(let formatStyle):
                if let formatter = ICUPercentNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.floatingPoint(Double(value)))

                }
            }

            // Fallback
            return AttributedString(Double(value).description)
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A format style that uses the specified locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            switch style {
            case .floatingPoint(var style):
                style.locale = locale
                new.style = .floatingPoint(style)
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

// MARK: Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FloatingPointFormatStyle : CustomConsumingRegexComponent {
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
        try FloatingPointParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FloatingPointFormatStyle.Percent : CustomConsumingRegexComponent {
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
        try FloatingPointParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FloatingPointFormatStyle.Currency : CustomConsumingRegexComponent {
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
        try FloatingPointParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == FloatingPointFormatStyle<Double> {
    /// Creates a regex component to match a localized number string and capture it as a `Double`.
    /// - Parameter locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized double string.
    public static func localizedDouble(locale: Locale) -> Self {
        FloatingPointFormatStyle(locale: locale)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == FloatingPointFormatStyle<Double>.Percent {
    /// Creates a regex component to match a localized string representing a percentage and capture it as a `Double`.
    /// - Parameter locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized percentage string.
    public static func localizedDoublePercentage(locale: Locale) -> Self {
        FloatingPointFormatStyle.Percent(locale: locale)
    }
}
