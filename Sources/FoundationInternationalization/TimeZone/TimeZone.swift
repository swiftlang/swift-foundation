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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

/**
 `TimeZone` defines the behavior of a time zone. Time zone values represent geopolitical regions. Consequently, these values have names for these regions. Time zone values also represent a temporal offset, either plus or minus, from Greenwich Mean Time (GMT) and an abbreviation (such as PST for Pacific Standard Time).

 `TimeZone` provides two static functions to get time zone values: `current` and `autoupdatingCurrent`. The `autoupdatingCurrent` time zone automatically tracks updates made by the user.

 Note that time zone database entries such as "America/Los_Angeles" are IDs, not names. An example of a time zone name is "Pacific Daylight Time". Although many `TimeZone` functions include the word "name", they refer to IDs.

 Cocoa does not provide any API to change the time zone of the computer, or of other applications.
 */
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct TimeZone : Hashable, Equatable, Sendable {
    private enum Kind: Sendable {
        // NSTimeZone uses the terminology 'system' for what Locale/Calendar call 'current'. When TimeZone.current is used, we create a `fixed` time zone reflecting the current settings.
        case fixed // aka 'system'
        case autoupdating // aka 'local'
        #if FOUNDATION_FRAMEWORK
        case bridged
        #endif
    }

    private var _kind: Kind
    private var _timeZone: _TimeZone!
    #if FOUNDATION_FRAMEWORK
    private var _bridged: _NSTimeZoneSwiftWrapper!
    #endif

    // MARK: -
    //

    /// Returns a time zone initialized with a given identifier.
    ///
    /// An example identifier is "America/Los_Angeles".
    ///
    /// If `identifier` is an unknown identifier, then returns `nil`.
    public init?(identifier: __shared String) {
        // This will create/cache the value if it is valid
        guard let cached = TimeZoneCache.cache.fixed(identifier) else {
            return nil
        }

        _kind = .fixed
        _timeZone = cached._timeZone
    }

    /// Called by TimeZoneCache to directly instantiate a time zone without causing infinite recursion.
    internal init(fixed: _TimeZone) {
        _kind = .fixed
        _timeZone = fixed
    }

    /// Returns a time zone initialized with a specific number of seconds from GMT.
    ///
    /// Time zones created with this never have daylight savings and the offset is constant no matter the date. The identifier and abbreviation do NOT follow the POSIX convention (of minutes-west).
    ///
    /// - parameter seconds: The number of seconds from GMT.
    /// - returns: A time zone, or `nil` if a valid time zone could not be created from `seconds`.
    public init?(secondsFromGMT seconds: Int) {
        guard let cached = TimeZoneCache.cache.offsetFixed(seconds) else {
            return nil
        }

        _kind = .fixed
        _timeZone = cached._timeZone
    }

    internal init?(name: String, data: Data?) {
        if data == nil {
            // Try the cache first
            if let cached = TimeZoneCache.cache.fixed(name) {
                _kind = .fixed
                _timeZone = cached._timeZone
            } else {
                return nil
            }
        } else {
            // We don't cache Data-based time zones
            guard let tz = _TimeZone(identifier: name, data: data) else {
                return nil
            }

            _kind = .fixed
            _timeZone = tz
        }
    }

    /// Returns a time zone identified by a given abbreviation.
    ///
    /// In general, you are discouraged from using abbreviations except for unique instances such as "GMT". Time Zone abbreviations are not standardized and so a given abbreviation may have multiple meanings--for example, "EST" refers to Eastern Time in both the United States and Australia
    ///
    /// - parameter abbreviation: The abbreviation for the time zone.
    /// - returns: A time zone identified by abbreviation determined by resolving the abbreviation to an identifier using the abbreviation dictionary and then returning the time zone for that identifier. Returns `nil` if there is no match for abbreviation.
    public init?(abbreviation: __shared String) {
        guard let id = TimeZone.identifierForAbbreviation(abbreviation) else {
            return nil
        }

        self.init(identifier: id)
    }

    internal static func identifierForAbbreviation(_ abbreviation: String) -> String? {
        if let name = TimeZone.abbreviationDictionary[abbreviation] {
            return name
        } else {
            // No known time zone for this abbreviation
            if let seconds = TimeZone.tryParseGMTName(abbreviation) {
                if let gmtName = TimeZone.nameForSecondsFromGMT(seconds) {
                    return gmtName
                }
            }
        }
        return nil
    }

    #if FOUNDATION_FRAMEWORK
    private init(reference: NSTimeZone) {
        if let swift = reference as? _NSSwiftTimeZone {
            let refTZ = swift.timeZone
            _kind = refTZ._kind
            _timeZone = refTZ._timeZone
        } else {
            // This is a custom NSTimeZone subclass
            _kind = .bridged
            _bridged = _NSTimeZoneSwiftWrapper(adoptingReference: reference)
        }
    }
    #endif

    enum CurrentKind {
        case current
        case autoupdating
    }

    /// The time zone currently used by the system.
    public static var current : TimeZone {
        TimeZone(current: .current)
    }

    /// The time zone currently used by the system, automatically updating to the user's current preference.
    ///
    /// If this time zone is mutated, then it no longer tracks the system time zone.
    ///
    /// The autoupdating time zone only compares equal to itself.
    public static var autoupdatingCurrent : TimeZone {
        TimeZone(current: .autoupdating)
    }

    /// The default time zone, settable via ObjC but not available in Swift API (because it's global mutable state).
    /// The default time zone is not autoupdating, but it can change at any time when the ObjC `setDefaultTimeZone:` API is called.
    internal static var `default` : TimeZone! {
        get {
            TimeZoneCache.cache.default
        }
        set {
            TimeZoneCache.cache.setDefault(newValue)
        }
    }

    private init(current: CurrentKind) {
        switch current {
        case .current:
            _kind = .fixed
            _timeZone = TimeZoneCache.cache.current._timeZone
        case .autoupdating:
            _kind = .autoupdating
        }
    }

    // MARK: -
    //

    /// The geopolitical region identifier that identifies the time zone.
    public var identifier: String {
        switch _kind {
        case .fixed:
            return _timeZone.identifier
        case .autoupdating:
            return TimeZoneCache.cache.current.identifier
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.identifier
        #endif
        }
    }

    /// Used by `==` and also for compatibility with `NSTimeZone`.
    internal var data: Data {
        switch _kind {
        case .fixed:
            return _timeZone.data
        case .autoupdating:
            return TimeZoneCache.cache.current.data
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.data
        #endif
        }
    }

    /// The current difference in seconds between the time zone and Greenwich Mean Time.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func secondsFromGMT(for date: Date = Date()) -> Int {
        switch _kind {
        case .fixed:
            return _timeZone.secondsFromGMT(for: date)
        case .autoupdating:
            return TimeZoneCache.cache.current.secondsFromGMT(for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.secondsFromGMT(for: date)
        #endif
        }
    }

    /// Returns the abbreviation for the time zone at a given date.
    ///
    /// Note that the abbreviation may be different at different dates. For example, during daylight saving time the US/Eastern time zone has an abbreviation of "EDT." At other times, its abbreviation is "EST."
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func abbreviation(for date: Date = Date()) -> String? {
        switch _kind {
        case .fixed:
            return _timeZone.abbreviation(for: date)
        case .autoupdating:
            return TimeZoneCache.cache.current.abbreviation(for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.abbreviation(for: date)
        #endif
        }
    }

    /// Returns a Boolean value that indicates whether the receiver uses daylight saving time at a given date.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func isDaylightSavingTime(for date: Date = Date()) -> Bool {
        switch _kind {
        case .fixed:
            return _timeZone.isDaylightSavingTime(for: date)
        case .autoupdating:
            return TimeZoneCache.cache.current.isDaylightSavingTime(for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.isDaylightSavingTime(for: date)
        #endif
        }
    }

    /// Returns the daylight saving time offset for a given date.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval {
        switch _kind {
        case .fixed:
            return _timeZone.daylightSavingTimeOffset(for: date)
        case .autoupdating:
            return TimeZoneCache.cache.current.daylightSavingTimeOffset(for: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.daylightSavingTimeOffset(for: date)
        #endif
        }
    }

    /// Returns the next daylight saving time transition after a given date.
    ///
    /// - parameter date: A date.
    /// - returns: The next daylight saving time transition after `date`. Depending on the time zone, this function may return a change of the time zone's offset from GMT. Returns `nil` if the time zone of the receiver does not observe daylight savings time as of `date`.
    public func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        switch _kind {
        case .fixed:
            return _timeZone.nextDaylightSavingTimeTransition(after: date)
        case .autoupdating:
            return TimeZoneCache.cache.current.nextDaylightSavingTimeTransition(after: date)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.nextDaylightSavingTimeTransition(after: date)
        #endif
        }
    }

    /// Returns an array of strings listing the identifier of all the time zones known to the system.
    public static var knownTimeZoneIdentifiers : [String] {
        TimeZoneCache.cache.knownTimeZoneIdentifiers()
    }

    /// Returns the mapping of abbreviations to time zone identifiers.
    public static var abbreviationDictionary : [String : String] {
        get {
            TimeZoneCache.cache.timeZoneAbbreviations()
        }
        set {
            TimeZoneCache.cache.setTimeZoneAbbreviations(newValue)
        }
    }

    /// Returns the time zone data version.
    public static var timeZoneDataVersion : String {
        _TimeZone.timeZoneDataVersion
    }

    /// Returns the date of the next (after the current instant) daylight saving time transition for the time zone. Depending on the time zone, the value of this property may represent a change of the time zone's offset from GMT. Returns `nil` if the time zone does not currently observe daylight saving time.
    public var nextDaylightSavingTimeTransition: Date? {
        switch _kind {
        case .fixed, .autoupdating:
            return self.nextDaylightSavingTimeTransition(after: Date.now)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.nextDaylightSavingTimeTransition(after: Date.now)
        #endif
        }
    }

    /// Returns the name of the receiver localized for a given locale.
    public func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        switch _kind {
        case .fixed:
            return _timeZone.localizedName(style, for: locale)
        case .autoupdating:
            return TimeZoneCache.cache.current.localizedName(for: style, locale: locale)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return _bridged.localizedName(for: style, locale: locale)
        #endif
        }
    }

    @_alwaysEmitIntoClient @_disfavoredOverload
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var gmt: TimeZone { TimeZone(secondsFromGMT: 0)! }

    internal static let cldrKeywordKey = ICUCLDRKey("tz")
    internal static let legacyKeywordKey = ICULegacyKey("timezone")

    // MARK: -

    public func hash(into hasher: inout Hasher) {
        switch _kind {
        case .fixed:
            hasher.combine(_timeZone.identifier)
        case .autoupdating:
            hasher.combine(1)
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            _bridged.hash(into: &hasher)
        #endif
        }
    }

    public static func ==(lhs: TimeZone, rhs: TimeZone) -> Bool {
        // Autoupdating is only ever equal to autoupdating. Other time zones compare their values.
        if lhs._kind == .autoupdating && rhs._kind == .autoupdating {
            return true
        } else if lhs._kind == .autoupdating || rhs._kind == .autoupdating {
            return false
        } else {
            return lhs.identifier == rhs.identifier && lhs.data == rhs.data
        }
    }
}

/// Constants you use to specify a style when presenting time zone names.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension TimeZone {
#if !FOUNDATION_FRAMEWORK
    public enum NameStyle : Int, Sendable {
        /// Specifies a standard name style. For example, “Central Standard Time” for Central Time.
        case standard
        /// Specifies a short name style. For example, “CST” for Central Time.
        case shortStandard
        /// Specifies a daylight saving name style. For example, “Central Daylight Time” for Central Time.
        case daylightSaving
        /// Specifies a short daylight saving name style. For example, “CDT” for Central Time.
        case shortDaylightSaving
        /// Specifies a generic name style. For example, “Central Time” for Central Time.
        case generic
        /// Specifies a generic time zone name. For example, “CT” for Central Time.
        case shortGeneric
    }
#else
    public typealias NameStyle = NSTimeZone.NameStyle
#endif
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension TimeZone : CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    private var _kindDescription : String {
        switch _kind {
        case .fixed:
            return "fixed"
        case .autoupdating:
            return "autoupdatingCurrent"
        #if FOUNDATION_FRAMEWORK
        case .bridged:
            return "bridged"
        #endif
        }
    }

    public var customMirror : Mirror {
        let c: [(label: String?, value: Any)] = [
          ("identifier", identifier),
          ("kind", _kindDescription),
          ("abbreviation", abbreviation() as Any),
          ("secondsFromGMT", secondsFromGMT()),
          ("isDaylightSavingTime", isDaylightSavingTime()),
        ]
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }

    public var description: String {
        return "\(identifier) (\(_kindDescription))"
    }

    public var debugDescription : String {
        return "\(identifier) (\(_kindDescription))"
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension TimeZone : Codable {
    private enum CodingKeys : Int, CodingKey {
        case identifier
        case autoupdating
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let autoupdating = try container.decodeIfPresent(Bool.self, forKey: .autoupdating), autoupdating {
            self = TimeZone.autoupdatingCurrent
            return
        }

        let identifier = try container.decode(String.self, forKey: .identifier)
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "Invalid TimeZone identifier."))
        }

        self = timeZone
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Even if we are autoupdatingCurrent, encode the identifier for backward compatibility
        try container.encode(self.identifier, forKey: .identifier)
        switch _kind {
        case .autoupdating:
            try container.encode(true, forKey: .autoupdating)
        default:
            break
        }
    }
}

extension TimeZone {
    internal static func nameForSecondsFromGMT(_ seconds: Int) -> String? {
        if seconds < -18 * 3600 || 18 * 3600 < seconds {
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
    internal static func tryParseGMTName(_ name: String) -> Int? {
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

// MARK: - Bridging
#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension TimeZone : ReferenceConvertible, _ObjectiveCBridgeable {

    public typealias ReferenceType = NSTimeZone

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSTimeZone {
        switch _kind {
        case .fixed:
            return _NSSwiftTimeZone(timeZone: self)
        case .autoupdating:
            return _NSSwiftTimeZone(timeZone: self)
        case .bridged:
            return _bridged.bridgeToObjectiveC()
        }
    }

    public static func _forceBridgeFromObjectiveC(_ input: NSTimeZone, result: inout TimeZone?) {
        if !_conditionallyBridgeFromObjectiveC(input, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ input: NSTimeZone, result: inout TimeZone?) -> Bool {
        result = TimeZone(reference: input)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSTimeZone?) -> TimeZone {
        var result: TimeZone?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSTimeZone : _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as TimeZone)
    }
}
#endif
