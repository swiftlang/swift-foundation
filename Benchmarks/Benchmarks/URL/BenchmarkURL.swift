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

    let validURLString = "http://example.com/path/index.html?query=value&some#fragment"
    let invalidURLString = "scheme://username:password@example.com:invalidport/path?query#fragment"
    let encodableASCIIString = "http://example.com/users/John Doe/home?date=01\\01\\2001"
    let encodableUnicodeString = "http://😂😂😂.com/users/i❤️swift/home%2Fpath?date=01∕01∕2001"

    // MARK: - String Parsing

    Benchmark("URL.ParseValidASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: validURLString))
        }
    }

    Benchmark("URLComponents.ParseValidASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: validURLString))
        }
    }

    Benchmark("URL.ParseInvalid") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: invalidURLString))
        }
    }

    Benchmark("URLComponents.ParseInvalid") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: invalidURLString))
        }
    }

    #if os(macOS) || compiler(>=6)
    Benchmark("URL.ParseAndEncodeASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: encodableASCIIString))
        }
    }

    Benchmark("URLComponents.ParseAndEncodeASCII") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: encodableASCIIString))
        }
    }

    Benchmark("URL.ParseAndEncodeUnicode") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: encodableUnicodeString))
        }
    }

    Benchmark("URLComponents.ParseAndEncodeUnicode") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URLComponents(string: encodableUnicodeString))
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
    Benchmark("URL.GetEncodedComponents") { benchmark in
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

    Benchmark("URLComponents.GetEncodedComponents") { benchmark in
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

    Benchmark("URL.GetDecodedComponents") { benchmark in
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

    Benchmark("URLComponents.GetDecodedComponents") { benchmark in
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
    Benchmark("URLComponents.GetComponentRanges") { benchmark in
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

    Benchmark("URLComponents.SetComponents") { benchmark in
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

    Benchmark("URLComponents.SetEncodableComponents") { benchmark in
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

    Benchmark("URLComponents.SetQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.queryItems = validQueryItems
            blackHole(comp)
        }
    }

    Benchmark("URLComponents.SetEncodableQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            var comp = URLComponents()
            comp.queryItems = encodableQueryItems
            blackHole(comp)
        }
    }

    var queryComp = URLComponents()
    queryComp.queryItems = encodableQueryItems

    Benchmark("URLComponents.GetEncodedQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(queryComp.percentEncodedQueryItems)
        }
    }

    Benchmark("URLComponents.GetDecodedQueryItems") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(queryComp.queryItems)
        }
    }

    // MARK: - URL.Template

    Benchmark("URL.TemplateParsing") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL.Template("/api/{version}/accounts/{accountId}/transactions/{transactionId}{?expand*,fields*,embed*,format}")!)
            blackHole(URL.Template("/special/{+a}/details")!)
            blackHole(URL.Template("/documents/{documentId}{#section,paragraph}")!)
        }
    }

    let templates = [
        URL.Template("/var/{var}/who/{who}/x/{x}{?keys*,count*,list*,y}")!,
        URL.Template("/special/{+keys}/details")!,
        URL.Template("x/y/{#path:6}/here")!,
        URL.Template("a/b{/var,x}/here")!,
        URL.Template("a{?var,y}")!,
    ]

    var variables: [URL.Template.VariableName: URL.Template.Value] = [
        .init("count"): ["one", "two", "three"],
        .init("dom"): ["example", "com"],
        .init("dub"): "me/too",
        .init("hello"): "Hello World!",
        .init("half"): "50%",
        .init("var"): "value",
        .init("who"): "fred",
        .init("base"): "http://example.com/home/",
        .init("path"): "/foo/bar",
        .init("list"): ["red", "green", "blue"],
        .init("keys"): [
            "semi": ";",
            "dot": ".",
            "comma": ",",
        ],
        .init("v"): "6",
        .init("x"): "1024",
        .init("y"): "768",
        .init("empty"): "",
        .init("empty_keys"): [:],
    ]

    Benchmark("URL.TemplateExpansion") { benchmark in
        for _ in benchmark.scaledIterations {
            for t in templates {
                blackHole(URL(template: t, variables: variables))
            }
        }
    }

    // MARK: - Non-File URL Path Manipulation

    let url = URL(string: "https://www.swift.org/api/v1/install/")!

    Benchmark("URL.isFileURL") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(url.isFileURL)
        }
    }

    Benchmark("URL.AppendingPathComponent") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(url.appending(path: "releases.json"))
        }
    }

    Benchmark("URL.DeletingLastPathComponent") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(url.deletingLastPathComponent())
        }
    }

    Benchmark("URL.PathComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(url.pathComponents)
        }
    }

    let swiftly = URL(string: ".././swiftly.json", relativeTo: url)!

    Benchmark("URL.Standardized") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(swiftly.standardized)
        }
    }

    Benchmark("URL.AbsoluteURL") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(swiftly.absoluteURL)
        }
    }

    // MARK: - File URL

    Benchmark("URL.ParseFilePath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(filePath: "/Users/Foo/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/"))
        }
    }

    let fileURL = URL(filePath: "/Users/Foo/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/")

    Benchmark("FileURL.isFileURL") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.isFileURL)
        }
    }

    Benchmark("FileURL.GetPath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.path)
        }
    }

    Benchmark("FileURL.AppendingPathComponent") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.appending(path: "modules.timestamp"))
        }
    }

    Benchmark("FileURL.DeletingLastPathComponent") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.deletingLastPathComponent())
        }
    }

    Benchmark("FileURL.LastPathComponent") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.lastPathComponent)
        }
    }

    Benchmark("FileURL.PathComponents") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.pathComponents)
        }
    }

    Benchmark("FileURL.AppendingPathExtension") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.appendingPathExtension("tar.gz"))
        }
    }

    Benchmark("FileURL.DeletingPathExtension") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.deletingPathExtension())
        }
    }

    Benchmark("FileURL.PathExtension") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURL.pathExtension)
        }
    }

    let fileURLWithDots = URL(filePath: "/Users/Foo/./Downloads/../Library//Developer/./Xcode/DerivedData/..")

    Benchmark("FileURL.Standardized") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(fileURLWithDots.standardized)
        }
    }

    Benchmark("URL.ParseAndEncodeFilePath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(filePath: "/Users/John Doe/Application Support/Xcode/"))
        }
    }

    let encodableFileURL = URL(filePath: "/Users/John Doe/Application Support/Xcode/")

    Benchmark("FileURL.GetDecodedPath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(encodableFileURL.path)
        }
    }

    // MARK: - Data Round Trip

    var data = Data("data:".utf8)
    for i in 0..<1000 {
        data.append(UInt8(i % 128))
    }

    Benchmark("URL.DataRepresentation") { benchmark in
        for _ in benchmark.scaledIterations {
            let url = URL(dataRepresentation: data, relativeTo: nil)!
            blackHole(url)
            blackHole(url.dataRepresentation)
        }
    }

    // MARK: - Long Strings

    let longDataString = {
        var string = "data:text/plain;base64,"
        for i in 0..<2048 {
            string += "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9w"
        }
        return string
    }()

    Benchmark("URL.ParseBigString") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(string: longDataString))
        }
    }

    Benchmark("URL.ParseBigFilePath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(filePath: "/Lorem/ipsum/dolor/sit/amet,/consectetur/adipiscing/elit./Aliquam/aliquam/a/libero/sit/amet/eleifend./Nulla/sapien/mi,/eleifend/quis/accumsan/id,/sollicitudin/in/nulla./Fusce/non/sodales/dolor./Morbi/luctus/consequat/felis/vitae/elementum./Nam/id/ex/in/sapien/congue/varius/nec/quis/eros./Proin/ut/turpis/eu/nisl/efficitur/tempus./Donec/mattis/congue/arcu/vel/convallis./Integer/sit/amet/nunc/sagittis,/gravida/ligula/eu,/varius/quam./Phasellus/sodales/ut/libero/id/ultrices./Mauris/tristique/risus/quis/massa/porta,/vel/ornare/libero/pharetra./Phasellus/id/suscipit/magna./Etiam/porta/nunc/ut/dolor/sollicitudin/commodo./Praesent/consequat/elit/a/ipsum/sodales/rhoncus./Fusce/malesuada/sed/diam/eget/rhoncus./Mauris/et/interdum/nulla./Sed/egestas/egestas/turpis/nec/imperdiet."))
        }
    }

    Benchmark("URL.ParseAndEncodeBigFilePath") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(URL(filePath: "/Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam aliquam a libero sit amet eleifend. Nulla sapien mi, eleifend quis accumsan id, sollicitudin in nulla. Fusce non sodales dolor. Morbi luctus consequat felis vitae elementum. Nam id ex in sapien congue varius nec quis eros. Proin ut turpis eu nisl efficitur tempus. Donec mattis congue arcu vel convallis. Integer sit amet nunc sagittis, gravida ligula eu, varius quam. Phasellus sodales ut libero id ultrices. Mauris tristique risus quis massa porta, vel ornare libero pharetra. Phasellus id suscipit magna. Etiam porta nunc ut dolor sollicitudin commodo. Praesent consequat elit a ipsum sodales rhoncus. Fusce malesuada sed diam eget rhoncus. Mauris et interdum nulla. Sed egestas egestas turpis nec imperdiet."))
        }
    }
}
