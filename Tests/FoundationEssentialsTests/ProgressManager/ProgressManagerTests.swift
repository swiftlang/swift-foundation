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

/// Unit tests for basic functionalities of ProgressManager
@Suite("Progress Manager") struct ProgressManagerTests {
    /// MARK: Helper methods that report progress
    func doBasicOperationV1(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 8)
        for i in 1...8 {
            manager.complete(count: 1)
            #expect(manager.completedCount == i)
            #expect(manager.fractionCompleted == Double(i) / Double(8))
        }
    }
    
    func doBasicOperationV2(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 7)
        for i in 1...7 {
            manager.complete(count: 1)
            #expect(manager.completedCount == i)
            #expect(manager.fractionCompleted == Double(i) / Double(7))
        }
    }
    
    func doBasicOperationV3(reportTo subprogress: consuming Subprogress) async {
        let manager =  subprogress.start(totalCount: 11)
        for i in 1...11 {
            manager.complete(count: 1)
            #expect(manager.completedCount == i)
            #expect(manager.fractionCompleted == Double(i) / Double(11))
        }
    }
    
    /// MARK: Tests calculations based on change in totalCount
    @Test func totalCountNil() async throws {
        let overall = ProgressManager(totalCount: nil)
        overall.complete(count: 10)
        #expect(overall.completedCount == 10)
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.isIndeterminate == true)
        #expect(overall.totalCount == nil)
    }
    
    @Test func totalCountReset() async throws {
        let overall = ProgressManager(totalCount: 10)
        overall.complete(count: 5)
        #expect(overall.completedCount == 5)
        #expect(overall.totalCount == 10)
        #expect(overall.fractionCompleted == 0.5)
        #expect(overall.isIndeterminate == false)

        overall.withProperties { p in
            p.totalCount = nil
            p.completedCount += 1
        }
        #expect(overall.completedCount == 6)
        #expect(overall.totalCount == nil)
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.isIndeterminate == true)
        #expect(overall.isFinished == false)
        
        overall.withProperties { p in
            p.totalCount = 12
            p.completedCount += 2
        }
        #expect(overall.completedCount == 8)
        #expect(overall.totalCount == 12)
        #expect(overall.fractionCompleted == Double(8) / Double(12))
        #expect(overall.isIndeterminate == false)
        #expect(overall.isFinished == false)
    }
    
    @Test func totalCountNilWithChild() async throws {
        let overall = ProgressManager(totalCount: nil)
        #expect(overall.completedCount == 0)
        #expect(overall.totalCount == nil)
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.isIndeterminate == true)
        #expect(overall.isFinished == false)
        
        let progress1 = overall.subprogress(assigningCount: 2)
        let manager1 = progress1.start(totalCount: 1)
        
        manager1.complete(count: 1)
        #expect(manager1.totalCount == 1)
        #expect(manager1.completedCount == 1)
        #expect(manager1.fractionCompleted == 1.0)
        #expect(manager1.isIndeterminate == false)
        #expect(manager1.isFinished == true)
        
        #expect(overall.completedCount == 2)
        #expect(overall.totalCount == nil)
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.isIndeterminate == true)
        #expect(overall.isFinished == false)
        
        overall.withProperties { p in
            p.totalCount = 5
        }
        #expect(overall.completedCount == 2)
        #expect(overall.totalCount == 5)
        #expect(overall.fractionCompleted == 0.4)
        #expect(overall.isIndeterminate == false)
        #expect(overall.isFinished == false)
    }
    
    @Test func totalCountFinishesWithLessCompletedCount() async throws {
        let overall = ProgressManager(totalCount: 10)
        overall.complete(count: 5)
        
        let progress1 = overall.subprogress(assigningCount: 8)
        let manager1 = progress1.start(totalCount: 1)
        manager1.complete(count: 1)
        
        #expect(overall.completedCount == 13)
        #expect(overall.totalCount == 10)
        #expect(overall.fractionCompleted == 1.3)
        #expect(overall.isIndeterminate == false)
        #expect(overall.isFinished == true)
    }
    
    /// MARK: Tests single-level tree
    @Test func discreteManager() async throws {
        let manager =  ProgressManager(totalCount: 3)
        await doBasicOperationV1(reportTo: manager.subprogress(assigningCount: 3))
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.completedCount == 3)
        #expect(manager.isFinished == true)
    }
    
    /// MARK: Tests multiple-level trees
    @Test func emptyDiscreteManager() async throws {
        let manager = ProgressManager(totalCount: nil)
        #expect(manager.isIndeterminate == true)
        
        manager.withProperties { p in
            p.totalCount = 10
        }
        #expect(manager.isIndeterminate == false)
        #expect(manager.totalCount == 10)
        
        await doBasicOperationV1(reportTo: manager.subprogress(assigningCount: 10))
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.completedCount == 10)
        #expect(manager.isFinished == true)
    }
    
    @Test func twoLevelTreeWithTwoChildren() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        await doBasicOperationV1(reportTo: overall.subprogress(assigningCount: 1))
        #expect(overall.fractionCompleted == 0.5)
        #expect(overall.completedCount == 1)
        #expect(overall.isFinished == false)
        #expect(overall.isIndeterminate == false)
        
        await doBasicOperationV2(reportTo: overall.subprogress(assigningCount: 1))
        #expect(overall.fractionCompleted == 1.0)
        #expect(overall.completedCount == 2)
        #expect(overall.isFinished == true)
        #expect(overall.isIndeterminate == false)
    }
    
    @Test func twoLevelTreeWithTwoChildrenWithOneFileProperty() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 5)
        manager1.complete(count: 5)
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let manager2 = progress2.start(totalCount: 5)
        manager2.withProperties { properties in
            properties.totalFileCount = 10
        }
 
        #expect(overall.fractionCompleted == 0.5)
        // Parent is expected to get totalFileCount from one of the children with a totalFileCount
        #expect(overall.withProperties(\.totalFileCount) == 0)
    }
    
    @Test func twoLevelTreeWithMultipleChildren() async throws {
        let overall = ProgressManager(totalCount: 3)
        
        await doBasicOperationV1(reportTo: overall.subprogress(assigningCount:1))
        #expect(overall.fractionCompleted == Double(1) / Double(3))
        #expect(overall.completedCount == 1)
        
        await doBasicOperationV2(reportTo: overall.subprogress(assigningCount:1))
        #expect(overall.fractionCompleted == Double(2) / Double(3))
        #expect(overall.completedCount == 2)
        
        await doBasicOperationV3(reportTo: overall.subprogress(assigningCount:1))
        #expect(overall.fractionCompleted == Double(3) / Double(3))
        #expect(overall.completedCount == 3)
    }
    
    @Test func threeLevelTree() async throws {
        let overall = ProgressManager(totalCount: 100)
        #expect(overall.fractionCompleted == 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let manager1 = child1.start(totalCount: 100)
        
        let grandchild1 = manager1.subprogress(assigningCount: 100)
        let grandchildManager1 = grandchild1.start(totalCount: 100)
        
        #expect(overall.fractionCompleted == 0.0)
        
        grandchildManager1.complete(count: 50)
        #expect(manager1.fractionCompleted == 0.5)
        #expect(overall.fractionCompleted == 0.5)
        
        grandchildManager1.complete(count: 50)
        #expect(manager1.fractionCompleted == 1.0)
        #expect(overall.fractionCompleted == 1.0)
        
        #expect(grandchildManager1.isFinished == true)
        #expect(manager1.isFinished == true)
        #expect(overall.isFinished == true)
    }
    
    @Test func fourLevelTree() async throws {
        let overall = ProgressManager(totalCount: 100)
        #expect(overall.fractionCompleted == 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let manager1 = child1.start(totalCount: 100)
        
        let grandchild1 = manager1.subprogress(assigningCount: 100)
        let grandchildManager1 = grandchild1.start(totalCount: 100)
        
        #expect(overall.fractionCompleted == 0.0)
        
        let greatGrandchild1 = grandchildManager1.subprogress(assigningCount: 100)
        let greatGrandchildManager1 = greatGrandchild1.start(totalCount: 100)
        
        greatGrandchildManager1.complete(count: 50)
        #expect(overall.fractionCompleted == 0.5)
        
        greatGrandchildManager1.complete(count: 50)
        #expect(overall.fractionCompleted == 1.0)
        
        #expect(greatGrandchildManager1.isFinished  == true)
        #expect(grandchildManager1.isFinished == true)
        #expect(manager1.isFinished == true)
        #expect(overall.isFinished == true)
    }
    
    func doSomething(amount: Int, subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: amount)
        for _ in 1...amount {
            manager.complete(count: 1)
        }
    }
    
    @Test func fiveThreadsMutatingAndReading() async throws {
        let manager = ProgressManager(totalCount: 10)

        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await doSomething(amount: 5, subprogress: manager.subprogress(assigningCount: 1))
            }
            
            group.addTask {
                await doSomething(amount: 8, subprogress: manager.subprogress(assigningCount: 1))
            }
            
            group.addTask {
                await doSomething(amount: 7, subprogress: manager.subprogress(assigningCount: 1))
            }
            
            group.addTask {
                await doSomething(amount: 6, subprogress: manager.subprogress(assigningCount: 1))
            }
            
            group.addTask {
                #expect(manager.fractionCompleted <= 0.4)
            }
        }
    }
    
    func makeUnfinishedChild(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        manager.complete(count: 2)
        #expect(manager.fractionCompleted == Double(2) / Double(3))
    }
    
    @Test func unfinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        #expect(manager.fractionCompleted == 0.5)
        
        await makeUnfinishedChild(subprogress: manager.subprogress(assigningCount: 1))
        #expect(manager.fractionCompleted == 1.0)
    }
}

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

@Suite("Progress Reporter") struct ProgressReporterTests {
    @Test func observeProgressReporter() {
        let manager = ProgressManager(totalCount: 3)
        
        let reporter = manager.reporter
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 1)
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 2)
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 3)
        
        let fileCount = reporter.withProperties { properties in
            properties.totalFileCount
        }
        #expect(fileCount == 0)
        
        manager.withProperties { properties in
            properties.totalFileCount = 6
        }
        #expect(reporter.withProperties(\.totalFileCount) == 6)
        
        let summaryTotalFile = manager.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 6)
    }
    
    @Test func testAddProgressReporterAsChild() {
        let manager = ProgressManager(totalCount: 2)
        
        let reporter = manager.reporter
        
        let altManager1 = ProgressManager(totalCount: 4)
        altManager1.assign(count: 1, to: reporter)
        
        let altManager2 = ProgressManager(totalCount: 5)
        altManager2.assign(count: 2, to: reporter)
        
        manager.complete(count: 1)
        #expect(altManager1.fractionCompleted == 0.125)
        #expect(altManager2.fractionCompleted == 0.2)
        
        manager.complete(count: 1)
        #expect(altManager1.fractionCompleted == 0.25)
        #expect(altManager2.fractionCompleted == 0.4)
    }
    
    @Test func testAssignToProgressReporterThenSetTotalCount() {
        let overall = ProgressManager(totalCount: nil)
        
        let child1 = ProgressManager(totalCount: 10)
        overall.assign(count: 10, to: child1.reporter)
        child1.complete(count: 5)
        
        let child2 = ProgressManager(totalCount: 20)
        overall.assign(count: 20, to: child2.reporter)
        child2.complete(count: 20)
        
        overall.withProperties { properties in
            properties.totalCount = 30
        }
        #expect(overall.completedCount == 20)
        #expect(overall.fractionCompleted == Double(25) / Double(30))
        
        child1.complete(count: 5)
        
        #expect(overall.completedCount == 30)
        #expect(overall.fractionCompleted == 1.0)
    }
    
    @Test func testMakeSubprogressThenSetTotalCount() async {
        let overall = ProgressManager(totalCount: nil)
        
        let reporter1 = await dummy(index: 1, subprogress: overall.subprogress(assigningCount: 10))
        
        let reporter2 = await dummy(index: 2, subprogress: overall.subprogress(assigningCount: 20))
        
        #expect(reporter1.fractionCompleted == 0.5)
        
        #expect(reporter2.fractionCompleted == 0.5)
        
        overall.withProperties { properties in
            properties.totalCount = 30
        }
        
        #expect(overall.totalCount == 30)
        #expect(overall.fractionCompleted == 0.5)
    }
    
    func dummy(index: Int, subprogress: consuming Subprogress) async -> ProgressReporter {
        let manager = subprogress.start(totalCount: index * 10)
        
        manager.complete(count: (index * 10) / 2)
        
        return manager.reporter
    }
    
    /// All of these test cases hit the precondition for cycle detection, but currently there's no way to check for hitting precondition in xctest.
    #if FOUNDATION_EXIT_TESTS
    @Test func testProgressReporterDirectCycleDetection() async {
        await #expect(processExitsWith: .failure) {
            let manager = ProgressManager(totalCount: 2)
            manager.assign(count: 1, to: manager.reporter)
        }
    }
    
    @Test func testProgressReporterIndirectCycleDetection() async throws {
        await #expect(processExitsWith: .failure) {
            let manager = ProgressManager(totalCount: 2)
                    
            let altManager = ProgressManager(totalCount: 1)
            altManager.assign(count: 1, to: manager.reporter)
            
            manager.assign(count: 1, to: altManager.reporter)
        }
    }
    
    @Test func testProgressReporterNestedCycleDetection() async throws {
        
        await #expect(processExitsWith: .failure) {
            let manager1 = ProgressManager(totalCount: 1)
            
            let manager2 = ProgressManager(totalCount: 2)
            manager1.assign(count: 1, to: manager2.reporter)
            
            let manager3 = ProgressManager(totalCount: 3)
            manager2.assign(count: 1, to: manager3.reporter)
            
            manager3.assign(count: 1, to: manager1.reporter)

        }
    }
    #endif
}
