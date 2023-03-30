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

@_implementationOnly import FoundationICU

typealias CalendarComponentAndValue = (component: Calendar.Component, value: Int)

extension Date {

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct RelativeFormatStyle : Codable, Hashable, Sendable {
        public struct UnitsStyle : Codable, Hashable, Sendable {
            enum Option : Int, Codable, Hashable {
                case wide
                case spellOut
                case abbreviated
                case narrow
            }
            var option: Option

            // NSICURelativeDateFormatter compatibility
            var icuNumberFormatStyle: UNumberFormatStyle? {
                switch self.option {
                case .spellOut:
                    return .spellout
                case .wide:
                    return nil
                case .abbreviated:
                    return nil
                case .narrow:
                    return nil
                }
            }

            var icuRelativeDateStyle: UDateRelativeDateTimeFormatterStyle {
                switch self.option {
                case .spellOut:
                    return .long
                case .wide:
                    return .long
                case .abbreviated:
                    return .short
                case .narrow:
                    return .narrow
                }
            }

            /// "2 months ago", "next Wednesday"
            public static var wide: Self { .init(option: .wide) }

            /// "two months ago", "next Wednesday"
            public static var spellOut: Self { .init(option: .spellOut) }

            /// "2 mo. ago", "next Wed."
            public static var abbreviated: Self { .init(option: .abbreviated) }

            /// "2 mo. ago", "next W"
            public static var narrow: Self { .init(option: .narrow) }
        }

        public struct Presentation : Codable, Hashable, Sendable {
            enum Option : Int, Codable, Hashable {
                case numeric
                case named
            }
            var option: Option

            /// "1 day ago", "2 days ago", "1 week ago", "in 1 week"
            public static var numeric: Self { .init(option: .numeric) }

            /// "yesterday", "2 days ago", "last week", "next week"; falls back to the numeric style if no name is available.
            public static var named: Self { .init(option: .named) }
        }

        public var presentation: Presentation
        public var unitsStyle: UnitsStyle
        public var capitalizationContext: FormatStyleCapitalizationContext
        public var locale: Locale
        public var calendar: Calendar

        public init(presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.presentation = presentation
            self.unitsStyle = unitsStyle
            self.capitalizationContext = capitalizationContext
            self.locale = locale
            self.calendar = calendar
        }

        // MARK: - FormatStyle conformance

        public func format(_ destDate: Date) -> String {
            return _format(destDate, refDate: Date.now)
        }

        public func locale(_ locale: Locale) -> Self {
            var new = self
            new.locale = locale
            return new
        }

        enum ComponentAdjustmentStrategy : Codable, Hashable {
            case alignedWithComponentBoundary
            case rounded
        }

        var componentAdjustmentStrategy: ComponentAdjustmentStrategy?

        internal func _format(_ destDate: Date, refDate: Date) -> String {
            let strategy: ComponentAdjustmentStrategy
            switch presentation.option {
            case .numeric:
                strategy = .rounded
            case .named:
                strategy = .alignedWithComponentBoundary
            }

            let (component, value) = _largestNonZeroComponent(destDate, reference: refDate, adjustComponent: strategy)
            return NSICURelativeDateFormatter.formatterCreateIfNeeded(format: self).format(value: value, component: component, presentation: self.presentation)!
        }


        private static func _alignedComponentValue(component: Calendar.Component, for destDate: Date, reference refDate: Date, calendar: Calendar) -> CalendarComponentAndValue? {
            // Calculates the value for the specified component in `destDate` by shifting (aligning) the reference date to the start or end of the specified component.
            // For example, we're interested the day component value for `refDate` of 2020-06-10 10:00:00 and `destDate` of 2020-06-12 09:00:00.
            // Without alignment, `refDate` and `destDate` are one day and 23 hours apart, so the value for the day component is 1.
            // With alignment, `refDate` is shifted to the beginning of the day, 2020-06-10 00:00:00, and is 2 days and 9 hours apart from `destDate`. This makes the value of the day component 2.

            var refDateStart: Date = refDate
            var interval: TimeInterval = 0
            guard calendar.dateInterval(of: component, start: &refDateStart, interval: &interval, for: refDate) else {
                return nil
            }

            let refDateEnd = refDateStart.addingTimeInterval(interval - 1)
            let dateComponents: DateComponents
            if refDate < destDate {
                dateComponents = calendar.dateComponents(Set(NSICURelativeDateFormatter.sortedAllowedComponents), from: refDateStart, to: destDate)
            } else {
                dateComponents = calendar.dateComponents(Set(NSICURelativeDateFormatter.sortedAllowedComponents), from: refDateEnd, to: destDate)
            }

            return dateComponents.nonZeroComponentsAndValue.first
        }

        private static func _roundedLargestComponentValue(components: DateComponents, for destDate: Date, calendar: Calendar) -> CalendarComponentAndValue? {
            // "day: 1, hour: 11" -> "day: 1"
            // "day: 1, hour: 15" -> "day: 2"
            // "hour: 23, minute: 50" -> "hour: 24" // only carry to the immediate previous value
            // "hour: -23, minute: -30" -> "hour: -24"

            let compsAndValues = components.nonZeroComponentsAndValue

            if let largest = compsAndValues.first {
                var roundedLargest = largest

                if compsAndValues.count >= 2 {
                    let secondLargest = compsAndValues[1]
                    if let range = calendar.range(of: secondLargest.component, in: largest.component, for: destDate) {
                        let v = secondLargest.value
                        if abs(v) * 2 >= range.count {
                            roundedLargest.value += v > 0 ? 1 : -1
                        }
                    }
                }

                return roundedLargest

            } else {
                return nil
            }
        }

        private func _largestNonZeroComponent(_ destDate: Date, reference refDate: Date, adjustComponent: ComponentAdjustmentStrategy) -> CalendarComponentAndValue {
            // Precision of `Date` is nanosecond. Round to the smallest supported unit, seconds.
            var searchComponents = NSICURelativeDateFormatter.sortedAllowedComponents
            searchComponents.append(.nanosecond)
            let components = self.calendar.dateComponents(Set(searchComponents), from: refDate, to: destDate)

            let nanosecondRange = 1.0e+9
            let dateComponents : DateComponents
            if let nanosecond = components.value(for: .nanosecond), abs(nanosecond) > Int(0.5 * nanosecondRange), let adjustedDestDate = calendar.date(byAdding: .second, value: nanosecond > 0 ? 1 : -1, to: destDate) {
                dateComponents = calendar.dateComponents(Set(NSICURelativeDateFormatter.sortedAllowedComponents), from: refDate, to: adjustedDestDate)
            } else {
                dateComponents = components
            }

            let compAndValue: CalendarComponentAndValue
            if let largest = dateComponents.nonZeroComponentsAndValue.first {
                let comp = largest.component
                if comp == .hour || comp == .minute || comp == .second {
                    compAndValue = Self._roundedLargestComponentValue(components: dateComponents, for: destDate, calendar: calendar) ?? largest
                } else {
                    // 79144218: It's incorrect to simply use `dateComponents` to determine the date difference. For example, two dates that are 23 hour apart may be in the same day or cross two days.
                    // Adjust the component value using the day/week/month/year boundaries.
                    compAndValue = Self._alignedComponentValue(component: largest.component, for: destDate, reference: refDate, calendar: calendar) ?? largest
                }
            } else {
                let smallestUnit = NSICURelativeDateFormatter.sortedAllowedComponents.last!
                compAndValue = (smallestUnit, dateComponents.value(for: smallestUnit)!)
            }

            return compAndValue
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.RelativeFormatStyle : FormatStyle {}

extension DateComponents {
    var nonZeroComponentsAndValue: [CalendarComponentAndValue] {
        return NSICURelativeDateFormatter.sortedAllowedComponents.filter({
            self.value(for: $0) != 0
        }).map { component in
            return (component, self.value(for: component)!)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.RelativeFormatStyle {
    static func relative(presentation: Date.RelativeFormatStyle.Presentation, unitsStyle: Date.RelativeFormatStyle.UnitsStyle = .wide) -> Self {
            .init(presentation: presentation, unitsStyle: unitsStyle)
    }
}
