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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if ICU
internal import _FoundationICU

/// Kept so existing call sites keep working; the ICU-independent implementation lives in `_TimeZoneRules`.
internal typealias _TimeZoneICUResource = _TimeZoneRules

// Loads `_TimeZoneRules` from ICU's `zoneinfo64` resource bundle
extension _TimeZoneRules {
    internal static let kZONEINFO = "zoneinfo64"
    internal static let kTRANS = "trans"
    internal static let kTRANSPRE32 = "transPre32"
    internal static let kTRANSPOST32 = "transPost32"
    internal static let kTYPEOFFSETS = "typeOffsets"
    internal static let kTYPEMAP = "typeMap"
    internal static let kNAMES = "Names"
    internal static let kZONES = "Zones"
    internal static let kRULES = "Rules"
    internal static let kFINALRULE = "finalRule"
    internal static let kFINALRAW = "finalRaw"
    internal static let kFINALYEAR = "finalYear"

    /// - Parameters:
    ///   - topBundle: The main ICU zoneinfo resource bundle
    ///   - finalRuleBundle: The bundle containing the rule name/reference
    ///   - rawOffsetSeconds: The raw (standard) offset in seconds
    /// - Returns: A TimeZone configured with the DST rules, or nil if there's no DST rule (the time zone doesn't observe DST). Throws when parsing fails
    static func loadSimpleTimeZone(topBundle: ICU.ResourceBundle, finalRuleBundle: ICU.ResourceBundle, rawOffsetSeconds: Int32) throws(ICUError) -> _TimeZoneSingleDSTRule? {

        let ruleName = try finalRuleBundle.asString()

        // Empty rule name means no DST
        if ruleName.isEmpty {
            return nil
        }

        guard let rulesBundle = try topBundle.resourceBundle(forKey:kRULES) else {
            throw ICUError(code: U_INVALID_FORMAT_ERROR)
        }

        guard let ruleBundle = findRuleByName(rulesBundle: rulesBundle, ruleName: ruleName) else {
            throw ICUError(code: U_INVALID_FORMAT_ERROR)
        }

        // ICU DST rules are stored as integer vectors with the following format:
        // [month, dayOfWeekInMonth, dayOfWeek, time, timeMode, dstSavings, ...]
        let (startMonth, startDayOfWeekInMonth, startDayOfWeek, startTime, startTimeMode, endMonth, endDayOfWeekInMonth, endDayOfWeek, endTime, endTimeMode, dstSavingsSeconds) = try ruleBundle.withIntegers { ruleData throws(ICUError) in
            // ICU stores DST rules as exactly 11 integer values
            guard ruleData.count == 11 else {
                throw ICUError(code: U_INVALID_FORMAT_ERROR)
            }

            // Start rule: indices 0-4
            let startMonth = Int8(ruleData[0])          // 0-based month (0 == January)
            let startDayOfWeekInMonth = Int8(ruleData[1]) // e.g., 2 == second occurrence, -1 == last
            let startDayOfWeek = Int8(ruleData[2])      // 1 == Sunday, 2 == Monday, etc.
            let startTime = ruleData[3]                 // Time in seconds
            let startTimeMode = ruleData[4]             // 0 == wall time, 1 == standard, 2 == UTC

            // End rule: indices 5-9
            let endMonth = Int8(ruleData[5])
            let endDayOfWeekInMonth = Int8(ruleData[6])
            let endDayOfWeek = Int8(ruleData[7])
            let endTime = ruleData[8]                   // Time in seconds
            let endTimeMode = ruleData[9]

            let dstSavingsSeconds = ruleData[10]        // Savings in seconds
            return (startMonth, startDayOfWeekInMonth, startDayOfWeek, startTime, startTimeMode, endMonth, endDayOfWeekInMonth, endDayOfWeek, endTime, endTimeMode, dstSavingsSeconds)
        }

        guard let startMode = _TimeZoneSingleDSTRule.TimeMode(rawValue: Int(startTimeMode)),
                let endMode = _TimeZoneSingleDSTRule.TimeMode(rawValue: Int(endTimeMode)) else {
            throw ICUError(code: U_INVALID_FORMAT_ERROR)
        }

        do {
            let simpleTimeZone = try _TimeZoneSingleDSTRule(
                offsetSeconds: rawOffsetSeconds,
                dstSavingsSeconds: dstSavingsSeconds,
                startMonth: startMonth,
                startDay: startDayOfWeekInMonth,
                startDayOfWeek: startDayOfWeek,
                startTime: startTime,
                startTimeMode: startMode,
                endMonth: endMonth,
                endDay: endDayOfWeekInMonth,
                endDayOfWeek: endDayOfWeek,
                endTime: endTime,
                endTimeMode: endMode,
                startYear: 0  // Default start year
            )

            return simpleTimeZone

        } catch {
            throw .init(code: U_INVALID_FORMAT_ERROR)
        }
    }

    private static func findRuleByName(rulesBundle: ICU.ResourceBundle, ruleName: String) -> ICU.ResourceBundle? {
        // ICU Rules are typically stored as string arrays or tables
        
        // First, try as a direct lookup (table format)
        if let directRule = try? rulesBundle.resourceBundle(forKey:ruleName) {
            return directRule
        }

        // Fall back to linear search (array format)
        for i in 0..<rulesBundle.size {
            if let ruleEntry = try? rulesBundle.resourceBundle(forIndex:i) {
                precondition(ruleEntry.resourceType != URES_TABLE)
                if let entryName = try? ruleEntry.asString(), entryName == ruleName {
                    return ruleEntry
                }
            }
        }
        
        return nil
    }

    static let zoneInfoBundle: ICU.ResourceBundle? = {
        return try? ICU.ResourceBundle(packageName: nil, bundleName: kZONEINFO, direct: true)
    }()

    // Load timezone data using ICU UResourceBundle
    static func openOlsonTimeZoneResource(identifier: String) throws(ICUError) -> (top: ICU.ResourceBundle, res: ICU.ResourceBundle)  {

        guard let top = zoneInfoBundle else {
            throw ICUError(code: U_MISSING_RESOURCE_ERROR)
        }

        // Load the Names resource to find the zone index
        let missingResourceError = ICUError(code: U_MISSING_RESOURCE_ERROR)
        guard let names = try top.resourceBundle(forKey:kNAMES) else {
            throw missingResourceError
        }

        // Find the zone ID in the string array
        // `names` is the "Names" array in zoneinfo64.txt, and is alphabetically sorted in ascending order.
        guard let zoneIndex = findStringInAscendingSortedArray(names, string: identifier) else {
            throw missingResourceError
        }

        // Load the Zones resource
        guard let zones = try top.resourceBundle(forKey:kZONES) else {
            throw missingResourceError
        }

        // Get the specific zone by index
        guard let zoneBundle = try zones.resourceBundle(forIndex:zoneIndex) else {
            throw ICUError(code: U_INVALID_FORMAT_ERROR)
        }

        return (top, zoneBundle)
    }

    // Assumes `bundle` to be an array of strings, sorted in ascending order
    static func findStringInAscendingSortedArray(_ bundle: ICU.ResourceBundle, string identifier: String) -> Int32? {
        let size = bundle.size
        guard size > 0 else { return nil }
        
        var start: Int32 = 0
        var limit: Int32 = size
        var lastMid: Int32 = Int32.max
        
        while true {
            let mid = (start + limit) / 2
            if lastMid == mid {
                break
            }
            lastMid = mid
            
            do {
                guard let subBundle = try? bundle.resourceBundle(forIndex:mid) else {
                    break
                }
                let idString = try subBundle.asString()
                
                let comparison = identifier.compare(idString)
                if comparison == .orderedSame {
                    return mid // Found
                } else if comparison == .orderedAscending {
                    limit = mid
                } else {
                    start = mid
                }
            } catch {
                // Failed to get string from bundle, skip this entry
                break
            }
        }
        
        return nil // Not found
    }

    // Initialize from ICU resource bundle
    convenience init(identifier: String) throws(ICUError) {
        let (topBundle, resBundle) = try _TimeZoneRules.openOlsonTimeZoneResource(identifier: identifier)

        // Handle zone aliases
        var zoneBundle = resBundle
        if zoneBundle.resourceType == URES_INT {
            // This is an alias, dereference it
            let aliasIndex = try zoneBundle.asInteger()
            let zones = try topBundle.resourceBundle(forKey:_TimeZoneRules.kZONES)
            guard let zones, let actualZone = try zones.resourceBundle(forIndex:aliasIndex) else {
                throw ICUError(code: U_MISSING_RESOURCE_ERROR)
            }

            zoneBundle = actualZone
        }

        // Read transition data and combine into unified array
        // Get total count first, then fill in the content so we can write directly into an array
        var totalTransitionCount = 0
        // Pre-32bit second transitions (stored as high/low pairs)
        let transPre32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kTRANSPRE32)
        if let transPre32Bundle {
            let transitionCount = transPre32Bundle.withIntegers { transPre32 in
                return (transPre32.count / 2)
            }
            totalTransitionCount += transitionCount
        }

        // 32bit second transitions
        let trans32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kTRANS)
        if let trans32Bundle {
           let transitionCount = trans32Bundle.withIntegers {
                return $0.count
            }
            totalTransitionCount += transitionCount
        }

        // Post-32bit second transitions (stored as high/low pairs)
        let transPost32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kTRANSPOST32)
        if let transPost32Bundle {
            let transitionCount = transPost32Bundle.withIntegers {
                return $0.count / 2
            }
            totalTransitionCount += transitionCount
        }

        func unpackPair(first: Int32, second: Int32) -> Int64 {
            let high = UInt32(bitPattern: first)
            let low = UInt32(bitPattern: second)
            return Int64(high) << 32 | Int64(low)
        }

        let allTransitionTimes: [Int64] = totalTransitionCount == 0 ? [] : .init(capacity: totalTransitionCount, initializingWith: { buffer in
            if let transPre32Bundle {
                transPre32Bundle.withIntegers { transPre32 in
                    for i in stride(from: 0, to: transPre32.count, by: 2) {
                        buffer.append(unpackPair(first: transPre32[i], second: transPre32[i + 1]))
                    }
                }
            }

            // 32bit second transitions
            if let trans32Bundle {
                trans32Bundle.withIntegers { trans32 in
                    for i in 0 ..< trans32.count {
                        let timestamp = Int64(trans32[i])
                        buffer.append(timestamp)
                    }
                }
            }

            // Post-32bit second transitions (stored as high/low pairs)
            if let transPost32Bundle {
                transPost32Bundle.withIntegers { transPost32 in
                    for i in stride(from: 0, to: transPost32.count, by: 2) {
                        buffer.append(unpackPair(first: transPost32[i], second: transPost32[i + 1]))
                    }
                }
            }
        })


        // Type offsets (must be even size, >= 2)
        guard let typeOffsetsBundle = try zoneBundle.resourceBundle(forKey:_TimeZoneRules.kTYPEOFFSETS) else {
            throw .init(code: U_MISSING_RESOURCE_ERROR)
        }

        // Initialize consolidated timezone offset information
        let zoneOffsets = try typeOffsetsBundle.withIntegers { typeOffsetsArray throws(ICUError) in
            guard typeOffsetsArray.count >= 2 && typeOffsetsArray.count % 2 == 0 else {
                throw ICUError(code: U_INVALID_FORMAT_ERROR)
            }

            // Zone offset map data
            guard totalTransitionCount > 0 else {
                return _TimeZoneOffsets(
                    offsets: typeOffsetsArray,
                    offsetMap: nil,
                    identifier: identifier
                )
            }
            guard let typeMapBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kTYPEMAP) else {
                throw .init(code: U_MISSING_RESOURCE_ERROR)
            }

            return typeMapBundle.withBinary { offsetMap in
                _TimeZoneOffsets(
                    offsets: typeOffsetsArray,
                    offsetMap: offsetMap,
                    identifier: identifier
                )
            }
        }

        let finalZone: _TimeZoneSingleDSTRule?
        let finalStartDate: Date?

        // Final rule processing - load actual ICU Rules resource
        if let finalRawBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kFINALRAW),
           let finalYearBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kFINALYEAR),
           let finalRuleBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneRules.kFINALRULE) {

                let finalRaw = try finalRawBundle.asInteger()
                let finalYear = try finalYearBundle.asInteger()
                
                // Load the actual DST rule from ICU Rules resource
                finalZone = try _TimeZoneRules.loadSimpleTimeZone(
                    topBundle: topBundle,
                    finalRuleBundle: finalRuleBundle,
                    rawOffsetSeconds: finalRaw
                )

                // Calculate final start millis (January 1st of finalYear)
                let calendar = _CalendarGregorian(identifier: .gregorian, timeZone: TimeZone(inner: _TimeZoneGMT(secondsFromGMT: 0)!), locale: .unlocalized, firstWeekday: nil, minimumDaysInFirstWeek: nil, gregorianStartDate: nil)
                var components = DateComponents()
                components.year = Int(finalYear)
                components.month = 1
                components.day = 1
                guard let finalStart = calendar.date(from: components) else {
                    preconditionFailure("Unexpected nil final zone start date")
                }
                finalStartDate = finalStart
        } else {
            // No final rule - timezone has fixed offset after last transition
            finalZone = nil
            finalStartDate = nil
        }

        self.init(identifier: identifier, allTransitionTimes: allTransitionTimes, zoneOffsets: zoneOffsets, finalZone: finalZone, finalStartDate: finalStartDate)
    }
}

#endif // ICU
