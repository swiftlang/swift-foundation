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
#if FOUNDATION_FRAMEWORK
    /// A parse strategy for creating decimal values from formatted strings.
    public struct ParseStrategy<Format> : Foundation.ParseStrategy, Codable, Hashable where Format : Foundation.FormatStyle, Format.FormatInput == Decimal {
        /// The format style describing the expected format of the string to parse.
        public var formatStyle: Format
        /// A Boolean value that indicates whether the parse strategy permits some discrepancies when parsing.
        public var lenient: Bool
        internal init(formatStyle: Format, lenient: Bool) {
            self.formatStyle = formatStyle
            self.lenient = lenient
        }
    }
#else
    /// A parse strategy for creating decimal values from formatted strings.
    public struct ParseStrategy<Format> : FoundationEssentials.ParseStrategy, Codable, Hashable where Format : FoundationEssentials.FormatStyle, Format.FormatInput == Decimal {
        /// The format style describing the expected format of the string to parse.
        public var formatStyle: Format
        /// A Boolean value that indicates whether the parse strategy permits some discrepancies when parsing.
        public var lenient: Bool
        internal init(formatStyle: Format, lenient: Bool) {
            self.formatStyle = formatStyle
            self.lenient = lenient
        }
    }
#endif // FOUNDATION_FRAMEWORK
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.ParseStrategy {
    internal func parse(_ value: String, startingAt index: String.Index, in range: Range<String.Index>) -> (String.Index, Decimal)? {
        guard index < range.upperBound else {
            return nil
        }

        var numberFormatType: ICULegacyNumberFormatter.NumberFormatType
        var locale: Locale

        if let format = formatStyle as? Decimal.FormatStyle {
            numberFormatType = .number(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? Decimal.FormatStyle.Percent {
            numberFormatType = .percent(format.collection)
            locale = format.locale
        } else if let format = formatStyle as? Decimal.FormatStyle.Currency {
            numberFormatType = .currency(format.collection, currencyCode: format.currencyCode)
            locale = format.locale
        } else {
            // For some reason we've managed to accept a format style of a type that we don't own, which shouldn't happen. Fallback to the default decimal style and try anyways.
            numberFormatType = .number(.init())
            locale = .autoupdatingCurrent
        }

        guard let parser = ICULegacyNumberFormatter.formatter(for: numberFormatType, locale: locale, lenient: lenient) else {
            return nil
        }
        let substr = value[index..<range.upperBound]
        var upperBound = 0
        guard let value = parser.parseAsDecimal(substr, upperBound: &upperBound) else {
            return nil
        }
        let upperBoundInSubstr = String.Index(utf16Offset: upperBound, in: substr)
        return (upperBoundInSubstr, value)
    }

    /// Parses a decimal string in accordance with this strategy and returns the parsed value.
    ///
    /// Use this method to repeatedly parse decimal strings with the same ``Decimal/ParseStrategy``.
    /// To parse a single decimal string, use the initializers inherited from ``Decimal`` that take
    /// a `String` and a ``Decimal/FormatStyle`` as parameters.
    ///
    /// This method throws an error if the parse strategy can't parse the provided string.
    ///
    /// - Parameter value: The string to parse.
    /// - Returns: The parsed decimal value.
    public func parse(_ value: String) throws -> Format.FormatInput {
        if let result = parse(value, startingAt: value.startIndex, in: value.startIndex..<value.endIndex) {
            return result.1
        } else if let d = Decimal(string: value) {
            return d
        } else {
            let exampleString1 = formatStyle.format(3.14)
            let exampleString2 = formatStyle.format(-12345)
            throw CocoaError(CocoaError.formatting, userInfo: [
                NSDebugDescriptionErrorKey: "Cannot parse \(value). String should adhere to the specified format, such as \"\(exampleString1)\" or \"\(exampleString2)\"" ])
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Decimal.ParseStrategy : Sendable where Format : Sendable {}

// MARK: - Decimal extension entry point

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Decimal {

#if FOUNDATION_FRAMEWORK
    /// Initialize an instance by parsing `value` with the given `strategy`.
    init<S: Foundation.ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#else
    /// Initialize an instance by parsing `value` with the given `strategy`.
    init<S: FoundationEssentials.ParseStrategy>(_ value: S.ParseInput, strategy: S) throws where S.ParseOutput == Self {
        self = try strategy.parse(value)
    }
#endif // FOUNDATION_FRAMEWORK

    init(_ value: String, format: Decimal.FormatStyle, lenient: Bool = true) throws {
        self = try Decimal(value, strategy: ParseStrategy(formatStyle: format, lenient: lenient))
    }

    init(_ value: String, format: Decimal.FormatStyle.Percent, lenient: Bool = true) throws {
        self = try Decimal(value, strategy: ParseStrategy(formatStyle: format, lenient: lenient))
    }

    init(_ value: String, format: Decimal.FormatStyle.Currency, lenient: Bool = true) throws {
        self = try Decimal(value, strategy: ParseStrategy(formatStyle: format, lenient: lenient))
    }

}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Decimal.ParseStrategy where Format == Decimal.FormatStyle {
    /// Creates a parse strategy instance using the specified decimal format style.
    ///
    /// - Parameters:
    ///   - format: A configured ``Decimal/FormatStyle`` that describes the string format to parse.
    ///   - lenient: A Boolean value that indicates whether the parse strategy should permit some
    ///     discrepancies when parsing. Defaults to `true`.
    init(format: Format, lenient: Bool = true) {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Decimal.ParseStrategy where Format == Decimal.FormatStyle.Percent {
    /// Creates a parse strategy instance using the specified decimal percentage format style.
    ///
    /// - Parameters:
    ///   - format: A configured ``Decimal/FormatStyle/Percent`` that describes the percent string format to parse.
    ///   - lenient: A Boolean value that indicates whether the parse strategy should permit some
    ///     discrepancies when parsing. Defaults to `true`.
    init(format: Format, lenient: Bool = true) {
        self.formatStyle = format
        self.lenient = lenient
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Decimal.ParseStrategy where Format == Decimal.FormatStyle.Currency {
    /// Creates a parse strategy instance using the specified decimal currency format style.
    ///
    /// - Parameters:
    ///   - format: A configured ``Decimal/FormatStyle/Currency`` that describes the currency string format to parse.
    ///   - lenient: A Boolean value that indicates whether the parse strategy should permit some
    ///     discrepancies when parsing. Defaults to `true`.
    init(format: Format, lenient: Bool = true) {
        self.formatStyle = format
        self.lenient = lenient
    }
}


