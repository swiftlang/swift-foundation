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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.FormatStyle {

    public struct Symbol : Hashable, Sendable {
        let symbolType: SymbolType

        public struct Era : Hashable, Sendable { let option: SymbolType.EraOption? }
        public struct Year : Hashable, Sendable { let option: SymbolType.YearOption? }
        public struct YearForWeekOfYear : Hashable, Sendable { let option: SymbolType.YearForWeekOfYearOption? }
        public struct CyclicYear : Hashable, Sendable { let option: SymbolType.CyclicYearOption? }
        public struct Quarter : Hashable, Sendable { let option: SymbolType.QuarterOption? }
        public struct Month : Hashable, Sendable { let option: SymbolType.MonthOption? }
        public struct Week : Hashable, Sendable { let option: SymbolType.WeekOption? }
        public struct Day : Hashable, Sendable { let option: SymbolType.DayOption? }
        public struct DayOfYear : Hashable, Sendable { let option: SymbolType.DayOfYearOption? }
        public struct Weekday : Hashable, Sendable { let option: SymbolType.WeekdayOption? }
        public struct DayPeriod : Hashable, Sendable { let option: SymbolType.DayPeriodOption? }
        public struct Hour : Hashable, Sendable { let option: SymbolType.HourOption? }
        public struct Minute : Hashable, Sendable { let option: SymbolType.MinuteOption? }
        public struct Second : Hashable, Sendable { let option: SymbolType.SecondOption? }
        public struct SecondFraction : Hashable, Sendable { let option: SymbolType.SecondFractionOption? }
        public struct TimeZone : Hashable, Sendable { let option: SymbolType.TimeZoneSymbolOption? }

        public struct StandaloneQuarter : Hashable, Sendable { let option: SymbolType.StandaloneQuarterOption }
        public struct StandaloneMonth : Hashable, Sendable { let option: SymbolType.StandaloneMonthOption }
        public struct StandaloneWeekday : Hashable, Sendable { let option: SymbolType.StandaloneWeekdayOption }
        public struct VerbatimHour : Hashable, Sendable { let option: SymbolType.VerbatimHourOption }

        static let maxPadding = 10
        enum SymbolType : Hashable {
            case era(EraOption)
            case year(YearOption)
            case yearForWeekOfYear(YearForWeekOfYearOption)
            case cyclicYear(CyclicYearOption)
            case quarter(QuarterOption)
            case standaloneQuarter(StandaloneQuarterOption)
            case month(MonthOption)
            case standaloneMonth(StandaloneMonthOption)
            case week(WeekOption)
            case day(DayOption)
            case dayOfYear(DayOfYearOption)
            case weekday(WeekdayOption)
            case standaloneWeekday(StandaloneWeekdayOption)
            case dayPeriod(DayPeriodOption)
            case hour(HourOption)
            case minute(MinuteOption)
            case second(SecondOption)
            case secondFraction(SecondFractionOption)
            case timeZone(TimeZoneSymbolOption)

            enum EraOption : String, Codable, Hashable {
                case abbreviated = "G"
                case wide = "GGGG"
                case narrow = "GGGGG"
            }

            enum YearOption : RawRepresentable, Codable, Hashable {
                case defaultDigits
                case twoDigits
                case padded(Int)
                case relatedGregorian(Int)
                case extended(Int)

                var rawValue: String {
                    let raw: String
                    switch self {
                    case .defaultDigits:
                        raw = "y"
                    case .twoDigits:
                        raw = "yy"
                    case .padded(let len):
                        raw = String(repeating: "y", count: len.clampedPadding)
                    case .relatedGregorian(let len):
                        raw = String(repeating: "r", count: len.clampedPadding)
                    case .extended(let len):
                        raw = String(repeating: "u", count: len.clampedPadding)
                    }
                    return raw
                }

                init?(rawValue: String) {
                    guard let begin = rawValue.first else {
                        return nil
                    }

                    if begin == "y" || begin == "r" || begin == "u" && rawValue.allSatisfy({ $0 == begin }) {
                        if begin == "y" {
                            if rawValue.count == 1 {
                                self = .defaultDigits
                            } else if rawValue.count == 2 {
                                self = .twoDigits
                            } else {
                                self = .padded(rawValue.count)
                            }
                        } else if begin == "r" {
                            self = .relatedGregorian(rawValue.count)
                        } else {
                            self = .extended(rawValue.count)
                        }
                    } else {
                        return nil
                    }
                }
            }

            enum YearForWeekOfYearOption : RawRepresentable, Codable, Hashable {
                case defaultDigits
                case twoDigits
                case padded(Int)

                var rawValue: String {
                    let raw: String
                    switch self {
                    case .defaultDigits:
                        raw = "Y"
                    case .twoDigits:
                        raw = "YY"
                    case .padded(let len):
                        raw = String(repeating: "Y", count: len.clampedPadding)
                    }
                    return raw
                }

                init?(rawValue: String) {
                    if rawValue.allSatisfy({ $0 == "Y" }) {
                        if rawValue.count == 1 {
                            self = .defaultDigits
                        } else if rawValue.count == 2 {
                            self = .twoDigits
                        } else {
                            self = .padded(rawValue.count)
                        }
                    } else {
                        return nil
                    }
                }
            }

            enum CyclicYearOption : String, Codable, Hashable {
                case abbreviated = "U"
                case wide = "UUUU"
                case narrow = "UUUUU"
            }

            enum QuarterOption : String, Codable, Hashable {
                case oneDigit = "Q"
                case twoDigits = "QQ"
                case abbreviated = "QQQ"
                case wide = "QQQQ"
                case narrow = "QQQQQ"
            }

            enum StandaloneQuarterOption : String, Codable, Hashable {
                case oneDigit = "q"
                case twoDigits = "qq"
                case abbreviated = "qqq"
                case wide  = "qqqq"
                case narrow = "qqqqq"
            }

            enum MonthOption : String, Codable, Hashable {
                case defaultDigits = "M"
                case twoDigits = "MM"
                case abbreviated = "MMM"
                case wide = "MMMM"
                case narrow = "MMMMM"
            }

            enum StandaloneMonthOption : String, Codable, Hashable {
                case defaultDigits = "L"
                case twoDigits = "LL"
                case abbreviated = "LLL"
                case wide = "LLLL"
                case narrow = "LLLLL"
            }

            enum WeekOption : String, Codable, Hashable {
                case defaultDigits = "w"
                case twoDigits = "ww"
                case weekOfMonth = "W"
            }

            enum DayOfYearOption : String, Codable, Hashable {
                case defaultDigits = "D"
                case twoDigits = "DD"
                case threeDigits = "DDD"
            }

            enum DayOption : RawRepresentable, Codable, Hashable {
                case defaultDigits
                case twoDigits
                case ordinalOfDayInMonth
                case julianModified(Int)

                var rawValue: String {
                    let raw: String
                    switch self {
                    case .defaultDigits:
                        raw = "d"
                    case .twoDigits:
                        raw = "dd"
                    case .ordinalOfDayInMonth:
                        raw = "F"
                    case .julianModified(let len):
                        raw = String(repeating: "g", count: len.clampedPadding)
                    }
                    return raw
                }

                init?(rawValue: String) {
                    switch rawValue {
                    case "d":
                        self = .defaultDigits
                    case "dd":
                        self = .twoDigits
                    case "F":
                        self = .ordinalOfDayInMonth
                    default:
                        if rawValue.allSatisfy({ $0 == "g" }) {
                            self = .julianModified(rawValue.count)
                        } else {
                            return nil
                        }
                    }
                }
            }

            enum WeekdayOption : String, Codable, Hashable {
                case abbreviated = "EEE"
                case wide = "EEEE"
                case narrow = "EEEEE"
                case short = "EEEEEE"
                case oneDigit = "e"
                case twoDigits = "ee"
            }

            enum StandaloneWeekdayOption : String, Codable, Hashable {
                case oneDigit = "c"
                case abbreviated = "ccc"
                case wide = "cccc"
                case narrow = "ccccc"
                case short = "cccccc"
            }

            enum DayPeriodOption : String, Codable, Hashable {
                case abbreviated = "a"
                case wide = "aaaa"
                case narrow = "aaaaa"
                case abbreviatedWith12s = "b"
                case wideWith12s = "bbbb"
                case narrowWith12s = "bbbbb"
                case conversationalAbbreviated = "B"
                case conversationalNarrow = "BBBB"
                case conversationalWide = "BBBBB"
            }

            enum HourOption : String, Codable, Hashable {
                case defaultDigitsWithAbbreviatedAMPM = "j"
                case twoDigitsWithAbbreviatedAMPM = "jj"
                case defaultDigitsWithWideAMPM = "jjj"
                case twoDigitsWithWideAMPM = "jjjj"
                case defaultDigitsWithNarrowAMPM = "jjjjj"
                case twoDigitsWithNarrowAMPM = "jjjjjj"

                case defaultDigitsNoAMPM = "J"
                case twoDigitsNoAMPM = "JJ"

                case conversationalDefaultDigitsWithAbbreviatedAMPM = "C"
                case conversationalTwoDigitsWithAbbreviatedAMPM = "CC"
                case conversationalDefaultDigitsWithWideAMPM = "CCC"
                case conversationalTwoDigitsWithWideAMPM = "CCCC"
                case conversationalDefaultDigitsWithNarrowAMPM = "CCCCC"
                case conversationalTwoDigitsWithNarrowAMPM = "CCCCCC"
            }

            enum VerbatimHourOption : String, Codable, Hashable {
                case twelveHourDefaultDigitsOneBased = "h"
                case twelveHourTwoDigitsOneBased = "hh"
                case twentyFourHourDefaultDigitsZeroBased = "H"
                case twentyFourHourTwoDigitsZeroBased = "HH"

                case twelveHourDefaultDigitsZeroBased = "K"
                case twelveHourTwoDigitsZeroBased = "KK"
                case twentyFourHourDefaultDigitsOneBased = "k"
                case twentyFourHourTwoDigitsOneBased = "kk"
            }

            enum MinuteOption : String, Codable, Hashable {
                case defaultDigits = "m"
                case twoDigits = "mm"
            }

            enum SecondOption : String, Codable, Hashable {
                case defaultDigits = "s"
                case twoDigits = "ss"
            }

            enum SecondFractionOption : RawRepresentable, Codable, Hashable {

                init?(rawValue: String) {
                    guard let first = rawValue.first else { return nil }
                    guard rawValue.allSatisfy({ $0 == first }) else { return nil }
                    switch first {
                    case "S":
                        self = .fractional(rawValue.count)
                    case "A":
                        self = .milliseconds(rawValue.count)
                    default:
                        return nil
                    }
                }

                case fractional(Int)
                case milliseconds(Int)

                public var rawValue : String {

                    let formatString : String
                    let requested : Int
                    let actual : Int
                    let maxCharacters = 9

                    switch self {
                    case .fractional(let n):
                        requested = n
                        formatString = "S"
                    case .milliseconds(let n):
                        requested = n
                        formatString = "A"
                    }

                    switch requested {
                    case 1 ... maxCharacters:
                        actual = requested
                    case maxCharacters ... Int.max:
                        actual = maxCharacters
                    default:
                        actual = 1
                    }

                    var value = ""
                    for _ in 1 ... actual {
                        value += formatString
                    }

                    return value
                }

            }

            enum TimeZoneSymbolOption : String, Codable, Hashable {
                case shortSpecificName = "z"
                case longSpecificName = "zzzz"
                case iso8601Basic = "Z"
                case longLocalizedGMT = "ZZZZ" // Equivalent to "OOOO"
                case iso8601Extended = "ZZZZZ"
                case shortLocalizedGMT = "O"
                case shortGenericName = "v"
                case longGenericName = "vvvv"
                case shortIdentifier = "V"
                case longIdentifier = "VV"
                case exemplarLocation = "VVV"
                case genericLocation = "VVVV"
            }

        }
    }
}

fileprivate extension Int {
    var clampedPadding : Int {
        if self < 1 {
            return 1
        } else if self > Date.FormatStyle.Symbol.maxPadding {
            return Date.FormatStyle.Symbol.maxPadding
        } else {
            return self
        }
    }
}


@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Era {
    /// Abbreviated Era name. For example, "AD", "Reiwa", "令和".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Wide era name. For example, "Anno Domini", "Reiwa", "令和".
    static var wide: Self { .init(option: .wide) }

    /// Narrow era name.
    /// For example, For example, "A", "R", "R".
    static var narrow: Self { .init(option: .narrow) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Year {

    /// Minimum number of digits that shows the full year.
    /// For example, `2`, `20`, `201`, `2017`, `20173`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two low-order digits.
    /// Padded or truncated if necessary. For example, `02`, `20`, `01`, `17`, `73`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Three or more digits.
    /// Padded if necessary. For example, `002`, `020`, `201`, `2017`, `20173`.
    static func padded(_ length: Int) -> Self { .init(option: .padded(length)) }

    /// Related Gregorian year.
    /// For non-Gregorian calendars, this corresponds to the extended Gregorian year in which the calendar’s year begins. Related Gregorian years are often displayed, for example, when formatting dates in the Japanese calendar — e.g. "2012(平成24)年1月15日" — or in the Chinese calendar — e.g. "2012壬辰年腊月初四".
    static func relatedGregorian(minimumLength: Int = 1) -> Self { .init(option: .relatedGregorian(minimumLength)) }

    /// Extended year.
    /// This is a single number designating the year of this calendar system, encompassing all supra-year fields. For example, for the Julian calendar system, year numbers are positive, with an era of BCE or CE. An extended year value for the Julian calendar system assigns positive values to CE years and negative values to BCE years, with 1 BCE being year 0.
    static func extended(minimumLength: Int = 1) -> Self { .init(option: .extended(minimumLength)) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.YearForWeekOfYear {

    /// Minimum number of digits that shows the full year in "Week of Year"-based calendars.
    /// For example, `2`, `20`, `201`, `2017`, `20173`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two low-order digits.  Padded or truncated if necessary.
    /// For example, `02`, `20`, `01`, `17`, `73`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Three or more digits. Padded if necessary.
    /// For example, `002`, `020`, `201`, `2017`, `20173`.
    static func padded(_ length: Int) -> Self { .init(option: .padded(length) ) }
}

/// Cyclic year symbols.
///
/// Calendars such as the Chinese lunar calendar (and related calendars) and the Hindu calendars use 60-year cycles of year names. If the calendar does not provide cyclic year name data, or if the year value to be formatted is out of the range of years for which cyclic name data is provided, then numeric formatting is used (behaves like `Year`).
///
/// Currently the data only provides abbreviated names, which will be used for all requested name widths.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.CyclicYear {

    /// Abbreviated cyclic year name.
    /// For example, "甲子".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Wide cyclic year name.
    /// For example, "甲子".
    static var wide: Self { .init(option: .wide) }

    /// Narrow cyclic year name.
    /// For example, "甲子".
    static var narrow: Self { .init(option: .narrow) }
}

/// Quarter symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Quarter {

    /// Numeric: one digit quarter. For example `2`.
    static var oneDigit: Self { .init(option: .oneDigit) }

    /// Numeric: two digits with zero padding. For example `02`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Abbreviated quarter. For example `Q2`.
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// The quarter spelled out in full, for example `2nd quarter`.
    static var wide: Self { .init(option: .wide) }

    /// Narrow quarter. For example `2`.
    static var narrow: Self { .init(option: .narrow) }
}

/// Standalone quarter symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.StandaloneQuarter {
    /// Standalone one-digit numeric quarter. For example `2`.
    static var oneDigit: Self { .init(option: .oneDigit) }

    /// Two-digit standalone numeric quarter with zero padding if necessary, for example `02`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Standalone abbreviated quarter. For example `Q2`.
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Standalone wide quarter. For example "2nd quarter".
    static var wide: Self { .init(option: .wide) }

    /// Standalone narrow quarter. For example "2".
    static var narrow: Self { .init(option: .narrow) }
}

/// Month symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Month {

    /// Minimum number of digits that shows the numeric month. Intended to be used in conjunction with `Day.defaultDigits`.
    /// For example, `9`, `12`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// 2 digits, zero pad if needed. For example, `09`, `12`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Abbreviated month name. For example, "Sep".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Wide month name. For example, "September".
    static var wide: Self { .init(option: .wide) }

    /// Narrow month name. For example, "S".
    static var narrow: Self { .init(option: .narrow) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.StandaloneMonth {
    /// Stand-alone minimum digits numeric month. Number/name (intended to be used without `Day`).
    /// For example, `9`, `12`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Stand-alone two-digit numeric month.
    /// Two digits, zero pad if needed. For example, `09`, `12`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Stand-alone abbreviated month.
    /// For example, "Sep".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Stand-alone wide month.
    /// For example, "September".
    static var wide: Self { .init(option: .wide) }

    /// Stand-alone narrow month.
    /// For example, "S".
    static var narrow: Self { .init(option: .narrow) }
}

/// Week symbols. Use with `YearForWeekOfYear` for the year field instead of `Year`.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Week {

    /// Numeric week of year. For example, `8`, `27`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two-digit numeric week of year, zero padded as necessary. For example, `08`, `27`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// One-digit numeric week of month, starting from 1. For example, `1`.
    static var weekOfMonth: Self { .init(option: .weekOfMonth) }
}

/// Day symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Day {

    /// Minimum number of digits that shows the full numeric day of month. For example, `1`, `18`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two-digit, zero-padded if necessary. For example, `01`, `18`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Ordinal of day in month.
    /// For example, the 2nd Wed in July would yield `2`.
    static var ordinalOfDayInMonth: Self { .init(option: .ordinalOfDayInMonth) }

    /// The field length specifies the minimum number of digits, with zero-padding as necessary.
    /// This is different from the conventional Julian day number in two regards. First, it demarcates days at local zone midnight, rather than noon GMT. Second, it is a local number; that is, it depends on the local time zone. It can be thought of as a single number that encompasses all the date-related fields.
    /// For example, `2451334`.
    static func julianModified(minimumLength: Int = 1) -> Self { .init(option: .julianModified(minimumLength)) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.DayOfYear {
    /// Minimum number of digits that shows the full numeric day of year. For example, `7`, `33`, `345`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two-digit day of year, with zero-padding as necessary. For example, `07`, `33`, `345`.
    static var twoDigits: Self { .init(option: .twoDigits) }

    /// Three-digit day of year, with zero-padding as necessary. For example, `007`, `033`, `345`.
    static var threeDigits: Self { .init(option: .threeDigits) }
}

/// Week day name symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Weekday {

    /// Abbreviated day of week name. For example, "Tue".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Wide day of week name. For example, "Tuesday".
    static var wide: Self { .init(option: .wide) }

    /// Narrow day of week name. For example, "T".
    static var narrow: Self { .init(option: .narrow) }

    /// Short day of week name. For example, "Tu".
    static var short: Self { .init(option: .short) }

    /// Local day of week number/name. The value depends on the local starting day of the week.
    static var oneDigit: Self { .init(option: .oneDigit) }

    /// Local day of week number/name, format style; two digits, zero-padded if necessary.
    static var twoDigits: Self { .init(option: .twoDigits) }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.StandaloneWeekday {
    /// Standalone local day of week number/name.
    static var oneDigit: Self { .init(option: .oneDigit) }

    /// Standalone local day of week number/name.
    /// For example, "Tue".
    static var abbreviated: Self { .init(option: .abbreviated) }

    /// Standalone wide local day of week number/name.
    /// For example, "Tuesday".
    static var wide: Self { .init(option: .wide) }

    /// Standalone narrow local day of week number/name.
    /// For example, "T".
    static var narrow: Self { .init(option: .narrow) }

    /// Standalone short local day of week number/name.
    /// For example, "Tu".
    static var short: Self { .init(option: .short) }
}

/// The time period (for example, "a.m." or "p.m."). May be upper or lower case depending on the locale and other options.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.DayPeriod {

    enum Width : Sendable {
        case abbreviated
        case wide
        case narrow
    }

    /// Standard day period. For example,
    /// Abbreviated: `12 am.`
    /// Wide: `12 am`
    /// Narrow: `12a`.
    static func standard(_ width: Width) -> Self {
        var option: Date.FormatStyle.Symbol.SymbolType.DayPeriodOption
        switch width {
        case .abbreviated:
            option = .abbreviated
        case .wide:
            option = .wide
        case .narrow:
            option = .narrow
        }
        return .init(option: option)
    }

    /// Day period including designations for noon and midnight. For example,
    /// Abbreviated: `mid`
    /// Wide: `midnight`
    /// Narrow: `md`.
    static func with12s(_ width: Width) -> Self {
        var option: Date.FormatStyle.Symbol.SymbolType.DayPeriodOption
        switch width {
        case .abbreviated:
            option = .abbreviatedWith12s
        case .wide:
            option = .wideWith12s
        case .narrow:
            option = .narrowWith12s
        }
        return .init(option: option)
    }

    /// Conversational day period. For example,
    /// Abbreviated: `at night`, `nachm.`, `ip.`
    /// Wide: `at night`, `nachmittags`, `iltapäivällä`.
    /// Narrow: `at night`, `nachm.`, `iltap`.
    static func conversational(_ width: Width) -> Self {
        var option: Date.FormatStyle.Symbol.SymbolType.DayPeriodOption
        switch width {
        case .abbreviated:
            option = .conversationalAbbreviated
        case .wide:
            option = .conversationalWide
        case .narrow:
            option = .conversationalNarrow
        }
        return .init(option: option)
    }
}

/// Hour symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Hour {
    struct AMPMStyle : Codable, Hashable, Sendable {
        let rawValue: UInt

        /// Hides the day period marker (AM/PM).
        /// For example, `8` (for 8 in the morning), `1` (for 1 in the afternoon) if used with `defaultDigits`.
        /// Or `08`, `01` if used with `twoDigits`.
        public static let omitted: AMPMStyle = AMPMStyle(rawValue: 0)

        /// Narrow day period if the locale prefers using day period with hour.
        /// For example, `8`, `8a`, `13`, `1p` if used with `defaultDigits`.
        /// Or `08`, `08a`, `13`, `01p` if used with `twoDigits`.
        public static let narrow: AMPMStyle = AMPMStyle(rawValue: 1)

        /// Abbreviated day period if the locale prefers using day period with hour.
        /// For example, `8`, `8 AM`, `13`, `1 PM` if used with `defaultDigits`.
        /// Or `08`, `08 AM`, `13`, `01 PM` if used with `twoDigits`.
        public static let abbreviated: AMPMStyle = AMPMStyle(rawValue: 2)

        /// Wide day period if the locale prefers using day period with hour.
        /// For example, `8`, `8 A.M.`, `13`, `1 P.M.` if used with `defaultDigits`.
        /// Or, `08`, `08 A.M.`, `13`, `01 P.M.` if used with `twoDigits`.
        public static let wide: AMPMStyle = AMPMStyle(rawValue: 3)
    }

    /// The preferred numeric hour format for the locale with minimum digits. Whether the period symbol (AM/PM) will be shown depends on the locale.
    static func defaultDigits(amPM: AMPMStyle) -> Self {
        let new : Self
        if amPM == .omitted {
            new = .init(option: .defaultDigitsNoAMPM)
        } else if amPM == .narrow {
            new = .init(option: .defaultDigitsWithNarrowAMPM)
        } else if amPM == .abbreviated {
            new = .init(option: .defaultDigitsWithAbbreviatedAMPM)
        } else if amPM == .wide {
            new = .init(option: .defaultDigitsWithWideAMPM)
        } else {
            fatalError("Specified amPM style is not supported by Hour.defaultDigits")
        }
        return new
    }

    /// The preferred two-digit hour format for the locale, zero padded if necessary. Whether the period symbol (AM/PM) will be shown depends on the locale.
    static func twoDigits(amPM: AMPMStyle) -> Self {
        let new : Self
        if amPM == .omitted {
            new = .init(option: .twoDigitsNoAMPM)
        } else if amPM == .narrow {
            new = .init(option: .twoDigitsWithNarrowAMPM)
        } else if amPM == .abbreviated {
            new = .init(option: .twoDigitsWithAbbreviatedAMPM)
        } else if amPM == .wide {
            new = .init(option: .twoDigitsWithWideAMPM)
        } else {
            fatalError("Specified amPM style is not supported by Hour.twoDigits")
        }
        return new
    }

    /// Behaves like `defaultDigits`: the preferred numeric hour format for the locale with minimum digits. May also use conversational period formats.
    static func conversationalDefaultDigits(amPM: AMPMStyle) -> Self {
        let new : Self
        if amPM == .omitted {
            new = .init(option: .defaultDigitsNoAMPM)
        } else if amPM == .narrow {
            new = .init(option: .conversationalDefaultDigitsWithNarrowAMPM)
        } else if amPM == .abbreviated {
            new = .init(option: .conversationalDefaultDigitsWithAbbreviatedAMPM)
        } else if amPM == .wide {
            new = .init(option: .conversationalDefaultDigitsWithWideAMPM)
        } else {
            fatalError("Specified amPM style is not supported by Hour.conversationalDefaultDigits")
        }
        return new
    }

    /// Behaves like `twoDigits`: two-digit hour format for the locale, zero padded if necessary. May also use conversational period formats.
    static func conversationalTwoDigits(amPM: AMPMStyle) -> Self {
        let new : Self
        if amPM == .omitted {
            new = .init(option: .twoDigitsNoAMPM)
        } else if amPM == .narrow {
            new = .init(option: .conversationalTwoDigitsWithNarrowAMPM)
        } else if amPM == .abbreviated {
            new = .init(option: .conversationalTwoDigitsWithAbbreviatedAMPM)
        } else if amPM == .wide {
            new = .init(option: .conversationalTwoDigitsWithWideAMPM)
        } else {
            fatalError("Specified amPM style is not supported by Hour.conversationalTwoDigits")
        }
        return new
    }

    @available(*, deprecated, renamed:"defaultDigits(amPM:)")
    static var defaultDigitsNoAMPM: Self { .init(option: .defaultDigitsNoAMPM) }

    @available(*, deprecated, renamed:"twoDigits(amPM:)")
    static var twoDigitsNoAMPM: Self { .init(option: .twoDigitsNoAMPM) }
}

/// Hour symbols that does not take users' preferences into account, and is displayed as-is.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.VerbatimHour {
    struct HourCycle : Codable, Hashable, Sendable {
        /// The hour ranges from 0 to 11 in a 12-hour clock. Ranges from 0 to 23 in a 24-hour clock.
        public static let zeroBased = HourCycle(rawValue: 0)

        /// The hour ranges from 1 to 12 in the 12-hour clock. Ranges from 1 to 24 in a 24-hour clock.
        public static let oneBased = HourCycle(rawValue: 1)

        let rawValue : UInt
    }

    struct Clock : Codable, Hashable, Sendable {
        /// In a 12-hour clock system, the 24-hour day is divided into two periods, a.m. and p.m, and each period consists of 12 hours.
        /// - Note: Does not include the period marker (AM/PM). Specify a `PeriodSymbol` if that's desired.
        public static let twelveHour = Clock(rawValue: 0)

        /// In a 24-hour clock system, the day runs from midnight to midnight, dividing into 24 hours.
        /// - Note: If using `twentyFourHour` together with `PeriodSymbol`, the period is ignored.
        public static let twentyFourHour = Clock(rawValue: 1)

        let rawValue : UInt
    }

    /// Minimum digits to show the numeric hour. For example, `1`, `12`.
    /// Or `23` if using the `twentyFourHour` clock.
    /// - Note: This format does not take user's locale preferences into account. Consider using `defaultDigits` if applicable.
    static func defaultDigits(clock: Clock, hourCycle: HourCycle) -> Self {
        let new : Self
        if clock == .twelveHour {
            if hourCycle == .zeroBased {
                new = .init(option: .twelveHourDefaultDigitsZeroBased)
            } else {
                new = .init(option: .twelveHourDefaultDigitsOneBased)
            }
        } else if clock == .twentyFourHour {
            if hourCycle == .zeroBased {
                new = .init(option: .twentyFourHourDefaultDigitsZeroBased)
            } else {
                new = .init(option: .twentyFourHourDefaultDigitsOneBased)
            }
        } else {
            fatalError("Specified clock or hourCycle is not supported by VerbatimHour.defaultDigits")
        }
        return new
    }

    /// Numeric two-digit hour, zero padded if necessary.
    /// For example, `01`, `12`.
    /// Or `23` if using the `twentyFourHour` clock.
    /// - Note: This format does not take user's locale preferences into account. Consider using `defaultDigits` if applicable.
    static func twoDigits(clock: Clock, hourCycle: HourCycle) -> Self {
        let new : Self
        if clock == .twelveHour {
            if hourCycle == .zeroBased {
                new = .init(option: .twelveHourTwoDigitsZeroBased)
            } else {
                new = .init(option: .twelveHourTwoDigitsOneBased)
            }
        } else if clock == .twentyFourHour {
            if hourCycle == .zeroBased {
                new = .init(option: .twentyFourHourTwoDigitsZeroBased)
            } else {
                new = .init(option: .twentyFourHourTwoDigitsOneBased)
            }
        } else {
            fatalError("Specified clock or hourCycle is not supported by VerbatimHour.twoDigits")
        }
        return new
    }
}

/// Minute symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Minute {

    /// Minimum digits to show the numeric minute. Truncated, not rounded. For example, `8`, `59`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two-digit numeric, zero padded if needed. For example, `08`, `59`.
    static var twoDigits: Self { .init(option: .twoDigits) }
}

/// Second symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.Second {

    /// Minimum digits to show the numeric second. Truncated, not rounded. For example, `8`, `12`.
    static var defaultDigits: Self { .init(option: .defaultDigits) }

    /// Two digits numeric, zero padded if needed, not rounded. For example, `08`, `12`.
    static var twoDigits: Self { .init(option: .twoDigits) }
}

/// Fractions of a second  symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.SecondFraction {

    /// Fractional second (numeric).
    /// Truncates, like other numeric time fields, but in this case to the number of digits specified by the associated `Int`.
    /// For example, specifying `4` for seconds value `12.34567` yields `12.3456`.
    static func fractional(_ val: Int) -> Self { .init(option: .fractional(val)) }

    /// Milliseconds in day (numeric).
    /// The associated `Int` specifies the minimum number of digits, with zero-padding as necessary. The maximum number of digits is 9.
    /// This field behaves exactly like a composite of all time-related fields, not including the zone fields. As such, it also reflects discontinuities of those fields on DST transition days. On a day of DST onset, it will jump forward. On a day of DST cessation, it will jump backward. This reflects the fact that is must be combined with the offset field to obtain a unique local time value.
    static func milliseconds(_ val: Int) -> Self { .init(option: .milliseconds(val)) }
}

/// Time zone symbols.
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Date.FormatStyle.Symbol.TimeZone {

    enum Width : Sendable {
        case short
        case long
    }

    /// Specific non-location format. Falls back to `shortLocalizedGMT` if unavailable. For example,
    /// short: "PDT"
    /// long: "Pacific Daylight Time".
    static func specificName(_ width: Width) -> Self {
        switch width {
        case .short:
            return .init(option: .shortSpecificName)
        case .long:
            return .init(option: .longSpecificName)
        }
    }

    /// Generic non-location format. Falls back to `genericLocation` if unavailable. For example,
    /// short: "PT". Fallback again to `localizedGMT(.short)` if `genericLocation(.short)` is unavailable.
    /// long: "Pacific Time"
    static func genericName(_ width: Width) -> Self {
        switch width {
        case .short:
            return .init(option: .shortGenericName)
        case .long:
            return .init(option: .longGenericName)
        }
    }

    /// The ISO8601 format with hours, minutes and optional seconds fields. For example,
    /// short: "-0800"
    /// long: "-08:00" or "-07:52:58".
     static func iso8601(_ width: Width) -> Self {
         switch width {
         case .short:
             return .init(option: .iso8601Basic)
         case .long:
             return .init(option: .iso8601Extended)
         }
    }

    /// Short localized GMT format. For example,
    /// short: "GMT-8"
    /// long: "GMT-8:00"
     static func localizedGMT(_ width: Width) -> Self {
         switch width {
         case .short:
             return .init(option: .shortLocalizedGMT)
         case .long:
             return .init(option: .longLocalizedGMT)
         }
     }

    /// The time zone ID. For example,
    /// short: "uslax"
    /// long: "America/Los_Angeles".
    static func identifier(_ width: Width) -> Self {
        switch width {
        case .short:
            return .init(option: .shortIdentifier)
        case .long:
            return .init(option: .longIdentifier)
        }
    }


    /// The exemplar city (location) for the time zone. The localized exemplar city name for the special zone or unknown is used as the fallback if it is unavailable.
    /// For example, "Los Angeles".
    static var exemplarLocation: Self { .init(option: .exemplarLocation) }

    /// The generic location format. Falls back to `longLocalizedGMT` if unavailable. Recommends for presenting possible time zone choices for user selection.
    /// For example, "Los Angeles Time".
    static var genericLocation: Self { .init(option: .genericLocation) }
}

// MARK: Omitted Symbol Options

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Era {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Year {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.YearForWeekOfYear {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.CyclicYear {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Quarter {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Month {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Week {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Day {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.DayOfYear {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Weekday {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.DayPeriod {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Hour {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Minute {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.Second {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.SecondFraction {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}

@available(FoundationPreview 0.4, *)
extension Date.FormatStyle.Symbol.TimeZone {
    /// The option for not including the symbol in the formatted output.
    public static let omitted: Self = .init(option: nil)
}
