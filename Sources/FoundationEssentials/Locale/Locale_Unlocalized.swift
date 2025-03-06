//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// An "unlocalized" Locale, for use in apps that do not otherwise care about localization. No matter which identifier or settings you initialize it with, it will still be `en_001`.
internal final class _LocaleUnlocalized : _LocaleProtocol, @unchecked Sendable {
    let _prefs: LocalePreferences?
    
    required init(identifier: String, prefs: LocalePreferences? = nil) {
        _prefs = prefs
    }
    
    required init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        _prefs = prefs
    }
    
    required init(components: Locale.Components) {
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
        .latin
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        [.latin]
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
