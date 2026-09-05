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

// Required to be `AnyObject` because it optimizes the call sites in the `struct` wrapper for efficient function dispatch.
package protocol _LocaleProtocol : AnyObject, Sendable, CustomDebugStringConvertible {

    init(identifier: String, prefs: LocalePreferences?)
    init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool)
    init(components: Locale.Components)

    /// Parses a locale identifier into its constituent components.
    ///
    /// This is the inverse of `Locale.Components.icuIdentifier` and provides the implementation of
    /// `Locale.Components.init(identifier:)`. It is `static` because most callers are parsing a bare
    /// identifier string and have no `Locale` in hand — several of them are parsing an identifier
    /// while a `Locale` is being constructed.
    static func components(forIdentifier identifier: String) -> Locale.Components
        
    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol
    
    var debugDescription: String { get }
    var isAutoupdating: Bool { get }
    var isBridged: Bool { get }
    
    var identifier: String { get }
    
    func identifierDisplayName(for value: String) -> String?
    func languageCodeDisplayName(for value: String) -> String?
    func countryCodeDisplayName(for regionCode: String) -> String?
    func scriptCodeDisplayName(for scriptCode: String) -> String?
    func variantCodeDisplayName(for variantCode: String) -> String?
    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String?
    func currencyCodeDisplayName(for value: String) -> String?
    func currencySymbolDisplayName(for value: String) -> String?
    func collationIdentifierDisplayName(for value: String) -> String?
    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String?
    
    var languageCode: String? { get }
    var scriptCode: String? { get }
    var variantCode: String? { get }
    var regionCode: String? { get }
    
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? { get }
#endif

    var calendar: Calendar { get }
    var calendarIdentifier: Calendar.Identifier { get }
    var collationIdentifier: String? { get }
    var usesMetricSystem: Bool { get }
    var decimalSeparator: String? { get }
    var groupingSeparator: String? { get }
    var currencySymbol: String? { get }
    var currencyCode: String? { get }
    var collatorIdentifier: String? { get }
    var quotationBeginDelimiter: String? { get }
    var quotationEndDelimiter: String? { get }
    var alternateQuotationBeginDelimiter: String? { get }
    var alternateQuotationEndDelimiter: String? { get }
    var measurementSystem: Locale.MeasurementSystem { get }
    var currency: Locale.Currency? { get }
    var numberingSystem: Locale.NumberingSystem { get }
    var availableNumberingSystems: [Locale.NumberingSystem] { get }
    var firstDayOfWeek: Locale.Weekday { get }
    var weekendRange: WeekendRange? { get }
    var minimumDaysInFirstWeek: Int { get }
    var language: Locale.Language { get }
    var hourCycle: Locale.HourCycle { get }
    var collation: Locale.Collation { get }
    var region: Locale.Region? { get }
    var timeZone: TimeZone? { get }
    var subdivision: Locale.Subdivision? { get }
    var variant: Locale.Variant? { get }
    var temperatureUnit: LocalePreferences.TemperatureUnit { get }

    func identifier(_ type: Locale.IdentifierType) -> String

    var forceHourCycle: Locale.HourCycle? { get }
    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday?
    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int?
    var forceMeasurementSystem: Locale.MeasurementSystem? { get }
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? { get }
    
    var prefs: LocalePreferences? { get }
    
    var identifierCapturingPreferences: String { get }
    
#if FOUNDATION_FRAMEWORK
    func pref(for key: String) -> Any?
    
    func bridgeToNSLocale() -> NSLocale
    
#if !NO_FORMATTERS
    // This is framework-only because Date.FormatStyle.DateStlye is Internationalization-only
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String?
#endif
#endif
}

extension _LocaleProtocol {

    // Only the implementations that can actually parse an identifier override this. For the others it is
    // unreachable in practice: `Locale.Components.init(identifier:)` is only available in
    // FoundationInternationalization, and `_localeICUClass()` never returns them from that module.
    package static func components(forIdentifier identifier: String) -> Locale.Components {
        Locale.Components()
    }

    package var regionCode: String? {
        region?.identifier
    }
    
    package var debugDescription: String {
        identifier
    }
    
    package var isAutoupdating: Bool {
        false
    }
    
    package var isBridged: Bool {
        false
    }
}
