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

/**
 `TimeZone` defines the behavior of a time zone. Time zone values represent geopolitical regions. Consequently, these values have names for these regions. Time zone values also represent a temporal offset, either plus or minus, from Greenwich Mean Time (GMT) and an abbreviation (such as PST for Pacific Standard Time).

 `TimeZone` provides two static functions to get time zone values: `current` and `autoupdatingCurrent`. The `autoupdatingCurrent` time zone automatically tracks updates made by the user.

 Note that time zone database entries such as "America/Los_Angeles" are IDs, not names. An example of a time zone name is "Pacific Daylight Time". Although many `TimeZone` functions include the word "name", they refer to IDs.

 Cocoa does not provide any API to change the time zone of the computer, or of other applications.
 */
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct TimeZone : Hashable, Equatable, Sendable {
    private var _tz: _TimeZoneProtocol

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

        _tz = cached
    }

    /// Directly instantiates a time zone without causing infinite recursion by checking the cache.
    internal init(inner: some _TimeZoneProtocol) {
        _tz = inner
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

        _tz = cached
    }

    internal init?(name: String) {
        // Try the cache first
        if let cached = TimeZoneCache.cache.fixed(name) {
            _tz = cached
        } else {
            return nil
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
            _tz = swift.timeZone._tz
        } else {
            // This is a custom NSTimeZone subclass
            _tz = _TimeZoneBridged(adoptingReference: reference)
        }
    }
    #endif

    /// The time zone currently used by the system.
    public static var current : TimeZone {
        TimeZone(inner: TimeZoneCache.cache.current._tz)
    }

    /// The time zone currently used by the system, automatically updating to the user's current preference.
    ///
    /// If this time zone is mutated, then it no longer tracks the system time zone.
    ///
    /// The autoupdating time zone only compares equal to itself.
    public static var autoupdatingCurrent : TimeZone {
        TimeZone(inner: TimeZoneCache.cache.autoupdatingCurrent())
    }

    /// The default time zone, settable via ObjC but not available in Swift API (because it's global mutable state).
    /// The default time zone is not autoupdating, but it can change at any time when the ObjC `setDefaultTimeZone:` API is called.
    package static var `default` : TimeZone! {
        get {
            TimeZoneCache.cache.default
        }
        set {
            TimeZoneCache.cache.setDefault(newValue)
        }
    }

    // MARK: -
    //

    /// The geopolitical region identifier that identifies the time zone.
    public var identifier: String {
        _tz.identifier
    }

    /// Used for compatibility with `NSTimeZone`.
    internal var data: Data? {
        _tz.data
    }

    /// The current difference in seconds between the time zone and Greenwich Mean Time.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func secondsFromGMT(for date: Date = Date()) -> Int {
        _tz.secondsFromGMT(for: date)
    }

    internal func rawAndDaylightSavingTimeOffset(for date: Date, repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, skippedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        _tz.rawAndDaylightSavingTimeOffset(for: date, repeatedTimePolicy: repeatedTimePolicy, skippedTimePolicy: skippedTimePolicy)
    }

    /// Returns the abbreviation for the time zone at a given date.
    ///
    /// Note that the abbreviation may be different at different dates. For example, during daylight saving time the US/Eastern time zone has an abbreviation of "EDT." At other times, its abbreviation is "EST."
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func abbreviation(for date: Date = Date()) -> String? {
        _tz.abbreviation(for: date)
    }

    /// Returns a Boolean value that indicates whether the receiver uses daylight saving time at a given date.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func isDaylightSavingTime(for date: Date = Date()) -> Bool {
        _tz.isDaylightSavingTime(for: date)
    }

    /// Returns the daylight saving time offset for a given date.
    ///
    /// - parameter date: The date to use for the calculation. The default value is the current date.
    public func daylightSavingTimeOffset(for date: Date = Date()) -> TimeInterval {
        _tz.daylightSavingTimeOffset(for: date)
    }

    /// Returns the next daylight saving time transition after a given date.
    ///
    /// - parameter date: A date.
    /// - returns: The next daylight saving time transition after `date`. Depending on the time zone, this function may return a change of the time zone's offset from GMT. Returns `nil` if the time zone of the receiver does not observe daylight savings time as of `date`.
    public func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        _tz.nextDaylightSavingTimeTransition(after: date)
    }

    /// Returns the mapping of abbreviations to time zone identifiers.
    public static var abbreviationDictionary : [String : String] {
        get {
            // TODO: We may want to consider changing this for Essentials, as it returns a list of abbreviations which only Internationalization supports
            TimeZoneCache.cache.timeZoneAbbreviations()
        }
        set {
            TimeZoneCache.cache.setTimeZoneAbbreviations(newValue)
        }
    }

    /// Returns the date of the next (after the current instant) daylight saving time transition for the time zone. Depending on the time zone, the value of this property may represent a change of the time zone's offset from GMT. Returns `nil` if the time zone does not currently observe daylight saving time.
    public var nextDaylightSavingTimeTransition: Date? {
        _tz.nextDaylightSavingTimeTransition(after: Date.now)
    }

    /// Returns the name of the receiver localized for a given locale.
    public func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        _tz.localizedName(for: style, locale: locale)
    }

    @_alwaysEmitIntoClient @_disfavoredOverload
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    public static var gmt: TimeZone { TimeZone(secondsFromGMT: 0)! }

    package static let cldrKeywordKey = ICUCLDRKey("tz")
    package static let legacyKeywordKey = ICULegacyKey("timezone")

    // MARK: -

    public func hash(into hasher: inout Hasher) {
        _tz.hash(into: &hasher)
    }

    public static func ==(lhs: TimeZone, rhs: TimeZone) -> Bool {
        // Autoupdating is only ever equal to autoupdating. Other time zones compare their values.
        if lhs._tz.isAutoupdating && rhs._tz.isAutoupdating {
            return true
        } else if lhs._tz.isAutoupdating || rhs._tz.isAutoupdating {
            return false
        } else {
            // If both have been initialized with data, then use it for comparison. Otherwise ignore it. Swift TimeZones, including autoupdating and current, do not set it.
            if let lhsData = lhs.data, let rhsData = rhs.data {
                return lhs.identifier == rhs.identifier && lhsData == rhsData
            } else {
                // Compare based on identifier only
                return lhs.identifier == rhs.identifier
            }
        }
    }
}

/// Constants you use to specify a style when presenting time zone names.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension TimeZone {
#if !FOUNDATION_FRAMEWORK
/// Enum you use to specify different name style of a time zone.
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
    public var customMirror : Mirror {
        let c: [(label: String?, value: Any)] = [
          ("identifier", identifier),
          ("tz", _tz),
          ("abbreviation", abbreviation() as Any),
          ("secondsFromGMT", secondsFromGMT()),
          ("isDaylightSavingTime", isDaylightSavingTime()),
        ]
        return Mirror(self, children: c, displayStyle: Mirror.DisplayStyle.struct)
    }

    public var description: String {
        return _tz.debugDescription
    }

    public var debugDescription : String {
        return _tz.debugDescription
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
        if _tz.isAutoupdating {
            try container.encode(true, forKey: .autoupdating)
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
        _tz.bridgeToNSTimeZone()
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

extension TimeZone {
    // Defines from tzfile.h
#if targetEnvironment(simulator)
    internal static let TZDIR = "/usr/share/zoneinfo"
#else
    internal static let TZDIR = "/var/db/timezone/zoneinfo"
#endif // targetEnvironment(simulator)

#if os(macOS) || targetEnvironment(simulator)
    internal static let TZDEFAULT = "/etc/localtime"
#else
    internal static let TZDEFAULT = "/var/db/timezone/localtime"
#endif // os(macOS) || targetEnvironment(simulator)
}

extension TimeZone {
    // Specifies which occurrence of time to use when it falls into the repeated hour or the skipped hour during DST transition day
    // For the skipped time frame when transitioning into DST (e.g. 1:00 - 3:00 AM for PDT), use `.former`  if asking for the occurrence when DST hasn't happened yet
    // For the repeated time frame when DST ends (e.g. 1:00 - 2:00 AM for PDT), use .former if asking for the instance before turning back the clock
    package enum DaylightSavingTimePolicy {
        case former
        case latter
    }
}
