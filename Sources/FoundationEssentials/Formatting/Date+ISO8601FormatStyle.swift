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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle {
    private struct ComponentsParseResult {
        var consumed: Int
        var components: DateComponents
    }
    
    private func components(from inputString: String, in view: borrowing BufferView<UInt8>) throws -> ComponentsParseResult {
        let fields = formatFields
        
        let asciiDash : UInt8 = 45 // -
        let asciiW : UInt8 = 87 // W
        let asciiT : UInt8 = 84 // T
        let asciiZero : UInt8 = 48 // 0
        let asciiNine : UInt8 = 57 // 9
        let asciiSpace : UInt8 = 32 // space
        let asciiColon : UInt8 = 58 // :
        let asciiPeriod : UInt8 = 46 // .
        let asciiMinus : UInt8 = 45 // same as -
        let asciiPlus : UInt8 = 43 // +
        
        func isDigit(_ x: UInt8) -> Bool {
            x >= asciiZero && x <= asciiNine
        }
                    
        func expectCharacter(_ expected: UInt8, _ i: inout BufferView<UInt8>.Iterator) throws {
            guard let parsed = i.next(), parsed == expected else {
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }
        }
        
        func expectOneOrMoreCharacters(_ expected: UInt8, _ i: inout BufferView<UInt8>.Iterator) throws {
            guard let parsed = i.next(), parsed == expected else {
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }
            
            while let parsed = i.peek(), parsed == expected {
                i.advance()
            }
        }
        
        func expectZeroOrMoreCharacters(_ expected: UInt8, _ i: inout BufferView<UInt8>.Iterator) {
            while let parsed = i.peek(), parsed == expected {
                i.advance()
            }
        }
                
        func digits(maxDigits: Int? = nil, nanoseconds: Bool = false, _ i: inout BufferView<UInt8>.Iterator) throws -> Int {
            // Consume all leading zeros, parse until we no longer see a digit
            var result = 0
            var count = 0
            // Cap at 10 digits max to avoid overflow
            let max = min(maxDigits ?? 10, 10)
            while let next = i.peek(), isDigit(next) {
                let digit = Int(next - asciiZero)
                result *= 10
                result += digit
                i.advance()
                count += 1
                if count >= max { break }
            }
            
            guard count > 0 else {
                // No digits actually found
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }
            
            if nanoseconds {
                // Keeps us in the land of integers
                if count == 1 { return result * 100_000_000 }
                if count == 2 { return result * 10_000_000 }
                if count == 3 { return result * 1_000_000 }
                if count == 4 { return result * 100_000 }
                if count == 5 { return result * 10_000 }
                if count == 6 { return result * 1_000 }
                if count == 7 { return result * 100 }
                if count == 8 { return result * 10 }
                if count == 9 { return result }
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }

            return result
        }
        
        var it = view.makeIterator()
        var needsSeparator = false
        var dc = DateComponents()
        if fields.contains(.year) {
            let max = dateSeparator == .omitted ? 4 : nil
            let value = try digits(maxDigits: max, &it)
            if fields.contains(.weekOfYear) {
                dc.yearForWeekOfYear = value
            } else {
                dc.year = value
            }
            
            needsSeparator = true
        } else {
            // Support for deprecated formats with missing values
            dc.year = 1970
        }
        
        if fields.contains(.month) {
            if needsSeparator && dateSeparator == .dash {
                try expectCharacter(asciiDash, &it)
            }
            
            // parse month digits
            let max = dateSeparator == .omitted ? 2 : nil
            let value = try digits(maxDigits: max, &it)
            guard _calendar.maximumRange(of: .month)!.contains(value) else {
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }
            dc.month = value

            needsSeparator = true
        } else if fields.contains(.weekOfYear) {
            if needsSeparator && dateSeparator == .dash {
                try expectCharacter(asciiDash, &it)
            }
            // parse W
            try expectCharacter(asciiW, &it)

            // parse week of year digits
            let max = dateSeparator == .omitted ? 2 : nil
            let value = try digits(maxDigits: max, &it)
            guard _calendar.maximumRange(of: .weekOfYear)!.contains(value) else {
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }
            dc.weekOfYear = value
            
            needsSeparator = true
        } else {
            // Support for deprecated formats with missing values
            dc.month = 1
        }
        
        if fields.contains(.day) {
            if needsSeparator && dateSeparator == .dash {
                try expectCharacter(asciiDash, &it)
            }
            
            if fields.contains(.weekOfYear) {
                // parse day of week ('ee')
                // ISO8601 "1" is Monday. For our date components, 2 is Monday. Add 1 to account for difference.
                let max = dateSeparator == .omitted ? 2 : nil
                let value = (try digits(maxDigits: max, &it) % 7) + 1
                
                guard _calendar.maximumRange(of: .weekday)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: self.format(Date.now))
                }
                dc.weekday = value
                
            } else if fields.contains(.month) {
                // parse day of month ('dd')
                let max = dateSeparator == .omitted ? 2 : nil
                let value = try digits(maxDigits: max, &it)
                guard _calendar.maximumRange(of: .day)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: self.format(Date.now))
                }

                dc.day = value
                
            } else {
                // parse 3 digit day of year ('DDD')
                let max = dateSeparator == .omitted ? 3 : nil
                let value = try digits(maxDigits: max, &it)
                guard _calendar.maximumRange(of: .dayOfYear)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: self.format(Date.now))
                }

                dc.dayOfYear = value
            }
            
            needsSeparator = true
        }
        
        if fields.contains(.time) {
            if needsSeparator {
                switch dateTimeSeparator {
                case .standard:
                    // parse T
                    try expectCharacter(asciiT, &it)
                case .space:
                    // parse any number of spaces
                    try expectOneOrMoreCharacters(asciiSpace, &it)
                }
            }
            
            switch timeSeparator {
            case .colon:
                dc.hour = try digits(&it)
                try expectCharacter(asciiColon, &it)
                dc.minute = try digits(&it)
                try expectCharacter(asciiColon, &it)
                dc.second = try digits(&it)
            case .omitted:
                dc.hour = try digits(maxDigits: 2, &it)
                dc.minute = try digits(maxDigits: 2, &it)
                dc.second = try digits(maxDigits: 2, &it)
            }
            
            if includingFractionalSeconds {
                try expectCharacter(asciiPeriod, &it)
                
                let fractionalSeconds = try digits(nanoseconds: true, &it)
                dc.nanosecond = fractionalSeconds
            }
            
            needsSeparator = true
        }
        
        if fields.contains(.timeZone) {
            // For compatibility with ICU implementation, if the dateTimeSeparator is a space, consume any number (including zero) of spaces here.
            if dateTimeSeparator == .space {
                expectZeroOrMoreCharacters(asciiSpace, &it)
            }
            
            guard let plusOrMinusOrZ = it.next() else {
                // Expected time zone
                throw parseError(inputString, exampleFormattedString: self.format(Date.now))
            }

            let tz: TimeZone

            if plusOrMinusOrZ == UInt8(ascii: "Z") || plusOrMinusOrZ == UInt8(ascii: "z") {
                tz = .gmt
            } else {
                var tzOffset = 0
                let positive: Bool
                var skipDigits = false
                
                // Allow GMT, or UTC
                if (plusOrMinusOrZ == UInt8(ascii: "G") || plusOrMinusOrZ == UInt8(ascii: "g")),
                    let m = it.next(), (m == UInt8(ascii: "M") || m == UInt8(ascii: "m")),
                    let t = it.next(), (t == UInt8(ascii: "T") || t == UInt8(ascii: "t")) {
                    // Allow GMT followed by + or -, or end of string, or other
                    if let next = it.peek(), (next == asciiPlus || next == asciiMinus) {
                        if next == asciiPlus { positive = true }
                        else { positive = false }
                        it.advance()
                    } else {
                        positive = true
                        tzOffset = 0
                        skipDigits = true
                    }
                } else if (plusOrMinusOrZ == UInt8(ascii: "U") || plusOrMinusOrZ == UInt8(ascii: "u")),
                          let t = it.next(), (t == UInt8(ascii: "T") || t == UInt8(ascii: "t")),
                          let c = it.next(), (c == UInt8(ascii: "C") || c == UInt8(ascii: "c")) {
                    // Allow UTC followed by + or -, or end of string, or other
                    if let next = it.peek(), (next == asciiPlus || next == asciiMinus) {
                        if next == asciiPlus { positive = true }
                        else { positive = false }
                        it.advance()
                    } else {
                        positive = true
                        tzOffset = 0
                        skipDigits = true
                    }
                } else if plusOrMinusOrZ == asciiPlus {
                    positive = true
                } else if plusOrMinusOrZ == asciiMinus {
                    positive = false
                } else {
                    // Expected time zone, found garbage
                    throw parseError(inputString, exampleFormattedString: self.format(Date.now))
                }
    
                if !skipDigits {
                    // Theoretically we would disallow or require the presence of a `:` here. However, the original implementation of this style with ICU accidentally allowed either the presence or absence of the `:` to be parsed regardless of the setting. We preserve that behavior now.

                    // parse Time Zone: ISO8601 extended hms?, with Z
                    // examples: -08:00, -07:52:58, Z
                    let hours = try digits(maxDigits: 2, &it)
                    
                    // Expect a colon, or not
                    if let maybeColon = it.peek(), maybeColon == asciiColon {
                        // Throw it away
                        it.advance()
                    }
                    
                    let minutes = try digits(maxDigits: 2, &it)
                    
                    if let maybeColon = it.peek(), maybeColon == asciiColon {
                        // Throw it away
                        it.advance()
                    }

                    if let secondsTens = it.peek(), isDigit(secondsTens) {
                        // We have seconds
                        let seconds = try digits(maxDigits: 2, &it)
                        tzOffset = (hours * 3600) + (minutes * 60) + seconds
                    } else {
                        // If the next character is missing, that's allowed - the time can be something like just -0852 and then the string can end
                        tzOffset = (hours * 3600) + (minutes * 60)
                    }
                }
                
                if tzOffset == 0 {
                    tz = .gmt
                } else {
                    guard let parsedTimeZone = TimeZone(secondsFromGMT: positive ? tzOffset : -tzOffset) else {
                        // Out of range time zone
                        throw parseError(inputString, exampleFormattedString: self.format(Date.now))
                    }
                    
                    tz = parsedTimeZone
                }
            }
            
            dc.timeZone = tz
        }
        
        // Would be nice to see this functionality on BufferView, but for now we calculate it ourselves.
        let utf8CharactersRead = it.curPointer - view.startIndex._rawValue
        return ComponentsParseResult(consumed: utf8CharactersRead, components: dc)
    }
}

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self {
        return Date.ISO8601FormatStyle()
    }
}

// MARK: - Parsing

// MARK: `FormatStyle` protocol membership

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseableFormatStyle where Self == Date.ISO8601FormatStyle {
    static var iso8601: Self { .init() }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ParseStrategy where Self == Date.ISO8601FormatStyle {
    @_disfavoredOverload
    static var iso8601: Self { .init() }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> Date {
        guard let (_, date) = parse(value, in: value.startIndex..<value.endIndex) else {
            throw parseError(value, exampleFormattedString: self.format(Date.now))
        }
        return date
    }
    
    package func parse(_ value: String, in range: Range<String.Index>) -> (String.Index, Date)? {
        var v = value[range]
        guard !v.isEmpty else {
            return nil
        }
        
        let result = v.withUTF8 { buffer -> (Int, Date)? in
            let view = BufferView(unsafeBufferPointer: buffer)!

            guard let comps = try? components(from: value, in: view) else {
                return nil
            }
            
            if let tz = comps.components.timeZone {
                guard let date = try? _calendar.date(from: comps.components, inTimeZone: tz) else {
                    return nil
                }
                                
                return (comps.consumed, date)
            } else {
                // Use the default time zone of the calendar. Neither date(from:inTimeZone:) nor date(from:) honor the time zone value set in the DateComponents instance.
                // rdar://122918762 (CalendarGregorian's date(from: components) does not honor the DateComponents time zone)
                guard let date = _calendar.date(from: comps.components) else {
                    return nil
                }
                
                return (comps.consumed, date)
            }
        }
        
        guard let result else {
            return nil
        }
        
        let endIndex = value.utf8.index(v.startIndex, offsetBy: result.0)
        return (endIndex, result.1)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.ISO8601FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self {
        return self
    }
}

// MARK: - Regex

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Date.ISO8601FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // It's important to return nil from parse in case of a failure, not throw. That allows things like the firstMatch regex to work.
        return self.parse(input, in: index..<bounds.upperBound)
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension RegexComponent where Self == Date.ISO8601FormatStyle {
    /// Creates a regex component to match an ISO 8601 date and time, such as "2015-11-14'T'15:05:03'Z'", and capture the string as a `Date` using the time zone as specified in the string.
    @_disfavoredOverload
    public static var iso8601: Date.ISO8601FormatStyle {
        return Date.ISO8601FormatStyle()
    }

    /// Creates a regex component to match an ISO 8601 date and time string, including time zone, and capture the string as a `Date` using the time zone as specified in the string.
    /// - Parameters:
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    ///   - timeZoneSeparator: The separator between time parts in the time zone.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string, including time zone.
    public static func iso8601WithTimeZone(includingFractionalSeconds: Bool = false, dateSeparator: Self.DateSeparator = .dash, dateTimeSeparator: Self.DateTimeSeparator = .standard, timeSeparator: Self.TimeSeparator = .colon, timeZoneSeparator: Self.TimeZoneSeparator = .omitted) -> Self {
        return Date.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeSeparator: timeSeparator, timeZoneSeparator: timeZoneSeparator, includingFractionalSeconds: includingFractionalSeconds)
    }

    /// Creates a regex component to match an ISO 8601 date and time string without time zone, and capture the string as a `Date` using the specified `timeZone`. If the string contains time zone designators, matches up until the start of time zone designators.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `Date` with.
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string.
    public static func iso8601(timeZone: TimeZone, includingFractionalSeconds: Bool = false, dateSeparator: Self.DateSeparator = .dash, dateTimeSeparator: Self.DateTimeSeparator = .standard, timeSeparator: Self.TimeSeparator = .colon) -> Self {
        return Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day().time(includingFractionalSeconds: includingFractionalSeconds).timeSeparator(timeSeparator).dateSeparator(dateSeparator).dateTimeSeparator(dateTimeSeparator)
    }

    /// Creates a regex component to match an ISO 8601 date string, such as "2015-11-14", and capture the string as a `Date`. The captured `Date` would be at midnight in the specified `timeZone`.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `Date` with.
    ///   - dateSeparator: The separator between date components.
    /// - Returns:  A `RegexComponent` to match an ISO 8601 date string, including time zone.
    public static func iso8601Date(timeZone: TimeZone, dateSeparator: Self.DateSeparator = .dash) -> Self {
        return Date.ISO8601FormatStyle(dateSeparator: dateSeparator, timeZone: timeZone).year().month().day()
    }
}
