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
        test("Antarctica/Davis",   "zh_TW", .shortStandard, "GMT+7", "GMT+7")
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
        try testAbbreviation("UTC+9", 32400, "GMT+0900")
        try testAbbreviation("UTC+9:00", 32400, "GMT+0900")
        try testAbbreviation("UTC+0900", 32400, "GMT+0900")
    }

    @Test func timeZoneGMTOffset() throws {
        func testName(_ name: String, _ expectedOffset: Int, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let tz = try #require(TimeZone(identifier: name))
            let secondsFromGMT = tz.secondsFromGMT()
            #expect(secondsFromGMT == expectedOffset)
            #expect(tz.isDaylightSavingTime() == false)
            #expect(tz.nextDaylightSavingTimeTransition == nil)
        }

        try testName("GMT+8", 8*3600)
        try testName("GMT+08", 8*3600)
        try testName("GMT+0800", 8*3600)
        try testName("GMT+08:00", 8*3600)
        try testName("GMT+8:00", 8*3600)
        try testName("UTC+9", 9*3600)
        try testName("UTC+09", 9*3600)
        try testName("UTC+0900", 9*3600)
        try testName("UTC+09:00", 9*3600)
        try testName("UTC+9:00", 9*3600)
    }

    @Test(arguments: ["en_001", "en_US", "ja_JP"])
    func timeZoneGMTOffset_localizedNames(localeIdentifier: String) throws {
        let locale = Locale(identifier: localeIdentifier)
        func testNames(
        _ names: [String],
        _ expectedStandardName: String,
        _ expectedShortStandardName: String,
        _ expectedDaylightSavingName: String,
        _ expectedShortDaylightSavingName: String,
        _ expectedGenericName: String,
        _ expectedShortGenericName: String,
        sourceLocation: SourceLocation = #_sourceLocation) throws {
            for name in names {
                let tz = try #require(TimeZone(identifier: name))
                let standardName = tz.localizedName(for: .standard, locale: locale)
                let shortStandardName = tz.localizedName(for: .shortStandard, locale: locale)
                let daylightSavingName = tz.localizedName(for: .daylightSaving, locale: locale)
                let shortDaylightSavingName = tz.localizedName(for: .shortDaylightSaving, locale: locale)
                let generic = tz.localizedName(for: .generic, locale: locale)
                let shortGeneric = tz.localizedName(for: .shortGeneric, locale: locale)

                #expect(expectedStandardName == standardName)
                #expect(expectedShortStandardName == shortStandardName)
                #expect(expectedDaylightSavingName == daylightSavingName)
                #expect(expectedShortDaylightSavingName == shortDaylightSavingName)
                #expect(expectedGenericName == generic)
                #expect(expectedShortGenericName == shortGeneric)
            }
        }

        try testNames(["GMT+8", "GMT+08", "GMT+0800", "GMT+08:00", "GMT+8:00"],
                      "GMT+08:00", "GMT+8", "GMT+08:00", "GMT+8", "GMT+08:00", "GMT+8")
        try testNames(["UTC+9", "UTC+09", "UTC+0900", "UTC+09:00", "UTC+9:00"],
                     "GMT+09:00", "GMT+9", "GMT+09:00", "GMT+9", "GMT+09:00", "GMT+9")
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
            
            do {
                // TimeZone does not decode the current as a sentinel value
                TimeZoneCache.cache.resetCurrent(to: .gmt)
                
                let encodedCurrent = try JSONEncoder().encode(TimeZone.current)
                let encodedAutoupdatingCurrent = try JSONEncoder().encode(TimeZone.autoupdatingCurrent)
                
                TimeZoneCache.cache.resetCurrent(to: TimeZone(identifier: "America/Los_Angeles")!)
                
                let decodedCurrent = try JSONDecoder().decode(TimeZone.self, from: encodedCurrent)
                let decodedAutoupdatingCurrent = try JSONDecoder().decode(TimeZone.self, from: encodedAutoupdatingCurrent)
                
                #expect(decodedCurrent.identifier == "GMT")
                #expect(decodedAutoupdatingCurrent.identifier == "America/Los_Angeles")
            }
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

    @Test func names_rawAndDaylightSavingTimeOffset() throws {
        var gmt_calendar = Calendar(identifier: .gregorian)
        gmt_calendar.timeZone = .gmt

        func test(_ identifier: String, _ dateComponent: DateComponents, expectedRawOffset: Int, expectedDSTOffset: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let tz = try #require(_TimeZoneICU(identifier: identifier))
            let d = try #require(gmt_calendar.date(from: dateComponent)) // date in GMT
            let (rawOffset, dstOffset) = tz.rawAndDaylightSavingTimeOffset(for: d)
            #expect(rawOffset == expectedRawOffset, sourceLocation: sourceLocation)
            #expect(dstOffset == expectedDSTOffset, sourceLocation: sourceLocation)
        }

        // PST
        // Not in DST
        try test("PST", .init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        // These times do not exist; we treat it as if in the previous time zone, i.e. not in DST
        try test("PST", .init(year: 2023, month: 3, day: 12, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        // After DST starts
        try test("PST", .init(year: 2023, month: 3, day: 12, hour: 3, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        // These times happen twice; we treat it as if in the previous time zone, i.e. still in DST
        try test("PST", .init(year: 2023, month: 11, day: 5, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        // Clock should turn right back as this moment, so if we insist on being at this point, then we've moved past the transition point -- hence not DST
        try test("PST", .init(year: 2023, month: 11, day: 5, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        // Not in DST
        try test("PST", .init(year: 2023, month: 11, day: 5, hour: 2, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)

        // JST: not in DST
        let dc = DateComponents(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00)
        try test("JST", dc, expectedRawOffset: 32400, expectedDSTOffset: 0)
        try test("UTC+9", dc, expectedRawOffset: 32400, expectedDSTOffset: 0)
        try test("UTC+0900", dc, expectedRawOffset: 32400, expectedDSTOffset: 0)
        try test("UTC+9:00", dc, expectedRawOffset: 32400, expectedDSTOffset: 0)
        try test("GMT+9", dc, expectedRawOffset: 32400, expectedDSTOffset: 0)
    }
}

@Suite("TimeZone_ICUResource")
private struct TimeZone_ICUResourceTests {

    let finalTimeZoneDates = {
        let fallTime = Date(timeIntervalSince1970: 1762041600) // 2025-11-02, end of DST
        var dates: [Date] = []
        let springTime = Date(timeIntervalSince1970: 1741392000) // 2025-03-08, DST start is 2025-03-09
        for i in 0...10000 {
            dates.append(Date(timeInterval: Double(i * 3600), since: fallTime))
            dates.append(Date(timeInterval: Double(i * -3600), since: fallTime))
        }
        for i in 0...10000 {
            dates.append(Date(timeInterval: Double(i * 3600), since: springTime))
            dates.append(Date(timeInterval: Double(i * -3600), since: springTime))
        }
        return dates
    }()

    @Test func singleDSTRuleTimeZone() throws {
        let t = try _TimeZoneSingleDSTRule(offsetSeconds: -28800, dstSavingsSeconds: 3600, startMonth: 2, startDay: 8, startDayOfWeek: -1, startTime: 7200, startTimeMode: .wallTime, endMonth: 10, endDay: 1, endDayOfWeek: -1, endTime: 7200, endTimeMode: .wallTime, startYear: 2008)
        let truth = try #require(_TimeZoneICU(identifier: "America/Los_Angeles"))
        let options: [(TimeZone.DaylightSavingTimePolicy, TimeZone.DaylightSavingTimePolicy)] = [
            (.former, .former),
            (.former, .latter),
            (.latter, .former),
            (.latter, .latter)
        ]

        for d in finalTimeZoneDates {
            for option in options {
                let offsets = t.rawAndDaylightSavingTimeOffset(for: d, local: true, duplicatedTimePolicy: option.0, nonExistingTimePolicy: option.1)
                let offsets_expected = truth.rawAndDaylightSavingTimeOffset(for: d, repeatedTimePolicy: option.0, skippedTimePolicy: option.1)

                #expect(offsets.0 == offsets_expected.0, "Date = Date(timeIntervalSince1970: \(d.timeIntervalSince1970)), option = \(option)")
                #expect(TimeInterval(offsets.1) == offsets_expected.1, "Date = Date(timeIntervalSince1970: \(d.timeIntervalSince1970)), option = \(option)")
            }
        }

        for d in finalTimeZoneDates {
            let nextTransition = t.dstTransition(after: d)
            let expected = truth.nextDaylightSavingTimeTransition(after: d)
            #expect(nextTransition == expected, "Date = Date(timeIntervalSince1970: \(d.timeIntervalSince1970)")
        }
    }


    @Test(.disabled("This test takes a long time to run because it tests all known timezones. Also this test is only useful when ICUResourceTimeZone feature flag is disabled"))
    func allKnownTimeZones() throws {
        func buildTestDates(_ seeds: [Date]) -> [Date] {

            var dates: [Date] = []
            for seed in seeds {
                for i in 0...10000 {
                    dates.append(Date(timeInterval: Double(i * 3600), since: seed))
                    dates.append(Date(timeInterval: Double(i * -3600), since: seed))
                }
            }
            return dates

        }

        let testDates = buildTestDates( [
            Date(timeIntervalSince1970: 1647165728.7119999) /*year 2022*/,
            Date(timeIntervalSince1970: 0),
            Date.now,
            Date(timeIntervalSince1970: -3389673178),
            Date(timeIntervalSince1970: 1196467622)
        ] )

        for name in TimeZone.knownTimeZoneIdentifiers {
            let t = try _TimeZoneICUResource(identifier: name)
            guard let truth = _TimeZoneICU(identifier: name) else {
                preconditionFailure("Unexpected nil TimeZoneICU")
            }

            for d in testDates {
                let offset = t.secondsFromGMT(for: d)
                let expect = truth.secondsFromGMT(for: d)
                #expect(offset == expect)

                let (rawOffset, dstOffset) = t.rawAndDSTOffset(for: d)
                let offsets_expected = truth.rawAndDaylightSavingTimeOffset(for: d)
                #expect(rawOffset == offsets_expected.0)
                #expect(TimeInterval(dstOffset) == offsets_expected.1)

                let nextDST = t.nextTransition(after: d, inclusive: false)
                let nextDST_expected = truth.nextDaylightSavingTimeTransition(after: d)
                #expect(nextDST == nextDST_expected)

                let expectedIsDST = truth.isDaylightSavingTime(for: d)
                let isDST = t.isDaylightSavingTime(for: d)
                #expect(isDST == expectedIsDST)
            }
        }
    }

    @Test func offsets() throws {
        func test(_ identifier: String, date: Date, expectedOffsetFromGMT: Int, expectedRawOffset: Int, expectedDSTOffset: Double, expectedIsDST: Bool, sourceLocation: SourceLocation = #_sourceLocation) throws {

            let tz = try _TimeZoneICUResource(identifier: identifier)

            let offset = tz.secondsFromGMT(for: date)
            let isDST = tz.isDaylightSavingTime(for: date)
            let (rawOffset, dstOffset) = tz.rawAndDaylightSavingTimeOffset(for: date)

            #expect(offset == expectedOffsetFromGMT)
            #expect(rawOffset == expectedRawOffset)
            #expect(dstOffset == expectedDSTOffset)
            #expect(isDST == expectedIsDST)
        }

        // 1916-04-30T23:00:00Z, Germany first DST
        try test("Europe/Berlin", date: Date(timeIntervalSince1970: -1693702800), expectedOffsetFromGMT: 7200, expectedRawOffset: 3600, expectedDSTOffset: 0, expectedIsDST: true)

        // 1918-03-31T12:00:00Z, America's first nationwide DST
        try test("America/New_York", date: Date(timeIntervalSince1970: -1633262400.0), expectedOffsetFromGMT: -14400, expectedRawOffset: -18000, expectedDSTOffset: 3600, expectedIsDST: true)

        // 1942-12-30T12:00:00Z, Year-round DST
        try test("America/New_York", date: Date(timeIntervalSince1970: -852206400), expectedOffsetFromGMT: -14400, expectedRawOffset: -18000, expectedDSTOffset: 3600, expectedIsDST: true)

        // 2021-10-31T12:00:00Z, 30-minute DST offset
        try test("Australia/Lord_Howe", date: Date(timeIntervalSince1970: 1635681600.0), expectedOffsetFromGMT: 39600, expectedRawOffset: 37800, expectedDSTOffset: 1800, expectedIsDST: true)

        // 2007-03-12T12:00:00Z, Extended DST period
        try test("America/Chicago", date: Date(timeIntervalSince1970: 1173700800), expectedOffsetFromGMT: -18000, expectedRawOffset: -21600, expectedDSTOffset: 3600, expectedIsDST: true)
        // 2006-10-30T12:00:00Z, Old DST rules
        try test("America/Chicago", date: Date(timeIntervalSince1970: 1162209600), expectedOffsetFromGMT: -21600, expectedRawOffset: -21600, expectedDSTOffset: 0, expectedIsDST: false)

        // 2010-10-30T12:00:00Z, Russia's DST
        try test("Europe/Moscow", date: Date(timeIntervalSince1970: 1288440000), expectedOffsetFromGMT: 14400, expectedRawOffset: 10800, expectedDSTOffset: 3600, expectedIsDST: true)
        // 2011-10-30T12:00:00Z, Russia abandoning DST
        try test("Europe/Moscow", date: Date(timeIntervalSince1970: 1319976000.0), expectedOffsetFromGMT: 14400, expectedRawOffset: 14400, expectedDSTOffset: 0, expectedIsDST: false)

        // 2016-09-06T23:59:59Z, Turkey's abolition of DST
        try test("Europe/Istanbul", date: Date(timeIntervalSince1970: 1473206399), expectedOffsetFromGMT: 10800, expectedRawOffset: 7200, expectedDSTOffset: 3600, expectedIsDST: false)
        // 2016-09-07T00:00:00Z, Turkey's abolition of DST
        try test("Europe/Istanbul", date: Date(timeIntervalSince1970: 1473206400), expectedOffsetFromGMT: 10800, expectedRawOffset: 10800, expectedDSTOffset: 0, expectedIsDST: false)
        // 2016-09-07T01:00:00Z
        try test("Europe/Istanbul", date: Date(timeIntervalSince1970: 1473210000), expectedOffsetFromGMT: 10800, expectedRawOffset: 10800, expectedDSTOffset: 0, expectedIsDST: false)

        // 2005-04-05T12:00:00Z, Indiana before statewide adoption
        try test("America/Indiana/Indianapolis", date: Date(timeIntervalSince1970: 1112702400.0), expectedOffsetFromGMT: -18000, expectedRawOffset: -18000, expectedDSTOffset: 0, expectedIsDST: false)
        // 2006-05-05T12:00:00Z, Indiana after adopting DST statewide
        try test("America/Indiana/Indianapolis", date: Date(timeIntervalSince1970: 1146830400.0), expectedOffsetFromGMT: -14400, expectedRawOffset: -18000, expectedDSTOffset: 3600, expectedIsDST: true)

        // 1995-01-02T12:00:00Z, Tests Kiritimati after moving to UTC+14
        try test("Pacific/Kiritimati", date: Date(timeIntervalSince1970: 789048000.0), expectedOffsetFromGMT: 50400, expectedRawOffset: 50400, expectedDSTOffset: 0, expectedIsDST: false)

        // 2011-12-29T12:00:00Z, Tests Samoa before skipping December 30th
        try test("Pacific/Apia", date: Date(timeIntervalSince1970: 1325160000.0), expectedOffsetFromGMT: -36000, expectedRawOffset: -39600, expectedDSTOffset: 3600, expectedIsDST: true)
        // 2011-12-30T12:00:00Z, Tests Samoa on skipping day
        try test("Pacific/Apia", date: Date(timeIntervalSince1970: 1325246400), expectedOffsetFromGMT: 50400, expectedRawOffset: -39600, expectedDSTOffset: 3600, expectedIsDST: true)
        // 2011-12-31T12:00:00Z, Tests Samoa after skipping a day - December 30, 2011 never existed in Samoa
        try test("Pacific/Apia", date: Date(timeIntervalSince1970: 1325332800.0), expectedOffsetFromGMT: 50400, expectedRawOffset: 46800, expectedDSTOffset: 3600, expectedIsDST: true)

        // 2010-02-28T12:00:00Z, Tests leap year February
        try test("America/New_York", date: Date(timeIntervalSince1970: 1267358400.0), expectedOffsetFromGMT: -18000, expectedRawOffset: -18000, expectedDSTOffset: 0, expectedIsDST: false)
        // 2000-02-29T12:00:00Z, Tests leap day in century year (divisible by 400)
        try test("Europe/Paris", date: Date(timeIntervalSince1970: 951825600.0), expectedOffsetFromGMT: 3600, expectedRawOffset: 3600, expectedDSTOffset: 0, expectedIsDST: false)

        // 2018-07-01, Morocco Ramadan
        try test("Africa/Casablanca", date: Date(timeIntervalSince1970: 1530485234), expectedOffsetFromGMT: 3600, expectedRawOffset: 0, expectedDSTOffset: 3600, expectedIsDST: true)
        // 2018-11-01, After Ramadan ended
        try test("Africa/Casablanca", date: Date(timeIntervalSince1970: 1541112434), expectedOffsetFromGMT: 3600, expectedRawOffset: 0, expectedDSTOffset: 3600, expectedIsDST: true)

        // 2014-05-30T12:00:00Z, Chile's regular year
        try test("America/Santiago", date: Date(timeIntervalSince1970: 1401451200), expectedOffsetFromGMT: -14400, expectedRawOffset: -14400, expectedDSTOffset: 0, expectedIsDST: false)
        // 2015-05-30T12:00:00Z, Tests Chile's all year DST ??
        try test("America/Santiago", date: Date(timeIntervalSince1970: 1432987200), expectedOffsetFromGMT: -10800, expectedRawOffset: -14400, expectedDSTOffset: 3600, expectedIsDST: true)

        // 1880-01-01T12:00:00Z, Tests historical Local Mean Time before standardized timezones (9min 21sec ahead of GMT)
        try test("Europe/Paris", date: Date(timeIntervalSince1970: -2840097600.0), expectedOffsetFromGMT: 561, expectedRawOffset: 561, expectedDSTOffset: 0, expectedIsDST: false)
        // 1883-11-18T12:00:00Z, Tests NYC Local Mean Time before railroad standard time adoption
        try test("America/New_York", date: Date(timeIntervalSince1970: -2717668800.0), expectedOffsetFromGMT: -17762, expectedRawOffset: -17762, expectedDSTOffset: 0, expectedIsDST: false)
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
