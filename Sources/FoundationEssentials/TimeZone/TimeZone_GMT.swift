//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

package final class _TimeZoneGMT : _TimeZoneProtocol, @unchecked Sendable {
    let offset: Int
    let name: String
    
    required package init?(identifier: String) {
        fatalError("Unexpected init")
    }

    required package init?(secondsFromGMT: Int) {
        guard let name = TimeZone.nameForSecondsFromGMT(secondsFromGMT) else {
            return nil
        }

        self.name = name
        offset = secondsFromGMT
    }

    package var identifier: String {
        self.name
    }
    
    package func secondsFromGMT(for date: Date) -> Int {
        offset
    }
    
    package func abbreviation(for date: Date) -> String? {
        _TimeZoneGMT.abbreviation(for: offset)
    }
    
    package func isDaylightSavingTime(for date: Date) -> Bool {
        false
    }
    
    package func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        0.0
    }
    
    package func rawAndDaylightSavingTimeOffset(for date: Date) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        (offset, 0)
    }

    package func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        nil
    }
    
    package func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        // _TimeZoneGMTICU has localization support, if required.
        nil
    }

    package var debugDescription: String {
        "gmt offset \(offset)"
    }    
}

extension _TimeZoneGMT {
    package static func abbreviation(for offset: Int) -> String? {
        guard !(offset < -18 * 3600 || 18 * 3600 < offset) else {
            return nil
        }
        
        // Move up by half a minute so that rounding down via division gets us the right answer
        var remainder = abs(offset) + 30
        
        let hours = remainder / 3600
        remainder = remainder % 3600
        let minutes = remainder / 60
        
        if hours == 0 && minutes == 0 {
            return "GMT"
        }

        // This format discards "seconds" values
        
        var result = "GMT"
        if offset < 0 {
            result += "-"
        } else {
            result += "+"
        }
        
        if hours >= 10 {
            // Tens
            result.unicodeScalars.append(Unicode.Scalar((hours / 10) + 48)!)
        }
        
        // Ones
        result.unicodeScalars.append(Unicode.Scalar((hours % 10) + 48)!)
        guard minutes > 0 else {
            return result
        }

        // ':'
        result.unicodeScalars.append(Unicode.Scalar(58)!)

        if minutes >= 10 {
            // Tens
            result.unicodeScalars.append(Unicode.Scalar((minutes / 10) + 48)!)
        } else if minutes > 0 {
            // 0 for Tens
            result.unicodeScalars.append(Unicode.Scalar(48)!)
        }
        
        // Ones
        result.unicodeScalars.append(Unicode.Scalar((minutes % 10) + 48)!)

        return result
    }
}

extension TimeZone {
    /// A time zone name, not the same as the abbreviated name above. e.g., that one includes a `:`.
    package static func nameForSecondsFromGMT(_ seconds: Int) -> String? {
        guard !(seconds < -18 * 3600 || 18 * 3600 < seconds) else {
            return nil
        }

        // Move up by half a minute so that rounding down via division gets us the right answer
        let at = abs(seconds) + 30
        let hour = at / 3600
        let second = at % 3600
        let minute = second / 60

        if hour == 0 && minute == 0 {
            return "GMT"
        } else {
            let formattedHour = hour < 10 ? "0\(hour)" : "\(hour)"
            let formattedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
            let negative = seconds < 0
            return "GMT\(negative ? "-" : "+")\(formattedHour)\(formattedMinute)"
        }
    }

    // Returns seconds offset (positive or negative or zero) from GMT on success, nil on failure
    package static func tryParseGMTName(_ name: String) -> Int? {
        // GMT, GMT{+|-}H, GMT{+|-}HH, GMT{+|-}HHMM, GMT{+|-}{H|HH}{:|.}MM
        // UTC, UTC{+|-}H, UTC{+|-}HH, UTC{+|-}HHMM, UTC{+|-}{H|HH}{:|.}MM
        //   where "00" <= HH <= "18", "00" <= MM <= "59", and if HH==18, then MM must == 00

        let len = name.count
        guard len >= 3 && len <= 9 else {
            return nil
        }

        let isGMT = name.starts(with: "GMT")
        let isUTC = name.starts(with: "UTC")

        guard isGMT || isUTC else {
            return nil
        }

        if len == 3 {
            // GMT or UTC, exactly
            return 0
        }

        guard len >= 5 else {
            return nil
        }

        var idx = name.index(name.startIndex, offsetBy: 3)
        let plusOrMinus = name[idx]
        let positive = plusOrMinus == "+"
        let negative = plusOrMinus == "-"
        guard positive || negative else {
            return nil
        }

        let zero: UInt8 = 0x30
        let five: UInt8 = 0x35
        let nine: UInt8 = 0x39

        idx = name.index(after: idx)
        let oneHourDigit = name[idx].asciiValue ?? 0
        guard oneHourDigit >= zero && oneHourDigit <= nine else {
            return nil
        }

        let hourOne = Int(oneHourDigit - zero)

        if len == 5 {
            // GMT{+|-}H
            if negative {
                return -hourOne * 3600
            } else {
                return hourOne * 3600
            }
        }

        idx = name.index(after: idx)
        let twoHourDigitOrPunct = name[idx].asciiValue ?? 0
        let colon: UInt8 = 0x3a
        let period: UInt8 = 0x2e

        let secondHourIsTwoHourDigit = (twoHourDigitOrPunct >= zero && twoHourDigitOrPunct <= nine)
        let secondHourIsPunct = twoHourDigitOrPunct == colon || twoHourDigitOrPunct == period
        guard secondHourIsTwoHourDigit || secondHourIsPunct else {
            return nil
        }

        let hours: Int
        if secondHourIsTwoHourDigit {
            hours = 10 * hourOne + Int(twoHourDigitOrPunct - zero)
        } else { // secondHourIsPunct
            // The above advance of idx 'consumed' the punctuation
            hours = hourOne
        }

        if 18 < hours {
            return nil
        }

        if secondHourIsTwoHourDigit && len == 6 {
            // GMT{+|-}HH
            if negative {
                return -hours * 3600
            } else {
                return hours * 3600
            }
        }

        if len < 8 {
            return nil
        }

        idx = name.index(after: idx)
        let firstMinuteDigitOrPunct = name[idx].asciiValue ?? 0
        let firstMinuteIsDigit = (firstMinuteDigitOrPunct >= zero && firstMinuteDigitOrPunct <= five)
        let firstMinuteIsPunct = firstMinuteDigitOrPunct == colon || firstMinuteDigitOrPunct == period
        guard (firstMinuteIsDigit && len == 8) || (firstMinuteIsPunct && len == 9) else {
            return nil
        }

        if firstMinuteIsPunct {
            // Skip the punctuation
            idx = name.index(after: idx)
        }

        let firstMinute = name[idx].asciiValue ?? 0

        // Next character must also be a digit, no single-minutes allowed
        idx = name.index(after: idx)
        let secondMinute = name[idx].asciiValue ?? 0
        guard secondMinute >= zero && secondMinute <= nine else {
            return nil
        }

        let minutes = Int(10 * (firstMinute - zero) + (secondMinute - zero))
        if hours == 18 && minutes != 0 {
            // 18 hours requires 0 minutes
            return nil
        }

        if negative {
            return -(hours * 3600 + minutes * 60)
        } else {
            return hours * 3600 + minutes * 60
        }
    }
}
