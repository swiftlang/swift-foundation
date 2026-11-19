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

extension TimeZone {
    package enum Error: Swift.Error {
        case dateOverflow
        case dateUnderflow
    }
}

extension Date {
    // Returns nil if it's out of Int64 bound
    package func secondsSince1970() throws(TimeZone.Error) -> Int64 {
        let sec = timeIntervalSince1970.rounded(.down)

        guard sec < Double(Int64.max) else {
            throw .dateOverflow
        }

        guard sec >= Double(Int64.min) else {
            throw .dateUnderflow
        }

        return Int64(sec)
    }

    package func checkBounds() throws(TimeZone.Error) {
        _ = try self.secondsSince1970()
    }
}

package struct _TimeZoneOffsets: Sendable {
    // Fixed offset timezone rule
    // All available fixed offset timezone rules. Values are in seconds.
    private let fixedOffsetRules: [(rawOffset: Int, dstSavings: Int)]

    // Maps transition indices to `fixedOffsetRules` indices
    private let transitionRuleMap: [UInt8]?

    package var count: Int { fixedOffsetRules.count }

    // Caller is responsible to validate that `offsets` has >= 2 elements
    package init(offsets: Span<Int32>, offsetMap: Span<UInt8>?, identifier: String) {
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
    package func offsets(at transitionIndex: Int) -> (rawOffset: Int, dstSavings: Int) {
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

    package func zoneOffset(at transitionIndex: Int) -> Int64 {
        let offsets = offsets(at: transitionIndex)
        return Int64(offsets.rawOffset + offsets.dstSavings)
    }

    // Get the initial/default offset (used before any transitions)
    package var initialOffsets: (rawOffset: Int, dstSavings: Int) {
        return fixedOffsetRules[0]
    }
}


/// Time zone data made up of historical transitions, a table of (raw offset, DST savings) pairs, and an optional final DST rule.
/// Data can come from any source (e.g. ICU's `zoneinfo64` resource, or provided directly).
package final class _TimeZoneRules: Sendable {
    package let identifier: String

    // All transitions in chronological order (in seconds)
    package let allTransitionTimes: [Int64]

    package let zoneOffsets: _TimeZoneOffsets

    package let finalZone: _TimeZoneSingleDSTRule?
    package let finalStartDate: Date?

    package init(identifier: String, allTransitionTimes: [Int64], zoneOffsets: _TimeZoneOffsets, finalZone: _TimeZoneSingleDSTRule?, finalStartDate: Date?) {
        self.identifier = identifier
        self.allTransitionTimes = allTransitionTimes
        self.zoneOffsets = zoneOffsets
        self.finalZone = finalZone
        self.finalStartDate = finalStartDate
    }

    // MARK: - Timezone Methods

    package func rawAndDSTOffset(for date: Date, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) -> (Int, Int) {
        guard let result = try? getOffset(date: date, local: true, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy) else {
            return (0, 0)
        }
        return (Int(result.rawOffset), Int(result.dstSavings))
    }

    package func secondsFromGMT(for date: Date) -> Int {
        guard let (rawOffset, dstOffset) = try? getOffset(date: date, local: false) else {
            // TODO: We should throw an error properly, but for now return 0 just like how we handle this when calling into ICU timezone
            return 0
        }
        return Int((rawOffset + dstOffset))
    }
    
    package func isDaylightSavingTime(for date: Date) -> Bool {
        guard let (_, dstOffset) = try? getOffset(date: date, local: false) else {
            return false
        }
        return dstOffset != 0
    }
    
    package func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        guard let (_, dstOffset) = try? getOffset(date: date, local: false) else {
            return 0
        }
        return TimeInterval(dstOffset)
    }
    
    // MARK: - Offset Calculation

    package func rawAndDaylightSavingTimeOffset(for date: Date, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) throws(TimeZone.Error) -> (rawOffset: Int, daylightSavingOffset: TimeInterval) {
        let res = try getOffset(date: date, local: true, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)
        return (Int(res.rawOffset), Double(res.dstSavings))
    }

    // Entry point for offset calculation that delegates to either historical or final zone
    // Returns: offsets in seconds
    package func getOffset(date: Date, local: Bool, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy = .former, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy = .former) throws(TimeZone.Error) -> (rawOffset: Int, dstSavings: Int) {
        // Check if we should use final zone first
        if let finalZone, let finalStartDate, date >= finalStartDate {
            return try finalZone.rawAndDaylightSavingTimeOffset(for: date, local: local, duplicatedTimePolicy: duplicatedTimePolicy, nonExistingTimePolicy: nonExistingTimePolicy)
        }
        
        // Otherwise use historical data
        return try historicalOffsets(date: date, local: local, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)
    }
    
    // MARK: - Historical Offset Calculation

    package func historicalOffsets(date: Date, local: Bool, nonExistingTimePolicy: TimeZone.DaylightSavingTimePolicy, duplicatedTimePolicy: TimeZone.DaylightSavingTimePolicy) throws(TimeZone.Error)-> (rawOffset: Int, dstSavings: Int) {
        let transCount = allTransitionTimes.count
        guard transCount > 0 else {
            // No transitions, single pair of offsets only
            return (initialRawOffset, initialDSTOffset)
        }

        let sec = try date.secondsSince1970()
        if !local, let firstTransitionTime = allTransitionTimes.first, sec < firstTransitionTime {
            // Before the first transition time
            return (initialRawOffset, initialDSTOffset)
        }

        let transIdx = binarySearchTransition(secondsSince1970: sec, local: local, start: 0, end: transCount - 1, nonExistingTimePolicy: nonExistingTimePolicy, duplicatedTimePolicy: duplicatedTimePolicy)

        return offsetsAt(transIdx)
    }

    package func transitionTimeInSeconds(at index: Int) -> Int64 {
        precondition(index >= 0 && index < allTransitionTimes.count, "Transition index \(index) out of range [0..<\(allTransitionTimes.count)]")

        return allTransitionTimes[index]
    }
    
    // MARK: - Zone offset Information Access

    // Get total timezone offset (raw + DST) for a transition
    package func zoneOffset(at transitionIndex: Int) -> Int64 {
        zoneOffsets.zoneOffset(at: transitionIndex)
    }
    
    // Get timezone offset information for a transition
    // This provides both raw and DST offsets in one efficient call
    package func offsetsAt(_ transitionIndex: Int) -> (rawOffset: Int, dstSavings: Int) {
        zoneOffsets.offsets(at: transitionIndex)
    }
    

    // MARK: - Transition Search Methods
    
    // Find the next timezone transition after the given base date
    // - Parameters:
    //   - after: The base date to search after
    // - Returns: The next transition, or nil if no transition is found
    package func nextTransition(after base: Date) -> Date? {
        // Check if we should use final zone first
        if let finalZone {
            if let finalStartDate, base >= finalStartDate {
                // Delegate to final zone for future transitions
                if finalZone.useDaylight {
                    // Use the final zone to get the next DST transition, or nil if there's no more transitions in final zone
                    return finalZone.dstTransition(after: base)
                } else {
                    // Final zone has no DST - no more transitions
                    return nil
                }
            }
        }
        
        if let firstTransition = self.firstTZTransition, base < firstTransition {
            return firstTransition
        }
        
        guard let baseSec = try? base.secondsSince1970() else {
            return nil
        }
        
        // Search historical transitions
        return nextHistoricalTransition(afterTimeIntervalSince1970: baseSec)
    }
    
    // MARK: - Historical Transition Search
    
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
    private func nextHistoricalTransition(afterTimeIntervalSince1970 baseSec: Int64) -> Date? {
        let transCount = allTransitionTimes.count
        guard transCount > 0 else {
            return nil
        }

        
        // Find the last transition that is <= base
        var left = 0
        var right = transCount - 1
        var ttidx = -1
        
        while left <= right {
            let mid = left + (right - left) / 2
            let transitionSec = allTransitionTimes[mid]
            
            if transitionSec <= baseSec {
                ttidx = mid
                left = mid + 1
            } else {
                right = mid - 1
            }
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
                let nextBase = transitionTimeInSeconds(at: nextIdx)

                return nextHistoricalTransition(afterTimeIntervalSince1970: nextBase)
            }
            
            let transitionTime = Date(timeIntervalSince1970: TimeInterval(transitionTimeInSeconds(at: nextIdx)))
            return transitionTime
        }
    }
    
    // Returns the index of the transition that applies to the given time
    private func binarySearchTransition(
        secondsSince1970 sec: Int64,
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
    package var initialRawOffset: Int {
        return zoneOffsets.initialOffsets.rawOffset
    }
    
    // Get the initial DST offset (before any transitions)
    package var initialDSTOffset: Int {
        return zoneOffsets.initialOffsets.dstSavings
    }
}

extension _TimeZoneRules {
    /// Creates rules from plain arrays, with no final (recurring) DST rule.
    /// - Parameters:
    ///   - transitions: Transition times in seconds since 1970, ascending.
    ///   - typeOffsets: Flattened (rawOffset, dstSavings) pairs in seconds. The first pair applies before the first transition.
    ///   - typeMap: For each transition, the index of the pair in `typeOffsets` that applies after it. Required if `transitions` is not empty.
    ///   - finalZone: The recurring DST rule that applies from `finalStartDate` on, if any.
    ///   - finalStartDate: When `finalZone` takes over from the listed transitions.
    package convenience init(identifier: String, transitions: [Int64], typeOffsets: [Int32], typeMap: [UInt8]?, finalZone: _TimeZoneSingleDSTRule? = nil, finalStartDate: Date? = nil) {
        precondition(typeOffsets.count >= 2 && typeOffsets.count % 2 == 0)
        precondition(transitions.isEmpty || typeMap?.count == transitions.count)
        let offsets = _TimeZoneOffsets(offsets: typeOffsets.span, offsetMap: transitions.isEmpty ? nil : typeMap?.span, identifier: identifier)
        self.init(identifier: identifier, allTransitionTimes: transitions, zoneOffsets: offsets, finalZone: finalZone, finalStartDate: finalStartDate)
    }
}
