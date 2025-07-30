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

#if FOUNDATION_FRAMEWORK
// for CFXPreferences call
internal import _ForSwiftFoundation
#endif

/// Holds user preferences about `Locale`, retrieved from user defaults. It is only used when creating the `current` Locale. Fixed-identifier locales never have preferences.
package struct LocalePreferences: Hashable, Sendable {
    package enum MeasurementUnit: Int, Codable {
        case centimeters
        case inches

        /// Init with the value of a user defaults string
        init?(_ string: String?) {
            guard let string else { return nil }
            if string == "Centimeters" { self = .centimeters }
            else if string == "Inches" { self = .inches }
            else { return nil }
        }

        /// Get the value as a user defaults string
        var userDefaultString: String {
            switch self {
            case .centimeters: return "Centimeters"
            case .inches: return "Inches"
            }
        }
    }

    package enum TemperatureUnit: Int, Codable {
        case fahrenheit
        case celsius

        /// Init with the value of a user defaults string
        init?(_ string: String?) {
            guard let string else { return nil }
            if string == "Celsius" { self = .celsius }
            else if string == "Fahrenheit" { self = .fahrenheit }
            else { return nil }
        }

        /// Get the value as a user defaults string
        var userDefaultString: String {
            switch self {
            case .celsius: return "Celsius"
            case .fahrenheit: return "Fahrenheit"
            }
        }
    }

    package var metricUnits: Bool?
    package var languages: [String]?
    package var locale: String?
    package var collationOrder: String?
    package var firstWeekday: [Calendar.Identifier : Int]?
    package var minDaysInFirstWeek: [Calendar.Identifier : Int]?
#if FOUNDATION_FRAMEWORK
    package struct ICUSymbolsAndStrings : Hashable, @unchecked Sendable {
        // The following `CFDictionary` ivars are used directly by `CFDateFormatter`. Keep them as `CFDictionary` to avoid bridging them into and out of Swift. We don't need to access them from Swift at all.
        
        package var icuDateTimeSymbols: CFDictionary?
        package var icuDateFormatStrings: CFDictionary?
        package var icuTimeFormatStrings: CFDictionary?
        
        // The OS no longer writes out this preference, but we keep it here for compatibility with CFDateFormatter behavior.
        package var icuNumberFormatStrings: CFDictionary?
        package var icuNumberSymbols: CFDictionary?
    }
    
    var icuSymbolsAndStrings = ICUSymbolsAndStrings()
    
#if !NO_FORMATTERS
    package var dateFormats: [Date.FormatStyle.DateStyle: String]? // Bridged version of `icuDateFormatStrings`
#endif
#endif
    package var numberSymbols: [UInt32 : String]? // Bridged version of `icuNumberSymbols`

    package var country: String?
    package var measurementUnits: MeasurementUnit?
    package var temperatureUnit: TemperatureUnit?
    package var force24Hour: Bool?
    package var force12Hour: Bool?
    
    // Note: When adding new preferences, be sure to include them in the serialized format via the Codable conformance below

    package init() { }
    
#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
    // The framework init supports customized dateFormats
    package init(metricUnits: Bool? = nil,
         languages: [String]? = nil,
         locale: String? = nil,
         collationOrder: String? = nil,
         firstWeekday: [Calendar.Identifier : Int]? = nil,
         minDaysInFirstWeek: [Calendar.Identifier : Int]? = nil,
         country: String? = nil,
         measurementUnits: MeasurementUnit? = nil,
         temperatureUnit: TemperatureUnit? = nil,
         force24Hour: Bool? = nil,
         force12Hour: Bool? = nil,
         numberSymbols: [UInt32 : String]? = nil,
         dateFormats: [Date.FormatStyle.DateStyle: String]? = nil,
         icuSymbolsAndStrings: ICUSymbolsAndStrings = ICUSymbolsAndStrings()) {

        self.metricUnits = metricUnits
        self.languages = languages
        self.locale = locale
        self.collationOrder = collationOrder
        self.firstWeekday = firstWeekday
        self.minDaysInFirstWeek = minDaysInFirstWeek
        self.country = country
        self.measurementUnits = measurementUnits
        self.temperatureUnit = temperatureUnit
        self.force24Hour = force24Hour
        self.force12Hour = force12Hour
        self.numberSymbols = numberSymbols
        self.dateFormats = dateFormats
        self.icuSymbolsAndStrings = icuSymbolsAndStrings
    }
#else
    package init(metricUnits: Bool? = nil,
         languages: [String]? = nil,
         locale: String? = nil,
         collationOrder: String? = nil,
         firstWeekday: [Calendar.Identifier : Int]? = nil,
         minDaysInFirstWeek: [Calendar.Identifier : Int]? = nil,
         country: String? = nil,
         measurementUnits: MeasurementUnit? = nil,
         temperatureUnit: TemperatureUnit? = nil,
         force24Hour: Bool? = nil,
         force12Hour: Bool? = nil,
         numberSymbols: [UInt32 : String]? = nil) {

        self.metricUnits = metricUnits
        self.languages = languages
        self.locale = locale
        self.collationOrder = collationOrder
        self.firstWeekday = firstWeekday
        self.minDaysInFirstWeek = minDaysInFirstWeek
        self.country = country
        self.measurementUnits = measurementUnits
        self.temperatureUnit = temperatureUnit
        self.force24Hour = force24Hour
        self.force12Hour = force12Hour
        self.numberSymbols = numberSymbols
    }
#endif

#if FOUNDATION_FRAMEWORK && !NO_CFPREFERENCES
    /// Interpret a dictionary (from user defaults) according to a predefined set of strings and convert it into the more strongly-typed `LocalePreferences` values.
    /// Several dictionaries may need to be applied to the same instance, which is why this is structured as a mutating setter rather than an initializer.
    /// Why use a `CFDictionary` instead of a Swift dictionary here? The input prefs may be a complete copy of the user's prefs, and we don't want to bridge a ton of unrelated data into Swift just to extract a few keys. Keeping it as a `CFDictionary` avoids that overhead, and we call into small CF helper functions to get the data we need, if it is there.
    package mutating func apply(_ prefs: CFDictionary) {
        var exists: DarwinBoolean = false
        
        guard CFDictionaryGetCount(prefs) > 0 else { return }
        
        if let langs = __CFLocalePrefsCopyAppleLanguages(prefs)?.takeRetainedValue() as? [String] {
            self.languages = langs
        }
        if let locale = __CFLocalePrefsCopyAppleLocale(prefs)?.takeRetainedValue() as? String {
            self.locale = locale
        }
        
        let isMetric = __CFLocalePrefsAppleMetricUnitsIsMetric(prefs, &exists)
        if exists.boolValue {
            self.metricUnits = isMetric
        }

        let isCentimeters = __CFLocalePrefsAppleMeasurementUnitsIsCm(prefs, &exists)
        if exists.boolValue {
            self.measurementUnits = isCentimeters ? .centimeters : .inches
        }

        let isCelsius = __CFLocalePrefsAppleTemperatureUnitIsC(prefs, &exists)
        if exists.boolValue {
            self.temperatureUnit = isCelsius ? .celsius : .fahrenheit
        }

        let is24Hour = __CFLocalePrefsAppleForce24HourTime(prefs, &exists)
        if exists.boolValue {
            self.force24Hour = is24Hour
        }
        
        let is12Hour = __CFLocalePrefsAppleForce12HourTime(prefs, &exists)
        if exists.boolValue {
            self.force12Hour = is12Hour
        }
        
        if let collationOrder = __CFLocalePrefsCopyAppleCollationOrder(prefs)?.takeRetainedValue() as? String {
            self.collationOrder = collationOrder
        }

        if let country = __CFLocalePrefsCopyCountry(prefs)?.takeRetainedValue() as? String {
            self.country = country
        }

        if let icuDateTimeSymbols = __CFLocalePrefsCopyAppleICUDateTimeSymbols(prefs)?.takeRetainedValue() {
            self.icuSymbolsAndStrings.icuDateTimeSymbols = icuDateTimeSymbols
        }

        if let icuDateFormatStrings = __CFLocalePrefsCopyAppleICUDateFormatStrings(prefs)?.takeRetainedValue() {
            self.icuSymbolsAndStrings.icuDateFormatStrings = icuDateFormatStrings
            // Bridge the mapping for Locale's usage
            if let dateFormatPrefs = icuDateFormatStrings as? [String: String] {
                var mapped: [Date.FormatStyle.DateStyle : String] = [:]
                for (key, value) in dateFormatPrefs {
                    if let k = UInt(key) {
                        mapped[Date.FormatStyle.DateStyle(rawValue: k)] = value
                    }
                }
                self.dateFormats = mapped
            }
        }
        
        if let icuTimeFormatStrings = __CFLocalePrefsCopyAppleICUTimeFormatStrings(prefs)?.takeRetainedValue() {
            self.icuSymbolsAndStrings.icuTimeFormatStrings = icuTimeFormatStrings
        }
        
        if let icuNumberFormatStrings = __CFLocalePrefsCopyAppleICUNumberFormatStrings(prefs)?.takeRetainedValue() {
            self.icuSymbolsAndStrings.icuNumberFormatStrings = icuNumberFormatStrings
        }
        
        if let icuNumberSymbols = __CFLocalePrefsCopyAppleICUNumberSymbols(prefs)?.takeRetainedValue() {
            // Store the CFDictionary for passing back to CFDateFormatter
            self.icuSymbolsAndStrings.icuNumberSymbols = icuNumberSymbols
            
            // And bridge the mapping for our own usage in Locale
            if let numberSymbolsPrefs = icuNumberSymbols as? [String: String] {
                var mapped: [UInt32 : String] = [:]
                for (key, value) in numberSymbolsPrefs {
                    if let symbol = UInt32(key) {
                        mapped[symbol] = value
                    }
                }
                
                if !mapped.isEmpty {
                    self.numberSymbols = mapped
                }
            }
        }
        

        if let firstWeekdaysPrefs = __CFLocalePrefsCopyAppleFirstWeekday(prefs)?.takeRetainedValue() as? [String: Int] {
            var mapped: [Calendar.Identifier : Int] = [:]
            for (key, value) in firstWeekdaysPrefs {
                if let id = Calendar.Identifier(identifierString: key) {
                    mapped[id] = value
                }
            }

            if !mapped.isEmpty {
                self.firstWeekday = mapped
            }
        }

        if let minDaysPrefs = __CFLocalePrefsCopyAppleMinDaysInFirstWeek(prefs)?.takeRetainedValue() as? [String: Int] {
            var mapped: [Calendar.Identifier : Int] = [:]
            for (key, value) in minDaysPrefs {
                if let id = Calendar.Identifier(identifierString: key) {
                    mapped[id] = value
                }
            }

            if !mapped.isEmpty {
                self.minDaysInFirstWeek = mapped
            }
        }
    }
#endif // FOUNDATION_FRAMEWORK
    
    /// For testing purposes, merge a set of override prefs into this one.
    package mutating func apply(_ prefs: LocalePreferences) {
        if let other = prefs.metricUnits { self.metricUnits = other }
        if let other = prefs.languages { self.languages = other }
        if let other = prefs.locale { self.locale = other }
        if let other = prefs.collationOrder { self.collationOrder = other }
        if let other = prefs.firstWeekday { self.firstWeekday = other }
        if let other = prefs.minDaysInFirstWeek { self.minDaysInFirstWeek = other }
        if let other = prefs.numberSymbols { self.numberSymbols = other }
#if FOUNDATION_FRAMEWORK
        if let other = prefs.icuSymbolsAndStrings.icuDateTimeSymbols { self.icuSymbolsAndStrings.icuDateTimeSymbols = other }
        if let other = prefs.icuSymbolsAndStrings.icuDateFormatStrings { self.icuSymbolsAndStrings.icuDateFormatStrings = other }
        if let other = prefs.icuSymbolsAndStrings.icuTimeFormatStrings { self.icuSymbolsAndStrings.icuTimeFormatStrings = other }
        if let other = prefs.icuSymbolsAndStrings.icuNumberFormatStrings { self.icuSymbolsAndStrings.icuNumberFormatStrings = other }
        if let other = prefs.icuSymbolsAndStrings.icuNumberSymbols { self.icuSymbolsAndStrings.icuNumberSymbols = other }
#if !NO_FORMATTERS
        if let other = prefs.dateFormats { self.dateFormats = other }
#endif // !NO_FORMATTERS
#endif // FOUNDATION_FRAMEWORK
        if let other = prefs.country { self.country = other }
        if let other = prefs.measurementUnits { self.measurementUnits = other }
        if let other = prefs.temperatureUnit { self.temperatureUnit = other }
        if let other = prefs.force24Hour { self.force24Hour = other }
        if let other = prefs.force12Hour { self.force12Hour = other }
    }

    package var measurementSystem: Locale.MeasurementSystem? {
        let metricPref = metricUnits
        let measurementPref = measurementUnits

        if metricPref == nil && measurementPref == nil {
            return nil
        } else if let metricPref, metricPref == true, let measurementPref, measurementPref == .inches {
            return Locale.MeasurementSystem.uk
        } else if let metricPref, metricPref == false {
            return Locale.MeasurementSystem.us
        } else if let measurementPref, measurementPref == .centimeters {
            return Locale.MeasurementSystem.metric
        } else {
            // There isn't enough info
            return nil
        }
    }

    package var hourCycle: Locale.HourCycle? {
        if let setForce24Hour = force24Hour, setForce24Hour  {
        // Respect 24-hour override if both force24hour and force12hour are true
            return .zeroToTwentyThree
        } else if let setForce12Hour = force12Hour, setForce12Hour {
            return .oneToTwelve
        } else {
            return nil
        }
    }
}

extension LocalePreferences: Codable {
    private enum CodingKeys: String, CodingKey {
        case metricUnits = "metric"
        case languages = "langs"
        case locale
        case collationOrder = "coll"
        case firstWeekday = "weekFirst"
        case minDaysInFirstWeek = "weekMin"
        case icuSymbolsAndStrings = "icu"
        case dateFormats = "dates"
        case numberSymbols = "nums"
        case country
        case measurementUnits = "meas"
        case temperatureUnit = "temp"
        case force24Hour = "24h"
        case force12Hour = "12h"
    }
    
    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(metricUnits, forKey: .metricUnits)
        try container.encodeIfPresent(languages, forKey: .languages)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(collationOrder, forKey: .collationOrder)
        let firstWeekdayMapped = self.firstWeekday.map {
            var result = [String : Int]()
            for (identifier, day) in $0 {
                result[identifier.cfCalendarIdentifier] = day
            }
            return result
        }
        try container.encodeIfPresent(firstWeekdayMapped, forKey: .firstWeekday)
        let minDaysInFirstWeekMapped = self.minDaysInFirstWeek.map {
            var result = [String : Int]()
            for (identifier, days) in $0 {
                result[identifier.cldrIdentifier] = days
            }
            return result
        }
        try container.encodeIfPresent(minDaysInFirstWeekMapped, forKey: .minDaysInFirstWeek)
#if FOUNDATION_FRAMEWORK
        if icuSymbolsAndStrings.containsValuesToSerialize {
            try container.encodeIfPresent(icuSymbolsAndStrings, forKey: .icuSymbolsAndStrings)
        }
#if !NO_FORMATTERS
        try container.encodeIfPresent(dateFormats.map {
            var result = [UInt : String]()
            for (format, value) in $0 {
                result[format.rawValue] = value
            }
            return result
        }, forKey: .dateFormats)
#endif
#endif
        try container.encodeIfPresent(numberSymbols, forKey: .numberSymbols)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(measurementUnits, forKey: .measurementUnits)
        try container.encodeIfPresent(temperatureUnit, forKey: .temperatureUnit)
        try container.encodeIfPresent(force24Hour, forKey: .force24Hour)
        try container.encodeIfPresent(force12Hour, forKey: .force12Hour)
    }
    
    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let metricUnits = try container.decodeIfPresent(Bool.self, forKey: .metricUnits)
        let languages = try container.decodeIfPresent([String].self, forKey: .languages)
        let locale = try container.decodeIfPresent(String.self, forKey: .locale)
        let collationOrder = try container.decodeIfPresent(String.self, forKey: .collationOrder)
        let firstWeekday = try container.decodeIfPresent([String : Int].self, forKey: .firstWeekday).map {
            var result = [Calendar.Identifier : Int]()
            for (stringIdentifier, day) in $0 {
                guard let identifier = Calendar.Identifier(identifierString: stringIdentifier) else {
                    throw DecodingError.dataCorruptedError(forKey: .firstWeekday, in: container, debugDescription: "Unknown calendar identifier '\(stringIdentifier)'")
                }
                result[identifier] = day
            }
            return result
        }
        let minDaysInFirstWeek = try container.decodeIfPresent([String : Int].self, forKey: .minDaysInFirstWeek).map {
            var result = [Calendar.Identifier : Int]()
            for (stringIdentifier, days) in $0 {
                guard let identifier = Calendar.Identifier(identifierString: stringIdentifier) else {
                    throw DecodingError.dataCorruptedError(forKey: .minDaysInFirstWeek, in: container, debugDescription: "Unknown calendar identifier '\(stringIdentifier)'")
                }
                result[identifier] = days
            }
            return result
        }
        let country = try container.decodeIfPresent(String.self, forKey: .country)
        let measurementUnits = try container.decodeIfPresent(MeasurementUnit.self, forKey: .measurementUnits)
        let temperatureUnit = try container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit)
        let force24Hour = try container.decodeIfPresent(Bool.self, forKey: .force24Hour)
        let force12Hour = try container.decodeIfPresent(Bool.self, forKey: .force12Hour)
        let numberSymbols = try container.decodeIfPresent([UInt32 : String].self, forKey: .numberSymbols)
        
        #if FOUNDATION_FRAMEWORK && !NO_FORMATTERS
        let dateFormats = try container.decodeIfPresent([UInt: String].self, forKey: .dateFormats).map {
            var result = [Date.FormatStyle.DateStyle : String]()
            for (rawValue, format) in $0 {
                result[Date.FormatStyle.DateStyle(rawValue: rawValue)] = format
            }
            return result
        }
        let icuDateFormats = dateFormats.map {
            var cfResult = [String : String]()
            for (style, format) in $0 {
                cfResult["\(style.rawValue)"] = format
            }
            return cfResult as CFDictionary
        }
        let icuNumberSymbols = numberSymbols.map {
            var result = [String : String]()
            for (rawValue, symbol) in $0 {
                result["\(rawValue)"] = symbol
            }
            return result as CFDictionary
        }
        var icuSymbolsAndStrings = try container.decodeIfPresent(ICUSymbolsAndStrings.self, forKey: .icuSymbolsAndStrings)
        if (icuDateFormats != nil || icuNumberSymbols != nil) && icuSymbolsAndStrings == nil {
            // Ensure that we have a value to store these in even if the archive didn't contain any serialized info
            icuSymbolsAndStrings = ICUSymbolsAndStrings()
        }
        icuSymbolsAndStrings?.icuDateFormatStrings = icuDateFormats
        icuSymbolsAndStrings?.icuNumberSymbols = icuNumberSymbols
        
        self.init(
            metricUnits: metricUnits,
            languages: languages,
            locale: locale,
            collationOrder: collationOrder,
            firstWeekday: firstWeekday,
            minDaysInFirstWeek: minDaysInFirstWeek,
            country: country,
            measurementUnits: measurementUnits,
            temperatureUnit: temperatureUnit,
            force24Hour: force24Hour,
            force12Hour: force12Hour,
            numberSymbols: numberSymbols,
            dateFormats: dateFormats,
            icuSymbolsAndStrings: icuSymbolsAndStrings ?? .init()
        )
        #else
        self.init(
            metricUnits: metricUnits,
            languages: languages,
            locale: locale,
            collationOrder: collationOrder,
            firstWeekday: firstWeekday,
            minDaysInFirstWeek: minDaysInFirstWeek,
            country: country,
            measurementUnits: measurementUnits,
            temperatureUnit: temperatureUnit,
            force24Hour: force24Hour,
            force12Hour: force12Hour,
            numberSymbols: numberSymbols
        )
        #endif
    }
}

#if FOUNDATION_FRAMEWORK
extension LocalePreferences.ICUSymbolsAndStrings: Codable {
    var containsValuesToSerialize: Bool {
        icuDateTimeSymbols != nil || icuTimeFormatStrings != nil || icuNumberFormatStrings != nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case icuDateTimeSymbols = "dtSym"
        case icuTimeFormatStrings = "times"
        case icuNumberFormatStrings = "nums"
    }
    
    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(icuDateTimeSymbols.map { $0 as? [String : [String]] }, forKey: .icuDateTimeSymbols)
        try container.encodeIfPresent(icuTimeFormatStrings.map { $0 as? [String : String] }, forKey: .icuTimeFormatStrings)
        try container.encodeIfPresent(icuNumberFormatStrings.map { $0 as? [String : String] }, forKey: .icuNumberFormatStrings)
    }
    
    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.icuDateTimeSymbols = try container.decodeIfPresent([String : [String]].self, forKey: .icuDateTimeSymbols).map { $0 as CFDictionary }
        self.icuTimeFormatStrings = try container.decodeIfPresent([String : String].self, forKey: .icuTimeFormatStrings).map { $0 as CFDictionary }
        self.icuNumberFormatStrings = try container.decodeIfPresent([String : String].self, forKey: .icuNumberFormatStrings).map { $0 as CFDictionary }
        
        // Will be filled in by LocalePreferences serialized value
        self.icuDateFormatStrings = nil
        self.icuNumberSymbols = nil
    }
}
#endif
