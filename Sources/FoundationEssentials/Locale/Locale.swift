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

/// Information about linguistic, cultural, and technological conventions for use in formatting data for presentation.
///
/// `Locale` encapsulates information about linguistic, cultural, and technological conventions and standards. Examples of information encapsulated by a locale include the symbol used for the decimal separator in numbers and the formatting conventions for dates and times.
///
/// Apps use locales to provide, format, and interpret information about and according to the user's customs and preferences. Data formatting APIs commonly make use of locales to present data in a locale-appropriate way.
///
/// You can create a `Locale` from a common identifier like `en-US`, or by specifying its components. More commonly, you access the current system locale with the ``current`` or ``autoupdatingCurrent`` static variables.
///
/// ### Working with locale components
///
/// A `Locale` exposes its various traits — the appropriate measurement system, currency symbols, date and time conventions, and more — as strongly-typed properties like ``currency``, `numberingSystem`, and `firstDayOfWeek`.
///
/// In addition, the ``language`` property allows you examine traits of languages, through the ``Language`` type, in contast with `NSLocale`, where `NSLocale.languageCode` is just a string identifier. You can use a locale's language to compare whether two locales use the same language, or if one language is a parent of another.
///
/// The following example creates a `Locale` from the identifier `zh-CN`, for Chinese. It then accesses this locale's ``language`` to get the language's ``Language/script``, and uses a US English locale to get a localized string describing the script: "Simplified Han". With the locale `zh-Hant-CN`, for Traditional Chinese, the script would be "Traditional Han" instead.
///
/// ```swift
/// let zhCN = Locale(identifier: "zh-CN")
/// if let script = zhCN.language.script {
///     let enUS = Locale(identifier: "en-US")
///     let localizedScript = enUS.localizedString(forScript: script) // "Simplified Han"
/// }
/// ```
///
/// ### Creating custom locales from components
///
/// You can create a custom locale by creating a `Locale` instance from a customized ``Components``. Do this when you want to tweak specific aspects of a locale. The following example creates a locale that uses language conventions of British English (language region `GB`), but otherwise uses US conventions for things like currency and measurement.
///
/// ```swift
/// var components = Locale.Components(languageCode: "en", languageRegion: "GB")
/// components.region = Locale.Region("US")
/// let en_GB_US = Locale(components: components)
/// ```
///
/// Creating a custom locale like this isn't necessarily common in apps, but can be useful in unit testing your app's localizations.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Locale : Hashable, Equatable, Sendable {

#if FOUNDATION_FRAMEWORK
    /// An alias for the standard set of language directions.
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

    /// A type that indicates the standard that defines a locale's identifier.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public enum IdentifierType : Sendable {
        /* This canonicalizes the identifier */
        /// The type of identifiers that follow ICU (International Components for Unicode) conventions.
        ///
        /// An example of this type is `th_TH@calendar=gregorian;numbers=thai`.
        case icu

        /* This would be a canonicalized "Unicode BCP 47 locale identifier", not a "BCP 47 language tag", per https://www.unicode.org/reports/tr35/#BCP_47_Language_Tag_Conversion */
        /// The type of BCP 47 language identifiers.
        ///
        /// An example of this type is `th-TH-u-ca-gregory-nu-thai`.
        case bcp47

        /// The type of identifiers that follow CLDR (Common Locale Data Repository) conventions.
        ///
        /// The components in this type of identifier use the same components as in ``Locale/IdentifierType/icu``, but don't use the key-value type keyword list. An example of this type is `th_TH_u_ca_gregory_nu_thai`.
        case cldr
    }

    internal var _locale: any _LocaleProtocol

    /// A locale which tracks the user's current preferences.
    ///
    /// This value represents the locale currently used by the app, based on the following:
    ///
    /// * The current system locale.
    /// * Any app-specific locale choice made in the Settings app.
    /// * The availability of the preferred locale in the app. For example, if the person using an app has set their device to use a Spanish-language locale, but the app only supports English, this value returns an English locale.
    ///
    /// Use this property when you want a locale that always reflects the latest configuration settings. When the person using the app changes settings, reading properties from a locale instance obtained from this property provides the latest values. If you need to rely on a locale that does not change, use the locale given by the ``Locale/current`` property instead.
    ///
    /// Although the locale obtained here automatically follows the latest language and region settings, it provides no indication when the settings change. To receive notification of locale changes in Swift, add an observer for ``Locale/CurrentLocaleDidChangeMessage``. In Objective-C, you can add your object as an observer of `NSCurrentLocaleDidChangeNotification`.
    ///
    /// If mutated, this `Locale` no longer tracks the user's preferences.
    ///
    /// - Note: The autoupdating `Locale` only compares as equal to another autoupdating `Locale`.
    public static var autoupdatingCurrent : Locale {
        Locale(inner: LocaleCache.autoupdatingCurrent)
    }

    /// A locale representing the user's region settings at the time the property is read.
    ///
    /// This value represents the locale currently used by the app, based on the following:
    ///
    /// * The current system locale.
    /// * Any app-specific locale choice made in the Settings app.
    /// * The availability of the preferred locale in the app. For example, if the person using an app has set their device to use a Spanish-language locale, but the app only supports English, this value returns an English locale.
    ///
    /// Use this property when you need to rely on a consistent locale. A locale instance obtained this way does not change even when the person using the device changes language or region settings. If you want a locale instance that always reflects the current configuration, use the one provided by the ``Locale/autoupdatingCurrent`` property instead.
    ///
    /// To receive notification of locale changes in Swift, add an observer for ``Locale/CurrentLocaleDidChangeMessage``. In Objective-C, you can add your object as an observer of ``NSLocale/currentLocaleDidChangeNotification``.
    public static var current : Locale {
        Locale(inner: LocaleCache.cache.current)
    }

    /// System locale.
    internal static var system : Locale {
        Locale(inner: LocaleCache.system)
    }
    
    /// Unlocalized locale (`en_001`).
    package static var unlocalized : Locale {
        Locale(inner: LocaleCache.unlocalized)
    }

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
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
    
    internal static func localeWithPreferences(identifier: String, preferences: LocalePreferences) -> Locale {
        return LocaleCache.cache.localeWithPreferences(identifier: identifier, prefs: preferences)
    }

    internal static func localeAsIfCurrentWithBundleLocalizations(_ availableLocalizations: [String], allowsMixedLocalizations: Bool) -> Locale? {
        return LocaleCache.cache.localeAsIfCurrentWithBundleLocalizations(availableLocalizations, allowsMixedLocalizations: allowsMixedLocalizations)
    }

    // MARK: -
    //

    /// Creates a locale with the specified identifier.
    ///
    /// - Parameter identifier: A BCP-47 language identifier such as `en_US` or `en-u-nu-thai-ca-buddhist`, or an ICU-style identifier such as `en@calendar=buddhist;numbers=thai`.
    public init(identifier: String) {
        _locale = LocaleCache.cache.fixed(identifier)
    }

    /// Creates a locale from the given components.
    ///
    /// Use this initializer to create a locale with a unique combination of components, beyond the defaults provided by a language and country code.
    ///
    /// For example, you can create a ``Locale/Components`` instance that uses UK language conventions, but US regional conventions for traits like currency and measurement. You then use the components to create a new `Locale` instance, like this:
    ///
    /// ```swift
    /// var components = Locale.Components(languageCode: "en", languageRegion: "GB")
    /// components.region = Locale.Region("US")
    /// let en_GB_US = Locale(components: components)
    /// ```
    ///
    /// - Parameter components: A ``Locale/Components`` instance that provides the components to create a customized locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(components: Locale.Components) {
        _locale = LocaleCache.cache.fixedComponents(components)
    }

    /// Creates a locale from the given language components.
    ///
    /// - Parameter languageComponents: A ``Locale/Language/Components`` instance that provides language components that identify a locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(languageComponents: Locale.Language.Components) {
        self = Locale(identifier: languageComponents.identifier)
    }

    /// Creates a locale with the specified language code, script, and region identifier.
    ///
    /// - Parameters:
    ///   - languageCode: A language code, typically created from a two- or three-letter language code specified by ISO 639.
    ///   - script: The script to use for the new locale components instance.
    ///   - languageRegion: A language region, typically created from a two-letter BCP 47 region subtag like `US`.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public init(languageCode: LanguageCode? = nil, script: Script? = nil, languageRegion: Region? = nil) {
        let comps = Components(languageCode: languageCode, script: script, languageRegion: languageRegion)
        self = .init(components: comps)
    }

    #if FOUNDATION_FRAMEWORK
    internal init(reference: __shared NSLocale) {
        if let swift = reference as? _NSSwiftLocale {
            _locale = swift.locale._locale
        } else {
            // This is a custom NSLocale subclass
            _locale = _LocaleBridged(adoptingReference: reference)
        }
    }
    #endif

    /// Used by `Locale_Cache` for creating fixed `NSLocale` instances.
    internal init(inner: any _LocaleProtocol) {
        _locale = inner
    }

    /// Used by `Calendar` to get a `Locale` with a specific identifier and preferences.
    package init(identifier: String, preferences: LocalePreferences?) {
        self = LocaleCache.cache.localeWithPreferences(identifier: identifier, prefs: preferences)
    }
    
    /// Produce a copy of the `Locale` (including `LocalePreferences`, if present), but with a different `Calendar.Identifier`. Date formatting uses this.
    internal func copy(newCalendarIdentifier identifier: Calendar.Identifier) -> Locale {
        Locale(inner: _locale.copy(newCalendarIdentifier: identifier))
    }

    // MARK: -
    //

    /// Returns a localized string for a specified locale identifier.
    ///
    /// For example, in the "en" locale, the result for `"es"` is `"Spanish"`.
    public func localizedString(forIdentifier identifier: String) -> String? {
        _locale.identifierDisplayName(for: identifier)
    }

    /// Returns a localized string for a specified language code.
    ///
    /// For example, in the "en" locale, the result for `"es"` is `"Spanish"`.
    public func localizedString(forLanguageCode languageCode: String) -> String? {
        _locale.languageCodeDisplayName(for: languageCode)
    }

    /// Returns a localized string for a specified region code.
    ///
    /// For example, in the "en" locale, the result for `"fr"` is `"France"`.
    public func localizedString(forRegionCode regionCode: String) -> String? {
        _locale.countryCodeDisplayName(for: regionCode)
    }

    /// Returns a localized string for a specified script code.
    ///
    /// For example, in the "en" locale, the result for `"Hans"` is `"Simplified Han"`.
    public func localizedString(forScriptCode scriptCode: String) -> String? {
        _locale.scriptCodeDisplayName(for: scriptCode)
    }

    /// Returns a localized string for a specified variant code.
    ///
    /// For example, in the "en" locale, the result for `"POSIX"` is `"Computer"`.
    public func localizedString(forVariantCode variantCode: String) -> String? {
        _locale.variantCodeDisplayName(for: variantCode)
    }

    /// Returns a localized string for a specified calendar.
    ///
    /// For example, in the "en" locale, the result for `.buddhist` is `"Buddhist Calendar"`.
    public func localizedString(for calendarIdentifier: Calendar.Identifier) -> String? {
        _locale.calendarIdentifierDisplayName(for: calendarIdentifier)
    }

    /// Returns a localized string for a specified ISO 4217 currency code.
    ///
    /// For example, in the "en" locale, the result for `"USD"` is `"US Dollar"`.
    /// - SeeAlso: `Locale.isoCurrencyCodes`
    public func localizedString(forCurrencyCode currencyCode: String) -> String? {
        _locale.currencyCodeDisplayName(for: currencyCode)
    }

    /// This exists in `NSLocale` via the `displayName` API, using the currency *symbol* key instead of *code*.
    internal func localizedString(forCurrencySymbol currencySymbol: String) -> String? {
        _locale.currencySymbolDisplayName(for: currencySymbol)
    }
    
#if !FOUNDATION_FRAMEWORK
    @_spi(SwiftCorelibsFoundation) public func _localizedString(forCurrencySymbol currencySymbol: String) -> String? {
        localizedString(forCurrencySymbol: currencySymbol)
    }
#endif
    
    /// Returns a localized string for a specified ICU collation identifier.
    ///
    /// For example, in the "en" locale, the result for `"phonebook"` is `"Phonebook Sort Order"`.
    public func localizedString(forCollationIdentifier collationIdentifier: String) -> String? {
        _locale.collationIdentifierDisplayName(for: collationIdentifier)
    }

    /// Returns a localized string for a specified ICU collator identifier.
    public func localizedString(forCollatorIdentifier collatorIdentifier: String) -> String? {
        _locale.collatorIdentifierDisplayName(for: collatorIdentifier)
    }

    // MARK: -
    //

    /// The identifier of the locale.
    public var identifier: String {
        @_effects(releasenone)
        get {
            _locale.identifier
        }
    }

    /// The language code of the locale, or `nil` if has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "zh".
    @available(macOS, deprecated: 13, renamed: "language.languageCode.identifier")
    @available(iOS, deprecated: 16, renamed: "language.languageCode.identifier")
    @available(tvOS, deprecated: 16, renamed: "language.languageCode.identifier")
    @available(watchOS, deprecated: 9, renamed: "language.languageCode.identifier")
    public var languageCode: String? {
        _locale.languageCode
    }

    /// The region code of the locale, or `nil` if it has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "HK".
    @available(macOS, deprecated: 13, renamed: "region.identifier")
    @available(iOS, deprecated: 16, renamed: "region.identifier")
    @available(tvOS, deprecated: 16, renamed: "region.identifier")
    @available(watchOS, deprecated: 9, renamed: "region.identifier")
    public var regionCode: String? {
        // n.b. this is called countryCode in ObjC
        let result = _locale.regionCode
        if let result, result.isEmpty {
            return nil
        }
        return result
    }

    /// The script code of the locale, or `nil` if has none.
    ///
    /// For example, for the locale "zh-Hant-HK", returns "Hant".
    @available(macOS, deprecated: 13, renamed: "language.script.identifier")
    @available(iOS, deprecated: 16, renamed: "language.script.identifier")
    @available(tvOS, deprecated: 16, renamed: "language.script.identifier")
    @available(watchOS, deprecated: 9, renamed: "language.script.identifier")
    public var scriptCode: String? {
        _locale.scriptCode
    }

    /// The variant code for the locale, or `nil` if it has none.
    ///
    /// For example, for the locale "en_POSIX", returns "POSIX".
    @available(macOS, deprecated: 13, renamed: "variant.identifier")
    @available(iOS, deprecated: 16, renamed: "variant.identifier")
    @available(tvOS, deprecated: 16, renamed: "variant.identifier")
    @available(watchOS, deprecated: 9, renamed: "variant.identifier")
    public var variantCode: String? {
        let result = _locale.variantCode
        if let result, result.isEmpty {
            return nil
        }
        return result
    }

#if FOUNDATION_FRAMEWORK
    /// The exemplar character set for the locale, or `nil` if has none.
    public var exemplarCharacterSet: CharacterSet? {
        _locale.exemplarCharacterSet
    }
#endif

    /// The calendar for the locale, or the Gregorian calendar as a fallback.
    public var calendar: Calendar {
        var cal = _locale.calendar
        // This is a fairly expensive operation, because it recreates the Calendar's backing ICU object.
        // However, we can't cache `struct Calendar` because it would create a retain cycle between _Calendar/_Locale:
        // struct Calendar -> inner _Calendar: any _CalendarProtocol -> struct Locale -> inner _Locale: any _LocaleProtocol -> struct Calendar...
        // _Calendar holds a Locale for performance reasons
        cal.locale = self
        return cal
    }

    /// Returns the calendar identifier for the locale, or the Gregorian identifier as a fallback.
    /// Useful if you need the identifier but not a full instance of the `Calendar`.
    package var _calendarIdentifier: Calendar.Identifier {
        _locale.calendarIdentifier
    }
    
#if !FOUNDATION_FRAMEWORK
    @_spi(SwiftCorelibsFoundation) public var __calendarIdentifier: Calendar.Identifier {
        _calendarIdentifier
    }
#endif

    /// The collation identifier for the locale, or `nil` if it has none.
    ///
    /// For example, for the locale "en_US@collation=phonebook", returns "phonebook".
    @available(macOS, deprecated: 13, renamed: "collation.identifier")
    @available(iOS, deprecated: 16, renamed: "collation.identifier")
    @available(tvOS, deprecated: 16, renamed: "collation.identifier")
    @available(watchOS, deprecated: 9, renamed: "collation.identifier")
    public var collationIdentifier: String? {
        _locale.collationIdentifier
    }

    /// A Boolean that is true if the locale uses the metric system.
    ///
    /// - SeeAlso: `MeasurementFormatter`
    @available(macOS, deprecated: 13, message: "Use `measurementSystem` instead")
    @available(iOS, deprecated: 16, message: "Use `measurementSystem` instead")
    @available(tvOS, deprecated: 16, message: "Use `measurementSystem` instead")
    @available(watchOS, deprecated: 9, message: "Use `measurementSystem` instead")
    public var usesMetricSystem: Bool {
        _locale.usesMetricSystem
    }

    /// The decimal separator of the locale.
    ///
    /// For example, for "en_US", returns ".".
    public var decimalSeparator: String? {
        _locale.decimalSeparator
    }

    /// The grouping separator of the locale.
    ///
    /// For example, for "en_US", returns ",".
    public var groupingSeparator: String? {
        _locale.groupingSeparator
    }

    /// The currency symbol of the locale.
    ///
    /// For example, for "zh-Hant-HK", returns "HK$".
    public var currencySymbol: String? {
        _locale.currencySymbol
    }

    /// The currency code of the locale.
    ///
    /// For example, for "zh-Hant-HK", returns "HKD".
    @available(macOS, deprecated: 13, renamed: "currency.identifier")
    @available(iOS, deprecated: 16, renamed: "currency.identifier")
    @available(tvOS, deprecated: 16, renamed: "currency.identifier")
    @available(watchOS, deprecated: 9, renamed: "currency.identifier")
    public var currencyCode: String? {
        _locale.currencyCode
    }

    /// The collator identifier of the locale.
    public var collatorIdentifier: String? {
        _locale.collatorIdentifier
    }

    /// The quotation begin delimiter of the locale.
    ///
    /// For example, returns `\u{201C}` for “en_US”, and `\u{300C}` for “zh-Hant-HK”.
    public var quotationBeginDelimiter: String? {
        _locale.quotationBeginDelimiter
    }

    /// The quotation end delimiter of the locale.
    ///
    /// For example, returns `\u{201D}` for “en_US”, and `\u{300D}` for “zh-Hant-HK”.
    public var quotationEndDelimiter: String? {
        _locale.quotationEndDelimiter
    }

    /// The alternate quotation begin delimiter of the locale.
    ///
    /// For example, returns `\u{2018}` for "en_US", and `\u{300E}` for "zh-Hant-HK".
    public var alternateQuotationBeginDelimiter: String? {
        _locale.alternateQuotationBeginDelimiter
    }

    /// The alternate quotation end delimiter of the locale.
    ///
    /// For example, returns `\u{2019}` for "en_US", and `\u{300F}` for "zh-Hant-HK".
    public var alternateQuotationEndDelimiter: String? {
        _locale.alternateQuotationEndDelimiter
    }

    // MARK: - Components

    /// The measurement system used by the locale, like metric or the US system.
    ///
    /// When called on the special `Locale` instances ``current`` or ``autoupdatingCurrent``, if the user overrode the default measurement system, this property provides the user's preference.
    ///
    /// This property corresponds to the `ms` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `ms` specifier (such as `en-US@ms=metric`), or with a custom ``Locale/Components``, this property represents the custom measurement system. Otherwise, it represents the locale's default measurement system.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var measurementSystem: MeasurementSystem {
        _locale.measurementSystem
    }

    /// The currency used by the locale.
    ///
    /// This property corresponds to the `cu` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `cu` specifier (such as `en-US@cu=cad`), or with a custom ``Locale/Components``, this property represents the custom currency. Otherwise, it represents the locale's default currency.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var currency: Currency? {
        _locale.currency
    }

    /// The numbering system used by the locale.
    ///
    /// This property corresponds to the `nu` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `nu` specifier (such as `en-US@nu=jpanfin`), or with a custom ``Locale/Components``, this property represents the custom numbering system. Otherwise, it represents the locale's default numbering system.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var numberingSystem: NumberingSystem {
        _locale.numberingSystem
    }

    /// An array containing all the valid numbering systems for the locale.
    ///
    /// The following snippet creates a locale for Arabic as used in United Arab Emirates. For this locale, there are two numbering systems available: `latn` (Latin digits) and `arab` (Arabic-Indic digits).
    ///
    /// ```swift
    /// let uae = Locale(identifier: "ar-AE") // Arabic / U.A.E.
    /// let numberingSystems = uae.availableNumberingSystems
    /// print("\(numberingSystems.map{$0.identifier})") // ["latn","arab"]
    /// ```
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var availableNumberingSystems: [NumberingSystem] {
        _locale.availableNumberingSystems
    }

    /// The first day of the week as represented by this locale.
    ///
    /// This value is the preferred first day of the week to show in a calendar view. It isn't necessarily the same as the first day after the weekend; don't try to determine a first-day-of-week value from weekend information.
    ///
    /// This property corresponds to the `fw` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `fw` specifier (such as `en-US@fw=mon`), or with a custom ``Locale/Components``, this property represents the custom day. Otherwise, it represents the locale's default first day of the week.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var firstDayOfWeek: Weekday {
        _locale.firstDayOfWeek
    }

    /// The language of the locale.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var language: Language {
        _locale.language
    }

    /// Returns the locale identifier, in the specified standard format.
    ///
    /// - Parameter type: The standard locale identifier format to use for the returned string.
    /// - Returns: The locale identifier, formatted in accordance with the specified identifier type.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public func identifier(_ type: IdentifierType) -> String {
        _locale.identifier(type)
    }

    /// The hour cycle used by the locale, like one-to-twelve or zero-to-twenty-three.
    ///
    /// When called on the special `Locale` instances ``current`` or ``autoupdatingCurrent``, if the user overrode the default hour cycle, this property provides the user's preference.
    ///
    /// This property corresponds to the `hc` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `hc` specifier (such as `en-US@hc=h23`), or with a custom ``Locale/Components``, this property represents the custom hour cycle. Otherwise, it represents the locale's default hour cycle.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var hourCycle: HourCycle {
        _locale.hourCycle
    }

    /// The string sort order of the locale.
    ///
    /// This property corresponds to the `co` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `co` specifier (such as `en-US@co=phonetic`), or with a custom ``Locale/Components``, this property represents the custom collation. Otherwise, it represents the locale's default sort order.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var collation: Collation {
        _locale.collation
    }

    /// The region used by the locale.
    ///
    /// This property corresponds to the `rg` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `rg` specifier (such as `en-GB@rg=US`), or with a custom ``Locale/Components``, this property represents the custom region. Otherwise, it represents the language's region.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var region: Region? {
        _locale.region
    }

    /// The time zone associated with the locale, if any.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var timeZone: TimeZone? {
        _locale.timeZone
    }

    /// The optional subdivision of the region used by this locale.
    ///
    /// This property corresponds to the `sd` key of the Unicode BCP 47 extension.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var subdivision: Subdivision? {
        _locale.subdivision
    }

    /// An optional variant used by the locale.
    ///
    /// This property corresponds to the `va` key of the Unicode BCP 47 extension.
    ///
    /// For locale instances created with the `va` specifier (such as `en-US@va=posix`), or with a custom ``Locale/Components``, this property represents the custom variant. Otherwise, it represents the locale's default variant.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public var variant: Variant? {
        _locale.variant
    }

    internal var weekendRange: WeekendRange? {
        _locale.weekendRange
    }

    internal var minimumDaysInFirstWeek: Int {
        _locale.minimumDaysInFirstWeek
    }
    
    // MARK: - Preferences support (Internal)

    package var forceHourCycle: HourCycle? {
        _locale.forceHourCycle
    }

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    package func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Weekday? {
        _locale.forceFirstWeekday(calendar)
    }

    package func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        _locale.forceMinDaysInFirstWeek(calendar)
    }

#if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
    // This is framework-only because Date.FormatStyle.DateStyle is Internationalization-only.
    package func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        _locale.customDateFormat(style)
    }
#endif

    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    package var forceMeasurementSystem: Locale.MeasurementSystem? {
        _locale.forceMeasurementSystem
    }

    package var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
        _locale.forceTemperatureUnit
    }

    package var temperatureUnit: LocalePreferences.TemperatureUnit {
        _locale.temperatureUnit
    }
    
    /// The whole bucket of preferences.
    /// For use by `Calendar`, which wants to keep these values without a circular retain cycle with `Locale`. Only `current` locales and current-alikes have prefs.
    package var prefs: LocalePreferences? {
        _locale.prefs
    }
    
#if FOUNDATION_FRAMEWORK
    internal func pref(for key: String) -> Any? {
        _locale.pref(for: key)
    }
#endif

    // Returns an identifier that includes preferences as keywords, such as "en_US@measure=metric" or "en_GB@hours=h12"
    package var identifierCapturingPreferences: String {
        _locale.identifierCapturingPreferences
    }


    // MARK: -
    //

    /// A list of the user's preferred languages.
    ///
    /// Returns a list of the user's preferred languages, as specified in Language & Region settings, taking into account any per-app language overrides.
    ///
    /// - Note: `Bundle` is responsible for determining the language that your application will run in, based on the result of this API and combined with the languages your application supports.
    /// - SeeAlso: `Bundle.preferredLocalizations(from:)`
    /// - SeeAlso: `Bundle.preferredLocalizations(from:forPreferences:)`
    /// - SeeAlso: `Locale.preferredLocales`
    public static var preferredLanguages: [String] {
        LocaleCache.cache.preferredLanguages(forCurrentUser: false)
    }

    /// Returns a list of the user’s preferred locales, as specified in Language & Region settings, taking into account any per-app language overrides.
    @available(FoundationPreview 6.2, *)
    public static var preferredLocales: [Locale] {
        return self.preferredLanguages.compactMap {
            Locale(identifier: $0)
        }
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
        return _canonicalLocaleIdentifier(from: string)
#else
        // TODO: (Locale.canonicalIdentifier) implement in Swift: https://github.com/apple/swift-foundation/issues/45
        return string
#endif // FOUNDATION_FRAMEWORK
    }

    /// Same as `canonicalIdentifier` but not deprecated, for internal usage. Also, it handles a nil result (e.g. non-ASCII identifier input) correctly.
    package static func _canonicalLocaleIdentifier(from string: String) -> String {
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

    // MARK: -

    /// Returns `true` if the locale is one of the "special" languages that requires special handling during case mapping.
    /// - "az": Azerbaijani
    /// - "lt": Lithuanian
    /// - "tr": Turkish
    /// - "nl": Dutch
    /// - "el": Greek
    /// For all other locales such as en_US, this is `false`.
    package static func identifierDoesNotRequireSpecialCaseHandling(_ identifier: String) -> Bool {
        var byteIterator = identifier.utf8.makeIterator()
        switch (byteIterator.next(), byteIterator.next()) {
        case
            (UInt8(ascii: "a"), UInt8(ascii: "z")),
            (UInt8(ascii: "l"), UInt8(ascii: "t")),
            (UInt8(ascii: "t"), UInt8(ascii: "r")),
            (UInt8(ascii: "n"), UInt8(ascii: "l")),
            (UInt8(ascii: "e"), UInt8(ascii: "l")):
            return false
        default:
            return true // Does not require special handling
        }
    }

    // MARK: -
    //

    public func hash(into hasher: inout Hasher) {
        if _locale.isAutoupdating {
            hasher.combine(true)
        } else {
            hasher.combine(false)
            hasher.combine(_locale.identifier)
            hasher.combine(prefs)
        }
    }

    public static func ==(lhs: Locale, rhs: Locale) -> Bool {
        if lhs._locale.isAutoupdating || rhs._locale.isAutoupdating {
            return lhs._locale.isAutoupdating && rhs._locale.isAutoupdating
        } else {
            return lhs.identifier == rhs.identifier && lhs.prefs == rhs.prefs
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Locale : CustomDebugStringConvertible, CustomStringConvertible, CustomReflectable {
    public var customMirror : Mirror {
        var c: [(label: String?, value: Any)] = []
        c.append((label: "identifier", value: identifier))
        c.append((label: "locale", value: _locale.debugDescription))
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }

    public var description: String {
        return "\(identifier) (\(_locale.debugDescription))"
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
        case preferences
    }

    // CFLocale enforces a rule that fixed/current/autoupdatingCurrent can never be equal even if their values seem like they are the same
    private enum Current : Int, Codable {
        case fixed
        case current
        case autoupdatingCurrent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let prefs = try container.decodeIfPresent(LocalePreferences.self, forKey: .preferences)

        if let current = try container.decodeIfPresent(Current.self, forKey: .current) {
            switch current {
            case .autoupdatingCurrent:
                self = Locale.autoupdatingCurrent
                return
            case .current:
                if prefs == nil {
                    // Prior to FoundationPreview 6.3 releases, Locale did not encode preferences and expected decoding .current to decode with the new current user's preferences via the new process' .currrent locale
                    // Preserve behavior for encoded current locales without encoded preferences by decoding as the current locale here to preserve the intent of including user preferences even though preferences are not included in the archive
                    // If preferences were encoded (the current locale encoded from a post-FoundationPreview 6.3 release), fallthrough to the new behavior below
                    self = Locale.current
                    return
                }
            case .fixed:
                // Fall through to identifier-based
                break
            }
        }

        let identifier = try container.decode(String.self, forKey: .identifier)
        if let prefs {
            // If preferences were encoded, create a locale with the preferences and identifier (not including preferences from the current user)
            self = Locale.localeWithPreferences(identifier: identifier, preferences: prefs)
        } else {
            // If no preferences were encoded, create a fixed locale with just the identifier
            self.init(identifier: identifier)
        }
    }
    
    // currentIsSentinel specifies whether .current should be encoded as a sentinel for compatibility with older runtimes
    // When true and encoding the current locale, decoding the archive on an older runtime will decode as the new "current"
    // When false and encoding the current locale, the locale is encoded as a fixed locale with preferences
    // When not encoding the current locale, this parameter has no effect
    internal func _encode(to encoder: Encoder, currentIsSentinel: Bool) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Even if we are current/autoupdatingCurrent, encode the identifier for backward compatibility
        try container.encode(self.identifier, forKey: .identifier)
        
        if self == Locale.autoupdatingCurrent {
            try container.encode(Current.autoupdatingCurrent, forKey: .current)
        } else if currentIsSentinel && self == Locale.current {
            // Always encode .current for the current locale to preserve existing decoding behavior of .current when decoding on older runtimes prior to FoundationPreview 6.3 releases
            try container.encode(Current.current, forKey: .current)
        } else {
            try container.encode(Current.fixed, forKey: .current)
        }
        
        if let prefs {
            // Encode preferences (if present) so that when decoding on newer runtimes (FoundationPreview 6.3 releases and later) we create a locale with the preferences as they are at encode time
            try container.encode(prefs, forKey: .preferences)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(to: encoder, currentIsSentinel: true)
    }
}
