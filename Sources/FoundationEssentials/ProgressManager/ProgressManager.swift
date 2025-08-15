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
internal import Synchronization

#if canImport(CollectionsInternal)
internal import CollectionsInternal
#elseif canImport(OrderedCollections)
internal import OrderedCollections
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

@available(FoundationPreview 6.2, *)
/// An object that conveys ongoing progress to the user for a specified task.
@Observable public final class ProgressManager: Sendable {
    
    internal let state: Mutex<State>
    
    /// The total units of work.
    public var totalCount: Int? {
        _$observationRegistrar.access(self, keyPath: \.totalCount)
        return state.withLock { state in
            state.getTotalCount()
        }
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        _$observationRegistrar.access(self, keyPath: \.completedCount)
        return state.withLock { state in
            state.getCompletedCount()
        }
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double {
        _$observationRegistrar.access(self, keyPath: \.fractionCompleted)
        return state.withLock { state in
            state.getFractionCompleted()
        }
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        _$observationRegistrar.access(self, keyPath: \.isIndeterminate)
        return state.withLock { state in
            state.getIsIndeterminate()
        }
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        _$observationRegistrar.access(self, keyPath: \.isFinished)
        return state.withLock { state in
            state.getIsFinished()
        }
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
            fileURL: ProgressManager.Properties.FileURL.defaultValue,
            propertiesInt: [:],
            propertiesDouble: [:],
            propertiesString: [:],
            propertiesURL: [:],
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
            fileURL: ProgressManager.Properties.FileURL.defaultValue,
            propertiesInt: [:],
            propertiesDouble: [:],
            propertiesString: [:]
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
    /// - Parameter count: Units, which is a portion of `totalCount`delegated to an instance of `Subprogress`.
    /// - Returns: A `Subprogress` instance.
    public func subprogress(assigningCount portionOfParent: Int) -> Subprogress {
        precondition(portionOfParent > 0, "Giving out zero units is not a valid operation.")
        let subprogress = Subprogress(parent: self, portionOfParent: portionOfParent)
        return subprogress
    }
    
    /// Adds a `ProgressReporter` as a child, with its progress representing a portion of `self`'s progress.
    /// - Parameters:
    ///   - reporter: A `ProgressReporter` instance.
    ///   - count: Units, which is a portion of `totalCount`delegated to an instance of `Subprogress`.
    public func assign(count: Int, to reporter: ProgressReporter) {
        precondition(isCycle(reporter: reporter) == false, "Creating a cycle is not allowed.")
        
        let actualManager = reporter.manager
        
        let position = self.addChild(child: actualManager, portion: count, childFraction: actualManager.getProgressFraction())
        actualManager.addParent(parent: self, positionInParent: position)
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        let parents: [ParentState]? = state.withLock { state in
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
    
    internal func markSelfDirty(parents: [ParentState]) {
        _$observationRegistrar.withMutation(of: self, keyPath: \.fractionCompleted) {
            if parents.count > 0 {
                for parentState in parents {
                    parentState.parent.markChildDirty(at: parentState.positionInParent)
                }
            }
        }
    }
    
    private func markChildDirty(at position: Int) {
        let parents: [ParentState]? = state.withLock { state in
            guard !state.children[position].isDirty else {
                return nil
            }
            state.children[position].isDirty = true
            return state.parents
        }
        if let parents = parents {
            markSelfDirty(parents: parents)
        }
    }
    
    internal func getUpdatedProgressFraction() -> ProgressFraction {
        return state.withLock { state in
            state.updateChildrenProgressFraction()
            return state.overallFraction
        }
    }
    
    //MARK: Parent - Child Relationship Methods
    internal func addChild(child: ProgressManager, portion: Int, childFraction: ProgressFraction) -> Int {
        let (index, parents) = state.withLock { state in
            let childState = ChildState(child: child,
                                        portionOfTotal: portion,
                                        childFraction: childFraction,
                                        isDirty: true,
                                        totalFileCount: PropertyStateInt(value: ProgressManager.Properties.TotalFileCount.defaultSummary, isDirty: false),
                                        completedFileCount: PropertyStateInt(value: ProgressManager.Properties.CompletedFileCount.defaultSummary, isDirty: false),
                                        totalByteCount: PropertyStateUInt64(value: ProgressManager.Properties.TotalByteCount.defaultSummary, isDirty: false),
                                        completedByteCount: PropertyStateUInt64(value: ProgressManager.Properties.CompletedByteCount.defaultSummary, isDirty: false),
                                        throughput: PropertyStateThroughput(value: ProgressManager.Properties.Throughput.defaultSummary, isDirty: false),
                                        estimatedTimeRemaining: PropertyStateDuration(value: ProgressManager.Properties.EstimatedTimeRemaining.defaultSummary, isDirty: false),
                                        fileURL: PropertyStateURL(value: ProgressManager.Properties.FileURL.defaultSummary, isDirty: false),
                                        childPropertiesInt: [:],
                                        childPropertiesDouble: [:],
                                        childPropertiesString: [:],
                                        childPropertiesURL: [:])
            state.children.append(childState)
            return (state.children.count - 1, state.parents)
        }
        // Mark dirty all the way up to the root so that if the branch was marked not dirty right before this it will be marked dirty again (for optimization to work)
        markSelfDirty(parents: parents)
        return index
    }
    
    internal func addParent(parent: ProgressManager, positionInParent: Int) {
        state.withLock { state in
            let parentState = ParentState(parent: parent, positionInParent: positionInParent)
            state.parents.append(parentState)
        }
    }
    
    // MARK: Cycle Detection Methods
    internal func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if reporter.manager === self {
            return true
        }
        
        let updatedVisited = visited.union([self])
        
        return state.withLock { state in
            for parentState in state.parents {
                if !updatedVisited.contains(parentState.parent) {
                    if (parentState.parent.isCycle(reporter: reporter, visited: updatedVisited)) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    internal func isCycleInterop(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        return state.withLock { state in
            for parentState in state.parents {
                if !visited.contains(parentState.parent) {
                    if (parentState.parent.isCycle(reporter: reporter, visited: visited)) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    deinit {
        if !isFinished {
            self.withProperties { properties in
                if let totalCount = properties.totalCount {
                    properties.completedCount = totalCount
                }
            }
        }
        
        let (propertiesInt, propertiesDouble, propertiesString, propertiesURL, parents) = state.withLock { state in
            return (state.propertiesInt, state.propertiesDouble, state.propertiesString, state.propertiesURL, state.parents)
        }
        
        var finalSummaryInt: [MetatypeWrapper<Int, Int>: Int] = [:]
        for property in propertiesInt.keys {
            let updatedSummary = self.getUpdatedIntSummary(property: property)
            finalSummaryInt[property] = updatedSummary
        }
        
        var finalSummaryDouble: [MetatypeWrapper<Double, Double>: Double] = [:]
        for property in propertiesDouble.keys {
            let updatedSummary = self.getUpdatedDoubleSummary(property: property)
            finalSummaryDouble[property] = updatedSummary
        }

        var finalSummaryString: [MetatypeWrapper<String?, [String?]>: [String?]] = [:]
        for property in propertiesString.keys {
            let updatedSummary = self.getUpdatedStringSummary(property: property)
            finalSummaryString[property] = updatedSummary
        }
        
        var finalSummaryURL: [MetatypeWrapper<URL?, [URL?]>: [URL?]] = [:]
        for property in propertiesURL.keys {
            let updatedSummary = self.getUpdatedURLSummary(property: property)
            finalSummaryURL[property] = updatedSummary
        }
        
        let totalFileCount = self.getUpdatedFileCount(type: .total)
        let completedFileCount = self.getUpdatedFileCount(type: .completed)
        let totalByteCount = self.getUpdatedByteCount(type: .total)
        let completedByteCount = self.getUpdatedByteCount(type: .completed)
        let throughput = self.getUpdatedThroughput()
        let estimatedTimeRemaining = self.getUpdatedEstimatedTimeRemaining()
        let fileURL = self.getUpdatedFileURL()
        
        for parentState in parents {
            parentState.parent.setChildDeclaredAdditionalProperties(
                at: parentState.positionInParent,
                totalFileCount: totalFileCount,
                completedFileCount: completedFileCount,
                totalByteCount: totalByteCount,
                completedByteCount: completedByteCount,
                throughput: throughput,
                estimatedTimeRemaining: estimatedTimeRemaining,
                fileURL: fileURL,
                propertiesInt: finalSummaryInt,
                propertiesDouble: finalSummaryDouble,
                propertiesString: finalSummaryString,
                propertiesURL: finalSummaryURL
            )
        }
    }
}
    
@available(FoundationPreview 6.2, *)
extension ProgressManager: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    /// Returns `true` if pointer of `lhs` is equal to pointer of `rhs`.
    public static func ==(lhs: ProgressManager, rhs: ProgressManager) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressManager: CustomStringConvertible, CustomDebugStringConvertible {
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
    
    public var debugDescription: String {
        return self.description
    }
}
