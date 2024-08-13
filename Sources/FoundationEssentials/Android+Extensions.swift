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

#if os(Android) && (arch(i386) || arch(arm))
import Android

// struct stat.st_mode is UInt32
internal func &(left: UInt32, right: mode_t) -> mode_t {
    return mode_t(left) & right
}
#endif
