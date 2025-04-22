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

#if os(WASI)

@preconcurrency import WASILibc
internal import _FoundationCShims

// MARK: - Clock

internal var CLOCK_REALTIME: clockid_t {
    return _platform_shims_clock_realtime()
}

internal var CLOCK_MONOTONIC: clockid_t {
    return _platform_shims_clock_monotonic()
}

internal var CLOCK_MONOTONIC_RAW: clockid_t {
    // WASI does not have a raw monotonic clock, so we use the monotonic clock instead.
    return CLOCK_MONOTONIC
}

// MARK: - File Operations

internal var DT_DIR: UInt8 {
    return _platform_shims_DT_DIR()
}
internal var DT_UNKNOWN: UInt8 {
    return _platform_shims_DT_UNKNOWN()
}
internal var O_CREAT: Int32 {
    return _platform_shims_O_CREAT()
}
internal var O_EXCL: Int32 {
    return _platform_shims_O_EXCL()
}
internal var O_TRUNC: Int32 {
    return _platform_shims_O_TRUNC()
}
internal var O_WRONLY: Int32 {
    return _platform_shims_O_WRONLY()
}
internal var O_NONBLOCK: Int32 {
    return _platform_shims_O_NONBLOCK()
}
internal var O_RDONLY: Int32 {
    return _platform_shims_O_RDONLY()
}
internal var O_DIRECTORY: Int32 {
    return _platform_shims_O_DIRECTORY()
}
internal var O_NOFOLLOW: Int32 {
    return _platform_shims_O_NOFOLLOW()
}

#endif // os(WASI)
