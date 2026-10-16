//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

/// Filling in date patterns, checked through `Date.VerbatimFormatStyle`.
@Suite("Date pattern formatting")
private struct DatePatternFormattingTests {
    typealias Field = AttributeScopes.FoundationAttributes.DateFieldAttribute.Field

    // 2026-09-18 14:05:09.306 UTC, a Friday.
    let date = Date(timeIntervalSince1970: 1_789_740_309.306)

    func style(_ pattern: String, locale: String = "en_US", timeZone: String = "UTC", firstWeekday: Int = 1, minimumDaysInFirstWeek: Int = 1) -> Date.VerbatimFormatStyle {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        return Date.VerbatimFormatStyle(format: Date.FormatString(rawFormat: pattern), locale: Locale(identifier: locale), timeZone: TimeZone(identifier: timeZone)!, calendar: calendar)
    }

    // MARK: - Numeric fields

    @Test(arguments: [
        ("y", "2026"), ("yy", "26"), ("yyy", "2026"), ("yyyy", "2026"), ("yyyyy", "02026"),
        ("u", "2026"), ("uuuuu", "02026"),
        ("M", "9"), ("MM", "09"), ("L", "9"), ("LL", "09"),
        ("d", "18"), ("dd", "18"),
        ("D", "261"), ("DDDD", "0261"),
        ("F", "3"),
        ("w", "38"), ("W", "3"), ("Y", "2026"),
        ("e", "6"), ("ee", "06"), ("c", "6"), ("cc", "6"),
        ("Q", "3"), ("QQ", "03"), ("q", "3"), ("qq", "03"),
        ("H", "14"), ("HH", "14"), ("k", "14"), ("h", "2"), ("hh", "02"), ("K", "2"), ("KK", "02"),
        ("m", "5"), ("mm", "05"),
        ("s", "9"), ("ss", "09"),
        ("S", "3"), ("SS", "30"), ("SSS", "306"), ("SSSS", "3060"),
        ("A", "50709306"),
        ("g", "2461302"),
    ])
    func numericField(pattern: String, expected: String) {
        #expect(style(pattern).format(date) == expected)
    }

    @Test func hoursAtMidnight() {
        let midnight = Date(timeIntervalSince1970: 1_789_689_600)
        #expect(style("H k h K").format(midnight) == "0 24 12 0")
    }

    @Test func fractionalSecondsAreTruncated() {
        #expect(style("HH:mm:ss.SSS").format(Date(timeIntervalSince1970: 1_000_000_000.9995)) == "01:46:40.999")
        #expect(style("yyyy-MM-dd HH:mm:ss.SSS").format(Date(timeIntervalSince1970: -0.0005)) == "1969-12-31 23:59:59.999")
    }

    @Test func weekFieldsFollowCalendarRules() {
        // 2027-01-01 is a Friday, in the last ISO week of 2026.
        let newYear = Date(timeIntervalSince1970: 1_798_761_600)
        #expect(style("Y-ww-e").format(newYear) == "2027-01-6")
        #expect(style("Y-ww-e", firstWeekday: 2, minimumDaysInFirstWeek: 4).format(newYear) == "2026-53-5")
        #expect(style("W c", firstWeekday: 2, minimumDaysInFirstWeek: 4).format(date) == "3 5")
    }

    @Test func yearBeforeCommonEra() {
        // One millisecond before 0001-01-01 (Julian, as the Gregorian calendar uses before 1582) is the last moment of 1 BC.
        let date = Date(timeIntervalSince1970: -62_135_769_600.001)
        #expect(style("y u M d HH:mm:ss.SSS").format(date) == "1 0 12 31 23:59:59.999")
    }

    // From ICU's format.txt TestYearLengths, which follows the table in UTS #35.
    @Test(arguments: [
        (-62_120_131_200.0, ["AD 1", "AD 01", "AD 001", "AD 0001", "AD 00001"]),
        (-61_772_976_000.0, ["AD 12", "AD 12", "AD 012", "AD 0012", "AD 00012"]),
        (-58_270_147_200.0, ["AD 123", "AD 23", "AD 123", "AD 0123", "AD 00123"]),
        (-23_209_632_000.0, ["AD 1234", "AD 34", "AD 1234", "AD 1234", "AD 01234"]),
        (327_419_098_992.0, ["AD 12345", "AD 45", "AD 12345", "AD 12345", "AD 12345"]),
    ])
    func yearLengths(seconds: Double, expected: [String]) {
        let date = Date(timeIntervalSince1970: seconds)
        let actual = ["G y", "G yy", "G yyy", "G yyyy", "G yyyyy"].map { style($0).format(date) }
        #expect(actual == expected)
    }

    // From ICU's DateFormatTest::TestEras and TestISOEra.
    @Test func eras() {
        let bc439 = Date(timeIntervalSince1970: -75_972_556_800) // July 17, 439 BC
        #expect(style("MMMM dd yyyy G").format(bc439) == "July 17 0439 BC")
        #expect(style("MMMM dd yyyy GGGG").format(bc439) == "July 17 0439 Before Christ")
        #expect(style("MMMM dd yyyy GGGG").format(Date(timeIntervalSince1970: -582_595_200)) == "July 17 1951 Anno Domini")
        #expect(style("GGG yyyy-MM-dd'T'HH:mm:ss'Z").format(Date(timeIntervalSince1970: -188_498_422_800)) == "BC 4005-10-23T07:00:00Z")
        #expect(style("GGG yyyy-MM-dd'T'HH:mm:ss'Z").format(Date(timeIntervalSince1970: 64_212_418_800)) == "AD 4004-10-23T07:00:00Z")
    }

    // From ICU's DateFormatTest::TestGeneral. ICU reads whole milliseconds, so .5675 gives 567.
    @Test func fractionalSecondLengths() {
        let date = Date(timeIntervalSince1970: 1_078_936_591.5675) // 2004-03-10 16:36:31.567 UTC
        #expect(style("y/M/d H:mm:ss.S", locale: "en").format(date) == "2004/3/10 16:36:31.5")
        #expect(style("y/M/d H:mm:ss.SS", locale: "en").format(date) == "2004/3/10 16:36:31.56")
        #expect(style("y/M/d H:mm:ss.SSS", locale: "en").format(date) == "2004/3/10 16:36:31.567")
        #expect(style("y/M/d H:mm:ss.SSSS", locale: "en").format(date) == "2004/3/10 16:36:31.5670")
        #expect(style("ss.SSS", locale: "en").format(Date(timeIntervalSince1970: 1_078_936_591.567)) == "31.566")
    }

    // ICU's calendar clamps the date to Julian day ±0x7F000000.
    @Test(arguments: [
        (Double.infinity, "000 0 2130706432"), (1e300, "000 0 2130706432"),
        (-Double.infinity, "000 0 -2130706432"), (-1e300, "000 0 -2130706432"),
    ])
    func outOfRangeDates(seconds: Double, expected: String) {
        #expect(style("SSS A g").format(Date(timeIntervalSinceReferenceDate: seconds)) == expected)
    }

    @Test func nanDate() {
        let nan = Date(timeIntervalSinceReferenceDate: .nan)
        #expect(style("SSS A g").format(nan) == nan.description)
    }

    // MARK: - Digits and minus signs

    @Test func localeDigits() {
        // From ICU's DateFormatTest::TestFormattingLocaleTimeSeparator (Apple's expected values).
        let cet = Date(timeIntervalSince1970: 874_266_720) // 1997-09-14 21:52 CET
        #expect(style("h:mm\u{A0}a", locale: "ar_EG", timeZone: "CET").format(cet) == "\u{669}:\u{665}\u{662}\u{A0}\u{645}")
        #expect(style("h:mm\u{A0}a", locale: "ar_EG@numbers=latn", timeZone: "CET").format(cet) == "9:52\u{A0}\u{645}")

        // Patterns and values from ICU's cdattst.c TestStandardPatterns.
        let date = Date(timeIntervalSince1970: 1_424_841_000) // 2015-02-25 05:10 UTC
        #expect(style("d-M-y", locale: "ff_Adlm").format(date) == "𞥒𞥕-𞥒-𞥒𞥐𞥑𞥕")
        #expect(style("d/M/yy", locale: "mr").format(date) == "25/2/15")
        #expect(style("d-M-yy", locale: "te").format(date) == "25-2-15")
    }

    @Test(arguments: [
        ("ar", "25/2/2015"),
        ("ar_SA", "٢٥/٢/٢٠١٥"),
        ("ar_EG", "٢٥/٢/٢٠١٥"),
        // ICU's cdattst.c TestCountryFallback: these fall back by region to Latin digits.
        ("ar_US", "25/2/2015"),
        ("ar_DE", "25/2/2015"),
        ("ar_FR", "25/2/2015"),
        ("fa", "۲۵/۲/۲۰۱۵"),
        ("ne", "२५/२/२०१५"),
        ("my", "၂၅/၂/၂၀၁၅"),
        ("en@numbers=arab", "٢٥/٢/٢٠١٥"),
        ("fa@numbers=latn", "25/2/2015"),
        ("hi@numbers=deva", "२५/२/२०१५"),
    ])
    func defaultDigits(locale: String, expected: String) {
        #expect(style("d/M/y", locale: locale).format(Date(timeIntervalSince1970: 1_424_841_000)) == expected)
    }

    @Test(arguments: [
        ("en", "-438"),
        ("sv", "\u{2212}438"),
        ("fi", "\u{2212}438"),
        ("he", "\u{200E}-438"),
        ("fa", "\u{200E}\u{2212}۴۳۸"),
        ("ar_EG", "\u{61C}-٤٣٨"),
    ])
    func negativeYearMinusSign(locale: String, expected: String) {
        let bc439 = Date(timeIntervalSince1970: -75_972_556_800)
        #expect(style("u", locale: locale).format(bc439) == expected)
    }

    // From ICU's DateFormatTest::TestNumberFormatOverride and cdattst.c TestOverrideNumberFormat.
    // With the locale keyword, Apple's ICU uses Chinese day numerals for the day field only.
    @Test func hanidays() {
        let date = Date(timeIntervalSince1970: 866_376_000) // 1997-06-15 12:00 UTC
        #expect(style("MM d", locale: "zh@numbers=hanidays").format(date) == "06 十五")
        #expect(style("y-MM-dd", locale: "zh@numbers=hanidays").format(date) == "1997-06-十五")
    }

    // The day numerals don't depend on the language, and aren't padded. Other fields keep the locale's digits.
    @Test func hanidaysDays() {
        let days = (0 ..< 31).map { style("d", locale: "zh@numbers=hanidays").format(Date(timeIntervalSince1970: Double($0) * 86_400)) }
        #expect(days == ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                         "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                         "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十", "丗一"])
        #expect(style("y-MM-dd HH", locale: "en@numbers=hanidays").format(Date(timeIntervalSince1970: 0)) == "1970-01-初一 00")
        #expect(style("y-MM-dd HH", locale: "ar_EG@numbers=hanidays").format(Date(timeIntervalSince1970: 0)) == "١٩٧٠-٠١-初一 ٠٠")
        #expect(style("M d", locale: "en@numbers=hanidays").attributedStyle.format(Date(timeIntervalSince1970: 0)) == attributed([
            ("1", .month), (" ", nil), ("初一", .day),
        ]))
    }

    // Foundation hands ICU the region of any `rg` value of 3 or more characters, as `rg=uszzzz`. ICU ignores an invalid region.
    @Test(arguments: [
        ("ar_US@rg=egzzzz", "٢٥/٢/٢٠١٥"),
        ("ar_US@rg=EGZZZZ", "٢٥/٢/٢٠١٥"),
        ("ar_US@rg=egc", "٢٥/٢/٢٠١٥"),
        ("ar_EG@rg=usca", "25/2/2015"),
        ("ar_EG@rg=us", "٢٥/٢/٢٠١٥"),
        ("ar_EG@rg=uszzzzz", "25/2/2015"),
        ("ar_EG@rg=12zzzz", "٢٥/٢/٢٠١٥"),
        ("ar_EG@rg=xxzzzz", "٢٥/٢/٢٠١٥"),
    ])
    func regionKeyword(locale: String, expected: String) {
        #expect(style("d/M/y", locale: locale).format(Date(timeIntervalSince1970: 1_424_841_000)) == expected)
    }

    // Checks each digit-based numbering system's digits against their Unicode values.
    @Test(arguments: [
        "adlm", "ahom", "arab", "arabext", "bali", "beng", "bhks", "brah", "cakm", "cham", "deva", "diak", "fullwide",
        "gara", "gong", "gonm", "gujr", "gukh", "guru", "hanidec", "hmng", "hmnp", "java", "kali", "kawi", "khmr", "knda",
        "krai", "lana", "lanatham", "laoo", "latn", "lepc", "limb", "mathbold", "mathdbl", "mathmono", "mathsanb",
        "mathsans", "mlym", "modi", "mong", "mroo", "mtei", "mymr", "mymrepka", "mymrpao", "mymrshan", "mymrtlng", "nagm",
        "newa", "nkoo", "olck", "onao", "orya", "osma", "outlined", "rohg", "saur", "segment", "shrd", "sind", "sinh",
        "sora", "sund", "sunu", "takr", "talu", "tamldec", "telu", "thai", "tibt", "tirh", "tnsa", "vaii", "wara", "wcho",
        // swift-foundation-icu's data doesn't have tols yet.
    ] + (hasAppleData ? ["tols"] : []))
    func numberingSystemDigits(system: String) {
        let digits = style("d/M/y", locale: "en@numbers=\(system)").format(date).unicodeScalars.filter { $0 != "/" }
        // A wrong digit in the data gives the wrong values.
        #expect(digits.map(\.properties.numericValue) == [1, 8, 9, 2, 0, 2, 6])
        // A system missing from the data falls back to ASCII digits, whose values still match.
        #expect(system == "latn" || !digits.contains { $0.isASCII })
    }

    // MARK: - Time zone offsets

    @Test(arguments: [
        ("Z", "+0000"), ("ZZZZZ", "Z"), ("X", "Z"), ("XXX", "Z"), ("x", "+00"), ("xx", "+0000"), ("xxx", "+00:00"),
    ])
    func utcOffset(pattern: String, expected: String) {
        #expect(style(pattern).format(date) == expected)
    }

    @Test func offsets() {
        #expect(style("Z|ZZZZZ|X|XX|XXX|XXXX|XXXXX|x|xxx", timeZone: "America/Los_Angeles").format(date) == "-0700|-07:00|-07|-0700|-07:00|-0700|-07:00|-07|-07:00")
        #expect(style("X|XXX", timeZone: "Asia/Kolkata").format(date) == "+0530|+05:30")
        #expect(style("X|XXX", timeZone: "Pacific/Chatham").format(date) == "+1245|+12:45")
    }

    @Test func offsetWithSeconds() {
        // Monrovia used UTC-0:44:30 until 1972.
        let date = Date(timeIntervalSince1970: -315_619_200) // 1960-01-01 00:00 UTC
        #expect(style("XXX|XXXX|XXXXX|Z", timeZone: "Africa/Monrovia").format(date) == "-00:44|-004430|-00:44:30|-004430")
    }

    @Test func daylightSavingTimeChange() {
        // Los Angeles moved from UTC-8 to UTC-7 at 2024-03-10 10:00 UTC.
        let change = Date(timeIntervalSince1970: 1_710_064_800)
        #expect(style("HH:mm:ss.SSS xxx", timeZone: "America/Los_Angeles").format(change - 0.001) == "01:59:59.999 -08:00")
        #expect(style("HH:mm:ss.SSS xxx", timeZone: "America/Los_Angeles").format(change) == "03:00:00.000 -07:00")
    }

    // From ICU's TimeZoneFormatTest::TestISOFormat, for the whole-minute offsets a TimeZone can have.
    @Test(arguments: [
        (0, ["Z", "Z", "Z", "Z", "Z", "+00", "+0000", "+00:00", "+0000", "+00:00", "+0000"]),
        (60, ["+0001", "+0001", "+00:01", "+0001", "+00:01", "+0001", "+0001", "+00:01", "+0001", "+00:01", "+0001"]),
        (1800, ["+0030", "+0030", "+00:30", "+0030", "+00:30", "+0030", "+0030", "+00:30", "+0030", "+00:30", "+0030"]),
        (-3600, ["-01", "-0100", "-01:00", "-0100", "-01:00", "-01", "-0100", "-01:00", "-0100", "-01:00", "-0100"]),
        (36000, ["+10", "+1000", "+10:00", "+1000", "+10:00", "+10", "+1000", "+10:00", "+1000", "+10:00", "+1000"]),
        (-37800, ["-1030", "-1030", "-10:30", "-1030", "-10:30", "-1030", "-1030", "-10:30", "-1030", "-10:30", "-1030"]),
    ])
    func isoOffsets(secondsFromGMT: Int, expected: [String]) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let patterns = ["X", "XX", "XXX", "XXXX", "XXXXX", "x", "xx", "xxx", "xxxx", "xxxxx", "Z"]
        let actual = patterns.map {
            Date.VerbatimFormatStyle(format: Date.FormatString(rawFormat: $0), locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: secondsFromGMT)!, calendar: calendar).format(date)
        }
        #expect(actual == expected)
    }

    @Test func offsetsUseASCIIDigits() {
        #expect(style("XXX Z", locale: "ar_EG", timeZone: "Asia/Kolkata").format(date) == "+05:30 +0530")
    }

    @Test func zoneIDs() {
        #expect(style("VV", timeZone: "America/Los_Angeles").format(date) == "America/Los_Angeles")
        #expect(style("VV", timeZone: "US/Pacific").format(date) == "US/Pacific")
        #expect(style("VV", timeZone: "GMT").format(date) == "GMT")
        // Offset time zones get ICU's form of the identifier.
        #expect(style("VV", timeZone: "GMT+0530").format(date) == "GMT+05:30")
        #expect(style("VV", timeZone: "GMT-1").format(date) == "GMT-01:00")
        #expect(style("d VV", timeZone: "Europe/Paris").attributedStyle.format(date) == attributed([
            ("18", .day), (" ", nil), ("Europe/Paris", .timeZone),
        ]))
    }

    // From ICU's DateFormatTest TestTimeZoneDisplayName.
    @Test(arguments: [
        ("en", "Australia/Sydney", 1_074_124_800.0, "GMT+11:00"),
        ("en", "Australia/Sydney", 1_089_849_600.0, "GMT+10:00"),
        ("en", "Europe/London", 1_089_849_600.0, "GMT+01:00"),
        ("de", "Australia/Sydney", 1_089_849_600.0, "GMT+10:00"),
        ("de", "Europe/London", 1_089_849_600.0, "GMT+01:00"),
        ("de", "Etc/GMT+3", 1_074_124_800.0, "GMT-03:00"),
    ])
    func localizedGMT(locale: String, timeZone: String, seconds: Double, expected: String) {
        #expect(style("ZZZZ", locale: locale, timeZone: timeZone).format(Date(timeIntervalSince1970: seconds)) == expected)
    }

    // Short and long localized GMT, with each locale's pattern, signs, separators, and digits.
    @Test(arguments: [
        ("en", "America/Los_Angeles", "GMT-7|GMT-07:00|GMT-07:00"),
        ("en", "Asia/Kolkata", "GMT+5:30|GMT+05:30|GMT+05:30"),
        ("en", "Pacific/Chatham", "GMT+12:45|GMT+12:45|GMT+12:45"),
        ("fr", "America/St_Johns", "UTC\u{2212}2:30|UTC\u{2212}02:30|UTC\u{2212}02:30"),
        ("fi", "Asia/Kolkata", "UTC+5.30|UTC+05.30|UTC+05.30"),
        ("am", "Asia/Kolkata", "ጂ ኤም ቲ+530|ጂ ኤም ቲ+0530|ጂ ኤም ቲ+0530"),
        ("mr", "America/Los_Angeles", "[GMT]-7|[GMT]-07:00|[GMT]-07:00"),
        ("ar_EG", "Asia/Kolkata", "غرينتش+٥:٣٠|غرينتش+٠٥:٣٠|غرينتش+٠٥:٣٠"),
        ("ar", "Asia/Kolkata", "غرينتش+5:30|غرينتش+05:30|غرينتش+05:30"),
        ("en@numbers=arab", "Asia/Kolkata", "GMT+٥:٣٠|GMT+٠٥:٣٠|GMT+٠٥:٣٠"),
        ("fa", "America/Los_Angeles", "\u{200E}\u{2212}۷ گرینویچ|\u{200E}\u{2212}۰۷:۰۰ گرینویچ|\u{200E}\u{2212}۰۷:۰۰ گرینویچ"),
        ("he", "America/Los_Angeles", "GMT-7\u{200E}|GMT-07:00\u{200E}\u{200E}|GMT-07:00\u{200E}\u{200E}"),
        ("he", "Asia/Kolkata", "GMT\u{200E}+5:30\u{200E}|GMT\u{200E}+05:30\u{200E}|GMT\u{200E}+05:30\u{200E}"),
    ])
    func localizedGMTForms(locale: String, timeZone: String, expected: String) {
        #expect(style("O|OOOO|ZZZZ", locale: locale, timeZone: timeZone).format(date) == expected)
    }

    @Test func localizedGMTWithSeconds() {
        // Monrovia used UTC-0:44:30 until 1972.
        let date = Date(timeIntervalSince1970: -315_619_200) // 1960-01-01 00:00 UTC
        #expect(style("O|OOOO", timeZone: "Africa/Monrovia").format(date) == "GMT-0:44:30|GMT-00:44:30")
        #expect(style("O|OOOO", locale: "fi", timeZone: "Africa/Monrovia").format(date) == "UTC-0.44.30|UTC-00.44.30")
        #expect(style("O|OOOO", locale: "fa", timeZone: "Africa/Monrovia").format(date) == "\u{200E}\u{2212}۰:۴۴:۳۰ گرینویچ|\u{200E}\u{2212}۰۰:۴۴:۳۰ گرینویچ")
    }

    @Test func localizedGMTCounts() {
        // `OO`, `OOO`, and five or more `O` write nothing. `ZZZZ` and six or more `Z` are long localized GMT.
        #expect(style("OO|OOO|OOOOO|ZZZZZZ", timeZone: "America/Los_Angeles").format(date) == "|||GMT-07:00")
        #expect(style("d OOOO", timeZone: "America/Los_Angeles").attributedStyle.format(date) == attributed([
            ("18", .day), (" ", nil), ("GMT-07:00", .timeZone),
        ]))
    }

    // ICU 78 writes a zero offset like any other, and ICU 76 uses the locale's zero format, such as "GMT".
    @Test(.enabled(if: hasAppleData), arguments: [
        ("en", "Europe/London", 1_074_124_800.0, "GMT+0|GMT+00:00"),
        ("de", "Europe/London", 1_074_124_800.0, "GMT+0|GMT+00:00"),
        ("fr", "UTC", 1_074_124_800.0, "UTC+0|UTC+00:00"),
        ("ar_EG", "UTC", 1_074_124_800.0, "غرينتش+٠|غرينتش+٠٠:٠٠"),
    ])
    func localizedGMTZero(locale: String, timeZone: String, seconds: Double, expected: String) {
        #expect(style("O|ZZZZ", locale: locale, timeZone: timeZone).format(Date(timeIntervalSince1970: seconds)) == expected)
    }

    // MARK: - Literals and quoting

    @Test(arguments: [
        ("yyyy-MM-dd'T'HH:mm:ss.SSS", "2026-09-18T14:05:09.306"),
        ("'o''clock' h", "o'clock 2"),
        ("h''mm", "2'05"),
        ("''", "'"),
        ("'yyyy'", "yyyy"),
        ("'unterminated d", "unterminated d"),
        ("[d] é 🙂 d", "[18] é 🙂 18"),
        ("d:", "18:"),
        ("ll d", " 18"),
    ])
    func literals(pattern: String, expected: String) {
        #expect(style(pattern).format(date) == expected)
    }

    @Test func invalidPatternLetter() {
        // A letter that isn't a pattern character fails, and the style falls back to the date's description.
        #expect(style("d J").format(date) == date.description)
    }

    // Both paths treat empty output as a failure.
    @Test func emptyOutput() {
        #expect(style("").format(date) == date.description)
    }

    // MARK: - Field attributes

    func attributed(_ pieces: [(String, Field?)]) -> AttributedString {
        var result = AttributedString()
        for (text, field) in pieces {
            var piece = AttributedString(text)
            if let field {
                piece.dateField = field
            }
            result += piece
        }
        return result
    }

    @Test func fieldAttributes() {
        #expect(style("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", timeZone: "America/Los_Angeles").attributedStyle.format(date) == attributed([
            ("2026", .year), ("-", nil), ("09", .month), ("-", nil), ("18", .day), ("T", nil),
            ("07", .hour), (":", nil), ("05", .minute), (":", nil), ("09", .second), (".", nil), ("306", .secondFraction), ("-07:00", .timeZone),
        ]))
        #expect(style("'o''clock' h:mm").attributedStyle.format(date) == attributed([
            ("o'clock ", nil), ("2", .hour), (":", nil), ("05", .minute),
        ]))
        #expect(style("Q/q e c D F").attributedStyle.format(date) == attributed([
            ("3", .quarter), ("/", nil), ("3", .quarter), (" ", nil), ("6", .weekday), (" ", nil), ("6", .weekday),
            (" ", nil), ("261", .dayOfYear), (" ", nil), ("3", .weekdayOrdinal),
        ]))
        #expect(style("Y-'W'ww-e").attributedStyle.format(date) == attributed([
            ("2026", .year), ("-W", nil), ("38", .weekOfYear), ("-", nil), ("6", .weekday),
        ]))
        #expect(style("ll d").attributedStyle.format(date) == attributed([(" ", nil), ("18", .day)]))
    }

    // MARK: - Names

    // From ICU's DateFormatTest TestStandAloneMonths, TestStandAloneDays, TestShortDays, TestNarrowNames, and TestQuarters. Dates are UTC.
    @Test(arguments: [
        ("en", "yyyy LLLL dd H:mm:ss", 1_078_936_591.0, "2004 March 10 16:36:31"),
        ("en", "yyyy LLL dd H:mm:ss", 1_078_936_591.0, "2004 Mar 10 16:36:31"),
        ("en", "LLLL", 20_995_200.0, "September"),
        ("en", "LLL", 20_995_200.0, "Sep"),
        ("cs", "yyyy LLLL dd H:mm:ss", 1_081_614_991.0, "2004 duben 10 16:36:31"),
        ("cs", "yyyy MMMM dd H:mm:ss", 1_081_614_991.0, "2004 dubna 10 16:36:31"),
        ("cs", "yyyy LLL dd H:mm:ss", 1_081_614_991.0, "2004 dub 10 16:36:31"),
        ("cs", "LLLL", 20_995_200.0, "září"),
        ("cs", "LLL", 15_638_400.0, "čvc"),
        ("en", "cccc", 259_200.0, "Sunday"),
        ("en", "ccc", 0.0, "Thu"),
        ("cs", "cccc", 432_000.0, "úterý"),
        ("cs", "ccc", 0.0, "čt"),
        ("en", "EEEEEE, MMM d y", 1_358_035_200.0, "Su, Jan 13 2013"),
        ("en", "EEEEEE, MMM d y", 1_358_294_400.0, "We, Jan 16 2013"),
        ("en", "cccccc d", 1_382_400.0, "Sa 17"),
        ("sv", "EEEEEE d MMM y", 1_358_035_200.0, "sö 13 jan. 2013"),
        ("sv", "EEEEEE d MMM y", 1_358_294_400.0, "on 16 jan. 2013"),
        ("sv", "cccccc", 172_800.0, "lö"),
        ("en", "yyyy MMMMM dd H:mm:ss", 1_078_936_591.0, "2004 M 10 16:36:31"),
        ("en", "LLLLL", 20_995_200.0, "S"),
        ("en", "EEEEE", 432_000.0, "T"),
        ("en", "ccccc", 518_400.0, "W"),
        ("en", "h:mm a", 1_420_106_400.0, "10:00 AM"),
        ("en", "h:mm a", 1_420_149_600.0, "10:00 PM"),
        ("en", "h:mm aaaaa", 1_420_106_400.0, "10:00 a"),
        ("en", "h:mm aaaaa", 1_420_149_600.0, "10:00 p"),
        ("cs", "yyyy MMMMM dd H:mm:ss", 1_081_614_991.0, "2004 4 10 16:36:31"),
        ("cs", "LLLLL", 28_857_600.0, "12"),
        ("cs", "EEEEE", 432_000.0, "Ú"),
        ("cs", "ccccc", 0.0, "Č"),
        ("cs", "h:mm a", 1_420_106_400.0, "10:00 dop."),
        ("cs", "h:mm aaaaa", 1_420_149_600.0, "10:00 odp."),
        ("en", "Q", 0.0, "1"),
        ("en", "QQQ", 15_638_400.0, "Q3"),
        ("en", "QQQQ", 23_587_200.0, "4th quarter"),
        ("en", "QQQQQ", 23_587_200.0, "4"),
        ("en", "qqq", 15_638_400.0, "Q3"),
        ("en", "qqqq", 23_587_200.0, "4th quarter"),
        ("en", "qqqqq", 23_587_200.0, "4"),
        ("en", "Qyy", 1_427_846_400.0, "215"),
        ("en", "QQyy", 1_435_708_800.0, "0315"),
        ("es_MX", "qqq", 0.0, "1er. trim."),
        ("es_MX", "qqqqq", 0.0, "1T"),
    ])
    func names(locale: String, pattern: String, seconds: Double, expected: String) {
        #expect(style(pattern, locale: locale).format(Date(timeIntervalSince1970: seconds)) == expected)
    }

    // Apple's ICU data and ICU 78 behavior, which the SwiftPM build's ICU 76 doesn't have.
    static let hasAppleData: Bool = {
#if FOUNDATION_FRAMEWORK || FOUNDATION_DATE_FORMAT_SWIFT
        true
#else
        false
#endif
    }()

    // From the Apple blocks in ICU's DateFormatTest TestQuarters, TestNarrowNames, and TestAmPmLengths23114.
    @Test(.enabled(if: hasAppleData), arguments: [
        ("es_MX", "QQQQ y", 0.0, "1er. trimestre 1970"),
        ("es_MX", "QQQ y", 0.0, "1er. trim. 1970"),
        ("es_MX", "QQQQQ y", 0.0, "1T 1970"),
        ("es_MX", "qqqq", 0.0, "1er. trimestre"),
        ("ca", "h:mm a", 1_420_106_400.0, "10:00 a.\u{202F}m."),
        ("ca", "h:mm a", 1_420_149_600.0, "10:00 p.\u{202F}m."),
        ("ca", "h:mm aaaaa", 1_420_106_400.0, "10:00 a.m."),
        ("ca", "h:mm aaaaa", 1_420_149_600.0, "10:00 p.m."),
        ("th", "h:mm:ss a", 939_859_139.0, "11:58:59 PM"),
        ("th", "h:mm:ss aaaa", 939_859_139.0, "11:58:59 PM"),
        // ICU 76 uses narrow AM/PM for 6 or more letters, and ICU 78 uses abbreviated.
        ("en", "aaaaaa", 1_789_740_309.306, "PM"),
        ("en", "bbbbbb", 1_447_376_400.0, "AM"),
    ])
    func appleNames(locale: String, pattern: String, seconds: Double, expected: String) {
        #expect(style(pattern, locale: locale).format(Date(timeIntervalSince1970: seconds)) == expected)
    }

    @Test func nameFieldAttributes() {
        #expect(style("EEEE, MMMM d, y G 'at' h:mm a").attributedStyle.format(date) == attributed([
            ("Friday", .weekday), (", ", nil), ("September", .month), (" ", nil), ("18", .day), (", ", nil), ("2026", .year), (" ", nil), ("AD", .era),
            (" at ", nil), ("2", .hour), (":", nil), ("05", .minute), (" ", nil), ("PM", .amPM),
        ]))
        #expect(style("QQQ LLL ccc").attributedStyle.format(date) == attributed([
            ("Q3", .quarter), (" ", nil), ("Sep", .month), (" ", nil), ("Fri", .weekday),
        ]))
    }

    // Counts past the longest name form, as ICU's SimpleDateFormat::subFormat handles them.
    @Test(arguments: [
        ("MMMMMM", "000009"), ("LLLLLL", "000009"),
        ("QQQQQQ", "3"), ("qqqqqq", "3"),
    ])
    func longNameCounts(pattern: String, expected: String) {
        #expect(style(pattern).format(date) == expected)
    }

    // Apple's ICU doesn't pass these yet.
    // TODO: Remove `hasSymbolLoadingFix` once rdar://188932615 and rdar://188036385 are fixed.
    static let hasSymbolLoadingFix: Bool = {
#if FOUNDATION_FRAMEWORK && !FOUNDATION_DATE_FORMAT_SWIFT
        false
#else
        true
#endif
    }()

    @Test(.enabled(if: hasSymbolLoadingFix), arguments: [
        ("GGGGGG", "AD"), ("GGGGGGG", "AD"),
        ("EEEEEEE", "Fri"), ("eeeeeee", "Fri"), ("ccccccc", "Fri"),
    ])
    func longAbbreviatedNameCounts(pattern: String, expected: String) {
        #expect(style(pattern).format(date) == expected)
    }

    // From ICU's DateFormatTest TestAmPmMidnightNoon, TestDayPeriodWithLocales, and TestMinuteSecondFieldsInOddPlaces, with noon in more locales. Dates are on 2015-11-13 UTC.
    @Test(arguments: [
        ("en", "hh:mm:ss bbb", 1_447_372_800.0, "12:00:00 AM"),
        ("en", "hh:mm:ss bbb", 1_447_372_830.0, "12:00:30 AM"),
        ("en", "hh:mm:ss bbb", 1_447_374_600.0, "12:30:00 AM"),
        ("en", "hh:mm:ss bbb", 1_447_394_400.0, "06:00:00 AM"),
        ("en", "hh:mm:ss bbb", 1_447_416_000.0, "12:00:00 noon"),
        ("en", "hh:mm:ss bbb", 1_447_437_600.0, "06:00:00 PM"),
        ("en", "hh:mm bbbb", 1_447_416_000.0, "12:00 noon"),
        ("en", "hh bbbbb", 1_447_374_600.0, "12 a"),
        ("en", "hh:mm:ss bbbbb", 1_447_416_000.0, "12:00:00 n"),
        ("en", "hh:mm:ss bbbbb", 1_447_437_600.0, "06:00:00 p"),
        // Noon needs zero minutes and seconds only where the pattern shows them.
        ("en", "hh:mm b", 1_447_416_030.0, "12:00 noon"),
        ("en", "hh b", 1_447_417_800.0, "12 noon"),
        ("en", "hh:mm:ss b", 1_447_416_030.0, "12:00:30 PM"),
        ("en", "hh:mm 'ss' bbbb", 1_447_416_030.0, "12:00 ss noon"),
        ("en", "hh 'mm ss' bbbb", 1_447_417_800.0, "12 mm ss noon"),
        ("en", "bbbb hh:mm:ss", 1_447_416_030.0, "PM 12:00:30"),
        // de has no word for noon.
        ("de", "hh:mm:ss bbbb", 1_447_416_000.0, "12:00:00 PM"),
        ("fr", "h:mm b", 1_447_416_000.0, "12:00 midi"),
        ("es", "h:mm b", 1_447_416_000.0, "12:00 del mediodía"),
        ("ja", "h:mm b", 1_447_416_000.0, "12:00 正午"),
        ("ru", "h:mm b", 1_447_416_000.0, "12:00 полд."),
        ("ru", "h:mm bbbb", 1_447_416_000.0, "12:00 полдень"),
        ("pl", "h:mm bbbbb", 1_447_416_000.0, "12:00 w poł."),
        ("tr", "h:mm bbbbb", 1_447_416_000.0, "12:00 ö"),
    ])
    func noon(locale: String, pattern: String, seconds: Double, expected: String) {
        #expect(style(pattern, locale: locale).format(Date(timeIntervalSince1970: seconds)) == expected)
    }

    @Test func noonFieldAttributes() {
        #expect(style("h:mm b").attributedStyle.format(Date(timeIntervalSince1970: 1_447_416_000)) == attributed([
            ("12", .hour), (":", nil), ("00", .minute), (" ", nil), ("noon", .amPM),
        ]))
        #expect(style("h:mm b").attributedStyle.format(Date(timeIntervalSince1970: 1_447_437_600)) == attributed([
            ("6", .hour), (":", nil), ("00", .minute), (" ", nil), ("PM", .amPM),
        ]))
    }

    @Test(.enabled(if: hasSymbolLoadingFix)) func longNoonCounts() {
        #expect(style("bbbbbb").format(Date(timeIntervalSince1970: 1_447_416_000)) == "noon")
    }

    // MARK: - Locales

    // CLDR locales that ICU doesn't build, which CLDR parents to root.
    @Test(arguments: ["en_Dsrt", "zh_Latn"])
    func localesOutsideICU(locale: String) {
        #expect(style("MMM EEEE a d", locale: locale).format(date) == "M09 Fri PM 18")
    }

    // Apple's ICU aliases.
    @Test(.enabled(if: hasAppleData), arguments: [
        ("wuu", "a", "下午"),
        ("ks_Aran", "d", "۱۸"),
        ("pa_Aran", "d", "۱۸"),
    ])
    func appleAliases(locale: String, pattern: String, expected: String) {
        #expect(style(pattern, locale: locale).format(date) == expected)
    }

    // Identifiers in any case, in BCP 47 form, or with keywords.
    @Test(arguments: [
        ("EN_GB", "EEEE d MMMM", "Friday 18 September"),
        ("DE_DE", "EEEE MMMM G", "Freitag September n. Chr."),
        ("zh_hant_tw", "MMMM G", "9月 西元"),
        ("sr_latn", "EEEE MMMM", "petak septembar"),
        ("en_gb", "h a", "2 pm"),
        ("ar_eg", "d/M/y", "١٨/٩/٢٠٢٦"),
        ("sr-Latn", "MMMM", "septembar"),
        ("th-TH-u-nu-thai", "d/M/y", "๑๘/๙/๒๐๒๖"),
        ("ar-EG-u-nu-latn", "d/M/y", "18/9/2026"),
        ("en-US-u-nu-arab", "d/M/y", "١٨/٩/٢٠٢٦"),
        ("ar-US-u-rg-egzzzz", "d/M/y", "١٨/٩/٢٠٢٦"),
        ("en-GB-u-ca-gregory-nu-arab", "d MMMM", "١٨ September"),
    ])
    func identifierForms(locale: String, pattern: String, expected: String) {
        #expect(style(pattern, locale: locale).format(date) == expected)
    }

    // MARK: - Script fallback

    // As ICU falls back for a locale without data: with a script and a region, it drops the script if that's the default
    // for the language and region (en_Latn_GB to en_GB), else the region (zh_Hans_TW to zh_Hans).
    @Test(arguments: [
        ("ar_Arab_EG", "d", "١٨"),
        ("en_Latn_GB", "a", "pm"),
        ("es_Latn_MX", "MMM", "sep"),
        ("fr_Latn_CA", "a", "p.m."),
        ("az_RU", "MMM", "сен"),
        ("zh_Hans_TW", "a", "下午"),
        ("sr_Latn_XX", "MMM", "sep"),
    ])
    func scriptFallback(locale: String, pattern: String, expected: String) {
        #expect(style(pattern, locale: locale).format(date) == expected)
    }

#if FOUNDATION_DATE_FORMAT_SWIFT
    // MARK: - Languages without data

    // A language with no data uses root, unless the data was built with a fallback locale.
    @Test(arguments: [
        ("xx", "Thu M01 CE AM 1 1970"),
        ("xx_YY", "Thu M01 CE AM 1 1970"),
        ("de_XX", "Donnerstag Januar n. Chr. AM 1 1970"),
        // CLDR languages that ICU doesn't build.
        ("la", "Thu M01 CE AM 1 1970"),
        ("kaa", "Thu M01 CE AM 1 1970"),
        ("kaa_Latn", "Thu M01 CE AM 1 1970"),
        ("cu_Glag", "Thu M01 CE AM 1 1970"),
    ])
    func languagesWithoutData(locale: String, expected: String) {
        let info = ICUDateFormatter.DateFormatInfo(localeIdentifier: locale, timeZoneIdentifier: "UTC", calendarIdentifier: .gregorian, firstWeekday: 1, minimumDaysInFirstWeek: 1, capitalizationContext: .unknown, pattern: "EEEE MMMM G a d y")
        #expect(DatePatternFormatter(info).format(Date(timeIntervalSince1970: 0)) == expected)
    }

    // MARK: - Unsupported

    func info(_ pattern: String, calendar: Calendar.Identifier = .gregorian) -> ICUDateFormatter.DateFormatInfo {
        ICUDateFormatter.DateFormatInfo(localeIdentifier: "en_US", timeZoneIdentifier: "UTC", calendarIdentifier: calendar, firstWeekday: 1, minimumDaysInFirstWeek: 1, capitalizationContext: .unknown, pattern: pattern)
    }

    // The data has only Gregorian names.
    @Test(arguments: [Calendar.Identifier.japanese, .hebrew, .islamicUmmAlQura, .buddhist, .chinese])
    func unsupportedCalendars(calendar: Calendar.Identifier) {
        let formatter = DatePatternFormatter(info("G y MMMM d", calendar: calendar))
        #expect(formatter.format(date) == "\(calendar.cldrIdentifier)_CALENDAR_IS_UNSUPPORTED")
        #expect(formatter.attributedFormat(date) == AttributedString("\(calendar.cldrIdentifier)_CALENDAR_IS_UNSUPPORTED"))
    }

    @Test func iso8601Calendar() {
        #expect(DatePatternFormatter(info("G y MMMM d", calendar: .iso8601)).format(date) == "AD 2026 September 18")
    }

    @Test(arguments: ["z", "zzzz", "v", "vvvv", "V", "VVV", "VVVV", "B", "BBBB", "ddd"])
    func unsupportedFields(field: String) {
        #expect(DatePatternFormatter(info("d \(field)")).format(date) == "18 \(field)_IS_UNSUPPORTED")
    }

    // The text takes the field's attribute, and isn't titlecased.
    @Test func unsupportedFieldAttributes() {
        let formatter = DatePatternFormatter(ICUDateFormatter.DateFormatInfo(localeIdentifier: "en_US", timeZoneIdentifier: "UTC", calendarIdentifier: .gregorian, firstWeekday: 1, minimumDaysInFirstWeek: 1, capitalizationContext: .beginningOfSentence, pattern: "vvvv d"))
        #expect(formatter.attributedFormat(date) == attributed([("vvvv_IS_UNSUPPORTED", .timeZone), (" ", nil), ("18", .day)]))
    }

    @Test func quotedUnsupportedLetters() {
        #expect(DatePatternFormatter(info("'zvVB ddd' d")).format(date) == "zvVB ddd 18")
    }

    @Test func unsupportedCalendarThroughStyle() {
        let style = Date.VerbatimFormatStyle(format: "\(era: .abbreviated) \(year: .defaultDigits)", locale: Locale(identifier: "ja_JP"), timeZone: .gmt, calendar: Calendar(identifier: .japanese))
        #expect(style.format(date) == "japanese_CALENDAR_IS_UNSUPPORTED")
    }
#endif

    // MARK: - Capitalization

    // 2008-07-02 12:00:01.979 UTC, a Wednesday, from ICU's TestContext.
    let july022008 = Date(timeIntervalSince1970: 1_215_000_001.979)

    /// Fills in `pattern` with a capitalization context, which `Date.VerbatimFormatStyle` doesn't have, through whichever formatter this build uses.
    func format(_ pattern: String, locale: String, context: FormatStyleCapitalizationContext) -> String? {
        let info = ICUDateFormatter.DateFormatInfo(localeIdentifier: locale, timeZoneIdentifier: "UTC", calendarIdentifier: .gregorian, firstWeekday: 1, minimumDaysInFirstWeek: 1, capitalizationContext: context, pattern: pattern)
#if FOUNDATION_DATE_FORMAT_SWIFT
        return DatePatternFormatter(info).format(july022008)
#else
        return ICUDateFormatter.cachedFormatter(for: info)?.format(july022008)
#endif
    }

    /// The output for the contexts unknown, middle of sentence, beginning of sentence, list item, and standalone.
    func formatInEveryContext(_ pattern: String, locale: String) -> [String?] {
        [FormatStyleCapitalizationContext.unknown, .middleOfSentence, .beginningOfSentence, .listItem, .standalone].map { format(pattern, locale: locale, context: $0) }
    }

    // From ICU's DateFormatTest TestContext, with more locales and fields. The first field is capitalized if it starts
    // with a lowercase letter: always at the beginning of a sentence, and for list items and standalone use as the
    // locale's contextTransforms say for that field.
    @Test(arguments: [
        ("fr", "MMMM y", ["juillet 2008", "juillet 2008", "Juillet 2008", "juillet 2008", "Juillet 2008"]),
        ("cs", "LLLL y", ["červenec 2008", "červenec 2008", "Červenec 2008", "Červenec 2008", "červenec 2008"]),
        ("fr", "EEEE d MMMM y", ["mercredi 2 juillet 2008", "mercredi 2 juillet 2008", "Mercredi 2 juillet 2008", "mercredi 2 juillet 2008", "Mercredi 2 juillet 2008"]),
        ("pt", "EEEE", ["quarta-feira", "quarta-feira", "Quarta-feira", "Quarta-feira", "Quarta-feira"]),
        ("ru", "GGGG y", ["от Рождества Христова 2008", "от Рождества Христова 2008", "От Рождества Христова 2008", "От Рождества Христова 2008", "От Рождества Христова 2008"]),
        ("ru", "MMMM d", ["июля 2", "июля 2", "Июля 2", "Июля 2", "Июля 2"]),
        ("ca", "LLLL", ["juliol", "juliol", "Juliol", "juliol", "juliol"]),
        // Only the first field, and only a lowercase first letter.
        ("fr", "d MMMM", ["2 juillet", "2 juillet", "2 juillet", "2 juillet", "2 juillet"]),
        ("fr", "QQQQ", ["3e trimestre", "3e trimestre", "3e trimestre", "3e trimestre", "3e trimestre"]),
    ])
    func capitalization(locale: String, pattern: String, expected: [String]) {
        #expect(formatInEveryContext(pattern, locale: locale) == expected)
    }

    @Test func capitalizationDataFallback() {
        // pt_PT has contextTransforms without day names, which hide pt's. ICU doesn't merge them.
        #expect(formatInEveryContext("EEEE", locale: "pt_PT") == ["quarta-feira", "quarta-feira", "Quarta-feira", "quarta-feira", "quarta-feira"])
        #expect(formatInEveryContext("EEEE", locale: "pt_BR") == ["quarta-feira", "quarta-feira", "Quarta-feira", "Quarta-feira", "Quarta-feira"])
    }

    @Test func capitalizationThroughFormatStyle() {
        let style = Date.FormatStyle(locale: Locale(identifier: "fr"), timeZone: .gmt, capitalizationContext: .beginningOfSentence).month(.wide)
        #expect(style.format(july022008) == "Juillet")
    }

    // From the Apple blocks in ICU's DateFormatTest TestContext. Where the output starts with fixed text, Apple's ICU
    // capitalizes that text instead of the first field: always at the beginning of a sentence, and for list items and
    // standalone use as the locale's date-other-beginning contextTransforms say.
    @Test(.enabled(if: hasAppleData), arguments: [
        ("vi", "'ngày' d MMMM, y", ["ngày 2 tháng 7, 2008", "ngày 2 tháng 7, 2008", "Ngày 2 tháng 7, 2008", "Ngày 2 tháng 7, 2008", "Ngày 2 tháng 7, 2008"]),
        ("fr", "'le' EEEE d MMMM y", ["le mercredi 2 juillet 2008", "le mercredi 2 juillet 2008", "Le mercredi 2 juillet 2008", "le mercredi 2 juillet 2008", "le mercredi 2 juillet 2008"]),
        ("en", "'today' EEEE", ["today Wednesday", "today Wednesday", "Today Wednesday", "today Wednesday", "today Wednesday"]),
        ("fr", "'(le)' EEEE", ["(le) mercredi", "(le) mercredi", "(le) mercredi", "(le) mercredi", "(le) mercredi"]),
    ])
    func capitalizationOfLeadingText(locale: String, pattern: String, expected: [String]) {
        #expect(formatInEveryContext(pattern, locale: locale) == expected)
    }

    // Titlecasing the first letter follows the locale, as ICU's toTitle does, and leaves the rest unchanged.
    @Test(.enabled(if: hasAppleData), arguments: [
        ("tr", "'iyi' d", "İyi 2"),
        ("tr", "'ılık' d", "Ilık 2"),
        ("az", "'il' d", "İl 2"),
        ("en", "'iyi' d", "Iyi 2"),
        ("nl", "'ijs' d", "IJs 2"),
        ("nl", "'i\u{301}j\u{301}s' d", "I\u{301}J\u{301}s 2"),
        ("en", "'ijs' d", "Ijs 2"),
        ("hy", "'և' d", "Եվ 2"),
        ("de", "'ß' d", "Ss 2"),
        ("lt", "'i\u{307}x' d", "I\u{307}x 2"),
    ])
    func titlecasing(locale: String, pattern: String, expected: String) {
        #expect(format(pattern, locale: locale, context: .beginningOfSentence) == expected)
    }

#if FOUNDATION_DATE_FORMAT_SWIFT
    // Field ranges follow a titlecase that changes the length, where Apple's ICU leaves them where they were.
    // İ is longer than i in UTF-8 only.
    @Test(arguments: [
        ("hy", "'և' d", "Եվ "),
        ("tr", "'iyi' d", "İyi "),
    ])
    func titlecasingShiftsFields(locale: String, pattern: String, expected: String) {
        let info = ICUDateFormatter.DateFormatInfo(localeIdentifier: locale, timeZoneIdentifier: "UTC", calendarIdentifier: .gregorian, firstWeekday: 1, minimumDaysInFirstWeek: 1, capitalizationContext: .beginningOfSentence, pattern: pattern)
        #expect(DatePatternFormatter(info).attributedFormat(july022008) == attributed([(expected, nil), ("2", .day)]))
    }
#endif
}
