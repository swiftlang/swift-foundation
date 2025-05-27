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

internal struct FractionState {
    var indeterminate: Bool
    var selfFraction: _ProgressFraction
    var childFraction: _ProgressFraction
    var overallFraction: _ProgressFraction {
        selfFraction + childFraction
    }
    var interopChild: ProgressManager? // read from this if self is actually an interop ghost
}

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
        var fractionState: FractionState
        var otherProperties: [AnyMetatypeWrapper: (any Sendable)]
        // Type: Metatype maps to dictionary of child to value
        var childrenOtherProperties: [AnyMetatypeWrapper: OrderedDictionary<ProgressManager, [(any Sendable)]>]
    }
    
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
            getTotalCount(fractionState: &state.fractionState)
        }
    }
    
    /// The completed units of work.
    /// If `self` is indeterminate, the value will be 0.
    public var completedCount: Int {
        _$observationRegistrar.access(self, keyPath: \.completedCount)
        return state.withLock { state in
            getCompletedCount(fractionState: &state.fractionState)
        }
    }
    
    /// The proportion of work completed.
    /// This takes into account the fraction completed in its children instances if children are present.
    /// If `self` is indeterminate, the value will be 0.
    public var fractionCompleted: Double {
        _$observationRegistrar.access(self, keyPath: \.fractionCompleted)
        return state.withLock { state in
            getFractionCompleted(fractionState: &state.fractionState)
        }
    }
    
    /// The state of initialization of `totalCount`.
    /// If `totalCount` is `nil`, the value will be `true`.
    public var isIndeterminate: Bool {
        _$observationRegistrar.access(self, keyPath: \.isIndeterminate)
        return state.withLock { state in
            getIsIndeterminate(fractionState: &state.fractionState)
        }
    }
    
    /// The state of completion of work.
    /// If `completedCount` >= `totalCount`, the value will be `true`.
    public var isFinished: Bool {
        _$observationRegistrar.access(self, keyPath: \.isFinished)
        return state.withLock { state in
            getIsFinished(fractionState: &state.fractionState)
        }
    }
    
    public var reporter: ProgressReporter {
        return .init(manager: self)
    }
    
    /// A type that conveys task-specific information on progress.
    public protocol Property {
        
        associatedtype Value: Sendable, Hashable, Equatable
        
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
                manager.getTotalCount(fractionState: &state.fractionState)
            }
            
            set {
                let previous = state.fractionState.overallFraction
                if state.fractionState.selfFraction.total != newValue && state.fractionState.selfFraction.total > 0 {
                    state.fractionState.childFraction = state.fractionState.childFraction * _ProgressFraction(completed: state.fractionState.selfFraction.total, total: newValue ?? 1)
                }
                state.fractionState.selfFraction.total = newValue ?? 0
                
                // if newValue is nil, reset indeterminate to true
                if newValue != nil {
                    state.fractionState.indeterminate = false
                } else {
                    state.fractionState.indeterminate = true
                }
                //TODO: rdar://149015734 Check throttling
                manager.updateFractionCompleted(from: previous, to: state.fractionState.overallFraction)
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
                manager.getCompletedCount(fractionState: &state.fractionState)
            }
            
            set {
                let prev = state.fractionState.overallFraction
                state.fractionState.selfFraction.completed = newValue
                manager.updateFractionCompleted(from: prev, to: state.fractionState.overallFraction)
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
                let flattenedChildrenValues: [P.Value?] = {
                    let childrenDictionary = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: P.self)]
                    var childrenValues: [P.Value?] = []
                    if let dictionary = childrenDictionary {
                        for (_, value) in dictionary {
                            if let value = value as? [P.Value?] {
                                childrenValues.append(contentsOf: value)
                            }
                        }
                    }
                    return childrenValues
                }()
                
                // Send the array of myself + children values of property to parents
                let updateValueForParent: [P.Value?] = [newValue] + flattenedChildrenValues
                manager.parents.withLock { [manager] parents in
                    for (parent, _) in parents {
                        parent.updateChildrenOtherProperties(property: P.self, child: manager, value: updateValueForParent)
                    }
                }
            }
        }
    }
    
    internal let parents: LockedState<[ProgressManager: Int]>
    private let children: LockedState<Set<ProgressManager>>
    private let state: LockedState<State>
    
    internal init(total: Int?, ghostReporter: ProgressManager?, interopObservation: (any Sendable)?) {
        self.parents = .init(initialState: [:])
        self.children = .init(initialState: Set())
        let fractionState = FractionState(
            indeterminate: total == nil ? true : false,
            selfFraction: _ProgressFraction(completed: 0, total: total ?? 0),
            childFraction: _ProgressFraction(completed: 0, total: 1),
            interopChild: nil
        )
        let state = State(fractionState: fractionState, otherProperties: [:], childrenOtherProperties: [:])
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
    
    /// Sets `totalCount`.
    /// - Parameter newTotal: Total units of work.
    public func setTotalCount(_ newTotal: Int?) {
        state.withLock { state in
            let previous = state.fractionState.overallFraction
            if state.fractionState.selfFraction.total != newTotal && state.fractionState.selfFraction.total > 0 {
                state.fractionState.childFraction = state.fractionState.childFraction * _ProgressFraction(completed: state.fractionState.selfFraction.total, total: newTotal ?? 1)
            }
            state.fractionState.selfFraction.total = newTotal ?? 0
            
            // if newValue is nil, reset indeterminate to true
            if newTotal != nil {
                state.fractionState.indeterminate = false
            } else {
                state.fractionState.indeterminate = true
            }
            updateFractionCompleted(from: previous, to: state.fractionState.overallFraction)
            
            ghostReporter?.notifyObservers(with: .totalCountUpdated)
            
            monitorInterop.withLock { [self] interop in
                if interop == true {
                    notifyObservers(with: .totalCountUpdated)
                }
            }
        }
    }
    
    /// Returns a `Subprogress` representing a portion of `self` which can be passed to any method that reports progress.
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
    ///   - portionOfParent: Units, which is a portion of `totalCount`delegated to an instance of `Subprogress`.
    public func assign(count portionOfParent: Int, to reporter: ProgressReporter) {
        precondition(isCycle(reporter: reporter) == false, "Creating a cycle is not allowed.")
        
        // get the actual progress from within the reporter, then add as children
        let actualManager = reporter.manager
        
        // Add reporter as child + Add self as parent
        self.addToChildren(childManager: actualManager)
        actualManager.addParent(parentReporter: self, portionOfParent: portionOfParent)
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        let updateState = updateCompletedCount(count: count)
        updateFractionCompleted(from: updateState.previous, to: updateState.current)
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
    public func values<P: Property>(of property: P.Type) -> [P.Value?] {
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
    /// 
    public func withProperties<T>(_ closure: @Sendable (inout Values) throws -> T) rethrows -> T {
        return try state.withLock { state in
            var values = Values(manager: self, state: state)
            // This is done to avoid copy on write later
            state = State(fractionState: FractionState(indeterminate: true, selfFraction: _ProgressFraction(), childFraction: _ProgressFraction()), otherProperties: [:], childrenOtherProperties: [:])
            let result = try closure(&values)
            state = values.state
            return result
        }
    }
    
//    public func withProperties<T, E: Error>(
//        _ closure: (inout sending Values) throws(E) -> sending T
//    ) throws(E) -> sending T {
//        return try state.withLock { state in
//            var values = Values(manager: self, state: state)
//            // This is done to avoid copy on write later
//            state = State(fractionState: FractionState(indeterminate: true, selfFraction: _ProgressFraction(), childFraction: _ProgressFraction()), otherProperties: [:], childrenOtherProperties: [:])
//            
//            do {
//                let result = try closure(&values)
//                state = values.state
//                return result
//            } catch let localError {
//                throw localError as! E
//            }
//        }
//    }
    
    //MARK: ProgressManager Properties getters
    /// Returns nil if `self` was instantiated without total units;
    /// returns a `Int` value otherwise.
    private func getTotalCount(fractionState: inout FractionState) -> Int? {
        if let interopChild = fractionState.interopChild {
            return interopChild.totalCount
        }
        if fractionState.indeterminate {
            return nil
        } else {
            return fractionState.selfFraction.total
        }
    }
    
    /// Returns nil if `self` has `nil` total units;
    /// returns a `Int` value otherwise.
    private func getCompletedCount(fractionState: inout FractionState) -> Int {
        if let interopChild = fractionState.interopChild {
            return interopChild.completedCount
        }
        return fractionState.selfFraction.completed
    }
    
    /// Returns 0.0 if `self` has `nil` total units;
    /// returns a `Double` otherwise.
    /// If `indeterminate`, return 0.0.
    ///
    /// The calculation of fraction completed for a ProgressManager instance that has children
    /// will take into account children's fraction completed as well.
    private func getFractionCompleted(fractionState: inout FractionState) -> Double {
        if let interopChild = fractionState.interopChild {
            return interopChild.fractionCompleted
        }
        if fractionState.indeterminate {
            return 0.0
        }
        guard fractionState.selfFraction.total > 0 else {
            return fractionState.selfFraction.fractionCompleted
        }
        return (fractionState.selfFraction + fractionState.childFraction).fractionCompleted
    }
    
    
    /// Returns `true` if completed and total units are not `nil` and completed units is greater than or equal to total units;
    /// returns `false` otherwise.
    private func getIsFinished(fractionState: inout FractionState) -> Bool {
        return fractionState.selfFraction.isFinished
    }
    
    
    /// Returns `true` if `self` has `nil` total units.
    private func getIsIndeterminate(fractionState: inout FractionState) -> Bool {
        return fractionState.indeterminate
    }
    
    //MARK: FractionCompleted Calculation methods
    private struct UpdateState {
        let previous: _ProgressFraction
        let current: _ProgressFraction
    }
    
    private func updateCompletedCount(count: Int) -> UpdateState {
        // Acquire and release child's lock
        let (previous, current) = state.withLock { state in
            let prev = state.fractionState.overallFraction
            state.fractionState.selfFraction.completed += count
            return (prev, state.fractionState.overallFraction)
        }
        return UpdateState(previous: previous, current: current)
    }
    
    private func updateFractionCompleted(from: _ProgressFraction, to: _ProgressFraction) {
        _$observationRegistrar.withMutation(of: self, keyPath: \.fractionCompleted) {
            if from != to {
                parents.withLock { parents in
                    for (parent, portionOfParent) in parents {
                        parent.updateChildFraction(from: from, to: to, portion: portionOfParent)
                    }
                }
            }
        }
    }
    
    /// A child progress has been updated, which changes our own fraction completed.
    internal func updateChildFraction(from previous: _ProgressFraction, to next: _ProgressFraction, portion: Int) {
        let updateState = state.withLock { state in
            let previousOverallFraction = state.fractionState.overallFraction
            let multiple = _ProgressFraction(completed: portion, total: state.fractionState.selfFraction.total)
            let oldFractionOfParent = previous * multiple
            
            if previous.total != 0 {
                state.fractionState.childFraction = state.fractionState.childFraction - oldFractionOfParent
            }
            
            if next.total != 0 {
                state.fractionState.childFraction = state.fractionState.childFraction + (next * multiple)
                
                if next.isFinished {
                    // Remove from children list
//                    _ = children.withLock { $0.remove(self) }
                    
                    if portion != 0 {
                        // Update our self completed units
                        state.fractionState.selfFraction.completed += portion
                    }
                    
                    // Subtract the (child's fraction completed * multiple) from our child fraction
                    state.fractionState.childFraction = state.fractionState.childFraction  - (multiple * next)
                }
            }
            return UpdateState(previous: previousOverallFraction, current: state.fractionState.overallFraction)
        }
        updateFractionCompleted(from: updateState.previous, to: updateState.current)
    }
    
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
            state.fractionState.interopChild = interopChild
        }
    }
    
    internal func addToChildren(childManager: ProgressManager) {
        _ = children.withLock { children in
            children.insert(childManager)
        }
    }
    
    internal func addParent(parentReporter: ProgressManager, portionOfParent: Int) {
        parents.withLock { parents in
            parents[parentReporter] = portionOfParent
        }
        
        let updates = state.withLock { state in
            // Update metatype entry in parent
            for (metatype, value) in state.otherProperties {
                let childrenValues = getFlattenedChildrenValues(property: metatype, state: &state)
                let updatedParentEntry: [(any Sendable)?] = [value] + childrenValues
                parentReporter.updateChildrenOtherPropertiesAnyValue(property: metatype, child: self, value: updatedParentEntry)
            }
            
            let original = _ProgressFraction(completed: 0, total: 0)
            let updated = state.fractionState.overallFraction
            return (original, updated)
        }
        
        // Update childFraction entry in parent
        parentReporter.updateChildFraction(from: updates.0, to: updates.1, portion: portionOfParent)
    }
    
    internal func getAdditionalProperties<T>(_ closure: @Sendable (Values) throws -> T) rethrows -> T {
        try state.withLock { state in
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
            parents.withLock { parents in
                for (parent, _) in parents {
                    parent.updateChildrenOtherPropertiesAnyValue(property: metatype, child: child, value: updatedParentEntry)
                }
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
            parents.withLock { parents in
                for (parent, _) in parents {
                    parent.updateChildrenOtherProperties(property: metatype, child: self, value: updatedParentEntry)
                }
            }
        }
    }
    
    // MARK: Cycle detection
    func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if reporter.manager === self {
            return true
        }
        
        let updatedVisited = visited.union([self])
        
        return parents.withLock { parents in
            for (parent, _) in parents {
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
