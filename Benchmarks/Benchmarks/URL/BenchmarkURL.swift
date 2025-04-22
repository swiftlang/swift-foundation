//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
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
#else
import Foundation
#endif

let benchmarks = {

    Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
    Benchmark.defaultConfiguration.maxDuration = .seconds(3)
    Benchmark.defaultConfiguration.scalingFactor = .kilo
    Benchmark.defaultConfiguration.metrics = [.cpuTotal, .throughput]

    let validURLString = "scheme://username:password@app.example.com:80/pathwithoutspaces/morepath?queryname=queryvalue#fragmentwithoutspaces"
    let invalidURLString = "scheme://username:password@example.com:invalidport/path?query#fragment"
    let encodableURLString = "scheme://user name:pass word@😂😂😂.example.com:80/path with spaces/more path?query name=query value#fragment with spaces"

    // MARK: - String Parsing

    Benchmark("URL-ParseValidASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: validURLString))
        }
    }

    Benchmark("URLComponents-ParseValidASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: validURLString))
        }
    }

    Benchmark("URL-ParseInvalid") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: invalidURLString))
        }
    }

    Benchmark("URLComponents-ParseInvalid") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: invalidURLString))
        }
    }

    #if os(macOS) || compiler(>=6)
    Benchmark("URL-ParseAndEncode") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: encodableURLString))
        }
    }

    Benchmark("URLComponents-ParseAndEncode") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: encodableURLString))
        }
    }
    #endif

    // MARK: - Get URL Components

    // Old swift-corelibs-foundation implementation fails to parse an
    // encodable string but allows encodable components to be set
    var encodedComp = URLComponents()
    encodedComp.scheme = "scheme"
    encodedComp.user = "user name"
    encodedComp.password = "pass word"
    encodedComp.host = "😂😂😂.example.com"
    encodedComp.port = 80
    encodedComp.path = "/path with spaces/more path"
    encodedComp.query = "query name=query value"
    encodedComp.fragment = "fragment with spaces"
    let encodedURL = encodedComp.url!

    #if os(macOS) || compiler(>=6)
    // Component functions, e.g. path(), are available in macOS 13 and Swift 6
    Benchmark("URL-GetEncodedComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(encodedURL.scheme)
            blackHole(encodedURL.user())
            blackHole(encodedURL.password())
            blackHole(encodedURL.host())
            blackHole(encodedURL.path())
            blackHole(encodedURL.query())
            blackHole(encodedURL.fragment())
        }
    }
    #endif

    Benchmark("URLComponents-GetEncodedComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(encodedComp.scheme)
            blackHole(encodedComp.percentEncodedUser)
            blackHole(encodedComp.percentEncodedPassword)
            #if os(macOS) || compiler(>=6)
            blackHole(encodedComp.encodedHost)
            #else
            blackHole(encodedComp.percentEncodedHost)
            #endif
            blackHole(encodedComp.percentEncodedPath)
            blackHole(encodedComp.percentEncodedQuery)
            blackHole(encodedComp.percentEncodedFragment)
        }
    }

    Benchmark("URL-GetDecodedComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(encodedURL.scheme)
            blackHole(encodedURL.user)
            blackHole(encodedURL.password)
            blackHole(encodedURL.host)
            blackHole(encodedURL.path)
            blackHole(encodedURL.query)
            blackHole(encodedURL.fragment)
        }
    }

    Benchmark("URLComponents-GetDecodedComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(encodedComp.scheme)
            blackHole(encodedComp.user)
            blackHole(encodedComp.password)
            blackHole(encodedComp.host)
            blackHole(encodedComp.path)
            blackHole(encodedComp.query)
            blackHole(encodedComp.fragment)
        }
    }

    let validComp = URLComponents(string: validURLString)!
    Benchmark("URLComponents-GetComponentRanges") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(validComp.rangeOfScheme)
            blackHole(validComp.rangeOfUser)
            blackHole(validComp.rangeOfPassword)
            blackHole(validComp.rangeOfHost)
            blackHole(validComp.rangeOfPort)
            blackHole(validComp.rangeOfPath)
            blackHole(validComp.rangeOfQuery)
            blackHole(validComp.rangeOfFragment)
        }
    }

    // MARK: - Set URL Components

    Benchmark("URLComponents-SetComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.scheme = "scheme"
            comp.user = "username"
            comp.password = "password"
            comp.host = "app.example.com"
            comp.port = 80
            comp.path = "/pathwithoutspaces/morepath"
            comp.query = "queryname=queryvalue"
            comp.fragment = "fragmentwithoutspaces"
            blackHole(comp.string)
        }
    }

    Benchmark("URLComponents-SetEncodableComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.scheme = "scheme"
            comp.user = "user name"
            comp.password = "pass word"
            comp.host = "😂😂😂.example.com"
            comp.port = 80
            comp.path = "/path with spaces/more path"
            comp.query = "query name=query value"
            comp.fragment = "fragment with spaces"
            blackHole(comp.string)
        }
    }

    // MARK: - Query Items

    let validQueryItems = [
        URLQueryItem(name: "querywithoutspace", value: "valuewithoutspace"),
        URLQueryItem(name: "myfavoriteletters", value: "abcdabcdabcdabcd"),
        URLQueryItem(name: "namewithnovalueorspace", value: nil)
    ]

    let encodableQueryItems = [
        URLQueryItem(name: "query with space", value: "value with space"),
        URLQueryItem(name: "my favorite emojis", value: "😂😂😂"),
        URLQueryItem(name: "name with no value", value: nil)
    ]

    Benchmark("URLComponents-SetQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.queryItems = validQueryItems
            blackHole(comp)
        }
    }

    Benchmark("URLComponents-SetEncodableQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.queryItems = encodableQueryItems
            blackHole(comp)
        }
    }

    var queryComp = URLComponents()
    queryComp.queryItems = encodableQueryItems

    Benchmark("URLComponents-GetEncodedQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(queryComp.percentEncodedQueryItems)
        }
    }

    Benchmark("URLComponents-GetDecodedQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(queryComp.queryItems)
        }
    }

}
