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

#if FOUNDATION_FRAMEWORK
@_implementationOnly import FoundationICU
#else
package import FoundationICU
#endif

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal final class ICULegacyNumberFormatter {

    let uformatter: UnsafeMutablePointer<UNumberFormat?>

    private init(type: UNumberFormatStyle, locale: Locale) throws {
        var status = U_ZERO_ERROR
        let result = unum_open(type, nil, 0, locale.identifier, nil, &status)
        guard let result else { throw ICUError(code: U_UNSUPPORTED_ERROR) }
        try status.checkSuccess()
        uformatter = result
    }

    deinit {
        unum_close(uformatter)
    }

    func setAttribute(_ attr: UNumberFormatAttribute, value: Double) {
        if attr == .roundingIncrement {
            // RoundingIncrement is the only attribute that takes a double value.
            unum_setDoubleAttribute(uformatter, attr, value)
        } else {
            unum_setAttribute(uformatter, attr, Int32(value))
        }
    }

    func setAttribute(_ attr: UNumberFormatAttribute, value: Int) {
        unum_setAttribute(uformatter, attr, Int32(value))
    }

    func setAttribute(_ attr: UNumberFormatAttribute, value: Bool) {
        unum_setAttribute(uformatter, attr, value ? 1 : 0)
    }

    func setTextAttribute(_ attr: UNumberFormatTextAttribute, value: String) throws {
        let uvalue = Array(value.utf16)
        var status = U_ZERO_ERROR
        unum_setTextAttribute(uformatter, attr, uvalue, Int32(uvalue.count), &status)
        try status.checkSuccess()
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

        guard let str = String(utf8String: decNumChars) else {
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

    // Attribute setters

    func setPrecision(_ precision: NumberFormatStyleConfiguration.Precision?) {
        guard let precision = precision else { return }

        switch precision.option {
        case .significantDigits(let min, let max):
            setAttribute(.significantDigitsUsed, value: true)
            setAttribute(.minSignificantDigits, value: min)
            if let max = max {
                setAttribute(.maxSignificantDigits, value: max)
            }
        case .integerAndFractionalLength(let minInt, let maxInt, let minFraction, let maxFraction):
            setAttribute(.significantDigitsUsed, value: false)
            if let minInt = minInt {
                setAttribute(.minIntegerDigits, value: minInt)
            }
            if let maxInt = maxInt {
                setAttribute(.maxIntegerDigits, value: maxInt)
            }
            if let minFraction = minFraction {
                setAttribute(.minFractionDigits, value: minFraction)
            }
            if let maxFraction = maxFraction {
                setAttribute(.maxFractionDigits, value: maxFraction)
            }
        }
    }

    func setMultiplier(_ multiplier: Double?) {
        if let multiplier {
            setAttribute(.multiplier, value: multiplier)
        }
    }

    func setGrouping(_ group: NumberFormatStyleConfiguration.Grouping?) {
        guard let group = group else { return }

        switch group.option {
        case .automatic:
            break
        case .hidden:
            setAttribute(.groupingUsed, value: false)
        }
    }

    func setDecimalSeparator(_ decimalSeparator: NumberFormatStyleConfiguration.DecimalSeparatorDisplayStrategy?) {
        guard let decimalSeparator = decimalSeparator else { return }

        switch decimalSeparator.option {
        case .automatic:
            break
        case .always:
            setAttribute(.decimalAlwaysShown, value: true)
        }
    }

    func setRoundingIncrement(_ increment: NumberFormatStyleConfiguration.RoundingIncrement?) {
        guard let increment = increment else { return }

        switch increment {
        case .integer(let value):
            setAttribute(.roundingIncrement, value: value)
        case .floatingPoint(let value):
            setAttribute(.roundingIncrement, value: value)
        }
    }

    func setCapitalizationContext(_ context: FormatStyleCapitalizationContext) {
        var status = U_ZERO_ERROR
        unum_setContext(uformatter, context.icuContext, &status)
        // status ignored, nothing to do on failure
    }

    // MARK: - Cache utilities

    enum NumberFormatType : Hashable, Codable {
        case number(NumberFormatStyleConfiguration.Collection)
        case percent(NumberFormatStyleConfiguration.Collection)
        case currency(CurrencyFormatStyleConfiguration.Collection)
        case descriptive(DescriptiveNumberFormatConfiguration.Collection)
    }

    private struct CacheSignature : Hashable {
        let type: NumberFormatType
        let locale: Locale
        let lenient: Bool

        func createNumberFormatter() -> ICULegacyNumberFormatter {
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

            let formatter = try! ICULegacyNumberFormatter(type: icuType, locale: locale)
            formatter.setAttribute(.lenientParse, value: lenient)

            switch type {
            case .number(let config):
                fallthrough
            case .percent(let config):
                formatter.setMultiplier(config.scale)
                formatter.setPrecision(config.precision)
                formatter.setGrouping(config.group)
                formatter.setDecimalSeparator(config.decimalSeparatorStrategy)
                formatter.setRoundingIncrement(config.roundingIncrement)

                // Decimal and percent style specific attributes
                if let sign = config.signDisplayStrategy  {
                    switch sign.positive {
                    case .always:
                        formatter.setAttribute(.signAlwaysShown, value: true)
                    case .hidden:
                        break
                    }
                }

            case .currency(let config):
                formatter.setMultiplier(config.scale)
                formatter.setPrecision(config.precision)
                formatter.setGrouping(config.group)
                formatter.setDecimalSeparator(config.decimalSeparatorStrategy)
                formatter.setRoundingIncrement(config.roundingIncrement)

                // Currency specific attributes
                if let sign = config.signDisplayStrategy {
                    switch sign.positive {
                    case .always:
                        formatter.setAttribute(.signAlwaysShown, value: true)
                    case .hidden:
                        break
                    }
                }
                
            case .descriptive(let config):
                if let capitalizationContext = config.capitalizationContext {
                    formatter.setCapitalizationContext(capitalizationContext)
                }
                
                switch config.presentation.option {
                case .spellOut:
                    break
                case .ordinal:
                    break
                case .cardinal:
                    do {
                        try formatter.setTextAttribute(.defaultRuleSet, value: "%spellout-cardinal")
                    } catch {
                        // the general cardinal rule isn't supported, so try a gendered cardinal. Note that a proper fix requires using the gender of the subsequent noun
                        try? formatter.setTextAttribute(.defaultRuleSet, value: "%spellout-cardinal-masculine")
                    }
                }
            }
            return formatter
        }
    }

    private static let cache = FormatterCache<CacheSignature, ICULegacyNumberFormatter>()
    // lenient is only used for parsing
    static func numberFormatterCreateIfNeeded(type: NumberFormatType, locale: Locale, lenient: Bool = false) -> ICULegacyNumberFormatter {
        let sig = CacheSignature(type: type, locale: locale, lenient: lenient)
        let formatter = ICULegacyNumberFormatter.cache.formatter(for: sig, creator: sig.createNumberFormatter)

        return formatter
    }
}
