//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

internal extension RangeExpression {
    func clampedLowerAndUpperBounds(_ boundary: Range<Int>) -> (lower: Int?, upper: Int?) {
        // Boundary should never be empty because there must be at least one valid value
        // Assuming boundary is non-empty allows us to increment its lowerBound or decrement its upperBound below without overflows
        assert(!boundary.isEmpty)

        switch self {
        case let self as Range<Int>:
            let clamped = self.clamped(to: boundary)
            if clamped.isEmpty {
                // If the range is empty, we have no choice but to treat it as a requirement for the closest valid value in boundary
                if clamped.lowerBound == boundary.upperBound {
                    return (boundary.upperBound - 1, boundary.upperBound - 1)
                } else {
                    return (clamped.lowerBound, clamped.lowerBound)
                }
            } else {
                // We can safely subtract 1 from clamped.upperBound below because we know that clamped.upperBound > boundary.lowerBound
                return (clamped.lowerBound, clamped.upperBound - 1)
            }
        case let self as ClosedRange<Int>:
            let clamped = self.clamped(to: ClosedRange(boundary))
            return (clamped.lowerBound, clamped.upperBound)
        case let self as PartialRangeFrom<Int>:
            let clamped = min(max(self.lowerBound, boundary.lowerBound), boundary.upperBound - 1)
            return (clamped, nil)
        case let self as PartialRangeThrough<Int>:
            let clamped = min(max(self.upperBound, boundary.lowerBound), boundary.upperBound - 1)
            return (nil, clamped)
        case let self as PartialRangeUpTo<Int>:
            let clamped = min(max(self.upperBound, boundary.lowerBound + 1), boundary.upperBound)
            // We can safely subtract 1 from clamped below because we know that clamped > boundary.lowerBound
            return (nil, clamped - 1)
        default:
            return (nil, nil)
        }
    }
}
