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

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation

@available(FoundationPreview 6.2, *)
//MARK: Progress Parent - ProgressManager Child Interop
// Actual Progress Parent
// Ghost Progress Parent
// Ghost ProgressManager Child
// Actual ProgressManager Child
extension Progress {
    
    /// Returns a Subprogress which can be passed to any method that reports progress
    /// and can be initialized into a child `ProgressManager` to the `self`.
    ///
    /// Delegates a portion of totalUnitCount to a future child `ProgressManager` instance.
    ///
    /// - Parameter count: Number of units delegated to a child instance of `ProgressManager`
    /// which may be instantiated by `Subprogress` later when `reporter(totalCount:)` is called.
    /// - Returns: A `Subprogress` instance.
    public func makeChild(withPendingUnitCount count: Int) -> Subprogress {
        
        // Make ghost parent & add it to actual parent's children list
        let ghostProgressParent = Progress(totalUnitCount: Int64(count))
        self.addChild(ghostProgressParent, withPendingUnitCount: Int64(count))
        
        // Make ghost child
        let ghostReporterChild = ProgressManager(totalCount: count)
        
        // Make observation instance
        let observation = _ProgressParentProgressManagerChild(ghostParent: ghostProgressParent, ghostChild: ghostReporterChild)
        
        // Make actual child with ghost child being parent
        var actualProgress = ghostReporterChild.subprogress(assigningCount: count)
        actualProgress.observation = observation
        actualProgress.ghostReporter = ghostReporterChild
        actualProgress.interopWithProgressParent = true
        return actualProgress
    }
    
    
    /// Adds a ProgressReporter as a child to a Progress, which constitutes a portion of Progress's totalUnitCount.
    ///
    /// - Parameters:
    ///   - reporter: A `ProgressReporter` instance.
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    public func addChild(_ reporter: ProgressReporter, withPendingUnitCount count: Int) {
        
        // Need to detect cycle here
        precondition(self.isCycle(reporter: reporter) == false, "Creating a cycle is not allowed.")
        
        // Make intermediary & add it to NSProgress parent's children list
        let ghostProgressParent = Progress(totalUnitCount: Int64(reporter.manager.totalCount ?? 0))
        ghostProgressParent.completedUnitCount = Int64(reporter.manager.completedCount)
        self.addChild(ghostProgressParent, withPendingUnitCount: Int64(count))
        
        // Make observation instance
        let observation = _ProgressParentProgressReporterChild(intermediary: ghostProgressParent, reporter: reporter)
        
        reporter.manager.setInteropObservationForMonitor(observation: observation)
        reporter.manager.setMonitorInterop(to: true)
    }
    
    // MARK: Cycle detection
    private func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if self._parent() == nil {
            return false
        }
        
        if !(self._parent() is _NSProgressParentBridge) {
            return self._parent().isCycle(reporter: reporter)
        }
        
        // then check against ProgressManager
        let unwrappedParent = (self._parent() as? _NSProgressParentBridge)?.actualParent
        if let unwrappedParent = unwrappedParent {
            if unwrappedParent === reporter.manager {
                return true
            }
            let updatedVisited = visited.union([unwrappedParent])
            return unwrappedParent.isCycleInterop(visited: updatedVisited)
        }
        return false
    }
}

private final class _ProgressParentProgressManagerChild: Sendable {
    private let ghostParent: Progress
    private let ghostChild: ProgressManager
    
    fileprivate init(ghostParent: Progress, ghostChild: ProgressManager) {
        self.ghostParent = ghostParent
        self.ghostChild = ghostChild
        
        // Set up mirroring observation relationship between ghostChild and ghostParent
        // - Ghost Parent should mirror values from Ghost Child, and Ghost Child just mirrors values of Actual Child
        ghostChild.addObserver { [weak self] observerState in
            guard let self else {
                return
            }
            
            switch observerState {
            case .totalCountUpdated:
                self.ghostParent.totalUnitCount = Int64(self.ghostChild.totalCount ?? 0)
                
            case .fractionUpdated:
                let count = self.ghostChild.withProperties { p in
                    return (p.completedCount, p.totalCount)
                }
                self.ghostParent.completedUnitCount = Int64(count.0)
                self.ghostParent.totalUnitCount = Int64(count.1 ?? 0)
            }
        }
    }
}

private final class _ProgressParentProgressReporterChild: Sendable {
    private let intermediary: Progress
    private let reporter: ProgressReporter
    
    fileprivate init(intermediary: Progress, reporter: ProgressReporter) {
        self.intermediary = intermediary
        self.reporter = reporter
        
        reporter.manager.addObserver { [weak self] observerState in
            guard let self else {
                return
            }
            
            switch observerState {
            case .totalCountUpdated:
                self.intermediary.totalUnitCount = Int64(self.reporter.manager.totalCount ?? 0)
                
            case .fractionUpdated:
                let count = self.reporter.manager.withProperties { p in
                    return (p.completedCount, p.totalCount)
                }
                self.intermediary.completedUnitCount = Int64(count.0)
                self.intermediary.totalUnitCount = Int64(count.1 ?? 0)
            }
        }
    }
    
}

@available(FoundationPreview 6.2, *)
//MARK: ProgressManager Parent - Progress Child Interop
extension ProgressManager {

    /// Adds a Foundation's `Progress` instance as a child which constitutes a certain `count` of `self`'s `totalCount`.
    /// - Parameters:
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    ///   - progress: `Progress` which receives the delegated `count`.
    public func subprogress(assigningCount count: Int, to progress: Foundation.Progress) {
        precondition(progress._parent() == nil, "Cannot assign a progress to more than one parent.")
        
        let parentBridge = _NSProgressParentBridge(managerParent: self, progressChild: progress, portion: count)
        progress._setParent(parentBridge, portion: Int64(count))

        // Save ghost parent in ProgressManager so it doesn't go out of scope after assign method ends
        // So that when NSProgress increases completedUnitCount and queries for parent there is still a reference to ghostParent and parent doesn't show 0x0 (portion: 5)
        self.setParentBridge(parentBridge: parentBridge)
    }
}

// Subclass of Foundation.Progress
internal final class _NSProgressParentBridge: Progress, @unchecked Sendable {

    internal let actualParent: ProgressManager
    internal let actualChild: Progress
    internal let ghostChild: ProgressManager

    init(managerParent: ProgressManager, progressChild: Progress, portion: Int) {
        self.actualParent = managerParent
        self.actualChild = progressChild
        self.ghostChild = ProgressManager(totalCount: Int(progressChild.totalUnitCount))
        super.init(parent: nil, userInfo: nil)
        
        // Make ghostChild mirror progressChild, ghostChild is added as a child to managerParent
        ghostChild.withProperties { properties in
            properties.completedCount = Int(progressChild.completedUnitCount)
        }
        
        managerParent.addToChildren(child: ghostChild, portion: portion, childFraction: _ProgressFraction(completed: Int(completedUnitCount), total: Int(totalUnitCount)))
        
        ghostChild.addParent(parent: managerParent, portionOfParent: portion)
    }

    // Overrides the _updateChild func that Foundation.Progress calls to update parent
    // so that the parent that gets updated is the ProgressManager parent
    override func _updateChild(_ child: Foundation.Progress, fraction: _NSProgressFractionTuple, portion: Int64) {
//        actualParent.updateChildFraction(from: _ProgressFraction(nsProgressFraction: fraction.previous), to: _ProgressFraction(nsProgressFraction: fraction.next), portion: Int(portion))
            actualParent.updateChildState(child: ghostChild, fraction: _ProgressFraction(nsProgressFraction: fraction.next))
    }
}
#endif
