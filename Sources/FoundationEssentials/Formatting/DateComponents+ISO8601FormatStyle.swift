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

@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Options for generating and parsing string representations of dates following the ISO 8601 standard.
    public struct ISO8601FormatStyle : Sendable, Codable {
        public internal(set) var timeSeparator: Date.ISO8601FormatStyle.TimeSeparator
        /// If set, fractional seconds will be present in formatted output. Fractional seconds may be present in parsing regardless of the setting of this property.
        public internal(set) var includingFractionalSeconds: Bool
        public internal(set) var timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator
        public internal(set) var dateSeparator: Date.ISO8601FormatStyle.DateSeparator
        public internal(set) var dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator
        
        internal struct Fields : Codable, Hashable, OptionSet {
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
        
        private var _formatFields: Fields = []
        // Used from Date.ISO8601FormatStyle's format
        internal var formatFields: Fields {
            if _formatFields.isEmpty {
                return [ .year, .month, .day, .time, .timeZone]
            } else {
                return _formatFields
            }
        }

        /// This is a cache of the Gregorian Calendar, updated if the time zone changes.
        /// In the future we can eliminate this by moving the calculations for the gregorian calendar into static functions there.
        internal private(set) var _calendar: Calendar
        
        private mutating func insertFormatFields(_ fields: Fields) {
            _formatFields.insert(fields)
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
            timeZoneSeparator = try c.decode(Date.ISO8601FormatStyle.TimeZoneSeparator.self, forKey: .timeZoneSeparator)
            timeZone = try c.decode(TimeZone.self, forKey: .timeZone)
            _formatFields = try c.decode(Fields.self, forKey: .fields)
            dateTimeSeparator = try c.decode(Date.ISO8601FormatStyle.DateTimeSeparator.self, forKey: .dateTimeSeparator)
            includingFractionalSeconds = try c.decode(Bool.self, forKey: .includingFractionalSeconds)
            dateSeparator = try c.decode(Date.ISO8601FormatStyle.DateSeparator.self, forKey: .dateSeparator)
            timeSeparator = try c.decode(Date.ISO8601FormatStyle.TimeSeparator.self, forKey: .timeSeparator)
            
            _calendar = Calendar(identifier: .iso8601)
            _calendar.timeZone = timeZone
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
                _calendar = Calendar(identifier: .iso8601)
                _calendar.timeZone = timeZone
            }
        }

        // MARK: -

        // The default is the format of RFC 3339 with no fractional seconds: "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        public init(dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon, timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator = .omitted, includingFractionalSeconds: Bool = false, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeZone = timeZone
            self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator
            self.includingFractionalSeconds = includingFractionalSeconds
            _calendar = Calendar(identifier: .iso8601)
            _calendar.timeZone = timeZone
        }
    }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle {
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

    public func timeZone(separator: Date.ISO8601FormatStyle.TimeZoneSeparator) -> Self {
        var new = self
        new.insertFormatFields(.timeZone)
        new.timeZoneSeparator = separator
        return new
    }

    public func dateSeparator(_ separator: Date.ISO8601FormatStyle.DateSeparator) -> Self {
        var new = self
        new.dateSeparator = separator
        return new
    }

    public func dateTimeSeparator(_ separator: Date.ISO8601FormatStyle.DateTimeSeparator) -> Self {
        var new = self
        new.dateTimeSeparator = separator
        return new
    }

    public func timeSeparator(_ separator: Date.ISO8601FormatStyle.TimeSeparator) -> Self {
        var new = self
        new.timeSeparator = separator
        return new
    }

    public func timeZoneSeparator(_ separator: Date.ISO8601FormatStyle.TimeZoneSeparator) -> Self {
        var new = self
        new.timeZoneSeparator = separator
        return new
    }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : FormatStyle {

    public func format(_ value: DateComponents) -> String {
        let secondsFromGMT: Int?
        if formatFields.contains(.timeZone) {
            // We need a concrete point in time to determine the offset from GMT, because the offset depends on time of year due to daylight saving changes.
            // For the some time zones, there is no change, so we can skip the calculation.
            if let fixed = timeZone.fixedOffsetFromGMT {
                secondsFromGMT = fixed
            } else if let calculatedDate = _calendar.date(from: value) {
                secondsFromGMT = timeZone.secondsFromGMT(for: calculatedDate)
            } else {
                secondsFromGMT = nil
            }
        } else {
            secondsFromGMT = nil
        }
        return format(value, appendingTimeZoneOffset: secondsFromGMT)
    }

    // Default values for missing fields:
    //  year: 1970
    //  month: 1
    //  day: 1
    //  weekOfYear: 1
    //  weekday: 1
    //  dayOfYear: 1
    //  hour: 0
    //  minute: 0
    //  second: 0
    //  nanosecond: 0
    internal func format(_ components: DateComponents, appendingTimeZoneOffset timeZoneOffset: Int?) -> String {
        var needSeparator = false
        let capacity = 128 // It is believed no ISO8601 date can exceed this size
        let result = withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity + 1) { _buffer in
            var buffer = OutputBuffer(initializing: _buffer.baseAddress!, capacity: _buffer.count)
            
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
                    buffer.append(y, zeroPad: 4)
                } else {
                    var y = components.year ?? 1970
                    if let era = components.era, era == 0 {
                        y = 1 - y
                    }
                    if y < 0 {
                        buffer.appendElement(asciiMinus)
                        y = -y
                    }
                    buffer.append(y, zeroPad: 4)
                }

                needSeparator = true
            }
            
            if formatFields.contains(.month) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                let m = components.month ?? 1
                buffer.append(m, zeroPad: 2)
                needSeparator = true
            }
            
            if formatFields.contains(.weekOfYear) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                let woy = components.weekOfYear ?? 1
                buffer.appendElement(asciiWeekOfYearSeparator)
                buffer.append(woy, zeroPad: 2)
                needSeparator = true
            }

            if formatFields.contains(.day) {
                if needSeparator && dateSeparator == .dash {
                    buffer.appendElement(asciiDash)
                }
                
                if formatFields.contains(.weekOfYear) {
                    var weekday = components.weekday ?? 1
                    // Weekday is always less than 10. Our weekdays are offset by 1.
                    if weekday >= 10 {
                        weekday = 10
                    }
                    buffer.append(weekday - 1, zeroPad: 2)
                } else if formatFields.contains(.month) {
                    let day = components.day ?? 1
                    buffer.append(day, zeroPad: 2)
                } else {
                    let dayOfYear = components.dayOfYear ?? 1
                    buffer.append(dayOfYear, zeroPad: 3)
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
                
                let h = components.hour ?? 0
                let m = components.minute ?? 0
                let s = components.second ?? 0

                switch timeSeparator {
                case .colon:
                    buffer.append(h, zeroPad: 2)
                    buffer.appendElement(asciiColon)
                    buffer.append(m, zeroPad: 2)
                    buffer.appendElement(asciiColon)
                    buffer.append(s, zeroPad: 2)
                case .omitted:
                    buffer.append(h, zeroPad: 2)
                    buffer.append(m, zeroPad: 2)
                    buffer.append(s, zeroPad: 2)
                }
                
                if includingFractionalSeconds {
                    let ns = components.nanosecond ?? 0
                    let ms = Int((Double(ns) / 1_000_000.0).rounded(.towardZero))
                    buffer.appendElement(asciiPeriod)
                    buffer.append(ms, zeroPad: 3)
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
                    buffer.append(hour, zeroPad: 2)
                    if timeZoneSeparator == .colon {
                        buffer.appendElement(asciiColon)
                    }
                    buffer.append(minute, zeroPad: 2)
                    if second != 0 {
                        if timeZoneSeparator == .colon {
                            buffer.appendElement(asciiColon)
                        }
                        buffer.append(second, zeroPad: 2)
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

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle {
    private struct ComponentsParseResult {
        var consumed: Int
        var components: DateComponents
    }
    
    private func components(from inputString: String, fillMissingUnits: Bool, defaultTimeZone: TimeZone, in view: borrowing BufferView<UInt8>) throws -> ComponentsParseResult {
        let fields = formatFields
        
        var it = view.makeIterator()
        var needsSeparator = false
        
        // Keep these fields local and set them in the DateComponents once for improved performance
        var yearForWeekOfYear: Int?
        var year: Int?
        var month: Int?
        var weekOfYear: Int?
        var weekday: Int?
        var day: Int?
        var dayOfYear: Int?
        var hour: Int?
        var minute: Int?
        var second: Int?
        var nanosecond: Int?
        var timeZone = defaultTimeZone

        if fields.contains(.year) {
            let max = dateSeparator == .omitted ? 4 : nil
            let value = try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            if fields.contains(.weekOfYear) {
                yearForWeekOfYear = value
            } else {
                year = value
            }
            
            needsSeparator = true
        } else if fillMissingUnits {
            // Support for deprecated formats with missing values
            year = 1970
        }
        
        if fields.contains(.month) {
            if needsSeparator && dateSeparator == .dash {
                try it.expectCharacter(UInt8(ascii: "-"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            
            // parse month digits
            let max = dateSeparator == .omitted ? 2 : nil
            let value = try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            guard _calendar.maximumRange(of: .month)!.contains(value) else {
                throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            month = value

            needsSeparator = true
        } else if fields.contains(.weekOfYear) {
            if needsSeparator && dateSeparator == .dash {
                try it.expectCharacter(UInt8(ascii: "-"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            // parse W
            try it.expectCharacter(UInt8(ascii: "W"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))

            // parse week of year digits
            let max = dateSeparator == .omitted ? 2 : nil
            let value = try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            guard _calendar.maximumRange(of: .weekOfYear)!.contains(value) else {
                throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            weekOfYear = value
            
            needsSeparator = true
        } else if fillMissingUnits {
            // Support for deprecated formats with missing values
            month = 1
        }
        
        if fields.contains(.day) {
            if needsSeparator && dateSeparator == .dash {
                try it.expectCharacter(UInt8(ascii: "-"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            
            if fields.contains(.weekOfYear) {
                // parse day of week ('ee')
                // ISO8601 "1" is Monday. For our date components, 2 is Monday. Add 1 to account for difference.
                let max = dateSeparator == .omitted ? 2 : nil
                let value = (try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now)) % 7) + 1
                
                guard _calendar.maximumRange(of: .weekday)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
                }
                weekday = value
                
            } else if fields.contains(.month) {
                // parse day of month ('dd')
                let max = dateSeparator == .omitted ? 2 : nil
                let value = try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                guard _calendar.maximumRange(of: .day)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
                }

                day = value
                
            } else {
                // parse 3 digit day of year ('DDD')
                let max = dateSeparator == .omitted ? 3 : nil
                let value = try it.digits(maxDigits: max, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                guard _calendar.maximumRange(of: .dayOfYear)!.contains(value) else {
                    throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
                }

                dayOfYear = value
            }
            
            needsSeparator = true
        }
        
        if fields.contains(.time) {
            if needsSeparator {
                switch dateTimeSeparator {
                case .standard:
                    // parse T
                    try it.expectCharacter(UInt8(ascii: "T"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                case .space:
                    // parse any number of spaces
                    try it.expectOneOrMoreCharacters(UInt8(ascii: " "), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                }
            }
            
            switch timeSeparator {
            case .colon:
                hour = try it.digits(input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                try it.expectCharacter(UInt8(ascii: ":"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                minute = try it.digits(input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                try it.expectCharacter(UInt8(ascii: ":"), input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                second = try it.digits(input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            case .omitted:
                hour = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                minute = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                second = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
            }
            
            // When parsing, fractional seconds are always optional (as of Swift 6.2).
            // Peek ahead and see if the next character is a period or not. If not, just continue on.
            if let next = it.peek(), next == UInt8(ascii: ".") {
                // Looks like a fractional seconds
                let _ = it.next() // consume the period
                let fractionalSeconds = try it.digits(nanoseconds: true, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                nanosecond = fractionalSeconds
            }
            
            needsSeparator = true
        }
        
        if fields.contains(.timeZone) {
            // For compatibility with ICU implementation, if the dateTimeSeparator is a space, consume any number (including zero) of spaces here.
            if dateTimeSeparator == .space {
                it.expectZeroOrMoreCharacters(UInt8(ascii: " "))
            }
            
            guard let plusOrMinusOrZ = it.next() else {
                // Expected time zone
                throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
            }


            if plusOrMinusOrZ == UInt8(ascii: "Z") || plusOrMinusOrZ == UInt8(ascii: "z") {
                timeZone = .gmt
            } else {
                var tzOffset = 0
                let positive: Bool
                var skipDigits = false
                
                // Allow GMT, or UTC
                if (plusOrMinusOrZ == UInt8(ascii: "G") || plusOrMinusOrZ == UInt8(ascii: "g")),
                    let m = it.next(), (m == UInt8(ascii: "M") || m == UInt8(ascii: "m")),
                    let t = it.next(), (t == UInt8(ascii: "T") || t == UInt8(ascii: "t")) {
                    // Allow GMT followed by + or -, or end of string, or other
                    if let next = it.peek(), (next == UInt8(ascii: "+") || next == UInt8(ascii: "-")) {
                        if next == UInt8(ascii: "+") { positive = true }
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
                    if let next = it.peek(), (next == UInt8(ascii: "+") || next == UInt8(ascii: "-")) {
                        if next == UInt8(ascii: "+") { positive = true }
                        else { positive = false }
                        it.advance()
                    } else {
                        positive = true
                        tzOffset = 0
                        skipDigits = true
                    }
                } else if plusOrMinusOrZ == UInt8(ascii: "+") {
                    positive = true
                } else if plusOrMinusOrZ == UInt8(ascii: "-") {
                    positive = false
                } else {
                    // Expected time zone, found garbage
                    throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
                }
    
                if !skipDigits {
                    // The parser is tolerant to the presence or absence of the `:` in the time zone, as well as the presence or absence of minutes.

                    // parse Time Zone: ISO8601 extended hms?, with Z
                    // examples: -08:00, -07:52:58, Z
                    let hours = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                    
                    // Expect a colon, or a minutes value, or the end.
                    let expectMinutes: Bool
                    if let next = it.peek() {
                        if next == UInt8(ascii: ":") {
                            // Throw it away
                            it.advance()
                            
                            // But we should have minutes after this
                            expectMinutes = true
                        } else if isASCIIDigit(next) {
                            // This should be minutes
                            expectMinutes = true
                        } else {
                            // Not a :, not a digit - end of the string
                            expectMinutes = false
                        }
                    } else {
                        expectMinutes = false
                    }
                    
                    if !expectMinutes {
                        // We reached the end of the string
                        tzOffset = hours * 3600
                    } else {
                        // Continue on
                        let minutes = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                        
                        if let maybeColon = it.peek(), maybeColon == UInt8(ascii: ":") {
                            // Throw it away
                            it.advance()
                        }

                        if let secondsTens = it.peek(), isASCIIDigit(secondsTens) {
                            // We have seconds
                            let seconds = try it.digits(maxDigits: 2, input: inputString, onFailure: Date.ISO8601FormatStyle(self).format(Date.now))
                            tzOffset = (hours * 3600) + (minutes * 60) + seconds
                        } else {
                            // If the next character is missing, that's allowed - the time can be something like just -0852 and then the string can end
                            tzOffset = (hours * 3600) + (minutes * 60)
                        }
                    }
                }
                
                if tzOffset == 0 {
                    timeZone = .gmt
                } else {
                    guard let parsedTimeZone = TimeZone(secondsFromGMT: positive ? tzOffset : -tzOffset) else {
                        // Out of range time zone
                        throw parseError(inputString, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
                    }
                    
                    timeZone = parsedTimeZone
                }
            }
        }
        
        // Use the internal init which does not attempt to check each value for Int.max
        let dc = DateComponents(calendar: Calendar(identifier: .iso8601),
                                timeZone: timeZone,
                                rawEra: nil,
                                rawYear: year,
                                rawMonth: month,
                                rawDay: day,
                                rawHour: hour,
                                rawMinute: minute,
                                rawSecond: second,
                                rawNanosecond: nanosecond,
                                rawWeekday: weekday,
                                rawWeekdayOrdinal: nil,
                                rawQuarter: nil,
                                rawWeekOfMonth: nil,
                                rawWeekOfYear: weekOfYear,
                                rawYearForWeekOfYear: yearForWeekOfYear,
                                rawDayOfYear: dayOfYear)

        // Would be nice to see this functionality on BufferView, but for now we calculate it ourselves.
        let utf8CharactersRead = it.curPointer - view.startIndex._rawValue
        return ComponentsParseResult(consumed: utf8CharactersRead, components: dc)
    }
}

// MARK: `FormatStyle` protocol membership

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == DateComponents.ISO8601FormatStyle {
    static var iso8601: Self {
        return DateComponents.ISO8601FormatStyle()
    }
}

// MARK: - Parsing

// MARK: `FormatStyle` protocol membership

@available(FoundationPreview 6.2, *)
public extension ParseableFormatStyle where Self == DateComponents.ISO8601FormatStyle {
    static var iso8601: Self { .init() }
}

@available(FoundationPreview 6.2, *)
public extension ParseStrategy where Self == DateComponents.ISO8601FormatStyle {
    @_disfavoredOverload
    static var iso8601: Self { .init() }
}


@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : ParseStrategy {
    public func parse(_ value: String) throws -> DateComponents {
        guard let (_, components) = parse(value, fillMissingUnits: false, in: value.startIndex..<value.endIndex) else {
            throw parseError(value, exampleFormattedString: Date.ISO8601FormatStyle(self).format(Date.now))
        }
        return components
    }
    
    internal func parse(_ value: String, fillMissingUnits: Bool, in range: Range<String.Index>) -> (String.Index, DateComponents)? {
        var v = value[range]
        guard !v.isEmpty else {
            return nil
        }
        
        let result = v.withUTF8 { buffer -> (Int, DateComponents)? in
            let view = BufferView(unsafeBufferPointer: buffer)!

            guard let comps = try? components(from: value, fillMissingUnits: fillMissingUnits, defaultTimeZone: timeZone, in: view) else {
                return nil
            }
            
            return (comps.consumed, comps.components)
        }
        
        guard let result else {
            return nil
        }
        
        let endIndex = value.utf8.index(v.startIndex, offsetBy: result.0)
        return (endIndex, result.1)
    }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle: ParseableFormatStyle {
    public var parseStrategy: Self {
        return self
    }
}

// MARK: - Regex

@available(FoundationPreview 6.2, *)
extension DateComponents.ISO8601FormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = DateComponents
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: DateComponents)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // It's important to return nil from parse in case of a failure, not throw. That allows things like the firstMatch regex to work.
        return self.parse(input, fillMissingUnits: false, in: index..<bounds.upperBound)
    }
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == DateComponents.ISO8601FormatStyle {
    /// Creates a regex component to match an ISO 8601 date and time, such as "2015-11-14'T'15:05:03'Z'", and capture the string as a `DateComponents` using the time zone as specified in the string.
    @_disfavoredOverload
    public static var iso8601Components: DateComponents.ISO8601FormatStyle {
        return DateComponents.ISO8601FormatStyle()
    }

    /// Creates a regex component to match an ISO 8601 date and time string, including time zone, and capture the string as a `DateComponents` using the time zone as specified in the string.
    /// - Parameters:
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    ///   - timeZoneSeparator: The separator between time parts in the time zone.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string, including time zone.
    public static func iso8601ComponentsWithTimeZone(includingFractionalSeconds: Bool = false, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon, timeZoneSeparator: Date.ISO8601FormatStyle.TimeZoneSeparator = .omitted) -> Self {
        return DateComponents.ISO8601FormatStyle(dateSeparator: dateSeparator, dateTimeSeparator: dateTimeSeparator, timeSeparator: timeSeparator, timeZoneSeparator: timeZoneSeparator, includingFractionalSeconds: includingFractionalSeconds)
    }

    /// Creates a regex component to match an ISO 8601 date and time string without time zone, and capture the string as a `DateComponents` using the specified `timeZone`. If the string contains time zone designators, matches up until the start of time zone designators.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `DateComponents` with.
    ///   - includingFractionalSeconds: Specifies if the string contains fractional seconds.
    ///   - dateSeparator: The separator between date components.
    ///   - dateTimeSeparator: The separator between date and time parts.
    ///   - timeSeparator: The separator between time components.
    /// - Returns: A `RegexComponent` to match an ISO 8601 string.
    public static func iso8601Components(timeZone: TimeZone, includingFractionalSeconds: Bool = false, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash, dateTimeSeparator: Date.ISO8601FormatStyle.DateTimeSeparator = .standard, timeSeparator: Date.ISO8601FormatStyle.TimeSeparator = .colon) -> Self {
        return DateComponents.ISO8601FormatStyle(timeZone: timeZone).year().month().day().time(includingFractionalSeconds: includingFractionalSeconds).timeSeparator(timeSeparator).dateSeparator(dateSeparator).dateTimeSeparator(dateTimeSeparator)
    }

    /// Creates a regex component to match an ISO 8601 date string, such as "2015-11-14", and capture the string as a `DateComponents`. The captured `DateComponents` would be at midnight in the specified `timeZone`.
    /// - Parameters:
    ///   - timeZone: The time zone to create the captured `Date` with.
    ///   - dateSeparator: The separator between date components.
    /// - Returns:  A `RegexComponent` to match an ISO 8601 date string, not any time zone that may be in the string.
    public static func iso8601DateComponents(timeZone: TimeZone, dateSeparator: Date.ISO8601FormatStyle.DateSeparator = .dash) -> Self {
        return DateComponents.ISO8601FormatStyle(dateSeparator: dateSeparator, timeZone: timeZone).year().month().day()
    }
}
