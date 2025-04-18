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

@_spi(Progress)
@available(FoundationPreview 6.2, *)
// ProgressReporter
/// An object that conveys ongoing progress to the user for a specified task.
@Observable public final class ProgressReporter: Sendable {
    
    // Stores all the state of properties
    internal struct State {
        var fractionState: FractionState
        var otherProperties: [AnyMetatypeWrapper: (any Sendable)]
    }
    
    // Interop states
    internal enum ObserverState {
        case fractionUpdated
        case totalCountUpdated
    }
    
    // Interop properties - Just kept alive
    internal let interopObservation: (any Sendable)? // set at init
    internal let parentBridge: LockedState<Foundation.Progress?> = LockedState(initialState: nil) // dummy, set upon calling setParentBridge
    
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
        
        associatedtype T: Sendable
        
        /// Aggregates an array of `T` into a single value `T`.
        /// - Parameter all: Array of `T` to be aggregated.
        /// - Returns: A new instance of `T`.
        static func reduce(_ all: [T]) -> T
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
        public subscript<P: Property>(dynamicMember key: KeyPath<ProgressReporter.Properties, P.Type>) -> P.T? {
            get {
                state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] as? P.T
            }
            
            set {
                state.otherProperties[AnyMetatypeWrapper(metatype: P.self)] = newValue
                // Update Parent's P.self value
                updateParentOtherPropertiesEntry(of: reporter, metatype: P.self, updatedValue: newValue, state: &state)
            }
        }
        
        private func updateParentOtherPropertiesEntry<P: Property>(of reporter: ProgressReporter, metatype: P.Type, updatedValue: P.T?, state: inout State) {
            // Check if parent exists to continue propagating values up
            if let parent = reporter.parent {
                parent.children.withLock { children in
                    // Array containing all children's values to pass into reduce
                    let childrenValues: LockedState<[P.T]> = LockedState(initialState: [])
                    // Add self's updatedValue to array
                    if let updatedValue = updatedValue {
                        childrenValues.withLock { values in
                            values.append(updatedValue)
                        }
                    }
                    // Add other children's values to array, skip over existing child's existing value
                    for child in children {
                        if child != reporter {
                            let childValue = child?.state.withLock { $0.otherProperties[AnyMetatypeWrapper(metatype: metatype)] as? P.T }
                            if let childValue = childValue {
                                childrenValues.withLock { values in
                                    values.append(childValue)
                                }
                            }
                        }
                    }
                    if !childrenValues.withLock(\.self).isEmpty {
                        parent.state.withLock { state in
                            // Set property in parent
                            let reducedValue = metatype.reduce(childrenValues.withLock(\.self))
                            state.otherProperties[AnyMetatypeWrapper(metatype: metatype)] = reducedValue
                            // Recursive call to parent's parent
                            updateParentOtherPropertiesEntry(of: parent, metatype: metatype, updatedValue: reducedValue, state: &state)
                        }
                    }
                }
            }
        }
        
    }
    
    private let portionOfParent: Int
    internal let parent: ProgressReporter?
    private let children: LockedState<Set<ProgressReporter?>>
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
        let state = State(fractionState: fractionState, otherProperties: [:])
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
    
    
    /// Returns a `ProgressReporter.Progress` representing a portion of `self`which can be passed to any method that reports progress.
    ///
    /// - Parameter count: Units, which is a portion of `totalCount`delegated to an instance of `ProgressReporter.Progress`.
    /// - Returns: A `ProgressReporter.Progress` instance.
    public func assign(count portionOfParent: Int) -> Progress {
        precondition(portionOfParent > 0, "Giving out zero units is not a valid operation.")
        let childProgress = Progress(parent: self, portionOfParent: portionOfParent)
        return childProgress
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
            state = State(fractionState: FractionState(indeterminate: true, selfFraction: _ProgressFraction(), childFraction: _ProgressFraction()), otherProperties: [:])
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
        // Acquire and release parent's lock
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
                    _ = children.withLock { $0.remove(self) }
                    
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
    internal func setParentBridge(parentBridge: Foundation.Progress) {
        self.parentBridge.withLock { bridge in
            bridge = parentBridge
        }
    }
    
    internal func setInteropChild(interopChild: ProgressReporter) {
        state.withLock { state in
            state.fractionState.interopChild = interopChild
        }
    }
    
    internal func addToChildren(childReporter: ProgressReporter) {
        _ = children.withLock { children in
            children.insert(childReporter)
        }
    }
}

@_spi(Progress)
@available(FoundationPreview 6.2, *)
// Default Implementation for reduce
extension ProgressReporter.Property where T : AdditiveArithmetic {
    public static func reduce(_ all: [T]) -> T {
        precondition(all.isEmpty == false, "Cannot reduce an empty array")
        let first = all.first!
        let rest = all.dropFirst()
        guard !rest.isEmpty else {
            return first
        }
        return rest.reduce(first, +)
    }
}

@_spi(Progress)
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

@_spi(Progress)
@available(FoundationPreview 6.2, *)
extension ProgressReporter: CustomDebugStringConvertible {
    /// The description for `completedCount` and `totalCount`.
    public var debugDescription: String {
        return "\(completedCount) / \(totalCount ?? 0)"
    }
}
