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
        var lower: Int?
        var upper: Int?
        switch self {
        case let self as Range<Int>:
            let clamped = self.clamped(to: boundary)
            lower = clamped.lowerBound
            // Convert exclusive upper bound to inclusive maximum
            let (inclusiveUpper, overflow) = clamped.upperBound.subtractingReportingOverflow(1)
            upper = overflow ? clamped.upperBound : inclusiveUpper
        case let self as ClosedRange<Int>:
            let clamped = self.clamped(to: ClosedRange(boundary))
            lower = clamped.lowerBound
            upper = clamped.upperBound
        case let self as PartialRangeFrom<Int>:
            lower = max(self.lowerBound, boundary.lowerBound)
            upper = nil
        case let self as PartialRangeThrough<Int>:
            lower = nil
            // upperBound is already inclusive, but boundary.upperBound is exclusive
            // Convert boundary to inclusive for comparison
            let (inclusiveBoundaryUpper, overflow) = boundary.upperBound.subtractingReportingOverflow(1)
            let boundaryMax = overflow ? boundary.upperBound : inclusiveBoundaryUpper
            upper = min(self.upperBound, boundaryMax)
        case let self as PartialRangeUpTo<Int>:
            lower = nil
            let (val, overflow) = self.upperBound.subtractingReportingOverflow(1)
            // Convert boundary.upperBound from exclusive to inclusive for comparison
            let (inclusiveBoundaryUpper, boundaryOverflow) = boundary.upperBound.subtractingReportingOverflow(1)
            let boundaryMax = boundaryOverflow ? boundary.upperBound : inclusiveBoundaryUpper
            if overflow { // So small that we have no choice but treating self as PartialRangeThrough
                upper = min(self.upperBound, boundaryMax)
            } else {
                upper = min(val, boundaryMax)
            }
        default:
            lower = nil
            upper = nil
        }

        // Convert boundary.upperBound from exclusive to inclusive for comparison
        let (inclusiveBoundaryUpper, boundaryOverflow) = boundary.upperBound.subtractingReportingOverflow(1)
        let boundaryMax = boundaryOverflow ? boundary.upperBound : inclusiveBoundaryUpper

        if lower != nil {
            lower = min(lower!, boundaryMax)
        }

        if upper != nil {
            upper = max(upper!, boundary.lowerBound)
        }

        return (lower: lower, upper: upper)
    }
}
