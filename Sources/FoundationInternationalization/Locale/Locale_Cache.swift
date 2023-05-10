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
@_implementationOnly import CoreFoundation_Private.CFNotificationCenter
@_implementationOnly import os
@_implementationOnly import _CShims
#else
package import _CShims
#endif

/// Singleton which listens for notifications about preference changes for Locale and holds cached singletons.
struct LocaleCache : Sendable {
    struct State {
        private var cachedCurrentLocale: _Locale!
        private var cachedSystemLocale: _Locale!
        private var cachedFixedLocales: [String : _Locale] = [:]
        private var cachedFixedComponentsLocales: [Locale.Components : _Locale] = [:]

#if FOUNDATION_FRAMEWORK
        private var cachedCurrentNSLocale: _NSSwiftLocale!
        private var cachedAutoupdatingNSLocale: _NSSwiftLocale!
        private var cachedSystemNSLocale: _NSSwiftLocale!
        private var cachedFixedIdentifierToNSLocales: [String : _NSSwiftLocale] = [:]
        private var cachedFixedLocaleToNSLocales: [_Locale : _NSSwiftLocale] = [:]
#endif

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

        mutating func current(preferences: LocalePreferences?, cache: Bool) -> _Locale? {
            resetCurrentIfNeeded()

            if let cachedCurrentLocale {
                return cachedCurrentLocale
            }
            
            // At this point we know we need to create, or re-create, the Locale instance.
            // If we do not have a set of preferences to use, we have to return nil.
            guard let preferences else {
                return nil
            }

            let locale = _Locale(name: nil, prefs: preferences, disableBundleMatching: false)
            if cache {
                // It's possible this was an 'incomplete locale', in which case we will want to calculate it again later.
                self.cachedCurrentLocale = locale
            }

            return locale
        }

        mutating func fixed(_ id: String) -> _Locale {
            // Note: Even if the currentLocale's identifier is the same, currentLocale may have preference overrides which are not reflected in the identifier itself.
            if let locale = cachedFixedLocales[id] {
                return locale
            } else {
                let locale = _Locale(identifier: id)
                cachedFixedLocales[id] = locale
                return locale
            }
        }

#if FOUNDATION_FRAMEWORK
        mutating func fixedNSLocale(_ id: String) -> _NSSwiftLocale {
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
        
        mutating func fixedNSLocale(_ locale: _Locale) -> _NSSwiftLocale {
            if let locale = cachedFixedLocaleToNSLocales[locale] {
                return locale
            } else {
                let inner = Locale(inner: locale)
                let nsLocale = _NSSwiftLocale(inner)
                // We have found ObjC clients that rely upon an immortal lifetime for these `Locale`s, so we do not clear this cache.
                cachedFixedLocaleToNSLocales[locale] = nsLocale
                return nsLocale
            }
        }

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

            // We have neither a Swift Locale nor an NSLocale. Recalculate and set both.
            let locale = _Locale(name: nil, prefs: preferences, disableBundleMatching: false)
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

            cachedAutoupdatingNSLocale = _NSSwiftLocale(Locale.autoupdatingCurrent)
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

        mutating func fixedComponents(_ comps: Locale.Components) -> _Locale {
            if let l = cachedFixedComponentsLocales[comps] {
                return l
            } else {
                let new = _Locale(components: comps)
                cachedFixedComponentsLocales[comps] = new
                return new
            }
        }

        mutating func system() -> _Locale {
            if let locale = cachedSystemLocale {
                return locale
            }

            let locale = _Locale(identifier: "")
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

    var current: _Locale {
        var result = lock.withLock {
            $0.current(preferences: nil, cache: false)
        }
        
        if let result { return result }
        
        // We need to fetch prefs and try again
        let (prefs, doCache) = preferences()
        
        result = lock.withLock {
            $0.current(preferences: prefs, cache: doCache)
        }
        
        guard let result else {
            fatalError("Nil result getting current Locale with preferences")
        }
        
        return result
    }

    var system: _Locale {
        lock.withLock { $0.system() }
    }

    func fixed(_ id: String) -> _Locale {
        lock.withLock { $0.fixed(id) }
    }

#if FOUNDATION_FRAMEWORK
    func fixedNSLocale(_ id: String) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(id) }
    }

    func fixedNSLocale(_ locale: _Locale) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(locale) }
    }

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

    func fixedComponents(_ comps: Locale.Components) -> _Locale {
        lock.withLock { $0.fixedComponents(comps) }
    }
    
#if FOUNDATION_FRAMEWORK
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
        prefs.locale = "en_US"
        prefs.languages = ["en-US"]
        return (prefs, true)
    }

    func preferredLanguages(forCurrentUser: Bool) -> [String] {
        [Locale.canonicalLanguageIdentifier(from: "en-US")]
    }
    
    func preferredLocale() -> String? {
        "en_US"
    }
#endif
    
#if FOUNDATION_FRAMEWORK
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    func localeAsIfCurrent(name: String?, cfOverrides: CFDictionary? = nil, disableBundleMatching: Bool = false) -> Locale {
        
        var (prefs, _) = preferences()
        if let cfOverrides { prefs.apply(cfOverrides) }
        
        let inner = _Locale(name: name, prefs: prefs, disableBundleMatching: disableBundleMatching)
        return Locale(.fixed(inner))
    }
#endif
    
    /// This returns an instance of `Locale` that's set up exactly like it would be if the user changed the current locale to that identifier, set the preferences keys in the overrides dictionary, then called `current`.
    func localeAsIfCurrent(name: String?, overrides: LocalePreferences? = nil, disableBundleMatching: Bool = false) -> Locale {
        var (prefs, _) = preferences()
        if let overrides { prefs.apply(overrides) }
        
        let inner = _Locale(name: name, prefs: prefs, disableBundleMatching: disableBundleMatching)
        return Locale(.fixed(inner))
    }


    func localeAsIfCurrentWithBundleLocalizations(_ availableLocalizations: [String], allowsMixedLocalizations: Bool) -> Locale? {
        guard !allowsMixedLocalizations else {
            let (prefs, _) = preferences()
            let inner = _Locale(name: nil, prefs: prefs, disableBundleMatching: true)
            return Locale(.fixed(inner))
        }

        let preferredLanguages = preferredLanguages(forCurrentUser: false)
        guard let preferredLocaleID = preferredLocale() else { return nil }
        
        let canonicalizedLocalizations = availableLocalizations.compactMap { Locale.canonicalLanguageIdentifier(from: $0) }
        let identifier = _Locale.localeIdentifierForCanonicalizedLocalizations(canonicalizedLocalizations, preferredLanguages: preferredLanguages, preferredLocaleID: preferredLocaleID)
        guard let identifier else {
            return nil
        }

        let inner = _Locale(identifier: identifier)
        return Locale(.fixed(inner))
    }
}
