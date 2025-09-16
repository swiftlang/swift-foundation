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
        manager.totalFileCount = 100
        
        #expect(manager.totalFileCount == 100)
        
        manager.complete(count: 100)
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.isFinished == true)
        
        manager.completedFileCount = 100
        #expect(manager.completedFileCount == 100)
        #expect(manager.totalFileCount == 100)
    }
    
    @Test func discreteReporterWithFileProperties() async throws {
        let fileProgressManager = ProgressManager(totalCount: 3)
        await doFileOperation(reportTo: fileProgressManager.subprogress(assigningCount: 3))
        #expect(fileProgressManager.fractionCompleted == 1.0)
        #expect(fileProgressManager.completedCount == 3)
        #expect(fileProgressManager.isFinished == true)
        #expect(fileProgressManager.totalFileCount == 0)
        #expect(fileProgressManager.completedFileCount == 0)
        
        let summaryTotalFile = fileProgressManager.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 100)
        
        let summaryCompletedFile = fileProgressManager.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 100)
    }
    
    @Test func twoLevelTreeWithOneChildWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 10)
        manager1.totalFileCount = 10
        manager1.completedFileCount = 0
        manager1.complete(count: 10)
        
        #expect(overall.fractionCompleted == 0.5)
        
        #expect(overall.totalFileCount == 0)
        #expect(manager1.totalFileCount == 10)
        #expect(manager1.completedFileCount == 0)
        
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 10)
        
        let summaryCompletedFile = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 0)
    }
    
    @Test func twoLevelTreeWithTwoChildrenWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 2)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 10)
        
        manager1.totalFileCount = 11
        manager1.completedFileCount = 0
        
        let progress2 = overall.subprogress(assigningCount: 1)
        let manager2 = progress2.start(totalCount: 10)
        
        manager2.totalFileCount = 9
        manager2.completedFileCount = 0
        
        #expect(overall.fractionCompleted == 0.0)
        #expect(overall.totalFileCount == 0)
        #expect(overall.completedFileCount == 0)
        
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 20)
        
        let summaryCompletedFile = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFile == 0)
        
        // Update FileCounts
        manager1.completedFileCount = 1
        
        manager2.completedFileCount = 1
        
        #expect(overall.completedFileCount == 0)
        let summaryCompletedFileUpdated = overall.summary(of: ProgressManager.Properties.CompletedFileCount.self)
        #expect(summaryCompletedFileUpdated == 2)
    }
    
    @Test func threeLevelTreeWithFileProperties() async throws {
        let overall = ProgressManager(totalCount: 1)
        
        let progress1 = overall.subprogress(assigningCount: 1)
        let manager1 = progress1.start(totalCount: 5)
        
        
        let childProgress1 = manager1.subprogress(assigningCount: 3)
        let childManager1 = childProgress1.start(totalCount: nil)
        childManager1.totalFileCount += 10
        #expect(childManager1.totalFileCount == 10)
        
        let summaryTotalFileInitial = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFileInitial == 10)
        
        let childProgress2 = manager1.subprogress(assigningCount: 2)
        let childManager2 = childProgress2.start(totalCount: nil)
        childManager2.totalFileCount += 10
        #expect(childManager2.totalFileCount == 10)

        // Tests that totalFileCount propagates to root level
        #expect(overall.totalFileCount == 0)
        let summaryTotalFile = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFile == 20)
        
        manager1.totalFileCount += 999
        let summaryTotalFileUpdated = overall.summary(of: ProgressManager.Properties.TotalFileCount.self)
        #expect(summaryTotalFileUpdated == 1019)
    }
}

@Suite("Progress Manager Byte Properties", .tags(.progressManager)) struct ProgressManagerBytePropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 3)
        manager.totalByteCount = 300000
        
        manager.complete(count: 1)
        manager.completedByteCount += 100000
        
        manager.complete(count: 1)
        manager.completedByteCount += 100000
        
        manager.complete(count: 1)
        manager.completedByteCount += 100000
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 300000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 300000)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalByteCount = 200000
        manager.completedByteCount = 200000
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 500000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 500000)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalByteCount = 2000
        manager.completedByteCount = 1000
        
        #expect(manager.fractionCompleted == 0.5)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 2000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 1000)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        manager.complete(count: 1)
        manager.totalByteCount = 500000
        manager.completedByteCount = 499999
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 800000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 799999)
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalByteCount = 100000
        manager.completedByteCount = 99999
        
        try await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalByteCount.self) == 600000)
        #expect(manager.summary(of: ProgressManager.Properties.CompletedByteCount.self) == 599999)
    }
}

@Suite("Progress Manager Throughput Properties", .tags(.progressManager)) struct ProgressManagerThroughputTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        manager.complete(count: 1)
        manager.throughput += 1000
        
        manager.complete(count: 1)
        manager.throughput += 1000
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [2000])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.throughput = 1000
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 2000])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.throughput = 1000
        manager.throughput += 2000
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [3000])
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        manager.complete(count: 1)
        manager.throughput = 1000
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 2000])
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        manager.complete(count: 1)
        
        manager.throughput = 1000
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Throughput.self) == [1000, 1000, 2000])
    }
}

@Suite("Progress Manager Estimated Time Remaining Properties", .tags(.progressManager)) struct ProgressManagerEstimatedTimeRemainingTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.estimatedTimeRemaining = Duration.seconds(3000)
        
        manager.complete(count: 1)
        manager.estimatedTimeRemaining += Duration.seconds(3000)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(6000))
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.estimatedTimeRemaining = Duration.seconds(1000)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(1000))
    }
    
    @Test func twoLevelManagerWithFinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.estimatedTimeRemaining = Duration.seconds(1)
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(1))
    }
    
    @Test func twoLevelManagerWithUnfinishedChild() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.estimatedTimeRemaining = Duration.seconds(200)
        
        var child: ProgressManager? = manager.subprogress(assigningCount: 1).start(totalCount: 2)
        child?.complete(count: 1)
        child?.estimatedTimeRemaining = Duration.seconds(80000)
        
        #expect(manager.fractionCompleted == 0.75)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(80000))
        
        child = nil
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.EstimatedTimeRemaining.self) == Duration.seconds(200))
    }
    
}

extension ProgressManager.Properties {

    var counter: Counter.Type { Counter.self }
    struct Counter: Sendable, ProgressManager.Property {
        
        typealias Value = Int
        
        typealias Summary = Int
        
        static var key: String { return "MyApp.Counter" }
        
        static var defaultValue: Int { return 0 }
        
        static var defaultSummary: Int { return 0 }
        
        static func reduce(into summary: inout Int, value: Int) {
            summary += value
        }
        
        static func merge(_ summary1: Int, _ summary2: Int) -> Int {
            return summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: Int, _ childSummary: Int) -> Int {
            return parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager Int Properties", .tags(.progressManager)) struct ProgressManagerIntPropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        
        manager.complete(count: 1)
        manager.counter += 10
        
        manager.complete(count: 1)
        manager.counter += 10
        
        manager.complete(count: 1)
        manager.counter += 10
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 30)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        
        manager.counter = 15
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 45)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.counter += 10
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 10)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.counter += 10
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 40)
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.counter += 10
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.Counter.self) == 55)
    }
}

extension ProgressManager.Properties {
    var byteSize: ByteSize.Type { ByteSize.self }
    struct ByteSize: Sendable, ProgressManager.Property {
        
        typealias Value = UInt64
        
        typealias Summary = UInt64
        
        static var key: String { return "MyApp.ByteSize" }
        
        static var defaultValue: UInt64 { return 0 }
        
        static var defaultSummary: UInt64 { return 0 }
        
        static func reduce(into summary: inout UInt64, value: UInt64) {
            summary += value
        }
        
        static func merge(_ summary1: UInt64, _ summary2: UInt64) -> UInt64 {
            return summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: UInt64, _ childSummary: UInt64) -> UInt64 {
            return parentSummary + childSummary
        }
    }
}


@Suite("Progress Manager UInt64 Properties", .tags(.progressManager)) struct ProgressManagerUInt64PropertiesTests {

func doSomething(subprogress: consuming Subprogress) async {
    let manager = subprogress.start(totalCount: 3)
    
    manager.complete(count: 1)
    manager.byteSize += 1024
    
    manager.complete(count: 1)
    manager.byteSize += 2048
    
    manager.complete(count: 1)
    manager.byteSize += 4096
    
    #expect(manager.fractionCompleted == 1.0)
    #expect(manager.summary(of: ProgressManager.Properties.ByteSize.self) == 7168)
}

func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
    let manager = subprogress.start(totalCount: 2)
    
    manager.complete(count: 1)
    
    manager.byteSize = 8192
    
    await doSomething(subprogress: manager.subprogress(assigningCount: 1))

    #expect(manager.fractionCompleted == 1.0)
    #expect(manager.summary(of: ProgressManager.Properties.ByteSize.self) == 15360)
}

@Test func discreteManager() async throws {
    let manager = ProgressManager(totalCount: 1)
    
    manager.complete(count: 1)
    manager.byteSize += 16384
    
    #expect(manager.fractionCompleted == 1.0)
    #expect(manager.summary(of: ProgressManager.Properties.ByteSize.self) == 16384)
}

@Test func twoLevelManager() async throws {
    let manager = ProgressManager(totalCount: 2)
    
    manager.complete(count: 1)
    manager.byteSize += 32768
    
    await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
    #expect(manager.fractionCompleted == 1.0)
    #expect(manager.summary(of: ProgressManager.Properties.ByteSize.self) == 39936)
}

@Test func threeLevelManager() async throws {
    let manager = ProgressManager(totalCount: 2)
    
    manager.complete(count: 1)
    manager.byteSize += 65536
    
    await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
    
    #expect(manager.fractionCompleted == 1.0)
    #expect(manager.summary(of: ProgressManager.Properties.ByteSize.self) == 80896)
}
}

extension ProgressManager.Properties {
    
    var justADouble: JustADouble.Type { JustADouble.self }
    struct JustADouble: Sendable, ProgressManager.Property {
        
        typealias Value = Double
        
        typealias Summary = Double
        
        static var key: String { return "MyApp.JustADouble" }

        static var defaultValue: Double { return 0.0 }
        
        static var defaultSummary: Double { return 0.0 }
        
        static func reduce(into summary: inout Double, value: Double) {
            summary += value
        }
        
        static func merge(_ summary1: Double, _ summary2: Double) -> Double {
            return summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: Double, _ childSummary: Double) -> Double {
            return parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager Double Properties", .tags(.progressManager)) struct ProgressManagerDoublePropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 3)
        
        manager.complete(count: 1)
        manager.justADouble += 10.0
        
        manager.complete(count: 1)
        manager.justADouble += 10.0
        
        manager.complete(count: 1)
        manager.justADouble += 10.0
        
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 30.0)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async throws {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.justADouble = 7.0
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 37.0)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.justADouble = 80.0
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 80.0)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.justADouble = 80.0
        
        try await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 110.0)
    }
    
    @Test func threeLevelManager() async throws {
        
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.justADouble = 80.0
        
        try await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.JustADouble.self) == 117.0)
    }
}

extension ProgressManager.Properties {
    
    var downloadedFile: DownloadedFile.Type { DownloadedFile.self }
    struct DownloadedFile: Sendable, ProgressManager.Property {
        
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
        
        static func finalSummary(_ parentSummary: [String?], _ childSummary: [String?]) -> [String?] {
            return parentSummary + childSummary
        }
    }
}


@Suite("Progress Manager String (Retaining) Properties", .tags(.progressManager)) struct ProgressManagerStringPropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.complete(count: 1)
        manager.downloadedFile = "Melon.jpg"
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.DownloadedFile.self) == ["Melon.jpg"])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.downloadedFile = "Cherry.jpg"
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.DownloadedFile.self) == ["Cherry.jpg", "Melon.jpg"])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.downloadedFile = "Grape.jpg"
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.downloadedFile == "Grape.jpg")
        #expect(manager.summary(of: ProgressManager.Properties.DownloadedFile.self) == ["Grape.jpg"])
    }
    
    @Test func twoLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.downloadedFile = "Watermelon.jpg"
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.DownloadedFile.self) == ["Watermelon.jpg", "Melon.jpg"])
    }
    
    @Test func threeLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.downloadedFile = "Watermelon.jpg"
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.DownloadedFile.self) == ["Watermelon.jpg", "Cherry.jpg", "Melon.jpg"])
    }
}

extension ProgressManager.Properties {
    
    var processingFile: ProcessingFile.Type { ProcessingFile.self }
    struct ProcessingFile: Sendable, ProgressManager.Property {
                
        typealias Value = String?
        
        typealias Summary = [String?]
        
        static var key: String { return "MyApp.ProcessingFile" }
        
        static var defaultValue: String? { return "" }
        
        static var defaultSummary: [String?] { return [] }
        
        static func reduce(into summary: inout [String?], value: String?) {
            summary.append(value)
        }
        
        static func merge(_ summary1: [String?], _ summary2: [String?]) -> [String?] {
            return summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: [String?], _ childSummary: [String?]) -> [String?] {
            return parentSummary
        }
    }
}

@Suite("Progress Manager String (Non-retaining) Properties", .tags(.progressManager)) struct ProgressManagerStringNonRetainingProperties {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.complete(count: 1)
        manager.processingFile = "Hello.jpg"
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessingFile.self) == ["Hello.jpg"])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processingFile = "Hi.jpg"
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessingFile.self) == ["Hi.jpg"])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.processingFile = "Howdy.jpg"
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.processingFile == "Howdy.jpg")
        #expect(manager.summary(of: ProgressManager.Properties.ProcessingFile.self) == ["Howdy.jpg"])
    }
    
    @Test func twoLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processingFile = "Howdy.jpg"
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessingFile.self) == ["Howdy.jpg"])
    }
    
    @Test func threeLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processingFile = "Howdy.jpg"
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessingFile.self) == ["Howdy.jpg"])
    }
}


extension ProgressManager.Properties {
    var imageURL: ImageURL.Type { ImageURL.self }
    struct ImageURL: Sendable, ProgressManager.Property {
        
        typealias Value = URL?
        
        typealias Summary = [URL?]
        
        static var key: String { "MyApp.ImageURL" }
        
        static var defaultValue: URL? { nil }
        
        static var defaultSummary: [URL?] { [] }
        
        static func reduce(into summary: inout [URL?], value: URL?) {
            summary.append(value)
        }
        
        static func merge(_ summary1: [URL?], _ summary2: [URL?]) -> [URL?] {
            summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: [URL?], _ childSummary: [URL?]) -> [URL?] {
            parentSummary
        }
    }
}

@Suite("Progress Manager URL (Non-retaining) Properties", .tags(.progressManager)) struct ProgressManagerURLProperties {
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.complete(count: 1)
        manager.imageURL = URL(string: "112.jpg")
        
        #expect(manager.summary(of: ProgressManager.Properties.ImageURL.self) == [URL(string: "112.jpg")])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.imageURL = URL(string: "114.jpg")
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.summary(of: ProgressManager.Properties.ImageURL.self) == [URL(string: "114.jpg")])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.imageURL = URL(string: "116.jpg")
        
        #expect(manager.fractionCompleted == 0.0)
        #expect(manager.summary(of: ProgressManager.Properties.ImageURL.self) == [URL(string: "116.jpg")])
    }
    
    @Test func twoLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.imageURL = URL(string: "116.jpg")
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ImageURL.self) == [URL(string: "116.jpg")])
    }
    
    @Test func threeLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.imageURL = URL(string: "116.jpg")
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ImageURL.self) == [URL(string: "116.jpg")])
    }
}

extension ProgressManager.Properties {
    var totalPixelCount: TotalPixelCount.Type { TotalPixelCount.self }
    struct TotalPixelCount: Sendable, ProgressManager.Property {
        typealias Value = UInt64
        
        typealias Summary = [UInt64]
        
        static var key: String { "MyApp.TotalPixelCount" }
        
        static var defaultValue: UInt64 { 0 }
        
        static var defaultSummary: [UInt64] { [] }
        
        static func reduce(into summary: inout [UInt64], value: UInt64) {
            summary.append(value)
        }
        
        static func merge(_ summary1: [UInt64], _ summary2: [UInt64]) -> [UInt64] {
            summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: [UInt64], _ childSummary: [UInt64]) -> [UInt64] {
            parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager UInt64 Array (Retaining) Properties", .tags(.progressManager)) struct ProgressManagerUInt64ArrayProperties {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 1)
        
        manager.complete(count: 1)
        manager.totalPixelCount = 24
        
        #expect(manager.summary(of: ProgressManager.Properties.TotalPixelCount.self) == [24])
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalPixelCount = 26
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.summary(of: ProgressManager.Properties.TotalPixelCount.self) == [26, 24])
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.totalPixelCount = 42
        
        #expect(manager.fractionCompleted == 0.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalPixelCount.self) == [42])
    }
    
    @Test func twoLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalPixelCount = 42
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalPixelCount.self) == [42, 24])
    }
    
    @Test func threeLevelsManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.totalPixelCount = 42
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.TotalPixelCount.self) == [42, 26, 24])
    }
}

extension ProgressManager.Properties {
    var viralIndeterminate: ViralIndeterminate.Type { ViralIndeterminate.self }
    struct ViralIndeterminate: Sendable, ProgressManager.Property {
        typealias Value = Int
        
        typealias Summary = Int
        
        static var key: String { "MyApp.ViralIndeterminate" }
        
        static var defaultValue: Int { 1 }
        
        static var defaultSummary: Int { 1 }
        
        static func reduce(into summary: inout Int, value: Int) {
            summary = min(summary, value)
        }
        
        static func merge(_ summary1: Int, _ summary2: Int) -> Int {
            min(summary1, summary2)
        }
        
        static func finalSummary(_ parentSummary: Int, _ childSummary: Int) -> Int {
            min(parentSummary, childSummary)
        }
    }
}


@Suite("Progress Manager Viral Indeterminate Property", .tags(.progressManager)) struct ProgressManagerViralIndeterminateProperties {
    // Tests the use of additional property to virally propagate property from leaf to root
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        
        manager.complete(count: 1)
        manager.viralIndeterminate = 0
        
        manager.complete(count: 1)
        
        manager.complete(count: 1)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ViralIndeterminate.self) == 0)
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        manager.viralIndeterminate = 1
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ViralIndeterminate.self) == 0)
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.viralIndeterminate = 1
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ViralIndeterminate.self) == 1)
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.viralIndeterminate = 1
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ViralIndeterminate.self) == 0)
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.viralIndeterminate = 1
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ViralIndeterminate.self) == 0)
    }
}

extension ProgressManager.Properties {
    var processTime: ProcessTime.Type { ProcessTime.self }
    struct ProcessTime: Sendable, ProgressManager.Property {
        
        typealias Value = Duration
        
        typealias Summary = Duration
        
        static var key: String { return "MyApp.ProcessTime" }
        
        static var defaultValue: Duration { return .zero }
        
        static var defaultSummary: Duration { return .zero }
        
        static func reduce(into summary: inout Duration, value: Duration) {
            summary += value
        }
        
        static func merge(_ summary1: Duration, _ summary2: Duration) -> Duration {
            return summary1 + summary2
        }
        
        static func finalSummary(_ parentSummary: Duration, _ childSummary: Duration) -> Duration {
            return parentSummary + childSummary
        }
    }
}

@Suite("Progress Manager Duration Properties", .tags(.progressManager)) struct ProgressManagerDurationPropertiesTests {
    
    func doSomething(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 3)
        
        manager.complete(count: 1)
        manager.processTime += Duration.seconds(10)
        
        manager.complete(count: 1)
        manager.processTime += Duration.seconds(15)
        
        manager.complete(count: 1)
        manager.processTime += Duration.seconds(25)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(50))
    }
    
    func doSomethingTwoLevels(subprogress: consuming Subprogress) async {
        let manager = subprogress.start(totalCount: 2)
        
        manager.complete(count: 1)
        
        manager.processTime = Duration.seconds(30)
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
    
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(80))
    }
    
    @Test func discreteManager() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        manager.processTime += Duration.milliseconds(500)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.milliseconds(500))
    }
    
    @Test func twoLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processTime += Duration.seconds(120)
        
        await doSomething(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(170))
    }
    
    @Test func threeLevelManager() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processTime += Duration.microseconds(1000000) // 1 second
        
        await doSomethingTwoLevels(subprogress: manager.subprogress(assigningCount: 1))
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(81))
    }
    
    @Test func zeroDurationHandling() async throws {
        let manager = ProgressManager(totalCount: 2)
        
        manager.complete(count: 1)
        manager.processTime = Duration.zero
        
        let childProgress = manager.subprogress(assigningCount: 1)
        let childManager = childProgress.start(totalCount: 1)
        
        childManager.complete(count: 1)
        childManager.processTime = Duration.seconds(42)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(42))
    }
    
    @Test func negativeDurationHandling() async throws {
        let manager = ProgressManager(totalCount: 1)
        
        manager.complete(count: 1)
        // Test with negative duration (though this might be unusual in practice)
        manager.processTime = Duration.seconds(-5)
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(-5))
    }
    
    @Test func mixedDurationUnits() async throws {
        let manager = ProgressManager(totalCount: 3)
        
        manager.complete(count: 1)
        manager.processTime = Duration.seconds(1) // 1 second
        
        manager.complete(count: 1)
        manager.processTime += Duration.milliseconds(500) // + 0.5 seconds
        
        manager.complete(count: 1)
        manager.processTime += Duration.microseconds(500000) // + 0.5 seconds
        
        #expect(manager.fractionCompleted == 1.0)
        #expect(manager.summary(of: ProgressManager.Properties.ProcessTime.self) == Duration.seconds(2))
    }
}

