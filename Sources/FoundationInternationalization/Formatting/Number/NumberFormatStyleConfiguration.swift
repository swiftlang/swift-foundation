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

internal import _FoundationICU

/// The capitalization formatting context used when formatting dates and times.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FormatStyleCapitalizationContext : Codable, Hashable, Sendable {

    internal enum Option: Int, Codable, Hashable {
        case unknown
        case standalone
        case listItem
        case beginningOfSentence
        case middleOfSentence
    }

    internal var option: Option

    private init(_ option: Option) {
        self.option = option
    }

    var icuContext: UDisplayContext {
        switch self.option {
        case .unknown:
            return .unknown
        case .standalone:
            return .standalone
        case .listItem:
            return .listItem
        case .beginningOfSentence:
            return .beginningOfSentence
        case .middleOfSentence:
            return .middleOfSentence
        }
    }

#if FOUNDATION_FRAMEWORK
    var formatterContext: Formatter.Context {
        switch option {
        case .unknown:
            return .unknown
        case .standalone:
            return .standalone
        case .listItem:
            return .listItem
        case .beginningOfSentence:
            return .beginningOfSentence
        case .middleOfSentence:
            return .middleOfSentence
        }
    }
#endif // FOUNDATION_FRAMEWORK

    public static var unknown : FormatStyleCapitalizationContext {
        .init(.unknown)
    }

    /// For stand-alone usage, such as an isolated name on a calendar page.
    public static var standalone : FormatStyleCapitalizationContext {
        .init(.standalone)
    }

    /// For use in a UI list or menu item.
    public static var listItem : FormatStyleCapitalizationContext {
        .init(.listItem)
    }

    public static var beginningOfSentence : FormatStyleCapitalizationContext {
        .init(.beginningOfSentence)
    }

    public static var middleOfSentence : FormatStyleCapitalizationContext {
        .init(.middleOfSentence)
    }
}

/// Configuration settings for formatting numbers of different types.
///
/// This type is effectively a namespace to collect types that configure parts of a formatted number, such as grouping, precision, and separator and sign characters.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public enum NumberFormatStyleConfiguration {
    internal struct Collection : Codable, Hashable, Sendable {
        var scale: Double?
        var precision: Precision?
        var group: Grouping?
        var signDisplayStrategy: SignDisplayStrategy?
        var decimalSeparatorStrategy: DecimalSeparatorDisplayStrategy?
        var rounding: RoundingRule?
        var roundingIncrement: RoundingIncrement?
        var notation: Notation?
    }

    /// The type used for rounding rule values.
    ///
    /// ``NumberFormatStyleConfiguration`` uses the `FloatingPointRoundingRule` enumeration for rounding rule values.
    public typealias RoundingRule = FloatingPointRoundingRule

    typealias Scale = Double

    /// A structure that an integer format style uses to configure grouping.
    public struct Grouping : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Codable, Hashable {
            case automatic
            case hidden

            // unused
            // case hiddenBelow10000 // UNUM_GROUPING_MIN2
            // case alwaysGreaterThan1000 // UNUM_GROUPING_ON_ALIGNED
            // case alwaysGroup3 // UNUM_GROUPING_THOUSANDS
        }
        var option: Option

        /// A grouping behavior that automatically applies locale-appropriate grouping.
        public static var automatic: Self { .init(option: .automatic) }
        /// A grouping behavior that never groups digits.
        public static var never: Self { .init(option: .hidden) }

        public var description: String {
            switch option {
            case .automatic:
                return "automatic"
            case .hidden:
                return "never"
            }
        }
    }

    /// A structure that an integer format style uses to configure precision.
    public struct Precision : Codable, Hashable, Sendable {

        enum Option: Hashable {
            case significantDigits(min: Int, max: Int?)
            case integerAndFractionalLength(minInt: Int?, maxInt: Int?, minFraction: Int?, maxFraction: Int?)
        }
        var option: Option

        // The maximum total length that ICU allows is 999.
        // We take one off to reserve one character for the non-zero digit skeleton (the "0" skeleton in the number format)
        static let validPartLength = 0..<999
        static let validSignificantDigits = 1..<999

        // min 3, max 3: 12345 -> 12300
        // min 3, max 3: 0.12345 -> 0.123
        // min 2, max 4: 3.14159 -> 3.142
        // min 2, max 4: 1.23004 -> 1.23
        // ^ Trailing zero digits to the right of the decimal separator are suppressed after the minimum number of significant digits have been shown

        /// Returns a precision that constrains formatted values to a range of significant digits.
        ///
        /// When using this precision, the formatter rounds values that have more significant digits than the maximum of the range, as seen in the following example:
        ///
        /// ```swift
        /// let myNum = 123456.formatted(.number
        ///     .precision(.significantDigits(2...4))
        ///     .rounded(rule: .down)) // "123,400"
        /// ```
        ///
        /// - Parameter limits: A range from the minimum to the maximum number of significant digits to use when formatting values.
        /// - Returns: A precision that constrains formatted values to a range of significant digits.
        public static func significantDigits<R: RangeExpression>(_ limits: R) -> Self where R.Bound == Int {
            let (lower, upper) = limits.clampedLowerAndUpperBounds(validSignificantDigits)
            return Precision(option: .significantDigits(min: lower ?? validSignificantDigits.lowerBound, max: upper))
        }

        /// Returns a precision that constrains formatted values to a given number of significant digits.
        ///
        /// When using this precision, the formatter rounds values that have more significant digits than the maximum of the range, as seen in the following example:
        ///
        /// ```swift
        /// let myNum = 123456.formatted(.number
        ///     .precision(.significantDigits(4))
        ///     .rounded(rule: .down)) // "123,400"
        /// ```
        ///
        /// - Parameter digits: The maximum number of significant digits to use when formatting values.
        /// - Returns: A precision that constrains formatted values to a given number of significant digits.
        public static func significantDigits(_ digits: Int) -> Self {
            return Precision(option: .significantDigits(min: digits, max: digits))
        }

        // maxInt 2 : 1997 -> 97
        // minInt 5: 1997 -> 01997
        // maxFrac 2: 0.125 -> 0.12
        // minFrac 4: 0.125 -> 0.1250
        /// Returns a precision that constrains formatted values to ranges of allowed digits in the integer and fraction parts.
        ///
        /// When using this precision, the formatter rounds values that have more digits than the maximum of the range, as seen in the following example:
        ///
        /// ```swift
        /// let myNum = 12345.6789.formatted(.number
        ///     .precision(.integerAndFractionLength(integerLimits: 2...,
        ///                                          fractionLimits: 2...3))
        ///     .rounded(rule: .down)) // "12,345.678"
        /// ```
        ///
        /// - Parameters:
        ///   - integerLimits: A range from the minimum to the maximum number of digits to use when formatting the integer part of a number.
        ///   - fractionLimits: A range from the minimum to the maximum number of digits to use when formatting the fraction part of a number.
        /// - Returns: A precision that constrains formatted values to ranges of digits in the integer and fraction parts.
        public static func integerAndFractionLength<R1: RangeExpression, R2: RangeExpression>(integerLimits: R1, fractionLimits: R2) -> Self where R1.Bound == Int, R2.Bound == Int {
            let (minInt, maxInt) =  integerLimits.clampedLowerAndUpperBounds(validPartLength)
            let (minFrac, maxFrac) = fractionLimits.clampedLowerAndUpperBounds(validPartLength)

            return Precision(option: .integerAndFractionalLength(minInt: minInt, maxInt: maxInt, minFraction: minFrac, maxFraction: maxFrac))
        }

        /// Returns a precision that constrains formatted values a given number of allowed digits in the integer and fraction parts.
        ///
        /// When using this precision, the formatter pads values with fewer digits than the specified digits for the integer or fraction parts. Similarly, it rounds values that have more digits than specified. The following example shows this behavior, padding the integer part while rounding the fraction:
        ///
        /// ```swift
        /// let myNum = 12345.6789.formatted(.number
        ///     .precision(.integerAndFractionLength(integer: 6,
        ///                                          fraction: 3))
        ///     .rounded(rule: .down)) // "012,345.678"
        /// ```
        ///
        /// - Parameters:
        ///   - integer: The number of digits to use when formatting the integer part of a number.
        ///   - fraction: The number of digits to use when formatting the fraction part of a number.
        /// - Returns: A precision that constrains formatted values a given number of digits in the integer and fraction parts.
        public static func integerAndFractionLength(integer: Int, fraction: Int) -> Self {
            return Precision(option: .integerAndFractionalLength(minInt: integer, maxInt: integer, minFraction: fraction, maxFraction: fraction))
        }

        /// Returns a precision that constrains formatted values to a range of allowed digits in the integer part.
        ///
        /// - Parameter limits: A range from the minimum to the maximum number of digits to use when formatting the integer part of a number.
        /// - Returns: A precision that constrains formatted values to ranges of digits in the integer part.
        public static func integerLength<R: RangeExpression>(_ limits: R) -> Self {
            let (minInt, maxInt) = limits.clampedLowerAndUpperBounds(validPartLength)
            return Precision(option: .integerAndFractionalLength(minInt: minInt, maxInt: maxInt, minFraction: nil, maxFraction: nil))
        }

        /// Returns a precision that constrains formatted values to a given number of allowed digits in the integer part.
        ///
        /// - Parameter length: The number of digits to use when formatting the integer part of a number.
        /// - Returns: A precision that constrains formatted values to a given number of allowed digits in the integer part.
        public static func integerLength(_ length: Int) -> Self {
            return Precision(option: .integerAndFractionalLength(minInt: length, maxInt: length, minFraction: nil, maxFraction: nil))
        }

        /// Returns a precision that constrains formatted values to a range of allowed digits in the fraction part.
        ///
        /// - Parameter limits: A range from the minimum to the maximum number of digits to use when formatting the fraction part of a number.
        /// - Returns: A precision that constrains formatted values to a range of allowed digits in the fraction part.
        public static func fractionLength<R: RangeExpression>(_ limits: R) -> Self where R.Bound == Int {
            let (minFrac, maxFrac) = limits.clampedLowerAndUpperBounds(validPartLength)
            return Precision(option: .integerAndFractionalLength(minInt: nil, maxInt: nil, minFraction: minFrac, maxFraction: maxFrac))
        }

        /// Returns a precision that constrains formatted values to a given number of allowed digits in the fraction part.
        ///
        /// - Parameter length: The number of digits to use when formatting the fraction part of a number.
        /// - Returns: A precision that constrains formatted values to a given number of allowed digits in the fraction part.
        public static func fractionLength(_ length: Int) -> Self {
            return Precision(option: .integerAndFractionalLength(minInt: nil, maxInt: nil, minFraction: length, maxFraction: length))
        }
    }

    /// A structure that an integer format style uses to configure a decimal separator display strategy.
    public struct DecimalSeparatorDisplayStrategy : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Codable, Hashable {
            case automatic
            case always
        }
        var option: Option

        /// A strategy to automatically configure locale-appropriate decimal separator display behavior.
        // "1.1", "1"
        public static var automatic: Self {
            .init(option: .automatic)
        }

        /// A strategy that always displays decimal separators.
        // "1.1", "1."
        public static var always : Self { .init(option: .always) }

        public var description: String {
            switch option {
            case .automatic:
                return "automatic"
            case .always:
                return "always"
            }
        }
    }

    /// A structure that an integer format style uses to configure a sign display strategy.
    public struct SignDisplayStrategy : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Hashable, Codable {
            case always
            case hidden
        }

        var positive: Option
        var negative: Option
        var zero: Option

        /// A strategy to automatically configure locale-appropriate sign display behavior.
        // Show the minus sign on negative numbers, and do not show the sign on positive numbers or zero
        public static var automatic: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden)
        }

        /// A strategy to never display sign symbols.
        public static var never: Self {
            SignDisplayStrategy(positive: .hidden, negative: .hidden, zero: .hidden)
        }

        /// A strategy to always display sign symbols.
        ///
        /// - Parameter includingZero: A Boolean value that determines whether the format style should apply sign characters to zero values. Defaults to `true`.
        /// - Returns: A strategy to always display sign symbols, with the given behavior for zero values.
        // Show the minus sign on negative numbers and the plus sign on positive numbers, and zero if specified
        public static func always(includingZero: Bool = true) -> Self {
            SignDisplayStrategy(positive: .always, negative: .always, zero: includingZero ? .always : .hidden)
        }

        public var description: String {
            switch positive {
            case .always:
                switch zero {
                case .always:
                    return "always(includingZero: true)"
                case .hidden:
                    return "always(includingZero: false)"
                }
            case .hidden:
                switch negative {
                case .always:
                    return "automatic"
                case .hidden:
                    return "never"
                }
            }
        }
    }

    /// A structure that an integer format style uses to configure notation.
    public struct Notation : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Codable, Hashable {
            case automatic
            case scientific
            case compactName
        }
        var option: Option

        /// A notation constant that formats values with scientific notation.
        ///
        /// The following example shows the effect of using scientific notation with a format style:
        ///
        /// ```swift
        /// let scientific = 12345.formatted(.number
        ///     .notation(.scientific)) // 1.2345E4"
        /// ```
        public static var scientific: Self { .init(option: .scientific) }
        /// A notation that automatically provides locale-appropriate behavior.
        public static var automatic: Self { .init(option: .automatic) }

        /// A locale-appropriate compact name notation.
        ///
        /// A compact name notation, when available in the format style's locale, that uses prefixes or suffixes corresponding to powers of ten. The following example shows a compact name notation in the `fr_FR` locale:
        ///
        /// ```swift
        /// let compactNameFormatted = 1234.formatted(.number
        ///     .locale(Locale(identifier: "fr_FR"))
        ///     .notation(.compactName)) // "1,2 k"
        /// ```
        ///
        /// - note: We do not support parsing a number string containing localized prefixes or suffixes.
        public static var compactName: Self { .init(option: .compactName) }

        public var description: String {
            switch option {
            case .scientific:
                return "scientific"
            case .automatic:
                return "automatic"
            case .compactName:
                return "compact name"
            }
        }
    }

    internal enum RoundingIncrement: Hashable, CustomStringConvertible {
        case integer(value: Int)
        case floatingPoint(value: Double)

        var description: String {
            switch self {
            case .integer(let value):
                return String(value)
            case .floatingPoint(let value):
                return String(value)
            }
        }
    }
}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension NumberFormatStyleConfiguration : Sendable {}

/// Configuration settings for formatting currency values.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public enum CurrencyFormatStyleConfiguration {
    /// The type used to configure grouping for currency format styles.
    public typealias Grouping = NumberFormatStyleConfiguration.Grouping
    /// The type used to configure precision for currency format styles.
    public typealias Precision = NumberFormatStyleConfiguration.Precision
    /// The type used to configure decimal separator display strategies for currency format styles.
    public typealias DecimalSeparatorDisplayStrategy = NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy
    /// The type used to configure rounding rules for currency format styles.
    public typealias RoundingRule = NumberFormatStyleConfiguration.RoundingRule
    /// The type used to configure notation for currency format styles.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
    public typealias Notation = NumberFormatStyleConfiguration.Notation

    internal typealias RoundingIncrement = NumberFormatStyleConfiguration.RoundingIncrement
    internal struct Collection : Codable, Hashable {
        var scale: Double?
        var precision: Precision?
        var group: Grouping?
        var signDisplayStrategy: SignDisplayStrategy?
        var decimalSeparatorStrategy: DecimalSeparatorDisplayStrategy?
        var rounding: RoundingRule?
        var roundingIncrement: RoundingIncrement?
        var presentation: Presentation
        var notation: Notation?
    }

    /// A structure used to configure sign display strategies for currency format styles.
    public struct SignDisplayStrategy: Codable, Hashable, Sendable {
        enum Option : Int, Hashable, Codable {
            case always
            case hidden
        }
        var positive: Option
        var negative: Option
        var zero: Option
        var accounting: Bool = false

        /// A strategy to automatically configure sign display.
        public static var automatic: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden)
        }

        /// A strategy to never show the sign.
        public static var never: Self {
            SignDisplayStrategy(positive: .hidden, negative: .hidden, zero: .hidden)
        }

        /// A sign display strategy to always show the sign, with a configurable behavior for handling zero values.
        ///
        /// - Parameter showZero: A Boolean value that indicates whether to show the sign symbol on zero values. Defaults to `true`.
        /// - Returns: A sign display strategy that always displays the sign, and uses the specified handling of zero values.
        // Show the minus sign on negative numbers and the plus sign on positive numbers, and zero if specified
        public static func always(showZero: Bool = true) -> Self {
            SignDisplayStrategy(positive: .always, negative: .always, zero: showZero ? .always : .hidden)
        }

        /// A sign display strategy to use accounting principles.
        ///
        /// This strategy always shows the currency symbol, and shows negative values in parenthesis. Examples of this strategy include `$123`, `$0`, and `($123)`.
        public static var accounting: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden, accounting: true)
        }

        /// A sign display strategy to use accounting principles, with a configurable behavior for handling zero values.
        ///
        /// - Parameter showZero: A Boolean value that indicates whether to show the sign symbol on zero values. Defaults to `false`.
        /// - Returns: A strategy that uses accounting principles, and the specified handling of zero values.
        public static func accountingAlways(showZero: Bool = false) -> Self {
            SignDisplayStrategy(positive: .always, negative: .always, zero: showZero ? .always : .hidden, accounting: true)
        }
    }

    /// A structure used to configure the presentation of currency format styles.
    public struct Presentation: Codable, Hashable, Sendable {
        enum Option : Int, Codable, Hashable {
            case narrow
            case standard
            case isoCode
            case fullName
        }
        internal var option: Option

        /// A presentation that shows a condensed expression of the currency.
        ///
        /// This presentation produces output like `$123.00`.
        public static var narrow: Self { Presentation(option: .narrow) }
        /// A presentation that shows a standard expression of the currency.
        ///
        /// This presentation produces output like `US$ 123.00`.
        public static var standard: Self { Presentation(option: .standard) }
        /// A presentation that shows the ISO code of the currency.
        ///
        /// This presentation produces output like `USD 123.00`.
        public static var isoCode: Self { Presentation(option: .isoCode) }
        /// A presentation that shows the full name of the currency.
        ///
        /// This presentation produces output like `123.00 US dollars`.
        public static var fullName: Self { Presentation(option: .fullName) }
    }
}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension CurrencyFormatStyleConfiguration : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public enum DescriptiveNumberFormatConfiguration {
    public typealias CapitalizationContext = FormatStyleCapitalizationContext
    public struct Presentation : Codable, Hashable, Sendable {
        internal enum Option : Int, Codable, Hashable {
            case spellOut = 1
            case ordinal = 2
            case cardinal = 3

            #if FOUNDATION_FRAMEWORK
            fileprivate var numberFormatterStyle : NumberFormatter.Style {
                switch self {
                case .spellOut:
                    return .spellOut
                case .ordinal:
                    return .ordinal
                case .cardinal:
                    return .spellOut // cardinal is a special case spellout style
                }
            }
            #endif // FOUNDATION_FRAMEWORK
        }
        internal var option: Option

        public static var spellOut: Self { Presentation(rawValue: 1) }
        public static var ordinal: Self { Presentation(rawValue: 2) }
        internal static var cardinal: Self { Presentation(rawValue: 3) }
        
        internal init(rawValue: Int) {
            option = Option(rawValue: rawValue)!
        }
    }

    internal struct Collection : Codable, Hashable {
        var presentation: Presentation
        var capitalizationContext: CapitalizationContext?

        var icuNumberFormatStyle: UNumberFormatStyle {
            switch presentation.option {
            case .spellOut:
                return .spellout
            case .ordinal:
                return .ordinal
            case .cardinal:
                return .spellout // cardinal is a special case spellout stype
            }
        }
    }
}

@available(macOS, unavailable, introduced: 12.0)
@available(iOS, unavailable, introduced: 15.0)
@available(tvOS, unavailable, introduced: 15.0)
@available(watchOS, unavailable, introduced: 8.0)
@available(*, unavailable)
extension DescriptiveNumberFormatConfiguration : Sendable {}

// MARK: - Codable

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointRoundingRule {
    private enum CodingValue: Int, Codable {
        case toNearestOrAwayFromZero
        case toNearestOrEven
        case up
        case down
        case towardZero
        case awayFromZero
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(CodingValue.self)
        switch value {
        case .toNearestOrAwayFromZero:
            self = .toNearestOrAwayFromZero
        case .toNearestOrEven:
            self = .toNearestOrEven
        case .up:
            self = .up
        case .down:
            self = .down
        case .towardZero:
            self = .towardZero
        case .awayFromZero:
            self = .awayFromZero
        }
    }

    public func encode(to encoder: Encoder) throws {
        let codingValue: CodingValue
        switch self {
        case .toNearestOrAwayFromZero:
            codingValue = .toNearestOrAwayFromZero
        case .toNearestOrEven:
            codingValue = .toNearestOrEven
        case .up:
            codingValue = .up
        case .down:
            codingValue = .down
        case .towardZero:
            codingValue = .towardZero
        case .awayFromZero:
            codingValue = .awayFromZero
        @unknown default:
            codingValue = .toNearestOrEven
        }
        var container = encoder.singleValueContainer()
        try container.encode(codingValue)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointRoundingRule: @retroactive Codable { }

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.RoundingIncrement: Codable {
    private enum CodingKeys: CodingKey {
        case integer
        case floatingPoint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(Int.self, forKey: .integer) {
            self = .integer(value: value)
        } else if let value = try container.decodeIfPresent(Double.self, forKey: .floatingPoint) {
            self = .floatingPoint(value: value)
        } else {
            self = .floatingPoint(value: 0.5)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .integer(let value):
            try container.encode(value, forKey: .integer)
        case .floatingPoint(let value):
            try container.encode(value, forKey: .floatingPoint)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Precision.Option : Codable {
    private enum CodingKeys: CodingKey {
        case minSignificantDigits
        case maxSignificantDigits
        case minIntegerLength
        case maxIntegerLength
        case minFractionalLength
        case maxFractionalLength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let minSignificantDigits = try container.decodeIfPresent(Int.self, forKey: .minSignificantDigits), let maxSignificantDigits = try container.decodeIfPresent(Int.self, forKey: .maxSignificantDigits) {
            self = .significantDigits(min: minSignificantDigits, max: maxSignificantDigits)
        } else if let minInt = try container.decodeIfPresent(Int.self, forKey: .minIntegerLength), let maxInt = try container.decodeIfPresent(Int.self, forKey: .maxIntegerLength), let minFrac = try container.decodeIfPresent(Int.self, forKey: .minFractionalLength), let maxFrac = try container.decodeIfPresent(Int.self, forKey: .maxFractionalLength) {
            self = .integerAndFractionalLength(minInt: minInt, maxInt: maxInt, minFraction: minFrac, maxFraction: maxFrac)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                              debugDescription: "Invalid Precision"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .significantDigits(let min, let max):
            try container.encode(min, forKey: .minSignificantDigits)
            try container.encode(max, forKey: .maxSignificantDigits)
        case .integerAndFractionalLength(let minInt, let maxInt, let minFraction, let maxFraction):
            try container.encode(minInt, forKey: .minIntegerLength)
            try container.encode(maxInt, forKey: .maxIntegerLength)
            try container.encode(minFraction, forKey: .minFractionalLength)
            try container.encode(maxFraction, forKey: .maxFractionalLength)
        }
    }
}


// MARK: - ICU compatibility: NumberFormatStyleConfiguration

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Collection {
    var skeleton: String {
        var s = ""
        if let scale = scale {
            s += scale.skeleton + " "
        }
        if let precision = precision, let roundingIncrement = roundingIncrement {
            s += precision.skeletonWithRoundingIncrement(stem: roundingIncrement.skeleton) + " "
        } else if let precision = precision {
            s += precision.skeleton + " "
        } else if let roundingIncrement = roundingIncrement {
            s += roundingIncrement.skeleton + " "
        }

        if let group = group {
            s += group.skeleton + " "
        }
        if let signDisplayStrategy = signDisplayStrategy {
            s += signDisplayStrategy.skeleton + " "
        }
        if let decimalSeparatorStrategy = decimalSeparatorStrategy {
            s += decimalSeparatorStrategy.skeleton + " "
        }
        if let rounding = rounding {
            s += rounding.skeleton + " "
        }
        if let notation = notation {
            s += notation.skeleton + " "
        }

        return s._trimmingWhitespace()
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.RoundingIncrement {
    var skeleton: String {
        switch self {
        // ICU treats any value <= 0 as invalid. Fallback to the default behavior if that's the case.
        case .integer(let value):
            if value > 0 {
                return "precision-increment/\(Decimal(value))"
            } else {
                return ""
            }
        case .floatingPoint(let value):
            if value > 0 {
                return "precision-increment/\(Decimal(value))"
            } else {
                return ""
            }
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Precision {

    private func significantDigitsSkeleton(min: Int, max: Int?) -> String {
        var stem: String = ""
        stem += String(repeating: "@", count: min)

        if let max = max {
            stem += String(repeating: "#", count: max - min)
        } else {
            stem += "+"
        }
        return stem
    }

    private func integerAndFractionalLengthSkeleton(minInt: Int?, maxInt: Int?, minFrac: Int?, maxFrac: Int?) -> String {
        var stem: String = ""
        // Construct skeleton for fractional part
        if minFrac != nil || maxFrac != nil {
            if maxFrac == 0 {
                stem += "precision-integer"
            } else {
                stem += fractionalStem(min: minFrac ?? 0, max: maxFrac)
            }
        }

        // Construct skeleton for integer part
        if minInt != nil || maxInt != nil {
            if stem.count > 0 {
                stem += " "
            }
            stem += integerStem(min: minInt ?? 0, max: maxInt)
        }

        return stem
    }

    func skeletonWithRoundingIncrement(stem: String) -> String {
        guard stem.count > 0 else { return self.skeleton }

        var incrementStem = stem
        switch self.option {
        case .significantDigits(_, _):
            // Specifying rounding increment hides the effect of significant digits
            break
        case .integerAndFractionalLength(let minInt, let maxInt, let minFrac, _):
            if let minFrac = minFrac {
                if let decimalPoint = incrementStem.lastIndex(of: ".") {
                    let frac = incrementStem.suffix(from: incrementStem.index(after: decimalPoint))
                    if minFrac > frac.count {
                        incrementStem += String(repeating: "0", count: minFrac - frac.count)
                    }
                } else {
                    incrementStem += "." + String(repeating: "0", count: minFrac)
                }
            }
            if minInt != nil || maxInt != nil {
                incrementStem += " " + integerStem(min: minInt ?? 0, max: maxInt)
            }
        }
        return incrementStem
    }

    var skeleton : String {
        switch self.option {
        case .significantDigits(let min, let max):
            return significantDigitsSkeleton(min: min, max: max)
        case .integerAndFractionalLength(let minInt, let maxInt, let minFrac, let maxFrac):
            return integerAndFractionalLengthSkeleton(minInt: minInt, maxInt: maxInt, minFrac: minFrac, maxFrac: maxFrac)
        }
    }

    private func integerStem(min: Int, max: Int?) -> String {
        var s = "integer-width/"
        if max == 0 && min == 0 {
            s += "*" // 75459602
            return s
        }

        if let max = max {
            guard max >= min else { return "" }
            s += String(repeating: "#", count: max - min)
        } else {
            s += "+"
        }

        s += String(repeating: "0", count: min)

        return s
    }

    private func fractionalStem(min: Int, max: Int?) -> String {
        var s = "."
        s += String(repeating: "0", count: min)

        if let max = max {
            guard max >= min else { return "" }
            s += String(repeating: "#", count: max - min)
        } else {
            s += "+"
        }

        return s
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Grouping {
    var skeleton : String {
        switch self.option {
        case .automatic:
            // This is the default, so no need to set it
            return ""
        case .hidden:
            return "group-off"
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.SignDisplayStrategy {
    var skeleton : String {
        let stem: String
        switch positive {
        case .always:
            switch zero {
            case .always:
                stem = "sign-always"
            case .hidden:
                stem = "sign-except-zero"
            }
        case .hidden:
            switch negative {
            case .always:
                stem = "sign-auto"
            case .hidden:
                stem = "sign-never"
            }
        }
        return stem
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy {
    var skeleton : String {
        let stem: String
        switch option {
        case .always:
            stem = "decimal-always"
        case .automatic:
            stem = "decimal-auto"
        }
        return stem
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.RoundingRule {
    var skeleton : String {
        var stem: String
        switch self {
        case .awayFromZero:
            stem = "rounding-mode-up"
        case .toNearestOrAwayFromZero:
            stem = "rounding-mode-half-up"
        case .toNearestOrEven:
            stem = "rounding-mode-half-even"
        case .up:
            stem = "rounding-mode-ceiling"
        case .down:
            stem = "rounding-mode-floor"
        case .towardZero:
            stem = "rounding-mode-down"
        @unknown default:
            stem = ""
        }
        return stem
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Notation {
    var skeleton : String {
        let stem: String
        switch self.option {
        case .scientific:
            stem = "scientific"
        case .automatic:
            stem = ""
        case .compactName:
            stem = "compact-short"
        }
        return stem
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NumberFormatStyleConfiguration.Scale {
    var skeleton : String {
        return "scale/\(Decimal(self))"
    }
}


// MARK: - ICU compatibility: CurrencyFormatStyleConfiguration

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension CurrencyFormatStyleConfiguration.Collection {
    var skeleton: String {
        var s = presentation.skeleton + " "

        if let scale = scale {
            s += scale.skeleton + " "
        }
        if let precision = precision, let roundingIncrement = roundingIncrement {
            s += precision.skeletonWithRoundingIncrement(stem: roundingIncrement.skeleton)
        } else if let precision = precision {
            s += precision.skeleton + " "
        } else if let roundingIncrement = roundingIncrement {
            s += roundingIncrement.skeleton + " "
        }
        if let group = group {
            s += group.skeleton + " "
        }
        if let signDisplayStrategy = signDisplayStrategy {
            s += signDisplayStrategy.skeleton + " "
        }
        if let decimalSeparatorStrategy = decimalSeparatorStrategy {
            s += decimalSeparatorStrategy.skeleton + " "
        }
        if let rounding = rounding {
            s += rounding.skeleton + " "
        }
        if let notation = notation {
            s += notation.skeleton + " "
        }

        return s._trimmingWhitespace()
    }

    var icuNumberFormatStyle: UNumberFormatStyle {
        if signDisplayStrategy?.accounting == true {
            return .currencyAccounting
        }
        switch presentation.option {
        case .narrow:
            return .currencyNarrow
        case .standard:
            return .currencyStandard
        case .isoCode:
            return .currencyISO
        case .fullName:
            return .currencyFullName
        }
    }

}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension CurrencyFormatStyleConfiguration.SignDisplayStrategy {
    var skeleton: String {
        var stem: String
        if accounting {
            switch positive {
            case .always:
                switch zero {
                case .always:
                    stem = "sign-accounting-always"
                case .hidden:
                    stem = "sign-accounting-except-zero"
                }
            case .hidden:
                stem = "sign-accounting"
            }
        } else {
            switch positive {
            case .always:
                switch zero {
                case .always:
                    stem = "sign-always"
                case .hidden:
                    stem = "sign-except-zero"
                }
            case .hidden:
                switch negative {
                case .always:
                    stem = "sign-auto"
                case .hidden:
                    stem = "sign-never"
                }
            }
        }

        return stem
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension CurrencyFormatStyleConfiguration.Presentation {
    var skeleton: String {
        var stem: String
        switch option {
        case .narrow:
            stem = "unit-width-narrow"
        case .standard:
            stem = "unit-width-short"
        case .isoCode:
            stem = "unit-width-iso-code"
        case .fullName:
            stem = "unit-width-full-name"
        }
        return stem
    }
}
