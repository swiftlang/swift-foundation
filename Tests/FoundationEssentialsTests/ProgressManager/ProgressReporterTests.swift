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

@Suite("Progress Reporter", .tags(.progressManager)) struct ProgressReporterTests {
    @Test func observeProgressReporter() {
        let manager = ProgressManager(totalCount: 3)
        
        let reporter = manager.reporter
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 1)
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 2)
        
        manager.complete(count: 1)
        #expect(reporter.completedCount == 3)
        
        let fileCount = reporter.totalFileCount
        #expect(fileCount == 0)
        
        manager.totalFileCount = 6
        #expect(reporter.totalFileCount == 6)
        
        let summaryTotalFile = manager.summary(of: \.totalFileCount)
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
        
        overall.setCounts { _, total in
            total = 30
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
        
        overall.setCounts { _, total in
            total = 30
        }
        
        #expect(overall.totalCount == 30)
        #expect(overall.fractionCompleted == 0.5)
    }
    
    func dummy(index: Int, subprogress: consuming Subprogress) async -> ProgressReporter {
        let manager = subprogress.start(totalCount: index * 10)
        
        manager.complete(count: (index * 10) / 2)
        
        return manager.reporter
    }
    
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
