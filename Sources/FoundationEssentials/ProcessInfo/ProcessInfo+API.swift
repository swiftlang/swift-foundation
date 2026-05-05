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
    /// Returns the process information agent for the process.
    ///
    /// An `ProcessInfo` object is created the first time this property is
    /// accessed, and that same object is returned on each subsequent access.
    public static let processInfo: ProcessInfo = ProcessInfo()

    private let _processInfo: _ProcessInfo = _ProcessInfo.processInfo
}

// MARK: - Accessing Process Information
extension ProcessInfo {
    /// Array of strings with the command-line arguments for the process.
    ///
    /// This array contains all the information passed in the `argv` array,
    /// including the executable name in the first element.
    public var arguments: [String] { _processInfo.arguments }

    /// The variable names (keys) and their values in the environment from which the process was launched.
    public var environment: [String : String] { _processInfo.environment }

    /// Global unique identifier for the process.
    ///
    /// The global ID for the process includes the host name, process ID, and a
    /// time stamp, which ensures that the ID is unique for the network. This
    /// property generates a new string each time its getter is invoked, and it
    /// uses a counter to guarantee that strings created from the same process
    /// are unique.
    public var globallyUniqueString: String { _processInfo.globallyUniqueString }

    /// The identifier of the process (often called process ID).
    public var processIdentifier: Int32 { _processInfo.processIdentifier }

    /// The name of the process.
    ///
    /// The process name is used to register application defaults and is used in
    /// error messages. It does not uniquely identify the process.
    ///
    /// > Warning: User defaults and other aspects of the environment might
    /// > depend on the process name, so be very careful if you change it.
    /// > Setting the process name in this manner is not thread safe.
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
    ///
    /// The operating system version string is human readable, localized, and is
    /// appropriate for displaying to the user. This string is _not_ appropriate
    /// for parsing.
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
    ///
    /// This method accounts for major, minor, and update versions of the
    /// operating system.
    ///
    /// - Parameter version: The operating system version to test against.
    /// - Returns: `true` if the operating system on which the process is
    ///   executing is the same or later than the given version; otherwise
    ///   `false`.
    public func isOperatingSystemAtLeast(_ version: OperatingSystemVersion) -> Bool {
        return _processInfo
            .isOperatingSystemAtLeast((
                major: version.majorVersion,
                minor: version.minorVersion,
                patch: version.patchVersion))
    }
}

/// A structure that contains version information about the currently executing operating system, including major, minor, and patch version numbers.
///
/// Use the ``ProcessInfo`` property ``ProcessInfo/operatingSystemVersion`` to fetch an instance of this type. You can also pass this type to ``ProcessInfo/isOperatingSystemAtLeast(_:)`` to determine whether the current operating system version is the same or later than the given value.
public struct OperatingSystemVersion: Hashable, Codable, Sendable {
    /// The major release number, such as 10 in version 10.9.3.
    public let majorVersion: Int
    /// The minor release number, such as 9 in version 10.9.3.
    public let minorVersion: Int
    /// The update release number, such as 3 in version 10.9.3.
    public let patchVersion: Int

    /// Creates an empty operating system version.
    ///
    /// All fields are initialized to `0`.
    public init() {
        self.init(majorVersion: 0, minorVersion: 0, patchVersion: 0)
    }

    /// Creates an operating system version with the provided values.
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
    ///
    /// Whereas the ``ProcessInfo/processorCount`` property reports the number of
    /// advertised processing cores, the ``ProcessInfo/activeProcessorCount``
    /// property reflects the actual number of active processing cores on the
    /// system. There are a number of different factors that may cause a core to
    /// not be active, including boot arguments, thermal throttling, or a
    /// manufacturing defect.
    public var activeProcessorCount: Int { _processInfo.activeProcessorCount }

    /// The amount of physical memory on the computer in bytes.
    public var physicalMemory: UInt64 { _processInfo.physicalMemory }

    /// The amount of time the system has been awake since the last time it was restarted.
    public var systemUptime: TimeInterval { _processInfo.systemUptime }
}

#endif // !FOUNDATION_FRAMEWORK
