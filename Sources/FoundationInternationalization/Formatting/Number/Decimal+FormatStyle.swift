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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal {
    /// A structure that converts between decimal values and their textual representations.
    public struct FormatStyle: Sendable {
        /// The locale of the format style.
        ///
        /// Use the ``locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale

        /// Creates a decimal format style that uses the given locale.
        ///
        /// Create a ``Decimal/FormatStyle`` instance when you intend to apply a given style to multiple
        /// decimal values. The following example creates a style that uses the `en_US` locale, which
        /// uses three-based grouping and comma separators. It then applies this style to all the
        /// ``Decimal`` values in an array.
        ///
        /// ```swift
        /// let enUSstyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let decimals: [Decimal] = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
        /// let formattedDecimals = decimals.map { enUSstyle.format($0) } // ["100.1", "1,000.2", "10,000.3", "100,000.4", "1,000,000.5"]
        /// ```
        ///
        /// To format a single integer, you can use the ``Decimal`` instance method ``Decimal/formatted(_:)``
        /// passing in an instance of ``Decimal/FormatStyle``.
        ///
        /// - Parameter locale: The locale to use when formatting or parsing decimal values.
        ///   Defaults to `Locale.autoupdatingCurrent`.
        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        /// An attributed format style based on the decimal format style.
        ///
        /// Use this modifier to create a ``Decimal/FormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        ///
        /// The following example finds runs of the attributed string that represent different parts
        /// of a formatted currency, and adds additional attributes like
        /// ``AttributeScopes/SwiftUIAttributes/foregroundColor`` and
        /// ``AttributeScopes/FoundationAttributes/inlinePresentationIntent``.
        ///
        /// ```swift
        /// func attributedPrice(price: Decimal) -> AttributedString {
        ///     var attributedPrice = price.formatted(
        ///         .currency(code: "USD")
        ///         .attributed)
        ///
        ///     for run in attributedPrice.runs {
        ///         if run.attributes.numberSymbol == .currency ||
        ///             run.attributes.numberSymbol == .decimalSeparator {
        ///             attributedPrice[run.range].foregroundColor = .red
        ///         }
        ///         if run.attributes.numberPart == .integer ||
        ///             run.attributes.numberPart == .fraction {
        ///             attributedPrice[run.range].inlinePresentationIntent = [.stronglyEmphasized]
        ///         }
        ///     }
        ///     return attributedPrice
        /// }
        /// ```
        ///
        /// User interface frameworks like SwiftUI can use these attributes when presenting the
        /// attributed string.
        public var attributed: Attributed {
            return Attributed(style: self)
        }

        public typealias Configuration = NumberFormatStyleConfiguration
        internal var collection: Configuration.Collection = Configuration.Collection()

        /// Modifies the format style to use the specified grouping.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that never uses grouping. It then applies each style to an array of
        /// decimal values. The formatting that the modified style applies eliminates the three-digit
        /// grouping usually performed for the `en_US` locale.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let neverStyle = defaultStyle.grouping(.never)
        /// let nums: [Decimal] = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["100.1", "1,000.2", "10,000.3", "100,000.4", "1,000,000.5"]
        /// let neverNums = nums.map { neverStyle.format($0) } // ["100.1", "1000.2", "10000.3", "100000.4", "1000000.5"]
        /// ```
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// The ``NumberFormatStyleConfiguration/Precision`` type lets you specify fixed numbers of digits
        /// to show for a number's integer and fractional parts. You can also set a fixed number of
        /// significant digits.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that uses a maximum of four significant digits. It then applies each
        /// style to an array of decimal values. The formatting applied by the modified style truncates
        /// precision to `0` after the fourth most-significant digit.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let precisionStyle = defaultStyle.precision(.significantDigits(1...4))
        /// let nums: [Decimal] = [123.1, 1234.1, 12345.1, 123456.1, 1234567.1]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["123.1", "1,234.1", "12,345.1", "123,456.1", "1,234,567.1"]
        /// let precisionNums = nums.map { precisionStyle.format($0) } // ["123.1", "1,234", "12,350", "123,500", "1,235,000"]
        /// ```
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that displays a sign for all values except zero. It then applies each
        /// style to an array of decimal values. The formatting that the modified style applies adds
        /// the negative (`-`) or positive (`+`) sign to all the numbers.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let alwaysStyle = defaultStyle.sign(strategy: .always(includingZero: false))
        /// let nums: [Decimal] = [-2.1, -1.2, 0, 1.4, 2.5]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["-2.1", "-1.2", "0", "1.4", "2.5"]
        /// let alwaysNums = nums.map { alwaysStyle.format($0) } // ["-2.1", "-1.2", "0", "+1.4", "+2.5"]
        /// ```
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that uses the ``NumberFormatStyleConfiguration/DecimalSeparatorDisplayStrategy/always``
        /// strategy. It then applies each style to an array of decimal values that don't have a
        /// fractional part. The formatting that the modified style applies adds a trailing decimal
        /// separator in all cases.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let alwaysStyle = defaultStyle.decimalSeparator(strategy: .always)
        /// let nums: [Decimal] = [100.0, 1000.0, 10000.0, 100000.0, 1000000.0]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["100", "1,000", "10,000", "100,000", "1,000,000"]
        /// let alwaysNums = nums.map { alwaysStyle.format($0) } // ["100.", "1,000.", "10,000.", "100,000.", "1,000,000."]
        /// ```
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified decimal separator display strategy.
        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified rounding rule and increment.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a modified style that rounds integers to the nearest multiple of `100`. It then
        /// formats the value `1999.95` using these format styles.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let roundedStyle = defaultStyle.rounded(rule: .toNearestOrEven,
        ///                                         increment: 100)
        /// let num: Decimal = 1999.95
        /// let defaultNum = num.formatted(defaultStyle) // "1,999.95"
        /// let roundedNum = num.formatted(roundedStyle) // "2,000"
        /// ```
        ///
        /// - Parameters:
        ///   - rule: The rounding rule to apply to the format style.
        ///   - increment: A multiple by which the formatter rounds the fractional part. The formatter
        ///     produces a value that is an even multiple of this increment. If this parameter is
        ///     `nil` (the default), the formatter doesn't apply an increment.
        /// - Returns: A decimal format style modified to use the specified rounding rule and increment.
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
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that scales by a `multiplicand` of `0.001`. It then applies each
        /// style to an array of decimal values. The formatting that the modified style applies
        /// expresses each value in terms of one-thousandths.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let scaledStyle = defaultStyle.scale(0.001)
        /// let nums: [Decimal] = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["100.1", "1,000.2", "10,000.3", "100,000.4", "1,000,000.5"]
        /// let scaledNums = nums.map { scaledStyle.format($0) } // ["0.1001", "1.0002", "10.0003", "100.0004", "1,000.0005"]
        /// ```
        ///
        /// - Parameter multiplicand: The multiplicand to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified scale.
        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and a second style that uses scientific notation style. It then applies each style to
        /// an array of decimal values.
        ///
        /// ```swift
        /// let defaultStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        /// let scientificStyle = defaultStyle.notation(.scientific)
        /// let nums: [Decimal] = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
        /// let defaultNums = nums.map { defaultStyle.format($0) } // ["100.1", "1,000.2", "10,000.3", "100,000.4", "1,000,000.5"]
        /// let scientificNums = nums.map { scientificStyle.format($0) } // ["1.001E2", "1.0002E3", "1.00003E4", "1.000004E5", "1E6"]
        /// ```
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A decimal format style modified to use the specified notation.
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }

        /// Formats a decimal value using this style.
        ///
        /// Use this method when you want to create a single style instance and then use it to format
        /// multiple decimal values. The following example creates a style that uses the `en_US` locale
        /// and then adds the ``NumberFormatStyleConfiguration/Notation/scientific`` modifier. It then
        /// applies this style to all of the decimal values in an array.
        ///
        /// ```swift
        /// let scientificStyle = Decimal.FormatStyle(
        ///     locale: Locale(identifier: "en_US"))
        ///     .notation(.scientific)
        /// let nums: [Decimal] = [100.1, 1000.2, 10000.3, 100000.4, 1000000.5]
        /// let formattedNums = nums.map { scientificStyle.format($0) } // ["1.001E2", "1.0002E3", "1.00003E4", "1.000004E5", "1E6"]
        /// ```
        ///
        /// To format a single value, use the ``Decimal`` instance method ``Decimal/formatted(_:)``,
        /// passing in an instance of ``Decimal/FormatStyle``, or ``Decimal/formatted()`` to use a
        /// default style.
        ///
        /// - Parameter value: The decimal value to format.
        /// - Returns: A string representation of `value` formatted according to the style's configuration.
        public func format(_ value: Decimal) -> String {
            if let f = ICUNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// Use this modifier to change the locale that an existing format style uses. To instead
        /// determine the locale that this format style uses, use the ``locale`` property.
        ///
        /// The following example creates a default ``Decimal/FormatStyle`` for the `en_US` locale,
        /// and applies the ``notation(_:)`` modifier to use compact name notation. Next, the sample
        /// creates a second style based on this, but that uses the German (`DE`) locale. It then
        /// applies each style to an array of decimal values.
        ///
        /// ```swift
        /// let compactStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
        ///     .notation(.compactName)
        /// let germanStyle = compactStyle.locale(Locale(identifier: "DE"))
        /// let nums: [Decimal] = [100, 1000, 10000, 100000, 1000000]
        /// let enUSCompactNums = nums.map { compactStyle.format($0) } // ["100", "1K", "10K", "100K", "1M"]
        /// let deCompactNums = nums.map { germanStyle.format($0) } // ["100", "1000", "10.000", "100.000", "1 Mio."]
        /// ```
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A decimal format style modified to use the provided locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle {
    /// A format style that converts between decimal percentage values and their textual representations.
    public struct Percent : Sendable {
        public typealias Configuration = NumberFormatStyleConfiguration

        /// The locale of the format style.
        ///
        /// Use the ``locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale
        // Set scale to 100 so we format 0.42 as "42%" instead of "0.42%"
        var collection: Configuration.Collection = Configuration.Collection(scale: 100)

        /// Creates a decimal percent format style that uses the given locale.
        ///
        /// - Parameter locale: The locale to use when formatting or parsing decimal values.
        ///   Defaults to `Locale.autoupdatingCurrent`.
        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        /// An attributed format style based on the decimal percent format style.
        ///
        /// Use this modifier to create a ``Decimal/FormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: Attributed {
            return Attributed(style: self)
        }

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the specified decimal separator display strategy.
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
        /// - Returns: A decimal percent format style modified to use the specified rounding rule and increment.
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
        /// - Returns: A decimal percent format style modified to use the specified scale.
        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the specified notation.
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }

        /// Formats a decimal value as a percentage, using this style.
        ///
        /// - Parameter value: The decimal value to format.
        /// - Returns: A string representation of `value` formatted as a percentage according to the style's configuration.
        public func format(_ value: Decimal) -> String {
            if let f = ICUPercentNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A decimal percent format style modified to use the provided locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }

    /// A format style that converts between decimal currency values and their textual representations.
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration

        /// The locale of the format style.
        ///
        /// Use the ``locale(_:)`` modifier to create a copy of this format style with a different locale.
        public var locale: Locale

        /// The currency code this format style uses, such as `USD` or `EUR`.
        public var currencyCode: String

        internal var collection: Configuration.Collection

        /// Creates a decimal currency format style that uses the given currency code and locale.
        ///
        /// - Parameters:
        ///   - code: The currency code to use, such as `EUR` or `JPY`.
        ///   - locale: The locale to use when formatting or parsing decimal values.
        ///     Defaults to `Locale.autoupdatingCurrent`.
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        /// An attributed format style based on the decimal currency format style.
        ///
        /// Use this modifier to create a ``Decimal/FormatStyle/Attributed`` instance, which formats
        /// values as ``AttributedString`` instances. These attributed strings contain attributes from
        /// the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use
        /// these attributes to determine which runs of the attributed string represent different
        /// parts of the formatted value.
        public var attributed: Attributed {
            return Attributed(style: self)
        }

        /// Modifies the format style to use the specified grouping.
        ///
        /// - Parameter group: The grouping to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the specified grouping.
        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        /// Modifies the format style to use the specified precision.
        ///
        /// - Parameter p: The precision to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the specified precision.
        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        /// Modifies the format style to use the specified sign display strategy for displaying or omitting sign symbols.
        ///
        /// - Parameter strategy: The sign display strategy to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the specified sign display strategy.
        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        /// Modifies the format style to use the specified decimal separator display strategy.
        ///
        /// - Parameter strategy: The decimal separator display strategy to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the specified decimal separator display strategy.
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
        /// - Returns: A decimal currency format style modified to use the specified rounding rule and increment.
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
        /// - Returns: A decimal currency format style modified to use the specified scale.
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
        /// - Returns: A decimal currency format style modified to use the specified presentation.
        public func presentation(_ p: Configuration.Presentation) -> Self {
            var new = self
            new.collection.presentation = p
            return new
        }

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the specified notation.
        @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }

        /// Formats a decimal value as a currency string, using this style.
        ///
        /// - Parameter value: The decimal value to format.
        /// - Returns: A string representation of `value` formatted as a currency value according to the style's configuration.
        public func format(_ value: Decimal) -> String {
            if let f = ICUCurrencyNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A decimal currency format style modified to use the provided locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }

    /// A format style that converts decimal values into attributed strings.
    ///
    /// Use the ``Decimal/FormatStyle/attributed`` modifier on a ``Decimal/FormatStyle`` to create
    /// a format style of this type.
    ///
    /// The attributed strings that this format style creates contain attributes from the
    /// ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use these
    /// attributes to determine which runs of the attributed string represent different parts of
    /// the formatted value.
    public struct Attributed : Sendable {
        enum Style : Hashable, Codable, Sendable {
            case decimal(Decimal.FormatStyle)
            case currency(Decimal.FormatStyle.Currency)
            case percent(Decimal.FormatStyle.Percent)
            
            private typealias DecimalCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias CurrencyCodingKeys = DefaultAssociatedValueCodingKeys1
            private typealias PercentCodingKeys = DefaultAssociatedValueCodingKeys1
        }

        var style: Style

        init(style: Decimal.FormatStyle) {
            self.style = .decimal(style)
        }

        init(style: Decimal.FormatStyle.Currency) {
            self.style = .currency(style)
        }

        init(style: Decimal.FormatStyle.Percent) {
            self.style = .percent(style)
        }

        /// Formats a decimal value, using this style.
        ///
        /// - Parameter value: The decimal value to format.
        /// - Returns: An attributed string representation of `value`, formatted according to the
        ///   style's configuration. The returned string contains attributes from the
        ///   ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope to
        ///   indicate runs formatted by this format style.
        public func format(_ value: Decimal) -> AttributedString {
            switch style {
            case .decimal(let formatStyle):
                if let formatter = ICUNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.decimal(value))
                }
            case .currency(let formatStyle):
                if let formatter = ICUCurrencyNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.decimal(value))

                }
            case .percent(let formatStyle):
                if let formatter = ICUPercentNumberFormatter.create(for: formatStyle) {
                    return formatter.attributedFormat(.decimal(value))

                }
            }

            // Fallback
            return AttributedString(value.description)
        }

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A format style that uses the specified locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            switch style {
            case .decimal(var s):
                s.locale = locale
                new.style = .decimal(s)
            case .currency(var s):
                s.locale = locale
                new.style = .currency(s)
            case .percent(var s):
                s.locale = locale
                new.style = .percent(s)
            }
            return new
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Percent : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Currency : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Attributed : FormatStyle {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Currency: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Percent: ParseableFormatStyle {
    /// The parse strategy that this format style uses.
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

// MARK: - FormatStyle protocol membership
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle {
    /// A style for formatting decimal values.
    ///
    /// Use this type property when the call point allows the use of ``Decimal/FormatStyle``.
    /// You typically do this when calling the ``Decimal/formatted(_:)`` method of ``Decimal``.
    static var number: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle.Percent {
    /// A style for formatting decimal values as a percent representation.
    ///
    /// Use this type property when the call point allows the use of ``Decimal/FormatStyle``.
    /// You typically do this when calling the ``Decimal/formatted(_:)`` method of ``Decimal``.
    static var percent: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle.Currency {
    /// Returns a format style to use decimal currency notation.
    ///
    /// Use the dot-notation form of this method when the call point allows the use of
    /// ``Decimal/FormatStyle``. You typically do this when calling the ``Decimal/formatted(_:)``
    /// method of ``Decimal``.
    ///
    /// The following example creates an array of decimals, then uses ``Decimal/formatted(_:)``
    /// and the currency style provided by this method to format the values as US dollars.
    ///
    /// ```swift
    /// let nums: [Decimal] = [100.01, 1000.02, 10000.03, 100000.04, 1000000.05]
    /// let currencyNums = nums.map { $0.formatted(
    ///     .currency(code:"USD")) } // ["$100.01", "$1,000.02", "$10,000.03", "$100,000.04", "$1,000,000.05"]
    /// ```
    ///
    /// - Parameter code: The currency code to use, such as `EUR` or `JPY`. See ISO-4217 for
    ///   a list of valid codes.
    /// - Returns: A decimal format style that uses the specified currency code.
    static func currency(code: String) -> Self { .init(code: code, locale: .autoupdatingCurrent) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Decimal.FormatStyle {
    static var number: Self { Decimal.FormatStyle() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Decimal.FormatStyle.Percent {
    static var percent: Self { Decimal.FormatStyle.Percent() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Decimal.FormatStyle.Currency {
    static func currency(code: String) -> Self { Decimal.FormatStyle.Currency(code: code) }
}

// MARK: - Decimal type entry point

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal {
    /// Formats the decimal using a default localized format style.
    ///
    /// - Returns: A string representation of the decimal, formatted according to the default format style.
    public func formatted() -> String {
        FormatStyle().format(self)
    }

#if FOUNDATION_FRAMEWORK
    /// Formats the decimal using the provided format style.
    ///
    /// Use this method when you want to format a single decimal value with a specific
    /// format style or multiple format styles. The following example shows the results
    /// of formatting a given decimal value with format styles for the `en_US` and
    /// `fr_FR` locales:
    ///
    /// ```swift
    /// let decimal: Decimal = 123456.789
    /// let usStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
    /// let frStyle = Decimal.FormatStyle(locale: Locale(identifier: "fr_FR"))
    /// let formattedUS = decimal.formatted(usStyle) // 123,456.789
    /// let formattedFR = decimal.formatted(frStyle) // 123 456,789
    /// ```
    ///
    /// - Parameter format: The format style to apply when formatting the decimal.
    /// - Returns: A localized, formatted string representation of the decimal.
    public func formatted<S: Foundation.FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput {
        format.format(self)
    }
#else
    /// Formats the decimal using the provided format style.
    ///
    /// Use this method when you want to format a single decimal value with a specific
    /// format style or multiple format styles. The following example shows the results
    /// of formatting a given decimal value with format styles for the `en_US` and
    /// `fr_FR` locales:
    ///
    /// ```swift
    /// let decimal: Decimal = 123456.789
    /// let usStyle = Decimal.FormatStyle(locale: Locale(identifier: "en_US"))
    /// let frStyle = Decimal.FormatStyle(locale: Locale(identifier: "fr_FR"))
    /// let formattedUS = decimal.formatted(usStyle) // 123,456.789
    /// let formattedFR = decimal.formatted(frStyle) // 123 456,789
    /// ```
    ///
    /// - Parameter format: The format style to apply when formatting the decimal.
    /// - Returns: A localized, formatted string representation of the decimal.
    public func formatted<S: FoundationEssentials.FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput {
        format.format(self)
    }
#endif
}

// MARK: - Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal

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
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        Decimal.ParseStrategy(formatStyle: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle.Percent : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal

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
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        Decimal.ParseStrategy(formatStyle: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle.Currency : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal

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
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        Decimal.ParseStrategy(formatStyle: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == Decimal.FormatStyle {
    /// Creates a regex component to match a localized number string and capture it as a `Decimal`.
    /// - Parameter locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized number string.
    public static func localizedDecimal(locale: Locale) -> Self {
        Decimal.FormatStyle(locale: locale)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == Decimal.FormatStyle.Currency {
    /// Creates a regex component to match a localized currency string and capture it as a `Decimal`. For example, `localizedIntegerCurrency(code: "USD", locale: Locale(identifier: "en_US"))` matches "$52,249.98" and captures it as 52249.98.
    /// - Parameters:
    ///   - code: The currency code of the currency symbol or name in the string.
    ///   - locale: The locale with which the string is formatted.
    /// - Returns: A `RegexComponent` to match a localized currency number.
    public static func localizedCurrency(code: Locale.Currency, locale: Locale) -> Self {
        Decimal.FormatStyle.Currency(code: code.identifier, locale: locale)
    }
}
