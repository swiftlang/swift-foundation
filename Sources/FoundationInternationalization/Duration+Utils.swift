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

// MARK: Rounding

extension Duration {
    func rounded(increment: Duration, rule: FloatingPointRoundingRule = .toNearestOrEven) -> Duration {
        rounded(rule, toMultipleOf: increment).value
    }

    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrEven, toMultipleOf increment: Duration) -> (value: Duration, roundsToEven: Bool) {
        let increment = abs(increment)
        let (truncated, truncatedCount) = roundedTowardZero(toMultipleOf: increment)
        let diffToTruncated = abs(abs(truncated) - abs(self))

        guard diffToTruncated != .zero else {
            return (self, truncatedCount % 2 == .zero)
        }

        let ceiled = truncated + (self < .zero ? .zero - increment : increment)
        let diffToCeiled = abs(abs(ceiled) - abs(self))

        let rounded: Duration
        switch rule {
        case .up:
            rounded = Swift.max(truncated, ceiled)
        case .down:
            rounded = Swift.min(truncated, ceiled)
        case .towardZero:
            rounded = truncated
        case .awayFromZero:
            rounded = ceiled
        case .toNearestOrAwayFromZero:
            if diffToTruncated < diffToCeiled {
                rounded = truncated
            } else {
                rounded = ceiled
            }
        case .toNearestOrEven:
            if diffToTruncated < diffToCeiled || diffToTruncated == diffToCeiled && truncatedCount % 2 == .zero {
                rounded = truncated
            } else {
                rounded = ceiled
            }
        @unknown default:
            fatalError()
        }

        return (rounded, (truncatedCount % 2 == .zero) == (rounded == truncated))
    }

    fileprivate static func % (_ lhs: Duration, _ rhs: Int64) -> Duration {
        lhs - ((lhs / rhs) * rhs)
    }

    fileprivate static func / (_ lhs: Duration, _ rhs: Int64) -> Duration {
        // Unfortunately, division between a Duration and an
        // Int64 is not implemented on 32 bit systems. We thus
        // repeatedly apply a floating point division until
        // the remainder is small enough to get a precise result.
        // This should take no more than three iterations because
        // Double has 52 fraction bits and Duration is 128 bits.
        #if arch(i386) || arch(arm) || arch(arm64_32) || arch(wasm32)
        let absSelf = abs(lhs)
        let absDivLower = abs(rhs)
        let absDiv = Duration(secondsComponent: 0, attosecondsComponent: absDivLower)
        var count = Duration.zero
        var remainder = abs(lhs)

        while abs(remainder) >= absDiv {
            count += .seconds(1e-18 * (remainder / absDiv))
            remainder = absSelf - (count * absDivLower)
        }

        if remainder < .zero {
            count -= .init(secondsComponent: 0, attosecondsComponent: 1)
        }

        return (lhs < .zero) != (rhs < .zero) ? .zero - count : count
        #else
        return lhs / (rhs as any BinaryInteger)
        #endif
    }

    private func roundedTowardZero(toMultipleOf divisor: Duration) -> (duration: Duration, count: Duration) {
        let absSelf = abs(self)
        let (s, _) = absSelf.components
        let absDiv = abs(divisor)
        let (ds, dattos) = absDiv.components

        let absCount: Duration
        let absValue: Duration

        if ds == 0 {
            absCount = absSelf / dattos
            absValue = absCount * dattos
        } else if dattos == 0 {
            absCount = .init(secondsComponent: 0, attosecondsComponent: s / ds)
            absValue = .init(secondsComponent: ds * (s / ds), attosecondsComponent: 0)
        } else if absSelf < absDiv {
            absCount = .zero
            absValue = .zero
        } else {
            // When reaching this branch, we know that absDiv is at least
            // one second, and that absSelf is even bigger.
            // This also means, that our result (theoretically) fits into
            // Int64, because wost case, we divide Int64.max seconds by
            // 1 second and 1 attosecond.

            // We first use the floating point based division provided by
            // the standard library to get an approximate count. Since
            // double cannot represent Int64.max at integer precision, but
            // rounds up to a higher number, we use UInt64, which can fit
            // even this rounded up number.
            let count = UInt64(absSelf / absDiv)

            // However, since Double only uses 52 bits to store the fraction,
            // our remainder can be (absolutely) bigger than absDiv. To get a
            // precise result, we do another floating point based division on
            // the remainder. Since the remainder is at most 2^(64-52) = 4096
            // big and absDiv is greater than 1, we know that the resulting
            // Double will have integer precision.
            let remainder = absSelf - (absDiv * count)
            let remainderCount = Int64(remainder / absDiv)

            absCount = .init(secondsComponent: 0, attosecondsComponent: 1) * count
                     + .init(secondsComponent: 0, attosecondsComponent: 1) * remainderCount
            absValue = absDiv * count
                     + absDiv * remainderCount
        }

        if (self < Self.zero) != (divisor < Self.zero) {
            return (.zero - absValue, .zero - absCount)
        } else {
            return (absValue, absCount)
        }
    }
}

// MARK: Utility

func abs(_ duration: Duration) -> Duration {
    duration < .zero ? Duration.zero - duration : duration
}
