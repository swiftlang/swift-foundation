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
