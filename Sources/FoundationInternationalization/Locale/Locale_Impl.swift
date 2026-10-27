//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal final class _LocaleImpl : _LocaleProtocol, Sendable {
    /// The identifier that `Locale.identifier` returns. It can be a BCP 47 language tag or an ICU identifier.
    let _identifier: String
    /// The ICU form of the identifier, for example `en_US@calendar=chinese`, and the ranges of its parts.
    let _canonical: Locale.CanonicalizedIdentifier
    let _prefs: LocalePreferences?
    /// The variant of the components that created this locale. The identifier has it as the "va" keyword, not as a variant.
    let _componentsVariant: Locale.Variant?

    // FIXME: Temporary stub to forward unimplemented functions to _LocaleICU. Remove it when it's no longer used.
    let _icu: _LocaleICU
    
    required init(identifier: String, prefs: LocalePreferences? = nil) {
        _icu = _LocaleICU(identifier: identifier, prefs: prefs)
        // For historical reasons, store the canonical identifier, not the raw identifier. `_icu` has already canonicalized it.
        _identifier = _icu.identifier
        _prefs = prefs
        _componentsVariant = nil
        _canonical = Locale.CanonicalizedIdentifier(canonicalizing: identifier)
    }
    
    required init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        // FIXME: Implement bundle matching here with user preferences
        _icu = _LocaleICU(name: name, prefs: prefs, disableBundleMatching: disableBundleMatching)
        _identifier = _icu.identifier
        _prefs = prefs
        _componentsVariant = nil
        _canonical = Locale.CanonicalizedIdentifier(canonicalizing: _icu.identifier)
    }
    
    required init(components: Locale.Components) {
        _icu = _LocaleICU(components: components)
        _identifier = _icu.identifier
        _canonical = Locale.CanonicalizedIdentifier(components: components)
        _prefs = nil
        _componentsVariant = components.variant
    }

    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
        _icu.copy(newCalendarIdentifier: identifier)
    }
    
    var debugDescription: String {
        "Fixed \(_canonical.identifier)"
    }
    
    var identifier: String {
        _identifier
    }
    
    func identifierDisplayName(for value: String) -> String? {
        _icu.identifierDisplayName(for: value)
    }
    
    func languageCodeDisplayName(for value: String) -> String? {
        _icu.languageCodeDisplayName(for: value)
    }
    
    func countryCodeDisplayName(for regionCode: String) -> String? {
        _icu.countryCodeDisplayName(for: regionCode)
    }
    
    func scriptCodeDisplayName(for scriptCode: String) -> String? {
        _icu.scriptCodeDisplayName(for: scriptCode)
    }
    
    func variantCodeDisplayName(for variantCode: String) -> String? {
        _icu.variantCodeDisplayName(for: variantCode)
    }
    
    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String? {
        _icu.calendarIdentifierDisplayName(for: value)
    }
    
    func currencyCodeDisplayName(for value: String) -> String? {
        _icu.currencyCodeDisplayName(for: value)
    }
    
    func currencySymbolDisplayName(for value: String) -> String? {
        _icu.currencySymbolDisplayName(for: value)
    }
    
    func collationIdentifierDisplayName(for value: String) -> String? {
        _icu.collationIdentifierDisplayName(for: value)
    }
    
    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String? {
        _icu.collatorIdentifierDisplayName(for: collatorIdentifier)
    }
    
    var languageCode: String? {
        _canonical.languageCode
    }
    
    var scriptCode: String? {
        _canonical.scriptCode
    }
    
    var variantCode: String? {
        _componentsVariant?.identifier ?? _canonical.variantCode
    }
    
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? {
        _icu.exemplarCharacterSet
    }
#endif
    
    var calendar: Calendar {
        let calendarIdentifier = self.calendarIdentifier
        var calendar = Calendar(identifier: calendarIdentifier)

        if let prefs {
            let firstWeekday = prefs.firstWeekday?[calendarIdentifier]
            let minDaysInFirstWeek = prefs.minDaysInFirstWeek?[calendarIdentifier]
            if let firstWeekday { calendar.firstWeekday = firstWeekday }
            if let minDaysInFirstWeek { calendar.minimumDaysInFirstWeek = minDaysInFirstWeek }
        }

        return calendar
    }
    
    var calendarIdentifier: Calendar.Identifier {
        if let value = _canonical.keywordValue("calendar"), let calendar = Calendar.Identifier(identifierString: value) {
            return calendar
        } else if let regionOverrideRange = _canonical.regionOverrideRange {
            return Self.defaultCalendar(forRegion: _canonical.identifier.utf8Span.span.extracting(regionOverrideRange))
        } else {
            // FIXME: Use the likely region of the language. For example, use the calendar of "TH" for "th".
            return _icu.calendarIdentifier
        }
    }
    
    var collationIdentifier: String? {
        _icu.collationIdentifier
    }
    
    var usesMetricSystem: Bool {
        _icu.usesMetricSystem
    }
    
    var decimalSeparator: String? {
        _icu.decimalSeparator
    }
    
    var groupingSeparator: String? {
        _icu.groupingSeparator
    }
    
    var currencySymbol: String? {
        _icu.currencySymbol
    }
    
    var currencyCode: String? {
        _icu.currencyCode
    }
    
    var collatorIdentifier: String? {
        _icu.collatorIdentifier
    }
    
    var quotationBeginDelimiter: String? {
        _icu.quotationBeginDelimiter
    }
    
    var quotationEndDelimiter: String? {
        _icu.quotationEndDelimiter
    }
    
    var alternateQuotationBeginDelimiter: String? {
        _icu.alternateQuotationBeginDelimiter
    }
    
    var alternateQuotationEndDelimiter: String? {
        _icu.alternateQuotationEndDelimiter
    }
    
    var measurementSystem: Locale.MeasurementSystem {
        _icu.measurementSystem
    }
    
    var currency: Locale.Currency? {
        _icu.currency
    }
    
    var numberingSystem: Locale.NumberingSystem {
        if let value = _canonical.keywordValue("numbers") {
            return Locale.NumberingSystem(value)
        } else {
            let identifier = _canonical.identifier.utf8Span.span
            let absent = 0..<0
            return Locale.NumberingSystem(Self.defaultNumberingSystem(
                forLanguage: identifier.extracting(_canonical.componentRanges.language ?? absent),
                script: identifier.extracting(_canonical.componentRanges.script ?? absent),
                region: identifier.extracting(_canonical.componentRanges.region ?? absent)))
        }
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        _icu.availableNumberingSystems
    }
    
    var firstDayOfWeek: Locale.Weekday {
        _icu.firstDayOfWeek
    }

    var weekendRange: WeekendRange? {
        _icu.weekendRange
    }

    var minimumDaysInFirstWeek: Int {
        _icu.minimumDaysInFirstWeek
    }

    var language: Locale.Language {
        // Use the region of the identifier, not the region of the "rg" keyword.
        Locale.Language(languageCode: languageCode.map { .init($0) },
                        script: scriptCode.map { .init($0) },
                        region: _canonical.regionCode.map { .init($0) })
    }
    
    func identifier(_ type: Locale.IdentifierType) -> String {
        switch type {
        case .icu:
            _canonical.icuIdentifier
        case .bcp47, .cldr:
            _icu.identifier(type)
        }
    }

    var hourCycle: Locale.HourCycle {
        _icu.hourCycle
    }

    var collation: Locale.Collation {
        _icu.collation
    }
    
    var region: Locale.Region? {
        _canonical.regionOverride.map { Locale.Region($0) }
    }

    var timeZone: TimeZone? {
        _icu.timeZone
    }
    
    var subdivision: Locale.Subdivision? {
        _icu.subdivision
    }
    
    var variant: Locale.Variant? {
        _componentsVariant ?? _canonical.variantCode.map { .init($0) }
    }
    
    var temperatureUnit: LocalePreferences.TemperatureUnit {
        _icu.temperatureUnit
    }
    
    var forceHourCycle: Locale.HourCycle? {
        _icu.forceHourCycle
    }
    
    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday? {
        _icu.forceFirstWeekday(calendar)
    }
    
    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        _icu.forceMinDaysInFirstWeek(calendar)
    }
    
    var forceMeasurementSystem: Locale.MeasurementSystem? {
        _icu.forceMeasurementSystem
    }
    
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
        _icu.forceTemperatureUnit
    }
    
#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        _icu.customDateFormat(style)
    }
#endif
    
    var prefs: LocalePreferences? {
        _prefs
    }
    
    var identifierCapturingPreferences: String {
        _icu.identifierCapturingPreferences
    }
    
#if FOUNDATION_FRAMEWORK
    func pref(for key: String) -> Any? {
        _icu.pref(for: key)
    }
    
    func bridgeToNSLocale() -> NSLocale {
        LocaleCache.cache.fixedNSLocale(_icu)
    }
#endif

    /// Returns the default calendar for a region code in any case. A missing region is empty.
    static func defaultCalendar(forRegion region: Span<UInt8>) -> Calendar.Identifier {
        // FIXME: Generate this table from the locale data. Use the first preferred calendar of each region.
        guard region.count == 2 else { return .gregorian }
        switch (region[0]._lowercased, region[1]._lowercased) {
        case (UInt8(ascii: "a"), UInt8(ascii: "f")), (UInt8(ascii: "i"), UInt8(ascii: "r")): return .persian
        case (UInt8(ascii: "s"), UInt8(ascii: "a")): return .islamicUmmAlQura
        case (UInt8(ascii: "t"), UInt8(ascii: "h")): return .buddhist
        default: return .gregorian
        }
    }

    /// Returns the default numbering system for normalized subtags: lowercase language, title-case script, uppercase region. A missing subtag is empty.
    static func defaultNumberingSystem(forLanguage language: Span<UInt8>, script: Span<UInt8>, region: Span<UInt8>) -> String {
        let script = RawByteSpanComparator(script)
        let region = RawByteSpanComparator(region)
        switch RawByteSpanComparator(language) {
        case "ff":
            return "Adlm" ~= script ? "adlm" : "latn"
        case "ar":
            switch region {
            case "BH", "DJ", "EG", "ER", "IL", "IQ", "JO", "KM", "KW", "LB", "MR", "OM", "PS", "QA", "SA", "SD", "SO", "SS", "SY", "TD", "YE":
                return "arab"
            default:
                return "latn"
            }
        case "ckb", "sdh":
            return "arab"
        case "sd":
            return "Deva" ~= script ? "latn" : "arab"
        case "uz":
            return "Arab" ~= script ? "arabext" : "latn"
        case "pa":
            return "Arab" ~= script || "Aran" ~= script ? "arabext" : "latn"
        case "ks":
            return "Deva" ~= script ? "latn" : "arabext"
        case "bgn", "fa", "lrc", "mzn", "ps":
            return "arabext"
        case "mni":
            return "Mtei" ~= script ? "mtei" : "beng"
        case "as":
            return "beng"
        case "ccp":
            return "cakm"
        case "sat":
            return "Deva" ~= script ? "deva" : "olck"
        case "bgc", "bho", "ne", "raj", "sa":
            return "deva"
        case "hnj", "mww":
            return "hmnp"
        case "my":
            return "mymr"
        case "nqo":
            return "nkoo"
        case "dz":
            return "tibt"
        default:
            return "latn"
        }
    }
}
