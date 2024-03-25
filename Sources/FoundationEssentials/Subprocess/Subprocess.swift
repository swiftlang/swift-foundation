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

import SystemPackage

/// An object that represents a subprocess of the current process.
///
/// Using `Subprocess`, your program can run another program as a subprocess
/// and can monitor that program’s execution. A `Subprocess` object creates a
/// **separate executable** entity; it’s different from `Thread` because it doesn’t
/// share memory space with the process that creates it.
public struct Subprocess: Sendable {
    /// The process identifier of the current subprocess
    public let processIdentifier: ProcessIdentifier

    internal let executionInput: ExecutionInput
    internal let executionOutput: ExecutionOutput
    internal let executionError: ExecutionOutput
    internal var extracted: Bool = false

    internal init(
        processIdentifier: ProcessIdentifier,
        executionInput: ExecutionInput,
        executionOutput: ExecutionOutput,
        executionError: ExecutionOutput
    ) {
        self.processIdentifier = processIdentifier
        self.executionInput = executionInput
        self.executionOutput = executionOutput
        self.executionError = executionError
    }

    /// The standard output of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.output` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardOutput: some _AsyncSequence<UInt8, any Error> {
        guard let (_, fd) = self.executionOutput
            .consumeCollectedFileDescriptor() else {
            fatalError("The standard output was not redirected")
        }
        guard let fd = fd else {
            fatalError("The standard output has already been closed")
        }
        return AsyncBytes(fileDescriptor: fd)
    }

    /// The standard error of the subprocess.
    /// Accessing this property will **fatalError** if
    /// - `.error` wasn't set to `.redirectToSequence` when the subprocess was spawned;
    /// - This property was accessed multiple times. Subprocess communicates with
    ///   parent process via pipe under the hood and each pipe can only be consumed ones.
    public var standardError: some _AsyncSequence<UInt8, any Error> {
        guard let (_, fd) = self.executionError
            .consumeCollectedFileDescriptor() else {
            fatalError("The standard error was not redirected")
        }
        guard let fd = fd else {
            fatalError("The standard error has already been closed")
        }
        return AsyncBytes(fileDescriptor: fd)
    }
}

// MARK: - StandardInputWriter
extension Subprocess {
    @_nonSendable
    public struct StandardInputWriter {

        private let input: ExecutionInput

        init(input: ExecutionInput) {
            self.input = input
        }

        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == UInt8 {
            guard let fd: FileDescriptor = self.input.getWriteFileDescriptor() else {
                fatalError("Attempting to write to a file descriptor that's already closed")
            }
            try await fd.write(sequence)
        }

        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == CChar {
            try await self.write(sequence.map { UInt8($0) })
        }

        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == CChar {
            let sequence = try await Array(asyncSequence).map { UInt8($0) }
            try await self.write(sequence)
        }

        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == UInt8 {
            let sequence = try await Array(asyncSequence)
            try await self.write(sequence)
        }

        public func finish() async throws {
            try self.input.closeParentSide()
        }
    }
}

// MARK: - Result
extension Subprocess {
    public struct ExecutionResult<T: Sendable>: Sendable {
        public let terminationStatus: TerminationStatus
        public let value: T

        internal init(terminationStatus: TerminationStatus, value: T) {
            self.terminationStatus = terminationStatus
            self.value = value
        }
    }

    public struct CollectedResult: Sendable, Hashable {
        public let processIdentifier: ProcessIdentifier
        public let terminationStatus: TerminationStatus
        private let _standardOutput: Data?
        private let _standardError: Data?
        public var standardOutput: Data {
            guard let output = self._standardOutput else {
                fatalError("standardOutput is only available if the Subprocess was ran with .collect as output")
            }
            return output
        }
        public var standardError: Data {
            guard let output = self._standardError else {
                fatalError("standardError is only available if the Subprocess was ran with .collect as error ")
            }
            return output
        }

        internal init(
            processIdentifier: ProcessIdentifier,
            terminationStatus: TerminationStatus,
            standardOutput: Data?,
            standardError: Data?) {
            self.processIdentifier = processIdentifier
            self.terminationStatus = terminationStatus
            self._standardOutput = standardOutput
            self._standardError = standardError
        }
    }
}

extension Subprocess.ExecutionResult: Equatable where T : Equatable {}

extension Subprocess.ExecutionResult: Hashable where T : Hashable {}

extension Subprocess.ExecutionResult: Codable where T : Codable {}

// MARK: Internal
extension Subprocess {
    internal enum OutputCapturingState {
        case standardOutputCaptured(Data?)
        case standardErrorCaptured(Data?)
    }

    private func capture(fileDescriptor: FileDescriptor, maxLength: Int) async throws -> Data{
        let chunkSize: Int = min(Subprocess.readBufferSize, maxLength)
        var buffer: [UInt8] = []
        while buffer.count <= maxLength {
            let captured = try await fileDescriptor.read(upToLength: chunkSize)
            buffer += captured
            if captured.count < chunkSize {
                break
            }
        }
        return Data(buffer)
    }

    internal func captureStandardOutput() async throws -> Data? {
        guard let (limit, readFd) = self.executionOutput
            .consumeCollectedFileDescriptor(),
              let readFd = readFd else {
            return nil
        }
        return try await self.capture(fileDescriptor: readFd, maxLength: limit)
    }

    internal func captureStandardError() async throws -> Data? {
        guard let (limit, readFd) = self.executionError
            .consumeCollectedFileDescriptor(),
              let readFd = readFd else {
            return nil
        }
        return try await self.capture(fileDescriptor: readFd, maxLength: limit)
    }

    internal func captureIOs() async throws -> (standardOut: Data?, standardError: Data?) {
        return try await withThrowingTaskGroup(of: OutputCapturingState.self) { group in
            group.addTask {
                let stdout = try await self.captureStandardOutput()
                return .standardOutputCaptured(stdout)
            }
            group.addTask {
                let stderr = try await self.captureStandardError()
                return .standardErrorCaptured(stderr)
            }
            
            var stdout: Data?
            var stderror: Data?
            while let state = try await group.next() {
                switch state {
                case .standardOutputCaptured(let output):
                    stdout = output
                case .standardErrorCaptured(let error):
                    stderror = error
                }
            }
            return (standardOut: stdout, standardError: stderror)
        }
    }
}
