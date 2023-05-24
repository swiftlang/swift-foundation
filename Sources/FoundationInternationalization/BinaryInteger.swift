//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

extension FixedWidthInteger {

    func roundedToSignificantDigits<T: BinaryInteger>(_ d: T, rule: FloatingPointRoundingRule) -> Self {
        guard d > 0 else {
            return self
        }

        let p = log10(abs(Double(self))).rounded(.towardZero)
        let inc = Self(pow(10, p - Double(d) + 1))
        let num = rounded(increment: inc, rule: rule)
        return Self(num)
    }

    func rounded<T: FixedWidthInteger>(increment: T, rule: FloatingPointRoundingRule) -> Self {
        guard increment != 0 else {
            return self
        }

        var increment = Self(increment)
        if increment.signum() == -1 {
            let (abs, overflow) = Self(0).subtractingReportingOverflow(increment)
            increment = overflow ? .max : abs
        }

        let (_, remainder) = quotientAndRemainder(dividingBy: increment)
        if remainder == 0 {
            return self
        }

        let rounded: Self
        let down: Self
        let up: Self
        let topDist: Self
        let downDist: Self
        if signum() == 1 {
            down = self - remainder
            let (added, overflow) = down.addingReportingOverflow(increment)
            up = overflow ? .max : added

            topDist = increment - remainder
            downDist = remainder
        } else {
            up = self - remainder
            let (d, overflow) = up.subtractingReportingOverflow(increment)
            down = overflow ? .min : d

            topDist = 0 - remainder
            let (dist, overflow2) = increment.addingReportingOverflow(remainder)
            downDist = overflow2 ? .max : dist
        }

        switch rule {
        case .toNearestOrAwayFromZero:
            if signum() == 1 {
                rounded = topDist > remainder ? down : up
            } else {
                rounded = topDist >= downDist ? down : up
            }

        case .toNearestOrEven:
            // This idea doesn't always make sense: when rounding 25 to increment of 10, both candidates 30 and 20 are even. In this case we mimic what floating point rounding does
            if topDist > downDist {
                rounded = down
            } else if topDist < downDist {
                rounded = up
            } else {
                if (down / increment).isMultiple(of: 2) {
                    rounded = down
                } else {
                    rounded = up
                }
            }

        case .up:
            rounded = up
        case .down:
            rounded = down
        case .towardZero:
            rounded = signum() == 1 ? down : up
        case .awayFromZero:
            rounded = signum() == 1 ? up : down
        @unknown default:
            rounded = down
        }

        return rounded
    }
}
