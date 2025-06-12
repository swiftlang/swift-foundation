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
    
    // Stores all the state of properties
    internal struct State {
        var interopChild: ProgressManager? // read from this if self is actually an interop ghost
        var isDirty: Bool
        var dirtyChildren: Set<ProgressManager> = Set()
        var indeterminate: Bool
        var selfFraction: _ProgressFraction
        var overallFraction: _ProgressFraction {
            var overallFraction = selfFraction
            for child in children {
                overallFraction = overallFraction + (_ProgressFraction(completed: child.value.portionOfSelf, total: selfFraction.total) * child.value.childFraction)
            }
            return overallFraction
        }
        var children: [ProgressManager: ChildState] // My children and their information in relation to me
        var parents: [ProgressManager: Int] // My parents and their information in relation to me, how much of their totalCount I am a part of
        var otherProperties: [AnyMetatypeWrapper: (any Sendable)]
        var childrenOtherProperties: [AnyMetatypeWrapper: OrderedDictionary<ProgressManager, [(any Sendable)]>] // Type: Metatype maps to dictionary of child to value
    }
    
    internal struct ChildState {
        var portionOfSelf: Int // Portion of my totalCount that this child accounts for
        var childFraction: _ProgressFraction // Fraction adjusted based on portion of self; If not dirty, overallFraction should be composed of this
    }
    
    private let state: LockedState<State>
    
    // Interop states
    internal enum ObserverState {
        case fractionUpdated
        case totalCountUpdated
    }
    
    // Interop properties - Just kept alive
    internal let interopObservation: (any Sendable)? // set at init
    internal let interopObservationForMonitor: LockedState<(any Sendable)?> = LockedState(initialState: nil)
    internal let monitorInterop: LockedState<Bool> = LockedState(initialState: false)
    
#if FOUNDATION_FRAMEWORK
    internal let parentBridge: LockedState<Foundation.Progress?> = LockedState(initialState: nil) // dummy, set upon calling setParentBridge
#endif
    // Interop properties - Actually set and called
    internal let ghostReporter: ProgressManager? // set at init, used to call notify observers
    internal let observers: LockedState<[@Sendable (ObserverState) -> Void]> = LockedState(initialState: [])// storage for all observers, set upon calling addObservers
    
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
        return state.withLock { state in
            getFractionCompleted(state: &state)
        }
        
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
    @dynamicMemberLookup
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
                manager.markDirty(state: &state)
                
                manager.ghostReporter?.notifyObservers(with: .totalCountUpdated)
                manager.monitorInterop.withLock { [manager] interop in
                    if interop == true {
                        manager.notifyObservers(with: .totalCountUpdated)
                    }
                }
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
                manager.markDirty(state: &state)
                
                manager.ghostReporter?.notifyObservers(with: .fractionUpdated)
                
                manager.monitorInterop.withLock { [manager] interop in
                    if interop == true {
                        manager.notifyObservers(with: .fractionUpdated)
                    }
                }
            }
        }
        
        /// Returns a property value that a key path indicates. If value is not defined, returns property's `defaultValue`.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value {
            get {
                return state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] as? P.Value ?? P.self.defaultValue
            }
            
            set {
                // Update my own other properties entry
                state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] = newValue
                
                // Generate an array of myself + children values of the property
                let flattenedChildrenValues: [P.Value] = {
                    let childrenDictionary = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: P.self)]
                    var childrenValues: [P.Value] = []
                    if let dictionary = childrenDictionary {
                        for (_, value) in dictionary {
                            if let value = value as? [P.Value] {
                                childrenValues.append(contentsOf: value)
                            }
                        }
                    }
                    return childrenValues
                }()
                
                // Send the array of myself + children values of property to parents
                let updateValueForParent: [P.Value] = [newValue] + flattenedChildrenValues
                for (parent, _) in state.parents {
                    parent.updateChildrenOtherProperties(property: P.self, child: manager, value: updateValueForParent)
                }
                
            }
        }
    }
    
    internal init(total: Int?, ghostReporter: ProgressManager?, interopObservation: (any Sendable)?) {
        let state = State(
            interopChild: nil,
            isDirty: false,
            dirtyChildren: Set<ProgressManager>(),
            indeterminate:  total == nil ? true : false,
            selfFraction: _ProgressFraction(completed: 0, total: total ?? 0),
            children: [:],
            parents: [:],
            otherProperties: [:],
            childrenOtherProperties: [:]
        )
        self.state = LockedState(initialState: state)
        self.interopObservation = interopObservation
        self.ghostReporter = ghostReporter
    }
    
    /// Initializes `self` with `totalCount`.
    ///
    /// If `totalCount` is set to `nil`, `self` is indeterminate.
    /// - Parameter totalCount: Total units of work.
    public convenience init(totalCount: Int?) {
        self.init(total: totalCount, ghostReporter: nil, interopObservation: nil)
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
        self.addToChildren(child: actualManager, portion: count, childFraction: actualManager.getProgressFraction())
        actualManager.addParent(parent: self, portionOfParent: count)
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        // Update self fraction + mark dirty
        state.withLock { state in
            state.selfFraction.completed += count
            markDirty(state: &state)
        }
        
        // Interop updates stuff
        ghostReporter?.notifyObservers(with: .fractionUpdated)
        monitorInterop.withLock { [self] interop in
            if interop == true {
                notifyObservers(with: .fractionUpdated)
            }
        }
    }
    
    /// Returns an array of values for specified property in subtree.
    /// - Parameter metatype: Type of property.
    /// - Returns: Array of values for property.
    public func values<P: Property>(of property: P.Type) -> [P.Value] {
        _$observationRegistrar.access(self, keyPath: \.state)
        return state.withLock { state in
            let childrenValues = getFlattenedChildrenValues(property: property, state: &state)
            return [state.otherProperties[AnyMetatypeWrapper(metatype: property)] as? P.Value ?? P.defaultValue] + childrenValues.map { $0 ?? P.defaultValue }
        }
    }
    
    
    /// Returns the aggregated result of values.
    /// - Parameters:
    ///   - property: Type of property.
    public func total<P: ProgressManager.Property>(of property: P.Type) -> P.Value where P.Value: AdditiveArithmetic {
        let droppedNil = values(of: property).compactMap { $0 }
        return droppedNil.reduce(P.Value.zero, +)
    }
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T, E: Error>(
        _ closure: (inout sending Values) throws(E) -> sending T
    ) throws(E) -> sending T {
        return try state.withLock { (state) throws(E) -> T in
            var values = Values(manager: self, state: state)
            // This is done to avoid copy on write later
            state = State(
                isDirty: false,
                indeterminate: true,
                selfFraction: _ProgressFraction(),
                children: [:],
                parents: [:],
                otherProperties: [:],
                childrenOtherProperties: [:])
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
        
//        // If self is dirty, that just means I got mutated and my parents haven't received updates.
//        // If my dirtyChildren list exists, that just means I have fractional updates from children, which might not have completed.
//        // If at least one of my dirtyChildren actually completed, that means I would need to update my completed count actually.

//        let completedDirtyChildren = state.dirtyChildren.filter(\.isFinished)
//        if !completedDirtyChildren.isEmpty {
//            // update my own value based on dirty children completion
//            for completedChild in completedDirtyChildren {
//                // Update my completed count with the portion I assigned to this child
//                state.selfFraction.completed += state.children[completedChild]?.portionOfSelf ?? 0
//                // Remove child from dirtyChildren list, so that the future updates won't be messed up
//                state.dirtyChildren.remove(completedChild)
//            }
//        }
        
        // If there are dirty children, get updates first
        if state.dirtyChildren.count > 0 {
            
            // Get dirty leaves
            var dirtyLeaves: [ProgressManager] = []
            collectDirtyNodes(dirtyNodes: &dirtyLeaves, state: &state)
            
            // Then ask each dirty leaf to propagate values up
            for leaf in dirtyLeaves {
                leaf.updateState(exclude: self, lockedState: &state)
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
    private func getFractionCompleted(state: inout State) -> Double {
        // If my self is dirty, that means I got mutated and I have parents that haven't received updates from me.
        // If my dirtyChildren list exists, that means I have fractional updates from these children, and I need these fractional updates.
        // But this runs into the issue of updating only the queried branch, but not the other branch that is not queried but dirty, this would cause the leaf to be cleaned up, but the other branch which share the dirty leaf hasn't received any updates.
        
        // If I am clean leaf and has no dirtyChildren, directly return fractionCompleted - no need to do recalculation whenn unnecessary
        // If I am dirty leaf and no dirtyChildren, directly return fractionCompleted - no need to do recalculation when unnecessary
        // If I am dirty leaf and also has dirtyChildren - get updates
        // If I am clean leaf and has dirtyChildren - get updates
        
        // Interop child
        if let interopChild = state.interopChild {
            return interopChild.fractionCompleted
        }
        
        // Indeterminate
        if state.indeterminate {
            return 0.0
        }
        
        // If there are dirty children, get updates first
        if state.dirtyChildren.count > 0 {
            
            // Get dirty leaves
            var dirtyLeaves: [ProgressManager] = []
            collectDirtyNodes(dirtyNodes: &dirtyLeaves, state: &state)
            
            // Then ask each dirty leaf to propagate values up
            for leaf in dirtyLeaves {
                leaf.updateState(exclude: self, lockedState: &state)
            }
        }
        
        return state.overallFraction.fractionCompleted
    }
    
    /// Collect bottommost dirty nodes in a subtree
    private func collectDirtyNodes(dirtyNodes: inout [ProgressManager], state: inout State) {
            if state.dirtyChildren.isEmpty && state.isDirty {
                dirtyNodes += [self]
            } else {
                for child in state.dirtyChildren {
                    child.collectDirtyNodes(dirtyNodes: &dirtyNodes)
                }
            }
        }
        
    private func collectDirtyNodes(dirtyNodes: inout [ProgressManager]) {
        state.withLock { state in
            if state.dirtyChildren.isEmpty && state.isDirty {
                dirtyNodes += [self]
            } else {
                for child in state.dirtyChildren {
                    child.collectDirtyNodes(dirtyNodes: &dirtyNodes)
                }
            }
        }
    }
    
    private func updateState(exclude lockedRoot: ProgressManager?, lockedState: inout State, child: ProgressManager? = nil, fraction: _ProgressFraction? = nil) {
        // If I am the root which was queried.
        if self === lockedRoot {
            print("Called updateState on self. This should never be called by a root. Only called by a leaf")
            return
        }
        
        state.withLock { state in
            // Set isDirty to false
            state.isDirty = false
            
            // Propagate these changes up to parent
            for (parent, _) in state.parents {
                parent.updateChildState(exclude: lockedRoot, lockedState: &lockedState, child: self, fraction: state.overallFraction)
            }
        }
    }

    internal func updateChildState(exclude lockedRoot: ProgressManager?, lockedState: inout State, child: ProgressManager, fraction: _ProgressFraction) {
        if self === lockedRoot {
            print("I am locked. Lock not acquired. Use lockedState passed in.")
            lockedState.children[child]?.childFraction = fraction
            lockedState.dirtyChildren.remove(child)
            
            if fraction.isFinished {
                lockedState.selfFraction.completed += lockedState.children[child]?.portionOfSelf ?? 0
                lockedState.children.removeValue(forKey: child)
            }
            return
        }
        
        state.withLock { state in
            state.children[child]?.childFraction = fraction
            state.dirtyChildren.remove(child)
            
            if fraction.isFinished {
                state.selfFraction.completed += state.children[child]?.portionOfSelf ?? 0
            }
            
            for (parent, _) in state.parents {
                parent.updateChildState(exclude: lockedRoot, lockedState: &lockedState, child: self, fraction: state.overallFraction)
            }
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
    private struct UpdateState {
        let previous: _ProgressFraction
        let current: _ProgressFraction
    }
    
    /// If parents exist, mark self as dirty and add self to parents' dirty children list.
    private func markDirty(state: inout State) {
        if state.parents.count > 0 {
            state.isDirty = true
        }
        
        // Recursively add self as dirty child to parents list
        for (parent, _) in state.parents {
            parent.addDirtyChild(self)
        }
    
    }
    
    /// Add a given child to self's dirty children list.
    private func addDirtyChild(_ child: ProgressManager) {
        state.withLock { state in
            // Child already exists in dirty children
            if state.dirtyChildren.contains(child) {
                return
            }
            
            state.dirtyChildren.insert(child)
            
            // Propagate dirty state up to parents
            for (parent, _) in state.parents {
                parent.addDirtyChild(self)
            }
        }
    }
    
    // This is used when parent has its lock acquired and wants its child to update parent's childFraction to reflect child's own changes
//    private func updateChildFractionSpecial(of manager: ProgressManager, state managerState: inout State) {
//        let portion = parents.withLock { parents in
//            return parents[manager]
//        }
//        
//        if let portionOfParent = portion {
//            let myFraction = state.withLock { $0.overallFraction }
//
//            if !myFraction.isFinished {
//                // If I'm not finished, update my entry in parent's childFraction
//                managerState.childFraction = managerState.childFraction + _ProgressFraction(completed: portionOfParent, total: managerState.selfFraction.total) * myFraction
//            }
//        }
//    }
    
    //MARK: Interop-related internal methods
    /// Adds `observer` to list of `_observers` in `self`.
    internal func addObserver(observer: @escaping @Sendable (ObserverState) -> Void) {
        observers.withLock { observers in
            observers.append(observer)
        }
    }
    
    /// Notifies all `_observers` of `self` when `state` changes.
    private func notifyObservers(with state: ObserverState) {
        observers.withLock { observers in
            for observer in observers {
                observer(state)
            }
        }
    }
    
    internal func setInteropObservationForMonitor(observation monitorObservation: (any Sendable)) {
        interopObservationForMonitor.withLock { observation in
            observation = monitorObservation
        }
    }
    
    internal func setMonitorInterop(to value: Bool) {
        monitorInterop.withLock { monitorInterop in
            monitorInterop = value
        }
    }
    
    //MARK: Internal methods to mutate locked context
#if FOUNDATION_FRAMEWORK
    internal func setParentBridge(parentBridge: Foundation.Progress) {
        self.parentBridge.withLock { bridge in
            bridge = parentBridge
        }
    }
#endif
    
    internal func setInteropChild(interopChild: ProgressManager) {
        state.withLock { state in
            state.interopChild = interopChild
        }
    }
    
    // Adds a child to the children list, with all of the info fields populated
    internal func addToChildren(child: ProgressManager, portion: Int, childFraction: _ProgressFraction) {
        state.withLock { state in
            let childState = ChildState(portionOfSelf: portion, childFraction: childFraction)
            state.children[child] = childState
            
            // Add child to dirtyChildren list
            state.dirtyChildren.insert(child)
        }
    }
    
    internal func addParent(parent: ProgressManager, portionOfParent: Int) {
        state.withLock { state in
            state.parents[parent] = portionOfParent
            
            // Update metatype entry in parent
            for (metatype, value) in state.otherProperties {
                let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
                let updatedParentEntry: [(any Sendable)?] = [value] + childrenValues
                parent.updateChildrenOtherPropertiesAnyValue(property: metatype, child: self, value: updatedParentEntry)
            }
        }
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
    private func getFlattenedChildrenValues<P: Property>(property metatype: P.Type, state: inout State) -> [P.Value?] {
        let childrenDictionary = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]
        var childrenValues: [P.Value?] = []
        if let dictionary = childrenDictionary {
            for (_, value) in dictionary {
                if let value = value as? [P.Value?] {
                    childrenValues.append(contentsOf: value)
                }
            }
        }
        return childrenValues
    }
    
    private func getFlattenedChildrenValues(property metatype: AnyMetatypeWrapper, state: inout State) -> [(any Sendable)?] {
        let childrenDictionary = state.childrenOtherProperties[metatype]
        var childrenValues: [(any Sendable)?] = []
        if let dictionary = childrenDictionary {
            for (_, value) in dictionary {
                childrenValues.append(contentsOf: value)
            }
        }
        return childrenValues
    }
    
    private func updateChildrenOtherPropertiesAnyValue(property metatype: AnyMetatypeWrapper, child: ProgressManager, value: [(any Sendable)?]) {
        state.withLock { state in
            let myEntries = state.childrenOtherProperties[metatype]
            if myEntries != nil {
                // If entries is not nil, then update my entry of children values
                state.childrenOtherProperties[metatype]![child] = value
            } else {
                // If entries is nil, initialize then update my entry of children values
                state.childrenOtherProperties[metatype] = [:]
                state.childrenOtherProperties[metatype]![child] = value
            }
            // Ask parent to update their entry with my value + new children value
            let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
            let updatedParentEntry: [(any Sendable)?] = [state.otherProperties[metatype]] + childrenValues
            for (parent, _) in state.parents {
                parent.updateChildrenOtherPropertiesAnyValue(property: metatype, child: child, value: updatedParentEntry)
            }
        }
    }
    
    private func updateChildrenOtherProperties<P: Property>(property metatype: P.Type, child: ProgressManager, value: [P.Value?]) {
        state.withLock { state in
            let myEntries = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]
            if myEntries != nil {
                // If entries is not nil, then update my entry of children values
                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![child] = value
            } else {
                // If entries is nil, initialize then update my entry of children values
                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] = [:]
                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![child] = value
            }
            // Ask parent to update their entry with my value + new children value
            let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
            let updatedParentEntry: [P.Value?] = [state.otherProperties[AnyMetatypeWrapper(metatype: metatype)] as? P.Value] + childrenValues
            
            for (parent, _) in state.parents {
                parent.updateChildrenOtherProperties(property: metatype, child: self, value: updatedParentEntry)
            }
            
        }
    }
    
    // MARK: Cycle detection
    func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if reporter.manager === self {
            return true
        }
        
        let updatedVisited = visited.union([self])
        
        return state.withLock { state in
            for (parent, _) in state.parents {
                if !updatedVisited.contains(parent) {
                    if parent.isCycle(reporter: reporter, visited: updatedVisited) {
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
        return "\(completedCount) / \(totalCount ?? 0)"
    }
}
