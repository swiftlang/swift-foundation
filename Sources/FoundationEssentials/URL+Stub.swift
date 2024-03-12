//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK

public struct URL : Hashable, Sendable, Codable {
    public let path: String
    
    enum DirectoryHint {
        case isDirectory
    }
    internal init(filePath: String, directoryHint: DirectoryHint = .isDirectory) {
        self.path = filePath
    }
    internal init(fileURLWithPath: String, isDirectory: Bool? = nil) {
        self.path = fileURLWithPath
    }
    
    // Temporary initializer, just to be able to stash URLs in things without any functionality.
    @_spi(SwiftCorelibsFoundation)
    public init(path: String) {
        self.path = path
    }
    
    public var isFileURL: Bool { true }
    public var lastPathComponent: String { path.lastPathComponent }
    public var scheme: String? { "file" }
    
    internal func path(percentEncoded: Bool = true) -> String { self.path }
    
    internal func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        try path.withFileSystemRepresentation(block)
    }
}

public struct URLResourceKey {}

#endif // !FOUNDATION_FRAMEWORK
