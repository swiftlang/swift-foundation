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

import Testing

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

extension String {
    var _scalarViewDescription: String {
        return unicodeScalars.map { "\\u{\(String($0.value, radix: 16, uppercase: true))}" }.joined()
    }
}

struct StringLocaleTests {

    @Test func testCapitalize_localized() {
        var locale: Locale?
        // JTODO: remove underscore?
        // `extension StringProtocol { func capitalized(with: Locale) }` is
        // declared twice on Darwin: once in FoundationInternationalization
        // and once in SDK. Therefore it is ambiguous when building the package
        // on Darwin. Workaround it by testing the internal implementation.
        func test(_ string: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(string._capitalized(with: locale) == expected, sourceLocation: sourceLocation)
        }

        do {
            locale = Locale(identifier: "tr")
            test("iı", "İı")
            test("ıi", "Ii")
            test("İİ", "İi")
            test("II", "Iı")
            test("«ijs»", "«İjs»")
            test("ijs.ıi", "İjs.Ii")
        }

        do {
            locale = Locale(identifier: "nl")
            test("iı", "Iı")
            test("ıi", "Ii")
            test("İİ", "İi̇")
            test("II", "Ii")
            test("«ijs»", "«IJs»")
            test("ijssEl iglOo IJSSEL", "IJssel Igloo IJssel")
            test("ijssEl.ijSSEL", "IJssel.IJssel")
        }

        do {
            locale = Locale(identifier: "el")
            test("άυλος", "Άυλος")
        }

        do {
            locale = Locale(identifier: "en_US")
            test("washington d.c.", "Washington D.C.")
            test("washington D.c.", "Washington D.C.")
            test("washington d.C.", "Washington D.C.")

            test("washington d. c.", "Washington D. C.")
            test("washington d. C.", "Washington D. C.")

            test("washington.D.C.", "Washington.D.C.")

            test("u.s.a.", "U.S.A.")
            test("U.S.A.", "U.S.A.")

            test("example county. happy. SOC'y, INC. V. COMM'R, 123 F.24d 314 (2d Cir. 1990).", "Example County. Happy. Soc'y, Inc. V. Comm'r, 123 F.24d 314 (2d Cir. 1990).")
            test("3.dollars", "3.Dollars")
        }
    }

    @Test func testUppercase_localized() {

        func test(_ localeID: String?, _ string: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let locale: Locale?
            if let localeID {
                locale = Locale(identifier: localeID)
            } else {
                locale = nil
            }
            let actual = string._uppercased(with: locale)

            #expect(actual == expected, "actual: \(actual._scalarViewDescription), expected: \(expected._scalarViewDescription)", sourceLocation: sourceLocation)
        }

        test(nil, "ﬄ", "FFL") // 0xFB04
        test(nil, "ß", "SS")   // 0x0053
        test(nil, "ﬀ", "FF")

        test("en", "ﬄ", "FFL")
        test("en", "ß", "SS")
        test("de", "ﬄ", "FFL")
        test("de", "ß", "SS")

        // Greek letter
        test(nil, "Ά", "Ά")
        test(nil, "ά", "Ά")
        test(nil, "ᾈ", "ἈΙ")  // 0x1F88

        test(nil, "\u{0391}\u{0301}", "\u{0391}\u{0301}")
        test(nil, "\u{03B1}\u{0301}", "\u{0391}\u{0301}")
        test(nil, "\u{0390}", "\u{0399}\u{0308}\u{0301}")
        test(nil, "\u{03B9}\u{0344}", "\u{0399}\u{0344}")
        test(nil, "\u{03B9}\u{0308}\u{0301}", "\u{0399}\u{0308}\u{0301}")

        test("el_GR", "Ά", "\u{0391}")
        test("el_GR", "ά", "\u{0391}")

        test("el_GR", "\u{0391}\u{0301}", "\u{0391}")
        test("el_GR", "\u{03B1}\u{0301}", "\u{0391}")
        test("el_GR", "\u{0390}", "\u{0399}\u{0308}")
        test("el_GR", "\u{03B9}\u{0344}", "\u{0399}\u{0308}")
        test("el_GR", "\u{03B9}\u{0308}\u{0301}", "\u{0399}\u{0308}")
    }

    @Test func testLowercase_localized() {
        func test(_ localeID: String?, _ string: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let locale: Locale?
            if let localeID {
                locale = Locale(identifier: localeID)
            } else {
                locale = nil
            }
            let actual = string._lowercased(with: locale)

            #expect(actual == expected, "actual: \(actual._scalarViewDescription), expected: \(expected._scalarViewDescription)", sourceLocation: sourceLocation)
        }

        test(nil, "ᾈ", "ᾀ")     // 0x1F88
        test("en", "ᾈ", "ᾀ")
        test("en", "SOMEVERYVERYVERYVERYVERYVERYVERYVERYVERYLONGSTRING", "someveryveryveryveryveryveryveryveryverylongstring")
        test("el_GR", "ᾈ", "ᾀ")

        // Turkik
        test(nil, "II", "ii")
        test("en", "II", "ii")
        test("tr", "II", "ıı")

        test(nil, "İİ", "i̇i̇")
        test("en", "İİ", "i̇i̇")
        test("tr", "İİ", "ii")
    }

    @Test func testFuzzFailure() throws {
        let data = try #require(Data(base64Encoded: "77+977+977+977+977+977+977+977+977+977+9Cg=="))
        let input = try #require(String(data: data, encoding: .utf8))
        _ = input.lowercased(with: Locale(identifier: "en_US"))
        _ = input.capitalized(with: Locale(identifier: "en_US"))
        _ = input.capitalized(with: Locale(identifier: "en_US"))
    }
}

