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
import Dispatch

extension Subprocess {
    public struct AsyncBytes: AsyncSequence, Sendable {
        @inline(__always) static var bufferSize: Int {
            16384
        }
        public typealias Element = UInt8

        @_nonSendable
        public struct Iterator: AsyncIteratorProtocol {
            public typealias Element = UInt8

            private let fileDescriptor: FileDescriptor
            private var buffer: [UInt8]
            private var currentPosition: Int
            private var finished: Bool

            internal init(fileDescriptor: FileDescriptor) {
                self.fileDescriptor = fileDescriptor
                self.buffer = []
                self.currentPosition = 0
                self.finished = false
            }

            private mutating func reloadBufferAndNext() async throws -> UInt8? {
                if self.finished {
                    return nil
                }
                try Task.checkCancellation()
                do {
                    self.buffer = try await self.fileDescriptor.read(
                        upToLength: AsyncBytes.bufferSize)
                    self.currentPosition = 0
                    if self.buffer.count < AsyncBytes.bufferSize {
                        self.finished = true
                    }
                } catch {
                    self.finished = true
                    throw error
                }
                return try await self.next()
            }

            public mutating func next() async throws -> UInt8? {
                if currentPosition < buffer.count {
                    let value = buffer[currentPosition]
                    self.currentPosition += 1
                    return value
                }
                return try await self.reloadBufferAndNext()
            }

            private func read(from fileDescriptor: FileDescriptor, maxLength: Int) async throws -> [UInt8] {
                return try await withCheckedThrowingContinuation { continuation in
                    DispatchIO.read(
                        fromFileDescriptor: fileDescriptor.rawValue,
                        maxLength: maxLength,
                        runningHandlerOn: .main
                    ) { data, error in
                        guard error == 0 else {
                            continuation.resume(
                                throwing: POSIXError(
                                    .init(rawValue: error) ?? .ENODEV)
                            )
                            return
                        }
                        continuation.resume(returning: Array(data))
                    }
                }
            }
        }

        private let fileDescriptor: FileDescriptor

        init(fileDescriptor: FileDescriptor) {
            self.fileDescriptor = fileDescriptor
        }

        public func makeAsyncIterator() -> Iterator {
            return Iterator(fileDescriptor: self.fileDescriptor)
        }
    }
}

extension RangeReplaceableCollection {
    /// Creates a new instance of a collection containing the elements of an asynchronous sequence.
    ///
    /// - Parameter source: The asynchronous sequence of elements for the new collection.
    @inlinable
    public init<Source: AsyncSequence>(_ source: Source) async rethrows where Source.Element == Element {
        self.init()
        for try await item in source {
            append(item)
        }
    }
}
