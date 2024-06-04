//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

internal import _FoundationICU

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class ICULegacyNumberFormatter : @unchecked Sendable {

    /// `Sendable` notes: `UNumberFormat` is safe to use from multple threads after initialization and configuration.
    let uformatter: UnsafeMutablePointer<UNumberFormat?>

    private init(openedFormatter: UnsafeMutablePointer<UNumberFormat?>) {
        uformatter = openedFormatter
    }

    deinit {
        unum_close(uformatter)
    }

    func parseAsInt(_ string: some StringProtocol) -> Int64? {
        let arr = Array(string.utf16)
        var status = U_ZERO_ERROR
        let parsed = unum_parseInt64(uformatter, arr, Int32(arr.count), nil, &status)
        guard status.isSuccess else { return nil }
        return parsed
    }

    // `upperBound`: the utf-16 position in the string where the parse ends
    func parseAsInt(_ string: some StringProtocol, upperBound: inout Int) -> Int64? {
        // ICU API lets us use position as both a starting and ending point, but we only need it as an ending point. The input value is ignored and it is only used to set the ending point as an out argument.
        let arr = Array(string.utf16)
        var status = U_ZERO_ERROR
        var pos = Int32(0) // 0 == start, per ICU docs
        let parsed = unum_parseInt64(uformatter, arr, Int32(arr.count), &pos, &status)
        guard status.isSuccess else { return nil }
        upperBound = Int(pos)
        return parsed
    }

    func parseAsDouble(_ string: some StringProtocol) -> Double? {
        let arr = Array(string.utf16)
        var status = U_ZERO_ERROR
        let parsed = unum_parseDouble(uformatter, arr, Int32(arr.count), nil, &status)
        guard status.isSuccess else { return nil }
        return parsed
    }

    func parseAsDouble(_ string: some StringProtocol, upperBound: inout Int) -> Double? {
        let arr = Array(string.utf16)
        var status = U_ZERO_ERROR
        var pos = Int32(0) // 0 == start, per ICU docs
        let parsed = unum_parseDouble(uformatter, arr, Int32(arr.count), &pos, &status)
        guard status.isSuccess else { return nil }
        upperBound = Int(pos)
        return parsed
    }

    func parseAsDecimal(_ string: some StringProtocol) -> Decimal? {
        var upperBound = 0
        return parseAsDecimal(string, upperBound: &upperBound)
    }

    func parseAsDecimal(_ string: some StringProtocol, upperBound: inout Int) -> Decimal? {
        var status = U_ZERO_ERROR
        let arr = Array(string.utf16)

        let formattable = ufmt_open(&status)
        guard status.isSuccess else { return nil }
        defer { ufmt_close(formattable) }

        var pos = Int32(0) // 0 == start, per ICU docs
        unum_parseToUFormattable(uformatter, formattable, arr, Int32(arr.count), &pos, &status)
        guard status.isSuccess else { return nil }
        upperBound = Int(pos)

        var len: Int32 = 0
        guard let decNumChars = ufmt_getDecNumChars(formattable, &len, &status) else {
            return nil
        }
        guard status.isSuccess else { return nil }

        guard let str = String(validatingUTF8: decNumChars) else {
            return nil
        }

        return Decimal(string: str)
    }

    func format(_ v: Double) -> String? {
        _withResizingUCharBuffer { buffer, size, status in
            unum_formatDouble(self.uformatter, v, buffer, size, nil, &status)
        }
    }

    func format(_ v: Int64) -> String? {
        _withResizingUCharBuffer { buffer, size, status in
            unum_formatInt64(self.uformatter, v, buffer, size, nil, &status)
        }
    }

    func format(_ v: Decimal) -> String? {
        _withResizingUCharBuffer { buffer, size, status in
            let valueString = v.description
            return unum_formatDecimal(uformatter, valueString, Int32(valueString.count), buffer, size, nil, &status)
        }
    }

    // MARK: - Cache utilities

    enum NumberFormatType : Hashable, Codable {
        case number(NumberFormatStyleConfiguration.Collection)
        case percent(NumberFormatStyleConfiguration.Collection)
        case currency(CurrencyFormatStyleConfiguration.Collection)
        case descriptive(DescriptiveNumberFormatConfiguration.Collection)
    }

    private struct Signature : Hashable {
        let type: NumberFormatType
        let localeIdentifier: String
        let lenient: Bool

        func createNumberFormatter() throws -> ICULegacyNumberFormatter {
            var icuType: UNumberFormatStyle
            switch type {
            case .number(let config):
                if config.notation == .scientific {
                    icuType = .scientific
                } else {
                    icuType = .decimal
                }
            case .percent(_):
                icuType = .percent
            case .currency(let config):
                icuType = config.icuNumberFormatStyle
            case .descriptive(let config):
                icuType = config.icuNumberFormatStyle
            }

            var status = U_ZERO_ERROR
            let formatter = unum_open(icuType, nil, 0, localeIdentifier, nil, &status)
            guard let formatter else {
                throw ICUError(code: U_UNSUPPORTED_ERROR)
            }
            try status.checkSuccess()

            setAttribute(.lenientParse, formatter: formatter, value: lenient)

            switch type {
            case .number(let config):
                fallthrough
            case .percent(let config):
                setMultiplier(config.scale, formatter: formatter)
                setPrecision(config.precision, formatter: formatter)
                setGrouping(config.group, formatter: formatter)
                setDecimalSeparator(config.decimalSeparatorStrategy, formatter: formatter)
                setRoundingIncrement(config.roundingIncrement, formatter: formatter)

                // Decimal and percent style specific attributes
                if let sign = config.signDisplayStrategy {
                    switch sign.positive {
                    case .always:
                        setAttribute(.signAlwaysShown, formatter: formatter, value: true)
                    case .hidden:
                        break
                    }
                }

            case .currency(let config):
                setMultiplier(config.scale, formatter: formatter)
                setPrecision(config.precision, formatter: formatter)
                setGrouping(config.group, formatter: formatter)
                setDecimalSeparator(config.decimalSeparatorStrategy, formatter: formatter)
                setRoundingIncrement(config.roundingIncrement, formatter: formatter)

                // Currency specific attributes
                if let sign = config.signDisplayStrategy {
                    switch sign.positive {
                    case .always:
                        setAttribute(.signAlwaysShown, formatter: formatter, value: true)
                    case .hidden:
                        break
                    }
                }
                
            case .descriptive(let config):
                if let capitalizationContext = config.capitalizationContext {
                    setCapitalizationContext(capitalizationContext, formatter: formatter)
                }
                
                switch config.presentation.option {
                case .spellOut:
                    break
                case .ordinal:
                    break
                case .cardinal:
                    do {
                        try setTextAttribute(.defaultRuleSet, formatter: formatter, value: "%spellout-cardinal")
                    } catch {
                        // the general cardinal rule isn't supported, so try a gendered cardinal. Note that a proper fix requires using the gender of the subsequent noun
                        try? setTextAttribute(.defaultRuleSet, formatter: formatter, value: "%spellout-cardinal-masculine")
                    }
                }
            }
            
            return ICULegacyNumberFormatter(openedFormatter: formatter)
        }
    }

    private static let cache = FormatterCache<Signature, ICULegacyNumberFormatter>()
    // lenient is only used for parsing
    static func formatter(for type: NumberFormatType, locale: Locale, lenient: Bool = false) -> ICULegacyNumberFormatter? {
        let sig = Signature(type: type, localeIdentifier: locale.identifier, lenient: lenient)
        let formatter = try? ICULegacyNumberFormatter.cache.formatter(for: sig, creator: sig.createNumberFormatter)

        return formatter
    }
}

// MARK: - Helper Setters

private func setAttribute(_ attr: UNumberFormatAttribute, formatter: UnsafeMutablePointer<UNumberFormat?>, value: Double) {
    if attr == .roundingIncrement {
        // RoundingIncrement is the only attribute that takes a double value.
        unum_setDoubleAttribute(formatter, attr, value)
    } else {
        unum_setAttribute(formatter, attr, Int32(value))
    }
}

private func setAttribute(_ attr: UNumberFormatAttribute, formatter: UnsafeMutablePointer<UNumberFormat?>, value: Int) {
    unum_setAttribute(formatter, attr, Int32(value))
}

private func setAttribute(_ attr: UNumberFormatAttribute, formatter: UnsafeMutablePointer<UNumberFormat?>, value: Bool) {
    unum_setAttribute(formatter, attr, value ? 1 : 0)
}

private func setTextAttribute(_ attr: UNumberFormatTextAttribute, formatter: UnsafeMutablePointer<UNumberFormat?>, value: String) throws {
    let uvalue = Array(value.utf16)
    var status = U_ZERO_ERROR
    unum_setTextAttribute(formatter, attr, uvalue, Int32(uvalue.count), &status)
    try status.checkSuccess()
}

private func setPrecision(_ precision: NumberFormatStyleConfiguration.Precision?, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    guard let precision = precision else { return }

    switch precision.option {
    case .significantDigits(let min, let max):
        setAttribute(.significantDigitsUsed, formatter: formatter, value: true)
        setAttribute(.minSignificantDigits, formatter: formatter, value: min)
        if let max = max {
            setAttribute(.maxSignificantDigits, formatter: formatter, value: max)
        }
    case .integerAndFractionalLength(let minInt, let maxInt, let minFraction, let maxFraction):
        setAttribute(.significantDigitsUsed, formatter: formatter, value: false)
        if let minInt = minInt {
            setAttribute(.minIntegerDigits, formatter: formatter, value: minInt)
        }
        if let maxInt = maxInt {
            setAttribute(.maxIntegerDigits, formatter: formatter, value: maxInt)
        }
        if let minFraction = minFraction {
            setAttribute(.minFractionDigits, formatter: formatter, value: minFraction)
        }
        if let maxFraction = maxFraction {
            setAttribute(.maxFractionDigits, formatter: formatter, value: maxFraction)
        }
    }
}

private func setMultiplier(_ multiplier: Double?, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    if let multiplier {
        setAttribute(.multiplier, formatter: formatter, value: multiplier)
    }
}

private func setGrouping(_ group: NumberFormatStyleConfiguration.Grouping?, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    guard let group = group else { return }

    switch group.option {
    case .automatic:
        break
    case .hidden:
        setAttribute(.groupingUsed, formatter: formatter, value: false)
    }
}

private func setDecimalSeparator(_ decimalSeparator: NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy?, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    guard let decimalSeparator = decimalSeparator else { return }

    switch decimalSeparator.option {
    case .automatic:
        break
    case .always:
        setAttribute(.decimalAlwaysShown, formatter: formatter, value: true)
    }
}

private func setRoundingIncrement(_ increment: NumberFormatStyleConfiguration.RoundingIncrement?, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    guard let increment = increment else { return }

    switch increment {
    case .integer(let value):
        setAttribute(.roundingIncrement, formatter: formatter, value: value)
    case .floatingPoint(let value):
        setAttribute(.roundingIncrement, formatter: formatter, value: value)
    }
}

private func setCapitalizationContext(_ context: FormatStyleCapitalizationContext, formatter: UnsafeMutablePointer<UNumberFormat?>) {
    var status = U_ZERO_ERROR
    unum_setContext(formatter, context.icuContext, &status)
    // status ignored, nothing to do on failure
}
