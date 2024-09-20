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

internal final class _LocaleAutoupdating : _LocaleProtocol, @unchecked Sendable {
    init() { }
        
    init(identifier: String, prefs: LocalePreferences?) {
        fatalError("Unexpected init")
    }
    
    init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        fatalError("Unexpected init")
    }
    
    init(components: Locale.Components) {
        fatalError("Unexpected init")
    }

    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
        LocaleCache.cache.current.copy(newCalendarIdentifier: identifier)
    }
    
    var debugDescription: String {
        "autoupdating \(identifier)"
    }
    
    var isAutoupdating: Bool {
        true
    }
    
    var identifier: String {
        LocaleCache.cache.current.identifier
    }
    
    func identifierDisplayName(for value: String) -> String? {
        LocaleCache.cache.current.identifierDisplayName(for: value)
    }
    
    func languageCodeDisplayName(for value: String) -> String? {
        LocaleCache.cache.current.languageCodeDisplayName(for: value)
    }
    
    func countryCodeDisplayName(for regionCode: String) -> String? {
        LocaleCache.cache.current.countryCodeDisplayName(for: regionCode)
    }
    
    func scriptCodeDisplayName(for scriptCode: String) -> String? {
        LocaleCache.cache.current.scriptCodeDisplayName(for: scriptCode)
    }
    
    func variantCodeDisplayName(for variantCode: String) -> String? {
        LocaleCache.cache.current.variantCodeDisplayName(for: variantCode)
    }
    
    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String? {
        LocaleCache.cache.current.calendarIdentifierDisplayName(for: value)
    }
    
    func currencyCodeDisplayName(for value: String) -> String? {
        LocaleCache.cache.current.currencyCodeDisplayName(for: value)
    }
    
    func currencySymbolDisplayName(for value: String) -> String? {
        LocaleCache.cache.current.currencySymbolDisplayName(for: value)
    }
    
    func collationIdentifierDisplayName(for value: String) -> String? {
        LocaleCache.cache.current.collationIdentifierDisplayName(for: value)
    }
    
    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String? {
        LocaleCache.cache.current.collatorIdentifierDisplayName(for: collatorIdentifier)
    }
    
    var languageCode: String? {
        LocaleCache.cache.current.languageCode
    }
    
    var scriptCode: String? {
        LocaleCache.cache.current.scriptCode
    }
    
    var variantCode: String? {
        LocaleCache.cache.current.variantCode
    }
    
    var regionCode: String? {
        LocaleCache.cache.current.regionCode
    }
    
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? {
        LocaleCache.cache.current.exemplarCharacterSet
    }
    
#endif
    var calendar: Calendar {
        LocaleCache.cache.current.calendar
    }
    
    var calendarIdentifier: Calendar.Identifier {
        LocaleCache.cache.current.calendarIdentifier
    }
    
    var collationIdentifier: String? {
        LocaleCache.cache.current.collationIdentifier
    }
    
    var usesMetricSystem: Bool {
        LocaleCache.cache.current.usesMetricSystem
    }
    
    var decimalSeparator: String? {
        LocaleCache.cache.current.decimalSeparator
    }
    
    var groupingSeparator: String? {
        LocaleCache.cache.current.groupingSeparator
    }
    
    var currencySymbol: String? {
        LocaleCache.cache.current.currencySymbol
    }
    
    var currencyCode: String? {
        LocaleCache.cache.current.currencyCode
    }
    
    var collatorIdentifier: String? {
        LocaleCache.cache.current.collatorIdentifier
    }
    
    var quotationBeginDelimiter: String? {
        LocaleCache.cache.current.quotationBeginDelimiter
    }
    
    var quotationEndDelimiter: String? {
        LocaleCache.cache.current.quotationEndDelimiter
    }
    
    var alternateQuotationBeginDelimiter: String? {
        LocaleCache.cache.current.alternateQuotationBeginDelimiter
    }
    
    var alternateQuotationEndDelimiter: String? {
        LocaleCache.cache.current.alternateQuotationEndDelimiter
    }
    
    var measurementSystem: Locale.MeasurementSystem {
        LocaleCache.cache.current.measurementSystem
    }
    
    var currency: Locale.Currency? {
        LocaleCache.cache.current.currency
    }
    
    var numberingSystem: Locale.NumberingSystem {
        LocaleCache.cache.current.numberingSystem
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        LocaleCache.cache.current.availableNumberingSystems
    }
    
    var firstDayOfWeek: Locale.Weekday {
        LocaleCache.cache.current.firstDayOfWeek
    }
    
    var weekendRange: WeekendRange? {
        LocaleCache.cache.current.weekendRange
    }

    var minimumDaysInFirstWeek: Int {
        LocaleCache.cache.current.minimumDaysInFirstWeek
    }

    var language: Locale.Language {
        LocaleCache.cache.current.language
    }
    
    func identifier(_ type: Locale.IdentifierType) -> String {
        LocaleCache.cache.current.identifier
    }
    
    var hourCycle: Locale.HourCycle {
        LocaleCache.cache.current.hourCycle
    }
    
    var collation: Locale.Collation {
        LocaleCache.cache.current.collation
    }
    
    var region: Locale.Region? {
        LocaleCache.cache.current.region
    }
    
    var timeZone: TimeZone? {
        LocaleCache.cache.current.timeZone
    }
    
    var subdivision: Locale.Subdivision? {
        LocaleCache.cache.current.subdivision
    }
    
    var variant: Locale.Variant? {
        LocaleCache.cache.current.variant
    }
    
    var temperatureUnit: LocalePreferences.TemperatureUnit {
        LocaleCache.cache.current.temperatureUnit
    }
    
    var forceHourCycle: Locale.HourCycle? {
        LocaleCache.cache.current.forceHourCycle
    }
    
    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday? {
        LocaleCache.cache.current.forceFirstWeekday(calendar)
    }
    
    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        LocaleCache.cache.current.forceMinDaysInFirstWeek(calendar)
    }
    
    var forceMeasurementSystem: Locale.MeasurementSystem? {
        LocaleCache.cache.current.forceMeasurementSystem
    }
    
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
        LocaleCache.cache.current.forceTemperatureUnit
    }
    
#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        LocaleCache.cache.current.customDateFormat(style)
    }
#endif
    
    var prefs: LocalePreferences? {
        LocaleCache.cache.current.prefs
    }
    
    var identifierCapturingPreferences: String {
        LocaleCache.cache.current.identifierCapturingPreferences
    }

    
#if FOUNDATION_FRAMEWORK
    func pref(for key: String) -> Any? {
        LocaleCache.cache.current.pref(for: key)
    }
    
    func bridgeToNSLocale() -> NSLocale {
        LocaleCache.autoupdatingCurrentNSLocale
    }
#endif

}
