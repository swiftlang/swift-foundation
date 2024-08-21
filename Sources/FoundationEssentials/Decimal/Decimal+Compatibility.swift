//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// NSDecimal compatibility API

#if FOUNDATION_FRAMEWORK
// For feature flag
internal import _ForSwiftFoundation
#endif

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal {
    public typealias RoundingMode = NSDecimalNumber.RoundingMode
    public typealias CalculationError = NSDecimalNumber.CalculationError
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal {
    @available(swift, obsoleted: 4, message: "Please use arithmetic operators instead")
    @_transparent
    public mutating func add(_ other: Decimal) {
        self += other
    }

    @available(swift, obsoleted: 4, message: "Please use arithmetic operators instead")
    @_transparent
    public mutating func subtract(_ other: Decimal) {
        self -= other
    }

    @available(swift, obsoleted: 4, message: "Please use arithmetic operators instead")
    @_transparent
    public mutating func multiply(by other: Decimal) {
        self *= other
    }

    @available(swift, obsoleted: 4, message: "Please use arithmetic operators instead")
    @_transparent
    public mutating func divide(by other: Decimal) {
        self /= other
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension Decimal : _ObjectiveCBridgeable {
    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSDecimalNumber {
        return NSDecimalNumber(decimal: self)
    }
    
    public static func _forceBridgeFromObjectiveC(_ x: NSDecimalNumber, result: inout Decimal?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }
    
    public static func _conditionallyBridgeFromObjectiveC(_ input: NSDecimalNumber, result: inout Decimal?) -> Bool {
        result = input.decimalValue
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSDecimalNumber?) -> Decimal {
        guard let src = source else { return Decimal(_exponent: 0, _length: 0, _isNegative: 0, _isCompact: 0, _reserved: 0, _mantissa: (0, 0, 0, 0, 0, 0, 0, 0)) }
        return src.decimalValue
    }
}
#endif

// MARK: - Bridging code to C functions
// We have one implementation function for each, and an entry point for both Darwin (cdecl, exported from the framework), and swift-corelibs-foundation (SPI here and available via that package as API)

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public func pow(_ x: Decimal, _ y: Int) -> Decimal {
    let result = try? x._power(
        exponent: UInt(y), roundingMode: .plain
    )
    return result ?? .nan
}
#else
@_spi(SwiftCorelibsFoundation)
public func _pow(_ x: Decimal, _ y: Int) -> Decimal {
    let result = try? x._power(
        exponent: UInt(y), roundingMode: .plain
    )
    return result ?? .nan
}
#endif

private func __NSDecimalAdd(
    _ result: UnsafeMutablePointer<Decimal>,
    _ lhs: UnsafePointer<Decimal>,
    _ rhs: UnsafePointer<Decimal>,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let addition = try lhs.pointee._add(
            rhs: rhs.pointee, roundingMode: roundingMode
        )
        result.pointee = addition.result
        if addition.lossOfPrecision {
            return .lossOfPrecision
        } else {
            return .noError
        }
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalAdd")
internal func _NSDecimalAdd(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalAdd(result, lhs, rhs, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalAdd(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalAdd(result, lhs, rhs, roundingMode)
}
#endif

private func __NSDecimalSubtract(
    _ result: UnsafeMutablePointer<Decimal>,
    _ lhs: UnsafePointer<Decimal>,
    _ rhs: UnsafePointer<Decimal>,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let subtraction = try lhs.pointee._subtract(
            rhs: rhs.pointee, roundingMode: roundingMode
        )
        result.pointee = subtraction
        return .noError
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalSubtract")
internal func _NSDecimalSubtract(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalSubtract(result, lhs, rhs, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalSubtract(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalSubtract(result, lhs, rhs, roundingMode)
}
#endif

private func __NSDecimalMultiply(
    _ result: UnsafeMutablePointer<Decimal>,
    _ lhs: UnsafePointer<Decimal>,
    _ rhs: UnsafePointer<Decimal>,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let product = try lhs.pointee._multiply(
            by: rhs.pointee, roundingMode: roundingMode
        )
        result.pointee = product
        return .noError
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalMultiply")
internal func _NSDecimalMultiply(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalMultiply(result, lhs, rhs, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalMultiply(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalMultiply(result, lhs, rhs, roundingMode)
}
#endif

private func __NSDecimalDivide(
    _ result: UnsafeMutablePointer<Decimal>,
    _ lhs: UnsafePointer<Decimal>,
    _ rhs: UnsafePointer<Decimal>,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let product = try lhs.pointee._divide(
            by: rhs.pointee, roundingMode: roundingMode
        )
        result.pointee = product
        return .noError
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalDivide")
internal func _NSDecimalDivide(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalDivide(result, lhs, rhs, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalDivide(_ result: UnsafeMutablePointer<Decimal>, _ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalDivide(result, lhs, rhs, roundingMode)
}
#endif

private func __NSDecimalPower(
    _ result: UnsafeMutablePointer<Decimal>,
    _ decimal: UnsafePointer<Decimal>,
    _ exponent: Int,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let power = try decimal.pointee._power(exponent: UInt(exponent), roundingMode: roundingMode)
        result.pointee = power
        return .noError
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalPower")
internal func _NSDecimalPower(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ exponent: Int, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalPower(result, decimal, exponent, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalPower(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ exponent: Int, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalPower(result, decimal, exponent, roundingMode)
}
#endif

private func __NSDecimalMultiplyByPowerOf10(
    _ result: UnsafeMutablePointer<Decimal>,
    _ decimal: UnsafePointer<Decimal>,
    _ power: CShort,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        let product = try decimal.pointee._multiplyByPowerOfTen(power: Int(power), roundingMode: roundingMode)
        result.pointee = product
        return .noError
    } catch {
        let converted = _convertError(error)
        result.pointee = .nan
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalMultiplyByPowerOf10")
internal func _NSDecimalMultiplyByPowerOf10(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ power: CShort, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalMultiplyByPowerOf10(result, decimal, power, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalMultiplyByPowerOf10(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ power: CShort, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalMultiplyByPowerOf10(result, decimal, power, roundingMode)
}
#endif

private func __NSDecimalCompare(
    _ lhs: UnsafePointer<Decimal>,
    _ rhs: UnsafePointer<Decimal>
) -> ComparisonResult {
    return Decimal._compare(lhs: lhs.pointee, rhs: rhs.pointee)
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalCompare")
internal func _NSDecimalCompare(_ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>) -> ComparisonResult {
    __NSDecimalCompare(lhs, rhs)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalCompare(_ lhs: UnsafePointer<Decimal>, _ rhs: UnsafePointer<Decimal>) -> ComparisonResult {
    __NSDecimalCompare(lhs, rhs)
}
#endif

private func __NSDecimalRound(
    _ result: UnsafeMutablePointer<Decimal>,
    _ decimal: UnsafePointer<Decimal>,
    _ scale: Int,
    _ roundingMode: Decimal.RoundingMode
) {
    do {
        let rounded = try decimal.pointee._round(
            scale: scale,
            roundingMode: roundingMode
        )
        result.pointee = rounded
    } catch {
        // Noop since this method does not
        // return a calculation error
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalRound")
internal func _NSDecimalRound(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ scale: Int, _ roundingMode: Decimal.RoundingMode) {
    __NSDecimalRound(result, decimal, scale, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalRound(_ result: UnsafeMutablePointer<Decimal>, _ decimal: UnsafePointer<Decimal>, _ scale: Int, _ roundingMode: Decimal.RoundingMode) {
    __NSDecimalRound(result, decimal, scale, roundingMode)
}
#endif

private func __NSDecimalNormalize(
    _ lhs: UnsafeMutablePointer<Decimal>,
    _ rhs: UnsafeMutablePointer<Decimal>,
    _ roundingMode: Decimal.RoundingMode
) -> Decimal.CalculationError {
    do {
        var a = lhs.pointee
        var b = rhs.pointee
        let lossPrecision = try Decimal._normalize(
            a: &a, b: &b, roundingMode: roundingMode
        )
        lhs.pointee = a
        rhs.pointee = b
        if lossPrecision {
            return .lossOfPrecision
        }
        return .noError
    } catch {
        let converted = _convertError(error)
        return converted
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalNormalize")
internal func _NSDecimalNormalize(_ lhs: UnsafeMutablePointer<Decimal>, _ rhs: UnsafeMutablePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalNormalize(lhs, rhs, roundingMode)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalNormalize(_ lhs: UnsafeMutablePointer<Decimal>, _ rhs: UnsafeMutablePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
    __NSDecimalNormalize(lhs, rhs, roundingMode)
}
#endif

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalCompact")
internal func _NSDecimalCompact(_ number: UnsafeMutablePointer<Decimal>) {
    var value = number.pointee
    value.compact()
    number.pointee = value
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalCompact(_ number: UnsafeMutablePointer<Decimal>) {
    var value = number.pointee
    value.compact()
    number.pointee = value
}
#endif

private func __NSDecimalString(
    _ decimal: UnsafePointer<Decimal>,
    _ locale: Any? = nil
) -> String {
    var decimalSeparator = "."
    if let useLocale = locale as? Locale,
       let separator = useLocale.decimalSeparator {
        decimalSeparator = separator
    }
#if FOUNDATION_FRAMEWORK
    if let dictionary = locale as? [AnyHashable : Any] {
        // NSDecimal favored NSLocale.Key.decimalSeparator if
        // both keys are present.
        if let separator = dictionary["NSDecimalSeparator"] as? String {
            decimalSeparator = separator
        }
        if let separator = dictionary[NSLocale.Key.decimalSeparator.rawValue] as? String {
            decimalSeparator = separator
        }
    }
#endif
    return decimal.pointee._toString(withDecimalSeparator: decimalSeparator)
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSDecimalString")
internal func _NSDecimalString(_ decimal: UnsafePointer<Decimal>, _ locale: Any? = nil) -> String {
    __NSDecimalString(decimal, locale)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSDecimalString(_ decimal: UnsafePointer<Decimal>, _ locale: Any? = nil) -> String {
    __NSDecimalString(decimal, locale)
}
#endif

internal func __NSStringToDecimal(
    _ string: String,
    processedLength: UnsafeMutablePointer<Int>,
    result: UnsafeMutablePointer<Decimal>
) {
    let parsed = Decimal._decimal(
        from: string.utf8,
        decimalSeparator: ".".utf8,
        matchEntireString: false
    ).asOptional
    processedLength.pointee = parsed.processedLength
    if let parsedResult = parsed.result {
        result.pointee = parsedResult
    }
}

#if FOUNDATION_FRAMEWORK
@_cdecl("_NSStringToDecimal")
internal func _NSStringToDecimal(_ string: String, processedLength: UnsafeMutablePointer<Int>, result: UnsafeMutablePointer<Decimal>) {
    __NSStringToDecimal(string, processedLength: processedLength, result: result)
}
#else
@_spi(SwiftCorelibsFoundation)
public func _NSStringToDecimal(_ string: String, processedLength: UnsafeMutablePointer<Int>, result: UnsafeMutablePointer<Decimal>) {
    __NSStringToDecimal(string, processedLength: processedLength, result: result)
}
#endif

private func _convertError(_ error: any Error) -> Decimal.CalculationError {
    guard let calculationError = error as? Decimal._CalculationError else {
        return .noError
    }
    switch calculationError {
    case .overflow:
        return .overflow
    case .underflow:
        return .underflow
    case .divideByZero:
        return .divideByZero
    }
}

#if FOUNDATION_FRAMEWORK
// MARK: Bin Compat Symbols
// We introduced the following symbols in Swift with iOS 18.
// For bin compat, we need maintain these symbols as stubs
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalAdd(
    _ result: UnsafeMutablePointer<Decimal>,
    _ leftOperand: UnsafePointer<Decimal>,
    _ rightOperand: UnsafePointer<Decimal>,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalAdd(result, leftOperand, rightOperand, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalSubtract(
    _ result: UnsafeMutablePointer<Decimal>,
    _ leftOperand: UnsafePointer<Decimal>,
    _ rightOperand: UnsafePointer<Decimal>,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalSubtract(result, leftOperand, rightOperand, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalMultiply(
    _ result: UnsafeMutablePointer<Decimal>,
    _ leftOperand: UnsafePointer<Decimal>,
    _ rightOperand: UnsafePointer<Decimal>,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalMultiply(result, leftOperand, rightOperand, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalDivide(
    _ result: UnsafeMutablePointer<Decimal>,
    _ leftOperand: UnsafePointer<Decimal>,
    _ rightOperand: UnsafePointer<Decimal>,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalDivide(result, leftOperand, rightOperand, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalPower(
    _ result: UnsafeMutablePointer<Decimal>,
    _ number: UnsafePointer<Decimal>,
    _ power: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalPower(result, number, power, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalMultiplyByPowerOf10(
    _ result: UnsafeMutablePointer<Decimal>,
    _ number: UnsafePointer<Decimal>,
    _ power: Int16,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalMultiplyByPowerOf10(result, number, power, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalCompare(
    _ leftOperand: UnsafePointer<Decimal>,
    _ rightOperand: UnsafePointer<Decimal>
) -> ComparisonResult {
    return __NSDecimalCompare(leftOperand, rightOperand)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalRound(
    _ result: UnsafeMutablePointer<Decimal>,
    _ number: UnsafePointer<Decimal>,
    _ scale: Int,
    _ roundingMode: NSDecimalNumber.RoundingMode
) {
    __NSDecimalRound(result, number, scale, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalNormalize(
    _ number1: UnsafeMutablePointer<Decimal>,
    _ number2: UnsafeMutablePointer<Decimal>,
    _ roundingMode: NSDecimalNumber.RoundingMode
) -> NSDecimalNumber.CalculationError {
    return __NSDecimalNormalize(number1, number2, roundingMode)
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalCompact(
    _ number: UnsafeMutablePointer<Decimal>
) {
    var value = number.pointee
    value.compact()
    number.pointee = value
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline internal func NSDecimalString(
    _ dcm: UnsafePointer<Decimal>,
    _ locale: Any?
) -> String {
    return __NSDecimalString(dcm, locale)
}

#endif // FOUNDATION_FRAMEWORK
