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

                guard let comps = try? componentsStyle.components(from: value, in: view) else {
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
            return String(_capacity: capacity + 1) { buffer in
                switch components.weekday {
                case 2:
                    buffer.append(UInt8(ascii: "M"))
                    buffer.append(UInt8(ascii: "o"))
                    buffer.append(UInt8(ascii: "n"))
                case 3:
                    buffer.append(UInt8(ascii: "T"))
                    buffer.append(UInt8(ascii: "u"))
                    buffer.append(UInt8(ascii: "e"))
                case 4:
                    buffer.append(UInt8(ascii: "W"))
                    buffer.append(UInt8(ascii: "e"))
                    buffer.append(UInt8(ascii: "d"))
                case 5:
                    buffer.append(UInt8(ascii: "T"))
                    buffer.append(UInt8(ascii: "h"))
                    buffer.append(UInt8(ascii: "u"))
                case 6:
                    buffer.append(UInt8(ascii: "F"))
                    buffer.append(UInt8(ascii: "r"))
                    buffer.append(UInt8(ascii: "i"))
                case 7:
                    buffer.append(UInt8(ascii: "S"))
                    buffer.append(UInt8(ascii: "a"))
                    buffer.append(UInt8(ascii: "t"))
                case 1:
                    // Sunday, or default / missing
                    fallthrough
                default:
                    buffer.append(UInt8(ascii: "S"))
                    buffer.append(UInt8(ascii: "u"))
                    buffer.append(UInt8(ascii: "n"))
                }
                
                buffer.append(UInt8(ascii: ","))
                buffer.append(UInt8(ascii: " "))
                
                let day = components.day ?? 1
                buffer.append(day, zeroPad: 2)
                buffer.append(UInt8(ascii: " "))
                
                switch components.month {
                case 2:
                    buffer.append(UInt8(ascii: "F"))
                    buffer.append(UInt8(ascii: "e"))
                    buffer.append(UInt8(ascii: "b"))
                case 3:
                    buffer.append(UInt8(ascii: "M"))
                    buffer.append(UInt8(ascii: "a"))
                    buffer.append(UInt8(ascii: "r"))
                case 4:
                    buffer.append(UInt8(ascii: "A"))
                    buffer.append(UInt8(ascii: "p"))
                    buffer.append(UInt8(ascii: "r"))
                case 5:
                    buffer.append(UInt8(ascii: "M"))
                    buffer.append(UInt8(ascii: "a"))
                    buffer.append(UInt8(ascii: "y"))
                case 6:
                    buffer.append(UInt8(ascii: "J"))
                    buffer.append(UInt8(ascii: "u"))
                    buffer.append(UInt8(ascii: "n"))
                case 7:
                    buffer.append(UInt8(ascii: "J"))
                    buffer.append(UInt8(ascii: "u"))
                    buffer.append(UInt8(ascii: "l"))
                case 8:
                    buffer.append(UInt8(ascii: "A"))
                    buffer.append(UInt8(ascii: "u"))
                    buffer.append(UInt8(ascii: "g"))
                case 9:
                    buffer.append(UInt8(ascii: "S"))
                    buffer.append(UInt8(ascii: "e"))
                    buffer.append(UInt8(ascii: "p"))
                case 10:
                    buffer.append(UInt8(ascii: "O"))
                    buffer.append(UInt8(ascii: "c"))
                    buffer.append(UInt8(ascii: "t"))
                case 11:
                    buffer.append(UInt8(ascii: "N"))
                    buffer.append(UInt8(ascii: "o"))
                    buffer.append(UInt8(ascii: "v"))
                case 12:
                    buffer.append(UInt8(ascii: "D"))
                    buffer.append(UInt8(ascii: "e"))
                    buffer.append(UInt8(ascii: "c"))
                case 1:
                    // Jan or default value
                    fallthrough
                default:
                    buffer.append(UInt8(ascii: "J"))
                    buffer.append(UInt8(ascii: "a"))
                    buffer.append(UInt8(ascii: "n"))
                }
                buffer.append(UInt8(ascii: " "))
                
                let year = components.year ?? 2000
                buffer.append(year, zeroPad: 4)
                buffer.append(UInt8(ascii: " "))
                
                let h = components.hour ?? 0
                let m = components.minute ?? 0
                let s = components.second ?? 0 
                
                buffer.append(h, zeroPad: 2)
                buffer.append(UInt8(ascii: ":"))
                buffer.append(m, zeroPad: 2)
                buffer.append(UInt8(ascii: ":"))
                buffer.append(s, zeroPad: 2)
                
                buffer.append(UInt8(ascii: " "))
                buffer.append(UInt8(ascii: "G"))
                buffer.append(UInt8(ascii: "M"))
                buffer.append(UInt8(ascii: "T"))
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

                guard let comps = try? components(from: value, in: view) else {
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
        
        fileprivate func components(from inputString: String, in view: borrowing BufferView<UInt8>) throws -> ComponentsParseResult {
            // https://www.rfc-editor.org/rfc/rfc9110.html#http.date
            // <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT

            var it = view.makeIterator()
            var dc = DateComponents()
            
            // Despite the spec, we allow the weekday name to be optional.
            guard let maybeWeekday1 = it.peek() else {
                throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now))
            }
            
            if isASCIIDigit(maybeWeekday1) {
                // This is the first digit of the day. Weekday is not present.
            } else {
                // Anything else must be a day-name (Mon, Tue, ... Sun)
                guard let weekday1 = it.next(), let weekday2 = it.next(), let weekday3 = it.next() else {
                    throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now))
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
                    throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Malformed weekday name")
                }
                
                // Move past , and space to weekday
                try it.expectCharacter(UInt8(ascii: ","), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing , after weekday")
                try it.expectCharacter(UInt8(ascii: " "), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing space after weekday")
            }

            // The spec does not define a range for days, but it uses the gregorian calendar so we limit to 1...31
            dc.day = try it.digits(minDigits: 2, maxDigits: 2, input: inputString, range: 1..<32, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing or malformed day")
            try it.expectCharacter(UInt8(ascii: " "), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))

            // month-name (Jan, Feb, ... Dec)
            guard let month1 = it.next(), let month2 = it.next(), let month3 = it.next() else {
                throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing month")
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
                throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Month \(String(describing: dc.month)) is out of bounds")
            }

            try it.expectCharacter(UInt8(ascii: " "), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))

            dc.year = try it.digits(minDigits: 4, maxDigits: 4, input: inputString, range: nil, onFailure: Date.HTTPFormatStyle().format(Date.now))
            // From the spec: The year is any numeric year 1900 or later.
            if let y = dc.year, y < 1900 {
                throw parseError(inputString, exampleFormattedString: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Year out of range")
            }
            try it.expectCharacter(UInt8(ascii: " "), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))

            dc.hour = try it.digits(minDigits: 2, maxDigits: 2, input: inputString, range: 0..<24, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Hour is out of bounds")
            
            try it.expectCharacter(UInt8(ascii: ":"), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))
            dc.minute = try it.digits(minDigits: 2, maxDigits: 2, input: inputString, range: 0..<60, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Minute is out of bounds")
            
            try it.expectCharacter(UInt8(ascii: ":"), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))
            dc.second = try it.digits(minDigits: 2, maxDigits: 2, input: inputString, range: 0..<61, onFailure: Date.HTTPFormatStyle().format(Date.now))
            // second '60' is supported in the spec for leap seconds, but Foundation does not support leap seconds. 60 is adjusted to 59.
            if dc.second == 60 {
                dc.second = 59
            }
            try it.expectCharacter(UInt8(ascii: " "), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now))

            // "GMT"
            try it.expectCharacter(UInt8(ascii: "G"), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing GMT time zone")
            try it.expectCharacter(UInt8(ascii: "M"), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing GMT time zone")
            try it.expectCharacter(UInt8(ascii: "T"), input: inputString, onFailure: Date.HTTPFormatStyle().format(Date.now), extendedDescription: "Missing GMT time zone")

            // Time zone is always GMT, calendar is always Gregorian
            dc.timeZone = .gmt
            dc.calendar = Calendar(identifier: .gregorian)

            // Would be nice to see this functionality on BufferView, but for now we calculate it ourselves.
            let utf8CharactersRead = it.curPointer - view.startIndex._rawValue
            
            return ComponentsParseResult(consumed: utf8CharactersRead, components: dc)
        }

    }
}

