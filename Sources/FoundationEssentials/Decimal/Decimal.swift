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
    @_spi(SwiftCorelibsFoundation)
    public typealias Mantissa = (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)

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

    internal var storage: Storage

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
        get {
            return (UInt32(self.storage.lengthFlagsAndReserved & 0x03) << 16) | UInt32(self.storage.reserved)
        }
        set {
            // Bottom 16 bits
            self.storage.reserved = UInt16(newValue & 0xFFFF)
            self.storage.lengthFlagsAndReserved &= 0xFC
            self.storage.lengthFlagsAndReserved |= UInt8(newValue >> 16) & 0xFF
        }
    }

    internal var _mantissa: Mantissa {
        get {
            return self.storage.mantissa
        }
        set {
            self.storage.mantissa = newValue
        }
    }

    internal var _lengthFlagsAndReserved: UInt8 {
        get {
            return self.storage.lengthFlagsAndReserved
        }
        set {
            self.storage.lengthFlagsAndReserved = newValue
        }
    }

    @_spi(SwiftCorelibsFoundation)
    public init(
        _exponent: Int32 = 0,
        _length: UInt32,
        _isNegative: UInt32 = 0,
        _isCompact: UInt32,
        _reserved: UInt32 = 0,
        _mantissa: Mantissa
    ) {
        let length: UInt8 = (UInt8(truncatingIfNeeded: _length) & 0xF) << 4
        let isNegative: UInt8 = UInt8(truncatingIfNeeded: _isNegative & 0x1) == 0 ? 0 : 0b00001000
        let isCompact: UInt8 = UInt8(truncatingIfNeeded: _isCompact & 0x1) == 0 ? 0 : 0b00000100
        let reservedLeft: UInt8 = UInt8(truncatingIfNeeded: (_reserved & 0x3FFFF) >> 16)
        self.storage = .init(
            exponent: Int8(truncatingIfNeeded: _exponent),
            lengthFlagsAndReserved: length | isNegative | isCompact | reservedLeft,
            reserved: UInt16(truncatingIfNeeded: _reserved & 0xFFFF),
            mantissa: _mantissa
        )
    }

    @_spi(SwiftCorelibsFoundation)
    public init(mantissa: UInt64, exponent: Int16, isNegative: Bool) {
        var d = Decimal(mantissa)
        d._exponent += Int32(exponent)
        d._isNegative = isNegative ? 1 : 0
        self = d
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

extension Decimal {
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public enum RoundingMode: UInt, Sendable {
        case plain
        case down
        case up
        case bankers
    }

    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public enum CalculationError: UInt, Sendable {
        case noError
        case lossOfPrecision
        case overflow
        case underflow
        case divideByZero
    }
}

#endif // !FOUNDATION_FRAMEWORK

// MARK: - String
extension Decimal {
#if FOUNDATION_FRAMEWORK
#else
    @_spi(SwiftCorelibsFoundation)
    public func toString(with locale: Locale? = nil) -> String {
        _toString(with: locale)
    }
    
    @_spi(SwiftCorelibsFoundation)
    public static func decimal(
        from stringView: String.UTF8View,
        decimalSeparator: String.UTF8View,
        matchEntireString: Bool
    ) -> (result: Decimal?, processedLength: Int) {
        _decimal(from: stringView, decimalSeparator: decimalSeparator, matchEntireString: matchEntireString).asOptional
    }
#endif
    internal func _toString(with locale: Locale? = nil) -> String {
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
            // _divide only throws `.divideByZero` which we are obviously
            // not doing here, hence try!
            let (result, remainder) = try! copy._divide(by: 10)
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

    internal enum DecimalParseResult {
        case success(Decimal, processedLength: Int)
        case parseFailure
        case overlargeValue

        var asOptional: (result: Decimal?, processedLength: Int) {
            switch self {
            case let .success(decimal, processedLength): (decimal, processedLength: processedLength)
            default: (nil, processedLength: 0)
            }
        }
    }

    @_specialize(where UTF8Collection == String.UTF8View)
    @_specialize(where UTF8Collection == BufferView<UInt8>)
    internal static func _decimal<UTF8Collection: Collection>(
        from utf8View: UTF8Collection,
        decimalSeparator: String.UTF8View = ".".utf8,
        matchEntireString: Bool
    ) -> DecimalParseResult where UTF8Collection.Element == UTF8.CodeUnit {
        func multiplyBy10AndAdd(
            _ decimal: Decimal,
            number: UInt16
        ) throws -> Decimal {
            do {
                var result = try decimal._multiply(byShort: 10)
                result = try result._add(number)
                return result
            } catch {
                throw _CalculationError.overflow
            }
        }

        func skipWhiteSpaces(from index: UTF8Collection.Index) -> UTF8Collection.Index {
            var i = index
            while i != utf8View.endIndex &&
                Character(utf8Scalar: utf8View[i]).isWhitespace {
                utf8View.formIndex(after: &i)
            }
            return i
        }

        func stringViewContainsDecimalSeparator(at index: UTF8Collection.Index) -> Bool {
            for indexOffset in 0 ..< decimalSeparator.count {
                let stringIndex = utf8View.index(index, offsetBy: indexOffset)
                let decimalIndex = decimalSeparator.index(
                    decimalSeparator.startIndex,
                    offsetBy: indexOffset
                )
                if utf8View[stringIndex] != decimalSeparator[decimalIndex] {
                    return false
                }
            }
            return true
        }

        var result = Decimal()
        var index = utf8View.startIndex
        index = skipWhiteSpaces(from: index)
        // Get the sign
        if index != utf8View.endIndex &&
            (utf8View[index] == UInt8._plus ||
             utf8View[index] == UInt8._minus) {
            result._isNegative = (utf8View[index] == UInt8._minus) ? 1 : 0
            // Advance over the sign
            utf8View.formIndex(after: &index)
        }
        // Build mantissa
        var tooBigToFit = false

        while index != utf8View.endIndex,
            let digitValue = utf8View[index].digitValue {
            defer {
                utf8View.formIndex(after: &index)
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
                    return .overlargeValue
                }
                continue
            }
            guard let product = try? result._multiplyBy10AndAdd(number: UInt16(digitValue)
            ) else {
                tooBigToFit = true
                incrementExponent(&result)
                if result.isNaN {
                    return .overlargeValue
                }
                continue
            }
            result = product
        }
        // Get the decimal point
        if index != utf8View.endIndex && stringViewContainsDecimalSeparator(at: index) {
            utf8View.formIndex(&index, offsetBy: decimalSeparator.count)
            // Continue to build the mantissa
            while index != utf8View.endIndex,
                  let digitValue = utf8View[index].digitValue {
                defer {
                    utf8View.formIndex(after: &index)
                }
                guard !tooBigToFit else {
                    continue
                }
                guard let product = try? result._multiplyBy10AndAdd(number: UInt16(digitValue)
                ) else {
                    tooBigToFit = true
                    continue
                }
                result = product
                // Before decrementing the exponent, we need to check
                // if it's still possible to decrement.
                if result._exponent == Int8.min {
                    return .overlargeValue
                }
                result._exponent -= 1
            }
        }
        // Get the exponent if any
        if index != utf8View.endIndex && (utf8View[index] == UInt8._E || utf8View[index] == UInt8._e) {
            utf8View.formIndex(after: &index)
            var exponentIsNegative = false
            var exponent = 0
            // Get the exponent sign
            if utf8View[index] == UInt8._minus || utf8View[index] == UInt8._plus {
                exponentIsNegative = utf8View[index] == UInt8._minus
                utf8View.formIndex(after: &index)
            }
            // Build the exponent
            while index != utf8View.endIndex,
                  let digitValue = utf8View[index].digitValue {
                exponent = 10 * exponent + digitValue
                if exponent > 2 * Int(Int8.max) {
                    // Too big to fit
                    return .overlargeValue
                }
                utf8View.formIndex(after: &index)
            }
            if exponentIsNegative {
                exponent = -exponent
            }
            // Check to see if it will fit into the exponent field
            exponent += Int(result._exponent)
            if exponent > Int8.max || exponent < Int8.min {
                return .overlargeValue
            }
            result._exponent = Int32(exponent)
        }
        // If we are required to match the entire string,
        // "trim" the end whitespaces and check if we are
        // at the end of the string
        if matchEntireString {
            // Trim end spaces
            index = skipWhiteSpaces(from: index)
            guard index == utf8View.endIndex else {
                // Any unprocessed content means the string
                // contains something not valid
                return .parseFailure
            }
        }
        if index == utf8View.startIndex {
            // If we weren't able to process any character
            // the entire string isn't a valid decimal
            return .parseFailure
        }
        result.compact()
        let processedLength = utf8View.distance(from: utf8View.startIndex, to: index)
        // if we get to this point, and have NaN,
        // then the input string was probably "-0"
        // or some variation on that, and
        // normalize that to zero.
        if result.isNaN {
            return .success(Decimal(0), processedLength: processedLength)
        }
        return .success(result, processedLength: processedLength)
    }
}

private extension Character {
    init(utf8Scalar: UTF8.CodeUnit) {
        self.init(Unicode.Scalar(utf8Scalar))
    }
}
