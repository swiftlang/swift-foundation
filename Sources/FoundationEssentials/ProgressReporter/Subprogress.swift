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
/// Subprogress is a nested ~Copyable struct used to establish parent-child relationship between two instances of ProgressReporter.
///
/// Subprogress is returned from a call to `subprogress(assigningCount:)` by a parent ProgressReporter.
/// A child ProgressReporter is then returned by calling`reporter(totalCount:)` on a Subprogress.
public struct Subprogress: ~Copyable, Sendable {
    internal var parent: ProgressReporter
    internal var portionOfParent: Int
    internal var isInitializedToProgressReporter: Bool
    
    // Interop variables for Progress - ProgressReporter Interop
    internal var interopWithProgressParent: Bool = false
    // To be kept alive in ProgressReporter
    internal var observation: (any Sendable)?
    internal var ghostReporter: ProgressReporter?
            
    internal init(parent: ProgressReporter, portionOfParent: Int) {
        self.parent = parent
        self.portionOfParent = portionOfParent
        self.isInitializedToProgressReporter = false
    }
    
    /// Instantiates a ProgressReporter which is a child to the parent from which `self` is returned.
    /// - Parameter totalCount: Total count of returned child `ProgressReporter` instance.
    /// - Returns: A `ProgressReporter` instance.
    public consuming func reporter(totalCount: Int?) -> ProgressReporter {
        isInitializedToProgressReporter = true
        
        let childReporter = ProgressReporter(total: totalCount, parent: parent, portionOfParent: portionOfParent, ghostReporter: ghostReporter, interopObservation: observation)
        
        if interopWithProgressParent {
            // Set interop child of ghost reporter so ghost reporter reads from here
            ghostReporter?.setInteropChild(interopChild: childReporter)
        } else {
            // Add child to parent's _children list & Store in child children's position in parent
            let childPositionInParent = parent.addToChildren(childReporter: childReporter)
            childReporter.setPositionInParent(to: childPositionInParent)
        }
        
        return childReporter
    }
    
    deinit {
        if !self.isInitializedToProgressReporter {
            parent.complete(count: portionOfParent)
        }
    }
}

