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

/// Abstract base class for time zones.
internal class _TimeZoneBase : @unchecked Sendable, CustomDebugStringConvertible {
    var identifier: String { fatalError("Abstract implementation must be overridden") }
    func secondsFromGMT(for date: Date = Date()) -> Int { fatalError("Abstract implementation must be overridden") }
    func abbreviation(for date: Date = Date()) -> String? { fatalError("Abstract implementation must be overridden") }
    func isDaylightSavingTime(for date: Date = Date()) -> Bool { fatalError("Abstract implementation must be overridden") }
    func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval { fatalError("Abstract implementation must be overridden") }
    func nextDaylightSavingTimeTransition(after date: Date) -> Date? { fatalError("Abstract implementation must be overridden") }
    func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? { fatalError("Abstract implementation must be overridden") }
    
    // Used by legacy ObjC clients only
    var data: Data? {
        nil
    }
    
    var isAutoupdating: Bool {
        false
    }
    
    var debugDescription: String {
        identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
#if FOUNDATION_FRAMEWORK
    func bridgeToNSTimeZone() -> NSTimeZone {
        _NSSwiftTimeZone(timeZone: TimeZone(inner: self))
    }
#endif
}
