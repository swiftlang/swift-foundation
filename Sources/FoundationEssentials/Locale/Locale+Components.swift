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
@preconcurrency import Glibc
#endif

extension Locale {

    /// A type that represents the components of a locale, for use when creating a locale with specific overrides.
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

        /// The region used by the locale.
        ///
        /// Set this property to override the region for region-related preferences,
        /// such as measuring system, calendar, and first day of the week. If unset,
        /// the locale uses the region of the language component.
        ///
        /// This property corresponds to the `rg` key of the Unicode BCP 47 extension.
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

        // Returns an ICU-style identifier like "de_DE@calendar=gregorian"
        // Must include every component stored by a `Locale.Components`, and be kept in sync with `init(identifier:)`.
        package var icuIdentifier: String {

            var keywords = [(ICULegacyKey, String)]()
            if let id = calendar?.cldrIdentifier { keywords.append((Calendar.Identifier.legacyKeywordKey, id)) }
            if let id = collation?._normalizedIdentifier { keywords.append((Locale.Collation.legacyKeywordKey, id)) }
            if let id = currency?._normalizedIdentifier { keywords.append((Locale.Currency.legacyKeywordKey, id)) }
            if let id = numberingSystem?._normalizedIdentifier { keywords.append((Locale.NumberingSystem.legacyKeywordKey, id)) }
            if let id = firstDayOfWeek?.rawValue { keywords.append((Locale.Weekday.legacyKeywordKey, id)) }
            if let id = hourCycle?.rawValue { keywords.append((Locale.HourCycle.legacyKeywordKey, id)) }
            if let id = measurementSystem?._normalizedIdentifier { keywords.append((Locale.MeasurementSystem.legacyKeywordKey, id)) }
            // No need for redundant region keyword
            if let region = region, region != languageComponents.region {
                // rg keyword value is actually a subdivision code
                keywords.append((Locale.Region.legacyKeywordKey, Locale.Subdivision.subdivision(for: region)._normalizedIdentifier))
            }
            if let id = subdivision?._normalizedIdentifier { keywords.append((Locale.Subdivision.legacyKeywordKey, id)) }
            if let id = timeZone?.identifier { keywords.append((TimeZone.legacyKeywordKey, id)) }
            if let id = variant?._normalizedIdentifier { keywords.append((Locale.Variant.legacyKeywordKey, id)) }

            var locID = languageComponents.identifier
            let keywordCounts = keywords.count
            if keywordCounts > 0 {
                locID.append("@")
            }

            for (i, (key, val)) in keywords.enumerated() {
                locID.append("\(key.key)=\(val)")
                if i != keywordCounts - 1 {
                    locID.append(";")
                }
            }
            return locID
        }
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.LanguageCode : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Script : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Region : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Currency : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Collation : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.NumberingSystem : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Subdivision : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.Variant : CustomDebugStringConvertible { }

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
extension Locale.MeasurementSystem : CustomDebugStringConvertible { }

extension Locale {

    /// An alphabetical code associated with a language.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct LanguageCode : Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        /// Creates a language code from an identifier as a string literal.
        ///
        /// - Parameter value: A two-letter ISO 639-1 or three-letter ISO 639-2 code, such as `en` for English. You can also use a code of your own choice for a custom language.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        /// Creates a `LanguageCode` type.
        /// - Parameter identifier: A two-letter or three-letter ISO 639 code, or a language code of your choice if using a custom language, such as "en" for English. Case-insensitive.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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

    /// The written script used with a given language.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Script : Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        /// Creates a script from a BCP 47 identifier as a string literal.
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

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
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

    /// A type that represents a geographic region, for use in specifying a locale or language.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Region : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("rg")
        package static let legacyKeywordKey = ICULegacyKey("rg")

        /// Creates a region from a BCP 47 identifier as a string literal.
        ///
        /// - Parameter value: A BCP 47 identifier, such as `US` for the United States. This parameter is case-insensitive.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// The BCP 47 identifier of the region.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.uppercased()
                _identifier = newValue
            }
        }

        /// Creates a region from a BCP 47 identifier.
        /// - Parameter identifier: A two-letter BCP 47 region subtag such as "US" for the United States. Case-insensitive.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.uppercased()
        }

        /// A pre-defined unknown or invalid region.
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

    /// A type that represents the string sort order used by the locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Collation : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("co")
        package static let legacyKeywordKey = ICULegacyKey("collation")

        /// Creates a collation from a BCP 47 identifier as a string literal.
        ///
        /// - Parameter value: The BCP 47 collation identifier, like `standard` for a language's standard ordering, or `phonetic` for phonetic ordering.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String
        /// The collation's BCP 47 identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.capitalized
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a collation from a BCP 47 identifier.
        ///
        /// - Parameter identifier: The BCP 47 collation identifier, like `standard` for a language's standard ordering, or `phonetic` for phonetic ordering. The complete list of collation identifiers can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/collation.xml), under the key named "co".
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// A collation used for string search.
        ///
        /// Use this collation only for determining whether to consider two strings as equivalent. Using this collation may modify the string for search purposes. For example, this collation suppresses the contractions in Thai and Lao.
        ///
        /// Don't use this collation to determine the relative order of two strings.
        public static let searchRules = Collation("search")
        /// A collation that provides the default ordering for each language.
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

    /// A type that represents the currency system used by a locale, like dollars or euros.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Currency : Hashable, Codable, Sendable, ExpressibleByStringLiteral {
        // The complete list of currency codes can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/currency.xml), under the key with the name "cu"
        
        package static let cldrKeywordKey = ICUCLDRKey("cu")
        package static let legacyKeywordKey = ICULegacyKey("currency")

        /// Creates a currency instance from a BCP 47 identifier as a string literal.
        ///
        /// - Parameter value: The currency's BCP 47 identifier, like `usd` for US dollars, or `jpy` for Japanese yen.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        /// The currency's identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a currency instance from a BCP 47 identifier.
        ///
        /// - Parameter identifier: The currency's BCP 47 identifier, like `usd` for US dollars, or `jpy` for Japanese yen.
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

    /// A type that represents the numbering system used in a locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct NumberingSystem : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("nu")
        package static let legacyKeywordKey = ICULegacyKey("numbers")

        /// Creates a numbering system instance from a BCP 47 identifier as a string literal.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        /// The numbering system's identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a numbering system from a BCP 47 identifier.
        ///
        /// The complete list of valid numbering systems can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/number.xml), under the key with the name "nu".
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

    /// A type that represents weekdays, used for indicating a locale's first day of the week.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum Weekday: String, Codable, Hashable, Sendable {
        /// The weekday enumeration value for Sunday.
        case sunday = "sun"
        /// The weekday enumeration value for Monday.
        case monday = "mon"
        /// The weekday enumeration value for Tuesday.
        case tuesday = "tue"
        /// The weekday enumeration value for Wednesday.
        case wednesday = "wed"
        /// The weekday enumeration value for Thursday.
        case thursday = "thu"
        /// The weekday enumeration value for Friday.
        case friday = "fri"
        /// The weekday enumeration value for Saturday.
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

        package init?(_ localePrefIndex: Int) {
            guard let innerSelf = Weekday(Int32(localePrefIndex)) else {
                return nil
            }
            self = innerSelf
        }

        package var icuIndex: Int {
            Self.weekdays.firstIndex(of: self)! + 1
        }
    }

    /// A type that represents the hour cycle used in a locale, like one-to-twelve or zero-to-twenty-three.
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

    /// A type that represents the measurement system used by a locale, like metric or the US system.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct MeasurementSystem: Codable, Hashable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("ms")
        package static let legacyKeywordKey = ICULegacyKey("measure")

        /// Creates a measurement system instance from a BCP 47 identifier as a string literal.
        ///
        /// - Parameter value: The measurement system's BCP 47 identifier, like `metric` or `ussystem`.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        /// The measurement system's identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a measurement system from a BCP 47 identifier.
        ///
        /// The complete list of valid measurement systems can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/measure.xml), under the key with the name "ms".
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// The metric system.
        public static let metric = MeasurementSystem("metric")
        /// The US system of measurement: feet, pints, etc.; pints are 16oz.
        public static let us = MeasurementSystem("ussystem")
        /// The UK system of measurement: feet, pints, etc.; pints are 20oz.
        public static let uk = MeasurementSystem("uksystem")

        /// An array containing all available measurement systems.
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

    /// A type that represents a subdivision of a region, such as a state in the US or a province in Canada.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Subdivision : Hashable, Codable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("sd")
        package static let legacyKeywordKey = ICULegacyKey("sd")

        /// Creates a subdivision from a Unicode identifier as a string literal.
        ///
        /// - Parameter value: The subdivision's identifier.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        /// The subdivision's identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a subdivision with the given identifier.
        /// - Parameter identifier: A unicode subdivision identifier, such as "usca" for California, US. Case-insensitive. The complete list of subdivision identifiers can be found [here](https://github.com/unicode-org/cldr/blob/maint/maint-40/common/validity/subdivision.xml), under the "subdivision" type.
        public init(_ identifier: String) {
            _identifier = identifier
            _normalizedIdentifier = identifier.lowercased()
        }

        /// Returns the subdivision representing the given region as a whole.
        ///
        /// For example, returns a subdivision with the "uszzzz" identifier for the entire US region.
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

    /// A type that represents a locale's language variant.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public struct Variant: Codable, Hashable, Sendable, ExpressibleByStringLiteral {

        package static let cldrKeywordKey = ICUCLDRKey("va")
        package static let legacyKeywordKey = ICULegacyKey("va")

        /// Creates a variant from a BCP 47 identifier as a string literal.
        ///
        /// - Parameter value: The variant's BCP 47 identifier.
        public init(stringLiteral value: String) {
            self.init(value)
        }

        package var _identifier: String
        package var _normalizedIdentifier: String

        /// The variant's identifier.
        public var identifier: String {
            get {
                _identifier
            }
            set {
                _normalizedIdentifier = newValue.lowercased()
                _identifier = newValue
            }
        }

        @available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
        public var debugDescription: String {
            _normalizedIdentifier
        }

        /// Creates a variant from a BCP 47 identifier.
        ///
        /// The complete list of valid variants can be found [here](https://github.com/unicode-org/cldr/blob/latest/common/bcp47/variant.xml), under the key named "va".
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
    @export(implementation)
    public static var ainu: Locale.LanguageCode { Locale.LanguageCode("ain") }

    @export(implementation)
    public static var albanian: Locale.LanguageCode { Locale.LanguageCode("sq") }

    @export(implementation)
    public static var amharic: Locale.LanguageCode { Locale.LanguageCode("am") }

    @export(implementation)
    public static var apacheWestern: Locale.LanguageCode { Locale.LanguageCode("apw") }

    @export(implementation)
    public static var arabic: Locale.LanguageCode { Locale.LanguageCode("ar") }

    @export(implementation)
    public static var armenian: Locale.LanguageCode { Locale.LanguageCode("hy") }

    @export(implementation)
    public static var assamese: Locale.LanguageCode { Locale.LanguageCode("as") }

    @export(implementation)
    public static var assyrian: Locale.LanguageCode { Locale.LanguageCode("syr") }

    @export(implementation)
    public static var azerbaijani: Locale.LanguageCode { Locale.LanguageCode("az") }

    @export(implementation)
    public static var bangla: Locale.LanguageCode { Locale.LanguageCode("bn") }

    @export(implementation)
    public static var belarusian: Locale.LanguageCode { Locale.LanguageCode("be") }

    @export(implementation)
    public static var bodo: Locale.LanguageCode { Locale.LanguageCode("brx") }

    @export(implementation)
    public static var bulgarian: Locale.LanguageCode { Locale.LanguageCode("bg") }

    @export(implementation)
    public static var burmese: Locale.LanguageCode { Locale.LanguageCode("my") }

    @export(implementation)
    public static var cantonese: Locale.LanguageCode { Locale.LanguageCode("yue") }

    @export(implementation)
    public static var catalan: Locale.LanguageCode { Locale.LanguageCode("ca") }

    @export(implementation)
    public static var cherokee: Locale.LanguageCode { Locale.LanguageCode("chr") }

    @export(implementation)
    public static var chinese: Locale.LanguageCode { Locale.LanguageCode("zh") }

    @export(implementation)
    public static var croatian: Locale.LanguageCode { Locale.LanguageCode("hr") }

    @export(implementation)
    public static var czech: Locale.LanguageCode { Locale.LanguageCode("cs") }

    @export(implementation)
    public static var danish: Locale.LanguageCode { Locale.LanguageCode("da") }

    @export(implementation)
    public static var dhivehi: Locale.LanguageCode { Locale.LanguageCode("dv") }

    @export(implementation)
    public static var dogri: Locale.LanguageCode { Locale.LanguageCode("doi") }

    @export(implementation)
    public static var dutch: Locale.LanguageCode { Locale.LanguageCode("nl") }

    @export(implementation)
    public static var dzongkha: Locale.LanguageCode { Locale.LanguageCode("dz") }

    @export(implementation)
    public static var english: Locale.LanguageCode { Locale.LanguageCode("en") }

    @export(implementation)
    public static var estonian: Locale.LanguageCode { Locale.LanguageCode("et") }

    @export(implementation)
    public static var faroese: Locale.LanguageCode { Locale.LanguageCode("fo") }

    @export(implementation)
    public static var finnish: Locale.LanguageCode { Locale.LanguageCode("fi") }

    @export(implementation)
    public static var french: Locale.LanguageCode { Locale.LanguageCode("fr") }

    @export(implementation)
    public static var fula: Locale.LanguageCode { Locale.LanguageCode("ff") }

    @export(implementation)
    public static var georgian: Locale.LanguageCode { Locale.LanguageCode("ka") }

    @export(implementation)
    public static var german: Locale.LanguageCode { Locale.LanguageCode("de") }

    @export(implementation)
    public static var greek: Locale.LanguageCode { Locale.LanguageCode("el") }

    @export(implementation)
    public static var gujarati: Locale.LanguageCode { Locale.LanguageCode("gu") }

    @export(implementation)
    public static var hawaiian: Locale.LanguageCode { Locale.LanguageCode("haw") }

    @export(implementation)
    public static var hebrew: Locale.LanguageCode { Locale.LanguageCode("he") }

    @export(implementation)
    public static var hindi: Locale.LanguageCode { Locale.LanguageCode("hi") }

    @export(implementation)
    public static var hungarian: Locale.LanguageCode { Locale.LanguageCode("hu") }

    @export(implementation)
    public static var icelandic: Locale.LanguageCode { Locale.LanguageCode("is") }

    @export(implementation)
    public static var igbo: Locale.LanguageCode { Locale.LanguageCode("ig") }

    @export(implementation)
    public static var indonesian: Locale.LanguageCode { Locale.LanguageCode("id") }

    @export(implementation)
    public static var irish: Locale.LanguageCode { Locale.LanguageCode("ga") }

    @export(implementation)
    public static var italian: Locale.LanguageCode { Locale.LanguageCode("it") }

    @export(implementation)
    public static var japanese: Locale.LanguageCode { Locale.LanguageCode("ja") }

    @export(implementation)
    public static var kannada: Locale.LanguageCode { Locale.LanguageCode("kn") }

    @export(implementation)
    public static var kashmiri: Locale.LanguageCode { Locale.LanguageCode("ks") }

    @export(implementation)
    public static var kazakh: Locale.LanguageCode { Locale.LanguageCode("kk") }

    @export(implementation)
    public static var khmer: Locale.LanguageCode { Locale.LanguageCode("km") }

    @export(implementation)
    public static var konkani: Locale.LanguageCode { Locale.LanguageCode("kok") }

    @export(implementation)
    public static var korean: Locale.LanguageCode { Locale.LanguageCode("ko") }

    @export(implementation)
    public static var kurdish: Locale.LanguageCode { Locale.LanguageCode("ku") }

    @export(implementation)
    public static var kurdishSorani: Locale.LanguageCode { Locale.LanguageCode("ckb") }

    @export(implementation)
    public static var kyrgyz: Locale.LanguageCode { Locale.LanguageCode("ky") }

    @export(implementation)
    public static var lao: Locale.LanguageCode { Locale.LanguageCode("lo") }

    @export(implementation)
    public static var latvian: Locale.LanguageCode { Locale.LanguageCode("lv") }

    @export(implementation)
    public static var lithuanian: Locale.LanguageCode { Locale.LanguageCode("lt") }

    @export(implementation)
    public static var macedonian: Locale.LanguageCode { Locale.LanguageCode("mk") }

    @export(implementation)
    public static var maithili: Locale.LanguageCode { Locale.LanguageCode("mai") }

    @export(implementation)
    public static var malay: Locale.LanguageCode { Locale.LanguageCode("ms") }

    @export(implementation)
    public static var malayalam: Locale.LanguageCode { Locale.LanguageCode("ml") }

    @export(implementation)
    public static var maltese: Locale.LanguageCode { Locale.LanguageCode("mt") }

    @export(implementation)
    public static var manipuri: Locale.LanguageCode { Locale.LanguageCode("mni") }

    @export(implementation)
    public static var māori: Locale.LanguageCode { Locale.LanguageCode("mi") }

    @export(implementation)
    public static var marathi: Locale.LanguageCode { Locale.LanguageCode("mr") }

    @export(implementation)
    public static var mongolian: Locale.LanguageCode { Locale.LanguageCode("mn") }

    @export(implementation)
    public static var navajo: Locale.LanguageCode { Locale.LanguageCode("nv") }

    @export(implementation)
    public static var nepali: Locale.LanguageCode { Locale.LanguageCode("ne") }

    @export(implementation)
    public static var norwegian: Locale.LanguageCode { Locale.LanguageCode("no") }

    @export(implementation)
    public static var norwegianBokmål: Locale.LanguageCode { Locale.LanguageCode("nb") }

    @export(implementation)
    public static var norwegianNynorsk: Locale.LanguageCode { Locale.LanguageCode("nn") }

    @export(implementation)
    public static var odia: Locale.LanguageCode { Locale.LanguageCode("or") }

    @export(implementation)
    public static var pashto: Locale.LanguageCode { Locale.LanguageCode("ps") }

    @export(implementation)
    public static var persian: Locale.LanguageCode { Locale.LanguageCode("fa") }

    @export(implementation)
    public static var polish: Locale.LanguageCode { Locale.LanguageCode("pl") }

    @export(implementation)
    public static var portuguese: Locale.LanguageCode { Locale.LanguageCode("pt") }

    @export(implementation)
    public static var punjabi: Locale.LanguageCode { Locale.LanguageCode("pa") }

    @export(implementation)
    public static var rohingya: Locale.LanguageCode { Locale.LanguageCode("rhg") }

    @export(implementation)
    public static var romanian: Locale.LanguageCode { Locale.LanguageCode("ro") }

    @export(implementation)
    public static var russian: Locale.LanguageCode { Locale.LanguageCode("ru") }

    @export(implementation)
    public static var samoan: Locale.LanguageCode { Locale.LanguageCode("sm") }

    @export(implementation)
    public static var sanskrit: Locale.LanguageCode { Locale.LanguageCode("sa") }

    @export(implementation)
    public static var santali: Locale.LanguageCode { Locale.LanguageCode("sat") }

    @export(implementation)
    public static var serbian: Locale.LanguageCode { Locale.LanguageCode("sr") }

    @export(implementation)
    public static var sindhi: Locale.LanguageCode { Locale.LanguageCode("sd") }

    @export(implementation)
    public static var sinhala: Locale.LanguageCode { Locale.LanguageCode("si") }

    @export(implementation)
    public static var slovak: Locale.LanguageCode { Locale.LanguageCode("sk") }

    @export(implementation)
    public static var slovenian: Locale.LanguageCode { Locale.LanguageCode("sl") }

    @export(implementation)
    public static var spanish: Locale.LanguageCode { Locale.LanguageCode("es") }

    @export(implementation)
    public static var swahili: Locale.LanguageCode { Locale.LanguageCode("sw") }

    @export(implementation)
    public static var swedish: Locale.LanguageCode { Locale.LanguageCode("sv") }

    @export(implementation)
    public static var tagalog: Locale.LanguageCode { Locale.LanguageCode("tl") }

    @export(implementation)
    public static var tajik: Locale.LanguageCode { Locale.LanguageCode("tg") }

    @export(implementation)
    public static var tamil: Locale.LanguageCode { Locale.LanguageCode("ta") }

    @export(implementation)
    public static var telugu: Locale.LanguageCode { Locale.LanguageCode("te") }

    @export(implementation)
    public static var thai: Locale.LanguageCode { Locale.LanguageCode("th") }

    @export(implementation)
    public static var tibetan: Locale.LanguageCode { Locale.LanguageCode("bo") }

    @export(implementation)
    public static var tongan: Locale.LanguageCode { Locale.LanguageCode("to") }

    @export(implementation)
    public static var turkish: Locale.LanguageCode { Locale.LanguageCode("tr") }

    @export(implementation)
    public static var turkmen: Locale.LanguageCode { Locale.LanguageCode("tk") }

    @export(implementation)
    public static var ukrainian: Locale.LanguageCode { Locale.LanguageCode("uk") }

    @export(implementation)
    public static var urdu: Locale.LanguageCode { Locale.LanguageCode("ur") }

    @export(implementation)
    public static var uyghur: Locale.LanguageCode { Locale.LanguageCode("ug") }

    @export(implementation)
    public static var uzbek: Locale.LanguageCode { Locale.LanguageCode("uz") }

    @export(implementation)
    public static var vietnamese: Locale.LanguageCode { Locale.LanguageCode("vi") }

    @export(implementation)
    public static var welsh: Locale.LanguageCode { Locale.LanguageCode("cy") }

    @export(implementation)
    public static var yiddish: Locale.LanguageCode { Locale.LanguageCode("yi") }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Region {
    @export(implementation)
    public static var afghanistan: Locale.Region { Locale.Region("AF") }

    @export(implementation)
    public static var ålandIslands: Locale.Region { Locale.Region("AX") }

    @export(implementation)
    public static var albania: Locale.Region { Locale.Region("AL") }

    @export(implementation)
    public static var algeria: Locale.Region { Locale.Region("DZ") }

    @export(implementation)
    public static var americanSamoa: Locale.Region { Locale.Region("AS") }

    @export(implementation)
    public static var andorra: Locale.Region { Locale.Region("AD") }

    @export(implementation)
    public static var angola: Locale.Region { Locale.Region("AO") }

    @export(implementation)
    public static var anguilla: Locale.Region { Locale.Region("AI") }

    @export(implementation)
    public static var antarctica: Locale.Region { Locale.Region("AQ") }

    @export(implementation)
    public static var antiguaBarbuda: Locale.Region { Locale.Region("AG") }

    @export(implementation)
    public static var argentina: Locale.Region { Locale.Region("AR") }

    @export(implementation)
    public static var armenia: Locale.Region { Locale.Region("AM") }

    @export(implementation)
    public static var aruba: Locale.Region { Locale.Region("AW") }

    @export(implementation)
    public static var ascensionIsland: Locale.Region { Locale.Region("AC") }

    @export(implementation)
    public static var australia: Locale.Region { Locale.Region("AU") }

    @export(implementation)
    public static var austria: Locale.Region { Locale.Region("AT") }

    @export(implementation)
    public static var azerbaijan: Locale.Region { Locale.Region("AZ") }

    @export(implementation)
    public static var bahamas: Locale.Region { Locale.Region("BS") }

    @export(implementation)
    public static var bahrain: Locale.Region { Locale.Region("BH") }

    @export(implementation)
    public static var bangladesh: Locale.Region { Locale.Region("BD") }

    @export(implementation)
    public static var barbados: Locale.Region { Locale.Region("BB") }

    @export(implementation)
    public static var belarus: Locale.Region { Locale.Region("BY") }

    @export(implementation)
    public static var belgium: Locale.Region { Locale.Region("BE") }

    @export(implementation)
    public static var belize: Locale.Region { Locale.Region("BZ") }

    @export(implementation)
    public static var benin: Locale.Region { Locale.Region("BJ") }

    @export(implementation)
    public static var bermuda: Locale.Region { Locale.Region("BM") }

    @export(implementation)
    public static var bhutan: Locale.Region { Locale.Region("BT") }

    @export(implementation)
    public static var bolivia: Locale.Region { Locale.Region("BO") }

    @export(implementation)
    public static var bosniaHerzegovina: Locale.Region { Locale.Region("BA") }

    @export(implementation)
    public static var botswana: Locale.Region { Locale.Region("BW") }

    @export(implementation)
    public static var bouvetIsland: Locale.Region { Locale.Region("BV") }

    @export(implementation)
    public static var brazil: Locale.Region { Locale.Region("BR") }

    @export(implementation)
    public static var britishVirginIslands: Locale.Region { Locale.Region("VG") }

    @export(implementation)
    public static var brunei: Locale.Region { Locale.Region("BN") }

    @export(implementation)
    public static var bulgaria: Locale.Region { Locale.Region("BG") }

    @export(implementation)
    public static var burkinaFaso: Locale.Region { Locale.Region("BF") }

    @export(implementation)
    public static var burundi: Locale.Region { Locale.Region("BI") }

    @export(implementation)
    public static var cambodia: Locale.Region { Locale.Region("KH") }

    @export(implementation)
    public static var cameroon: Locale.Region { Locale.Region("CM") }

    @export(implementation)
    public static var canada: Locale.Region { Locale.Region("CA") }

    @export(implementation)
    public static var canaryIslands: Locale.Region { Locale.Region("IC") }

    @export(implementation)
    public static var capeVerde: Locale.Region { Locale.Region("CV") }

    @export(implementation)
    public static var caribbeanNetherlands: Locale.Region { Locale.Region("BQ") }

    @export(implementation)
    public static var caymanIslands: Locale.Region { Locale.Region("KY") }

    @export(implementation)
    public static var centralAfricanRepublic: Locale.Region { Locale.Region("CF") }

    @export(implementation)
    public static var ceutaMelilla: Locale.Region { Locale.Region("EA") }

    @export(implementation)
    public static var chad: Locale.Region { Locale.Region("TD") }

    @export(implementation)
    public static var chagosArchipelago: Locale.Region { Locale.Region("IO") }

    @export(implementation)
    public static var chile: Locale.Region { Locale.Region("CL") }

    @export(implementation)
    public static var chinaMainland: Locale.Region { Locale.Region("CN") }

    @export(implementation)
    public static var christmasIsland: Locale.Region { Locale.Region("CX") }

    @export(implementation)
    public static var clippertonIsland: Locale.Region { Locale.Region("CP") }

    @export(implementation)
    public static var cocosIslands: Locale.Region { Locale.Region("CC") }

    @export(implementation)
    public static var colombia: Locale.Region { Locale.Region("CO") }

    @export(implementation)
    public static var comoros: Locale.Region { Locale.Region("KM") }

    @export(implementation)
    public static var congoBrazzaville: Locale.Region { Locale.Region("CG") }

    @export(implementation)
    public static var congoKinshasa: Locale.Region { Locale.Region("CD") }

    @export(implementation)
    public static var cookIslands: Locale.Region { Locale.Region("CK") }

    @export(implementation)
    public static var costaRica: Locale.Region { Locale.Region("CR") }

    @export(implementation)
    public static var côteDIvoire: Locale.Region { Locale.Region("CI") }

    @export(implementation)
    public static var croatia: Locale.Region { Locale.Region("HR") }

    @export(implementation)
    public static var cuba: Locale.Region { Locale.Region("CU") }

    @export(implementation)
    public static var curaçao: Locale.Region { Locale.Region("CW") }

    @export(implementation)
    public static var cyprus: Locale.Region { Locale.Region("CY") }

    @export(implementation)
    public static var czechia: Locale.Region { Locale.Region("CZ") }

    @export(implementation)
    public static var denmark: Locale.Region { Locale.Region("DK") }

    @export(implementation)
    public static var diegoGarcia: Locale.Region { Locale.Region("DG") }

    @export(implementation)
    public static var djibouti: Locale.Region { Locale.Region("DJ") }

    @export(implementation)
    public static var dominica: Locale.Region { Locale.Region("DM") }

    @export(implementation)
    public static var dominicanRepublic: Locale.Region { Locale.Region("DO") }

    @export(implementation)
    public static var ecuador: Locale.Region { Locale.Region("EC") }

    @export(implementation)
    public static var egypt: Locale.Region { Locale.Region("EG") }

    @export(implementation)
    public static var elSalvador: Locale.Region { Locale.Region("SV") }

    @export(implementation)
    public static var equatorialGuinea: Locale.Region { Locale.Region("GQ") }

    @export(implementation)
    public static var eritrea: Locale.Region { Locale.Region("ER") }

    @export(implementation)
    public static var estonia: Locale.Region { Locale.Region("EE") }

    @export(implementation)
    public static var eswatini: Locale.Region { Locale.Region("SZ") }

    @export(implementation)
    public static var ethiopia: Locale.Region { Locale.Region("ET") }

    @export(implementation)
    public static var falklandIslands: Locale.Region { Locale.Region("FK") }

    @export(implementation)
    public static var faroeIslands: Locale.Region { Locale.Region("FO") }

    @export(implementation)
    public static var fiji: Locale.Region { Locale.Region("FJ") }

    @export(implementation)
    public static var finland: Locale.Region { Locale.Region("FI") }

    @export(implementation)
    public static var france: Locale.Region { Locale.Region("FR") }

    @export(implementation)
    public static var frenchGuiana: Locale.Region { Locale.Region("GF") }

    @export(implementation)
    public static var frenchPolynesia: Locale.Region { Locale.Region("PF") }

    @export(implementation)
    public static var frenchSouthernTerritories: Locale.Region { Locale.Region("TF") }

    @export(implementation)
    public static var gabon: Locale.Region { Locale.Region("GA") }

    @export(implementation)
    public static var gambia: Locale.Region { Locale.Region("GM") }

    @export(implementation)
    public static var georgia: Locale.Region { Locale.Region("GE") }

    @export(implementation)
    public static var germany: Locale.Region { Locale.Region("DE") }

    @export(implementation)
    public static var ghana: Locale.Region { Locale.Region("GH") }

    @export(implementation)
    public static var gibraltar: Locale.Region { Locale.Region("GI") }

    @export(implementation)
    public static var greece: Locale.Region { Locale.Region("GR") }

    @export(implementation)
    public static var greenland: Locale.Region { Locale.Region("GL") }

    @export(implementation)
    public static var grenada: Locale.Region { Locale.Region("GD") }

    @export(implementation)
    public static var guadeloupe: Locale.Region { Locale.Region("GP") }

    @export(implementation)
    public static var guam: Locale.Region { Locale.Region("GU") }

    @export(implementation)
    public static var guatemala: Locale.Region { Locale.Region("GT") }

    @export(implementation)
    public static var guernsey: Locale.Region { Locale.Region("GG") }

    @export(implementation)
    public static var guinea: Locale.Region { Locale.Region("GN") }

    @export(implementation)
    public static var guineaBissau: Locale.Region { Locale.Region("GW") }

    @export(implementation)
    public static var guyana: Locale.Region { Locale.Region("GY") }

    @export(implementation)
    public static var haiti: Locale.Region { Locale.Region("HT") }

    @export(implementation)
    public static var heardMcdonaldIslands: Locale.Region { Locale.Region("HM") }

    @export(implementation)
    public static var honduras: Locale.Region { Locale.Region("HN") }

    @export(implementation)
    public static var hongKong: Locale.Region { Locale.Region("HK") }

    @export(implementation)
    public static var hungary: Locale.Region { Locale.Region("HU") }

    @export(implementation)
    public static var iceland: Locale.Region { Locale.Region("IS") }

    @export(implementation)
    public static var india: Locale.Region { Locale.Region("IN") }

    @export(implementation)
    public static var indonesia: Locale.Region { Locale.Region("ID") }

    @export(implementation)
    public static var iran: Locale.Region { Locale.Region("IR") }

    @export(implementation)
    public static var iraq: Locale.Region { Locale.Region("IQ") }

    @export(implementation)
    public static var ireland: Locale.Region { Locale.Region("IE") }

    @export(implementation)
    public static var isleOfMan: Locale.Region { Locale.Region("IM") }

    @export(implementation)
    public static var israel: Locale.Region { Locale.Region("IL") }

    @export(implementation)
    public static var italy: Locale.Region { Locale.Region("IT") }

    @export(implementation)
    public static var jamaica: Locale.Region { Locale.Region("JM") }

    @export(implementation)
    public static var japan: Locale.Region { Locale.Region("JP") }

    @export(implementation)
    public static var jersey: Locale.Region { Locale.Region("JE") }

    @export(implementation)
    public static var jordan: Locale.Region { Locale.Region("JO") }

    @export(implementation)
    public static var kazakhstan: Locale.Region { Locale.Region("KZ") }

    @export(implementation)
    public static var kenya: Locale.Region { Locale.Region("KE") }

    @export(implementation)
    public static var kiribati: Locale.Region { Locale.Region("KI") }

    @export(implementation)
    public static var kosovo: Locale.Region { Locale.Region("XK") }

    @export(implementation)
    public static var kuwait: Locale.Region { Locale.Region("KW") }

    @export(implementation)
    public static var kyrgyzstan: Locale.Region { Locale.Region("KG") }

    @export(implementation)
    public static var laos: Locale.Region { Locale.Region("LA") }

    @export(implementation)
    public static var latvia: Locale.Region { Locale.Region("LV") }

    @export(implementation)
    public static var lebanon: Locale.Region { Locale.Region("LB") }

    @export(implementation)
    public static var lesotho: Locale.Region { Locale.Region("LS") }

    @export(implementation)
    public static var liberia: Locale.Region { Locale.Region("LR") }

    @export(implementation)
    public static var libya: Locale.Region { Locale.Region("LY") }

    @export(implementation)
    public static var liechtenstein: Locale.Region { Locale.Region("LI") }

    @export(implementation)
    public static var lithuania: Locale.Region { Locale.Region("LT") }

    @export(implementation)
    public static var luxembourg: Locale.Region { Locale.Region("LU") }

    @export(implementation)
    public static var macao: Locale.Region { Locale.Region("MO") }

    @export(implementation)
    public static var madagascar: Locale.Region { Locale.Region("MG") }

    @export(implementation)
    public static var malawi: Locale.Region { Locale.Region("MW") }

    @export(implementation)
    public static var malaysia: Locale.Region { Locale.Region("MY") }

    @export(implementation)
    public static var maldives: Locale.Region { Locale.Region("MV") }

    @export(implementation)
    public static var mali: Locale.Region { Locale.Region("ML") }

    @export(implementation)
    public static var malta: Locale.Region { Locale.Region("MT") }

    @export(implementation)
    public static var marshallIslands: Locale.Region { Locale.Region("MH") }

    @export(implementation)
    public static var martinique: Locale.Region { Locale.Region("MQ") }

    @export(implementation)
    public static var mauritania: Locale.Region { Locale.Region("MR") }

    @export(implementation)
    public static var mauritius: Locale.Region { Locale.Region("MU") }

    @export(implementation)
    public static var mayotte: Locale.Region { Locale.Region("YT") }

    @export(implementation)
    public static var mexico: Locale.Region { Locale.Region("MX") }

    @export(implementation)
    public static var micronesia: Locale.Region { Locale.Region("FM") }

    @export(implementation)
    public static var moldova: Locale.Region { Locale.Region("MD") }

    @export(implementation)
    public static var monaco: Locale.Region { Locale.Region("MC") }

    @export(implementation)
    public static var mongolia: Locale.Region { Locale.Region("MN") }

    @export(implementation)
    public static var montenegro: Locale.Region { Locale.Region("ME") }

    @export(implementation)
    public static var montserrat: Locale.Region { Locale.Region("MS") }

    @export(implementation)
    public static var morocco: Locale.Region { Locale.Region("MA") }

    @export(implementation)
    public static var mozambique: Locale.Region { Locale.Region("MZ") }

    @export(implementation)
    public static var myanmar: Locale.Region { Locale.Region("MM") }

    @export(implementation)
    public static var namibia: Locale.Region { Locale.Region("NA") }

    @export(implementation)
    public static var nauru: Locale.Region { Locale.Region("NR") }

    @export(implementation)
    public static var nepal: Locale.Region { Locale.Region("NP") }

    @export(implementation)
    public static var netherlands: Locale.Region { Locale.Region("NL") }

    @export(implementation)
    public static var newCaledonia: Locale.Region { Locale.Region("NC") }

    @export(implementation)
    public static var newZealand: Locale.Region { Locale.Region("NZ") }

    @export(implementation)
    public static var nicaragua : Locale.Region { Locale.Region("NI") }

    @export(implementation)
    public static var niger: Locale.Region { Locale.Region("NE") }

    @export(implementation)
    public static var nigeria: Locale.Region { Locale.Region("NG") }

    @export(implementation)
    public static var niue: Locale.Region { Locale.Region("NU") }

    @export(implementation)
    public static var norfolkIsland: Locale.Region { Locale.Region("NF") }

    @export(implementation)
    public static var northernMarianaIslands: Locale.Region { Locale.Region("MP") }

    @export(implementation)
    public static var northMacedonia: Locale.Region { Locale.Region("MK") }

    @export(implementation)
    public static var norway: Locale.Region { Locale.Region("NO") }

    @export(implementation)
    public static var oman: Locale.Region { Locale.Region("OM") }

    @export(implementation)
    public static var pakistan: Locale.Region { Locale.Region("PK") }

    @export(implementation)
    public static var palau: Locale.Region { Locale.Region("PW") }

    @export(implementation)
    public static var palestinianTerritories: Locale.Region { Locale.Region("PS") }

    @export(implementation)
    public static var panama: Locale.Region { Locale.Region("PA") }

    @export(implementation)
    public static var papuaNewGuinea: Locale.Region { Locale.Region("PG") }

    @export(implementation)
    public static var paraguay: Locale.Region { Locale.Region("PY") }

    @export(implementation)
    public static var peru: Locale.Region { Locale.Region("PE") }

    @export(implementation)
    public static var philippines: Locale.Region { Locale.Region("PH") }

    @export(implementation)
    public static var pitcairnIslands: Locale.Region { Locale.Region("PN") }

    @export(implementation)
    public static var poland: Locale.Region { Locale.Region("PL") }

    @export(implementation)
    public static var portugal: Locale.Region { Locale.Region("PT") }

    @export(implementation)
    public static var puertoRico: Locale.Region { Locale.Region("PR") }

    @export(implementation)
    public static var qatar: Locale.Region { Locale.Region("QA") }

    @export(implementation)
    public static var réunion: Locale.Region { Locale.Region("RE") }

    @export(implementation)
    public static var romania: Locale.Region { Locale.Region("RO") }

    @export(implementation)
    public static var russia: Locale.Region { Locale.Region("RU") }

    @export(implementation)
    public static var rwanda: Locale.Region { Locale.Region("RW") }

    @export(implementation)
    public static var saintBarthélemy: Locale.Region { Locale.Region("BL") }

    @export(implementation)
    public static var saintHelena: Locale.Region { Locale.Region("SH") }

    @export(implementation)
    public static var saintKittsNevis: Locale.Region { Locale.Region("KN") }

    @export(implementation)
    public static var saintLucia: Locale.Region { Locale.Region("LC") }

    @export(implementation)
    public static var saintMartin: Locale.Region { Locale.Region("MF") }

    @export(implementation)
    public static var saintPierreMiquelon: Locale.Region { Locale.Region("PM") }

    @export(implementation)
    public static var saintVincentGrenadines: Locale.Region { Locale.Region("VC") }

    @export(implementation)
    public static var samoa: Locale.Region { Locale.Region("WS") }

    @export(implementation)
    public static var sanMarino: Locale.Region { Locale.Region("SM") }

    @export(implementation)
    public static var sãoToméPríncipe: Locale.Region { Locale.Region("ST") }

    @export(implementation)
    public static var saudiArabia: Locale.Region { Locale.Region("SA") }

    @export(implementation)
    public static var senegal: Locale.Region { Locale.Region("SN") }

    @export(implementation)
    public static var serbia: Locale.Region { Locale.Region("RS") }

    @export(implementation)
    public static var seychelles: Locale.Region { Locale.Region("SC") }

    @export(implementation)
    public static var sierraLeone: Locale.Region { Locale.Region("SL") }

    @export(implementation)
    public static var singapore: Locale.Region { Locale.Region("SG") }

    @export(implementation)
    public static var sintMaarten: Locale.Region { Locale.Region("SX") }

    @export(implementation)
    public static var slovakia: Locale.Region { Locale.Region("SK") }

    @export(implementation)
    public static var slovenia: Locale.Region { Locale.Region("SI") }

    @export(implementation)
    public static var solomonIslands: Locale.Region { Locale.Region("SB") }

    @export(implementation)
    public static var somalia: Locale.Region { Locale.Region("SO") }

    @export(implementation)
    public static var southAfrica: Locale.Region { Locale.Region("ZA") }

    @export(implementation)
    public static var southGeorgiaSouthSandwichIslands: Locale.Region { Locale.Region("GS") }

    @export(implementation)
    public static var southKorea: Locale.Region { Locale.Region("KR") }

    @export(implementation)
    public static var southSudan: Locale.Region { Locale.Region("SS") }

    @export(implementation)
    public static var spain: Locale.Region { Locale.Region("ES") }

    @export(implementation)
    public static var sriLanka: Locale.Region { Locale.Region("LK") }

    @export(implementation)
    public static var suriname: Locale.Region { Locale.Region("SR") }

    @export(implementation)
    public static var svalbardJanMayen: Locale.Region { Locale.Region("SJ") }

    @export(implementation)
    public static var sweden: Locale.Region { Locale.Region("SE") }

    @export(implementation)
    public static var switzerland: Locale.Region { Locale.Region("CH") }

    @export(implementation)
    public static var taiwan: Locale.Region { Locale.Region("TW") }

    @export(implementation)
    public static var tajikistan: Locale.Region { Locale.Region("TJ") }

    @export(implementation)
    public static var tanzania: Locale.Region { Locale.Region("TZ") }

    @export(implementation)
    public static var thailand: Locale.Region { Locale.Region("TH") }

    @export(implementation)
    public static var timorLeste: Locale.Region { Locale.Region("TL") }

    @export(implementation)
    public static var togo: Locale.Region { Locale.Region("TG") }

    @export(implementation)
    public static var tokelau: Locale.Region { Locale.Region("TK") }

    @export(implementation)
    public static var tonga: Locale.Region { Locale.Region("TO") }

    @export(implementation)
    public static var trinidadTobago: Locale.Region { Locale.Region("TT") }

    @export(implementation)
    public static var tristanDaCunha: Locale.Region { Locale.Region("TA") }

    @export(implementation)
    public static var tunisia: Locale.Region { Locale.Region("TN") }

    @export(implementation)
    public static var turkey: Locale.Region { Locale.Region("TR") }

    @export(implementation)
    public static var turkmenistan: Locale.Region { Locale.Region("TM") }

    @export(implementation)
    public static var turksCaicosIslands: Locale.Region { Locale.Region("TC") }

    @export(implementation)
    public static var tuvalu: Locale.Region { Locale.Region("TV") }

    @export(implementation)
    public static var uganda: Locale.Region { Locale.Region("UG") }

    @export(implementation)
    public static var ukraine: Locale.Region { Locale.Region("UA") }

    @export(implementation)
    public static var unitedArabEmirates: Locale.Region { Locale.Region("AE") }

    @export(implementation)
    public static var unitedKingdom: Locale.Region { Locale.Region("GB") }

    @export(implementation)
    public static var unitedStates: Locale.Region { Locale.Region("US") }

    @export(implementation)
    public static var unitedStatesOutlyingIslands: Locale.Region { Locale.Region("UM") }

    @export(implementation)
    public static var unitedStatesVirginIslands: Locale.Region { Locale.Region("VI") }

    @export(implementation)
    public static var uruguay: Locale.Region { Locale.Region("UY") }

    @export(implementation)
    public static var uzbekistan: Locale.Region { Locale.Region("UZ") }

    @export(implementation)
    public static var vanuatu: Locale.Region { Locale.Region("VU") }

    @export(implementation)
    public static var vaticanCity: Locale.Region { Locale.Region("VA") }

    @export(implementation)
    public static var venezuela: Locale.Region { Locale.Region("VE") }

    @export(implementation)
    public static var vietnam: Locale.Region { Locale.Region("VN") }

    @export(implementation)
    public static var wallisFutuna: Locale.Region { Locale.Region("WF") }

    @export(implementation)
    public static var westernSahara: Locale.Region { Locale.Region("EH") }

    @export(implementation)
    public static var yemen: Locale.Region { Locale.Region("YE") }

    @export(implementation)
    public static var zambia: Locale.Region { Locale.Region("ZM") }

    @export(implementation)
    public static var zimbabwe: Locale.Region { Locale.Region("ZW") }

    // MARK: - Region codes for specifying language variants

    @export(implementation)
    public static var world: Locale.Region { Locale.Region("001") }

    @export(implementation)
    public static var latinAmerica: Locale.Region { Locale.Region("419") }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Script {
    @export(implementation)
    public static var adlam: Locale.Script { Locale.Script("Adlm") }

    @export(implementation)
    public static var arabic: Locale.Script { Locale.Script("Arab") }

    @export(implementation)
    public static var arabicNastaliq: Locale.Script { Locale.Script("Aran") }

    @export(implementation)
    public static var armenian: Locale.Script { Locale.Script("Armn") }

    @export(implementation)
    public static var bangla: Locale.Script { Locale.Script("Beng") }

    @export(implementation)
    public static var cherokee: Locale.Script { Locale.Script("Cher") }

    @export(implementation)
    public static var cyrillic: Locale.Script { Locale.Script("Cyrl") }

    @export(implementation)
    public static var devanagari: Locale.Script { Locale.Script("Deva") }

    @export(implementation)
    public static var ethiopic: Locale.Script { Locale.Script("Ethi") }

    @export(implementation)
    public static var georgian: Locale.Script { Locale.Script("Geor") }

    @export(implementation)
    public static var greek: Locale.Script { Locale.Script("Grek") }

    @export(implementation)
    public static var gujarati: Locale.Script { Locale.Script("Gujr") }

    @export(implementation)
    public static var gurmukhi: Locale.Script { Locale.Script("Guru") }

    @export(implementation)
    public static var hanifiRohingya: Locale.Script { Locale.Script("Rohg") }

    @export(implementation)
    public static var hanSimplified: Locale.Script { Locale.Script("Hans") }

    @export(implementation)
    public static var hanTraditional: Locale.Script { Locale.Script("Hant") }

    @export(implementation)
    public static var hebrew: Locale.Script { Locale.Script("Hebr") }

    @export(implementation)
    public static var hiragana: Locale.Script { Locale.Script("Hira") }

    @export(implementation)
    public static var japanese: Locale.Script { Locale.Script("Jpan") }

    @export(implementation)
    public static var kannada: Locale.Script { Locale.Script("Knda") }

    @export(implementation)
    public static var katakana: Locale.Script { Locale.Script("Kana") }

    @export(implementation)
    public static var khmer: Locale.Script { Locale.Script("Khmr") }

    @export(implementation)
    public static var korean: Locale.Script { Locale.Script("Kore") }

    @export(implementation)
    public static var lao: Locale.Script { Locale.Script("Laoo") }

    @export(implementation)
    public static var latin: Locale.Script { Locale.Script("Latn") }

    @export(implementation)
    public static var malayalam: Locale.Script { Locale.Script("Mlym") }

    @export(implementation)
    public static var meiteiMayek: Locale.Script { Locale.Script("Mtei") }

    @export(implementation)
    public static var myanmar: Locale.Script { Locale.Script("Mymr") }

    @export(implementation)
    public static var odia: Locale.Script { Locale.Script("Orya") }

    @export(implementation)
    public static var olChiki: Locale.Script { Locale.Script("Olck") }

    @export(implementation)
    public static var sinhala: Locale.Script { Locale.Script("Sinh") }

    @export(implementation)
    public static var syriac: Locale.Script { Locale.Script("Syrc") }

    @export(implementation)
    public static var tamil: Locale.Script { Locale.Script("Taml") }

    @export(implementation)
    public static var telugu: Locale.Script { Locale.Script("Telu") }

    @export(implementation)
    public static var thaana: Locale.Script { Locale.Script("Thaa") }

    @export(implementation)
    public static var thai: Locale.Script { Locale.Script("Thai") }

    @export(implementation)
    public static var tibetan: Locale.Script { Locale.Script("Tibt") }
}

