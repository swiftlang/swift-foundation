//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

let metricUnitsKey = "AppleMetricUnits"
let measurementUnitsKey = "AppleMeasurementUnits"
let force24HourKey = "AppleICUForce24HourTime"
let force12HourKey = "AppleICUForce12HourTime"
let temperatureUnitKey = "AppleTemperatureUnit"
let firstWeekdayKey = "AppleFirstWeekday"

let cm = "Centimeters"
let inch = "Inches"

struct LocalePreferences {
    var measurementSystem: Locale.MeasurementSystem?
    var force24Hour: Bool?
    var force12Hour: Bool?
    var temperatureUnit: UnitTemperature?
    var firstWeekday: [Calendar.Identifier : Locale.Weekday]?
    init(measurementSystem: Locale.MeasurementSystem? = nil, force24Hour: Bool? = nil, force12Hour: Bool? = nil, temperatureUnit: UnitTemperature? = nil, firstWeekday: [Calendar.Identifier : Locale.Weekday]? = nil) {
        self.measurementSystem = measurementSystem
        self.force24Hour = force24Hour
        self.force12Hour = force12Hour
        self.temperatureUnit = temperatureUnit
        self.firstWeekday = firstWeekday
    }
}

extension Locale {
    static func likeCurrent(identifier: String, preferences: LocalePreferences) -> Locale {
        var override = [String : Any]()
        if let measurementSystem = preferences.measurementSystem {
            switch measurementSystem {
            case .metric:
                override[metricUnitsKey] = true
                override[measurementUnitsKey] = cm
            case .us:
                override[metricUnitsKey] = false
                override[measurementUnitsKey] = inch
            case .uk:
                override[metricUnitsKey] = true
                override[measurementUnitsKey] = inch
            default:
                override[metricUnitsKey] = Null()
                override[measurementUnitsKey] = Null()
            }
        } else {
            override[metricUnitsKey] = Null()
            override[measurementUnitsKey] = Null()
        }

        if let force12Hour = preferences.force12Hour {
            override[force12HourKey] = force12Hour
        } else {
            override[force12HourKey] = Null()
        }

        if let force24Hour = preferences.force24Hour {
            override[force24HourKey] = force24Hour
        } else {
            override[force24HourKey] = Null()
        }

        if let temperatureUnit = preferences.temperatureUnit {
            switch temperatureUnit {
            case .celsius:
                override[temperatureUnitKey] = "Celsius"
            case .fahrenheit:
                override[temperatureUnitKey] = "Fahrenheit"
            default:
                override[temperatureUnitKey] = Null()
            }
        } else {
            override[temperatureUnitKey] = Null()
        }

        if let firstWeekday = preferences.firstWeekday {
            let mapped = Dictionary(uniqueKeysWithValues: firstWeekday.map({ key, value in
                return (key.cldrIdentifier, value.icuIndex)
            }))

            override[firstWeekdayKey] = mapped
        } else {
            override[firstWeekdayKey] = Null()
        }
        return Locale.localeAsIfCurrent(name: identifier, overrides: override)
    }

}

// MARK: - Stubs
fileprivate struct Null {}
#if !FOUNDATION_FRAMEWORK
internal enum UnitTemperature {
    case celsius
    case fahrenheit
}
#endif // !FOUNDATION_FRAMEWORK
