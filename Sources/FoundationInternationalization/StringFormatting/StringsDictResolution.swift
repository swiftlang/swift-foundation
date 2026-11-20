//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

extension ParsedFormatSpec {
    #if !FOUNDATION_FRAMEWORK && !hasFeature(Embedded)
    @_dynamicReplacement(for: innerFormatInfo(in:from:))
    #endif
    func innerFormatInfo_localized(in format: StringContents, from config: StringsDictConfig?) throws(CocoaError) -> StringsDictConfig.InnerFormatInfo? {
        #if FOUNDATION_FRAMEWORK && ICU
        guard let configArgument = self.config, let rule = StringsDictFormattingRule(for: configArgument, in: config, keyString: configArgument.keyString(in: format)) else {
            return nil
        }
        // TODO: Should this be cached?
        if let innerFormat = rule.formatValueType, !innerFormat.isEmpty {
            let parsedSpec = try ParsedFormatSpec(parsingFrom: innerFormat.utf8.span, withoutPercent: true)
            if parsedSpec.kind.usesArgument {
                return StringsDictConfig.InnerFormatInfo(innerFormat: innerFormat, innerKind: parsedSpec.kind)
            } else {
                return StringsDictConfig.InnerFormatInfo(innerFormat: innerFormat, innerKind: nil)
            }
        }
        return StringsDictConfig.InnerFormatInfo(innerFormat: nil, innerKind: nil)
        #else
        return nil
        #endif
    }
}

#if FOUNDATION_FRAMEWORK && ICU

internal import _FoundationICU
internal import CoreFoundation_Private
internal import CoreFoundation_Private.CFString

enum StringsDictFormattingRule {
    /// An entry from the stringsdict, of which only pluralization rules are supported
    case stringsDict(StringsDictConfig.RuleConfig)

    /// The built-in rule for the `%#[tt]@` entity marker
    case technicalTerm

    /// The built-in rule for `%#[VocativeName]@` entity markers (any key with the `VocativeName` prefix)
    case vocativeName

    /// The result of resolving a rule for an argument
    enum Resolution {
        /// A format string to format with the arguments, starting at the spec's argument
        case format(String)
        /// Text to append as-is
        case literal(String)
    }

    init?(for config: ParsedFormatSpec.ConfigArgument, in stringsDict: StringsDictConfig?, keyString: String) {
        if config.entityMarker {
            if keyString.utf8.elementsEqual("tt".utf8) {
                self = .technicalTerm
            } else if keyString.utf8.starts(with: "VocativeName".utf8) {
                self = .vocativeName
            } else {
                return nil
            }
        } else {
            guard let contents = stringsDict?[keyString] else {
                return nil
            }
            self = .stringsDict(contents)
        }
    }

    /// Whether this is a pluralization rule without a value type, which uses the pluralization number instead of an argument
    var usesPluralizationNumber: Bool {
        guard case .stringsDict(let contents) = self else {
            return false
        }
        return contents[kCFStringFormatValueTypeKey] == nil && Self.isPluralRule(contents)
    }

    var formatValueType: String? {
        switch self {
        case .stringsDict(let contents):
            contents[kCFStringFormatValueTypeKey] as? String
        case .technicalTerm, .vocativeName:
            "@"
        }
    }

    func resolve(specKind: ParsedFormatSpec.Kind, object: _VarArgs.Argument, locale: Locale?) -> Resolution? {
        switch self {
        case .stringsDict(let contents):
            // Other stringsdict rule types (gender, affix, entity formatting, and vocative names) are unsupported
            guard Self.isPluralRule(contents) else {
                return nil
            }
            let resolvedLocale = contents[kCFStringFormatLocaleKey] as? Locale ?? locale ?? Locale.current
            return Self.resolvePlural(contents, specKind: specKind, object: object, locale: resolvedLocale).map(Resolution.format)
        case .technicalTerm:
            let value = object.pointerValue.flatMap { unsafeBitCast($0, to: AnyObject.self) as? String }
            return Self.resolveTechnicalTerm(value, locale: locale ?? Locale.current).map(Resolution.format)
        case .vocativeName:
            guard let pointer = object.pointerValue else {
                return nil
            }
            return Self.resolveVocativeName(unsafeBitCast(pointer, to: AnyObject.self), locale: locale ?? Locale.current).map(Resolution.literal)
        }
    }
}

// MARK: - Pluralization

extension StringsDictFormattingRule {
    private static func isPluralRule(_ contents: StringsDictConfig.RuleConfig) -> Bool {
        contents[kCFStringFormatSpecTypeKey] as? String == kCFStringPluralRuleType as String
    }

    private static func operandNumber(from object: _VarArgs.Argument, specKind: ParsedFormatSpec.Kind) -> (doubleValue: Double?, integerValue: Int64?)? {
        switch specKind {
        case .integer(_):
            return (Double(object.integerValue), object.integerValue)
        case .double(_):
            return (object.doubleValue, nil)
        case .pointer:
            return (Double(object.integerValue), nil)
        case .object:
            guard let pointer = object.pointerValue,
                  let number = unsafeBitCast(pointer, to: AnyObject.self) as? NSNumber,
                  CFGetTypeID(number) == CFNumberGetTypeID() else {
                // If the pointer is null, the value is not an NSNumber, or the NSNumber is not a CFNumber (i.e. it represents a boolean), we can't use the operand as a number
                return nil
            }
            var doubleValue = 0.0
            let doubleSuccess = CFNumberGetValue(number, .doubleType, &doubleValue)
            var int64Value: Int64 = 0
            let int64Success = !CFNumberIsFloatType(number) && CFNumberGetValue(number, .sInt64Type, &int64Value)
            return (doubleSuccess ? doubleValue : nil, int64Success ? int64Value : nil)
        default:
            return nil
        }
    }

    private static func resolvePlural(_ contents: StringsDictConfig.RuleConfig, specKind: ParsedFormatSpec.Kind, object: _VarArgs.Argument, locale: Locale) -> String? {
        guard let (doubleValue, integerValue) = operandNumber(from: object, specKind: specKind) else {
            return nil
        }
        // Only use special cases for actual integer values
        if integerValue == 0, let zero = contents["zero"] {
            return zero as? String
        }
        if integerValue == Int64(NSNotFound), let other = contents["other"] {
            // special case for an "unknown" quantity
            return other as? String
        }

        if let doubleValue {
            let localeIdentifier = locale.identifier
            var status = U_ZERO_ERROR
            let uplrule = localeIdentifier.withCString {
                uplrules_open($0, &status)
            }
            defer { uplrules_close(uplrule) }

            if status.isSuccess {
                let key = withUnsafeTemporaryAllocation(of: UTF16.CodeUnit.self, capacity: Int(ULOC_FULLNAME_CAPACITY)) { buffer -> String? in
                    let length = uplrules_select(uplrule, doubleValue, buffer.baseAddress, Int32(buffer.count), &status)
                    if status.isSuccess && length > 0 {
                        return String(decoding: buffer.extracting(first: Int(length)), as: UTF16.self)
                    } else {
                        return nil
                    }
                }
                if let key, let value = contents[key] {
                    return value as? String
                }
            }
        }

        if integerValue == 1, let one = contents["one"] {
            return one as? String
        } else {
            return contents["other"] as? String
        }
    }
}

// MARK: - Technical Term

extension StringsDictFormattingRule {
    private enum TechnicalTermLocalization: String, CaseIterable {
        case `default`
        case en
        case fi
        case ja
        case th
        case zhHans = "zh-Hans"
        case zhHant = "zh-Hant"

        init?(for locale: Locale) {
            let matching = Bundle.preferredLocalizations(from: Self.allCases.map(\.rawValue), forPreferences: [locale.identifier])
            guard let identifier = Bundle.preferredLocalizations(from: matching).first else {
                return nil
            }
            self = Self(rawValue: identifier) ?? .default
        }
    }

    private static func resolveTechnicalTerm(_ value: String?, locale: Locale) -> String? {
        guard let localization = TechnicalTermLocalization(for: locale) else {
            return nil
        }
        switch localization {
        case .default:
            return value == nil ? nil : "%@"
        case .en:
            return "%@"
        case .fi:
            // Values containing whitespace (general category Zs or a tab) are followed by a space
            if let value, locale.language.languageCode?.identifier == "fi", value.unicodeScalars.contains(where: { $0 == "\t" || $0.properties.generalCategory == .spaceSeparator }) {
                return "%@ "
            }
            return "%@"
        case .ja, .zhHans, .zhHant:
            guard let value else {
                return nil
            }
            // Values are quoted unless they are entirely Latin, with CJK taking precedence when both match (ex. an empty string). Spaces don't count against membership.
            func isEntirely(_ family: EntityFamily) -> Bool {
                value.unicodeScalars.allSatisfy { $0 == " " || family.contains($0) }
            }
            if !isEntirely(.cjk) && isEntirely(.latin) {
                return "%@"
            }
            return localization == .zhHant ? "「%@」" : "“%@”"
        case .th:
            guard let value else {
                return " %@ "
            }
            guard let first = value.utf16.first, let last = value.utf16.last else {
                // An empty string is treated as a string in the locale's language
                return locale.language.languageCode?.identifier == "th" ? "%@" : nil
            }
            // Values are separated by spaces on each side that doesn't start or end with a Thai character
            let leading = EntityFamily.thai.contains(first) ? "" : " "
            let trailing = EntityFamily.thai.contains(last) ? "" : " "
            return leading + "%@" + trailing
        }
    }
}

private struct EntityFamily: @unchecked Sendable {
    private let set: OpaquePointer

    static let cjk = EntityFamily(pattern: "[[:Hani:][:Hiragana:][:Katakana:][:Katakana_Or_Hiragana:][:Bopomofo:][:Hangul:][ˉˊˇˋ˙]]")
    static let latin = EntityFamily(pattern: "[[:Latin:]]")
    static let thai = EntityFamily(pattern: "[[:Thai:]]")

    private init(pattern: String) {
        let utf16 = Array(pattern.utf16)
        var status = U_ZERO_ERROR
        let set = utf16.withUnsafeBufferPointer { uset_openPattern($0.baseAddress, Int32($0.count), &status) }
        guard status.isSuccess, let set else {
            preconditionFailure("Failed to create the character set for \(pattern)")
        }
        uset_freeze(set)
        self.set = set
    }

    func contains(_ scalar: Unicode.Scalar) -> Bool {
        uset_contains(set, UChar32(bitPattern: scalar.value)) != 0
    }

    func contains(_ codeUnit: UTF16.CodeUnit) -> Bool {
        Unicode.Scalar(codeUnit).map(contains) ?? false
    }
}

// MARK: - Vocative Name

extension StringsDictFormattingRule {
    private static func resolveVocativeName(_ object: AnyObject, locale: Locale) -> String? {
        if let name = object as? String {
            return vocativeCase(ofGivenName: name, locale: locale)
        }
        // Person name components use the vocative case of their given name, formatted with a default name formatter
        guard var components = object as? PersonNameComponents,
              let givenName = components.givenName,
              let vocative = vocativeCase(ofGivenName: givenName, locale: locale) else {
            return nil
        }
        components.givenName = vocative
        // Ideally we'd use PersonNameComponents.FormatStyle here, but we need to configure the formatter without a locale (to use the user's name order preference) and the FormatStyle always applies a locale (which uses the locale's name order preference)
        return PersonNameComponentsFormatter().string(from: components)
    }

    private static func vocativeCase(ofGivenName name: String, locale: Locale) -> String? {
        _CFStringCopyVocativeCaseOfGivenName(name as CFString, locale as CFLocale)?.takeRetainedValue() as String?
    }
}

#endif
