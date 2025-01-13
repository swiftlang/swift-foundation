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
public struct FloatingPointFormatStyle<Value: BinaryFloatingPoint>: Codable, Hashable, Sendable {
    public var locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public var attributed: FloatingPointFormatStyle.Attributed {
        return FloatingPointFormatStyle.Attributed(style: self)
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

    public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
        var new = self
        new.collection.rounding = rule
        if let increment = increment {
            new.collection.roundingIncrement = .floatingPoint(value: increment)
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
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle {
    public struct Percent : Codable, Hashable, Sendable {
        public var locale: Locale

        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        public var attributed: FloatingPointFormatStyle.Attributed {
            return FloatingPointFormatStyle.Attributed(style: self)
        }

        public typealias Configuration = NumberFormatStyleConfiguration

        // Set scale to 100 so we format 0.42 as "42%" instead of "0.42%"
        var collection: Configuration.Collection = Configuration.Collection(scale: 100)

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

        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .floatingPoint(value: increment)
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
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Codable, Hashable, Sendable {
        public var locale: Locale
        public let currencyCode: String

        public typealias Configuration = CurrencyFormatStyleConfiguration
        internal var collection: Configuration.Collection
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        public var attributed: FloatingPointFormatStyle.Attributed {
            return FloatingPointFormatStyle.Attributed(style: self)
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

        public func rounded(rule: Configuration.RoundingRule = .toNearestOrEven, increment: Double? = nil) -> Self {
            var new = self
            new.collection.rounding = rule
            if let increment = increment {
                new.collection.roundingIncrement = .floatingPoint(value: increment)
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

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: A floating-point currency format style modified to use the specified notation.
        @available(FoundationPreview 0.4, *)
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
    public func format(_ value: Value) -> String {
        if let nf = ICUNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    public func locale(_ locale: Locale) -> FloatingPointFormatStyle {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Percent : FormatStyle {
    public func format(_ value: Value) -> String {
        if let nf = ICUPercentNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    public func locale(_ locale: Locale) -> FloatingPointFormatStyle.Percent {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Currency : FormatStyle {
    public func format(_ value: Value) -> String {
        if let nf = ICUCurrencyNumberFormatter.create(for: self), let str = nf.format(Double(value)) {
            return str
        }
        return String(Double(value))
    }

    public func locale(_ locale: Locale) -> FloatingPointFormatStyle.Currency {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: - ParseableFormatStyle protocol membership
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Currency: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle.Percent: ParseableFormatStyle {
    public var parseStrategy: FloatingPointParseStrategy<Self> {
        return FloatingPointParseStrategy<Self>(format: self, lenient: true)
    }
}

// MARK: - `FormatStyle` static membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Double> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    @_alwaysEmitIntoClient
    static func currency<Value>(code: String) -> Self where Self == FloatingPointFormatStyle<Value>.Currency {
        return Self(code: code)
    }
}

#if !((os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)) // Float16 is unavailable on Intel Macs
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float16> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == FloatingPointFormatStyle<Float16>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}
#endif

// MARK: - Attributed string

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointFormatStyle {
    public struct Attributed : Codable, Hashable, FormatStyle, Sendable {
        enum Style : Codable, Hashable, Sendable {
            case floatingPoint(FloatingPointFormatStyle)
            case currency(FloatingPointFormatStyle.Currency)
            case percent(FloatingPointFormatStyle.Percent)

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

        /// Returns an attributed string with `NumberFormatAttributes.SymbolAttribute` and `NumberFormatAttributes.NumberPartAttribute`.
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
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        try FloatingPointParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FloatingPointFormatStyle.Percent : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        try FloatingPointParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FloatingPointFormatStyle.Currency : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
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
