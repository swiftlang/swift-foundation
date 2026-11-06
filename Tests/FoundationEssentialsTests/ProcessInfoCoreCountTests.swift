//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if os(Linux)

import Testing
import Foundation

@testable import FoundationEssentials

@Suite struct ProcessInfoCoreCountTests {
    private func file(with contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func cpusetCountsEveryRange() throws {
        let url = try file(with: "0-3,8-11")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuset: url) == 8)
    }

    @Test func cpusetCountsSingleCPUs() throws {
        let url = try file(with: "0,2,4,6")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuset: url) == 4)
    }

    @Test func cpusetRejectsUnparseableEntry() throws {
        let url = try file(with: "0-3,foo")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuset: url) == nil)
    }

    @Test func cpuMaxRoundsQuotaUp() throws {
        let url = try file(with: "150000 100000")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuMax: url) == 2)
    }

    @Test func cpuMaxExactQuota() throws {
        let url = try file(with: "400000 100000")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuMax: url) == 4)
    }

    @Test func cpuMaxUnlimitedIsNil() throws {
        let url = try file(with: "max 100000")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(_ProcessInfo.coreCount(cpuMax: url) == nil)
    }

    @Test func quotaRoundsUp() throws {
        let quota = try file(with: "150000")
        defer { try? FileManager.default.removeItem(at: quota) }
        let period = try file(with: "100000")
        defer { try? FileManager.default.removeItem(at: period) }
        #expect(_ProcessInfo.coreCount(quota: quota, period: period) == 2)
    }
}

#endif
