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

#if !FOUNDATION_FRAMEWORK

/// A collection of information about the current process.
public final class ProcessInfo: Sendable {
    public static let processInfo: ProcessInfo = ProcessInfo()

    private let _processInfo: _ProcessInfo = _ProcessInfo.processInfo
}

// MARK: - Accessing Process Information
extension ProcessInfo {
    /// Array of strings with the command-line arguments for the process.
    public var arguments: [String] { _processInfo.arguments }

    /// The variable names (keys) and their values in the environment from which the process was launched.
    public var environment: [String : String] { _processInfo.environment }

    /// Global unique identifier for the process.
    public var globallyUniqueString: String { _processInfo.globallyUniqueString }

    /// The identifier of the process (often called process ID).
    public var processIdentifier: Int32 { _processInfo.processIdentifier }

    /// The name of the process.
    public var processName: String {
        get { _processInfo.processName }
        set { _processInfo.processName = newValue }
    }
}

// MARK: - Accessing User Information
extension ProcessInfo {
    /// Returns the account name of the current user.
    public var userName: String { _processInfo.userName }

    /// Returns the full name of the current user.
    public var fullUserName: String { _processInfo.fullUserName }
}

// MARK: - Getting Host Information
extension ProcessInfo {

    /// The name of the host computer on which the process is executing.
    public var hostName: String { _processInfo.hostName }

    /// A string containing the version of the operating system on which the process is executing.
    public var operatingSystemVersionString: String {
        _processInfo.operatingSystemVersionString
    }

    /// The version of the operating system on which the process is executing.
    public var operatingSystemVersion: OperatingSystemVersion {
        let (major, minor, patch) = _processInfo.operatingSystemVersion
        return OperatingSystemVersion(
            majorVersion: major,
            minorVersion: minor,
            patchVersion: patch)
    }

    /// Returns a Boolean value indicating whether the version of the operating system on which the process
    /// is executing is the same or later than the given version.
    public func isOperatingSystemAtLeast(_ version: OperatingSystemVersion) -> Bool {
        return _processInfo
            .isOperatingSystemAtLeast((
                major: version.majorVersion,
                minor: version.minorVersion,
                patch: version.patchVersion))
    }
}

public struct OperatingSystemVersion: Hashable, Codable, Sendable {
    public let majorVersion: Int
    public let minorVersion: Int
    public let patchVersion: Int
    
    public init() {
        self.init(majorVersion: 0, minorVersion: 0, patchVersion: 0)
    }
    
    public init(majorVersion: Int, minorVersion: Int, patchVersion: Int) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.patchVersion = patchVersion
    }
}

// MARK: - Getting Computer Information
extension ProcessInfo {
    /// The number of processing cores available on the computer.
    public var processorCount: Int { _processInfo.processorCount }

    /// The number of active processing cores available on the computer.
    public var activeProcessorCount: Int { _processInfo.activeProcessorCount }

    /// The amount of physical memory on the computer in bytes.
    public var physicalMemory: UInt64 { _processInfo.physicalMemory }

    /// The amount of time the system has been awake since the last time it was restarted.
    public var systemUptime: TimeInterval { _processInfo.systemUptime }
}

#endif // !FOUNDATION_FRAMEWORK
