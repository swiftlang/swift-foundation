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
@Suite("Progress Manager File Properties", .tags(.progressManager)) struct ProgressManagerAdditionalPropertiesTests {
    func doFileOperation(reportTo subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 100)
        manager.withProperties { properties in
            properties.totalFileCount = 100
        }
        
        #expect(manager.withProperties(\.totalFileCount) == 100)
        
        manager.complete(count: 100)
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.isFinished == true)
        
        manager.withProperties { properties in
            properties.completedFileCount = 100
        }
        #expect(manager.withProperties(\.completedFileCount) == 100)
        #expect(manager.withProperties(\.totalFileCount) == 100)
    }
    
    @Test func discreteReporterWithFileProperties() async throws {
        let fileProgressManager = ProgressManager(totalCount: 3)
        await doFileOperation(reportTo: fileProgressManager.subprogress(assigningCount: 3))
        #expect(fileProgressManager.fractionCompleted == 1.0)
        #expect(fileProgressManager.completedCount == 3)
        #expect(fileProgressManager.isFinished == true)
        #expect(fileProgressManager.withProperties(\.totalFileCount) == 0)
        #expect(fileProgressManager.withProperties(\.completedFileCount) == 0)
        
        let summaryTotalFile = fileProgressManager.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 100)
        
        let summaryCompletedFile = fileProgressManager.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 100)
    }
    
    @Test func twoLevelTreeWithOneChildWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 10)
        manager1.withProperties { properties in
            properties.totalFileCount = 10
            properties.completedFileCount = 0
        }
        manager1.complete(count: 10)
        
        #expect(overall.fractionCompleted == 0.5)
        
        #expect(overall.withProperties(\.totalFileCount) == 0)
        #expect(manager1.withProperties(\.totalFileCount) == 10)
        #expect(manager1.withProperties(\.completedFileCount) == 0)
        
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 10)
        
        let summaryCompletedFile = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 0)
    }
    
    @Test func twoLevelTreeWithTwoChildrenWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 10)
        
        manager1.withProperties { properties in
            properties.totalFileCount = 11
            properties.completedFileCount = 0
        }
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let manager2 = progress2.start(totalCount: 10)
        
        manager2.withProperties { properties in
            properties.totalFileCount = 9
            properties.completedFileCount = 0
        }
        
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.withProperties(\.totalFileCount) == 0)
        #expect(overall.withProperties(\.completedFileCount) == 0)
        
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 20)
        
        let summaryCompletedFile = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 0)
        
        // Update FileCounts
        manager1.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        manager2.withProperties { properties in
            properties.completedFileCount = 1
        }
        
        #expect(overall.withProperties(\.completedFileCount) == 0)
        let summaryCompletedFileUpdated = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFileUpdated == 2)
    }
    
    @Test func threeLevelTreeWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 1)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 5)
        
        
        let childProgress1 = manager1.subprogress(assigningCount: 3)
        let childManager1 = childProgress1.start(totalCount: nil)
        childManager1.withProperties { properties in
            properties.totalFileCount += 10
        }
        #expect(childManager1.withProperties(\.totalFileCount) == 10)
        
        let summaryTotalFileInitial = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFileInitial == 10)
        
        let childProgress2 = manager1.subprogress(assigningCount: 2)
        let childManager2 = childProgress2.start(totalCount: nil)
        childManager2.withProperties { properties in
            properties.totalFileCount += 10
        }
        #expect(childManager2.withProperties(\.totalFileCount) == 10)

        // Tests that totalFileCount propagates to root level
        #expect(overall.withProperties(\.totalFileCount) == 0)
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 20)
        
        manager1.withProperties { properties in
            properties.totalFileCount += 999
        }
        let summaryTotalFileUpdated = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFileUpdated == 1019)
    }
}

@Suite("Progress Manager Byte Properties", .tags(.progressManager)) struct ProgressManagerBytePropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 3)
        manager.withProperties { properties in
            properties.totalByteCount = 300000
            
            properties.completedCount += 1
            properties.completedByteCount += 100000
            
            properties.completedCount += 1
            properties.completedByteCount += 100000
            
            properties.completedCount += 1
            properties.completedByteCount += 100000
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 300000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 300000)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.totalByteCount = 200000
            properties.completedByteCount = 200000
        }
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 500000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 500000)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.totalByteCount = 2000
            properties.completedByteCount = 1000
        }
        
        #expect(manager.fractionCompleted == 0.5)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 2000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 1000)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.totalByteCount = 500000
            properties.completedByteCount = 499999
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 800000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 799999)
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.totalByteCount = 100000
            properties.completedByteCount = 99999
        }
        
        try await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 600000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 599999)
    }
}

@Suite("Progress Manager Throughput Properties", .tags(.progressManager)) struct ProgressManagerThroughputTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.throughput += 1000
            
            properties.completedCount += 1
            properties.throughput += 1000
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [2000])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.throughput = 1000
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 2000])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.throughput = 1000
            properties.throughput += 2000
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [3000])
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        manager.complete(count: 1)
        manager.withProperties { properties in
            properties.throughput = 1000
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 2000])
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        manager.complete(count: 1)
        
        manager.withProperties { properties in
            properties.throughput = 1000
        }
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 1000, 2000])
    }
}

@Suite("Progress Manager Estimated Time Remaining Properties", .tags(.progressManager)) struct ProgressManagerEstimatedTimeRemainingTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.estimatedTimeRemaining = Duration.seconds(3000)
            
            properties.completedCount += 1
            properties.estimatedTimeRemaining += Duration.seconds(3000)
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(6000))
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.estimatedTimeRemaining = Duration.seconds(1000)
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(1000))
    }
    
    @Test func twoLevelManagerWithFinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.estimatedTimeRemaining = Duration.seconds(1)
        }
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(1))
    }
    
    @Test func twoLevelManagerWithUnfinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.estimatedTimeRemaining = Duration.seconds(200)
        }
        
        let child = manager.subprogress(assigningCount: 1).start(totalCount: 2)
        child.withProperties { properties in
            properties.completedCount = 1
            properties.estimatedTimeRemaining = Duration.seconds(80000)
        }
        
        #expect(manager.fractionCompleted == 0.75)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(80000))
    }
    
}
    
@Suite("Progress Manager File URL Properties", .tags(.progressManager)) struct ProgressManagerFileURLTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.fileURL = URL(string: "https://www.kittens.com")
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileURL.self) == [URL(string: "https://www.kittens.com")])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.fileURL = URL(string: "https://www.cats.com")
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileURL.self) == [URL(string: "https://www.cats.com")])
    }
    
    @Test func twoLevelManagerWithFinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.fileURL = URL(string: "https://www.cats.com")
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileURL.self) == [URL(string: "https://www.cats.com")])
    }
    
    @Test func twoLevelManagerWithUnfinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.fileURL = URL(string: "https://www.cats.com")
        }
        
        var childManager: ProgressManager? = manager.subprogress(assigningCount: 1).start(totalCount: 2)
        
        childManager?.withProperties { properties in
            properties.completedCount = 1
            properties.fileURL = URL(string: "https://www.kittens.com")
        }
        
        #expect(manager.fractionCompleted == 0.75)
        #expect(manager.summary(of: ProgressManager.Properties.FileURL.self) == [URL(string: "https://www.cats.com"), URL(string: "https://www.kittens.com")])
                
        childManager = nil
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileURL.self) == [URL(string: "https://www.cats.com")])
    }
}

extension ProgressManager.Properties {

    var counter: Counter.Type { Counter.self }
    struct Counter: Sendable, ProgressManager.Property {
        
        typealias Value = Int
        
        typealias Summary = Int
        
        static var key: String { return "Counter" }
        
        static var defaultValue: Int { return 0 }
        
        static var defaultSummary: Int { return 0 }
        
        static func reduce(into summary: inout Int, value: Int) {
            summary += value
        }
        
        static func merge(_ summary1: Int, _ summary2: Int) -> Int {
            return summary1 + summary2
        }
        
        static func terminate(_ parentSummary: Int, _ childSummary: Int) -> Int {
            return parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager Int Properties", .tags(.progressManager)) struct ProgressManagerIntPropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.counter += 10
            
            properties.completedCount += 1
            properties.counter += 10
            
            properties.completedCount += 1
            properties.counter += 10
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 30)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        
        manager.withProperties { properties in
            properties.counter = 15
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 45)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.counter += 10
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 10)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.counter += 10
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 40)
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.counter += 10
        }
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 55)
    }
}

extension ProgressManager.Properties {
    
    var justADouble: JustADouble.Type { JustADouble.self }
    struct JustADouble: Sendable, ProgressManager.Property {
        
        typealias Value = Double
        
        typealias Summary = Double
        
        static var key: String { return "JustADouble" }

        static var defaultValue: Double { return 0.0 }
        
        static var defaultSummary: Double { return 0.0 }
        
        static func reduce(into summary: inout Double, value: Double) {
            summary += value
        }
        
        static func merge(_ summary1: Double, _ summary2: Double) -> Double {
            return summary1 + summary2
        }
        
        static func terminate(_ parentSummary: Double, _ childSummary: Double) -> Double {
            return parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager Double Properties", .tags(.progressManager)) struct ProgressManagerDoublePropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 3)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.justADouble += 10.0
            
            properties.completedCount += 1
            properties.justADouble += 10.0
            
            properties.completedCount += 1
            properties.justADouble += 10.0
        }
        
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 30.0)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.justADouble = 7.0
        }
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 37.0)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.justADouble = 80.0
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 80.0)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.justADouble = 80.0
        }
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 110.0)
    }
    
    @Test func threeLevelManager() async throws {
        
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.justADouble = 80.0
        }
        
        try await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 117.0)
    }
}

extension ProgressManager.Properties {
    
    var fileName: FileName.Type { FileName.self }
    struct FileName: Sendable, ProgressManager.Property {
        
        typealias Value = String?
        
        typealias Summary = [String?]
        
        static var key: String { return "FileName" }
        
        static var defaultValue: String? { return "" }
        
        static var defaultSummary: [String?] { return [] }
        
        static func reduce(into summary: inout [String?], value: String?) {
            summary.append(value)
        }
        
        static func merge(_ summary1: [String?], _ summary2: [String?]) -> [String?] {
            return summary1 + summary2
        }
        
        static func terminate(_ parentSummary: [String?], _ childSummary: [String?]) -> [String?] {
            return parentSummary + childSummary
        }
    }
}


@Suite("Progress Manager String Properties", .tags(.progressManager)) struct ProgressManagerStringPropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.fileName = "Melon.jpg"
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileName.self) == ["Melon.jpg"])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.fileName = "Cherry.jpg"
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileName.self) == ["Cherry.jpg", "Melon.jpg"])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.withProperties { properties in
            properties.completedCount += 1
            properties.fileName = "Grape.jpg"
        }
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.withProperties { $0.fileName } == "Grape.jpg")
        #expect(manager.summary(of: ProgressManager.Properties.FileName.self) == ["Grape.jpg"])
    }
    
    @Test func twoLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.fileName = "Watermelon.jpg"
        }
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileName.self) == ["Watermelon.jpg", "Melon.jpg"])
    }
    
    @Test func threeLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.withProperties { properties in
            properties.completedCount = 1
            properties.fileName = "Watermelon.jpg"
        }
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.FileName.self) == ["Watermelon.jpg", "Cherry.jpg", "Melon.jpg"])
    }
}
