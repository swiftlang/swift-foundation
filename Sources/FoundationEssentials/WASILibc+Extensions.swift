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

import WASILibc
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

#endif // os(WASI)
