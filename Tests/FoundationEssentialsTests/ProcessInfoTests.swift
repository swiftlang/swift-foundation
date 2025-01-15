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

#if canImport(TestSupport)
import TestSupport
#endif

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
final class ProcessInfoTests : XCTestCase {
    func testArguments() {
        let args = ProcessInfo.processInfo.arguments
        XCTAssertTrue(
            !args.isEmpty,"arguments should not have been empty")
    }

    func testEnvironment() {
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
        XCTAssertTrue(
            !env.isEmpty, "environment should not have been empty")
        
        let preset = ProcessInfo.processInfo.environment["test"]
        setenv("test", "worked", 1)
        let postset = ProcessInfo.processInfo.environment["test"]
        XCTAssertNil(preset)
        XCTAssertEqual(postset, "worked")
    }

    func testProcessIdentifier() {
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertEqual(
            pid, getpid(), "ProcessInfo disagrees with getpid()")
    }

    func testGlobalUniqueString() {
        let unique = ProcessInfo.processInfo.globallyUniqueString
        XCTAssertNotEqual(
            unique,
            ProcessInfo.processInfo.globallyUniqueString,
            "globallyUniqueString should never return the same string twice")
    }

    func testOperatingSystemVersionString() {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        XCTAssertFalse(version.isEmpty, "ProcessInfo returned empty string for operation system version")
        #if os(Windows)
        XCTAssertTrue(version.starts(with: "Windows"), "'\(version)' did not start with 'Windows'")
        #endif
    }

    func testProcessorCount() {
        let count = ProcessInfo.processInfo.processorCount
        XCTAssertTrue(count > 0, "ProcessInfo doesn't think we have any processors")
    }

    func testActiveProcessorCount() {
        let count = ProcessInfo.processInfo.activeProcessorCount
        XCTAssertTrue(count > 0, "ProcessInfo doesn't think we have any active processors")
    }

    func testPhysicalMemory() {
        let memory = ProcessInfo.processInfo.physicalMemory
        XCTAssertTrue(memory > 0, "ProcessInfo doesn't think we have any memory")
    }

    func testSystemUpTime() async throws {
        let now = ProcessInfo.processInfo.systemUptime
        XCTAssertTrue(
            now > 1, "ProcessInfo returned an unrealistically low system uptime")
        // Sleep for 0.1s
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(
            ProcessInfo.processInfo.systemUptime > now,
            "ProcessInfo returned the same system uptime with 400")

    }

    func testOperatingSystemVersion() throws {
        #if canImport(Darwin)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        #if os(visionOS)
        let expectedMinMajorVersion = 1
        #else
        let expectedMinMajorVersion = 2
        #endif
        XCTAssertGreaterThanOrEqual(version.majorVersion, expectedMinMajorVersion, "Unrealistic major system version")
        #elseif os(Windows) || os(Linux) || os(Android)
        let minVersion = OperatingSystemVersion(majorVersion: 1, minorVersion: 0, patchVersion: 0)
        XCTAssertTrue(ProcessInfo.processInfo.isOperatingSystemAtLeast(minVersion))
        #else
        throw XCTSkip("This test is not supported on this platform")
        #endif
    }

    func testOperatingSystemIsAtLeastVersion() throws {
        #if !canImport(Darwin)
        throw XCTSkip("This test is not supported on this platform")
        #else
        #if os(watchOS)
        XCTAssertTrue(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 1, minorVersion: 12, patchVersion: 0)
            ),
        "ProcessInfo thinks 1.12 is > than 2.something")
        XCTAssertTrue(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 1, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on watchOS 1")
        #elseif os(macOS) || (os(iOS) && !os(visionOS))
        XCTAssertTrue(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 6, minorVersion: 12, patchVersion: 0)
            ),
        "ProcessInfo thinks 6.12 is > than 10.something")
        XCTAssertTrue(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 6, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on System 5")
        #endif
        XCTAssertFalse(ProcessInfo.processInfo
            .isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: 70, minorVersion: 0, patchVersion: 0)
            ),
        "ProcessInfo thinks we are on System 70")
        #endif
    }

#if os(macOS)
    func testUserName() {
        XCTAssertFalse(ProcessInfo.processInfo.userName.isEmpty)
    }

    func testFullUserName() {
        XCTAssertFalse(ProcessInfo.processInfo.fullUserName.isEmpty)
    }
#endif
    
    func testProcessName() {
#if FOUNDATION_FRAMEWORK
        let targetName = "TestHost"
#elseif os(Linux) || os(Windows) || os(Android) || os(FreeBSD)
        let targetName = "swift-foundationPackageTests.xctest"
#else
        let targetName = "xctest"
#endif
        let processInfo = ProcessInfo.processInfo
        let originalProcessName = processInfo.processName
        XCTAssertEqual(originalProcessName, targetName)
        
        // Try assigning a new process name.
        let newProcessName = "TestProcessName"
        processInfo.processName = newProcessName
        XCTAssertEqual(processInfo.processName, newProcessName)
        
        // Assign back to the original process name.
        processInfo.processName = originalProcessName
        XCTAssertEqual(processInfo.processName, originalProcessName)
    }

    func testWindowsEnvironmentDoesNotContainMagicValues() {
        // Windows GetEnvironmentStringsW API can return
        // magic environment variables set by the cmd shell
        // that starts with `=`
        // This test makes sure we don't include these
        // magic variables
        let env = ProcessInfo.processInfo.environment
        XCTAssertNil(env[""])
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
