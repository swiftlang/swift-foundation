//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK

@_implementationOnly import _ForSwiftFoundation
import CoreFoundation
@_implementationOnly import os
@_implementationOnly import CoreFoundation_Private.CFLocale
@_implementationOnly import Foundation_Private.NSLocale

/// Wraps an NSLocale with a more Swift-like `Locale` API.
/// This is only used in the case where we have custom Objective-C subclasses of `NSLocale`. It is assumed that the subclass is Sendable.
/// TODO: It is a bit of a TBD if this extra effort to preserve a subclass sent to Swift from ObjC is worth it for `struct Locale`.
internal final class _LocaleBridged: _LocaleProtocol, @unchecked Sendable {
    
    init(identifier: String, prefs: LocalePreferences?) {
        fatalError("Unexpected init")
    }
    
    init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        fatalError("Unexpected init")
    }
    
    init(components: Locale.Components) {
        fatalError("Unexpected init")
    }
    
    let _wrapped: NSLocale

    init(adoptingReference reference: NSLocale) {
        self._wrapped = reference
    }
    
    func bridgeToNSLocale() -> NSLocale {
        return _wrapped.copy() as! NSLocale
    }

    var debugDescription: String {
        _wrapped.debugDescription
    }

    func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> any _LocaleProtocol {
#if canImport(FoundationICU)
        // Round trip through Locale.Components
        var comps = Locale.Components(identifier: self.identifier)
        comps.calendar = identifier
        return Locale(components: comps)._locale
#else
        return _LocaleUnlocalized(identifier: identifier.cfCalendarIdentifier)
#endif
    }
    
    var isBridged: Bool {
        true
    }
    
    // MARK: -
    //

    var identifier: String {
        _wrapped.localeIdentifier
    }

    // MARK: -

    func identifierDisplayName(for identifier: String) -> String? {
        _wrapped.displayName(forKey: .identifier, value: identifier)
    }

    func languageCodeDisplayName(for languageCode: String) -> String? {
        _wrapped.displayName(forKey: .languageCode, value: languageCode)
    }

    func countryCodeDisplayName(for regionCode: String) -> String? {
        _wrapped.displayName(forKey: .countryCode, value: regionCode)
    }

    func scriptCodeDisplayName(for scriptCode: String) -> String? {
        _wrapped.displayName(forKey: .scriptCode, value: scriptCode)
    }

    func variantCodeDisplayName(for variantCode: String) -> String? {
        _wrapped.displayName(forKey: .variantCode, value: variantCode)
    }

    func calendarIdentifierDisplayName(for calendarIdentifier: Calendar.Identifier) -> String? {
        // NSLocale doesn't export a constant for this
        CFLocaleCopyDisplayNameForPropertyValue(unsafeBitCast(_wrapped, to: CFLocale.self), .calendarIdentifier, Calendar._toNSCalendarIdentifier(calendarIdentifier).rawValue as CFString) as String?
    }

    func currencyCodeDisplayName(for currencyCode: String) -> String? {
        _wrapped.displayName(forKey: .currencyCode, value: currencyCode)
    }
    
    func currencySymbolDisplayName(for currencySymbol: String) -> String? {
        _wrapped.displayName(forKey: .currencySymbol, value: currencySymbol)
    }

    func collationIdentifierDisplayName(for collationIdentifier: String) -> String? {
        _wrapped.displayName(forKey: .collationIdentifier, value: collationIdentifier)
    }

    func collatorIdentifierDisplayName(for collatorIdentifier: String) -> String? {
        _wrapped.displayName(forKey: .collatorIdentifier, value: collatorIdentifier)
    }

    // MARK: -
    //

    var languageCode: String? {
        _wrapped.object(forKey: .languageCode) as? String
    }

    var scriptCode: String? {
        _wrapped.object(forKey: .scriptCode) as? String
    }

    var variantCode: String? {
        guard let result = _wrapped.object(forKey: .variantCode) as? String else {
            return nil
        }
        
        if result.isEmpty {
            return nil
        } else {
            return result
        }
    }
    
    var regionCode: String? {
        if let result = _wrapped.object(forKey: .countryCode) as? String {
            if result.isEmpty {
                return nil
            } else {
                return result
            }
        } else {
            return nil
        }
    }

    var exemplarCharacterSet: CharacterSet? {
        _wrapped.object(forKey: .exemplarCharacterSet) as? CharacterSet
    }
    
    var calendar: Calendar {
        if let result = _wrapped.object(forKey: .calendar) as? Calendar {
            // NSLocale should not return nil here
            return result
        } else {
            return Calendar(identifier: .gregorian)
        }
    }

    var calendarIdentifier: Calendar.Identifier {
        Calendar._fromNSCalendarIdentifier(NSCalendar.Identifier(rawValue: _wrapped.calendarIdentifier)) ?? .gregorian
    }

    var collationIdentifier: String? {
        _wrapped.object(forKey: .collationIdentifier) as? String
    }

    var usesMetricSystem: Bool {
        // NSLocale should not return nil here, but just in case
        if let result = (_wrapped.object(forKey: .usesMetricSystem) as? NSNumber)?.boolValue {
            return result
        } else {
            return false
        }
    }

    var decimalSeparator: String? {
        _wrapped.object(forKey: .decimalSeparator) as? String
    }

    var groupingSeparator: String? {
        _wrapped.object(forKey: .groupingSeparator) as? String
    }

    var currencySymbol: String? {
        _wrapped.object(forKey: .currencySymbol) as? String
    }

    var currencyCode: String? {
        _wrapped.object(forKey: .currencyCode) as? String
    }

    var collatorIdentifier: String? {
        _wrapped.object(forKey: .collatorIdentifier) as? String
    }

    var quotationBeginDelimiter: String? {
        _wrapped.object(forKey: .quotationBeginDelimiterKey) as? String
    }

    var quotationEndDelimiter: String? {
        _wrapped.object(forKey: .quotationEndDelimiterKey) as? String
    }

    var alternateQuotationBeginDelimiter: String? {
        _wrapped.object(forKey: .alternateQuotationBeginDelimiterKey) as? String
    }

    var alternateQuotationEndDelimiter: String? {
        _wrapped.object(forKey: .alternateQuotationEndDelimiterKey) as? String
    }
    
    var measurementSystem: Locale.MeasurementSystem {
        LocaleCache.cache.fixed(identifier).measurementSystem
    }
    
    var currency: Locale.Currency? {
        LocaleCache.cache.fixed(identifier).currency
    }
    
    var numberingSystem: Locale.NumberingSystem {
        LocaleCache.cache.fixed(identifier).numberingSystem
    }
    
    var availableNumberingSystems: [Locale.NumberingSystem] {
        LocaleCache.cache.fixed(identifier).availableNumberingSystems
    }
    
    var firstDayOfWeek: Locale.Weekday {
        LocaleCache.cache.fixed(identifier).firstDayOfWeek
    }
    
    var language: Locale.Language {
        LocaleCache.cache.fixed(identifier).language
    }
    
    func identifier(_ type: Locale.IdentifierType) -> String {
        LocaleCache.cache.fixed(identifier).identifier(type)
    }
    
    var hourCycle: Locale.HourCycle {
        LocaleCache.cache.fixed(identifier).hourCycle
    }
    
    var collation: Locale.Collation {
        LocaleCache.cache.fixed(identifier).collation
    }
    
    var region: Locale.Region? {
        LocaleCache.cache.fixed(identifier).region
    }
    
    var timeZone: TimeZone? {
        LocaleCache.cache.fixed(identifier).timeZone
    }
    
    var subdivision: Locale.Subdivision? {
        LocaleCache.cache.fixed(identifier).subdivision
    }
    
    var variant: Locale.Variant? {
        LocaleCache.cache.fixed(identifier).variant
    }
    
    var temperatureUnit: LocalePreferences.TemperatureUnit {
        LocaleCache.cache.fixed(identifier).temperatureUnit
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

#if !NO_FORMATTERS
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        nil
    }
#endif
    
    var prefs: LocalePreferences? {
        nil
    }
    
    var identifierCapturingPreferences: String {
        identifier
    }
    
    func pref(for key: String) -> Any? {
        nil
    }
    
    var doesNotRequireSpecialCaseHandling: Bool {
        Locale.identifierDoesNotRequireSpecialCaseHandling(identifier)
    }
}

#endif
