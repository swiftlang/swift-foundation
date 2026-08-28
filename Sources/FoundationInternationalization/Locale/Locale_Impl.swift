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
            // TODO: Add code to map 3-letter codes into equivalent 2-letter codes when possible
            normalizedIdentifier.append(language.lowercased())
        }
        if let script {
            // TODO: Add code to fill in a default script when appropriate and possible
            normalizedIdentifier.append("_\(script.capitalized)")
        }
        if let region {
            // TODO: Add code to map 3-letter codes [I didn't know they were legal!] into equivalent 2-letter codes when possible
            normalizedIdentifier.append("_\(region.uppercased())")
        }
        if let variant {
            if language == nil {
                // special-case for the situation where the variant is the only populated field
                normalizedIdentifier.append("__\(variant.uppercased())")
            } else {
                normalizedIdentifier.append("_\(variant.uppercased())")
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
        Locale.Components(languageCode: "en", languageRegion: "001")
    }

    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
        // Nothing changes here
        self
    }
    
    var debugDescription: String {
        "Fixed \(_originalIdentifier)"
    }
    
    var identifier: String {
        _originalIdentifier
    }
    
    func identifierDisplayName(for value: String) -> String? {
        nil
    }
    
    func languageCodeDisplayName(for value: String) -> String? {
        nil
    }
    
    func countryCodeDisplayName(for regionCode: String) -> String? {
        nil
    }
    
    func scriptCodeDisplayName(for scriptCode: String) -> String? {
        nil
    }
    
    func variantCodeDisplayName(for variantCode: String) -> String? {
        nil
    }
    
    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String? {
        nil
    }
    
    func currencyCodeDisplayName(for value: String) -> String? {
        nil
    }
    
    func currencySymbolDisplayName(for value: String) -> String? {
        nil
    }
    
    func collationIdentifierDisplayName(for value: String) -> String? {
        nil
    }
    
    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String? {
        nil
    }
    
    var languageCode: String? {
        "en"
    }
    
    var scriptCode: String? {
        nil
    }
    
    var variantCode: String? {
        nil
    }
    
    var regionCode: String? {
        "001"
    }
    
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? {
        LocaleCache.cache.fixed(identifier).exemplarCharacterSet
    }
#endif
    
    var calendar: Calendar {
        Calendar.current
    }
    
    var calendarIdentifier: Calendar.Identifier {
        .gregorian
    }
    
    var collationIdentifier: String? {
        "standard"
    }
    
    var usesMetricSystem: Bool {
        true
    }
    
    var decimalSeparator: String? {
        "."
    }
    
    var groupingSeparator: String? {
        ","
    }
    
    var currencySymbol: String? {
        "¤"
    }
    
    var currencyCode: String? {
        nil
    }
    
    var collatorIdentifier: String? {
        identifier
    }
    
    var quotationBeginDelimiter: String? {
        "“"
    }
    
    var quotationEndDelimiter: String? {
        "”"
    }
    
    var alternateQuotationBeginDelimiter: String? {
        "‘"
    }
    
    var alternateQuotationEndDelimiter: String? {
        "’"
    }
    
    var measurementSystem: Locale.MeasurementSystem {
        .metric
    }
    
    var currency: Locale.Currency? {
        nil
    }
    
    var numberingSystem: Locale.NumberingSystem {
        .latn
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        [.latn]
    }
    
    var firstDayOfWeek: Locale.Weekday {
        .monday
    }

    var weekendRange: WeekendRange? {
        // Weekend range for 001 region
        WeekendRange(onsetTime: 0, ceaseTime: 86400, start: 7, end: 1)
    }

    var minimumDaysInFirstWeek: Int {
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
        switch type {
        case .bcp47: "en-001"
        case .cldr: "en_001"
        case .icu: "en_001"
        }
    }
    
    var hourCycle: Locale.HourCycle {
        .zeroToTwentyThree
    }
    
    var collation: Locale.Collation {
        .standard
    }
    
    var region: Locale.Region? {
        // TODO: This will need to be beefed up to also handle the "rg" subtag
        let (_, _, region, _) = Self.parseBaseLocaleID(_normalizedIdentifier)
        
        return region.map { .init(String($0)) }
    }
    
    var timeZone: TimeZone? {
        nil
    }
    
    var subdivision: Locale.Subdivision? {
        nil
    }
    
    var variant: Locale.Variant? {
        let (_, _, _, variant) = Self.parseBaseLocaleID(_normalizedIdentifier)
        
        return variant.map { .init(String($0)) }
    }
    
    var temperatureUnit: LocalePreferences.TemperatureUnit {
        .celsius
    }
    
    var forceHourCycle: Locale.HourCycle? {
        nil
    }
    
    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday? {
        nil
    }
    
    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        nil
    }
    
    var forceMeasurementSystem: Locale.MeasurementSystem? {
        nil
    }
    
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
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

    private static func parseBaseLocaleID(_ identifier: String) -> (language: Substring?, script: Substring?, region: Substring?, variant: Substring?) {
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
}
