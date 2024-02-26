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

#if canImport(Glibc)

import Glibc
import SystemPackage
import FoundationEssentials
package import _CShims

// Linux specific implementations
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
             uidPtr, gidPtr,
             supplementaryGroups
        ) = try self.preSpawn()
        defer {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            uidPtr?.deallocate()
            gidPtr?.deallocate()
        }

        let fileDescriptors: [CInt] = [
            input.getReadFileDescriptor().rawValue, input.getWriteFileDescriptor()?.rawValue ?? 0,
            output.getWriteFileDescriptor().rawValue, output.getReadFileDescriptor()?.rawValue ?? 0,
            error.getWriteFileDescriptor().rawValue, error.getReadFileDescriptor()?.rawValue ?? 0
        ]

        var workingDirectory: String?
        if intendedWorkingDir != FilePath.currentWorkingDirectory {
            // Only pass in working directory if it's different
            workingDirectory = intendedWorkingDir.string
        }
        // Spawn
        var pid: pid_t = 0
        let spawnError: CInt = executablePath.withCString { exePath in
            return workingDirectory.withOptionalCString { workingDir in
                return supplementaryGroups.withOptionalUnsafeBufferPointer { sgroups in
                    return fileDescriptors.withUnsafeBufferPointer { fds in
                        return _subprocess_fork_exec(
                            &pid, exePath, workingDir,
                            fds.baseAddress!,
                            argv, env,
                            uidPtr, gidPtr,
                            CInt(supplementaryGroups?.count ?? 0), sgroups?.baseAddress,
                            self.platformOptions.createSession ? 1 : 0,
                            self.platformOptions.createProcessGroup ? 1 : 0
                        )
                    }
                }
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

// MARK: - Platform Specific Options
extension Subprocess {
    public struct PlatformOptions: Sendable {
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
        // This callback is run after `fork` but before `exec`.
        // Use it to perform any custom process setup
        public var customProcessConfigurator: (@Sendable () -> Void)? = nil

        public init(
            userID: Int?,
            groupID: Int?,
            supplementaryGroups: [Int]?,
            createSession: Bool,
            createProcessGroup: Bool
        ) {
            self.userID = userID
            self.groupID = groupID
            self.supplementaryGroups = supplementaryGroups
            self.createSession = createSession
            self.createProcessGroup = createProcessGroup
        }

        public static var `default`: Self {
            return .init(
                userID: nil,
                groupID: nil,
                supplementaryGroups: nil,
                createSession: false,
                createProcessGroup: false
            )
        }
    }
}

// Special keys used in Error's user dictionary
extension String {
    static let debugDescriptionErrorKey = "DebugDescription"
}


#endif // canImport(Glibc)
