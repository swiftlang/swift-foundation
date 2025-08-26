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

#if FOUNDATION_FRAMEWORK

internal import os

/// Wrapper for OSLog until it is marked as Sendable.
package struct SendableOSLog : @unchecked Sendable {
    init(_ log: OSLog) { self.log = log }
    let log: OSLog
}

#endif
