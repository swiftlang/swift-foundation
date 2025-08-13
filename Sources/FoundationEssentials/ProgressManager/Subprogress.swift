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
/// Subprogress is a nested ~Copyable struct used to establish parent-child relationship between two instances of ProgressManager.
///
/// Subprogress is returned from a call to `subprogress(assigningCount:)` by a parent ProgressManager.
/// A child ProgressManager is then returned by calling`manager(totalCount:)` on a Subprogress.
public struct Subprogress: ~Copyable, Sendable {
    internal var parent: ProgressManager
    internal var portionOfParent: Int
    internal var isInitializedToProgressReporter: Bool
#if FOUNDATION_FRAMEWORK
    internal var subprogressBridge: SubprogressBridge?
#endif
     
#if FOUNDATION_FRAMEWORK
    internal init(parent: ProgressManager, portionOfParent: Int, subprogressBridge: SubprogressBridge? = nil) {
        self.parent = parent
        self.portionOfParent = portionOfParent
        self.isInitializedToProgressReporter = false
        self.subprogressBridge = subprogressBridge
    }
#else
    internal init(parent: ProgressManager, portionOfParent: Int) {
        self.parent = parent
        self.portionOfParent = portionOfParent
        self.isInitializedToProgressReporter = false
    }
#endif
    
    /// Instantiates a ProgressManager which is a child to the parent from which `self` is returned.
    /// - Parameter totalCount: Total count of returned child `ProgressManager` instance.
    /// - Returns: A `ProgressManager` instance.
    public consuming func start(totalCount: Int?) -> ProgressManager {
        isInitializedToProgressReporter = true

#if FOUNDATION_FRAMEWORK
        let childManager = ProgressManager(
            total: totalCount,
            completed: nil,
            subprogressBridge: subprogressBridge
        )
        
        guard subprogressBridge == nil else {
            subprogressBridge?.manager.setInteropChild(interopMirror: childManager)
            return childManager
        }
#else
        let childManager = ProgressManager(
            total: totalCount,
            completed: nil
        )
#endif

        let position = parent.addChild(
            child: childManager,
            portion: portionOfParent,
            childFraction: childManager.getProgressFraction()
        )
        childManager.addParent(
            parent: parent,
            positionInParent: position
        )
        
        return childManager
    }
    
    deinit {
        if !self.isInitializedToProgressReporter {
            parent.complete(count: portionOfParent)
        }
    }
}
