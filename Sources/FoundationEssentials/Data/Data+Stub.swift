//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK

// Placeholder for Progress
internal final class Progress {
    var completedUnitCount: Int64
    var totalUnitCount: Int64
    
    init(totalUnitCount: Int64) {
        self.completedUnitCount = 0
        self.totalUnitCount = totalUnitCount
    }
    
    func becomeCurrent(withPendingUnitCount: Int64) { }
    func resignCurrent() { }
    var isCancelled: Bool { false }
    static func current() -> Progress? { nil }
    var fractionCompleted: Double {
        0.0
    }
}

#endif // !FOUNDATION_FRAMEWORK

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
        case .url(let u): return u.path(percentEncoded: false)
        }
    }
}
