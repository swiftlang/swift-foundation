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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal import _FoundationICU

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Components {
    // Returns an ICU-style identifier like "de_DE@calendar=gregorian"
    internal var icuIdentifier: String {
        var keywords: [ICULegacyKey: String] = [:]
        if let id = calendar?.cldrIdentifier { keywords[Calendar.Identifier.legacyKeywordKey] = id }
        if let id = collation?._normalizedIdentifier { keywords[Locale.Collation.legacyKeywordKey] = id }
        if let id = currency?._normalizedIdentifier { keywords[Locale.Currency.legacyKeywordKey] = id }
        if let id = numberingSystem?._normalizedIdentifier { keywords[Locale.NumberingSystem.legacyKeywordKey] = id }
        if let id = firstDayOfWeek?.rawValue { keywords[Locale.Weekday.legacyKeywordKey] = id }
        if let id = hourCycle?.rawValue { keywords[Locale.HourCycle.legacyKeywordKey] = id }
        if let id = measurementSystem?._normalizedIdentifier { keywords[Locale.MeasurementSystem.legacyKeywordKey] = id }
        // No need for redundant region keyword
        if let region = region, region != languageComponents.region {
            // rg keyword value is actually a subdivision code
            keywords[Locale.Region.legacyKeywordKey] = Locale.Subdivision.subdivision(for: region)._normalizedIdentifier
        }
        if let id = subdivision?._normalizedIdentifier { keywords[Locale.Subdivision.legacyKeywordKey] = id }
        if let id = timeZone?.identifier { keywords[TimeZone.legacyKeywordKey] = id }
        if let id = variant?._normalizedIdentifier { keywords[Locale.Variant.legacyKeywordKey] = id }

        var locID = languageComponents.identifier
        for (key, val) in keywords {
            // This uses legacy key-value pairs, like "collation=phonebook" instead of "-cu-phonebk", so be sure that the above values are `legacyKeywordKey`
            // See Locale.Components.legacyKey(forKey:) for more info on performance costs
            locID = Locale.identifierWithKeywordValue(locID, key: key, value: val)
        }
        return locID
    }
    
    /// - Parameter identifier: Unicode language identifier such as "en-u-nu-thai-ca-buddhist-kk-true"
    public init(identifier: String) {
        let languageComponents = Locale.Language.Components(identifier: identifier)
        self.init(languageCode: languageComponents.languageCode, script: languageComponents.script, languageRegion: languageComponents.region)

        let s = _withFixedCharBuffer { buffer, size, status in
            return uloc_getVariant(identifier, buffer, size, &status)
        }
        if let s {
            variant = Locale.Variant(s)
        }

        var status = U_ZERO_ERROR
        let uenum = uloc_openKeywords(identifier, &status)
        guard status.isSuccess, let uenum else { return }

        let enumator = ICU.Enumerator(enumerator: uenum)
        for key in enumator.elements {
            guard let legacyKey = Locale.legacyKey(forKey: key) else {
                continue
            }

            guard let value = Locale.keywordValue(identifier: identifier, key: legacyKey) else {
                continue
            }

            switch legacyKey {
            case Calendar.Identifier.legacyKeywordKey:
                calendar = Calendar.Identifier(identifierString: value)
            case Locale.Collation.legacyKeywordKey:
                collation = Locale.Collation(value)
            case Locale.Currency.legacyKeywordKey:
                currency = Locale.Currency(value)
            case Locale.NumberingSystem.legacyKeywordKey:
                numberingSystem = Locale.NumberingSystem(value)
            case Locale.Weekday.legacyKeywordKey:
                firstDayOfWeek = Locale.Weekday(rawValue: value)
            case Locale.HourCycle.legacyKeywordKey:
                hourCycle = Locale.HourCycle(rawValue: value)
            case Locale.MeasurementSystem.legacyKeywordKey:
                if value == "imperial" {
                    // Legacy alias for "uksystem"
                    measurementSystem = .uk
                } else {
                    measurementSystem = Locale.MeasurementSystem(value)
                }
            case Locale.Region.legacyKeywordKey:
                if value.count > 2 {
                    // A valid `regionString` is a unicode subdivision id that consists of a region subtag suffixed either by "zzzz" ("uszzzz") for whole region, or by a subdivision suffix for a partial subdivision ("usca").
                    // Retrieve the region part ("us").
                    region = Locale.Region(String(value.prefix(2).uppercased()))
                }
            case Locale.Subdivision.legacyKeywordKey:
                subdivision = Locale.Subdivision(value)
            case TimeZone.legacyKeywordKey:
                timeZone = TimeZone(identifier: value)
            default:
                break
            }
        }
    }

    /// Creates a `Locale.Components` with the identifier of the specified `locale`.
    /// - Parameter locale: The locale whose identifier is used to create the component. If `Locale.current` or `Locale.autoupdatingCurrent` is specified, the created `Locale.Components` will contain user's preferred values as set in the system settings if available.
    public init(locale: Locale) {
        self = .init(identifier: locale.identifier)

        // Special case: the current locale may have user preferences override. These values should be reflected in the created Locale.Components too.
        applyPreferencesOverride(locale)
    }

    private mutating func applyPreferencesOverride(_ locale: Locale) {
        if hourCycle == nil, let hc = locale.forceHourCycle {
            hourCycle = hc
        }
        
        if measurementSystem == nil, let ms = locale.forceMeasurementSystem {
            measurementSystem = ms
        }

        if firstDayOfWeek == nil, let weekday = locale.forceFirstWeekday(locale._calendarIdentifier) {
            firstDayOfWeek = weekday
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.LanguageCode {
    /// Returns the ISO code of the given identifier type.
    /// Returns nil if the language isn't a valid ISO language,
    /// or if the specified identifier type isn't available to
    /// the language.
    public func identifier(_ type: IdentifierType) -> String? {
        switch type {
        case .alpha2:
            var alpha2: String?
            let tmp = _withFixedCharBuffer { buffer, size, status in
                return uloc_getLanguage(_normalizedIdentifier, buffer, size, &status)
            }
            if let tmp, Locale.LanguageCode._isoLanguageCodeStrings.contains(tmp) {
                alpha2 = tmp
            }
            return alpha2
        case .alpha3:
            var alpha3: String?
            let str = _withStringAsCString(_normalizedIdentifier) {
                uloc_getISO3Language($0)
            }
            if let str, !str.isEmpty {
                alpha3 = str
            }
            return alpha3
        }
    }
    
    /// Returns if the language is an ISO-639 language
    public var isISOLanguage: Bool {
        if Locale.LanguageCode._isoLanguageCodeStrings.contains(_normalizedIdentifier) {
            return true
        } else {
            return identifier(.alpha2) != nil
        }
    }

    /// Returns a list of `Locale` language codes that are two-letter language codes defined in ISO 639 and two-letter codes without a two-letter equivalent
    public static var isoLanguageCodes: [Locale.LanguageCode] {
        return _isoLanguageCodeStrings.map { Locale.LanguageCode($0) }
    }
    
    // This is sorted
    internal static let _isoLanguageCodeStrings: [String] = {
        var result: [String] = []
        let langs = uloc_getISOLanguages()
        guard var langs else { return [] }
        while let p = langs.pointee {
            let str = String(cString: p)
            result.append(str)
            langs = langs.advanced(by: 1)
        }

        return result
    }()
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Script {
    /// Returns if the script is an ISO 15924 script
    public var isISOScript: Bool {
        withUnsafeTemporaryAllocation(of: UScriptCode.self, capacity: Int(USCRIPT_CODE_LIMIT.rawValue)) { buffer in
            var status = U_ZERO_ERROR
            let len = uscript_getCode(_normalizedIdentifier, buffer.baseAddress!, USCRIPT_CODE_LIMIT.rawValue, &status)
            return status.isSuccess && len > 0 && buffer[0] != USCRIPT_INVALID_CODE
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Region {
    public var isISORegion: Bool {
        var status = U_ZERO_ERROR
        let region = uregion_getRegionFromCode(identifier, &status)
        return status.isSuccess && region != nil
    }

    /// Returns all the sub-regions of the region
    public var subRegions : [Locale.Region] {
        var status = U_ZERO_ERROR
        let icuRegion = uregion_getRegionFromCode(identifier, &status)
        guard status.isSuccess, let icuRegion else {
            return []
        }

        let values = uregion_getContainedRegions(icuRegion, &status)
        guard status.isSuccess, let values else {
            return []
        }

        let e = ICU.Enumerator(enumerator: values)
        return e.elements.map { Locale.Region($0) }
    }

    /// Returns the region within which the region is contained, e.g. for `US`, returns `Northern America`
    public var containingRegion: Locale.Region? {
        var status = U_ZERO_ERROR
        let icuRegion = uregion_getRegionFromCode(identifier, &status)
        guard status.isSuccess, let icuRegion else {
            return nil
        }

        guard let containingRegion = uregion_getContainingRegion(icuRegion) else {
            return nil
        }

        guard let code = String(validatingUTF8: uregion_getRegionCode(containingRegion)) else {
            return nil
        }

        return Locale.Region(code)
    }

    /// Returns the continent of the region. Returns `nil` if the continent cannot be determined, such as when the region isn't an ISO region
    public var continent: Locale.Region? {
        var status = U_ZERO_ERROR
        let icuRegion = uregion_getRegionFromCode(identifier, &status)

        guard status.isSuccess, let icuRegion else {
            return nil
        }

        guard let containingContinent = uregion_getContainingRegionOfType(icuRegion, URGN_CONTINENT) else {
            return nil
        }

        guard let code = String(validatingUTF8: uregion_getRegionCode(containingContinent)) else {
            return nil
        }

        return Locale.Region(code)
    }

    /// Returns a list of regions of a specified type defined by ISO
    public static var isoRegions: [Locale.Region] {
        _isoRegionCodes.map { Locale.Region($0) }
    }

    /// Used for deprecated ISO Country Code
    internal static let isoCountries: [String] = {
        var result: [String] = []
        let langs = uloc_getISOCountries()
        guard var langs else { return [] }
        while let p = langs.pointee {
            let str = String(cString: p)
            result.append(str)
            langs = langs.advanced(by: 1)
        }
        return result
    }()

    internal static let _isoRegionCodes: [String] = {
        var status = U_ZERO_ERROR
        let types = [URGN_WORLD, URGN_CONTINENT, URGN_SUBCONTINENT, URGN_TERRITORY]
        var codes: [String] = []
        for t in types {
            status = U_ZERO_ERROR
            let values = uregion_getAvailable(t, &status)
            if status.isSuccess, let values {
                let e = ICU.Enumerator(enumerator: values)
                codes.append(contentsOf: e.elements)
            }
        }
        return codes
    }()
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Collation {
    /// A list of available collations on the system.
    public static var availableCollations: [Locale.Collation] {
        var status = U_ZERO_ERROR
        let values = ucol_getKeywordValues("collation", &status)
        guard let values, status.isSuccess else {
            return []
        }

        return ICU.Enumerator(enumerator: values).elements.map { Locale.Collation($0) }
    }

    /// A list of available collations for the specified `language` in the order that it is most likely to make a difference.
    public static func availableCollations(for language: Locale.Language) -> [Locale.Collation] {
        var status = U_ZERO_ERROR
        let values = ucol_getKeywordValuesForLocale("collation", language.components.identifier, UBool.true, &status)
        guard let values, status.isSuccess else {
            return []
        }

        return ICU.Enumerator(enumerator: values).elements.map { Locale.Collation($0) }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Currency {
    public var isISOCurrency: Bool {
        identifier.withCString(encodedAs: UTF16.self) {
            ucurr_getNumericCode($0) != 0
        }
    }

    /// Represents an unknown currency, used when no currency is involved in a transaction
    public static let unknown = Locale.Currency("xxx")

    /// Returns a list of `Locale` currency codes defined in ISO-4217
    public static var isoCurrencies: [Locale.Currency] {
        var status = U_ZERO_ERROR
        let values = ucurr_openISOCurrencies(UInt32(UCURR_ALL.rawValue), &status)
        guard status.isSuccess, let values else { return [] }
        let e = ICU.Enumerator(enumerator: values)
        return e.elements.map { Locale.Currency($0) }
    }

    /// For `Locale.commonISOCurrencyCodes`
    internal static var commonISOCurrencies: [String] {
        var status = U_ZERO_ERROR
        let values = ucurr_openISOCurrencies(UInt32(UCURR_COMMON.rawValue | UCURR_NON_DEPRECATED.rawValue), &status)
        guard status.isSuccess, let values else { return [] }
        let e = ICU.Enumerator(enumerator: values)
        return e.elements.map { $0 }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.NumberingSystem {
    /// A list of available numbering systems on the system.
    public static var availableNumberingSystems: [Locale.NumberingSystem] {
        var status = U_ZERO_ERROR
        let values = unumsys_openAvailableNames(&status)
        guard let values, status.isSuccess else { return [] }

        let e = ICU.Enumerator(enumerator: values)
        return e.elements.map { Locale.NumberingSystem($0) }
    }

    internal static func defaultNumberingSystem(for localeId: String) -> Locale.NumberingSystem? {
        var comps = Locale.Components(identifier: localeId)
        comps.numberingSystem = Locale.NumberingSystem("default")
        var status = U_ZERO_ERROR
        let sys = unumsys_open(comps.icuIdentifier, &status)
        defer { unumsys_close(sys) }
        guard status.isSuccess else { return nil }
        guard let name = unumsys_getName(sys) else { return nil }
        return Locale.NumberingSystem(String(cString: name))
    }

    internal static func validNumberingSystems(for localeId: String) -> [Locale.NumberingSystem] {
        // The result is ordered
        var result: [Locale.NumberingSystem] = []
        var components = Locale.Components(identifier: localeId)

        // 1. If there is an explicitly defined override numbering system, add it first to the list.
        if let numbers = components.numberingSystem {
            result.append(numbers)
        }

        // 2. Query ICU for additional supported numbering systems
        let queryList: [String]
        // For Chinese & Thai, although there is a traditional numbering system, it is not one that users will expect to use as a numbering system in the system. (cf. <rdar://problem/19742123&20068835>)
        if let languageCode = components.languageComponents.languageCode, !(languageCode == .thai || languageCode == .chinese || languageCode.identifier == "wuu" || languageCode == .cantonese) {
            queryList = ["default", "native", "traditional", "finance"]
        } else {
            queryList = ["default"]
        }

        for q in queryList {
            components.numberingSystem = .init(q)
            let localeIDWithNumbers = components.icuIdentifier

            var status = U_ZERO_ERROR
            let numberingSystem = unumsys_open(localeIDWithNumbers, &status)
            defer { unumsys_close(numberingSystem) }
            guard status.isSuccess else {
                continue
            }

            // We do not support numbering systems that are algorithmic (like the traditional ones for Hebrew, etc.) and ones that are not base 10.
            guard !unumsys_isAlgorithmic(numberingSystem).boolValue && unumsys_getRadix(numberingSystem) == 10 else {
                continue
            }

            guard let name = unumsys_getName(numberingSystem) else {
                continue
            }

            let ns = Locale.NumberingSystem(String(cString: name))
            if !result.contains(ns) {
                result.append(ns)
            }
        }

         // 3. Add `latn` (if required) which we support that for all languages.
        let latn = Locale.NumberingSystem("latn")
        if !result.contains(latn) {
            result.append(latn)
        }

        return result
    }
    
    /// Create a `NumberingSystem` from a complete Locale identifier, or nil if does not explicitly specify one.
    internal init?(localeIdentifierIfSpecified localeIdentifier: String) {
        // Just verify it has a value at all, but pass the whole identifier to `NumberingSystem`
        guard let _ = Locale.keywordValue(identifier: localeIdentifier, key: Locale.NumberingSystem.legacyKeywordKey) else {
            return nil
        }

        self = Locale.NumberingSystem(localeIdentifier: localeIdentifier)
    }
    
    internal init(localeIdentifier: String) {
        var status = U_ZERO_ERROR
        let numberingSystem = unumsys_open(localeIdentifier, &status)
        defer { unumsys_close(numberingSystem) }
        if let numberingSystem, status.isSuccess {
            self.init(String(cString: unumsys_getName(numberingSystem)))
        } else {
            self = .latin
        }
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Language {
    /// Ordering of lines within a page.
    /// For example, top-to-bottom for English; right-to-left for Mongolian in the Mongolian Script
    /// - note: See also `characterDirection`.
    public var lineLayoutDirection: Locale.LanguageDirection {
        var status = U_ZERO_ERROR
        let orientation = uloc_getLineOrientation(components.identifier, &status)
        guard status.isSuccess else {
            return .unknown
        }

        return Locale.LanguageDirection(layoutType: orientation)
    }

    /// Ordering of characters within a line.
    /// For example, left-to-right for English; top-to-bottom for Mongolian in the Mongolian Script
    public var characterDirection: Locale.LanguageDirection {
        var status = U_ZERO_ERROR
        let orientation = uloc_getCharacterOrientation(components.identifier, &status)
        guard status.isSuccess else {
            return .unknown
        }

        return Locale.LanguageDirection(layoutType: orientation)
    }

    // MARK: - Getting information

    /// Returns the parent language of a language. For example, the parent language of `"en_US_POSIX"` is `"en_US"`
    /// Returns nil if the parent language cannot be determined
    public var parent: Locale.Language? {
        let parentID = _withFixedCharBuffer { buffer, size, status in
            return ualoc_getAppleParent(components.identifier, buffer, size, &status)
        }

        if let parentID {
            let comp = Locale.Language.Components(identifier: parentID)
            return Locale.Language(components: comp)
        } else {
            return nil
        }

    }
    
    public func hasCommonParent(with language: Locale.Language) -> Bool {
        self.parent == language.parent
    }

    /// Returns if `self` and the specified `language` are equal after expanding missing components
    /// For example, `en`, `en-Latn`, `en-US`, and `en-Latn-US` are equivalent
    public func isEquivalent(to language: Locale.Language) -> Bool {
        return self.maximalIdentifier == language.maximalIdentifier
    }

    // MARK: - identifiers

    /// Creates a `Language` with the language identifier
    /// - Parameter identifier: Unicode language identifier, such as "en-US", "es-419", "zh-Hant-TW"
    public init(identifier: String) {
        self = .init(components: Components(identifier: identifier))
    }

    /// Returns a BCP-47 identifier in a minimalist form. Script and region may be omitted. For example, "zh-TW", "en"
    public var minimalIdentifier : String {
        let componentsIdentifier = components.identifier

        guard !componentsIdentifier.isEmpty else {
            // Just return "". Nothing to reduce.
            return componentsIdentifier
        }

        let localeIDWithLikelySubtags = _withFixedCharBuffer { buffer, size, status in
            return uloc_minimizeSubtags(componentsIdentifier, buffer, size, &status)
        }

        guard let localeIDWithLikelySubtags else { return componentsIdentifier }

        let tag = _withFixedCharBuffer { buffer, Size, status in
            return uloc_toLanguageTag(localeIDWithLikelySubtags, buffer, Size, UBool.false, &status)
        }

        guard let tag else { return componentsIdentifier }

        return tag
    }

    /// Returns a BCP-47 identifier that always includes the script: "zh-Hant-TW", "en-Latn-US"
    public var maximalIdentifier : String {
        let id = components.identifier
        guard !id.isEmpty else {
            // Just return "" instead of trying to fill it up
            return id
        }

        let localeIDWithLikelySubtags = _withFixedCharBuffer { buffer, size, status in
            return uloc_addLikelySubtags(id, buffer, size, &status)
        }

        guard let localeIDWithLikelySubtags else { return id }

        let tag = _withFixedCharBuffer { buffer, size, status in
            return uloc_toLanguageTag(localeIDWithLikelySubtags, buffer, size, UBool.false, &status)
        }

        guard let tag else { return id }

        return tag
    }
    
    // MARK: -

    /// The language code of the language. Returns nil if it cannot be determined
    public var languageCode: Locale.LanguageCode? {
        var result: Locale.LanguageCode?
        if let lang = components.languageCode {
            result = lang
        } else {
            result = _withFixedCharBuffer { buffer, size, status in
                uloc_getLanguage(components.identifier, buffer, size, &status)
            }.map { Locale.LanguageCode($0) }
        }
        return result
    }

    /// The script of the language. Returns nil if it cannot be determined
    public var script: Locale.Script? {
        var result: Locale.Script?
        if let script = components.script {
            result = script
        } else {
            result = _withFixedCharBuffer { buffer, size, status in
                // Use `maximalIdentifier` to ensure that script code is present in the identifier.
                uloc_getScript(maximalIdentifier, buffer, size, &status)
            }.map { Locale.Script($0) }
        }
        return result
    }

    /// The region of the language. Returns nil if it cannot be determined
    public var region: Locale.Region? {
        var result: Locale.Region?
        if let script = components.region {
            result = script
        } else {
            result = _withFixedCharBuffer { buffer, size, status in
                uloc_getCountry(components.identifier, buffer, size, &status)
            }.map { Locale.Region($0) }
        }
        return result
    }
}

@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
extension Locale.Language.Components {
    /// - Parameter identifier: Unicode language identifier, such as "en-US", "es-419", "zh-Hant-TW"
    public init(identifier: String) {
        let languageCode = _withFixedCharBuffer { buffer, size, status in
            uloc_getLanguage(identifier, buffer, size, &status)
        }
        let scriptCode = _withFixedCharBuffer { buffer, size, status in
            uloc_getScript(identifier, buffer, size, &status)
        }
        let countryCode = _withFixedCharBuffer { buffer, size, status in
            uloc_getCountry(identifier, buffer, size, &status)
        }

        let lc: Locale.LanguageCode? = if let languageCode {
            Locale.LanguageCode(languageCode)
        } else {
            nil
        }
        
        let sc: Locale.Script? = if let scriptCode {
            Locale.Script(scriptCode)
        } else {
            nil
        }
        
        let rc: Locale.Region? = if let countryCode {
            Locale.Region(countryCode)
        } else {
            nil
        }
        
        self = Locale.Language.Components(languageCode: lc, script: sc, region: rc)
    }
    
    public init(language: Locale.Language) {
        self = Locale.Language.Components(languageCode: language.languageCode, script: language.script, region: language.region)
    }
}

extension Locale.LanguageDirection {
    init(layoutType: ULayoutType) {
        switch layoutType {
        case ULOC_LAYOUT_UNKNOWN:
            self = .unknown
        case ULOC_LAYOUT_LTR:
            self = .leftToRight
        case ULOC_LAYOUT_RTL:
            self = .rightToLeft
        case ULOC_LAYOUT_TTB:
            self = .topToBottom
        case ULOC_LAYOUT_BTT:
            self = .bottomToTop
        default:
            self = .unknown
        }
    }
}
