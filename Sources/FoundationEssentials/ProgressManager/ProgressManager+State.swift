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
internal import Synchronization

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
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
    
    internal struct ChildState {
        weak var child: ProgressManager?
        var portionOfTotal: Int
        var childFraction: ProgressFraction
        var isDirty: Bool
        var totalFileCount: PropertyStateInt
        var completedFileCount: PropertyStateInt
        var totalByteCount: PropertyStateUInt64
        var completedByteCount: PropertyStateUInt64
        var throughput: PropertyStateThroughput
        var estimatedTimeRemaining: PropertyStateDuration
        var childPropertiesInt: [MetatypeWrapper<Int, Int>: PropertyStateInt]
        var childPropertiesDouble: [MetatypeWrapper<Double, Double>: PropertyStateDouble]
        var childPropertiesString: [MetatypeWrapper<String?, [String?]>: PropertyStateString]
        var childPropertiesURL: [MetatypeWrapper<URL?, [URL?]>: PropertyStateURL]
        var childPropertiesUInt64: [MetatypeWrapper<UInt64, [UInt64]>: PropertyStateThroughput]
    }
    
    internal struct ParentState {
        var parent: ProgressManager
        var positionInParent: Int
    }
    
    internal struct State {
        var selfFraction: ProgressFraction
        var overallFraction: ProgressFraction {
            var overallFraction = selfFraction
            for childState in children {
                if let _ = childState.child {
                    if !childState.childFraction.isFinished {
                        let multiplier = ProgressFraction(completed: childState.portionOfTotal, total: selfFraction.total)
                        if let additionalFraction = multiplier * childState.childFraction {
                            overallFraction = overallFraction + additionalFraction
                        }
                    }
                }
            }
            return overallFraction
        }
        var children: [ChildState]
        var parents: [ParentState]
        var totalFileCount: Int
        var completedFileCount: Int
        var totalByteCount: UInt64
        var completedByteCount: UInt64
        var throughput: UInt64
        var estimatedTimeRemaining: Duration
        var propertiesInt: [MetatypeWrapper<Int, Int>: Int]
        var propertiesDouble: [MetatypeWrapper<Double, Double>: Double]
        var propertiesString: [MetatypeWrapper<String?, [String?]>: String?]
        var propertiesURL: [MetatypeWrapper<URL?, [URL?]>: URL?]
        var propertiesUInt64: [MetatypeWrapper<UInt64, [UInt64]>: UInt64]
#if FOUNDATION_FRAMEWORK
        var observers: [@Sendable (ObserverState) -> Void]
        var interopType: InteropType?
#endif

        /// Returns nil if `self` was instantiated without total units;
        /// returns a `Int` value otherwise.
        internal func getTotalCount() -> Int? {
#if FOUNDATION_FRAMEWORK
            if let interopTotalCount = interopType?.totalCount {
                return interopTotalCount
            }
#endif
            return selfFraction.total
        }
        
        /// Returns 0 if `self` has `nil` total units;
        /// returns a `Int` value otherwise.
        internal mutating func getCompletedCount() -> Int {
#if FOUNDATION_FRAMEWORK
            if let interopCompletedCount = interopType?.completedCount {
                return interopCompletedCount
            }
#endif
            updateChildrenProgressFraction()
            return selfFraction.completed
        }
        
        internal mutating func getFractionCompleted() -> Double {
#if FOUNDATION_FRAMEWORK
            if let interopFractionCompleted = interopType?.fractionCompleted {
                return interopFractionCompleted
            }
#endif
            updateChildrenProgressFraction()
            return overallFraction.fractionCompleted
        }
        
        internal func getIsIndeterminate() -> Bool {
#if FOUNDATION_FRAMEWORK
            if let interopIsIndeterminate = interopType?.isIndeterminate {
                return interopIsIndeterminate
            }
#endif
            return selfFraction.isIndeterminate
        }
        
        internal mutating func getIsFinished() -> Bool {
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
            for (idx, childState) in children.enumerated() {
                if childState.isDirty {
                    if let child = childState.child {
                        let updatedProgressFraction = child.getUpdatedProgressFraction()
                        children[idx].childFraction = updatedProgressFraction
                        if updatedProgressFraction.isFinished {
                            selfFraction.completed += children[idx].portionOfTotal
                        }
                    } else {
                        selfFraction.completed += children[idx].portionOfTotal
                    }
                    children[idx].isDirty = false
                }
            }
        }
        
        internal mutating func complete(by count: Int) {
            selfFraction.completed += count

#if FOUNDATION_FRAMEWORK
            switch interopType {
            case .interopObservation(let observation):
                observation.subprogressBridge?.manager.notifyObservers(
                    with: .fractionUpdated(
                        totalCount: selfFraction.total ?? 0,
                        completedCount: selfFraction.completed
                    )
                )
                
                if let _ = observation.reporterBridge {
                    notifyObservers(
                        with: .fractionUpdated(
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
        internal mutating func markChildDirty(at position: Int) -> [ParentState]? {
            guard !children[position].isDirty else {
                return nil
            }
            children[position].isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<Int, Int>, at position: Int) -> [ParentState] {
            children[position].childPropertiesInt[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<Double, Double>, at position: Int) -> [ParentState] {
            children[position].childPropertiesDouble[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<String?, [String?]>, at position: Int) -> [ParentState] {
            children[position].childPropertiesString[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<URL?, [URL?]>, at position: Int) -> [ParentState] {
            children[position].childPropertiesURL[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: MetatypeWrapper<UInt64, [UInt64]>, at position: Int) -> [ParentState] {
            children[position].childPropertiesUInt64[property]?.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.TotalFileCount.Type, at position: Int) -> [ParentState] {
            children[position].totalFileCount.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.CompletedFileCount.Type, at position: Int) -> [ParentState] {
            children[position].completedFileCount.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.TotalByteCount.Type, at position: Int) -> [ParentState] {
            children[position].totalByteCount.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.CompletedByteCount.Type, at position: Int) -> [ParentState] {
            children[position].completedByteCount.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.Throughput.Type, at position: Int) -> [ParentState] {
            children[position].throughput.isDirty = true
            return parents
        }
        
        internal mutating func markChildDirty(property: ProgressManager.Properties.EstimatedTimeRemaining.Type, at position: Int) -> [ParentState] {
            children[position].estimatedTimeRemaining.isDirty = true
            return parents
        }
        
        // MARK: Clean up dirty paths
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
                
                for (idx, childState) in children.enumerated() {
                    if childState.totalByteCount.isDirty {
                        if let child = childState.child {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = childState.child != nil
                        nonDirtySummaries.append((idx, childState.totalByteCount.value, isAlive))
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
                
                for (idx, childState) in children.enumerated() {
                    if childState.completedByteCount.isDirty {
                        if let child = childState.child {
                            dirtyChildren.append((idx, child))
                        }
                    } else {
                        let isAlive = childState.child != nil
                        nonDirtySummaries.append((idx, childState.completedByteCount.value, isAlive))
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
                    children[update.index].totalByteCount = PropertyStateUInt64(value: update.updatedSummary, isDirty: false)
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
                    children[update.index].completedByteCount = PropertyStateUInt64(value: update.updatedSummary, isDirty: false)
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
            
            for (idx, childState) in children.enumerated() {
                if childState.throughput.isDirty {
                    if let child = childState.child {
                        dirtyChildren.append((idx, child))
                    }
                } else {
                    let isAlive = childState.child != nil
                    nonDirtySummaries.append((idx, childState.throughput.value, isAlive))
                }
            }
            
            return ThroughputUpdateInfo(
                currentSummary: currentSummary,
                dirtyChildren: dirtyChildren,
                nonDirtySummaries: nonDirtySummaries
            )
        }
        
        internal mutating func getUpdatedThroughput(_ updateInfo: ThroughputUpdateInfo, _ childUpdates: [ThroughputUpdate]) -> [UInt64] {
            var value = updateInfo.currentSummary
            
            // Apply updates from children that were dirty
            for update in childUpdates {
                children[update.index].throughput = PropertyStateThroughput(value: update.updatedSummary, isDirty: false)
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
            
            for (idx, childState) in children.enumerated() {
                if childState.estimatedTimeRemaining.isDirty {
                    if let child = childState.child {
                        dirtyChildren.append((idx, child))
                    }
                } else {
                    let isAlive = childState.child != nil
                    nonDirtySummaries.append((idx, childState.estimatedTimeRemaining.value, isAlive))
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
                children[update.index].estimatedTimeRemaining = PropertyStateDuration(value: update.updatedSummary, isDirty: false)
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
    }
}
