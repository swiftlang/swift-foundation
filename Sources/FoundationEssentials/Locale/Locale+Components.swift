//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Glibc)
import Glibc
#endif

extension Locale {

    /// Represents locale-related attributes. You can use `Locale.Components` to create a `Locale` with specific overrides.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Components : Hashable, Codable, Sendable {

        /// Represents the language identifier a locale
        public var languageComponents: Language.Components

        /// Set this to override the default calendar. To request the default calendar used by the locale, use `Locale.calendar`
        ///
        /// Corresponds to the "ca" key of the Unicode BCP 47 extension
        public var calendar: Calendar.Identifier?

        /// Set this to override the string sort order. To request the default calendar used by the locale, use `Locale.calendar`
        ///
        /// Corresponds to the "co" key of the Unicode BCP 47 extension
        public var collation: Locale.Collation?

        /// Set this to override the currency. To request the default currency used by the locale, use `Locale.currency`
        ///
        /// Corresponds to the "cu" key of the Unicode BCP 47 extension
        public var currency: Locale.Currency?

        /// Set this to override the numbering system. To request the default numbering system used by the locale, use `Locale.numberingSystem`
        ///
        /// Corresponds to the "nu" key of the Unicode BCP 47 extension
        public var numberingSystem: Locale.NumberingSystem?

        /// Set this to override the first day of the week. To request the default first day of the week preferred by the locale, use `Locale.firstDayOfWeek`
        ///
        /// Corresponds to the "fw" key of the Unicode BCP 47 extension
        /// The preferred first day of the week that should be shown in a calendar view. Not necessarily the same as the first day after the weekend, and should not be determined from the weekend information
        public var firstDayOfWeek: Locale.Weekday?

        /// Set this to override the hour cycle. To request the default hour cycle, use `Locale.hourCycle`
        ///
        /// Corresponds to the "hc" key
        public var hourCycle: Locale.HourCycle?

        /// Set this to override the measurement system. To request the default measurement system, use `Locale.measurementSystem`
        ///
        /// Corresponds to the "ms" key of the Unicode BCP 47 extension
        public var measurementSystem: Locale.MeasurementSystem?

        /// Set this to override the region for region-related preferences, such as measuring system, calendar, and first day of the week. If unset, the region of the language component is used
        ///
        /// Corresponds to the "rg" key of the Unicode BCP 47 extension
        public var region: Locale.Region?

        /// Set this to override the regional subdivision of `region`
        ///
        /// Corresponds to the "sd" key of the Unicode BCP 47 extension
        public var subdivision: Locale.Subdivision?

        /// Set this to specify a time zone to associate with this locale
        ///
        /// Corresponds to the "tz" key of the Unicode BCP 47 extension
        public var timeZone: TimeZone?

        /// Set this to specify a variant used for the locale
        ///
        /// Corresponds to the "va" key of the Unicode BCP 47 extension
        public var variant: Variant?

        // MARK: - Initializers

        /// Creates a `Locale.Components` with the specified language code, script and region for the language
        public init(languageCode: Locale.LanguageCode? = nil, script: Locale.Script? = nil, languageRegion: Locale.Region? = nil) {
            self.languageComponents = Language.Components(languageCode: languageCode, script: script, region: languageRegion)
        }
    }
}

@available(FoundationPreview 0.1, *)
extension Locale.LanguageCode : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Script : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Region : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Currency : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Collation : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.NumberingSystem : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Subdivision : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.Variant : CustomDebugStringConvertible { }

@available(FoundationPreview 0.1, *)
extension Locale.MeasurementSystem : CustomDebugStringConvertible { }

extension Locale {

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct LanguageCode : Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public init(stringLiteral value: String) {
            self.init(value)
        }

        /// Creates a `LanguageCode` type
        /// - Parameter identifier: A two-letter or three-letter ISO 639 code, or a language code of your choice if using a custom language, such as "en" for English. Case-insensitive.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// A two-letter or three-letter code supported by ISO 639, or a language code of your choice if using a custom language.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        /// Types of ISO 639 language code.
        public enum IdentifierType : Sendable {
            /// Two-letter alpha-2 code, e.g. "en" for English
            case alpha2

            /// Three-letter alpha-3 code, e.g. "eng" for English
            case alpha3
        }

        /// The `und` code: used in cases where the language has not been identified
        public static let unidentified: LanguageCode = LanguageCode("und")

        /// The `mis` code: represents languages that have not been included in the ISO standard yet
        public static let uncoded: LanguageCode = LanguageCode("mis")

        /// The `mul` code: represents the language of some content when there are more than one languages
        public static let multiple: LanguageCode = LanguageCode("mul")

        /// The `zxx` code: used in cases when the content is not in any particular languages, such as images, symbols, etc.
        public static let unavailable: LanguageCode = LanguageCode("zxx")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: LanguageCode, rhs: LanguageCode) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Script : Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        public init(stringLiteral value: String) {
            self.init(value)
        }

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.capitalized
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a `Script` with specified identifier
        /// - Parameter identifier: A BCP 47 script subtag such as "Arab", "Cyrl" or "Latn". Case-insensitive.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.capitalized
        }
        package var _identifier: String
        package var _normalizedIdentifier: String

        /// Represents an uncoded script
        public static let unknown = Script("Zzzz")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func ==(lhs: Script, rhs: Script) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.capitalized
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Region : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("rg")
        package static let legacyKeywordKey = ICULegacyKey("rg")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.uppercased()
                _identifier = newValue
            }
        }

        /// Creates a `Region` with the specified region code
        /// - Parameter identifier: A two-letter BCP 47 region subtag such as "US" for the United States. Case-insensitive.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.uppercased()
        }

        /// Represents an unknown or invalid region
        public static let unknown = Region("ZZ")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: Region, rhs: Region) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.uppercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Collation : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("co")
        package static let legacyKeywordKey = ICULegacyKey("collation")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// The complete list of collation identifiers can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/collation.xml), under the key named "co"
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// Dedicated for string search. This is only appropriate for determining whether two strings should be considered equivalent. Using this may ignore or modify the string for searching purpose. For example, the contractions in Thai and Lao are suppressed. It should not be used to determine the relative order of the two strings.
        public static let searchRules = Collation("search")
        /// The default ordering for each language
        public static let standard = Collation("standard")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: Collation, rhs: Collation) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    /// The complete list of currency codes can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/currency.xml), under the key with the name "cu"
    public struct Currency : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("cu")
        package static let legacyKeywordKey = ICULegacyKey("currency")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: Currency, rhs: Currency) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    /// Defines representations for numeric values. Also known as numeral system
    public struct NumberingSystem : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("nu")
        package static let legacyKeywordKey = ICULegacyKey("numbers")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// The complete list of valid numbering systems can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml), under the key with the name "nu"
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        package static let latn = NumberingSystem("latn")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: NumberingSystem, rhs: NumberingSystem) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum Weekday: String, Codable, Hashable, Sendable {
        case sunday = "sun"
        case monday = "mon"
        case tuesday = "tue"
        case wednesday = "wed"
        case thursday = "thu"
        case friday = "fri"
        case saturday = "sat"

        package static let cldrKeywordKey = ICUCLDRKey("fw")
        package static let legacyKeywordKey = ICULegacyKey("fw")

        // Conforming to ICU index: 1 is Sunday
        package static let weekdays : [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        package init?(_ icuIndex: Int32) {
            guard icuIndex >= 1, icuIndex <= 7 else {
                return nil
            }

            self = Self.weekdays[Int(icuIndex) - 1]
        }

        package var icuIndex: Int {
            Self.weekdays.firstIndex(of: self)! + 1
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum HourCycle : String, Codable, Hashable, Sendable {
        /// 12-hour clock. Hour ranges from 0 to 11
        case zeroToEleven = "h11"

        /// 12-hour clock. Hour ranges from 1 to 12
        case oneToTwelve = "h12"

        /// 24-hour clock. Hour ranges from 0 to 23
        case zeroToTwentyThree = "h23"

        /// 24-hour clock. Hour ranges from 1 to 24
        case oneToTwentyFour = "h24"

        package static let cldrKeywordKey = ICUCLDRKey("hc")
        package static let legacyKeywordKey = ICULegacyKey("hours")
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct MeasurementSystem: Codable, Hashable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("ms")
        package static let legacyKeywordKey = ICULegacyKey("measure")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// The complete list of valid measurement systems can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/measure.xml), under the key with the name "ms"
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// Metric system
        public static let metric = MeasurementSystem("metric")
        /// US System of measurement: feet, pints, etc.; pints are 16oz
        public static let us = MeasurementSystem("ussystem")
        /// UK System of measurement: feet, pints, etc.; pints are 20oz
        public static let uk = MeasurementSystem("uksystem")

        /// Returns a list of measurement systems
        public static var measurementSystems: [MeasurementSystem] {
            [ metric, us, uk ]
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: MeasurementSystem, rhs: MeasurementSystem) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    /// A subdivision of a country or region, such as a state in the United States, or a province in Canada.
    public struct Subdivision : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("sd")
        package static let legacyKeywordKey = ICULegacyKey("sd")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a subdivision with the given identifier
        /// - Parameter identifier: A unicode subdivision identifier, such as "usca" for California, US. Case-insensitive. The complete list of subdivision identifier can be found [here](https://github.com/unicode-org/cldr/blob/maint/maint-40/common/validity/subdivision.xml), under the "subdivision" type
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// Returns the subdivision representing the given region as a whole. For example, returns a subdivision with the "uszzzz" identifier for the entire US region
        public static func subdivision(for region: Region) -> Subdivision {
            return .init(region.identifier + "zzzz")
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: Subdivision, rhs: Subdivision) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Variant: Codable, Hashable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("va")
        package static let legacyKeywordKey = ICULegacyKey("va")

        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(FoundationPreview 0.1, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// The complete list of valid variants can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/variant.xml), under the key named "va"
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        public static let posix: Variant = .init("posix")

        public func hash(into hasher: inout Hasher) {
            hasher.combine(_normalizedIdentifier)
        }

        public static func == (lhs: Variant, rhs: Variant) -> Bool {
            return lhs._normalizedIdentifier == rhs._normalizedIdentifier
        }

        // Codable conformance
        enum CodingKeys: CodingKey {
            case _normalizedIdentifier
            case _identifier
        }

        public init(from decoder: Decoder) throws {
            do {
                _identifier = try decoder.singleValueContainer().decode(String.self)
                _normalizedIdentifier = _identifier.lowercased()
            } catch {
                // backward compatibility: we used to encode both _identifier and _normalizedIdentifier. Fall back to this if there's not a matched single value container
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _normalizedIdentifier = try container.decode(String.self, forKey: ._normalizedIdentifier)
                _identifier = try container.decode(String.self, forKey: ._identifier)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(_identifier)
        }
    }
}

// MARK: - Key Wrappers

/// Use to represent an ICU legacy key.
/// Some ICU API only accepts these, so we have a type-safe wrapper to catch a potential bug.
package struct ICULegacyKey : Hashable {
    package let key: String
    package init(_ key: String) { self.key = key }
}

/// Use to represent a modern ICU key.
package struct ICUCLDRKey : Hashable {
    package let key: String
    package init(_ key: String) { self.key = key }
}

// MARK: - Constants

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.LanguageCode {
    @_alwaysEmitIntoClient
    public static var ainu: Locale.LanguageCode { Locale.LanguageCode("ain") }

    @_alwaysEmitIntoClient
    public static var albanian: Locale.LanguageCode { Locale.LanguageCode("sq") }

    @_alwaysEmitIntoClient
    public static var amharic: Locale.LanguageCode { Locale.LanguageCode("am") }

    @_alwaysEmitIntoClient
    public static var apacheWestern: Locale.LanguageCode { Locale.LanguageCode("apw") }

    @_alwaysEmitIntoClient
    public static var arabic: Locale.LanguageCode { Locale.LanguageCode("ar") }

    @_alwaysEmitIntoClient
    public static var armenian: Locale.LanguageCode { Locale.LanguageCode("hy") }

    @_alwaysEmitIntoClient
    public static var assamese: Locale.LanguageCode { Locale.LanguageCode("as") }

    @_alwaysEmitIntoClient
    public static var assyrian: Locale.LanguageCode { Locale.LanguageCode("syr") }

    @_alwaysEmitIntoClient
    public static var azerbaijani: Locale.LanguageCode { Locale.LanguageCode("az") }

    @_alwaysEmitIntoClient
    public static var bangla: Locale.LanguageCode { Locale.LanguageCode("bn") }

    @_alwaysEmitIntoClient
    public static var belarusian: Locale.LanguageCode { Locale.LanguageCode("be") }

    @_alwaysEmitIntoClient
    public static var bodo: Locale.LanguageCode { Locale.LanguageCode("brx") }

    @_alwaysEmitIntoClient
    public static var bulgarian: Locale.LanguageCode { Locale.LanguageCode("bg") }

    @_alwaysEmitIntoClient
    public static var burmese: Locale.LanguageCode { Locale.LanguageCode("my") }

    @_alwaysEmitIntoClient
    public static var cantonese: Locale.LanguageCode { Locale.LanguageCode("yue") }

    @_alwaysEmitIntoClient
    public static var catalan: Locale.LanguageCode { Locale.LanguageCode("ca") }

    @_alwaysEmitIntoClient
    public static var cherokee: Locale.LanguageCode { Locale.LanguageCode("chr") }

    @_alwaysEmitIntoClient
    public static var chinese: Locale.LanguageCode { Locale.LanguageCode("zh") }

    @_alwaysEmitIntoClient
    public static var croatian: Locale.LanguageCode { Locale.LanguageCode("hr") }

    @_alwaysEmitIntoClient
    public static var czech: Locale.LanguageCode { Locale.LanguageCode("cs") }

    @_alwaysEmitIntoClient
    public static var danish: Locale.LanguageCode { Locale.LanguageCode("da") }

    @_alwaysEmitIntoClient
    public static var dhivehi: Locale.LanguageCode { Locale.LanguageCode("dv") }

    @_alwaysEmitIntoClient
    public static var dogri: Locale.LanguageCode { Locale.LanguageCode("doi") }

    @_alwaysEmitIntoClient
    public static var dutch: Locale.LanguageCode { Locale.LanguageCode("nl") }

    @_alwaysEmitIntoClient
    public static var dzongkha: Locale.LanguageCode { Locale.LanguageCode("dz") }

    @_alwaysEmitIntoClient
    public static var english: Locale.LanguageCode { Locale.LanguageCode("en") }

    @_alwaysEmitIntoClient
    public static var estonian: Locale.LanguageCode { Locale.LanguageCode("et") }

    @_alwaysEmitIntoClient
    public static var faroese: Locale.LanguageCode { Locale.LanguageCode("fo") }

    @_alwaysEmitIntoClient
    public static var finnish: Locale.LanguageCode { Locale.LanguageCode("fi") }

    @_alwaysEmitIntoClient
    public static var french: Locale.LanguageCode { Locale.LanguageCode("fr") }

    @_alwaysEmitIntoClient
    public static var fula: Locale.LanguageCode { Locale.LanguageCode("ff") }

    @_alwaysEmitIntoClient
    public static var georgian: Locale.LanguageCode { Locale.LanguageCode("ka") }

    @_alwaysEmitIntoClient
    public static var german: Locale.LanguageCode { Locale.LanguageCode("de") }

    @_alwaysEmitIntoClient
    public static var greek: Locale.LanguageCode { Locale.LanguageCode("el") }

    @_alwaysEmitIntoClient
    public static var gujarati: Locale.LanguageCode { Locale.LanguageCode("gu") }

    @_alwaysEmitIntoClient
    public static var hawaiian: Locale.LanguageCode { Locale.LanguageCode("haw") }

    @_alwaysEmitIntoClient
    public static var hebrew: Locale.LanguageCode { Locale.LanguageCode("he") }

    @_alwaysEmitIntoClient
    public static var hindi: Locale.LanguageCode { Locale.LanguageCode("hi") }

    @_alwaysEmitIntoClient
    public static var hungarian: Locale.LanguageCode { Locale.LanguageCode("hu") }

    @_alwaysEmitIntoClient
    public static var icelandic: Locale.LanguageCode { Locale.LanguageCode("is") }

    @_alwaysEmitIntoClient
    public static var igbo: Locale.LanguageCode { Locale.LanguageCode("ig") }

    @_alwaysEmitIntoClient
    public static var indonesian: Locale.LanguageCode { Locale.LanguageCode("id") }

    @_alwaysEmitIntoClient
    public static var irish: Locale.LanguageCode { Locale.LanguageCode("ga") }

    @_alwaysEmitIntoClient
    public static var italian: Locale.LanguageCode { Locale.LanguageCode("it") }

    @_alwaysEmitIntoClient
    public static var japanese: Locale.LanguageCode { Locale.LanguageCode("ja") }

    @_alwaysEmitIntoClient
    public static var kannada: Locale.LanguageCode { Locale.LanguageCode("kn") }

    @_alwaysEmitIntoClient
    public static var kashmiri: Locale.LanguageCode { Locale.LanguageCode("ks") }

    @_alwaysEmitIntoClient
    public static var kazakh: Locale.LanguageCode { Locale.LanguageCode("kk") }

    @_alwaysEmitIntoClient
    public static var khmer: Locale.LanguageCode { Locale.LanguageCode("km") }

    @_alwaysEmitIntoClient
    public static var konkani: Locale.LanguageCode { Locale.LanguageCode("kok") }

    @_alwaysEmitIntoClient
    public static var korean: Locale.LanguageCode { Locale.LanguageCode("ko") }

    @_alwaysEmitIntoClient
    public static var kurdish: Locale.LanguageCode { Locale.LanguageCode("ku") }

    @_alwaysEmitIntoClient
    public static var kurdishSorani: Locale.LanguageCode { Locale.LanguageCode("ckb") }

    @_alwaysEmitIntoClient
    public static var kyrgyz: Locale.LanguageCode { Locale.LanguageCode("ky") }

    @_alwaysEmitIntoClient
    public static var lao: Locale.LanguageCode { Locale.LanguageCode("lo") }

    @_alwaysEmitIntoClient
    public static var latvian: Locale.LanguageCode { Locale.LanguageCode("lv") }

    @_alwaysEmitIntoClient
    public static var lithuanian: Locale.LanguageCode { Locale.LanguageCode("lt") }

    @_alwaysEmitIntoClient
    public static var macedonian: Locale.LanguageCode { Locale.LanguageCode("mk") }

    @_alwaysEmitIntoClient
    public static var maithili: Locale.LanguageCode { Locale.LanguageCode("mai") }

    @_alwaysEmitIntoClient
    public static var malay: Locale.LanguageCode { Locale.LanguageCode("ms") }

    @_alwaysEmitIntoClient
    public static var malayalam: Locale.LanguageCode { Locale.LanguageCode("ml") }

    @_alwaysEmitIntoClient
    public static var maltese: Locale.LanguageCode { Locale.LanguageCode("mt") }

    @_alwaysEmitIntoClient
    public static var manipuri: Locale.LanguageCode { Locale.LanguageCode("mni") }

    @_alwaysEmitIntoClient
    public static var māori: Locale.LanguageCode { Locale.LanguageCode("mi") }

    @_alwaysEmitIntoClient
    public static var marathi: Locale.LanguageCode { Locale.LanguageCode("mr") }

    @_alwaysEmitIntoClient
    public static var mongolian: Locale.LanguageCode { Locale.LanguageCode("mn") }

    @_alwaysEmitIntoClient
    public static var navajo: Locale.LanguageCode { Locale.LanguageCode("nv") }

    @_alwaysEmitIntoClient
    public static var nepali: Locale.LanguageCode { Locale.LanguageCode("ne") }

    @_alwaysEmitIntoClient
    public static var norwegian: Locale.LanguageCode { Locale.LanguageCode("no") }

    @_alwaysEmitIntoClient
    public static var norwegianBokmål: Locale.LanguageCode { Locale.LanguageCode("nb") }

    @_alwaysEmitIntoClient
    public static var norwegianNynorsk: Locale.LanguageCode { Locale.LanguageCode("nn") }

    @_alwaysEmitIntoClient
    public static var odia: Locale.LanguageCode { Locale.LanguageCode("or") }

    @_alwaysEmitIntoClient
    public static var pashto: Locale.LanguageCode { Locale.LanguageCode("ps") }

    @_alwaysEmitIntoClient
    public static var persian: Locale.LanguageCode { Locale.LanguageCode("fa") }

    @_alwaysEmitIntoClient
    public static var polish: Locale.LanguageCode { Locale.LanguageCode("pl") }

    @_alwaysEmitIntoClient
    public static var portuguese: Locale.LanguageCode { Locale.LanguageCode("pt") }

    @_alwaysEmitIntoClient
    public static var punjabi: Locale.LanguageCode { Locale.LanguageCode("pa") }

    @_alwaysEmitIntoClient
    public static var rohingya: Locale.LanguageCode { Locale.LanguageCode("rhg") }

    @_alwaysEmitIntoClient
    public static var romanian: Locale.LanguageCode { Locale.LanguageCode("ro") }

    @_alwaysEmitIntoClient
    public static var russian: Locale.LanguageCode { Locale.LanguageCode("ru") }

    @_alwaysEmitIntoClient
    public static var samoan: Locale.LanguageCode { Locale.LanguageCode("sm") }

    @_alwaysEmitIntoClient
    public static var sanskrit: Locale.LanguageCode { Locale.LanguageCode("sa") }

    @_alwaysEmitIntoClient
    public static var santali: Locale.LanguageCode { Locale.LanguageCode("sat") }

    @_alwaysEmitIntoClient
    public static var serbian: Locale.LanguageCode { Locale.LanguageCode("sr") }

    @_alwaysEmitIntoClient
    public static var sindhi: Locale.LanguageCode { Locale.LanguageCode("sd") }

    @_alwaysEmitIntoClient
    public static var sinhala: Locale.LanguageCode { Locale.LanguageCode("si") }

    @_alwaysEmitIntoClient
    public static var slovak: Locale.LanguageCode { Locale.LanguageCode("sk") }

    @_alwaysEmitIntoClient
    public static var slovenian: Locale.LanguageCode { Locale.LanguageCode("sl") }

    @_alwaysEmitIntoClient
    public static var spanish: Locale.LanguageCode { Locale.LanguageCode("es") }

    @_alwaysEmitIntoClient
    public static var swahili: Locale.LanguageCode { Locale.LanguageCode("sw") }

    @_alwaysEmitIntoClient
    public static var swedish: Locale.LanguageCode { Locale.LanguageCode("sv") }

    @_alwaysEmitIntoClient
    public static var tagalog: Locale.LanguageCode { Locale.LanguageCode("tl") }

    @_alwaysEmitIntoClient
    public static var tajik: Locale.LanguageCode { Locale.LanguageCode("tg") }

    @_alwaysEmitIntoClient
    public static var tamil: Locale.LanguageCode { Locale.LanguageCode("ta") }

    @_alwaysEmitIntoClient
    public static var telugu: Locale.LanguageCode { Locale.LanguageCode("te") }

    @_alwaysEmitIntoClient
    public static var thai: Locale.LanguageCode { Locale.LanguageCode("th") }

    @_alwaysEmitIntoClient
    public static var tibetan: Locale.LanguageCode { Locale.LanguageCode("bo") }

    @_alwaysEmitIntoClient
    public static var tongan: Locale.LanguageCode { Locale.LanguageCode("to") }

    @_alwaysEmitIntoClient
    public static var turkish: Locale.LanguageCode { Locale.LanguageCode("tr") }

    @_alwaysEmitIntoClient
    public static var turkmen: Locale.LanguageCode { Locale.LanguageCode("tk") }

    @_alwaysEmitIntoClient
    public static var ukrainian: Locale.LanguageCode { Locale.LanguageCode("uk") }

    @_alwaysEmitIntoClient
    public static var urdu: Locale.LanguageCode { Locale.LanguageCode("ur") }

    @_alwaysEmitIntoClient
    public static var uyghur: Locale.LanguageCode { Locale.LanguageCode("ug") }

    @_alwaysEmitIntoClient
    public static var uzbek: Locale.LanguageCode { Locale.LanguageCode("uz") }

    @_alwaysEmitIntoClient
    public static var vietnamese: Locale.LanguageCode { Locale.LanguageCode("vi") }

    @_alwaysEmitIntoClient
    public static var welsh: Locale.LanguageCode { Locale.LanguageCode("cy") }

    @_alwaysEmitIntoClient
    public static var yiddish: Locale.LanguageCode { Locale.LanguageCode("yi") }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Region {
    @_alwaysEmitIntoClient
    public static var afghanistan: Locale.Region { Locale.Region("AF") }

    @_alwaysEmitIntoClient
    public static var ålandIslands: Locale.Region { Locale.Region("AX") }

    @_alwaysEmitIntoClient
    public static var albania: Locale.Region { Locale.Region("AL") }

    @_alwaysEmitIntoClient
    public static var algeria: Locale.Region { Locale.Region("DZ") }

    @_alwaysEmitIntoClient
    public static var americanSamoa: Locale.Region { Locale.Region("AS") }

    @_alwaysEmitIntoClient
    public static var andorra: Locale.Region { Locale.Region("AD") }

    @_alwaysEmitIntoClient
    public static var angola: Locale.Region { Locale.Region("AO") }

    @_alwaysEmitIntoClient
    public static var anguilla: Locale.Region { Locale.Region("AI") }

    @_alwaysEmitIntoClient
    public static var antarctica: Locale.Region { Locale.Region("AQ") }

    @_alwaysEmitIntoClient
    public static var antiguaBarbuda: Locale.Region { Locale.Region("AG") }

    @_alwaysEmitIntoClient
    public static var argentina: Locale.Region { Locale.Region("AR") }

    @_alwaysEmitIntoClient
    public static var armenia: Locale.Region { Locale.Region("AM") }

    @_alwaysEmitIntoClient
    public static var aruba: Locale.Region { Locale.Region("AW") }

    @_alwaysEmitIntoClient
    public static var ascensionIsland: Locale.Region { Locale.Region("AC") }

    @_alwaysEmitIntoClient
    public static var australia: Locale.Region { Locale.Region("AU") }

    @_alwaysEmitIntoClient
    public static var austria: Locale.Region { Locale.Region("AT") }

    @_alwaysEmitIntoClient
    public static var azerbaijan: Locale.Region { Locale.Region("AZ") }

    @_alwaysEmitIntoClient
    public static var bahamas: Locale.Region { Locale.Region("BS") }

    @_alwaysEmitIntoClient
    public static var bahrain: Locale.Region { Locale.Region("BH") }

    @_alwaysEmitIntoClient
    public static var bangladesh: Locale.Region { Locale.Region("BD") }

    @_alwaysEmitIntoClient
    public static var barbados: Locale.Region { Locale.Region("BB") }

    @_alwaysEmitIntoClient
    public static var belarus: Locale.Region { Locale.Region("BY") }

    @_alwaysEmitIntoClient
    public static var belgium: Locale.Region { Locale.Region("BE") }

    @_alwaysEmitIntoClient
    public static var belize: Locale.Region { Locale.Region("BZ") }

    @_alwaysEmitIntoClient
    public static var benin: Locale.Region { Locale.Region("BJ") }

    @_alwaysEmitIntoClient
    public static var bermuda: Locale.Region { Locale.Region("BM") }

    @_alwaysEmitIntoClient
    public static var bhutan: Locale.Region { Locale.Region("BT") }

    @_alwaysEmitIntoClient
    public static var bolivia: Locale.Region { Locale.Region("BO") }

    @_alwaysEmitIntoClient
    public static var bosniaHerzegovina: Locale.Region { Locale.Region("BA") }

    @_alwaysEmitIntoClient
    public static var botswana: Locale.Region { Locale.Region("BW") }

    @_alwaysEmitIntoClient
    public static var bouvetIsland: Locale.Region { Locale.Region("BV") }

    @_alwaysEmitIntoClient
    public static var brazil: Locale.Region { Locale.Region("BR") }

    @_alwaysEmitIntoClient
    public static var britishVirginIslands: Locale.Region { Locale.Region("VG") }

    @_alwaysEmitIntoClient
    public static var brunei: Locale.Region { Locale.Region("BN") }

    @_alwaysEmitIntoClient
    public static var bulgaria: Locale.Region { Locale.Region("BG") }

    @_alwaysEmitIntoClient
    public static var burkinaFaso: Locale.Region { Locale.Region("BF") }

    @_alwaysEmitIntoClient
    public static var burundi: Locale.Region { Locale.Region("BI") }

    @_alwaysEmitIntoClient
    public static var cambodia: Locale.Region { Locale.Region("KH") }

    @_alwaysEmitIntoClient
    public static var cameroon: Locale.Region { Locale.Region("CM") }

    @_alwaysEmitIntoClient
    public static var canada: Locale.Region { Locale.Region("CA") }

    @_alwaysEmitIntoClient
    public static var canaryIslands: Locale.Region { Locale.Region("IC") }

    @_alwaysEmitIntoClient
    public static var capeVerde: Locale.Region { Locale.Region("CV") }

    @_alwaysEmitIntoClient
    public static var caribbeanNetherlands: Locale.Region { Locale.Region("BQ") }

    @_alwaysEmitIntoClient
    public static var caymanIslands: Locale.Region { Locale.Region("KY") }

    @_alwaysEmitIntoClient
    public static var centralAfricanRepublic: Locale.Region { Locale.Region("CF") }

    @_alwaysEmitIntoClient
    public static var ceutaMelilla: Locale.Region { Locale.Region("EA") }

    @_alwaysEmitIntoClient
    public static var chad: Locale.Region { Locale.Region("TD") }

    @_alwaysEmitIntoClient
    public static var chagosArchipelago: Locale.Region { Locale.Region("IO") }

    @_alwaysEmitIntoClient
    public static var chile: Locale.Region { Locale.Region("CL") }

    @_alwaysEmitIntoClient
    public static var chinaMainland: Locale.Region { Locale.Region("CN") }

    @_alwaysEmitIntoClient
    public static var christmasIsland: Locale.Region { Locale.Region("CX") }

    @_alwaysEmitIntoClient
    public static var clippertonIsland: Locale.Region { Locale.Region("CP") }

    @_alwaysEmitIntoClient
    public static var cocosIslands: Locale.Region { Locale.Region("CC") }

    @_alwaysEmitIntoClient
    public static var colombia: Locale.Region { Locale.Region("CO") }

    @_alwaysEmitIntoClient
    public static var comoros: Locale.Region { Locale.Region("KM") }

    @_alwaysEmitIntoClient
    public static var congoBrazzaville: Locale.Region { Locale.Region("CG") }

    @_alwaysEmitIntoClient
    public static var congoKinshasa: Locale.Region { Locale.Region("CD") }

    @_alwaysEmitIntoClient
    public static var cookIslands: Locale.Region { Locale.Region("CK") }

    @_alwaysEmitIntoClient
    public static var costaRica: Locale.Region { Locale.Region("CR") }

    @_alwaysEmitIntoClient
    public static var côteDIvoire: Locale.Region { Locale.Region("CI") }

    @_alwaysEmitIntoClient
    public static var croatia: Locale.Region { Locale.Region("HR") }

    @_alwaysEmitIntoClient
    public static var cuba: Locale.Region { Locale.Region("CU") }

    @_alwaysEmitIntoClient
    public static var curaçao: Locale.Region { Locale.Region("CW") }

    @_alwaysEmitIntoClient
    public static var cyprus: Locale.Region { Locale.Region("CY") }

    @_alwaysEmitIntoClient
    public static var czechia: Locale.Region { Locale.Region("CZ") }

    @_alwaysEmitIntoClient
    public static var denmark: Locale.Region { Locale.Region("DK") }

    @_alwaysEmitIntoClient
    public static var diegoGarcia: Locale.Region { Locale.Region("DG") }

    @_alwaysEmitIntoClient
    public static var djibouti: Locale.Region { Locale.Region("DJ") }

    @_alwaysEmitIntoClient
    public static var dominica: Locale.Region { Locale.Region("DM") }

    @_alwaysEmitIntoClient
    public static var dominicanRepublic: Locale.Region { Locale.Region("DO") }

    @_alwaysEmitIntoClient
    public static var ecuador: Locale.Region { Locale.Region("EC") }

    @_alwaysEmitIntoClient
    public static var egypt: Locale.Region { Locale.Region("EG") }

    @_alwaysEmitIntoClient
    public static var elSalvador: Locale.Region { Locale.Region("SV") }

    @_alwaysEmitIntoClient
    public static var equatorialGuinea: Locale.Region { Locale.Region("GQ") }

    @_alwaysEmitIntoClient
    public static var eritrea: Locale.Region { Locale.Region("ER") }

    @_alwaysEmitIntoClient
    public static var estonia: Locale.Region { Locale.Region("EE") }

    @_alwaysEmitIntoClient
    public static var eswatini: Locale.Region { Locale.Region("SZ") }

    @_alwaysEmitIntoClient
    public static var ethiopia: Locale.Region { Locale.Region("ET") }

    @_alwaysEmitIntoClient
    public static var falklandIslands: Locale.Region { Locale.Region("FK") }

    @_alwaysEmitIntoClient
    public static var faroeIslands: Locale.Region { Locale.Region("FO") }

    @_alwaysEmitIntoClient
    public static var fiji: Locale.Region { Locale.Region("FJ") }

    @_alwaysEmitIntoClient
    public static var finland: Locale.Region { Locale.Region("FI") }

    @_alwaysEmitIntoClient
    public static var france: Locale.Region { Locale.Region("FR") }

    @_alwaysEmitIntoClient
    public static var frenchGuiana: Locale.Region { Locale.Region("GF") }

    @_alwaysEmitIntoClient
    public static var frenchPolynesia: Locale.Region { Locale.Region("PF") }

    @_alwaysEmitIntoClient
    public static var frenchSouthernTerritories: Locale.Region { Locale.Region("TF") }

    @_alwaysEmitIntoClient
    public static var gabon: Locale.Region { Locale.Region("GA") }

    @_alwaysEmitIntoClient
    public static var gambia: Locale.Region { Locale.Region("GM") }

    @_alwaysEmitIntoClient
    public static var georgia: Locale.Region { Locale.Region("GE") }

    @_alwaysEmitIntoClient
    public static var germany: Locale.Region { Locale.Region("DE") }

    @_alwaysEmitIntoClient
    public static var ghana: Locale.Region { Locale.Region("GH") }

    @_alwaysEmitIntoClient
    public static var gibraltar: Locale.Region { Locale.Region("GI") }

    @_alwaysEmitIntoClient
    public static var greece: Locale.Region { Locale.Region("GR") }

    @_alwaysEmitIntoClient
    public static var greenland: Locale.Region { Locale.Region("GL") }

    @_alwaysEmitIntoClient
    public static var grenada: Locale.Region { Locale.Region("GD") }

    @_alwaysEmitIntoClient
    public static var guadeloupe: Locale.Region { Locale.Region("GP") }

    @_alwaysEmitIntoClient
    public static var guam: Locale.Region { Locale.Region("GU") }

    @_alwaysEmitIntoClient
    public static var guatemala: Locale.Region { Locale.Region("GT") }

    @_alwaysEmitIntoClient
    public static var guernsey: Locale.Region { Locale.Region("GG") }

    @_alwaysEmitIntoClient
    public static var guinea: Locale.Region { Locale.Region("GN") }

    @_alwaysEmitIntoClient
    public static var guineaBissau: Locale.Region { Locale.Region("GW") }

    @_alwaysEmitIntoClient
    public static var guyana: Locale.Region { Locale.Region("GY") }

    @_alwaysEmitIntoClient
    public static var haiti: Locale.Region { Locale.Region("HT") }

    @_alwaysEmitIntoClient
    public static var heardMcdonaldIslands: Locale.Region { Locale.Region("HM") }

    @_alwaysEmitIntoClient
    public static var honduras: Locale.Region { Locale.Region("HN") }

    @_alwaysEmitIntoClient
    public static var hongKong: Locale.Region { Locale.Region("HK") }

    @_alwaysEmitIntoClient
    public static var hungary: Locale.Region { Locale.Region("HU") }

    @_alwaysEmitIntoClient
    public static var iceland: Locale.Region { Locale.Region("IS") }

    @_alwaysEmitIntoClient
    public static var india: Locale.Region { Locale.Region("IN") }

    @_alwaysEmitIntoClient
    public static var indonesia: Locale.Region { Locale.Region("ID") }

    @_alwaysEmitIntoClient
    public static var iran: Locale.Region { Locale.Region("IR") }

    @_alwaysEmitIntoClient
    public static var iraq: Locale.Region { Locale.Region("IQ") }

    @_alwaysEmitIntoClient
    public static var ireland: Locale.Region { Locale.Region("IE") }

    @_alwaysEmitIntoClient
    public static var isleOfMan: Locale.Region { Locale.Region("IM") }

    @_alwaysEmitIntoClient
    public static var israel: Locale.Region { Locale.Region("IL") }

    @_alwaysEmitIntoClient
    public static var italy: Locale.Region { Locale.Region("IT") }

    @_alwaysEmitIntoClient
    public static var jamaica: Locale.Region { Locale.Region("JM") }

    @_alwaysEmitIntoClient
    public static var japan: Locale.Region { Locale.Region("JP") }

    @_alwaysEmitIntoClient
    public static var jersey: Locale.Region { Locale.Region("JE") }

    @_alwaysEmitIntoClient
    public static var jordan: Locale.Region { Locale.Region("JO") }

    @_alwaysEmitIntoClient
    public static var kazakhstan: Locale.Region { Locale.Region("KZ") }

    @_alwaysEmitIntoClient
    public static var kenya: Locale.Region { Locale.Region("KE") }

    @_alwaysEmitIntoClient
    public static var kiribati: Locale.Region { Locale.Region("KI") }

    @_alwaysEmitIntoClient
    public static var kosovo: Locale.Region { Locale.Region("XK") }

    @_alwaysEmitIntoClient
    public static var kuwait: Locale.Region { Locale.Region("KW") }

    @_alwaysEmitIntoClient
    public static var kyrgyzstan: Locale.Region { Locale.Region("KG") }

    @_alwaysEmitIntoClient
    public static var laos: Locale.Region { Locale.Region("LA") }

    @_alwaysEmitIntoClient
    public static var latvia: Locale.Region { Locale.Region("LV") }

    @_alwaysEmitIntoClient
    public static var lebanon: Locale.Region { Locale.Region("LB") }

    @_alwaysEmitIntoClient
    public static var lesotho: Locale.Region { Locale.Region("LS") }

    @_alwaysEmitIntoClient
    public static var liberia: Locale.Region { Locale.Region("LR") }

    @_alwaysEmitIntoClient
    public static var libya: Locale.Region { Locale.Region("LY") }

    @_alwaysEmitIntoClient
    public static var liechtenstein: Locale.Region { Locale.Region("LI") }

    @_alwaysEmitIntoClient
    public static var lithuania: Locale.Region { Locale.Region("LT") }

    @_alwaysEmitIntoClient
    public static var luxembourg: Locale.Region { Locale.Region("LU") }

    @_alwaysEmitIntoClient
    public static var macao: Locale.Region { Locale.Region("MO") }

    @_alwaysEmitIntoClient
    public static var madagascar: Locale.Region { Locale.Region("MG") }

    @_alwaysEmitIntoClient
    public static var malawi: Locale.Region { Locale.Region("MW") }

    @_alwaysEmitIntoClient
    public static var malaysia: Locale.Region { Locale.Region("MY") }

    @_alwaysEmitIntoClient
    public static var maldives: Locale.Region { Locale.Region("MV") }

    @_alwaysEmitIntoClient
    public static var mali: Locale.Region { Locale.Region("ML") }

    @_alwaysEmitIntoClient
    public static var malta: Locale.Region { Locale.Region("MT") }

    @_alwaysEmitIntoClient
    public static var marshallIslands: Locale.Region { Locale.Region("MH") }

    @_alwaysEmitIntoClient
    public static var martinique: Locale.Region { Locale.Region("MQ") }

    @_alwaysEmitIntoClient
    public static var mauritania: Locale.Region { Locale.Region("MR") }

    @_alwaysEmitIntoClient
    public static var mauritius: Locale.Region { Locale.Region("MU") }

    @_alwaysEmitIntoClient
    public static var mayotte: Locale.Region { Locale.Region("YT") }

    @_alwaysEmitIntoClient
    public static var mexico: Locale.Region { Locale.Region("MX") }

    @_alwaysEmitIntoClient
    public static var micronesia: Locale.Region { Locale.Region("FM") }

    @_alwaysEmitIntoClient
    public static var moldova: Locale.Region { Locale.Region("MD") }

    @_alwaysEmitIntoClient
    public static var monaco: Locale.Region { Locale.Region("MC") }

    @_alwaysEmitIntoClient
    public static var mongolia: Locale.Region { Locale.Region("MN") }

    @_alwaysEmitIntoClient
    public static var montenegro: Locale.Region { Locale.Region("ME") }

    @_alwaysEmitIntoClient
    public static var montserrat: Locale.Region { Locale.Region("MS") }

    @_alwaysEmitIntoClient
    public static var morocco: Locale.Region { Locale.Region("MA") }

    @_alwaysEmitIntoClient
    public static var mozambique: Locale.Region { Locale.Region("MZ") }

    @_alwaysEmitIntoClient
    public static var myanmar: Locale.Region { Locale.Region("MM") }

    @_alwaysEmitIntoClient
    public static var namibia: Locale.Region { Locale.Region("NA") }

    @_alwaysEmitIntoClient
    public static var nauru: Locale.Region { Locale.Region("NR") }

    @_alwaysEmitIntoClient
    public static var nepal: Locale.Region { Locale.Region("NP") }

    @_alwaysEmitIntoClient
    public static var netherlands: Locale.Region { Locale.Region("NL") }

    @_alwaysEmitIntoClient
    public static var newCaledonia: Locale.Region { Locale.Region("NC") }

    @_alwaysEmitIntoClient
    public static var newZealand: Locale.Region { Locale.Region("NZ") }

    @_alwaysEmitIntoClient
    public static var nicaragua : Locale.Region { Locale.Region("NI") }

    @_alwaysEmitIntoClient
    public static var niger: Locale.Region { Locale.Region("NE") }

    @_alwaysEmitIntoClient
    public static var nigeria: Locale.Region { Locale.Region("NG") }

    @_alwaysEmitIntoClient
    public static var niue: Locale.Region { Locale.Region("NU") }

    @_alwaysEmitIntoClient
    public static var norfolkIsland: Locale.Region { Locale.Region("NF") }

    @_alwaysEmitIntoClient
    public static var northernMarianaIslands: Locale.Region { Locale.Region("MP") }

    @_alwaysEmitIntoClient
    public static var northMacedonia: Locale.Region { Locale.Region("MK") }

    @_alwaysEmitIntoClient
    public static var norway: Locale.Region { Locale.Region("NO") }

    @_alwaysEmitIntoClient
    public static var oman: Locale.Region { Locale.Region("OM") }

    @_alwaysEmitIntoClient
    public static var pakistan: Locale.Region { Locale.Region("PK") }

    @_alwaysEmitIntoClient
    public static var palau: Locale.Region { Locale.Region("PW") }

    @_alwaysEmitIntoClient
    public static var palestinianTerritories: Locale.Region { Locale.Region("PS") }

    @_alwaysEmitIntoClient
    public static var panama: Locale.Region { Locale.Region("PA") }

    @_alwaysEmitIntoClient
    public static var papuaNewGuinea: Locale.Region { Locale.Region("PG") }

    @_alwaysEmitIntoClient
    public static var paraguay: Locale.Region { Locale.Region("PY") }

    @_alwaysEmitIntoClient
    public static var peru: Locale.Region { Locale.Region("PE") }

    @_alwaysEmitIntoClient
    public static var philippines: Locale.Region { Locale.Region("PH") }

    @_alwaysEmitIntoClient
    public static var pitcairnIslands: Locale.Region { Locale.Region("PN") }

    @_alwaysEmitIntoClient
    public static var poland: Locale.Region { Locale.Region("PL") }

    @_alwaysEmitIntoClient
    public static var portugal: Locale.Region { Locale.Region("PT") }

    @_alwaysEmitIntoClient
    public static var puertoRico: Locale.Region { Locale.Region("PR") }

    @_alwaysEmitIntoClient
    public static var qatar: Locale.Region { Locale.Region("QA") }

    @_alwaysEmitIntoClient
    public static var réunion: Locale.Region { Locale.Region("RE") }

    @_alwaysEmitIntoClient
    public static var romania: Locale.Region { Locale.Region("RO") }

    @_alwaysEmitIntoClient
    public static var russia: Locale.Region { Locale.Region("RU") }

    @_alwaysEmitIntoClient
    public static var rwanda: Locale.Region { Locale.Region("RW") }

    @_alwaysEmitIntoClient
    public static var saintBarthélemy: Locale.Region { Locale.Region("BL") }

    @_alwaysEmitIntoClient
    public static var saintHelena: Locale.Region { Locale.Region("SH") }

    @_alwaysEmitIntoClient
    public static var saintKittsNevis: Locale.Region { Locale.Region("KN") }

    @_alwaysEmitIntoClient
    public static var saintLucia: Locale.Region { Locale.Region("LC") }

    @_alwaysEmitIntoClient
    public static var saintMartin: Locale.Region { Locale.Region("MF") }

    @_alwaysEmitIntoClient
    public static var saintPierreMiquelon: Locale.Region { Locale.Region("PM") }

    @_alwaysEmitIntoClient
    public static var saintVincentGrenadines: Locale.Region { Locale.Region("VC") }

    @_alwaysEmitIntoClient
    public static var samoa: Locale.Region { Locale.Region("WS") }

    @_alwaysEmitIntoClient
    public static var sanMarino: Locale.Region { Locale.Region("SM") }

    @_alwaysEmitIntoClient
    public static var sãoToméPríncipe: Locale.Region { Locale.Region("ST") }

    @_alwaysEmitIntoClient
    public static var saudiArabia: Locale.Region { Locale.Region("SA") }

    @_alwaysEmitIntoClient
    public static var senegal: Locale.Region { Locale.Region("SN") }

    @_alwaysEmitIntoClient
    public static var serbia: Locale.Region { Locale.Region("RS") }

    @_alwaysEmitIntoClient
    public static var seychelles: Locale.Region { Locale.Region("SC") }

    @_alwaysEmitIntoClient
    public static var sierraLeone: Locale.Region { Locale.Region("SL") }

    @_alwaysEmitIntoClient
    public static var singapore: Locale.Region { Locale.Region("SG") }

    @_alwaysEmitIntoClient
    public static var sintMaarten: Locale.Region { Locale.Region("SX") }

    @_alwaysEmitIntoClient
    public static var slovakia: Locale.Region { Locale.Region("SK") }

    @_alwaysEmitIntoClient
    public static var slovenia: Locale.Region { Locale.Region("SI") }

    @_alwaysEmitIntoClient
    public static var solomonIslands: Locale.Region { Locale.Region("SB") }

    @_alwaysEmitIntoClient
    public static var somalia: Locale.Region { Locale.Region("SO") }

    @_alwaysEmitIntoClient
    public static var southAfrica: Locale.Region { Locale.Region("ZA") }

    @_alwaysEmitIntoClient
    public static var southGeorgiaSouthSandwichIslands: Locale.Region { Locale.Region("GS") }

    @_alwaysEmitIntoClient
    public static var southKorea: Locale.Region { Locale.Region("KR") }

    @_alwaysEmitIntoClient
    public static var southSudan: Locale.Region { Locale.Region("SS") }

    @_alwaysEmitIntoClient
    public static var spain: Locale.Region { Locale.Region("ES") }

    @_alwaysEmitIntoClient
    public static var sriLanka: Locale.Region { Locale.Region("LK") }

    @_alwaysEmitIntoClient
    public static var suriname: Locale.Region { Locale.Region("SR") }

    @_alwaysEmitIntoClient
    public static var svalbardJanMayen: Locale.Region { Locale.Region("SJ") }

    @_alwaysEmitIntoClient
    public static var sweden: Locale.Region { Locale.Region("SE") }

    @_alwaysEmitIntoClient
    public static var switzerland: Locale.Region { Locale.Region("CH") }

    @_alwaysEmitIntoClient
    public static var taiwan: Locale.Region { Locale.Region("TW") }

    @_alwaysEmitIntoClient
    public static var tajikistan: Locale.Region { Locale.Region("TJ") }

    @_alwaysEmitIntoClient
    public static var tanzania: Locale.Region { Locale.Region("TZ") }

    @_alwaysEmitIntoClient
    public static var thailand: Locale.Region { Locale.Region("TH") }

    @_alwaysEmitIntoClient
    public static var timorLeste: Locale.Region { Locale.Region("TL") }

    @_alwaysEmitIntoClient
    public static var togo: Locale.Region { Locale.Region("TG") }

    @_alwaysEmitIntoClient
    public static var tokelau: Locale.Region { Locale.Region("TK") }

    @_alwaysEmitIntoClient
    public static var tonga: Locale.Region { Locale.Region("TO") }

    @_alwaysEmitIntoClient
    public static var trinidadTobago: Locale.Region { Locale.Region("TT") }

    @_alwaysEmitIntoClient
    public static var tristanDaCunha: Locale.Region { Locale.Region("TA") }

    @_alwaysEmitIntoClient
    public static var tunisia: Locale.Region { Locale.Region("TN") }

    @_alwaysEmitIntoClient
    public static var turkey: Locale.Region { Locale.Region("TR") }

    @_alwaysEmitIntoClient
    public static var turkmenistan: Locale.Region { Locale.Region("TM") }

    @_alwaysEmitIntoClient
    public static var turksCaicosIslands: Locale.Region { Locale.Region("TC") }

    @_alwaysEmitIntoClient
    public static var tuvalu: Locale.Region { Locale.Region("TV") }

    @_alwaysEmitIntoClient
    public static var uganda: Locale.Region { Locale.Region("UG") }

    @_alwaysEmitIntoClient
    public static var ukraine: Locale.Region { Locale.Region("UA") }

    @_alwaysEmitIntoClient
    public static var unitedArabEmirates: Locale.Region { Locale.Region("AE") }

    @_alwaysEmitIntoClient
    public static var unitedKingdom: Locale.Region { Locale.Region("GB") }

    @_alwaysEmitIntoClient
    public static var unitedStates: Locale.Region { Locale.Region("US") }

    @_alwaysEmitIntoClient
    public static var unitedStatesOutlyingIslands: Locale.Region { Locale.Region("UM") }

    @_alwaysEmitIntoClient
    public static var unitedStatesVirginIslands: Locale.Region { Locale.Region("VI") }

    @_alwaysEmitIntoClient
    public static var uruguay: Locale.Region { Locale.Region("UY") }

    @_alwaysEmitIntoClient
    public static var uzbekistan: Locale.Region { Locale.Region("UZ") }

    @_alwaysEmitIntoClient
    public static var vanuatu: Locale.Region { Locale.Region("VU") }

    @_alwaysEmitIntoClient
    public static var vaticanCity: Locale.Region { Locale.Region("VA") }

    @_alwaysEmitIntoClient
    public static var venezuela: Locale.Region { Locale.Region("VE") }

    @_alwaysEmitIntoClient
    public static var vietnam: Locale.Region { Locale.Region("VN") }

    @_alwaysEmitIntoClient
    public static var wallisFutuna: Locale.Region { Locale.Region("WF") }

    @_alwaysEmitIntoClient
    public static var westernSahara: Locale.Region { Locale.Region("EH") }

    @_alwaysEmitIntoClient
    public static var yemen: Locale.Region { Locale.Region("YE") }

    @_alwaysEmitIntoClient
    public static var zambia: Locale.Region { Locale.Region("ZM") }

    @_alwaysEmitIntoClient
    public static var zimbabwe: Locale.Region { Locale.Region("ZW") }

    // MARK: - Region codes for specifying language variants

    @_alwaysEmitIntoClient
    public static var world: Locale.Region { Locale.Region("001") }

    @_alwaysEmitIntoClient
    public static var latinAmerica: Locale.Region { Locale.Region("419") }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Script {
    @_alwaysEmitIntoClient
    public static var adlam: Locale.Script { Locale.Script("Adlm") }

    @_alwaysEmitIntoClient
    public static var arabic: Locale.Script { Locale.Script("Arab") }

    @_alwaysEmitIntoClient
    public static var arabicNastaliq: Locale.Script { Locale.Script("Aran") }

    @_alwaysEmitIntoClient
    public static var armenian: Locale.Script { Locale.Script("Armn") }

    @_alwaysEmitIntoClient
    public static var bangla: Locale.Script { Locale.Script("Beng") }

    @_alwaysEmitIntoClient
    public static var cherokee: Locale.Script { Locale.Script("Cher") }

    @_alwaysEmitIntoClient
    public static var cyrillic: Locale.Script { Locale.Script("Cyrl") }

    @_alwaysEmitIntoClient
    public static var devanagari: Locale.Script { Locale.Script("Deva") }

    @_alwaysEmitIntoClient
    public static var ethiopic: Locale.Script { Locale.Script("Ethi") }

    @_alwaysEmitIntoClient
    public static var georgian: Locale.Script { Locale.Script("Geor") }

    @_alwaysEmitIntoClient
    public static var greek: Locale.Script { Locale.Script("Grek") }

    @_alwaysEmitIntoClient
    public static var gujarati: Locale.Script { Locale.Script("Gujr") }

    @_alwaysEmitIntoClient
    public static var gurmukhi: Locale.Script { Locale.Script("Guru") }

    @_alwaysEmitIntoClient
    public static var hanifiRohingya: Locale.Script { Locale.Script("Rohg") }

    @_alwaysEmitIntoClient
    public static var hanSimplified: Locale.Script { Locale.Script("Hans") }

    @_alwaysEmitIntoClient
    public static var hanTraditional: Locale.Script { Locale.Script("Hant") }

    @_alwaysEmitIntoClient
    public static var hebrew: Locale.Script { Locale.Script("Hebr") }

    @_alwaysEmitIntoClient
    public static var hiragana: Locale.Script { Locale.Script("Hira") }

    @_alwaysEmitIntoClient
    public static var japanese: Locale.Script { Locale.Script("Jpan") }

    @_alwaysEmitIntoClient
    public static var kannada: Locale.Script { Locale.Script("Knda") }

    @_alwaysEmitIntoClient
    public static var katakana: Locale.Script { Locale.Script("Kana") }

    @_alwaysEmitIntoClient
    public static var khmer: Locale.Script { Locale.Script("Khmr") }

    @_alwaysEmitIntoClient
    public static var korean: Locale.Script { Locale.Script("Kore") }

    @_alwaysEmitIntoClient
    public static var lao: Locale.Script { Locale.Script("Laoo") }

    @_alwaysEmitIntoClient
    public static var latin: Locale.Script { Locale.Script("Latn") }

    @_alwaysEmitIntoClient
    public static var malayalam: Locale.Script { Locale.Script("Mlym") }

    @_alwaysEmitIntoClient
    public static var meiteiMayek: Locale.Script { Locale.Script("Mtei") }

    @_alwaysEmitIntoClient
    public static var myanmar: Locale.Script { Locale.Script("Mymr") }

    @_alwaysEmitIntoClient
    public static var odia: Locale.Script { Locale.Script("Orya") }

    @_alwaysEmitIntoClient
    public static var olChiki: Locale.Script { Locale.Script("Olck") }

    @_alwaysEmitIntoClient
    public static var sinhala: Locale.Script { Locale.Script("Sinh") }

    @_alwaysEmitIntoClient
    public static var syriac: Locale.Script { Locale.Script("Syrc") }

    @_alwaysEmitIntoClient
    public static var tamil: Locale.Script { Locale.Script("Taml") }

    @_alwaysEmitIntoClient
    public static var telugu: Locale.Script { Locale.Script("Telu") }

    @_alwaysEmitIntoClient
    public static var thaana: Locale.Script { Locale.Script("Thaa") }

    @_alwaysEmitIntoClient
    public static var thai: Locale.Script { Locale.Script("Thai") }

    @_alwaysEmitIntoClient
    public static var tibetan: Locale.Script { Locale.Script("Tibt") }
}

