//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

#if FOUNDATION_FRAMEWORK
// FOUNDATION_FRAMEWORK has a scheme per benchmark file, so only include one benchmark here.
let benchmarks: @Sendable () -> Void = {
    localeBenchmarks()
}
#endif

func localeBenchmarks() {
    Benchmark.defaultConfiguration.maxIterations = 1_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .wallClock, .throughput, .peakMemoryResident, .peakMemoryResidentDelta]

#if FOUNDATION_FRAMEWORK
    let string1 = "aaA" as CFString
    let string2 = "AAà" as CFString
    let range1 = CFRange(location: 0, length: CFStringGetLength(string1))
    let nsLocales = Locale.availableIdentifiers.map {
        NSLocale(localeIdentifier: $0)
    }

    Benchmark("CFStringCompareWithOptionsAndLocale", configuration: .init(scalingFactor: .mega)) { benchmark in
        for nsLocale in nsLocales {
            CFStringCompareWithOptionsAndLocale(string1, string2, range1, .init(rawValue: 0), nsLocale)
        }
    }
#endif

    let identifiers = Locale.availableIdentifiers
    let allComponents = identifiers.map { Locale.Components(identifier: $0) }
    Benchmark("LocaleInitFromComponents") { benchmark in
        for components in allComponents {
            let locale = Locale(components: components)
            let components2 = Locale.Components(locale: locale)
            let locale2 = Locale(components: components2) // cache hit
        }
    }

    Benchmark("LocaleComponentsInitIdentifer") { benchmark in
        for identifier in identifiers {
            let components = Locale.Components(identifier: identifier)
        }
    }

    let legacyIdentifiers: [String] = [ "English", "French", "Japanese", "Norwegian", "Chinese, Simplified", "Chinese, Traditional", "Chinese, Tradtional", "Brazilian Portugese", "Brazilian Portuguese", "Simplified Chinese", "Traditional Chinese", "Flemish", "Nynorsk", "Tagalog", "Farsi", "Scottish", "az.Ar", "az.Cy", "az.La", "zh.Ha-S", "zh.Ha-S_CN", "zh.Ha-T", "zh.Ha-T_TW", "mn.Cy", "mn.Mn", "ms.Ar", "el.El-P", "ga.Lg", "ga.Lg_IE", "sa.Dv", "yi.He", "en_??", "de_??", "es_??", "fr_??", "ar_??", "be_??", "sr_??", "sl_??", "zh-simp", "zh-trad", "ga-dots", "ga-dots_IE", "no-NO", "no-NO_NO", "no_BOKMAL", "no_NYNORSK", "aa_SAAHO", "nl-be", "nl-be_BE", "fra_FR", "deu_DE", "spa_ES", "zho_CN", "jpn_JP", "kor_KR", "cmn", "zh-cmn", "zh-yue", "zh-wuu", "zh-nan", "zh-hak", "zh-min-nan", "zh-guoyu", "zh-hakka", "zh-xiang", "iw_IL", "in_ID", "ji", "jw", "mo", "tw", "art-lojban", "i-hak", "no-bok", "no-nyn", "sgn-us", "en_UK", "pt_TP", "cs_CS", "sk_CS", "sr_CS", "sr_YU", "sh_HR", "sh_RS", "zh-Hans_CN", "zh-Hans_SG", "zh-Hant_TW", "zh-Hant_HK", "zh-Hant_MO", "zh-Hans_TW", "zh-Hant_CN", "en-Latn_US", "ar-Arab_SA", "ru-Cyrl_RU", "ja-Jpan_JP", "de-Latn-1901_DE", "ko-Kore_KR", "en-Cyrl_US", "ks-Aran-IN", "ks-Arab-IN", "ur-Aran-IN", "ur-Arab-IN", "EN_US", "en_us", "eN_uS", "ZH-HANS-CN", "sr-latn-rs", "ja_JP_TRADITIONAL", "th_TH_TRADITIONAL", "en_US_POSIX", "en_US@calendar=japanese", "de_DE@collation=phonebook", "ar_SA@numbers=arab", "ja_JP_TRADITIONAL@numbers=latn", "de-96", "de_96", "en-ascii", "es_XL", "", "en", "und", "root", "pt-BR", "pt_BR", "zh-Hans-CN", "zh_Hans_CN", "arb", "zsm", "ekk", "uzn", "en-US_US", "zh-TW_TW", "fr-CA_CA", "es-MX_AR", "zh_TW@COLLATION=pinyin", "de_DE@currency=DEM;calendar=gregorian", "en_US@", "zh_Hans_CN@collation=big5han", "en_US@@calendar=japanese", "en_US@a=1;a=2"]

#if FOUNDATION_FRAMEWORK
    Benchmark("CanonicalizeIdentifier_CF") { benchmark in
        for identifier in identifiers {
            let r = CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorSystemDefault, identifier as CFString)
            blackHole(r)
        }
    }

    Benchmark("CanonicalizeIdentifier_CF_legacyIdentifiers") { benchmark in
        for identifier in legacyIdentifiers {
            let r = CFLocaleCreateCanonicalLocaleIdentifierFromString(kCFAllocatorSystemDefault, identifier as CFString)
            blackHole(r)
        }
    }
#endif // FOUNDATION_FRAMEWORK

    Benchmark("CanonicalizeIdentifier_Swift") { benchmark in
        for identifier in identifiers {
            let k = Locale.canonicalIdentifier(from: identifier)
            blackHole(k)
        }
    }

    Benchmark("CanonicalizeIdentifier_Swift_legacyIdentifiers") { benchmark in
        for identifier in legacyIdentifiers {
            let k = Locale.canonicalIdentifier(from: identifier)
            blackHole(k)
        }
    }
}
