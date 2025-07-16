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
        let metatype: Any.Type
        
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
                    overallFraction = overallFraction + ((ProgressFraction(completed: child.portionOfTotal, total: selfFraction.total) * child.childFraction)!)
                    // should not crash here - add a test case - child becomes indeterminate halfway
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
        
        /// Returns nil if `self` was instantiated without total units;
        /// returns a `Int` value otherwise.
        internal func getTotalCount() -> Int? {
            if let interopChild = interopChild {
                return interopChild.totalCount
            }
            return selfFraction.total
        }
    }
}
