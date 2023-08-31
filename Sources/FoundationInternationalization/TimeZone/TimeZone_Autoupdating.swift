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
#endif

/// A time zone which always reflects what the currently set time zone is. Aka `local` in Objective-C.
internal final class _TimeZoneAutoupdating : _TimeZoneBase, Sendable {
    override var identifier: String {
        TimeZoneCache.cache.current.identifier
    }
    
    override func secondsFromGMT(for date: Date = Date()) -> Int {
        TimeZoneCache.cache.current.secondsFromGMT(for: date)
    }
    
    override func abbreviation(for date: Date = Date()) -> String? {
        TimeZoneCache.cache.current.abbreviation(for: date)
    }
    
    override func isDaylightSavingTime(for date: Date = Date()) -> Bool {
        TimeZoneCache.cache.current.isDaylightSavingTime(for: date)
    }
    
    override func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval {
        TimeZoneCache.cache.current.daylightSavingTimeOffset(for: date)
    }
    
    override func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        TimeZoneCache.cache.current.nextDaylightSavingTimeTransition(after: date)
    }
        
    override func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        TimeZoneCache.cache.current.localizedName(for: style, locale: locale)
    }
    
    override var isAutoupdating: Bool {
        true
    }
    
    override var debugDescription: String {
        "autoupdating \(identifier)"
    }
    
    override func hash(into hasher: inout Hasher) {
        hasher.combine(1)
    }    
}
