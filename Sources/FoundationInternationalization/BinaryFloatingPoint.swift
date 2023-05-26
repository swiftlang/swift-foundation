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

extension BinaryFloatingPoint {

    var parts: (whole: Int64, nano: Int64) {
        let whole = self.rounded(.towardZero)
        let remainder = self - whole
        let nano = Int64(remainder * 1_000_000_000)
        return (Int64(whole), nano)
    }

    func rounded<T: BinaryFloatingPoint>(increment: T, rule: FloatingPointRoundingRule) -> Self {
        guard increment != 0 else {
            return self
        }

        return (self / Self(increment)).rounded(rule) * Self(increment)
    }

    func rounded<T: BinaryFloatingPoint, T2: BinaryInteger>(increment: T, base: T2, rule: FloatingPointRoundingRule) -> (whole: Int64, nano: Int64) {
        let roundedInBase = ((self / Self(base)).rounded(increment: increment, rule: rule)) * Self(base)
        return roundedInBase.parts
    }

    func roundedToPrecision<T: BinaryInteger, T2: BinaryInteger>(_ precision: T, base: T2, rule: FloatingPointRoundingRule) -> (whole: Int64, nano: Int64) {
        let base = Double(base)
        let selfInBase = Double(self) / base
        let divisor = pow(10, Double(precision))

        guard divisor != 0 && !divisor.isInfinite else {
            return self.parts
        }

        let rounded = ((selfInBase * divisor).rounded(rule) / divisor) * base
        return rounded.parts
    }
}
