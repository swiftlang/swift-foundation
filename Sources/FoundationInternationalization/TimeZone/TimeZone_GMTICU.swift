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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

internal final class _TimeZoneGMTICU : _TimeZoneProtocol, @unchecked Sendable {
    let offset: Int
    let name: String
    
    init?(identifier: String) {
        fatalError("Unexpected init")
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
    
    var debugDescription: String {
        "gmt icu offset \(offset)"
    }
    
    package func localizedName(for style: TimeZone.NameStyle, locale: Locale?) -> String? {
        // The GMT localized name is always the 'generic' one, as there is no variation for daylight vs standard time. Short or not depends on the style.
        let isShort = switch style {
        case .shortStandard, .shortDaylightSaving, .shortGeneric: true
        default: false
        }
        
        // TODO: Consider using ICU C++ API instead of a date formatter here
        let timeZoneIdentifier = Array(name.utf16)
        let result: String? = timeZoneIdentifier.withUnsafeBufferPointer {
            var status = U_ZERO_ERROR
            guard let df = udat_open(UDAT_NONE, UDAT_NONE, locale?.identifier ?? "", $0.baseAddress, Int32($0.count), nil, 0, &status) else {
                return nil
            }

            guard status.isSuccess else {
                return nil
            }

            defer { udat_close(df) }

            let pattern = "vvvv"
            let patternUTF16 = Array(pattern.utf16)
            return patternUTF16.withUnsafeBufferPointer {
                udat_applyPattern(df, UBool.false, $0.baseAddress, Int32(isShort ? 1 : $0.count))

                return _withResizingUCharBuffer { buffer, size, status in
                    udat_format(df, ucal_getNow(), buffer, size, nil, &status)
                }
            }
        }

        return result
    }
}
