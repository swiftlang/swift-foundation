//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif
#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif
import Testing
#if FOUNDATION_FRAMEWORK
@_spi(Unstable) internal import CollectionsInternal
#elseif canImport(_RopeModule)
internal import _RopeModule
#elseif canImport(_FoundationCollections)
internal import _FoundationCollections
#endif

//
// These test cases are (mostly) from RFC 6570.
//

private var variables: [URL.Template.VariableName: URL.Template.Value] {
    return [
        "count": ["one", "two", "three"],
        "dom": ["example", "com"],
        "dub": "me/too",
        "hello": "Hello World!",
        "half": "50%",
        "var": "value",
        "who": "fred",
        "base": "http://example.com/home/",
        "path": "/foo/bar",
        "list": ["red", "green", "blue"],
        "keys": [
            "semi": ";",
            "dot": ".",
            "comma": ",",
        ],
        "v": "6",
        "x": "1024",
        "y": "768",
        "empty": "",
        "empty_keys": [:],
    ]
}

private func assertReplacing(template: String, result: String, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        let t = try #require(URL.Template(template))
        #expect(
            t.expand(variables) == result,
            #"template: "\#(template)""#,
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record(
            #"Failed to parse template: "\#(template)": \#(error)"#,
            sourceLocation: sourceLocation
        )
    }
}

@Suite("URL.Template Template")
private enum TemplateTests {
    @Test(arguments: [
        "a",
        "a{count}b",
        "O{undef}X",
        "here?ref={+path}",
        "{/list*,path:4}",
    ])
    static func stringRoundTrip(
        template: String
    ) throws {
        let t = try #require(URL.Template(template))
        #expect("\(t)" == template, "original: '\(template)'")
    }

    @Test
    static func literals() {
        // unreserved / reserved / pct-encoded
        // -> copy

        assertReplacing(template: "foo", result: "foo")
        assertReplacing(template: "foo-._~bar", result: "foo-._~bar")
        assertReplacing(template: "foo:/?#[]@bar", result: "foo:/?#[]@bar")
        assertReplacing(template: "foo!$&'()*+,;=bar", result: "foo!$&'()*+,;=bar")
        assertReplacing(template: "foo%20bar", result: "foo%20bar")
        assertReplacing(template: "foo%20-bar", result: "foo%20-bar")
        assertReplacing(template: "foo%-bar", result: "foo%25-bar")
        assertReplacing(template: "%", result: "%25")

        // others -> escape

        assertReplacing(template: "foo^|bar", result: "foo%5E%7Cbar")

        // Use Normalization Form C (NFC)

        assertReplacing(template: "fooäbar", result: "foo%C3%A4bar")
        assertReplacing(template: "\u{00e2}", result: "%C3%A2")
        assertReplacing(template: "\u{0061}\u{0302}", result: "%C3%A2")
        assertReplacing(template: "\u{fb01}", result: "%EF%AC%81")
    }

    @Test
    static func separators() {
        assertReplacing(template: "{count}", result: "one,two,three")
        assertReplacing(template: "{count*}", result: "one,two,three")
        assertReplacing(template: "{/count}", result: "/one,two,three")
        assertReplacing(template: "{/count*}", result: "/one/two/three")
        assertReplacing(template: "{;count}", result: ";count=one,two,three")
        assertReplacing(template: "{;count*}", result: ";count=one;count=two;count=three")
        assertReplacing(template: "{?count}", result: "?count=one,two,three")
        assertReplacing(template: "{?count*}", result: "?count=one&count=two&count=three")
        assertReplacing(template: "{&count*}", result: "&count=one&count=two&count=three")
    }

    @Test
    static func simpleStringExpansion() {
        assertReplacing(template: "{var}", result: "value")
        assertReplacing(template: "{hello}", result: "Hello%20World%21")
        assertReplacing(template: "{half}", result: "50%25")
        assertReplacing(template: "O{empty}X", result: "OX")
        assertReplacing(template: "O{undef}X", result: "OX")
        assertReplacing(template: "{x,y}", result: "1024,768")
        assertReplacing(template: "{x,hello,y}", result: "1024,Hello%20World%21,768")
        assertReplacing(template: "?{x,empty}", result: "?1024,")
        assertReplacing(template: "?{x,undef}", result: "?1024")
        assertReplacing(template: "?{undef,y}", result: "?768")
        assertReplacing(template: "{var:3}", result: "val")
        assertReplacing(template: "{var:30}", result: "value")
        assertReplacing(template: "{list}", result: "red,green,blue")
        assertReplacing(template: "{list*}", result: "red,green,blue")
        assertReplacing(template: "{keys}", result: "semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "{keys*}", result: "semi=%3B,dot=.,comma=%2C")
    }

    @Test
    static func reservedExpansion() {
        assertReplacing(template: "{+var}", result: "value")
        assertReplacing(template: "{+hello}", result: "Hello%20World!")
        assertReplacing(template: "{+half}", result: "50%25")
        assertReplacing(template: "{base}index", result: "http%3A%2F%2Fexample.com%2Fhome%2Findex")
        assertReplacing(template: "{+base}index", result: "http://example.com/home/index")
        assertReplacing(template: "O{+empty}X", result: "OX")
        assertReplacing(template: "O{+undef}X", result: "OX")
        assertReplacing(template: "{+path}/here", result: "/foo/bar/here")
        assertReplacing(template: "here?ref={+path}", result: "here?ref=/foo/bar")
        assertReplacing(template: "up{+path}{var}/here", result: "up/foo/barvalue/here")
        assertReplacing(template: "{+x,hello,y}", result: "1024,Hello%20World!,768")
        assertReplacing(template: "{+path,x}/here", result: "/foo/bar,1024/here")
        assertReplacing(template: "{+path:6}/here", result: "/foo/b/here")
        assertReplacing(template: "{+list}", result: "red,green,blue")
        assertReplacing(template: "{+list*}", result: "red,green,blue")
        assertReplacing(template: "{+keys}", result: "semi,;,dot,.,comma,,")
        assertReplacing(template: "{+keys*}", result: "semi=;,dot=.,comma=,")
    }

    @Test
    static func fragmentExpansion() {
        assertReplacing(template: "{#var}", result: "#value")
        assertReplacing(template: "{#hello}", result: "#Hello%20World!")
        assertReplacing(template: "{#half}", result: "#50%25")
        assertReplacing(template: "foo{#empty}", result: "foo#")
        assertReplacing(template: "foo{#undef}", result: "foo")
        assertReplacing(template: "{#x,hello,y}", result: "#1024,Hello%20World!,768")
        assertReplacing(template: "{#path,x}/here", result: "#/foo/bar,1024/here")
        assertReplacing(template: "{#path:6}/here", result: "#/foo/b/here")
        assertReplacing(template: "{#list}", result: "#red,green,blue")
        assertReplacing(template: "{#list*}", result: "#red,green,blue")
        assertReplacing(template: "{#keys}", result: "#semi,;,dot,.,comma,,")
        assertReplacing(template: "{#keys*}", result: "#semi=;,dot=.,comma=,")
    }

    @Test
    static func labelExpansionWithDotPrefix() {
        assertReplacing(template: "{.who}", result: ".fred")
        assertReplacing(template: "{.who,who}", result: ".fred.fred")
        assertReplacing(template: "{.half,who}", result: ".50%25.fred")
        assertReplacing(template: "www{.dom*}", result: "www.example.com")
        assertReplacing(template: "X{.var}", result: "X.value")
        assertReplacing(template: "X{.empty}", result: "X.")
        assertReplacing(template: "X{.undef}", result: "X")
        assertReplacing(template: "X{.var:3}", result: "X.val")
        assertReplacing(template: "X{.list}", result: "X.red,green,blue")
        assertReplacing(template: "X{.list*}", result: "X.red.green.blue")
        assertReplacing(template: "X{.keys}", result: "X.semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "X{.keys*}", result: "X.semi=%3B.dot=..comma=%2C")
        assertReplacing(template: "X{.empty_keys}", result: "X")
        assertReplacing(template: "X{.empty_keys*}", result: "X")
    }

    @Test
    static func pathSegmentExpansion() {
        assertReplacing(template: "{/who}", result: "/fred")
        assertReplacing(template: "{/who,who}", result: "/fred/fred")
        assertReplacing(template: "{/half,who}", result: "/50%25/fred")
        assertReplacing(template: "{/who,dub}", result: "/fred/me%2Ftoo")
        assertReplacing(template: "{/var}", result: "/value")
        assertReplacing(template: "{/var,empty}", result: "/value/")
        assertReplacing(template: "{/var,undef}", result: "/value")
        assertReplacing(template: "{/var,x}/here", result: "/value/1024/here")
        assertReplacing(template: "{/var:1,var}", result: "/v/value")
        assertReplacing(template: "{/list}", result: "/red,green,blue")
        assertReplacing(template: "{/list*}", result: "/red/green/blue")
        assertReplacing(template: "{/list*,path:4}", result: "/red/green/blue/%2Ffoo")
        assertReplacing(template: "{/keys}", result: "/semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "{/keys*}", result: "/semi=%3B/dot=./comma=%2C")
    }

    @Test
    static func pathStyleParameterExpansion() {
        assertReplacing(template: "{;who}", result: ";who=fred")
        assertReplacing(template: "{;half}", result: ";half=50%25")
        assertReplacing(template: "{;empty}", result: ";empty")
        assertReplacing(template: "{;v,empty,who}", result: ";v=6;empty;who=fred")
        assertReplacing(template: "{;v,bar,who}", result: ";v=6;who=fred")
        assertReplacing(template: "{;x,y}", result: ";x=1024;y=768")
        assertReplacing(template: "{;x,y,empty}", result: ";x=1024;y=768;empty")
        assertReplacing(template: "{;x,y,undef}", result: ";x=1024;y=768")
        assertReplacing(template: "{;hello:5}", result: ";hello=Hello")
        assertReplacing(template: "{;list}", result: ";list=red,green,blue")
        assertReplacing(template: "{;list*}", result: ";list=red;list=green;list=blue")
        assertReplacing(template: "{;keys}", result: ";keys=semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "{;keys*}", result: ";semi=%3B;dot=.;comma=%2C")
    }

    @Test
    static func formStyleQueryExpansion() {
        assertReplacing(template: "{?who}", result: "?who=fred")
        assertReplacing(template: "{?half}", result: "?half=50%25")
        assertReplacing(template: "{?x,y}", result: "?x=1024&y=768")
        assertReplacing(template: "{?x,y,empty}", result: "?x=1024&y=768&empty=")
        assertReplacing(template: "{?x,y,undef}", result: "?x=1024&y=768")
        assertReplacing(template: "{?var:3}", result: "?var=val")
        assertReplacing(template: "{?list}", result: "?list=red,green,blue")
        assertReplacing(template: "{?list*}", result: "?list=red&list=green&list=blue")
        assertReplacing(template: "{?keys}", result: "?keys=semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "{?keys*}", result: "?semi=%3B&dot=.&comma=%2C")
    }

    @Test
    static func formStyleQueryContinuation() {
        assertReplacing(template: "{&who}", result: "&who=fred")
        assertReplacing(template: "{&half}", result: "&half=50%25")
        assertReplacing(template: "?fixed=yes{&x}", result: "?fixed=yes&x=1024")
        assertReplacing(template: "{&x,y,empty}", result: "&x=1024&y=768&empty=")
        assertReplacing(template: "{&x,y,undef}", result: "&x=1024&y=768")
        assertReplacing(template: "{&var:3}", result: "&var=val")
        assertReplacing(template: "{&list}", result: "&list=red,green,blue")
        assertReplacing(template: "{&list*}", result: "&list=red&list=green&list=blue")
        assertReplacing(template: "{&keys}", result: "&keys=semi,%3B,dot,.,comma,%2C")
        assertReplacing(template: "{&keys*}", result: "&semi=%3B&dot=.&comma=%2C")
    }
}
