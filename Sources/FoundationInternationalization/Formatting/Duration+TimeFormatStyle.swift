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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

let hourSymbol: Character = "h"
let minuteSymbol: Character = "m"
let secondSymbol: Character = "s"
let quoteSymbol: Character = "'"

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Duration {

    /// Format style to format a `Duration` in a localized positional format.
    /// For example, one hour and ten minutes is displayed as “1:10:00” in
    /// the U.S. English locale, or “1.10.00” in the Finnish locale.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public struct TimeFormatStyle : FormatStyle, Sendable {

        /// The units to display a Duration with and configurations for the units.
        public struct Pattern : Hashable, Codable, Sendable {
            enum Fields: Hashable, Codable {
                case hourMinute(roundSeconds: FloatingPointRoundingRule)
                case hourMinuteSecond(fractionalSecondsLength: Int, roundFractionalSeconds: FloatingPointRoundingRule)
                case minuteSecond(fractionalSecondsLength: Int, roundFractionalSeconds: FloatingPointRoundingRule)
            }
            var fields: Fields

            var paddingForLargestField: Int?

            init(fields: Fields, paddingForLargestField: Int? = nil) {
                self.fields = fields
                self.paddingForLargestField = paddingForLargestField
            }

            /// Displays a duration in hours and minutes.
            public static var hourMinute: Pattern {
                .init(fields: .hourMinute(roundSeconds: .toNearestOrEven))
            }
            /// Displays a duration in terms of hours and minutes with the specified configurations.
            /// - Parameters:
            ///   - padHourToLength: Padding for the hour field. For example, one hour is formatted as "01:00" in en_US locale when this value is set to 2.
            ///   - roundSeconds: Rounding rule for the remaining second values.
            /// - Returns: A pattern to format a duration with.
            public static func hourMinute(padHourToLength: Int, roundSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern {
                .init(fields: .hourMinute(roundSeconds: roundSeconds), paddingForLargestField: padHourToLength)
            }

            /// Displays a duration in hours, minutes, and seconds.
            public static var hourMinuteSecond: Pattern {
                .init(fields: .hourMinuteSecond(fractionalSecondsLength: 0, roundFractionalSeconds: .toNearestOrEven))
            }

            /// Displays a duration in terms of hours, minutes, and seconds with the specified configurations.
            /// - Parameters:
            ///   - padHourToLength: Padding for the hour field. For example, one hour is formatted as "01:00:00" in en_US locale when this value is set to 2.
            ///   - fractionalSecondsLength: The length of the fractional seconds. For example, one hour is formatted as "1:00:00.00" in en_US locale when this value is set to 2.
            ///   - roundFractionalSeconds: Rounding rule for the fractional second values.
            /// - Returns: A pattern to format a duration with.
            public static func hourMinuteSecond(padHourToLength: Int, fractionalSecondsLength: Int = 0, roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern {
                .init(fields: .hourMinuteSecond(fractionalSecondsLength: fractionalSecondsLength, roundFractionalSeconds: roundFractionalSeconds), paddingForLargestField: padHourToLength)
            }

            /// Displays a duration in minutes and seconds. For example, one hour is formatted as "60:00" in en_US locale.
            public static var minuteSecond: Pattern {
                .init(fields: .minuteSecond(fractionalSecondsLength: 0, roundFractionalSeconds: .toNearestOrEven))
            }
            /// Displays a duration in minutes and seconds with the specified configurations.
            /// - Parameters:
            ///   - padMinuteToLength: Padding for the minute field. For example, five minutes is formatted as "05:00" in en_US locale when this value is set to 2.
            ///   - fractionalSecondsLength: The length of the fractional seconds. For example, one hour is formatted as "1:00:00.00" in en_US locale when this value is set to 2.
            ///   - roundFractionalSeconds: Rounding rule for the fractional second values.
            /// - Returns: A pattern to format a duration with.
            public static func minuteSecond(padMinuteToLength: Int, fractionalSecondsLength: Int = 0, roundFractionalSeconds: FloatingPointRoundingRule = .toNearestOrEven) -> Pattern {
                .init(fields: .minuteSecond(fractionalSecondsLength: fractionalSecondsLength, roundFractionalSeconds: roundFractionalSeconds), paddingForLargestField: padMinuteToLength)
            }
        }

        var _attributed: Attributed
        /// The locale to use when formatting the duration.
        public var locale: Locale {
            get { _attributed.locale }
            set { _attributed.locale = newValue }
        }

        /// The pattern to display a Duration with.
        public var pattern: Pattern {
            get { _attributed.pattern }
            set { _attributed.pattern = newValue }
        }

        /// The attributed format style corresponding to this style.
        public var attributed: Attributed {
            return _attributed
        }

        /// Creates an instance using the provided pattern and locale.
        /// - Parameters:
        ///   - pattern: A `Pattern` to specify the units to include in the displayed string and the behavior of the units.
        ///   - locale: The `Locale` used to create the string representation of the duration.
        public init(pattern: Pattern, locale: Locale = .autoupdatingCurrent) {
            self._attributed = Attributed(pattern: pattern, locale: locale)
        }

        fileprivate init(_ attributedStyle: Attributed) {
            self._attributed = attributedStyle
        }

        // `FormatStyle` conformance

        /// Creates a locale-aware string representation from a duration value.
        /// - Parameter value: The value to format.
        /// - Returns: A string representation of the duration.
        public func format(_ value: Duration) -> String {
            String(_attributed.format(value).characters[...])
        }

        /// Modifies the format style to use the specified locale.
        /// - Parameter locale: The locale to use when formatting a duration.
        /// - Returns: A format style with the provided locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }

    }

    // For testing purpose. See notes about String._Encoding
    internal typealias _TimeFormatStyle = TimeFormatStyle
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FormatStyle where Self == Duration.TimeFormatStyle {
    /// A factory variable to create a time format style to format a duration.
    /// - Parameter pattern: A `Pattern` to specify the units to include in the displayed string and the behavior of the units.
    /// - Returns: A format style to format a duration.
    public static func time(pattern: Duration.TimeFormatStyle.Pattern) -> Self {
        .init(pattern: pattern)
    }
}

// MARK: - Attributed style


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Duration.TimeFormatStyle {

    /// Formats a duration as an attributed string with the `durationField` attribute key and `FoundationAttributes.DurationFieldAttribute` attribute.
    ///
    /// For example, two hour, 43 minute and 26.25 seconds can be formatted as an attributed string, "2:43:26.25" with the following run text and attributes:
    /// ```
    /// 2 { durationField: .hours }
    /// : { nil }
    /// 43 { durationField: .minutes }
    /// : { nil }
    /// 26.25 { durationField: .seconds }
    /// ```
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public struct Attributed : FormatStyle, Sendable {

        typealias Pattern = Duration.TimeFormatStyle.Pattern

        var pattern: Pattern

        var grouping: NumberFormatStyleConfiguration.Grouping = .automatic

        var locale: Locale

        internal init(pattern: Pattern, locale: Locale) {
            self.pattern = pattern
            self.locale = locale
        }

        /// Modifies the format style to use the specified locale.
        /// - Parameter locale: The locale to use when formatting a duration.
        /// - Returns: A format style with the provided locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }

        /// Formats a duration as an attributed string with `DurationFieldAttribute`.
        /// - Parameter value: The value to format.
        /// - Returns: An attributed string to represent the duration.
        public func format(_ value: Duration) -> AttributedString {
            var uPattern: UATimeUnitTimePattern
            var fallbackPattern: String
            switch pattern.fields {
            case .hourMinute:
                uPattern = .hourMinute
                fallbackPattern = "h':'mm"
                break
            case .hourMinuteSecond:
                uPattern = .hourMinuteSecond
                fallbackPattern = "h':'mm':'ss"
                break
            case .minuteSecond:
                uPattern = .minuteSecond
                fallbackPattern = "m':'ss"
                break
            }

            var patternString: String!

            let capacity = 128
            withUnsafeTemporaryAllocation(of: UChar.self, capacity: capacity) { ptr in
                var status = U_ZERO_ERROR
                let len = uatmufmt_getTimePattern(locale.identifier, uPattern, ptr.baseAddress!, Int32(capacity), &status)
                guard status.isSuccess, let bufferStart = ptr.baseAddress, let str = String(_utf16: bufferStart, count: Int(len)) else {
                    patternString = fallbackPattern
                    return
                }

                patternString = str.lowercased()
            }

            let units: [Duration.UnitsFormatStyle.Unit]
            let rounding: FloatingPointRoundingRule
            let lastUnitFractionalLen: Int
            switch pattern.fields {
            case .hourMinute(let roundSeconds):
                units = [ .hours, .minutes ]
                rounding = roundSeconds
                lastUnitFractionalLen = 0
            case .hourMinuteSecond(let fractionalSecondsLength, let roundFractionalSeconds):
                units = [ .hours, .minutes, .seconds ]
                rounding = roundFractionalSeconds
                lastUnitFractionalLen = fractionalSecondsLength
            case .minuteSecond(let fractionalSecondsLength, let roundFractionalSeconds):
                units = [ .minutes, .seconds ]
                rounding = roundFractionalSeconds
                lastUnitFractionalLen = fractionalSecondsLength
            }

            let values = value.valuesForUnits(units, trailingFractionalLength: lastUnitFractionalLen, smallestUnitRounding: rounding, roundingIncrement: nil)
            assert(units.count == values.count)
            let unitValues = Dictionary(uniqueKeysWithValues: zip(units, values))

            let patternComponents = Self.componentsFromPatternString(patternString, patternSet: [ hourSymbol, minuteSymbol, secondSymbol ])

            return formatWithPatternComponents(patternComponents, hour: unitValues[.hours] ?? 0, minute: unitValues[.minutes] ?? 0, second: unitValues[.seconds] ?? 0)
        }

        internal struct PatternComponent {
            // Consecutive characters in a pattern that represents a single symbol or a literal string.
            // For example, in the "h':'mm" pattern, this could be [":"] or ["m", "m"].
            let symbols: [Character]

            // True if this component is one of the pre-defined symbols, or false if it's a literal string surrounded by single quotation marks.
            let isField: Bool

            // The start and end index of the component
            let start: Int
            let end: Int
        }

        // Parses a pattern string and returns a list of components the pattern specifies.
        // The pattern string should consist symbols (represented by a character) and literals (enclosed with single quotation marks).
        static func componentsFromPatternString(_ pattern: String, patternSet: [Character]) -> [PatternComponent] {
            var inQuote: Bool = false // inside a quoted literal
            var runBegin: Int = 0
            var runSymbol: Character?
            var runIsField: Bool = true

            var result = [PatternComponent]()
            var token = [Character]()

            for (idx, c) in pattern.enumerated() {
                // Record the previous token up until the current position if we see
                // 1) a different symbol while we're in the middle of parsing a field. This would happen if the pattern consists of multiple consecutive symbols that are not separated by literals, such as "hmmss".
                // or
                // 2) a literal while parsing a field, such as the first quotation mark of "h':'mm"
                let isField = !inQuote && patternSet.contains(c)
                if idx > runBegin, (isField && c != runSymbol) || (!isField && runIsField) {
                    result.append(PatternComponent(symbols: token, isField: runIsField, start: runBegin, end: idx))

                    token = []
                    runBegin = idx
                }

                if c == quoteSymbol {
                    if runSymbol == quoteSymbol {
                        token.append(quoteSymbol)
                    } else {
                        inQuote = !inQuote
                    }
                } else {
                    token.append(c)
                }

                runIsField = isField
                runSymbol = c
            }

            if !token.isEmpty {
                result.append(PatternComponent(symbols: token, isField: runIsField, start: runBegin, end: pattern.count))
            }

            return result
        }

        func formatWithPatternComponents(_ components: [PatternComponent], hour: Double, minute: Double, second: Double) -> AttributedString {
            // The number format does not contain rounding settings because it's handled on the value itself
            var numberFormatStyle = FloatingPointFormatStyle<Double>(locale: locale).grouping(grouping)
            var result = AttributedString()

            let isNegative = hour < 0 || minute < 0 || second < 0

            for component in components {
                var attr: AttributeScopes.FoundationAttributes.DurationFieldAttribute.Field?
                var substring: String
                if component.isField {
                    let patternSymbols = component.symbols
                    guard let symbol = patternSymbols.first else { continue }
                    var value: Double?
                    let isMostSignificantField: Bool

                    var minIntLength = patternSymbols.count
                    switch symbol {
                    case hourSymbol:
                        value = hour
                        if let padding = pattern.paddingForLargestField {
                            minIntLength = max(padding, patternSymbols.count)
                        }
                        numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: 0...0))
                        attr = .hours
                        isMostSignificantField = true
                    case minuteSymbol:
                        value = minute
                        switch pattern.fields {
                        case .hourMinute:
                            numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: 0...0))
                            isMostSignificantField = false
                        case .hourMinuteSecond:
                            numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: 0...0))
                            isMostSignificantField = false
                        case .minuteSecond:
                            if let padding = pattern.paddingForLargestField {
                                minIntLength = max(padding, patternSymbols.count)
                            }
                            numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: 0...0))
                            isMostSignificantField = true
                        }

                        attr = .minutes
                    case secondSymbol:
                        value = second
                        switch pattern.fields {
                        case .hourMinute:
                            break
                        case .hourMinuteSecond(let fractionalSecondsLength, _):
                            numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: fractionalSecondsLength...fractionalSecondsLength))
                        case .minuteSecond(let fractionalSecondsLength, _):
                            numberFormatStyle = numberFormatStyle.precision(.integerAndFractionLength(integerLimits: minIntLength..., fractionLimits: fractionalSecondsLength...fractionalSecondsLength))
                        }

                        attr = .seconds
                        isMostSignificantField = false
                    default:
                        isMostSignificantField = false
                    }

                    if var value = value {
                        // we only want the sign to show for the first component
                        // and only if the overall value is negative
                        let showNegativeSign = isNegative && isMostSignificantField

                        // if the first component is zero, we normally wouldn't get
                        // a negative sign, so we make the value a small negative
                        // value that still rounds to zero
                        if showNegativeSign && value == 0 {
                            value = -0.1
                        }

                        substring = numberFormatStyle
                            .sign(strategy: showNegativeSign
                                                ? .always(includingZero: true)
                                                : .never)
                            .format(value)
                    } else {
                        substring = String(component.symbols)
                    }
                } else {
                    substring = String(component.symbols)
                }

                let attrSubstring: AttributedString
                if let attr = attr {
                    attrSubstring = AttributedString(substring, attributes: .init().durationField(attr))
                } else {
                    attrSubstring = AttributedString(substring)
                }
                result += attrSubstring
            }

            return result
        }
    }
}

@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle {
    /// Returns a modified style that applies the given `grouping` rule to the highest field in the
    /// pattern.
    public func grouping(_ grouping: NumberFormatStyleConfiguration.Grouping) -> Self {
        var copy = self
        copy._attributed.grouping = grouping
        return copy
    }

    /// The `grouping` rule applied to high number values on the largest field in the pattern.
    public var grouping: NumberFormatStyleConfiguration.Grouping {
        get { _attributed.grouping }
        set { _attributed.grouping = newValue }
    }
}

@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle.Attributed {
    /// Returns a modified style that applies the given `grouping` rule to the highest field in the
    /// pattern.
    public func grouping(_ grouping: NumberFormatStyleConfiguration.Grouping) -> Self {
        var copy = self
        copy.grouping = grouping
        return copy
    }
}

// MARK: Dynamic Member Lookup

@available(FoundationPreview 0.4, *)
extension Duration.TimeFormatStyle.Attributed {
    private var innerStyle: Duration.TimeFormatStyle {
        get {
            .init(self)
        }
        set {
            self = newValue._attributed
        }
    }

    public subscript<T>(dynamicMember key: KeyPath<Duration.TimeFormatStyle, T>) -> T {
        innerStyle[keyPath: key]
    }

    public subscript<T>(dynamicMember key: WritableKeyPath<Duration.TimeFormatStyle, T>) -> T {
        get {
            innerStyle[keyPath: key]
        }
        set {
            innerStyle[keyPath: key] = newValue
        }
    }
}
