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

#if canImport(Glibc)
import Glibc
#endif

#if !FOUNDATION_FRAMEWORK
@_dynamicReplacement(for: _localeICUClass())
private func _localeICUClass_localized() -> any _LocaleProtocol.Type {
    return _LocaleICU.self
}
#endif

let MAX_ICU_NAME_SIZE: Int32 = 1024

internal final class _LocaleICU: _LocaleProtocol, Sendable {
    // Double-optional values are caches where the result may be nil. If the outer value is nil, the result has not yet been calculated.
    // Single-optional values are caches where the result may not be nil. If the value is nil, the result has not yet been calculated.
    struct State: Hashable, Sendable {
        var languageComponents: Locale.Language.Components?
        var collation: Locale.Collation?
        var currency: Locale.Currency??
        var numberingSystem: Locale.NumberingSystem?
        var availableNumberingSystems: [Locale.NumberingSystem]?
        var firstDayOfWeek: Locale.Weekday?
        var weekendRange: WeekendRange??
        var minimalDaysInFirstWeek: Int?
        var hourCycle: Locale.HourCycle?
        var measurementSystem: Locale.MeasurementSystem?
        var usesCelsius: Bool? // UnitTemperature is not Sendable
        var region: Locale.Region??
        var subdivision: Locale.Subdivision??
        var timeZone: TimeZone??
        var variant: Locale.Variant??

        // If the key is present, the value has been calculated (and the result may or may not be nil).
        var identifierDisplayNames: [String : String?] = [:]
        var identifierTypes: [Locale.IdentifierType : String] = [:]
        var languageCodeDisplayNames: [String : String?] = [:]
        var countryCodeDisplayNames: [String : String?] = [:]
        var scriptCodeDisplayNames: [String : String?] = [:]
        var variantCodeDisplayNames: [String : String?] = [:]
        var calendarIdentifierDisplayNames: [Calendar.Identifier : String?] = [:]
        var collationIdentifierDisplayNames: [String : String?] = [:]
        var currencySymbolDisplayNames: [String : String?] = [:]
        var currencyCodeDisplayNames: [String : String?] = [:]
        var numberFormatters = NumberFormattersBox()

        // This type is @unchecked Sendable because it stores mutable pointers
        // The mutable pointers are only ever "mutated" during the call to cleanup, so this type can be safely sent across concurrency boundaries so long as care is taken to ensure that during a call to cleanup that you have exclusive access to this box
        // This is done by ensuring that cleanup is called from within the _LocaleICU lock
        struct NumberFormattersBox : Hashable, @unchecked Sendable {
            private var numberFormatters: [UInt32 /* UNumberFormatStyle */ : UnsafeMutablePointer<UNumberFormat?>] = [:]

            mutating func formatter(for style: UNumberFormatStyle, identifier: String, numberSymbols: [UInt32 : String]?) -> UnsafePointer<UNumberFormat?>? {
                if let nf = numberFormatters[UInt32(style.rawValue)] {
                    return UnsafePointer(nf)
                }

                var status = U_ZERO_ERROR
                guard let nf = unum_open(style, nil, 0, identifier, nil, &status) else {
                    return nil
                }

                let multiplier = unum_getAttribute(nf, UNUM_MULTIPLIER)
                if multiplier != 1 {
                    unum_setAttribute(nf, UNUM_MULTIPLIER, 1)
                }

                unum_setAttribute(nf, UNUM_LENIENT_PARSE, 0)
                unum_setContext(nf, UDISPCTX_CAPITALIZATION_NONE, &status)

                if let numberSymbols {
                    for (sym, str) in numberSymbols {
                        let utf16 = Array(str.utf16)
                        utf16.withUnsafeBufferPointer {
                            var status = U_ZERO_ERROR
                            unum_setSymbol(nf, UNumberFormatSymbol(CInt(sym)), $0.baseAddress, Int32($0.count), &status)
                        }
                    }
                }

                numberFormatters[UInt32(style.rawValue)] = nf
                
                // Vending non-mutable pointers ensures callers don't mutate state
                return UnsafePointer(nf)
            }

            mutating func cleanup() {
                for nf in numberFormatters.values {
                    unum_close(nf)
                }
                numberFormatters = [:]
            }
        }

        mutating func formatter(for style: UNumberFormatStyle, identifier: String, numberSymbols: [UInt32 : String]?) -> UnsafePointer<UNumberFormat?>? {
            numberFormatters.formatter(for: style, identifier: identifier, numberSymbols: numberSymbols)
        }

        mutating func cleanup() {
            numberFormatters.cleanup()
        }
    }

    // MARK: - ivar

    let identifier: String
    let identifierCapturingPreferences: String
    let calendarIdentifier: Calendar.Identifier

    let prefs: LocalePreferences?
    
    private let lock: LockedState<State>

    var debugDescription: String { "fixed \(identifier)" }

    // MARK: - Logging
#if FOUNDATION_FRAMEWORK
    static private let log: SendableOSLog = {
        .init(OSLog(subsystem: "com.apple.foundation", category: "locale"))
    }()
#endif // FOUNDATION_FRAMEWORK
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSLocale() -> NSLocale {
        LocaleCache.cache.fixedNSLocale(self)
    }
#endif

    // MARK: - init

    required init(identifier: String, prefs: LocalePreferences? = nil) {
        self.identifier = Locale._canonicalLocaleIdentifier(from: identifier)
        self.prefs = prefs
        calendarIdentifier = Self._calendarIdentifier(forIdentifier: self.identifier)
        identifierCapturingPreferences = Self._identifierCapturingPreferences(forIdentifier: self.identifier, calendarIdentifier: calendarIdentifier, preferences: prefs)
        lock = LockedState(initialState: State())
    }

    required init(components: Locale.Components) {
        self.identifier = components.icuIdentifier
        prefs = nil
        calendarIdentifier = Self._calendarIdentifier(forIdentifier: self.identifier)
        identifierCapturingPreferences = Self._identifierCapturingPreferences(forIdentifier: self.identifier, calendarIdentifier: calendarIdentifier, preferences: prefs)

        // Copy over the component values into our internal state - if they are set
        var state = State()
        state.languageComponents = components.languageComponents
        if let v = components.collation { state.collation = v }
        if let v = components.currency { state.currency = v }
        if let v = components.numberingSystem { state.numberingSystem = v }
        if let v = components.firstDayOfWeek { state.firstDayOfWeek = v }
        if let v = components.hourCycle { state.hourCycle = v }
        if let v = components.measurementSystem { state.measurementSystem = v }
        if let v = components.region { state.region = v }
        if let v = components.subdivision { state.subdivision = v }
        if let v = components.timeZone { state.timeZone = v }
        if let v = components.variant { state.variant = v }
        lock = LockedState(initialState: state)
    }

    /// Use to create a current-like Locale, with preferences.
    required init(name: String?, prefs: LocalePreferences, disableBundleMatching: Bool) {
        var ident: String?
        if let name {
            ident = Locale._canonicalLocaleIdentifier(from: name)
#if FOUNDATION_FRAMEWORK
            if Self.log.log.isEnabled(type: .debug) {
                if let ident {
                    let components = Locale.Components(identifier: ident)
                    if components.languageComponents.region == nil {
                        Logger(Self.log.log).debug("Current locale fetched with overriding locale identifier '\(ident, privacy: .public)' which does not have a country code")
                    }
                }
            }
#endif // FOUNDATION_FRAMEWORK
        }

        if let identSet = ident {
            ident = Locale._canonicalLocaleIdentifier(from: identSet)
        } else {
            let preferredLocale = prefs.locale

            // If CFBundleAllowMixedLocalizations is set, don't do any checking of the user's preferences for locale-matching purposes (32264371)
#if FOUNDATION_FRAMEWORK
            // Do not call the usual 'objectForInfoDictionaryKey' method, as it localizes the Info.plist content, which recurisvely calls back into Locale
            let allowMixed = _generouslyInterpretedInfoDictionaryBoolean(Bundle.main._object(forUnlocalizedInfoDictionaryKey: "CFBundleAllowMixedLocalizations"))
#else
            let allowMixed = false
#endif
            let performBundleMatching = !disableBundleMatching && !allowMixed

            let preferredLanguages = prefs.languages

            #if FOUNDATION_FRAMEWORK
            if preferredLanguages == nil && (preferredLocale == nil || performBundleMatching) {
                Logger(Self.log.log).debug("Lookup of 'AppleLanguages' from current preferences failed lookup (app preferences do not contain the key); likely falling back to default locale identifier as current")
            }
            #endif

            // Since localizations can contains legacy lproj names such as `English`, `French`, etc. we need to canonicalize these into language identifiers such as `en`, `fr`, etc. Otherwise the logic that later compares these to language identifiers will fail. (<rdar://problem/37141123>)
            // `preferredLanguages` has not yet been canonicalized, and if we won't perform the bundle matching below (and have a preferred locale), we don't need to canonicalize the list up-front. We'll do so below on demand.
            var canonicalizedLocalizations: [String]?

            if let preferredLocale, let preferredLanguages, performBundleMatching {
                let mainBundle = Bundle.main
                let availableLocalizations = mainBundle.localizations
                canonicalizedLocalizations = Locale.canonicalizeLocalizations(availableLocalizations)

                ident = Locale.localeIdentifierForCanonicalizedLocalizations(canonicalizedLocalizations!, preferredLanguages: preferredLanguages, preferredLocaleID: preferredLocale)
            }

            if ident == nil {
                // Either we didn't need to match the locale identifier against the main bundle's localizations, or were unable to.
                if let preferredLocale {
                    ident = Locale._canonicalLocaleIdentifier(from: preferredLocale)
                } else if let preferredLanguages {
                    if canonicalizedLocalizations == nil {
                        canonicalizedLocalizations = Locale.canonicalizeLocalizations(preferredLanguages)
                    }

                    if canonicalizedLocalizations!.count > 0 {
                        let languageName = canonicalizedLocalizations![0]

                        // This variable name is a bit confusing, but we do indeed mean to call the canonicalLocaleIdentifier function here and not canonicalLanguageIdentifier.
                        let languageIdentifier = Locale._canonicalLocaleIdentifier(from: languageName)
                        // Country???
                        if let countryCode = prefs.country {
                            #if FOUNDATION_FRAMEWORK
                            Logger(Self.log.log).debug("Locale.current constructing a locale identifier from preferred languages by combining with set country code '\(countryCode, privacy: .public)'")
                            #endif // FOUNDATION_FRAMEWORK
                            ident = Locale._canonicalLocaleIdentifier(from: "\(languageIdentifier)_\(countryCode)")
                        } else {
                            #if FOUNDATION_FRAMEWORK
                            Logger(Self.log.log).debug("Locale.current constructing a locale identifier from preferred languages without a set country code")
                            #endif // FOUNDATION_FRAMEWORK
                            ident = Locale._canonicalLocaleIdentifier(from: languageIdentifier)
                        }
                    } else {
                        #if FOUNDATION_FRAMEWORK
                        Logger(Self.log.log).debug("Value for 'AppleLanguages' found in preferences contains no valid entries; falling back to default locale identifier as current")
                        #endif // FOUNDATION_FRAMEWORK
                    }
                } else {
                    // We're going to fall back below.
                    // At this point, we've logged about both `preferredLocale` and `preferredLanguages` being missing, so no need to log again.
                }
            }
        }

        let fixedIdent: String
        if let ident, !ident.isEmpty {
            fixedIdent = ident
        } else {
            fixedIdent = "en_001"
        }

        self.identifier = Locale._canonicalLocaleIdentifier(from: fixedIdent)
        self.prefs = prefs
        calendarIdentifier = Self._calendarIdentifier(forIdentifier: self.identifier)
        identifierCapturingPreferences = Self._identifierCapturingPreferences(forIdentifier: self.identifier, calendarIdentifier: calendarIdentifier, preferences: prefs)
        lock = LockedState(initialState: State())
    }

    deinit {
        lock.withLock { state in
            // We can safely call this here because we have exclusive access to state within the lock
            state.cleanup()
        }
    }

    // MARK: -

    func copy(newCalendarIdentifier id: Calendar.Identifier) -> any _LocaleProtocol {
        // Update the identifier to respect the new calendar ID
        var comps = Locale.Components(identifier: identifier)
        comps.calendar = id
        let newIdentifier = comps.icuIdentifier

        return _LocaleICU(identifier: newIdentifier, prefs: prefs)
    }

    // MARK: - Direct Prefs Access

#if FOUNDATION_FRAMEWORK
    func pref(for key: String) -> Any? {
        guard let prefs else { return nil }
        // This doesn't support all prefs, just the subset needed by CF
        switch key {
        case "AppleMetricUnits":
            return prefs.metricUnits
        case "AppleMeasurementUnits":
            return prefs.measurementUnits?.userDefaultString
        case "AppleTemperatureUnit":
            return prefs.temperatureUnit?.userDefaultString
        case "AppleFirstWeekday":
            guard let p = prefs.firstWeekday else { return nil }
            var result: [String: Int] = [:]
            for (k, v) in p {
                result[k.cfCalendarIdentifier] = v
            }
            return result
        case "AppleMinDaysInFirstWeek":
            guard let p = prefs.minDaysInFirstWeek else { return nil }
            var result: [String: Int] = [:]
            for (k, v) in p {
                result[k.cfCalendarIdentifier] = v
            }
            return result
        case "AppleICUDateTimeSymbols":
            return prefs.icuSymbolsAndStrings.icuDateTimeSymbols
        case "AppleICUForce24HourTime":
            return prefs.force24Hour
        case "AppleICUForce12HourTime":
            return prefs.force12Hour
        case "AppleICUDateFormatStrings":
            return prefs.icuSymbolsAndStrings.icuDateFormatStrings
        case "AppleICUTimeFormatStrings":
            return prefs.icuSymbolsAndStrings.icuTimeFormatStrings
        case "AppleICUNumberFormatStrings":
            return prefs.icuSymbolsAndStrings.icuNumberFormatStrings
        case "AppleICUNumberSymbols":
            return prefs.icuSymbolsAndStrings.icuNumberSymbols
        default:
            return nil
        }
    }
#endif

    // MARK: - Identifier

    func identifierDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.identifierDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                var status = U_ZERO_ERROR
                if let result = displayString(for: lang, value: value, status: &status, uloc_getDisplayName), status != U_USING_DEFAULT_WARNING {
                    return result
                }

                // Did we wind up using a default somewhere?
                if status == U_USING_DEFAULT_WARNING {
                    // For some locale IDs, there may be no language which has a translation for every piece. Rather than return nothing, see if we can at least handle the language part of the locale.
                    status = U_ZERO_ERROR
                    return displayString(for: lang, value: value, status: &status, uloc_getDisplayLanguage)
                } else {
                    return nil
                }
            }

            state.identifierDisplayNames[value] = name
            return name
        }
    }

    private static func identifier(forType type: Locale.IdentifierType, from string: String) -> String? {
        var result: String?
        switch type {
        case .icu:
            result = _withFixedCharBuffer(size: ULOC_FULLNAME_CAPACITY) { buffer, size, status in
                return ualoc_canonicalForm(string, buffer, size, &status)
            }
        case .bcp47:
            result = _withFixedCharBuffer { buffer, size, status in
                return uloc_toLanguageTag(string, buffer, size, UBool.false, &status)
            }
        case .cldr:
            //  A Unicode BCP 47 locale identifier can be transformed into a Unicode CLDR locale identifier by performing the following transformation.
            //  - the separator is changed to "_"
            //  - the primary language subtag "und" is replaced with "root" if no script, region, or variant subtags are present.
            let bcp47 = _withFixedCharBuffer { buffer, size, status in
                return uloc_toLanguageTag(string, buffer, size, UBool.false, &status)
            }

            if let canonicalized = bcp47?.replacing("-", with: "_") {
                if canonicalized == "und" {
                    result = canonicalized.replacing("und", with: "root")
                } else {
                    result = canonicalized
                }
            }
        }
        return result
    }

    func identifier(_ type: Locale.IdentifierType) -> String {
        lock.withLock { state in
            if let result = state.identifierTypes[type] {
                return result
            }

            if let result = _LocaleICU.identifier(forType: type, from: identifier) {
                state.identifierTypes[type] = result
                return result
            } else {
                state.identifierTypes[type] = identifier
                return identifier
            }
        }
    }

    // This only includes a subset of preferences that are representable by
    // CLDR keywords: https://www.unicode.org/reports/tr35/#Key_Type_Definitions
    //
    // Intentionally ignore `prefs.country`: Locale identifier should already contain
    // that information. Do not override it.
    static func _identifierCapturingPreferences(forIdentifier identifier: String, calendarIdentifier: Calendar.Identifier, preferences prefs: LocalePreferences?) -> String {
        guard let prefs else {
            return identifier
        }

        var components = Locale.Components(identifier: identifier)

        if let id = prefs.collationOrder {
            components.collation = .init(id)
        }

        if let firstWeekdayPrefs = prefs.firstWeekday {
            let calendarID = calendarIdentifier
            if let weekdayNumber = firstWeekdayPrefs[calendarID], let weekday = Locale.Weekday(Int32(weekdayNumber)) {
                components.firstDayOfWeek = weekday
            }
        }

        if let measurementSystem = prefs.measurementSystem {
            components.measurementSystem = measurementSystem
        }

        if let hourCycle = prefs.hourCycle {
            components.hourCycle = hourCycle
        }

        return components.icuIdentifier
    }

    // MARK: - Language Code

    var languageCode: String? {
        lock.withLock { state in
            if let comps = state.languageComponents {
                return comps.languageCode?.identifier
            } else {
                let comps = Locale.Language.Components(identifier: identifier)
                state.languageComponents = comps
                return comps.languageCode?.identifier
            }
        }
    }

    func languageCodeDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.languageCodeDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                var status = U_ZERO_ERROR
                return displayString(for: lang, value: value, status: &status, uloc_getDisplayLanguage)
            }

            state.languageCodeDisplayNames[value] = name
            return name
        }
    }

    var language: Locale.Language {
        Locale.Language(identifier: identifier)
    }

    // MARK: - Country, Region, Subdivision, Variant

    func countryCodeDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.countryCodeDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                // Need to make a fake locale ID
                if value.count < ULOC_FULLNAME_CAPACITY - 3 {
                    let localeId = "en_" + value
                    var status = U_ZERO_ERROR
                    return displayString(for: lang, value: localeId, status: &status, uloc_getDisplayCountry)
                } else {
                    return nil
                }
            }

            state.countryCodeDisplayNames[value] = name
            return name
        }
    }

    private func _lockedRegion(_ state: inout State) -> Locale.Region? {
        if let region = state.region {
            // Cached value available, either a value or nil
            if let region {
                return region
            } else {
                return nil
            }
        } else {
            // Fill the cached value
            if let regionString = Locale.keywordValue(identifier: identifier, key: Locale.Region.legacyKeywordKey), regionString.count > 2 {
                // A valid `regionString` is a unicode subdivision id that consists of a region subtag suffixed either by "zzzz" ("uszzzz") for whole region, or by a subdivision suffix for a partial subdivision ("usca").
                // Retrieve the region part ("us").
                let region = Locale.Region(String(regionString.prefix(2)).uppercased())
                state.region = region
                return region
            } else {
                let region = Locale.Language(identifier: identifier).region
                state.region = region
                return region
            }
        }
    }

    var region: Locale.Region? {
        lock.withLock { state in
            _lockedRegion(&state)
        }
    }

    var subdivision: Locale.Subdivision? {
        lock.withLock { state in
            if let subdivision = state.subdivision {
                return subdivision
            } else {
                // Fill the cached value
                if let subdivisionString = Locale.keywordValue(identifier: identifier, key: Locale.Subdivision.legacyKeywordKey) {
                    let subdivision = Locale.Subdivision(subdivisionString)
                    state.subdivision = subdivision
                    return subdivision
                } else {
                    state.subdivision = .some(nil)
                    return nil
                }
            }
        }
    }

    var variant: Locale.Variant? {
        lock.withLock { state in
            if let variant = state.variant {
                return variant
            } else {
                // Fill the cached value
                let variantStr = _withFixedCharBuffer { buffer, size, status in
                    return uloc_getVariant(identifier, buffer, size, &status)
                }

                if let variantStr {
                    let variant = Locale.Variant(variantStr)
                    state.variant = variant
                    return variant
                }

                state.variant = .some(nil)
                return nil
            }
        }
    }


    // MARK: - Script Code

    var scriptCode: String? {
        lock.withLock { state in
            if let comps = state.languageComponents {
                return comps.script?.identifier
            } else {
                let comps = Locale.Language.Components(identifier: identifier)
                state.languageComponents = comps
                return comps.script?.identifier
            }
        }
    }

    func scriptCodeDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.scriptCodeDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                // Need to make a fake locale ID
                if value.count == 4 {
                    let localeId = "en_" + value + "_US"
                    var status = U_ZERO_ERROR
                    return displayString(for: lang, value: localeId, status: &status, uloc_getDisplayScript)
                } else {
                    return nil
                }
            }

            state.scriptCodeDisplayNames[value] = name
            return name
        }
    }

    // MARK: - Variant Code

    var variantCode: String? {
        return variant?.identifier
    }

    func variantCodeDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.variantCodeDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                // Need to make a fake locale ID
                if value.count < ULOC_FULLNAME_CAPACITY + ULOC_KEYWORD_AND_VALUES_CAPACITY - 6 {
                    let localeId = "en_US_" + value
                    var status = U_ZERO_ERROR
                    return displayString(for: lang, value: localeId, status: &status, uloc_getDisplayVariant)
                } else {
                    return nil
                }
            }

            state.variantCodeDisplayNames[value] = name
            return name
        }
    }

    // MARK: - Exemplar Character Set
#if FOUNDATION_FRAMEWORK
    var exemplarCharacterSet: CharacterSet? {
        var status = U_ZERO_ERROR
        let data = ulocdata_open(identifier, &status)
        guard status.isSuccess else { return nil }
        defer { ulocdata_close(data) }

        let set = ulocdata_getExemplarSet(data, nil, UInt32(USET_ADD_CASE_MAPPINGS), ULOCDATA_ES_STANDARD, &status)
        guard status.isSuccess else { return nil }
        defer { uset_close(set) }

        if status == U_USING_DEFAULT_WARNING {
            // If default locale is used, force to empty set
            uset_clear(set)
        }

        // _CFCreateCharacterSetFromUSet, also used by NSPersonNameComponentsFormatter
        var characterSet = CharacterSet()
        // // Suitable for most small sets
        var capacity: Int32 = 2048
        var buffer = UnsafeMutableBufferPointer<UChar>.allocate(capacity: Int(capacity))
        defer { buffer.deallocate() }
        let count = uset_getItemCount(set)
        for i in 0..<count {
            var start: UChar32 = 0
            var end: UChar32 = 0

            let len = uset_getItem(set, i, &start, &end, buffer.baseAddress, capacity, &status)
            if status == U_BUFFER_OVERFLOW_ERROR {
                buffer.deallocate()
                capacity = len + 1
                buffer = UnsafeMutableBufferPointer<UChar>.allocate(capacity: Int(capacity))
                status = U_ZERO_ERROR
                // Try again
                _ = uset_getItem(set, i, &start, &end, buffer.baseAddress, capacity, &status)
            }

            guard status.isSuccess else {
                return nil
            }

            if len <= 0 {
                let r = Unicode.Scalar(UInt32(exactly: start)!)!...Unicode.Scalar(UInt32(exactly: end)!)!
                characterSet.insert(charactersIn: r)
            } else {
                let s = String(UnicodeScalarType(utf16CodeUnits: buffer.baseAddress!, count: Int(len)))
                characterSet.insert(charactersIn: s)
            }
        }

        return characterSet
    }
#endif

    // MARK: - LocaleCalendarIdentifier

    private static func _calendarIdentifier(forIdentifier identifier: String) -> Calendar.Identifier {
        var calendarIDString = Locale.keywordValue(identifier: identifier, key: "calendar")
        if calendarIDString == nil {
            // Try again
            var status = U_ZERO_ERROR
            let e = ucal_getKeywordValuesForLocale("calendar", identifier, UBool.true, &status)
            defer { uenum_close(e) }
            guard let e, status.isSuccess else {
                return .gregorian
            }
            // Just get the first value
            var resultLength = Int32(0)
            let result = uenum_next(e, &resultLength, &status)
            guard status.isSuccess, let result else {
                return .gregorian
            }
            calendarIDString = String(cString: result)
        }

        guard let calendarIDString else {
            // Fallback value
            return .gregorian
        }

        return Calendar.Identifier(identifierString: calendarIDString) ?? .gregorian
    }

    func calendarIdentifierDisplayName(for value: Calendar.Identifier) -> String? {
        lock.withLock { state in
            if let result = state.calendarIdentifierDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                displayKeyword(for: lang, keyword: "calendar", value: value.cfCalendarIdentifier)
            }

            state.calendarIdentifierDisplayNames[value] = name
            return name
        }
    }

    // MARK: - LocaleCalendar

    var calendar: Calendar {
        var calendar = Calendar(identifier: calendarIdentifier)
        
        if let prefs {
            let firstWeekday = prefs.firstWeekday?[calendarIdentifier]
            let minDaysInFirstWeek = prefs.minDaysInFirstWeek?[calendarIdentifier]
            if let firstWeekday { calendar.firstWeekday = firstWeekday }
            if let minDaysInFirstWeek { calendar.minimumDaysInFirstWeek = minDaysInFirstWeek }
        }

        // In order to avoid a retain cycle (Calendar has a Locale, Locale has a Calendar), we do not keep a reference to the Calendar in Locale but create one each time. Most of the time the value of `Calendar(identifier:)` will return a cached value in any case.
        return calendar
    }

    var timeZone: TimeZone? {
        lock.withLock { state in
            if let timeZone = state.timeZone {
                return timeZone
            } else {
                if let timeZoneString = Locale.keywordValue(identifier: identifier, key: TimeZone.legacyKeywordKey) {
                    let timeZone = TimeZone(identifier: timeZoneString)
                    state.timeZone = timeZone
                    return timeZone
                } else {
                    state.timeZone = .some(nil)
                    return nil
                }
            }
        }
    }

    // MARK: - LocaleCollationIdentifier

    var collationIdentifier: String? {
        collation.identifier
    }

    func collationIdentifierDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.collationIdentifierDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                displayKeyword(for: lang, keyword: "collation", value: value)
            }

            state.collationIdentifierDisplayNames[value] = name
            return name
        }
    }

    var collation: Locale.Collation {
        lock.withLock { state in
            if let collation = state.collation {
                return collation
            } else {
                if let value = Locale.keywordValue(identifier: identifier, key: Locale.Collation.legacyKeywordKey) {
                    let collation = Locale.Collation(value)
                    state.collation = collation
                    return collation
                } else {
                    state.collation = .standard
                    return .standard
                }
            }
        }
    }

    // MARK: - LocaleUsesMetricSystem

    var usesMetricSystem: Bool {
        let ms = measurementSystem
        if ms != .us {
            return true
        } else {
            return false
        }
    }

    // MARK: - LocaleMeasurementSystem

    /// Will return nil if the measurement system is not set in the prefs, unlike `measurementSystem` which has a fallback value.
    var forceMeasurementSystem: Locale.MeasurementSystem? {
        return prefs?.measurementSystem
    }

    var measurementSystem: Locale.MeasurementSystem {
        return lock.withLock { state in
            if let ms = state.measurementSystem {
                return ms
            } else {
                // Check identifier for explicit value first
                if let value = Locale.keywordValue(identifier: identifier, key: Locale.MeasurementSystem.legacyKeywordKey) {
                    if value == "imperial" {
                        // Legacy alias for "uksystem"
                        state.measurementSystem = .uk
                        return .uk
                    } else {
                        let ms = Locale.MeasurementSystem(value)
                        state.measurementSystem = ms
                        return ms
                    }
                }

                // Check user prefs
                if let ms = forceMeasurementSystem {
                    state.measurementSystem = ms
                    return ms
                }

                // Fallback to the identifier's default value
                var status = U_ZERO_ERROR
                let output = ulocdata_getMeasurementSystem(identifier, &status)
                if status.isSuccess {
                    let ms = switch output {
                    case UMS_US: Locale.MeasurementSystem.us
                    case UMS_UK: Locale.MeasurementSystem.uk
                    default: Locale.MeasurementSystem.metric
                    }
                    state.measurementSystem = ms
                    return ms
                }

                // Fallback to SI
                let ms = Locale.MeasurementSystem.metric
                state.measurementSystem = ms
                return ms
            }
        }
    }

    // MARK: - LocaleTemperatureUnit
    var forceTemperatureUnit: LocalePreferences.TemperatureUnit? {
        prefs?.temperatureUnit
    }

    var temperatureUnit: LocalePreferences.TemperatureUnit {
        if let unit = forceTemperatureUnit {
            return unit
        }

        let usesCelsius = lock.withLock { state in
            if let ms = state.usesCelsius {
                return ms
            } else {
                var icuUnit = UAMEASUNIT_TEMPERATURE_GENERIC
                var status = U_ZERO_ERROR
                let count = uameasfmt_getUnitsForUsage(identifier, "temperature", "weather", &icuUnit, 1, &status)
                if status.isSuccess, count > 0 {
                    if icuUnit == UAMEASUNIT_TEMPERATURE_FAHRENHEIT {
                        state.usesCelsius = false
                        return false
                    } else {
                        state.usesCelsius = true
                        return true
                    }
                } else {
                    state.usesCelsius = true
                    return true
                }
            }
        }

        return usesCelsius ? .celsius : .fahrenheit
    }

    // MARK: - LocaleDecimalSeparator

    var decimalSeparator: String? {
        lock.withLock { state in
            guard let nf = state.formatter(for: UNUM_DECIMAL, identifier: identifier, numberSymbols: prefs?.numberSymbols) else {
                return nil
            }

            return _withFixedUCharBuffer(size: 32) { buffer, size, status in
                return unum_getSymbol(nf, UNUM_DECIMAL_SEPARATOR_SYMBOL, buffer, size, &status)
            }
        }
    }

    // MARK: - LocaleGroupingSeparator

    var groupingSeparator: String? {
        lock.withLock { state in
            guard let nf = state.formatter(for: UNUM_DECIMAL, identifier: identifier, numberSymbols: prefs?.numberSymbols) else {
                return nil
            }

            return _withFixedUCharBuffer(size: 32) { buffer, size, status in
                return unum_getSymbol(nf, UNUM_GROUPING_SEPARATOR_SYMBOL, buffer, size, &status)
            }
        }
    }

    // MARK: - CurrencySymbolKey

    private func icuCurrencyName(localeIdentifier: String, value: String, style: UCurrNameStyle) -> String? {
        guard value.count == 3 else {
            // Not a valid ISO code
            return nil
        }

        return withUnsafeTemporaryAllocation(of: UChar.self, capacity: 4) { buffer -> String? in
            u_charsToUChars(value, buffer.baseAddress!, 3)
            buffer[3] = UChar(0)
            var isChoice = UBool.false
            var size: Int32 = 0
            var status = U_ZERO_ERROR
            let name = ucurr_getName(buffer.baseAddress, localeIdentifier, style, &isChoice, &size, &status)
            guard let name, status.isSuccess, status != U_USING_DEFAULT_WARNING else {
                return nil
            }

            guard let nameStr = String(_utf16: name, count: Int(size)) else {
                return nil
            }

            if isChoice.boolValue {
                let pattern = "{0,choice,\(nameStr)}"

                let uchars = Array(pattern.utf16)
                return _withFixedUCharBuffer { buffer, size, status in
                    var size: Int32 = 0
                    withVaList([10.0]) { vaPtr in
                        size = u_vformatMessage("en_US", uchars, Int32(uchars.count), buffer, size, vaPtr, &status)
                    }
                    return size
                }
            } else {
                return nameStr
            }
        }
    }

    var currencySymbol: String? {
        lock.withLock { state in
            guard let nf = state.formatter(for: UNUM_DECIMAL, identifier: identifier, numberSymbols: prefs?.numberSymbols) else {
                return nil
            }

            return _withFixedUCharBuffer(size: 32) { buffer, size, status in
                return unum_getSymbol(nf, UNUM_CURRENCY_SYMBOL, buffer, size, &status)
            }
        }
    }

    func currencySymbolDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.currencySymbolDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                icuCurrencyName(localeIdentifier: lang, value: value, style: UCURR_SYMBOL_NAME)
            }

            state.currencySymbolDisplayNames[value] = name
            return name
        }
    }

    // MARK: - CurrencyCodeKey

    var currencyCode: String? {
        lock.withLock { state in
            guard let nf = state.formatter(for: UNUM_CURRENCY, identifier: identifier, numberSymbols: prefs?.numberSymbols) else {
                return nil
            }

            let result = _withFixedUCharBuffer { buffer, size, status in
                unum_getTextAttribute(nf, UNUM_CURRENCY_CODE, buffer, size, &status)
            }

            return result
        }
    }

    func currencyCodeDisplayName(for value: String) -> String? {
        lock.withLock { state in
            if let result = state.currencyCodeDisplayNames[value] {
                return result
            }

            let name = displayNameIncludingFallbacks { lang in
                icuCurrencyName(localeIdentifier: lang, value: value, style: UCURR_LONG_NAME)
            }

            state.currencyCodeDisplayNames[value] = name
            return name
        }
    }

    var currency: Locale.Currency? {
        lock.withLock { state in
            if let currency = state.currency {
                return currency
            } else {
                let str = _withFixedUCharBuffer { buffer, size, status in
                    return ucurr_forLocale(identifier, buffer, size, &status)
                }

                guard let str else {
                    state.currency = .some(nil)
                    return nil
                }

                let c = Locale.Currency(str)
                state.currency = c
                return c
            }
        }
    }

    // MARK: - CollatorIdentifierKey

    // "kCFLocaleCollatorIdentifierKey" aka "locale:collator id"
    var collatorIdentifier: String? {
        if let prefs {
            if let order = prefs.collationOrder {
                return Locale.canonicalLanguageIdentifier(from: order)
            } else if let languages = prefs.languages, languages.count > 0 {
                return Locale.canonicalLanguageIdentifier(from: languages[0])
            }
        }

        // Identifier is the fallback
        return identifier
    }

    func collatorIdentifierDisplayName(for value: String) -> String? {
        // Unsupported
        return nil
    }

    // MARK: - QuotationBeginDelimiterKey

    private func delimiterString(_ type: ULocaleDataDelimiterType) -> String? {
        var status = U_ZERO_ERROR
        let uld = ulocdata_open(identifier, &status)
        defer { ulocdata_close(uld) }

        guard status.isSuccess else {
            return nil
        }

        let result = _withFixedUCharBuffer(size: 130) { buffer, size, status in
            ulocdata_getDelimiter(uld, type, buffer, size, &status)
        }

        return result
    }

    var quotationBeginDelimiter: String? {
        delimiterString(ULOCDATA_QUOTATION_START)
    }

    // MARK: - QuotationEndDelimiterKey
    var quotationEndDelimiter: String? {
        delimiterString(ULOCDATA_QUOTATION_END)
    }

    // MARK: - AlternateQuotationBeginDelimiterKey
    var alternateQuotationBeginDelimiter: String? {
        delimiterString(ULOCDATA_ALT_QUOTATION_START)
    }

    // MARK: - AlternateQuotationEndDelimiterKey
    var alternateQuotationEndDelimiter: String? {
        delimiterString(ULOCDATA_ALT_QUOTATION_END)
    }

    // MARK: 24/12 hour

    var forceHourCycle: Locale.HourCycle? {
        return prefs?.hourCycle
    }

    var hourCycle: Locale.HourCycle {
        lock.withLock { state in
            if let hourCycle = state.hourCycle {
                return hourCycle
            } else {
                // Always respect the `hc` override in the identifier first
                if let hcStr = Locale.keywordValue(identifier: identifier, key: Locale.HourCycle.legacyKeywordKey) {
                    if let hc = Locale.HourCycle(rawValue: hcStr) {
                        state.hourCycle = hc
                        return hc
                    }
                }

                if let hourCycleOverride = prefs?.hourCycle {
                    state.hourCycle = hourCycleOverride
                    return hourCycleOverride
                }

                let comps = Locale.Components(identifier: identifier)
                if let hourCycle = comps.hourCycle {
                    // Always respect the `hc` override in the identifier first
                    state.hourCycle = hourCycle
                    return hourCycle
                }

                let calendarId = calendarIdentifier
                let rootHourCycle = Locale.HourCycle.zeroToTwentyThree
                if let regionOverride = _lockedRegion(&state)?.identifier {
                    // Use the "rg" override in the identifier if there's one
                    // ICU isn't handling `rg` keyword yet (93783223), so we do this manually: create a fake locale with the `rg` override as the language region.
                    // Use "und" as the language code as it is irrelevant for regional preferences
                    let tmpLocaleIdentifier = "und_\(regionOverride)"
                    guard let icuPatternGenerator = ICUPatternGenerator.cachedPatternGenerator(localeIdentifier: tmpLocaleIdentifier, calendarIdentifier: calendarId) else {
                        state.hourCycle = rootHourCycle
                        return rootHourCycle
                    }
                    let hc = icuPatternGenerator.defaultHourCycle
                    state.hourCycle = hc
                    return hc
                }

                guard let icuPatternGenerator = ICUPatternGenerator.cachedPatternGenerator(localeIdentifier: identifier, calendarIdentifier: calendarId) else {
                    state.hourCycle = rootHourCycle
                    return rootHourCycle
                }
                
                let hc = icuPatternGenerator.defaultHourCycle
                state.hourCycle = hc
                return hc
            }
        }
    }

    // MARK: First weekday

    func forceFirstWeekday(_ calendar: Calendar.Identifier) -> Locale.Weekday? {
        if let weekdayNumber = prefs?.firstWeekday?[calendar] {
            // 1 is Sunday
            return Locale.Weekday(Int32(weekdayNumber))
        }

        return nil
    }

    var firstDayOfWeek: Locale.Weekday {
        lock.withLock { state in
            if let first = state.firstDayOfWeek {
                return first
            } else {
                // Check identifier
                if let firstString = Locale.keywordValue(identifier: identifier, key: Locale.Weekday.legacyKeywordKey) {
                    if let first = Locale.Weekday(rawValue: firstString) {
                        state.firstDayOfWeek = first
                        return first
                    }
                }

                // Check prefs
                if let firstWeekdayPref = prefs?.firstWeekday {
                    let calendarId = calendarIdentifier
                    if let first = forceFirstWeekday(calendarId) {
                        state.firstDayOfWeek = first
                        return first
                    }
                }

                // Fall back to the calendar's default value
                var status = U_ZERO_ERROR
                let cal = ucal_open(nil, 0, identifier, UCAL_DEFAULT, &status)
                defer { ucal_close(cal) }

                if status.isSuccess {
                    // 1-based. Sunday is 1
                    let firstDay = ucal_getAttribute(cal, UCAL_FIRST_DAY_OF_WEEK)
                    if let result = Locale.Weekday(firstDay) {
                        state.firstDayOfWeek = result
                        return result
                    }
                }

                // Last fallback
                state.firstDayOfWeek = .sunday
                return .sunday
            }
        }
    }

    var weekendRange: WeekendRange? {
        let firstWeekday = self.firstDayOfWeek
        return lock.withLock { state -> WeekendRange? in

            if let r = state.weekendRange {
                return r
            }

            var result = WeekendRange(start: 0, end: 0)

            var weekdaysIndex : [UInt32] = [0, 0, 0, 0, 0, 0, 0]
            weekdaysIndex[0] = UInt32(firstWeekday.icuIndex)
            for i in 1..<7 {
                weekdaysIndex[i] = (weekdaysIndex[i - 1] % 7) + 1
            }

            var weekdayTypes : [UCalendarWeekdayType] = [UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY, UCAL_WEEKDAY]

#if os(Windows)
            var onset: CInt?
            var cease: CInt?
#else
            var onset: CUnsignedInt?
            var cease: CUnsignedInt?
#endif

            var status = U_ZERO_ERROR
            let cal = ucal_open(nil, 0, identifier, UCAL_DEFAULT, &status)
            defer { ucal_close(cal) }

            for i in 0..<7 {
                var status = U_ZERO_ERROR
                weekdayTypes[i] = ucal_getDayOfWeekType(cal, UCalendarDaysOfWeek(CInt(weekdaysIndex[i])), &status)
                if weekdayTypes[i] == UCAL_WEEKEND_ONSET {
                    onset = numericCast(weekdaysIndex[i])
                } else if weekdayTypes[i] == UCAL_WEEKEND_CEASE {
                    cease = numericCast(weekdaysIndex[i])
                }
            }

            let hasWeekend = weekdayTypes.contains {
                $0 == UCAL_WEEKEND || $0 == UCAL_WEEKEND_ONSET || $0 == UCAL_WEEKEND_CEASE
            }

            guard hasWeekend else {
                return nil
            }

            if let onset {
                var status = U_ZERO_ERROR
                // onsetTime is milliseconds after midnight at which the weekend starts. Divide to get to TimeInterval (seconds)
                result.onsetTime = Double(ucal_getWeekendTransition(cal, UCalendarDaysOfWeek(rawValue: onset), &status)) / 1000.0
            }

            if let cease {
                var status = U_ZERO_ERROR
                // onsetTime is milliseconds after midnight at which the weekend ends. Divide to get to TimeInterval (seconds)
                result.ceaseTime = Double(ucal_getWeekendTransition(cal, UCalendarDaysOfWeek(rawValue: cease), &status)) / 1000.0
            }

#if os(Windows)
            var weekendStart: CInt?
            var weekendEnd: CInt?
#else
            var weekendStart: CUnsignedInt?
            var weekendEnd: CUnsignedInt?
#endif

            if let onset {
                weekendStart = onset
            } else {
                if weekdayTypes[0] == UCAL_WEEKEND && weekdayTypes[6] == UCAL_WEEKEND {
                    for i in (0...5).reversed() {
                        if weekdayTypes[i] != UCAL_WEEKEND {
                            weekendStart = numericCast(weekdaysIndex[i + 1])
                            break
                        }
                    }
                } else {
                    for i in 0..<7 {
                        if weekdayTypes[i] == UCAL_WEEKEND {
                            weekendStart = numericCast(weekdaysIndex[i])
                            break
                        }
                    }
                }
            }

            if let cease {
                weekendEnd = cease
            } else {
                if weekdayTypes[0] == UCAL_WEEKEND && weekdayTypes[6] == UCAL_WEEKEND {
                    for i in 1..<7 {
                        if weekdayTypes[i] != UCAL_WEEKEND {
                            weekendEnd = numericCast(weekdaysIndex[i - 1])
                            break
                        }
                    }
                } else {
                    for i in (0...6).reversed() {
                        if weekdayTypes[i] == UCAL_WEEKEND {
                            weekendEnd = numericCast(weekdaysIndex[i])
                            break
                        }
                    }
                }
            }

            // There needs to be a start and end to have a next weekend
            guard let weekendStart, let weekendEnd else {
                return nil
            }

            result.start = Int(weekendStart)
            result.end = Int(weekendEnd)
            return result
        }
    }

    // MARK: Min days in first week

    var minimumDaysInFirstWeek: Int {
        lock.withLock { state in
            if let minDays = state.minimalDaysInFirstWeek {
                return minDays
            }

            // Check prefs
            if prefs != nil {
                // `_lockedCalendarIdentifier` isn't cheap. Only call it when we already know there is `prefs` to read from
                let calendarId = calendarIdentifier
                if let minDays = forceMinDaysInFirstWeek(calendarId) {
                    state.minimalDaysInFirstWeek = minDays
                    return minDays
                }
            }

            // Use locale's value
            var status = U_ZERO_ERROR
            let cal = ucal_open(nil, 0, identifier, UCAL_DEFAULT, &status)
            defer { ucal_close(cal) }

            guard status.isSuccess else {
                // fallback to 001's value
                state.minimalDaysInFirstWeek = 1
                return 1
            }

            let minDays = Int(ucal_getAttribute(cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK))
            state.minimalDaysInFirstWeek = minDays
            return minDays
        }
    }

    func forceMinDaysInFirstWeek(_ calendar: Calendar.Identifier) -> Int? {
        if let prefs {
            return prefs.minDaysInFirstWeek?[calendar]
        }

        return nil
    }

    // MARK: Numbering system

    private func _lockedNumberingSystem(_ state: inout State) -> Locale.NumberingSystem {
        if let ns = state.numberingSystem {
            return ns
        }

        // TODO: PERF: Refactor to not waste components
        let comps = Locale.Components(identifier: identifier)
        if let ns = comps.numberingSystem {
            state.numberingSystem = ns
            return ns
        }

        // Legacy fallback
        return Locale.NumberingSystem(localeIdentifier: identifier)
    }

    var numberingSystem: Locale.NumberingSystem {
        lock.withLock { state in
            _lockedNumberingSystem(&state)
        }
    }

    var availableNumberingSystems: [Locale.NumberingSystem] {
        lock.withLock { state in
            if let systems = state.availableNumberingSystems {
                return systems
            }

            // The result always has .latn and the locale's numbering system
            var result: Set<Locale.NumberingSystem> = [.latn, _lockedNumberingSystem(&state)]

            // https://www.unicode.org/reports/tr35/tr35-numbers.html#Numbering_Systems
            let variants: [Locale.NumberingSystem] = [ "default", "native", "traditional", "finance" ]
            for variant in variants {
                var componentsWithVariant = Locale.Components(identifier: identifier)
                componentsWithVariant.numberingSystem = variant
                let locWithVariant = Locale(components: componentsWithVariant)

                result.insert(Locale.NumberingSystem(localeIdentifier: locWithVariant.identifier))
            }

            let resultArray = Array(result)
            state.availableNumberingSystems = resultArray
            return resultArray
        }
    }

    // MARK: - Date/Time Formats

#if FOUNDATION_FRAMEWORK
    func customDateFormat(_ style: Date.FormatStyle.DateStyle) -> String? {
        guard let dateFormatStrings = prefs?.dateFormats else { return nil }
        return dateFormatStrings[style]
    }
#endif

    // MARK: -

    private func displayString(for identifier: String, value: String, status: UnsafeMutablePointer<UErrorCode>, _ f: (UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafeMutablePointer<UChar>?, Int32, UnsafeMutablePointer<UErrorCode>?) -> Int32) -> String? {
        // Do not allow 'default' values from ICU data to be returned here.
        let result = _withFixedUCharBuffer(defaultIsError: true) { buffer, size, status in
            return f(value, identifier, buffer, size, &status)
        }
        return result
    }

    /// Use this for all displayName API. Attempts using the `identifier` first, then falls back to a canonicalized list of preferred languages from the Locale overrides (if set), and then user data.
    func displayNameIncludingFallbacks(_ algo: (String) -> String?) -> String? {
        if let result = algo(identifier) {
            return result
        }

        // Couldn't get a value using the identifier; try again with the list of preferred languages
        let langs: [String]

        if let prefs, let override = prefs.languages {
            langs = override
        } else {
            langs = Locale.preferredLanguages
        }

        for l in langs {
            // Canonicalize the id
            let cleanLanguage = Locale.canonicalLanguageIdentifier(from: l)
            if let result = algo(cleanLanguage) {
                return result
            }
        }

        return nil
    }

    private func displayKeyword(for identifier: String, keyword: String, value: String) -> String? {
        // Make a fake locale ID
        let lid = "en_US@" + keyword + "=" + value
        // Do not allow 'default' values from ICU data to be returned here.
        return _withFixedUCharBuffer(defaultIsError: true) { buffer, size, status in
            uloc_getDisplayKeywordValue(lid, keyword, identifier, buffer, size, &status)
        }
    }
}

// MARK: - ICU Extensions on Locale

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Locale {
    /// Returns the `Locale` identifier from a given Windows locale code, or nil if it could not be converted.
    public static func identifier(fromWindowsLocaleCode code: Int) -> String? {
        guard let unsigned = UInt32(exactly: code) else {
            return nil
        }
        
        let result = _withFixedCharBuffer(size: MAX_ICU_NAME_SIZE) { buffer, size, status in
            return uloc_getLocaleForLCID(unsigned, buffer, size, &status)
        }

        return result
    }

    /// Returns the Windows locale code from a given identifier, or nil if it could not be converted.
    public static func windowsLocaleCode(fromIdentifier identifier: String) -> Int? {
        let result = uloc_getLCID(identifier)
        if result == 0 {
            return nil
        } else {
            return Int(result)
        }
    }

    /// Returns the identifier conforming to the specified standard for the specified string.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static func identifier(_ type: IdentifierType, from string: String) -> String {
        Locale(identifier: string).identifier(type)
    }

    /// Returns a list of available `Locale` identifiers.
    public static var availableIdentifiers: [String] {
        var working = Set<String>()
        let localeCount = uloc_countAvailable()
        for locale in 0..<localeCount {
            let localeID = String(cString: uloc_getAvailable(locale))
            working.insert(localeID)
        }
        return Array(working)
    }

    /// Returns a list of common `Locale` currency codes.
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var commonISOCurrencyCodes: [String] {
        Locale.Currency.commonISOCurrencies
    }
}

extension Locale {
    // Helper
    internal static func legacyKey(forKey key: String) -> ICULegacyKey? {
        // Calling into ICU for these values requires quite a bit of I/O. We can precalculate the most important ones here.
        let legacyKey: String
        switch key {
        case "calendar", "colalternate", "colbackwards", "colcasefirst", "colcaselevel", "colhiraganaquaternary", "collation", "colnormalization", "colnumeric", "colreorder", "colstrength", "currency", "hours", "measure", "numbers", "timezone", "variabletop", "cf", "d0", "dx", "em", "fw", "h0", "i0", "k0", "kv", "lb", "lw", "m0", "rg", "s0", "sd", "ss", "t0", "va", "x0":
            legacyKey = key
        case "ca": legacyKey = "calendar"
        case "ka": legacyKey = "colalternate"
        case "kb": legacyKey = "colbackwards"
        case "kf": legacyKey = "colcasefirst"
        case "kc": legacyKey = "colcaselevel"
        case "kh": legacyKey = "colhiraganaquaternary"
        case "co": legacyKey = "collation"
        case "kk": legacyKey = "colnormalization"
        case "kn": legacyKey = "colnumeric"
        case "kr": legacyKey = "colreorder"
        case "ks": legacyKey = "colstrength"
        case "cu": legacyKey = "currency"
        case "hc": legacyKey = "hours"
        case "ms": legacyKey = "measure"
        case "nu": legacyKey = "numbers"
        case "tz": legacyKey = "timezone"
        case "vt": legacyKey = "variabletop"
        default:
            let ulocLegacyKey = _withStringAsCString(key) { uloc_toLegacyKey($0) }
            guard let ulocLegacyKey else {
                return nil
            }

            legacyKey = ulocLegacyKey
        }
        return ICULegacyKey(legacyKey)
    }

    internal static func keywordValue(identifier: String, key: String) -> String? {
        // Unlike other many ICU variables, `ULOC_KEYWORD_AND_VALUES_CAPACITY` does not include null-termination.
        // Manually add one here.
        return _withFixedCharBuffer(size: ULOC_KEYWORD_AND_VALUES_CAPACITY + 1) { buffer, size, status in
            return uloc_getKeywordValue(identifier, key, buffer, size, &status)
        }
    }

    internal static func keywordValue(identifier: String, key: ICULegacyKey) -> String? {
        return keywordValue(identifier: identifier, key: key.key)
    }

    internal static func identifierWithKeywordValue(_ identifier: String, key: ICULegacyKey, value: String) -> String {
        var identifierWithKeywordValue: String?
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(ULOC_FULLNAME_CAPACITY) + 1) { buffer in
            guard let buf: UnsafeMutablePointer<CChar> = buffer.baseAddress else {
                return
            }
            var status = U_ZERO_ERROR
            Platform.copyCString(dst: buf, src: identifier, size: Int(ULOC_FULLNAME_CAPACITY))

            // TODO: This could probably be lifted out of ICU; it is mostly string concatenation
            let len = uloc_setKeywordValue(key.key, value, buf, ULOC_FULLNAME_CAPACITY, &status)
            if status.isSuccess && len > 0 {
                let last = buf.advanced(by: Int(len))
                last.pointee = 0
                identifierWithKeywordValue = String(cString: buf)
            }
        }

        return identifierWithKeywordValue ?? identifier
    }
    // MARK: -

    static func numberingSystemForLocaleIdentifier(_ localeID: String) -> Locale.NumberingSystem {
        if let numbering = Locale.NumberingSystem(localeIdentifierIfSpecified: localeID) {
            return numbering
        }

        return Locale.NumberingSystem.defaultNumberingSystem(for: localeID) ?? .latn
    }

    static func localeIdentifierWithLikelySubtags(_ localeID: String) -> String {
        let maximizedLocaleID = _withFixedCharBuffer { buffer, size, status in
            uloc_addLikelySubtags(localeID, buffer, size, &status)
        }

        guard let maximizedLocaleID else { return localeID }
        return maximizedLocaleID
    }

    // Locale.Components.Language has `identifier` but it does not return nil in case language or script is nil. This is a different algorithm.
    static func languageIdentifierWithScriptCodeForLocaleIdentifier(_ localeID: String) -> String? {
        let maximizedLocaleID = _withFixedCharBuffer { buffer, size, status in
            return uloc_addLikelySubtags(localeID, buffer, size, &status)
        }

        guard let maximizedLocaleID else {
            return nil
        }

        let components = Locale.Components(identifier: maximizedLocaleID)

        guard let languageCode = components.languageComponents.languageCode, let scriptCode = components.languageComponents.script else {
            return nil
        }

        return "\(languageCode.identifier)-\(scriptCode.identifier)"
    }

    static func localeIdentifierByReplacingLanguageCodeAndScriptCode(localeIDWithDesiredLangCode: String, localeIDWithDesiredComponents: String) -> String? {

        guard let langIDToUse = languageIdentifierWithScriptCodeForLocaleIdentifier(localeIDWithDesiredLangCode) else {
            return nil
        }

        let maximizedLocaleID = _withFixedCharBuffer { buffer, size, status in
            return uloc_addLikelySubtags(localeIDWithDesiredComponents, buffer, size, &status)
        }
        guard let maximizedLocaleID else {
            return nil
        }

        var localeIDComponents = Locale.Components(identifier: maximizedLocaleID)
        let languageIDComponents = Locale.Components(identifier: langIDToUse)

        guard let languageCode = languageIDComponents.languageComponents.languageCode else {
            return nil
        }

        guard let scriptCode = languageIDComponents.languageComponents.script else {
            return nil
        }

        // 1. Language & Script
        // Note that both `languageCode` and `scriptCode` should be overridden in `localeIDComponents`, even for combinations like `en` + `latn`, because the previous language’s script may not be compatible with the new language. This will produce a “maximized” locale identifier, which we will canonicalize (below) to remove superfluous tags.
        localeIDComponents.languageComponents.languageCode = languageCode
        localeIDComponents.languageComponents.script = scriptCode

        // 2. Numbering System
        let numberingSystem = numberingSystemForLocaleIdentifier(localeIDWithDesiredComponents)
        let validNumberingSystems = Locale.NumberingSystem.validNumberingSystems(for: localeIDWithDesiredLangCode)

        if let whichNumberingSystem = validNumberingSystems.firstIndex(of: numberingSystem) {
            if whichNumberingSystem == 0 {
                // The numbering system is already the default numbering system (index 0)
                localeIDComponents.numberingSystem = nil
            } else if whichNumberingSystem > 0 {
                // If the numbering system for `localeIDWithDesiredComponents` is compatible with the constructed locale’s language and is not already the default numbering system (index 0), then set it on the new locale, e.g. `hi_IN@numbers=latn` + `ar` should get `ar_IN@numbers=latn`, since `latn` is valid for `ar`.
                localeIDComponents.numberingSystem = validNumberingSystems[whichNumberingSystem]
            }

        } else {
            // If the numbering system for `localeIDWithDesiredComponents` is not compatible with the constructed locale’s language, then we should discard it, e.g. `ar_AE@numbers=arab` + `en` should get `en_AE`, not `en_AE@numbers=arab`, since `arab` is not valid for `en`.
            localeIDComponents.numberingSystem = nil
        }

        // 3. Construct & Canonicalize
        // The locale constructed from the components will be over-specified for many cases, such as `en_Latn_US`. Before returning it, we should canonicalize it, which will remove any script code that is already implicit in the definition of the locale, yielding `en_US` instead.
        let idFromComponents = localeIDComponents.icuIdentifier
        return Locale._canonicalLocaleIdentifier(from: idFromComponents)
    }

    // MARK: -

    /// Creates a new locale identifier by identifying the most preferred localization (using `canonicalizedLocalizations` and `preferredLanguages`) and then creating a locale based on the most preferred localization, while retaining any relevant attributes from `preferredLocaleID`.
    /// For example, if `canonicalizedLocalizations` is `[ "en", "fr", "de" ]`, `preferredLanguages` is `[ "ar-AE", "en-AE" ]`, `preferredLocaleID` is `ar_AE@numbers=arab;calendar=islamic-civil`, it will return `en_AE@calendar=islamic-civil`, i.e. the language will be matched to `en` since that’s the only available localization that matches, `calendar` will be retained since it’s language-agnostic, but `numbers` will be discarded because the `arab` numbering system is not valid for `en`.
    internal static func localeIdentifierForCanonicalizedLocalizations(_ canonicalizedLocalizations: [String], preferredLanguages: [String], preferredLocaleID: String) -> String? {
        guard !canonicalizedLocalizations.isEmpty && !preferredLanguages.isEmpty && !preferredLocaleID.isEmpty else {
            return nil
        }

        let canonicalizedPreferredLanguages = canonicalizeLocalizations(preferredLanguages)

        // Combine `canonicalizedLocalizations` with `canonicalizedPreferredLanguages` to get `preferredLocalizations`. `[0]` indicates the localization that the app is currently launched in.
        let preferredLocalizations = Bundle.preferredLocalizations(from: canonicalizedLocalizations, forPreferences: canonicalizedPreferredLanguages)

        guard preferredLocalizations.count > 0 else { return nil }

        // If we didn't find an overlap, we go with the preferred locale of the bundle.
        let preferredLocalization = preferredLocalizations[0]

        // The goal here is to preserve all of the overrides present in the value stored in AppleLocale (e.g. "@calendar=buddhist")

        let preferredLocaleLanguageID = languageIdentifierWithScriptCodeForLocaleIdentifier(preferredLocaleID)
        let preferredLocalizationLanguageID = languageIdentifierWithScriptCodeForLocaleIdentifier(preferredLocalization)

        if let preferredLocaleLanguageID, let preferredLocalizationLanguageID {
            if preferredLocaleLanguageID == preferredLocalizationLanguageID {
                return preferredLocaleID
            } else {
                return localeIdentifierByReplacingLanguageCodeAndScriptCode(localeIDWithDesiredLangCode: preferredLocalization, localeIDWithDesiredComponents: preferredLocaleID)
            }
        }

        return nil
    }

    static fileprivate func canonicalizeLocalizations(_ locs: [String]) -> [String] {
        locs.compactMap {
            Locale.canonicalLanguageIdentifier(from: $0)
        }
    }

}
