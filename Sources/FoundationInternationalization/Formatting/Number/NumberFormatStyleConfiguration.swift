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

@_nonSendable
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

    public typealias RoundingRule = FloatingPointRoundingRule

    typealias Scale = Double

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

        public static var automatic: Self { .init(option: .automatic) }
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

    public struct Precision : Codable, Hashable, Sendable {

        enum Option: Hashable {
            case significantDigits(min: Int, max: Int?)
            case integerAndFractionalLength(minInt: Int?, maxInt: Int?, minFraction: Int?, maxFraction: Int?)
        }
        var option: Option

        // The maximum total length that ICU allows is 999.
        // We take one off to reserve one character for the non-zero digit skeleton (the "0" skeleton in the number format)
        static var validPartLength = 0..<999
        static var validSignificantDigits = 1..<999

        // min 3, max 3: 12345 -> 12300
        // min 3, max 3: 0.12345 -> 0.123
        // min 2, max 4: 3.14159 -> 3.142
        // min 2, max 4: 1.23004 -> 1.23
        // ^ Trailing zero digits to the right of the decimal separator are suppressed after the minimum number of significant digits have been shown

        public static func significantDigits<R: RangeExpression>(_ limits: R) -> Self where R.Bound == Int {
            let (lower, upper) = limits.clampedLowerAndUpperBounds(validSignificantDigits)
            return Precision(option: .significantDigits(min: lower ?? validSignificantDigits.lowerBound, max: upper))
        }

        public static func significantDigits(_ digits: Int) -> Self {
            return Precision(option: .significantDigits(min: digits, max: digits))
        }

        // maxInt 2 : 1997 -> 97
        // minInt 5: 1997 -> 01997
        // maxFrac 2: 0.125 -> 0.12
        // minFrac 4: 0.125 -> 0.1250
        public static func integerAndFractionLength<R1: RangeExpression, R2: RangeExpression>(integerLimits: R1, fractionLimits: R2) -> Self where R1.Bound == Int, R2.Bound == Int {
            let (minInt, maxInt) =  integerLimits.clampedLowerAndUpperBounds(validPartLength)
            let (minFrac, maxFrac) = fractionLimits.clampedLowerAndUpperBounds(validPartLength)

            return Precision(option: .integerAndFractionalLength(minInt: minInt, maxInt: maxInt, minFraction: minFrac, maxFraction: maxFrac))
        }

        public static func integerAndFractionLength(integer: Int, fraction: Int) -> Self {
            return Precision(option: .integerAndFractionalLength(minInt: integer, maxInt: integer, minFraction: fraction, maxFraction: fraction))
        }

        public static func integerLength<R: RangeExpression>(_ limits: R) -> Self {
            let (minInt, maxInt) = limits.clampedLowerAndUpperBounds(validPartLength)
            return Precision(option: .integerAndFractionalLength(minInt: minInt, maxInt: maxInt, minFraction: nil, maxFraction: nil))
        }

        public static func integerLength(_ length: Int) -> Self  {
            return Precision(option: .integerAndFractionalLength(minInt: length, maxInt: length, minFraction: nil, maxFraction: nil))
        }

        public static func fractionLength<R: RangeExpression>(_ limits: R) -> Self where R.Bound == Int {
            let (minFrac, maxFrac) = limits.clampedLowerAndUpperBounds(validPartLength)
            return Precision(option: .integerAndFractionalLength(minInt: nil, maxInt: nil, minFraction: minFrac, maxFraction: maxFrac))
        }

        public static func fractionLength(_ length: Int) -> Self {
            return Precision(option: .integerAndFractionalLength(minInt: nil, maxInt: nil, minFraction: length, maxFraction: length))
        }
    }

    public struct DecimalSeparatorDisplayStrategy : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Codable, Hashable {
            case automatic
            case always
        }
        var option: Option

        // "1.1", "1"
        public static var automatic: Self {
            .init(option: .automatic)
        }

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

    public struct SignDisplayStrategy : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Hashable, Codable {
            case always
            case hidden
        }

        var positive: Option
        var negative: Option
        var zero: Option

        // Show the minus sign on negative numbers, and do not show the sign on positive numbers or zero
        public static var automatic: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden)
        }

        public static var never: Self {
            SignDisplayStrategy(positive: .hidden, negative: .hidden, zero: .hidden)
        }

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

    public struct Notation : Codable, Hashable, CustomStringConvertible, Sendable {
        enum Option : Int, Codable, Hashable {
            case automatic
            case scientific
            case compactName
        }
        var option: Option

        public static var scientific: Self { .init(option: .scientific) }
        public static var automatic: Self { .init(option: .automatic) }

        /// Formats the number with localized prefixes or suffixes corresponding to powers of ten. Rounds to integer while showing at least two significant digits by default.
        /// For example, "42.3K" for 42300 for the "en_US" locale.
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

@_nonSendable
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public enum CurrencyFormatStyleConfiguration {
    public typealias Grouping = NumberFormatStyleConfiguration.Grouping
    public typealias Precision = NumberFormatStyleConfiguration.Precision
    public typealias DecimalSeparatorDisplayStrategy = NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy
    public typealias RoundingRule = NumberFormatStyleConfiguration.RoundingRule

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
    }

    public struct SignDisplayStrategy: Codable, Hashable, Sendable {
        enum Option : Int, Hashable, Codable {
            case always
            case hidden
        }
        var positive: Option
        var negative: Option
        var zero: Option
        var accounting: Bool = false

        public static var automatic: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden)
        }

        public static var never: Self {
            SignDisplayStrategy(positive: .hidden, negative: .hidden, zero: .hidden)
        }

        // Show the minus sign on negative numbers and the plus sign on positive numbers, and zero if specified
        public static func always(showZero: Bool = true) -> Self {
            SignDisplayStrategy(positive: .always, negative: .always, zero: showZero ? .always : .hidden)
        }

        public static var accounting: Self {
            SignDisplayStrategy(positive: .hidden, negative: .always, zero: .hidden, accounting: true)
        }

        public static func accountingAlways(showZero: Bool = false) -> Self {
            SignDisplayStrategy(positive: .always, negative: .always, zero: showZero ? .always : .hidden, accounting: true)
        }
    }

    public struct Presentation: Codable, Hashable, Sendable {
        enum Option : Int, Codable, Hashable {
            case narrow
            case standard
            case isoCode
            case fullName
        }
        internal var option: Option

        public static var narrow: Self { Presentation(option: .narrow) }
        public static var standard: Self { Presentation(option: .standard) }
        public static var isoCode: Self { Presentation(option: .isoCode) }
        public static var fullName: Self { Presentation(option: .fullName) }
    }
}

@_nonSendable
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

#if os(Linux) || os(Windows) || FOUNDATION_FRAMEWORK
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension FloatingPointRoundingRule : Codable { }
#endif

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
        // Construct skeleton for fractonal part
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
            s += group.skeleton
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
