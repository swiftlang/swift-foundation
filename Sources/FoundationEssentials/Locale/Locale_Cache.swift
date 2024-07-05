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

internal import _FoundationCShims

/// Singleton which listens for notifications about preference changes for Locale and holds cached singletons.
/// A note about locking and thread safety: The idea of 'current' or 'autoupdating current' is inherently racy. It is possible to ask for the current Locale, and before getting back the instance, the idea of current has changed due to some notification post. This is deemed acceptable for this use case. The only requirement is that the returned value is actually safe to use, not a dangling pointer or garbage value.
internal struct LocaleCache : Sendable, ~Copyable {
    // MARK: - Concrete Classes
    
    // _LocaleICU, if present. Otherwise we use _LocaleUnlocalized. The `Locale` initializers are not failable, so we just fall back to the unlocalized type when needed without failure.
    static let localeICUClass: _LocaleProtocol.Type = {
#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
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
        
        init() {
#if FOUNDATION_FRAMEWORK
            // For Foundation.framework, we listen for system notifications about the system Locale changing from the Darwin notification center.
            _CFNotificationCenterInitializeDependentNotificationIfNecessary(CFNotificationName.cfLocaleCurrentLocaleDidChange!.rawValue)
#endif
        }
        
        private var cachedFixedLocales: [String : any _LocaleProtocol] = [:]
        private var cachedFixedComponentsLocales: [Locale.Components : any _LocaleProtocol] = [:]

#if FOUNDATION_FRAMEWORK
        private var cachedFixedIdentifierToNSLocales: [String : _NSSwiftLocale] = [:]
        
        struct IdentifierAndPrefs : Hashable {
            let identifier: String
            let prefs: LocalePreferences?
        }
        
        private var cachedFixedLocaleToNSLocales: [IdentifierAndPrefs : _NSSwiftLocale] = [:]
#endif
                
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
        
#if canImport(_FoundationICU)
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

#endif // FOUNDATION_FRAMEWORK

        func fixedComponents(_ comps: Locale.Components) -> (any _LocaleProtocol)? {
            cachedFixedComponentsLocales[comps]
        }
        
        mutating func fixedComponentsWithCache(_ comps: Locale.Components) -> any _LocaleProtocol {
            if let l = fixedComponents(comps) {
                return l
            } else {
                let new = LocaleCache.localeICUClass.init(components: comps)
                
                cachedFixedComponentsLocales[comps] = new
                return new
            }
        }
    }

    let lock: LockedState<State>
    
    static let cache = LocaleCache()
    private let _currentCache = LockedState<(any _LocaleProtocol)?>(initialState: nil)
    
#if FOUNDATION_FRAMEWORK
    private var _currentNSCache = LockedState<_NSSwiftLocale?>(initialState: nil)
#endif
    
    fileprivate init() {
        lock = LockedState(initialState: State())
    }

    
    /// For testing of `autoupdatingCurrent` only. If you want to test `current`, create a custom `Locale` with the appropriate settings using `localeAsIfCurrent(name:overrides:disableBundleMatching:)` and use that instead.
    /// This mutates global state of the current locale, so it is not safe to use in concurrent testing.
    func resetCurrent(to preferences: LocalePreferences) {
        // Disable bundle matching so we can emulate a non-English main bundle during test
        let newLocale = LocaleCache.localeICUClass.init(name: nil, prefs: preferences, disableBundleMatching: true)
        _currentCache.withLock {
            $0 = newLocale
        }
#if FOUNDATION_FRAMEWORK
        _currentNSCache.withLock { $0 = nil }
#endif
    }

    func reset() {
        _currentCache.withLock { $0 = nil }
#if FOUNDATION_FRAMEWORK
        _currentNSCache.withLock { $0 = nil }
#endif
    }

    var current: any _LocaleProtocol {
        if let result = _currentCache.withLock({ $0 }) {
            return result
        }
        
        // We need to fetch prefs and try again
        let (preferences, doCache) = preferences()
        let locale = LocaleCache.localeICUClass.init(name: nil, prefs: preferences, disableBundleMatching: false)
        
        // It's possible this was an 'incomplete locale', in which case we will want to calculate it again later.
        if doCache {
            return _currentCache.withLock {
                if let current = $0 {
                    // Someone beat us to setting it - use existing one
                    return current
                } else {
                    $0 = locale
                    return locale
                }
            }
        }
        
        return locale
    }
    
    // MARK: Singletons
    
    // This value is immutable, so we can share one instance for the whole process.
    static let unlocalized = _LocaleUnlocalized(identifier: "en_001")

    // This value is immutable, so we can share one instance for the whole process.
    static let autoupdatingCurrent = _LocaleAutoupdating()

    static let system : any _LocaleProtocol = {
        LocaleCache.localeICUClass.init(identifier: "", prefs: nil)
    }()
    
#if FOUNDATION_FRAMEWORK
    static let autoupdatingCurrentNSLocale : _NSSwiftLocale = {
        _NSSwiftLocale(Locale(inner: autoupdatingCurrent))
    }()
    
    static let systemNSLocale : _NSSwiftLocale = {
        _NSSwiftLocale(Locale(inner: system))
    }()
#endif
    
    // MARK: -
    
    func fixed(_ id: String) -> any _LocaleProtocol {
        lock.withLock {
            $0.fixed(id)
        }
    }

#if FOUNDATION_FRAMEWORK
    func fixedNSLocale(identifier id: String) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(identifier: id) }
    }

#if canImport(_FoundationICU)
    func fixedNSLocale(_ locale: _LocaleICU) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(locale) }
    }
#endif

    func currentNSLocale() -> _NSSwiftLocale {
        if let result = _currentNSCache.withLock({ $0 }) {
            return result
        }
        
        // Create the current _NSSwiftLocale, based on the current Swift Locale.
        let nsLocale = _NSSwiftLocale(Locale(inner: current))
            
        // TODO: The current locale has an idea of not caching, which we have never honored here in the NSLocale cache
        return _currentNSCache.withLock {
            if let current = $0 {
                // Someone beat us to setting it, use that one
                return current
            } else {
                $0 = nsLocale
                return nsLocale
            }
        }
    }

#endif // FOUNDATION_FRAMEWORK

    func fixedComponents(_ comps: Locale.Components) -> any _LocaleProtocol {
        lock.withLock { $0.fixedComponentsWithCache(comps) }
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
        if let prefs {
            let inner = LocaleCache.localeICUClass.init(identifier: identifier, prefs: prefs)
            return Locale(inner: inner)
        } else {
            return Locale(inner: LocaleCache.cache.fixed(identifier))
        }
    }

    func localeAsIfCurrentWithBundleLocalizations(_ availableLocalizations: [String], allowsMixedLocalizations: Bool) -> Locale? {
#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
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
