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

extension BinaryFloatingPoint {
    func rounded<T: BinaryFloatingPoint>(increment: T, rule: FloatingPointRoundingRule) -> Self {
        guard increment != 0 else {
            return self
        }

        return (self / Self(increment)).rounded(rule) * Self(increment)
    }
}
