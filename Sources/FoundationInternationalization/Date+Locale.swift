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

extension Date {
#if !FOUNDATION_FRAMEWORK
    /**
     Returns a string representation of the receiver using the given
     locale.

     - Parameter locale: A `Locale`. If you pass `nil`, `Date` formats the date in the same way as the `description` property.

     - Returns: A string representation of the `Date`, using the given locale, or if the locale argument is `nil`, in the international format `YYYY-MM-DD HH:MM:SS ±HHMM`, where `±HHMM` represents the time zone offset in hours and minutes from UTC (for example, "`2001-03-24 10:45:32 +0600`").
     */
    public func description(with locale: Locale?) -> String {
        // FIXME: Use DateFormatStyle once implemented
        return description
    }
#endif // !FOUNDATION_FRAMEWORK
}
