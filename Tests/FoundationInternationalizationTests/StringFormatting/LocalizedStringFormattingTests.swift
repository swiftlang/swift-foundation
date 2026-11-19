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

import Testing

#if canImport(TestSupport)
import TestSupport
#endif

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

private func formatted(_ format: String, arguments: [any CVarArg], locale: String?) -> String {
    withVaList(arguments) {
        String(_format: format, pluralizationNumber: nil, locale: locale.map(Locale.init(identifier:)), args: $0)
    }
}

private func formatted(_ format: String, _ arguments: any CVarArg..., locale: String?) -> String {
    formatted(format, arguments: arguments, locale: locale)
}

private func checkFormat(_ format: String, _ arguments: any CVarArg..., locale: String?, expectation: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(formatted(format, arguments: arguments, locale: locale) == expectation, sourceLocation: sourceLocation)
}

@Suite("Localized String Formatting")
struct LocalizedStringFormattingTests {
    @Test func integers() {
        checkFormat("%d", Int32(1234567), locale: "en_US", expectation: "1,234,567")
        checkFormat("%d", Int32(1234567), locale: "de_DE", expectation: "1.234.567")
        checkFormat("%d", Int32(1234567), locale: "fr_FR", expectation: "1\u{202F}234\u{202F}567")
        checkFormat("%d", Int32(1234567), locale: "hi_IN", expectation: "12,34,567")
        checkFormat("%d", Int32(1234567), locale: "ar", expectation: "1,234,567")
        checkFormat("%d", Int32(1234567), locale: "ar_SA", expectation: "١٬٢٣٤٬٥٦٧")
        checkFormat("%d", Int32(1234), locale: "ja_JP", expectation: "1,234")
        checkFormat("%d", Int32(12), locale: "en_US", expectation: "12")
        checkFormat("%d", Int32(-1234), locale: "en_US", expectation: "-1,234")
        checkFormat("%ld", Int.min, locale: "en_US", expectation: "-9,223,372,036,854,775,808")
        checkFormat("%x", Int32(0xFFFF), locale: "de_DE", expectation: "ffff")
        checkFormat("%+d", Int32(1234), locale: "en_US", expectation: "+1,234")
        checkFormat("%08d", Int32(1234), locale: "en_US", expectation: "00,001,234")
        checkFormat("%8d|", Int32(1234), locale: "en_US", expectation: "   1,234|")
        checkFormat("%-8d|", Int32(1234), locale: "en_US", expectation: "1,234   |")
        checkFormat("%.6d", Int32(1234), locale: "en_US", expectation: "001,234")
    }

    @Test func floatingPoint() {
        checkFormat("%f", 1234.5, locale: "en_US", expectation: "1,234.500000")
        checkFormat("%f", 1234.5, locale: "de_DE", expectation: "1.234,500000")
        checkFormat("%f", 1234.5, locale: "fr_FR", expectation: "1\u{202F}234,500000")
        checkFormat("%f", 1234.5, locale: "ar", expectation: "1,234.500000")
        checkFormat("%.2f", 1234.567, locale: "de_DE", expectation: "1.234,57")
        checkFormat("%.0f", 2.5, locale: "en_US", expectation: "2")
        checkFormat("%.0f", 1234.5, locale: "en_US", expectation: "1,234")
        checkFormat("%+.1f", 2.25, locale: "en_US", expectation: "+2.2")
        checkFormat("%10.2f|", 3.14159, locale: "en_US", expectation: "      3.14|")
        checkFormat("%f", -0.5, locale: "en_US", expectation: "-0.500000")
        checkFormat("%g", 0.5, locale: "en_US", expectation: "0.5")
        checkFormat("%g", 1234.5, locale: "en_US", expectation: "1,234.5")
        checkFormat("%g", 1234.5, locale: "de_DE", expectation: "1.234,5")
        checkFormat("%.3g", 3.14159, locale: "de_DE", expectation: "3,14")
        checkFormat("%a", 1.5, locale: "de_DE", expectation: "0x1,8p+0")
        checkFormat("%f", Double.nan, locale: "en_US", expectation: "NaN")
        checkFormat("%f", Double.infinity, locale: "de_DE", expectation: "∞")
    }

    #if FOUNDATION_FRAMEWORK
    @Test func objectDescriptionsUseTheLocale() {
        checkFormat("%@", NSNumber(value: 1234.5), locale: "de_DE", expectation: "1.234,5")
        checkFormat("%@", NSNumber(value: 1234.5), locale: "en_US", expectation: "1,234.5")
        checkFormat("%@", NSNumber(value: 1234567), locale: "de_DE", expectation: "1.234.567")
    }
    #endif

    @Test func negativeWidthAndPrecision() {
        checkFormat("%*d", Int32(-8), Int32(42), locale: "en_US", expectation: "42      ")
        checkFormat("%.*f", Int32(-3), 3.14159, locale: "en_US", expectation: "3.141590")
        checkFormat("%0*.*d", Int32(8), Int32(-8), Int32(42), locale: "en_US", expectation: "00,000,042")
    }

    @Test func scientificNotation() {
        checkFormat("%e", 1234.5, locale: "en_US", expectation: "1.234500E+03")
        checkFormat("%E", 1234.5, locale: "en_US", expectation: "1.234500E+03")
        checkFormat("%e", 1234.5, locale: "de_DE", expectation: "1,234500E+03")
        checkFormat("%.3e", 0.00012345, locale: "en_US", expectation: "1.234E-04")
        checkFormat("%e", -1e100, locale: "en_US", expectation: "-1.000000E+100")
        checkFormat("%g", 1e10, locale: "en_US", expectation: "1E+10")
        checkFormat("%g", 0.00001, locale: "en_US", expectation: "1E-05")
        checkFormat("%G", 1e-10, locale: "de_DE", expectation: "1E-10")
        checkFormat("%g", 1000000.0, locale: "en_US", expectation: "1E+06")
        checkFormat("%.3g", 999.5, locale: "en_US", expectation: "1E+03")
    }

    #if FOUNDATION_FRAMEWORK && ICU
    @Test func rightToLeftArgumentsAreIsolated() {
        let isolated = ["\u{2068}שלום\u{2069}", "\u{2067}שלום\u{2069}"]
        #expect(isolated.contains(formatted("%@", CVarArgString("שלום"), locale: "en_US")))
        #expect(isolated.map { "hello and \($0)" }.contains(formatted("%@ and %@", CVarArgString("hello"), CVarArgString("שלום"), locale: "en_US")))
    }

    @Test func leftToRightArgumentsAreNotIsolated() {
        checkFormat("%@", CVarArgString("hello"), locale: "en_US", expectation: "hello")
    }

    @Test func unlocalizedFormattingDoesNotIsolate() {
        checkFormat("%@", CVarArgString("שלום"), locale: nil, expectation: "שלום")
    }
    #endif
}
