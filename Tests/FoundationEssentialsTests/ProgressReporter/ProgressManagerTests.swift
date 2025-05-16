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
import XCTest

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
#endif // FOUNDATION_FRAMEWORK

/// Unit tests for basic functionalities of ProgressManager
class TestProgressManager: XCTestCase {
    /// MARK: Helper methods that report progress
    func doBasicOperationV1(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.manager(totalCount: 8)
        for i in 1...8 {
            manager.complete(count: 1)
            XCTAssertEqual(manager.completedCount, i)
            XCTAssertEqual(manager.fractionCompleted, Double(i) / Double(8))
        }
    }
    
    func doBasicOperationV2(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.manager(totalCount: 7)
        for i in 1...7 {
            manager.complete(count: 1)
            XCTAssertEqual(manager.completedCount, i)
            XCTAssertEqual(manager.fractionCompleted,Double(i) / Double(7))
        }
    }
    
    func doBasicOperationV3(reportTo subprogress: consuming Subprogress) async {
        let manager =  subprogress.manager(totalCount: 11)
        for i in 1...11 {
            manager.complete(count: 1)
            XCTAssertEqual(manager.completedCount, i)
            XCTAssertEqual(manager.fractionCompleted, Double(i) / Double(11))
        }
    }
    
    /// MARK: Tests calculations based on change in totalCount
    func testTotalCountNil() async throws {
        let overall = ProgressManager(totalCount: nil)
        overall.complete(count: 10)
        XCTAssertEqual(overall.completedCount, 10)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertNil(overall.totalCount)
    }
    
    func testTotalCountReset() async throws {
        let overall = ProgressManager(totalCount: 10)
        overall.complete(count: 5)
        XCTAssertEqual(overall.completedCount, 5)
        XCTAssertEqual(overall.totalCount, 10)
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertFalse(overall.isIndeterminate)

        overall.withProperties { p in
            p.totalCount = nil
            p.completedCount += 1
        }
        XCTAssertEqual(overall.completedCount, 6)
        XCTAssertNil(overall.totalCount)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
        
        overall.withProperties { p in
            p.totalCount = 12
            p.completedCount += 2
        }
        XCTAssertEqual(overall.completedCount, 8)
        XCTAssertEqual(overall.totalCount, 12)
        XCTAssertEqual(overall.fractionCompleted, Double(8) / Double(12))
        XCTAssertFalse(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
    }
    
    func testTotalCountNilWithChild() async throws {
        let overall = ProgressManager(totalCount: nil)
        XCTAssertEqual(overall.completedCount, 0)
        XCTAssertNil(overall.totalCount)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
        
        let progress1 = overall.subprogress(assigningCount: 2)
        let manager1 = progress1.manager(totalCount: 1)
        
        manager1.complete(count: 1)
        XCTAssertEqual(manager1.totalCount, 1)
        XCTAssertEqual(manager1.completedCount, 1)
        XCTAssertEqual(manager1.fractionCompleted, 1.0)
        XCTAssertFalse(manager1.isIndeterminate)
        XCTAssertTrue(manager1.isFinished)
        
        XCTAssertEqual(overall.completedCount, 2)
        XCTAssertEqual(overall.totalCount, nil)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
        
        overall.withProperties { p in
            p.totalCount = 5
        }
        XCTAssertEqual(overall.completedCount, 2)
        XCTAssertEqual(overall.totalCount, 5)
        XCTAssertEqual(overall.fractionCompleted, 0.4)
        XCTAssertFalse(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
    }
    
    func testTotalCountFinishesWithLessCompletedCount() async throws {
        let overall = ProgressManager(totalCount: 10)
        overall.complete(count: 5)
        
        let progress1 = overall.subprogress(assigningCount: 8)
        let manager1 = progress1.manager(totalCount: 1)
        manager1.complete(count: 1)
        
        XCTAssertEqual(overall.completedCount, 13)
        XCTAssertEqual(overall.totalCount, 10)
        XCTAssertEqual(overall.fractionCompleted, 1.3)
        XCTAssertFalse(overall.isIndeterminate)
        XCTAssertTrue(overall.isFinished)
    }
    
    /// MARK: Tests single-level tree
    func testDiscreteReporter() async throws {
        let manager =  ProgressManager(totalCount: 3)
        await doBasicOperationV1(reportTo: manager.subprogress(assigningCount: 3))
        XCTAssertEqual(manager.fractionCompleted, 1.0)
        XCTAssertEqual(manager.completedCount, 3)
        XCTAssertTrue(manager.isFinished)
    }
    
    /// MARK: Tests multiple-level trees
    func testEmptyDiscreteReporter() async throws {
        let manager =  ProgressManager(totalCount: nil)
        XCTAssertTrue(manager.isIndeterminate)
        
        manager.withProperties { p in
            p.totalCount = 10
        }
        XCTAssertFalse(manager.isIndeterminate)
        XCTAssertEqual(manager.totalCount, 10)
        
        await doBasicOperationV1(reportTo: manager.subprogress(assigningCount: 10))
        XCTAssertEqual(manager.fractionCompleted, 1.0)
        XCTAssertEqual(manager.completedCount, 10)
        XCTAssertTrue(manager.isFinished)
    }
    
    func testTwoLevelTreeWithTwoChildren() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        await doBasicOperationV1(reportTo: overall.subprogress(assigningCount: 1))
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertEqual(overall.completedCount, 1)
        XCTAssertFalse(overall.isFinished)
        XCTAssertFalse(overall.isIndeterminate)
        
        await doBasicOperationV2(reportTo: overall.subprogress(assigningCount: 1))
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        XCTAssertEqual(overall.completedCount, 2)
        XCTAssertTrue(overall.isFinished)
        XCTAssertFalse(overall.isIndeterminate)
    }
    
    func testTwoLevelTreeWithTwoChildrenWithOneFileProperty() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.manager(totalCount: 5)
        manager1.complete(count: 5)
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let manager2 = progress2.manager(totalCount: 5)
        manager2.withProperties { properties in
            properties.totalFileCount = 10
        }
 
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        // Parent is expected to get totalFileCount from one of the children with a totalFileCount
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 0)
    }
    
    func testTwoLevelTreeWithMultipleChildren() async throws {
        let overall = ProgressManager(totalCount: 3)
        
        await doBasicOperationV1(reportTo: overall.subprogress(assigningCount:1))
        XCTAssertEqual(overall.fractionCompleted, Double(1) / Double(3))
        XCTAssertEqual(overall.completedCount, 1)
        
        await doBasicOperationV2(reportTo: overall.subprogress(assigningCount:1))
        XCTAssertEqual(overall.fractionCompleted, Double(2) / Double(3))
        XCTAssertEqual(overall.completedCount, 2)
        
        await doBasicOperationV3(reportTo: overall.subprogress(assigningCount:1))
        XCTAssertEqual(overall.fractionCompleted, Double(3) / Double(3))
        XCTAssertEqual(overall.completedCount, 3)
    }
    
    func testThreeLevelTree() async throws {
        let overall = ProgressManager(totalCount: 100)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let manager1 = child1.manager(totalCount: 100)
        
        let grandchild1 = manager1.subprogress(assigningCount: 100)
        let grandchildManager1 = grandchild1.manager(totalCount: 100)
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        grandchildManager1.complete(count: 50)
        XCTAssertEqual(manager1.fractionCompleted, 0.5)
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        
        grandchildManager1.complete(count: 50)
        XCTAssertEqual(manager1.fractionCompleted, 1.0)
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        
        XCTAssertTrue(grandchildManager1.isFinished)
        XCTAssertTrue(manager1.isFinished)
        XCTAssertTrue(overall.isFinished)
    }
    
    func testFourLevelTree() async throws {
        let overall = ProgressManager(totalCount: 100)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let manager1 = child1.manager(totalCount: 100)
        
        let grandchild1 = manager1.subprogress(assigningCount: 100)
        let grandchildManager1 = grandchild1.manager(totalCount: 100)
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        
        let greatGrandchild1 = grandchildManager1.subprogress(assigningCount: 100)
        let greatGrandchildManager1 = greatGrandchild1.manager(totalCount: 100)
        
        greatGrandchildManager1.complete(count: 50)
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        
        greatGrandchildManager1.complete(count: 50)
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        
        XCTAssertTrue(greatGrandchildManager1.isFinished)
        XCTAssertTrue(grandchildManager1.isFinished)
        XCTAssertTrue(manager1.isFinished)
        XCTAssertTrue(overall.isFinished)
    }
}

/// Unit tests for propagation of type-safe metadata in ProgressManager tree.
class TestProgressManagerAdditionalProperties: XCTestCase {
    func doFileOperation(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.manager(totalCount: 100)
        manager.withProperties { properties in
            properties.totalFileCount = 100
        }
        
        XCTAssertEqual(manager.withProperties(\.totalFileCount), 100)
        
        manager.complete(count: 100)
        XCTAssertEqual(manager.fractionCompleted, 1.0)
        XCTAssertTrue(manager.isFinished)
        
        manager.withProperties { properties in
            properties.completedFileCount = 100
        }
        XCTAssertEqual(manager.withProperties(\.completedFileCount), 100)
        XCTAssertEqual(manager.withProperties(\.totalFileCount), 100)
    }
    
    func testDiscreteReporterWithFileProperties() async throws {
        let fileProgressManager = ProgressManager(totalCount: 3)
        await doFileOperation(reportTo: fileProgressManager.subprogress(assigningCount: 3))
        XCTAssertEqual(fileProgressManager.fractionCompleted, 1.0)
        XCTAssertEqual(fileProgressManager.completedCount, 3)
        XCTAssertTrue(fileProgressManager.isFinished)
        XCTAssertEqual(fileProgressManager.withProperties(\.totalFileCount), 0)
        XCTAssertEqual(fileProgressManager.withProperties(\.completedFileCount), 0)

        let totalFileValues = fileProgressManager.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(totalFileValues, [0, 100])
        
        let reducedTotalFileValue = fileProgressManager.total(property: ProgressManager.Properties.TotalFileCount.self, values: totalFileValues)
        XCTAssertEqual(reducedTotalFileValue, 100)
        
        let completedFileValues = fileProgressManager.values(property: ProgressManager.Properties.CompletedFileCount.self)
        XCTAssertEqual(completedFileValues, [0, 100])
        
        let reducedCompletedFileValue = fileProgressManager.total(property: ProgressManager.Properties.CompletedFileCount.self, values: completedFileValues)
        XCTAssertEqual(reducedCompletedFileValue, 100)
    }
    
    func testTwoLevelTreeWithOneChildWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.manager(totalCount: 10)
        manager1.withProperties { properties in
            properties.totalFileCount = 10
            properties.completedFileCount = 0
        }
        manager1.complete(count: 10)
        
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 0)
        XCTAssertEqual(manager1.withProperties(\.totalFileCount), 10)
        XCTAssertEqual(manager1.withProperties(\.completedFileCount), 0)
        
        let totalFileValues = overall.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(totalFileValues, [0, 10])
        
        let completedFileValues = overall.values(property: ProgressManager.Properties.CompletedFileCount.self)
        XCTAssertEqual(completedFileValues, [0, 0])
    }
    
    func testTwoLevelTreeWithTwoChildrenWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.manager(totalCount: 10)
        
        manager1.withProperties { properties in
            properties.totalFileCount = 11
            properties.completedFileCount = 0
        }
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let manager2 = progress2.manager(totalCount: 10)
        
        manager2.withProperties { properties in
            properties.totalFileCount = 9
            properties.completedFileCount = 0
        }
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 0)
        XCTAssertEqual(overall.withProperties(\.completedFileCount), 0)
        let totalFileValues = overall.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(totalFileValues, [0, 11, 9])
        let completedFileValues = overall.values(property: ProgressManager.Properties.CompletedFileCount.self)
        XCTAssertEqual(completedFileValues, [0, 0, 0])
        
        // Update FileCounts
        manager1.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        manager2.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        XCTAssertEqual(overall.withProperties(\.completedFileCount), 0)
        let updatedCompletedFileValues = overall.values(property: ProgressManager.Properties.CompletedFileCount.self)
        XCTAssertEqual(updatedCompletedFileValues, [0, 1, 1])
    }
    
    func testThreeLevelTreeWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 1)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.manager(totalCount: 5)
        
        
        let childProgress1 = manager1.subprogress(assigningCount: 3)
        let childManager1 = childProgress1.manager(totalCount: nil)
        childManager1.withProperties { properties in
            properties.totalFileCount += 10
        }
        XCTAssertEqual(childManager1.withProperties(\.totalFileCount), 10)
        
        let preTotalFileValues = overall.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(preTotalFileValues, [0, 0, 10])
        
        let childProgress2 = manager1.subprogress(assigningCount: 2)
        let childManager2 = childProgress2.manager(totalCount: nil)
        childManager2.withProperties { properties in
            properties.totalFileCount += 10
        }
        XCTAssertEqual(childManager2.withProperties(\.totalFileCount), 10)

        // Tests that totalFileCount propagates to root level
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 0)
        let totalFileValues = overall.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(totalFileValues, [0, 0, 10, 10])
        
        manager1.withProperties { properties in
            properties.totalFileCount += 999
        }
        let totalUpdatedFileValues = overall.values(property: ProgressManager.Properties.TotalFileCount.self)
        XCTAssertEqual(totalUpdatedFileValues, [0, 999, 10, 10])
    }
}

#if FOUNDATION_FRAMEWORK
/// Unit tests for interop methods that support building Progress trees with both Progress and ProgressManager
class TestProgressManagerInterop: XCTestCase {
    func doSomethingWithProgress(expectation1: XCTestExpectation, expectation2: XCTestExpectation) async -> Progress {
        let p = Progress(totalUnitCount: 2)
        Task.detached {
            p.completedUnitCount = 1
            expectation1.fulfill()
            p.completedUnitCount = 2
            expectation2.fulfill()
        }
        return p
    }
    
    func doSomethingWithReporter(subprogress: consuming Subprogress?) async {
        let manager =  subprogress?.manager(totalCount: 4)
        manager?.complete(count: 2)
        manager?.complete(count: 2)
    }
    
    func testInteropProgressParentProgressManagerChild() async throws {
        // Initialize a Progress Parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p1 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overall.addChild(p1, withPendingUnitCount: 5)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)
        
        // Check if ProgressManager values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertEqual(overall.completedUnitCount, 5)
        
        // Add ProgressManager as Child
        let p2 = overall.makeChild(withPendingUnitCount: 5)
        await doSomethingWithReporter(subprogress: p2)
        
        // Check if Progress values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        XCTAssertEqual(overall.completedUnitCount, 10)
    }
    
    func testInteropProgressParentProgressMonitorChildWithEmptyProgress() async throws {
        // Initialize a Progress parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p1 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overall.addChild(p1, withPendingUnitCount: 5)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)

        // Check if ProgressManager values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertEqual(overall.completedUnitCount, 5)
        
        // Add ProgressMonitor as Child
        let p2 = ProgressManager(totalCount: 10)
        let p2Reporter = p2.reporter
        overall.addChild(p2Reporter, withPendingUnitCount: 5)
        
        p2.complete(count: 10)
        
        // Check if Progress values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        XCTAssertEqual(overall.completedUnitCount, 10)
    }
    
    func testInteropProgressParentProgressMonitorChildWithExistingProgress() async throws {
        // Initialize a Progress parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p1 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overall.addChild(p1, withPendingUnitCount: 5)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)

        // Check if ProgressManager values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertEqual(overall.completedUnitCount, 5)
        
        // Add ProgressMonitor with CompletedCount 3 as Child
        let p2 = ProgressManager(totalCount: 10)
        p2.complete(count: 3)
        let p2Reporter = p2.reporter
        overall.addChild(p2Reporter, withPendingUnitCount: 5)
        
        p2.complete(count: 7)
        
        // Check if Progress values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        XCTAssertEqual(overall.completedUnitCount, 10)
    }
    
    func testInteropProgressManagerParentProgressChild() async throws {
        // Initialize ProgressManager parent
        let overallManager = ProgressManager(totalCount: 10)
        
        // Add ProgressManager as Child
        await doSomethingWithReporter(subprogress: overallManager.subprogress(assigningCount: 5))
        
        // Check if ProgressManager values propagate to ProgressManager parent
        XCTAssertEqual(overallManager.fractionCompleted, 0.5)
        XCTAssertEqual(overallManager.completedCount, 5)
        
        // Interop: Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p2 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overallManager.subprogress(assigningCount: 5, to: p2)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)
        
        // Check if Progress values propagate to ProgressRerpoter parent
        XCTAssertEqual(overallManager.completedCount, 10)
        XCTAssertEqual(overallManager.totalCount, 10)
        //TODO: Somehow this sometimes gets updated to 1.25 instead of just 1.0
        XCTAssertEqual(overallManager.fractionCompleted, 1.0)
    }
    
    func getProgressWithTotalCountInitialized() -> Progress {
        return Progress(totalUnitCount: 5)
    }
    
    func receiveProgress(progress: consuming Subprogress) {
        let _ = progress.manager(totalCount: 5)
    }
    
    func testInteropProgressManagerParentProgressChildConsistency() async throws {
        let overallReporter = ProgressManager(totalCount: nil)
        let child = overallReporter.subprogress(assigningCount: 5)
        receiveProgress(progress: child)
        XCTAssertNil(overallReporter.totalCount)
        
        let overallReporter2 = ProgressManager(totalCount: nil)
        let interopChild = getProgressWithTotalCountInitialized()
        overallReporter2.subprogress(assigningCount: 5, to: interopChild)
        XCTAssertNil(overallReporter2.totalCount)
    }
    
    func testInteropProgressParentProgressManagerChildConsistency() async throws {
        let overallProgress = Progress()
        let child = Progress(totalUnitCount: 5)
        overallProgress.addChild(child, withPendingUnitCount: 5)
        XCTAssertEqual(overallProgress.totalUnitCount, 0)
        
        let overallProgress2 = Progress()
        let interopChild = overallProgress2.makeChild(withPendingUnitCount: 5)
        receiveProgress(progress: interopChild)
        XCTAssertEqual(overallProgress2.totalUnitCount, 0)
    }
}
#endif
