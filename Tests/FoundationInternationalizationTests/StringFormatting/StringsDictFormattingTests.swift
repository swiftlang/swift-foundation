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

#if FOUNDATION_FRAMEWORK && ICU
import Testing
@_spi(Localization) @testable import Foundation

private enum StringsDictRule {
    case files, folders, filesIn, allForms, noZero, nested, inner, longs, doubles, objects, russian
    case things, countedThings, loop

    var configuration: [String: Any] {
        switch self {
        case .files: Self.plural("d", ["one": "%d file", "other": "%d files"])
        case .folders: Self.plural("d", ["one": "%d folder", "other": "%d folders"])
        case .filesIn: Self.plural("d", ["one": "%d file in %@", "other": "%d files in %@"])
        case .allForms: Self.plural("d", ["zero": "%d zero", "one": "%d one", "two": "%d two", "few": "%d few", "many": "%d many", "other": "%d other"])
        case .noZero: Self.plural("d", ["one": "%d one", "two": "%d two", "few": "%d few", "many": "%d many", "other": "%d other"])
        case .nested: Self.plural("d", ["other": "%#@inner@"])
        case .inner: Self.plural("d", ["one": "%d inner one", "other": "%d inner"])
        case .longs: Self.plural("ld", ["one": "%ld item", "other": "%ld items"])
        case .doubles: Self.plural("f", ["one": "%.1f star", "other": "%.1f stars"])
        case .objects: Self.plural("@", ["one": "%@ thing", "other": "%@ things"])
        case .russian: Self.plural("d", ["one": "%d one", "few": "%d few", "many": "%d many", "other": "%d other"], locale: "ru")
        case .things: Self.plural(nil, ["zero": "none", "one": "one thing", "other": "some things"])
        case .countedThings: Self.plural(nil, ["one": "%d thing", "other": "%d things"])
        case .loop: Self.plural("d", ["other": "%#@loop@"])
        }
    }

    private static func plural(_ valueType: String?, _ forms: [String: String], locale: String? = nil) -> [String: Any] {
        var rule: [String: Any] = forms
        rule["NSStringFormatSpecTypeKey"] = "NSStringPluralRuleType"
        if let valueType {
            rule["NSStringFormatValueTypeKey"] = valueType
        }
        if let locale {
            rule["NSStringFormatLocaleKey"] = NSLocale(localeIdentifier: locale)
        }
        return rule
    }
}

private func configuredFormat(_ format: String, _ rules: [String: StringsDictRule]) -> String {
    let configuration = rules.mapValues(\.configuration) as NSDictionary
    return (format as NSString).perform(Selector(("_copyFormatStringWithConfiguration:")), with: configuration).takeRetainedValue() as! String
}

private func checkConfiguredFormat(_ format: String, _ rules: [String: StringsDictRule], _ arguments: any CVarArg..., locale: String? = nil, expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    withVaList(arguments) { argsPointer in
        let result = String(_format: configuredFormat(format, rules), pluralizationNumber: nil, locale: locale.map(Locale.init(identifier:)), args: argsPointer)
        #expect(result == expectation, sourceLocation: sourceLocation)
    }
}

private func checkPluralization(_ format: String, _ rules: [String: StringsDictRule], pluralizationNumber: String.LocalizationOptions._PluralizationNumber?, _ arguments: any CVarArg..., expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let result = withVaList(arguments) {
        String(_format: configuredFormat(format, rules), pluralizationNumber: pluralizationNumber, locale: Locale(identifier: "en_US"), args: $0)
    }
    #expect(result == expectation, sourceLocation: sourceLocation)
}

private func validatedFormat(_ format: String, validFormatSpecifiers: String, locale: Locale? = nil, arguments: [any CVarArg]) throws -> String {
    try withVaList(arguments) { args in
        Result {
            try String(_format: format, validFormatSpecifiers: validFormatSpecifiers, pluralizationNumber: nil, locale: locale, args: args)
        }
    }.get()
}

private func checkValidFormat(_ format: String, validFormatSpecifiers: String, _ arguments: any CVarArg..., locale: String? = nil, expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        let result = try validatedFormat(format, validFormatSpecifiers: validFormatSpecifiers, locale: locale.map(Locale.init(identifier:)), arguments: arguments)
        #expect(result == expectation, sourceLocation: sourceLocation)
    } catch {
        Issue.record(error, sourceLocation: sourceLocation)
    }
}

private func checkInvalidFormat(_ format: String, validFormatSpecifiers: String, _ arguments: any CVarArg..., locale: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(throws: CocoaError.self, sourceLocation: sourceLocation) {
        try validatedFormat(format, validFormatSpecifiers: validFormatSpecifiers, locale: locale.map(Locale.init(identifier:)), arguments: arguments)
    }
}

@Suite("Stringsdict Formatting")
struct StringsDictFormattingTests {
    @Test func pluralRules() {
        checkConfiguredFormat("%#@n@", ["n": .files], Int32(0), locale: "en_US", expectation: "0 files")
        checkConfiguredFormat("%#@n@", ["n": .files], Int32(1), locale: "en_US", expectation: "1 file")
        checkConfiguredFormat("%#@n@", ["n": .files], Int32(2), locale: "en_US", expectation: "2 files")
        checkConfiguredFormat("%#@n@", ["n": .files], Int32(1000), locale: "en_US", expectation: "1,000 files")
        checkConfiguredFormat("%#@n@", ["n": .files], Int32(1234), locale: "de_DE", expectation: "1.234 files")
        checkConfiguredFormat("%#@n@", ["n": .allForms], Int32(0), locale: "en_US", expectation: "0 zero")
        checkConfiguredFormat("%#@n@", ["n": .allForms], Int32(1), locale: "en_US", expectation: "1 one")
        checkConfiguredFormat("%#@n@", ["n": .allForms], Int32(2), locale: "en_US", expectation: "2 other")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(0), locale: "ru", expectation: "0 many")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(1), locale: "ru", expectation: "1 one")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(2), locale: "ru", expectation: "2 few")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(3), locale: "ru", expectation: "3 few")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(5), locale: "ru", expectation: "5 many")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(21), locale: "ru", expectation: "21 one")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(0), locale: "ar", expectation: "0 other")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(1), locale: "ar", expectation: "1 one")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(2), locale: "ar", expectation: "2 two")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(3), locale: "ar", expectation: "3 few")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(11), locale: "ar", expectation: "11 many")
        checkConfiguredFormat("%#@n@", ["n": .noZero], Int32(100), locale: "ar", expectation: "100 other")
        checkConfiguredFormat("%#@n@", ["n": .russian], Int32(2), locale: "en_US", expectation: "2 few")
    }

    @Test func valueTypes() {
        checkConfiguredFormat("%#@n@", ["n": .longs], 1, locale: "en_US", expectation: "1 item")
        checkConfiguredFormat("%#@n@", ["n": .doubles], 1.5, locale: "en_US", expectation: "1.5 stars")
        checkConfiguredFormat("%#@n@", ["n": .objects], NSNumber(value: 1), locale: "en_US", expectation: "1 thing")
        checkConfiguredFormat("%#@n@", ["n": .objects], NSNumber(value: 2), locale: "en_US", expectation: "2 things")
    }

    @Test func structure() {
        checkConfiguredFormat("Found %#@n@.", ["n": .files], Int32(1), locale: "en_US", expectation: "Found 1 file.")
        checkConfiguredFormat("%#@n@ in %#@m@", ["n": .files, "m": .folders], Int32(1), Int32(2), locale: "en_US", expectation: "1 file in 2 folders")
        checkConfiguredFormat("%2$#@m@ then %1$#@n@", ["n": .files, "m": .folders], Int32(1), Int32(2), locale: "en_US", expectation: "2 folders then 1 file")
        checkConfiguredFormat("%@: %#@n@", ["n": .files], "Docs", Int32(3), locale: "en_US", expectation: "Docs: 3 files")
        checkConfiguredFormat("%d %#@n@ %d", ["n": .files], Int32(7), Int32(1), Int32(9), locale: "en_US", expectation: "7 1 file 9")
        checkConfiguredFormat("%#@n@", ["n": .filesIn], Int32(3), "dir", locale: "en_US", expectation: "3 files in dir")
        checkConfiguredFormat("%#@n@", ["n": .nested, "inner": .inner], Int32(1), locale: "en_US", expectation: "1 inner one")
        checkConfiguredFormat("%#@missing@", ["n": .files], Int32(1), locale: "en_US", expectation: "%#@missing@")
        checkConfiguredFormat("%#@n@ %#@missing@", ["n": .files], Int32(1), locale: "en_US", expectation: "1 file %#@missing@")
    }

    @Test func technicalTerms() {
        checkConfiguredFormat("Use %#[tt]@.", [:], "iPhone", locale: "en_US", expectation: "Use iPhone.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "iPhone", locale: "de_DE", expectation: "Use iPhone.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "iPhone", locale: "ja", expectation: "Use iPhone.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "日本語", locale: "ja", expectation: "Use “日本語”.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "日本語", locale: "zh-Hans", expectation: "Use “日本語”.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "中文", locale: "zh-Hant", expectation: "Use 「中文」.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "ไทย", locale: "th", expectation: "Use ไทย.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "iPhone", locale: "th", expectation: "Use  iPhone .")
        checkConfiguredFormat("Use %#[tt]@.", [:], "iPhoneไทย", locale: "th", expectation: "Use  iPhoneไทย.")
        checkConfiguredFormat("Use %#[tt]@.", [:], "Mac mini", locale: "fi", expectation: "Use Mac mini .")
        checkConfiguredFormat("Use %#[tt]@.", [:], NSNumber(value: 5), locale: "ja", expectation: "Use (null).")
        checkConfiguredFormat("%[tt]@ and %#[tt]@", [:], "iPhone", "日本", locale: "ja", expectation: "iPhone and “日本”")
    }

    @Test func vocativeNames() {
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Jana", locale: "cs", expectation: "Hi Jano!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Petr", locale: "cs", expectation: "Hi Petře!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Νίκος", locale: "el", expectation: "Hi Νίκο!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Олена", locale: "uk", expectation: "Hi Олено!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Jonas", locale: "lt", expectation: "Hi Jonai!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Jana", locale: "en_US", expectation: "Hi Jana!")
        checkConfiguredFormat("Hi %#[VocativeNameGiven]@!", [:], "Jana", locale: "cs", expectation: "Hi Jano!")
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], NSNumber(value: 5), locale: "cs", expectation: "Hi (null)!")
    }

    @Test("Vocative names are not treated as format strings")
    func vocativeNamesAreLiteral() {
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], "Ann%@", locale: "cs", expectation: "Hi Ann%@!")
    }

    @Test func vocativeNamesFromPersonNameComponents() {
        let person = NSPersonNameComponents()
        person.givenName = "Petr"
        checkConfiguredFormat("Hi %#[VocativeName]@!", [:], person, locale: "cs", expectation: "Hi Petře!")
    }

    @Test func pluralizationNumber() {
        checkPluralization("%#@pn@", ["pn": .things], pluralizationNumber: .specific(0), expectation: "none")
        checkPluralization("%#@pn@", ["pn": .things], pluralizationNumber: .specific(1), expectation: "one thing")
        checkPluralization("%#@pn@", ["pn": .things], pluralizationNumber: .specific(5), expectation: "some things")
        checkPluralization("%#@pn@", ["pn": .things], pluralizationNumber: .unknown, expectation: "some things")
        checkPluralization("%#@pn@", ["pn": .things], pluralizationNumber: nil, expectation: "(null)")
        checkPluralization("%#@pn@", ["pn": .countedThings], pluralizationNumber: .specific(1), Int32(7), expectation: "7 thing")
        checkPluralization("%d, %#@pn@", ["pn": .countedThings], pluralizationNumber: .specific(2), Int32(3), Int32(7), expectation: "3, 7 things")
    }

    @Test func selfReferencingKeyThrows() {
        checkInvalidFormat(configuredFormat("%#@loop@", ["loop": .loop]), validFormatSpecifiers: "%d", Int32(1))
    }

    @Test func stringsDictValidFormatSpecifiers() {
        let format = configuredFormat("%#@n@", ["n": .files])
        checkValidFormat(format, validFormatSpecifiers: "%d", Int32(1), locale: "en_US", expectation: "1 file")
        checkInvalidFormat(format, validFormatSpecifiers: "%@", "x", locale: "en_US")
    }
}

#endif
