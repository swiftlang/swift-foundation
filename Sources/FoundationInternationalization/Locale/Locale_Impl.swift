//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026- Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// TODO: Is there boilerplate legalese we have to add to point back to ICU/CLDR as the source of the algorithms?

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
// for CFXPreferences call
internal import _ForSwiftFoundation
// For Logger
internal import os
#endif

internal import _FoundationICU
internal import Synchronization

#if canImport(Glibc)
@preconcurrency import Glibc
#endif

#if FOUNDATION_LOCALE_EXPERIMENTAL
#if !FOUNDATION_FRAMEWORK
@_dynamicReplacement(for: _localeICUClass())
private func _localeICUClass_localized() -> any _LocaleProtocol.Type {
    return _LocaleImpl.self
}
#endif
#endif

// TODO: Right now, this is just a copy of _Locale_Unlocalized.  The plan is first to convert it to a thin wrapper around _Locale_ICU and then slowly replace all of the calls to _Locale_ICU with our own implementations.

internal final class _LocaleImpl : _LocaleProtocol, @unchecked Sendable {
    private let _originalIdentifier: String
    private let _normalizedIdentifier: String
    private let _prefs: LocalePreferences?
    
    required init(identifier: String, prefs: LocalePreferences? = nil) {
        _originalIdentifier = identifier
        _prefs = prefs
        
        let (language, script, region, variant) = Self.parseBaseLocaleID(identifier)
        var normalizedIdentifier = ""
        if let language {
            normalizedIdentifier.append(Self.normalizedLanguageCode(language))
        }
        if let script {
            normalizedIdentifier.append("_\(Self.normalizedScriptCode(script))")
        }
        if let region {
            normalizedIdentifier.append("_\(Self.normalizedRegionCode(region))")
        }
        if let variant {
            if language == nil {
                // special-case for the situation where the variant is the only populated field
                normalizedIdentifier.append("__\(Self.normalizedVariantCode(variant))")
            } else {
                normalizedIdentifier.append("_\(Self.normalizedVariantCode(variant))")
            }
        }
        _normalizedIdentifier = normalizedIdentifier
    }
    
    required init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        // TODO: What does this function do?  How do I replicate the current implementation?
        _originalIdentifier = ""
        _normalizedIdentifier = ""
        _prefs = prefs
    }
    
    required init(components: Locale.Components) {
        _originalIdentifier = components.icuIdentifier
        _normalizedIdentifier = _originalIdentifier
        _prefs = nil
    }

    // TODO: Implement identifier parsing in Swift. Must handle every component stored by a
    // `Locale.Components`, and be kept in sync with `Locale.Components.icuIdentifier`.
    // See `_LocaleICU.components(forIdentifier:)` for the behavior being replaced.
    static func components(forIdentifier identifier: String) -> Locale.Components {
        let (language, script, region, variant) = Self.parseBaseLocaleID(identifier)
        var result = Locale.Components(languageCode: language.map { Locale.LanguageCode(Self.normalizedLanguageCode($0)) }, script: script.map { Locale.Script(Self.normalizedScriptCode($0)) }, languageRegion: region.map { Locale.Region(Self.normalizedRegionCode($0)) })
        result.variant = variant.map { Locale.Variant(Self.normalizedVariantCode($0)) }
        return result
    }

    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
        // TODO: FILL IN!!!
        self
    }
    
    var debugDescription: String {
        "Fixed \(_originalIdentifier)"
    }
    
    var identifier: String {
        _originalIdentifier
    }
    
    func identifierDisplayName(for value: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func languageCodeDisplayName(for value: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func countryCodeDisplayName(for regionCode: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func scriptCodeDisplayName(for scriptCode: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func variantCodeDisplayName(for variantCode: String) -> String? {
        // TODO: FILL IN!!!
       nil
    }
    
    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func currencyCodeDisplayName(for value: String) -> String? {
       // TODO: FILL IN!!!
       nil
    }
    
    func currencySymbolDisplayName(for value: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func collationIdentifierDisplayName(for value: String) -> String? {
        // TODO: FILL IN!!!
        nil
    }
    
    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String? {
        // TODO: FILL IN!!!
       nil
    }
    
    var languageCode: String? {
        let (result, _, _, _) = Self.parseBaseLocaleID(_normalizedIdentifier)
        return result.map { String($0) }
    }
    
    var scriptCode: String? {
        let (_, result, _, _) = Self.parseBaseLocaleID(_normalizedIdentifier)
        return result.map { String($0) }
    }
    
    var variantCode: String? {
        let (_, _, _, result) = Self.parseBaseLocaleID(_normalizedIdentifier)
        return result.map { String($0) }
    }
    
    var regionCode: String? {
        let (_, _, result, _) = Self.parseBaseLocaleID(_normalizedIdentifier)
        return result.map { String($0) }
    }
    
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? {
        LocaleCache.cache.fixed(identifier).exemplarCharacterSet
    }
#endif
    
    var calendar: Calendar {
        // TODO: FILL IN!!!
        Calendar.current
    }
    
    var calendarIdentifier: Calendar.Identifier {
        // TODO: FILL IN!!!
        .gregorian
    }
    
    var collationIdentifier: String? {
        // TODO: FILL IN!!!
        "standard"
    }
    
    var usesMetricSystem: Bool {
        // TODO: FILL IN!!!
        true
    }
    
    var decimalSeparator: String? {
        // TODO: FILL IN!!!
        "."
    }
    
    var groupingSeparator: String? {
        // TODO: FILL IN!!!
        ","
    }
    
    var currencySymbol: String? {
        // TODO: FILL IN!!!
        "¤"
    }
    
    var currencyCode: String? {
        // TODO: FILL IN!!!
        nil
    }
    
    var collatorIdentifier: String? {
        // TODO: FILL IN!!!
        identifier
    }
    
    var quotationBeginDelimiter: String? {
        // TODO: FILL IN!!!
        "“"
    }
    
    var quotationEndDelimiter: String? {
        // TODO: FILL IN!!!
        "”"
    }
    
    var alternateQuotationBeginDelimiter: String? {
        // TODO: FILL IN!!!
        "‘"
    }
    
    var alternateQuotationEndDelimiter: String? {
        // TODO: FILL IN!!!
        "’"
    }
    
    var measurementSystem: Locale.MeasurementSystem {
        // TODO: FILL IN!!!
        .metric
    }
    
    var currency: Locale.Currency? {
        // TODO: FILL IN!!!
        nil
    }
    
    var numberingSystem: Locale.NumberingSystem {
        // TODO: FILL IN!!!
        .latn
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        // TODO: FILL IN!!!
        [.latn]
    }
    
    var firstDayOfWeek: Locale.Weekday {
        // TODO: FILL IN!!!
        .monday
    }

    var weekendRange: WeekendRange? {
        // TODO: FILL IN!!!
        // Weekend range for 001 region
        WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1)
    }

    var minimumDaysInFirstWeek: Int {
        // TODO: FILL IN!!!
        // Minimum days in first week for 001 region
        1
    }

    var language: Locale.Language {
        let (language, script, region, _) = Self.parseBaseLocaleID(_normalizedIdentifier)

        return Locale.Language(languageCode: language.map { .init(String($0)) },
                               script: script.map { .init(String($0)) },
                               region: region.map { .init(String($0)) })
    }
    
    func identifier(_ type: Locale.IdentifierType) -> String {
        // TODO: FILL IN!!!
        switch type {
        case .bcp47: "en-001"
        case .cldr: "en_001"
        case .icu: "en_001"
        }
    }
    
    var hourCycle: Locale.HourCycle {
        // TODO: FILL IN!!!
        .zeroToTwentyThree
    }
    
    var collation: Locale.Collation {
        // TODO: FILL IN!!!
        .standard
    }
    
    var region: Locale.Region? {
        // TODO: This will need to be beefed up to also handle the "rg" subtag
        let (_, _, region, _) = Self.parseBaseLocaleID(_normalizedIdentifier)
        
        return region.map { .init(String($0)) }
    }
    
    var timeZone: TimeZone? {
        // TODO: FILL IN!!!
        nil
    }
    
    var subdivision: Locale.Subdivision? {
        // TODO: FILL IN!!!
        nil
    }
    
    var variant: Locale.Variant? {
        let (_, _, _, variant) = Self.parseBaseLocaleID(_normalizedIdentifier)
        
        return variant.map { .init(String($0)) }
    }
    
    var temperatureUnit: LocalePreferences.TemperatureUnit {
        // TODO: FILL IN!!!
        .celsius
    }
    
    var forceHourCycle: Locale.HourCycle? {
        // TODO: FILL IN!!!
        nil
    }
    
    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday? {
        // TODO: FILL IN!!!
        nil
    }
    
    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        // TODO: FILL IN!!!
        nil
    }
    
    var forceMeasurementSystem: Locale.MeasurementSystem? {
        // TODO: FILL IN!!!
        nil
    }
    
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
        // TODO: FILL IN!!!
        nil
    }
    
#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        nil
    }
#endif
    
    var prefs: LocalePreferences? {
        _prefs
    }
    
    var identifierCapturingPreferences: String {
        identifier
    }
    
#if FOUNDATION_FRAMEWORK
    func pref(for key: String) -> Any? {
        nil
    }
    
    func bridgeToNSLocale() -> NSLocale {
        Locale(identifier: identifier) as NSLocale
    }
#endif

    static func parseBaseLocaleID(_ identifier: String) -> (language: Substring?, script: Substring?, region: Substring?, variant: Substring?) {
        let baseLocaleID = identifier.split(separator: "@").first ?? ""
        var parts = baseLocaleID.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "-" || $0 == "_" })[...]
        
        // the first segment is always considered to be the language code, even if empty or syntactically malformed (TODO: tighten this up?)
        // TODO: the corresponding ICU code also handles language codes that begin with "i-" and "x-".  We might need to do the same (maybe in a separate BCP 47 code path)
        var language = parts.first
        parts = parts.dropFirst()
        if let l = language, !(1...11).contains(l.count) {
            language = nil
        }
        
        // if the next segment contains exactly 4 letters, it's the script code
        var script = parts.first
        if let script, script.count == 4, script.allSatisfy({ $0.isASCII && $0.isLetter }) {
            parts = parts.dropFirst()
        } else {
            script = nil
        }
        
        // the next segment is considered the region code if it contains 2 or 3 characters
        // TODO: we don't check the actual characters here, but maybe should?
        var region = parts.first
        if let region, region.count == 2 || region.count == 3 {
            parts = parts.dropFirst()
        } else {
            region = nil
        }
        
        // if there are any segments left, consider ALL of them together to be the variant code (TODO: tighten this up somehow? deal with the fact that - in the variant doesn't get converted to _?)
        while let p = parts.first, p.isEmpty {
            parts = parts.dropFirst()
        }
        var variant: Substring? = if let first = parts.first, let last = parts.last {
            baseLocaleID[first.startIndex..<last.endIndex]
        } else {
            nil
        }
        if let v = variant, v.isEmpty {
            variant = nil
        }

        return (language, script, region, variant)
    }
    
    static func normalizedLanguageCode(_ language: Substring) -> String {
        // TODO: Add code here to map from 3-letter language codes to 2-letter equivalents
        return language.lowercased()
    }
    
    static func normalizedScriptCode(_ script: Substring) -> String {
        // TODO: Add code to calculate the default script for the language code (which will mean changing this function's signature)
        return script.capitalized
    }
    
    static func normalizedRegionCode(_ region: Substring) -> String {
        // TODO: Add code to map 3-letter codes [I didn't know they were legal!] into equivalent 2-letter codes when possible (if we need this?)
        return region.uppercased()
    }
    
    static func normalizedVariantCode(_ variant: Substring) -> String {
        return variant.uppercased()
    }
}

/// Pure-Swift implementation of the `Locale.Language` operations.
///
/// Selected as `_LanguageEngine` when `FOUNDATION_LOCALE_EXPERIMENTAL` is defined. Until each
/// operation has a native implementation, it forwards sideways to `_LocaleLanguageICU` so that
/// `Locale.Language` keeps behaving correctly during the transition.
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
enum _LocaleLanguageImpl: _LocaleLanguageProtocol {
    // These read the parsed component directly (no ICU). An absent subtag is returned as `nil`
    // rather than being inferred from likely subtags.
    static func languageCode(_ components: Locale.Language.Components) -> Locale.LanguageCode? {
        components.languageCode
    }

    static func script(_ components: Locale.Language.Components) -> Locale.Script? {
        components.script
    }

    static func region(_ components: Locale.Language.Components) -> Locale.Region? {
        components.region
    }

    static func components(forIdentifier identifier: String) -> Locale.Language.Components {
        let (language, script, region, _) = _LocaleImpl.parseBaseLocaleID(identifier)
        return Locale.Language.Components(
            languageCode: language.map { Locale.LanguageCode(String($0)) },
            script: script.map { Locale.Script(String($0)) },
            region: region.map { Locale.Region(String($0)) })
    }

    // TODO: Replace these ICU forwards with pure-Swift implementations, one at a time.
    static func minimalIdentifier(_ components: Locale.Language.Components) -> String {
        _LocaleLanguageICU.minimalIdentifier(components)
    }

    static func maximalIdentifier(_ components: Locale.Language.Components) -> String {
        _LocaleLanguageICU.maximalIdentifier(components)
    }

    static func parent(_ components: Locale.Language.Components) -> Locale.Language? {
        _LocaleLanguageICU.parent(components)
    }

    static func characterDirection(_ components: Locale.Language.Components) -> Locale.LanguageDirection {
        _LocaleLanguageICU.characterDirection(components)
    }

    static func lineLayoutDirection(_ components: Locale.Language.Components) -> Locale.LanguageDirection {
        _LocaleLanguageICU.lineLayoutDirection(components)
    }
}
