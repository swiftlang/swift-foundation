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

/// A time zone which always reflects what the currently set time zone is. Aka `local` in Objective-C.
internal final class _TimeZoneAutoupdating : _TimeZoneProtocol, Sendable {
    init() {
    }
    
    init?(secondsFromGMT: Int) {
        fatalError("Unexpected init call")
    }
    
    init?(identifier: String) {
        fatalError("Unexpected init call")
    }
    
    var identifier: String {
        TimeZoneCache.cache.current.identifier
    }
    
    func secondsFromGMT(for date: Date = Date()) -> Int {
        TimeZoneCache.cache.current.secondsFromGMT(for: date)
    }
    
    func abbreviation(for date: Date = Date()) -> String? {
        TimeZoneCache.cache.current.abbreviation(for: date)
    }
    
    func isDaylightSavingTime(for date: Date = Date()) -> Bool {
        TimeZoneCache.cache.current.isDaylightSavingTime(for: date)
    }
    
    func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval {
        TimeZoneCache.cache.current.daylightSavingTimeOffset(for: date)
    }
    
    func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        TimeZoneCache.cache.current.nextDaylightSavingTimeTransition(after: date)
    }
        
    func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        TimeZoneCache.cache.current.localizedName(for: style, locale: locale)
    }
    
    func rawAndDaylightSavingTimeOffset(forGMTDate date: Date) -> (rawOffset: Int, daylightSavingOffset: Int) {
        TimeZoneCache.cache.current.rawAndDaylightSavingTimeOffset(forGMTDate: date)
    }

    var isAutoupdating: Bool {
        true
    }
    
    var debugDescription: String {
        "autoupdating \(identifier)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(1)
    }    
}
