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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

// MARK: Date.AnchoredRelativeFormatStyle

@available(FoundationPreview 0.4, *)
extension Date {
    /// A relative format style that is detached from the system time, and instead
    /// formats an anchor date relative to the format input.
    public struct AnchoredRelativeFormatStyle : Codable, Hashable, Sendable {
        public typealias Presentation = Date.RelativeFormatStyle.Presentation
        public typealias UnitsStyle = Date.RelativeFormatStyle.UnitsStyle
        public typealias Field = Date.RelativeFormatStyle.Field

        var innerStyle: Date.RelativeFormatStyle

        /// The date the formatted output refers to from the perspective of the input values.
        public var anchor: Date

        public var presentation: Presentation {
            get {
                innerStyle.presentation
            }
            set {
                innerStyle.presentation = newValue
            }
        }
        public var unitsStyle: UnitsStyle {
            get {
                innerStyle.unitsStyle
            }
            set {
                innerStyle.unitsStyle = newValue
            }
        }
        public var capitalizationContext: FormatStyleCapitalizationContext {
            get {
                innerStyle.capitalizationContext
            }
            set {
                innerStyle.capitalizationContext = newValue
            }
        }
        public var locale: Locale {
            get {
                innerStyle.locale
            }
            set {
                innerStyle.locale = newValue
            }
        }
        public var calendar: Calendar {
            get {
                innerStyle.calendar
            }
            set {
                innerStyle.calendar = newValue
            }
        }
        /// The fields that can be used in the formatted output.
        public var allowedFields: Set<Field> {
            get {
                innerStyle.allowedFields
            }
            set {
                innerStyle.allowedFields = newValue
            }
        }

        /// Create a relative format style that is detached from the system time, and instead
        /// formats an anchor date relative to the format input.
        ///
        /// - Parameter anchor: The date the formatted output is referring to.
        public init(anchor: Date, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.anchor = anchor
            self.innerStyle = .init(presentation: presentation, unitsStyle: unitsStyle, locale: locale, calendar: calendar, capitalizationContext: capitalizationContext)
        }

        /// Create a relative format style that is detached from the system time, and instead
        /// formats an anchor date relative to the format input.
        ///
        /// - Parameter anchor: The date the formatted output is referring to.
        public init(anchor: Date, allowedFields: Set<Field>, presentation: Presentation = .numeric, unitsStyle: UnitsStyle = .wide, locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent, capitalizationContext: FormatStyleCapitalizationContext = .unknown) {
            self.anchor = anchor
            self.innerStyle = .init(allowedFields: allowedFields, presentation: presentation, unitsStyle: unitsStyle, locale: locale, calendar: calendar, capitalizationContext: capitalizationContext)
        }

        public func format(_ input: Date) -> String {
            innerStyle._format(anchor, refDate: input)
        }

        public func locale(_ locale: Locale) -> Self {
            var copy = self
            copy.innerStyle.locale = locale
            return copy
        }
    }
}

// MARK: DiscreteFormatStyle Conformance

@available(FoundationPreview 0.4, *)
extension Date.AnchoredRelativeFormatStyle : DiscreteFormatStyle {
    public func discreteInput(before input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, relativeTo: anchor, movingDown: true, countingTowardZero: input > anchor) else {
            return nil
        }

        return isIncluded ? bound.nextDown : bound
    }

    public func discreteInput(after input: Date) -> Date? {
        guard let (bound, isIncluded) = bound(for: input, relativeTo: anchor, movingDown: false, countingTowardZero: input < anchor) else {
            return nil
        }

        return isIncluded ? bound.nextUp : bound
    }

    public func input(before input: Date) -> Date? {
        let conversionLoss = abs(input.timeIntervalSince(input.nextDown)) + abs(input.timeIntervalSince(Date(udate: input.udate.nextDown))) +
            abs(anchor.timeIntervalSince(anchor.nextDown)) + abs(anchor.timeIntervalSince(Date(udate: anchor.udate.nextDown)))
        let inaccuracy = 2 * conversionLoss
        let result = input - inaccuracy

        return result < input ? result : nil
    }

    public func input(after input: Date) -> Date? {
        let conversionLoss = abs(input.timeIntervalSince(input.nextDown)) + abs(input.timeIntervalSince(Date(udate: input.udate.nextDown))) +
            abs(anchor.timeIntervalSince(anchor.nextDown)) + abs(anchor.timeIntervalSince(Date(udate: anchor.udate.nextDown)))
        let inaccuracy = 2 * conversionLoss
        let result = input + inaccuracy

        return result > input ? result : nil
    }

    private func bound(for referenceDate: Date, relativeTo destination: Date, movingDown: Bool, countingTowardZero: Bool) -> (bound: Date, includedInRangeOfInput: Bool)? {
        guard let currentLargest = self.innerStyle._largestNonZeroComponent(destination, reference: referenceDate, adjustComponent: self.innerStyle.componentAdjustmentStrategy) else {
            return nil
        }

        let currentLargestField = Date.RelativeFormatStyle.Field.Option(component: currentLargest.component)!
        
        let largestField: Date.ComponentsFormatStyle.Field.Option

        if countingTowardZero && abs(currentLargest.value) == 1,
           let nextLargest = self.usableFields().filter({ $0 < currentLargestField }).first {
            largestField = nextLargest
        } else {
            largestField = currentLargestField
        }

        let alignReferenceDateToBoundsOfLargest = largestField > .hour

        let largest: (component: Calendar.Component, value: Int)
        if largestField != currentLargestField,
           let range = self.innerStyle.calendar.range(of: largestField.component, in: currentLargest.component, for: destination),
           let lastDateRoundedToLargest = self.innerStyle.calendar.date(byAdding: currentLargest.component, value: movingDown ? 1 : -1, to: destination) {

            let truncatedNextLargestCount = (0...range.count+1).lazy.reversed().compactMap { count in
                guard let date = self.innerStyle.calendar.date(byAdding: largestField.component, value: -currentLargest.value * count, to: destination) else {
                    return nil
                }

                guard movingDown ? date <= lastDateRoundedToLargest : date >= lastDateRoundedToLargest && date > referenceDate else {
                    return nil
                }
                
                if count < range.count+1 && !movingDown && date > lastDateRoundedToLargest {
                    return count + 1
                } else {
                    return count
                }
            }.first ?? range.count

            largest = (largestField.component, currentLargest.value * truncatedNextLargestCount)
        } else {
            largest = currentLargest
        }

        var alignedReferenceDate = self.innerStyle.calendar.date(byAdding: largest.component, value: -largest.value, to: destination)

        if alignReferenceDateToBoundsOfLargest {
            alignedReferenceDate = alignedReferenceDate?.aligned(to: movingDown ? .start : .end, of: largest.component, in: self.innerStyle.calendar)
            let nanoseconds = calendar.component(.nanosecond, from: destination)
            if movingDown {
                alignedReferenceDate = alignedReferenceDate?.addingTimeInterval(1e-9 * Double(nanoseconds))
            } else {
                alignedReferenceDate = alignedReferenceDate?.addingTimeInterval(1e-9 * Double(nanoseconds - 1_000_000_000))
            }
        }


        guard var alignedReferenceDate else {
            return nil
        }

        let roundingComponents: [Calendar.Component]
        if !alignReferenceDateToBoundsOfLargest,
           let secondLargestComponent = ICURelativeDateFormatter.sortedAllowedComponents.first(where: { component in
            guard let field = Date.RelativeFormatStyle.Field.Option(component: component) else {
                return false
            }

            return field < largestField
        }) {
            roundingComponents = [secondLargestComponent, .nanosecond]
        } else {
            roundingComponents = [.nanosecond]
        }

        let movingDirection = movingDown ? -1 : 1

        for roundingComponent in roundingComponents {
            let roundingDirection: Int
            if roundingComponent == .nanosecond && roundingComponents.count > 1 {
                roundingDirection = countingTowardZero == movingDown ? -1 : 1
            } else {
                roundingDirection = movingDirection
            }

            guard let coefficient = self.innerStyle.calendar.range(of: roundingComponent, in: largest.component, for: destination)?.count,
                  let realignedReferenceDate = self.innerStyle.calendar.date(byAdding: roundingComponent, value: roundingDirection * coefficient / 2, to: alignedReferenceDate) else {
                return (alignedReferenceDate, true)
            }

            alignedReferenceDate = realignedReferenceDate
        }

        let includedInRangeOfInput = countingTowardZero && ((referenceDate < destination) == (alignedReferenceDate < destination))

        return (alignedReferenceDate, includedInRangeOfInput)
    }

    private func usableFields() -> [Date.RelativeFormatStyle.Field.Option] {
        allowedFields.map(\.option).sorted(by: >)
    }

}

extension Date {
    fileprivate enum Bound {
        case start, end
    }

    fileprivate func aligned(to bound: Bound, of component: Calendar.Component, in calendar: Calendar) -> Date? {
        var refDateStart: Date = self
        var interval: TimeInterval = 0
        guard calendar.dateInterval(of: component, start: &refDateStart, interval: &interval, for: self) else {
            return nil
        }

        switch bound {
        case .start:
            return refDateStart
        case .end:
            return refDateStart.addingTimeInterval(interval.nextDown)
        }
    }
}
