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
internal import Synchronization

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    
    internal struct MetatypeWrapper<T: Sendable>: Hashable, Equatable, Sendable {
        
        let reduce: @Sendable (inout T, T) -> ()
        let merge: @Sendable (T, T) -> T
        
        let defaultValue: T
        let defaultSummary: T
        
        let key: String
        
        init<P: Property>(_ argument: P.Type) where P.Value == T, P.Summary == T {
            reduce = P.reduce
            merge = P.merge
            defaultValue = P.defaultValue
            defaultSummary = P.defaultSummary
            key = P.key
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
        
        static func == (lhs: ProgressManager.MetatypeWrapper<T>, rhs: ProgressManager.MetatypeWrapper<T>) -> Bool {
            lhs.key == rhs.key
        }
    }
    
    internal struct PropertyStateInt {
        var value: Int
        var isDirty: Bool
    }
    
    internal struct PropertyStateUInt64 {
        var value: UInt64
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
    
    internal struct PropertyStateURL {
        var value: [URL]
        var isDirty: Bool
    }
    
    internal struct ChildState {
        weak var child: ProgressManager?
        var remainingPropertiesInt: [MetatypeWrapper<Int>: Int]?
        var remainingPropertiesDouble: [MetatypeWrapper<Double>: Double]?
        var remainingPropertiesString: [MetatypeWrapper<String>: String]?
        var portionOfTotal: Int
        var childFraction: ProgressFraction
        var isDirty: Bool
        var totalFileCount: PropertyStateInt
        var completedFileCount: PropertyStateInt
        var totalByteCount: PropertyStateUInt64
        var completedByteCount: PropertyStateUInt64
        var throughput: PropertyStateThroughput
        var estimatedTimeRemaining: PropertyStateDuration
        var fileURL: PropertyStateURL
        var childPropertiesInt: [MetatypeWrapper<Int>: PropertyStateInt]
        var childPropertiesDouble: [MetatypeWrapper<Double>: PropertyStateDouble]
        var childPropertiesString: [MetatypeWrapper<String>: PropertyStateString]
    }
    
    internal struct ParentState {
        var parent: ProgressManager
        var positionInParent: Int
    }
    
    internal struct State {
        var selfFraction: ProgressFraction
        var overallFraction: ProgressFraction {
            var overallFraction = selfFraction
            for child in children {
                if !child.childFraction.isFinished {
                    let multiplier = ProgressFraction(completed: child.portionOfTotal, total: selfFraction.total)
                    if let additionalFraction = multiplier * child.childFraction {
                        overallFraction = overallFraction + additionalFraction
                    }
                }
            }
            return overallFraction
        }
        var children: [ChildState]
        var parents: [ParentState]
        var totalFileCount: Int
        var completedFileCount: Int
        var totalByteCount: UInt64
        var completedByteCount: UInt64
        var throughput: UInt64
        var estimatedTimeRemaining: Duration
        var fileURL: URL?
        var propertiesInt: [MetatypeWrapper<Int>: Int]
        var propertiesDouble: [MetatypeWrapper<Double>: Double]
        var propertiesString: [MetatypeWrapper<String>: String]
#if FOUNDATION_FRAMEWORK
        var interopChild: ProgressManager?
        var interopObservation: InteropObservation
        var observers: [@Sendable (ObserverState) -> Void]
#endif

        /// Returns nil if `self` was instantiated without total units;
        /// returns a `Int` value otherwise.
        internal func getTotalCount() -> Int? {
#if FOUNDATION_FRAMEWORK
            if let interopChild = interopChild {
                return interopChild.totalCount
            }
#endif
            return selfFraction.total
        }
        
        /// Returns 0 if `self` has `nil` total units;
        /// returns a `Int` value otherwise.
        internal mutating func getCompletedCount() -> Int {
#if FOUNDATION_FRAMEWORK
            if let interopChild = interopChild {
                return interopChild.completedCount
            }
#endif
            
            updateChildrenProgressFraction()

            return selfFraction.completed
        }
        
        internal mutating func getFractionCompleted() -> Double {
#if FOUNDATION_FRAMEWORK
            // change name later to interopMirror
            if let interopChild = interopChild {
                return interopChild.fractionCompleted
            }
#endif
            
            updateChildrenProgressFraction()
                        
            return overallFraction.fractionCompleted

        }
        
        internal func getIsIndeterminate() -> Bool {
#if FOUNDATION_FRAMEWORK
            if let interopChild = interopChild {
                return interopChild.isIndeterminate
            }
#endif
            return selfFraction.isIndeterminate
        }
        
        internal func getIsFinished() -> Bool {
#if FOUNDATION_FRAMEWORK
            if let interopChild = interopChild {
                return interopChild.isIndeterminate
            }
#endif
            return selfFraction.isFinished
        }
        
        internal mutating func updateChildrenProgressFraction() {
            guard !children.isEmpty else {
                return
            }
            for (idx, childState) in children.enumerated() {
                if childState.isDirty {
                    if let child = childState.child {
                        let updatedProgressFraction = child.getUpdatedProgressFraction()
                        children[idx].childFraction = updatedProgressFraction
                        if updatedProgressFraction.isFinished {
                            selfFraction.completed += children[idx].portionOfTotal
                        }
                    } else {
                        selfFraction.completed += children[idx].portionOfTotal
                    }
                    children[idx].isDirty = false
                }
            }
        }
        
        internal mutating func complete(by count: Int) {
            selfFraction.completed += count

#if FOUNDATION_FRAMEWORK
            interopObservation.subprogressBridge?.manager.notifyObservers(
                with: .fractionUpdated(
                    totalCount: selfFraction.total ?? 0,
                    completedCount: selfFraction.completed
                )
            )
            
            if let _ = interopObservation.reporterBridge {
                notifyObservers(
                    with: .fractionUpdated(
                        totalCount: selfFraction.total ?? 0,
                        completedCount: selfFraction.completed
                    )
                )
            }
#endif
        }
    }
}
