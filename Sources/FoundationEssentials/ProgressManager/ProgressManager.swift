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
    // These are "fake" keypaths used for registering observations of values and summaries of custom properties declared by developers.
    internal let customPropertiesInt: Void
    internal let customPropertiesUInt64: Void
    internal let customPropertiesDouble: Void
    internal let customPropertiesString: Void
    internal let customPropertiesURL: Void
    internal let customPropertiesUInt64Array: Void
    internal let customPropertiesDuration: Void
    internal let customPropertiesIntSummary: Void
    internal let customPropertiesUInt64Summary: Void
    internal let customPropertiesDoubleSummary: Void
    internal let customPropertiesStringSummary: Void
    internal let customPropertiesURLSummary: Void
    internal let customPropertiesUInt64ArraySummary: Void
    internal let customPropertiesDurationSummary: Void
    // These are "fake" keypaths used for registering observations of summaries of pre-declared custom properties.
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
        
        // Get information about dirty children (Acquire and release self's lock)
        let (children, completedCount, pendingUpdates) = state.withLock { state in
            let (completedCount, pendingUpdates) = state.completedCountInfo()
            return (state.children.compactMap { $0.manager }, completedCount, pendingUpdates)
        }
        
        guard let updates = pendingUpdates else {
            for child in children {
                child.access(keyPath: \.completedCount)
            }
            return completedCount
        }
        
        // Get updated information for each dirty child (Acquire and release each child's lock)
        var childrenUpdates: [PendingChildUpdate] = []
        
        for update in updates {
            let updatedFraction = update.manager.updatedProgressFraction()
            childrenUpdates.append(PendingChildUpdate(
                index: update.index,
                updatedFraction: updatedFraction,
                assignedCount: update.assignedCount
            ))
        }
        
        // Apply updated information of dirty child in self's children array (Acquire and release self's lock)
        let updatedCompletedCount = state.withLock { state in
            state.updateChildrenProgressFraction(updates: childrenUpdates)
            return state.selfFraction.completed
        }
        
        for child in children {
            child.access(keyPath: \.completedCount)
        }
        
        return updatedCompletedCount
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.0.
    public var fractionCompleted: Double {
        self.access(keyPath: \.totalCount)
        self.access(keyPath: \.completedCount)
        
        // Get information about dirty children (Acquire and release self's lock)
        let (children, fractionCompleted, pendingUpdates) = state.withLock { state in
            let (fractionCompleted, pendingUpdates) = state.fractionCompletedInfo()
            return (state.children.compactMap { $0.manager }, fractionCompleted, pendingUpdates)
        }
                
        guard let updates = pendingUpdates else {
            for child in children {
                child.access(keyPath: \.totalCount)
                child.access(keyPath: \.completedCount)
            }
            return fractionCompleted
        }
        
        // Get updated information for each dirty child (Acquire and release each child's lock)
        var childrenUpdates: [PendingChildUpdate] = []
        
        for update in updates {
            let updatedFraction = update.manager.updatedProgressFraction()
            childrenUpdates.append(PendingChildUpdate(
                index: update.index,
                updatedFraction: updatedFraction,
                assignedCount: update.assignedCount
            ))
        }
        
        // Apply updated information of dirty child in self's children array (Acquire and release self's lock)
        let updatedFractionCompleted = state.withLock { state in
            state.updateChildrenProgressFraction(updates: childrenUpdates)
            return state.overallFraction.fractionCompleted
        }
        
        for child in children {
            child.access(keyPath: \.totalCount)
            child.access(keyPath: \.completedCount)
        }
        
        return updatedFractionCompleted
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
        
        // Get information about dirty children (Acquire and release self's lock)
        let (children, isFinished, pendingUpdates) = state.withLock { state in
            let (isFinished, pendingUpdates) = state.isFinishedInfo()
            return (state.children.compactMap { $0.manager }, isFinished, pendingUpdates)
        }
        
        guard let updates = pendingUpdates else {
            for child in children {
                child.access(keyPath: \.totalCount)
                child.access(keyPath: \.completedCount)
            }
            return isFinished
        }
        
        // Get updated information for each dirty child (Acquire and release each child's lock)
        var childrenUpdates: [PendingChildUpdate] = []
        
        for update in updates {
            let updatedFraction = update.manager.updatedProgressFraction()
            childrenUpdates.append(PendingChildUpdate(
                index: update.index,
                updatedFraction: updatedFraction,
                assignedCount: update.assignedCount
            ))
        }
        
        // Apply updated information of dirty child in self's children array (Acquire and release self's lock)
        let updatedIsFinished = state.withLock { state in
            state.updateChildrenProgressFraction(updates: childrenUpdates)
            return state.selfFraction.isFinished
        }
        
        for child in children {
            child.access(keyPath: \.completedCount)
        }
        
        return updatedIsFinished
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
    public func subprogress(assigningCount portionOfParentTotal: Int) -> Subprogress {
        precondition(portionOfParentTotal > 0, "Giving out zero units is not a valid operation.")
        let subprogress = Subprogress(parent: self, assignedCount: portionOfParentTotal)
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
        // Get information about dirty children (Acquire and release self's lock)
        let pendingUpdates = state.withLock { state in
            state.pendingChildrenUpdates()
        }
        
        guard let updates = pendingUpdates else {
            // No pending updates, just return the overall fraction
            return state.withLock { state in
                state.overallFraction
            }
        }
        
        // Get updated information for each dirty child (Acquire and release each child's lock)
        var childrenUpdates: [PendingChildUpdate] = []
        
        for update in updates {
            let updatedFraction = update.manager.updatedProgressFraction()
            childrenUpdates.append(PendingChildUpdate(
                index: update.index,
                updatedFraction: updatedFraction,
                assignedCount: update.assignedCount
            ))
        }
        
        // Apply updated information of dirty child in self's children array (Acquire and release self's lock)
        return state.withLock { state in
            state.updateChildrenProgressFraction(updates: childrenUpdates)
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
                                  throughputSummary: PropertyStateUInt64Array(value: ProgressManager.Properties.Throughput.defaultSummary, isDirty: false),
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
        let parents = state.withLock { state in
            return state.parents
        }
        for parent in parents {
            guard !updatedVisited.contains(parent.manager) else {
                continue
            }
            if parent.manager.isCycle(reporter: reporter, visited: updatedVisited) {
                return true
            }
        }
        return false
    }
    
    internal func isCycleInterop(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        let parents = state.withLock { state in
            return state.parents
        }
        for parent in parents {
            guard !visited.contains(parent.manager) else {
                continue
            }
            if parent.manager.isCycle(reporter: reporter, visited: visited) {
                return true
            }
        }
        return false
    }
    
    deinit {
        // Custom Properties directly updates parents' entries so it should not be marked dirty.
        let (finalSummary, parents) = state.withLock { state in
            state.customPropertiesCleanup()
        }
        
        for parent in parents {
            parent.manager.setChildDeclaredAdditionalProperties(
                at: parent.positionInParent,
                totalFileCount: finalSummary.totalFileCountSummary,
                completedFileCount: finalSummary.completedFileCountSummary,
                totalByteCount: finalSummary.totalByteCountSummary,
                completedByteCount: finalSummary.completedByteCountSummary,
                throughput: finalSummary.throughputSummary,
                estimatedTimeRemaining: finalSummary.estimatedTimeRemainingSummary,
                propertiesInt: finalSummary.customPropertiesIntSummary,
                propertiesUInt64: finalSummary.customPropertiesUInt64Summary,
                propertiesDouble: finalSummary.customPropertiesDoubleSummary,
                propertiesString: finalSummary.customPropertiesStringSummary,
                propertiesURL: finalSummary.customPropertiesURLSummary,
                propertiesUInt64Array: finalSummary.customPropertiesUInt64ArraySummary,
                propertiesDuration: finalSummary.customPropertiesDurationSummary
            )
        }
        
        // Fractional property does not update parents' entries so it should be marked dirty. If fraction is not finished when deinit, mark the path dirty so that parents have an opportunity to check and complete the portion that is unfinished. The parent will later complete the portion when trying to clear the dirty bit in state.updateChildrenProgressFraction().
        if !isFinished {
            markSelfDirty(parents: parents)
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
