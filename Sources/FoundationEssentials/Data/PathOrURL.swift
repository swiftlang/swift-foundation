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

internal enum PathOrURL {
    case path(String)
    case url(URL)
    
    func withFileSystemRepresentation<R>(_ block: (UnsafePointer<CChar>?) throws -> R) rethrows -> R {
        return try path.withFileSystemRepresentation(block)
    }

    func withMutableFileSystemRepresentation<R>(_ block: (UnsafeMutablePointer<CChar>?) throws -> R) rethrows -> R {
        return try path.withMutableFileSystemRepresentation(block)
    }

    var isEmpty: Bool {
        path.isEmpty
    }
    
    var path: String {
        switch self {
        case .path(let p): return p
        case .url(let u): return u.path
        }
    }
}
