//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
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
#elseif canImport(ucrt)
import ucrt
#endif

#if !FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct Decimal: Sendable {
    internal typealias Mantissa = (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)

    internal struct Storage: Sendable {
        var exponent: Int8
        // Layout:
        // |  0  1  2  3 | 4 | 5 | 6  7 |
        // | -> _length  | | | | | ->_reserved
        // |             | | | |-> _isCompact
        // |             | |-> _isNegative
        var lengthFlagsAndReserved: UInt8
        // 18 bits long
        var reserved: UInt16
        var mantissa: Mantissa
    }

    private var storage: Storage

    // Int8
    internal var _exponent: Int32 {
        get {
            return Int32(self.storage.exponent)
        }
        set {
            self.storage.exponent = Int8(newValue)
        }
    }

    // 4 bits
    internal var _length: UInt32 {
        get {
            return UInt32(self.storage.lengthFlagsAndReserved >> 4)
        }
        set {
            let newLength = (UInt8(truncatingIfNeeded: newValue) & 0x0F) << 4
            self.storage.lengthFlagsAndReserved &= 0x0F // clear the length
            self.storage.lengthFlagsAndReserved |= newLength // set the new length
        }
    }
    // Bool
    internal var _isNegative: UInt32 {
        get {
            return UInt32((self.storage.lengthFlagsAndReserved >> 3) & 0x01)
        }
        set {
            if (newValue & 0x1) != 0 {
                self.storage.lengthFlagsAndReserved |= 0b00001000
            } else {
                self.storage.lengthFlagsAndReserved &= 0b11110111
            }
        }
    }
    // Bool
    internal var _isCompact: UInt32 {
        get {
            return UInt32((self.storage.lengthFlagsAndReserved >> 2) & 0x01)
        }
        set {
            if (newValue & 0x1) != 0 {
                self.storage.lengthFlagsAndReserved |= 0b00000100
            } else {
                self.storage.lengthFlagsAndReserved &= 0b11111011
            }
        }
    }
    // Only 18 bits
    internal var _reserved: UInt32 {
        return (UInt32(self.storage.lengthFlagsAndReserved & 0x03) << 16) | UInt32(self.storage.reserved)
    }

    internal var _mantissa: Mantissa {
        get {
            return self.storage.mantissa
        }
        set {
            self.storage.mantissa = newValue
        }
    }

    internal init(
        _exponent: Int32,
        _length: UInt32,
        _isNegative: UInt32,
        _isCompact: UInt32,
        _reserved: UInt32,
        _mantissa: Mantissa
    ) {
        let length: UInt8 = (UInt8(truncatingIfNeeded: _length) & 0xF) << 4
        let isNagitive: UInt8 = UInt8(truncatingIfNeeded: _isNegative & 0x1) == 0 ? 0 : 0b00001000
        let isCompact: UInt8 = UInt8(truncatingIfNeeded: _isCompact & 0x1) == 0 ? 0 : 0b00000100
        let reservedLeft: UInt8 = UInt8(truncatingIfNeeded: (_reserved & 0x3FFFF) >> 16)
        self.storage = .init(
            exponent: Int8(truncatingIfNeeded: _exponent),
            lengthFlagsAndReserved: length | isNagitive | isCompact | reservedLeft,
            reserved: UInt16(truncatingIfNeeded: _reserved & 0xFFFF),
            mantissa: _mantissa
        )
    }

    public init() {
        self.storage = .init(
            exponent: 0,
            lengthFlagsAndReserved: 0,
            reserved: 0,
            mantissa: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }
}

extension Decimal: Equatable {
    public static func == (lhs: Decimal, rhs: Decimal) -> Bool {
        return lhs.storage.exponent == rhs.storage.exponent &&
        lhs.storage.lengthFlagsAndReserved == rhs.storage.lengthFlagsAndReserved &&
        lhs.storage.reserved == rhs.storage.reserved &&
        lhs.storage.mantissa.0 == rhs.storage.mantissa.0 &&
        lhs.storage.mantissa.1 == rhs.storage.mantissa.1 &&
        lhs.storage.mantissa.2 == rhs.storage.mantissa.2 &&
        lhs.storage.mantissa.3 == rhs.storage.mantissa.3 &&
        lhs.storage.mantissa.4 == rhs.storage.mantissa.4 &&
        lhs.storage.mantissa.5 == rhs.storage.mantissa.5 &&
        lhs.storage.mantissa.6 == rhs.storage.mantissa.6 &&
        lhs.storage.mantissa.7 == rhs.storage.mantissa.7
    }
}

#endif // !FOUNDATION_FRAMEWORK

// MARK: - String
extension Decimal {
    internal func toString(with locale: Locale? = nil) -> String {
        if self.isNaN {
            return "NaN"
        }
        if self._length == 0 {
            return "0"
        }
        var buffer = ""
        let separator: String
        if let locale = locale,
           let localizedSeparator = locale.decimalSeparator {
            separator = String(localizedSeparator.reversed())
        } else {
            separator = "."
        }
        var copy = self
        while copy._exponent > 0 {
            buffer += "0"
            copy._exponent -= 1
        }
        if copy._exponent == 0 {
            copy._exponent = 1
        }
        while copy._length != 0 {
            if copy._exponent == 0 {
                buffer.append(separator)
            }
            copy._exponent += 1
            let (result, remainder) = copy._divide(by: 10)
            copy = result
            let zero = Unicode.Scalar("0")
            buffer.append(String(Unicode.Scalar(zero.value + UInt32(remainder))!))
        }

        if copy._exponent <= 0 {
            while copy._exponent != 0 {
                buffer.append("0")
                copy._exponent += 1
            }
            buffer.append(separator)
            buffer.append("0")
        }

        if copy._isNegative != 0 {
            buffer.append("-")
        }
        return String(buffer.reversed())
    }

    internal static func decimal(
        from stringView: String.UTF8View,
        matchEntireString: Bool
    ) -> Decimal? {
        func multiplyBy10AndAdd(
            _ decimal: Decimal,
            number: UInt16
        ) throws -> Decimal {
            do {
                var result = try decimal._multiply(by: 10)
                result = try result._add(number)
                return result
            } catch {
                throw _CalculationError.overflow
            }
        }

        func skipWhiteSpaces(from index: String.UTF8View.Index) -> String.UTF8View.Index {
            var i = index
            while i != stringView.endIndex &&
                Character(utf8Scalar: stringView[i]).isWhitespace {
                stringView.formIndex(after: &i)
            }
            return i
        }

        var result = Decimal()
        var index = stringView.startIndex
        index = skipWhiteSpaces(from: index)
        // Get the sign
        if index != stringView.endIndex &&
            (stringView[index] == UInt8._plus ||
             stringView[index] == UInt8._minus) {
            result._isNegative = (stringView[index] == UInt8._minus) ? 1 : 0
            // Advance over the sign
            stringView.formIndex(after: &index)
        }
        // Build mantissa
        var tooBigToFit = false

        while index != stringView.endIndex,
            let digitValue = stringView[index].digitValue {
            defer {
                stringView.formIndex(after: &index)
            }
            // Multiply the value by 10 and add the current digit
            func incrementExponent(_ decimal: inout Decimal) {
                // Before incrementing the exponent, we need to check
                // if it's still possible to increment.
                if decimal._exponent == Int8.max {
                    decimal = .nan
                    return
                }
                decimal._exponent += 1
            }

            if tooBigToFit {
                incrementExponent(&result)
                if result.isNaN {
                    return nil
                }
                continue
            }
            guard let product = try? multiplyBy10AndAdd(
                result,
                number: UInt16(digitValue)
            ) else {
                tooBigToFit = true
                incrementExponent(&result)
                if result.isNaN {
                    return nil
                }
                continue
            }
            result = product
        }
        // Get the decimal point
        if index != stringView.endIndex && stringView[index] == UInt8._period {
            stringView.formIndex(after: &index)
            // Continue to build the mantissa
            while index != stringView.endIndex,
                  let digitValue = stringView[index].digitValue {
                defer {
                    stringView.formIndex(after: &index)
                }
                guard !tooBigToFit else {
                    continue
                }
                guard let product = try? multiplyBy10AndAdd(
                    result,
                    number: UInt16(digitValue)
                ) else {
                    tooBigToFit = true
                    continue
                }
                result = product
                // Before decrementing the exponent, we need to check
                // if it's still possible to decrement.
                if result._exponent == Int8.min {
                    return nil
                }
                result._exponent -= 1
            }
        }
        // Get the exponent if any
        if index != stringView.endIndex && (stringView[index] == UInt8._E || stringView[index] == UInt8._e) {
            stringView.formIndex(after: &index)
            var exponentIsNegative = false
            var exponent = 0
            // Get the exponent sign
            if stringView[index] == UInt8._minus || stringView[index] == UInt8._plus {
                exponentIsNegative = stringView[index] == UInt8._minus
                stringView.formIndex(after: &index)
            }
            // Build the exponent
            while index != stringView.endIndex,
                  let digitValue = stringView[index].digitValue {
                exponent = 10 * exponent + digitValue
                if exponent > 2 * Int(Int8.max) {
                    // Too big to fit
                    return nil
                }
                stringView.formIndex(after: &index)
            }
            if exponentIsNegative {
                exponent = -exponent
            }
            // Check to see if it will fit into the exponent field
            exponent += Int(result._exponent)
            if exponent > Int8.max || exponent < Int8.min {
                return nil
            }
            result._exponent = Int32(exponent)
        }
        // If we are required to match the entire string,
        // "trim" the end whitespaces and check if we are
        // at the end of the string
        if matchEntireString {
            // Trim end spaces
            index = skipWhiteSpaces(from: index)
            guard index == stringView.endIndex else {
                // Any unprocessed content means the string
                // contains something not valid
                return nil
            }
        }
        result.compact()
        // if we get to this point, and have NaN,
        // then the input string was probably "-0"
        // or some variation on that, and
        // normalize that to zero.
        if result.isNaN {
            return Decimal(0)
        }
        return result
    }
}

// MARK: - Mathmatics
extension Decimal {
    private static let maxSize = 8
    private enum _CalculationError: Error {
        case overflow
        case underflow
    }

    mutating func compact() {
        var secureExponent = self._exponent
        if self._isCompact != 0 || self.isNaN || self._length == 0 {
            // No need to compact
            return
        }
        // Divide by 10 as much as possible
        var remainder: UInt16 = 0
        repeat {
            let (result, _remainder) = self._divide(by: 10)
            remainder = _remainder
            self = result
            secureExponent += 1
        } while remainder == 0 && self._length > 0
        if self._length == 0 && remainder == 0 {
            self = Decimal()
            return
        }

        // Put the non-null remdr in place
        self = try! self._multiply(by: 10)
        self = try! self._add(remainder)
        secureExponent -= 1

        // Set the new exponent
        while secureExponent > Int8.max {
            self = try! self._multiply(by: 10)
            secureExponent -= 1
        }
        self._exponent = secureExponent
        // Mark the decimal as compact
        self._isCompact = 1
    }

    private func _divide(by divisor: UInt16) -> (result: Decimal, remainder: UInt16) {
        guard divisor != 0 else {
            fatalError("Divide by zero")
        }
        var result = self
        var carry: UInt32 = 0
        for index in (0 ..< result._length).reversed() {
            let acc = UInt32(result[index]) + carry * (1 << 16)
            result[index] = UInt16(acc / UInt32(divisor))
            carry = acc % UInt32(divisor)
        }
        var resultLength = result._length
        while resultLength != 0 && result[resultLength-1] == 0 {
            resultLength -= 1
        }
        result._length = resultLength
        return (result: result, remainder: UInt16(carry))
    }

    private func _multiply(by multiplicand: UInt16) throws -> Decimal {
        var result = self
        if multiplicand == 0 {
            result._length = 0
            return result
        }
        var carry: UInt32 = 0
        var index: UInt32 = 0
        while index < result._length {
            let acc = UInt32(result[index]) *
                UInt32(multiplicand) + carry
            carry = acc >> 16
            result[index] = UInt16(acc & 0xFFFF)
            index += 1
        }
        if carry != 0 {
            if result._length >= Decimal.maxSize {
                throw _CalculationError.overflow
            }
            result[index] = UInt16(carry)
            index += 1
        }
        result._length = index
        return result
    }

    private func _add(_ amount: UInt16) throws -> Decimal {
        var result = self
        var carry: UInt32 = UInt32(amount)
        var index: UInt32 = 0
        while index < result._length {
            let acc = UInt32(result[index]) + carry
            carry = acc >> 16
            result[index] = UInt16(acc & 0xFFFF)
            index += 1
        }
        if carry != 0 {
            if result._length >= Decimal.maxSize {
                throw _CalculationError.overflow
            }
            result[index] = UInt16(carry)
            index += 1
        }
        result._length = index
        return result
    }
}

private extension Character {
    init(utf8Scalar: UTF8.CodeUnit) {
        self.init(Unicode.Scalar(utf8Scalar))
    }
}
