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
    
    private let state: Mutex<State> //CheerBridge exclusion
    
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
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == Int {
        return getUpdatedIntSummary(property: property)
    }
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == Double {
        return getUpdatedDoubleSummary(property: property)
    }
    
    public func summary<P: Property>(of property: P.Type) -> P.Summary where P.Summary == String {
        return getUpdatedStringSummary(property: property)
    }
    
    public func summary(of property: ProgressManager.Properties.TotalFileCount) -> Int {
        return getUpdatedFileCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedFileCount) -> Int {
        return getUpdatedFileCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.TotalByteCount) -> Int64 {
        return getUpdatedByteCount(type: .total)
    }
    
    public func summary(of property: ProgressManager.Properties.CompletedByteCount) -> Int64 {
        return getUpdatedByteCount(type: .completed)
    }
    
    public func summary(of property: ProgressManager.Properties.Throughput) -> Int64 {
        let throughput = getUpdatedThroughput()
        return throughput.values / Int64(throughput.count)
    }
    
    public func summary(of property: ProgressManager.Properties.EstimatedTimeRemaining) -> Duration {
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
    
    // MARK: Additional Properties Methods (Dual Mode of Operations)
    private func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) {
        for parentState in parents {
            parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
        }
    }
    
    private func markChildDirty<P: Property>(property: P.Type, at position: Int) {
        let parents = state.withLock { state in
            state.children[position].childProperties[AnyMetatypeWrapper(metatype: property)]?.isDirty = true
            return state.parents
        }
        markSelfDirty(property: property, parents: parents)
    }
    
    private func getUpdatedSummary<P: Property>(property: P.Type) -> P.Summary {
        return state.withLock { state in
            let propertyWrapper = AnyMetatypeWrapper(metatype: property)
            
            var value: P.Summary = P.defaultSummary
            P.reduce(into: &value, value: state.properties[propertyWrapper] as? P.Value ?? P.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childProperties[propertyWrapper] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedSummary(property: property)
                            let newChildPropertyState = PropertyState(value: updatedSummary, isDirty: false)
                            state.children[idx].childProperties[propertyWrapper] = newChildPropertyState
                            value = P.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingProperties {
                                if let remainingSummary = remainingProperties[propertyWrapper] {
                                    value = P.merge(value, remainingSummary as? P.Summary ?? P.defaultSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = P.merge(value, childPropertyState.value as? P.Summary ?? P.defaultSummary)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedSummary(property: property)
                        let newChildPropertyState = PropertyState(value: childSummary, isDirty: false)
                        state.children[idx].childProperties[propertyWrapper] = newChildPropertyState
                        value = P.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingProperties {
                            if let remainingSummary = remainingProperties[propertyWrapper] {
                                value = P.merge(value, remainingSummary as? P.Summary ?? P.defaultSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    private func getUpdatedIntSummary<P: Property>(property: P.Type) -> P.Summary where P.Summary == Int {
        return state.withLock { state in
            let propertyWrapper = AnyMetatypeWrapper(metatype: property)
            
            var value: Int = P.defaultSummary
            P.reduce(into: &value, value: state.propertiesInt[propertyWrapper] as? P.Value ?? P.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesInt[propertyWrapper] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedIntSummary(property: property)
                            let newChildPropertyState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesInt[propertyWrapper] = newChildPropertyState
                            value = P.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingPropertiesInt {
                                if let remainingSummary = remainingProperties[propertyWrapper] {
                                    value = P.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = P.merge(value, childPropertyState.value)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedIntSummary(property: property)
                        let newChildPropertyState = PropertyStateInt(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesInt[propertyWrapper] = newChildPropertyState
                        value = P.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesInt {
                            if let remainingSummary = remainingProperties[propertyWrapper] {
                                value = P.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    private func getUpdatedDoubleSummary<P: Property>(property: P.Type) -> P.Summary where P.Summary == Double {
        return state.withLock { state in
            let propertyWrapper = AnyMetatypeWrapper(metatype: property)
            
            var value: Double = P.defaultSummary
            P.reduce(into: &value, value: state.propertiesDouble[propertyWrapper] as? P.Value ?? P.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesDouble[propertyWrapper] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedDoubleSummary(property: property)
                            let newChildPropertyState = PropertyStateDouble(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesDouble[propertyWrapper] = newChildPropertyState
                            value = P.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingPropertiesDouble {
                                if let remainingSummary = remainingProperties[propertyWrapper] {
                                    value = P.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = P.merge(value, childPropertyState.value)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedDoubleSummary(property: property)
                        let newChildPropertyState = PropertyStateDouble(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesDouble[propertyWrapper] = newChildPropertyState
                        value = P.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesDouble {
                            if let remainingSummary = remainingProperties[propertyWrapper] {
                                value = P.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    private func getUpdatedStringSummary<P: Property>(property: P.Type) -> P.Summary where P.Summary == String {
        return state.withLock { state in
            let propertyWrapper = AnyMetatypeWrapper(metatype: property)
            
            var value: String = P.defaultSummary
            P.reduce(into: &value, value: state.propertiesString[propertyWrapper] as? P.Value ?? P.defaultValue)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if let childPropertyState = childState.childPropertiesString[propertyWrapper] {
                    if childPropertyState.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedStringSummary(property: property)
                            let newChildPropertyState = PropertyStateString(value: updatedSummary, isDirty: false)
                            state.children[idx].childPropertiesString[propertyWrapper] = newChildPropertyState
                            value = P.merge(value, updatedSummary)
                        } else {
                            // Get value from remainingProperties
                            if let remainingProperties = childState.remainingPropertiesString {
                                if let remainingSummary = remainingProperties[propertyWrapper] {
                                    value = P.merge(value, remainingSummary)
                                }
                            }
                        }
                    } else {
                        // Merge non-dirty, updated value
                        value = P.merge(value, childPropertyState.value)
                    }
                } else {
                    // First fetch of value
                    if let child = childState.child {
                        let childSummary = child.getUpdatedStringSummary(property: property)
                        let newChildPropertyState = PropertyStateString(value: childSummary, isDirty: false)
                        state.children[idx].childPropertiesString[propertyWrapper] = newChildPropertyState
                        value = P.merge(value, childSummary)
                    } else {
                        // Get value from remainingProperties
                        if let remainingProperties = childState.remainingPropertiesString {
                            if let remainingSummary = remainingProperties[propertyWrapper] {
                                value = P.merge(value, remainingSummary)
                            }
                        }
                    }
                }
            }
            return value
        }
    }
    
    private enum CountType {
        case total
        case completed
    }
    
    private func getUpdatedFileCount(type: CountType) -> Int {
        switch type {
        case .total:
            return state.withLock { state in
                // Get self's totalFileCount as part of summary
                var value: Int = 0
                ProgressManager.Properties.TotalFileCount.reduce(into: &value, value: state.totalFileCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.totalFileCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedFileCount(type: type)
                            let newTotalFileCountState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].totalFileCount =  newTotalFileCountState
                            value = ProgressManager.Properties.TotalFileCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-drity, updated value
                        value = ProgressManager.Properties.TotalFileCount.merge(value, childState.totalFileCount.value)
                    }
                }
                return value
            }
        case .completed:
            return state.withLock { state in
                // Get self's completedFileCount as part of summary
                var value: Int = 0
                ProgressManager.Properties.CompletedFileCount.reduce(into: &value, value: state.completedFileCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.completedFileCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedFileCount(type: type)
                            let newCompletedFileCountState = PropertyStateInt(value: updatedSummary, isDirty: false)
                            state.children[idx].completedFileCount =  newCompletedFileCountState
                            value = ProgressManager.Properties.CompletedFileCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-drity, updated value
                        value = ProgressManager.Properties.CompletedFileCount.merge(value, childState.completedFileCount.value)
                    }
                }
                return value
            }
        }
    }
    
    private func getUpdatedByteCount(type: CountType) -> Int64 {
        switch type {
        case .total:
            return state.withLock { state in
                // Get self's totalByteCount as part of summary
                var value: Int64 = 0
                ProgressManager.Properties.TotalByteCount.reduce(into: &value, value: state.totalByteCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.totalByteCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedByteCount(type: type)
                            let newTotalByteCountState = PropertyStateInt64(value: updatedSummary, isDirty: false)
                            state.children[idx].totalByteCount =  newTotalByteCountState
                            value = ProgressManager.Properties.TotalByteCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-drity, updated value
                        value = ProgressManager.Properties.TotalByteCount.merge(value, childState.totalByteCount.value)
                    }
                }
                return value
            }
        case .completed:
            return state.withLock { state in
                // Get self's completedByteCount as part of summary
                var value: Int64 = 0
                ProgressManager.Properties.CompletedByteCount.reduce(into: &value, value: state.completedByteCount)
                
                guard !state.children.isEmpty else {
                    return value
                }
                
                for (idx, childState) in state.children.enumerated() {
                    if childState.completedByteCount.isDirty {
                        // Update dirty path
                        if let child = childState.child {
                            let updatedSummary = child.getUpdatedByteCount(type: type)
                            let newCompletedByteCountState = PropertyStateInt64(value: updatedSummary, isDirty: false)
                            state.children[idx].completedByteCount =  newCompletedByteCountState
                            value = ProgressManager.Properties.CompletedByteCount.merge(value, updatedSummary)
                        }
                    } else {
                        // Merge non-drity, updated value
                        value = ProgressManager.Properties.CompletedByteCount.merge(value, childState.completedByteCount.value)
                    }
                }
                return value
            }
        }
    }
    
    private func getUpdatedThroughput() -> ProgressManager.Properties.Throughput.AggregateThroughput {
        return state.withLock { state in
            // Get self's throughput as part of summary
            var value: ProgressManager.Properties.Throughput.AggregateThroughput = ProgressManager.Properties.Throughput.defaultSummary
            ProgressManager.Properties.Throughput.reduce(into: &value, value: state.throughput)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if childState.throughput.isDirty {
                    // Update dirty path
                    if let child = childState.child {
                        let updatedSummary = child.getUpdatedThroughput()
                        let newThroughputState = PropertyStateThroughput(value: updatedSummary, isDirty: false)
                        state.children[idx].throughput =  newThroughputState
                        value = ProgressManager.Properties.Throughput.merge(value, updatedSummary)
                    }
                } else {
                    // Merge non-drity, updated value
                    value = ProgressManager.Properties.Throughput.merge(value, childState.throughput.value)
                }
            }
            return value
        }
    }
    
    private func getUpdatedEstimatedTimeRemaining() -> Duration {
        return state.withLock { state in
            // Get self's throughput as part of summary
            var value: Duration = Duration.seconds(0)
            ProgressManager.Properties.EstimatedTimeRemaining.reduce(into: &value, value: state.estimatedTimeRemaining)
            
            guard !state.children.isEmpty else {
                return value
            }
            
            for (idx, childState) in state.children.enumerated() {
                if childState.estimatedTimeRemaining.isDirty {
                    // Update dirty path
                    if let child = childState.child {
                        let updatedSummary = child.getUpdatedEstimatedTimeRemaining()
                        let newDurationState = PropertyStateDuration(value: updatedSummary, isDirty: false)
                        state.children[idx].estimatedTimeRemaining = newDurationState
                        value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, updatedSummary)
                    }
                } else {
                    // Merge non-dirty, updated value
                    value = ProgressManager.Properties.EstimatedTimeRemaining.merge(value, state.estimatedTimeRemaining)
                }
            }
            return value
        }
    }
    
    private func setChildRemainingProperties(_ properties: [AnyMetatypeWrapper: (any Sendable)], at position: Int) {
        state.withLock { state in
            state.children[position].remainingProperties = properties
        }
    }
    
    private func setChildTotalFileCount(value: Int, at position: Int) {
        state.withLock { state in
            state.children[position].totalFileCount = PropertyStateInt(value: value, isDirty: false)
        }
    }
    
    private func setChildCompletedFileCount(value: Int, at position: Int) {
        state.withLock { state in
            state.children[position].completedFileCount = PropertyStateInt(value: value, isDirty: false)
        }
    }
    
    private func setChildTotalByteCount(value: Int64, at position: Int) {
        state.withLock { state in
            state.children[position].totalByteCount = PropertyStateInt64(value: value, isDirty: false)
        }
    }
    
    private func setChildCompletedByteCount(value: Int64, at position: Int) {
        state.withLock { state in
            state.children[position].completedByteCount = PropertyStateInt64(value: value, isDirty: false)
        }
    }
    
    private func setChildThroughput(value: ProgressManager.Properties.Throughput.AggregateThroughput, at position: Int) {
        state.withLock { state in
            state.children[position].throughput = PropertyStateThroughput(value: value, isDirty: false)
        }
    }
    
    private func setChildEstimatedTimeRemaining(value: Duration, at position: Int) {
        state.withLock { state in
            state.children[position].estimatedTimeRemaining = PropertyStateDuration(value: value, isDirty: false)
        }
    }
    
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
        
        // TODO: Handle declared properties (specialize)
        
        let (properties, parents) = state.withLock { state in
            return (state.properties, state.parents)
        }
        
        var finalSummary: [AnyMetatypeWrapper: (any Sendable)] = [:]
        for property in properties.keys {
            let updatedSummary = self.summary(of: property.metatype.self)
            finalSummary[property] = updatedSummary
        }
        
        for parentState in parents {
            parentState.parent.setChildRemainingProperties(finalSummary, at: parentState.positionInParent)
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
