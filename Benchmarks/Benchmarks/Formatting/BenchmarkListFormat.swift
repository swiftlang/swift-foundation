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

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE
import FoundationEssentials
import FoundationInternationalization
#else
import Foundation
#endif

// Benchmarks for `ListFormatStyle`. These call the public API, so swapping
// between the ICU bridge and the native implementation is a build-flag
// concern: build the benchmarks package with and without
// `FOUNDATION_LIST_FORMAT_NATIVE` and diff the runs.
func listFormatBenchmarks() {
    typealias Style = ListFormatStyle<StringStyle, [String]>

    let scaling = Benchmark.Configuration(scalingFactor: .kilo)

    // MARK: Inputs

    let englishItems = ["Apple", "Orange", "Banana"]
    let single = ["only"]
    let pair = ["one", "two"]
    let empty: [String] = []
    let longItems = (0..<20).map { "item\($0)" }

    // Spanish: third item starts with "i" → triggers the y→e rule.
    let spanishItems = ["agua", "aceite", "hierro"]

    // Hebrew: second item starts with non-Hebrew text → triggers the
    // vav-prefix rule.
    let hebrewItems = ["חיפה", "Tel Aviv"]

    // Thai: connector adjacent to a non-Thai item → triggers the joiner
    // spacing rule.
    let thaiItems = ["ข้อความธรรมดา", "1 ภาพ"]

    // Mixed direction: Arabic items in an English list trigger FSI/PDI
    // wrapping around the wrong-direction items.
    let bidiMixed = ["Alice", "\u{628}\u{628}\u{628}", "Charlie"]

    // MARK: Pre-built styles (formatter cache warm)

    let enStyle: Style = .list(type: .and, width: .standard)
        .locale(Locale(identifier: "en"))
    let esStyle: Style = .list(type: .and, width: .standard)
        .locale(Locale(identifier: "es"))
    let heStyle: Style = .list(type: .and, width: .standard)
        .locale(Locale(identifier: "he"))
    let thStyle: Style = .list(type: .and, width: .standard)
        .locale(Locale(identifier: "th"))

    let multiLocaleStyles: [Style] = [
        "en", "es", "en_GB", "en_001", "fr",
        "de", "ja", "ar", "ru", "zh",
    ].map { .list(type: .and, width: .standard).locale(Locale(identifier: $0)) }

    // MARK: Edge-case branches in the formatting algorithm

    Benchmark("list-format-en-empty", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(empty.formatted(enStyle))
        }
    }

    Benchmark("list-format-en-single", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(single.formatted(enStyle))
        }
    }

    Benchmark("list-format-en-pair", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(pair.formatted(enStyle))
        }
    }

    // MARK: Hot path — typical 3-item English list

    Benchmark("list-format-en-three", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(englishItems.formatted(enStyle))
        }
    }

    // MARK: Long list — exercises start + middle*N + end vs the pair branch

    Benchmark("list-format-en-long", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(longItems.formatted(enStyle))
        }
    }

    // MARK: Contextual rules unique to the native implementation

    Benchmark("list-format-es-contextual", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(spanishItems.formatted(esStyle))
        }
    }

    Benchmark("list-format-he-contextual", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(hebrewItems.formatted(heStyle))
        }
    }

    Benchmark("list-format-th-contextual", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(thaiItems.formatted(thStyle))
        }
    }

    // MARK: FSI/PDI bidi wrapping

    Benchmark("list-format-bidi-mixed", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(bidiMixed.formatted(enStyle))
        }
    }

    // MARK: Parent walk + cache lookup variety

    Benchmark("list-format-multi-locale", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            for style in multiLocaleStyles {
                blackHole(englishItems.formatted(style))
            }
        }
    }

    // MARK: Style construction overhead
    //
    // Constructs a fresh style each iteration. The FormatterCache key matches
    // the warm case, so this measures the (style init + .locale modifier +
    // signature hash + cache lookup) cost on top of the format itself.

    Benchmark("list-format-fresh-style", configuration: scaling) { benchmark in
        for _ in benchmark.scaledIterations {
            let style: Style = .list(type: .and, width: .standard)
                .locale(Locale(identifier: "en"))
            blackHole(englishItems.formatted(style))
        }
    }
}
