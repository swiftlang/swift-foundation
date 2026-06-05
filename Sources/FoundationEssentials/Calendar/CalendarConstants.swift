//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Time-unit constants shared across calendar implementations.
internal enum _CalendarConstants {
    static let kSecondsInWeek = 604_800
    static let kSecondsInDay = 86400
    static let kSecondsInHour = 3600
    static let kSecondsInMinute = 60

    /// Sentinel used by unbounded-range loops in date arithmetic.
    static let inf_ti: TimeInterval = 4398046511104.0
}
