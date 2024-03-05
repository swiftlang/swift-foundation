//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {
    public func ISO8601Format(_ style: ISO8601FormatStyle = .init()) -> String {
        return style.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date {

    /// Options for generating and parsing string representations of dates following the ISO 8601 standard.
    public struct ISO8601FormatStyle : Sendable {
        public enum TimeZoneSeparator : String, Codable, Sendable {
            case colon = ":"
            case omitted = ""
        }

        public enum DateSeparator : String, Codable, Sendable {
            case dash = "-"
            case omitted = ""
        }

        public enum TimeSeparator : String, Codable, Sendable {
            case colon = ":"
            case omitted = ""
        }

        public enum DateTimeSeparator : String, Codable, Sendable {
            case space = " "
            case standard = "'T'"
        }

        // `package` visibility so Date+ISO8601FormatStyleParsing.swift can see this
        package struct Fields : Codable, Hashable, OptionSet {
            package var rawValue: UInt
            package init(rawValue: UInt) {
                self.rawValue = rawValue
            }
            
            package static var year: Self { Self(rawValue: 1 << 0) }
            package static var month: Self { Self(rawValue: 1 << 1) }
            package static var weekOfYear: Self { Self(rawValue: 1 << 2) }
            package static var day: Self { Self(rawValue: 1 << 3) }
            package static var time: Self { Self(rawValue: 1 << 4) }
            package static var timeZone: Self { Self(rawValue: 1 << 5) }
            
            package init(from decoder: any Decoder) throws {
                let c = try decoder.singleValueContainer()
                rawValue = try c.decode(UInt.self)
            }
            
            package func encode(to encoder: any Encoder) throws {
                var c = encoder.singleValueContainer()
                try c.encode(rawValue)
            }
        }

        public private(set) var timeSeparator: TimeSeparator
        public private(set) var includingFractionalSeconds: Bool
        public private(set) var timeZoneSeparator: TimeZoneSeparator
        public private(set) var dateSeparator: DateSeparator
        public private(set) var dateTimeSeparator: DateTimeSeparator
        private var _formatFields: Fields = []
        
        /// This is a cache of the Gregorian Calendar, updated if the time zone changes.
        /// In the future we can eliminate this by moving the calculations for the gregorian calendar into static functions there.
        private var _calendar: _CalendarGregorian
        
        mutating func insertFormatFields(_ fields: Fields) {
            _formatFields.insert(fields)
        }

        // `package` visibility so Date+ISO8601FormatStyleParsing.swift can see this
        package var formatFields: Fields {
            if _formatFields.isEmpty {
                return [ .year, .month, .day, .time, .timeZone]
            } else {
                return _formatFields
            }
        }
        
        enum CodingKeys : String, CodingKey {
            case timeZoneSeparator
            case timeZone
            case fields
            case dateTimeSeparator
            case includingFractionalSeconds
            case dateSeparator
            case timeSeparator
        }
        
        // Encoding
        
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            timeZoneSeparator = try c.decode(TimeZoneSeparator.self, forKey: .timeZoneSeparator)
            timeZone = try c.decode(TimeZone.self, forKey: .timeZone)
            _formatFields = try c.decode(Fields.self, forKey: .fields)
            dateTimeSeparator = try c.decode(DateTimeSeparator.self, forKey: .dateTimeSeparator)
            includingFractionalSeconds = try c.decode(Bool.self, forKey: .includingFractionalSeconds)
            dateSeparator = try c.decode(DateSeparator.self, forKey: .dateSeparator)
            timeSeparator = try c.decode(TimeSeparator.self, forKey: .timeSeparator)
            
            _calendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: Locale.unlocalized, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        }
        
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(timeZoneSeparator, forKey: .timeZoneSeparator)
            try c.encode(timeZone, forKey: .timeZone)
            try c.encode(_formatFields, forKey: .fields)
            try c.encode(dateTimeSeparator, forKey: .dateTimeSeparator)
            try c.encode(includingFractionalSeconds, forKey: .includingFractionalSeconds)
            try c.encode(dateSeparator, forKey: .dateSeparator)
            try c.encode(timeSeparator, forKey: .timeSeparator)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(timeZoneSeparator)
            hasher.combine(timeZone)
            hasher.combine(_formatFields)
            hasher.combine(dateTimeSeparator)
            hasher.combine(includingFractionalSeconds)
            hasher.combine(dateSeparator)
            hasher.combine(timeSeparator)
        }
        
        public static func ==(lhs: ISO8601FormatStyle, rhs: ISO8601FormatStyle) -> Bool {
            lhs.timeZoneSeparator == rhs.timeZoneSeparator &&
            lhs.timeZone == rhs.timeZone &&
            lhs._formatFields == rhs._formatFields &&
            lhs.dateTimeSeparator == rhs.dateTimeSeparator &&
            lhs.includingFractionalSeconds == rhs.includingFractionalSeconds &&
            lhs.dateSeparator == rhs.dateSeparator &&
            lhs.timeSeparator == rhs.timeSeparator
        }
        
        /// The time zone to use to create and parse date representations.
        public var timeZone: TimeZone = TimeZone(secondsFromGMT: 0)! {
            didSet {
                // Locale.unlocalized is `en_001`, which is equivalent to `en_US_POSIX` for our needs.
                _calendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: Locale.unlocalized, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
            }
        }

        // MARK: -

        @_disfavoredOverload
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeZone = timeZone
            self.timeSeparator = .colon
            self.timeZoneSeparator = .omitted
            self.includingFractionalSeconds = false
            
            _calendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: Locale.unlocalized, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        }

        // The default is the format of RFC 3339 with no fractional seconds: "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        public init(dateSeparator: DateSeparator = .dash, dateTimeSeparator: DateTimeSeparator = .standard, timeSeparator: TimeSeparator = .colon, timeZoneSeparator: TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeZone = timeZone
            self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator
            self.includingFractionalSeconds = includingFractionalSeconds
            
            _calendar = _CalendarGregorian(identifier: .gregorian, timeZone: timeZone, locale: Locale.unlocalized, firstWeekday: 2, minimumDaysInFirstWeek: 4, gregorianStartDate: nil)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle {
    public func year() -> Self {
        var new = self
        new.insertFormatFields(.year)
        return new
    }

    public func weekOfYear() -> Self {
        var new = self
        new.insertFormatFields(.weekOfYear)
        return new
    }

    public func month() -> Self {
        var new = self
        new.insertFormatFields(.month)
        return new
    }

    public func day() -> Self {
        var new = self
        new.insertFormatFields(.day)
        return new
    }

    public func time(includingFractionalSeconds: Bool) -> Self {
        var new = self
        new.insertFormatFields(.time)
        new.includingFractionalSeconds = includingFractionalSeconds
        return new
    }

    public func timeZone(separator: TimeZoneSeparator) -> Self {
        var new = self
        new.insertFormatFields(.timeZone)
        new.timeZoneSeparator = separator
        return new
    }

    public func dateSeparator(_ separator: DateSeparator) -> Self {
        var new = self
        new.dateSeparator = separator
        return new
    }

    public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self {
        var new = self
        new.dateTimeSeparator = separator
        return new
    }

    public func timeSeparator(_ separator: TimeSeparator) -> Self {
        var new = self
        new.timeSeparator = separator
        return new
    }

    public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self {
        var new = self
        new.timeZoneSeparator = separator
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : FormatStyle {

    public func format(_ value: Date) -> String {
        var whichComponents = Calendar.ComponentSet()
        let fields = formatFields

        // If we use week of year, don't bother with year
        if fields.contains(.year) && !fields.contains(.weekOfYear) {
            whichComponents.insert(.era)
            whichComponents.insert(.year)
        }

        if fields.contains(.month) {
            whichComponents.insert(.month)
        }

        if fields.contains(.weekOfYear) {
            whichComponents.insert([.weekOfYear, .yearForWeekOfYear])
        }

        if fields.contains(.day) {
            if fields.contains(.weekOfYear) {
                whichComponents.insert(.weekday)
            } else if fields.contains(.month) {
                whichComponents.insert(.day)
            } else {
                whichComponents.insert(.dayOfYear)
            }
        }

        if fields.contains(.time) {
            whichComponents.insert([.hour, .minute, .second])
            if includingFractionalSeconds {
                whichComponents.insert(.nanosecond)
            }
        }

        let secondsFromGMT: Int?
        let components = _calendar.dateComponents(whichComponents, from: value)
        if fields.contains(.timeZone) {
            secondsFromGMT = timeZone.secondsFromGMT(for: value)
        } else {
            secondsFromGMT = nil
        }
        return format(components, appendingTimeZoneOffset: secondsFromGMT)
    }

    func format(_ components: DateComponents, appendingTimeZoneOffset timeZoneOffset: Int?) -> String {
        var needSeparator = false
        let capacity = 128 // It is believed no ISO8601 date can exceed this size
        let result = withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity + 1) { _buffer in
            var buffer = OutputBuffer(initializing: _buffer.baseAddress!, capacity: _buffer.count)
            
            let asciiZero = CChar(48)
            
            func append(_ i: Int, zeroPad: Int, buffer: inout OutputBuffer<CChar>) {
                if i < 10 {
                    if zeroPad - 1 > 0 {
                        for _ in 0..<zeroPad-1 { buffer.appendElement(asciiZero) }
                    }
                    buffer.appendElement(asciiZero + CChar(i))
                } else if i < 100 {
                    if zeroPad - 2 > 0 {
                        for _ in 0..<zeroPad-2 { buffer.appendElement(asciiZero) }
                    }
                    let (tens, ones) = i.quotientAndRemainder(dividingBy: 10)
                    buffer.appendElement(asciiZero + CChar(tens))
                    buffer.appendElement(asciiZero + CChar(ones))
                } else if i < 1000 {
                    if zeroPad - 3 > 0 {
                        for _ in 0..<zeroPad-3 { buffer.appendElement(asciiZero) }
                    }
                    let (hundreds, remainder) = i.quotientAndRemainder(dividingBy: 100)
                    let (tens, ones) = remainder.quotientAndRemainder(dividingBy: 10)
                    buffer.appendElement(asciiZero + CChar(hundreds))
                    buffer.appendElement(asciiZero + CChar(tens))
                    buffer.appendElement(asciiZero + CChar(ones))
                } else if i < 10000 {
                    if zeroPad - 4 > 0 {
                        for _ in 0..<zeroPad-4 { buffer.appendElement(asciiZero) }
                    }
                    let (thousands, remainder) = i.quotientAndRemainder(dividingBy: 1000)
                    let (hundreds, remainder2) = remainder.quotientAndRemainder(dividingBy: 100)
                    let (tens, ones) = remainder2.quotientAndRemainder(dividingBy: 10)
                    buffer.appendElement(asciiZero + CChar(thousands))
                    buffer.appendElement(asciiZero + CChar(hundreds))
                    buffer.appendElement(asciiZero + CChar(tens))
                    buffer.appendElement(asciiZero + CChar(ones))
                } else {
                    // Special case - we don't do zero padding
                    var desc = i.numericStringRepresentation
                    desc.withUTF8 {
                        $0.withMemoryRebound(to: CChar.self) { buf in
                            buffer.append(fromContentsOf: buf)
                        }
                    }
                }
            }
            
            let asciiColon = CChar(58)
            let asciiDash = CChar(45)
            let asciiSpace = CChar(32)
            let asciiPeriod = CChar(46)
            let asciiTimeSeparator = CChar(84)
            let asciiWeekOfYearSeparator = CChar(87)
            let asciiZulu = CChar(90)
            let asciiPlus = CChar(43)
            let asciiMinus = CChar(45) // Same as dash, renamed for clarity
            let asciiNull = CChar(0)
            
            if formatFields.contains(.year) {
                if formatFields.contains(.weekOfYear), let y = components.yearForWeekOfYear {
                    append(y, zeroPad: 4, buffer: &buffer)
                } else {
                    var y = components.year!
                    if let era = components.era, era == 0 {
                        y = 1 - y
                    }
                    if y < 0 {
                        buffer.appendElement(asciiMinus)
                        y = -y
                    }
                    append(y, zeroPad: 4, buffer: &buffer)
                }

                needSeparator = true
            }
            
            if formatFields.contains(.month) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                let m = components.month!
                append(m, zeroPad: 2, buffer: &buffer)
                needSeparator = true
            }
            
            if formatFields.contains(.weekOfYear) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                let woy = components.weekOfYear!
                buffer.appendElement(asciiWeekOfYearSeparator)
                append(woy, zeroPad: 2, buffer: &buffer)
                needSeparator = true
            }

            if formatFields.contains(.day) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                
                if formatFields.contains(.weekOfYear) {
                    var weekday = components.weekday!
                    // Weekday is always less than 10. Our weekdays are offset by 1.
                    if weekday >= 10 {
                        weekday = 10
                    }
                    append(weekday - 1, zeroPad: 2, buffer: &buffer)
                } else if formatFields.contains(.month) {
                    let day = components.day!
                    append(day, zeroPad: 2, buffer: &buffer)
                } else {
                    let dayOfYear = components.dayOfYear!
                    append(dayOfYear, zeroPad: 3, buffer: &buffer)
                }
                
                needSeparator = true
            }
            
            if formatFields.contains(.time) {
                if needSeparator {
                    switch dateTimeSeparator {
                    case .space: buffer.appendElement(asciiSpace)
                    case .standard: buffer.appendElement(asciiTimeSeparator)
                    }
                }
                
                let h = components.hour!
                let m = components.minute!
                let s = components.second!

                switch timeSeparator {
                case .colon:
                    append(h, zeroPad: 2, buffer: &buffer)
                    buffer.appendElement(asciiColon)
                    append(m, zeroPad: 2, buffer: &buffer)
                    buffer.appendElement(asciiColon)
                    append(s, zeroPad: 2, buffer: &buffer)
                case .omitted:
                    append(h, zeroPad: 2, buffer: &buffer)
                    append(m, zeroPad: 2, buffer: &buffer)
                    append(s, zeroPad: 2, buffer: &buffer)
                }
                
                if includingFractionalSeconds {
                    let ns = components.nanosecond!
                    let ms = Int((Double(ns) / 1_000_000.0).rounded(.towardZero))
                    buffer.appendElement(asciiPeriod)
                    append(ms, zeroPad: 3, buffer: &buffer)
                }
                
                needSeparator = true
            }

            if formatFields.contains(.timeZone) {
                // A time zone name, not the same as the abbreviated name from TimeZone. e.g., that one includes a `:`.
                var secondsFromGMT: Int
                if let timeZoneOffset, (-18 * 3600 < timeZoneOffset && timeZoneOffset < 18 * 3600)  {
                    secondsFromGMT = timeZoneOffset
                } else {
                    secondsFromGMT = 0
                }

                if secondsFromGMT == 0 {
                    buffer.appendElement(asciiZulu)
                } else {
                    let (hour, minuteAndSecond) = abs(secondsFromGMT).quotientAndRemainder(dividingBy: 3600)
                    let (minute, second) = minuteAndSecond.quotientAndRemainder(dividingBy: 60)
                    
                    if secondsFromGMT < 0 {
                        buffer.appendElement(asciiMinus)
                    } else {
                        buffer.appendElement(asciiPlus)
                    }
                    append(hour, zeroPad: 2, buffer: &buffer)
                    if timeZoneSeparator == .colon {
                        buffer.appendElement(asciiColon)
                    }
                    append(minute, zeroPad: 2, buffer: &buffer)
                    if second != 0 {
                        if timeZoneSeparator == .colon {
                            buffer.appendElement(asciiColon)
                        }
                        append(second, zeroPad: 2, buffer: &buffer)
                    }
                }
            }
            
            // Null-terminate
            buffer.appendElement(asciiNull)
            
            // Make a string
            let initialized = buffer.relinquishBorrowedMemory()
            return String(validatingUTF8: initialized.baseAddress!)!
        }
        
        return result
    }
}

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self {
        return Date.ISO8601FormatStyle()
    }
}
