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

import Observation
#if canImport(Synchronization)
internal import Synchronization
#endif

#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

/// An object that conveys ongoing progress to the user for a specified task.
@available(FoundationPreview 6.4, *)
@dynamicMemberLookup
@Observable public final class ProgressManager: Sendable {
    
    internal let state: Mutex<State>
    internal let additionalPropertiesSink: Void
    internal let additionalPropertiesSummarySink: Void
    internal let totalFileCountSummary: Void
    internal let completedFileCountSummary: Void
    internal let totalByteCountSummary: Void
    internal let completedByteCountSummary: Void
    internal let throughputSummary: Void
    internal let estimatedTimeRemainingSummary: Void
    
    /// The total units of work.
    public var totalCount: Int? {
        self.access(keyPath: \.totalCount)
        return state.withLock { state in
            state.totalCount
        }
    }
    
    /// The completed units of work.
    public var completedCount: Int {
        self.access(keyPath: \.completedCount)
        let (children, completedCount) =  state.withLock { state in
            (state.children.compactMap { $0.manager }, state.completedCount())
        }
        for child in children {
            child.access(keyPath: \.completedCount)
        }
        return completedCount
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.0.
    public var fractionCompleted: Double {
        self.access(keyPath: \.totalCount)
        self.access(keyPath: \.completedCount)
        let (children, fractionCompleted) = state.withLock { state in
            (state.children.compactMap { $0.manager }, state.fractionCompleted())
        }
        for child in children {
            child.access(keyPath: \.totalCount)
            child.access(keyPath: \.completedCount)
        }
        return fractionCompleted
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        self.access(keyPath: \.totalCount)
        return state.withLock { state in
            state.isIndeterminate
        }
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        self.access(keyPath: \.totalCount)
        self.access(keyPath: \.completedCount)
        let (children, isFinished) = state.withLock { state in
            (state.children.compactMap { $0.manager }, state.isFinished())
        }
        for child in children {
            child.access(keyPath: \.totalCount)
            child.access(keyPath: \.completedCount)
        }
        return isFinished
    }
    
    /// A `ProgressReporter` instance, used for providing read-only observation of progress updates or composing into other `ProgressManager`s.
    public var reporter: ProgressReporter {
        return .init(manager: self)
    }
    
#if FOUNDATION_FRAMEWORK
    internal init(total: Int?, completed: Int?, subprogressBridge: SubprogressBridge?) {
        let state = State(
            selfFraction: ProgressFraction(completed: completed ?? 0, total: total),
            children: [],
            parents: [],
            totalFileCount: ProgressManager.Properties.TotalFileCount.defaultValue,
            completedFileCount: ProgressManager.Properties.CompletedFileCount.defaultValue,
            totalByteCount: ProgressManager.Properties.TotalByteCount.defaultValue,
            completedByteCount: ProgressManager.Properties.CompletedByteCount.defaultValue,
            throughput: ProgressManager.Properties.Throughput.defaultValue,
            estimatedTimeRemaining: ProgressManager.Properties.EstimatedTimeRemaining.defaultValue,
            customPropertiesInt: [:],
            customPropertiesUInt64: [:],
            customPropertiesDouble: [:],
            customPropertiesString: [:],
            customPropertiesURL: [:],
            customPropertiesUInt64Array: [:],
            customPropertiesDuration: [:],
            observers: [],
            interopType: .interopObservation(InteropObservation(subprogressBridge: subprogressBridge))
        )
        self.state = Mutex(state)
    }
#else
    internal init(total: Int?, completed: Int?) {
        let state = State(
            selfFraction: ProgressFraction(completed: completed ?? 0, total: total),
            children: [],
            parents: [],
            totalFileCount: ProgressManager.Properties.TotalFileCount.defaultValue,
            completedFileCount: ProgressManager.Properties.CompletedFileCount.defaultValue,
            totalByteCount: ProgressManager.Properties.TotalByteCount.defaultValue,
            completedByteCount: ProgressManager.Properties.CompletedByteCount.defaultValue,
            throughput: ProgressManager.Properties.Throughput.defaultValue,
            estimatedTimeRemaining: ProgressManager.Properties.EstimatedTimeRemaining.defaultValue,
            customPropertiesInt: [:],
            customPropertiesUInt64: [:],
            customPropertiesDouble: [:],
            customPropertiesString: [:],
            customPropertiesURL: [:],
            customPropertiesUInt64Array: [:],
            customPropertiesDuration: [:]
        )
        self.state = Mutex(state)
    }
#endif
    
    /// Initializes `self` with `totalCount`.
    ///
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    /// - Parameter totalCount: Total units of work.
    public convenience init(totalCount: Int?) {
        #if FOUNDATION_FRAMEWORK
        self.init(
            total: totalCount,
            completed: nil,
            subprogressBridge: nil
        )
        #else
        self.init(
            total: totalCount,
            completed: nil,
        )
        #endif
    }
    
    /// Returns a `Subprogress` representing a portion of `self` which can be passed to any method that reports progress.
    ///
    /// If the `Subprogress` is not converted into a `ProgressManager` (for example, due to an error or early return),
    /// then the assigned count is marked as completed in the parent `ProgressManager`.
    ///
    /// - Parameter count: The portion of `totalCount` to be delegated to the `Subprogress`.
    /// - Returns: A `Subprogress` instance.
    public func subprogress(assigningCount portionOfParent: Int) -> Subprogress {
        precondition(portionOfParent > 0, "Giving out zero units is not a valid operation.")
        let subprogress = Subprogress(parent: self, portionOfParent: portionOfParent)
        return subprogress
    }
    
    /// Adds a `ProgressReporter` as a child, with its progress representing a portion of `self`'s progress.
    ///
    /// If a cycle is detected, this will cause a crash at runtime.
    ///
    /// - Parameters:
    ///   - count: Units, which is a portion of `totalCount`delegated to an instance of `Subprogress`.
    ///   - reporter: A `ProgressReporter` instance.
    public func assign(count: Int, to reporter: ProgressReporter) {
        precondition(isCycle(reporter: reporter) == false, "Creating a cycle is not allowed.")
        
        let actualManager = reporter.manager
        
        let position = self.addChild(childManager: actualManager, assignedCount: count, childFraction: actualManager.getProgressFraction())
        actualManager.addParent(parentManager: self, positionInParent: position)
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        self.withMutation(keyPath: \.completedCount) {
            let parents: [Parent]? = state.withLock { state in
                guard state.selfFraction.completed != (state.selfFraction.completed + count) else {
                    return nil
                }
                
                state.complete(by: count)
                
                return state.parents
            }
            if let parents = parents {
                markSelfDirty(parents: parents)
            }
        }
    }
    
    public func setCounts(_ counts: (_ completed: inout Int, _ total: inout Int?) -> Void) {
        self.withMutation(keyPath: \.completedCount) {
            self.withMutation(keyPath: \.totalCount) {
                let parents: [Parent]? = state.withLock { state in
                    var completed = state.selfFraction.completed
                    var total = state.selfFraction.total
                    
                    counts(&completed, &total)
                    
                    guard state.selfFraction.completed != completed || state.selfFraction.total != total else {
                        return nil
                    }
                    
                    state.selfFraction.completed = completed
                    state.selfFraction.total = total
                    
                    return state.parents
                }
                
                if let parents = parents {
                    markSelfDirty(parents: parents)
                }
            }
        }
    }
    
    //MARK: Observation Methods
    internal func willSet<T>(keyPath: KeyPath<ProgressManager, T>) {
        _$observationRegistrar.willSet(self, keyPath: keyPath)
    }
    
    internal func didSet<T>(keyPath: KeyPath<ProgressManager, T>) {
        _$observationRegistrar.didSet(self, keyPath: keyPath)
    }

    //MARK: Fractional Properties Methods
    internal func getProgressFraction() -> ProgressFraction {
        return state.withLock { state in
            return state.selfFraction
        }
    }
    
    //MARK: Fractional Calculation methods
    internal func markSelfDirty() {
        let parents = state.withLock { state in
            return state.parents
        }
        markSelfDirty(parents: parents)
    }
    
    internal func markSelfDirty(parents: [Parent]) {
        if parents.count > 0 {
            for parent in parents {
                parent.manager.markChildDirty(at: parent.positionInParent)
            }
        }
    }
    
    private func markChildDirty(at position: Int) {
        let parents: [Parent]? = state.withLock { state in
            state.markChildDirty(at: position)
        }
        if let parents = parents {
            markSelfDirty(parents: parents)
        }
    }
    
    internal func updatedProgressFraction() -> ProgressFraction {
        return state.withLock { state in
            state.updateChildrenProgressFraction()
            return state.overallFraction
        }
    }
    
    //MARK: Parent - Child Relationship Methods
    internal func addChild(childManager: ProgressManager, assignedCount: Int, childFraction: ProgressFraction) -> Int {
        self.withMutation(keyPath: \.completedCount) {
            let (index, parents) = state.withLock { state in
                let child = Child(manager: childManager,
                                  assignedCount: assignedCount,
                                  fraction: childFraction,
                                  isFractionDirty: true,
                                  totalFileCountSummary: PropertyStateInt(value: ProgressManager.Properties.TotalFileCount.defaultSummary, isDirty: false),
                                  completedFileCountSummary: PropertyStateInt(value: ProgressManager.Properties.CompletedFileCount.defaultSummary, isDirty: false),
                                  totalByteCountSummary: PropertyStateUInt64(value: ProgressManager.Properties.TotalByteCount.defaultSummary, isDirty: false),
                                  completedByteCountSummary: PropertyStateUInt64(value: ProgressManager.Properties.CompletedByteCount.defaultSummary, isDirty: false),
                                  throughputSummary: PropertyStateThroughput(value: ProgressManager.Properties.Throughput.defaultSummary, isDirty: false),
                                  estimatedTimeRemainingSummary: PropertyStateDuration(value: ProgressManager.Properties.EstimatedTimeRemaining.defaultSummary, isDirty: false),
                                  customPropertiesIntSummary: [:],
                                  customPropertiesUInt64Summary: [:],
                                  customPropertiesDoubleSummary: [:],
                                  customPropertiesStringSummary: [:],
                                  customPropertiesURLSummary: [:],
                                  customPropertiesUInt64ArraySummary: [:],
                                  customPropertiesDurationSummary: [:])
                state.children.append(child)
                return (state.children.count - 1, state.parents)
            }
            // Mark dirty all the way up to the root so that if the branch was marked not dirty right before this it will be marked dirty again (for optimization to work)
            markSelfDirty(parents: parents)
            return index
        }
    }
    
    internal func addParent(parentManager: ProgressManager, positionInParent: Int) {
        state.withLock { state in
            let parent = Parent(manager: parentManager, positionInParent: positionInParent)
            state.parents.append(parent)
        }
    }
    
    // MARK: Cycle Detection Methods
    internal func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if reporter.manager === self {
            return true
        }
        
        let updatedVisited = visited.union([self])
        
        return state.withLock { state in
            for parent in state.parents {
                if !updatedVisited.contains(parent.manager) {
                    if (parent.manager.isCycle(reporter: reporter, visited: updatedVisited)) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    internal func isCycleInterop(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        return state.withLock { state in
            for parent in state.parents {
                if !visited.contains(parent.manager) {
                    if (parent.manager.isCycle(reporter: reporter, visited: visited)) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    deinit {
                
        let (propertiesInt, propertiesUInt64, propertiesDouble, propertiesString, propertiesURL, propertiesUInt64Array, propertiesDuration, parents) = state.withLock { state in
            return (state.customPropertiesInt, state.customPropertiesUInt64, state.customPropertiesDouble, state.customPropertiesString, state.customPropertiesURL, state.customPropertiesUInt64Array, state.customPropertiesDuration, state.parents)
        }
        
        var finalSummaryInt: [MetatypeWrapper<Int, Int>: Int] = [:]
        for property in propertiesInt.keys {
            let updatedSummary = self.updatedIntSummary(property: property)
            finalSummaryInt[property] = updatedSummary
        }
        
        var finalSummaryUInt64: [MetatypeWrapper<UInt64, UInt64>: UInt64] = [:]
        for property in propertiesUInt64.keys {
            let updatedSummary = self.updatedUInt64Summary(property: property)
            finalSummaryUInt64[property] = updatedSummary
        }
        
        var finalSummaryDouble: [MetatypeWrapper<Double, Double>: Double] = [:]
        for property in propertiesDouble.keys {
            let updatedSummary = self.updatedDoubleSummary(property: property)
            finalSummaryDouble[property] = updatedSummary
        }

        var finalSummaryString: [MetatypeWrapper<String?, [String?]>: [String?]] = [:]
        for property in propertiesString.keys {
            let updatedSummary = self.updatedStringSummary(property: property)
            finalSummaryString[property] = updatedSummary
        }
        
        var finalSummaryURL: [MetatypeWrapper<URL?, [URL?]>: [URL?]] = [:]
        for property in propertiesURL.keys {
            let updatedSummary = self.updatedURLSummary(property: property)
            finalSummaryURL[property] = updatedSummary
        }
        
        var finalSummaryUInt64Array: [MetatypeWrapper<UInt64, [UInt64]>: [UInt64]] = [:]
        for property in propertiesUInt64Array.keys {
            let updatedSummary = self.updatedUInt64ArraySummary(property: property)
            finalSummaryUInt64Array[property] = updatedSummary
        }
        
        var finalSummaryDuration: [MetatypeWrapper<Duration, Duration>: Duration] = [:]
        for property in propertiesDuration.keys {
            let updatedSummary = self.updatedDurationSummary(property: property)
            finalSummaryDuration[property] = updatedSummary
        }
        
        let totalFileCount = self.updatedFileCount(type: .total)
        let completedFileCount = self.updatedFileCount(type: .completed)
        let totalByteCount = self.updatedByteCount(type: .total)
        let completedByteCount = self.updatedByteCount(type: .completed)
        let throughput = self.updatedThroughput()
        let estimatedTimeRemaining = self.updatedEstimatedTimeRemaining()
        
        if !isFinished {
            markSelfDirty(parents: parents)
        }
        
        for parent in parents {
            parent.manager.setChildDeclaredAdditionalProperties(
                at: parent.positionInParent,
                totalFileCount: totalFileCount,
                completedFileCount: completedFileCount,
                totalByteCount: totalByteCount,
                completedByteCount: completedByteCount,
                throughput: throughput,
                estimatedTimeRemaining: estimatedTimeRemaining,
                propertiesInt: finalSummaryInt,
                propertiesUInt64: finalSummaryUInt64,
                propertiesDouble: finalSummaryDouble,
                propertiesString: finalSummaryString,
                propertiesURL: finalSummaryURL,
                propertiesUInt64Array: finalSummaryUInt64Array,
                propertiesDuration: finalSummaryDuration
            )
        }
    }
}
    
@available(FoundationPreview 6.4, *)
extension ProgressManager: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    /// Returns `true` if pointer of `lhs` is equal to pointer of `rhs`.
    public static func ==(lhs: ProgressManager, rhs: ProgressManager) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

@available(FoundationPreview 6.4, *)
extension ProgressManager: CustomStringConvertible, CustomDebugStringConvertible {
    /// A description.
    public var description: String {
        return """
        Class Name: ProgressManager
        Object Identifier: \(ObjectIdentifier(self))
        totalCount: \(String(describing: totalCount))
        completedCount: \(completedCount)
        fractionCompleted: \(fractionCompleted)
        isIndeterminate: \(isIndeterminate)
        isFinished: \(isFinished)
        totalFileCount: \(summary(of: ProgressManager.Properties.TotalFileCount.self))
        completedFileCount: \(summary(of: ProgressManager.Properties.CompletedFileCount.self))
        totalByteCount: \(summary(of: ProgressManager.Properties.TotalByteCount.self))
        completedByteCount: \(summary(of: ProgressManager.Properties.CompletedByteCount.self))
        throughput: \(summary(of: ProgressManager.Properties.Throughput.self))
        estimatedTimeRemaining: \(summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self))
        """
    }
    
    /// A debug description.
    public var debugDescription: String {
        return self.description
    }
}
