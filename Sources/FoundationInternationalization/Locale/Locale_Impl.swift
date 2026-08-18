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
    let _prefs: LocalePreferences?
    
//    internal static func waitASecond() {
//        let startTime = ContinuousClock.now
//        let endTime = startTime.advanced(by: .seconds(0.1))
//        while ContinuousClock.now < endTime {}
//    }
    
    required init(identifier: String, prefs: LocalePreferences? = nil) {
//        Self.waitASecond()
        _prefs = prefs
    }
    
    required init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
//        Self.waitASecond()
        _prefs = prefs
    }
    
    required init(components: Locale.Components) {
//        Self.waitASecond()
       _prefs = nil
    }
    
    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
        // Nothing changes here
        self
    }
    
    var debugDescription: String {
        "unlocalized en_001"
    }
    
    var identifier: String {
        "en_001"
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
        Locale.Language(components: .init(languageCode: .init("en"), script: nil, region: .init("001")))
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
        Locale.Region("001")
    }
    
    var timeZone: TimeZone? {
        nil
    }
    
    var subdivision: Locale.Subdivision? {
        nil
    }
    
    var variant: Locale.Variant? {
        nil
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

}
