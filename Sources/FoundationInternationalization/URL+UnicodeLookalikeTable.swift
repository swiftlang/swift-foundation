//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
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

extension URL {
    final class UnicodeLookalikeTable: Sendable {
        static let `default` = UnicodeLookalikeTable()

        static let IDNScriptAllowedList: Set<Int> = {
            func allowIDNScript(_ scriptName: String, to allowList: inout Set<Int>) {
                let scriptCode = scriptName.withCString {
                    return Int(u_getPropertyValueEnum(UCHAR_SCRIPT, $0))
                }

                if scriptCode >= 0 && scriptCode < UScriptCode.codeLimit.rawValue {
                    allowList.insert(scriptCode)
                }
            }

            var allowList: Set<Int> = Set()
            // Populate the allow list
            allowIDNScript("Common", to: &allowList)
            allowIDNScript("Inherited", to: &allowList)
            allowIDNScript("Arabic", to: &allowList)
            allowIDNScript("Armenian", to: &allowList)
            allowIDNScript("Bopomofo", to: &allowList)
            allowIDNScript("Canadian_Aboriginal", to: &allowList)
            allowIDNScript("Devanagari", to: &allowList)
            allowIDNScript("Deseret", to: &allowList)
            allowIDNScript("Gujarati", to: &allowList)
            allowIDNScript("Gurmukhi", to: &allowList)
            allowIDNScript("Hangul", to: &allowList)
            allowIDNScript("Han", to: &allowList)
            allowIDNScript("Hebrew", to: &allowList)
            allowIDNScript("Hiragana", to: &allowList)
            allowIDNScript("Katakana_Or_Hiragana", to: &allowList)
            allowIDNScript("Katakana", to: &allowList)
            allowIDNScript("Latin", to: &allowList)
            allowIDNScript("Tamil", to: &allowList)
            allowIDNScript("Thai", to: &allowList)
            allowIDNScript("Yi", to: &allowList)

            return allowList
        }()

        func shouldDisplayEncodedHost(for hostString: String) -> Bool {
            if self.allCharactersInIDNScriptAllowList(in: hostString) {
                return false
            }
            return !self.allCharactersAllowedByTLDRules(in: hostString)
        }

        private init() {}
    }
}

extension Unicode.Scalar {
    var ucharValue: UChar32 {
        UChar32(value)
    }
}

// MARK: - Lookalike Table
extension URL.UnicodeLookalikeTable {
    /// This function treats the following as unsafe, lookalike characters:
    /// - any non-printable character, any character considered as whitespace,
    /// - any ignorable character, and emoji characters related to locks.
    /// We also considered the characters Mozilla disallows <http://kb.mozillazine.org/Network.IDN.blacklist_chars>.
    private func isLookalikeScalar(_ scalar: Unicode.Scalar, withPreviousScalar previousScalar: Unicode.Scalar?) -> Bool {
        if !u_isprint(scalar.ucharValue).boolValue || u_isUWhiteSpace(scalar.ucharValue).boolValue || u_hasBinaryProperty(scalar.ucharValue, UCHAR_DEFAULT_IGNORABLE_CODE_POINT).boolValue {
            return true
        }
        let blockCode = ublock_getCode(scalar.ucharValue)
        if blockCode == UBLOCK_IPA_EXTENSIONS || blockCode == UBLOCK_DESERET {
            return true
        }

        switch (scalar.value) {
        case 0x00BC: fallthrough /* VULGAR FRACTION ONE QUARTER */
        case 0x00BD: fallthrough /* VULGAR FRACTION ONE HALF */
        case 0x00BE: fallthrough /* VULGAR FRACTION THREE QUARTERS */
        /* 0x0131 LATIN SMALL LETTER DOTLESS I is intentionally not considered a lookalike character because
        it is visually distinguishable from i and it has legitimate use in the Turkish language */
        case 0x01C0: fallthrough /* LATIN LETTER DENTAL CLICK */
        case 0x01C3: fallthrough /* LATIN LETTER RETROFLEX CLICK */
        case 0x1E9C: fallthrough /* LATIN SMALL LETTER LONG S WITH DIAGONAL STROKE */
        case 0x1E9D: fallthrough /* LATIN SMALL LETTER LONG S WITH HIGH STROKE */
        case 0x1EFE: fallthrough /* LATIN CAPITAL LETTER Y WITH LOOP */
        case 0x1EFF: fallthrough /* LATIN SMALL LETTER Y WITH LOOP */
        case 0x0237: fallthrough /* LATIN SMALL LETTER DOTLESS J */
        case 0x0251: fallthrough /* LATIN SMALL LETTER ALPHA */
        case 0x0261: fallthrough /* LATIN SMALL LETTER SCRIPT G */
        case 0x02D0: fallthrough /* MODIFIER LETTER TRIANGULAR COLON */
        case 0x0335: fallthrough /* COMBINING SHORT STROKE OVERLAY */
        case 0x0337: fallthrough /* COMBINING SHORT SOLIDUS OVERLAY */
        case 0x0338: fallthrough /* COMBINING LONG SOLIDUS OVERLAY */
        case 0x0589: fallthrough /* ARMENIAN FULL STOP */
        case 0x05B4: fallthrough /* HEBREW POINT HIRIQ */
        case 0x05B9: fallthrough /* HEBREW POINT HOLAM */
        case 0x05BA: fallthrough /* HEBREW POINT HOLAM HASER FOR VAV */
        case 0x05BC: fallthrough /* HEBREW POINT DAGESH OR MAPIQ */
        case 0x05C1: fallthrough /* HEBREW POINT SHIN DOT */
        case 0x05C2: fallthrough /* HEBREW POINT SIN DOT */
        case 0x05C3: fallthrough /* HEBREW PUNCTUATION SOF PASUQ */
        case 0x05C4: fallthrough /* HEBREW MARK UPPER DOT */
        case 0x05F4: fallthrough /* HEBREW PUNCTUATION GERSHAYIM */
        case 0x0609: fallthrough /* ARABIC-INDIC PER MILLE SIGN */
        case 0x060A: fallthrough /* ARABIC-INDIC PER TEN THOUSAND SIGN */
        case 0x0650: fallthrough /* ARABIC KASRA */
        case 0x0660: fallthrough /* ARABIC INDIC DIGIT ZERO */
        case 0x066A: fallthrough /* ARABIC PERCENT SIGN */
        case 0x06D4: fallthrough /* ARABIC FULL STOP */
        case 0x06F0: fallthrough /* EXTENDED ARABIC INDIC DIGIT ZERO */
        case 0x0701: fallthrough /* SYRIAC SUPRALINEAR FULL STOP */
        case 0x0702: fallthrough /* SYRIAC SUBLINEAR FULL STOP */
        case 0x0703: fallthrough /* SYRIAC SUPRALINEAR COLON */
        case 0x0704: fallthrough /* SYRIAC SUBLINEAR COLON */
        case 0x1735: fallthrough /* PHILIPPINE SINGLE PUNCTUATION */
        case 0x1D04: fallthrough /* LATIN LETTER SMALL CAPITAL C */
        case 0x1D0F: fallthrough /* LATIN LETTER SMALL CAPITAL O */
        case 0x1D1C: fallthrough /* LATIN LETTER SMALL CAPITAL U */
        case 0x1D20: fallthrough /* LATIN LETTER SMALL CAPITAL V */
        case 0x1D21: fallthrough /* LATIN LETTER SMALL CAPITAL W */
        case 0x1D22: fallthrough /* LATIN LETTER SMALL CAPITAL Z */
        case 0x2010: fallthrough /* HYPHEN */
        case 0x2011: fallthrough /* NON-BREAKING HYPHEN */
        case 0x2024: fallthrough /* ONE DOT LEADER */
        case 0x2027: fallthrough /* HYPHENATION POINT */
        case 0x2039: fallthrough /* SINGLE LEFT-POINTING ANGLE QUOTATION MARK */
        case 0x203A: fallthrough /* SINGLE RIGHT-POINTING ANGLE QUOTATION MARK */
        case 0x2041: fallthrough /* CARET INSERTION POINT */
        case 0x2044: fallthrough /* FRACTION SLASH */
        case 0x2052: fallthrough /* COMMERCIAL MINUS SIGN */
        case 0x2153: fallthrough /* VULGAR FRACTION ONE THIRD */
        case 0x2154: fallthrough /* VULGAR FRACTION TWO THIRDS */
        case 0x2155: fallthrough /* VULGAR FRACTION ONE FIFTH */
        case 0x2156: fallthrough /* VULGAR FRACTION TWO FIFTHS */
        case 0x2157: fallthrough /* VULGAR FRACTION THREE FIFTHS */
        case 0x2158: fallthrough /* VULGAR FRACTION FOUR FIFTHS */
        case 0x2159: fallthrough /* VULGAR FRACTION ONE SIXTH */
        case 0x215A: fallthrough /* VULGAR FRACTION FIVE SIXTHS */
        case 0x215B: fallthrough /* VULGAR FRACTION ONE EIGHT */
        case 0x215C: fallthrough /* VULGAR FRACTION THREE EIGHTHS */
        case 0x215D: fallthrough /* VULGAR FRACTION FIVE EIGHTHS */
        case 0x215E: fallthrough /* VULGAR FRACTION SEVEN EIGHTHS */
        case 0x215F: fallthrough /* FRACTION NUMERATOR ONE */
        case 0x2212: fallthrough /* MINUS SIGN */
        case 0x2215: fallthrough /* DIVISION SLASH */
        case 0x2216: fallthrough /* SET MINUS */
        case 0x2236: fallthrough /* RATIO */
        case 0x233F: fallthrough /* APL FUNCTIONAL SYMBOL SLASH BAR */
        case 0x23AE: fallthrough /* INTEGRAL EXTENSION */
        case 0x244A: fallthrough /* OCR DOUBLE BACKSLASH */
        case 0x2571: fallthrough /* BOX DRAWINGS LIGHT DIAGONAL UPPER RIGHT TO LOWER LEFT */
        case 0x2572: fallthrough /* BOX DRAWINGS LIGHT DIAGONAL UPPER LEFT TO LOWER RIGHT */
        case 0x29F6: fallthrough /* SOLIDUS WITH OVERBAR */
        case 0x29F8: fallthrough /* BIG SOLIDUS */
        case 0x2AFB: fallthrough /* TRIPLE SOLIDUS BINARY RELATION */
        case 0x2AFD: fallthrough /* DOUBLE SOLIDUS OPERATOR */
        case 0x2FF0: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER LEFT TO RIGHT */
        case 0x2FF1: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER ABOVE TO BELOW */
        case 0x2FF2: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER LEFT TO MIDDLE AND RIGHT */
        case 0x2FF3: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER ABOVE TO MIDDLE AND BELOW */
        case 0x2FF4: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER FULL SURROUND */
        case 0x2FF5: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM ABOVE */
        case 0x2FF6: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM BELOW */
        case 0x2FF7: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM LEFT */
        case 0x2FF8: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM UPPER LEFT */
        case 0x2FF9: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM UPPER RIGHT */
        case 0x2FFA: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER SURROUND FROM LOWER LEFT */
        case 0x2FFB: fallthrough /* IDEOGRAPHIC DESCRIPTION CHARACTER OVERLAID */
        case 0x3002: fallthrough /* IDEOGRAPHIC FULL STOP */
        case 0x3008: fallthrough /* LEFT ANGLE BRACKET */
        case 0x3014: fallthrough /* LEFT TORTOISE SHELL BRACKET */
        case 0x3015: fallthrough /* RIGHT TORTOISE SHELL BRACKET */
        case 0x3033: fallthrough /* VERTICAL KANA REPEAT MARK UPPER HALF */
        case 0x3035: fallthrough /* VERTICAL KANA REPEAT MARK LOWER HALF */
        case 0x321D: fallthrough /* PARENTHESIZED KOREAN CHARACTER OJEON */
        case 0x321E: fallthrough /* PARENTHESIZED KOREAN CHARACTER O HU */
        case 0x33AE: fallthrough /* SQUARE RAD OVER S */
        case 0x33AF: fallthrough /* SQUARE RAD OVER S SQUARED */
        case 0x33C6: fallthrough /* SQUARE C OVER KG */
        case 0x33DF: fallthrough /* SQUARE A OVER M */
        case 0xA731: fallthrough /* LATIN LETTER SMALL CAPITAL S */
        case 0xA771: fallthrough /* LATIN SMALL LETTER DUM */
        case 0xA789: fallthrough /* MODIFIER LETTER COLON */
        case 0xFE14: fallthrough /* PRESENTATION FORM FOR VERTICAL SEMICOLON */
        case 0xFE15: fallthrough /* PRESENTATION FORM FOR VERTICAL EXCLAMATION MARK */
        case 0xFE3F: fallthrough /* PRESENTATION FORM FOR VERTICAL LEFT ANGLE BRACKET */
        case 0xFE5D: fallthrough /* SMALL LEFT TORTOISE SHELL BRACKET */
        case 0xFE5E: fallthrough /* SMALL RIGHT TORTOISE SHELL BRACKET */
        case 0xFF0E: fallthrough /* FULLWIDTH FULL STOP */
        case 0xFF0F: fallthrough /* FULL WIDTH SOLIDUS */
        case 0xFF61: fallthrough /* HALFWIDTH IDEOGRAPHIC FULL STOP */
        case 0xFFFC: fallthrough /* OBJECT REPLACEMENT CHARACTER */
        case 0xFFFD: fallthrough /* REPLACEMENT CHARACTER */
        case 0x1F50F: fallthrough /* LOCK WITH INK PEN */
        case 0x1F510: fallthrough /* CLOSED LOCK WITH KEY */
        case 0x1F511: fallthrough /* KEY */
        case 0x1F512: fallthrough /* LOCK */
        case 0x1F513: /* OPEN LOCK */
            return true;
        case 0x0307: /* COMBINING DOT ABOVE */
            guard let previousScalar = previousScalar else {
                return false
            }

            return previousScalar.value == 0x0237 /* LATIN SMALL LETTER DOTLESS J */
                || previousScalar.value == 0x0131 /* LATIN SMALL LETTER DOTLESS I */
                || previousScalar.value == 0x05D5 /* HEBREW LETTER VAV */
        case 0x002E: /* FULL STOP */
            return false;
        default:
            return isLookalikeSequence(
                withScalar: scalar,
                previousScalar: previousScalar,
                ofScriptType: .armenian)
                || isLookalikeSequence(
                    withScalar: scalar,
                    previousScalar: previousScalar,
                    ofScriptType: .tamil)
                || isLookalikeSequence(
                    withScalar: scalar,
                    previousScalar: previousScalar,
                    ofScriptType: .canadianAboriginal)
                || isLookalikeSequence(
                    withScalar: scalar,
                    previousScalar: previousScalar,
                    ofScriptType: .thai)
                || isLookalikeSequence(
                    withScalar: scalar,
                    previousScalar: previousScalar,
                    ofScriptType: .arabic)
        }
    }

    private func isLookalikeSequence(withScalar scalar: Unicode.Scalar, previousScalar: Unicode.Scalar?, ofScriptType scriptType: UScriptCode) -> Bool {
        guard let previousScalar = previousScalar,
            previousScalar != "/"
        else {
            return false
        }

        if scriptType == .arabic {
            return isLookalikeSequenceOfArabic(withScalar: scalar, previousScalar: previousScalar)
        }

        let isLookalikePair = { (first: Unicode.Scalar, second: Unicode.Scalar) -> Bool in
            return first.isLookalikeScalarOfScriptType(scriptType) && !(second.isOfScriptType(scriptType) || second.isASCIIDigitOrValidHostCharacter())
        }
        return isLookalikePair(scalar, previousScalar) || isLookalikePair(previousScalar, scalar)
    }

    private func isLookalikeSequenceOfArabic(withScalar scalar: Unicode.Scalar, previousScalar: Unicode.Scalar?) -> Bool {
        return scalar.isArabicDiacritic() && !(previousScalar?.isArabicCodePoint() ?? false)
    }
}

// MARK: - IDN Script Allow List / TLD Rules
extension URL.UnicodeLookalikeTable {
    private func allCharactersInIDNScriptAllowList(in string: String) -> Bool {
        var previousScalar: Unicode.Scalar? = nil
        for scalar in string.unicodeScalars {
            if !self.isScalarInIDNScriptAllowList(scalar) {
                return false
            }
            if self.isLookalikeScalar(scalar, withPreviousScalar: previousScalar) {
                return false
            }
            previousScalar = scalar
        }
        return true
    }

    private func isScalarInIDNScriptAllowList(_ scalar: Unicode.Scalar) -> Bool {
        var status = U_ZERO_ERROR
        let scriptCode = uscript_getScript(UChar32(scalar.value), &status)
        guard status.isSuccess else { return false }

        return URL.UnicodeLookalikeTable.IDNScriptAllowedList.contains(Int(scriptCode.rawValue))
    }

    private func allCharactersAllowedByTLDRules(in string: String) -> Bool {
        var buffer = string
        // Skip trailing dot for root domain.
        if buffer.hasSuffix(".") {
            buffer.removeLast(1)
        }

        // http://cctld.ru/files/pdf/docs/rules_ru-rf.pdf
        let cyrillicRF: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0440, // CYRILLIC SMALL LETTER ER
            0x0444, // CYRILLIC SMALL LETTER EF
        ])
        if buffer.count > cyrillicRF.count && buffer.unicodeScalars.hasSuffix(cyrillicRF) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicRF.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://rusnames.ru/rules.pl
        let cyrillicRUS: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0440, // CYRILLIC SMALL LETTER ER
            0x0443, // CYRILLIC SMALL LETTER U
            0x0441, // CYRILLIC SMALL LETTER ES
        ])
        if buffer.count > cyrillicRUS.count && buffer.unicodeScalars.hasSuffix(cyrillicRUS) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicRUS.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://ru.faitid.org/projects/moscow/documents/moskva/idn
        let cyrillicMOSKVA: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x043C, // CYRILLIC SMALL LETTER EM
            0x043E, // CYRILLIC SMALL LETTER O
            0x0441, // CYRILLIC SMALL LETTER ES
            0x043A, // CYRILLIC SMALL LETTER KA
            0x0432, // CYRILLIC SMALL LETTER VE
            0x0430, // CYRILLIC SMALL LETTER A
        ])
        if buffer.count > cyrillicMOSKVA.count && buffer.unicodeScalars.hasSuffix(cyrillicMOSKVA) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicMOSKVA.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://www.dotdeti.ru/foruser/docs/regrules.php
        let cyrillicDETI: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0434, // CYRILLIC SMALL LETTER DE
            0x0435, // CYRILLIC SMALL LETTER IE
            0x0442, // CYRILLIC SMALL LETTER TE
            0x0438, // CYRILLIC SMALL LETTER I
        ])
        if buffer.count > cyrillicDETI.count && buffer.unicodeScalars.hasSuffix(cyrillicDETI) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicDETI.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://corenic.org - rules not published. The word is Russian,
        // so only allowing Russian at this time, although we may need to
        // revise the checks if this ends up being used with other languages
        // spoken in Russia.
        let cyrillicONLAYN: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x043E, // CYRILLIC SMALL LETTER O
            0x043D, // CYRILLIC SMALL LETTER EN
            0x043B, // CYRILLIC SMALL LETTER EL
            0x0430, // CYRILLIC SMALL LETTER A
            0x0439, // CYRILLIC SMALL LETTER SHORT I
            0x043D, // CYRILLIC SMALL LETTER EN
        ])
        if buffer.count > cyrillicONLAYN.count && buffer.unicodeScalars.hasSuffix(cyrillicONLAYN) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicONLAYN.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://corenic.org - same as above.
        let cyrillicSAYT: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0441, // CYRILLIC SMALL LETTER ES
            0x0430, // CYRILLIC SMALL LETTER A
            0x0439, // CYRILLIC SMALL LETTER SHORT I
            0x0442, // CYRILLIC SMALL LETTER TE
        ])
        if buffer.count > cyrillicSAYT.count && buffer.unicodeScalars.hasSuffix(cyrillicSAYT) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicSAYT.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://pir.org/products/opr-domain/ - rules not published.
        // According to the registry site, the intended audience is
        // "Russian and other Slavic-speaking markets".
        // Chrome appears to only allow Russian, so sticking with that for now.
        let cyrillicORG: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x043E, // CYRILLIC SMALL LETTER O
            0x0440, // CYRILLIC SMALL LETTER ER
            0x0433, // CYRILLIC SMALL LETTER GHE
        ])
        if buffer.count > cyrillicORG.count && buffer.unicodeScalars.hasSuffix(cyrillicORG) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicORG.count),
                allowedBy: { $0.isRussianDomainNameCharacter() })
        }

        // http://cctld.by/rules.html
        let cyrillicBEL: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0431, // CYRILLIC SMALL LETTER BE
            0x0435, // CYRILLIC SMALL LETTER IE
            0x043B, // CYRILLIC SMALL LETTER EL
        ])
        if buffer.count > cyrillicBEL.count && buffer.unicodeScalars.hasSuffix(cyrillicBEL) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicBEL.count),
                allowedBy: {
                    // Russian and Byelorussian letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x044f) || $0.value == 0x0451 || $0.value == 0x0456 || $0.value == 0x045E || $0.value == 0x2019 || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // http://www.nic.kz/docs/poryadok_vnedreniya_kaz_ru.pdf
        let cyrillicKAZ: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x049B, // CYRILLIC SMALL LETTER KA WITH DESCENDER
            0x0430, // CYRILLIC SMALL LETTER A
            0x0437, // CYRILLIC SMALL LETTER ZE
        ])
        if buffer.count > cyrillicKAZ.count && buffer.unicodeScalars.hasSuffix(cyrillicKAZ) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicKAZ.count),
                allowedBy: {
                    // Kazakh letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x044f) || $0.value == 0x0451 || $0.value == 0x04D9 || $0.value == 0x0493 || $0.value == 0x049B || $0.value == 0x04A3 || $0.value == 0x04E9 || $0.value == 0x04B1 || $0.value == 0x04AF
                        || $0.value == 0x04BB || $0.value == 0x0456 || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // http://uanic.net/docs/documents-ukr/Rules%20of%20UKR_v4.0.pdf
        let cyrillicUKR: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0443, // CYRILLIC SMALL LETTER U
            0x043A, // CYRILLIC SMALL LETTER KA
            0x0440, // CYRILLIC SMALL LETTER ER
        ])
        if buffer.count > cyrillicUKR.count && buffer.unicodeScalars.hasSuffix(cyrillicUKR) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicUKR.count),
                allowedBy: {
                    // Russian and Ukrainian letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x044f) || $0.value == 0x0451 || $0.value == 0x0491 || $0.value == 0x0404 || $0.value == 0x0456 || $0.value == 0x0457 || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // http://www.rnids.rs/data/DOKUMENTI/idn-srb-policy-termsofuse-v1.4-eng.pdf
        let cyrillicSRB: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0441, // CYRILLIC SMALL LETTER ES
            0x0440, // CYRILLIC SMALL LETTER ER
            0x0431, // CYRILLIC SMALL LETTER BE
        ])
        if buffer.count > cyrillicSRB.count && buffer.unicodeScalars.hasSuffix(cyrillicSRB) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicSRB.count),
                allowedBy: {
                    // Serbian letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x0438) || ($0.value >= 0x043A && $0.value <= 0x0448) || $0.value == 0x0452 || $0.value == 0x0458 || $0.value == 0x0459 || $0.value == 0x045A || $0.value == 0x045B || $0.value == 0x045F
                        || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // http://marnet.mk/doc/pravilnik-mk-mkd.pdf
        let cyrillicMKD: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x043C, // CYRILLIC SMALL LETTER EM
            0x043A, // CYRILLIC SMALL LETTER KA
            0x0434, // CYRILLIC SMALL LETTER DE
        ])
        if buffer.count > cyrillicMKD.count && buffer.unicodeScalars.hasSuffix(cyrillicMKD) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicMKD.count),
                allowedBy: {
                    // Macedonian letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x0438) || ($0.value >= 0x043A && $0.value <= 0x0448) || $0.value == 0x0453 || $0.value == 0x0455 || $0.value == 0x0458 || $0.value == 0x0459 || $0.value == 0x045A || $0.value == 0x045C
                        || $0.value == 0x045F || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // https://www.mon.mn/cs/
        let cyrillicMON: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x043C, // CYRILLIC SMALL LETTER EM
            0x043E, // CYRILLIC SMALL LETTER O
            0x043D, // CYRILLIC SMALL LETTER EN
        ])
        if buffer.count > cyrillicMON.count && buffer.unicodeScalars.hasSuffix(cyrillicMON) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicMON.count),
                allowedBy: {
                    // Mongolian letters, digits and dashes are allowed.
                    return ($0.value >= 0x0430 && $0.value <= 0x044f) || $0.value == 0x0451 || $0.value == 0x04E9 || $0.value == 0x04AF || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // https://www.icann.org/sites/default/files/packages/lgr/lgr-second-level-bulgarian-30aug16-en.html
        let cyrillicBG: String.UnicodeScalarView = .init([
            0x002E, // '.' FULL STOP
            0x0431, // CYRILLIC SMALL LETTER BE
            0x0433, // CYRILLIC SMALL LETTER GHE
        ])
        if buffer.count > cyrillicBG.count && buffer.unicodeScalars.hasSuffix(cyrillicBG) {
            return self.secondLevelDomain(
                buffer.unicodeScalars.dropLast(cyrillicBG.count),
                allowedBy: {
                    return ($0.value >= 0x0430 && $0.value <= 0x044A) || $0.value == 0x044C || ($0.value >= 0x044E && $0.value <= 0x0450) || $0.value == 0x045D || $0.isASCIIDigit() || $0 == "-"
                })
        }

        // Not a known top level domain with special rules.
        return false
    }

    private func secondLevelDomain(_ secondLevelDomain: String.UnicodeScalarView.SubSequence, allowedBy filterFunc: (Unicode.Scalar) -> Bool) -> Bool {
        for scalar in secondLevelDomain.reversed() {
            if filterFunc(scalar) {
                continue
            }
            // Only check the second level domain. Lower level registrars may have different rules.
            if scalar == "." {
                break
            }
            return false
        }
        return true
    }
}

// MARK: - Unicode Scalar Extensions
extension Unicode.Scalar {
    fileprivate func isOfScriptType(_ type: UScriptCode) -> Bool {
        var status = U_ZERO_ERROR
        let scriptCode = uscript_getScript(UChar32(self.value), &status)
        return scriptCode == type
    }

    fileprivate func isLookalikeScalarOfScriptType(_ scriptType: UScriptCode) -> Bool {
        switch scriptType {
        case .armenian:
            return self.isLookalikeScalarOfArmenianScript()
        case .tamil:
            return self.isLookalikeScalarOfTamilScript()
        case .thai:
            return self.isLookalikeScalarOfThai()
        case .canadianAboriginal:
            return self.isLookalikeScalarOfCanadianAboriginal()
        case .codeLimit:
            return false
        default:
            return false
        }
    }

    fileprivate func isLookalikeScalarOfTamilScript() -> Bool {
        switch self.value {
        case 0x0BE6: /* TAMIL DIGIT ZERO */
            return true
        default:
            return false
        }
    }

    fileprivate func isLookalikeScalarOfArmenianScript() -> Bool {
        switch self.value {
        case 0x0548: fallthrough /* ARMENIAN CAPITAL LETTER VO */
        case 0x054D: fallthrough /* ARMENIAN CAPITAL LETTER SEH */
        case 0x0551: fallthrough /* ARMENIAN CAPITAL LETTER CO */
        case 0x0555: fallthrough /* ARMENIAN CAPITAL LETTER OH */
        case 0x0578: fallthrough /* ARMENIAN SMALL LETTER VO */
        case 0x057D: fallthrough /* ARMENIAN SMALL LETTER SEH */
        case 0x0581: fallthrough /* ARMENIAN SMALL LETTER CO */
        case 0x0585: /* ARMENIAN SMALL LETTER OH */
            return true
        default:
            return false
        }
    }

    fileprivate func isLookalikeScalarOfCanadianAboriginal() -> Bool {
        switch self.value {
        case 0x146D: fallthrough /* CANADIAN SYLLABICS KI */
        case 0x146F: fallthrough /* CANADIAN SYLLABICS KO */
        case 0x1472: fallthrough /* CANADIAN SYLLABICS KA */
        case 0x14AA: fallthrough /* CANADIAN SYLLABICS MA */
        case 0x157C: fallthrough /* CANADIAN SYLLABICS NUNAVUT H */
        case 0x1587: fallthrough /* CANADIAN SYLLABICS TLHI */
        case 0x15AF: fallthrough /* CANADIAN SYLLABICS AIVILIK B */
        case 0x15B4: fallthrough /* CANADIAN SYLLABICS BLACKFOOT WE */
        case 0x15C5: fallthrough /* CANADIAN SYLLABICS CARRIER GHO */
        case 0x15DE: fallthrough /* CANADIAN SYLLABICS CARRIER THE */
        case 0x15E9: fallthrough /* CANADIAN SYLLABICS CARRIER PO */
        case 0x15F1: fallthrough /* CANADIAN SYLLABICS CARRIER GE */
        case 0x15F4: fallthrough /* CANADIAN SYLLABICS CARRIER GA */
        case 0x166D: fallthrough /* CANADIAN SYLLABICS CHI SIGN */
        case 0x166E: /* CANADIAN SYLLABICS FULL STOP */
            return true
        default:
            return false
        }
    }

    fileprivate func isLookalikeScalarOfThai() -> Bool {
        switch self.value {
        case 0x0E01: /* THAI CHARACTER KO KAI */
            return true
        default:
            return false
        }
    }

    fileprivate func isASCIIDigitOrValidHostCharacter() -> Bool {
        if !self.isASCIIDigitOrPunctuation() {
            return false
        }
        return self.isValidHostCharacter()
    }

    fileprivate func isRussianDomainNameCharacter() -> Bool {
        // Only modern Russian letters, digits and dashes are allowed.
        return (self.value >= 0x0430 && self.value <= 0x044f) || self.value == 0x0451 || self.isASCIIDigit() || self == "-"
    }

    fileprivate func isASCIIDigit() -> Bool {
        return self >= "0" && self <= "9"
    }

    fileprivate func isArabicDiacritic() -> Bool {
        return 0x064B <= self.value && self.value <= 0x065F
    }

    fileprivate func isArabicCodePoint() -> Bool {
        return ublock_getCode(self.ucharValue) == UBLOCK_ARABIC
    }

    private func isASCIIDigitOrPunctuation() -> Bool {
        return (self >= "!" && self <= "@") || (self >= "[" && self <= "`") || (self >= "{" && self <= "~")
    }

    private func isValidHostCharacter() -> Bool {
        switch self {
        case "#": fallthrough
        case "%": fallthrough
        case "/": fallthrough
        case ":": fallthrough
        case "?": fallthrough
        case "@": fallthrough
        case "[": fallthrough
        case "\\": fallthrough
        case "]":
            return false
        default:
            return true
        }
    }
}

extension String.UnicodeScalarView {
    fileprivate init<S>(_ elements: S) where S: Sequence, S.Element == UInt32 {
        self.init(elements.map { Unicode.Scalar($0)! })
    }

    fileprivate func hasSuffix(_ suffix: String.UnicodeScalarView) -> Bool {
        guard suffix.count < self.count else {
            return false
        }

        let target = self[self.index(self.endIndex, offsetBy: -suffix.count)..<self.endIndex]
        return String.UnicodeScalarView(target).elementsEqual(suffix)
    }
}
