//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Adopted by types which can provide a file system representation, for use in reading paths on disk.
internal protocol FileSystemRepresentable: ~Copyable {
    func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R
    func errorWithFilePath(errno: Int32, reading: Bool, variant: String?, source: String?, destination: String?, debugDescription: String?) -> CocoaError
    var isEmpty: Bool { get }
    var path: String { get }
}

extension URL: FileSystemRepresentable {
    func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        try self.withUnsafeFileSystemRepresentation(block)
    }
    func errorWithFilePath(errno: Int32, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil, debugDescription: String? = nil) -> CocoaError {
        CocoaError(CocoaError.Code(fileErrno: errno, reading: reading), url: self, underlying: POSIXError(errno: errno), variant: variant, source: source, destination: destination, debugDescription: debugDescription)
    }
    var isEmpty: Bool {
        // URLs can't really be empty; even a URL(fileURLWithPath: "") has a path of "./".
        // Avoid converting the URL to a string here just to return false.
        false
    }
}

extension String: FileSystemRepresentable {
    func errorWithFilePath(errno: Int32, reading: Bool, variant: String? = nil, source: String? = nil, destination: String? = nil, debugDescription: String? = nil) -> CocoaError {
        CocoaError(CocoaError.Code(fileErrno: errno, reading: reading), path: self, underlying: POSIXError(errno: errno), variant: variant, source: source, destination: destination, debugDescription: debugDescription)
    }
    var path: String { self }
}
