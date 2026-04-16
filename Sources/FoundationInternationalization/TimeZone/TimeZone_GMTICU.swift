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

internal import _FoundationICU

#if !FOUNDATION_FRAMEWORK
@_dynamicReplacement(for: _timeZoneGMTClass())
private func _timeZoneGMTClass_localized() -> _TimeZoneProtocol.Type {
    return _TimeZoneGMTICU.self
}
#endif

internal final class _TimeZoneGMTICU : _TimeZoneProtocol, @unchecked Sendable {
    let offset: Int
    let name: String

    // Allow using this class to represent time zone whose names take form of "GMT+<offset>" such as "GMT+8".
    init?(identifier: String) {
        guard let offset = TimeZone.tryParseGMTName(identifier), let offsetName = TimeZone.nameForSecondsFromGMT(offset) else {
            return nil
        }

        self.name = offsetName
        self.offset = offset
    }
    
    init?(secondsFromGMT: Int) {
        guard let name = TimeZone.nameForSecondsFromGMT(secondsFromGMT) else {
            return nil
        }

        self.name = name
        offset = secondsFromGMT
    }

    var identifier: String {
        self.name
    }
    
    func secondsFromGMT(for date: Date) -> Int {
        offset
    }
    
    func abbreviation(for date: Date) -> String? {
        _TimeZoneGMT.abbreviation(for: offset)
    }
    
    func isDaylightSavingTime(for date: Date) -> Bool {
        false
    }
    
    func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        0.0
    }
    
    func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        nil
    }
    
    func rawAndDaylightSavingTimeOffset(for date: Date, repeatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, skippedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        (offset, 0)
    }

    var debugDescription: String {
        "GMT (\(offset))"
    }
    
    package func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        // The GMT localized name is always the 'generic' one, as there is no variation for daylight vs standard time. Short or not depends on the style.
        let isShort = switch style {
        case .shortStandard, .shortDaylightSaving, .shortGeneric: true
        default: false
        }
        
        // TODO: Consider implementing this ourselves
        let timeZoneIdentifier = Array(name.utf16)
        let result: String? = timeZoneIdentifier.withUnsafeBufferPointer {
            var status = U_ZERO_ERROR
            let tz = uatimezone_open($0.baseAddress, Int32($0.count), &status)
            defer {
                // `uatimezone_close` checks for nil input, so it's safe to do it even there's an error.
                uatimezone_close(tz)
            }
            guard status.isSuccess else {
                return nil
            }

            let result: String? = _withResizingUCharBuffer { buffer, size, status in
                uatimezone_getDisplayName(tz, isShort ? UTIMEZONE_SHORT: UTIMEZONE_LONG, locale?.identifier ?? "", buffer, size, &status)
            }
            return result
        }

        return result
    }
}
