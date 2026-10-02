//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2026 Apple Inc. and the Swift project authors
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

@Suite("Locale", .tags(.locale))
private struct LocaleTests {
    // Test cases derived from `CFLocaleCreateCanonicalLocaleIdentifierFromString`
    static let cases: [(identifier: String, expected: String)] = [
        // Old-style Apple English-word locale names
        ("English", "en"),
        ("French", "fr"),
        ("Japanese", "ja"),
        ("Norwegian", "nb"),
        ("Chinese, Simplified", "zh-Hans"),
        ("Chinese, Traditional", "zh-Hant"),
        ("Chinese, Tradtional", "zh-Hant"),
        ("Brazilian Portugese", "pt-BR"),
        ("Brazilian Portuguese", "pt-BR"),
        ("Simplified Chinese", "zh-Hans"),
        ("Traditional Chinese", "zh-Hant"),
        ("Flemish", "nl-BE"),
        ("Nynorsk", "nn"),
        ("Tagalog", "fil"),
        ("Farsi", "fa"),
        ("Scottish", "gd"),

        ("az.Ar", "az-Arab"),
        ("az.Cy", "az-Cyrl"),
        ("az.La", "az"),
        ("zh.Ha-S", "zh-Hans"),
        ("zh.Ha-S_CN", "zh_CN"),
        ("zh.Ha-T", "zh-Hant"),
        ("zh.Ha-T_TW", "zh_TW"),
        ("mn.Cy", "mn"),
        ("mn.Mn", "mn-Mong"),
        ("ms.Ar", "ms-Arab"),
        ("el.El-P", "grc"),
        ("ga.Lg", "ga-Latg"),
        ("ga.Lg_IE", "ga-Latg_IE"),
        ("sa.Dv", "sa"),
        ("yi.He", "yi"),
        ("en_??", "en_001"),
        ("de_??", "de-1996"),
        ("es_??", "es_419"),
        ("fr_??", "fr_001"),
        ("ar_??", "ar"),
        ("be_??", "be_BY"),
        ("sr_??", "sr_RS"),
        ("sl_??", "sl_SI"),
        ("zh-simp", "zh-Hans"),
        ("zh-trad", "zh-Hant"),
        ("ga-dots", "ga-Latg"),
        ("ga-dots_IE", "ga-Latg_IE"),
        ("no-NO", "nb-NO"),
        ("no-NO_NO", "nb-NO_NO"),
        ("no_BOKMAL", "nb-bokmal"),
        ("no_NYNORSK", "nb-nynorsk"),
        ("aa_SAAHO", "aa-saaho"),
        ("nl-be", "nl-BE"),
        ("nl-be_BE", "nl_BE"),

        // 3-letter ISO 639 to 2-letter mapping
        ("fra_FR", "fr_FR"),
        ("deu_DE", "de_DE"),
        ("spa_ES", "es_ES"),
        ("zho_CN", "zh_CN"),
        ("jpn_JP", "ja_JP"),
        ("kor_KR", "ko_KR"),
        ("cmn", "zh"),

        // Chinese extlang subtag mapping
        ("zh-cmn", "zh"),
        ("zh-yue", "yue"),
        ("zh-wuu", "wuu"),
        ("zh-nan", "nan"),
        ("zh-hak", "hak"),
        ("zh-min-nan", "nan"),
        ("zh-guoyu", "zh"),
        ("zh-hakka", "hak"),
        ("zh-xiang", "hsn"),

        // Obsolete ISO 639 language codes
        ("iw_IL", "he_IL"),
        ("in_ID", "id_ID"),
        ("ji", "yi"),
        ("jw", "jv"),
        ("mo", "mo"),
        ("tw", "ak"),

        // Deprecated RFC 3066 tags
        ("art-lojban", "jbo"),
        ("i-hak", "hak"),
        ("no-bok", "nb"),
        ("no-nyn", "nn"),
        ("sgn-us", "sgn-US"),

        // Region code updates
        ("en_UK", "en_GB"),
        ("pt_TP", "pt_TL"),
        ("cs_CS", "cs_CZ"),
        ("sk_CS", "sk_SK"),
        ("sr_CS", "sr_RS"),
        ("sr_YU", "sr_RS"),
        ("sh_HR", "hr_HR"),
        ("sh_RS", "sr_RS"),
        ("sh_YU", "sr_RS"),
        ("sh_CS", "sr_RS"),
        ("sh-YU", "sr-RS"),
        ("sh-CS", "sr-RS"),
        ("sh_Latn_YU", "sr-Latn_RS"),
        ("sh_US-YU", "sr_US-RS"),
        ("sh_HR_YU", "hr_HR_YU"),
        ("sh-US-HR", "sh-US-hr"),
        ("sk_YU-CS", "sk_RS-SK"),
        ("sr_RS-CS", "sr_RS-RS"),
        ("en_US-UK", "en_US-GB"),
        ("en_US-TP", "en_US-TL"),
        ("en_US-YU", "en_US-RS"),
        ("cs_US-CS", "cs_US-CZ"),
        ("en_419-UK", "en_419-GB"),
        ("en-UK-US", "en-GB-us"),
        ("en_CS_RS", "en_RS_RS"),
        ("en-UK_TP", "en-GB_TL"),
        ("sk_CS-CS", "sk_SK-SK"),
        ("zh-CN_CN_CN", "zh_CN_CN"),
        ("zh-Hans-CN_CN_CN", "zh_CN_CN"),

        // Default-script stripping by region
        ("zh-Hans_CN", "zh_CN"),
        ("zh-Hans_SG", "zh_SG"),
        ("zh-Hant_TW", "zh_TW"),
        ("zh-Hant_HK", "zh_HK"),
        ("zh-Hant_MO", "zh_MO"),
        ("zh-Hans_TW", "zh-Hans_TW"),
        ("zh-Hant_CN", "zh-Hant_CN"),

        // Default-script stripping by language prefix
        ("en-Latn_US", "en_US"),
        ("ar-Arab_SA", "ar_SA"),
        ("ru-Cyrl_RU", "ru_RU"),
        ("ja-Jpan_JP", "ja_JP"),
        ("de-Latn-1901_DE", "de_DE"),
        ("ko-Kore_KR", "ko_KR"),
        ("en-Cyrl_US", "en-Cyrl_US"),

        // Aran script canonicalization
        ("ks-Aran-IN", "ks-IN"),
        ("ks-Arab-IN", "ks-Arab-IN"),
        ("ur-Aran-IN", "ur-IN"),
        ("ur-Arab-IN", "ur-Arab-IN"),

        // Case normalization
        ("EN_US", "en_US"),
        ("en_us", "en_US"),
        ("eN_uS", "en_US"),
        ("ZH-HANS-CN", "zh-Hans-CN"),
        ("sr-latn-rs", "sr-Latn-RS"),

        ("ja_JP_TRADITIONAL", "ja_JP_TRADITIONAL"),
        ("th_TH_TRADITIONAL", "th_TH_TRADITIONAL"),
        ("en_US_POSIX", "en_US_POSIX"),

        // keyword values
        ("en_US@calendar=japanese", "en_US@calendar=japanese"),
        ("de_DE@collation=phonebook", "de_DE@collation=phonebook"),
        ("ar_SA@numbers=arab", "ar_SA@numbers=arab"),
        ("ja_JP_TRADITIONAL@numbers=latn", "ja_JP_TRADITIONAL@numbers=latn"),

        // Legacy code
        ("de-96", "de-1996"),
        ("de_96", "de-1996"),
        ("en-ascii", "en_001"),
        ("es_XL", "es_419"),

        ("", ""),
        ("en", "en"),
        ("und", "und"),
        ("root", "root"),

        // Separator normalization
        ("pt-BR", "pt-BR"),
        ("pt_BR", "pt_BR"),
        ("zh-Hans-CN", "zh-Hans-CN"),
        ("zh_Hans_CN", "zh_CN"),

        // Macrolanguage mappings
        ("arb", "ar"),
        ("zsm", "ms"),
        ("ekk", "et"),
        ("uzn", "uz"),

        // Duplicate language-region-variant/region subtag dedup
        ("en-US_US", "en_US"),
        ("zh-TW_TW", "zh_TW"),
        ("fr-CA_CA", "fr_CA"),
        ("es-MX_AR", "es-MX_AR"),

        // Fuzzer tests
        ("sh", "sh"),
        ("-----------AAA------------------------------------------BB-------CC", "-----------aaa------------------------------------------BB-------cc"),
        // trailing "@" with empty keyword values is trimmed
        ("BRBBrrrrrrrrrrrrrrrrrrrrrrrrrrrtrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrtrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrBB@",
         "brbbrrrrrrrrrrrrrrrrrrrrrrrrrrrtrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrtrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrbb"),

    ]

    @Test(arguments: cases)
    func canonicalLocaleIdentifier(testCase: (identifier: String, expected: String)) {
        let actual = Locale._canonicalLocaleIdentifier(from: testCase.identifier)
        #expect(actual == testCase.expected, "input \"\(testCase.identifier)\"")
    }

#if FOUNDATION_FRAMEWORK
    // TODO: Enable the tests when once we are done implementing ICU locale canonicalization functions in FoundationEssentials
    @Test(arguments: [
        ("zh_TW@COLLATION=pinyin", "zh_TW@collation=pinyin"),
        ("de_DE@currency=DEM;calendar=gregorian", "de_DE@calendar=gregorian;currency=DEM"),
        ("en_US@", "en_US"),
        ("en_US@@calendar=japanese", "en_US"),
        ("en_US@a=1;a=2", "en_US@a=1"),
        ("zh_Hans_CN@collation=big5han", "zh_CN@collation=big5han"),
        ( "hbs-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@a", "sr-Latn-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    ])
    func canonicalLocaleIdentifierWithKeywordValues(testCase: (identifier: String, expected: String)) {
        let actual = Locale._canonicalLocaleIdentifier(from: testCase.identifier)
        #expect(actual == testCase.expected, "input \"\(testCase.identifier)\"")
    }
#endif
}
