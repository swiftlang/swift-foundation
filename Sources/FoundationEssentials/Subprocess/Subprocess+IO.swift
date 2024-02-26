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

// MARK: - Input
extension Subprocess {
    public struct InputMethod: Sendable, Hashable {
        internal enum Storage: Sendable, Hashable {
            case noInput
            case fileDescriptor(FileDescriptor, Bool)
        }

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        internal func createExecutionInput() throws -> ExecutionInput {
            switch self.method {
            case .noInput:
                let devnull: FileDescriptor = try .open("/dev/null", .readOnly)
                return .noInput(devnull)
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .fileDescriptor(fileDescriptor, closeWhenDone)
            }
        }

        public static var noInput: Self {
            return .init(method: .noInput)
        }

        public static func readFrom(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self {
            return .init(method: .fileDescriptor(fd, closeWhenDone))
        }
    }
}

extension Subprocess {
    public struct CollectedOutputMethod: Sendable, Hashable {
        internal enum Storage: Sendable, Hashable {
            case discarded
            case fileDescriptor(FileDescriptor, Bool)
            case collected(Int)
        }

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        public static var discard: Self {
            return .init(method: .discarded)
        }

        public static var collect: Self {
            return .init(method: .collected(128 * 1024))
        }

        public static func writeTo(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self {
            return .init(method: .fileDescriptor(fd, closeWhenDone))
        }

        public static func collect(limit: Int) -> Self {
            return .init(method: .collected(limit))
        }

        internal func createExecutionOutput() throws -> ExecutionOutput {
            switch self.method {
            case .discarded:
                // Bind to /dev/null
                let devnull: FileDescriptor = try .open("/dev/null", .writeOnly)
                return .discarded(devnull)
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .fileDescriptor(fileDescriptor, closeWhenDone)
            case .collected(let limit):
                let (readFd, writeFd) = try FileDescriptor.pipe()
                return .collected(limit, readFd, writeFd)
            }
        }
    }

    public struct RedirectedOutputMethod: Sendable, Hashable {
        typealias Storage = CollectedOutputMethod.Storage

        internal let method: Storage

        internal init(method: Storage) {
            self.method = method
        }

        public static var discard: Self {
            return .init(method: .discarded)
        }

        public static var redirect: Self {
            return .init(method: .collected(128 * 1024))
        }

        public static func writeTo(_ fd: FileDescriptor, closeWhenDone: Bool) -> Self {
            return .init(method: .fileDescriptor(fd, closeWhenDone))
        }

        internal func createExecutionOutput() throws -> ExecutionOutput {
            switch self.method {
            case .discarded:
                // Bind to /dev/null
                let devnull: FileDescriptor = try .open("/dev/null", .writeOnly)
                return .discarded(devnull)
            case .fileDescriptor(let fileDescriptor, let closeWhenDone):
                return .fileDescriptor(fileDescriptor, closeWhenDone)
            case .collected(let limit):
                let (readFd, writeFd) = try FileDescriptor.pipe()
                return .collected(limit, readFd, writeFd)
            }
        }
    }
}

// MARK: - Execution IO
extension Subprocess {
    internal enum ExecutionInput {
        case noInput(FileDescriptor)
        case customWrite(FileDescriptor, FileDescriptor)
        case fileDescriptor(FileDescriptor, Bool)

        internal func getReadFileDescriptor() -> FileDescriptor {
            switch self {
            case .noInput(let readFd):
                return readFd
            case .customWrite(let readFd, _):
                return readFd
            case .fileDescriptor(let readFd, _):
                return readFd
            }
        }

        internal func getWriteFileDescriptor() -> FileDescriptor? {
            switch self {
            case .noInput(_), .fileDescriptor(_, _):
                return nil
            case .customWrite(_, let writeFd):
                return writeFd
            }
        }

        internal func closeChildSide() throws {
            switch self {
            case .noInput(let devnull):
                try devnull.close()
            case .customWrite(let readFd, _):
                try readFd.close()
            case .fileDescriptor(let fd, let closeWhenDone):
                // User passed in fd
                if closeWhenDone {
                    try fd.close()
                }
                break
            }
        }

        internal func closeParentSide() throws {
            switch self {
            case .noInput(_), .fileDescriptor(_, _):
                break
            case .customWrite(_, _):
                // The parent fd should have been closed
                // in the `body` when writer.finish() is called
                break
            }
        }

        internal func closeAll() throws {
            switch self {
            case .noInput(let readFd):
                try readFd.close()
            case .customWrite(let readFd, let writeFd):
                try readFd.close()
                try writeFd.close()
            case .fileDescriptor(let fd, _):
                try fd.close()
            }
        }
    }

    internal enum ExecutionOutput {
        case discarded(FileDescriptor)
        case fileDescriptor(FileDescriptor, Bool)
        case collected(Int, FileDescriptor, FileDescriptor)

        internal func getWriteFileDescriptor() -> FileDescriptor {
            switch self {
            case .discarded(let writeFd):
                return writeFd
            case .fileDescriptor(let writeFd, _):
                return writeFd
            case .collected(_, _, let writeFd):
                return writeFd
            }
        }

        internal func getReadFileDescriptor() -> FileDescriptor? {
            switch self {
            case .discarded(_), .fileDescriptor(_, _):
                return nil
            case .collected(_, let readFd, _):
                return readFd
            }
        }

        internal func closeChildSide() throws {
            switch self {
            case .discarded(let writeFd):
                try writeFd.close()
            case .fileDescriptor(let fd, let closeWhenDone):
                // User passed fd
                if closeWhenDone {
                    try fd.close()
                }
                break
            case .collected(_, _, let writeFd):
                try writeFd.close()
            }
        }

        internal func closeParentSide() throws {
            switch self {
            case .discarded(_), .fileDescriptor(_, _):
                break
            case .collected(_, let readFd, _):
                try readFd.close()
            }
        }

        internal func closeAll() throws {
            switch self {
            case .discarded(let writeFd):
                try writeFd.close()
            case .fileDescriptor(let fd, _):
                try fd.close()
            case .collected(_, let readFd, let writeFd):
                try readFd.close()
                try writeFd.close()
            }
        }
    }
}

// MARK: - Private Helpers
extension FileDescriptor {
    internal func read(upToLength maxLength: Int) throws -> [UInt8] {
        let buffer: UnsafeMutableBufferPointer<UInt8> = .allocate(capacity: maxLength)
        let readCount = try self.read(into: .init(buffer))
        let resizedBuffer: UnsafeBufferPointer<UInt8> = .init(start: buffer.baseAddress, count: readCount)
        return Array(resizedBuffer)
    }
}
