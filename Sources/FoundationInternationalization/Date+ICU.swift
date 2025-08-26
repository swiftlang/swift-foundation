//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal import _FoundationICU

#if canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Internal extensions on Date, for interop with ICU.
extension Date {
    /// Convert a Date into a UDate.
    /// UDate is defined as number of milliseconds since 1970 Jan 01, 00:00 UTC
    /// Date is defined as the number of seconds since 2001 Jan 01, 00:00 UTC (`Date`'s "reference date" and `CFAbsoluteTime`).
    var udate: UDate {
        timeIntervalSince1970 * 1000
    }

    /// Convert a Date into a UDate, to a precision of 1 second maximum.
    /// UDate is defined as number of milliseconds since 1970 Jan 01, 00:00 UTC
    /// Date is defined as the number of seconds since 2001 Jan 01, 00:00 UTC (`Date`'s "reference date" and `CFAbsoluteTime`).
    var udateInSeconds: UDate {
        (floor(timeIntervalSinceReferenceDate) + Date.timeIntervalBetween1970AndReferenceDate) * 1000
    }

    /// Convert a UDate into a Date.
    /// UDate is defined as number of milliseconds since 1970 Jan 01, 00:00 UTC.
    /// Date is defined as the number of seconds since 2001 Jan 01, 00:00 UTC (`Date`'s "reference date" and `CFAbsoluteTime`).
    init(udate: UDate) {
        self = Date(timeIntervalSince1970: udate / 1000)
    }
}
