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
#endif

#if canImport(_CShims)
@_implementationOnly import _CShims
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
        private var cachedFixedNSLocales: [String : _NSSwiftLocale] = [:]
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

        mutating func current() -> _Locale {
            resetCurrentIfNeeded()

            if let cachedCurrentLocale {
                return cachedCurrentLocale
            } else {
                let (locale, doCache) = _Locale._currentLocaleWithOverrides(name: nil, overrides: nil, disableBundleMatching: false)
                if doCache {
                    self.cachedCurrentLocale = locale
                }
                return locale
            }
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
            if let locale = cachedFixedNSLocales[id] {
                return locale
            } else {
                let inner = Locale(inner: fixed(id))
                let locale = _NSSwiftLocale(inner)
                // We have found ObjC clients that rely upon an immortal lifetime for these `Locale`s, so we do not clear this cache.
                cachedFixedNSLocales[id] = locale
                return locale
            }
        }

        mutating func currentNSLocale() -> _NSSwiftLocale {
            resetCurrentIfNeeded()

            if let currentNSLocale = cachedCurrentNSLocale {
                return currentNSLocale
            } else if let current = cachedCurrentLocale {
                // We have a cached Swift Locale but not an NSLocale, yet
                let nsLocale = _NSSwiftLocale(Locale(inner: current))
                cachedCurrentNSLocale = nsLocale
                return nsLocale
            } else {
                // We have neither a Swift Locale nor an NSLocale. Recalculate and set both.
                let (locale, doCache) = _Locale._currentLocaleWithOverrides(name: nil, overrides: nil, disableBundleMatching: false)
                let nsLocale = _NSSwiftLocale(Locale(inner: locale))
                if doCache {
                    // It's possible this was an 'incomplete locale', in which case we will want to calculate it again later.
                    self.cachedCurrentLocale = locale
                    cachedCurrentNSLocale = nsLocale
                }
                return nsLocale
            }
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
        lock.withLock { $0.current() }
    }

    var system: _Locale {
        lock.withLock { $0.system() }
    }

    var preferred: _Locale {
        let (locale, _) = _Locale._currentLocaleWithOverrides(name: nil, overrides: nil, disableBundleMatching: false)
        return locale
    }

    func fixed(_ id: String) -> _Locale {
        lock.withLock { $0.fixed(id) }
    }

#if FOUNDATION_FRAMEWORK
    func fixedNSLocale(_ id: String) -> _NSSwiftLocale {
        lock.withLock { $0.fixedNSLocale(id) }
    }

    func autoupdatingCurrentNSLocale() -> _NSSwiftLocale {
        lock.withLock { $0.autoupdatingNSLocale() }
    }

    func currentNSLocale() -> _NSSwiftLocale {
        lock.withLock { $0.currentNSLocale() }
    }

    func systemNSLocale() -> _NSSwiftLocale {
        lock.withLock { $0.systemNSLocale() }
    }
#endif // FOUNDATION_FRAMEWORK

    func fixedComponents(_ comps: Locale.Components) -> _Locale {
        lock.withLock { $0.fixedComponents(comps) }
    }
}
