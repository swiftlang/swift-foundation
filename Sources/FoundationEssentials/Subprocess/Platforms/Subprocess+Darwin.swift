//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)

import Darwin
import SystemPackage

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _CShims
#else
package import _CShims
#endif

// Darwin specific implementation
extension Subprocess.Configuration {
    internal typealias StringOrRawBytes = Subprocess.StringOrRawBytes

    internal func spawn(
        withInput input: Subprocess.ExecutionInput,
        output: Subprocess.ExecutionOutput,
        error: Subprocess.ExecutionOutput
    ) throws -> Subprocess {
        let (executablePath,
            env, argv,
            intendedWorkingDir,
            uidPtr, gidPtr, supplementaryGroups
        ) = try self.preSpawn()
        defer {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            uidPtr?.deallocate()
            gidPtr?.deallocate()
        }

        // Setup file actions and spawn attributes
        var fileActions: posix_spawn_file_actions_t? = nil
        var spawnAttributes: posix_spawnattr_t? = nil
        // Setup stdin, stdout, and stderr
        posix_spawn_file_actions_init(&fileActions)
        defer {
            posix_spawn_file_actions_destroy(&fileActions)
        }

        var result = posix_spawn_file_actions_adddup2(&fileActions, input.getReadFileDescriptor().rawValue, 0)
        guard result == 0 else {
            try self.cleanupAll(input: input, output: output, error: error)
            throw POSIXError(.init(rawValue: result) ?? .ENODEV)
        }
        if let inputWrite = input.getWriteFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, inputWrite.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        result = posix_spawn_file_actions_adddup2(&fileActions, output.getWriteFileDescriptor().rawValue, 1)
        guard result == 0 else {
            try self.cleanupAll(input: input, output: output, error: error)
            throw POSIXError(.init(rawValue: result) ?? .ENODEV)
        }
        if let outputRead = output.getReadFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, outputRead.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        result = posix_spawn_file_actions_adddup2(&fileActions, error.getWriteFileDescriptor().rawValue, 2)
        guard result == 0 else {
            try self.cleanupAll(input: input, output: output, error: error)
            throw POSIXError(.init(rawValue: result) ?? .ENODEV)
        }
        if let errorRead = error.getReadFileDescriptor() {
            // Close parent side
            result = posix_spawn_file_actions_addclose(&fileActions, errorRead.rawValue)
            guard result == 0 else {
                try self.cleanupAll(input: input, output: output, error: error)
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }
        }
        // Setup spawnAttributes
        posix_spawnattr_init(&spawnAttributes)
        defer {
            posix_spawnattr_destroy(&spawnAttributes)
        }
        var noSignals = sigset_t()
        var allSignals = sigset_t()
        sigemptyset(&noSignals)
        sigfillset(&allSignals)
        posix_spawnattr_setsigmask(&spawnAttributes, &noSignals)
        posix_spawnattr_setsigdefault(&spawnAttributes, &allSignals)
        // Configure spawnattr
        var flags: Int32 = POSIX_SPAWN_CLOEXEC_DEFAULT |
            POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
        if self.platformOptions.createProcessGroup {
            flags |= POSIX_SPAWN_SETPGROUP
        }
        var spawnAttributeError = posix_spawnattr_setflags(&spawnAttributes, Int16(flags))
        // Set QualityOfService
        // spanattr_qos seems to only accept `QOS_CLASS_UTILITY` or `QOS_CLASS_BACKGROUND`
        // and returns an error of `EINVAL` if anything else is provided
        if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .utility{
            spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_UTILITY)
        } else if spawnAttributeError == 0 && self.platformOptions.qualityOfService == .background {
            spawnAttributeError = posix_spawnattr_set_qos_class_np(&spawnAttributes, QOS_CLASS_BACKGROUND)
        }

        // Setup cwd
        var chdirError: Int32 = 0
        if intendedWorkingDir != .currentWorkingDirectory {
            chdirError = intendedWorkingDir.withPlatformString { workDir in
                return posix_spawn_file_actions_addchdir_np(&fileActions, workDir)
            }
        }

        // Error handling
        if chdirError != 0 || spawnAttributeError != 0 {
            try self.cleanupAll(input: input, output: output, error: error)
            if spawnAttributeError != 0 {
                throw POSIXError(.init(rawValue: result) ?? .ENODEV)
            }

            if chdirError != 0 {
                throw CocoaError(.fileNoSuchFile, userInfo: [
                    .debugDescriptionErrorKey: "Cannot failed to change the working directory to \(intendedWorkingDir) with errno \(chdirError)"
                ])
            }
        }
        // Run additional config
        if let spawnConfig = self.platformOptions.additionalSpawnAttributeConfigurator {
            try spawnConfig(&spawnAttributes)
        }
        if let fileAttributeConfig = self.platformOptions.additionalFileAttributeConfigurator {
            try fileAttributeConfig(&fileActions)
        }
        // Spawn
        var pid: pid_t = 0
        let spawnError: CInt = executablePath.withCString { exePath in
            return supplementaryGroups.withOptionalUnsafeBufferPointer { sgroups in
                return _subprocess_spawn(
                    &pid, exePath,
                    &fileActions, &spawnAttributes,
                    argv, env,
                    uidPtr, gidPtr,
                    Int32(supplementaryGroups?.count ?? 0), sgroups?.baseAddress,
                    self.platformOptions.createSession ? 1 : 0
                )
            }
        }
        // Spawn error
        if spawnError != 0 {
            try self.cleanupAll(input: input, output: output, error: error)
            throw POSIXError(.init(rawValue: spawnError) ?? .ENODEV)
        }
        return Subprocess(
            processIdentifier: .init(value: pid),
            executionInput: input,
            executionOutput: output,
            executionError: error
        )
    }
}

// Special keys used in Error's user dictionary
extension String {
    static let debugDescriptionErrorKey = "NSDebugDescription"
}

// MARK: - Platform Specific Options
extension Subprocess {
    /// The collection of platform-specific configurations
    public struct PlatformOptions: Sendable {
        public var qualityOfService: QualityOfService = .default
        // Set user ID for the subprocess
        public var userID: Int? = nil
        // Set group ID for the subprocess
        public var groupID: Int? = nil
        // Set list of supplementary group IDs for the subprocess
        public var supplementaryGroups: [Int]? = nil
        // Creates a session and sets the process group ID
        // i.e. Detach from the terminal.
        public var createSession: Bool = false
        // Create a new process group
        public var createProcessGroup: Bool = false
        public var launchRequirementData: Data? = nil
        public var additionalSpawnAttributeConfigurator: (@Sendable (inout posix_spawnattr_t?) throws -> Void)?
        public var additionalFileAttributeConfigurator: (@Sendable (inout posix_spawn_file_actions_t?) throws -> Void)?

        public init(
            qualityOfService: QualityOfService,
            userID: Int?,
            groupID: Int?,
            supplementaryGroups: [Int]?,
            createSession: Bool,
            createProcessGroup: Bool,
            launchRequirementData: Data?
        ) {
            self.qualityOfService = qualityOfService
            self.userID = userID
            self.groupID = groupID
            self.supplementaryGroups = supplementaryGroups
            self.createSession = createSession
            self.createProcessGroup = createProcessGroup
            self.launchRequirementData = launchRequirementData
        }

        public static var `default`: Self {
            return .init(
                qualityOfService: .default,
                userID: nil,
                groupID: nil,
                supplementaryGroups: nil,
                createSession: false,
                createProcessGroup: false,
                launchRequirementData: nil
            )
        }
    }
}

#endif // canImport(Darwin)
