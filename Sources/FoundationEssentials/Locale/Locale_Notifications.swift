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

#if canImport(Synchronization) && FOUNDATION_FRAMEWORK
internal import Synchronization
#endif

/// Keeps a global generation count for updated Locale information, including locale, time zone, and calendar preferences.
/// If any of those preferences change, then `count` will update to a new value. Compare that to a cached value to see if your cached `Locale.current`, `TimeZone.current`, or `Calendar.current` to see if it is out of date.
/// If any cached values need to be recalculated process-wide, call `reset`.
struct LocaleNotifications : Sendable, ~Copyable {
    static let cache = LocaleNotifications()
    
#if canImport(Synchronization) && FOUNDATION_FRAMEWORK
    let _count = Atomic<Int>(1)
#else
    let _count = LockedState<Int>(initialState: 1)
#endif
    
    func count() -> Int {
#if canImport(Synchronization) && FOUNDATION_FRAMEWORK
        _count.load(ordering: .relaxed)
#else
        _count.withLock { $0 }
#endif
    }
    
    /// Make a new generation current, but no associated Locale.
    func reset() {
        LocaleCache.cache.reset()
        CalendarCache.cache.reset()
        _ = TimeZoneCache.cache.reset()
#if canImport(Synchronization) && FOUNDATION_FRAMEWORK
        _count.add(1, ordering: .relaxed)
#else
        _count.withLock { $0 += 1 }
#endif
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_localeNotificationCount")
func _localeNotificationCount() -> Int {
    LocaleNotifications.cache.count()
}
#endif

