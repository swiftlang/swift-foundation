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

#if canImport(Darwin) || canImport(Glibc)


#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import SystemPackage

#if FOUNDATION_FRAMEWORK
@_implementationOnly import _CShims
#else
package import _CShims
#endif


// MARK: - Signals
extension Subprocess {
    public struct Signal : Hashable, Sendable {
        public let rawValue: Int32

        private init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static var interrupt: Self { .init(rawValue: SIGINT) }
        public static var terminate: Self { .init(rawValue: SIGTERM) }
        public static var suspend: Self { .init(rawValue: SIGSTOP) }
        public static var resume: Self { .init(rawValue: SIGCONT) }
        public static var kill: Self { .init(rawValue: SIGKILL) }
        public static var terminalClosed: Self { .init(rawValue: SIGHUP) }
        public static var quit: Self { .init(rawValue: SIGQUIT) }
        public static var userDefinedOne: Self { .init(rawValue: SIGUSR1) }
        public static var userDefinedTwo: Self { .init(rawValue: SIGUSR2) }
        public static var alarm: Self { .init(rawValue: SIGALRM) }
        public static var windowSizeChange: Self { .init(rawValue: SIGWINCH) }
    }

    public func sendSignal(_ signal: Signal, toProcessGroup shouldSendToProcessGroup: Bool) throws {
        let pid = shouldSendToProcessGroup ? -(self.processIdentifier.value) : self.processIdentifier.value
        guard kill(pid, signal.rawValue) == 0 else {
            throw POSIXError(.init(rawValue: errno)!)
        }
    }
}

// MARK: Environment Resolution
extension Subprocess.Environment {
    internal static let pathEnvironmentVariableName = "PATH"

    internal func pathValue() -> String? {
        switch self.config {
        case .inherit(let overrides):
            // If PATH value exists in overrides, use it
            if let value = overrides[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            // Fall back to current process
            return ProcessInfo.processInfo.environment[Self.pathEnvironmentVariableName]
        case .custom(let fullEnvironment):
            if let value = fullEnvironment[.string(Self.pathEnvironmentVariableName)] {
                return value.stringValue
            }
            return nil
        }
    }

    // This method follows the standard "create" rule: `env` needs to be
    // manually deallocated
    internal func createEnv() -> [UnsafeMutablePointer<CChar>?] {
        func createFullCString(
            fromKey keyContainer: Subprocess.StringOrRawBytes,
            value valueContainer: Subprocess.StringOrRawBytes
        ) -> UnsafeMutablePointer<CChar> {
            let rawByteKey: UnsafeMutablePointer<CChar> = keyContainer.createRawBytes()
            let rawByteValue: UnsafeMutablePointer<CChar> = valueContainer.createRawBytes()
            defer {
                rawByteKey.deallocate()
                rawByteValue.deallocate()
            }
            /// length = `key` + `=` + `value` + `\null`
            let totalLength = keyContainer.count + 1 + valueContainer.count + 1
            let fullString: UnsafeMutablePointer<CChar> = .allocate(capacity: totalLength)
            #if canImport(Darwin)
            _ = snprintf(ptr: fullString, totalLength, "%s=%s", rawByteKey, rawByteValue)
            #else
            _ = _shims_snprintf(fullString, CInt(totalLength), "%s=%s", rawByteKey, rawByteValue)
            #endif
            return fullString
        }

        var env: [UnsafeMutablePointer<CChar>?] = []
        switch self.config {
        case .inherit(let updates):
            var current = ProcessInfo.processInfo.environment
            for (keyContainer, valueContainer) in updates {
                if let stringKey = keyContainer.stringValue {
                    // Remove the value from current to override it
                    current.removeValue(forKey: stringKey)
                }
                // Fast path
                if case .string(let stringKey) = keyContainer,
                   case .string(let stringValue) = valueContainer {
                    let fullString = "\(stringKey)=\(stringValue)"
                    env.append(strdup(fullString))
                    continue
                }

                env.append(createFullCString(fromKey: keyContainer, value: valueContainer))
            }
            // Add the rest of `current` to env
            for (key, value) in current {
                let fullString = "\(key)=\(value)"
                env.append(strdup(fullString))
            }
        case .custom(let customValues):
            for (keyContainer, valueContainer) in customValues {
                // Fast path
                if case .string(let stringKey) = keyContainer,
                   case .string(let stringValue) = valueContainer {
                    let fullString = "\(stringKey)=\(stringValue)"
                    env.append(strdup(fullString))
                    continue
                }
                env.append(createFullCString(fromKey: keyContainer, value: valueContainer))
            }
        }
        env.append(nil)
        return env
    }
}

// MARK: Args Creation
extension Subprocess.Arguments {
    // This method follows the standard "create" rule: `args` needs to be
    // manually deallocated
    internal func createArgs(withExecutablePath executablePath: String) -> [UnsafeMutablePointer<CChar>?] {
        var argv: [UnsafeMutablePointer<CChar>?] = self.storage.map { $0.createRawBytes() }
        // argv[0] = executable path
        if let override = self.executablePathOverride {
            argv.insert(override.createRawBytes(), at: 0)
        } else {
            argv.insert(strdup(executablePath), at: 0)
        }
        argv.append(nil)
        return argv
    }
}

// MARK: -  Executable Searching
extension Subprocess.Executable {
    internal static var defaultSearchPaths: Set<String> {
        return Set([
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/usr/local/bin"
        ])
    }

    internal func resolveExecutablePath(withPathValue pathValue: String?) -> String? {
        switch self.storage {
        case .executable(let executableName):
            // If the executableName in is already a full path, return it directly
            if Subprocess.Configuration.pathAccessible(executableName, mode: X_OK) {
                return executableName
            }
            // Get $PATH from environment
            let searchPaths: Set<String>
            if let pathValue = pathValue {
                let localSearchPaths = pathValue.split(separator: ":").map { String($0) }
                searchPaths = Set(localSearchPaths).union(Self.defaultSearchPaths)
            } else {
                searchPaths = Self.defaultSearchPaths
            }

            for path in searchPaths {
                let fullPath = "\(path)/\(executableName)"
                let fileExists = Subprocess.Configuration.pathAccessible(fullPath, mode: X_OK)
                if fileExists {
                    return fullPath
                }
            }
        case .path(let executablePath):
            // Use path directly
            return executablePath.string
        }
        return nil
    }
}

// MARK: - Configuration
extension Subprocess.Configuration {
    internal func preSpawn() throws -> (
        executablePath: String,
        env: [UnsafeMutablePointer<CChar>?],
        argv: [UnsafeMutablePointer<CChar>?],
        intendedWorkingDir: FilePath,
        uidPtr: UnsafeMutablePointer<uid_t>?,
        gidPtr: UnsafeMutablePointer<gid_t>?,
        supplementaryGroups: [gid_t]?
    ) {
        // Prepare environment
        let env = self.environment.createEnv()
        // Prepare executable path
        guard let executablePath = self.executable.resolveExecutablePath(
            withPathValue: self.environment.pathValue()) else {
            for ptr in env { ptr?.deallocate() }
            throw CocoaError(.executableNotLoadable, userInfo: [
                .debugDescriptionErrorKey : "\(self.executable.description) is not an executable"
            ])
        }
        // Prepare arguments
        let argv: [UnsafeMutablePointer<CChar>?] = self.arguments.createArgs(withExecutablePath: executablePath)
        // Prepare workingDir
        let intendedWorkingDir = self.workingDirectory
        guard Self.pathAccessible(intendedWorkingDir.string, mode: F_OK) else {
            for ptr in env { ptr?.deallocate() }
            for ptr in argv { ptr?.deallocate() }
            throw CocoaError(.fileNoSuchFile, userInfo: [
                .debugDescriptionErrorKey : "Failed to set working directory to \(intendedWorkingDir)"
            ])
        }

        var uidPtr: UnsafeMutablePointer<uid_t>? = nil
        if let userID = self.platformOptions.userID {
            uidPtr = .allocate(capacity: 1)
            uidPtr?.pointee = uid_t(userID)
        }
        var gidPtr: UnsafeMutablePointer<gid_t>? = nil
        if let groupID = self.platformOptions.groupID {
            gidPtr = .allocate(capacity: 1)
            gidPtr?.pointee = gid_t(groupID)
        }
        var supplementaryGroups: [gid_t]?
        if let groupsValue = self.platformOptions.supplementaryGroups {
            supplementaryGroups = groupsValue.map { gid_t($0) }
        }
        return (
            executablePath: executablePath,
            env: env, argv: argv,
            intendedWorkingDir: intendedWorkingDir,
            uidPtr: uidPtr, gidPtr: gidPtr,
            supplementaryGroups: supplementaryGroups
        )
    }

    internal static func pathAccessible(_ path: String, mode: Int32) -> Bool {
        return path.withCString {
            return access($0, mode) == 0
        }
    }
}

// MARK: - Process Monitoring
@Sendable
internal func monitorProcessTermination(
    forProcessWithIdentifier pid: Subprocess.ProcessIdentifier
) -> Subprocess.TerminationStatus {
    var status: Int32 = -1
    // Block and wait
    waitpid(pid.value, &status, 0)
    if _was_process_exited(status) != 0 {
        return .exit(_get_exit_code(status))
    }
    if _was_process_signaled(status) != 0 {
        return .unhandledException(_get_signal_code(status))
    }
    fatalError("Unexpected exit status type: \(status)")
}

#endif // canImport(Darwin) || canImport(Glibc)
