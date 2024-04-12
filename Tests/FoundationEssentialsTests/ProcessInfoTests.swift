//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Since we can't really mock system settings like OS name,
/// these tests simply check that the values returned are not empty
struct ProcessInfoTests {
    @Test func testArguments() {
        let args = _ProcessInfo.processInfo.arguments
        #expect(!args.isEmpty, "arguments should not have been empty")
    }

    @Test func testEnvironment() {
        let env = _ProcessInfo.processInfo.environment
        #expect(!env.isEmpty, "environment should not have been empty")
    }

    @Test func testProcessIdentifier() {
        let pid = _ProcessInfo.processInfo.processIdentifier
        #expect(pid == getpid(), "ProcessInfo disagrees with getpid()")
    }

    @Test func testGlobalUniqueString() {
        let unique = _ProcessInfo.processInfo.globallyUniqueString
        #expect(unique != _ProcessInfo.processInfo.globallyUniqueString,
            "globallyUniqueString should never return the same string twice")
    }

    @Test func testOperatingSystemVersionString() {
        let version = _ProcessInfo.processInfo.operatingSystemVersionString
        #expect(!version.isEmpty,
                "ProcessInfo returned empty string for operation system version")
    }

    @Test func testProcessorCount() {
        let count = _ProcessInfo.processInfo.processorCount
        #expect(count > 0, "ProcessInfo doesn't think we have any processors")
    }

    @Test func testActiveProcessorCount() {
        let count = _ProcessInfo.processInfo.activeProcessorCount
        #expect(count > 0, "ProcessInfo doesn't think we have any active processors")
    }

    @Test func testPhysicalMemory() {
        let memory = _ProcessInfo.processInfo.physicalMemory
        #expect(memory > 0, "ProcessInfo doesn't think we have any memory")
    }

    @Test func testSystemUpTime() {
        let now = _ProcessInfo.processInfo.systemUptime
        #expect(now > 1, "ProcessInfo returned an unrealistically low system uptime")
        // Sleep for 0.1s
        var ts: timespec = timespec(tv_sec: 0, tv_nsec: 100000000)
        nanosleep(&ts, nil)
        #expect(
            _ProcessInfo.processInfo.systemUptime > now,
            "ProcessInfo returned the same system uptime with 400")

    }

#if canImport(Darwin) // Only test on Apple's OSs
    @Test func testOperatingSystemVersion() {
        let version = _ProcessInfo.processInfo.operatingSystemVersion
        #if os(visionOS)
        let expectedMinMajorVersion = 1
        #else
        let expectedMinMajorVersion = 2
        #endif
        #expect(
            version.major >= expectedMinMajorVersion,
            "Unrealistic major system version")
    }

    @Test func testOperatingSystemIsAtLeastVersion() {
        #if os(watchOS)
        #expect(_ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                (major: 1, minor: 12, patch: 0)
            ),
        "ProcessInfo thinks 1.12 is > than 2.something")
        #expect(_ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                (major: 1, minor: 0, patch: 0)
            ),
        "ProcessInfo thinks we are on watchOS 1")
        #elseif os(macOS) || os(iOS)
        #expect(_ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                (major: 6, minor: 12, patch: 0)
            ),
        "ProcessInfo thinks 6.12 is > than 10.something")
        #expect(_ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                (major: 6, minor: 0, patch: 0)
            ),
        "ProcessInfo thinks we are on System 5")
        #endif
        #expect(_ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                (major: 70, minor: 0, patch: 0)
            ) == false,
        "ProcessInfo thinks we are on System 70")
    }
#endif

#if os(macOS)
    @Test func testUserName() {
        #expect(!_ProcessInfo.processInfo.userName.isEmpty)
    }

    @Test func testFullUserName() {
        #expect(!_ProcessInfo.processInfo.fullUserName.isEmpty)
    }
#endif
}
