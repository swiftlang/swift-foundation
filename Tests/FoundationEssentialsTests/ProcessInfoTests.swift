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
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#elseif os(Windows)
import CRT
#endif

/// Since we can't really mock system settings like OS name,
/// these tests simply check that the values returned are not empty
struct ProcessInfoTests {
    @Test func testArguments() {
        let args = ProcessInfo.processInfo.arguments
        #expect(!args.isEmpty, "arguments should not have been empty")
    }

    @Test func testEnvironment() {
#if os(Windows)
        func setenv(_ key: String, _ value: String, _ overwrite: Int) -> Int32 {
          assert(overwrite == 1)
          guard !key.contains("=") else {
              errno = EINVAL
              return -1
          }
          return _putenv("\(key)=\(value)")
        }
#endif
        let env = ProcessInfo.processInfo.environment
        #expect(!env.isEmpty, "environment should not have been empty")
        
        #expect(ProcessInfo.processInfo.environment["test"] == nil)
        setenv("test", "worked", 1)
        #expect(ProcessInfo.processInfo.environment["test"] == "worked")
    }

    @Test func testProcessIdentifier() {
        let pid = ProcessInfo.processInfo.processIdentifier
        #expect(pid == getpid(), "ProcessInfo disagrees with getpid()")
    }

    @Test func testGlobalUniqueString() {
        let a = ProcessInfo.processInfo.globallyUniqueString
        let b = ProcessInfo.processInfo.globallyUniqueString
        #expect(a != b, "globallyUniqueString should never return the same string twice")
    }

    @Test func testOperatingSystemVersionString() {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        #expect(!version.isEmpty, "ProcessInfo returned empty string for operation system version")
        #if os(Windows)
        #expect(version.starts(with: "Windows"), "'\(version)' did not start with 'Windows'")
        #endif
    }

    @Test func testProcessorCount() {
        let count = ProcessInfo.processInfo.processorCount
        #expect(count > 0, "ProcessInfo doesn't think we have any processors")
    }

    @Test func testActiveProcessorCount() {
        let count = ProcessInfo.processInfo.activeProcessorCount
        #expect(count > 0, "ProcessInfo doesn't think we have any active processors")
    }

    @Test func testPhysicalMemory() {
        let memory = ProcessInfo.processInfo.physicalMemory
        #expect(memory > 0, "ProcessInfo doesn't think we have any memory")
    }

    @Test func testSystemUpTime() async throws {
        let now = ProcessInfo.processInfo.systemUptime
        #expect(now > 1, "ProcessInfo returned an unrealistically low system uptime")
        // Sleep for 0.1s
        try await Task.sleep(for: .milliseconds(100))
        #expect(ProcessInfo.processInfo.systemUptime > now, "ProcessInfo returned the same system uptime with 400")

    }

    @Test func testOperatingSystemVersion() throws {
        #if canImport(Darwin)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        #if os(visionOS)
        let expectedMinMajorVersion = 1
        #else
        let expectedMinMajorVersion = 2
        #endif
        #expect(version.majorVersion >= expectedMinMajorVersion, "Unrealistic major system version")
        #elseif os(Windows) || os(Linux)
        let minVersion = OperatingSystemVersion(majorVersion: 1, minorVersion: 0, patchVersion: 0)
        #expect(ProcessInfo.processInfo.isOperatingSystemAtLeast(minVersion))
        #endif
    }

    #if canImport(Darwin)
    @Test func testOperatingSystemIsAtLeastVersion() throws {
        #if os(watchOS)
        #expect(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 1, minorVersion: 12, patchVersion: 0)
            ),
        "ProcessInfo thinks 1.12 is > than 2.something")
        #expect(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 1, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on watchOS 1")
        #elseif os(macOS) || (os(iOS) && !os(visionOS))
        #expect(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 6, minorVersion: 12, patchVersion: 0)
            ),
        "ProcessInfo thinks 6.12 is > than 10.something")
        #expect(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 6, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on System 5")
        #endif
        #expect(!ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 70, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on System 70")
    }
    #endif

#if os(macOS)
    @Test func testUserName() {
        #expect(!ProcessInfo.processInfo.userName.isEmpty)
    }

    @Test func testFullUserName() {
        #expect(!ProcessInfo.processInfo.fullUserName.isEmpty)
    }
#endif
    
    @Test func testProcessName() {
#if FOUNDATION_FRAMEWORK
        let targetNames = ["TestHost"]
#elseif os(Linux) || os(Windows)
        let targetNames = ["swift-foundationPackageTests.xctest"]
#else
        let targetNames = ["xctest", "swiftpm-testing-helper"]
#endif
        let processInfo = ProcessInfo.processInfo
        let originalProcessName = processInfo.processName
        #expect(targetNames.contains(originalProcessName))
        
        // Try assigning a new process name.
        let newProcessName = "TestProcessName"
        processInfo.processName = newProcessName
        #expect(processInfo.processName == newProcessName)
        
        // Assign back to the original process name.
        processInfo.processName = originalProcessName
        #expect(processInfo.processName == originalProcessName)
    }

    @Test func testWindowsEnvironmentDoesNotContainMagicValues() {
        // Windows GetEnvironmentStringsW API can return
        // magic environment variables set by the cmd shell
        // that starts with `=`
        // This test makes sure we don't include these
        // magic variables
        let env = ProcessInfo.processInfo.environment
        #expect(env[""] == nil)
    }
}

// MARK: - ThermalState and PowerState tests
#if FOUNDATION_FRAMEWORK
extension ProcessInfoTests {
    func testThermalPowerState() {
        // This test simply makes sure we can deliver the correct
        // thermal and power state for all platforms.
        // Fake a new value
        _NSSwiftProcessInfo._globalState.withLock {
            $0.thermalState = .critical
            $0.powerState = .restricted
        }
        XCTAssertEqual(ProcessInfo.processInfo.thermalState, .critical)
        XCTAssertEqual(ProcessInfo.processInfo.isLowPowerModeEnabled, true)
    }
}
#endif // FOUDATION_FRAMEWORK
