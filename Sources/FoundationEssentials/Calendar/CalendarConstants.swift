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

extension Calendar {
    /// Time unit constants shared across calendar implementations.
    static let _secondsInWeek = 604_800
    static let _secondsInDay = 86400
    static let _secondsInHour = 3600
    static let _secondsInMinute = 60

    /// Upper bound for date interval durations in unbounded range loops.
    static let _maxDateIntervalDuration: TimeInterval = 4398046511104.0
}
