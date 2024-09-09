// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
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
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

struct DateIntervalFormatStyleTests {
    
    let minute: TimeInterval = 60
    let hour: TimeInterval = 60 * 60
    let day: TimeInterval = 60 * 60 * 24
    let enUSLocale = Locale(identifier: "en_US")
    let calendar = Calendar(identifier: .gregorian)
    let timeZone = TimeZone(abbreviation: "GMT")!
    
    let date = Date(timeIntervalSinceReferenceDate: 0)
    
    @Test func testDefaultFormatStyle() throws {
        var style = Date.IntervalFormatStyle()
        style.timeZone = timeZone
        // Make sure the default style does produce some output
        #expect(style.format(date ..< date + hour).count > 0)
    }
    
    @Test func testBasicFormatStyle() throws {
        let style = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        #expect(style.format(date..<date + hour) == "1/1/2001, 12:00 – 1:00 AM")
        #expect(style.format(date..<date + day) == "1/1/2001, 12:00 AM – 1/2/2001, 12:00 AM")
        #expect(style.format(date..<date + day * 32) == "1/1/2001, 12:00 AM – 2/2/2001, 12:00 AM")
        let dayStyle = Date.IntervalFormatStyle(date: .long, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        #expect(dayStyle.format(date..<date + hour) == "January 1, 2001")
        #expect(dayStyle.format(date..<date + day) == "January 1 – 2, 2001")
        #expect(dayStyle.format(date..<date + day * 32) == "January 1 – February 2, 2001")
        
        let timeStyle = Date.IntervalFormatStyle(time: .standard, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        #expect(timeStyle.format(date..<date + hour) == "12:00:00 AM – 1:00:00 AM")
        #expect(timeStyle.format(date..<date + day) == "1/1/2001, 12:00:00 AM – 1/2/2001, 12:00:00 AM")
        #expect(timeStyle.format(date..<date + day * 32) == "1/1/2001, 12:00:00 AM – 2/2/2001, 12:00:00 AM")
        
        let dateTimeStyle = Date.IntervalFormatStyle(date:.numeric, time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone)
        #expect(dateTimeStyle.format(date..<date + hour) == "1/1/2001, 12:00 – 1:00 AM")
        #expect(dateTimeStyle.format(date..<date + day) == "1/1/2001, 12:00 AM – 1/2/2001, 12:00 AM")
        #expect(dateTimeStyle.format(date..<date + day * 32) == "1/1/2001, 12:00 AM – 2/2/2001, 12:00 AM")
    }
    
    @Test func testCustomFields() throws {
        let fullDayStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).year().month().weekday().day()
        #expect(fullDayStyle.format(date..<date + hour) == "Mon, Jan 1, 2001")
        #expect(fullDayStyle.format(date..<date + day) == "Mon, Jan 1 – Tue, Jan 2, 2001")
        #expect(fullDayStyle.format(date..<date + day * 32) == "Mon, Jan 1 – Fri, Feb 2, 2001")
        let timeStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour().timeZone()
        #expect(timeStyle.format(date..<date + hour * 0.5) == "12 AM GMT")
        #expect(timeStyle.format(date..<date + hour) == "12 – 1 AM GMT")
        #expect(timeStyle.format(date..<date + hour * 1.5) == "12 – 1 AM GMT")
        // The date interval range (day) is larger than the specified unit (hour), so ICU fills the missing day parts to AMbiguate.
        #expect(timeStyle.format(date..<date + day) == "1/1/2001, 12 AM GMT – 1/2/2001, 12 AM GMT")
        #expect(timeStyle.format(date..<date + day * 32) == "1/1/2001, 12 AM GMT – 2/2/2001, 12 AM GMT")
        let weekDayStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).weekday()
        #expect(weekDayStyle.format(date..<date + hour) == "Mon")
        #expect(weekDayStyle.format(date..<date + day) == "Mon – Tue")
        #expect(weekDayStyle.format(date..<date + day * 32) == "Mon – Fri")
        
        // This style doesn't really make sense since the gap between `weekDay` and `hour` makes the result AMbiguous. ICU fills the missing pieces on our behalf.
        let weekDayHourStyle = Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone).weekday().hour()
        #expect(weekDayHourStyle.format(date..<date + hour) == "Mon, 12 – 1 AM")
        #expect(weekDayHourStyle.format(date..<date + day) == "Mon 1, 12 AM – Tue 2, 12 AM")
        #expect(weekDayHourStyle.format(date..<date + day * 32) == "Mon, 1/1, 12 AM – Fri, 2/2, 12 AM")
    }
    
    @Test func testStyleWithCustomFields() throws {
        let dateHourStyle = Date.IntervalFormatStyle(date: .numeric, locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour()
        #expect(dateHourStyle.format(date..<date + hour) == "1/1/2001, 12 – 1 AM")
        #expect(dateHourStyle.format(date..<date + day) == "1/1/2001, 12 AM – 1/2/2001, 12 AM")
        #expect(dateHourStyle.format(date..<date + day * 32) == "1/1/2001, 12 AM – 2/2/2001, 12 AM")
        
        let timeMonthDayStyle = Date.IntervalFormatStyle(time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone).month(.defaultDigits).day()
        #expect(timeMonthDayStyle.format(date..<date + hour) == "1/1, 12:00 – 1:00 AM")
        #expect(timeMonthDayStyle.format(date..<date + day) == "1/1, 12:00 AM – 1/2, 12:00 AM")
        #expect(timeMonthDayStyle.format(date..<date + day * 32) == "1/1, 12:00 AM – 2/2, 12:00 AM")
        let noAMPMStyle = Date.IntervalFormatStyle(date: .numeric, time: .shortened, locale: enUSLocale, calendar: calendar, timeZone: timeZone).hour(.defaultDigits(amPM: .omitted))
        #expect(noAMPMStyle.format(date..<date + hour) == "1/1/2001, 12:00 – 1:00")
        #expect(noAMPMStyle.format(date..<date + day) == "1/1/2001, 12:00 – 1/2/2001, 12:00")
        #expect(noAMPMStyle.format(date..<date + day * 32) == "1/1/2001, 12:00 – 2/2/2001, 12:00")
    }
    
#if FIXED_ICU_74_DAYPERIOD
    @Test func testForcedHourCycle() {
        
        let default12 = enUSLocale
        let default12force24 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(force24Hour: true))
        let default12force12 = Locale.localeAsIfCurrent(name: "en_US", overrides: .init(force12Hour: true))
        let default24 = Locale(identifier: "en_GB")
        let default24force24 = Locale.localeAsIfCurrent(name: "en_GB", overrides: .init(force24Hour: true))
        let default24force12 = Locale.localeAsIfCurrent(name: "en_GB", overrides: .init(force12Hour: true))
        
        let range = (date..<date + hour)
        let afternoon = (Date(timeIntervalSince1970: 13 * 3600)..<Date(timeIntervalSince1970: 15 * 3600))
        func verify(date: Date.IntervalFormatStyle.DateStyle? = nil, time: Date.IntervalFormatStyle.TimeStyle, locale: Locale, expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let style = Date.IntervalFormatStyle(date: date, time: time, locale: locale, calendar: calendar, timeZone: timeZone)
            #expect(style.format(range) == expected, sourceLocation: sourceLocation)
        }
        verify(time: .shortened, locale: default12,        expected: "12:00 – 1:00 AM")
        verify(time: .shortened, locale: default12force24, expected: "00:00 – 01:00")
        verify(time: .shortened, locale: default12force12, expected: "12:00 – 1:00 AM")
        verify(time: .shortened, locale: default24,        expected: "00:00 – 01:00")
        verify(time: .shortened, locale: default24force24, expected: "00:00 – 01:00")
        verify(time: .shortened, locale: default24force12, expected: "12:00 – 1:00 AM")
        
        verify(time: .complete, locale: default12,        expected: "12:00:00 AM GMT – 1:00:00 AM GMT")
        verify(time: .complete, locale: default12force24, expected: "00:00:00 GMT – 01:00:00 GMT")
        verify(time: .complete, locale: default12force12, expected: "12:00:00 AM GMT – 1:00:00 AM GMT")
        verify(time: .complete, locale: default24,        expected: "00:00:00 GMT – 01:00:00 GMT")
        verify(time: .complete, locale: default24force24, expected: "00:00:00 GMT – 01:00:00 GMT")
        verify(time: .complete, locale: default24force12, expected: "12:00:00 AM GMT – 1:00:00 AM GMT")
        
        verify(date: .numeric, time: .standard, locale: default12,        expected: "1/1/2001, 12:00:00 AM – 1:00:00 AM")
        verify(date: .numeric, time: .standard, locale: default12force24, expected: "1/1/2001, 00:00:00 – 01:00:00")
        verify(date: .numeric, time: .standard, locale: default12force12, expected: "1/1/2001, 12:00:00 AM – 1:00:00 AM")
        verify(date: .numeric, time: .standard, locale: default24,        expected: "01/01/2001, 00:00:00 – 01:00:00")
        verify(date: .numeric, time: .standard, locale: default24force24, expected: "01/01/2001, 00:00:00 – 01:00:00")
        verify(date: .numeric, time: .standard, locale: default24force12, expected: "01/01/2001, 12:00:00 AM – 1:00:00 AM")

        func verify(_ tests: (locale: Locale, expected: String, expectedAfternoon: String)..., sourceLocation: SourceLocation = #_sourceLocation, customStyle: (Date.IntervalFormatStyle) -> (Date.IntervalFormatStyle)) {
            
            let style = customStyle(Date.IntervalFormatStyle(locale: enUSLocale, calendar: calendar, timeZone: timeZone))
            for (i, (locale, expected, expectedAfternoon)) in tests.enumerated() {
                let localizedStyle = style.locale(locale)
                var loc = sourceLocation
                loc.line += i
                #expect(localizedStyle.format(range) == expected, sourceLocation: loc)
                #expect(localizedStyle.format(afternoon) == expectedAfternoon, sourceLocation: loc)
            }
        }
        verify((default12,        "12:00 – 1:00 AM", "1:00 – 3:00 PM"),
               (default12force24, "00:00 – 01:00", "13:00 – 15:00")) { style in
            style.hour().minute()
        }

        verify((default24,        "00:00 – 01:00",   "13:00 – 15:00"),
               (default24force12, "12:00 – 1:00 AM", "1:00 – 3:00 PM")) { style in
            style.hour().minute()
        }
        
#if FIXED_96909465
        // ICU does not yet support two-digit hour configuration
        verify((default12,        "12:00 – 1:00 AM",    "01:00 – 03:00 PM"),
               (default12force24, "00:00 – 01:00",      "13:00 – 15:00"),
               (default24,        "00:00 – 01:00",      "13:00 – 15:00"),
               (default24force12, "12:00 – 1:00 AM",    "01:00 – 03:00 PM")) { style in
            style.hour(.twoDigits(amPM: .abbreviated)).minute()
        }
#endif
        
        verify((default12,        "12:00 – 1:00", "1:00 – 3:00"),
               (default12force24, "00:00 – 01:00", "13:00 – 15:00")) { style in
            style.hour(.twoDigits(amPM: .omitted)).minute()
        }
        
        verify((default24,        "00:00 – 01:00", "13:00 – 15:00")) { style in
            style.hour(.twoDigits(amPM: .omitted)).minute()
        }
        
#if FIXED_97447020
        verify() { style in
            style.hour(.twoDigits(amPM: .omitted)).minute()
        }
#endif
        
        verify((default12,        "Jan 1, 12:00 – 1:00 AM", "Jan 1, 1:00 – 3:00 PM"),
               (default12force24, "Jan 1, 00:00 – 01:00", "Jan 1, 13:00 – 15:00"),
               (default24,        "1 Jan, 00:00 – 01:00", "1 Jan, 13:00 – 15:00"),
               (default24force12, "1 Jan, 12:00 – 1:00 AM", "1 Jan, 1:00 – 3:00 PM")) { style in
            style.month().day().hour().minute()
        }
    }
#endif // FIXED_ICU_74_DAYPERIOD
}

extension CurrentLocaleTimeZoneCalendarDependentTests {
    struct DateIntervalFormatStyleTests {
        @Test func testAutoupdatingCurrentChangesFormatResults() {
            let locale = Locale.autoupdatingCurrent
            let range = Date.now..<(Date.now + 3600)
            
            // Get a formatted result from es-ES
            var prefs = LocalePreferences()
            prefs.languages = ["es-ES"]
            prefs.locale = "es_ES"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedSpanish = range.formatted(.interval.locale(locale))
            
            // Get a formatted result from en-US
            prefs.languages = ["en-US"]
            prefs.locale = "en_US"
            LocaleCache.cache.resetCurrent(to: prefs)
            let formattedEnglish = range.formatted(.interval.locale(locale))
            
            // Reset to current preferences before any possibility of failing this test
            LocaleCache.cache.reset()
            
            // No matter what 'current' was before this test was run, formattedSpanish and formattedEnglish should be different.
            #expect(formattedSpanish != formattedEnglish)
        }
        
        @Test func testLeadingDotSyntax() {
            let range = (Date(timeIntervalSinceReferenceDate: 0) ..< Date(timeIntervalSinceReferenceDate: 0) + (60 * 60))
            #expect(range.formatted() == Date.IntervalFormatStyle().format(range))
            #expect(range.formatted(date: .numeric, time: .shortened) == Date.IntervalFormatStyle(date: .numeric, time: .shortened).format(range))
            #expect(range.formatted(.interval.day().month().year()) == Date.IntervalFormatStyle().day().month().year().format(range))
        }
    }
}
