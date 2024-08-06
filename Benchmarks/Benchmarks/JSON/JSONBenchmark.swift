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

/// Swift port of [Native-JSON Benchmark](https://github.com/miloyip/nativejson-benchmark)
/*
The MIT License (MIT)

Copyright (c) 2014 Milo Yip

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import Benchmark
import func Benchmark.blackHole

#if os(macOS) && USE_PACKAGE

// Import the package
import FoundationEssentials

// Also import the system Foundation, because we need it for `Bundle` to find resources
import Foundation

// Use the types from the package, to disambiguate from the system Foundation
typealias _Data = FoundationEssentials.Data
typealias _URL = FoundationEssentials.URL
typealias _JSONEncoder = FoundationEssentials.JSONEncoder
typealias _JSONDecoder = FoundationEssentials.JSONDecoder
#else
import Foundation

// Use the types from Foundation
typealias _Data = Foundation.Data
typealias _URL = Foundation.URL
typealias _JSONEncoder = Foundation.JSONEncoder
typealias _JSONDecoder = Foundation.JSONDecoder
#endif

func path(forResource name: String) -> _URL? {
#if FOUNDATION_FRAMEWORK
    // This benchmark config puts resources in the main bundle
    guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return nil }
#else
    // This is always package-based, and uses the module to find resources
    guard let url = Bundle.module.url(forResource: name, withExtension: nil) else { return nil }
#endif
    return _URL(fileURLWithPath: url.path)
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .throughput]
    
    let canadaPath = path(forResource: "canada.json")
    let canadaData = try! _Data(contentsOf: canadaPath!)
    let canada = try! _JSONDecoder().decode(FeatureCollection.self, from: canadaData)

    let twitterPath = path(forResource: "twitter.json")
    let twitterData = try! _Data(contentsOf: twitterPath!)
    let twitter = try! _JSONDecoder().decode(TwitterArchive.self, from: twitterData)

    Benchmark("Canada-decodeFromJSON") { benchmark in
        let result = try _JSONDecoder().decode(FeatureCollection.self, from: canadaData)
        blackHole(result)
    }

    Benchmark("Canada-encodeToJSON") { benchmark in
        let data = try _JSONEncoder().encode(canada)
        blackHole(data)
    }

    Benchmark("Twitter-decodeFromJSON") { benchmark in
        let result = try _JSONDecoder().decode(TwitterArchive.self, from: twitterData)
        blackHole(result)
    }

    Benchmark("Twitter-encodeToJSON") { benchmark in
        let result = try _JSONEncoder().encode(twitter)
        blackHole(result)
    }
}

