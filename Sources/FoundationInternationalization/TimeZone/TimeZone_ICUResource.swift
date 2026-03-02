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

#if canImport(_FoundationICU)
internal import _FoundationICU
#endif


struct _TimeZoneOffsets: Sendable {
    // Fixed offset timezone rule (equivalent to ICU's simple rules)
    // All available fixed offset timezone rules. Values are in seconds.
    private let fixedOffsetRules: [(rawOffset: Int, dstSavings: Int)]

    // Maps transition indices to `fixedOffsetRules` indices
    private let transitionRuleMap: [UInt8]?

    var count: Int { fixedOffsetRules.count }

    // Initialize from ICU raw data
    // Caller is responsible to validate that `offsets` has >= 2 elements
    init(offsets: Span<Int32>, offsetMap: Span<UInt8>?, identifier: String) {
        precondition(offsets.count >= 2)

        self.fixedOffsetRules = .init(capacity: offsets.count / 2, initializingWith: { buffer in
            for i in stride(from: 0, to: offsets.count, by: 2) {
                buffer.append((Int(offsets[i]), Int(offsets[i + 1])))
            }
        })

        self.transitionRuleMap = offsetMap?.withUnsafeBufferPointer { Array($0) }
    }
    
    // Get offsets for a specific transition
    // - Parameter transitionIndex: The index of the transition
    // - Returns: The timezone offsets that applies after this transition
    func offsets(at transitionIndex: Int) -> (rawOffset: Int, dstSavings: Int) {
        // Handle case where transitionIndex is -1 (can happen with local time disambiguation)
        guard transitionIndex >= 0 else {
            // Before all transitions - return initial/default offset
            return fixedOffsetRules[0]
        }
        
        guard let typeMap = transitionRuleMap, transitionIndex < typeMap.count else {
            // No transitions or invalid index - return first offset (default)
            return fixedOffsetRules[0]
        }
        
        let typeIndex = Int(typeMap[transitionIndex])
        guard typeIndex < fixedOffsetRules.count else {
            return fixedOffsetRules[0]
        }
        
        return fixedOffsetRules[typeIndex]
    }

    func zoneOffset(at transitionIndex: Int) -> Int64 {
        let offsets = offsets(at: transitionIndex)
        return Int64(offsets.rawOffset + offsets.dstSavings)
    }

    // Get the initial/default offset (used before any transitions)
    var initialOffsets: (rawOffset: Int, dstSavings: Int) {
        return fixedOffsetRules[0]
    }
}


// Includes IANA timezone data with historical transitions
// This class is backed by ICU's timezone resources, but has its own implementation that does not use ICU's timezone class
internal final class _TimeZoneICUResource: Sendable {

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

    // MARK: -

    let identifier: String

    // All transitions in chronological order (in seconds)
    let allTransitionTimes: [Int64]

    let zoneOffsets: _TimeZoneOffsets

    let finalZone: _TimeZoneSingleDSTRule?
    let finalStartDate: Date?

    // MARK: - ICU Resource Loading
    
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
    
    // MARK: - Initialization from ICU UResourceBundle
    
    // Initialize from ICU resource bundle
    init(identifier: String) throws(ICUError) {
        self.identifier = identifier

        let (topBundle, resBundle) = try _TimeZoneICUResource.openOlsonTimeZoneResource(identifier: identifier)

        // Handle zone aliases
        var zoneBundle = resBundle
        if zoneBundle.resourceType == URES_INT {
            // This is an alias, dereference it
            let aliasIndex = try zoneBundle.asInteger()
            let zones = try topBundle.resourceBundle(forKey:_TimeZoneICUResource.kZONES)
            guard let zones, let actualZone = try zones.resourceBundle(forIndex:aliasIndex) else {
                throw ICUError(code: U_MISSING_RESOURCE_ERROR)
            }

            zoneBundle = actualZone
        }

        // Read transition data and combine into unified array
        // Get total count first, then fill in the content so we can write directly into an array
        var totalTransitionCount = 0
        // Pre-32bit second transitions (stored as high/low pairs)
        let transPre32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kTRANSPRE32)
        if let transPre32Bundle {
            let transitionCount = transPre32Bundle.withIntegers { transPre32 in
                return (transPre32.count / 2)
            }
            totalTransitionCount += transitionCount
        }

        // 32bit second transitions
        let trans32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kTRANS)
        if let trans32Bundle {
           let transitionCount = trans32Bundle.withIntegers {
                return $0.count
            }
            totalTransitionCount += transitionCount
        }

        // Post-32bit second transitions (stored as high/low pairs)
        let transPost32Bundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kTRANSPOST32)
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

        self.allTransitionTimes = totalTransitionCount == 0 ? [] : .init(capacity: totalTransitionCount, initializingWith: { buffer in
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
        guard let typeOffsetsBundle = try zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kTYPEOFFSETS) else {
            throw .init(code: U_MISSING_RESOURCE_ERROR)
        }

        // Initialize consolidated timezone offset information
        self.zoneOffsets = try typeOffsetsBundle.withIntegers { typeOffsetsArray throws(ICUError) in
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
            guard let typeMapBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kTYPEMAP) else {
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

        // Final rule processing - load actual ICU Rules resource
        if let finalRawBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kFINALRAW),
           let finalYearBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kFINALYEAR),
           let finalRuleBundle = try? zoneBundle.resourceBundle(forKey:_TimeZoneICUResource.kFINALRULE) {

                let finalRaw = try finalRawBundle.asInteger()
                let finalYear = try finalYearBundle.asInteger()
                
                // Load the actual DST rule from ICU Rules resource
                self.finalZone = try _TimeZoneICUResource.loadSimpleTimeZone(
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
                self.finalStartDate = finalStart
        } else {
            // No final rule - timezone has fixed offset after last transition
            self.finalZone = nil
            self.finalStartDate = nil
        }

    }
    
    // MARK: - Timezone Methods

    func rawAndDSTOffset(for date: Date, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (Int, Int) {
        let (rawOffset, dstOffset) = getOffset(date: date, local: true, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)
        return (Int(rawOffset), Int(dstOffset))
    }

    func secondsFromGMT(for date: Date) -> Int {
        guard Date.validCalendarRange.contains(date) else {
            // TODO: We should throw an error properly, but for now return 0 just like how we handle this when calling into ICU timezone
            return 0
        }
        let (rawOffset, dstOffset) = getOffset(date: date, local: false)
        return Int((rawOffset + dstOffset))
    }
    
    func isDaylightSavingTime(for date: Date) -> Bool {
        let (_, dstOffset) = getOffset(date: date, local: false)
        return dstOffset != 0
    }
    
    func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        let (_, dstOffset) = getOffset(date: date, local: false)
        return TimeInterval(dstOffset)
    }
    
    // MARK: - Offset Calculation

    func rawAndDaylightSavingTimeOffset(for date: Date, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        let res = getOffset(date: date, local: true, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)
        return (Int(res.rawOffset), Double(res.dstSavings))
    }

    // Entry point for offset calculation that delegates to either historical or final zone
    // Returns: offsets in seconds
    func getOffset(date: Date, local: Bool, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (rawOffset: Int, dstSavings: Int) {
        // Check if we should use final zone first
        if let finalZone, let finalStartDate, date >= finalStartDate {
            return finalZone.rawAndDaylightSavingTimeOffset(for: date, local: local, duplicatedTimePolicy: duplicatedTimePolicy, nonExistingTimePolicy: nonExistingTimePolicy)
        }
        
        // Otherwise use historical data
        return historicalOffsets(date: date, local: local, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)
    }
    
    // MARK: - Historical Offset Calculation

    func historicalOffsets(date: Date, local: Bool, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy) -> (rawOffset: Int, dstSavings: Int) {
        let transCount = allTransitionTimes.count
        guard transCount > 0 else {
            // No transitions, single pair of offsets only
            return (initialRawOffset, initialDSTOffset)
        }

        let sec = Int64(date.timeIntervalSince1970.rounded(.down))
        if !local, let firstTransitionTime = allTransitionTimes.first, sec < firstTransitionTime {
            // Before the first transition time
            return (initialRawOffset, initialDSTOffset)
        }

        let transIdx = binarySearchTransition(secondsSinceEpoch: sec, local: local, start: 0, end: transCount - 1, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)

        return offsetsAt(transIdx)
    }

    func transitionTimeInSeconds(at index: Int) -> Int64 {
        precondition(index >= 0 && index < allTransitionTimes.count, "Transition index \(index) out of range [0..<\(allTransitionTimes.count)]")

        return allTransitionTimes[index]
    }
    
    // MARK: - Zone offset Information Access

    // Get total timezone offset (raw + DST) for a transition
    func zoneOffset(at transitionIndex: Int) -> Int64 {
        zoneOffsets.zoneOffset(at: transitionIndex)
    }
    
    // Get timezone offset information for a transition
    // This provides both raw and DST offsets in one efficient call
    func offsetsAt(_ transitionIndex: Int) -> (rawOffset: Int, dstSavings: Int) {
        zoneOffsets.offsets(at: transitionIndex)
    }
    

    // MARK: - Transition Discovery Methods
    
    // Find the next timezone transition after the given base date
    // - Parameters:
    //   - after: The base date to search after
    //   - inclusive: If true, include transitions that occur exactly at the base time
    // - Returns: The next transition, or nil if no transition is found
    func nextTransition(after base: Date, inclusive: Bool) -> Date? {
        // Check if we should use final zone first
        if let finalZone {
            if inclusive, let firstFinalTZTransition, base == firstFinalTZTransition {
                return firstFinalTZTransition
            } else if let finalStartDate, base >= finalStartDate {
                // Delegate to final zone for future transitions
                if finalZone.useDaylight {
                    // Use the final zone to get the next DST transition, or nil if there's no more transitions in final zone
                    return finalZone.dstTransition(after: base, inclusive: inclusive) ?? nil
                } else {
                    // Final zone has no DST - no more transitions
                    return nil
                }
            }
        }
        
        // Search historical transitions
        return nextHistoricalTransition(after: base, inclusive: inclusive)
    }
    
    // MARK: - Historical Transition Search (Direct Port from olsontz.cpp)
    
    // Lazy computed first historical transition
    private var firstTZTransition: Date? {
        guard allTransitionTimes.count > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(transitionTimeInSeconds(at: 0)))
    }

    // Returns the first transition occuring within the final zone; one of the following:
    // - first DST transition if the final zone observes DST
    // - start date of the final zone
    // - nil if there's no final zone
    private var firstFinalTZTransition: Date? {
        guard let finalZone else {
            return nil
        }

        guard finalZone.useDaylight else {
            // No DST transitions in final zone, use standard time
            return finalStartDate
        }

        // Get the first transition from the final zone
        if let finalStartDate, let firstTransition = finalZone.dstTransition(after: finalStartDate, inclusive: false) {
            return firstTransition
        } else {
            // No DST transitions in final zone, use standard time
            return finalStartDate
        }
    }

    // Find next historical transition
    // Follows ICU's backward search algorithm for now.
    // TODO: This can be optimized with binary search
    private func nextHistoricalTransition(after base: Date, inclusive: Bool) -> Date? {
        let transCount = allTransitionTimes.count
        guard transCount > 0 else {
            return nil
        }

        let baseSec = Int64(base.timeIntervalSince1970.rounded(.down))
        var ttidx = transCount - 1
        
        // Find the last transition that is <= base (or < base if not inclusive)
        while ttidx >= 0 {
            let transitionSec = transitionTimeInSeconds(at: ttidx)
            if baseSec > transitionSec || (!inclusive && baseSec == transitionSec) {
                break
            }
            ttidx -= 1
        }

        if ttidx == transCount - 1 {
            // We're past the last historical transition
            return firstFinalTZTransition
        } else if ttidx < 0 {
            // We're before the first transition
            return firstTZTransition
        } else {
            // Return the transition at ttidx + 1 (the next one after ttidx)
            let nextIdx = ttidx + 1
            guard nextIdx < transCount else { 
                return nil 
            }

            let fromOffsets = offsetsAt(ttidx)
            let toOffsets = offsetsAt(nextIdx)
            // Check for non-transition data (same offsets)
            if fromOffsets == toOffsets {
                // Skip non-transitions and recursively search
                let nextBase = Date(timeIntervalSince1970: TimeInterval(transitionTimeInSeconds(at: nextIdx)))

                return nextHistoricalTransition(after: nextBase, inclusive: false)
            }
            
            let transitionTime = Date(timeIntervalSince1970: TimeInterval(transitionTimeInSeconds(at: nextIdx)))
            return transitionTime
        }
    }
    
    // Returns the index of the transition that applies to the given time
    private func binarySearchTransition(
        secondsSinceEpoch sec: Int64,
        local: Bool,
        start: Int,
        end: Int,
        nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former,
        duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former
    ) -> Int {
        var left = start
        var right = end
        
        // Binary search to find the last transition <= sec
        while left <= right {
            let mid = left + (right - left) / 2
            var transition = transitionTimeInSeconds(at: mid)

            if local && (sec >= (transition - 86400)) {
                let offsetBefore = zoneOffset(at: mid - 1)
                let offsetAfter = zoneOffset(at: mid)

                if offsetAfter - offsetBefore >= 0 {
                    switch nonExistingTimePolicy {
                    case .former:
                        transition += offsetAfter
                    case .latter:
                        transition += offsetBefore
                    }
                } else {
                    // Negative transition (fall back) - creates duplicated time range
                    switch duplicatedTimePolicy {
                    case .former:
                        transition += offsetBefore
                    case .latter:
                        transition += offsetAfter
                    }
                }
            }
            
            if transition <= sec {
                // This transition might be the one we want, but check if there's a later one
                if mid == allTransitionTimes.count - 1 {
                    // This is the last transition
                    return mid
                }
                
                var nextTransition = transitionTimeInSeconds(at: mid + 1)
                
                // Apply the same disambiguation logic to the next transition
                if local && (sec >= (nextTransition - 86400)) {
                    let nextOffsetBefore = zoneOffset(at: mid)
                    let nextOffsetAfter = zoneOffset(at: mid + 1)

                    if nextOffsetAfter - nextOffsetBefore >= 0 {
                        switch nonExistingTimePolicy {
                        case .former:
                            nextTransition += nextOffsetAfter
                        case .latter:
                            nextTransition += nextOffsetBefore
                        }

                    } else {
                        switch duplicatedTimePolicy {
                        case .former:
                            nextTransition += nextOffsetBefore
                        case .latter:
                            nextTransition += nextOffsetAfter
                        }
                    }
                }
                
                if nextTransition > sec {
                    // Found it: mid's transition applies, next one doesn't
                    return mid
                } else {
                    // Need to search further right
                    left = mid + 1
                }
            } else {
                // This transition is too late, search left
                right = mid - 1
            }
        }
        
        // If we get here, sec is before all transitions
        return right
    }

    
    // Get the initial raw offset (before any transitions)
    var initialRawOffset: Int {
        return zoneOffsets.initialOffsets.rawOffset
    }
    
    // Get the initial DST offset (before any transitions)
    var initialDSTOffset: Int {
        return zoneOffsets.initialOffsets.dstSavings
    }
}
