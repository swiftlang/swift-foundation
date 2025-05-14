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
//MARK: Progress Parent - ProgressReporter Child Interop
// Actual Progress Parent
// Ghost Progress Parent
// Ghost ProgressReporter Child
// Actual ProgressReporter Child
extension Progress {
    
    /// Returns a Subprogress which can be passed to any method that reports progress
    /// and can be initialized into a child `ProgressReporter` to the `self`.
    ///
    /// Delegates a portion of totalUnitCount to a future child `ProgressReporter` instance.
    ///
    /// - Parameter count: Number of units delegated to a child instance of `ProgressReporter`
    /// which may be instantiated by `Subprogress` later when `reporter(totalCount:)` is called.
    /// - Returns: A `Subprogress` instance.
    public func makeChild(withPendingUnitCount count: Int) -> ProgressInput {
        
        // Make ghost parent & add it to actual parent's children list
        let ghostProgressParent = Progress(totalUnitCount: Int64(count))
        self.addChild(ghostProgressParent, withPendingUnitCount: Int64(count))
        
        // Make ghost child
        let ghostReporterChild = ProgressReporter(totalCount: count)
        
        // Make observation instance
        let observation = _ProgressParentProgressReporterChild(ghostParent: ghostProgressParent, ghostChild: ghostReporterChild)
        
        // Make actual child with ghost child being parent
        var actualProgress = ghostReporterChild.subprogress(assigningCount: count)
        actualProgress.observation = observation
        actualProgress.ghostReporter = ghostReporterChild
        actualProgress.interopWithProgressParent = true
        return actualProgress
    }
    
    public func addChild(_ output: ProgressOutput, withPendingUnitCount count: Int) {

        // Make intermediary & add it to NSProgress parent's children list
        let ghostProgressParent = Progress(totalUnitCount: Int64(output.reporter.totalCount ?? 0))
        ghostProgressParent.completedUnitCount = Int64(output.reporter.completedCount)
        self.addChild(ghostProgressParent, withPendingUnitCount: Int64(count))
        
        // Make observation instance
        let observation = _ProgressParentProgressOutputChild(intermediary: ghostProgressParent, progressOutput: output)

        output.reporter.setInteropObservationForMonitor(observation: observation)
        output.reporter.setMonitorInterop(to: true)
    }
}

private final class _ProgressParentProgressReporterChild: Sendable {
    private let ghostParent: Progress
    private let ghostChild: ProgressReporter
    
    fileprivate init(ghostParent: Progress, ghostChild: ProgressReporter) {
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

private final class _ProgressParentProgressOutputChild: Sendable {
    private let intermediary: Progress
    private let progressOutput: ProgressOutput
    
    fileprivate init(intermediary: Progress, progressOutput: ProgressOutput) {
        self.intermediary = intermediary
        self.progressOutput = progressOutput
        
        progressOutput.reporter.addObserver { [weak self] observerState in
            guard let self else {
                return
            }
            
            switch observerState {
            case .totalCountUpdated:
                self.intermediary.totalUnitCount = Int64(self.progressOutput.reporter.totalCount ?? 0)
                
            case .fractionUpdated:
                let count = self.progressOutput.reporter.withProperties { p in
                    return (p.completedCount, p.totalCount)
                }
                self.intermediary.completedUnitCount = Int64(count.0)
                self.intermediary.totalUnitCount = Int64(count.1 ?? 0)
            }
        }
    }
    
}

@available(FoundationPreview 6.2, *)
//MARK: ProgressReporter Parent - Progress Child Interop
extension ProgressReporter {

    /// Adds a Foundation's `Progress` instance as a child which constitutes a certain `count` of `self`'s `totalCount`.
    /// - Parameters:
    ///   - count: Number of units delegated from `self`'s `totalCount`.
    ///   - progress: `Progress` which receives the delegated `count`.
    public func subprogress(assigningCount count: Int, to progress: Foundation.Progress) {
        let parentBridge = _NSProgressParentBridge(reporterParent: self)
        progress._setParent(parentBridge, portion: Int64(count))

        // Save ghost parent in ProgressReporter so it doesn't go out of scope after assign method ends
        // So that when NSProgress increases completedUnitCount and queries for parent there is still a reference to ghostParent and parent doesn't show 0x0 (portion: 5)
        self.setParentBridge(parentBridge: parentBridge)
    }
}

// Subclass of Foundation.Progress
internal final class _NSProgressParentBridge: Progress, @unchecked Sendable {

    let actualParent: ProgressReporter

    init(reporterParent: ProgressReporter) {
        self.actualParent = reporterParent
        super.init(parent: nil, userInfo: nil)
    }

    // Overrides the _updateChild func that Foundation.Progress calls to update parent
    // so that the parent that gets updated is the ProgressReporter parent
    override func _updateChild(_ child: Foundation.Progress, fraction: _NSProgressFractionTuple, portion: Int64) {
        actualParent.updateChildFraction(from: _ProgressFraction(nsProgressFraction: fraction.previous), to: _ProgressFraction(nsProgressFraction: fraction.next), portion: Int(portion))
    }
}
#endif
