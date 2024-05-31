//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 - 2023 Apple Inc. and the Swift project authors
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

typealias ICUNumberFormatterSkeleton = String

/// For testing purposes, remove all caches from below formatters.
internal func resetAllNumberFormatterCaches() {
    ICUNumberFormatter.cache.removeAllObjects()
    ICUCurrencyNumberFormatter.cache.removeAllObjects()
    ICUPercentNumberFormatter.cache.removeAllObjects()
    ICUMeasurementNumberFormatter.cache.removeAllObjects()
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
internal class ICUNumberFormatterBase {
    internal let uformatter: OpaquePointer
    /// Stored for testing purposes only
    internal let skeleton: String

    init?(skeleton: String, localeIdentifier: String, preferences: LocalePreferences?) {
        self.skeleton = skeleton
        let ustr = Array(skeleton.utf16)
        var status = U_ZERO_ERROR
        let formatter = unumf_openForSkeletonAndLocale(ustr, Int32(ustr.count), localeIdentifier, &status)
        
        guard let formatter else {
            return nil
        }
        
        guard status.isSuccess else {
            unumf_close(formatter)
            return nil
        }
        
        uformatter = formatter
    }

    deinit {
        unumf_close(uformatter)
    }

    struct AttributePosition {
        let field: UNumberFormatFields
        let begin: Int
        let end: Int
    }

    enum Value {
        case integer(Int64)
        case floatingPoint(Double)
        case decimal(Decimal)
        case numericStringRepresentation(String)

        var fallbackDescription: String {
            switch self {
            case .integer(let i): return String(i)
            case .floatingPoint(let d): return String(d)
            case .decimal(let d): return d.description
            case .numericStringRepresentation(let i): return i
            }
        }
    }

    func attributedStringFromPositions(_ positions: [ICUNumberFormatter.AttributePosition], string: String) -> AttributedString {
        typealias NumberPartAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart
        typealias NumberSymbolAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol

        var attrstr = AttributedString(string)
        for attr in positions {

            let strRange = String.Index(utf16Offset: attr.begin, in: string) ..<
                String.Index(utf16Offset: attr.end, in: string)
            let range = Range<AttributedString.Index>(strRange, in: attrstr)!


            let field = attr.field
            var container = AttributeContainer()

            if let part = NumberPartAttribute(unumberFormatField: field) {
                container.numberPart = part
            }

            if let symbol = NumberSymbolAttribute(unumberFormatField: field) {
                container.numberSymbol = symbol
            }

            attrstr[range].mergeAttributes(container)
        }

        return attrstr
    }

    func attributedFormatPositions(_ v: Value) -> (String, [AttributePosition])? {
        var result: FormatResult?
        switch v {
        case .integer(let v):
            result = try? FormatResult(formatter: uformatter, value: v)
        case .floatingPoint(let v):
            result = try? FormatResult(formatter: uformatter, value: v)
        case .decimal(let v):
            result = try? FormatResult(formatter: uformatter, value: v)
        case .numericStringRepresentation(let v):
            result = try? FormatResult(formatter: uformatter, value: v)
        }

        guard let result, let str = result.string else {
            return nil
        }

        do {
            let positer = try ICU.FieldPositer()

            var status = U_ZERO_ERROR
            unumf_resultGetAllFieldPositions(result.result, positer.positer, &status)
            try status.checkSuccess()

            let attributePositions = positer.fields.compactMap { next -> AttributePosition? in
                return AttributePosition(field: UNumberFormatFields(CInt(next.field)), begin: next.begin, end: next.end)
            }

            return (str, attributePositions)
        } catch {
            return nil
        }
    }

    func format(_ v: Int64) -> String? {
        try? FormatResult(formatter: uformatter, value: v).string
    }

    func format(_ v: Double) -> String? {
        try? FormatResult(formatter: uformatter, value: v).string
    }

    func format(_ v: Decimal) -> String? {
        try? FormatResult(formatter: uformatter, value: v).string
    }

    func format(_ v: String) -> String? {
        try? FormatResult(formatter: uformatter, value: v).string
    }

    // MARK: -

    class FormatResult {
        var result: OpaquePointer

        init(formatter: OpaquePointer, value: Int64) throws {
            var status = U_ZERO_ERROR
            result = unumf_openResult(&status)
            try status.checkSuccess()
            unumf_formatInt(formatter, value, result, &status)
            try status.checkSuccess()
        }

        init(formatter: OpaquePointer, value: Double) throws {
            var status = U_ZERO_ERROR
            result = unumf_openResult(&status)
            try status.checkSuccess()
            unumf_formatDouble(formatter, value, result, &status)
            try status.checkSuccess()
        }

        init(formatter: OpaquePointer, value: Decimal) throws {
            var status = U_ZERO_ERROR
            result = unumf_openResult(&status)
            try status.checkSuccess()
#if FOUNDATION_FRAMEWORK // TODO: Remove this when Decimal is moved
            var v = value
            var str = NSDecimalString(&v, nil)
#else
            var str = value.description
#endif // FOUNDATION_FRAMEWORK
            str.withUTF8 {
                unumf_formatDecimal(formatter, $0.baseAddress, Int32($0.count), result, &status)
            }
            try status.checkSuccess()
        }

        init(formatter: OpaquePointer, value: String) throws {
            var status = U_ZERO_ERROR
            result = unumf_openResult(&status)
            try status.checkSuccess()
            
            var value = value
            value.withUTF8 {
                unumf_formatDecimal(formatter, $0.baseAddress, Int32($0.count), result, &status)
            }
            
            try status.checkSuccess()
        }

        deinit {
            unumf_closeResult(result)
        }

        var string: String? {
            return _withResizingUCharBuffer { buffer, size, status in
                unumf_resultToString(result, buffer, size, &status)
            }
        }
    }
}

// MARK: - Integer

final class ICUNumberFormatter : ICUNumberFormatterBase {
    fileprivate struct Signature : Hashable {
        let collection: NumberFormatStyleConfiguration.Collection
        let localeIdentifier: String
        let localePreferences: LocalePreferences?
    }

    fileprivate static let cache = FormatterCache<Signature, ICUNumberFormatter?>()

    private static func _create(with signature: Signature) -> ICUNumberFormatter? {
        Self.cache.formatter(for: signature) {
            .init(skeleton: signature.collection.skeleton, localeIdentifier: signature.localeIdentifier, preferences: signature.localePreferences)
        }
    }

    static func create<T: BinaryInteger>(for style: IntegerFormatStyle<T>) -> ICUNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create(for style: Decimal.FormatStyle) -> ICUNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create<T: BinaryFloatingPoint>(for style: FloatingPointFormatStyle<T>) -> ICUNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    func attributedFormat(_ v: Value) -> AttributedString {
        guard let (str, attributes) = attributedFormatPositions(v) else {
            return AttributedString(v.fallbackDescription)
        }
        return attributedStringFromPositions(attributes, string: str)
    }
}

// MARK: - Currency

final class ICUCurrencyNumberFormatter : ICUNumberFormatterBase {
    fileprivate struct Signature : Hashable {
        let collection: CurrencyFormatStyleConfiguration.Collection
        let currencyCode: String
        let localeIdentifier: String
        let localePreferences: LocalePreferences?
    }

    private static func skeleton(for signature: Signature) -> String {
        var s = "currency/\(signature.currencyCode)"

        let stem = signature.collection.skeleton
        if stem.count > 0 {
            s += " " + stem
        }

        return s
    }

    fileprivate static let cache = FormatterCache<Signature, ICUCurrencyNumberFormatter?>()

    static private func _create(with signature: Signature) -> ICUCurrencyNumberFormatter? {
        return Self.cache.formatter(for: signature) {
            .init(skeleton: Self.skeleton(for: signature), localeIdentifier: signature.localeIdentifier, preferences: signature.localePreferences)
        }
    }

    static func create<T: BinaryInteger>(for style: IntegerFormatStyle<T>.Currency) -> ICUCurrencyNumberFormatter? {
        _create(with: .init(collection: style.collection, currencyCode: style.currencyCode, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create(for style: Decimal.FormatStyle.Currency) -> ICUCurrencyNumberFormatter? {
        _create(with: .init(collection: style.collection, currencyCode: style.currencyCode, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create<T: BinaryFloatingPoint>(for style: FloatingPointFormatStyle<T>.Currency) -> ICUCurrencyNumberFormatter? {
        _create(with: .init(collection: style.collection, currencyCode: style.currencyCode, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    func attributedFormat(_ v: Value) -> AttributedString {
        guard let (str, attributes) = attributedFormatPositions(v) else {
            return AttributedString(v.fallbackDescription)
        }
        return attributedStringFromPositions(attributes, string: str)
    }
}

// MARK: - Integer Percent

final class ICUPercentNumberFormatter : ICUNumberFormatterBase {
    fileprivate struct Signature : Hashable {
        let collection: NumberFormatStyleConfiguration.Collection
        let localeIdentifier: String
        let localePreferences: LocalePreferences?
    }

    private static func skeleton(for signature: Signature) -> String {
        var s = "percent"
        let stem = signature.collection.skeleton
        if stem.count > 0 {
            s += " " + stem
        }
        return s
    }

    fileprivate static let cache = FormatterCache<Signature, ICUPercentNumberFormatter?>()

    private static func _create(with signature: Signature) -> ICUPercentNumberFormatter? {
        return Self.cache.formatter(for: signature) {
            .init(skeleton: Self.skeleton(for: signature), localeIdentifier: signature.localeIdentifier, preferences: signature.localePreferences)
        }
    }

    static func create<T: BinaryInteger>(for style: IntegerFormatStyle<T>.Percent) -> ICUPercentNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create(for style: Decimal.FormatStyle.Percent) -> ICUPercentNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    static func create<T: BinaryFloatingPoint>(for style: FloatingPointFormatStyle<T>.Percent) -> ICUPercentNumberFormatter? {
        _create(with: .init(collection: style.collection, localeIdentifier: style.locale.identifierCapturingPreferences, localePreferences: style.locale.prefs))
    }

    func attributedFormat(_ v: Value) -> AttributedString {
        guard let (str, attributes) = attributedFormatPositions(v) else {
            return AttributedString(v.fallbackDescription)
        }
        return attributedStringFromPositions(attributes, string: str)
    }
}

// MARK: - Byte Count

final class ICUByteCountNumberFormatter : ICUNumberFormatterBase {
    fileprivate struct Signature : Hashable {
        let skeleton: String
        let localeIdentifier: String
        let localePreferences: LocalePreferences?
    }

    fileprivate static let cache = FormatterCache<Signature, ICUByteCountNumberFormatter?>()

    static func create(for skeleton: String, locale: Locale) -> ICUByteCountNumberFormatter? {
        let signature = Signature(skeleton: skeleton, localeIdentifier: locale.identifierCapturingPreferences, localePreferences: locale.prefs)
        return Self.cache.formatter(for: signature) {
            .init(skeleton: skeleton, localeIdentifier: locale.identifierCapturingPreferences, preferences: locale.prefs)
        }
    }

    func attributedFormat(_ v: Value, unit: ByteCountFormatStyle.Unit) -> AttributedString {
        guard let (str, attributes) = attributedFormatPositions(v) else {
            return AttributedString(v.fallbackDescription)
        }
        return attributedStringFromPositions(attributes, string: str, unit: unit)
    }

    private func attributedStringFromPositions(_ positions: [ICUNumberFormatter.AttributePosition], string: String, unit: ByteCountFormatStyle.Unit) -> AttributedString {
        typealias NumberPartAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart
        typealias NumberSymbolAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol
        typealias ByteCountAttribute = AttributeScopes.FoundationAttributes.ByteCountAttribute.Component

        var attrstr = AttributedString(string)
        for attr in positions {

            let strRange = String.Index(utf16Offset: attr.begin, in: string) ..<
                String.Index(utf16Offset: attr.end, in: string)
            let range = Range<AttributedString.Index>(strRange, in: attrstr)!

            let field = attr.field
            var container = AttributeContainer()

            if let part = NumberPartAttribute(unumberFormatField: field) {
                container.numberPart = part
            }

            if let symbol = NumberSymbolAttribute(unumberFormatField: field) {
                container.numberSymbol = symbol
            }

            if let comp = ByteCountAttribute(unumberFormatField: field, unit: unit) {
                container.byteCount = comp
            }

            attrstr[range].mergeAttributes(container)
        }

        return attrstr
    }
}

// MARK: - Measurement

final class ICUMeasurementNumberFormatter : ICUNumberFormatterBase {
    fileprivate struct Signature : Hashable {
        let skeleton: String
        let localeIdentifier: String
        let localePreferences: LocalePreferences?
    }

    fileprivate static let cache = FormatterCache<Signature, ICUMeasurementNumberFormatter?>()

    static func create(for skeleton: String, locale: Locale) -> ICUMeasurementNumberFormatter? {
        let signature = Signature(skeleton: skeleton, localeIdentifier: locale.identifierCapturingPreferences, localePreferences: locale.prefs)
        return Self.cache.formatter(for: signature) {
            .init(skeleton: skeleton, localeIdentifier: locale.identifierCapturingPreferences, preferences: locale.prefs)
        }
    }

    func attributedFormat(_ v: Value) -> AttributedString {
        guard let (str, attributes) = attributedFormatPositions(v) else {
            return AttributedString(v.fallbackDescription)
        }
        return attributedStringFromPositions(attributes, string: str)
    }

    /// Overrides superclass implementation to add the `MeasurementAttribute` property.
    override func attributedStringFromPositions(_ positions: [ICUNumberFormatter.AttributePosition], string: String) -> AttributedString {
        typealias NumberPartAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.NumberPartAttribute.NumberPart
        typealias NumberSymbolAttribute = AttributeScopes.FoundationAttributes.NumberFormatAttributes.SymbolAttribute.Symbol
        typealias MeasurementAttribute = AttributeScopes.FoundationAttributes.MeasurementAttribute.Component

        var attrstr = AttributedString(string)
        for attr in positions {

            let strRange = String.Index(utf16Offset: attr.begin, in: string) ..<
                String.Index(utf16Offset: attr.end, in: string)
            let range = Range<AttributedString.Index>(strRange, in: attrstr)!
            let field = attr.field
            var container = AttributeContainer()

            if let part = NumberPartAttribute(unumberFormatField: field) {
                container.numberPart = part
            }

            if let symbol = NumberSymbolAttribute(unumberFormatField: field) {
                container.numberSymbol = symbol
            }

            if let comp = MeasurementAttribute(unumberFormatField: field) {
                container.measurement = comp
            }

            attrstr[range].mergeAttributes(container)
        }

        return attrstr
    }

    // The raw values are for use with ICU's API. They should match CLDR's declaration at https://github.com/unicode-org/cldr/blob/master/common/supplemental/units.xml
    internal enum Usage: String {
        // common
        case general = "default"
        case person
        // energy
        case food
        // length
        case personHeight = "person-height"
        case road
        case focalLength = "focal-length"
        case rainfall
        case snowfall
        case visibility = "visiblty"
        // pressure
        case barometric = "baromtrc"
        // speed
        case wind
        // temperature
        case weather
        // volume
        case fluid
        // Foundation's flag: Do not convert to preferred unit
        case asProvided
    }

    enum UnitWidth: String, Codable {
        case wide = "unit-width-full-name"
        case abbreviated = "unit-width-short"
        case narrow = "unit-width-narrow"

        init(_ width: Duration.UnitsFormatStyle.UnitWidth) {
            switch width.width.option {
            case .wide:
                self = .wide
            case .abbreviated:
                self = .abbreviated
            case .narrow:
                self = .narrow
            }
        }
    }

    static func skeleton(_ unitSkeleton: String?, width: UnitWidth, usage: Usage?, numberFormatStyle: FloatingPointFormatStyle<Double>?) -> String {
        var stem = ""
        if let unitSkeleton = unitSkeleton {
            stem += unitSkeleton + " " + width.rawValue
            if let usage {
                // ICU handles the conversion when using the `usage` skeleton.
                stem += " usage/" + usage.rawValue
            }
        }
        if let numberFormatSkeleton = numberFormatStyle?.collection.skeleton {
            if stem.count > 0 {
                stem += " "
            }
            stem += numberFormatSkeleton
        }
        return stem
    }
}
