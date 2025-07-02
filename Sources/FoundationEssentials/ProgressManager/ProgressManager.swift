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
// ProgressManager
/// An object that conveys ongoing progress to the user for a specified task.
@Observable public final class ProgressManager: Sendable {
    
    // Stores the information on each child added to children
    internal struct ChildState {
        weak var child: ProgressManager?
        var portionOfTotal: Int
        var childFraction: _ProgressFraction // Fraction adjusted based on portion of self; If not dirty, overallFraction should be composed of this
        var isDirty: Bool
    }
    
    internal struct ParentState {
        var parent: ProgressManager
        var positionInParent: Int // My position in this parent's children array
    }
    
    // Interop states to notify observers
    internal enum ObserverState {
        case fractionUpdated(totalCount: Int, completedCount: Int)
    }
    
    // Mirroring observation to be kept alive
    internal struct InteropObservation {
        // Formerly interopObservation, interopObservationForMonitor, parentBridge
        var progressParentProgressManagerChild: _ProgressParentProgressManagerChild? // Set when init
        var progressParentProgressReporterChild: _ProgressParentProgressReporterChild? = nil // Set when setInteropObservationForReporter is called
        #if FOUNDATION_FRAMEWORK
        var parentBridge: Foundation.Progress? = nil // Set when setParentBridge is called
        #endif
    }
    
    // Stores all the state of properties
    internal struct State {
        var interopChild: ProgressManager? // read from this if self is actually an interop ghost
        var indeterminate: Bool
        var selfFraction: _ProgressFraction
        var overallFraction: _ProgressFraction {
            var overallFraction = selfFraction
            for child in children {
                overallFraction = overallFraction + (_ProgressFraction(completed: child.portionOfTotal, total: selfFraction.total) * child.childFraction)
            }
            return overallFraction
        }
        var children: [ChildState]
//        var otherProperties: [AnyMetatypeWrapper: (any Sendable)]
//        var childrenOtherProperties: [AnyMetatypeWrapper: OrderedDictionary<ProgressManager, [(any Sendable)]>] // Type: Metatype maps to dictionary of child to value
        // Interop properties - only kept alive
        var interopObservation: InteropObservation
        // Interop properties - Actually set and called
        var progressParentProgressManagerChildMessenger: ProgressManager? // set at init, used to call notify observers
        var observers: [@Sendable (ObserverState) -> Void] = [] // storage for all observers, set upon calling addObservers
    }
    
    private let state: Mutex<State>
    private let parents: Mutex<[ParentState]>
    
    /// The total units of work.
    public var totalCount: Int? {
        _$observationRegistrar.access(self, keyPath: \.totalCount)
        return state.withLock { state in
            getTotalCount(state: &state)
        }
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        _$observationRegistrar.access(self, keyPath: \.completedCount)
        return state.withLock { state in
            getCompletedCount(state: &state)
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
        return state.withLock { state in
            getIsIndeterminate(state: &state)
        }
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        _$observationRegistrar.access(self, keyPath: \.isFinished)
        return state.withLock { state in
            getIsFinished(state: &state)
        }
    }
    
    /// A `ProgressReporter` instance, used for providing read-only observation of progress updates or composing into other `ProgressManager`s.
    public var reporter: ProgressReporter {
        return .init(manager: self)
    }
    
    /// A type that conveys task-specific information on progress.
    public protocol Property {
        
        associatedtype Value: Sendable, Hashable, Equatable
        
        /// The default value to return when property is not set to a specific value.
        static var defaultValue: Value { get }
    }
    
    /// A container that holds values for properties that specify information on progress.
//    @dynamicMemberLookup
    public struct Values : Sendable {
        //TODO: rdar://149225947 Non-escapable conformance
        let manager: ProgressManager
        var state: State
        
        /// The total units of work.
        public var totalCount: Int? {
            mutating get {
                manager.getTotalCount(state: &state)
            }
            
            set {
                // if newValue is nil, reset indeterminate to true
                if newValue != nil {
                    state.indeterminate = false
                } else {
                    state.indeterminate = true
                }
                state.selfFraction.total = newValue ?? 0
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total, completedCount: state.selfFraction.completed))
                
                if let _ = state.interopObservation.progressParentProgressReporterChild {
                    manager.notifyObservers(with: .fractionUpdated(totalCount: state.selfFraction.total, completedCount: state.selfFraction.completed), state: &state)
                }
                manager.markDirtyInParents()
            }
        }
        
        
        /// The completed units of work.
        public var completedCount: Int {
            mutating get {
                manager.getCompletedCount(state: &state)
            }
            
            set {
                //TODO: Update self completedCount and notify parents that I am dirty
                state.selfFraction.completed = newValue
                
                state.progressParentProgressManagerChildMessenger?.notifyObservers(with:.fractionUpdated(totalCount: state.selfFraction.total, completedCount: state.selfFraction.completed))
                if let _ = state.interopObservation.progressParentProgressReporterChild  {
                    manager.notifyObservers(
                        with: .fractionUpdated(
                            totalCount: state.selfFraction.total,
                            completedCount: state.selfFraction.completed
                        ),
                        state: &state
                    )
                }
                manager.markDirtyInParents()
            }
        }
        
        /// Returns a property value that a key path indicates. If value is not defined, returns property's `defaultValue`.
//        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value {
//            get {
//                return state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value ?? P.self.defaultValue
//            }
//            
//            set {
//                // Update my own other properties entry
//                state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] = newValue
//                
//                // Generate an array of myself + children values of the property
//                let flattenedChildrenValues: [P.Value] = {
//                    let childrenDictionary = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: P.self)]
//                    var childrenValues: [P.Value] = []
//                    if let dictionary = childrenDictionary {
//                        for (_, value) in dictionary {
//                            if let value = value as? [P.Value] {
//                                childrenValues.append(contentsOf: value)
//                            }
//                        }
//                    }
//                    return childrenValues
//                }()
//                
//                // Send the array of myself + children values of property to parents
//                let updateValueForParent: [P.Value] = [newValue] + flattenedChildrenValues
//                for parentState in state.parents {
//                    parentState.parent.updateChildrenOtherProperties(property: P.self, child: manager, value: updateValueForParent)
//                }
//                
//            }
//        }
    }
    
    internal init(total: Int?, progressParentProgressManagerChildMessenger: ProgressManager?, managerObservation: _ProgressParentProgressManagerChild?) {
        let state = State(
            interopChild: nil,
            indeterminate:  total == nil ? true : false,
            selfFraction: _ProgressFraction(completed: 0, total: total ?? 0),
            children: [],
//            otherProperties: [:],
//            childrenOtherProperties: [:],
            interopObservation: InteropObservation(progressParentProgressManagerChild: managerObservation),
            progressParentProgressManagerChildMessenger: progressParentProgressManagerChildMessenger
        )
        self.state = Mutex(state)
        self.parents = Mutex([])
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
        
        // get the actual progress from within the reporter, then add as children
        let actualManager = reporter.manager
        
        // Add reporter as child + Add self as parent
        let position = self.addToChildren(child: actualManager, portion: count, childFraction: actualManager.getProgressFraction())
        actualManager.addParent(parent: self, positionInParent: position)
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        // Update self fraction + mark dirty
        state.withLock { state in
            state.selfFraction.completed += count
            
            state.progressParentProgressManagerChildMessenger?.notifyObservers(
                with: .fractionUpdated(
                    totalCount: state.selfFraction.total,
                    completedCount: state.selfFraction.completed
                )
            )
            if let _ = state.interopObservation.progressParentProgressReporterChild  {
                notifyObservers(
                    with: .fractionUpdated(
                        totalCount: state.selfFraction.total,
                        completedCount: state.selfFraction.completed
                    ),
                    state: &state
                )
            }
        }
        
        markDirtyInParents()
    }
    
//    /// Returns an array of values for specified property in subtree.
//    /// - Parameter metatype: Type of property.
//    /// - Returns: Array of values for property.
//    public func values<P: Property>(of property: P.Type) -> [P.Value] {
////        _$observationRegistrar.access(self, keyPath: \.state)
//        return state.withLock { state in
//            let childrenValues = getFlattenedChildrenValues(property: property, state: &state)
//            return [state.otherProperties[AnyMetatypeWrapper(metatype: property)] as? P.Value ?? P.defaultValue] + childrenValues.map { $0 ?? P.defaultValue }
//        }
//    }
//    
//    
//    /// Returns the aggregated result of values.
//    /// - Parameters:
//    ///   - property: Type of property.
//    public func total<P: ProgressManager.Property>(of property: P.Type) -> P.Value where P.Value: AdditiveArithmetic {
//        let droppedNil = values(of: property).compactMap { $0 }
//        return droppedNil.reduce(P.Value.zero, +)
//    }
//    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        return try state.withLock { (state) throws(E) -> T in
            var values = Values(manager: self, state: state)
            // This is done to avoid copy on write later
            state = State(
                indeterminate: true,
                selfFraction: _ProgressFraction(),
                children: [],
//                otherProperties: [:],
//                childrenOtherProperties: [:],
                interopObservation: InteropObservation()
            )
            let result = try closure(&values)
            state = values.state
            return result
        }
    }
    
    //MARK: ProgressManager Properties getters
    internal func getProgressFraction() -> _ProgressFraction {
        return state.withLock { state in
            return state.selfFraction
        }
    }
    
    /// Returns nil if `self` was instantiated without total units;
    /// returns a `Int` value otherwise.
    private func getTotalCount(state: inout State) -> Int? {
        if let interopChild = state.interopChild {
            return interopChild.totalCount
        }
        if state.indeterminate {
            return nil
        } else {
            return state.selfFraction.total
        }
    }
    
    /// Returns 0 if `self` has `nil` total units;
    /// returns a `Int` value otherwise.
    private func getCompletedCount(state: inout State) -> Int {
        if let interopChild = state.interopChild {
            return interopChild.completedCount
        }
        // Implementation thoughts:
        // If self is dirty, that just means I got mutated and my parents haven't received updates.
        // If my dirtyChildren list exists, that just means I have fractional updates from children, which might not have completed.
        // If at least one of my dirtyChildren actually completed, that means I would need to update my completed count actually.
    
        // If there are dirty children, get updates first
        if state.children.count > 0 {
            for childState in state.children {
                if childState.isDirty {
                    // if this path is dirty, update child state's selfFraction and mark not dirty
                }
            }
        }
        
        // Return the actual completedCount
        return state.selfFraction.completed
    }
    
    /// Returns 0.0 if `self` has `nil` total units;
    /// returns a `Double` otherwise.
    /// If `indeterminate`, return 0.0.
    ///
    /// The calculation of fraction completed for a ProgressManager instance that has children
    /// will take into account children's fraction completed as well.
    private func getFractionCompleted() -> Double {
        // Implementation thoughts: 
        // If my self is dirty, that means I got mutated and I have parents that haven't received updates from me.
        // If my dirtyChildren list exists, that means I have fractional updates from these children, and I need these fractional updates.
        // But this runs into the issue of updating only the queried branch, but not the other branch that is not queried but dirty, this would cause the leaf to be cleaned up, but the other branch which share the dirty leaf hasn't received any updates.
        
        // If I am clean leaf and has no dirtyChildren, directly return fractionCompleted - no need to do recalculation whenn unnecessary
        // If I am dirty leaf and no dirtyChildren, directly return fractionCompleted - no need to do recalculation when unnecessary
        // If I am dirty leaf and also has dirtyChildren - get updates
        // If I am clean leaf and has dirtyChildren - get updates
        return state.withLock { state in
            // Interop child
            if let interopChild = state.interopChild {
                return interopChild.fractionCompleted
            }
            
            // Indeterminate
            if state.indeterminate {
                return 0.0
            }
            
            // If there are children, ask children to give updated values & store them
            if state.children.count > 0 {
                for i in 0...state.children.endIndex {
                    if state.children[i].isDirty {
                        if let child = state.children[i].child {
                            let updatedProgressFraction = child.getDirtyProgressFraction()
                            state.children[i] = ChildState(child: child,
                                                           portionOfTotal: state.children[i].portionOfTotal,
                                                           childFraction: updatedProgressFraction,
                                                           isDirty: false)
                        }
                    }
                }
            }
            
            return state.overallFraction.fractionCompleted
        }
    }

    /// Returns `true` if completed and total units are not `nil` and completed units is greater than or equal to total units;
    /// returns `false` otherwise.
    private func getIsFinished(state: inout State) -> Bool {
        return state.selfFraction.isFinished
    }
    
    
    /// Returns `true` if `self` has `nil` total units.
    private func getIsIndeterminate(state: inout State) -> Bool {
        return state.indeterminate
    }
    
    //MARK: FractionCompleted Calculation methods
    /// If parents exist, mark self as dirty and send dirtyState to parent.
    private func markDirtyInParents() {
        // Recursively add self as dirty child to parents list
        parents.withLock { parents in
            for parentState in parents {
                parentState.parent.markChildDirty(at: parentState.positionInParent)
            }
        }
    }
    
    /// Mark child at given index as dirty.
    private func markChildDirty(at position: Int) {
        state.withLock { state in
            state.children[position].isDirty = true
        }
        markDirtyInParents()
    }
    
    private func getDirtyProgressFraction() -> _ProgressFraction {
        return state.withLock { state in
            if state.children.count > 0 {
                for i in 0...state.children.endIndex {
                    if state.children[i].isDirty {
                        if let child = state.children[i].child {
                            let updatedProgressFraction = child.getDirtyProgressFraction()
                            state.children[i] = ChildState(child: child,
                                                           portionOfTotal: state.children[i].portionOfTotal,
                                                           childFraction: updatedProgressFraction,
                                                           isDirty: false)
                        }
                    }
                }
            }
            return state.selfFraction
        }
    }

    //MARK: Interop-related internal methods
    /// Adds `observer` to list of `_observers` in `self`.
    internal func addObserver(observer: @escaping @Sendable (ObserverState) -> Void) {
        state.withLock { state in
            state.observers.append(observer)
        }
    }
    
    /// Notifies all `_observers` of `self` when `state` changes.
    private func notifyObservers(with observedState: ObserverState) {
        state.withLock {state in
            for observer in state.observers {
                observer(observedState)
            }
        }
    }
    
    private func notifyObservers(with observedState: ObserverState, state: inout State) {
        for observer in state.observers {
            observer(observedState)
        }
    }
    
    internal func setInteropObservationForReporter(observation reporterObservation: _ProgressParentProgressReporterChild) {
        state.withLock { state in
            state.interopObservation.progressParentProgressReporterChild = reporterObservation
        }
    }

    
    //MARK: Internal methods to mutate locked context
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
    
    // Adds a child to the children list, with all of the info fields populated
    internal func addToChildren(child: ProgressManager, portion: Int, childFraction: _ProgressFraction) -> Int {
        let index = state.withLock { state in
            let childState = ChildState(child: child, portionOfTotal: portion, childFraction: childFraction, isDirty: true)
            state.children.append(childState)
            return state.children.count - 1
        }
        return index
    }
    
    internal func addParent(parent: ProgressManager, positionInParent: Int) {
        parents.withLock { parents in
            let parentState = ParentState(parent: parent, positionInParent: positionInParent)
            parents.append(parentState)
        }
            // Update metatype entry in parent
//            for (metatype, value) in state.otherProperties {
//                let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
//                let updatedParentEntry: [(any Sendable)?] = [value] + childrenValues
//                parent.updateChildrenOtherPropertiesAnyValue(property: metatype, child: self, value: updatedParentEntry)
//            }

    }
    
    internal func getAdditionalProperties<T, E: Error>(
        _ closure: (sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        try state.withLock { state throws(E) -> T in
            let values = Values(manager: self, state: state)
            // No need to modify state since this is read-only
            let result = try closure(values)
            // No state update after closure execution
            return result
        }
    }
    
    // MARK: Propagation of Additional Properties Methods (Dual Mode of Operations)
//    private func getFlattenedChildrenValues<P: Property>(property metatype: P.Type, state: inout State) -> [P.Value?] {
//        let childrenDictionary = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]
//        var childrenValues: [P.Value?] = []
//        if let dictionary = childrenDictionary {
//            for (_, value) in dictionary {
//                if let value = value as? [P.Value?] {
//                    childrenValues.append(contentsOf: value)
//                }
//            }
//        }
//        return childrenValues
//    }
//    
//    private func getFlattenedChildrenValues(property metatype: AnyMetatypeWrapper, state: inout State) -> [(any Sendable)?] {
//        let childrenDictionary = state.childrenOtherProperties[metatype]
//        var childrenValues: [(any Sendable)?] = []
//        if let dictionary = childrenDictionary {
//            for (_, value) in dictionary {
//                childrenValues.append(contentsOf: value)
//            }
//        }
//        return childrenValues
//    }
//    
//    private func updateChildrenOtherPropertiesAnyValue(property metatype: AnyMetatypeWrapper, child: ProgressManager, value: [(any Sendable)?]) {
//        state.withLock { state in
//            let myEntries = state.childrenOtherProperties[metatype]
//            if myEntries != nil {
//                // If entries is not nil, then update my entry of children values
//                state.childrenOtherProperties[metatype]![child] = value
//            } else {
//                // If entries is nil, initialize then update my entry of children values
//                state.childrenOtherProperties[metatype] = [:]
//                state.childrenOtherProperties[metatype]![child] = value
//            }
//            // Ask parent to update their entry with my value + new children value
//            let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
//            let updatedParentEntry: [(any Sendable)?] = [state.otherProperties[metatype]] + childrenValues
//            for (parent, _) in state.parents {
//                parent.updateChildrenOtherPropertiesAnyValue(property: metatype, child: child, value: updatedParentEntry)
//            }
//        }
//    }
//    
//    private func updateChildrenOtherProperties<P: Property>(property metatype: P.Type, child: ProgressManager, value: [P.Value?]) {
//        state.withLock { state in
//            let myEntries = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]
//            if myEntries != nil {
//                // If entries is not nil, then update my entry of children values
//                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![child] = value
//            } else {
//                // If entries is nil, initialize then update my entry of children values
//                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] = [:]
//                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![child] = value
//            }
//            // Ask parent to update their entry with my value + new children value
//            let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
//            let updatedParentEntry: [P.Value?] = [state.otherProperties[AnyMetatypeWrapper(metatype: metatype)] as? P.Value] + childrenValues
//            
//            for (parent, _) in state.parents {
//                parent.updateChildrenOtherProperties(property: metatype, child: self, value: updatedParentEntry)
//            }
//            
//        }
//    }
    
    // MARK: Cycle detection
    func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if reporter.manager === self {
            return true
        }
        
        let updatedVisited = visited.union([self])
        
        return parents.withLock { parents in
            for parentState in parents {
                if !updatedVisited.contains(parentState.parent) {
                    if parentState.parent.isCycle(reporter: reporter, visited: updatedVisited) {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    func isCycleInterop(visited: Set<ProgressManager> = []) -> Bool {
        return parents.withLock { parents in
            for parentState in parents {
                if !visited.contains(parentState.parent) {
                    if parentState.parent.isCycle(reporter: reporter, visited: visited) {
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
    }
}
    
@available(FoundationPreview 6.2, *)
// Hashable & Equatable Conformance
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
extension ProgressManager: CustomDebugStringConvertible {
    /// The description for `completedCount` and `totalCount`.
    public var debugDescription: String {
        return self.description
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressManager: CustomStringConvertible {
    public var description: String {
        return """
        ObjectIdentifier: \(ObjectIdentifier(self))
        totalCount: \(String(describing: totalCount))
        completedCount: \(completedCount)
        fractionCompleted: \(fractionCompleted)
        isIndeterminate: \(isIndeterminate)
        isFinished: \(isFinished)
        """
        
//        totalFileCount: \(values(of: ProgressManager.Properties.TotalFileCount.self))
//        completedFileCount: \(values(of: ProgressManager.Properties.CompletedFileCount.self))
//        totalByteCount: \(values(of: ProgressManager.Properties.TotalByteCount.self))
//        completedByteCount: \(values(of: ProgressManager.Properties.CompletedByteCount.self))
//        throughput: \(values(of: ProgressManager.Properties.Throughput.self))
//        estimatedTimeRemaining: \(values(of: ProgressManager.Properties.EstimatedTimeRemaining.self))
    }
}
