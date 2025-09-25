//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Synchronization)
internal import Synchronization
#endif

@available(FoundationPreview 6.4, *)
extension ProgressManager {
    
//    @_specialize(where V == Int, S == Int)
    internal struct MetatypeWrapper<V: Sendable, S: Sendable>: Hashable, Equatable, Sendable {
        
        let reduce: @Sendable (inout S, V) -> ()
        let merge: @Sendable (S, S) -> S
        let finalSummary: @Sendable (S, S) -> S
        
        let defaultValue: V
        let defaultSummary: S
        
        let key: String
        
        init<P: Property>(_ argument: P.Type) where P.Value == V, P.Summary == S {
            reduce = P.reduce
            merge = P.merge
            finalSummary = P.finalSummary
            defaultValue = P.defaultValue
            defaultSummary = P.defaultSummary
            key = P.key
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
        
        static func == (lhs: ProgressManager.MetatypeWrapper<V, S>, rhs: ProgressManager.MetatypeWrapper<V, S>) -> Bool {
            lhs.key == rhs.key
        }
    }
    
    internal struct PropertyStateInt {
        var value: Int
        var isDirty: Bool
    }
    
    internal struct PropertyStateUInt64 {
        var value: UInt64
        var isDirty: Bool
    }
    
    internal struct PropertyStateThroughput {
        var value: [UInt64]
        var isDirty: Bool
    }
    
    internal struct PropertyStateDuration {
        var value: Duration
        var isDirty: Bool
    }
    
    internal struct PropertyStateDouble {
        var value: Double
        var isDirty: Bool
    }
    
    internal struct PropertyStateString {
        var value: [String?]
        var isDirty: Bool
    }
    
    internal struct PropertyStateURL {
        var value: [URL?]
        var isDirty: Bool
    }
    
    internal struct Child {
        weak var manager: ProgressManager?
        // portion of self's totalCount assigned to child
        var assignedCount: Int
        var fraction: ProgressFraction
        var isFractionDirty: Bool
        // Summary of additional properties
        var totalFileCountSummary: PropertyStateInt
        var completedFileCountSummary: PropertyStateInt
        var totalByteCountSummary: PropertyStateUInt64
        var completedByteCountSummary: PropertyStateUInt64
        var throughputSummary: PropertyStateThroughput
        var estimatedTimeRemainingSummary: PropertyStateDuration
        // Summary of custom additional properties
        var customPropertiesIntSummary: [MetatypeWrapper<Int, Int>: PropertyStateInt]
        var customPropertiesUInt64Summary: [MetatypeWrapper<UInt64, UInt64>: PropertyStateUInt64]
        var customPropertiesDoubleSummary: [MetatypeWrapper<Double, Double>: PropertyStateDouble]
        var customPropertiesStringSummary: [MetatypeWrapper<String?, [String?]>: PropertyStateString]
        var customPropertiesURLSummary: [MetatypeWrapper<URL?, [URL?]>: PropertyStateURL]
        var customPropertiesUInt64ArraySummary: [MetatypeWrapper<UInt64, [UInt64]>: PropertyStateThroughput]
        var customPropertiesDurationSummary: [MetatypeWrapper<Duration, Duration>: PropertyStateDuration]
    }
    
    internal struct Parent {
        var manager: ProgressManager
        // self's position in parent's children list
        var positionInParent: Int
    }
    
    internal struct State {
        var selfFraction: ProgressFraction
        var overallFraction: ProgressFraction {
            var overallFraction = selfFraction
            for child in children {
                if !child.fraction.isFinished {
                    let multiplier = ProgressFraction(completed: child.assignedCount, total: selfFraction.total)
                    if let additionalFraction = multiplier * child.fraction {
                        overallFraction = overallFraction + additionalFraction
                    }
                }
            }
            return overallFraction
        }
        var children: [Child]
        var parents: [Parent]
        // Value of additional properties
        var totalFileCount: Int
        var completedFileCount: Int
        var totalByteCount: UInt64
        var completedByteCount: UInt64
        var throughput: UInt64
        var estimatedTimeRemaining: Duration
        // Value of custom additional properties
        var customPropertiesInt: [MetatypeWrapper<Int, Int>: Int]
        var customPropertiesUInt64: [MetatypeWrapper<UInt64, UInt64>: UInt64]
        var customPropertiesDouble: [MetatypeWrapper<Double, Double>: Double]
        var customPropertiesString: [MetatypeWrapper<String?, [String?]>: String?]
        var customPropertiesURL: [MetatypeWrapper<URL?, [URL?]>: URL?]
        var customPropertiesUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>: UInt64]
        var customPropertiesDuration: [MetatypeWrapper<Duration, Duration>: Duration]
#if FOUNDATION_FRAMEWORK
        var observers: [@Sendable (ObserverState) -> Void]
        var interopType: InteropType?
#endif

        /// Returns nil if `self` was instantiated without total units;
        /// returns a `Int` value otherwise.
        internal var totalCount: Int? {
#if FOUNDATION_FRAMEWORK
            if let interopTotalCount = interopType?.totalCount {
                return interopTotalCount
            }
#endif
            return selfFraction.total
        }
        
        /// Returns 0 if `self` has `nil` total units;
        /// returns a `Int` value otherwise.
        internal mutating func completedCount() -> Int {
#if FOUNDATION_FRAMEWORK
            if let interopCompletedCount = interopType?.completedCount {
                return interopCompletedCount
            }
#endif
            updateChildrenProgressFraction()
            return selfFraction.completed
        }
        
        internal mutating func fractionCompleted() -> Double {
#if FOUNDATION_FRAMEWORK
            if let interopFractionCompleted = interopType?.fractionCompleted {
                return interopFractionCompleted
            }
#endif
            updateChildrenProgressFraction()
            return overallFraction.fractionCompleted
        }
        
        internal var isIndeterminate: Bool {
#if FOUNDATION_FRAMEWORK
            if let interopIsIndeterminate = interopType?.isIndeterminate {
                return interopIsIndeterminate
            }
#endif
            return selfFraction.isIndeterminate
        }
        
        internal mutating func isFinished() -> Bool {
#if FOUNDATION_FRAMEWORK
            if let interopIsFinished = interopType?.isFinished {
                return interopIsFinished
            }
#endif
            updateChildrenProgressFraction()
            return selfFraction.isFinished
        }
        
        internal mutating func updateChildrenProgressFraction() {
            guard !children.isEmpty else {
                return
            }
            
            for (idx, child) in children.enumerated() {
                if child.isFractionDirty {
                    if let child = child.manager {
                        let updatedProgressFraction = child.updatedProgressFraction()
                        let wasFinished = children[idx].fraction.isFinished
                        children[idx].fraction = updatedProgressFraction
                        // Only add to selfFraction if transitioning from unfinished to finished
                        if updatedProgressFraction.isFinished && !wasFinished {
                            selfFraction.completed += children[idx].assignedCount
                        }
                    } else {
                        let wasFinished = children[idx].fraction.isFinished
                        if !wasFinished {
                            selfFraction.completed += children[idx].assignedCount
                            // Mark nil child as finished to avoid any double counting
                            children[idx].fraction = ProgressFraction(
                                completed: children[idx].assignedCount,
                                total: children[idx].assignedCount
                            )
                        }
                    }
                    children[idx].isFractionDirty = false
                }
            }
        }
        
        internal mutating func complete(by count: Int) {
            selfFraction.completed += count

#if FOUNDATION_FRAMEWORK
            switch interopType {
            case .interopObservation(let observation):
                observation.subprogressBridge?.manager.notifyObservers(
                    with: ObserverState(
                        totalCount: selfFraction.total ?? 0,
                        completedCount: selfFraction.completed
                    )
                )
                
                if let _ = observation.reporterBridge {
                    notifyObservers(
                        with: ObserverState(
                            totalCount: selfFraction.total ?? 0,
                            completedCount: selfFraction.completed
                        )
                    )
                }
            case .interopMirror:
                break
            default:
                break
            }
#endif
        }
        
        // MARK: Mark paths dirty
        internal mutating func markChildDirty(at position: Int) -> [Parent]? {
            guard position >= 0 && position < children.count else {
                return nil
            }
            guard !children[position].isFractionDirty else {
                return nil
            }
            children[position].isFractionDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<Int, Int>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesIntSummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<UInt64, UInt64>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesUInt64Summary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<Double, Double>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesDoubleSummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<String?, [String?]>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesStringSummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<URL?, [URL?]>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesURLSummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<UInt64, [UInt64]>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesUInt64ArraySummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<Duration, Duration>, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].customPropertiesDurationSummary[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.TotalFileCount.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].totalFileCountSummary.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.CompletedFileCount.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].completedFileCountSummary.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.TotalByteCount.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].totalByteCountSummary.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.CompletedByteCount.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].completedByteCountSummary.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.Throughput.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].throughputSummary.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, at position: Int) -> [Parent] {
            guard position >= 0 && position < children.count else {
                return parents
            }
            children[position].estimatedTimeRemainingSummary.isDirty = true
            return parents
        }
        
        // MARK: Clean up dirty paths
        internal struct IntSummaryUpdateInfo {
            let currentSummary: Int
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: Int, isAlive: Bool)]
            let property: MetatypeWrapper<Int, Int>
        }
        
        internal struct IntSummaryUpdate {
            let index: Int
            let updatedSummary: Int
        }
        
        internal struct UInt64SummaryUpdateInfo {
            let currentSummary: UInt64
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: UInt64, isAlive: Bool)]
            let property: MetatypeWrapper<UInt64, UInt64>
        }
        
        internal struct UInt64SummaryUpdate {
            let index: Int
            let updatedSummary: UInt64
        }
        
        internal struct DoubleSummaryUpdateInfo {
            let currentSummary: Double
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: Double, isAlive: Bool)]
            let property: MetatypeWrapper<Double, Double>
        }
        
        internal struct DoubleSummaryUpdate {
            let index: Int
            let updatedSummary: Double
        }
        
        internal struct StringSummaryUpdateInfo {
            let currentSummary: [String?]
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: [String?], isAlive: Bool)]
            let property: MetatypeWrapper<String?, [String?]>
        }
        
        internal struct StringSummaryUpdate {
            let index: Int
            let updatedSummary: [String?]
        }
        
        internal struct URLSummaryUpdateInfo {
            let currentSummary: [URL?]
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: [URL?], isAlive: Bool)]
            let property: MetatypeWrapper<URL?, [URL?]>
        }
        
        internal struct URLSummaryUpdate {
            let index: Int
            let updatedSummary: [URL?]
        }
        
        internal struct UInt64ArraySummaryUpdateInfo {
            let currentSummary: [UInt64]
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: [UInt64], isAlive: Bool)]
            let property: MetatypeWrapper<UInt64, [UInt64]>
        }
        
        internal struct UInt64ArraySummaryUpdate {
            let index: Int
            let updatedSummary: [UInt64]
        }
        
        internal struct DurationSummaryUpdateInfo {
            let currentSummary: Duration
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: Duration, isAlive: Bool)]
            let property: MetatypeWrapper<Duration, Duration>
        }
        
        internal struct DurationSummaryUpdate {
            let index: Int
            let updatedSummary: Duration
        }
        
        internal struct FileCountUpdateInfo {
            let currentSummary: Int
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: Int, isAlive: Bool)]
            let type: CountType
        }
        
        internal struct FileCountUpdate {
            let index: Int
            let updatedSummary: Int
        }
        
        internal struct ByteCountUpdateInfo {
            let currentSummary: UInt64
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: UInt64, isAlive: Bool)]
            let type: CountType
        }
        
        internal struct ByteCountUpdate {
            let index: Int
            let updatedSummary: UInt64
        }
        
        internal struct ThroughputUpdateInfo {
            let currentSummary: [UInt64]
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: [UInt64], isAlive: Bool)]
        }
        
        internal struct ThroughputUpdate {
            let index: Int
            let updatedSummary: [UInt64]
        }
        
        internal struct EstimatedTimeRemainingUpdateInfo {
            let currentSummary: Duration
            let dirtyChildren: [(index: Int, manager: ProgressManager)]
            let nonDirtySummaries: [(index: Int, summary: Duration, isAlive: Bool)]
        }
        
        internal struct EstimatedTimeRemainingUpdate {
            let index: Int
            let updatedSummary: Duration
        }
        
        internal mutating func getIntSummaryUpdateInfo(property: MetatypeWrapper<Int, Int>) -> IntSummaryUpdateInfo {
            var currentSummary: Int = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesInt[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return IntSummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: Int, isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesIntSummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return IntSummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateIntSummary(_ updateInfo: IntSummaryUpdateInfo, _ childUpdates: [IntSummaryUpdate]) -> Int {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesIntSummary[updateInfo.property] = PropertyStateInt(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getUInt64SummaryUpdateInfo(property: MetatypeWrapper<UInt64, UInt64>) -> UInt64SummaryUpdateInfo {
            var currentSummary: UInt64 = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesUInt64[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return UInt64SummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: UInt64, isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesUInt64Summary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return UInt64SummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateUInt64Summary(_ updateInfo: UInt64SummaryUpdateInfo, _ childUpdates: [UInt64SummaryUpdate]) -> UInt64 {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesUInt64Summary[updateInfo.property] = PropertyStateUInt64(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getDoubleSummaryUpdateInfo(property: MetatypeWrapper<Double, Double>) -> DoubleSummaryUpdateInfo {
            var currentSummary: Double = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesDouble[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return DoubleSummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: Double, isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesDoubleSummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return DoubleSummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateDoubleSummary(_ updateInfo: DoubleSummaryUpdateInfo, _ childUpdates: [DoubleSummaryUpdate]) -> Double {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesDoubleSummary[updateInfo.property] = PropertyStateDouble(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getStringSummaryUpdateInfo(property: MetatypeWrapper<String?, [String?]>) -> StringSummaryUpdateInfo {
            var currentSummary: [String?] = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesString[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return StringSummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: [String?], isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesStringSummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return StringSummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateStringSummary(_ updateInfo: StringSummaryUpdateInfo, _ childUpdates: [StringSummaryUpdate]) -> [String?] {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesStringSummary[updateInfo.property] = PropertyStateString(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getURLSummaryUpdateInfo(property: MetatypeWrapper<URL?, [URL?]>) -> URLSummaryUpdateInfo {
            var currentSummary: [URL?] = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesURL[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return URLSummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: [URL?], isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesURLSummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return URLSummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateURLSummary(_ updateInfo: URLSummaryUpdateInfo, _ childUpdates: [URLSummaryUpdate]) -> [URL?] {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesURLSummary[updateInfo.property] = PropertyStateURL(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getUInt64ArraySummaryUpdateInfo(property: MetatypeWrapper<UInt64, [UInt64]>) -> UInt64ArraySummaryUpdateInfo {
            var currentSummary: [UInt64] = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesUInt64Array[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return UInt64ArraySummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: [UInt64], isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesUInt64ArraySummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return UInt64ArraySummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateUInt64ArraySummary(_ updateInfo: UInt64ArraySummaryUpdateInfo, _ childUpdates: [UInt64ArraySummaryUpdate]) -> [UInt64] {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesUInt64ArraySummary[updateInfo.property] = PropertyStateThroughput(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getDurationSummaryUpdateInfo(property: MetatypeWrapper<Duration, Duration>) -> DurationSummaryUpdateInfo {
            var currentSummary: Duration = property.defaultSummary
            property.reduce(&currentSummary, customPropertiesDuration[property] ?? property.defaultValue)
            
            guard !children.isEmpty else {
                return DurationSummaryUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: [],
                    property: property
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: Duration, isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if let childPropertyState = child.customPropertiesDurationSummary[property] {
                    if childPropertyState.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, childPropertyState.value, isAlive))
                    }
                } else {
                    // Property doesn't exist yet in child - need to fetch it
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                }
            }
            
            return DurationSummaryUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                property: property
            )
        }
        
        internal mutating func updateDurationSummary(_ updateInfo: DurationSummaryUpdateInfo, _ childUpdates: [DurationSummaryUpdate]) -> Duration {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].customPropertiesDurationSummary[updateInfo.property] = PropertyStateDuration(value: update.updatedSummary, isDirty: false)
                value = updateInfo.property.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = updateInfo.property.merge(value, childSummary)
                } else {
                    value = updateInfo.property.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getFileCountUpdateInfo(type: CountType) -> FileCountUpdateInfo {
            let currentSummary: Int
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: Int, isAlive: Bool)] = []
            
            switch type {
            case .total:
                var value: Int = 0
                ProgressManager.Properties.TotalFileCount.reduce(into: &value, value: totalFileCount)
                currentSummary = value
                
                guard !children.isEmpty else {
                    return FileCountUpdateInfo(
                        currentSummary: currentSummary,
                        dirtyChildren: [],
                        nonDirtySummaries: [],
                        type: type
                    )
                }
                
                for (idx, child) in children.enumerated() {
                    if child.totalFileCountSummary.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, child.totalFileCountSummary.value, isAlive))
                    }
                }
                
            case .completed:
                var value: Int = 0
                ProgressManager.Properties.CompletedFileCount.reduce(into: &value, value: completedFileCount)
                currentSummary = value
                
                guard !children.isEmpty else {
                    return FileCountUpdateInfo(
                        currentSummary: currentSummary,
                        dirtyChildren: [],
                        nonDirtySummaries: [],
                        type: type
                    )
                }
                
                for (idx, child) in children.enumerated() {
                    if child.completedFileCountSummary.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, child.completedFileCountSummary.value, isAlive))
                    }
                }
            }
            
            return FileCountUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                type: type
            )
        }
        
        internal mutating func updateFileCount(_ updateInfo: FileCountUpdateInfo, _ childUpdates: [FileCountUpdate]) -> Int {
            var value = updateInfo.currentSummary
            
            switch updateInfo.type {
            case .total:
                // Apply updates from children that were dirty
                for update in childUpdates {
                    children[update.index].totalFileCountSummary = PropertyStateInt(value: update.updatedSummary, isDirty: false)
                    value = ProgressManager.Properties.TotalFileCount.merge(value, update.updatedSummary)
                }
                
                // Apply values from non-dirty children
                for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                    if isAlive {
                        value = ProgressManager.Properties.TotalFileCount.merge(value, childSummary)
                    } else {
                        value = ProgressManager.Properties.TotalFileCount.finalSummary(value, childSummary)
                    }
                }
                
            case .completed:
                // Apply updates from children that were dirty
                for update in childUpdates {
                    children[update.index].completedFileCountSummary = PropertyStateInt(value: update.updatedSummary, isDirty: false)
                    value = ProgressManager.Properties.CompletedFileCount.merge(value, update.updatedSummary)
                }
                
                // Apply values from non-dirty children
                for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                    if isAlive {
                        value = ProgressManager.Properties.CompletedFileCount.merge(value, childSummary)
                    } else {
                        value = ProgressManager.Properties.CompletedFileCount.finalSummary(value, childSummary)
                    }
                }
            }
            
            return value
        }
        
        internal mutating func getByteCountUpdateInfo(type: CountType) -> ByteCountUpdateInfo {
            let currentSummary: UInt64
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: UInt64, isAlive: Bool)] = []
            
            switch type {
            case .total:
                var value: UInt64 = 0
                ProgressManager.Properties.TotalByteCount.reduce(into: &value, value: totalByteCount)
                currentSummary = value
                
                guard !children.isEmpty else {
                    return ByteCountUpdateInfo(
                        currentSummary: currentSummary,
                        dirtyChildren: [],
                        nonDirtySummaries: [],
                        type: type
                    )
                }
                
                for (idx, child) in children.enumerated() {
                    if child.totalByteCountSummary.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, child.totalByteCountSummary.value, isAlive))
                    }
                }
                
            case .completed:
                var value: UInt64 = 0
                ProgressManager.Properties.CompletedByteCount.reduce(into: &value, value: completedByteCount)
                currentSummary = value
                
                guard !children.isEmpty else {
                    return ByteCountUpdateInfo(
                        currentSummary: currentSummary,
                        dirtyChildren: [],
                        nonDirtySummaries: [],
                        type: type
                    )
                }
                
                for (idx, child) in children.enumerated() {
                    if child.completedByteCountSummary.isDirty {
                        if let child = child.manager {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = child.manager != nil
                        nonDirtySummaries.append((idx, child.completedByteCountSummary.value, isAlive))
                    }
                }
            }
            
            return ByteCountUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries,
                type: type
            )
        }
        
        internal mutating func updateByteCount(_ updateInfo: ByteCountUpdateInfo, _ childUpdates: [ByteCountUpdate]) -> UInt64 {
            var value = updateInfo.currentSummary
            
            switch updateInfo.type {
            case .total:
                // Apply updates from children that were dirty
                for update in childUpdates {
                    children[update.index].totalByteCountSummary = PropertyStateUInt64(value: update.updatedSummary, isDirty: false)
                    value = ProgressManager.Properties.TotalByteCount.merge(value, update.updatedSummary)
                }
                
                // Apply values from non-dirty children
                for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                    if isAlive {
                        value = ProgressManager.Properties.TotalByteCount.merge(value, childSummary)
                    } else {
                        value = ProgressManager.Properties.TotalByteCount.finalSummary(value, childSummary)
                    }
                }
                
            case .completed:
                // Apply updates from children that were dirty
                for update in childUpdates {
                    children[update.index].completedByteCountSummary = PropertyStateUInt64(value: update.updatedSummary, isDirty: false)
                    value = ProgressManager.Properties.CompletedByteCount.merge(value, update.updatedSummary)
                }
                
                // Apply values from non-dirty children
                for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                    if isAlive {
                        value = ProgressManager.Properties.CompletedByteCount.merge(value, childSummary)
                    } else {
                        value = ProgressManager.Properties.CompletedByteCount.finalSummary(value, childSummary)
                    }
                }
            }
            
            return value
        }
        
        internal mutating func getThroughputUpdateInfo() -> ThroughputUpdateInfo {
            var currentSummary = ProgressManager.Properties.Throughput.defaultSummary
            ProgressManager.Properties.Throughput.reduce(into: &currentSummary, value: throughput)
            
            guard !children.isEmpty else {
                return ThroughputUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: []
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: [UInt64], isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if child.throughputSummary.isDirty {
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                } else {
                    let isAlive = child.manager != nil
                    nonDirtySummaries.append((idx, child.throughputSummary.value, isAlive))
                }
            }
            
            return ThroughputUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries
            )
        }
        
        internal mutating func updatedThroughput(_ updateInfo: ThroughputUpdateInfo, _ childUpdates: [ThroughputUpdate]) -> [UInt64] {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].throughputSummary = PropertyStateThroughput(value: update.updatedSummary, isDirty: false)
                value = ProgressManager.Properties.Throughput.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = ProgressManager.Properties.Throughput.merge(value, childSummary)
                } else {
                    value = ProgressManager.Properties.Throughput.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        internal mutating func getEstimatedTimeRemainingUpdateInfo() -> EstimatedTimeRemainingUpdateInfo {
            var currentSummary: Duration = Duration.seconds(0)
            ProgressManager.Properties.EstimatedTimeRemaining.reduce(into: &currentSummary, value: estimatedTimeRemaining)
            
            guard !children.isEmpty else {
                return EstimatedTimeRemainingUpdateInfo(
                    currentSummary: currentSummary,
                    dirtyChildren: [],
                    nonDirtySummaries: []
                )
            }
            
            var dirtyChildren: [(index: Int, manager: ProgressManager)] = []
            var nonDirtySummaries: [(index: Int, summary: Duration, isAlive: Bool)] = []
            
            for (idx, child) in children.enumerated() {
                if child.estimatedTimeRemainingSummary.isDirty {
                    if let child = child.manager {
                        dirtyChildren.append((idx, child))
                    }
                } else {
                    let isAlive = child.manager != nil
                    nonDirtySummaries.append((idx, child.estimatedTimeRemainingSummary.value, isAlive))
                }
            }
            
            return EstimatedTimeRemainingUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries
            )
        }
        
        internal mutating func updateEstimatedTimeRemaining(_ updateInfo: EstimatedTimeRemainingUpdateInfo, _ childUpdates: [EstimatedTimeRemainingUpdate]) -> Duration {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].estimatedTimeRemainingSummary = PropertyStateDuration(value: update.updatedSummary, isDirty: false)
                value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, update.updatedSummary)
            }
            
            // Apply values from non-dirty children
            for (_, childSummary, isAlive) in updateInfo.nonDirtySummaries {
                if isAlive {
                    value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, childSummary)
                } else {
                    value = ProgressManager.Properties.EstimatedTimeRemaining.finalSummary(value, childSummary)
                }
            }
            
            return value
        }
        
        struct FinalSummary {
            var totalFileCountSummary:  Int
            var completedFileCountSummary: Int
            var totalByteCountSummary: UInt64
            var completedByteCountSummary: UInt64
            var throughputSummary: [UInt64]
            var estimatedTimeRemainingSummary: Duration
            var customPropertiesIntSummary: [MetatypeWrapper<Int, Int>: Int]
            var customPropertiesUInt64Summary: [MetatypeWrapper<UInt64, UInt64>: UInt64]
            var customPropertiesDoubleSummary: [MetatypeWrapper<Double, Double>: Double]
            var customPropertiesStringSummary: [MetatypeWrapper<String?, [String?]>: [String?]]
            var customPropertiesURLSummary: [MetatypeWrapper<URL?, [URL?]>: [URL?]]
            var customPropertiesUInt64ArraySummary: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]]
            var customPropertiesDurationSummary: [MetatypeWrapper<Duration, Duration>: Duration]
        }
        
        func customPropertiesCleanup() -> (FinalSummary, [Parent]) {
            // Set up default summaries
            var totalFileCount = Properties.TotalFileCount.defaultSummary
            var completedFileCount = Properties.CompletedFileCount.defaultSummary
            var totalByteCount = Properties.TotalByteCount.defaultSummary
            var completedByteCount = Properties.CompletedByteCount.defaultSummary
            var throughput = Properties.Throughput.defaultSummary
            var estimatedTimeRemaining = Properties.EstimatedTimeRemaining.defaultSummary
            var customPropertiesIntSummary: [MetatypeWrapper<Int, Int>: Int] = [:]
            var customPropertiesUInt64Summary: [MetatypeWrapper<UInt64, UInt64>: UInt64] = [:]
            var customPropertiesDoubleSummary: [MetatypeWrapper<Double, Double>: Double] = [:]
            var customPropertiesStringSummary: [MetatypeWrapper<String?, [String?]>: [String?]] = [:]
            var customPropertiesURLSummary: [MetatypeWrapper<URL?, [URL?]>: [URL?]] = [:]
            var customPropertiesUInt64ArraySummary: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]] = [:]
            var customPropertiesDurationSummary: [MetatypeWrapper<Duration, Duration>: Duration] = [:]
        
            // Include self's custom properties values
            Properties.TotalFileCount.reduce(into: &totalFileCount, value: self.totalFileCount)
            Properties.CompletedFileCount.reduce(into: &completedFileCount, value: self.completedFileCount)
            Properties.TotalByteCount.reduce(into: &totalByteCount, value: self.totalByteCount)
            Properties.CompletedByteCount.reduce(into: &completedByteCount, value: self.completedByteCount)
            Properties.Throughput.reduce(into: &throughput, value: self.throughput)
            Properties.EstimatedTimeRemaining.reduce(into: &estimatedTimeRemaining, value: self.estimatedTimeRemaining)
            
            // MARK: Custom Properties (Int, Int)
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesInt {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)
                
                // Save summary to dictionary
                customPropertiesIntSummary[key] = summary
            }
            
            // MARK: Custom Properties (UInt64, UInt64)
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesUInt64 {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)
            
                // Save summary to dictionary
                customPropertiesUInt64Summary[key] = summary
            }
            
            // MARK: Custom Properties (UInt64, [UInt64])
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesUInt64Array {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)

                // Save summary to dictionary
                customPropertiesUInt64ArraySummary[key] = summary
            }
            
            // MARK: Custom Properties (Double, Double)
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesDouble {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)

                // Save summary to dictionary
                customPropertiesDoubleSummary[key] = summary
            }
            
            // MARK: Custom Properties (String?, [String?])
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesString {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)

                // Save summary to dictionary
                customPropertiesStringSummary[key] = summary
            }
            
            // MARK: Custom Properties (URL?, [URL?])
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesURL {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)

                // Save summary to dictionary
                customPropertiesURLSummary[key] = summary
            }
            
            // MARK: Custom Properties (Duration, Duration)
            // Aggregate information using self's custom property keys
            for (key, value) in customPropertiesDuration {
                // Set up overall summary
                var summary = key.defaultSummary
                
                // Include self's value into summary
                key.reduce(&summary, value)
                
                // Save summary to dictionary
                customPropertiesDurationSummary[key] = summary
            }
            
            // Include child's custom properties summaries, we need to take into account the fact that some of the children's custom properties may not be in self, so we need to check that too. As for the ones that are in self, we need to call finalSummary.
            for child in children {
                totalFileCount = Properties.TotalFileCount.finalSummary(totalFileCount, child.totalFileCountSummary.value)
                completedFileCount = Properties.CompletedFileCount.finalSummary(completedFileCount, child.completedFileCountSummary.value)
                totalByteCount = Properties.TotalByteCount.finalSummary(totalByteCount, child.totalByteCountSummary.value)
                completedByteCount = Properties.CompletedByteCount.finalSummary(completedByteCount, child.completedByteCountSummary.value)
                throughput = Properties.Throughput.finalSummary(throughput, child.throughputSummary.value)
                estimatedTimeRemaining = Properties.EstimatedTimeRemaining.finalSummary(estimatedTimeRemaining, child.estimatedTimeRemainingSummary.value)
                
                for (key, _) in customPropertiesInt {
                    customPropertiesIntSummary[key] = key.finalSummary(customPropertiesIntSummary[key] ?? key.defaultSummary, child.customPropertiesIntSummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesIntSummary {
                    if !customPropertiesInt.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesIntSummary[key] = summary
                    }
                }
                
                
                for (key, _) in customPropertiesUInt64 {
                    customPropertiesUInt64Summary[key] = key.finalSummary(customPropertiesUInt64Summary[key] ?? key.defaultSummary, child.customPropertiesUInt64Summary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesUInt64Summary {
                    if !customPropertiesUInt64.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesUInt64Summary[key] = summary
                    }
                }
                
            
                for (key, _) in customPropertiesUInt64Array {
                    customPropertiesUInt64ArraySummary[key] = key.finalSummary(customPropertiesUInt64ArraySummary[key] ?? key.defaultSummary, child.customPropertiesUInt64ArraySummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesUInt64ArraySummary {
                    if !customPropertiesUInt64Array.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesUInt64ArraySummary[key] = summary
                    }
                }
                
                for (key, _) in customPropertiesDouble {
                    customPropertiesDoubleSummary[key] = key.finalSummary(customPropertiesDoubleSummary[key] ?? key.defaultSummary, child.customPropertiesDoubleSummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesDoubleSummary {
                    if !customPropertiesDouble.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesDoubleSummary[key] = summary
                    }
                }
                
                for (key, _) in customPropertiesString {
                    customPropertiesStringSummary[key] = key.finalSummary(customPropertiesStringSummary[key] ?? key.defaultSummary, child.customPropertiesStringSummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesStringSummary {
                    if !customPropertiesString.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesStringSummary[key] = summary
                    }
                }
                
                for (key, _) in customPropertiesURL {
                    customPropertiesURLSummary[key] = key.finalSummary(customPropertiesURLSummary[key] ?? key.defaultSummary, child.customPropertiesURLSummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesURLSummary {
                    if !customPropertiesURL.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesURLSummary[key] = summary
                    }
                }
                
                for (key, _) in customPropertiesDuration {
                    customPropertiesDurationSummary[key] = key.finalSummary(customPropertiesDurationSummary[key] ?? key.defaultSummary, child.customPropertiesDurationSummary[key]?.value ?? key.defaultSummary)
                }
                
                // Aggregate information using child's custom property keys that may be absent from self's custom property keys
                for (key, value) in child.customPropertiesDurationSummary {
                    if !customPropertiesDuration.keys.contains(key) {
                        // Set up default summary
                        var summary = key.defaultSummary
                        // Include child's value
                        summary = key.finalSummary(summary, value.value)
                        // Save summary value to dictionary
                        customPropertiesDurationSummary[key] = summary
                    }
                }
            }
            
            return (FinalSummary(totalFileCountSummary: totalFileCount,
                                 completedFileCountSummary: completedFileCount,
                                 totalByteCountSummary: totalByteCount,
                                 completedByteCountSummary: completedByteCount,
                                 throughputSummary: throughput,
                                 estimatedTimeRemainingSummary: estimatedTimeRemaining,
                                 customPropertiesIntSummary: customPropertiesIntSummary,
                                 customPropertiesUInt64Summary: customPropertiesUInt64Summary,
                                 customPropertiesDoubleSummary: customPropertiesDoubleSummary,
                                 customPropertiesStringSummary: customPropertiesStringSummary,
                                 customPropertiesURLSummary: customPropertiesURLSummary,
                                 customPropertiesUInt64ArraySummary: customPropertiesUInt64ArraySummary,
                                 customPropertiesDurationSummary: customPropertiesDurationSummary
                                ),
                    parents)
        }
    }
}
