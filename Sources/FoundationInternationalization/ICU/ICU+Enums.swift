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

internal import _FoundationICU

#if os(Windows)
typealias EnumRawType = CInt
#else
typealias EnumRawType = CUnsignedInt
#endif

extension UBool {
    static let `true` = UBool(1)
    static let `false` = UBool(0)
    var boolValue: Bool {
        if self == 0 { return false }
        else { return true }
    }
}

extension UDateFormatSymbolType {
    static let eras = UDAT_ERAS
    static let months = UDAT_MONTHS
    static let shortMonths = UDAT_SHORT_MONTHS
    static let weekdays = UDAT_WEEKDAYS
    static let shortWeekdays = UDAT_SHORT_WEEKDAYS
    static let amPMs = UDAT_AM_PMS
    static let localizedCharacters = UDAT_LOCALIZED_CHARS
    static let eraNames = UDAT_ERA_NAMES
    static let narrowMonths = UDAT_NARROW_MONTHS
    static let narrowWeekdays = UDAT_NARROW_WEEKDAYS
    static let standaloneMonths = UDAT_STANDALONE_MONTHS
    static let standaloneShortMonths = UDAT_STANDALONE_SHORT_MONTHS
    static let standaloneNarrowMonths = UDAT_STANDALONE_NARROW_MONTHS
    static let standaloneWeekdays = UDAT_STANDALONE_WEEKDAYS
    static let standaloneShortWeekdays = UDAT_STANDALONE_SHORT_WEEKDAYS
    static let standaloneNarrowWeekdays = UDAT_STANDALONE_NARROW_WEEKDAYS
    static let quarters = UDAT_QUARTERS
    static let shortQuarters = UDAT_SHORT_QUARTERS
    static let standaloneQuarters = UDAT_STANDALONE_QUARTERS
    static let standaloneShortQuarters = UDAT_STANDALONE_SHORT_QUARTERS
    static let shorterWeekdays = UDAT_SHORTER_WEEKDAYS
    static let standaloneShorterWeekdays = UDAT_STANDALONE_SHORTER_WEEKDAYS
    static let cyclicYearsWide = UDAT_CYCLIC_YEARS_WIDE
    static let cyclicYearsAbbreviated = UDAT_CYCLIC_YEARS_ABBREVIATED
    static let cyclicYearsNarrow = UDAT_CYCLIC_YEARS_NARROW
    static let zodiacNamesWide = UDAT_ZODIAC_NAMES_WIDE
    static let zodiacNamesAbbreviated = UDAT_ZODIAC_NAMES_ABBREVIATED
    static let zodiacNamesNarrow = UDAT_ZODIAC_NAMES_NARROW
    static let narrowQuarters = UDAT_NARROW_QUARTERS
    static let standaloneNarrowQuarters = UDAT_STANDALONE_NARROW_QUARTERS
}

extension UDisplayContext {
    static let beginningOfSentence = UDISPCTX_CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE
    static let listItem = UDISPCTX_CAPITALIZATION_FOR_UI_LIST_OR_MENU
    static let middleOfSentence = UDISPCTX_CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE
    static let standalone = UDISPCTX_CAPITALIZATION_FOR_STANDALONE
    static let unknown = UDISPCTX_CAPITALIZATION_NONE
}

extension UNumberFormatStyle {
    static let currencyAccounting = UNUM_CURRENCY_ACCOUNTING
    static let currencyFullName = UNUM_CURRENCY_PLURAL
    static let currencyISO = UNUM_CURRENCY_ISO
    static let currencyNarrow = UNUM_CURRENCY
    static let currencyStandard = UNUM_CURRENCY_STANDARD
    static let decimal = UNUM_DECIMAL
    static let percent = UNUM_PERCENT
    static let spellout = UNUM_SPELLOUT
    static let ordinal = UNUM_ORDINAL
    static let scientific = UNUM_SCIENTIFIC
}

extension UNumberFormatAttribute {
    static let groupingUsed = UNUM_GROUPING_USED
    static let decimalAlwaysShown = UNUM_DECIMAL_ALWAYS_SHOWN
    static let maxIntegerDigits = UNUM_MAX_INTEGER_DIGITS
    static let minIntegerDigits = UNUM_MIN_INTEGER_DIGITS
    static let integerDigits = UNUM_INTEGER_DIGITS
    static let maxFractionDigits = UNUM_MAX_FRACTION_DIGITS
    static let minFractionDigits = UNUM_MIN_FRACTION_DIGITS
    static let fractionDigits = UNUM_FRACTION_DIGITS
    static let multiplier = UNUM_MULTIPLIER
    static let groupingSize = UNUM_GROUPING_SIZE
    static let roundingMode = UNUM_ROUNDING_MODE
    static let roundingIncrement = UNUM_ROUNDING_INCREMENT
    static let formatWidth = UNUM_FORMAT_WIDTH
    static let paddingPosition = UNUM_PADDING_POSITION
    static let significantDigitsUsed = UNUM_SIGNIFICANT_DIGITS_USED
    static let minSignificantDigits = UNUM_MIN_SIGNIFICANT_DIGITS
    static let maxSignificantDigits = UNUM_MAX_SIGNIFICANT_DIGITS
    static let lenientParse = UNUM_LENIENT_PARSE
    static let currencyUsage = UNUM_CURRENCY_USAGE
    static let parseNoExponent = UNUM_PARSE_NO_EXPONENT
    static let parseDecimalMarkRequired = UNUM_PARSE_DECIMAL_MARK_REQUIRED
    static let parseCaseSensitive = UNUM_PARSE_CASE_SENSITIVE
    static let signAlwaysShown = UNUM_SIGN_ALWAYS_SHOWN
}

extension UNumberFormatTextAttribute {
    static let defaultRuleSet = UNUM_DEFAULT_RULESET
    static let currencyCode = UNUM_CURRENCY_CODE
}

extension UDateRelativeDateTimeFormatterStyle {
    static let long = UDAT_STYLE_LONG
    static let short = UDAT_STYLE_SHORT
    static let narrow = UDAT_STYLE_NARROW
}

extension URelativeDateTimeUnit {
    static let year = UDAT_REL_UNIT_YEAR
    static let quarter = UDAT_REL_UNIT_QUARTER
    static let month = UDAT_REL_UNIT_MONTH
    static let week = UDAT_REL_UNIT_WEEK
    static let day = UDAT_REL_UNIT_DAY
    static let hour = UDAT_REL_UNIT_HOUR
    static let minute = UDAT_REL_UNIT_MINUTE
    static let second = UDAT_REL_UNIT_SECOND
    static let sunday = UDAT_REL_UNIT_SUNDAY
    static let monday = UDAT_REL_UNIT_MONDAY
    static let tuesday = UDAT_REL_UNIT_TUESDAY
    static let wednesday = UDAT_REL_UNIT_WEDNESDAY
    static let thursday = UDAT_REL_UNIT_THURSDAY
    static let friday = UDAT_REL_UNIT_FRIDAY
    static let saturday = UDAT_REL_UNIT_SATURDAY
}

extension UListFormatterType {
    static let and = ULISTFMT_TYPE_AND
    static let or = ULISTFMT_TYPE_OR
    static let units = ULISTFMT_TYPE_UNITS
}

extension UListFormatterWidth {
    static let wide = ULISTFMT_WIDTH_WIDE
    static let short = ULISTFMT_WIDTH_SHORT
    static let narrow = ULISTFMT_WIDTH_NARROW
}

extension UDateFormatField {
    static let era = UDAT_ERA_FIELD
    static let year = UDAT_YEAR_FIELD
    static let month = UDAT_MONTH_FIELD
    static let date = UDAT_DATE_FIELD
    static let hourOfDay1 = UDAT_HOUR_OF_DAY1_FIELD
    static let hourOfDay0 = UDAT_HOUR_OF_DAY0_FIELD
    static let minute = UDAT_MINUTE_FIELD
    static let second = UDAT_SECOND_FIELD
    static let fractionalSecond = UDAT_FRACTIONAL_SECOND_FIELD
    static let dayOfWeek = UDAT_DAY_OF_WEEK_FIELD
    static let dayOfYear = UDAT_DAY_OF_YEAR_FIELD
    static let dayOfWeekInMonth = UDAT_DAY_OF_WEEK_IN_MONTH_FIELD
    static let weekOfYear = UDAT_WEEK_OF_YEAR_FIELD
    static let weekOfMonth = UDAT_WEEK_OF_MONTH_FIELD
    static let amPm = UDAT_AM_PM_FIELD
    static let hour1 = UDAT_HOUR1_FIELD
    static let hour0 = UDAT_HOUR0_FIELD
    static let timezone = UDAT_TIMEZONE_FIELD
    static let yearWoy = UDAT_YEAR_WOY_FIELD
    static let dowLocal = UDAT_DOW_LOCAL_FIELD
    static let extendedYear = UDAT_EXTENDED_YEAR_FIELD
    static let julianDay = UDAT_JULIAN_DAY_FIELD
    static let millisecondsInDay = UDAT_MILLISECONDS_IN_DAY_FIELD
    static let timezoneRfc = UDAT_TIMEZONE_RFC_FIELD
    static let timezoneGeneric = UDAT_TIMEZONE_GENERIC_FIELD
    static let standaloneDay = UDAT_STANDALONE_DAY_FIELD
    static let standaloneMonth = UDAT_STANDALONE_MONTH_FIELD
    static let quarter = UDAT_QUARTER_FIELD
    static let standaloneQuarter = UDAT_STANDALONE_QUARTER_FIELD
    static let timezoneSpecial = UDAT_TIMEZONE_SPECIAL_FIELD
    static let yearName = UDAT_YEAR_NAME_FIELD
    static let timezoneLocalizedGmtOffset = UDAT_TIMEZONE_LOCALIZED_GMT_OFFSET_FIELD
    static let timezoneIso = UDAT_TIMEZONE_ISO_FIELD
    static let timezoneIsoLocal = UDAT_TIMEZONE_ISO_LOCAL_FIELD
    static let amPmMidnightNoon = UDAT_AM_PM_MIDNIGHT_NOON_FIELD
    static let flexibleDayPeriod = UDAT_FLEXIBLE_DAY_PERIOD_FIELD
}

extension UDateFormatField {
  internal init(_ rawValue: CInt) {
    self.init(rawValue: EnumRawType(rawValue))
  }
}

extension UCalendarAttribute {
    static let lenient = UCAL_LENIENT
    static let firstDayOfWeek = UCAL_FIRST_DAY_OF_WEEK
    static let minimalDaysInFirstWeek = UCAL_MINIMAL_DAYS_IN_FIRST_WEEK
}

extension ULocaleDataExemplarSetType {
    static let standard = ULOCDATA_ES_STANDARD
    static let auxiliary = ULOCDATA_ES_AUXILIARY
    static let index = ULOCDATA_ES_INDEX
    static let punctuation = ULOCDATA_ES_PUNCTUATION
}

extension UScriptCode {
    static let arabic = USCRIPT_ARABIC
    static let armenian = USCRIPT_ARMENIAN
    static let tamil = USCRIPT_TAMIL
    static let thai = USCRIPT_THAI
    static let codeLimit = USCRIPT_CODE_LIMIT
    static let canadianAboriginal = USCRIPT_CANADIAN_ABORIGINAL
    // There are more script codes defined by UScriptCode.
    // We are only exposing the ones needed here
}

extension UNumberFormatFields {
    static let integer = UNUM_INTEGER_FIELD
    static let fraction = UNUM_FRACTION_FIELD
    static let decimalSeparator = UNUM_DECIMAL_SEPARATOR_FIELD
    static let groupingSeparator = UNUM_GROUPING_SEPARATOR_FIELD
    static let currencySymbol = UNUM_CURRENCY_FIELD
    static let percentSymbol = UNUM_PERCENT_FIELD
    static let sign = UNUM_SIGN_FIELD
    static let measureUnit = UNUM_MEASURE_UNIT_FIELD
}

extension UNumberFormatFields {
  internal init(_ rawValue: CInt) {
    self.init(rawValue: EnumRawType(rawValue))
  }
}

extension UDateFormatHourCycle {
    static let hourCycle11 = UDAT_HOUR_CYCLE_11
    static let hourCycle12 = UDAT_HOUR_CYCLE_12
    static let hourCycle23 = UDAT_HOUR_CYCLE_23
    static let hourCycle24 = UDAT_HOUR_CYCLE_24
}

extension UATimeUnitTimePattern {
    static let hourMinute = UATIMEUNITTIMEPAT_HM
    static let hourMinuteSecond = UATIMEUNITTIMEPAT_HMS
    static let minuteSecond = UATIMEUNITTIMEPAT_MS
}

extension UCalendarDaysOfWeek {
    internal init(_ rawValue: CInt) {
        self.init(rawValue: EnumRawType(rawValue))
    }
}

extension UNumberFormatSymbol {
    internal init(_ rawValue: CInt) {
        self.init(rawValue: EnumRawType(rawValue))
    }
}
