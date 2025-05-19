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
    
    // Interop variables for Progress - ProgressManager Interop
    internal var interopWithProgressParent: Bool = false
    // To be kept alive in ProgressManager
    internal var observation: (any Sendable)?
    internal var ghostReporter: ProgressManager?
            
    internal init(parent: ProgressManager, portionOfParent: Int) {
        self.parent = parent
        self.portionOfParent = portionOfParent
        self.isInitializedToProgressReporter = false
    }
    
    /// Instantiates a ProgressManager which is a child to the parent from which `self` is returned.
    /// - Parameter totalCount: Total count of returned child `ProgressManager` instance.
    /// - Returns: A `ProgressManager` instance.
    public consuming func manager(totalCount: Int?) -> ProgressManager {
        isInitializedToProgressReporter = true
        
        let childManager = ProgressManager(total: totalCount, ghostReporter: ghostReporter, interopObservation: observation)
        
        if interopWithProgressParent {
            // Set interop child of ghost manager so ghost manager reads from here
            ghostReporter?.setInteropChild(interopChild: childManager)
        } else {
            // Add child to parent's _children list & Store in child children's position in parent
            parent.addToChildren(childManager: childManager)
            childManager.addParent(parentReporter: parent, portionOfParent: portionOfParent)
        }
        
        return childManager
    }
    
    deinit {
        if !self.isInitializedToProgressReporter {
            parent.complete(count: portionOfParent)
        }
    }
}

