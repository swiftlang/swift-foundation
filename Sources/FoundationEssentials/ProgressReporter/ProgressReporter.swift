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

internal struct FractionState {
    var indeterminate: Bool
    var selfFraction: _ProgressFraction
    var childFraction: _ProgressFraction
    var overallFraction: _ProgressFraction {
        selfFraction + childFraction
    }
    var interopChild: ProgressReporter? // read from this if self is actually an interop ghost
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
// ProgressReporter
/// An object that conveys ongoing progress to the user for a specified task.
@Observable public final class ProgressReporter: Sendable {
    
    // Stores all the state of properties
    internal struct State {
        var positionInParent: Int?
        var fractionState: FractionState
        var otherProperties: [AnyMetatypeWrapper: (any Sendable)]
        // Type: Array of Array
        var childrenOtherProperties: [AnyMetatypeWrapper: [[(any Sendable)]]]
    }
    
    // Interop states
    internal enum ObserverState {
        case fractionUpdated
        case totalCountUpdated
    }
    
    // Interop properties - Just kept alive
    internal let interopObservation: (any Sendable)? // set at init
    #if FOUNDATION_FRAMEWORK
    internal let parentBridge: LockedState<Foundation.Progress?> = LockedState(initialState: nil) // dummy, set upon calling setParentBridge
    #endif
    // Interop properties - Actually set and called
    internal let ghostReporter: ProgressReporter? // set at init, used to call notify observers
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
    
    /// A type that conveys task-specific information on progress.
    public protocol Property {
        
        associatedtype T: Sendable, Hashable, Equatable
        
        static var defaultValue: T { get }
    }
    
    /// A container that holds values for properties that specify information on progress.
    @dynamicMemberLookup
    public struct Values : Sendable {
        //TODO: rdar://149225947 Non-escapable conformance
        let reporter: ProgressReporter
        var state: State
        
        /// The total units of work.
        public var totalCount: Int? {
            mutating get {
                reporter.getTotalCount(fractionState: &state.fractionState)
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
                reporter.updateFractionCompleted(from: previous, to: state.fractionState.overallFraction)
                reporter.ghostReporter?.notifyObservers(with: .totalCountUpdated)
            }
        }
        
        
        /// The completed units of work.
        public var completedCount: Int {
            mutating get {
                reporter.getCompletedCount(fractionState: &state.fractionState)
            }
            
            set {
                let prev = state.fractionState.overallFraction
                state.fractionState.selfFraction.completed = newValue
                reporter.updateFractionCompleted(from: prev, to: state.fractionState.overallFraction)
                reporter.ghostReporter?.notifyObservers(with: .fractionUpdated)
            }
        }
        
        /// Returns a property value that a key path indicates.
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressReporter.Properties, P.Type>) -> P.T {
            get {
                return state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] as? P.T ?? P.self.defaultValue
            }
            
            set {
                // Update my own other properties entry
                state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] = newValue
                // Flatten myself + myChildren to be sent to parent
                var updateValueForParent: [P.T?] = [newValue]
                let childrenValues: [[P.T?]]? = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: P.self)] as? [[P.T?]]
                let flattenedChildrenValues: [P.T?] = {
                    guard let values = childrenValues else { return [] }
                    // Use flatMap to flatten the array but preserve nil values
                    return values.flatMap { innerArray -> [P.T?] in
                        // Each inner array element is preserved, including nil values
                        return innerArray.map { $0 }
                    }
                }()
                updateValueForParent += flattenedChildrenValues
                reporter.parent?.updateChildrenOtherProperties(property: P.self, idx: state.positionInParent!, value: updateValueForParent)
            }
        }
    }
    
    private let portionOfParent: Int
    internal let parent: ProgressReporter?
    private let children: LockedState<[ProgressReporter?]>
    private let state: LockedState<State>
    
    internal init(total: Int?, parent: ProgressReporter?, portionOfParent: Int, ghostReporter: ProgressReporter?, interopObservation: (any Sendable)?) {
        self.portionOfParent = portionOfParent
        self.parent = parent
        self.children = .init(initialState: [])
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
        self.init(total: totalCount, parent: nil, portionOfParent: 0, ghostReporter: nil, interopObservation: nil)
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
        }
    }
    
    
    /// Returns a `Subprogress` representing a portion of `self`which can be passed to any method that reports progress.
    ///
    /// - Parameter count: Units, which is a portion of `totalCount`delegated to an instance of `Subprogress`.
    /// - Returns: A `Subprogress` instance.
    public func subprogress(assigningCount portionOfParent: Int) -> Subprogress {
        precondition(portionOfParent > 0, "Giving out zero units is not a valid operation.")
        let subprogress = Subprogress(parent: self, portionOfParent: portionOfParent)
        return subprogress
    }
    
    /// Increases `completedCount` by `count`.
    /// - Parameter count: Units of work.
    public func complete(count: Int) {
        let updateState = updateCompletedCount(count: count)
        updateFractionCompleted(from: updateState.previous, to: updateState.current)
        ghostReporter?.notifyObservers(with: .fractionUpdated)
    }
    
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
    
    /// Mutates any settable properties that convey information about progress.
    public func withProperties<T>(_ closure: @Sendable (inout Values) throws -> T) rethrows -> T {
        return try state.withLock { state in
            var values = Values(reporter: self, state: state)
            // This is done to avoid copy on write later
            state = State(fractionState: FractionState(indeterminate: true, selfFraction: _ProgressFraction(), childFraction: _ProgressFraction()), otherProperties: [:], childrenOtherProperties: [:])
            let result = try closure(&values)
            state = values.state
            return result
        }
    }
    
    //MARK: ProgressReporter Properties getters
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
    /// The calculation of fraction completed for a ProgressReporter instance that has children
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
    private func updateFractionCompleted(from: _ProgressFraction, to: _ProgressFraction) {
        _$observationRegistrar.withMutation(of: self, keyPath: \.fractionCompleted) {
            if from != to {
                parent?.updateChildFraction(from: from, to: to, portion: portionOfParent)
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
    
    //MARK: Internal methods to mutate locked context
#if FOUNDATION_FRAMEWORK
    internal func setParentBridge(parentBridge: Foundation.Progress) {
        self.parentBridge.withLock { bridge in
            bridge = parentBridge
        }
    }
#endif
    
    internal func setInteropChild(interopChild: ProgressReporter) {
        state.withLock { state in
            state.fractionState.interopChild = interopChild
        }
    }
    
    // Returns position of child in parent
    internal func addToChildren(childReporter: ProgressReporter) -> Int {
        let childPosition = children.withLock { children in
            children.append(childReporter)
            return children.count - 1
        }
        return childPosition
    }
    
    internal func setPositionInParent(to position: Int) {
        state.withLock { state in
            state.positionInParent = position
        }
    }
    
    internal func updateChildrenOtherProperties<P: Property>(property metatype: P.Type, idx: Int, value: [P.T?]) {
        state.withLock { state in
            let myEntries: [[P.T?]]? = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] as? [[P.T?]]
            if let entries = myEntries {
                // If entries is not nil, make sure it is a valid index, then update my entry of children values
                let entriesLength = entries.count
                // Check if entries need resizing
                if idx >= entriesLength {
                    // Entries need resizing
                    state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] = resizeArray(array: &state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)], to: idx+1)
                    state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![idx] = value
                } else {
                    // Entries don't need resizing
                    state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![idx] = value
                }
                
            } else {
                // If entries is nil
                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] = resizeArray(array: &state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)], to: idx+1)
                state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)]![idx] = value
            }
            // Ask parent to update their entry with my value + new children value
            let newChildrenValues: [[P.T?]]? = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] as? [[P.T?]]
            let flattenedChildrenValues: [P.T?] = {
                guard let values = newChildrenValues else { return [] }
                // Use flatMap to flatten the array but preserve nil values
                return values.flatMap { innerArray -> [P.T?] in
                    // Each inner array element is preserved, including nil values
                    return innerArray.map { $0 }
                }
            }()
            let newValueForParent: [P.T?] = [state.otherProperties[AnyMetatypeWrapper(metatype: metatype)] as? P.T] + flattenedChildrenValues
            parent?.updateChildrenOtherProperties(property: metatype, idx: state.positionInParent!, value: newValueForParent)
        }
    }
    
    // Copy elements of array to new array with the correct size
    private func resizeArray(array: inout [[any Sendable]]?, to size: Int) -> [[any Sendable]] {
        var newArray: [[any Sendable]] = Array(repeating: [], count: size)
        if array == nil && size == 1 {
            return newArray
        }
        if let oldArray = array {
            // Use array.count to avoid invalid index
            for idx in 0..<oldArray.count {
                newArray[idx] = oldArray[idx]
            }
        }
        return newArray
    }
    
    public func getAllValues<P: Property>(property metatype: P.Type) -> [P.T?] {
        return state.withLock { state in
            let childrenValues: [[P.T?]]? = state.childrenOtherProperties[AnyMetatypeWrapper(metatype: metatype)] as? [[P.T?]]
            let flattenedChildrenValues: [P.T?] = {
                guard let values = childrenValues else { return [] }
                // Use flatMap to flatten the array but preserve nil values
                return values.flatMap { innerArray -> [P.T?] in
                    // Each inner array element is preserved, including nil values
                    return innerArray.map { $0 }
                }
            }()
            return [state.otherProperties[AnyMetatypeWrapper(metatype: metatype)] as? P.T] + flattenedChildrenValues
        }
    }
    
    public func reduce<P: ProgressReporter.Property>(property: P.Type, values: [P.T?]) -> P.T where P.T: AdditiveArithmetic {
        let droppedNil = values.compactMap { $0 }
        return droppedNil.reduce(P.T.zero, +)
    }
}
    
@available(FoundationPreview 6.2, *)
// Hashable & Equatable Conformance
extension ProgressReporter: Hashable, Equatable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    /// Returns `true` if pointer of `lhs` is equal to pointer of `rhs`.
    public static func ==(lhs: ProgressReporter, rhs: ProgressReporter) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressReporter: CustomDebugStringConvertible {
    /// The description for `completedCount` and `totalCount`.
    public var debugDescription: String {
        return "\(completedCount) / \(totalCount ?? 0)"
    }
}
