//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension Duration {
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public func formatted<S: FormatStyle>(_ v: S) -> S.FormatOutput where S.FormatInput == Self {
        v.format(self)
    }

    /// Formats `self` using the hour-minute-second time pattern
    /// - Returns: A formatted string to describe the duration, such as "1:30:56" for a duration of 1 hour, 30 minutes, and 56 seconds
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public func formatted() -> String {
        return Self.TimeFormatStyle(pattern: .hourMinuteSecond).format(self)
    }
}

extension Duration {
    static func bound(
        for input: Duration,
        in interval: Duration,
        countingDown: Bool,
        roundingRule: FloatingPointRoundingRule
    ) -> (bound: Duration, includedInRangeOfInput: Bool) {
        let (rounded, roundsToEven) = input.rounded(roundingRule, toMultipleOf: interval)

        let shift: Duration
        switch (roundingRule, input >= .zero) {
        case (.toNearestOrAwayFromZero, _), (.toNearestOrEven, _):
            shift = countingDown ? interval / -2 : interval / 2
        case (.up, _):
            shift = countingDown ? .zero - interval : .zero
        case (.down, _):
            shift = countingDown ? .zero : interval
        case (.towardZero, let inputGeqZero):
            let direction: Int
            if rounded == .zero && countingDown == inputGeqZero {
                direction = countingDown ? -1 : 1
            } else if countingDown == inputGeqZero {
                direction = 0
            } else if inputGeqZero {
                direction = 1
            } else {
                direction = -1
            }

            shift = interval * direction
        case (.awayFromZero, _):
            if input == .zero || countingDown != (input >= .zero) {
                shift = .zero
            } else {
                shift = input >= .zero ? .zero - interval : interval
            }
        @unknown default:
            fatalError("Unknown FloatingPointRoundingRule \(roundingRule)")
        }

        let bound = rounded + shift

        let doesBoundRoundToInput: Bool
        switch (roundingRule, input >= .zero) {
        case (.down, _), (.awayFromZero, false):
            doesBoundRoundToInput = countingDown
        case (.up, _), (.awayFromZero, true):
            doesBoundRoundToInput = !countingDown
        case (.toNearestOrAwayFromZero, _):
            doesBoundRoundToInput = countingDown && bound > .zero
            || !countingDown && bound < .zero
        case (.toNearestOrEven, _):
            doesBoundRoundToInput = roundsToEven
        case (.towardZero, _):
            doesBoundRoundToInput = (bound >= .zero) == countingDown
        @unknown default:
            fatalError("Unknown FloatingPointRoundingRule \(roundingRule)")
        }

        return (bound, doesBoundRoundToInput || input == bound)
    }

    // Returns an array of values corresponding to each unit in `units`
    func valuesForUnits(
        _ units: [UnitsFormatStyle.Unit],
        trailingFractionalLength: Int,
        smallestUnitRounding: FloatingPointRoundingRule,
        roundingIncrement: Double?
    ) -> [Double] {
        guard let smallestUnit = units.last?.unit else {
            return []
        }

        let increment = Self.interval(
            for: .init(unit: smallestUnit),
            fractionalDigits: trailingFractionalLength,
            roundingIncrement: roundingIncrement
        )

        let rounded: Duration
        if increment != .zero {
            rounded = self.rounded(increment: increment, rule: smallestUnitRounding)
        } else {
            rounded = self
        }

        var (values, remainder) = rounded.factor(intoUnits: units)

        values[values.count-1] += TimeInterval(remainder) / Self.secondCoefficient(for: smallestUnit)

        return values
    }

    static func interval(
        for unit: Duration.UnitsFormatStyle.Unit,
        fractionalDigits: Int = 0,
        roundingIncrement: Double? = nil
    ) -> Duration {
        let fractionalLengthBasedIncrement: Duration
        if unit.unit >= .seconds {
            fractionalLengthBasedIncrement = Self.interval(fractionalSecondsLength: fractionalDigits) * Self.secondCoefficient(for: unit.unit)!
        } else {
            let offset = Self.fractionalDigitOffsetToSecond(from: unit.unit)!
            fractionalLengthBasedIncrement = Self.interval(fractionalSecondsLength: offset + Swift.min(fractionalDigits, Int.max - offset))
        }

        if let roundingIncrement {
            let roundingIncrementBasedIncrement: Duration
            if unit.unit >= .seconds {
                roundingIncrementBasedIncrement = .seconds(Self.secondCoefficient(for: unit.unit)!) * roundingIncrement
            } else {
                roundingIncrementBasedIncrement = .nanoseconds(Self.nanosecondCoefficientsForSubsecondUnits(unit.unit)!) * roundingIncrement
            }

            return Swift.max(fractionalLengthBasedIncrement, roundingIncrementBasedIncrement)
        } else {
            return fractionalLengthBasedIncrement
        }
    }

    private static func interval(fractionalSecondsLength: Int) -> Duration {
        let intervalMod3: Int64
        switch fractionalSecondsLength % 3 {
        case 0:
            intervalMod3 = 1
        case 1:
            intervalMod3 = 100
        case 2:
            intervalMod3 = 10
        default:
            fatalError("Int % 3 >= 3")
        }
        switch fractionalSecondsLength {
        case ...0:
            return .seconds(1)
        case ...3:
            return .milliseconds(intervalMod3)
        case ...6:
            return .microseconds(intervalMod3)
        case ...9:
            return .nanoseconds(intervalMod3)
        default:
            return .seconds(pow(0.1, Double(fractionalSecondsLength)))
        }
    }

    func factor(intoUnits units: [UnitsFormatStyle.Unit]) -> (values: [Double], remainder: Duration) {
        var value = self
        var values = [Double]()
        for unit in units {
            if unit.unit >= .seconds {
                guard let coefficient = Self.secondCoefficient(for: unit.unit) else {
                    values.append(0)
                    continue
                }

                let (quotient, remainder) = value.components.seconds.quotientAndRemainder(dividingBy: coefficient)

                values.append(Double(quotient))
                value = .init(secondsComponent: remainder, attosecondsComponent: value.components.attoseconds)
            } else {
                guard let coefficient = Self.attosecondCoefficient(for: unit.unit) else {
                    values.append(0)
                    continue
                }

                let (quotient, remainder) = value.components.attoseconds.quotientAndRemainder(dividingBy: coefficient)

                var unitValue = Double(quotient)

                if value.components.seconds != .zero {
                    unitValue += Double(value.components.seconds) * pow(10, Double(Self.fractionalDigitOffsetToSecond(from: unit.unit)!))
                }

                values.append(unitValue)
                value = .init(secondsComponent: 0, attosecondsComponent: remainder)
            }
        }
        return (values, value)
    }


    private static func secondCoefficient(for unit: UnitsFormatStyle.Unit._Unit) -> Double {
        if let c: Int64 = secondCoefficient(for: unit) {
            return Double(c)
        } else {
            return pow(0.1, Double(fractionalDigitOffsetToSecond(from: unit)!))
        }
    }

    private static func secondCoefficient(for unit: UnitsFormatStyle.Unit._Unit) -> Int64? {
        switch unit {
        case .weeks:
            return 604800
        case .days:
            return 86400
        case .hours:
            return 3600
        case .minutes:
            return 60
        case .seconds:
            return 1
        default:
            return nil
        }
    }

    private static func fractionalDigitOffsetToSecond(from unit: UnitsFormatStyle.Unit._Unit) -> Int? {
        switch unit {
        case .seconds:
            return 0
        case .milliseconds:
            return 3
        case .microseconds:
            return 6
        case .nanoseconds:
            return 9
        default:
            return nil
        }
    }

    private static func attosecondCoefficient(for unit: UnitsFormatStyle.Unit._Unit) -> Int64? {
        switch unit {
        case .seconds:
            return 1_000_000_000_000_000_000
        case .milliseconds:
            return  1_000_000_000_000_000
        case .microseconds:
            return 1_000_000_000_000
        case .nanoseconds:
            return 1_000_000_000
        default:
            return nil
        }
    }

    private static func nanosecondCoefficientsForSubsecondUnits(_ unit: UnitsFormatStyle.Unit._Unit) -> Int64? {
        switch unit {
        case .seconds:
            return 1_000_000_000
        case .milliseconds:
            return 1_000_000
        case .microseconds:
            return 1_000
        case .nanoseconds:
            return 1
        default:
            return nil
        }
    }
}
