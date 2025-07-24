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
        //TODO: Think about cleaning up for readability
        var remainingPropertiesInt: [AnyMetatypeWrapper: Int]?
        var remainingPropertiesDouble: [AnyMetatypeWrapper: Double]?
        var remainingPropertiesString: [AnyMetatypeWrapper: String]?
        var portionOfTotal: Int
        var childFraction: ProgressFraction
        var isDirty: Bool
        var totalFileCount: PropertyStateInt
        var completedFileCount: PropertyStateInt
        var totalByteCount: PropertyStateInt64
        var completedByteCount: PropertyStateInt64
        var throughput: PropertyStateThroughput
        var estimatedTimeRemaining: PropertyStateDuration
        //TODO: Make sure this gets triggered
        var childPropertiesInt: [AnyMetatypeWrapper: PropertyStateInt]
        var childPropertiesDouble: [AnyMetatypeWrapper: PropertyStateDouble]
        var childPropertiesString: [AnyMetatypeWrapper: PropertyStateString]
    }
    
    internal struct ParentState {
        var parent: ProgressManager
        var positionInParent: Int
    }
    
    internal enum ObserverState {
        case fractionUpdated(totalCount: Int, completedCount: Int)
    }
    
#if FOUNDATION_FRAMEWORK //put more behind this
    internal struct InteropObservation {
        let progressParentProgressManagerChild: _NSProgressParentSubprogressChild?
        var progressParentProgressReporterChild: _NSProgressParentProgressReporterChild?
        var parentBridge: Foundation.Progress?
    }
#endif

//    internal enum InteropOrNot {
//        case interop(ProgressManager)
//        case nonInterop(ProgressFraction)
//    }
    
    internal struct State {
        #if FOUNDATION_FRAMEWORK
        var interopChild: ProgressManager?
        #endif
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
                                                   childPropertiesString: children[idx].childPropertiesString)
                        if updatedProgressFraction.isFinished {
                            selfFraction.completed += children[idx].portionOfTotal
                        }
                    } else {
                        children[idx] = ChildState(child: nil,
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
                                                   childPropertiesString: children[idx].childPropertiesString)
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
