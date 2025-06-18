//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == Date.HTTPFormatStyle {
    static var http: Self {
        return Date.HTTPFormatStyle()
    }
}

@available(FoundationPreview 6.2, *)
public extension ParseableFormatStyle where Self == Date.HTTPFormatStyle {
    static var http: Self { .init() }
}

@available(FoundationPreview 6.2, *)
public extension ParseStrategy where Self == Date.HTTPFormatStyle {
    @_disfavoredOverload
    static var http: Self { .init() }
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : ParseStrategy {
    public var parseStrategy: Date.HTTPFormatStyle { self }
}

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : FormatStyle {
}

@available(FoundationPreview 6.2, *)
extension Date {
    /// Options for generating and parsing string representations of dates following the HTTP date format from [RFC 9110 § 5.6.7](https://www.rfc-editor.org/rfc/rfc9110.html#http.date).
    public struct HTTPFormatStyle : Sendable, Hashable, Codable, ParseableFormatStyle {
        let componentsStyle = DateComponents.HTTPFormatStyle()

        public init() {}
        public init(from decoder: any Decoder) throws {}
        
        public func format(_ date: Date) -> String {
            // <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
            let components = Calendar(identifier: .gregorian)._dateComponents([.weekday, .day, .month, .year, .hour, .minute, .second], from: date, in: .gmt)
            return componentsStyle.format(components)
        }
                
        public func parse(_ value: String) throws -> Date {
            guard let (_, date) = parse(value, in: value.startIndex..<value.endIndex) else {
                throw parseError(value, exampleFormattedString: self.format(Date.now))
            }
            return date
        }

        fileprivate func parse(_ value: String, in range: Range<String.Index>) -> (String.Index, Date)? {
            var v = value[range]
            guard !v.isEmpty else {
                return nil
            }
            
            let result = v.withUTF8 { buffer -> (Int, Date)? in
                let view = BufferView(unsafeBufferPointer: buffer)!

                guard let comps = try? componentsStyle.components(in: view) else {
                    return nil
                }
                
                // HTTP dates are always GMT
                guard let date = Calendar(identifier: .gregorian).date(from: comps.components) else {
                    return nil
                }
                    
                return (comps.consumed, date)
            }
            
            guard let result else {
                return nil
            }
            
            let endIndex = value.utf8.index(v.startIndex, offsetBy: result.0)
            return (endIndex, result.1)
        }
    }
}

// MARK: - Regex

@available(FoundationPreview 6.2, *)
extension Date.HTTPFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = Date
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: Date)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // It's important to return nil from parse in case of a failure, not throw. That allows things like the firstMatch regex to work.
        return self.parse(input, in: index..<bounds.upperBound)
    }
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == Date.HTTPFormatStyle {
    /// Creates a regex component to match an HTTP date and time, such as "2015-11-14'T'15:05:03'Z'", and capture the string as a `Date` using the time zone as specified in the string.
    public static var http: Date.HTTPFormatStyle {
        return Date.HTTPFormatStyle()
    }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : CustomConsumingRegexComponent {
    public typealias RegexOutput = DateComponents
    public func consuming(_ input: String, startingAt index: String.Index, in bounds: Range<String.Index>) throws -> (upperBound: String.Index, output: DateComponents)? {
        guard index < bounds.upperBound else {
            return nil
        }
        // It's important to return nil from parse in case of a failure, not throw. That allows things like the firstMatch regex to work.
        return self.parse(input, in: index..<bounds.upperBound)
    }
}

@available(FoundationPreview 6.2, *)
extension RegexComponent where Self == DateComponents.HTTPFormatStyle {
    /// Creates a regex component to match an HTTP date and time, such as "2015-11-14'T'15:05:03'Z'", and capture the string as a `DateComponents` using the time zone as specified in the string.
    public static var httpComponents: DateComponents.HTTPFormatStyle {
        return DateComponents.HTTPFormatStyle()
    }
}

// MARK: - Components

@available(FoundationPreview 6.2, *)
public extension FormatStyle where Self == DateComponents.HTTPFormatStyle {
    static var http: Self {
        return DateComponents.HTTPFormatStyle()
    }
}

@available(FoundationPreview 6.2, *)
public extension ParseableFormatStyle where Self == DateComponents.HTTPFormatStyle {
    static var http: Self { .init() }
}

@available(FoundationPreview 6.2, *)
public extension ParseStrategy where Self == DateComponents.HTTPFormatStyle {
    @_disfavoredOverload
    static var http: Self { .init() }
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : FormatStyle {
}

@available(FoundationPreview 6.2, *)
extension DateComponents.HTTPFormatStyle : ParseStrategy {
    public var parseStrategy: DateComponents.HTTPFormatStyle { self }
}

@available(FoundationPreview 6.2, *)
extension DateComponents {
    /// Converts `DateComponents` into RFC 9110-compatible "HTTP date" `String`, and parses in the reverse direction.
    /// This parser does not do validation on the individual values of the components. An optional date can be created from the result using `Calendar(identifier: .gregorian).date(from: ...)`.
    /// When formatting, missing or invalid fields are filled with default values: `Sun`, `01`, `Jan`, `2000`, `00:00:00`, `GMT`. Note that missing fields may result in an invalid date or time. Other values in the `DateComponents` are ignored.
    public struct HTTPFormatStyle : Sendable, Hashable, Codable, ParseableFormatStyle {
        public init() {
        }
        
        // MARK: - Format
        
        public func format(_ components: DateComponents) -> String {
            let capacity = 32 // It is believed no HTTP date can exceed this size (max should be 26)
            return withUnsafeTemporaryAllocation(of: CChar.self, capacity: capacity + 1) { _buffer in
                var buffer = OutputBuffer(initializing: _buffer.baseAddress!, capacity: _buffer.count)
                
                switch components.weekday {
                case 2:
                    buffer.appendElement(CChar(UInt8(ascii: "M")))
                    buffer.appendElement(CChar(UInt8(ascii: "o")))
                    buffer.appendElement(CChar(UInt8(ascii: "n")))
                case 3:
                    buffer.appendElement(CChar(UInt8(ascii: "T")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                    buffer.appendElement(CChar(UInt8(ascii: "e")))
                case 4:
                    buffer.appendElement(CChar(UInt8(ascii: "W")))
                    buffer.appendElement(CChar(UInt8(ascii: "e")))
                    buffer.appendElement(CChar(UInt8(ascii: "d")))
                case 5:
                    buffer.appendElement(CChar(UInt8(ascii: "T")))
                    buffer.appendElement(CChar(UInt8(ascii: "h")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                case 6:
                    buffer.appendElement(CChar(UInt8(ascii: "F")))
                    buffer.appendElement(CChar(UInt8(ascii: "r")))
                    buffer.appendElement(CChar(UInt8(ascii: "i")))
                case 7:
                    buffer.appendElement(CChar(UInt8(ascii: "S")))
                    buffer.appendElement(CChar(UInt8(ascii: "a")))
                    buffer.appendElement(CChar(UInt8(ascii: "t")))
                case 1:
                    // Sunday, or default / missing
                    fallthrough
                default:
                    buffer.appendElement(CChar(UInt8(ascii: "S")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                    buffer.appendElement(CChar(UInt8(ascii: "n")))
                }
                
                buffer.appendElement(CChar(UInt8(ascii: ",")))
                buffer.appendElement(CChar(UInt8(ascii: " ")))
                
                let day = components.day ?? 1
                buffer.append(day, zeroPad: 2)
                buffer.appendElement(CChar(UInt8(ascii: " ")))
                
                switch components.month {
                case 2:
                    buffer.appendElement(CChar(UInt8(ascii: "F")))
                    buffer.appendElement(CChar(UInt8(ascii: "e")))
                    buffer.appendElement(CChar(UInt8(ascii: "b")))
                case 3:
                    buffer.appendElement(CChar(UInt8(ascii: "M")))
                    buffer.appendElement(CChar(UInt8(ascii: "a")))
                    buffer.appendElement(CChar(UInt8(ascii: "r")))
                case 4:
                    buffer.appendElement(CChar(UInt8(ascii: "A")))
                    buffer.appendElement(CChar(UInt8(ascii: "p")))
                    buffer.appendElement(CChar(UInt8(ascii: "r")))
                case 5:
                    buffer.appendElement(CChar(UInt8(ascii: "M")))
                    buffer.appendElement(CChar(UInt8(ascii: "a")))
                    buffer.appendElement(CChar(UInt8(ascii: "y")))
                case 6:
                    buffer.appendElement(CChar(UInt8(ascii: "J")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                    buffer.appendElement(CChar(UInt8(ascii: "n")))
                case 7:
                    buffer.appendElement(CChar(UInt8(ascii: "J")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                    buffer.appendElement(CChar(UInt8(ascii: "l")))
                case 8:
                    buffer.appendElement(CChar(UInt8(ascii: "A")))
                    buffer.appendElement(CChar(UInt8(ascii: "u")))
                    buffer.appendElement(CChar(UInt8(ascii: "g")))
                case 9:
                    buffer.appendElement(CChar(UInt8(ascii: "S")))
                    buffer.appendElement(CChar(UInt8(ascii: "e")))
                    buffer.appendElement(CChar(UInt8(ascii: "p")))
                case 10:
                    buffer.appendElement(CChar(UInt8(ascii: "O")))
                    buffer.appendElement(CChar(UInt8(ascii: "c")))
                    buffer.appendElement(CChar(UInt8(ascii: "t")))
                case 11:
                    buffer.appendElement(CChar(UInt8(ascii: "N")))
                    buffer.appendElement(CChar(UInt8(ascii: "o")))
                    buffer.appendElement(CChar(UInt8(ascii: "v")))
                case 12:
                    buffer.appendElement(CChar(UInt8(ascii: "D")))
                    buffer.appendElement(CChar(UInt8(ascii: "e")))
                    buffer.appendElement(CChar(UInt8(ascii: "c")))
                case 1:
                    // Jan or default value
                    fallthrough
                default:
                    buffer.appendElement(CChar(UInt8(ascii: "J")))
                    buffer.appendElement(CChar(UInt8(ascii: "a")))
                    buffer.appendElement(CChar(UInt8(ascii: "n")))
                }
                buffer.appendElement(CChar(UInt8(ascii: " ")))
                
                let year = components.year ?? 2000
                buffer.append(year, zeroPad: 4)
                buffer.appendElement(CChar(UInt8(ascii: " ")))
                
                let h = components.hour ?? 0
                let m = components.minute ?? 0
                let s = components.second ?? 0 
                
                buffer.append(h, zeroPad: 2)
                buffer.appendElement(CChar(UInt8(ascii: ":")))
                buffer.append(m, zeroPad: 2)
                buffer.appendElement(CChar(UInt8(ascii: ":")))
                buffer.append(s, zeroPad: 2)
                
                buffer.appendElement(CChar(UInt8(ascii: " ")))
                buffer.appendElement(CChar(UInt8(ascii: "G")))
                buffer.appendElement(CChar(UInt8(ascii: "M")))
                buffer.appendElement(CChar(UInt8(ascii: "T")))
                
                // Null-terminate
                buffer.appendElement(CChar(0))
                
                // Make a string
                let initialized = buffer.relinquishBorrowedMemory()
                return String(validatingUTF8: initialized.baseAddress!)!
            }
        }
        
        // MARK: - Parse
        
        fileprivate struct ComponentsParseResult {
            var consumed: Int
            var components: DateComponents
        }
        
        public func parse(_ value: String) throws -> DateComponents {
            guard let (_, components) = parse(value, in: value.startIndex..<value.endIndex) else {
                throw parseError(value, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now))
            }
            return components
        }

        private func parse(_ value: String, in range: Range<String.Index>) -> (String.Index, DateComponents)? {
            var v = value[range]
            guard !v.isEmpty else {
                return nil
            }
            
            let result = v.withUTF8 { buffer -> (Int, DateComponents)? in
                let view = BufferView(unsafeBufferPointer: buffer)!

                guard let comps = try? components(in: view) else {
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

        fileprivate func components(in view: borrowing BufferView<UInt8>) throws -> ComponentsParseResult {
            // https://www.rfc-editor.org/rfc/rfc9110.html#http.date
            // <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT

            // Produce an error message to throw
            func error(_ extendedDescription: String? = nil) -> CocoaError {
                parseError(view, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now), extendedDescription: extendedDescription)
            }

            var it = view.makeIterator()
            var dc = DateComponents()
            
            // Despite the spec, we allow the weekday name to be optional.
            guard let maybeWeekday1 = it.peek() else {
                throw error()
            }
            
            if isASCIIDigit(maybeWeekday1) {
                // This is the first digit of the day. Weekday is not present.
            } else {
                // Anything else must be a day-name (Mon, Tue, ... Sun)
                guard let weekday1 = it.next(), let weekday2 = it.next(), let weekday3 = it.next() else {
                    throw error()
                }

                dc.weekday = switch (weekday1, weekday2, weekday3) {
                case (UInt8(ascii: "S"), UInt8(ascii: "u"), UInt8(ascii: "n")):
                    1
                case (UInt8(ascii: "M"), UInt8(ascii: "o"), UInt8(ascii: "n")):
                    2
                case (UInt8(ascii: "T"), UInt8(ascii: "u"), UInt8(ascii: "e")):
                    3
                case (UInt8(ascii: "W"), UInt8(ascii: "e"), UInt8(ascii: "d")):
                    4
                case (UInt8(ascii: "T"), UInt8(ascii: "h"), UInt8(ascii: "u")):
                    5
                case (UInt8(ascii: "F"), UInt8(ascii: "r"), UInt8(ascii: "i")):
                    6
                case (UInt8(ascii: "S"), UInt8(ascii: "a"), UInt8(ascii: "t")):
                    7
                default:
                    throw error("Malformed weekday name")
                }
                
                // Move past , and space to weekday
                guard it.matchByte(UInt8(ascii: ",")) else {
                    throw error("Missing , after weekday")
                }
                guard it.matchByte(UInt8(ascii: " ")) else {
                    throw error("Missing space after weekday")
                }
            }

            guard let day = it.parseNumber(minDigits: 2, maxDigits: 2) else {
                throw error("Missing or malformed day")
            }
            dc.day = day

            guard it.matchByte(UInt8(ascii: " ")) else {
                throw error()
            }

            // month-name (Jan, Feb, ... Dec)
            guard let month1 = it.next(), let month2 = it.next(), let month3 = it.next() else {
                throw error("Missing month")
            }
            
            dc.month = switch (month1, month2, month3) {
            case (UInt8(ascii: "J"), UInt8(ascii: "a"), UInt8(ascii: "n")):
                1
            case (UInt8(ascii: "F"), UInt8(ascii: "e"), UInt8(ascii: "b")):
                2
            case (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "r")):
                3
            case (UInt8(ascii: "A"), UInt8(ascii: "p"), UInt8(ascii: "r")):
                4
            case (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "y")):
                5
            case (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "n")):
                6
            case (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "l")):
                7
            case (UInt8(ascii: "A"), UInt8(ascii: "u"), UInt8(ascii: "g")):
                8
            case (UInt8(ascii: "S"), UInt8(ascii: "e"), UInt8(ascii: "p")):
                9
            case (UInt8(ascii: "O"), UInt8(ascii: "c"), UInt8(ascii: "t")):
                10
            case (UInt8(ascii: "N"), UInt8(ascii: "o"), UInt8(ascii: "v")):
                11
            case (UInt8(ascii: "D"), UInt8(ascii: "e"), UInt8(ascii: "c")):
                12
            default:
                throw error("Month \(String(describing: dc.month)) is out of bounds")
            }

            guard it.matchByte(UInt8(ascii: " ")) else {
                throw error()
            }

            guard let year = it.parseNumber(minDigits: 4, maxDigits: 4) else {
                throw error()
            }
            dc.year = year

            guard it.matchByte(UInt8(ascii: " ")) else {
                throw error()
            }

            guard let hour = it.parseNumber(minDigits: 2, maxDigits: 2) else {
                throw error()
            }
            if hour < 0 || hour > 23 {
                throw error("Hour \(hour) is out of bounds")
            }
            dc.hour = hour
            
            guard it.matchByte(UInt8(ascii: ":")) else {
                throw error()
            }
            guard let minute = it.parseNumber(minDigits: 2, maxDigits: 2) else {
                throw error()
            }
            if minute < 0 || minute > 59 {
                throw error("Minute \(minute) is out of bounds")
            }
            dc.minute = minute
            
            guard it.matchByte(UInt8(ascii: ":")) else {
                throw error()
            }
            guard let second = it.parseNumber(minDigits: 2, maxDigits: 2) else {
                throw error()
            }
            // second '60' is supported in the spec for leap seconds, but Foundation does not support leap seconds. 60 is adjusted to 59.
            if second < 0 || second > 60 {
                throw error("Second \(second) is out of bounds")
            }
            // Foundation does not support leap seconds. We convert 60 seconds into 59 seconds.
            if second == 60 {
                dc.second = 59
            } else {
                dc.second = second
            }
            guard it.matchByte(UInt8(ascii: " ")) else {
                throw error()
            }

            // "GMT"
            guard it.matchByte(UInt8(ascii: "G")),
                  it.matchByte(UInt8(ascii: "M")),
                  it.matchByte(UInt8(ascii: "T"))
            else {
                throw error("Missing GMT time zone")
            }

            // Time zone is always GMT, calendar is always Gregorian
            dc.timeZone = .gmt
            dc.calendar = Calendar(identifier: .gregorian)

            // Would be nice to see this functionality on BufferView, but for now we calculate it ourselves.
            let utf8CharactersRead = it.curPointer - view.startIndex._rawValue
            
            return ComponentsParseResult(consumed: utf8CharactersRead, components: dc)
        }

    }
}

