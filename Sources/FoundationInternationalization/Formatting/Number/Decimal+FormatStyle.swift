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
    public struct FormatStyle: Sendable {
        public var locale: Locale
        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        public var attributed: Attributed {
            return Attributed(style: self)
        }

        public typealias Configuration = NumberFormatStyleConfiguration
        internal var collection: Configuration.Collection = Configuration.Collection()

        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .integer(value: increment)
            }
            return new
        }

        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }

        // FormatStyle
        public func format(_ value: Decimal) -> String {
            if let f = ICUNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

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
    public struct Percent : Sendable {
        public typealias Configuration = NumberFormatStyleConfiguration

        public var locale: Locale
        // Set scale to 100 so we format 0.42 as "42%" instead of "0.42%"
        var collection: Configuration.Collection = Configuration.Collection(scale: 100)

        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        public var attributed: Attributed {
            return Attributed(style: self)
        }

        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .integer(value: increment)
            }
            return new
        }

        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        public func notation(_ notation: Configuration.Notation) -> Self {
            var new = self
            new.collection.notation = notation
            return new
        }

        // FormatStyle
        public func format(_ value: Decimal) -> String {
            if let f = ICUPercentNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration

        public var locale: Locale
        public var currencyCode: String

        internal var collection: Configuration.Collection
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        public var attributed: Attributed {
            return Attributed(style: self)
        }

        public func grouping(_ group: Configuration.Grouping) -> Self {
            var new = self
            new.collection.group = group
            return new
        }

        public func precision(_ p: Configuration.Precision) -> Self {
            var new = self
            new.collection.precision = p
            return new
        }

        public func sign(strategy: Configuration.SignDisplayStrategy) -> Self {
            var new = self
            new.collection.signDisplayStrategy = strategy
            return new
        }

        public func decimalSeparator(strategy: Configuration.DecimalSeparatorDisplayStrategy) -> Self {
            var new = self
            new.collection.decimalSeparatorStrategy = strategy
            return new
        }

        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Int? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .integer(value: increment)
            }
            return new
        }

        public func scale(_ multiplicand: Double) -> Self {
            var new = self
            new.collection.scale = multiplicand
            return new
        }

        public func presentation(_ p: Configuration.Presentation) -> Self {
            var new = self
            new.collection.presentation = p
            return new
        }

        // FormatStyle
        public func format(_ value: Decimal) -> String {
            if let f = ICUCurrencyNumberFormatter.create(for: self), let res = f.format(value) {
                return res
            }

            return value.description
        }

        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }
    }

    public struct Attributed : Sendable {
        enum Style : Hashable, Codable, Sendable {
            case decimal(Decimal.FormatStyle)
            case currency(Decimal.FormatStyle.Currency)
            case percent(Decimal.FormatStyle.Percent)
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

        /// Returns an attributed string with `NumberFormatAttributes.SymbolAttribute` and `NumberFormatAttributes.NumberPartAttribute`.
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
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Currency: ParseableFormatStyle {
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.FormatStyle.Percent: ParseableFormatStyle {
    public var parseStrategy: Decimal.ParseStrategy<Self> { .init(formatStyle: self, lenient: true) }
}

// MARK: - FormatStyle protocol membership
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle {
    static var number: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle.Percent {
    static var percent: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Decimal.FormatStyle.Currency {
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
    /// Format `self` using `Decimal.FormatStyle`
    public func formatted() -> String {
        FormatStyle().format(self)
    }

#if FOUNDATION_FRAMEWORK
    /// Format `self` with the given format.
    public func formatted<S: Foundation.FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput {
        format.format(self)
    }
#else
    /// Format `self` with the given format.
    public func formatted<S: FoundationEssentials.FormatStyle>(_ format: S) -> S.FormatOutput where Self == S.FormatInput {
        format.format(self)
    }
#endif
}

// MARK: - Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        Decimal.ParseStrategy(formatStyle: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle.Percent : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Decimal)? {
        Decimal.ParseStrategy(formatStyle: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Decimal.FormatStyle.Currency : CustomConsumingRegexComponent {
    public typealias RegexOutput = Decimal
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
