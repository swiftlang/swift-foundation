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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#elseif canImport(FoundationInternationalization)
@testable import FoundationInternationalization
#endif

final class TimeZoneTests : XCTestCase {

    func test_timeZoneBasics() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertTrue(!tz.identifier.isEmpty)
    }

    func test_equality() {
        let autoupdating = TimeZone.autoupdatingCurrent
        let autoupdating2 = TimeZone.autoupdatingCurrent

        XCTAssertEqual(autoupdating, autoupdating2)

        let current = TimeZone.current

        XCTAssertNotEqual(autoupdating, current)
    }

    func test_AnyHashableContainingTimeZone() {
        let values: [TimeZone] = [
            TimeZone(identifier: "America/Los_Angeles")!,
            TimeZone(identifier: "Europe/Kiev")!,
            TimeZone(identifier: "Europe/Kiev")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(TimeZone.self, type(of: anyHashables[0].base))
        expectEqual(TimeZone.self, type(of: anyHashables[1].base))
        expectEqual(TimeZone.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }

    func testPredefinedTimeZone() {
        XCTAssertEqual(TimeZone.gmt, TimeZone(identifier: "GMT"))
    }

    func testLocalizedName_103036605() {
        func test(_ tzIdentifier: String, _ localeIdentifier: String, _ style: TimeZone.NameStyle, _ expected: String?, file: StaticString = #file, line: UInt = #line) {
            let tz = TimeZone(identifier: tzIdentifier)
            guard let expected else {
                XCTAssertNil(tz, file: file, line: line)
                return
            }

            let locale = Locale(identifier: localeIdentifier)
            XCTAssertEqual(tz?.localizedName(for: .generic, locale: locale), expected, file: file, line: line)
        }

        test("America/Los_Angeles", "en_US", .generic, "Pacific Time")
        test("Europe/Berlin",       "en_US", .generic, "Central European Time")
        test("Antarctica/Vostok",   "en_US", .generic, "Vostok Time")
        test("Asia/Chongqing",      "en_US", .generic, "China Standard Time")
        test("America/Sao_Paulo",   "en_US", .generic, "Brasilia Standard Time")

        test("America/Los_Angeles", "zh_TW", .shortStandard, "太平洋時間")
        test("Europe/Berlin",       "zh_TW", .shortStandard, "中歐時間")
        test("Antarctica/Vostok",   "zh_TW", .shortStandard, "沃斯托克時間")
        test("Asia/Chongqing",      "zh_TW", .shortStandard, "中國標準時間")
        test("America/Sao_Paulo",   "zh_TW", .shortStandard, "巴西利亞標準時間")

        // abbreviation
        test("GMT",     "en_US", .standard, "Greenwich Mean Time")
        test("GMT+8",   "en_US", .standard, "GMT+08:00")
        test("PST",     "en_US", .standard, "Pacific Time")

        // invalid names
        test("XYZ", "en_US", .standard, nil)
        test("BOGUS/BOGUS", "en_US", .standard, nil)
    }

    func testTimeZoneName_103097012() {

        func _verify(_ tz: TimeZone?, _ expectedOffset: Int?, _ createdId: String?, file: StaticString = #file, line: UInt = #line) {
            if let expectedOffset {
                XCTAssertNotNil(tz, file: file, line: line)
                XCTAssertEqual(tz!.secondsFromGMT(for: Date(timeIntervalSince1970: 0)), expectedOffset, file: file, line: line)
                XCTAssertEqual(tz!.identifier, createdId, file: file, line: line)
            } else {
                XCTAssertNil(tz, file: file, line: line)
            }
        }

        func testIdentifier(_ tzID: String, _ expectedOffset: Int?, _ createdId: String?, file: StaticString = #file, line: UInt = #line) {
            _verify(TimeZone(identifier: tzID), expectedOffset, createdId, file: file, line: line)
        }

        func testAbbreviation(_ abb: String, _ expectedOffset: Int?, _ createdId: String?, file: StaticString = #file, line: UInt = #line) {
            _verify(TimeZone(abbreviation: abb), expectedOffset, createdId, file: file, line: line)

        }

        testIdentifier("America/Los_Angeles", -28800, "America/Los_Angeles")
        testIdentifier("GMT", 0, "GMT")
        testIdentifier("PST", -28800, "PST")
        testIdentifier("GMT+8", 28800, "GMT+0800")
        testIdentifier("GMT+8:00", 28800, "GMT+0800")
        testIdentifier("BOGUS", nil, nil)
        testIdentifier("XYZ", nil, nil)
        testIdentifier("UTC", 0, "GMT")

        testAbbreviation("America/Los_Angeles", nil, nil)
        testAbbreviation("XYZ", nil, nil)
        testAbbreviation("GMT", 0, "GMT")
        testAbbreviation("PST", -28800, "America/Los_Angeles")
        testAbbreviation("GMT+8", 28800, "GMT+0800")
        testAbbreviation("GMT+8:00", 28800, "GMT+0800")
        testAbbreviation("GMT+0800", 28800, "GMT+0800")
        testAbbreviation("UTC", 0, "GMT")
    }

    func testSecondsFromGMT_RemoteDates() {
        let date = Date(timeIntervalSinceReferenceDate: -5001243627) // "1842-07-09T05:39:33+0000"
        let europeRome = TimeZone(identifier: "Europe/Rome")!
        let secondsFromGMT = europeRome.secondsFromGMT(for: date)
        XCTAssertEqual(secondsFromGMT, 2996) //  Before 1893 the time zone is UTC+00:49:56
    }
}

final class TimeZoneGMTTests : XCTestCase {
    var tz: TimeZone {
        TimeZone(identifier: "GMT")!
    }
    
    func testIdentifier() {
        XCTAssertEqual(tz.identifier, "GMT")
    }

    func testSecondsFromGMT() {
        XCTAssertEqual(tz.secondsFromGMT(), 0)
    }

    func testSecondsFromGMTForDate() {
        XCTAssertEqual(tz.secondsFromGMT(for: Date.now), 0)
        XCTAssertEqual(tz.secondsFromGMT(for: Date.distantFuture), 0)
        XCTAssertEqual(tz.secondsFromGMT(for: Date.distantPast), 0)
    }
    
    func testAbbreviationForDate() {
        XCTAssertEqual(tz.abbreviation(for: Date.now), "GMT")
        XCTAssertEqual(tz.abbreviation(for: Date.distantFuture), "GMT")
        XCTAssertEqual(tz.abbreviation(for: Date.distantPast), "GMT")
    }
    
    func testDaylightSavingTimeOffsetForDate() {
        XCTAssertEqual(tz.daylightSavingTimeOffset(for: Date.now), 0)
        XCTAssertEqual(tz.daylightSavingTimeOffset(for: Date.distantFuture), 0)
        XCTAssertEqual(tz.daylightSavingTimeOffset(for: Date.distantPast), 0)
    }
    
    func testNextDaylightSavingTimeTransitionAfterDate() {
        XCTAssertNil(tz.nextDaylightSavingTimeTransition(after: Date.now))
        XCTAssertNil(tz.nextDaylightSavingTimeTransition(after: Date.distantFuture))
        XCTAssertNil(tz.nextDaylightSavingTimeTransition(after: Date.distantPast))
    }

    func testNextDaylightSavingTimeTransition() {
        XCTAssertNil(tz.nextDaylightSavingTimeTransition)
        XCTAssertNil(tz.nextDaylightSavingTimeTransition)
        XCTAssertNil(tz.nextDaylightSavingTimeTransition)
    }

    func testLocalizedName() {
        XCTAssertEqual(tz.localizedName(for: .standard, locale: Locale(identifier: "en_US")), "Greenwich Mean Time")
        XCTAssertEqual(tz.localizedName(for: .shortStandard, locale: Locale(identifier: "en_US")), "GMT")
        XCTAssertEqual(tz.localizedName(for: .daylightSaving, locale: Locale(identifier: "en_US")), "Greenwich Mean Time")
        XCTAssertEqual(tz.localizedName(for: .shortDaylightSaving, locale: Locale(identifier: "en_US")), "GMT")
        XCTAssertEqual(tz.localizedName(for: .generic, locale: Locale(identifier: "en_US")), "Greenwich Mean Time")
        XCTAssertEqual(tz.localizedName(for: .shortGeneric, locale: Locale(identifier: "en_US")), "GMT")
        
        // TODO: In non-framework, no FoundationInternationalization cases, return nil for all of tehse
    }
    
    func testEqual() {
        XCTAssertEqual(TimeZone(identifier: "UTC"), TimeZone(identifier: "UTC"))
    }
    
    func test_abbreviated() {
        // A sampling of expected values for abbreviated GMT names
        let expected : [(Int, String)] = [(-64800, "GMT-18"), (-64769, "GMT-17:59"), (-64709, "GMT-17:58"),  (-61769, "GMT-17:09"), (-61229, "GMT-17"), (-36029, "GMT-10"), (-35969, "GMT-9:59"), (-35909, "GMT-9:58"), (-32489, "GMT-9:01"), (-32429, "GMT-9"), (-3629, "GMT-1"), (-1829, "GMT-0:30"), (-89, "GMT-0:01"), (-29, "GMT"), (-1, "GMT"), (0, "GMT"), (29, "GMT"), (30, "GMT+0:01"), (90, "GMT+0:02"), (1770, "GMT+0:30"), (3570, "GMT+1"), (3630, "GMT+1:01"), (34170, "GMT+9:30"), (35910, "GMT+9:59"), (35970, "GMT+10"), (36030, "GMT+10:01"), (64650, "GMT+17:58"), (64710, "GMT+17:59"), (64770, "GMT+18")]

        for (offset, expect) in expected {
            let tz = TimeZone(secondsFromGMT: offset)!
            XCTAssertEqual(tz.abbreviation(), expect)
        }
    }
}

final class TimeZoneICUTests: XCTestCase {
    func testTimeZoneOffset() {
        let tz = _TimeZoneICU(identifier: "America/Los_Angeles")!
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        var gmt_calendar = Calendar(identifier: .gregorian)
        gmt_calendar.timeZone = .gmt
        func test(_ dateComponent: DateComponents, expectedRawOffset: Int, expectedDSTOffset: TimeInterval, file: StaticString = #file, line: UInt = #line) {
            let d = gmt_calendar.date(from: dateComponent)! // date in GMT
            let (rawOffset, dstOffset) = tz.rawAndDaylightSavingTimeOffset(for: d)
            XCTAssertEqual(rawOffset, expectedRawOffset, file: file, line: line)
            XCTAssertEqual(dstOffset, expectedDSTOffset, file: file, line: line)
        }

        // Not in DST
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 00, nanosecond: 1), expectedRawOffset: -28800, expectedDSTOffset: 0)
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 00, second: 01), expectedRawOffset: -28800, expectedDSTOffset: 0)
        test(.init(year: 2023, month: 3, day: 12, hour: 1, minute: 59, second: 59), expectedRawOffset: -28800, expectedDSTOffset: 0)
        
        // These times do not exist; we treat it as if in the previous time zone, i.e. not in DST
        test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)
        test(.init(year: 2023, month: 3, day: 12, hour: 2, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)

        // After DST starts
        test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        test(.init(year: 2023, month: 3, day: 12, hour: 3, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        test(.init(year: 2023, month: 3, day: 12, hour: 4, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)

        // These times happen twice; we treat it as if in the previous time zone, i.e. still in DST
        test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        test(.init(year: 2023, month: 11, day: 5, hour: 1, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 3600)
        
        // Clock should turn right back as this moment, so if we insist on being at this point, then we've moved past the transition point -- hence not DST
        test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 00, second: 00), expectedRawOffset: -28800, expectedDSTOffset: 0)

        // Not in DST
        test(.init(year: 2023, month: 11, day: 5, hour: 2, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)
        test(.init(year: 2023, month: 11, day: 5, hour: 3, minute: 34, second: 52), expectedRawOffset: -28800, expectedDSTOffset: 0)
    }

}
// MARK: - FoundationPreview disabled tests
#if FOUNDATION_FRAMEWORK
extension TimeZoneTests {
    func decodeHelper(_ l: TimeZone) -> TimeZone {
        let je = JSONEncoder()
        let data = try! je.encode(l)
        let jd = JSONDecoder()
        return try! jd.decode(TimeZone.self, from: data)
    }

    // Reenable once JSONEncoder/Decoder are moved
    func test_serializationOfCurrent() {
        let current = TimeZone.current
        let decodedCurrent = decodeHelper(current)
        XCTAssertEqual(decodedCurrent, current)

        let autoupdatingCurrent = TimeZone.autoupdatingCurrent
        let decodedAutoupdatingCurrent = decodeHelper(autoupdatingCurrent)
        XCTAssertEqual(decodedAutoupdatingCurrent, autoupdatingCurrent)

        XCTAssertNotEqual(decodedCurrent, decodedAutoupdatingCurrent)
        XCTAssertNotEqual(current, autoupdatingCurrent)
        XCTAssertNotEqual(decodedCurrent, autoupdatingCurrent)
        XCTAssertNotEqual(current, decodedAutoupdatingCurrent)
    }
}
#endif // FOUNDATION_FRAMEWORK

// MARK: - Bridging Tests
#if FOUNDATION_FRAMEWORK
final class TimeZoneBridgingTests : XCTestCase {
    func testCustomNSTimeZone() {
        // This test verifies that a custom ObjC subclass of NSTimeZone, bridged into Swift, still calls back into ObjC. `customTimeZone` returns an instances of "MyCustomTimeZone : NSTimeZone".
        let myTZ = customTimeZone()

        XCTAssertEqual(myTZ.identifier, "MyCustomTimeZone")
        XCTAssertEqual(myTZ.nextDaylightSavingTimeTransition(after: Date.now), Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(myTZ.secondsFromGMT(), 42)
        XCTAssertEqual(myTZ.abbreviation(), "hello")
        XCTAssertEqual(myTZ.isDaylightSavingTime(), true)
        XCTAssertEqual(myTZ.daylightSavingTimeOffset(), 12345)
    }

    func testCustomNSTimeZoneAsDefault() {
        // Set a custom subclass of NSTimeZone as the default time zone
        setCustomTimeZoneAsDefault()

        // Calendar uses the default time zone
        let defaultTZ = Calendar.current.timeZone
        XCTAssertEqual(defaultTZ.identifier, "MyCustomTimeZone")
        XCTAssertEqual(defaultTZ.nextDaylightSavingTimeTransition(after: Date.now), Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(defaultTZ.secondsFromGMT(), 42)
        XCTAssertEqual(defaultTZ.abbreviation(), "hello")
        XCTAssertEqual(defaultTZ.isDaylightSavingTime(), true)
        XCTAssertEqual(defaultTZ.daylightSavingTimeOffset(), 12345)
    }

    func test_AnyHashableCreatedFromNSTimeZone() {
        let values: [NSTimeZone] = [
            NSTimeZone(name: "America/Los_Angeles")!,
            NSTimeZone(name: "Europe/Kiev")!,
            NSTimeZone(name: "Europe/Kiev")!,
        ]
        let anyHashables = values.map(AnyHashable.init)
        expectEqual(TimeZone.self, type(of: anyHashables[0].base))
        expectEqual(TimeZone.self, type(of: anyHashables[1].base))
        expectEqual(TimeZone.self, type(of: anyHashables[2].base))
        XCTAssertNotEqual(anyHashables[0], anyHashables[1])
        XCTAssertEqual(anyHashables[1], anyHashables[2])
    }
}
#endif // FOUNDATION_FRAMEWORK
