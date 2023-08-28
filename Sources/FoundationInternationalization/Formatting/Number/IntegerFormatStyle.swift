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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct IntegerFormatStyle<Value: BinaryInteger>: Codable, Hashable, Sendable {
    public typealias Configuration = NumberFormatStyleConfiguration

    public var locale: Locale
    internal var collection: Configuration.Collection = Configuration.Collection()

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public var attributed: IntegerFormatStyle.Attributed {
        return IntegerFormatStyle.Attributed(style: self)
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
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle {
    public struct Percent : Codable, Hashable, Sendable {
        public typealias Configuration = NumberFormatStyleConfiguration

        public var locale: Locale
        // Specifically set scale to 1 so `42` is formatted as `42%`.
        var collection: Configuration.Collection = Configuration.Collection(scale: 1)

        public init(locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
        }

        public var attributed: IntegerFormatStyle.Attributed {
            return IntegerFormatStyle.Attributed(style: self)
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
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct Currency : Codable, Hashable, Sendable {
        public typealias Configuration = CurrencyFormatStyleConfiguration

        public var locale: Locale
        public let currencyCode: String

        internal var collection: Configuration.Collection
        public init(code: String, locale: Locale = .autoupdatingCurrent) {
            self.locale = locale
            self.currencyCode = code
            self.collection = Configuration.Collection(presentation: .standard)
        }

        public var attributed: IntegerFormatStyle.Attributed {
            return IntegerFormatStyle.Attributed(style: self)
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

        /// Modifies the format style to use the specified notation.
        ///
        /// - Parameter notation: The notation to apply to the format style.
        /// - Returns: An integer currency format style modified to use the specified notation.
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
extension IntegerFormatStyle : FormatStyle {
    /// Returns a localized string for the given value. Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
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

    public func locale(_ locale: Locale) -> IntegerFormatStyle {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Percent : FormatStyle {
    /// Returns a localized string for the given value in percentage. Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
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

    public func locale(_ locale: Locale) -> IntegerFormatStyle.Percent {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Currency : FormatStyle {
    /// Returns a localized currency string for the given value. Supports up to 64-bit signed integer precision. Values not representable by `Int64` are clamped.
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

    public func locale(_ locale: Locale) -> IntegerFormatStyle.Currency {
        var new = self
        new.locale = locale
        return new
    }
}

// MARK: - FormatStyle protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Currency: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle.Percent: ParseableFormatStyle {
    public var parseStrategy: IntegerParseStrategy<Self> {
        return IntegerParseStrategy(format: self, lenient: true)
    }
}

// MARK: - `FormatStyle` protocol membership

// MARK: Number

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int16> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int32> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int64> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int8> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt16> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt32> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt64> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt8> {
    @_alwaysEmitIntoClient
    static var number: Self { Self() }
}

// MARK: Percent


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int16>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int32>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int64>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<Int8>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt16>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt32>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt64>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == IntegerFormatStyle<UInt8>.Percent {
    @_alwaysEmitIntoClient
    static var percent: Self { Self() }
}

// MARK: Currency

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    static func currency<V: BinaryInteger>(code: String) -> Self where Self == IntegerFormatStyle<V>.Currency {
        return Self(code: code)
    }
}

// MARK: - Attributed string

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension IntegerFormatStyle {
    public struct Attributed : Codable, Hashable, FormatStyle, Sendable {
        enum Style : Codable, Hashable {
            case integer(IntegerFormatStyle)
            case percent(IntegerFormatStyle.Percent)
            case currency(IntegerFormatStyle.Currency)
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

        /// Returns an attributed string with `NumberFormatAttributes.SymbolAttribute` and `NumberFormatAttributes.NumberPartAttribute`. Values not representable by `Int64` are clamped.
        /// - Parameter value: The value to be formatted.
        /// - Returns: A localized attributed string for the given value.
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
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension IntegerFormatStyle.Percent : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension IntegerFormatStyle.Currency : CustomConsumingRegexComponent {
    public typealias RegexOutput = Value
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Value)? {
        IntegerParseStrategy(format: self, lenient: false).parse(input, startingAt: index, in: bounds)
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
