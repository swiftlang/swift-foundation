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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif // canImport(FoundationEssentials)

/**
 `Locale` encapsulates information about linguistic, cultural, and technological conventions and standards. Examples of information encapsulated by a locale include the symbol used for the decimal separator in numbers and the way dates are formatted.

 Locales are typically used to provide, format, and interpret information about and according to the user's customs and preferences. They are frequently used in conjunction with formatters. Although you can use many locales, you usually use the one associated with the current user.
*/
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Locale : Hashable, Equatable, Sendable {

#if FOUNDATION_FRAMEWORK
    public typealias LanguageDirection = NSLocale.LanguageDirection
#else
    public enum LanguageDirection : UInt, Sendable {
        /// The direction of the language is unknown.
        case unknown

        /// The language direction is from left to right.
        case leftToRight

        /// The language direction is from right to left.
        case rightToLeft

        /// The language direction is from top to bottom.
        case topToBottom

        /// The language direction is from bottom to top.
        case bottomToTop
    }
#endif

    internal enum Kind: Equatable, CustomDebugStringConvertible {
        case fixed(_Locale)
        case autoupdating
        #if FOUNDATION_FRAMEWORK
        case bridged(_NSLocaleSwiftWrapper)
        #endif

        public static func ==(lhs: Kind, rhs: Kind) -> Bool {
            switch lhs {
            case .autoupdating:
                switch rhs {
                case .autoupdating:
                    return true
                default:
                    return false
                }
            case .fixed(let lhsLocale):
                switch rhs {
                case .autoupdating:
                    return false
                case .fixed(let rhsLocale):
                    return lhsLocale == rhsLocale
#if FOUNDATION_FRAMEWORK
                case .bridged(let wrapper):
                    return lhsLocale.identifier == wrapper.identifier
#endif
                }
#if FOUNDATION_FRAMEWORK
            case .bridged(let wrapper):
                switch rhs {
                case .autoupdating:
                    return false
                case .fixed(let rhsLocale):
                    return rhsLocale.identifier == wrapper.identifier
                case .bridged(let rhsWrapper):
                    return wrapper == rhsWrapper
                }
#endif
            }
        }

        var debugDescription: String {
            switch self {
            case .fixed(_):
                return "fixed"
            case .autoupdating:
                return "autoupdating"
#if FOUNDATION_FRAMEWORK
            case .bridged(let wrapper):
                return wrapper.debugDescription
#endif
            }
        }
    }

    internal var kind: Kind

    /// Returns a locale which tracks the user's current preferences.
    ///
    /// If mutated, this Locale will no longer track the user's preferences.
    ///
    /// - note: The autoupdating Locale will only compare equal to another autoupdating Locale.
    public static var autoupdatingCurrent : Locale {
        return Locale(.autoupdating)
    }

    /// Returns the user's current locale.
    public static var current : Locale {
        return Locale(.fixed(LocaleCache.cache.current))
    }

    /// System locale.
    internal static var system : Locale {
        return Locale(.fixed(LocaleCache.cache.system))
    }

#if FOUNDATION_FRAMEWORK
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    internal static func localeAsIfCurrent(name: String?, cfOverrides: CFDictionary? = nil, disableBundleMatching: Bool = false) -> Locale {
        return LocaleCache.cache.localeAsIfCurrent(name: name, cfOverrides: cfOverrides, disableBundleMatching: disableBundleMatching)
    }
#endif
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    internal static func localeAsIfCurrent(name: String?, overrides: LocalePreferences? = nil, disableBundleMatching: Bool = false) -> Locale {
        // On Darwin, this overrides are applied on top of CFPreferences.
        return LocaleCache.cache.localeAsIfCurrent(name: name, overrides: overrides, disableBundleMatching: disableBundleMatching)
    }

    internal static func localeAsIfCurrentWithBundleLocalizations(_ availableLocalizations: [String], allowsMixedLocalizations: Bool) -> Locale? {
        return LocaleCache.cache.localeAsIfCurrentWithBundleLocalizations(availableLocalizations, allowsMixedLocalizations: allowsMixedLocalizations)
    }

    // MARK: -
    //

    /// Return a locale with the specified identifier.
    public init(identifier: String) {
        kind = .fixed(LocaleCache.cache.fixed(identifier))
    }

    /// Creates a `Locale` with the specified locale components
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(components: Locale.Components) {
        kind = .fixed(LocaleCache.cache.fixedComponents(components))
    }

    /// Creates a `Locale` with the specified language components
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(languageComponents: Locale.Language.Components) {
        self = Locale(identifier: languageComponents.identifier)
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(languageCode: LanguageCode? = nil, script: Script? = nil, languageRegion: Region? = nil) {
        let comps = Components(languageCode: languageCode, script: script, languageRegion: languageRegion)
        self = .init(components: comps)
    }

    /// To be used only by `LocaleCache`.
    internal init(_ kind: Kind) {
        self.kind = kind
    }


    internal init(identifier: String, calendarIdentifier: Calendar.Identifier, prefs: LocalePreferences?) {
        self.kind = .fixed(_Locale(identifier: identifier, prefs: prefs))
    }

    #if FOUNDATION_FRAMEWORK
    internal init(reference: __shared NSLocale) {
        if let swift = reference as? _NSSwiftLocale {
            kind = swift.locale.kind
        } else {
            // This is a custom NSLocale subclass
            kind = .bridged(_NSLocaleSwiftWrapper(adoptingReference: reference))
        }
    }

    /// Used by `Locale_Cache` for creating fixed `NSLocale` instances.
    internal init(inner: _Locale) {
        self.kind = .fixed(inner)
    }
    #endif

    /// Produce a copy of the `Locale` (including `LocalePreferences`, if present), but with a different `Calendar.Identifier`. Date formatting uses this.
    internal func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> Locale {
        switch kind {
        case .fixed(let l):
            return Locale(.fixed(l.copy(newCalendarIdentifier: identifier)))
        case .autoupdating:
            return Locale(.fixed(LocaleCache.cache.current.copy(newCalendarIdentifier: identifier)))
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            var comps = Locale.Components(identifier: l.identifier)
            comps.calendar = identifier
            return Locale(components: comps)
#endif
        }
    }

    // MARK: -
    //

    /// Returns a localized string for a specified identifier.
    ///
    /// For example, in the "en" locale, the result for `"es"` is `"Spanish"`.
    public func localizedString(forIdentifier identifier: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.identifierDisplayName(for: identifier)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.identifierDisplayName(for: identifier)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.identifierDisplayName(for: identifier)
        }
    }

    /// Returns a localized string for a specified language code.
    ///
    /// For example, in the "en" locale, the result for `"es"` is `"Spanish"`.
    public func localizedString(forLanguageCode languageCode: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.languageCodeDisplayName(for: languageCode)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.languageCodeDisplayName(for: languageCode)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.languageCodeDisplayName(for: languageCode)
        }
    }

    /// Returns a localized string for a specified region code.
    ///
    /// For example, in the "en" locale, the result for `"fr"` is `"France"`.
    public func localizedString(forRegionCode regionCode: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.countryCodeDisplayName(for: regionCode)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.countryCodeDisplayName(for: regionCode)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.countryCodeDisplayName(for: regionCode)
        }
    }

    /// Returns a localized string for a specified script code.
    ///
    /// For example, in the "en" locale, the result for `"Hans"` is `"Simplified Han"`.
    public func localizedString(forScriptCode scriptCode: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.scriptCodeDisplayName(for: scriptCode)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.scriptCodeDisplayName(for: scriptCode)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.scriptCodeDisplayName(for: scriptCode)
        }
    }

    /// Returns a localized string for a specified variant code.
    ///
    /// For example, in the "en" locale, the result for `"POSIX"` is `"Computer"`.
    public func localizedString(forVariantCode variantCode: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.variantCodeDisplayName(for: variantCode)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.variantCodeDisplayName(for: variantCode)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.variantCodeDisplayName(for: variantCode)
        }
    }

    /// Returns a localized string for a specified `Calendar.Identifier`.
    ///
    /// For example, in the "en" locale, the result for `.buddhist` is `"Buddhist Calendar"`.
    public func localizedString(for calendarIdentifier: Calendar.Identifier) -> String? {
        switch kind {
        case .fixed(let l):
            return l.calendarIdentifierDisplayName(for: calendarIdentifier)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.calendarIdentifierDisplayName(for: calendarIdentifier)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.calendarIdentifierDisplayName(for: calendarIdentifier)
        }
    }

    /// Returns a localized string for a specified ISO 4217 currency code.
    ///
    /// For example, in the "en" locale, the result for `"USD"` is `"US Dollar"`.
    /// - seealso: `Locale.isoCurrencyCodes`
    public func localizedString(forCurrencyCode currencyCode: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.currencyCodeDisplayName(for: currencyCode)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.currencyCodeDisplayName(for: currencyCode)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.currencyCodeDisplayName(for: currencyCode)
        }
    }

    /// This exists in `NSLocale` via the `displayName` API, using the currency *symbol* key instead of *code*.
    internal func localizedString(forCurrencySymbol currencySymbol: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.currencySymbolDisplayName(for: currencySymbol)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.currencySymbolDisplayName(for: currencySymbol)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.currencySymbolDisplayName(for: currencySymbol)
        }
    }
    
    /// Returns a localized string for a specified ICU collation identifier.
    ///
    /// For example, in the "en" locale, the result for `"phonebook"` is `"Phonebook Sort Order"`.
    public func localizedString(forCollationIdentifier collationIdentifier: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.collationIdentifierDisplayName(for: collationIdentifier)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.collationIdentifierDisplayName(for: collationIdentifier)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.collationIdentifierDisplayName(for: collationIdentifier)
        }
    }

    /// Returns a localized string for a specified ICU collator identifier.
    public func localizedString(forCollatorIdentifier collatorIdentifier: String) -> String? {
        switch kind {
        case .fixed(let l):
            return l.collatorIdentifierDisplayName(for: collatorIdentifier)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return l.collatorIdentifierDisplayName(for: collatorIdentifier)
#endif
        case .autoupdating:
            return LocaleCache.cache.current.collatorIdentifierDisplayName(for: collatorIdentifier)
        }
    }

    // MARK: -
    //

    /// Returns the identifier of the locale.
    public var identifier: String {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.identifier
        case .fixed(let l): return l.identifier
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.identifier
#endif
        }
    }

    /// Returns the language code of the locale, or nil if has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "zh".
    @available(macOS, deprecated: 13, renamed: "language.languageCode.identifier")
    @available(iOS, deprecated: 16, renamed: "language.languageCode.identifier")
    @available(tvOS, deprecated: 16, renamed: "language.languageCode.identifier")
    @available(watchOS, deprecated: 9, renamed: "language.languageCode.identifier")
    public var languageCode: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.languageCode
        case .fixed(let l): return l.languageCode
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.languageCode
#endif
        }
    }

    /// Returns the region code of the locale, or nil if it has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "HK".
    @available(macOS, deprecated: 13, renamed: "language.region.identifier")
    @available(iOS, deprecated: 16, renamed: "language.region.identifier")
    @available(tvOS, deprecated: 16, renamed: "language.region.identifier")
    @available(watchOS, deprecated: 9, renamed: "language.region.identifier")
    public var regionCode: String? {
        // n.b. this is called countryCode in ObjC
        let result: String?
        switch kind {
        case .autoupdating: result = LocaleCache.cache.current.region?.identifier
        case .fixed(let l): result = l.region?.identifier
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): result = l.countryCode
#endif
        }
        if let result, result.isEmpty {
            return nil
        }
        return result
    }

    /// Returns the script code of the locale, or nil if has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "Hant".
    @available(macOS, deprecated: 13, renamed: "language.script.identifier")
    @available(iOS, deprecated: 16, renamed: "language.script.identifier")
    @available(tvOS, deprecated: 16, renamed: "language.script.identifier")
    @available(watchOS, deprecated: 9, renamed: "language.script.identifier")
    public var scriptCode: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.scriptCode
        case .fixed(let l): return l.scriptCode
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.scriptCode
#endif
        }
    }

    /// Returns the variant code for the locale, or nil if it has none.
    ///
    /// For example, for the locale "en_POSIX", returns "POSIX".
    @available(macOS, deprecated: 13, renamed: "variant.identifier")
    @available(iOS, deprecated: 16, renamed: "variant.identifier")
    @available(tvOS, deprecated: 16, renamed: "variant.identifier")
    @available(watchOS, deprecated: 9, renamed: "variant.identifier")
    public var variantCode: String? {
        let result: String?
        switch kind {
        case .autoupdating: result = LocaleCache.cache.current.variantCode
        case .fixed(let l): result = l.variantCode
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): result = l.variantCode
#endif
        }
        if let result, result.isEmpty {
            return nil
        }
        return result
    }

#if FOUNDATION_FRAMEWORK
    /// Returns the exemplar character set for the locale, or nil if has none.
    public var exemplarCharacterSet: CharacterSet? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.exemplarCharacterSet
        case .fixed(let l): return l.exemplarCharacterSet
        case .bridged(let l): return l.exemplarCharacterSet
        }
    }
#endif

    /// Returns the calendar for the locale, or the Gregorian calendar as a fallback.
    public var calendar: Calendar {
        var cal: Calendar
        switch kind {
        case .autoupdating: cal = LocaleCache.cache.current.calendar
        case .fixed(let l): cal = l.calendar
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): cal = l.calendar
#endif
        }
        // TODO: This is a fairly expensive operation, because it recreates the Calendar's backing ICU object. However, we can't cache the value or we risk creating a retain cycle between _Calendar/_Locale. We'll need to sort out some way around this.
        // TODO: Calendar doesn't store a Locale anymore!
        cal.locale = self
        return cal
    }

    /// Returns the calendar identifier for the locale, or the Gregorian identifier as a fallback.
    /// Useful if you need the identifier but not a full instance of the `Calendar`.
    internal var _calendarIdentifier: Calendar.Identifier {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.calendarIdentifier
        case .fixed(let l): return l.calendarIdentifier
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.calendarIdentifier
#endif
        }
    }

    /// Returns the collation identifier for the locale, or nil if it has none.
    ///
    /// For example, for the locale "en_US@collation=phonebook", returns "phonebook".
    @available(macOS, deprecated: 13, renamed: "collation.identifier")
    @available(iOS, deprecated: 16, renamed: "collation.identifier")
    @available(tvOS, deprecated: 16, renamed: "collation.identifier")
    @available(watchOS, deprecated: 9, renamed: "collation.identifier")
    public var collationIdentifier: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.collationIdentifier
        case .fixed(let l): return l.collationIdentifier
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.collationIdentifier
#endif
        }
    }

    /// Returns true if the locale uses the metric system.
    ///
    /// -seealso: MeasurementFormatter
    @available(macOS, deprecated: 13, message: "Use `measurementSystem` instead")
    @available(iOS, deprecated: 16, message: "Use `measurementSystem` instead")
    @available(tvOS, deprecated: 16, message: "Use `measurementSystem` instead")
    @available(watchOS, deprecated: 9, message: "Use `measurementSystem` instead")
    public var usesMetricSystem: Bool {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.usesMetricSystem
        case .fixed(let l): return l.usesMetricSystem
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.usesMetricSystem
#endif
        }
    }

    /// Returns the decimal separator of the locale.
    ///
    /// For example, for "en_US", returns ".".
    public var decimalSeparator: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.decimalSeparator
        case .fixed(let l): return l.decimalSeparator
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.decimalSeparator
#endif
        }
    }

    /// Returns the grouping separator of the locale.
    ///
    /// For example, for "en_US", returns ",".
    public var groupingSeparator: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.groupingSeparator
        case .fixed(let l): return l.groupingSeparator
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.groupingSeparator
#endif
        }
    }

    /// Returns the currency symbol of the locale.
    ///
    /// For example, for "zh-Hant-HK", returns "HK$".
    public var currencySymbol: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.currencySymbol
        case .fixed(let l): return l.currencySymbol
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.currencySymbol
#endif
        }
    }

    /// Returns the currency code of the locale.
    ///
    /// For example, for "zh-Hant-HK", returns "HKD".
    @available(macOS, deprecated: 13, renamed: "currency.identifier")
    @available(iOS, deprecated: 16, renamed: "currency.identifier")
    @available(tvOS, deprecated: 16, renamed: "currency.identifier")
    @available(watchOS, deprecated: 9, renamed: "currency.identifier")
    public var currencyCode: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.currencyCode
        case .fixed(let l): return l.currencyCode
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.currencyCode
#endif
        }
    }

    /// Returns the collator identifier of the locale.
    public var collatorIdentifier: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.collatorIdentifier
        case .fixed(let l): return l.collatorIdentifier
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.collatorIdentifier
#endif
        }
    }

    /// Returns the quotation begin delimiter of the locale.
    ///
    /// For example, returns `“` for "en_US", and `「` for "zh-Hant-HK".
    public var quotationBeginDelimiter: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.quotationBeginDelimiter
        case .fixed(let l): return l.quotationBeginDelimiter
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.quotationBeginDelimiter
#endif
        }
    }

    /// Returns the quotation end delimiter of the locale.
    ///
    /// For example, returns `”` for "en_US", and `」` for "zh-Hant-HK".
    public var quotationEndDelimiter: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.quotationEndDelimiter
        case .fixed(let l): return l.quotationEndDelimiter
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.quotationEndDelimiter
#endif
        }
    }

    /// Returns the alternate quotation begin delimiter of the locale.
    ///
    /// For example, returns `‘` for "en_US", and `『` for "zh-Hant-HK".
    public var alternateQuotationBeginDelimiter: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.alternateQuotationBeginDelimiter
        case .fixed(let l): return l.alternateQuotationBeginDelimiter
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.alternateQuotationBeginDelimiter
#endif
        }
    }

    /// Returns the alternate quotation end delimiter of the locale.
    ///
    /// For example, returns `’` for "en_US", and `』` for "zh-Hant-HK".
    public var alternateQuotationEndDelimiter: String? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.alternateQuotationEndDelimiter
        case .fixed(let l): return l.alternateQuotationEndDelimiter
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return l.alternateQuotationEndDelimiter
#endif
        }
    }

    // MARK: - Components

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    /// Returns the measurement system of the locale. Returns `metric` as the default value if the data isn't available.
    public var measurementSystem: MeasurementSystem {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.measurementSystem
        case .fixed(let l): return l.measurementSystem
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).measurementSystem
#endif
        }
    }

    /// Returns the currency of the locale. Returns nil if the data isn't available.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var currency: Currency? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.currency
        case .fixed(let l): return l.currency
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).currency
#endif
        }
    }

    /// Returns the numbering system of the locale. If the locale has an explicitly specified numbering system in the identifier (e.g. `bn_BD@numbers=latn`) or in the associated `Locale.Components`, that numbering system is returned. Otherwise, returns the default numbering system of the locale. Returns `"latn"` as the default value if the data isn't available.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var numberingSystem: NumberingSystem {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.numberingSystem
        case .fixed(let l): return l.numberingSystem
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).numberingSystem
#endif
        }
    }

    /// Returns all the valid numbering systems for the locale. For example, `"ar-AE (Arabic (United Arab Emirates)"` has both `"latn" (Latin digits)` and `"arab" (Arabic-Indic digits)` numbering system.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var availableNumberingSystems: [NumberingSystem] {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.availableNumberingSystems
        case .fixed(let l): return l.availableNumberingSystems
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).availableNumberingSystems
#endif
        }
    }

    /// Returns the first day of the week of the locale. Returns `.sunday` as the default value if the data isn't available to the requested locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var firstDayOfWeek: Weekday {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.firstDayOfWeek
        case .fixed(let l): return l.firstDayOfWeek
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).firstDayOfWeek
#endif
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var language: Language {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.language
        case .fixed(let l): return l.language
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).language
#endif
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    /// Returns the identifier conforming to the specified standard
    public func identifier(_ type: IdentifierType) -> String {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.identifier(type)
        case .fixed(let l): return l.identifier(type)
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).identifier(type)
#endif
        }
    }

    /// Returns the hour cycle such as whether it uses 12-hour clock or 24-hour clock. Default is `.zeroToTwentyThree` if the data isn't available.
    /// Calling this on `.current` or `.autoupdatingCurrent` returns user's preference values as set in the system settings if available, overriding the default value of the user's locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var hourCycle: HourCycle {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.hourCycle
        case .fixed(let l): return l.hourCycle
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).hourCycle
#endif
        }
    }

    /// Returns the default collation used by the locale. Default is `.standard`.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var collation: Collation {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.collation
        case .fixed(let l): return l.collation
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).collation
#endif
        }
    }

    /// Returns the region of the locale. For example, "US" for "en_US", "GB" for "en_GB", "PT" for "pt_PT".
    ///
    ///
    /// note: Typically this is equivalent to the language region, unless there's an `rg` override in the locale identifier. For example, for "en_GB@rg=USzzzz", the language region is "GB", while the locale region is "US". `Language.region` represents the region variant of the language, such as "British English" in this example, while `Locale.region` controls the region-specific default values, such as measuring system and first day of the week.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var region: Region? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.region
        case .fixed(let l): return l.region
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).region
#endif
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var timeZone: TimeZone? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.timeZone
        case .fixed(let l): return l.timeZone
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).timeZone
#endif
        }
    }

    /// Returns the regional subdivision for the locale, or nil if there is none.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var subdivision: Subdivision? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.subdivision
        case .fixed(let l): return l.subdivision
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).subdivision
#endif
        }
    }

    /// Returns the variant for the locale, or nil if it has none. For example, for the locale "en_POSIX", returns "POSIX".
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var variant: Variant? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.variant
        case .fixed(let l): return l.variant
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).variant
#endif
        }
    }

    // MARK: - Preferences support (Internal)

    internal var force24Hour: Bool {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.force24Hour
        case .fixed(let l): return l.force24Hour
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return false
#endif
        }
    }

    internal var force12Hour: Bool {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.force12Hour
        case .fixed(let l): return l.force12Hour
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return false
#endif
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    internal func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Weekday? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.forceFirstWeekday(in: calendar)
        case .fixed(let l): return l.forceFirstWeekday(in: calendar)
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return nil
#endif
        }
    }

    internal func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.forceMinDaysInFirstWeek(in: calendar)
        case .fixed(let l): return l.forceMinDaysInFirstWeek(in: calendar)
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return nil
#endif
        }
    }

    internal func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        switch kind {
        case .fixed(let l):
            return l.customDateFormat(style)
        case .autoupdating:
            return LocaleCache.cache.current.customDateFormat(style)
#if FOUNDATION_FRAMEWORK
        case .bridged(_):
            return nil
#endif
        }
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    internal var forceMeasurementSystem: Locale.MeasurementSystem? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.forceMeasurementSystem
        case .fixed(let l): return l.forceMeasurementSystem
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return nil
#endif
        }
    }

#if FOUNDATION_FRAMEWORK // TODO: Reenable once UnitTemperature is moved
    internal var forceTemperatureUnit: UnitTemperature? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.forceTemperatureUnit
        case .fixed(let l): return l.forceTemperatureUnit
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return nil
#endif
        }
    }

    internal var temperatureUnit: UnitTemperature {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.temperatureUnit
        case .fixed(let l): return l.temperatureUnit
#if FOUNDATION_FRAMEWORK
        case .bridged(let l): return _Locale(identifier: l.identifier).temperatureUnit
#endif
        }
    }
#endif // FOUNDATION_FRAMEWORK
    
    /// The whole bucket of preferences.
    /// For use by `Calendar`, which wants to keep these values without a circular retain cycle with `Locale`. Only `current` locales and current-alikes have prefs.
    internal var prefs: LocalePreferences? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.prefs
        case .fixed(let l): return l.prefs
#if FOUNDATION_FRAMEWORK
        case .bridged(_): return nil
#endif
        }
    }
    
#if FOUNDATION_FRAMEWORK
    internal func pref(for key: String) -> Any? {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.pref(for: key)
        case .fixed(let l): return l.pref(for: key)
        case .bridged(_): return nil
        }
    }
#endif

    // MARK: -
    //

    /// Returns a list of available `Locale` identifiers.
    public static var availableIdentifiers: [String] {
        return Locale.availableLocaleIdentifiers
    }

    /// Returns a list of common `Locale` currency codes.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var commonISOCurrencyCodes: [String] {
        Locale.Currency.commonISOCurrencies
    }

    /// Returns a list of the user's preferred languages.
    ///
    /// - note: `Bundle` is responsible for determining the language that your application will run in, based on the result of this API and combined with the languages your application supports.
    /// - seealso: `Bundle.preferredLocalizations(from:)`
    /// - seealso: `Bundle.preferredLocalizations(from:forPreferences:)`
    public static var preferredLanguages: [String] {
        LocaleCache.cache.preferredLanguages(forCurrentUser: false)
    }

    private static let languageCodeKey = "kCFLocaleLanguageCodeKey"
    private static let scriptCodeKey = "kCFLocaleScriptCodeKey"
    private static let countryCodeKey = "kCFLocaleCountryCodeKey"
    private static let variantCodeKey = "kCFLocaleVariantCodeKey"
    private static let calendarKey = "kCFLocaleCalendarKey"

    /// Constructs an identifier from a dictionary of components.
    public static func identifier(fromComponents components: [String : String]) -> String {
        // Holds remaining keywords after we remove the CF-specific ones
        var keywords = components
        var result = ""
        if let language = components[Self.languageCodeKey] {
            result += language
            keywords.removeValue(forKey: Self.languageCodeKey)
        }
        if let script = components[Self.scriptCodeKey] {
            result += "_" + script
            keywords.removeValue(forKey: Self.scriptCodeKey)
        }
        let country = components[Self.countryCodeKey]
        let variant = components[Self.variantCodeKey]
        
        if country != nil || variant != nil {
            result += "_"
        }
        
        if let country {
            result += country
            keywords.removeValue(forKey: Self.countryCodeKey)
        }
        
        if let variant {
            result += "_" + variant
            keywords.removeValue(forKey: Self.variantCodeKey)
        }
                
        let corrected = Dictionary<String, String>(uniqueKeysWithValues: keywords.compactMap { key, value -> (String, String)? in
            // Keys must be non-empty
            guard !key.isEmpty else { return nil }
            
            // Identifier keywords must be ASCII a-z, A-Z, 0-9
            // They are normalized to all-lowercase
            var correctedKey : [CChar] = []
            for char in key.utf8 {
                if (0x41...0x5a).contains(char) {
                    // A-Z
                    // Convert to lowercase by adding 0x20
                    correctedKey.append(CChar(char + 0x20))
                } else if (0x61...0x7a).contains(char) {
                    // a-z
                    correctedKey.append(CChar(char))
                } else if (0x30...0x39).contains(char) {
                    // 0-9
                    correctedKey.append(CChar(char))
                } else {
                    // Skip this key
                    return nil
                }
            }
            // null-terminate
            correctedKey.append(CChar(0))
            
            let correctedKeyString = String(cString: correctedKey)
            
            // Values must be non-empty
            guard !value.isEmpty else { return nil }
            
            // Values must be ASCII a-z, A-Z, 0-9, _, -, +, /
            let validValue = value.utf8.allSatisfy { char in
                /* A-Z */ (0x41...0x5a).contains(char) ||
                /* a-z */ (0x61...0x7a).contains(char) ||
                /* 0-9 */ (0x30...0x39).contains(char) ||
                /* _   */ char == 0x5f ||
                /* -   */ char == 0x2d ||
                /* +   */ char == 0x2b ||
                /* /   */ char == 0x2f
            }
            
            guard validValue else { return nil }
                
            return (correctedKeyString, value)
        })
        
        guard !corrected.isEmpty else {
            // Stop here
            return result
        }
        
        result += "@"
        let sortedKeys = corrected.keys.sorted(by: <)
        
        for key in sortedKeys {
            result += key + "=" + corrected[key]! + ";"
        }
        
        // Remove last ;
        let _ = result.popLast()

        return result
    }

#if FOUNDATION_FRAMEWORK
    /// Constructs an identifier from a dictionary of components, allowing a `Calendar` value. Compatibility only.
    internal static func identifier(fromAnyComponents components: [String : Any]) -> String {
        // n.b. the CFLocaleCreateLocaleIdentifierFromComponents API is normally [String: String], but for 'convenience' allows a `Calendar` value for "kCFLocaleCalendarKey"/"calendar". This version for framework use allows Calendar.
        
        // Handle a special case of having both "kCFLocaleCalendarKey" and "calendar"
        var uniqued = components
        if let calendar = uniqued[Self.calendarKey] as? Calendar {
            // Overwrite any value for "calendar" - the CF key takes precedence
            uniqued["calendar"] = calendar.identifier.cfCalendarIdentifier
        }
        
        // Always remove this key
        uniqued.removeValue(forKey: Self.calendarKey)
        
        // Map the remaining values to strings, or remove them
        let converted = Dictionary<String, String>(uniqueKeysWithValues: uniqued.compactMap { key, value in
            if let value = value as? String {
                return (key, value)
            } else {
                // Remove this, bad value type
                return nil
            }
        })
        
        return identifier(fromComponents: converted)
    }
#endif // FOUNDATION_FRAMEWORK


    /// Returns a canonical identifier from the given string.
    @available(macOS, deprecated: 13, renamed: "identifier(_:from:)")
    @available(iOS, deprecated: 16, renamed: "identifier(_:from:)")
    @available(tvOS, deprecated: 16, renamed: "identifier(_:from:)")
    @available(watchOS, deprecated: 9, renamed: "identifier(_:from:)")
    public static func canonicalIdentifier(from string: String) -> String {
#if FOUNDATION_FRAMEWORK
        CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorSystemDefault, string as CFString).rawValue as String
#else
        // TODO: (Locale.canonicalIdentifier) implement in Swift: https://github.com/apple/swift-foundation/issues/45
        return string
#endif // FOUNDATION_FRAMEWORK
    }

    /// Same as `canonicalIdentifier` but not deprecated, for internal usage. Also, it handles a nil result (e.g. non-ASCII identifier input) correctly.
    internal static func _canonicalLocaleIdentifier(from string: String) -> String {
#if FOUNDATION_FRAMEWORK
        if let id = CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorSystemDefault, string as CFString) {
            return id.rawValue as String
        } else {
            return ""
        }
#else
        // TODO: (Locale.canonicalIdentifier) implement in Swift: https://github.com/apple/swift-foundation/issues/45
        return string
#endif // FOUNDATION_FRAMEWORK
    }

    /// Returns a canonical language identifier from the given string.
    public static func canonicalLanguageIdentifier(from string: String) -> String {
#if FOUNDATION_FRAMEWORK
        if let id = CFLocaleCreateCanonicalLanguageIdentifierFromString(kCFAllocatorSystemDefault, string as CFString) {
            return id.rawValue as String
        } else {
            return ""
        }
#else
        // TODO: (Locale.canonicalLanguageIdentifier) Implement in Swift: https://github.com/apple/swift-foundation/issues/45
        return string
#endif // FOUNDATION_FRAMEWORK
    }

    /// Returns the `Locale` identifier from a given Windows locale code, or nil if it could not be converted.
    public static func identifier(fromWindowsLocaleCode code: Int) -> String? {
        _Locale.identifierFromWindowsLocaleCode(UInt32(code))
    }

    /// Returns the Windows locale code from a given identifier, or nil if it could not be converted.
    public static func windowsLocaleCode(fromIdentifier identifier: String) -> Int? {
        _Locale.windowsLocaleCode(from: identifier)
    }

    // MARK: -

    /// Returns `true` if the locale is one of the "special" languages that requires special handling during case mapping.
    /// - "az": Azerbaijani
    /// - "lt": Lithuanian
    /// - "tr": Turkish
    /// - "nl": Dutch
    /// - "el": Greek
    /// For all other locales such as en_US, this is `false`.
    internal var doesNotRequireSpecialCaseHandling: Bool {
        switch kind {
        case .autoupdating: return LocaleCache.cache.current.doesNotRequireSpecialCaseHandling
        case .fixed(let l): return l.doesNotRequireSpecialCaseHandling
#if FOUNDATION_FRAMEWORK
        case .bridged(let l):
            return _Locale.identifierDoesNotRequireSpecialCaseHandling(l.identifier)
#endif
        }
    }

    // MARK: -
    //

    public func hash(into hasher: inout Hasher) {
        switch kind {
        case .fixed(let inner):
            hasher.combine(true)
            hasher.combine(inner)
        case .autoupdating:
            hasher.combine(false)
#if FOUNDATION_FRAMEWORK
        case .bridged(let inner):
            hasher.combine(false)
            inner.hash(into: &hasher)
#endif
        }
    }

    public static func ==(lhs: Locale, rhs: Locale) -> Bool {
        lhs.kind == rhs.kind
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Locale : CustomDebugStringConvertible, CustomStringConvertible, CustomReflectable {
    public var customMirror : Mirror {
        var c: [(label: String?, value: Any)] = []
        c.append((label: "identifier", value: identifier))
        c.append((label: "kind", value: kind.debugDescription))
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }

    public var description: String {
        return "\(identifier) (\(kind))"
    }

    public var debugDescription : String {
        description
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Locale : Codable {
    private enum CodingKeys : Int, CodingKey {
        case identifier
        case current
    }

    // CFLocale enforces a rule that fixed/current/autoupdatingCurrent can never be equal even if their values seem like they are the same
    private enum Current : Int, Codable {
        case fixed
        case current
        case autoupdatingCurrent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let current = try container.decodeIfPresent(Current.self, forKey: .current) {
            switch current {
            case .autoupdatingCurrent:
                self = Locale.autoupdatingCurrent
                return
            case .current:
                self = Locale.current
                return
            case .fixed:
                // Fall through to identifier-based
                break
            }
        }

        let identifier = try container.decode(String.self, forKey: .identifier)
        self.init(identifier: identifier)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Even if we are current/autoupdatingCurrent, encode the identifier for backward compatibility
        try container.encode(self.identifier, forKey: .identifier)

        if self == Locale.autoupdatingCurrent {
            try container.encode(Current.autoupdatingCurrent, forKey: .current)
        } else if self == Locale.current {
            try container.encode(Current.current, forKey: .current)
        } else {
            try container.encode(Current.fixed, forKey: .current)
        }
    }
}
