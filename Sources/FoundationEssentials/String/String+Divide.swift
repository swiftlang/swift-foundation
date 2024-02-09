//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension String {
    /// Extension on String to calculate the remainder value of two strings.
    ///
    /// This extension allows you to calculate the remainder when dividing one string
    /// (representing a decimal number) by another string (representing the divisor).
    /// The strings are internally converted to NSDecimalNumber for precision.
    ///
    /// - Parameters:
    ///   - lhs: The dividend as a string (decimalNumber).
    ///   - rhs: The divisor as a string.
    ///
    /// - Returns: The remainder as an integer.
    ///
    /// Example:
    /// ```
    /// let remainder = "20.5" % "3"
    /// print("Remainder: \(remainder)")  // Output: 2
    /// ```
    ///
    /// - Note: The decimal parts are truncated during the conversion.
    ///
    /// - Warning: Ensure that the input strings represent valid decimal numbers,
    ///   as using non-numeric strings may result in unexpected behavior.
    static func %(lhs: String, rhs: String) -> Int {
        let decimalNumber = NSDecimalNumber(string: lhs)
        let divisor = NSDecimalNumber(string: rhs)
        let quotient = decimalNumber.dividing(by: divisor)
        let remainder = decimalNumber.subtracting(quotient.multiplying(by: divisor))
        return remainder.intValue
    }
}
