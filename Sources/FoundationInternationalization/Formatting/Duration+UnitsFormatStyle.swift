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


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Duration {

    /// A `FormatStyle` that displays a duration as a list of duration units, such as "2 hours, 43 minutes, 26 seconds" in English.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public struct UnitsFormatStyle : FormatStyle, Sendable {

        /// Specifies the width of the unit and the spacing of the value and the unit.
        public struct UnitWidth : Codable, Hashable, Sendable {
            var width: Measurement<UnitDuration>.FormatStyle.UnitWidth
            var patternStyle: UATimeUnitStyle

            /// Shows the full unit name, such as "3 hours" for a 3-hour duration in the en_US locale.
            public static var wide: UnitWidth { .init(width: .wide, patternStyle: UATIMEUNITSTYLE_FULL) }

            /// Shows the abbreviated unit name, such as "3 hr" for a 3-hour duration in the en_US locale.
            public static var abbreviated: UnitWidth { .init(width: .abbreviated, patternStyle: UATIMEUNITSTYLE_ABBREVIATED) }

            /// Shows the abbreviated unit name with a condensed space between the value and unit, such as "3hr" for a 3-hour duration in the en_US locale.
            public static var condensedAbbreviated: UnitWidth { .init(width: .abbreviated, patternStyle: UATIMEUNITSTYLE_SHORTER) }

            /// Shows the shortest unit name, such as "3h" for a 3-hour duration in the en_US locale.
            public static var narrow: UnitWidth { .init(width: .narrow, patternStyle: UATIMEUNITSTYLE_NARROW) }
        }

        /// Units that a duration can be displayed as with `UnitsFormatStyle`.
        public struct Unit : Codable, Hashable, Sendable {
            // Sorted from largest to smallest
            enum _Unit : Int, Codable, Hashable, Comparable, CaseIterable {
                static func < (lhs: Duration.UnitsFormatStyle.Unit._Unit, rhs: Duration.UnitsFormatStyle.Unit._Unit) -> Bool {
                    // It's more intuitive to represent comparison by the unit duration, i.e. .weeks > .hours
                    // But the raw value is ordered the other way; reverse the comparison
                    lhs.rawValue > rhs.rawValue
                }

                case weeks
                case days
                case hours
                case minutes
                case seconds
                case milliseconds
                case microseconds
                case nanoseconds
            }
            var unit: _Unit
            var icuSkeleton: String {
                var subtype: String
                switch unit {
                case .weeks:
                    subtype = "week"
                case .days:
                    subtype = "day"
                case .hours:
                    subtype = "hour"
                case .minutes:
                    subtype = "minute"
                case .seconds:
                    subtype = "second"
                case .milliseconds:
                    subtype = "millisecond"
                case .microseconds:
                    subtype = "microsecond"
                case .nanoseconds:
                    subtype = "nanosecond"
                }
                return "measure-unit/duration-\(subtype)"
            }

            /// The unit for weeks. One week is always 604800 seconds.
            public static var weeks: Unit { .init(unit: .weeks) }

            /// The unit for days. One day is always 86400 seconds.
            public static var days: Unit { .init(unit: .days) }

            /// The unit for hours. One day is 3600 seconds.
            public static var hours: Unit { .init(unit: .hours) }

            /// The unit for minutes. One minute is 60 seconds.
            public static var minutes: Unit { .init(unit: .minutes) }

            /// The unit for seconds.
            public static var seconds: Unit { .init(unit: .seconds) }

            /// The unit for milliseconds.
            public static var milliseconds: Unit { .init(unit: .milliseconds) }

            /// The unit for microseconds.
            public static var microseconds: Unit { .init(unit: .microseconds) }

            /// The unit for nanoseconds.
            public static var nanoseconds: Unit { .init(unit: .nanoseconds) }
        }

        /// Specifies how zero value units are handled.
        public struct ZeroValueUnitsDisplayStrategy : Codable, Hashable, Sendable {
            var length: Int

            /// Excludes zero-value units from the formatted string.
            public static var hide: ZeroValueUnitsDisplayStrategy { .init(length: 0) }

            /// Displays zero-value units with zero padding to the specified length.
            public static func show(length: Int) -> ZeroValueUnitsDisplayStrategy { .init(length: length)}
        }

        /// Specifies how a duration is displayed if it cannot be represented exactly with the allowed units.
        ///
        /// For example, you can change this option to show a duration of 1 hour and 15 minutes as "1.25 hr", "1 hr", or "1.5 hr" with different lengths and rounding rules when hour is the only allowed unit.
        public struct FractionalPartDisplayStrategy : Codable, Hashable, Sendable {
            public var minimumLength: Int
            public var maximumLength: Int
            public var roundingRule: FloatingPointRoundingRule
            public var roundingIncrement: Double?

            init(mininumLength: Int, maximumLength: Int, roundingRule: FloatingPointRoundingRule, roundingIncrement: Double?) {
                self.minimumLength = mininumLength
                self.maximumLength = maximumLength
                self.roundingRule = roundingRule
                self.roundingIncrement = roundingIncrement
            }

            /// Displays the remaining part as the fractional part of the smallest unit.
            /// - Parameters:
            ///   - lengthLimits: The range of the length of the fractional part.
            ///   - roundingRule: Rounding rule for the remaining value.
            ///   - roundingIncrement: Rounding increment for the remaining value.
            public init<Range: RangeExpression>(lengthLimits: Range, roundingRule: FloatingPointRoundingRule = .toNearestOrEven, roundingIncrement: Double? = nil) where Range.Bound == Int {
                let (lower, upper) = lengthLimits.clampedLowerAndUpperBounds(0..<Int.max)
                self.init(mininumLength: lower ?? 0, maximumLength: upper ?? Int.max, roundingRule: roundingRule, roundingIncrement: roundingIncrement)
            }

            /// Displays the remaining part as the fractional part of the smallest unit.
            /// - Parameters:
            ///   - length: The length of the fractional part.
            ///   - rule: Rounding rule for the remaining value.
            ///   - increment: Rounding increment for the remaining value.
            public static func show(length: Int, rounded rule: FloatingPointRoundingRule = .toNearestOrEven, increment: Double? = nil) -> FractionalPartDisplayStrategy {
                .init(mininumLength: length, maximumLength: length, roundingRule: rule, roundingIncrement: increment)
            }

            /// Excludes the remaining part.
            public static var hide: FractionalPartDisplayStrategy {
                .init(mininumLength: 0, maximumLength: 0, roundingRule: .toNearestOrEven, roundingIncrement: nil)
            }

            /// Excludes the remaining part with the specified rounding rule.
            /// - Parameter rounded: Rounding rule for the remaining value.
            public static func hide(rounded: FloatingPointRoundingRule = .toNearestOrEven) -> FractionalPartDisplayStrategy {
                .init(mininumLength: 0, maximumLength: 0, roundingRule: rounded, roundingIncrement: nil)
            }

        }

        /// The locale to use when formatting the duration.
        public var locale: Locale

        /// The units that may be included in the output string.
        public var allowedUnits: Set<Unit>

        /// The width of the unit and the spacing between the value and the unit.
        public var unitWidth: UnitWidth

        /// The maximum number of time units to include in the output string.
        public var maximumUnitCount: Int?

        /// The strategy for how zero-value units are handled.
        public var zeroValueUnitsDisplay: ZeroValueUnitsDisplayStrategy

        /// The strategy for displaying a duration if it cannot be represented exactly with the allowed units.
        public var fractionalPartDisplay: FractionalPartDisplayStrategy

        /// The padding or truncating behavior of the unit value.
        ///
        /// For example, set this to `2...` to force 2-digit padding on all units.
        public var valueLengthLimits: Range<Int>?

        /// Creates an instance using the provided specifications.
        /// - Parameters:
        ///   - allowedUnits: The units that may be included in the output string.
        ///   - width: The width of the unit and the spacing between the value and the unit.
        ///   - maximumUnitCount: The maximum number of time units to include in the output string.
        ///   - zeroValueUnits: The strategy for how zero-value units are handled.
        ///   - valueLength: The padding or truncating behavior of the unit value. Negative values are ignored.
        ///   - fractionalPart: The strategy for displaying a duration if it cannot be represented exactly with the allowed units.
        public init(allowedUnits: Set<Unit>, width: UnitWidth, maximumUnitCount: Int? = nil, zeroValueUnits: ZeroValueUnitsDisplayStrategy = .hide, valueLength: Int? = nil, fractionalPart: FractionalPartDisplayStrategy = .hide) {
            self.allowedUnits = allowedUnits
            self.unitWidth = width
            self.maximumUnitCount = maximumUnitCount
            self.zeroValueUnitsDisplay = zeroValueUnits
            self.fractionalPartDisplay = fractionalPart
            if let valueLength, valueLength > 0 {
                let upperBound = min(Int.max - 1, valueLength)
                self.valueLengthLimits = upperBound ..< upperBound + 1
            } else {
                self.valueLengthLimits = nil
            }
            self.locale = .autoupdatingCurrent
        }

        /// Creates an instance using the provided specifications.
        /// - Parameters:
        ///   - allowedUnits: The units that may be included in the output string.
        ///   - width: The width of the unit and the spacing between the value and the unit.
        ///   - maximumUnitCount: The maximum number of time units to include in the output string.
        ///   - zeroValueUnits: The strategy for how zero-value units are handled.
        ///   - valueLengthLimits: The padding or truncating behavior of the unit value. Values with negative bounds are ignored.
        ///   - fractionalPart: The strategy for displaying a duration if it cannot be represented exactly with the allowed units.
        public init<ValueRange: RangeExpression>(allowedUnits: Set<Unit>, width: UnitWidth, maximumUnitCount: Int? = nil, zeroValueUnits: ZeroValueUnitsDisplayStrategy = .hide, valueLengthLimits: ValueRange, fractionalPart: FractionalPartDisplayStrategy = .hide) where ValueRange.Bound == Int {
            self.allowedUnits = allowedUnits
            self.unitWidth = width
            self.maximumUnitCount = maximumUnitCount
            self.zeroValueUnitsDisplay = zeroValueUnits
            self.fractionalPartDisplay = fractionalPart
            let (lower, upper) = valueLengthLimits.clampedLowerAndUpperBounds(0..<Int.max)
            if lower == nil && upper == nil {
                self.valueLengthLimits = nil
            } else {
                self.valueLengthLimits = (lower ?? 0) ..< (upper ?? Int.max)
            }

            self.locale = .autoupdatingCurrent
        }

        // MARK: - `FormatStyle` conformance

        /// Creates a locale-aware string representation from a duration value.
        /// - Parameter duration: The value to format.
        /// - Returns: A string representation of the duration.
        public func format(_ duration: Duration) -> String {
            let formattedFields = _formatFields(duration)
            var result = _getFullListPattern(length: formattedFields.count)
            for formattedField in formattedFields.reversed() {
                let range = result._range(of: "{0}", anchored: false, backwards: true)!
                result.replaceSubrange(range, with: formattedField)
            }
            return result
        }

        // The number format does not contain rounding settings because it's handled on the value itself
        func _createNumberFormatStyle(useFractionalLimitsIfAvailable: Bool) -> FloatingPointFormatStyle<Double> {
            var collection = NumberFormatStyleConfiguration.Collection()

            let fractionalLimits = useFractionalLimitsIfAvailable ? fractionalPartDisplay.minimumLength...fractionalPartDisplay.maximumLength : 0...0
            let zeroValueLimits = zeroValueUnitsDisplay.length...
            if let valueLengthLimits = valueLengthLimits, zeroValueUnitsDisplay.length > 0 {
                let tightestLimits = zeroValueLimits.relative(to: valueLengthLimits)
                collection.precision = .integerAndFractionLength(integerLimits: tightestLimits, fractionLimits: fractionalLimits)
            } else if let valueLengthLimits = valueLengthLimits {
                collection.precision = .integerAndFractionLength(integerLimits: valueLengthLimits, fractionLimits: fractionalLimits)
            } else if zeroValueUnitsDisplay.length > 0 {
                collection.precision = .integerAndFractionLength(integerLimits: zeroValueLimits, fractionLimits: fractionalLimits)
            } else {
                collection.precision = .fractionLength(fractionalLimits)
            }

            var format = FloatingPointFormatStyle<Double>(locale: locale)
            format.collection = collection

            return format
        }

        func _formatFields(_ duration: Duration) -> [String] {
            let skeletons = _getSkeletons(duration)
            return skeletons.map { (skeleton: String, unit: Unit, value: Double) in
                let numberFormatter = ICUMeasurementNumberFormatter.create(for: skeleton, locale: locale)!
                let formatted = numberFormatter.format(value)
                return formatted ?? "\(value) \(unit.icuSkeleton)" // Return a description if ICU can't format it
            }
        }

        func _getSkeletons(_ duration: Duration) -> [(skeleton: String, measurementUnit: Unit, measurementValue: Double)] {

            let (units, values) = Self.unitsToUse(duration: duration, allowedUnits: allowedUnits, maximumUnitCount: maximumUnitCount, roundSmallerParts: fractionalPartDisplay.roundingRule, trailingFractionalPartLength: fractionalPartDisplay.maximumLength, roundingIncrement: fractionalPartDisplay.roundingIncrement, dropZeroUnits: zeroValueUnitsDisplay.length <= 0)

            let numberFormatStyleWithFraction = _createNumberFormatStyle(useFractionalLimitsIfAvailable: true)
            let numberFormatStyleNoFraction = _createNumberFormatStyle(useFractionalLimitsIfAvailable: false)

            if units.count == 0, let smallest = allowedUnits.sorted(by: { $0.unit.rawValue < $1.unit.rawValue }).last {
                // Fallback to the smallest allowed unit when there is no units to show, such as when the duration is 0 and client wants to hide zero fields

                let skeleton = ICUMeasurementNumberFormatter.skeleton(smallest.icuSkeleton, width: .init(unitWidth), usage: nil, numberFormatStyle: numberFormatStyleWithFraction)

                return [(skeleton, measurementUnit: smallest, measurementValue: 0)]
            }

            var result = [(skeleton: String, measurementUnit: Unit, measurementValue: Double)]()

            let isNegative = values.contains(where: { $0 < 0 })

            lazy var mostSignificantUnit = units.map(\.unit).max()

            for (index, (unit, value)) in zip(units, values).enumerated() {
                var numberFormatStyle: FloatingPointFormatStyle<Double>
                if index == units.count - 1 {
                    numberFormatStyle = numberFormatStyleWithFraction
                } else {
                    numberFormatStyle = numberFormatStyleNoFraction
                }

                var value = value
                // we only want the sign to show for the first component
                // and only if the overall value is negative
                if isNegative && unit.unit == mostSignificantUnit {
                    numberFormatStyle = numberFormatStyle.sign(strategy: .always(includingZero: true))
                    // if the first component is zero, we normally wouldn't get
                    // a negative sign, so we make the value a small negative
                    // value that still rounds to zero
                    if value == .zero {
                        value = -0.1
                    }
                } else {
                    numberFormatStyle = numberFormatStyle.sign(strategy: .never)
                }


                let skeleton = ICUMeasurementNumberFormatter.skeleton(unit.icuSkeleton, width: .init(unitWidth), usage: nil, numberFormatStyle: numberFormatStyle)

                result.append((skeleton: skeleton, measurementUnit: unit, measurementValue: value))
            }

            return result
        }

        func _getListPattern(_ type: UATimeUnitListPattern) -> String {
            let listPattern = _withFixedUCharBuffer(size: 128) { buffer, size, status in
                uatmufmt_getListPattern(locale.identifier, unitWidth.patternStyle, type, buffer, size, &status)
            }

            if let listPattern {
                return listPattern
            } else {
                let fallbackPattern = "{0}, {1}"
                return fallbackPattern
            }
        }

        // A list pattern has a form such as
        //
        // unit-short{
        //    2{"{0}, {1}"}
        //    end{"{0}, {1}"}
        //    middle{"{0}, {1}"}
        //    start{"{0}, {1}"}
        // }
        //
        // Returns a "combined list pattern" that contains all the start, middle and end parts. The returned pattern uses "{0}" as the placeholder. The result looks something like this: "{0}, {0}, {0}, and {0}"
        func _getFullListPattern(length: Int) -> String {
            let placeholder = "{0}"
            let lastPlaceholder = "{1}"

            var pattern: String!

            switch length {
            case 1:
                pattern = placeholder
            case 2:
                pattern = self._getListPattern(UATIMEUNITLISTPAT_TWO_ONLY)
                pattern.replace(lastPlaceholder, with: placeholder)
            case let length:
                let middle = self._getListPattern(UATIMEUNITLISTPAT_MIDDLE_PIECE)

                pattern = self._getListPattern(UATIMEUNITLISTPAT_START_PIECE)
                // Each of the three pieces provides _two_ placeholders each,
                // such that we start with two and each replacement adds one
                // more, so start the loop at 2 as well.
                for _ in 2 ..< (length - 1) {
                    pattern.replace(lastPlaceholder, with: middle)
                }

                pattern.replace(lastPlaceholder, with: self._getListPattern(UATIMEUNITLISTPAT_END_PIECE))
                pattern.replace(lastPlaceholder, with: placeholder)
            }
            return pattern
        }

        static func removingZeroUnits(units: [Unit], values: [Double]) -> (units: [Unit], values: [Double]) {
            var nonZeroUnits = [Unit]()
            var nonZeroValues = [Double]()
            for (idx, value) in values.enumerated() {
                if value != 0 {
                    nonZeroUnits.append(units[idx])
                    nonZeroValues.append(value)
                }
            }
            return (nonZeroUnits, nonZeroValues)
        }

        // Returns the units that are going to show up in the final string, sorted from largest to smallest
        static func unitsToUse(duration: Duration, allowedUnits: Set<Unit>, maximumUnitCount: Int?, roundSmallerParts: FloatingPointRoundingRule, trailingFractionalPartLength: Int, roundingIncrement: Double?, dropZeroUnits: Bool) -> (units: [Unit], values: [Double]) {

            var units = allowedUnits.sorted { $0.unit.rawValue < $1.unit.rawValue }
            var values = duration.valuesForUnits(units, trailingFractionalLength: trailingFractionalPartLength, smallestUnitRounding: roundSmallerParts, roundingIncrement: roundingIncrement)

            // First check if we fit in `maximumUnitCount`
            if maximumUnitCount == nil || allowedUnits.count <= maximumUnitCount! {
                return dropZeroUnits ? removingZeroUnits(units: units, values: values) : (units, values)
            }

            let maximumUnitCount = maximumUnitCount!

            // If we can drop zero fields, check if the units fit in after dropping them
            if dropZeroUnits {
                let (nonZeroUnits, nonZeroValues) = removingZeroUnits(units: units, values: values)
                if nonZeroUnits.count <= maximumUnitCount {
                    return (nonZeroUnits, nonZeroValues)
                } else {
                    units = nonZeroUnits
                    values = nonZeroValues
                }
            }

            // We can't drop zero fields, or dropping them still exceeds `maximumUnitCount`
            // Move on to collapse units to fit into `maximumUnitCount`
            let idx = values.firstIndex { $0 != 0 }
            guard let idx = idx else {
                // Cannot generate a list of units using `allowedUnits`.
                return (units, values)
            }

            let r = idx ..< min(units.count, idx + maximumUnitCount)
            let usefulUnits = Array(units[r])
            let usefulValues = duration.valuesForUnits(usefulUnits, trailingFractionalLength: trailingFractionalPartLength, smallestUnitRounding: roundSmallerParts, roundingIncrement: roundingIncrement)

            return (usefulUnits, usefulValues)
        }

        /// A modifier to set the locale of the format style.
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A copy of this format with the new locale set.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }

        /// Returns a `Duration.UnitsFormatStyle.Attributed` style to format a duration as an attributed string using the configuration of this format style. Units in the string are annotated with the `durationField` and `measurement` attribute keys and the `DurationFieldAttribute` and `MeasurementAttribute` attribute values.
        ///
        /// For example, formatting a duration of 2 hours, 43 minutes, 26.25 second in `en_US` locale yeilds the following conceptually
        /// ```
        /// 2 { durationField: .hours, component: .value }
        /// hours { durationField: .hours, component: .unit }
        /// , { nil }
        /// 43 { durationField: .minutes, component: .value }
        /// minutes { durationField: .minutes, component: .unit }
        /// , { nil }
        /// 26.25 { durationField: .seconds, component: .value }
        /// seconds { durationField: .seconds, component: .unit }
        /// ```
        public var attributed: Attributed {
            Attributed(innerStyle: self)
        }
    }

    // For testing purpose. See notes about String._Encoding
    internal typealias _UnitsFormatStyle = UnitsFormatStyle
}

// `FormatStyle` static membership lookup
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension FormatStyle where Self == Duration.UnitsFormatStyle {
    /// A factory function to create a units format style to format a duration.
    /// - Parameters:
    ///   - units: The units that may be included in the output string.
    ///   - width: The width of the unit and the spacing between the value and the unit.
    ///   - maximumUnitCount: The maximum number of time units to include in the output string.
    ///   - zeroValueUnits: The strategy for how zero-value units are handled.
    ///   - valueLength: The padding or truncating behavior of the unit value.
    ///   - fractionalPart: The strategy for displaying a duration if it cannot be represented exactly with the allowed units.
    /// - Returns: A format style to format a duration.
    public static func units(allowed units: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds], width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated, maximumUnitCount : Int? = nil, zeroValueUnits: Duration.UnitsFormatStyle.ZeroValueUnitsDisplayStrategy = .hide, valueLength: Int? = nil, fractionalPart: Duration.UnitsFormatStyle.FractionalPartDisplayStrategy = .hide) -> Self {
        .init(allowedUnits: units, width: width, maximumUnitCount: maximumUnitCount, zeroValueUnits: zeroValueUnits, valueLength: valueLength, fractionalPart: fractionalPart)
    }

    /// A factory function to create a units format style to format a duration.
    /// - Parameters:
    ///   - allowedUnits: The units that may be included in the output string.
    ///   - width: The width of the unit and the spacing between the value and the unit.
    ///   - maximumUnitCount: The maximum number of time units to include in the output string.
    ///   - zeroValueUnits: The strategy for how zero-value units are handled.
    ///   - valueLengthLimits: The padding or truncating behavior of the unit value.
    ///   - fractionalPart: The strategy for displaying a duration if it cannot be represented exactly with the allowed units.
    ///   - Returns: A format style to format a duration.
    public static func units<ValueRange: RangeExpression>(allowed units: Set<Duration.UnitsFormatStyle.Unit> = [.hours, .minutes, .seconds], width: Duration.UnitsFormatStyle.UnitWidth = .abbreviated, maximumUnitCount : Int? = nil, zeroValueUnits: Duration.UnitsFormatStyle.ZeroValueUnitsDisplayStrategy = .hide, valueLengthLimits: ValueRange, fractionalPart: Duration.UnitsFormatStyle.FractionalPartDisplayStrategy = .hide) -> Self where ValueRange.Bound == Int {
        .init(allowedUnits: units, width: width, maximumUnitCount: maximumUnitCount, zeroValueUnits: zeroValueUnits, valueLengthLimits: valueLengthLimits, fractionalPart: fractionalPart)
    }
}

// MARK: - Attributed style

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Duration.UnitsFormatStyle {

    /// A format style to format a duration as an attributed string. Units in the string are annotated with the `durationField` and `measurement` attribute keys and the `DurationFieldAttribute` and `MeasurementAttribute` attribute values.
    ///
    /// You can use `Duration.UnitsFormatStyle` to configure the style, and create an `Attributed` format with its `public var attributed: Attributed`
    ///
    /// For example, formatting a duration of 2 hours, 43 minutes, 26.25 second in `en_US` locale yeilds the following conceptually
    /// ```
    /// 2 { durationField: .hours, component: .value }
    /// hours { durationField: .hours, component: .unit }
    /// , { nil }
    /// 43 { durationField: .minutes, component: .value }
    /// minutes { durationField: .minutes, component: .unit }
    /// , { nil }
    /// 26.25 { durationField: .seconds, component: .value }
    /// seconds { durationField: .seconds, component: .unit }
    /// ```
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @dynamicMemberLookup
    public struct Attributed : FormatStyle, Sendable {

        var innerStyle: Duration.UnitsFormatStyle

        /// Formats a duration as an attributed string with `DurationFieldAttribute`.
        public func format(_ duration: Duration) -> AttributedString {
            let formattedFields = _formatFields(duration)
            var result = AttributedString(innerStyle._getFullListPattern(length: formattedFields.count))
            for formattedField in formattedFields.reversed() {
                let range = result.range(of: "{0}", options: [.backwards])!
                result.replaceSubrange(range, with: formattedField)
            }

            return result
        }

        /// A modifier to set the locale of the format style.
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A copy of this format with the new locale set.
        public func locale(_ locale: Locale) -> Self {
            Attributed(innerStyle: innerStyle.locale(locale))
        }

        func _formatFields(_ duration: Duration) -> [AttributedString] {
            typealias Component = AttributeScopes.FoundationAttributes.MeasurementAttribute.Component
            typealias DurationField = AttributeScopes.FoundationAttributes.DurationFieldAttribute.Field

            let skeletons = innerStyle._getSkeletons(duration)
            return skeletons.map { (skeleton: String, unit: Unit, value: Double) in
                let numberFormatter = ICUMeasurementNumberFormatter.create(for: skeleton, locale: innerStyle.locale)!
                var durationField: DurationField!
                switch unit.unit {
                case .weeks:
                    durationField = .weeks
                case .days:
                    durationField = .days
                case .hours:
                    durationField = .hours
                case .minutes:
                    durationField = .minutes
                case .seconds:
                    durationField = .seconds
                case .milliseconds:
                    durationField = .milliseconds
                case .microseconds:
                    durationField = .microseconds
                case .nanoseconds:
                    durationField = .nanoseconds
                }

                guard let (str, attributes) = numberFormatter.attributedFormatPositions(.floatingPoint(value)) else {
                    return AttributedString(innerStyle.format(duration), attributes: .init().durationField(durationField))
                }

                var attrStr = AttributedString(str)
                attrStr.durationField = durationField

                for attr in attributes {
                    var component: Component?
                    switch attr.field {
                    case .measureUnit:
                        component = .unit
                    default:
                        component = .value
                    }

                    let strRange = String.Index(utf16Offset: attr.begin, in: str)..<String.Index(utf16Offset: attr.end, in: str)
                    if let range = Range(strRange, in: attrStr) {
                        attrStr[range].measurement = component
                    }

                }
                return attrStr
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension UATimeUnitStyle : Codable, Hashable {}

// MARK: Dynamic Member Lookup

@available(FoundationPreview 0.4, *)
extension Duration.UnitsFormatStyle.Attributed {
    public subscript<T>(dynamicMember key: KeyPath<Duration.UnitsFormatStyle, T>) -> T {
        innerStyle[keyPath: key]
    }

    public subscript<T>(dynamicMember key: WritableKeyPath<Duration.UnitsFormatStyle, T>) -> T {
        get {
            innerStyle[keyPath: key]
        }
        set {
            innerStyle[keyPath: key] = newValue
        }
    }
}

// MARK: DiscreteFormatStyle Conformance

@available(FoundationPreview 0.4, *)
extension Duration.UnitsFormatStyle.Attributed : DiscreteFormatStyle {
    public func discreteInput(before input: Duration) -> Duration? {
        self.innerStyle.discreteInput(before: input)
    }

    public func discreteInput(after input: Duration) -> Duration? {
        self.innerStyle.discreteInput(after: input)
    }
}

@available(FoundationPreview 0.4, *)
extension Duration.UnitsFormatStyle : DiscreteFormatStyle {
    public func discreteInput(before input: Duration) -> Duration? {
        let (bound, isIncluded) = self.bound(for: input, countingDown: true)

        return isIncluded ? bound.nextDown : bound
    }

    public func discreteInput(after input: Duration) -> Duration? {
        let (bound, isIncluded) = self.bound(for: input, countingDown: false)

        return isIncluded ? bound.nextUp : bound
    }

    private func bound(for input: Duration, countingDown: Bool) -> (bound: Duration, includedInRangeOfInput: Bool) {
        // Initially we determine the interval for the smallest unit that is used to
        // format `input`. If `forceRoundingToFull` is true, that is because we are
        // rounding `toNearestOr` and we are close to the point where `interval`
        // changes.
        let (interval, forceRoundingToFull) = interval(for: input,
                                                       countingDown: countingDown,
                                                       allowedUnits: self.allowedUnits)

        // Thus, if `forceRoundingToFull` is true, we round `.towardZero`. E.g.
        // if we can only show one unit and we're at -70 seconds, we format that
        // as "1 minute". By rounding `.towardZero`, we get 60 seconds as the
        // `unadjustedBound`, not 30 seconds as we would get for `toNearestOr`
        // rounding.
        let (unadjustedBound, includedInRangeOfInput) = Duration.bound(for: input,
                                                                       in: interval,
                                                                       countingDown: countingDown,
                                                                       roundingRule: forceRoundingToFull ? .towardZero : self.fractionalPartDisplay.roundingRule)

        // If we didn't `forceRoundingToFull`, we're done at this point. However,
        // if we did, we determine the bound again, disallowing the unit that
        // would just fit the `unadjustedBound` (in the example `.minute`), so
        // we get the appropriate bound for the smaller unit, which would be
        // 59.5 seconds in the example, rendered as "59 seconds".
        if forceRoundingToFull {
            let (bound, includedInRangeOfInput) = Duration.bound(for: unadjustedBound,
                                                                    in: self.interval(for: unadjustedBound,
                                                                                      countingDown: countingDown,
                                                                                      allowedUnits: allowedUnits.filter({ Duration.interval(for: $0) < abs(unadjustedBound) })).duration,
                                                                    countingDown: countingDown,
                                                                    roundingRule: self.fractionalPartDisplay.roundingRule)

            return (bound, includedInRangeOfInput)
        } else {
            return (unadjustedBound, includedInRangeOfInput)
        }
    }

    private func interval(for input: Duration, countingDown: Bool, allowedUnits: Set<Unit>) -> (duration: Duration, forceRoundingToFull: Bool) {
        let allowedUnits = Unit._Unit.allCases.filter({ allowedUnits.contains(.init(unit: $0)) }).map({ Unit(unit: $0) })

        guard let smallestAllowedUnit = allowedUnits.last else {
            return (.seconds(Int64.max), false)
        }

        var remainder = input
        var visibleUnitLimit = self.maximumUnitCount ?? allowedUnits.count
        var smallestInterval: Duration!
        var forceRoundingToFull = false

        let roundsToHalf = self.fractionalPartDisplay.roundingRule == .toNearestOrEven || self.fractionalPartDisplay.roundingRule == .toNearestOrAwayFromZero

        for unit in allowedUnits {
            guard visibleUnitLimit > 0 else {
                break
            }

            let unitInterval = Duration.interval(for: unit)

            let roundedRemainder = input.rounded(increment: Duration.interval(for: smallestAllowedUnit,
                                                                       fractionalDigits: self.fractionalPartDisplay.maximumLength,
                                                                       roundingIncrement: self.fractionalPartDisplay.roundingIncrement),
                                          rule: self.fractionalPartDisplay.roundingRule)

            guard unit == smallestAllowedUnit || unitInterval < abs(roundedRemainder) || unitInterval == abs(roundedRemainder) && (remainder < .zero) == countingDown else {
                continue
            }



            var interval: Duration
            if unit == smallestAllowedUnit || visibleUnitLimit == 1  {
                interval = Duration.interval(for: unit, fractionalDigits: self.fractionalPartDisplay.maximumLength, roundingIncrement: self.fractionalPartDisplay.roundingIncrement)
            } else {
                interval = Duration.interval(for: unit)
            }

            if roundsToHalf && countingDown == (remainder > .zero) && abs(remainder) <= unitInterval + interval / 2 && unit != smallestAllowedUnit && visibleUnitLimit == 1 {
                forceRoundingToFull = true
            } else {
                forceRoundingToFull = false
            }

            let value = roundedRemainder.rounded(increment: interval, rule: .towardZero)

            remainder -= value

            if value != .zero || self.zeroValueUnitsDisplay.length > 0 {
                visibleUnitLimit -= 1
            }

            smallestInterval = interval
        }


        return (smallestInterval, forceRoundingToFull)
    }
}
