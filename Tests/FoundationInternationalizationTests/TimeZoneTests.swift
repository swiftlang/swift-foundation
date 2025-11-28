//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationInternationalization)
@testable import FoundationInternationalization
@testable import FoundationEssentials
#endif

@Suite("TimeZone")
private struct TimeZoneTests {
    @Test func basics() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!

        #expect(!tz.identifier.isEmpty)
    }

    @Test func equality() async {
        await usingCurrentInternationalizationPreferences {
            let autoupdating = TimeZone.autoupdatingCurrent
            let autoupdating2 = TimeZone.autoupdatingCurrent
            
            #expect(autoupdating == autoupdating2)
            
            let current = TimeZone.current
            
            #expect(autoupdating != current)
        }
    }

    @Test func anyHashableContainingTimeZone() {
        let values: [TimeZone] = [
            TimeZone(identifier: "America/Los_Angeles")!,
            TimeZone(identifier: "Europe/Kiev")!,
            TimeZone(identifier: "Europe/Kiev")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(TimeZone.self == type(of: anyHashables[0].base))
        #expect(TimeZone.self == type(of: anyHashables[1].base))
        #expect(TimeZone.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }

    @Test func predefinedTimeZone() {
        #expect(TimeZone.gmt == TimeZone(identifier: "GMT"))
    }

    @Test func localizedName_103036605() {
        func test(_ tzIdentifier: String, _ localeIdentifier: String, _ style: TimeZone.NameStyle, _ expected: String?, _ expectedDST: String?, sourceLocation: SourceLocation = #_sourceLocation) {
            let tz = TimeZone(identifier: tzIdentifier)
            guard let expected else {
                #expect(tz == nil, sourceLocation: sourceLocation)
                return
            }

            let locale = Locale(identifier: localeIdentifier)
            if let tz, tz.isDaylightSavingTime(for: .now) {
                #expect(tz.localizedName(for: style, locale: locale) == expectedDST, sourceLocation: sourceLocation)
            } else {
                #expect(tz?.localizedName(for: style, locale: locale) == expected, sourceLocation: sourceLocation)
            }
        }

        test("America/Los_Angeles", "en_US", .generic, "Pacific Time", "Pacific Time")
        test("Europe/Paris",       "en_US", .generic, "Central European Time", "Central European Time")
        test("Antarctica/Vostok",   "en_US", .generic, "Vostok Time", "Vostok Time")
        test("Asia/Chongqing",      "en_US", .generic, "China Standard Time", "China Standard Time")
        test("America/Sao_Paulo",   "en_US", .generic, "Brasilia Standard Time", "Brasilia Standard Time")

        test("America/Los_Angeles", "zh_TW", .shortStandard, "PST", "PST")
        test("Europe/Paris",       "zh_TW", .shortStandard, "GMT+1", "GMT+2")
        test("Antarctica/Vostok",   "zh_TW", .shortStandard, "GMT+6", "GMT+6")
        test("Asia/Chongqing",      "zh_TW", .shortStandard, "GMT+8", "GMT+8")
        test("America/Sao_Paulo",   "zh_TW", .shortStandard, "GMT-3", "GMT-3")

        // abbreviation
        test("GMT",     "en_US", .standard, "Greenwich Mean Time", "Greenwich Mean Time")
        test("GMT+8",   "en_US", .standard, "GMT+08:00", "GMT+08:00")
        test("PST",     "en_US", .standard, "Pacific Standard Time", "Pacific Standard Time")

        // invalid names
        test("XYZ", "en_US", .standard, nil, nil)
        test("BOGUS/BOGUS", "en_US", .standard, nil, nil)
    }

    @Test func timeZoneName_103097012() throws {

        func _verify(_ tz: TimeZone?, _ expectedOffset: Int?, _ createdId: String?, sourceLocation: SourceLocation = #_sourceLocation) throws {
            if let expectedOffset {
                #expect(tz?.secondsFromGMT(for: Date(timeIntervalSince1970: 0)) == expectedOffset, sourceLocation: sourceLocation)
                #expect(tz?.identifier == createdId, sourceLocation: sourceLocation)
            } else {
                #expect(tz == nil, sourceLocation: sourceLocation)
            }
        }

        func testIdentifier(_ tzID: String, _ expectedOffset: Int?, _ createdId: String?, sourceLocation: SourceLocation = #_sourceLocation) throws {
            try _verify(TimeZone(identifier: tzID), expectedOffset, createdId, sourceLocation: sourceLocation)
        }

        func testAbbreviation(_ abb: String, _ expectedOffset: Int?, _ createdId: String?, sourceLocation: SourceLocation = #_sourceLocation) throws {
            try _verify(TimeZone(abbreviation: abb), expectedOffset, createdId, sourceLocation: sourceLocation)

        }

        try testIdentifier("America/Los_Angeles", -28800, "America/Los_Angeles")
        try testIdentifier("GMT", 0, "GMT")
        try testIdentifier("PST", -28800, "PST")
        try testIdentifier("GMT+8", 28800, "GMT+0800")
        try testIdentifier("GMT+8:00", 28800, "GMT+0800")
        try testIdentifier("BOGUS", nil, nil)
        try testIdentifier("XYZ", nil, nil)
        try testIdentifier("UTC", 0, "GMT")

        try testAbbreviation("America/Los_Angeles", nil, nil)
        try testAbbreviation("XYZ", nil, nil)
        try testAbbreviation("GMT", 0, "GMT")
        try testAbbreviation("PST", -28800, "America/Los_Angeles")
        try testAbbreviation("GMT+8", 28800, "GMT+0800")
        try testAbbreviation("GMT+8:00", 28800, "GMT+0800")
        try testAbbreviation("GMT+0800", 28800, "GMT+0800")
        try testAbbreviation("UTC", 0, "GMT")
    }

    @Test func secondsFromGMT_RemoteDates() {
        let date = Date(timeIntervalSinceReferenceDate: -5001243627) // "1842-07-09T05:39:33+0000"
        let europeRome = TimeZone(identifier: "Europe/Rome")!
        let secondsFromGMT = europeRome.secondsFromGMT(for: date)
        #expect(secondsFromGMT == 2996) //  Before 1893 the time zone is UTC+00:49:56
    }
    
    func decodeHelper(_ l: TimeZone) throws -> TimeZone {
        let je = JSONEncoder()
        let data = try je.encode(l)
        let jd = JSONDecoder()
        return try jd.decode(TimeZone.self, from: data)
    }
    
    @Test func serializationOfCurrent() async throws {
        try await usingCurrentInternationalizationPreferences {
            let current = TimeZone.current
            let decodedCurrent = try decodeHelper(current)
            #expect(decodedCurrent == current)
            
            let autoupdatingCurrent = TimeZone.autoupdatingCurrent
            let decodedAutoupdatingCurrent = try decodeHelper(autoupdatingCurrent)
            #expect(decodedAutoupdatingCurrent == autoupdatingCurrent)
            
            #expect(decodedCurrent != decodedAutoupdatingCurrent)
            #expect(current != autoupdatingCurrent)
            #expect(decodedCurrent != autoupdatingCurrent)
            #expect(current != decodedAutoupdatingCurrent)
        }
    }
}

@Suite("TimeZone GMT")
private struct TimeZoneGMTTests {
    var tz: TimeZone {
        TimeZone(identifier: "GMT")!
    }
    
    @Test func identifier() {
        #expect(tz.identifier == "GMT")
    }

    @Test func secondsFromGMT() {
        #expect(tz.secondsFromGMT() == 0)
    }

    @Test func secondsFromGMTForDate() {
        #expect(tz.secondsFromGMT(for: Date.now) == 0)
        #expect(tz.secondsFromGMT(for: Date.distantFuture) == 0)
        #expect(tz.secondsFromGMT(for: Date.distantPast) == 0)
    }
    
    @Test func abbreviationForDate() {
        #expect(tz.abbreviation(for: Date.now) == "GMT")
        #expect(tz.abbreviation(for: Date.distantFuture) == "GMT")
        #expect(tz.abbreviation(for: Date.distantPast) == "GMT")
    }
    
    @Test func daylightSavingTimeOffsetForDate() {
        #expect(tz.daylightSavingTimeOffset(for: Date.now) == 0)
        #expect(tz.daylightSavingTimeOffset(for: Date.distantFuture) == 0)
        #expect(tz.daylightSavingTimeOffset(for: Date.distantPast) == 0)
    }
    
    @Test func nextDaylightSavingTimeTransitionAfterDate() {
        #expect(tz.nextDaylightSavingTimeTransition(after: Date.now) == nil)
        #expect(tz.nextDaylightSavingTimeTransition(after: Date.distantFuture) == nil)
        #expect(tz.nextDaylightSavingTimeTransition(after: Date.distantPast) == nil)
    }

    @Test func nextDaylightSavingTimeTransition() {
        #expect(tz.nextDaylightSavingTimeTransition == nil)
        #expect(tz.nextDaylightSavingTimeTransition == nil)
        #expect(tz.nextDaylightSavingTimeTransition == nil)
    }

    @Test func localizedName() {
        #expect(tz.localizedName(for: .standard, locale: Locale(identifier: "en_US")) == "Greenwich Mean Time")
        #expect(tz.localizedName(for: .shortStandard, locale: Locale(identifier: "en_US")) == "GMT")
        #expect(tz.localizedName(for: .daylightSaving, locale: Locale(identifier: "en_US")) == "Greenwich Mean Time")
        #expect(tz.localizedName(for: .shortDaylightSaving, locale: Locale(identifier: "en_US")) == "GMT")
        #expect(tz.localizedName(for: .generic, locale: Locale(identifier: "en_US")) == "Greenwich Mean Time")
        #expect(tz.localizedName(for: .shortGeneric, locale: Locale(identifier: "en_US")) == "GMT")
        
        // TODO: In non-framework, no FoundationInternationalization cases, return nil for all of tehse
    }
    
    @Test func equal() {
        #expect(TimeZone(identifier: "UTC") == TimeZone(identifier: "UTC"))
    }
    
    @Test func abbreviated() throws {
        // A sampling of expected values for abbreviated GMT names
        let expected : [(Int, String)] = [(-64800, "GMT-18"), (-64769, "GMT-17:59"), (-64709, "GMT-17:58"),  (-61769, "GMT-17:09"), (-61229, "GMT-17"), (-36029, "GMT-10"), (-35969, "GMT-9:59"), (-35909, "GMT-9:58"), (-32489, "GMT-9:01"), (-32429, "GMT-9"), (-3629, "GMT-1"), (-1829, "GMT-0:30"), (-89, "GMT-0:01"), (-29, "GMT"), (-1, "GMT"), (0, "GMT"), (29, "GMT"), (30, "GMT+0:01"), (90, "GMT+0:02"), (1770, "GMT+0:30"), (3570, "GMT+1"), (3630, "GMT+1:01"), (34170, "GMT+9:30"), (35910, "GMT+9:59"), (35970, "GMT+10"), (36030, "GMT+10:01"), (64650, "GMT+17:58"), (64710, "GMT+17:59"), (64770, "GMT+18")]

        for (offset, expect) in expected {
            let tz = try #require(TimeZone(secondsFromGMT: offset))
            #expect(tz.abbreviation() == expect)
        }
    }
}

@Suite("TimeZone ICU")
private struct TimeZoneICUTests {
    @Test func timeZoneOffset() throws {
        let tz = _TimeZoneICU(identifier: "America/Los_Angeles")!
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        var gmt_calendar = Calendar(identifier: .gregorian)
        gmt_calendar.timeZone = .gmt
        func test(_ dateComponent: DateComponents, expectedRawOffset: Int, expectedDSTOffset: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let d = try #require(gmt_calendar.date(from: dateComponent)) // date in GMT
            let (rawOffset, dstOffset) = tz.rawAndDaylightSavingTimeOffset(for: d)
            #expect(rawOffset == expectedRawOffset, sourceLocation: sourceLocation)
            #expect(dstOffset == expectedDSTOffset, sourceLocation: sourceLocation)
        }

        // Not in DST
        try test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        try test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00, nanosecond: 1), expectedRawOffset: -28800, expectedDSTOffset: 0)
        try test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 01), expectedRawOffset: -28800, expectedDSTOffset: 0)
        try test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 59, second: 59), expectedRawOffset: -28800, expectedDSTOffset: 0)
        
        // These times do not exist; we treat it as if in the previous time zone, i.e. not in DST
        try test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        try test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)

        // After DST starts
        try test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        try test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        try test(.init(year: 2023, month: 3, day: 12, hour: 4, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)

        // These times happen twice; we treat it as if in the previous time zone, i.e. still in DST
        try test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        try test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        
        // Clock should turn right back as this moment, so if we insist on being at this point, then we've moved past the transition point -- hence not DST
        try test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)

        // Not in DST
        try test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)
        try test(.init(year: 2023, month: 11, day: 5, hour: 3, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)
    }

}
// MARK: - FoundationPreview disabled tests

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK
@Suite("TimeZone Bridging")
private struct TimeZoneBridgingTests {
    @Test func customNSTimeZone() {
        // This test verifies that a custom ObjC subclass of NSTimeZone, bridged into Swift, still calls back into ObjC. `customTimeZone` returns an instances of "MyCustomTimeZone : NSTimeZone".
        let myTZ = customTimeZone()

        #expect(myTZ.identifier == "MyCustomTimeZone")
        #expect(myTZ.nextDaylightSavingTimeTransition(after: Date.now) == Date(timeIntervalSince1970: 1000000))
        #expect(myTZ.secondsFromGMT() == 42)
        #expect(myTZ.abbreviation() == "hello")
        #expect(myTZ.isDaylightSavingTime() == true)
        #expect(myTZ.daylightSavingTimeOffset() == 12345)
    }

    @Test func anyHashableCreatedFromNSTimeZone() {
        let values: [NSTimeZone] = [
            NSTimeZone(name: "America/Los_Angeles")!,
            NSTimeZone(name: "Europe/Kiev")!,
            NSTimeZone(name: "Europe/Kiev")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        #expect(TimeZone.self == type(of: anyHashables[0].base))
        #expect(TimeZone.self == type(of: anyHashables[1].base))
        #expect(TimeZone.self == type(of: anyHashables[2].base))
        #expect(anyHashables[0] != anyHashables[1])
        #expect(anyHashables[1] == anyHashables[2])
    }
    
    @Test func customNSTimeZoneAsDefault() async {
        await usingCurrentInternationalizationPreferences {
            // Set a custom subclass of NSTimeZone as the default time zone
            setCustomTimeZoneAsDefault()
            
            // Calendar uses the default time zone
            let defaultTZ = Calendar.current.timeZone
            #expect(defaultTZ.identifier == "MyCustomTimeZone")
            #expect(defaultTZ.nextDaylightSavingTimeTransition(after: Date.now) == Date(timeIntervalSince1970: 1000000))
            #expect(defaultTZ.secondsFromGMT() == 42)
            #expect(defaultTZ.abbreviation() == "hello")
            #expect(defaultTZ.isDaylightSavingTime() == true)
            #expect(defaultTZ.daylightSavingTimeOffset() == 12345)
        }
    }
}
#endif // FOUNDATION_FRAMEWORK
