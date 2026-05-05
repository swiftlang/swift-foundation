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

/// A format style that provides string representations of byte counts.
///
/// The following example creates an `Int` representing 1,024 bytes, and then formats it as an
/// expression of memory storage, with the default byte count format style.
///
/// ```swift
/// let count: Int64 = 1024
/// let formatted = count.formatted(.byteCount(style: .memory)) // "1 kB"
/// ```
///
/// You can also customize a byte count format style, and use this to format one or more `Int64`
/// instances. The following example creates a format style to only use kilobyte units, and to
/// spell out the exact byte count of the measurement.
///
/// ```swift
/// let style = ByteCountFormatStyle(
///     style: .memory,
///     allowedUnits: [.kb],
///     spellsOutZero: true,
///     includesActualByteCount: false,
///     locale: Locale(identifier: "en_US"))
/// let counts: [Int64] = [0, 1024, 2048, 4096, 8192, 16384, 32768, 65536]
/// let formatted = counts.map { style.format($0) }
/// // ["Zero kB", "1 kB", "2 kB", "4 kB", "8 kB", "16 kB", "32 kB", "64 kB"]
/// ```
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ByteCountFormatStyle: FormatStyle, Sendable {
    /// The semantic style the format style uses to represent a byte count value.
    public var style: Style { get { attributed.style } set { attributed.style = newValue} }
    /// The units the format style can use to express the byte count.
    public var allowedUnits: Units { get { attributed.allowedUnits } set { attributed.allowedUnits = newValue} }
    /// A Boolean value that indicates whether the format style should spell out zero-byte values as text.
    public var spellsOutZero: Bool { get { attributed.spellsOutZero } set { attributed.spellsOutZero = newValue} }
    /// A Boolean value that indicates whether the format style should include the exact byte count, in addition to expressing it in terms of units.
    public var includesActualByteCount: Bool { get { attributed.includesActualByteCount } set { attributed.includesActualByteCount = newValue} }
    /// The locale to use to format the numeric part of the byte count.
    public var locale: Locale { get { attributed.locale } set { attributed.locale = newValue} }
    /// An attributed format style based on the byte count format style.
    public var attributed: Attributed

    internal enum Unit: Int {
        case byte = 0
        case kilobyte
        case megabyte
        case gigabyte
        case terabyte
        case petabyte
        // 84270854: The ones below are still pending support by ICU 69.
        case exabyte
        case zettabyte
        case yottabyte

        var name: String {
            Self.unitNames[rawValue]
        }

        var decimalSize: Int64 {
            Self.decimalByteSizes[rawValue]
        }

        var binarySize: Int64 {
            Self.binaryByteSizes[rawValue]
        }

        static let unitNames = ["byte", "kilobyte", "megabyte", "gigabyte", "terabyte", "petabyte"]
        static let decimalByteSizes: [Int64] = [1, 1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000, 1_000_000_000_000_000]
        static let binaryByteSizes: [Int64] = [1, 1024, 1048576, 1073741824, 1099511627776, 1125899906842624]
    }

    /// Formats a numeric byte count, using this style.
    public func format(_ value: Int64) -> String {
        String(attributed.format(value).characters)
    }

    /// Modifies the format style to use the specified locale.
    public func locale(_ locale: Locale) -> Self {
        var new = self
        new.locale = locale
        return new
    }

    /// Initializes a byte count format style.
    public init(style: Style = .file, allowedUnits: Units = .all, spellsOutZero: Bool = true, includesActualByteCount: Bool = false, locale: Locale = .autoupdatingCurrent) {
        self.attributed = Attributed(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount, locale: locale)
    }

    /// The semantic style to use when formatting a byte count value.
    public enum Style: Int, Codable, Hashable, Sendable {
        /// A style for representing file system storage.
        case file = 0
        /// The style for representing memory usage.
        case memory
        /// A style for representing byte counts as decimal values.
        case decimal
        /// A style for representing byte counts as binary values.
        case binary
    }

    /// The units to use when formatting a byte count, such as kilobytes or gigabytes.
    public struct Units: OptionSet, Codable, Hashable, Sendable {
        public var rawValue: UInt

        public init(rawValue: UInt) {
            if rawValue == 0 {
                self = .all
            } else {
                self.rawValue = rawValue
            }
        }

        /// A value that indicates a format style should express byte counts in individual bytes.
        public static var bytes: Self { Self(rawValue: 1 << 0) }
        /// The kilobytes unit.
        public static var kb: Self { Self(rawValue: 1 << 1) }
        /// The megabytes unit.
        public static var mb: Self { Self(rawValue: 1 << 2) }
        /// The gigabytes unit.
        public static var gb: Self { Self(rawValue: 1 << 3) }
        /// The terabytes unit.
        public static var tb: Self { Self(rawValue: 1 << 4) }
        /// The petabytes unit.
        public static var pb: Self { Self(rawValue: 1 << 5) }
        /// The exabytes unit.
        public static var eb: Self { Self(rawValue: 1 << 6) }
        /// The zettabytes unit.
        public static var zb: Self { Self(rawValue: 1 << 7) }
        /// A value that indicates a format style should express byte counts as yottabytes or higher.
        public static var ybOrHigher: Self { Self(rawValue: 0x0FF << 8) }

        /// A value that allows the use of all byte-count units.
        public static var all: Self { .init(rawValue: 0x0FFFF) }
        /// A value that indicates a format style should use the most appropriate units to express a byte count.
        public static var `default`: Self { .all }

        fileprivate var smallestUnit: Unit {
            for idx in (Unit.byte.rawValue...Unit.petabyte.rawValue) {
                if self.contains(.init(rawValue: UInt(idx))) { return Unit(rawValue: idx)! }
            }
            // 84270854: Fall back to petabyte if the unit is larger than petabyte, which is the largest we currently support
            return .petabyte
        }
    }

    /// A format style that converts byte counts into attributed strings.
    ///
    /// Use the ``ByteCountFormatStyle/attributed`` modifier on a ``ByteCountFormatStyle`` to create a format style of this type.
    ///
    /// The attributed strings that this format style creates contain attributes from the ``AttributeScopes/FoundationAttributes/NumberFormatAttributes`` attribute scope. Use these attributes to determine which runs of the attributed string represent different parts of the formatted value.
    public struct Attributed: FormatStyle, Sendable {
        /// The semantic style the format style uses to represent a byte count value.
        public var style: Style
        /// The units the format style can use to express the byte count.
        public var allowedUnits: Units
        /// A Boolean value that indicates whether the format style should spell out zero-byte values as text.
        public var spellsOutZero: Bool
        /// A Boolean value that indicates whether the format style should include the exact byte count, in addition to expressing it in terms of units.
        public var includesActualByteCount: Bool
        /// The locale to use to format the numeric part of the byte count.
        public var locale: Locale

        /// Modifies the format style to use the specified locale.
        ///
        /// - Parameter locale: The locale to apply to the format style.
        /// - Returns: A format style that uses the specified locale.
        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }

        // Max sizes to use for a given unit.
        // These sizes take into account the precision of each unit. e.g. 1023.95 MB should be formatted as 1 GB since MB only uses 1 fraction digit
        fileprivate static let maxDecimalSizes = [999, 999499, 999949999, 999994999999, 999994999999999, Int64.max]
        fileprivate static let maxBinarySizes = [1023, 1048063, 1073689395, 1099506259066, 1125894409284485, Int64.max]

        func useSpelloutZero(forLocale locale: Locale, unit: Unit) -> Bool {
            guard unit == .byte || unit == .kilobyte else { return false }

            guard let languageCode = locale.language.languageCode?._normalizedIdentifier else { return false }

            switch languageCode {
            case "ar", "da", "el", "en", "fr",  "hi", "hr", "id", "it", "ms", "pt", "ro", "th":
                return true
            default:
                break
            }

            guard unit == .byte else { return false }

            // These only uses spellout zero with byte but not with kilobyte
            switch languageCode {
            case "ca", "no":
                return true
            default:
                break
            }

            return false
        }
        
        func _format(_ formatterValue: ICUNumberFormatter.Value, doubleValue: Double) -> AttributedString {
            let unit: Unit = allowedUnits.contains(.kb) ? .kilobyte : .byte
            if spellsOutZero && doubleValue.isZero {
                let numberFormatter = ICUByteCountNumberFormatter.create(for: "measure-unit/digital-\(unit.name)\(unit == .byte ? " unit-width-full-name" : "")", locale: locale)
                guard var attributedFormat = numberFormatter?.attributedFormat(.integer(.zero), unit: unit) else {
                    // fallback to English if ICU formatting fails
                    return unit == .byte ? "Zero bytes" : "Zero kB"
                }

                guard useSpelloutZero(forLocale: locale, unit: unit) else {
                    return attributedFormat
                }

                let configuration = DescriptiveNumberFormatConfiguration.Collection(presentation: .cardinal, capitalizationContext: .beginningOfSentence)
                guard let spellOutFormatter = ICULegacyNumberFormatter.formatter(for: .descriptive(configuration), locale: locale) else {
                    return attributedFormat
                }

                guard let zeroFormatted = spellOutFormatter.format(Int64.zero) else {
                    return attributedFormat
                }

                var attributedZero = AttributedString(zeroFormatted)
                attributedZero.byteCount = .spelledOutValue
                for (value, range) in attributedFormat.runs[\.byteCount] where value == .value {
                    attributedFormat.replaceSubrange(range, with: attributedZero)
                }

                return attributedFormat
            }

            let decimal: Bool
            let maxSizes: [Int64]
            switch style {
            case .file, .decimal:
                decimal = true
                maxSizes = Self.maxDecimalSizes
            case .memory, .binary:
                decimal = false
                maxSizes = Self.maxBinarySizes
            }

            let absValue = abs(doubleValue)
            let bestUnit: Unit = {
                var bestUnit = allowedUnits.smallestUnit
                for (idx, size) in maxSizes.enumerated() {
                    guard allowedUnits.contains(.init(rawValue: 1 << idx)) else {
                        continue
                    }
                    bestUnit = Unit(rawValue: idx)!
                    if absValue < Double(size) {
                        break
                    }
                }

                return bestUnit
            }()

            let denominator = decimal ? bestUnit.decimalSize : bestUnit.binarySize
            let unitValue = doubleValue/Double(denominator)

            let precisionSkeleton: String
            switch bestUnit {
            case .byte, .kilobyte:
                precisionSkeleton = "." // 0 fraction digits
            case .megabyte:
                precisionSkeleton = ".#" // Up to one fraction digit
            default:
                precisionSkeleton = ".##" // Up to two fraction digits
            }

            let formatter = ICUByteCountNumberFormatter.create(for: "\(precisionSkeleton) measure-unit/digital-\(bestUnit.name) \(bestUnit == .byte ? "unit-width-full-name" : "")", locale: locale)

            var attributedString = formatter!.attributedFormat(.floatingPoint(unitValue), unit: bestUnit)

            if includesActualByteCount {
                let byteFormatter = ICUByteCountNumberFormatter.create(for: "measure-unit/digital-byte unit-width-full-name", locale: locale)

                let localizedParens = localizedParens(locale: locale)
                attributedString.append(AttributedString(localizedParens.0))

                var attributedBytes = byteFormatter!.attributedFormat(formatterValue, unit: .byte)
                for (value, range) in attributedBytes.runs[\.byteCount] where value == .value {
                    attributedBytes[range].byteCount = .actualByteCount
                }
                attributedString.append(attributedBytes)

                attributedString.append(AttributedString(localizedParens.1))
            }

            return attributedString
        }
        
        /// Formats a numeric byte count, using this style.
        ///
        /// - Parameter value: The 64-bit byte count to format.
        /// - Returns: A formatted attributed string representation of the byte count.
        public func format(_ value: Int64) -> AttributedString {
            _format(.integer(value), doubleValue: Double(value))
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == ByteCountFormatStyle {
    /// Returns a format style to format a data storage value.
    ///
    /// Use this type method when the call point allows the use of ``ByteCountFormatStyle``.
    /// You typically do this when calling the `formatted` method of `BinaryInteger` values
    /// that represent byte counts, as seen here:
    ///
    /// ```swift
    /// let count: Int64 = 1024
    /// let formatted = count.formatted(.byteCount(style: .memory)) // "1 kB"
    /// ```
    ///
    /// - Parameters:
    ///   - style: The style of byte count to express, such as memory or file system storage.
    ///   - allowedUnits: The units the format style can use to express the byte count.
    ///   - spellsOutZero: A Boolean value that indicates whether the format style should
    ///     spell out zero-byte values as text, like `Zero kB`.
    ///   - includesActualByteCount: A Boolean value that indicates whether the format style
    ///     should include the exact byte count, in addition to expressing it in terms of
    ///     units. For example, `1 kB (1,024 bytes)`.
    /// - Returns: A format style for formatting a measurement of data storage, customized
    ///   with the provided behaviors.
    static func byteCount(style: ByteCountFormatStyle.Style, allowedUnits: ByteCountFormatStyle.Units = .all, spellsOutZero: Bool = true, includesActualByteCount: Bool = false) -> Self {
        return ByteCountFormatStyle(style: style, allowedUnits: allowedUnits, spellsOutZero: spellsOutZero, includesActualByteCount: includesActualByteCount)
    }

}

private func localizedParens(locale: Locale) -> (String, String) {
    var status = U_ZERO_ERROR

    let ulocdata = locale.identifier.withCString {
        ulocdata_open($0, &status)
    }
    defer { ulocdata_close(ulocdata) }

    guard status.checkSuccessAndLogError("ulocdata_open failed.") else {
        return (" (", ")")
    }

    let exemplars = ulocdata_getExemplarSet(ulocdata, nil, 0, .punctuation, &status)
    defer { uset_close(exemplars) }

    guard status.checkSuccessAndLogError("ulocdata_getExemplarSet failed.") else {
        return (" (", ")")
    }
    
    let fullwidthLeftParenUTF32 = 0x0000FF08 as Int32
    let containsFullWidth = uset_contains(exemplars!, fullwidthLeftParenUTF32).boolValue

    if containsFullWidth {
        return ("（", "）")
    } else {
        return (" (", ")")
    }
}

extension AttributeScopes.FoundationAttributes.ByteCountAttribute.Component {
    internal init?(unumberFormatField: UNumberFormatFields, unit: ByteCountFormatStyle.Unit) {
        switch unumberFormatField {
        case .integer:
            self = .value
        case .fraction:
            self = .value
        case .decimalSeparator:
            self = .value
        case .groupingSeparator:
            self = .value
        case .sign:
            self = .value
        case .currencySymbol:
            return nil
        case .percentSymbol:
            return nil
        case .measureUnit:
            self = .unit(.init(unit))
        default:
            return nil
        }
    }
}

extension AttributeScopes.FoundationAttributes.ByteCountAttribute.Unit {
    internal init(_ unit: ByteCountFormatStyle.Unit) {
        switch unit {
        case .byte:
            self = .byte
        case .kilobyte:
            self = .kb
        case .megabyte:
            self = .mb
        case .gigabyte:
            self = .gb
        case .terabyte:
            self = .tb
        case .petabyte:
            self = .pb
        case .exabyte:
            self = .eb
        case .zettabyte:
            self = .zb
        case .yottabyte:
            self = .yb
        }
    }
}
