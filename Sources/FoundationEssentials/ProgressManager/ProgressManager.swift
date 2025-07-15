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

internal struct AnyMetatypeWrapper: Hashable, Equatable, Sendable {
    let metatype: Any.Type
    
    internal static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.metatype == rhs.metatype
    }
    
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(metatype))
    }
}

@available(FoundationPreview 6.2, *)
/// An object that conveys ongoing progress to the user for a specified task.
@Observable public final class ProgressManager: Sendable {
    
    internal struct PropertyState {
        var value: (any Sendable)
        var isDirty: Bool
    }
    
    internal struct ChildState {
        weak var child: ProgressManager?
        var portionOfTotal: Int
        var childFraction: ProgressFraction
        var isDirty: Bool
        var childProperties: [AnyMetatypeWrapper: PropertyState]
    }
    
    internal struct ParentState {
        var parent: ProgressManager
        var positionInParent: Int
    }
    
    internal enum ObserverState {
        case fractionUpdated(totalCount: Int, completedCount: Int)
    }
    
    internal struct InteropObservation {
        let progressParentProgressManagerChild: _ProgressParentProgressManagerChild?
        var progressParentProgressReporterChild: _ProgressParentProgressReporterChild?
        #if FOUNDATION_FRAMEWORK
        var parentBridge: Foundation.Progress?
        #endif
    }
    
    internal struct State {
        var interopChild: ProgressManager?
        var selfFraction: ProgressFraction
        var overallFraction: ProgressFraction {
            var overallFraction = selfFraction
            for child in children {
                if !child.childFraction.isFinished {
                    overallFraction = overallFraction + ((ProgressFraction(completed: child.portionOfTotal, total: selfFraction.total) * child.childFraction)!)
                }
            }
            return overallFraction
        }
        var children: [ChildState]
        var parents: [ParentState]
        var properties: [AnyMetatypeWrapper: (any Sendable)]
        var interopObservation: InteropObservation
        let progressParentProgressManagerChildMessenger: ProgressManager?
        var observers: [@Sendable (ObserverState) -> Void]
    }
    
    private let state: Mutex<State>
    
    /// The total units of work.
    public var totalCount: Int? {
        _$observationRegistrar.access(self, keyPath: \.totalCount)
        return state.withLock { state in
            getTotalCountLocked(state: state)
        }
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        _$observationRegistrar.access(self, keyPath: \.completedCount)
        return state.withLock { state in
            getCompletedCountLocked(state: &state)
        }
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double {
        _$observationRegistrar.access(self, keyPath: \.fractionCompleted)
        return getFractionCompleted()
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        _$observationRegistrar.access(self, keyPath: \.isIndeterminate)
        return getIsIndeterminate()
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        _$observationRegistrar.access(self, keyPath: \.isFinished)
        return getIsFinished()
    }
    
    /// A `ProgressReporter` instance, used for providing read-only observation of progress updates or composing into other `ProgressManager`s.
    public var reporter: ProgressReporter {
        return .init(manager: self)
    }
    
    /// A type that conveys task-specific information on progress.
    public protocol Property {
        
        associatedtype Value: Sendable, Hashable, Equatable
        associatedtype Summary: Sendable, Hashable, Equatable
        
        /// The default value to return when property is not set to a specific value.
        static var defaultValue: Value { get }
        // don't need default value because that just means dictionary is empty 
        
        static var defaultSummary: Summary { get }
        
        static func reduce(into: inout Summary, value: Value)
        
        static func merge(_ summary1: Summary, _ summary2: Summary) -> Summary
    }
    
    /// A container that holds values for properties that specify information on progress.
    @dynamicMemberLookup
    public struct Values : Sendable {
        //TODO: rdar://149225947 Non-escapable conformance
        var state: State
        
        let willGetCompletedCount: (@Sendable (inout State) -> (Int))
        let willMarkSelfDirty: (@Sendable ([ParentState]) -> ())
        let willMarkPropertyDirty: (@Sendable (any Property.Type, [ParentState]) -> ())
        let willNotifyObservers: (@Sendable (ObserverState, inout State) -> ())
        
        /// The total units of work.
        public var totalCount: Int? {
            get {
                if let interopChild = state.interopChild {
                    return interopChild.totalCount
                }
                return state.selfFraction.total
            }
            
            set {
                guard newValue != state.selfFraction.total else {
                    return 
                }
                
                state.selfFraction.total = newValue
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total!, completedCount: state.selfFraction.completed))
                
                if let _ = state.interopObservation.progressParentProgressReporterChild {
                    willNotifyObservers(.fractionUpdated(totalCount: state.selfFraction.total!, completedCount: state.selfFraction.completed), &state)
                }
                
                willMarkSelfDirty(state.parents)
            }
        }
        
        
        /// The completed units of work.
        public var completedCount: Int {
            mutating get {
                willGetCompletedCount(&state)
            }
            
            set {
                guard newValue != state.selfFraction.completed else {
                    return
                }
                
                state.selfFraction.completed = newValue
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total!, completedCount: state.selfFraction.completed))
                
                if let _ = state.interopObservation.progressParentProgressReporterChild {
                    willNotifyObservers(.fractionUpdated(totalCount: state.selfFraction.total!, completedCount: state.selfFraction.completed), &state)
                }
                
                willMarkSelfDirty(state.parents)
            }
        }
        
        /// Returns a property value that a key path indicates. If value is not defined, returns property's `defaultValue`.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value {
            get {
                return state.properties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value ?? P.self.defaultValue
            }
            
            set {
                guard newValue != state.properties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value else {
                    return
                }
                
                state.properties[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                willMarkPropertyDirty(P.self, state.parents)
            }
        }
    }
    
    internal init(total: Int?, progressParentProgressManagerChildMessenger: ProgressManager?, managerObservation: _ProgressParentProgressManagerChild?) {
        let state = State(
            interopChild: nil,
            selfFraction: ProgressFraction(completed: 0, total: total),
            children: [],
            parents: [],
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
                    totalCount: state.selfFraction.total!,
                    completedCount: state.selfFraction.completed
                )
            )
            if let _ = state.interopObservation.progressParentProgressReporterChild {
                notifyObserversLocked(
                    with: .fractionUpdated(
                        totalCount: state.selfFraction.total!,
                        completedCount: state.selfFraction.completed
                    ),
                    state: &state
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
    public func summary<P: Property>(of property: P.Type) -> P.Summary {
//        _$observationRegistrar.access(self, keyPath: \.state)
        return getUpdatedSummary(property: property)
    }
    
    /// Returns the aggregated result of values.
    /// - Parameters:
    ///   - property: Type of property.
//    public func total<P: ProgressManager.Property>(of property: P.Type) -> P.Summary where P.Value: AdditiveArithmetic {
//        return getUpdatedValues(property: property, includeSelf: true)
//    }
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        return try state.withLock { (state) throws(E) -> T in
            var values = Values(state: state, willGetCompletedCount: { updatedState in
                self.getCompletedCountLocked(state: &updatedState)
            }, willMarkSelfDirty: { parents in
                self.markSelfDirty(parents: parents)
            }, willMarkPropertyDirty: { property, parents in
                self.markSelfDirty(property: property, parents: parents)
            }, willNotifyObservers: { observerState, state in
                self.notifyObserversLocked(with: observerState, state: &state)
            })
            // This is done to avoid copy on write later
            state = State(
                selfFraction: ProgressFraction(),
                children: [],
                parents: [],
                properties: [:],
                interopObservation: InteropObservation(progressParentProgressManagerChild: nil),
                progressParentProgressManagerChildMessenger: nil,
                observers: []
            )
            let result = try closure(&values)
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
    
    /// Returns nil if `self` was instantiated without total units;
    /// returns a `Int` value otherwise.
    private func getTotalCountLocked(state: State) -> Int? {
        if let interopChild = state.interopChild {
            return interopChild.totalCount
        }
        return state.selfFraction.total
    }
    
    /// Returns 0 if `self` has `nil` total units;
    /// returns a `Int` value otherwise.
    private func getCompletedCountLocked(state: inout State) -> Int {
        if let interopChild = state.interopChild {
            return interopChild.completedCount
        }
        
        updateChildrenProgressFractionLocked(state: &state)

        return state.selfFraction.completed
    }
    
    /// Returns 0.0 if `self` has `nil` total units;
    /// returns a `Double` otherwise.
    /// If `indeterminate`, return 0.0.
    ///
    /// The calculation of fraction completed for a ProgressManager instance that has children
    /// will take into account children's fraction completed as well.
    private func getFractionCompleted() -> Double {
        return state.withLock { state in
            if let interopChild = state.interopChild {
                return interopChild.fractionCompleted
            }
            
            updateChildrenProgressFractionLocked(state: &state)

            return state.overallFraction.fractionCompleted
        }
    }

    /// Returns `true` if completed and total units are not `nil` and completed units is greater than or equal to total units;
    /// returns `false` otherwise.
    private func getIsFinished() -> Bool {
        return state.withLock { state in
            state.selfFraction.isFinished
        }
    }
    
    /// Returns `true` if `self` has `nil` total units.
    private func getIsIndeterminate() -> Bool {
        return state.withLock { state in
            state.selfFraction.isIndeterminate
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
    
    private func getUpdatedProgressFraction() -> ProgressFraction {
        return state.withLock { state in
            updateChildrenProgressFractionLocked(state: &state)
            return state.overallFraction
        }
    }
    
    private func updateChildrenProgressFractionLocked(state: inout State) {
        if state.children.count > 0 {
            for i in 0..<state.children.count {
                if state.children[i].isDirty {
                    if let child = state.children[i].child {
                        let updatedProgressFraction = child.getUpdatedProgressFraction()
                        state.children[i] = ChildState(child: child,
                                                       portionOfTotal: state.children[i].portionOfTotal,
                                                       childFraction: updatedProgressFraction,
                                                       isDirty: false,
                                                       childProperties: state.children[i].childProperties)
                        if updatedProgressFraction.isFinished {
                            state.selfFraction.completed += state.children[i].portionOfTotal
                        }
                    } else {
                        state.children[i] = ChildState(child: nil,
                                                       portionOfTotal: state.children[i].portionOfTotal,
                                                       childFraction: state.children[i].childFraction,
                                                       isDirty: false,
                                                       childProperties: state.children[i].childProperties)
                        state.selfFraction.completed += state.children[i].portionOfTotal
                    }
                }
            }
        }
    }
    
    // MARK: Additional Properties Methods (Dual Mode of Operations)
    private func markSelfDirty<P: Property>(property: P.Type, parents: [ParentState]) {
        if parents.count > 0 {
            for parentState in parents {
                parentState.parent.markChildDirty(property: property, at: parentState.positionInParent)
            }
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
            var value: P.Summary = P.defaultSummary
            P.reduce(into: &value, value: state.properties[AnyMetatypeWrapper(metatype: property)] as? P.Value ?? P.defaultValue)
            if state.children.count > 0 {
                for i in 0..<state.children.count {
                    if let childPropertyState = state.children[i].childProperties[AnyMetatypeWrapper(metatype: property)] {
                        if childPropertyState.isDirty {
                            if let child = state.children[i].child {
                                let updatedSummary = child.getUpdatedSummary(property: property)
                                state.children[i].childProperties[AnyMetatypeWrapper(metatype: property)]! = PropertyState(value: updatedSummary, isDirty: false)
                                value = P.merge(value, updatedSummary)
                            }
                        } else {
                            value = P.merge(value, childPropertyState.value as? P.Summary ?? P.defaultSummary)
                        }
                    } else {
                        if let child = state.children[i].child {
                            let childSummary = child.getUpdatedSummary(property: property)
                            state.children[i].childProperties[AnyMetatypeWrapper(metatype: property)] = PropertyState(value: childSummary, isDirty: false)
                            value = P.merge(value, childSummary)
                        }
                    }
                }
            }
            return value
        }
    }
    
    private func setPropertyState<P: Property>(property: P.Type, value: P.Summary, at position: Int) {
        state.withLock { state in
            state.children[position].childProperties[AnyMetatypeWrapper(metatype: property)] = PropertyState(value: value, isDirty: false)
        }
    }
    
    internal func getProperties<T, E: Error>(
        _ closure: (sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        try state.withLock { state throws(E) -> T in
            let values = Values(state: state, willGetCompletedCount: { updatedState in
                self.getCompletedCountLocked(state: &updatedState)
            }, willMarkSelfDirty: { parents in
                self.markSelfDirty(parents: parents)
            }, willMarkPropertyDirty: { property, parents in
                self.markSelfDirty(property: property, parents: parents)
            }, willNotifyObservers: { observerState, state in
                self.notifyObserversLocked(with: observerState, state: &state)
            })
            let result = try closure(values)
            return result
        }
    }
    
    //MARK: Parent - Child Relationship Methods
    internal func addChild(child: ProgressManager, portion: Int, childFraction: ProgressFraction) -> Int {
        let index = state.withLock { state in
            let childState = ChildState(child: child, portionOfTotal: portion, childFraction: childFraction, isDirty: true, childProperties: [:])
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
    private func notifyObservers(with observedState: ObserverState) {
        state.withLock { state in
            for observer in state.observers {
                observer(observedState)
            }
        }
    }
    
    private func notifyObserversLocked(with observedState: ObserverState, state: inout State) {
        for observer in state.observers {
            observer(observedState)
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
        
        let parents = state.withLock { state in
            return state.parents
        }
        
        for parentState in parents {
            parentState.parent.setPropertyState(property: ProgressManager.Properties.TotalFileCount.self, value: self.summary(of: ProgressManager.Properties.TotalFileCount.self), at: parentState.positionInParent)
            
            parentState.parent.setPropertyState(property: ProgressManager.Properties.CompletedFileCount.self, value: self.summary(of: ProgressManager.Properties.CompletedFileCount.self), at: parentState.positionInParent)
            
            parentState.parent.setPropertyState(property: ProgressManager.Properties.TotalByteCount.self, value: self.summary(of: ProgressManager.Properties.TotalByteCount.self), at: parentState.positionInParent)

            parentState.parent.setPropertyState(property: ProgressManager.Properties.CompletedByteCount.self, value: self.summary(of: ProgressManager.Properties.CompletedByteCount.self), at: parentState.positionInParent)
            
            parentState.parent.setPropertyState(property: ProgressManager.Properties.Throughput.self, value: self.summary(of: ProgressManager.Properties.Throughput.self), at: parentState.positionInParent)
            
            parentState.parent.setPropertyState(property: ProgressManager.Properties.EstimatedTimeRemaining.self, value: self.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self), at: parentState.positionInParent)
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
