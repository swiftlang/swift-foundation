//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if canImport(Glibc)
import Glibc
#endif

#if canImport(CRT)
import CRT
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

/**
 `Calendar` encapsulates information about systems of reckoning time in which the beginning, length, and divisions of a year are defined. It provides information about the calendar and support for calendrical computations such as determining the range of a given calendrical unit and adding units to a given absolute time.
*/
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Calendar : Hashable, Equatable, Sendable {
    // It'd be nice to use associated values here, but that ruins our ability to perform uniqueness checks on `_Calendar` for efficient copy-on-write behavior.
    private enum Kind: Sendable {
        case fixed
        case autoupdating
        #if FOUNDATION_FRAMEWORK
        case bridged
        #endif
    }

    private var _kind: Kind
    private var _calendar: _Calendar!
    #if FOUNDATION_FRAMEWORK
    private var _bridged: _NSCalendarSwiftWrapper!
    #endif

    /// Calendar supports many different kinds of calendars. Each is identified by an identifier here.
    public enum Identifier : Sendable, CustomDebugStringConvertible {
        /// The common calendar in Europe, the Western Hemisphere, and elsewhere.
        case gregorian
        case buddhist
        case chinese
        case coptic
        case ethiopicAmeteMihret
        case ethiopicAmeteAlem
        case hebrew
        case iso8601
        case indian
        case islamic
        case islamicCivil
        case japanese
        case persian
        case republicOfChina

        /// A simple tabular Islamic calendar using the astronomical/Thursday epoch of CE 622 July 15
        @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
        case islamicTabular

        /// The Islamic Umm al-Qura calendar used in Saudi Arabia. This is based on astronomical calculation, instead of tabular behavior.
        @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
        case islamicUmmAlQura

        static let cldrKeywordKey = "ca"
        static let legacyKeywordKey = ICULegacyKey("calendar")

        public var debugDescription: String {
            self.cldrIdentifier
        }

        /// Converts both CLDR and CF `String` identifiers to `Calendar.Identifier`.
        /// Note: The strings for both are equal except for `.ethiopicAmeteAlem` -- that is `ethioaa` for CLDR and `ethiopic-amete-alem` for CF.
        internal init?(identifierString id: String) {
            switch id {
            case "gregorian": self = .gregorian
            case "buddhist": self = .buddhist
            case "chinese": self = .chinese
            case "coptic": self = .coptic
            case "ethiopic": self = .ethiopicAmeteMihret
            case "ethioaa", "ethiopic-amete-alem": self = .ethiopicAmeteAlem
            case "hebrew": self = .hebrew
            case "iso8601": self = .iso8601
            case "indian": self = .indian
            case "islamic": self = .islamic
            case "islamic-civil": self = .islamicCivil
            case "japanese": self = .japanese
            case "persian": self = .persian
            case "roc": self = .republicOfChina
            case "islamic-tbla": self = .islamicTabular
            case "islamic-umalqura": self = .islamicUmmAlQura
            default: return nil
            }
        }

        internal var cldrIdentifier: String {
            switch self {
            case .gregorian: return "gregorian"
            case .buddhist: return "buddhist"
            case .chinese: return "chinese"
            case .coptic: return "coptic"
            case .ethiopicAmeteMihret: return "ethiopic"
            case .ethiopicAmeteAlem: return "ethioaa"
            case .hebrew: return "hebrew"
            case .iso8601: return "iso8601"
            case .indian: return "indian"
            case .islamic: return "islamic"
            case .islamicCivil: return "islamic-civil"
            case .japanese: return "japanese"
            case .persian: return "persian"
            case .republicOfChina: return "roc"
            case .islamicTabular: return "islamic-tbla"
            case .islamicUmmAlQura: return "islamic-umalqura"
            }
        }

        /// Same as CLDR identifiers except for `.ethiopicAmeteAlem`.
        internal var cfCalendarIdentifier: String {
            switch self {
            case .gregorian: return "gregorian"
            case .buddhist: return "buddhist"
            case .japanese: return "japanese"
            case .islamic: return "islamic"
            case .islamicCivil: return "islamic-civil"
            case .islamicUmmAlQura: return "islamic-umalqura"
            case .islamicTabular: return "islamic-tbla"
            case .hebrew: return "hebrew"
            case .chinese: return "chinese"
            case .republicOfChina: return "roc"
            case .persian: return "persian"
            case .indian: return "indian"
            case .iso8601: return "iso8601"
            case .coptic: return "coptic"
            case .ethiopicAmeteMihret: return "ethiopic"
            case .ethiopicAmeteAlem: return "ethiopic-amete-alem"
            }
        }
    }

    /// Bitwise set of which components in a `DateComponents` are interesting to use. More efficient than`Set<Component>`.
    internal struct ComponentSet: OptionSet {
        let rawValue: UInt
        init(rawValue: UInt) { self.rawValue = rawValue }

        init(_ components: Set<Component>) {
            self.rawValue = components.reduce(ComponentSet.RawValue(), { partialResult, c in
                return partialResult | c.componentSetValue
            })
        }

        init(_ components: Component...) {
            self.rawValue = components.reduce(ComponentSet.RawValue(), { partialResult, c in
                return partialResult | c.componentSetValue
            })
        }

        init(single component: Component) {
            self.rawValue = component.componentSetValue
        }

        static let era = ComponentSet(rawValue: 1 << 0)
        static let year = ComponentSet(rawValue: 1 << 1)
        static let month = ComponentSet(rawValue: 1 << 2)
        static let day = ComponentSet(rawValue: 1 << 3)
        static let hour = ComponentSet(rawValue: 1 << 4)
        static let minute = ComponentSet(rawValue: 1 << 5)
        static let second = ComponentSet(rawValue: 1 << 6)
        static let weekday = ComponentSet(rawValue: 1 << 7)
        static let weekdayOrdinal = ComponentSet(rawValue: 1 << 8)
        static let quarter = ComponentSet(rawValue: 1 << 9)
        static let weekOfMonth = ComponentSet(rawValue: 1 << 10)
        static let weekOfYear = ComponentSet(rawValue: 1 << 11)
        static let yearForWeekOfYear = ComponentSet(rawValue: 1 << 12)
        static let nanosecond = ComponentSet(rawValue: 1 << 13)
        static let calendar = ComponentSet(rawValue: 1 << 14)
        static let timeZone = ComponentSet(rawValue: 1 << 15)
        static let isLeapMonth = ComponentSet(rawValue: 1 << 16)

        var count: Int {
            rawValue.nonzeroBitCount
        }

        var set: Set<Component> {
            var result: Set<Component> = Set()
            if contains(.era) { result.insert(.era) }
            if contains(.year) { result.insert(.year) }
            if contains(.month) { result.insert(.month) }
            if contains(.day) { result.insert(.day) }
            if contains(.hour) { result.insert(.hour) }
            if contains(.minute) { result.insert(.minute) }
            if contains(.second) { result.insert(.second) }
            if contains(.weekday) { result.insert(.weekday) }
            if contains(.weekdayOrdinal) { result.insert(.weekdayOrdinal) }
            if contains(.quarter) { result.insert(.quarter) }
            if contains(.weekOfMonth) { result.insert(.weekOfMonth) }
            if contains(.weekOfYear) { result.insert(.weekOfYear) }
            if contains(.yearForWeekOfYear) { result.insert(.yearForWeekOfYear) }
            if contains(.nanosecond) { result.insert(.nanosecond) }
            if contains(.calendar) { result.insert(.calendar) }
            if contains(.timeZone) { result.insert(.timeZone) }
            if contains(.isLeapMonth) { result.insert(.isLeapMonth) }
            return result
        }

        var highestSetUnit: Calendar.Component? {
            if self.contains(.era) { return .era }
            if self.contains(.year) { return .year }
            if self.contains(.quarter) { return .quarter }
            if self.contains(.month) { return .month }
            if self.contains(.day) { return .day }
            if self.contains(.hour) { return .hour }
            if self.contains(.minute) { return .minute }
            if self.contains(.second) { return .second }
            if self.contains(.weekday) { return .weekday }
            if self.contains(.weekdayOrdinal) { return .weekdayOrdinal }
            if self.contains(.weekOfMonth) { return .weekOfMonth }
            if self.contains(.weekOfYear) { return .weekOfYear }
            if self.contains(.yearForWeekOfYear) { return .yearForWeekOfYear }
            if self.contains(.nanosecond) { return .nanosecond }

            // The algorithms that call this function assume that isLeapMonth counts as a 'highest unit set', but the order is after nanosecond.
            if self.contains(.isLeapMonth) { return .isLeapMonth }

            // The calendar and timeZone properties do not count as a 'highest unit set', since they are not ordered in time like the others are.
            return nil
        }
    }

    /// An enumeration for the various components of a calendar date.
    ///
    /// Several `Calendar` APIs use either a single unit or a set of units as input to a search algorithm.
    ///
    /// - seealso: `DateComponents`
    public enum Component : Sendable {
        case era
        case year
        case month
        case day
        case hour
        case minute
        case second
        case weekday
        case weekdayOrdinal
        case quarter
        case weekOfMonth
        case weekOfYear
        case yearForWeekOfYear
        case nanosecond
        case calendar
        case timeZone
        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        case isLeapMonth

        internal var icuFieldCode: UCalendarDateFields? {
            switch self {
            case .era:
                return UCAL_ERA
            case .year:
                return UCAL_YEAR
            case .month:
                return UCAL_MONTH
            case .day:
                return UCAL_DAY_OF_MONTH
            case .hour:
                return UCAL_HOUR_OF_DAY
            case .minute:
                return UCAL_MINUTE
            case .second:
                return UCAL_SECOND
            case .weekday:
                return UCAL_DAY_OF_WEEK
            case .weekdayOrdinal:
                return UCAL_DAY_OF_WEEK_IN_MONTH
            case .quarter:
                return UCalendarDateFields(rawValue: 4444)
            case .weekOfMonth:
                return UCAL_WEEK_OF_MONTH
            case .weekOfYear:
                return UCAL_WEEK_OF_YEAR
            case .yearForWeekOfYear:
                return UCAL_YEAR_WOY
            case .isLeapMonth:
                return UCAL_IS_LEAP_MONTH
            case .nanosecond:
                return nil
            case .calendar:
                return nil
            case .timeZone:
                return nil
            }
        }

        fileprivate var componentSetValue: ComponentSet.RawValue {
            switch self {
            case .era: return ComponentSet.era.rawValue
            case .year: return ComponentSet.year.rawValue
            case .month: return ComponentSet.month.rawValue
            case .day: return ComponentSet.day.rawValue
            case .hour: return ComponentSet.hour.rawValue
            case .minute: return ComponentSet.minute.rawValue
            case .second: return ComponentSet.second.rawValue
            case .weekday: return ComponentSet.weekday.rawValue
            case .weekdayOrdinal: return ComponentSet.weekdayOrdinal.rawValue
            case .quarter: return ComponentSet.quarter.rawValue
            case .weekOfMonth: return ComponentSet.weekOfMonth.rawValue
            case .weekOfYear: return ComponentSet.weekOfYear.rawValue
            case .yearForWeekOfYear: return ComponentSet.yearForWeekOfYear.rawValue
            case .nanosecond: return ComponentSet.nanosecond.rawValue
            case .calendar: return ComponentSet.calendar.rawValue
            case .timeZone: return ComponentSet.timeZone.rawValue
            case .isLeapMonth: return ComponentSet.isLeapMonth.rawValue
            }
        }
    }

    /// Returns the user's current calendar.
    ///
    /// This calendar does not track changes that the user makes to their preferences.
    public static var current : Calendar {
        Calendar(current: .current)
    }

    /// A Calendar that tracks changes to user's preferred calendar.
    ///
    /// If mutated, this calendar will no longer track the user's preferred calendar.
    ///
    /// - note: The autoupdating Calendar will only compare equal to another autoupdating Calendar.
    public static var autoupdatingCurrent : Calendar {
        Calendar(current: .autoupdating)
    }

    // MARK: -
    // MARK: init

    /// Returns a new Calendar.
    ///
    /// - parameter identifier: The kind of calendar to use.
    public init(identifier: __shared Identifier) {
        _kind = .fixed
        _calendar = CalendarCache.cache.fixed(identifier)
    }

    /// For use by `NSCoding` implementation in `NSCalendar` and `Codable` for `Calendar` only.
    internal init(identifier: Identifier, locale: Locale, timeZone: TimeZone?, firstWeekday: Int?, minimumDaysInFirstWeek: Int?, gregorianStartDate: Date?) {
        _kind = .fixed
        _calendar = _Calendar(identifier: identifier, timeZone: timeZone, locale: locale, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: gregorianStartDate)
    }

    enum CurrentKind {
        case current
        case autoupdating
    }

    private init(current: CurrentKind) {
        switch current {
        case .current:
            _kind = .fixed
            _calendar = CalendarCache.cache.current
        case .autoupdating:
            _kind = .autoupdating
        }
    }

    // MARK: -
    // MARK: Bridging

    #if FOUNDATION_FRAMEWORK
    fileprivate init(reference : __shared NSCalendar) {
        if let swift = reference as? _NSSwiftCalendar {
            let refCalendar = swift.calendar
            _kind = refCalendar._kind
            _calendar = refCalendar._calendar
        } else {
            // This is a custom NSCalendar subclass
            _kind = .bridged
            _bridged = _NSCalendarSwiftWrapper(adoptingReference: reference)
        }
    }
    #endif

    // MARK: -
    //

    /// The identifier of the calendar.
    public var identifier : Identifier {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.identifier
        case .fixed:
            return _calendar.identifier
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.identifier
        #endif
        }
    }

    /// The locale of the calendar.
    public var locale : Locale? {
        get {
            switch _kind {
            case .autoupdating:
                return CalendarCache.cache.current.locale
            case .fixed:
                return _calendar.locale
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                return _bridged.locale
            #endif
            }
        }
        set {
            switch _kind {
            case .fixed:
                if isKnownUniquelyReferenced(&_calendar) {
                    _calendar.locale = newValue ?? Locale.system
                } else {
                    _calendar = _calendar.copy(changingLocale: newValue)
                }
            case .autoupdating:
                // Make a new, non-autoupdating copy
                let c = CalendarCache.cache.current
                _kind = .fixed
                _calendar = _Calendar(identifier: c.identifier, timeZone: c.timeZone, locale: newValue)
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                _bridged.locale = newValue
            #endif
            }
        }
    }

    /// The time zone of the calendar.
    public var timeZone : TimeZone {
        get {
            switch _kind {
            case .autoupdating:
                return CalendarCache.cache.current.timeZone
            case .fixed:
                return _calendar.timeZone
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                return _bridged.timeZone
            #endif
            }
        }
        set {
            switch _kind {
            case .fixed:
                if isKnownUniquelyReferenced(&_calendar) {
                    _calendar.timeZone = newValue
                } else {
                    _calendar = _calendar.copy(changingTimeZone: newValue)
                }
            case .autoupdating:
                let c = CalendarCache.cache.current
                _kind = .fixed
                _calendar = _Calendar(identifier: c.identifier, timeZone: newValue, locale: c.locale)
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                _bridged.timeZone = newValue
            #endif
            }
        }
    }

    /// The first weekday of the calendar.
    public var firstWeekday : Int {
        get {
            switch _kind {
            case .autoupdating:
                return CalendarCache.cache.current.firstWeekday
            case .fixed:
                return _calendar.firstWeekday
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                return _bridged.firstWeekday
            #endif
            }
        }
        set {
            switch _kind {
            case .fixed:
                if isKnownUniquelyReferenced(&_calendar) {
                    _calendar.firstWeekday = newValue
                } else {
                    _calendar = _calendar.copy(changingFirstWeekday: newValue)
                }
            case .autoupdating:
                let c = CalendarCache.cache.current
                _kind = .fixed
                _calendar = _Calendar(identifier: c.identifier, timeZone: c.timeZone, locale: c.locale, firstWeekday: newValue)
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                _bridged.firstWeekday = newValue
            #endif
            }
        }
    }

    /// The number of minimum days in the first week.
    public var minimumDaysInFirstWeek : Int {
        get {
            switch _kind {
            case .autoupdating:
                return CalendarCache.cache.current.minimumDaysInFirstWeek
            case .fixed:
                return _calendar.minimumDaysInFirstWeek
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                return _bridged.minimumDaysInFirstWeek
            #endif
            }
        }
        set {
            switch _kind {
            case .fixed:
                if isKnownUniquelyReferenced(&_calendar) {
                    _calendar.minimumDaysInFirstWeek = newValue
                } else {
                    _calendar = _calendar.copy(changingMinimumDaysInFirstWeek: newValue)
                }
            case .autoupdating:
                let c = CalendarCache.cache.current
                _kind = .fixed
                _calendar = _Calendar(identifier: c.identifier, timeZone: c.timeZone, locale: c.locale, minimumDaysInFirstWeek: newValue)
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                _bridged.minimumDaysInFirstWeek = newValue
            #endif
            }
        }
    }

    // MARK: - Symbols
    private enum SymbolKey {
        case eraSymbols
        case longEraSymbols
        case monthSymbols
        case shortMonthSymbols
        case veryShortMonthSymbols
        case standaloneMonthSymbols
        case shortStandaloneMonthSymbols
        case veryShortStandaloneMonthSymbols
        case weekdaySymbols
        case shortWeekdaySymbols
        case veryShortWeekdaySymbols
        case standaloneWeekdaySymbols
        case shortStandaloneWeekdaySymbols
        case veryShortStandaloneWeekdaySymbols
        case quarterSymbols
        case shortQuarterSymbols
        case standaloneQuarterSymbols
        case shortStandaloneQuarterSymbols
        case amSymbol
        case pmSymbol

#if FOUNDATION_FRAMEWORK
        func toCFDateFormatterKey() -> CFDateFormatterKey {
            switch self {
            case .eraSymbols:
                return .eraSymbols
            case .longEraSymbols:
                return .longEraSymbols
            case .monthSymbols:
                return .monthSymbols
            case .shortMonthSymbols:
                return .shortMonthSymbols
            case .veryShortMonthSymbols:
                return .veryShortMonthSymbols
            case .standaloneMonthSymbols:
                return .standaloneMonthSymbols
            case .shortStandaloneMonthSymbols:
                return .shortStandaloneMonthSymbols
            case .veryShortStandaloneMonthSymbols:
                return .veryShortStandaloneMonthSymbols
            case .weekdaySymbols:
                return .weekdaySymbols
            case .shortWeekdaySymbols:
                return .shortWeekdaySymbols
            case .veryShortWeekdaySymbols:
                return .veryShortWeekdaySymbols
            case .standaloneWeekdaySymbols:
                return .standaloneWeekdaySymbols
            case .shortStandaloneWeekdaySymbols:
                return .shortStandaloneWeekdaySymbols
            case .veryShortStandaloneWeekdaySymbols:
                return .veryShortStandaloneWeekdaySymbols
            case .quarterSymbols:
                return .quarterSymbols
            case .shortQuarterSymbols:
                return .shortQuarterSymbols
            case .standaloneQuarterSymbols:
                return .standaloneQuarterSymbols
            case .shortStandaloneQuarterSymbols:
                return .shortStandaloneQuarterSymbols
            case .amSymbol:
                return .amSymbol
            case .pmSymbol:
                return .pmSymbol
            }
        }
#endif
    }

    private func symbols(for key: SymbolKey) -> [String] {
#if FOUNDATION_FRAMEWORK
        // TODO: (Calendar.symbols) Figure out how to replace this with modern FormatStyle
        // rdar://71815286 (Allow formatting day/era/month symbols)
        let cfdf = CFDateFormatterCreate(kCFAllocatorSystemDefault, (locale as? NSLocale), .noStyle, .noStyle)
        guard let result = CFDateFormatterCopyProperty(cfdf, key.toCFDateFormatterKey()) else {
            return []
        }
        return result as! [String]
#else
        return [""]
#endif
    }

    private func symbol(for key: SymbolKey) -> String {
#if FOUNDATION_FRAMEWORK
        // TODO: (Calendar.symbols) Figure out how to replace this with modern FormatStyle
        // rdar://71815286 (Allow formatting day/era/month symbols)
        let cfdf = CFDateFormatterCreate(kCFAllocatorSystemDefault, (locale as? NSLocale), .noStyle, .noStyle)
        guard let result = CFDateFormatterCopyProperty(cfdf, key.toCFDateFormatterKey()) else {
            return ""
        }
        return result as! String
#else
        return ""
#endif
    }

    /// A list of eras in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["BC", "AD"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var eraSymbols: [String] {
        symbols(for: .eraSymbols)
    }

    /// A list of longer-named eras in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Before Christ", "Anno Domini"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var longEraSymbols: [String] {
        symbols(for: .longEraSymbols)
    }

    /// A list of months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var monthSymbols: [String] {
        symbols(for: .monthSymbols)
    }

    /// A list of shorter-named months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortMonthSymbols: [String] {
        symbols(for: .shortMonthSymbols)
    }

    /// A list of very-shortly-named months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var veryShortMonthSymbols: [String] {
        symbols(for: .veryShortMonthSymbols)
    }

    /// A list of standalone months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var standaloneMonthSymbols: [String] {
        symbols(for: .standaloneMonthSymbols)
    }

    /// A list of shorter-named standalone months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortStandaloneMonthSymbols: [String] {
        symbols(for: .shortStandaloneMonthSymbols)
    }

    /// A list of very-shortly-named standalone months in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var veryShortStandaloneMonthSymbols: [String] {
        symbols(for: .veryShortStandaloneMonthSymbols)
    }

    /// A list of weekdays in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var weekdaySymbols: [String] {
        symbols(for: .weekdaySymbols)
    }

    /// A list of shorter-named weekdays in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortWeekdaySymbols: [String] {
        symbols(for: .shortWeekdaySymbols)
    }

    /// A list of very-shortly-named weekdays in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["S", "M", "T", "W", "T", "F", "S"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var veryShortWeekdaySymbols: [String] {
        symbols(for: .veryShortWeekdaySymbols)
    }

    /// A list of standalone weekday names in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var standaloneWeekdaySymbols: [String] {
        symbols(for: .standaloneWeekdaySymbols)
    }

    /// A list of shorter-named standalone weekdays in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortStandaloneWeekdaySymbols: [String] {
        symbols(for: .shortStandaloneWeekdaySymbols)
    }

    /// A list of very-shortly-named weekdays in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["S", "M", "T", "W", "T", "F", "S"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var veryShortStandaloneWeekdaySymbols: [String] {
        symbols(for: .veryShortStandaloneWeekdaySymbols)
    }

    /// A list of quarter names in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["1st quarter", "2nd quarter", "3rd quarter", "4th quarter"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var quarterSymbols: [String] {
        symbols(for: .quarterSymbols)
    }

    /// A list of shorter-named quarters in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Q1", "Q2", "Q3", "Q4"]`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortQuarterSymbols: [String] {
        symbols(for: .shortQuarterSymbols)
    }

    /// A list of standalone quarter names in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["1st quarter", "2nd quarter", "3rd quarter", "4th quarter"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var standaloneQuarterSymbols: [String] {
        symbols(for: .standaloneQuarterSymbols)
    }

    /// A list of shorter-named standalone quarters in this calendar, localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `["Q1", "Q2", "Q3", "Q4"]`.
    /// - note: Stand-alone properties are for use in places like calendar headers. Non-stand-alone properties are for use in context (for example, "Saturday, November 12th").
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var shortStandaloneQuarterSymbols: [String] {
        symbols(for: .shortStandaloneQuarterSymbols)
    }

    /// The symbol used to represent "AM", localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `"AM"`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var amSymbol: String {
        symbol(for: .amSymbol)
    }

    /// The symbol used to represent "PM", localized to the Calendar's `locale`.
    ///
    /// For example, for English in the Gregorian calendar, returns `"PM"`.
    ///
    /// - note: By default, Calendars have no locale set. If you wish to receive a localized answer, be sure to set the `locale` property first - most likely to `Locale.autoupdatingCurrent`.
    public var pmSymbol: String {
        symbol(for: .pmSymbol)
    }

    // MARK: -
    //

    /// Returns the minimum range limits of the values that a given component can take on in the receiver.
    ///
    /// As an example, in the Gregorian calendar the minimum range of values for the Day component is 1-28.
    /// - parameter component: A component to calculate a range for.
    /// - returns: The range, or nil if it could not be calculated.
    public func minimumRange(of component: Component) -> Range<Int>? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.minimumRange(of: component)
        case .fixed:
            return _calendar.minimumRange(of: component)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.minimumRange(of: component)
        #endif
        }
    }

    /// The maximum range limits of the values that a given component can take on in the receive
    ///
    /// As an example, in the Gregorian calendar the maximum range of values for the Day component is 1-31.
    /// - parameter component: A component to calculate a range for.
    /// - returns: The range, or nil if it could not be calculated.
    public func maximumRange(of component: Component) -> Range<Int>? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.maximumRange(of: component)
        case .fixed:
            return _calendar.maximumRange(of: component)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.maximumRange(of: component)
        #endif
        }
    }


    /// Returns the range of absolute time values that a smaller calendar component (such as a day) can take on in a larger calendar component (such as a month) that includes a specified absolute time.
    ///
    /// You can use this method to calculate, for example, the range the `day` component can take on in the `month` in which `date` lies.
    /// - parameter smaller: The smaller calendar component.
    /// - parameter larger: The larger calendar component.
    /// - parameter date: The absolute time for which the calculation is performed.
    /// - returns: The range of absolute time values smaller can take on in larger at the time specified by date. Returns `nil` if larger is not logically bigger than smaller in the calendar, or the given combination of components does not make sense (or is a computation which is undefined).
    public func range(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.range(of: smaller, in: larger, for: date)
        case .fixed:
            return _calendar.range(of: smaller, in: larger, for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.range(of: smaller, in: larger, for: date)
        #endif
        }
    }

    /// Returns, via two inout parameters, the starting time and duration of a given calendar component that contains a given date.
    ///
    /// - seealso: `range(of:for:)`
    /// - seealso: `dateInterval(of:for:)`
    /// - parameter component: A calendar component.
    /// - parameter start: Upon return, the starting time of the calendar component that contains the date.
    /// - parameter interval: Upon return, the duration of the calendar component that contains the date.
    /// - parameter date: The specified date.
    /// - returns: `true` if the starting time and duration of a component could be calculated, otherwise `false`.
    public func dateInterval(of component: Component, start: inout Date, interval: inout TimeInterval, for date: Date) -> Bool {
        guard let timeRange = dateInterval(of: component, for: date) else {
            return false
        }

        start = timeRange.start
        interval = timeRange.duration
        return true
    }

    /// Returns the starting time and duration of a given calendar component that contains a given date.
    ///
    /// - parameter component: A calendar component.
    /// - parameter date: The specified date.
    /// - returns: A new `DateInterval` if the starting time and duration of a component could be calculated, otherwise `nil`.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public func dateInterval(of component: Component, for date: Date) -> DateInterval? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.dateInterval(of: component, for: date)
        case .fixed:
            return _calendar.dateInterval(of: component, for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.dateInterval(of: component, for: date)
        #endif
        }
    }

    /// Returns, for a given absolute time, the ordinal number of a smaller calendar component (such as a day) within a specified larger calendar component (such as a week).
    ///
    /// The ordinality is in most cases not the same as the decomposed value of the component. Typically return values are 1 and greater. For example, the time 00:45 is in the first hour of the day, and for components `hour` and `day` respectively, the result would be 1. An exception is the week-in-month calculation, which returns 0 for days before the first week in the month containing the date.
    ///
    /// - note: Some computations can take a relatively long time.
    /// - parameter smaller: The smaller calendar component.
    /// - parameter larger: The larger calendar component.
    /// - parameter date: The absolute time for which the calculation is performed.
    /// - returns: The ordinal number of smaller within larger at the time specified by date. Returns `nil` if larger is not logically bigger than smaller in the calendar, or the given combination of components does not make sense (or is a computation which is undefined).
    public func ordinality(of smaller: Component, in larger: Component, for date: Date) -> Int? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.ordinality(of: smaller, in: larger, for: date)
        case .fixed:
            return _calendar.ordinality(of: smaller, in: larger, for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.ordinality(of: smaller, in: larger, for: date)
        #endif
        }
    }

    /// Returns a new `Date` representing the date calculated by adding components to a given date.
    ///
    /// - parameter components: A set of values to add to the date.
    /// - parameter date: The starting date.
    /// - parameter wrappingComponents: If `true`, the component should be incremented and wrap around to zero/one on overflow, and should not cause higher components to be incremented. The default value is `false`.
    /// - returns: A new date, or nil if a date could not be calculated with the given input.
    public func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
        case .fixed:
            return _calendar.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
        #endif
        }
    }

    /// Returns a new `Date` representing the date calculated by adding an amount of a specific component to a given date.
    ///
    /// - parameter component: A single component to add.
    /// - parameter value: The value of the specified component to add.
    /// - parameter date: The starting date.
    /// - parameter wrappingComponents: If `true`, the component should be incremented and wrap around to zero/one on overflow, and should not cause higher components to be incremented. The default value is `false`.
    /// - returns: A new date, or nil if a date could not be calculated with the given input.
    @available(iOS 8.0, *)
    public func date(byAdding component: Component, value: Int, to date: Date, wrappingComponents: Bool = false) -> Date? {
        var dc = DateComponents()
        switch component {
        case .era:
            dc.era = value
        case .year:
            dc.year = value
        case .month:
            dc.month = value
        case .day:
            dc.day = value
        case .hour:
            dc.hour = value
        case .minute:
            dc.minute = value
        case .second:
            dc.second = value
        case .weekday:
            dc.weekday = value
        case .weekdayOrdinal:
            dc.weekdayOrdinal = value
        case .quarter:
            dc.quarter = value
        case .weekOfMonth:
            dc.weekOfMonth = value
        case .weekOfYear:
            dc.weekOfYear = value
        case .yearForWeekOfYear:
            dc.yearForWeekOfYear = value
        case .nanosecond:
            dc.nanosecond = value
        case .calendar, .timeZone, .isLeapMonth:
            return nil
        }

        return self.date(byAdding: dc, to: date, wrappingComponents: wrappingComponents)
    }

    /// Returns a date created from the specified components.
    ///
    /// - parameter components: Used as input to the search algorithm for finding a corresponding date.
    /// - returns: A new `Date`, or nil if a date could not be found which matches the components.
    public func date(from components: DateComponents) -> Date? {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.date(from: components)
        case .fixed:
            return _calendar.date(from: components)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.date(from: components)
        #endif
        }
    }

    /// Returns all the date components of a date, using the calendar time zone.
    ///
    /// - note: If you want "date information in a given time zone" in order to display it, you should use `DateFormatter` to format the date.
    /// - parameter date: The `Date` to use.
    /// - returns: The date components of the specified date.
    public func dateComponents(_ components: Set<Component>, from date: Date) -> DateComponents {
        var dc: DateComponents
        switch _kind {
        case .autoupdating:
            dc = CalendarCache.cache.current.dateComponents(Calendar.ComponentSet(components), from: date)
        case .fixed:
            dc = _calendar.dateComponents(Calendar.ComponentSet(components), from: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            dc = _bridged.dateComponents(components, from: date)
        #endif
        }

        // Fill out the Calendar field of dateComponents, if requested.
        if components.contains(.calendar) {
            dc.calendar = self
        }

        return dc
    }

    /// Same as `dateComponents:from:` but uses the more efficient bitset form of ComponentSet.
    /// Prefixed with `_` to avoid ambiguity at call site with the `Set<Component>` method.
    internal func _dateComponents(_ components: ComponentSet, from date: Date) -> DateComponents {
        var dc: DateComponents
        switch _kind {
        case .fixed:
            dc = _calendar.dateComponents(components, from: date)
        case .autoupdating:
            dc = CalendarCache.cache.current.dateComponents(components, from: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            dc = _bridged.dateComponents(components.set, from: date)
        #endif
        }

        // Fill out the Calendar field of dateComponents, if requested.
        if components.contains(.calendar) {
            dc.calendar = self
        }

        return dc
    }

    /// Returns all the date components of a date, as if in a given time zone (instead of the `Calendar` time zone).
    ///
    /// The time zone overrides the time zone of the `Calendar` for the purposes of this calculation.
    /// - note: If you want "date information in a given time zone" in order to display it, you should use `DateFormatter` to format the date.
    /// - parameter timeZone: The `TimeZone` to use.
    /// - parameter date: The `Date` to use.
    /// - returns: All components, calculated using the `Calendar` and `TimeZone`.
    @available(iOS 8.0, *)
    public func dateComponents(in timeZone: TimeZone, from date: Date) -> DateComponents {
        var dc: DateComponents
        switch _kind {
        case .fixed:
            dc = _calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date, in: timeZone)
        case .autoupdating:
            dc = CalendarCache.cache.current.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date, in: timeZone)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            // This is mutating, but was not marked mutating in struct Calendar. NSCalendar will have to handle it correctly.
            let originalTimeZone = _bridged.timeZone
            _bridged.timeZone = timeZone
            defer { _bridged.timeZone = originalTimeZone }

            dc = _bridged.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .calendar, .timeZone], from: date)
        #endif
        }

        // Fill out the Calendar field of dateComponents (the above calls cannot insert this struct into the date components, because they don't know the right value).
        dc.calendar = self
        return dc
    }

    /// Returns the difference between two dates.
    ///
    /// - parameter components: Which components to compare.
    /// - parameter start: The starting date.
    /// - parameter end: The ending date.
    /// - returns: The result of calculating the difference from start to end.
    public func dateComponents(_ components: Set<Component>, from start: Date, to end: Date) -> DateComponents {
        var dc: DateComponents
        switch _kind {
        case .autoupdating:
            dc = CalendarCache.cache.current.dateComponents(Calendar.ComponentSet(components), from: start, to: end)
        case .fixed:
            dc = _calendar.dateComponents(Calendar.ComponentSet(components), from: start, to: end)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            dc = _bridged.dateComponents(components, from: start, to: end)
        #endif
        }

        // Fill out the Calendar field of dateComponents, if requested.
        if components.contains(.calendar) {
            dc.calendar = self
        }

        return dc
    }

    /// Returns the difference between two dates specified as `DateComponents`.
    ///
    /// For components which are not specified in each `DateComponents`, but required to specify an absolute date, the base value of the component is assumed.  For example, for an `DateComponents` with just a `year` and a `month` specified, a `day` of 1, and an `hour`, `minute`, `second`, and `nanosecond` of 0 are assumed.
    /// Calendrical calculations with unspecified `year` or `year` value prior to the start of a calendar are not advised.
    /// For each `DateComponents`, if its `timeZone` property is set, that time zone is used for it. If the `calendar` property is set, that is used rather than the receiving calendar, and if both the `calendar` and `timeZone` are set, the `timeZone` property value overrides the time zone of the `calendar` property.
    ///
    /// - parameter components: Which components to compare.
    /// - parameter start: The starting date components.
    /// - parameter end: The ending date components.
    /// - returns: The result of calculating the difference from start to end.
    @available(iOS 8.0, *)
    public func dateComponents(_ components: Set<Component>, from start: DateComponents, to end: DateComponents) -> DateComponents {
        var startDate: Date?
        var endDate: Date?
        if let startCalendar = start.calendar {
            startDate = startCalendar.date(from: start)
        } else {
            startDate = self.date(from: start)
        }

        if let endCalendar = end.calendar {
            endDate = endCalendar.date(from: end)
        } else {
            endDate = self.date(from: end)
        }

        guard let startDate, let endDate else {
            return DateComponents(calendar: self)
        }

        return dateComponents(components, from: startDate, to: endDate)
    }

    /// Returns the value for one component of a date.
    ///
    /// - parameter component: The component to calculate.
    /// - parameter date: The date to use.
    /// - returns: The value for the component.
    @available(iOS 8.0, *)
    public func component(_ component: Component, from date: Date) -> Int {
        // struct Calendar API probably should have marked this optional, as some components are not integers. For now, we just return 0 instead for things like time zone or calendar.
        // Avoid an unneeded creation of an array and set by calling the internal version
        let dc = self._dateComponents(ComponentSet(single: component), from: date)
        if let result = dc.value(for: component) {
            return result
        } else {
            return 0
        }
    }

    /// Returns the first moment of a given Date, as a Date.
    ///
    /// For example, pass in `Date()`, if you want the start of today.
    /// If there were two midnights, it returns the first.  If there was none, it returns the first moment that did exist.
    /// - parameter date: The date to search.
    /// - returns: The first moment of the given date.
    @available(iOS 8.0, *)
    public func startOfDay(for date: Date) -> Date {
        guard let interval = dateInterval(of: .day, for: date) else {
            // Attempt to avoid any kind of infinite looping here by not returning the same value
            return date - 1
        }

        return interval.start
    }

    /// Compares the given dates down to the given component, reporting them `orderedSame` if they are the same in the given component and all larger components, otherwise either `orderedAscending` or `orderedDescending`.
    ///
    /// - parameter date1: A date to compare.
    /// - parameter date2: A date to compare.
    /// - parameter: component: A granularity to compare. For example, pass `.hour` to check if two dates are in the same hour.
    @available(iOS 8.0, *)
    public func compare(_ date1: Date, to date2: Date, toGranularity component: Component) -> ComparisonResult {
        // Fallback option for out-of-range or other exceptional results
        let fallback: ComparisonResult = date1 == date2 ? .orderedSame : (date1 > date2 ? .orderedDescending : .orderedAscending)

        // Ensure we are within the valid calendrical calculation range, or fall back to simple numeric comparison
        guard Date.validCalendarRange.contains(date1) && Date.validCalendarRange.contains(date2) else {
            return fallback
        }

        switch component {
        case .calendar, .timeZone, .isLeapMonth:
            return .orderedSame
        case .day, .hour:
            // Day here so we don't assume that time zone fall back situations don't fall back into a previous day
            guard let interval = dateInterval(of: component, for: date1) else {
                return fallback
            }
            if interval.range.contains(date2) {
                return .orderedSame
            } else if date2 < interval.start {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        case .minute:
            // assumes that time zone or other adjustments are always whole minutes
            var (int1, _) = modf(date1.timeIntervalSinceReferenceDate)
            var (int2, _) = modf(date2.timeIntervalSinceReferenceDate)
            int1 = floor(int1 / 60.0)
            int2 = floor(int2 / 60.0)
            if int1 == int2 {
                return .orderedSame
            } else if int2 < int1 {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        case .second:
            let (int1, _) = modf(date1.timeIntervalSinceReferenceDate)
            let (int2, _) = modf(date2.timeIntervalSinceReferenceDate)
            if int1 == int2 {
                return .orderedSame
            } else if int2 < int1 {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        case .nanosecond:
            let (int1, frac1) = modf(date1.timeIntervalSinceReferenceDate)
            let (int2, frac2) = modf(date2.timeIntervalSinceReferenceDate)
            if int1 == int2 {
                let nano1 = floor(frac1 * 1000000000.0)
                let nano2 = floor(frac2 * 1000000000.0)
                if nano1 == nano2 {
                    return .orderedSame
                } else if nano1 < nano2 {
                    return .orderedDescending
                } else {
                    return .orderedSame
                }
            } else if int2 < int1 {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        default:
            break
        }

        // Order matters in the for loop below. Largest first.
        let units: [Calendar.Component]

        if component == .yearForWeekOfYear || component == .weekOfYear {
            units = [.era, .yearForWeekOfYear, .weekOfYear, .weekday]
        } else if component == .weekdayOrdinal {
            // logically this would be NSCalendarUnitWeekday, but this allows for an optimization, as the weekday values cannot be compared directly, because the first day of the week changes which values are less than other values
            units = [.era, .year, .month, .weekdayOrdinal, .day]
        } else if component == .weekday || component == .weekOfMonth {
            units = [.era, .year, .month, .weekOfMonth, .weekday]
        } else {
            units = [.era, .year, .month, .day]
        }

        let comp1 = self.dateComponents(Set(units), from: date1)
        let comp2 = self.dateComponents(Set(units), from: date2)

        for c in units {
            guard let value1 = comp1.value(for: c), let value2 = comp2.value(for: c) else {
                return fallback
            }

            if value1 > value2 {
                return .orderedDescending
            } else if value1 < value2 {
                return .orderedAscending
            }

            if c == .month && identifier == .chinese {
                let leap1 = comp1.isLeapMonth ?? false
                let leap2 = comp2.isLeapMonth ?? false

                if !leap1 && leap2 {
                    return .orderedAscending
                } else if leap1 && !leap2 {
                    return .orderedDescending
                }
            }

            if component == c {
                return .orderedSame
            }
        }

        return .orderedSame
    }

    /// Compares the given dates down to the given component, reporting them equal if they are the same in the given component and all larger components.
    ///
    /// - parameter date1: A date to compare.
    /// - parameter date2: A date to compare.
    /// - parameter component: A granularity to compare. For example, pass `.hour` to check if two dates are in the same hour.
    /// - returns: `true` if the given date is within tomorrow.
    @available(iOS 8.0, *)
    public func isDate(_ date1: Date, equalTo date2: Date, toGranularity component: Component) -> Bool {
        return compare(date1, to: date2, toGranularity: component) == .orderedSame
    }


    /// Returns `true` if the given date is within the same day as another date, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date1: A date to check for containment.
    /// - parameter date2: A date to check for containment.
    /// - returns: `true` if `date1` and `date2` are in the same day.
    @available(iOS 8.0, *)
    public func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        return compare(date1, to: date2, toGranularity: .day) == .orderedSame
    }


    /// Returns `true` if the given date is within today, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within today.
    @available(iOS 8.0, *)
    public func isDateInToday(_ date: Date) -> Bool {
        return compare(date, to: Date.now, toGranularity: .day) == .orderedSame
    }


    /// Returns `true` if the given date is within yesterday, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within yesterday.
    @available(iOS 8.0, *)
    public func isDateInYesterday(_ date: Date) -> Bool {
        guard let today = dateInterval(of: .day, for: Date.now) else {
            return false
        }

        let inYesterday = today.start - 60
        return compare(date, to: inYesterday, toGranularity: .day) == .orderedSame
    }


    /// Returns `true` if the given date is within tomorrow, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within tomorrow.
    @available(iOS 8.0, *)
    public func isDateInTomorrow(_ date: Date) -> Bool {
        guard let today = dateInterval(of: .day, for: Date.now) else {
            return false
        }

        let inTomorrow = today.end + 60.0
        return compare(date, to: inTomorrow, toGranularity: .day) == .orderedSame
    }


    /// Returns `true` if the given date is within a weekend period, as defined by the calendar and calendar's locale.
    ///
    /// - parameter date: The specified date.
    /// - returns: `true` if the given date is within a weekend.
    @available(iOS 8.0, *)
    public func isDateInWeekend(_ date: Date) -> Bool {
        switch _kind {
        case .autoupdating:
            return CalendarCache.cache.current.isDateInWeekend(date)
        case .fixed:
            return _calendar.isDateInWeekend(date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.isDateInWeekend(date)
        #endif
        }
    }

    /// Finds the range of the weekend around the given date, and returns the starting date and duration of the weekend via two inout parameters.
    ///
    /// Note that a given entire day within a calendar is not necessarily all in a weekend or not; weekends can start in the middle of a day in some calendars and locales.
    /// - seealso: `dateIntervalOfWeekend(containing:)`
    /// - parameter date: The date at which to start the search.
    /// - parameter start: Upon return, the starting date of the weekend if found.
    /// - parameter interval: Upon return, the duration of the weekend if found.
    /// - returns: `true` if a date range could be found, and `false` if the date is not in a weekend.
    @available(iOS 8.0, *)
    public func dateIntervalOfWeekend(containing date: Date, start: inout Date, interval: inout TimeInterval) -> Bool {
        guard let weekend = dateIntervalOfWeekend(containing: date) else {
            return false
        }

        start = weekend.start
        interval = weekend.duration
        return true
    }

    /// Returns a `DateInterval` of the weekend contained by the given date, or nil if the date is not in a weekend.
    ///
    /// - parameter date: The date contained in the weekend.
    /// - returns: A `DateInterval`, or nil if the date is not in a weekend.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public func dateIntervalOfWeekend(containing date: Date) -> DateInterval? {
        guard let next = nextWeekend(startingAfter: date, direction: .forward) else {
            return nil
        }

        // nextWeekend is the start of next weekend starting strictly after the date, so the previous weekend is either strictly before or includes the date

        guard let previous = nextWeekend(startingAfter: next.start, direction: .backward) else {
            return nil
        }

        let dateAbsolute = date.timeIntervalSinceReferenceDate
        let weekendStart = previous.start.timeIntervalSinceReferenceDate
        let weekendEnd = weekendStart + previous.duration

        let isWeekend = weekendStart <= dateAbsolute && dateAbsolute < weekendEnd
        guard isWeekend else {
            return nil
        }

        return previous
    }

    /// Returns the range of the next weekend via two inout parameters. The weekend starts strictly after the given date.
    ///
    /// If `direction` is `.backward`, then finds the previous weekend range strictly before the given date.
    ///
    /// Note that a given entire Day within a calendar is not necessarily all in a weekend or not; weekends can start in the middle of a day in some calendars and locales.
    /// - parameter date: The date at which to begin the search.
    /// - parameter start: Upon return, the starting date of the next weekend if found.
    /// - parameter interval: Upon return, the duration of the next weekend if found.
    /// - parameter direction: Which direction in time to search. The default value is `.forward`.
    /// - returns: `true` if the next weekend is found.
    @available(iOS 8.0, *)
    public func nextWeekend(startingAfter date: Date, start: inout Date, interval: inout TimeInterval, direction: SearchDirection = .forward) -> Bool {
        guard let weekend = nextWeekend(startingAfter: date, direction: direction) else {
            return false
        }

        start = weekend.start
        interval = weekend.duration
        return true
    }

    /// Returns a `DateInterval` of the next weekend, which starts strictly after the given date.
    ///
    /// If `direction` is `.backward`, then finds the previous weekend range strictly before the given date.
    ///
    /// Note that a given entire Day within a calendar is not necessarily all in a weekend or not; weekends can start in the middle of a day in some calendars and locales.
    /// - parameter date: The date at which to begin the search.
    /// - parameter direction: Which direction in time to search. The default value is `.forward`.
    /// - returns: A `DateInterval`, or nil if weekends do not exist in the specific calendar or locale.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public func nextWeekend(startingAfter date: Date, direction: SearchDirection = .forward) -> DateInterval? {
        let weekend: WeekendRange?
        switch _kind {
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.nextWeekend(startingAfter: date, direction: direction)
        #endif
        case .autoupdating:
            weekend = CalendarCache.cache.current.weekendRange()
        case .fixed:
            weekend = _calendar.weekendRange()
        }

        guard let weekend else {
            return nil
        }

        let weekendStartComponents = DateComponents(weekday: weekend.start)

        guard var start = nextDate(after: date, matching: weekendStartComponents, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: direction) else {
            return nil
        }

        if let onsetTime = weekend.onsetTime {
            let tempStart = start.addingTimeInterval(onsetTime)
            start = startOfDay(for: tempStart)
        } else {
            start = startOfDay(for: start)
        }

        let weekendEndComponents = DateComponents(weekday: weekend.end)
        // We only care about the end date to get the interval of the weekend, so we don't care if it falls ahead of the passed in date. Always search forward from here, since we just found the *beginning* of the weekend.
        guard var end = nextDate(after: start, matching: weekendEndComponents, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) else {
            return nil
        }

        if let ceaseTime = weekend.ceaseTime, ceaseTime > 0 {
            end = end.addingTimeInterval(ceaseTime)
        } else {
            guard let interval = dateInterval(of: .day, for: end) else {
                return nil
            }
            end = interval.start
            end = end.addingTimeInterval(interval.duration)
            end = startOfDay(for: end)
        }

        return DateInterval(start: start, end: end)
    }

    // MARK: -
    // MARK: Searching

    /// The direction in time to search.
    public enum SearchDirection : Sendable {
        /// Search for a date later in time than the start date.
        case forward

        /// Search for a date earlier in time than the start date.
        case backward
    }

    /// Determines which result to use when a time is repeated on a day in a calendar (for example, during a daylight saving transition when the times between 2:00am and 3:00am may happen twice).
    public enum RepeatedTimePolicy : Sendable {
        /// If there are two or more matching times (all the components are the same, including isLeapMonth) before the end of the next instance of the next higher component to the highest specified component, then the algorithm will return the first occurrence.
        case first

        /// If there are two or more matching times (all the components are the same, including isLeapMonth) before the end of the next instance of the next higher component to the highest specified component, then the algorithm will return the last occurrence.
        case last
    }

    /// A hint to the search algorithm to control the method used for searching for dates.
    public enum MatchingPolicy : Sendable {
        /// If there is no matching time before the end of the next instance of the next higher component to the highest specified component in the `DateComponents` argument, the algorithm will return the next existing time which exists.
        ///
        /// For example, during a daylight saving transition there may be no 2:37am. The result would then be 3:00am, if that does exist.
        case nextTime

        /// If specified, and there is no matching time before the end of the next instance of the next higher component to the highest specified component in the `DateComponents` argument, the method will return the next existing value of the missing component and preserves the lower components' values (e.g., no 2:37am results in 3:37am, if that exists).
        case nextTimePreservingSmallerComponents

        /// If there is no matching time before the end of the next instance of the next higher component to the highest specified component in the `DateComponents` argument, the algorithm will return the previous existing value of the missing component and preserves the lower components' values.
        ///
        /// For example, during a daylight saving transition there may be no 2:37am. The result would then be 1:37am, if that does exist.
        case previousTimePreservingSmallerComponents

        /// If specified, the algorithm travels as far forward or backward as necessary looking for a match.
        ///
        /// For example, if searching for Feb 29 in the Gregorian calendar, the algorithm may choose March 1 instead (for example, if the year is not a leap year). If you wish to find the next Feb 29 without the algorithm adjusting the next higher component in the specified `DateComponents`, then use the `strict` option.
        /// - note: There are ultimately implementation-defined limits in how far distant the search will go.
        case strict
    }

    /// Computes the dates which match (or most closely match) a given set of components, and calls the closure once for each of them, until the enumeration is stopped.
    ///
    /// There will be at least one intervening date which does not match all the components (or the given date itself must not match) between the given date and any result.
    ///
    /// If `direction` is set to `.backward`, this method finds the previous match before the given date. The intent is that the same matches as for a `.forward` search will be found (that is, if you are enumerating forwards or backwards for each hour with minute "27", the seconds in the date you will get in forwards search would obviously be 00, and the same will be true in a backwards search in order to implement this rule.  Similarly for DST backwards jumps which repeats times, you'll get the first match by default, where "first" is defined from the point of view of searching forwards.  So, when searching backwards looking for a particular hour, with no minute and second specified, you don't get a minute and second of 59:59 for the matching hour (which would be the nominal first match within a given hour, given the other rules here, when searching backwards).
    ///
    /// If an exact match is not possible, and requested with the `strict` option, nil is passed to the closure and the enumeration ends.  (Logically, since an exact match searches indefinitely into the future, if no match is found there's no point in continuing the enumeration.)
    ///
    /// Result dates have an integer number of seconds (as if 0 was specified for the nanoseconds property of the `DateComponents` matching parameter), unless a value was set in the nanoseconds property, in which case the result date will have that number of nanoseconds (or as close as possible with floating point numbers).
    ///
    /// The enumeration is stopped by setting `stop` to `true` in the closure and returning. It is not necessary to set `stop` to `false` to keep the enumeration going.
    /// - parameter start: The `Date` at which to start the search.
    /// - parameter components: The `DateComponents` to use as input to the search algorithm.
    /// - parameter matchingPolicy: Determines the behavior of the search algorithm when the input produces an ambiguous result.
    /// - parameter repeatedTimePolicy: Determines the behavior of the search algorithm when the input produces a time that occurs twice on a particular day.
    /// - parameter direction: Which direction in time to search. The default value is `.forward`, which means later in time.
    /// - parameter block: A closure that is called with search results.
    @available(iOS 8.0, *)
    public func enumerateDates(startingAfter start: Date, matching components: DateComponents, matchingPolicy: MatchingPolicy, repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward, using block: (_ result: Date?, _ exactMatch: Bool, _ stop: inout Bool) -> Void) {
        _enumerateDates(startingAfter: start, matching: components, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction, using: block)
    }

    /// Computes the dates which match (or most closely match) a given set of components, returned as a `Sequence`.
    ///
    /// There will be at least one intervening date which does not match all the components (or the given date itself must not match) between the given date and any result.
    ///
    /// If `direction` is set to `.backward`, this method finds the previous match before the given date. The intent is that the same matches as for a `.forward` search will be found (that is, if you are searching forwards or backwards for each hour with minute "27", the seconds in the date you will get in forwards search would be 00), and the same will be true in a backwards search in order to implement this rule.  Similarly for DST backwards jumps which repeats times, you'll get the first match by default, where "first" is defined from the point of view of searching forwards.  So, when searching backwards looking for a particular hour, with no minute and second specified, you don't get a minute and second of 59:59 for the matching hour (which would be the nominal first match within a given hour, given the other rules here, when searching backwards).
    ///
    /// If an exact match is not possible, and requested with the `strict` option, the sequence ends.  (Logically, since an exact match searches indefinitely into the future, if no match is found there's no point in continuing the enumeration.)
    ///
    /// Result dates have an integer number of seconds (as if 0 was specified for the nanoseconds property of the `DateComponents` matching parameter), unless a value was set in the nanoseconds property, in which case the result date will have that number of nanoseconds (or as close as possible with floating point numbers).
    /// - parameter start: The `Date` at which to start the search.
    /// - parameter components: The `DateComponents` to use as input to the search algorithm.
    /// - parameter matchingPolicy: Determines the behavior of the search algorithm when the input produces an ambiguous result.
    /// - parameter repeatedTimePolicy: Determines the behavior of the search algorithm when the input produces a time that occurs twice on a particular day.
    /// - parameter direction: Which direction in time to search. The default value is `.forward`, which means later in time.
    internal func dates(startingAfter start: Date,
                        matching components: DateComponents,
                        matchingPolicy: MatchingPolicy = .nextTime,
                        repeatedTimePolicy: RepeatedTimePolicy = .first,
                        direction: SearchDirection = .forward) -> DateSequence {
        DateSequence(calendar: self, start: start, matchingComponents: components, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
    }

    /// Computes the next date which matches (or most closely matches) a given set of components.
    ///
    /// The general semantics follow those of the `enumerateDates` function.
    /// To compute a sequence of results, use the `enumerateDates` function, rather than looping and calling this method with the previous loop iteration's result.
    /// - parameter date: The starting date.
    /// - parameter components: The components to search for.
    /// - parameter matchingPolicy: Specifies the technique the search algorithm uses to find results. Default value is `.nextTime`.
    /// - parameter repeatedTimePolicy: Specifies the behavior when multiple matches are found. Default value is `.first`.
    /// - parameter direction: Specifies the direction in time to search. Default is `.forward`.
    /// - returns: A `Date` representing the result of the search, or `nil` if a result could not be found.
    @available(iOS 8.0, *)
    public func nextDate(after date: Date, matching components: DateComponents, matchingPolicy: MatchingPolicy, repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> Date? {
        var result: Date?
        enumerateDates(startingAfter: date, matching: components, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction) { date, exactMatch, stop in
            result = date
            stop = true
        }
        return result
    }

    // MARK: -
    //

    /// Returns a new `Date` representing the date calculated by setting a specific component to a given time, and trying to keep lower components the same.  If the component already has that value, this may result in a date which is the same as the given date.
    ///
    /// Changing a component's value often will require higher or coupled components to change as well.  For example, setting the Weekday to Thursday usually will require the Day component to change its value, and possibly the Month and Year as well.
    /// If no such time exists, the next available time is returned (which could, for example, be in a different day, week, month, ... than the nominal target date).  Setting a component to something which would be inconsistent forces other components to change; for example, setting the Weekday to Thursday probably shifts the Day and possibly Month and Year.
    /// The exact behavior of this method is implementation-defined. For example, if changing the weekday to Thursday, does that move forward to the next, backward to the previous, or to the nearest Thursday? The algorithm will try to produce a result which is in the next-larger component to the one given (there's a table of this mapping at the top of this document).  So for the "set to Thursday" example, find the Thursday in the Week in which the given date resides (which could be a forwards or backwards move, and not necessarily the nearest Thursday). For more control over the exact behavior, use `nextDate(after:matching:matchingPolicy:behavior:direction:)`.
    @available(iOS 8.0, *)
    public func date(bySetting component: Component, value: Int, of date: Date) -> Date? {
        guard let currentValue = self.dateComponents([component], from: date).value(for: component) else {
            return nil
        }
        guard currentValue != value else {
            return date
        }

        var result: Date?
        var targetComponents = DateComponents()
        targetComponents.setValue(value, for: component)
        self.enumerateDates(startingAfter: date, matching: targetComponents, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) { date, exactMatch, stop in
            result = date
            stop = true
        }
        return result
    }

    /// Returns a new `Date` representing the date calculated by setting hour, minute, and second to a given time on a specified `Date`.
    ///
    /// If no such time exists, the next available time is returned (which could, for example, be in a different day than the nominal target date).
    /// The intent is to return a date on the same day as the original date argument.  This may result in a date which is backward than the given date, of course.
    /// - parameter hour: A specified hour.
    /// - parameter minute: A specified minute.
    /// - parameter second: A specified second.
    /// - parameter date: The date to start calculation with.
    /// - parameter matchingPolicy: Specifies the technique the search algorithm uses to find results. Default value is `.nextTime`.
    /// - parameter repeatedTimePolicy: Specifies the behavior when multiple matches are found. Default value is `.first`.
    /// - parameter direction: Specifies the direction in time to search. Default is `.forward`.
    /// - returns: A `Date` representing the result of the search, or `nil` if a result could not be found.
    @available(iOS 8.0, *)
    public func date(bySettingHour hour: Int, minute: Int, second: Int, of date: Date, matchingPolicy: MatchingPolicy = .nextTime, repeatedTimePolicy: RepeatedTimePolicy = .first, direction: SearchDirection = .forward) -> Date? {
        guard let interval = dateInterval(of: .day, for: date) else {
            return nil
        }

        let comps = DateComponents(hour: hour, minute: minute, second: second)

        // This function has historically only supported `nextTime` and `strict`. `nextTimePreservingSmallerComponents` and `previousTimePreservingSmallerComponents` are converted into `nextTime`. This is perhaps something that could be improved.
        let restrictedMatchingPolicy: MatchingPolicy
        if matchingPolicy == .nextTime || matchingPolicy == .strict {
            restrictedMatchingPolicy = matchingPolicy
        } else {
            restrictedMatchingPolicy = .nextTime
        }

        guard let result = nextDate(after: interval.start - 0.5, matching: comps, matchingPolicy: restrictedMatchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction) else {
            return nil
        }

        if result < interval.start {
            return nextDate(after: interval.start, matching: comps, matchingPolicy: matchingPolicy, repeatedTimePolicy: repeatedTimePolicy, direction: direction)
        } else {
            return result
        }
    }

    /// Determine if the `Date` has all of the specified `DateComponents`.
    ///
    /// It may be useful to test the return value of `nextDate(after:matching:matchingPolicy:behavior:direction:)` to find out if the components were obeyed or if the method had to fudge the result value due to missing time (for example, a daylight saving time transition).
    ///
    /// - returns: `true` if the date matches all of the components, otherwise `false`.
    @available(iOS 8.0, *)
    public func date(_ date: Date, matchesComponents components: DateComponents) -> Bool {
        let comparedUnits: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal, .quarter, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .nanosecond]

        let actualUnits = comparedUnits.filter { u in
            return components.value(for: u) != nil
        }

        if actualUnits.isEmpty {
            // Try leap month
            if components.isLeapMonth != nil {
                let monthComponents = _dateComponents(.month, from: date)
                // Apparently, enough that it's set and we don't check the actual value
                return monthComponents.isLeapMonth != nil
            }
        }

        var comp = dateComponents(actualUnits, from: date)
        var tempComp = components

        if comp.isLeapMonth != nil && components.isLeapMonth != nil {
            tempComp.isLeapMonth = comp.isLeapMonth
        }

        // Apply an epsilon to comparison of nanosecond values
        if let nanosecond = comp.nanosecond, let tempNanosecond = tempComp.nanosecond {
            if labs(CLong(nanosecond - tempNanosecond)) > 500 {
                return false
            } else {
                comp.nanosecond = 0
                tempComp.nanosecond = 0
            }
        }

        return tempComp == comp
    }

    // MARK: -

    public func hash(into hasher: inout Hasher) {
        switch _kind {
        case .fixed:
            _calendar.hash(into: &hasher)
        case .autoupdating:
            hasher.combine(1)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            _bridged.hash(into: &hasher)
        #endif
        }
    }

    // MARK: -
    // MARK: Conversion Functions

#if FOUNDATION_FRAMEWORK
    internal static func _toNSCalendarIdentifier(_ identifier : Identifier) -> NSCalendar.Identifier {
        switch identifier {
        case .gregorian:
            return .gregorian
        case .buddhist:
            return .buddhist
        case .chinese:
            return .chinese
        case .coptic:
            return .coptic
        case .ethiopicAmeteMihret:
            return .ethiopicAmeteMihret
        case .ethiopicAmeteAlem:
            return .ethiopicAmeteAlem
        case .hebrew:
            return .hebrew
        case .iso8601:
            return .ISO8601
        case .indian:
            return .indian
        case .islamic:
            return .islamic
        case .islamicCivil:
            return .islamicCivil
        case .japanese:
            return .japanese
        case .persian:
            return .persian
        case .republicOfChina:
            return .republicOfChina
        case .islamicTabular:
            return .islamicTabular
        case .islamicUmmAlQura:
            return .islamicUmmAlQura
        }
    }

    internal static func _fromNSCalendarIdentifier(_ identifier : NSCalendar.Identifier) -> Identifier? {
        switch identifier {
        case .gregorian:
            return .gregorian
        case .buddhist:
            return .buddhist
        case .chinese:
            return .chinese
        case .coptic:
            return .coptic
        case .ethiopicAmeteMihret:
            return .ethiopicAmeteMihret
        case .ethiopicAmeteAlem:
            return .ethiopicAmeteAlem
        case .hebrew:
            return .hebrew
        case .ISO8601:
            return .iso8601
        case .indian:
            return .indian
        case .islamic:
            return .islamic
        case .islamicCivil:
            return .islamicCivil
        case .japanese:
            return .japanese
        case .persian:
            return .persian
        case .republicOfChina:
            return .republicOfChina
        case .islamicTabular:
            return .islamicTabular
        case .islamicUmmAlQura:
            return .islamicUmmAlQura
        default:
            return nil
        }
    }
#endif // FOUNDATION_FRAMEWORK

    // MARK: - Private helpers

    static func localeIdentifierWithCalendar(localeIdentifier: String, calendarIdentifier: Calendar.Identifier) -> String? {
        var comps = Locale.Components(identifier: localeIdentifier)
        comps.calendar = calendarIdentifier
        return comps.identifier
    }

    public static func ==(lhs: Calendar, rhs: Calendar) -> Bool {
        switch lhs._kind {
        case .autoupdating:
            switch rhs._kind {
            case .autoupdating:
                return true
            default:
                return false
            }
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            switch rhs._kind {
            case .autoupdating:
                return false
            case .bridged:
                return lhs._bridged == rhs._bridged
            case .fixed:
                // compare swift/objc
                return lhs._bridged.identifier == rhs._calendar.identifier &&
                lhs._bridged.locale == rhs._calendar.locale &&
                lhs._bridged.timeZone == rhs._calendar.timeZone &&
                lhs._bridged.firstWeekday == rhs._calendar.firstWeekday &&
                lhs._bridged.minimumDaysInFirstWeek == rhs._calendar.minimumDaysInFirstWeek
            }
        #endif
        case .fixed:
            switch rhs._kind {
            case .autoupdating:
                return false
            #if FOUNDATION_FRAMEWORK
            case .bridged:
                // compare swift/objc
                return lhs._calendar.identifier == rhs._bridged.identifier &&
                lhs._calendar.locale == rhs._bridged.locale &&
                lhs._calendar.timeZone == rhs._bridged.timeZone &&
                lhs._calendar.firstWeekday == rhs._bridged.firstWeekday &&
                lhs._calendar.minimumDaysInFirstWeek == rhs._bridged.minimumDaysInFirstWeek
            #endif
            case .fixed:
                return lhs._calendar == rhs._calendar
            }
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Calendar : CustomDebugStringConvertible, CustomStringConvertible, CustomReflectable {
    private var _kindDescription : String {
        switch _kind {
        case .fixed:
            return "fixed"
        case .autoupdating:
            return "autoupdating"
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return "bridged"
        #endif
        }
    }

    public var description: String {
        return "\(identifier) (\(_kindDescription)) locale: \(locale?.identifier ?? "") time zone: \(timeZone) firstWeekday: \(firstWeekday) minDaysInFirstWeek: \(minimumDaysInFirstWeek)"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        let c: [(label: String?, value: Any)] = [
          ("identifier", identifier),
          ("kind", _kindDescription),
          ("locale", locale as Any),
          ("timeZone", timeZone),
          ("firstWeekday", firstWeekday),
          ("minimumDaysInFirstWeek", minimumDaysInFirstWeek),
        ]
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Calendar : Codable {
    private enum CodingKeys : Int, CodingKey {
        case identifier
        case locale
        case timeZone
        case firstWeekday
        case minimumDaysInFirstWeek
        case current
    }

    private enum Current : Int, Codable {
        case fixed
        case current
        case autoupdatingCurrent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let current = try container.decodeIfPresent(Current.self, forKey: .current) {
            switch current {
            case .autoupdatingCurrent:
                self = Calendar.autoupdatingCurrent
                return
            case .current:
                self = Calendar.current
                return
            case .fixed:
                // Fall through to identifier-based
                break
            }
        }

        let identifierString = try container.decode(String.self, forKey: .identifier)
        // Same as NSCalendar.Identifier
        guard let identifier = Identifier(identifierString: identifierString) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid calendar identifier \(identifierString)."))
        }

        let locale = try container.decodeIfPresent(Locale.self, forKey: .locale)
        let timeZone = try container.decode(TimeZone.self, forKey: .timeZone)
        let firstWeekday = try container.decode(Int.self, forKey: .firstWeekday)
        let minimumDaysInFirstWeek = try container.decode(Int.self, forKey: .minimumDaysInFirstWeek)

        self.init(identifier: identifier, locale: locale ?? Locale.current, timeZone: timeZone, firstWeekday: firstWeekday, minimumDaysInFirstWeek: minimumDaysInFirstWeek, gregorianStartDate: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Even if we are current/autoupdatingCurrent, encode the identifier for backward compatibility
        let identifier = self.identifier.cfCalendarIdentifier // Same string value as NSCalendar.Identifier
        try container.encode(identifier, forKey: .identifier)
        try container.encode(self.locale, forKey: .locale)
        try container.encode(self.timeZone, forKey: .timeZone)
        try container.encode(self.firstWeekday, forKey: .firstWeekday)
        try container.encode(self.minimumDaysInFirstWeek, forKey: .minimumDaysInFirstWeek)

        // current and autoupdatingCurrent are sentinel values. Calendar could theoretically not treat 'current' as a sentinel, but it is required for Locale (one of the properties of Calendar), so transitively we have to do the same here
        if self == Calendar.autoupdatingCurrent {
            try container.encode(Current.autoupdatingCurrent, forKey: .current)
        } else if self == Calendar.current {
            try container.encode(Current.current, forKey: .current)
        } else {
            try container.encode(Current.fixed, forKey: .current)
        }
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Calendar.Identifier : Codable {}

/// Internal-use struct for holding the range of a Weekend
internal struct WeekendRange {
    var onsetTime: TimeInterval?
    var ceaseTime: TimeInterval?
    var start: Int
    var end: Int
}

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Calendar : ReferenceConvertible {
    public typealias ReferenceType = NSCalendar
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Calendar : _ObjectiveCBridgeable {
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSCalendar {
        switch _kind {
        case .fixed:
            return _NSSwiftCalendar(calendar: self)
        case .autoupdating:
            return _NSSwiftCalendar(calendar: self)
        case .bridged:
            return _bridged.bridgeToObjectiveC()
        }
    }

    public static func _forceBridgeFromObjectiveC(_ input: NSCalendar, result: inout Calendar?) {
        if !_conditionallyBridgeFromObjectiveC(input, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ input: NSCalendar, result: inout Calendar?) -> Bool {
        result = Calendar(reference: input)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSCalendar?) -> Calendar {
        var result: Calendar?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSCalendar : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as Calendar)
    }
}
#endif // FOUNDATION_FRAMEWORK
