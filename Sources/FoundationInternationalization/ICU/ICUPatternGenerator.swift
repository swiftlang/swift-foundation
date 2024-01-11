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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

final class ICUPatternGenerator {

    let upatternGenerator: UnsafeMutablePointer<UDateTimePatternGenerator?>

    private init(localeIdentifier: String, calendarIdentifier: Calendar.Identifier) {
        // We failed to construct a locale with the given calendar; fall back to locale's identifier
        let localeIdentifierWithCalendar = Calendar.localeIdentifierWithCalendar(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier) ?? localeIdentifier
        var status = U_ZERO_ERROR
        upatternGenerator = udatpg_open(localeIdentifierWithCalendar, &status)
        try! status.checkSuccess()
    }

    deinit {
        udatpg_close(upatternGenerator)
    }

    func _patternForSkeleton(_ skeleton: String) -> String {
        var status = U_ZERO_ERROR
        let clonedPatternGenerator = udatpg_clone(upatternGenerator, &status)
        try! status.checkSuccess()
        defer {
             udatpg_close(clonedPatternGenerator)
        }

        let skeletonUChar = Array(skeleton.utf16)
        let pattern = _withResizingUCharBuffer { buffer, size, status in
            udatpg_getBestPatternWithOptions(clonedPatternGenerator, skeletonUChar, Int32(skeletonUChar.count), UDATPG_MATCH_ALL_FIELDS_LENGTH, buffer, size, &status)
        }

        return pattern ?? skeleton
    }

    var defaultHourCycle: Locale.HourCycle {
        var status = U_ZERO_ERROR
        let icuHourCycle = udatpg_getDefaultHourCycle(upatternGenerator, &status)
        guard status.isSuccess else { return .zeroToTwentyThree }

        switch icuHourCycle {
        case .hourCycle11:
            return .zeroToEleven
        case .hourCycle12:
            return .oneToTwelve
        case .hourCycle23:
            return .zeroToTwentyThree
        case .hourCycle24:
            return .oneToTwentyFour
        default:
            return .zeroToTwentyThree
        }
    }

    // -- Caching support

    struct PatternGeneratorInfo: Hashable {
        let localeIdentifier: String
        let calendarIdentifier: Calendar.Identifier
    }

    static let _patternGeneratorCache = FormatterCache<PatternGeneratorInfo, ICUPatternGenerator>()

    static func localizedPattern(symbols: Date.FormatStyle.DateFieldCollection, locale: Locale, calendar: Calendar) -> String {
        let upatternGenerator = cachedPatternGenerator(localeIdentifier: locale.identifierCapturingPreferences, calendarIdentifier: calendar.identifier)

        let skeleton = symbols.formatterTemplate(overridingDayPeriodWithLocale: locale)
        return upatternGenerator._patternForSkeleton(skeleton)
    }

    static func cachedPatternGenerator(localeIdentifier: String, calendarIdentifier: Calendar.Identifier) -> ICUPatternGenerator {
        let patternInfo = PatternGeneratorInfo(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier)
        return _patternGeneratorCache.formatter(for: patternInfo) {
            ICUPatternGenerator(localeIdentifier: localeIdentifier, calendarIdentifier: calendarIdentifier)
        }
    }
}
