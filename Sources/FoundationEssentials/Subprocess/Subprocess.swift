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

public struct Subprocess: Sendable {
    public let processIdentifier: ProcessIdentifier

    internal let executionInput: ExecutionInput
    internal let executionOutput: ExecutionOutput
    internal let executionError: ExecutionOutput

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

    public var standardOutput: AsyncBytes? {
        switch self.executionOutput {
        case .discarded(_), .fileDescriptor(_, _):
            // The output has been written somewhere else
            return nil
        case .collected(_, let readFd, _):
            return AsyncBytes(fileDescriptor: readFd)
        }
    }

    public var standardError: AsyncBytes? {
        switch self.executionError {
        case .discarded(_), .fileDescriptor(_, _):
            // The output has been written somewhere else
            return nil
        case .collected(_, let readFd, _):
            return AsyncBytes(fileDescriptor: readFd)
        }
    }

    internal func captureStandardOutput() throws -> Data? {
        guard case .collected(let limit, let readFd, _) = self.executionOutput else {
            return nil
        }
        let captured = try readFd.read(upToLength: limit)
        return Data(captured)
    }

    internal func captureStandardError() throws -> Data? {
        guard case .collected(let limit, let readFd, _) = self.executionError else {
            return nil
        }
        let captured = try readFd.read(upToLength: limit)
        return Data(captured)
    }
}

// MARK: - StandardInputWriter
extension Subprocess {
    internal actor StandardInputWriterActor {
        private let fileDescriptor: FileDescriptor

        internal init(fileDescriptor: FileDescriptor) {
            self.fileDescriptor = fileDescriptor
        }

        @discardableResult
        public func write<S>(_ sequence: S) async throws -> Int where S : Sequence, S.Element == UInt8 {
            return try self.fileDescriptor.writeAll(sequence)
        }

        @discardableResult
        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws -> Int where S.Element == UInt8 {
            let sequence = try await Array(asyncSequence)
            return try self.fileDescriptor.writeAll(sequence)
        }

        public func finish() async throws {
            try self.fileDescriptor.close()
        }
    }

    public struct StandardInputWriter: Sendable {

        private let actor: StandardInputWriterActor

        init(fileDescriptor: FileDescriptor) {
            self.actor = StandardInputWriterActor(fileDescriptor: fileDescriptor)
        }

        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == UInt8 {
            try await self.actor.write(sequence)
        }

        public func write<S>(_ sequence: S) async throws where S : Sequence, S.Element == CChar {
            try await self.actor.write(sequence.map { UInt8($0) })
        }

        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == CChar {
            let sequence = try await Array(asyncSequence).map { UInt8($0) }
            try await self.actor.write(sequence)
        }

        public func write<S: AsyncSequence>(_ asyncSequence: S) async throws where S.Element == UInt8 {
            let sequence = try await Array(asyncSequence)
            try await self.actor.write(sequence)
        }

        public func finish() async throws {
            try await self.actor.finish()
        }
    }
}

// MARK: - Result
extension Subprocess {
    public struct Result<T: Sendable>: Sendable {
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
        public let standardOutput: Data?
        public let standardError: Data?

        internal init(
            processIdentifier: ProcessIdentifier,
            terminationStatus: TerminationStatus,
            standardOutput: Data?,
            standardError: Data?) {
            self.processIdentifier = processIdentifier
            self.terminationStatus = terminationStatus
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }
}


extension Subprocess.Result: Equatable where T : Equatable {}

extension Subprocess.Result: Hashable where T : Hashable {}

extension POSIXError : Swift.Error {}
