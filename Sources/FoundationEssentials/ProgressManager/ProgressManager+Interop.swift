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
internal import Synchronization

//MARK: Progress Parent - Subprogress / ProgressReporter Child Interop
@available(FoundationPreview 6.2, *)
extension Progress {
    
    /// Returns a Subprogress which can be passed to any method that reports progress
    /// It can be then used to create a child `ProgressManager` reporting to this `Progress`
    ///
    /// Delegates a portion of totalUnitCount to a future child `ProgressManager` instance.
    ///
    /// - Parameter count: Number of units delegated to a child instance of `ProgressManager`
    /// which may be instantiated by `Subprogress` later when `reporter(totalCount:)` is called.
    /// - Returns: A `Subprogress` instance.
    public func makeChild(withPendingUnitCount count: Int) -> Subprogress {
        
        // Make a ProgressManager
        let manager = ProgressManager(totalCount: 1)
        
        // Create a NSProgress - ProgressManager bridge for mirroring
        let subprogressBridge = SubprogressBridge(
            parent: self,
            portion: Int64(count),
            manager: manager
        )
        
        // Instantiate a Subprogress with ProgressManager as parent
        // Store bridge
        let subprogress = Subprogress(
            parent: manager,
            portionOfParent: 1,
            subprogressBridge: subprogressBridge
        )
        
        return subprogress
    }
    
    /// Adds a ProgressReporter as a child to a Progress, which constitutes a portion of Progress's totalUnitCount.
    ///
    /// - Parameters:
    ///   - reporter: A `ProgressReporter` instance.
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    public func addChild(_ reporter: ProgressReporter, withPendingUnitCount count: Int) {
        
        precondition(self.isCycle(reporter: reporter) == false, "Creating a cycle is not allowed.")
        
        // Create a NSProgress - ProgressReporter bridge
        let reporterBridge = ProgressReporterBridge(
            parent: self,
            portion: Int64(count),
            reporterBridge: reporter
        )
        
        // Store bridge
        reporter.manager.addBridge(reporterBridge: reporterBridge)
    }
    
    // MARK: Cycle detection
    private func isCycle(reporter: ProgressReporter, visited: Set<ProgressManager> = []) -> Bool {
        if self._parent() == nil {
            return false
        }
        
        if !(self._parent() is NSProgressBridge) {
            return self._parent().isCycle(reporter: reporter)
        }
        
        let unwrappedParent = (self._parent() as? NSProgressBridge)?.manager
        if let unwrappedParent = unwrappedParent {
            if unwrappedParent === reporter.manager {
                return true
            }
            let updatedVisited = visited.union([unwrappedParent])
            return unwrappedParent.isCycleInterop(reporter: reporter, visited: updatedVisited)
        }
        return false
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
        
        // Create a ProgressManager - NSProgress bridge
        let progressBridge = NSProgressBridge(
            manager: self,
            progress: progress,
            portion: count
        )
        
        // Add bridge as a parent
        progress._setParent(progressBridge, portion: Int64(count))

        // Store bridge
        self.addBridge(nsProgressBridge: progressBridge)
    }
}

internal final class SubprogressBridge: Sendable {
    
    internal let progressBridge: Progress
    internal let manager: ProgressManager
    
    init(parent: Progress, portion: Int64, manager: ProgressManager) {
        self.progressBridge = Progress(totalUnitCount: 1, parent: parent, pendingUnitCount: portion)
        self.manager = manager

        manager.addObserver { [weak self] observerState in
            guard let self else {
                return
            }
            
            switch observerState {
            case .fractionUpdated(let totalCount, let completedCount):
                // This needs to change totalUnitCount before completedUnitCount otherwise progressBridge will finish and mess up the math
                self.progressBridge.totalUnitCount = Int64(totalCount)
                self.progressBridge.completedUnitCount = Int64(completedCount)
            }
        }
    }
}

internal final class ProgressReporterBridge: Sendable {
    
    internal let progressBridge: Progress
    internal let reporterBridge: ProgressReporter
    
    init(parent: Progress, portion: Int64, reporterBridge: ProgressReporter) {
        self.progressBridge = Progress(
            totalUnitCount: Int64(reporterBridge.manager.totalCount ?? 0),
            parent: parent,
            pendingUnitCount: portion
        )
        self.progressBridge.completedUnitCount = Int64(reporterBridge.manager.completedCount)
        self.reporterBridge = reporterBridge
                
        let manager = reporterBridge.manager
        
        manager.addObserver { [weak self] observerState in
            guard let self else {
                return
            }
            
            switch observerState {
            case .fractionUpdated(let totalCount, let completedCount):
                self.progressBridge.totalUnitCount = Int64(totalCount)
                self.progressBridge.completedUnitCount = Int64(completedCount)
            }
        }
    }
    
}

internal final class NSProgressBridge: Progress, @unchecked Sendable {

    internal let manager: ProgressManager
    internal let managerBridge: ProgressManager
    internal let progress: Progress

    init(manager: ProgressManager, progress: Progress, portion: Int) {
        self.manager = manager
        self.managerBridge = ProgressManager(totalCount: Int(progress.totalUnitCount))
        self.progress = progress
        super.init(parent: nil, userInfo: nil)
        
        managerBridge.withProperties { properties in
            properties.completedCount = Int(progress.completedUnitCount)
        }
        
        let position = manager.addChild(
            child: managerBridge,
            portion: portion,
            childFraction: ProgressFraction(completed: Int(completedUnitCount), total: Int(totalUnitCount))
        )
        managerBridge.addParent(parent: manager, positionInParent: position)
    }

    // Overrides the _updateChild func that Foundation.Progress calls to update parent
    // so that the parent that gets updated is the ProgressManager parent
    override func _updateChild(_ child: Foundation.Progress, fraction: _NSProgressFractionTuple, portion: Int64) {
        managerBridge.withProperties { properties in
            properties.totalCount = Int(fraction.next.total)
            properties.completedCount = Int(fraction.next.completed)
        }
        
        managerBridge.markSelfDirty()
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    // Keeping this as an enum in case we have other states to track in the future.
    internal enum ObserverState {
        case fractionUpdated(totalCount: Int, completedCount: Int)
    }
    
    internal struct InteropObservation {
        let subprogressBridge: SubprogressBridge?
        var reporterBridge: ProgressReporterBridge?
        var nsProgressBridge: Foundation.Progress?
    }
    
    internal enum InteropType {
        case interopMirror(ProgressManager)
        case interopObservation(InteropObservation)
        
        internal var totalCount: Int? {
            switch self {
            case .interopMirror(let mirror):
                mirror.totalCount
            case .interopObservation:
                nil
            }
        }
        
        internal var completedCount: Int? {
            switch self {
            case .interopMirror(let mirror):
                mirror.completedCount
            case .interopObservation:
                nil
            }
        }
        
        internal var fractionCompleted: Double? {
            switch self {
            case .interopMirror(let mirror):
                mirror.fractionCompleted
            case .interopObservation:
                nil
            }
        }
        
        internal var isIndeterminate: Bool? {
            switch self {
            case .interopMirror(let mirror):
                mirror.isIndeterminate
            case .interopObservation:
                nil
            }
        }
        
        internal var isFinished: Bool? {
            switch self {
            case .interopMirror(let mirror):
                 mirror.isFinished
            case .interopObservation:
                nil
            }
        }
    }
}

extension ProgressManager.State {
    internal func notifyObservers(with observerState: ProgressManager.ObserverState) {
        for observer in observers {
            observer(observerState)
        }
    }
}

@available(FoundationPreview 6.2, *)
extension ProgressManager {
    //MARK: Interop Methods
    /// Adds `observer` to list of `_observers` in `self`.
    internal func addObserver(observer: @escaping @Sendable (ObserverState) -> Void) {
        state.withLock { state in
            state.observers.append(observer)
        }
    }
    
    /// Notifies all `_observers` of `self` when `state` changes.
    internal func notifyObservers(with observedState: ObserverState) {
        state.withLock { state in
            for observer in state.observers {
                observer(observedState)
            }
        }
    }
    
    internal func addBridge(reporterBridge: ProgressReporterBridge? = nil, nsProgressBridge: Foundation.Progress? = nil) {
        state.withLock { state in
            var interopObservation = InteropObservation(subprogressBridge: nil)
            
            if let reporterBridge {
                interopObservation.reporterBridge = reporterBridge
//                state.interopObservation.reporterBridge = reporterBridge
            }
            
            if let nsProgressBridge {
                interopObservation.nsProgressBridge = nsProgressBridge
//                state.interopObservation.nsProgressBridge = nsProgressBridge
            }
            
            state.interopType = .interopObservation(interopObservation)
        }
    }
    
    internal func setInteropChild(interopMirror: ProgressManager) {
        state.withLock { state in
            state.interopType = .interopMirror(interopMirror)
        }
    }
}
#endif
