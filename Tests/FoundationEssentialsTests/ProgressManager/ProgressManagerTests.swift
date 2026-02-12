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

extension Tag {
    @Tag static var progressManager: Self
}

/// Unit tests for basic functionalities of ProgressManager
@Suite("Progress Manager", .tags(.progressManager)) struct ProgressManagerTests {
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
        
        overall.setCounts { _, total in
            total = nil
        }
        overall.complete(count: 1)
        #expect(overall.completedCount == 6)
        #expect(overall.totalCount == nil)
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.isIndeterminate == true)
        #expect(overall.isFinished == false)
        
        overall.setCounts { _, total in
            total = 12
        }
        overall.complete(count: 2)
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
        
        overall.setCounts { _, total in
            total = 5
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
    
    @Test func childTotalCountReset() async throws {
        let overall = ProgressManager(totalCount: 1)
        
        let childManager = overall.subprogress(assigningCount: 1).start(totalCount: 4)
        childManager.complete(count: 2)
        
        #expect(overall.fractionCompleted == 0.5)
        #expect(childManager.isIndeterminate == false)
        
        childManager.setCounts { _, total in
            total = nil
        }
        
        #expect(overall.fractionCompleted == 0.0)
        #expect(childManager.isIndeterminate == true)
        #expect(childManager.completedCount == 2)
        
        childManager.setCounts { _, total in
            total = 5
        }
        childManager.complete(count: 2)
        
        #expect(overall.fractionCompleted == 0.8)
        #expect(childManager.completedCount == 4)
        #expect(childManager.isIndeterminate == false)
        
        childManager.complete(count: 1)
        #expect(overall.fractionCompleted == 1.0)
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
        
        manager.setCounts { _, total in
            total = 10
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
        manager2.totalFileCount = 10
        
        #expect(overall.fractionCompleted == 0.5)
        // Parent is expected to get totalFileCount from one of the children with a totalFileCount
        #expect(overall.totalFileCount == 0)
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
    
    // MARK: Test deinit behavior
    func makeUnfinishedChild(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        manager.complete(count: 2)
        #expect(manager.fractionCompleted == Double(2) / Double(3))
    }
    
    func makeFinishedChild(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        manager.complete(count: 2)
    }
    
    @Test func unfinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        #expect(manager.fractionCompleted == 0.5)
        
        await makeUnfinishedChild(subprogress: manager.subprogress(assigningCount: 1))
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func unfinishedGrandchild() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        let child = manager.subprogress(assigningCount: 1).start(totalCount: 1)
        
        await makeUnfinishedChild(subprogress: child.subprogress(assigningCount: 1))
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func unfinishedGreatGrandchild() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        let child = manager.subprogress(assigningCount: 1).start(totalCount: 1)
        
        let grandchild = child.subprogress(assigningCount: 1).start(totalCount: 1)
        
        await makeUnfinishedChild(subprogress: grandchild.subprogress(assigningCount: 1))
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func finishedChildUnreadBeforeDeinit() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        #expect(manager.fractionCompleted == 0.5)
        
        await makeFinishedChild(subprogress: manager.subprogress(assigningCount: 1))
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func finishedChildReadBeforeDeinit() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        #expect(manager.fractionCompleted == 0.5)

        var child: ProgressManager? = manager.subprogress(assigningCount: 1).start(totalCount: 1)
        child?.complete(count: 1)
        #expect(manager.fractionCompleted == 1.0)
        
        child = nil
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func uninitializedSubprogress() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        
        withExtendedLifetime(manager.subprogress(assigningCount: 1)) {
            #expect(manager.fractionCompleted == 0.5)
        }

        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func deallocatedChild() async throws {
        let manager = ProgressManager(totalCount: 100)
        
        var child: ProgressManager? = manager.subprogress(assigningCount: 50).start(totalCount: 10)
        child!.complete(count: 5)
        
        let fractionBeforeDeallocation = manager.fractionCompleted
        #expect(fractionBeforeDeallocation == 0.25)
        
        child = nil
        
        for _ in 1...10 {
            _ = manager.fractionCompleted
        }
        
        let fractionAfterDeallocation = manager.fractionCompleted
        
        #expect(fractionAfterDeallocation == 0.5, "Deallocated child should be assumed completed.")
        
        manager.complete(count: 50)
        #expect(manager.fractionCompleted == 1.0)
    }
}

// MARK: - Thread Safety and Concurrent Access Tests
@Suite("Progress Manager Thread Safety Tests", .tags(.progressManager)) struct ProgressManagerThreadSafetyTests {
    
    @Test func concurrentBasicPropertiesAccess() async throws {
        let manager = ProgressManager(totalCount: 10)
        manager.complete(count: 5)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            
            group.addTask {
                for _ in 1...10 {
                    let fraction = manager.fractionCompleted
                    #expect(fraction == 0.5)
                }
            }
            
            group.addTask {
                for _ in 1...10 {
                    let completed = manager.completedCount
                    #expect(completed == 5)
                }
            }
            
            group.addTask {
                for _ in 1...10 {
                    let total = manager.totalCount
                    #expect(total == 10)
                }
            }
            
            group.addTask {
                for _ in 1...10 {
                    let isFinished = manager.isFinished
                    #expect(isFinished == false)
                }
            }
            
            group.addTask {
                for _ in 1...10 {
                    let isIndeterminate = manager.isIndeterminate
                    #expect(isIndeterminate == false)
                }
            }
        }
    }
    
    @Test func concurrentMultipleChildrenUpdatesAndParentReads() async throws {
        let manager = ProgressManager(totalCount: 100)
        let child1 = manager.subprogress(assigningCount: 30).start(totalCount: 10)
        let child2 = manager.subprogress(assigningCount: 40).start(totalCount: 8)
        let child3 = manager.subprogress(assigningCount: 30).start(totalCount: 6)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...10 {
                    child1.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...8 {
                    child2.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...6 {
                    child3.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...50 {
                    let _ = manager.fractionCompleted
                    let _ = manager.completedCount
                    let _ = manager.isFinished
                }
            }
            
            group.addTask {
                for _ in 1...30 {
                    let _ = child1.fractionCompleted
                    let _ = child2.completedCount
                    let _ = child3.isFinished
                }
            }
        }
        
        #expect(child1.isFinished == true)
        #expect(child2.isFinished == true)
        #expect(child3.isFinished == true)
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func concurrentSingleChildUpdatesAndParentReads() async throws {
        let manager = ProgressManager(totalCount: 50)
        let child = manager.subprogress(assigningCount: 50).start(totalCount: 100)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 1...100 {
                    child.complete(count: 1)
                    if i % 10 == 0 {
                        try? await Task.sleep(nanoseconds: 1_000_000)
                    }
                }
            }
            
            group.addTask {
                for _ in 1...200 {
                    let _ = manager.fractionCompleted
                    let _ = manager.completedCount
                    let _ = manager.totalCount
                    let _ = manager.isFinished
                    let _ = manager.isIndeterminate
                }
            }
            
            group.addTask {
                for _ in 1...150 {
                    let _ = child.fractionCompleted
                    let _ = child.completedCount
                    let _ = child.isFinished
                }
            }
        }
        
        #expect(child.isFinished == true)
        #expect(manager.fractionCompleted == 1.0)
    }
    
    @Test func concurrentGrandchildrenUpdates() async throws {
        let parent = ProgressManager(totalCount: 60)
        let child1 = parent.subprogress(assigningCount: 20).start(totalCount: 10)
        let child2 = parent.subprogress(assigningCount: 20).start(totalCount: 8)
        let child3 = parent.subprogress(assigningCount: 20).start(totalCount: 6)
        
        let grandchild1 = child1.subprogress(assigningCount: 5).start(totalCount: 4)
        let grandchild2 = child2.subprogress(assigningCount: 4).start(totalCount: 3)
        let grandchild3 = child3.subprogress(assigningCount: 3).start(totalCount: 2)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...4 {
                    grandchild1.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...3 {
                    grandchild2.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...2 {
                    grandchild3.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...5 {
                    child1.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...4 {
                    child2.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...3 {
                    child3.complete(count: 1)
                }
            }
            
            group.addTask {
                for _ in 1...100 {
                    let _ = parent.fractionCompleted
                    let _ = child1.fractionCompleted
                    let _ = grandchild1.completedCount
                }
            }
        }
        
        #expect(grandchild1.isFinished == true)
        #expect(grandchild2.isFinished == true)
        #expect(grandchild3.isFinished == true)
        #expect(parent.isFinished == true)
    }
    
    @Test func concurrentReadDuringIndeterminateToDeterminateTransition() async throws {
        let manager = ProgressManager(totalCount: nil)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...50 {
                    let _ = manager.fractionCompleted
                    let _ = manager.isIndeterminate
                }
            }
            
            group.addTask {
                for _ in 1...10 {
                    manager.complete(count: 1)
                }
            }
            
            // Task 3: Change to determinate after a delay
            group.addTask {
                try? await Task.sleep(nanoseconds: 1_000_000)
                manager.setCounts { _, total in
                    total = 20
                }
                
                for _ in 1...30 {
                    let _ = manager.fractionCompleted
                    let _ = manager.isIndeterminate
                }
            }
        }
        
        #expect(manager.totalCount == 20)
        #expect(manager.completedCount == 10)
        #expect(manager.isIndeterminate == false)
    }
    
    @Test func concurrentReadDuringExcessiveCompletion() async throws {
        let manager = ProgressManager(totalCount: 5)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for _ in 1...20 {
                    manager.complete(count: 1)
                    try? await Task.sleep(nanoseconds: 100_000)
                }
            }
            
            group.addTask {
                for _ in 1...100 {
                    let fraction = manager.fractionCompleted
                    let completed = manager.completedCount
                    
                    #expect(completed >= 0 && completed <= 20)
                    #expect(fraction >= 0.0 && fraction <= 4.0)
                }
            }
        }
        
        #expect(manager.completedCount == 20)
        #expect(manager.fractionCompleted == 4.0)
        #expect(manager.isFinished == true)
    }
    
    @Test func concurrentChildrenDeinitializationAndParentReads() async throws {
        let manager = ProgressManager(totalCount: 100)
        
        await withThrowingTaskGroup(of: Void.self) { group in
            // Create and destroy children rapidly
            for batch in 1...10 {
                group.addTask {
                    for i in 1...5 {
                        func createAndDestroyChild() {
                            let child = manager.subprogress(assigningCount: 2).start(totalCount: 3)
                            child.complete(count: 2 + (i % 2)) // Complete 2 or 3
                            // child deinits here
                        }
                        
                        createAndDestroyChild()
                        try? await Task.sleep(nanoseconds: 200_000 * UInt64(batch))
                    }
                }
            }
            
            // Continuously read manager state during child lifecycle
            group.addTask {
                for _ in 1...300 {
                    let fraction = manager.fractionCompleted
                    let completed = manager.completedCount
                    
                    // Properties should be stable and valid
                    #expect(fraction >= 0.0)
                    #expect(completed >= 0)
                    
                    try? await Task.sleep(nanoseconds: 50_000)
                }
            }
        }
        
        // Manager should reach completion
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.completedCount == 100)
    }
    
    @Test func concurrentReadAndWriteAndCycleDetection() async throws {
        let manager1 = ProgressManager(totalCount: 10)
        let manager2 = ProgressManager(totalCount: 10)
        let manager3 = ProgressManager(totalCount: 10)
        
        // Create initial chain: manager1 -> manager2 -> manager3
        manager1.assign(count: 5, to: manager2.reporter)
        manager2.assign(count: 5, to: manager3.reporter)
        
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Try to detect cycles continuously
            group.addTask {
                for _ in 1...50 {
                    let wouldCycle1 = manager1.isCycle(reporter: manager3.reporter)
                    let wouldCycle2 = manager2.isCycle(reporter: manager1.reporter)
                    let wouldCycle3 = manager3.isCycle(reporter: manager2.reporter)
                    
                    #expect(wouldCycle1 == false) // No cycle yet
                    #expect(wouldCycle2 == true) // Would create cycle
                    #expect(wouldCycle3 == true) // Would create cycle
                }
            }
            
            // Task 2: Complete work in all managers
            group.addTask {
                for _ in 1...5 {
                    manager1.complete(count: 1)
                    manager2.complete(count: 1)
                    manager3.complete(count: 1)
                }
            }
            
            // Task 3: Access properties during cycle detection
            group.addTask {
                for _ in 1...100 {
                    let _ = manager1.fractionCompleted
                    let _ = manager2.completedCount
                    let _ = manager3.isFinished
                }
            }
        }
    }
    
    @Test func concurrentSubprogressCreation() async throws {
        let manager = ProgressManager(totalCount: 1000)

        await withThrowingTaskGroup(of: Void.self) { group in
            // Create 20 concurrent tasks, each creating multiple subprogresses
            for _ in 1...20 {
                group.addTask {
                    for i in 1...10 {
                        let child = manager.subprogress(assigningCount: 5).start(totalCount: 4)
                        child.complete(count: 4)

                        // Immediately access properties
                        let _ = child.fractionCompleted
                        let _ = manager.fractionCompleted

                        try? await Task.sleep(nanoseconds: 100_000 * UInt64(i))
                    }
                }
            }
        }

        #expect(manager.completedCount == 1000)
    }
}
