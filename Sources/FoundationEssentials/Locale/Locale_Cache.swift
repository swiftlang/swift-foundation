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
internal import _ForSwiftFoundation
import CoreFoundation
internal import CoreFoundation_Private.CFNotificationCenter
internal import os
#endif

internal import _CShims

/// Singleton which listens for notifications about preference changes for Locale and holds cached singletons.
struct LocaleCache : Sendable {
    // MARK: - Concrete Classes
    
    // _LocaleICU, if present. Otherwise we use _LocaleUnlocalized. The `Locale` initializers are not failable, so we just fall back to the unlocalized type when needed without failure.
    static var localeICUClass: _LocaleProtocol.Type = {
#if FOUNDATION_FRAMEWORK && canImport(FoundationICU)
        return _LocaleICU.self
#else
        if let name = _typeByName("FoundationInternationalization._LocaleICU"), let t = name as? _LocaleProtocol.Type {
            return t
        } else {
            return _LocaleUnlocalized.self
        }
#endif
    }()

    // MARK: - State
    
    struct State {
        private var cachedCurrentLocale: (any _LocaleProtocol)!
        private var cachedSystemLocale: (any _LocaleProtocol)!
        private var cachedFixedLocales: [String : any _LocaleProtocol] = [:]
        private var cachedFixedComponentsLocales: [Locale.Components : any _LocaleProtocol] = [:]

#if FOUNDATION_FRAMEWORK
        private var cachedCurrentNSLocale: _NSSwiftLocale!
        private var cachedAutoupdatingNSLocale: _NSSwiftLocale!
        private var cachedSystemNSLocale: _NSSwiftLocale!
        private var cachedFixedIdentifierToNSLocales: [String : _NSSwiftLocale] = [:]
        
        struct IdentifierAndPrefs : Hashable {
            let identifier: String
            let prefs: LocalePreferences?
        }
        
        private var cachedFixedLocaleToNSLocales: [IdentifierAndPrefs : _NSSwiftLocale] = [:]
#endif

        private var cachedAutoupdatingLocale: _LocaleAutoupdating!
        
        private var noteCount = -1
        private var wasResetManually = false

        /// Clears the cached `Locale` values, if they need to be recalculated.
        mutating func resetCurrentIfNeeded() {
#if FOUNDATION_FRAMEWORK
            let newNoteCount = _CFLocaleGetNoteCount() + _CFTimeZoneGetNoteCount() + Int(_CFCalendarGetMidnightNoteCount())
#else
            let newNoteCount = 1
#endif

            if newNoteCount != noteCount || wasResetManually {
                cachedCurrentLocale = nil
                noteCount = newNoteCount
                wasResetManually = false

#if FOUNDATION_FRAMEWORK
                cachedCurrentNSLocale = nil
                // For Foundation.framework, we listen for system notifications about the system Locale changing from the Darwin notification center.
                _CFNotificationCenterInitializeDependentNotificationIfNecessary(CFNotificationName.cfLocaleCurrentLocaleDidChange!.rawValue)
#endif
            }
        }

        /// Get or create the current locale.
        /// `disableBundleMatching` should normally be disabled (`false`). The only reason to turn it on (`true`) is if we are attempting to create a testing scenario that does not use the main bundle's languages.
        mutating func current(preferences: LocalePreferences?, cache: Bool, disableBundleMatching: Bool) -> (any _LocaleProtocol)? {
            resetCurrentIfNeeded()

            if let cachedCurrentLocale {
                return cachedCurrentLocale
            }
            
            // At this point we know we need to create, or re-create, the Locale instance.
            // If we do not have a set of preferences to use, we have to return nil.
            guard let preferences else {
                return nil
            }

            let locale = LocaleCache.localeICUClass.init(name: nil, prefs: preferences, disableBundleMatching: disableBundleMatching)
            if cache {
                // It's possible this was an 'incomplete locale', in which case we will want to calculate it again later.
                self.cachedCurrentLocale = locale
            }

            return locale
        }
        
        mutating func autoupdatingCurrent() -> _LocaleAutoupdating {
            if let cached = cachedAutoupdatingLocale {
                return cached
            } else {
                cachedAutoupdatingLocale = _LocaleAutoupdating()
                return cachedAutoupdatingLocale
            }
        }

        mutating func fixed(_ id: String) -> any _LocaleProtocol {
            // Note: Even if the currentLocale's identifier is the same, currentLocale may have preference overrides which are not reflected in the identifier itself.
            if let locale = cachedFixedLocales[id] {
                return locale
            } else {
                let locale = LocaleCache.localeICUClass.init(identifier: id, prefs: nil)
                cachedFixedLocales[id] = locale
                return locale
            }
        }

#if FOUNDATION_FRAMEWORK
        mutating func fixedNSLocale(identifier id: String) -> _NSSwiftLocale {
            if let locale = cachedFixedIdentifierToNSLocales[id] {
                return locale
            } else {
                let inner = Locale(inner: fixed(id))
                let locale = _NSSwiftLocale(inner)
                // We have found ObjC clients that rely upon an immortal lifetime for these `Locale`s, so we do not clear this cache.
                cachedFixedIdentifierToNSLocales[id] = locale
                return locale
            }
        }
        
#if canImport(FoundationICU)
        mutating func fixedNSLocale(_ locale: _LocaleICU) -> _NSSwiftLocale {
            let id = IdentifierAndPrefs(identifier: locale.identifier, prefs: locale.prefs)
            if let locale = cachedFixedLocaleToNSLocales[id] {
                return locale
            } else {
                let inner = Locale(inner: locale)
                let nsLocale = _NSSwiftLocale(inner)
                // We have found ObjC clients that rely upon an immortal lifetime for these `Locale`s, so we do not clear this cache.
                cachedFixedLocaleToNSLocales[id] = nsLocale
                return nsLocale
            }
        }
#endif

        mutating func currentNSLocale(preferences: LocalePreferences?, cache: Bool) -> _NSSwiftLocale? {
            resetCurrentIfNeeded()

            if let currentNSLocale = cachedCurrentNSLocale {
                return currentNSLocale
            } else if let current = cachedCurrentLocale {
                // We have a cached Swift Locale but not an NSLocale, yet
                let nsLocale = _NSSwiftLocale(Locale(inner: current))
                cachedCurrentNSLocale = nsLocale
                return nsLocale
            }
            
            // At this point we know we need to create, or re-create, the Locale instance.
            
            // If we do not have a set of preferences to use, we have to return nil.
            guard let preferences else {
                return nil
            }

#if canImport(FoundationICU)
            // We have neither a Swift Locale nor an NSLocale. Recalculate and set both.
            let locale = _LocaleICU(name: nil, prefs: preferences, disableBundleMatching: false)
#else
            let locale = _LocaleUnlocalized(name: nil, prefs: preferences, disableBundleMatching: false)
#endif
            let nsLocale = _NSSwiftLocale(Locale(inner: locale))
            
            if cache {
                // It's possible this was an 'incomplete locale', in which case we will want to calculate it again later.
                self.cachedCurrentLocale = locale
                cachedCurrentNSLocale = nsLocale
            }

            return nsLocale
        }

        mutating func autoupdatingNSLocale() -> _NSSwiftLocale {
            if let result = cachedAutoupdatingNSLocale {
                return result
            }

            // Don't call Locale.autoupdatingCurrent directly to avoid a recursive lock
            cachedAutoupdatingNSLocale = _NSSwiftLocale(Locale(inner: autoupdatingCurrent()))
            return cachedAutoupdatingNSLocale
        }

        mutating func systemNSLocale() -> _NSSwiftLocale {
            if let result = cachedSystemNSLocale {
                return result
            }

            let inner = Locale(inner: system())
            cachedSystemNSLocale = _NSSwiftLocale(inner)
            return cachedSystemNSLocale
        }
#endif // FOUNDATION_FRAMEWORK

        mutating func fixedComponents(_ comps: Locale.Components) -> any _LocaleProtocol {
            if let l = cachedFixedComponentsLocales[comps] {
                return l
            } else {
                let new = LocaleCache.localeICUClass.init(components: comps)
                
                cachedFixedComponentsLocales[comps] = new
                return new
            }
        }

        mutating func system() -> any _LocaleProtocol {
            if let locale = cachedSystemLocale {
                return locale
            }

            let locale = LocaleCache.localeICUClass.init(identifier: "", prefs: nil)
            cachedSystemLocale = locale
            return locale
        }

        mutating func reset() {
            wasResetManually = true
        }
    }

    let lock: LockedState<State>

    static let cache = LocaleCache()

    fileprivate init() {
        lock = LockedState(initialState: State())
    }

    func reset() {
        lock.withLock { $0.reset() }
    }

    /// For testing of `autoupdatingCurrent` only. If you want to test `current`, create a custom `Locale` with the appropriate settings using `localeAsIfCurrent(name:overrides:disableBundleMatching:)` and use that instead.
    /// This mutates global state of the current locale, so it is not safe to use in concurrent testing.
    func resetCurrent(to preferences: LocalePreferences) {
        lock.withLock {
            $0.reset()
            // Disable bundle matching so we can emulate a non-English main bundle during test
            let _ = $0.current(preferences: preferences, cache: true, disableBundleMatching: true)
        }
    }

    var current: any _LocaleProtocol {
        var result = lock.withLock {
            $0.current(preferences: nil, cache: false, disableBundleMatching: false)
        }
        
        if let result { return result }
        
        // We need to fetch prefs and try again
        let (prefs, doCache) = preferences()
        
        result = lock.withLock {
            $0.current(preferences: prefs, cache: doCache, disableBundleMatching: false)
        }
        
        guard let result else {
            fatalError("Nil result getting current Locale with preferences")
        }
        
        return result
    }
    
    /// This value is immutable, so we can share one instance for the whole process.
    private static let _unlocalizedCache = _LocaleUnlocalized(identifier: "en_001")
    var unlocalized: _LocaleUnlocalized {
        Self._unlocalizedCache
    }
    
    var autoupdatingCurrent: _LocaleAutoupdating {
        lock.withLock { $0.autoupdatingCurrent() }
    }

    var system: any _LocaleProtocol {
        lock.withLock { $0.system() }
    }

    func fixed(_ id: String) -> any _LocaleProtocol {
        lock.withLock { $0.fixed(id) }
    }

#if FOUNDATION_FRAMEWORK
    func fixedNSLocale(identifier id: String) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(identifier: id) }
    }

#if canImport(FoundationICU)
    func fixedNSLocale(_ locale: _LocaleICU) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(locale) }
    }
#endif

    func autoupdatingCurrentNSLocale() -> _NSSwiftLocale {
        lock.withLock { $0.autoupdatingNSLocale() }
    }

    func currentNSLocale() -> _NSSwiftLocale {
        var result = lock.withLock {
            $0.currentNSLocale(preferences: nil, cache: false)
        }
        
        if let result { return result }
        
        // We need to fetch prefs and try again. Don't do this inside a lock (106190030). On Darwin it is possible to get a KVO callout from fetching the preferences, which could ask for the current Locale, which could cause a reentrant lock.
        let (prefs, doCache) = preferences()
        
        result = lock.withLock {
            $0.currentNSLocale(preferences: prefs, cache: doCache)
        }
        
        guard let result else {
            fatalError("Nil result getting current NSLocale with preferences")
        }
        
        return result
    }

    func systemNSLocale() -> _NSSwiftLocale {
        lock.withLock { $0.systemNSLocale() }
    }
#endif // FOUNDATION_FRAMEWORK

    func fixedComponents(_ comps: Locale.Components) -> any _LocaleProtocol {
        lock.withLock { $0.fixedComponents(comps) }
    }
    
#if FOUNDATION_FRAMEWORK && !NO_CFPREFERENCES
    func preferences() -> (LocalePreferences, Bool) {
        // On Darwin, we check the current user preferences for Locale values
        var wouldDeadlock: DarwinBoolean = false
        let cfPrefs = __CFXPreferencesCopyCurrentApplicationStateWithDeadlockAvoidance(&wouldDeadlock).takeRetainedValue()

        var prefs = LocalePreferences()
        prefs.apply(cfPrefs)
        
        if wouldDeadlock.boolValue {
            // Don't cache a locale built with incomplete prefs
            return (prefs, false)
        } else {
            return (prefs, true)
        }
    }
    
    func preferredLanguages(forCurrentUser: Bool) -> [String] {
        var languages: [String] = []
        if forCurrentUser {
            languages = CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
        } else {
            languages = CFPreferencesCopyAppValue("AppleLanguages" as CFString, kCFPreferencesCurrentApplication) as? [String] ?? []
        }
        
        return languages.compactMap {
            Locale.canonicalLanguageIdentifier(from: $0)
        }
    }
    
    func preferredLocale() -> String? {
        guard let preferredLocaleID = CFPreferencesCopyAppValue("AppleLocale" as CFString, kCFPreferencesCurrentApplication) as? String else {
            return nil
        }
        return preferredLocaleID
    }
#else
    func preferences() -> (LocalePreferences, Bool) {
        var prefs = LocalePreferences()
        prefs.locale = "en_001"
        prefs.languages = ["en-001"]
        return (prefs, true)
    }

    func preferredLanguages(forCurrentUser: Bool) -> [String] {
        [Locale.canonicalLanguageIdentifier(from: "en-001")]
    }
    
    func preferredLocale() -> String? {
        "en_001"
    }
#endif
    
#if FOUNDATION_FRAMEWORK && !NO_CFPREFERENCES
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    func localeAsIfCurrent(name: String?, cfOverrides: CFDictionary? = nil, disableBundleMatching: Bool = false) -> Locale {
        
        var (prefs, _) = preferences()
        if let cfOverrides { prefs.apply(cfOverrides) }
        
        let inner = _LocaleICU(name: name, prefs: prefs, disableBundleMatching: disableBundleMatching)
        return Locale(inner: inner)
    }
#endif
    
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    func localeAsIfCurrent(name: String?, overrides: LocalePreferences? = nil, disableBundleMatching: Bool = false) -> Locale {
        var (prefs, _) = preferences()
        if let overrides { prefs.apply(overrides) }
        
        let inner = LocaleCache.localeICUClass.init(name: name, prefs: prefs, disableBundleMatching: disableBundleMatching)
        return Locale(inner: inner)
    }

    func localeWithPreferences(identifier: String, prefs: LocalePreferences?) -> Locale {
        let inner = LocaleCache.localeICUClass.init(identifier: identifier, prefs: prefs)
        return Locale(inner: inner)
    }

    func localeAsIfCurrentWithBundleLocalizations(_ availableLocalizations: [String], allowsMixedLocalizations: Bool) -> Locale? {
#if FOUNDATION_FRAMEWORK && canImport(FoundationICU)
        guard !allowsMixedLocalizations else {
            let (prefs, _) = preferences()
            let inner = _LocaleICU(name: nil, prefs: prefs, disableBundleMatching: true)
            return Locale(inner: inner)
        }

        let preferredLanguages = preferredLanguages(forCurrentUser: false)
        guard let preferredLocaleID = preferredLocale() else { return nil }
        
        let canonicalizedLocalizations = availableLocalizations.compactMap { Locale.canonicalLanguageIdentifier(from: $0) }
        let identifier = Locale.localeIdentifierForCanonicalizedLocalizations(canonicalizedLocalizations, preferredLanguages: preferredLanguages, preferredLocaleID: preferredLocaleID)
        guard let identifier else {
            return nil
        }

        let (prefs, _) = preferences()
        let inner = _LocaleICU(identifier: identifier, prefs: prefs)
        return Locale(inner: inner)
#else
        // No way to canonicalize on this platform
        return nil
#endif
    }
}
