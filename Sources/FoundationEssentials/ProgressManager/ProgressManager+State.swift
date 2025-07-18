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

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    internal struct AnyMetatypeWrapper: Hashable, Equatable, Sendable {
        let metatype: any Property.Type
        
        internal static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.metatype == rhs.metatype
        }
        
        internal func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(metatype))
        }
    }
    
    internal struct PropertyState {
        var value: (any Sendable)
        var isDirty: Bool
    }
    
    internal struct PropertyStateInt {
        var value: Int
        var isDirty: Bool
    }
    
    internal struct PropertyStateInt64 {
        var value: Int64
        var isDirty: Bool
    }
    
    internal struct PropertyStateThroughput {
        var value: ProgressManager.Properties.Throughput.AggregateThroughput
        var isDirty: Bool
    }
    
    internal struct PropertyStateDuration {
        var value: Duration
        var isDirty: Bool
    }
    
    internal struct PropertyStateDouble {
        var value: Double
        var isDirty: Bool
    }
    
    internal struct PropertyStateString {
        var value: String
        var isDirty: Bool
    }
    
    internal struct ChildState {
        weak var child: ProgressManager?
        var remainingPropertiesInt: [AnyMetatypeWrapper: Int]?
        var remainingPropertiesDouble: [AnyMetatypeWrapper: Double]?
        var remainingPropertiesString: [AnyMetatypeWrapper: String]?
        var remainingProperties: [AnyMetatypeWrapper: (any Sendable)]?
        var portionOfTotal: Int
        var childFraction: ProgressFraction
        var isDirty: Bool
        var totalFileCount: PropertyStateInt
        var completedFileCount: PropertyStateInt
        var totalByteCount: PropertyStateInt64
        var completedByteCount: PropertyStateInt64
        var throughput: PropertyStateThroughput
        var estimatedTimeRemaining: PropertyStateDuration
        var childPropertiesInt: [AnyMetatypeWrapper: PropertyStateInt]
        var childPropertiesDouble: [AnyMetatypeWrapper: PropertyStateDouble]
        var childPropertiesString: [AnyMetatypeWrapper: PropertyStateString]
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
        #if FOUNDATION_FRAMEWORK //put more behind this
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
                    let multiplier = ProgressFraction(completed: child.portionOfTotal, total: selfFraction.total)
                    if let additionalFraction = multiplier * child.childFraction {
                        overallFraction = overallFraction + additionalFraction
                    }
                    // should not crash here - add a test case - child becomes indeterminate halfway
                }
            }
            return overallFraction
        }
        var children: [ChildState]
        var parents: [ParentState]
        var totalFileCount: Int
        var completedFileCount: Int
        var totalByteCount: Int64
        var completedByteCount: Int64
        var throughput: Int64
        var estimatedTimeRemaining: Duration
        var propertiesInt: [AnyMetatypeWrapper: Int]
        var propertiesDouble: [AnyMetatypeWrapper: Double]
        var propertiesString: [AnyMetatypeWrapper: String]
        var properties: [AnyMetatypeWrapper: (any Sendable)]
        var interopObservation: InteropObservation
        let progressParentProgressManagerChildMessenger: ProgressManager?
        var observers: [@Sendable (ObserverState) -> Void]
        
        /// Returns nil if `self` was instantiated without total units;
        /// returns a `Int` value otherwise.
        internal func getTotalCount() -> Int? {
            if let interopChild = interopChild {
                return interopChild.totalCount
            }
            return selfFraction.total
        }
        
        /// Returns 0 if `self` has `nil` total units;
        /// returns a `Int` value otherwise.
        internal mutating func getCompletedCount() -> Int {
            if let interopChild = interopChild {
                return interopChild.completedCount
            }
            
            updateChildrenProgressFraction()

            return selfFraction.completed
        }
        
        internal mutating func updateChildrenProgressFraction() {
            guard !children.isEmpty else {
                return
            }
            for (idx, childState) in children.enumerated() {
                if childState.isDirty {
                    if let child = childState.child {
                        let updatedProgressFraction = child.getUpdatedProgressFraction()
                        children[idx] = ChildState(child: child,
                                                   remainingProperties: children[idx].remainingProperties,
                                                   portionOfTotal: children[idx].portionOfTotal,
                                                   childFraction: updatedProgressFraction,
                                                   isDirty: false,
                                                   totalFileCount: children[idx].totalFileCount,
                                                   completedFileCount: children[idx].completedFileCount,
                                                   totalByteCount: children[idx].totalByteCount,
                                                   completedByteCount: children[idx].completedByteCount,
                                                   throughput: children[idx].throughput,
                                                   estimatedTimeRemaining: children[idx].estimatedTimeRemaining,
                                                   childPropertiesInt: children[idx].childPropertiesInt,
                                                   childPropertiesDouble: children[idx].childPropertiesDouble,
                                                   childPropertiesString: children[idx].childPropertiesString,
                                                   childProperties: children[idx].childProperties)
                        if updatedProgressFraction.isFinished {
                            selfFraction.completed += children[idx].portionOfTotal
                        }
                    } else {
                        children[idx] = ChildState(child: nil,
                                                   remainingProperties: children[idx].remainingProperties,
                                                   portionOfTotal: children[idx].portionOfTotal,
                                                   childFraction: children[idx].childFraction,
                                                   isDirty: false,
                                                   totalFileCount: children[idx].totalFileCount,
                                                   completedFileCount: children[idx].completedFileCount,
                                                   totalByteCount: children[idx].totalByteCount,
                                                   completedByteCount: children[idx].completedByteCount,
                                                   throughput: children[idx].throughput,
                                                   estimatedTimeRemaining: children[idx].estimatedTimeRemaining,
                                                   childPropertiesInt: children[idx].childPropertiesInt,
                                                   childPropertiesDouble: children[idx].childPropertiesDouble,
                                                   childPropertiesString: children[idx].childPropertiesString,
                                                   childProperties: children[idx].childProperties)
                        selfFraction.completed += children[idx].portionOfTotal
                    }
                }
            }
        }
        
        internal func notifyObservers(with observerState: ObserverState) {
            for observer in observers {
                observer(observerState)
            }
        }
    }
}
