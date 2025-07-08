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
    
    @Test func childTotalCountReset() async throws {
        let overall = ProgressManager(totalCount: 1)
        
        let childManager = overall.subprogress(assigningCount: 1).start(totalCount: 4)
        childManager.complete(count: 2)
        
        #expect(overall.fractionCompleted == 0.5)
        #expect(childManager.isIndeterminate == false)
        
        childManager.withProperties { properties in
            properties.totalCount = nil
        }
        
        #expect(overall.fractionCompleted == 0.0)
        #expect(childManager.isIndeterminate == true)
        #expect(childManager.completedCount == 2)
        
        childManager.withProperties { properties in
            properties.totalCount = 5
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
