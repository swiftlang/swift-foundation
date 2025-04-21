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

/// Unit tests for basic functionalities of ProgressReporter
class TestProgressReporter: XCTestCase {
    /// MARK: Helper methods that report progress
    func doBasicOperationV1(reportTo progress: consuming Subprogress) async {
        let reporter = progress.reporter(totalCount: 8)
        for i in 1...8 {
            reporter.complete(count: 1)
            XCTAssertEqual(reporter.completedCount, i)
            XCTAssertEqual(reporter.fractionCompleted, Double(i) / Double(8))
        }
    }
    
    func doBasicOperationV2(reportTo progress: consuming Subprogress) async {
        let reporter = progress.reporter(totalCount: 7)
        for i in 1...7 {
            reporter.complete(count: 1)
            XCTAssertEqual(reporter.completedCount, i)
            XCTAssertEqual(reporter.fractionCompleted,Double(i) / Double(7))
        }
    }
    
    func doBasicOperationV3(reportTo progress: consuming Subprogress) async {
        let reporter = progress.reporter(totalCount: 11)
        for i in 1...11 {
            reporter.complete(count: 1)
            XCTAssertEqual(reporter.completedCount, i)
            XCTAssertEqual(reporter.fractionCompleted, Double(i) / Double(11))
        }
    }
    
    func doFileOperation(reportTo progress: consuming Subprogress) async {
        let reporter = progress.reporter(totalCount: 100)
        reporter.withProperties { properties in
            properties.totalFileCount = 100
        }
        
        XCTAssertEqual(reporter.withProperties(\.totalFileCount), 100)
        XCTAssertNil(reporter.withProperties(\.completedFileCount))
        
        reporter.complete(count: 100)
        XCTAssertEqual(reporter.fractionCompleted, 1.0)
        XCTAssertTrue(reporter.isFinished)
        
        reporter.withProperties { properties in
            properties.completedFileCount = 100
        }
        XCTAssertEqual(reporter.withProperties(\.completedFileCount), 100)
        XCTAssertEqual(reporter.withProperties(\.totalFileCount), 100)
    }
    
    /// MARK: Tests calculations based on change in totalCount
    func testTotalCountNil() async throws {
        let overall = ProgressReporter(totalCount: nil)
        overall.complete(count: 10)
        XCTAssertEqual(overall.completedCount, 10)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertNil(overall.totalCount)
    }
    
    func testTotalCountReset() async throws {
        let overall = ProgressReporter(totalCount: 10)
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
        let overall = ProgressReporter(totalCount: nil)
        XCTAssertEqual(overall.completedCount, 0)
        XCTAssertNil(overall.totalCount)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertTrue(overall.isIndeterminate)
        XCTAssertFalse(overall.isFinished)
        
        let progress1 = overall.subprogress(assigningCount: 2)
        let reporter1 = progress1.reporter(totalCount: 1)
        
        reporter1.complete(count: 1)
        XCTAssertEqual(reporter1.totalCount, 1)
        XCTAssertEqual(reporter1.completedCount, 1)
        XCTAssertEqual(reporter1.fractionCompleted, 1.0)
        XCTAssertFalse(reporter1.isIndeterminate)
        XCTAssertTrue(reporter1.isFinished)
        
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
        let overall = ProgressReporter(totalCount: 10)
        overall.complete(count: 5)
        
        let progress1 = overall.subprogress(assigningCount: 8)
        let reporter1 = progress1.reporter(totalCount: 1)
        reporter1.complete(count: 1)
        
        XCTAssertEqual(overall.completedCount, 13)
        XCTAssertEqual(overall.totalCount, 10)
        XCTAssertEqual(overall.fractionCompleted, 1.3)
        XCTAssertFalse(overall.isIndeterminate)
        XCTAssertTrue(overall.isFinished)
    }
    
    /// MARK: Tests single-level tree
    func testDiscreteReporter() async throws {
        let reporter = ProgressReporter(totalCount: 3)
        await doBasicOperationV1(reportTo: reporter.subprogress(assigningCount: 3))
        XCTAssertEqual(reporter.fractionCompleted, 1.0)
        XCTAssertEqual(reporter.completedCount, 3)
        XCTAssertTrue(reporter.isFinished)
    }
    
    func testDiscreteReporterWithFileProperties() async throws {
        let fileReporter = ProgressReporter(totalCount: 3)
        await doFileOperation(reportTo: fileReporter.subprogress(assigningCount: 3))
        XCTAssertEqual(fileReporter.fractionCompleted, 1.0)
        XCTAssertEqual(fileReporter.completedCount, 3)
        XCTAssertTrue(fileReporter.isFinished)
    }
    
    /// MARK: Tests multiple-level trees
    func testEmptyDiscreteReporter() async throws {
        let reporter = ProgressReporter(totalCount: nil)
        XCTAssertTrue(reporter.isIndeterminate)
        
        reporter.withProperties { p in
            p.totalCount = 10
        }
        XCTAssertFalse(reporter.isIndeterminate)
        XCTAssertEqual(reporter.totalCount, 10)
        
        await doBasicOperationV1(reportTo: reporter.subprogress(assigningCount: 10))
        XCTAssertEqual(reporter.fractionCompleted, 1.0)
        XCTAssertEqual(reporter.completedCount, 10)
        XCTAssertTrue(reporter.isFinished)
    }
    
    func testTwoLevelTreeWithOneChildWithFileProperties() async throws {
        let overall = ProgressReporter(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let reporter1 = progress1.reporter(totalCount: 10)
        reporter1.withProperties { properties in
            properties.totalFileCount = 10
            properties.completedFileCount = 0
        }
        reporter1.complete(count: 10)
        
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        // This should call reduce and get 10
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 10)
    }
    
    func testTwoLevelTreeWithTwoChildrenWithFileProperties() async throws {
        let overall = ProgressReporter(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let reporter1 = progress1.reporter(totalCount: 10)
        
        reporter1.withProperties { properties in
            properties.totalFileCount = 11
            properties.completedFileCount = 0
        }
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let reporter2 = progress2.reporter(totalCount: 10)
        
        reporter2.withProperties { properties in
            properties.totalFileCount = 9
            properties.completedFileCount = 0
        }
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 20)
        
        // Update FileCounts
        reporter1.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        reporter2.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        XCTAssertEqual(overall.withProperties(\.completedFileCount), 2)
    }
    
    func testThreeLevelTreeWithFileProperties() async throws {
        let overall = ProgressReporter(totalCount: 1)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let reporter1 = progress1.reporter(totalCount: 5)
        
        let childProgress1 = reporter1.subprogress(assigningCount: 3)
        let childReporter1 = childProgress1.reporter(totalCount: nil)
        childReporter1.withProperties { properties in
            properties.totalFileCount = 10
        }
        
        let childProgress2 = reporter1.subprogress(assigningCount: 2)
        let childReporter2 = childProgress2.reporter(totalCount: nil)
        childReporter2.withProperties { properties in
            properties.totalFileCount = 10
        }
        
        XCTAssertEqual(reporter1.withProperties(\.totalFileCount), 20)
        
        // Tests that totalFileCount propagates to root level
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 20)
    }
    
    func testTwoLevelTreeWithTwoChildren() async throws {
        let overall = ProgressReporter(totalCount: 2)
        
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
        let overall = ProgressReporter(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let reporter1 = progress1.reporter(totalCount: 5)
        reporter1.complete(count: 5)
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let reporter2 = progress2.reporter(totalCount: 5)
        reporter2.withProperties { properties in
            properties.totalFileCount = 10
        }
 
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        // Parent is expected to get totalFileCount from one of the children with a totalFileCount
        XCTAssertEqual(overall.withProperties(\.totalFileCount), 10)
    }
    
    func testTwoLevelTreeWithMultipleChildren() async throws {
        let overall = ProgressReporter(totalCount: 3)
        
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
        let overall = ProgressReporter(totalCount: 100)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let reporter1 = child1.reporter(totalCount: 100)
        
        let grandchild1 = reporter1.subprogress(assigningCount: 100)
        let grandchildReporter1 = grandchild1.reporter(totalCount: 100)
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        grandchildReporter1.complete(count: 50)
        XCTAssertEqual(reporter1.fractionCompleted, 0.5)
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        
        grandchildReporter1.complete(count: 50)
        XCTAssertEqual(reporter1.fractionCompleted, 1.0)
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        
        XCTAssertTrue(grandchildReporter1.isFinished)
        XCTAssertTrue(reporter1.isFinished)
        XCTAssertTrue(overall.isFinished)
    }
    
    func testFourLevelTree() async throws {
        let overall = ProgressReporter(totalCount: 100)
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        let child1 = overall.subprogress(assigningCount: 100)
        let reporter1 = child1.reporter(totalCount: 100)
        
        let grandchild1 = reporter1.subprogress(assigningCount: 100)
        let grandchildReporter1 = grandchild1.reporter(totalCount: 100)
        
        XCTAssertEqual(overall.fractionCompleted, 0.0)
        
        
        let greatGrandchild1 = grandchildReporter1.subprogress(assigningCount: 100)
        let greatGrandchildReporter1 = greatGrandchild1.reporter(totalCount: 100)
        
        greatGrandchildReporter1.complete(count: 50)
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        
        greatGrandchildReporter1.complete(count: 50)
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        
        XCTAssertTrue(greatGrandchildReporter1.isFinished)
        XCTAssertTrue(grandchildReporter1.isFinished)
        XCTAssertTrue(reporter1.isFinished)
        XCTAssertTrue(overall.isFinished)
    }
}


/// Unit tests for interop methods that support building Progress trees with both Progress and ProgressReporter
class TestProgressReporterInterop: XCTestCase {
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
    
    func doSomethingWithReporter(progress: consuming Subprogress?) async {
        let reporter = progress?.reporter(totalCount: 4)
        reporter?.complete(count: 2)
        reporter?.complete(count: 2)
    }
    
    func testInteropProgressParentProgressReporterChild() async throws {
        // Initialize a Progress Parent
        let overall = Progress.discreteProgress(totalUnitCount: 10)
        
        // Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p1 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overall.addChild(p1, withPendingUnitCount: 5)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)
        
        // Check if ProgressReporter values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 0.5)
        XCTAssertEqual(overall.completedUnitCount, 5)
        
        // Add ProgressReporter as Child
        let p2 = overall.makeChild(withPendingUnitCount: 5)
        await doSomethingWithReporter(progress: p2)
        
        // Check if Progress values propagate to Progress parent
        XCTAssertEqual(overall.fractionCompleted, 1.0)
        XCTAssertEqual(overall.completedUnitCount, 10)
    }
    
    func testInteropProgressReporterParentProgressChild() async throws {
        // Initialize ProgressReporter parent
        let overallReporter = ProgressReporter(totalCount: 10)
        
        // Add ProgressReporter as Child
        await doSomethingWithReporter(progress: overallReporter.subprogress(assigningCount: 5))
        
        // Check if ProgressReporter values propagate to ProgressReporter parent
        XCTAssertEqual(overallReporter.fractionCompleted, 0.5)
        XCTAssertEqual(overallReporter.completedCount, 5)
        
        // Interop: Add Progress as Child
        let expectation1 = XCTestExpectation(description: "Set completed unit count to 1")
        let expectation2 = XCTestExpectation(description: "Set completed unit count to 2")
        let p2 = await doSomethingWithProgress(expectation1: expectation1, expectation2: expectation2)
        overallReporter.subprogress(assigningCount: 5, to: p2)
        
        await fulfillment(of: [expectation1, expectation2], timeout: 10.0)
        
        // Check if Progress values propagate to ProgressRerpoter parent
        XCTAssertEqual(overallReporter.completedCount, 10)
        XCTAssertEqual(overallReporter.totalCount, 10)
        XCTAssertEqual(overallReporter.fractionCompleted, 1.0)
    }
    
    func getProgressWithTotalCountInitialized() -> Progress {
        return Progress(totalUnitCount: 5)
    }
    
    func receiveProgress(progress: consuming Subprogress) {
        let _ = progress.reporter(totalCount: 5)
    }
    
    func testInteropProgressReporterParentProgressChildConsistency() async throws {
        let overallReporter = ProgressReporter(totalCount: nil)
        let child = overallReporter.subprogress(assigningCount: 5)
        receiveProgress(progress: child)
        XCTAssertNil(overallReporter.totalCount)
        
        let overallReporter2 = ProgressReporter(totalCount: nil)
        let interopChild = getProgressWithTotalCountInitialized()
        overallReporter2.subprogress(assigningCount: 5, to: interopChild)
        XCTAssertNil(overallReporter2.totalCount)
    }
    
    func testInteropProgressParentProgressReporterChildConsistency() async throws {
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

