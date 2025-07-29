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
import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

/// Unit tests for propagation of type-safe metadata in ProgressManager tree.
#if FOUNDATION_FRAMEWORK
/// Unit tests for interop methods that support building Progress trees with both Progress and ProgressManager
@Suite("Progress Manager Interop") struct ProgressManagerInteropTests {
    func doSomethingWithProgress() async -> Progress {
        let p = Progress(totalUnitCount: 2)
        return p
    }
    
    func doSomethingWithReporter(subprogress: consuming Subprogress?) async {
        let manager =  subprogress?.start(totalCount: 4)
        manager?.complete(count: 2)
        manager?.complete(count: 2)
    }
    
    @Test func interopProgressParentProgressManagerChild() async throws {
        // Initialize a Progress Parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let p1 = await doSomethingWithProgress()
        overall.addChild(p1, withPendingUnitCount: 5)
        
        let _ = await Task.detached {
            p1.completedUnitCount = 1
            try? await Task.sleep(nanoseconds: 10000)
            p1.completedUnitCount = 2
        }.value
        
        // Check if ProgressManager values propagate to Progress parent
        #expect(overall.fractionCompleted == 0.5)
        #expect(overall.completedUnitCount == 5)
        
        // Add ProgressManager as Child
        let p2 = overall.makeChild(withPendingUnitCount: 5)
        await doSomethingWithReporter(subprogress: p2)
        
        // Check if Progress values propagate to Progress parent
        #expect(overall.fractionCompleted == 1.0)
        #expect(overall.completedUnitCount == 10)
    }
    
    @Test func interopProgressParentProgressReporterChildWithEmptyProgress() async throws {
        // Initialize a Progress parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let p1 = await doSomethingWithProgress()
        overall.addChild(p1, withPendingUnitCount: 5)
        
        let _ = await Task.detached {
            p1.completedUnitCount = 1
            try? await Task.sleep(nanoseconds: 10000)
            p1.completedUnitCount = 2
        }.value

        // Check if ProgressManager values propagate to Progress parent
        #expect(overall.fractionCompleted == 0.5)
        #expect(overall.completedUnitCount == 5)
        
        // Add ProgressReporter as Child
        let p2 = ProgressManager(totalCount: 10)
        let p2Reporter = p2.reporter
        overall.addChild(p2Reporter, withPendingUnitCount: 5)
        
        p2.complete(count: 10)
        
        // Check if Progress values propagate to Progress parent
        #expect(overall.fractionCompleted == 1.0)
        #expect(overall.completedUnitCount == 10)
    }
    
    @Test func interopProgressParentProgressReporterChildWithExistingProgress() async throws {
        // Initialize a Progress parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let p1 = await doSomethingWithProgress()
        overall.addChild(p1, withPendingUnitCount: 5)
        
        let _ = await Task.detached {
            p1.completedUnitCount = 1
            try? await Task.sleep(nanoseconds: 10000)
            p1.completedUnitCount = 2
        }.value
        
        // Check if ProgressManager values propagate to Progress parent
        #expect(overall.fractionCompleted == 0.5)
        #expect(overall.completedUnitCount == 5)
        
        // Add ProgressReporter with CompletedCount 3 as Child
        let p2 = ProgressManager(totalCount: 10)
        p2.complete(count: 3)
        let p2Reporter = p2.reporter
        overall.addChild(p2Reporter, withPendingUnitCount: 5)
        
        p2.complete(count: 7)
        
        // Check if Progress values propagate to Progress parent
        #expect(overall.fractionCompleted == 1.0)
        #expect(overall.completedUnitCount == 10)
    }
    
    @Test func interopProgressManagerParentProgressChild() async throws {
        // Initialize ProgressManager parent
        let overallManager = ProgressManager(totalCount: 10)
        
        // Add ProgressManager as Child
        await doSomethingWithReporter(subprogress: overallManager.subprogress(assigningCount: 5))
        
        // Check if ProgressManager values propagate to ProgressManager parent
        #expect(overallManager.fractionCompleted == 0.5)
        #expect(overallManager.completedCount == 5)
        
        // Interop: Add Progress as Child
        let p2 = await doSomethingWithProgress()
        overallManager.subprogress(assigningCount: 5, to: p2)
        
        let _ = await Task.detached {
            p2.completedUnitCount = 1
            try? await Task.sleep(nanoseconds: 10000)
            p2.completedUnitCount = 2
        }.value
        
        // Check if Progress values propagate to ProgressRerpoter parent
        #expect(overallManager.completedCount == 10)
        #expect(overallManager.totalCount == 10)
        #expect(overallManager.fractionCompleted == 1.0)
    }
    
    func getProgressWithTotalCountInitialized() -> Progress {
        return Progress(totalUnitCount: 5)
    }
    
    func receiveProgress(progress: consuming Subprogress) {
        let _ = progress.start(totalCount: 5)
    }
    
    @Test func interopProgressManagerParentProgressChildConsistency() async throws {
        let overallReporter = ProgressManager(totalCount: nil)
        let child = overallReporter.subprogress(assigningCount: 5)
        receiveProgress(progress: child)
        #expect(overallReporter.totalCount == nil)
        
        let overallReporter2 = ProgressManager(totalCount: nil)
        let interopChild = getProgressWithTotalCountInitialized()
        overallReporter2.subprogress(assigningCount: 5, to: interopChild)
        #expect(overallReporter2.totalCount == nil)
    }
    
    @Test func interopProgressParentProgressManagerChildConsistency() async throws {
        let overallProgress = Progress()
        let child = Progress(totalUnitCount: 5)
        overallProgress.addChild(child, withPendingUnitCount: 5)
        #expect(overallProgress.totalUnitCount == 0)
        
        let overallProgress2 = Progress()
        let interopChild = overallProgress2.makeChild(withPendingUnitCount: 5)
        receiveProgress(progress: interopChild)
        #expect(overallProgress2.totalUnitCount == 0)
    }
    
    #if FOUNDATION_EXIT_TESTS
    @Test func indirectParticipationOfProgressInAcyclicGraph() async throws {
        await #expect(processExitsWith: .failure) {
            let manager = ProgressManager(totalCount: 2)
            
            let parentManager1 = ProgressManager(totalCount: 1)
            parentManager1.assign(count: 1, to: manager.reporter)
            
            let parentManager2 = ProgressManager(totalCount: 1)
            parentManager2.assign(count: 1, to: manager.reporter)
            
            let progress = Progress.discreteProgress(totalUnitCount: 4)
            manager.subprogress(assigningCount: 1, to: progress)
                    
            progress.completedUnitCount = 2
            #expect(progress.fractionCompleted == 0.5)
            #expect(manager.fractionCompleted == 0.25)
            #expect(parentManager1.fractionCompleted == 0.25)
            #expect(parentManager2.fractionCompleted == 0.25)
            
            progress.addChild(parentManager1.reporter, withPendingUnitCount: 1)
        }
    }
    #endif
}
#endif
