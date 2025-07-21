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
    
    internal let state: Mutex<State> //CheerBridge exclusion
    
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
            if let interopChild = state.interopChild {
                return interopChild.fractionCompleted
            }
            
            state.updateChildrenProgressFraction()
                        
            return state.overallFraction.fractionCompleted
        }
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        _$observationRegistrar.access(self, keyPath: \.isIndeterminate)
        return state.withLock { state in
            state.selfFraction.isIndeterminate
        }
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        _$observationRegistrar.access(self, keyPath: \.isFinished)
        return state.withLock { state in
            state.selfFraction.isFinished
        }
    }
    
    /// A `ProgressReporter` instance, used for providing read-only observation of progress updates or composing into other `ProgressManager`s.
    public var reporter: ProgressReporter {
        return .init(manager: self)
    }
    
    internal init(total: Int?, progressParentProgressManagerChildMessenger: ProgressManager?, managerObservation: _ProgressParentProgressManagerChild?) {
        let state = State(
            interopChild: nil,
            selfFraction: ProgressFraction(completed: 0, total: total),
            children: [],
            parents: [],
            totalFileCount: ProgressManager.Properties.TotalFileCount.defaultValue,
            completedFileCount: ProgressManager.Properties.CompletedFileCount.defaultValue,
            totalByteCount: ProgressManager.Properties.TotalByteCount.defaultValue,
            completedByteCount: ProgressManager.Properties.CompletedByteCount.defaultValue,
            throughput: ProgressManager.Properties.Throughput.defaultValue,
            estimatedTimeRemaining: ProgressManager.Properties.EstimatedTimeRemaining.defaultValue,
            propertiesInt: [:],
            propertiesDouble: [:],
            propertiesString: [:],
            properties: [:],
            interopObservation: InteropObservation(progressParentProgressManagerChild: managerObservation),
            progressParentProgressManagerChildMessenger: progressParentProgressManagerChildMessenger,
            observers: []
        )
        self.state = Mutex(state)
    }
    
    /// Initializes `self` with `totalCount`.
    ///
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    /// - Parameter totalCount: Total units of work.
    public convenience init(totalCount: Int?) {
        self.init(
            total: totalCount,
            progressParentProgressManagerChildMessenger: nil,
            managerObservation: nil
        )
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
            
            state.selfFraction.completed += count
            
            state.progressParentProgressManagerChildMessenger?.notifyObservers(
                with: .fractionUpdated(
                    totalCount: state.selfFraction.total ?? 0,
                    completedCount: state.selfFraction.completed
                )
            )
            if let _ = state.interopObservation.progressParentProgressReporterChild {
                state.notifyObservers(
                    with: .fractionUpdated(
                        totalCount: state.selfFraction.total ?? 0,
                        completedCount: state.selfFraction.completed
                    )
                )
            }
            
            return state.parents
        }
        if let parents = parents {
            markSelfDirty(parents: parents)
        }
    }
    
    /// Returns a summary for specified property in subtree.
    /// - Parameter metatype: Type of property.
    /// - Returns: Summary of property as specified.
    public func summary<P: Property>(of property: P.Type) -> P.Summary { // rename this later - aggregate 
//        _$observationRegistrar.access(self, keyPath: \.state)
        return getUpdatedSummary(property: property)
    }
    
    @_disfavoredOverload
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == Int {
        return getUpdatedIntSummary(property: property)
    }
    
    @_disfavoredOverload
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == Double {
        return getUpdatedDoubleSummary(property: property)
    }
    
    @_disfavoredOverload
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == String {
        return getUpdatedStringSummary(property: property)
    }
    
    public func summary(of property: ProgressManager.Properties.TotalFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedFileCount.Type) -> Int {
        return getUpdatedFileCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.TotalByteCount.Type) -> Int64 {
        return getUpdatedByteCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedByteCount.Type) -> Int64 {
        return getUpdatedByteCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.Throughput.Type) -> Int64 {
        let throughput = getUpdatedThroughput()
        return throughput.values / Int64(throughput.count)
    }
    
    public func summary(of property: ProgressManager.Properties.EstimatedTimeRemaining.Type) -> Duration {
        return getUpdatedEstimatedTimeRemaining()
    }
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        return try state.withLock { (state) throws(E) -> T in
            var values = Values(state: state)
            // This is done to avoid copy on write later
            state = State(
                selfFraction: ProgressFraction(),
                children: [],
                parents: [],
                totalFileCount: ProgressManager.Properties.TotalFileCount.defaultValue,
                completedFileCount: ProgressManager.Properties.CompletedFileCount.defaultValue,
                totalByteCount: ProgressManager.Properties.TotalByteCount.defaultValue,
                completedByteCount: ProgressManager.Properties.CompletedByteCount.defaultValue,
                throughput: ProgressManager.Properties.Throughput.defaultValue,
                estimatedTimeRemaining: ProgressManager.Properties.EstimatedTimeRemaining.defaultValue,
                propertiesInt: [:],
                propertiesDouble: [:],
                propertiesString: [:],
                properties: [:],
                interopObservation: InteropObservation(progressParentProgressManagerChild: nil),
                progressParentProgressManagerChildMessenger: nil,
                observers: []
            )
            let result = try closure(&values)
            if values.fractionalCountDirty {
                markSelfDirty(parents: values.state.parents)
            }
            
            if values.totalFileCountDirty {
                markSelfDirty(property: Properties.TotalFileCount.self, parents: values.state.parents)
            }
            
            if values.completedFileCountDirty {
                markSelfDirty(property: Properties.CompletedFileCount.self, parents: values.state.parents)
            }
            
            if values.totalByteCountDirty {
                markSelfDirty(property: Properties.TotalByteCount.self, parents: values.state.parents)
            }
            
            if values.completedByteCountDirty {
                markSelfDirty(property: Properties.CompletedByteCount.self, parents: values.state.parents)
            }
            
            if values.throughputDirty {
                markSelfDirty(property: Properties.Throughput.self, parents: values.state.parents)
            }
            
            if values.estimatedTimeRemainingDirty {
                markSelfDirty(property: Properties.EstimatedTimeRemaining.self, parents: values.state.parents)
            }
            
            if values.dirtyPropertiesInt.count > 0 {
                for property in values.dirtyProperties {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if values.dirtyPropertiesDouble.count > 0 {
                for property in values.dirtyProperties {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if values.dirtyPropertiesString.count > 0 {
                for property in values.dirtyProperties {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if values.dirtyProperties.count > 0 {
                for property in values.dirtyProperties {
                    markSelfDirty(property: property, parents: values.state.parents)
                }
            }
            
            if let observerState = values.observerState {
                if let _ = state.interopObservation.progressParentProgressReporterChild {
                    notifyObservers(with: observerState)
                }
            }
            state = values.state
            return result
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
    
    private func markSelfDirty(parents: [ParentState]) {
        _$observationRegistrar.withMutation(of: self, keyPath: \.fractionCompleted) {
            if parents.count > 0 {
                for parentState in parents {
                    parentState.parent.markChildDirty(at: parentState.positionInParent)
                }
            }
        }
    }
    
    private func markChildDirty(at position: Int) {
        let parents = state.withLock { state in
            state.children[position].isDirty = true
            return state.parents
        }
        markSelfDirty(parents: parents)
    }
    
    internal func getUpdatedProgressFraction() -> ProgressFraction {
        return state.withLock { state in
            state.updateChildrenProgressFraction()
            return state.overallFraction
        }
    }
    
    // MARK: Additional Properties Methods
    internal func getProperties<T, E: Error>(
        _ closure: (sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        try state.withLock { state throws(E) -> T in
            let values = Values(state: state)
            let result = try closure(values)
            return result
        }
    }
    
    //MARK: Parent - Child Relationship Methods
    internal func addChild(child: ProgressManager, portion: Int, childFraction: ProgressFraction) -> Int {
        let index = state.withLock { state in
            let childState = ChildState(child: child,
                                        remainingPropertiesInt: nil,
                                        remainingPropertiesDouble: nil,
                                        remainingPropertiesString: nil,
                                        remainingProperties: nil,
                                        portionOfTotal: portion,
                                        childFraction: childFraction,
                                        isDirty: true,
                                        totalFileCount: PropertyStateInt(value: ProgressManager.Properties.TotalFileCount.defaultSummary, isDirty: false),
                                        completedFileCount: PropertyStateInt(value: ProgressManager.Properties.CompletedFileCount.defaultSummary, isDirty: false),
                                        totalByteCount: PropertyStateInt64(value: ProgressManager.Properties.TotalByteCount.defaultSummary, isDirty: false),
                                        completedByteCount: PropertyStateInt64(value: ProgressManager.Properties.CompletedByteCount.defaultSummary, isDirty: false),
                                        throughput: PropertyStateThroughput(value: ProgressManager.Properties.Throughput.defaultSummary, isDirty: false),
                                        estimatedTimeRemaining: PropertyStateDuration(value: ProgressManager.Properties.EstimatedTimeRemaining.defaultSummary, isDirty: false),
                                        childPropertiesInt: [:],
                                        childPropertiesDouble: [:],
                                        childPropertiesString: [:],
                                        childProperties: [:])
            state.children.append(childState)
            return state.children.count - 1
        }
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

    //MARK: Interop Methods
    /// Adds `observer` to list of `_observers` in `self`.
    internal func addObserver(observer: @escaping @Sendable (ObserverState) -> Void) {
        state.withLock { state in
            state.observers.append(observer)
        }
    }
    
    /// Notifies all `_observers` of `self` when `state` changes.
    internal func notifyObservers(with observedState: ObserverState) {
        state.withLock { state in
            for observer in state.observers {
                observer(observedState)
            }
        }
    }
    
    internal func setInteropObservationReporter(observation reporterObservation: _ProgressParentProgressReporterChild) {
        state.withLock { state in
            state.interopObservation.progressParentProgressReporterChild = reporterObservation
        }
    }
    
#if FOUNDATION_FRAMEWORK
    internal func setParentBridge(parentBridge: Foundation.Progress) {
        state.withLock { state in
            state.interopObservation.parentBridge = parentBridge
        }
    }
#endif
    
    internal func setInteropChild(interopChild: ProgressManager) {
        state.withLock { state in
            state.interopChild = interopChild
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
        
        let (properties, propertiesInt, propertiesDouble, propertiesString, parents) = state.withLock { state in
            return (state.properties,
                    state.propertiesInt,
                    state.propertiesDouble,
                    state.propertiesString,
                    state.parents)
        }
        
        var finalSummary: [AnyMetatypeWrapper: (any Sendable)] = [:]
        for property in properties.keys {
            let updatedSummary = self.summary(of: property.metatype.self)
            finalSummary[property] = updatedSummary
        }
        
        var finalSummaryInt: [AnyMetatypeWrapper: Int] = [:]
        for property in propertiesInt.keys {
            let updatedSummary = self.summary(of: property.metatype.self)
            finalSummaryInt[property] = updatedSummary as? Int
        }
        
        var finalSummaryDouble: [AnyMetatypeWrapper: Double] = [:]
        for property in propertiesDouble.keys {
            let updatedSummary = self.summary(of: property.metatype.self)
            finalSummaryDouble[property] = updatedSummary as? Double
        }
        
        var finalSummaryString: [AnyMetatypeWrapper: String] = [:]
        for property in propertiesString.keys {
            let updatedSummary = self.summary(of: property.metatype.self)
            finalSummaryString[property] = updatedSummary as? String
        }
        
        
        for parentState in parents {
            parentState.parent.setChildRemainingProperties(finalSummary, at: parentState.positionInParent)
            parentState.parent.setChildRemainingPropertiesInt(finalSummaryInt, at: parentState.positionInParent)
            parentState.parent.setChildRemainingPropertiesDouble(finalSummaryDouble, at: parentState.positionInParent)
            parentState.parent.setChildRemainingPropertiesString(finalSummaryString, at: parentState.positionInParent)
            parentState.parent.setChildTotalFileCount(value: self.summary(of: Properties.TotalFileCount.self), at: parentState.positionInParent)
            parentState.parent.setChildCompletedFileCount(value: self.summary(of: Properties.CompletedFileCount.self), at: parentState.positionInParent)
            parentState.parent.setChildTotalByteCount(value: self.summary(of: Properties.TotalByteCount.self), at: parentState.positionInParent)
            parentState.parent.setChildCompletedByteCount(value: self.summary(of: Properties.CompletedByteCount.self), at: parentState.positionInParent)
            parentState.parent.setChildThroughput(value: self.summary(of: Properties.Throughput.self), at: parentState.positionInParent)
            parentState.parent.setChildEstimatedTimeRemaining(value: self.summary(of: Properties.EstimatedTimeRemaining.self), at: parentState.positionInParent)
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
        ObjectIdentifier: \(ObjectIdentifier(self))
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
