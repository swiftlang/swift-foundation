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

internal import _FoundationICU

typealias CalendarComponentAndValue = (component: Calendar.Component, value: Int)

extension Date {

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct RelativeFormatStyle : Codable, Hashable, Sendable {
        @available(FoundationPreview 0.4, *)
        public typealias Field = Date.ComponentsFormatStyle.Field

        public struct UnitsStyle : Codable, Hashable, Sendable {
            enum Option : Int, Codable, Hashable {
                case wide
                case spellOut
                case abbreviated
                case narrow
            }
            var option: Option

            // ICURelativeDateFormatter compatibility
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

        /// The fields that can be used in the formatted output.
        @available(FoundationPreview 0.4, *)
        public var allowedFields: Set<Field> {
            get {
                _allowedFields
            }
            set {
                _allowedFields = newValue
            }
        }

        var _allowedFields: Set<Date.ComponentsFormatStyle.Field>

        private enum CodingKeys: String, CodingKey {
            case presentation
            case unitsStyle
            case capitalizationContext
            case locale
            case calendar
            case _allowedFields = "allowedFields"
        }

        public init(presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.presentation = presentation
            self.unitsStyle = unitsStyle
            self.capitalizationContext = capitalizationContext
            self.locale = locale
            self.calendar = calendar
            self._allowedFields = Set(Date.ComponentsFormatStyle.Field.Option.allCases.map { .init(option: $0) })
        }

        @available(FoundationPreview 0.4, *)
        public init(allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.presentation = presentation
            self.unitsStyle = unitsStyle
            self.capitalizationContext = capitalizationContext
            self.locale = locale
            self.calendar = calendar
            self._allowedFields = allowedFields
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

        var componentAdjustmentStrategy: ComponentAdjustmentStrategy {
            switch presentation.option {
            case .numeric:
                return .rounded
            case .named:
                return .alignedWithComponentBoundary
            }
        }

        var sortedAllowedComponents: [Calendar.Component] {
             ICURelativeDateFormatter.sortedAllowedComponents.filter({ component in
                 guard let field = Date.ComponentsFormatStyle.Field.Option(component: component) else {
                     return false
                 }
                 return _allowedFields.contains(.init(option: field))
             })
         }

        package func _format(_ destDate: Date, refDate: Date) -> String {
             guard let (component, value) = _largestNonZeroComponent(destDate, reference: refDate, adjustComponent: componentAdjustmentStrategy) else {
                 return ""
             }
             
             return ICURelativeDateFormatter.formatter(for: self).format(value: value, component: component, presentation: self.presentation)!
         }

        private static func _alignedComponentValue(component: Calendar.Component, for destDate: Date, reference refDate: Date, calendar: Calendar, allowedComponents: Set<Calendar.Component>) -> CalendarComponentAndValue? {
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
                dateComponents = calendar.dateComponents(allowedComponents, from: refDateStart, to: destDate)
            } else {
                dateComponents = calendar.dateComponents(allowedComponents, from: refDateEnd, to: destDate)
            }

            return dateComponents.nonZeroComponentsAndValue.first
        }

        private static func _roundedLargestComponentValue(refDate: Date, for destDate: Date, calendar: Calendar, allowedComponents: Set<Calendar.Component>, largestAllowedComponent: Calendar.Component) -> CalendarComponentAndValue? {
            // "day: 1, hour: 11" -> "day: 1"
            // "day: 1, hour: 15" -> "day: 2"
            // "hour: 23, minute: 50" -> "hour: 24" // only carry to the immediate previous value
            // "hour: -23, minute: -30" -> "hour: -24"

            var components = calendar.dateComponents(Set(ICURelativeDateFormatter.sortedAllowedComponents.filter({
                Date.ComponentsFormatStyle.Field.Option(component: $0)! <= Date.ComponentsFormatStyle.Field.Option(component: largestAllowedComponent)!
            })).union([.nanosecond]), from: refDate, to: destDate)

            if let seconds = components.second,
               abs(components.nanosecond!) >= 500_000_000 {
                components.second = seconds + components.nanosecond!.signum()
            }

            let largestNonZeroComponent = components.nonZeroComponentsAndValue.first?.component

            // the smallest allowed component that is greater or equal to the largestNonZeroComponent
            let largest = ICURelativeDateFormatter.sortedAllowedComponents.last(where: { component in
                guard allowedComponents.contains(component) else {
                    return false
                }

                guard let field = Date.ComponentsFormatStyle.Field.Option(component: component) else {
                    return false
                }

                guard let largestNonZeroComponent,
                      let largestNonZeroField = Date.ComponentsFormatStyle.Field.Option(component: largestNonZeroComponent) else {
                    return true
                }

                return field >= largestNonZeroField
            })

            guard let largest else {
                return nil
            }

            let secondLargest = ICURelativeDateFormatter.sortedAllowedComponents.first(where: { component in
                Date.ComponentsFormatStyle.Field.Option(component: component)! < Date.ComponentsFormatStyle.Field.Option(component: largest)!
            }).map { component in
                (component: component, value: components.value(for: component) ?? 0)
            } ?? (.nanosecond, components.nanosecond!)

            var roundedLargest = (component: largest, value: components.value(for: largest) ?? 0)

            if let range = calendar.range(of: secondLargest.component, in: largest, for: destDate) {
                let v = secondLargest.value
                if abs(v) * 2 >= range.count {
                    roundedLargest.value += v > 0 ? 1 : -1
                }
            }

            guard let shiftedDate = calendar.date(byAdding: roundedLargest.component, value: -roundedLargest.value, to: destDate) else {
                return nil
            }

            // re-calculate component in case rounding caused next larger component to become non-zero
            if let newRoundedLargest = calendar.dateComponents(allowedComponents, from: shiftedDate, to: destDate).nonZeroComponentsAndValue.first, newRoundedLargest.component != roundedLargest.component {
                return newRoundedLargest
            } else {
                // if the component didn't change, use the original calculation, which is more precise
                return roundedLargest
            }
        }

        func _largestNonZeroComponent(_ destDate: Date, reference refDate: Date, adjustComponent: ComponentAdjustmentStrategy) -> CalendarComponentAndValue? {
            guard let smallest = self.sortedAllowedComponents.last else {
                return nil
            }

            // Precision of `Date` is higher than second, which is the smallest supported unit. Round to seconds.
            let refDate = destDate.addingTimeInterval(refDate.timeIntervalSince(destDate).rounded(increment: 1.0, rule: .toNearestOrAwayFromZero))

            let allowedComponents = Set(self.sortedAllowedComponents)

            let dateComponents = self.calendar.dateComponents(allowedComponents, from: refDate, to: destDate)

            let compAndValue: CalendarComponentAndValue
            let largest = dateComponents.nonZeroComponentsAndValue.first ?? (smallest, 0)

            let comp = largest.component
            if comp == .hour || comp == .minute || comp == .second {
                compAndValue = Self._roundedLargestComponentValue(
                    refDate: refDate,
                    for: destDate,
                    calendar: calendar,
                    allowedComponents: allowedComponents,
                    largestAllowedComponent: comp) ?? largest
            } else {
                compAndValue = Self._alignedComponentValue(component: largest.component, for: destDate, reference: refDate, calendar: calendar, allowedComponents: allowedComponents) ?? largest
            }

            return compAndValue
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension Date.RelativeFormatStyle : FormatStyle {}

extension DateComponents {
    var nonZeroComponentsAndValue: [CalendarComponentAndValue] {
        return ICURelativeDateFormatter.sortedAllowedComponents.compactMap {
            guard let value = self.value(for: $0), value != 0 else {
                return nil
            }

            return ($0, value)
        }
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle where Self == Date.RelativeFormatStyle {
    static func relative(presentation: Date.RelativeFormatStyle.Presentation, unitsStyle: Date.RelativeFormatStyle.UnitsStyle = .wide) -> Self {
            .init(presentation: presentation, unitsStyle: unitsStyle)
    }
}
