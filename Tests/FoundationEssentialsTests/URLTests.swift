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

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

private func checkBehavior<T: Equatable>(_ result: T, new: T, old: T, sourceLocation: SourceLocation = #_sourceLocation) {
    #if FOUNDATION_FRAMEWORK
    if foundation_swift_url_enabled() {
        #expect(result == new, sourceLocation: sourceLocation)
    } else {
        #expect(result == old, sourceLocation: sourceLocation)
    }
    #else
    #expect(result == new, sourceLocation: sourceLocation)
    #endif
}

@Suite("URL")
private struct URLTests {

    @Test func basics() throws {
        let string = "https://username:password@example.com:80/path/path?query=value&q=v#fragment"
        let url = try #require(URL(string: string))

        #expect(url.scheme == "https")
        #expect(url.user() == "username")
        #expect(url.password() == "password")
        #expect(url.host() == "example.com")
        #expect(url.port == 80)
        #expect(url.path() == "/path/path")
        #expect(url.relativePath == "/path/path")
        #expect(url.query() == "query=value&q=v")
        #expect(url.fragment() == "fragment")
        #expect(url.absoluteString == string)
        #expect(url.absoluteURL == url)
        #expect(url.relativeString == string)
        #expect(url.baseURL == nil)

        let baseString = "https://user:pass@base.example.com:8080/base/"
        let baseURL = try #require(URL(string: baseString))
        let absoluteURLWithBase = try #require(URL(string: string, relativeTo: baseURL))

        // The URL is already absolute, so .baseURL is nil, and the components are unchanged
        #expect(absoluteURLWithBase.scheme == "https")
        #expect(absoluteURLWithBase.user() == "username")
        #expect(absoluteURLWithBase.password() == "password")
        #expect(absoluteURLWithBase.host() == "example.com")
        #expect(absoluteURLWithBase.port == 80)
        #expect(absoluteURLWithBase.path() == "/path/path")
        #expect(absoluteURLWithBase.relativePath == "/path/path")
        #expect(absoluteURLWithBase.query() == "query=value&q=v")
        #expect(absoluteURLWithBase.fragment() == "fragment")
        #expect(absoluteURLWithBase.absoluteString == string)
        #expect(absoluteURLWithBase.absoluteURL == url)
        #expect(absoluteURLWithBase.relativeString == string)
        #expect(absoluteURLWithBase.baseURL == nil)
        #expect(absoluteURLWithBase.absoluteURL == url)

        let relativeString = "relative/path?query#fragment"
        let relativeURL = try #require(URL(string: relativeString))

        #expect(relativeURL.scheme == nil)
        #expect(relativeURL.user() == nil)
        #expect(relativeURL.password() == nil)
        #expect(relativeURL.host() == nil)
        #expect(relativeURL.port == nil)
        #expect(relativeURL.path() == "relative/path")
        #expect(relativeURL.relativePath == "relative/path")
        #expect(relativeURL.query() == "query")
        #expect(relativeURL.fragment() == "fragment")
        #expect(relativeURL.absoluteString == relativeString)
        #expect(relativeURL.absoluteURL == relativeURL)
        #expect(relativeURL.relativeString == relativeString)
        #expect(relativeURL.baseURL == nil)

        let relativeURLWithBase = try #require(URL(string: relativeString, relativeTo: baseURL))

        #expect(relativeURLWithBase.scheme == baseURL.scheme)
        #expect(relativeURLWithBase.user() == baseURL.user())
        #expect(relativeURLWithBase.password() == baseURL.password())
        #expect(relativeURLWithBase.host() == baseURL.host())
        #expect(relativeURLWithBase.port == baseURL.port)
        #expect(relativeURLWithBase.path() == "/base/relative/path")
        #expect(relativeURLWithBase.relativePath == "relative/path")
        #expect(relativeURLWithBase.query() == "query")
        #expect(relativeURLWithBase.fragment() == "fragment")
        #expect(relativeURLWithBase.absoluteString == "https://user:pass@base.example.com:8080/base/relative/path?query#fragment")
        #expect(relativeURLWithBase.absoluteURL == URL(string: "https://user:pass@base.example.com:8080/base/relative/path?query#fragment"))
        #expect(relativeURLWithBase.relativeString == relativeString)
        #expect(relativeURLWithBase.baseURL == baseURL)
    }

    @Test func resolvingAgainstBase() throws {
        let base = URL(string: "http://a/b/c/d;p?q")
        let tests = [
            // RFC 3986 5.4.1. Normal Examples
            "g:h"           :  "g:h",
            "g"             :  "http://a/b/c/g",
            "./g"           :  "http://a/b/c/g",
            "g/"            :  "http://a/b/c/g/",
            "/g"            :  "http://a/g",
            "//g"           :  "http://g",
            "?y"            :  "http://a/b/c/d;p?y",
            "g?y"           :  "http://a/b/c/g?y",
            "#s"            :  "http://a/b/c/d;p?q#s",
            "g#s"           :  "http://a/b/c/g#s",
            "g?y#s"         :  "http://a/b/c/g?y#s",
            ";x"            :  "http://a/b/c/;x",
            "g;x"           :  "http://a/b/c/g;x",
            "g;x?y#s"       :  "http://a/b/c/g;x?y#s",
            ""              :  "http://a/b/c/d;p?q",
            "."             :  "http://a/b/c/",
            "./"            :  "http://a/b/c/",
            ".."            :  "http://a/b/",
            "../"           :  "http://a/b/",
            "../g"          :  "http://a/b/g",
            "../.."         :  "http://a/",
            "../../"        :  "http://a/",
            "../../g"       :  "http://a/g",

            // RFC 3986 5.4.1. Abnormal Examples
            "../../../g"    :  "http://a/g",
            "../../../../g" :  "http://a/g",
            "/./g"          :  "http://a/g",
            "/../g"         :  "http://a/g",
            "g."            :  "http://a/b/c/g.",
            ".g"            :  "http://a/b/c/.g",
            "g.."           :  "http://a/b/c/g..",
            "..g"           :  "http://a/b/c/..g",

            "./../g"        :  "http://a/b/g",
            "./g/."         :  "http://a/b/c/g/",
            "g/./h"         :  "http://a/b/c/g/h",
            "g/../h"        :  "http://a/b/c/h",
            "g;x=1/./y"     :  "http://a/b/c/g;x=1/y",
            "g;x=1/../y"    :  "http://a/b/c/y",

            "g?y/./x"       :  "http://a/b/c/g?y/./x",
            "g?y/../x"      :  "http://a/b/c/g?y/../x",
            "g#s/./x"       :  "http://a/b/c/g#s/./x",
            "g#s/../x"      :  "http://a/b/c/g#s/../x",

            "http:g"        :  "http:g", // For strict parsers
        ]

        let testsFailingWithoutSwiftURL = Set([
            "",
            "../../../g",
            "../../../../g",
            "/./g",
            "/../g",
        ])

        for test in tests {
            if !foundation_swift_url_enabled(), testsFailingWithoutSwiftURL.contains(test.key) {
                continue
            }

            let url = try #require(URL(stringOrEmpty: test.key, relativeTo: base), "Got nil url for string: \(test.key)")
            #expect(url.absoluteString == test.value, "Failed test for string: \(test.key)")
        }
    }

    @Test(.enabled(if: foundation_swift_url_enabled()))
    func pathAPIsResolveAgainstBase() throws {
        // Borrowing the same test cases from RFC 3986, but checking paths
        let base = URL(string: "http://a/b/c/d;p?q")
        let tests = [
            // RFC 3986 5.4.1. Normal Examples
            "g:h"           :  "h",
            "g"             :  "/b/c/g",
            "./g"           :  "/b/c/g",
            "g/"            :  "/b/c/g/",
            "/g"            :  "/g",
            "//g"           :  "",
            "?y"            :  "/b/c/d;p",
            "g?y"           :  "/b/c/g",
            "#s"            :  "/b/c/d;p",
            "g#s"           :  "/b/c/g",
            "g?y#s"         :  "/b/c/g",
            ";x"            :  "/b/c/;x",
            "g;x"           :  "/b/c/g;x",
            "g;x?y#s"       :  "/b/c/g;x",
            ""              :  "/b/c/d;p",
            "."             :  "/b/c/",
            "./"            :  "/b/c/",
            ".."            :  "/b/",
            "../"           :  "/b/",
            "../g"          :  "/b/g",
            "../.."         :  "/",
            "../../"        :  "/",
            "../../g"       :  "/g",

            // RFC 3986 5.4.1. Abnormal Examples
            "../../../g"    :  "/g",
            "../../../../g" :  "/g",
            "/./g"          :  "/g",
            "/../g"         :  "/g",
            "g."            :  "/b/c/g.",
            ".g"            :  "/b/c/.g",
            "g.."           :  "/b/c/g..",
            "..g"           :  "/b/c/..g",

            "./../g"        :  "/b/g",
            "./g/."         :  "/b/c/g/",
            "g/./h"         :  "/b/c/g/h",
            "g/../h"        :  "/b/c/h",
            "g;x=1/./y"     :  "/b/c/g;x=1/y",
            "g;x=1/../y"    :  "/b/c/y",

            "g?y/./x"       :  "/b/c/g",
            "g?y/../x"      :  "/b/c/g",
            "g#s/./x"       :  "/b/c/g",
            "g#s/../x"      :  "/b/c/g",

            "http:g"        :  "g", // For strict parsers
        ]
        for test in tests {
            let url = URL(stringOrEmpty: test.key, relativeTo: base)!
            #expect(url.absolutePath() == test.value)
            if (url.hasDirectoryPath && url.absolutePath().count > 1) {
                // The trailing slash is stripped in .path for file system compatibility
                #expect(String(url.absolutePath().dropLast()) == url.path)
            } else {
                #expect(url.absolutePath() == url.path)
            }
        }
    }

    @Test
    func checkComponentValidation() throws {
        struct ValidationResults: Equatable {
            var lower: UInt128 = 0
            var upper: UInt128 = 0
            mutating func setAllowed(_ codeUnit: UInt8) {
                if codeUnit < 128 {
                    lower |= (UInt128(1) << codeUnit)
                } else {
                    upper |= (UInt128(1) << codeUnit)
                }
            }
        }

        var schemeResults = ValidationResults()
        var userResults = ValidationResults()
        var passwordResults = ValidationResults()
        var hostResults = ValidationResults()
        var hostIPvFutureResults = ValidationResults()
        var hostZoneIDResults = ValidationResults()
        var portResults = ValidationResults()
        var pathResults = ValidationResults()
        var pathFirstSegmentResults = ValidationResults()
        var queryResults = ValidationResults()
        var queryItemResults = ValidationResults()
        var fragmentResults = ValidationResults()

        for codeUnit in UInt8(0)...UInt8(255) {
            let s = String(UnicodeScalar(codeUnit))
            // Scheme must start with ALPHA, so satisfy that here
            if RFC3986Parser.validate("A\(s)", component: .scheme) {
                schemeResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .user) {
                userResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .password) {
                passwordResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .host) {
                hostResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate("[\(s)]", component: .host) {
                hostIPvFutureResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate("[::1%25\(s)]", component: .host) {
                hostZoneIDResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .port) {
                portResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate("/\(s)", component: .path) {
                pathResults.setAllowed(codeUnit)
            }
            // URLComponents handles path first segment validation
            var comp = URLComponents()
            comp.path = s
            if comp.percentEncodedPath == s {
                pathFirstSegmentResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .query) {
                queryResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .queryItem) {
                queryItemResults.setAllowed(codeUnit)
            }
            if RFC3986Parser.validate(s, component: .fragment) {
                fragmentResults.setAllowed(codeUnit)
            }
        }

        // Non-ASCII characters shouldn't be allowed in any component
        #expect(schemeResults.upper == 0)
        #expect(userResults.upper == 0)
        #expect(passwordResults.upper == 0)
        #expect(hostResults.upper == 0)
        #expect(hostIPvFutureResults.upper == 0)
        #expect(hostZoneIDResults.upper == 0)
        #expect(portResults.upper == 0)
        #expect(pathResults.upper == 0)
        #expect(pathFirstSegmentResults.upper == 0)
        #expect(queryResults.upper == 0)
        #expect(queryItemResults.upper == 0)
        #expect(fragmentResults.upper == 0)

        // Actual checks for valid ASCII characters
        #expect(schemeResults.lower == 0x07fffffe07fffffe03ff680000000000)
        #expect(userResults.lower == 0x47fffffe87fffffe2fff7fd200000000)
        #expect(passwordResults.lower == 0x47fffffe87fffffe2fff7fd200000000)
        #expect(hostResults.lower == 0x47fffffe87fffffe2bff7fd200000000)
        #expect(hostIPvFutureResults.lower == 0x47fffffe87fffffe2fff7fd200000000)
        #expect(hostZoneIDResults.lower == 0x47fffffe87fffffe03ff600000000000)
        #expect(portResults.lower == 0x000000000000000003ff000000000000)
        #expect(pathResults.lower == 0x47fffffe87ffffff2fffffd200000000)
        #expect(pathFirstSegmentResults.lower == 0x47fffffe87ffffff2bffffd200000000)
        #expect(queryResults.lower == 0x47fffffe87ffffffafffffd200000000)
        #expect(queryItemResults.lower == 0x47fffffe87ffffff8fffff9200000000)
        #expect(fragmentResults.lower == 0x47fffffe87ffffffafffffd200000000)
    }

    
    @Test(.enabled(if: foundation_swift_url_enabled()))
    func pathComponentsPercentEncodedSlash() throws {
        var url = try #require(URL(string: "https://example.com/https%3A%2F%2Fexample.com"))
        #expect(url.pathComponents == ["/", "https://example.com"])

        url = try #require(URL(string: "https://example.com/https:%2f%2fexample.com"))
        #expect(url.pathComponents == ["/", "https://example.com"])

        url = try #require(URL(string: "https://example.com/https:%2F%2Fexample.com%2Fpath"))
        #expect(url.pathComponents == ["/", "https://example.com/path"])

        url = try #require(URL(string: "https://example.com/https:%2F%2Fexample.com/path"))
        #expect(url.pathComponents == ["/", "https://example.com", "path"])

        url = try #require(URL(string: "https://example.com/https%3A%2F%2Fexample.com%2Fpath%3Fquery%23fragment"))
        #expect(url.pathComponents == ["/", "https://example.com/path?query#fragment"])

        url = try #require(URL(string: "https://example.com/https%3A%2F%2Fexample.com%2Fpath?query#fragment"))
        #expect(url.pathComponents == ["/", "https://example.com/path"])
    }

    
    @Test(.enabled(if: foundation_swift_url_enabled()))
    func rootlessPath() throws {
        let paths = ["", "path"]
        let queries = [nil, "query"]
        let fragments = [nil, "fragment"]

        for path in paths {
            for query in queries {
                for fragment in fragments {
                    let queryString = query != nil ? "?\(query!)" : ""
                    let fragmentString = fragment != nil ? "#\(fragment!)" : ""
                    let urlString = "scheme:\(path)\(queryString)\(fragmentString)"
                    let url = try #require(URL(string: urlString))
                    #expect(url.absoluteString == urlString)
                    #expect(url.scheme == "scheme")
                    #expect(url.host() == nil)
                    #expect(url.path() == path)
                    #expect(url.query() == query)
                    #expect(url.fragment() == fragment)
                }
            }
        }
    }

    @Test func nonSequentialIPLiteralAndPort() {
        let urlString = "https://[fe80::3221:5634:6544]invalid:433/"
        let url = URL(string: urlString)
        #expect(url == nil)
    }

    @Test func filePathInitializer() throws {
        let directory = URL(filePath: "/some/directory", directoryHint: .isDirectory)
        #expect(directory.hasDirectoryPath)

        let notDirectory = URL(filePath: "/some/file", directoryHint: .notDirectory)
        #expect(!notDirectory.hasDirectoryPath)

        // directoryHint defaults to .inferFromPath
        let directoryAgain = URL(filePath: "/some/directory.framework/")
        #expect(directoryAgain.hasDirectoryPath)

        let notDirectoryAgain = URL(filePath: "/some/file")
        #expect(!notDirectoryAgain.hasDirectoryPath)

        // Test .checkFileSystem by creating a directory
        let tempDirectory = URL.temporaryDirectory
        let urlBeforeCreation = URL(filePath: "\(tempDirectory.path)/tmp-dir", directoryHint: .checkFileSystem)
        #expect(!urlBeforeCreation.hasDirectoryPath)

        try FileManager.default.createDirectory(
            at: URL(filePath: "\(tempDirectory.path)/tmp-dir"),
            withIntermediateDirectories: true
        )
        let urlAfterCreation = URL(filePath: "\(tempDirectory.path)/tmp-dir", directoryHint: .checkFileSystem)
        #expect(urlAfterCreation.hasDirectoryPath)
        try FileManager.default.removeItem(at: URL(filePath: "\(tempDirectory.path)/tmp-dir"))
    }

    #if FOUNDATION_FRAMEWORK
    @Test func fileSystemRepresentations() throws {
        let base = "/base/"
        let pathNFC = "/caf\u{E9}"
        let relativeNFC = "caf\u{E9}"
        let pathNFD = "/cafe\u{301}"
        let relativeNFD = "cafe\u{301}"

        let resolvedPathNFC = "/base/caf\u{E9}"
        let resolvedPathNFD = "/base/cafe\u{301}"
        let baseExtensionNFD = "/base.cafe\u{301}"
        let doubleCafeNFD = "/cafe\u{301}/cafe\u{301}"

        // URL(filePath:) should always convert the input to decomposed (NFD) representation
        let baseURL = URL(filePath: base)
        let urlNFC = URL(filePath: pathNFC)
        let urlRelativeNFC = URL(filePath: relativeNFC, relativeTo: baseURL)
        let urlNFD = URL(filePath: pathNFD)
        let urlRelativeNFD = URL(filePath: relativeNFD, relativeTo: baseURL)

        func equalBytes(_ p1: UnsafePointer<CChar>, _ p2: UnsafePointer<CChar>) -> Bool {
            return strcmp(p1, p2) == 0
        }

        // Compare bytes to ensure we have the right representation
        #expect(equalBytes(urlNFC.path, pathNFD))
        #expect(equalBytes(urlNFD.path, pathNFD))
        #expect(urlNFC == urlNFD)

        #expect(equalBytes(urlRelativeNFC.path, resolvedPathNFD))
        #expect(equalBytes(urlRelativeNFD.path, resolvedPathNFD))
        #expect(urlRelativeNFC == urlRelativeNFD)

        // withUnsafeFileSystemRepresentation should return a pointer to decomposed bytes
        try urlNFC.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        try urlNFD.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        try urlRelativeNFC.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, resolvedPathNFD))
        }

        try urlRelativeNFD.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, resolvedPathNFD))
        }

        // ...unless we specifically .init(fileURLWithFileSystemRepresentation:) with absolute NFC
        let urlNFCFSR = URL(fileURLWithFileSystemRepresentation: pathNFC, isDirectory: false, relativeTo: nil)
        let urlNFDFSR = URL(fileURLWithFileSystemRepresentation: pathNFD, isDirectory: false, relativeTo: nil)

        #expect(equalBytes(urlNFCFSR.path, pathNFC))
        #expect(equalBytes(urlNFDFSR.path, pathNFD))
        #expect(urlNFCFSR != urlNFDFSR)

        try urlNFCFSR.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFC))
        }

        try urlNFDFSR.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        // If we .init(fileURLWithFileSystemRepresentation:) with a relative path,
        // we store the given representation but must convert when returning it
        let urlRelativeNFCFSR = URL(fileURLWithFileSystemRepresentation: relativeNFC, isDirectory: false, relativeTo: baseURL)
        let urlRelativeNFDFSR = URL(fileURLWithFileSystemRepresentation: relativeNFD, isDirectory: false, relativeTo: baseURL)

        #expect(equalBytes(urlRelativeNFCFSR.path, resolvedPathNFC))
        #expect(equalBytes(urlRelativeNFDFSR.path, resolvedPathNFD))
        #expect(urlRelativeNFCFSR != urlRelativeNFDFSR)

        try urlRelativeNFCFSR.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, resolvedPathNFD))
        }

        try urlRelativeNFDFSR.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, resolvedPathNFD))
        }

        // Appending a path component should convert to decomposed for file URLs
        let baseWithNFCComponent = baseURL.appending(path: relativeNFC)
        #expect(equalBytes(baseWithNFCComponent.path, resolvedPathNFD))

        let baseWithNFDComponent = baseURL.appending(path: relativeNFD)
        #expect(equalBytes(baseWithNFDComponent.path, resolvedPathNFD))
        #expect(baseWithNFCComponent == baseWithNFDComponent)

        let urlNFCWithNFCComponent = urlNFC.appending(path: relativeNFC)
        let urlNFCWithNFDComponent = urlNFC.appending(path: relativeNFD)
        let urlNFDWithNFCComponent = urlNFD.appending(path: relativeNFC)
        let urlNFDWithNFDComponent = urlNFD.appending(path: relativeNFD)
        #expect(equalBytes(urlNFCWithNFCComponent.path, doubleCafeNFD))
        #expect(equalBytes(urlNFCWithNFDComponent.path, doubleCafeNFD))
        #expect(equalBytes(urlNFDWithNFCComponent.path, doubleCafeNFD))
        #expect(equalBytes(urlNFDWithNFDComponent.path, doubleCafeNFD))
        #expect(urlNFCWithNFCComponent == urlNFCWithNFDComponent)
        #expect(urlNFCWithNFCComponent == urlNFDWithNFCComponent)
        #expect(urlNFCWithNFCComponent == urlNFDWithNFDComponent)

        // Appending an extension should convert to decomposed for file URLs
        let baseWithNFCExtension = baseURL.appendingPathExtension(relativeNFC)
        #expect(equalBytes(baseWithNFCExtension.path, baseExtensionNFD))

        let baseWithNFDExtension = baseURL.appendingPathExtension(relativeNFD)
        #expect(equalBytes(baseWithNFDExtension.path, baseExtensionNFD))
        #expect(baseWithNFCExtension == baseWithNFDExtension)

        // None of these conversions apply for initializing or appending to non-file URLs
        let httpBase = try #require(URL(string: "https://example.com/"))
        let httpRelativeNFC = try #require(URL(string: relativeNFC, relativeTo: httpBase))
        let httpRelativeNFD = try #require(URL(string: relativeNFD, relativeTo: httpBase))
        let httpWithNFCComponent = httpBase.appending(path: relativeNFC)
        let httpWithNFDComponent = httpBase.appending(path: relativeNFD)

        #expect(equalBytes(httpRelativeNFC.path, pathNFC))
        #expect(equalBytes(httpRelativeNFD.path, pathNFD))
        #expect(httpRelativeNFC != httpRelativeNFD)

        #expect(equalBytes(httpWithNFCComponent.path, pathNFC))
        #expect(equalBytes(httpWithNFDComponent.path, pathNFD))
        #expect(httpWithNFCComponent != httpWithNFDComponent)

        // Except when we explicitly get the file system representation
        try httpRelativeNFC.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        try httpRelativeNFD.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        try httpWithNFCComponent.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }

        try httpWithNFDComponent.withUnsafeFileSystemRepresentation { fsRep in
            let fsRep = try #require(fsRep)
            #expect(equalBytes(fsRep, pathNFD))
        }
    }
    #endif

    #if os(Windows)
    @Test func windowsDriveLetterPath() throws {
        var url = URL(filePath: #"C:\test\path"#, directoryHint: .notDirectory)
        // .absoluteString and .path() use the RFC 8089 URL path
        #expect(url.absoluteString == "file:///C:/test/path")
        #expect(url.path() == "/C:/test/path")
        // .path and .fileSystemPath() strip the leading slash
        #expect(url.path == "C:/test/path")
        #expect(url.fileSystemPath() == "C:/test/path")

        url = URL(filePath: #"C:\"#, directoryHint: .isDirectory)
        #expect(url.absoluteString == "file:///C:/")
        #expect(url.path() == "/C:/")
        #expect(url.path == "C:/")
        #expect(url.fileSystemPath() == "C:/")

        url = URL(filePath: #"C:\\\"#, directoryHint: .isDirectory)
        #expect(url.absoluteString == "file:///C:///")
        #expect(url.path() == "/C:///")
        #expect(url.path == "C:/")
        #expect(url.fileSystemPath() == "C:/")

        url = URL(filePath: #"\C:\"#, directoryHint: .isDirectory)
        #expect(url.absoluteString == "file:///C:/")
        #expect(url.path() == "/C:/")
        #expect(url.path == "C:/")
        #expect(url.fileSystemPath() == "C:/")

        let base = URL(filePath: #"\d:\path\"#, directoryHint: .isDirectory)
        url = URL(filePath: #"%43:\fake\letter"#, directoryHint: .notDirectory, relativeTo: base)
        // ":" is encoded to "%3A" in the first path segment so it's not mistaken as the scheme separator
        #expect(url.relativeString == "%2543%3A/fake/letter")
        #expect(url.path() == "/d:/path/%2543%3A/fake/letter")
        #expect(url.path == "d:/path/%43:/fake/letter")
        #expect(url.fileSystemPath() == "d:/path/%43:/fake/letter")

        let cwd = URL.currentDirectory()
        var iter = cwd.path().utf8.makeIterator()
        if iter.next() == ._slash,
           let driveLetter = iter.next(), driveLetter.isLetter!,
           iter.next() == ._colon {
            let path = #"\\?\"# + "\(Unicode.Scalar(driveLetter))" + #":\"#
            url = URL(filePath: path, directoryHint: .isDirectory)
            #expect(url.path.last == "/")
            #expect(url.fileSystemPath().last == "/")
        }
    }
    #endif

    @Test func relativeDotDotResolution() throws {
        let baseURL = URL(filePath: "/docs/src/")
        var result = URL(filePath: "../images/foo.png", relativeTo: baseURL)
        #expect(result.path == "/docs/images/foo.png")

        result = URL(filePath: "/../images/foo.png", relativeTo: baseURL)
        #expect(result.path == "/../images/foo.png")
    }

    @Test func appendFamily() throws {
        let base = URL(string: "https://www.example.com")!

        // Appending path
        #expect(
            base.appending(path: "/api/v2").absoluteString ==
            "https://www.example.com/api/v2"
        )
        var testAppendPath = base
        testAppendPath.append(path: "/api/v3")
        #expect(
            testAppendPath.absoluteString ==
            "https://www.example.com/api/v3"
        )

        // Appending component
        #expect(
            base.appending(component: "AC/DC").absoluteString ==
            "https://www.example.com/AC%2FDC"
        )
        var testAppendComponent = base
        testAppendComponent.append(component: "AC/DC")
        #expect(
            testAppendComponent.absoluteString ==
            "https://www.example.com/AC%2FDC"
        )

        // Append queryItems
        let queryItems = [
            URLQueryItem(name: "id", value: "42"),
            URLQueryItem(name: "color", value: "blue")
        ]
        #expect(
            base.appending(queryItems: queryItems).absoluteString ==
            "https://www.example.com?id=42&color=blue"
        )
        var testAppendQueryItems = base
        testAppendQueryItems.append(queryItems: queryItems)
        #expect(
            testAppendQueryItems.absoluteString ==
            "https://www.example.com?id=42&color=blue"
        )

        // Appending components
        #expect(
            base.appending(components: "api", "artist", "AC/DC").absoluteString ==
            "https://www.example.com/api/artist/AC%2FDC"
        )
        var testAppendComponents = base
        testAppendComponents.append(components: "api", "artist", "AC/DC")
        #expect(
            testAppendComponents.absoluteString ==
            "https://www.example.com/api/artist/AC%2FDC"
        )

        // Chaining various appends
        let chained = base
            .appending(path: "api/v2")
            .appending(queryItems: [
                URLQueryItem(name: "magic", value: "42"),
                URLQueryItem(name: "color", value: "blue")
            ])
            .appending(components: "get", "products")
        #expect(
            chained.absoluteString ==
            "https://www.example.com/api/v2/get/products?magic=42&color=blue"
        )
    }

    @Test func appendFamilyDirectoryHint() throws {
        // Make sure directoryHint values are propagated correctly
        let base = URL(string: "file:///var/mobile")!

        // Appending path
        var url = base.appending(path: "/folder/item", directoryHint: .isDirectory)
        #expect(url.hasDirectoryPath)

        url = base.appending(path: "folder/item", directoryHint: .notDirectory)
        #expect(!url.hasDirectoryPath)

        url = base.appending(path: "/folder/item.framework/")
        #expect(url.hasDirectoryPath)

        url = base.appending(path: "/folder/item")
        #expect(!url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(path: "/folder/item", directoryHint: .checkFileSystem)
        }

        // Appending component
        url = base.appending(component: "AC/DC", directoryHint: .isDirectory)
        #expect(url.hasDirectoryPath)

        url = base.appending(component: "AC/DC", directoryHint: .notDirectory)
        #expect(!url.hasDirectoryPath)

        url = base.appending(component: "AC/DC/", directoryHint: .isDirectory)
        #expect(url.hasDirectoryPath)

        url = base.appending(component: "AC/DC")
        #expect(!url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(component: "AC/DC", directoryHint: .checkFileSystem)
        }

        // Appending components
        url = base.appending(components: "api", "v2", "AC/DC", directoryHint: .isDirectory)
        #expect(url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC", directoryHint: .notDirectory)
        #expect(!url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC/", directoryHint: .isDirectory)
        #expect(url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC")
        #expect(!url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(components: "api", "v2", "AC/DC", directoryHint: .checkFileSystem)
        }
    }

    private func runDirectoryHintCheckFilesystemTest(_ builder: (URL) -> URL) throws {
        let tempDirectory = URL.temporaryDirectory
        // We should not have directory path before it's created
        #expect(!builder(tempDirectory).hasDirectoryPath)
        // Create the folder
        try FileManager.default.createDirectory(
            at: builder(tempDirectory),
            withIntermediateDirectories: true
        )
        #expect(builder(tempDirectory).hasDirectoryPath)
        try FileManager.default.removeItem(at: builder(tempDirectory))
    }

    @Test(arguments: [
        " ",
        "path space",
        "/absolute path space",
        "scheme:path space",
        "scheme://host/path space",
        "scheme://host/path space?query space#fragment space",
        "scheme://user space:pass space@host/",
        "unsafe\"<>%{}\\|^~[]`##",
        "http://example.com/unsafe\"<>%{}\\|^~[]`##",
        "mailto:\"Your Name\" <you@example.com>",
        "[This is not a valid URL without encoding.]",
        "Encoding a relative path! 😎",
    ])
    func encodingInvalidCharacters(urlString: String) throws {
        var url = URL(string: urlString, encodingInvalidCharacters: true)
        #expect(url != nil, "Expected a percent-encoded url for string \(urlString)")
        url = URL(string: urlString, encodingInvalidCharacters: false)
        #expect(url == nil, "Expected to fail strict url parsing for string \(urlString)")
    }

    @Test func appendingPathDoesNotEncodeColon() throws {
        let baseURL = URL(string: "file:///var/mobile/")!
        let url = URL(string: "relative", relativeTo: baseURL)!
        let component = "no:slash"
        let slashComponent = "/with:slash"

        // Make sure we don't encode ":" since `component` is not the first path segment
        var appended = url.appending(path: component, directoryHint: .notDirectory)
        #expect(appended.absoluteString == "file:///var/mobile/relative/no:slash")
        #expect(appended.relativePath == "relative/no:slash")

        appended = url.appending(path: slashComponent, directoryHint: .notDirectory)
        #expect(appended.absoluteString == "file:///var/mobile/relative/with:slash")
        #expect(appended.relativePath == "relative/with:slash")

        appended = url.appending(component: component, directoryHint: .notDirectory)
        #expect(appended.absoluteString == "file:///var/mobile/relative/no:slash")
        #expect(appended.relativePath == "relative/no:slash")

        // .appending(component:) should explicitly treat slashComponent as a single
        // path component, meaning "/" should be encoded to "%2F" before appending.
        // However, the old behavior didn't do this for file URLs, so we maintain the
        // old behavior to prevent breakage.
        appended = url.appending(component: slashComponent, directoryHint: .notDirectory)
        #expect(appended.absoluteString == "file:///var/mobile/relative/with:slash")
        #expect(appended.relativePath == "relative/with:slash")

        appended = url.appendingPathComponent(component, isDirectory: false)
        #expect(appended.absoluteString == "file:///var/mobile/relative/no:slash")
        #expect(appended.relativePath == "relative/no:slash")

        // Test deprecated API, which acts like `appending(path:)`
        appended = url.appendingPathComponent(slashComponent, isDirectory: false)
        #expect(appended.absoluteString == "file:///var/mobile/relative/with:slash")
        #expect(appended.relativePath == "relative/with:slash")
    }

    @Test func deletingLastPathComponent() throws {
        var absolute = URL(filePath: "/absolute/path", directoryHint: .notDirectory)
        // Note: .relativePath strips the trailing slash for compatibility
        #expect(absolute.relativePath == "/absolute/path")
        #expect(!absolute.hasDirectoryPath)

        absolute.deleteLastPathComponent()
        #expect(absolute.relativePath == "/absolute")
        #expect(absolute.hasDirectoryPath)

        absolute.deleteLastPathComponent()
        #expect(absolute.relativePath == "/")
        #expect(absolute.hasDirectoryPath)

        // The old .deleteLastPathComponent() implementation appends ".." to the
        // root directory "/", resulting in "/../". This resolves back to "/".
        // The new implementation simply leaves "/" as-is.
        absolute.deleteLastPathComponent()
        checkBehavior(absolute.relativePath, new: "/", old: "/..")
        #expect(absolute.hasDirectoryPath)

        absolute.append(path: "absolute", directoryHint: .isDirectory)
        checkBehavior(absolute.path, new: "/absolute", old: "/../absolute")

        // Reset `var absolute` to "/absolute" to prevent having
        // a "/../" prefix in all the old expectations.
        absolute = URL(filePath: "/absolute", directoryHint: .isDirectory)

        var relative = URL(filePath: "relative/path", directoryHint: .notDirectory, relativeTo: absolute)
        #expect(relative.relativePath == "relative/path")
        #expect(!relative.hasDirectoryPath)
        #expect(relative.path == "/absolute/relative/path")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "relative")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute/relative")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == ".")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "..")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "../..")
        #expect(relative.hasDirectoryPath)
        checkBehavior(relative.path, new:"/", old: "/..")

        relative.append(path: "path", directoryHint: .isDirectory)
        #expect(relative.relativePath == "../../path")
        #expect(relative.hasDirectoryPath)
        checkBehavior(relative.path, new: "/path", old: "/../path")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "../..")
        #expect(relative.hasDirectoryPath)
        checkBehavior(relative.path, new: "/", old: "/..")

        relative = URL(filePath: "", relativeTo: absolute)
        #expect(relative.relativePath == ".")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "..")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "../..")
        #expect(relative.hasDirectoryPath)
        checkBehavior(relative.path, new: "/", old: "/..")

        relative = URL(filePath: "relative/./", relativeTo: absolute)
        // According to RFC 3986, "." and ".." segments should not be removed
        // until the path is resolved against the base URL (when calling .path)
        checkBehavior(relative.relativePath, new: "relative/.", old: "relative")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute/relative")

        relative.deleteLastPathComponent()
        checkBehavior(relative.relativePath, new: "relative/..", old: ".")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute")

        relative = URL(filePath: "relative/.", directoryHint: .isDirectory, relativeTo: absolute)
        checkBehavior(relative.relativePath, new: "relative/.", old: "relative")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute/relative")

        relative.deleteLastPathComponent()
        checkBehavior(relative.relativePath, new: "relative/..", old: ".")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute")

        relative = URL(filePath: "relative/..", relativeTo: absolute)
        #expect(relative.relativePath == "relative/..")
        checkBehavior(relative.hasDirectoryPath, new: true, old: false)
        #expect(relative.path == "/absolute")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "relative/../..")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/")

        relative = URL(filePath: "relative/..", directoryHint: .isDirectory, relativeTo: absolute)
        #expect(relative.relativePath == "relative/..")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/absolute")

        relative.deleteLastPathComponent()
        #expect(relative.relativePath == "relative/../..")
        #expect(relative.hasDirectoryPath)
        #expect(relative.path == "/")

        var url = try #require(URL(string: "scheme://host.with.no.path"))
        #expect(url.path().isEmpty)

        url.deleteLastPathComponent()
        #expect(url.absoluteString == "scheme://host.with.no.path")
        #expect(url.path().isEmpty)

        let unusedBase = URL(string: "base://url")
        url = try #require(URL(string: "scheme://host.with.no.path", relativeTo: unusedBase))
        #expect(url.absoluteString == "scheme://host.with.no.path")
        #expect(url.path().isEmpty)

        url.deleteLastPathComponent()
        #expect(url.absoluteString == "scheme://host.with.no.path")
        #expect(url.path().isEmpty)

        var schemeRelative = try #require(URL(string: "scheme:relative/path"))
        // Bug in the old implementation where a relative path is not recognized
        checkBehavior(schemeRelative.relativePath, new: "relative/path", old: "")

        schemeRelative.deleteLastPathComponent()
        checkBehavior(schemeRelative.relativePath, new: "relative", old: "")

        schemeRelative.deleteLastPathComponent()
        #expect(schemeRelative.relativePath == "")

        schemeRelative.deleteLastPathComponent()
        #expect(schemeRelative.relativePath == "")
    }

    @Test func deletingLastPathComponentWithBase() throws {
        let basePath = "/Users/foo-bar/Test1 Test2? Test3/Test4"
        let baseURL = URL(filePath: basePath, directoryHint: .isDirectory)
        let fileURL = URL(filePath: "../Test5.txt", directoryHint: .notDirectory, relativeTo: baseURL)
        #expect(fileURL.path == "/Users/foo-bar/Test1 Test2? Test3/Test5.txt")
        #expect(fileURL.deletingLastPathComponent().path == "/Users/foo-bar/Test1 Test2? Test3")
        #expect(baseURL.deletingLastPathComponent().path == "/Users/foo-bar/Test1 Test2? Test3")
    }

    @Test func filePathDropsTrailingSlashes() throws {
        var url = URL(filePath: "/path/slashes///")
        #expect(url.path() == "/path/slashes///")
        // TODO: Update this once .fileSystemPath uses backslashes for Windows
        #expect(url.fileSystemPath() == "/path/slashes")

        url = URL(filePath: "/path/slashes/")
        #expect(url.path() == "/path/slashes/")
        #expect(url.fileSystemPath() == "/path/slashes")

        url = URL(filePath: "/path/slashes")
        #expect(url.path() == "/path/slashes")
        #expect(url.fileSystemPath() == "/path/slashes")
    }

    @Test func notDirectoryHintStripsTrailingSlash() throws {
        // Supply a path with a trailing slash but say it's not a direcotry
        var url = URL(filePath: "/path/", directoryHint: .notDirectory)
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/path")

        url = URL(fileURLWithPath: "/path/", isDirectory: false)
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/path")

        url = URL(filePath: "/path///", directoryHint: .notDirectory)
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/path")

        url = URL(fileURLWithPath: "/path///", isDirectory: false)
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/path")

        // With .checkFileSystem, don't modify the path for a non-existent file
        url = URL(filePath: "/my/non/existent/path/", directoryHint: .checkFileSystem)
        #expect(url.hasDirectoryPath)
        #expect(url.path() == "/my/non/existent/path/")

        url = URL(fileURLWithPath: "/my/non/existent/path/")
        #expect(url.hasDirectoryPath)
        #expect(url.path() == "/my/non/existent/path/")

        url = URL(filePath: "/my/non/existent/path", directoryHint: .checkFileSystem)
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/my/non/existent/path")

        url = URL(fileURLWithPath: "/my/non/existent/path")
        #expect(!url.hasDirectoryPath)
        #expect(url.path() == "/my/non/existent/path")
    }

    @Test func hostRetainsIDNAEncoding() throws {
        let url = URL(string: "ftp://user:password@*.xn--poema-9qae5a.com.br:4343/cat.txt")!
        #expect(url.host == "*.xn--poema-9qae5a.com.br")
    }

    @Test func hostIPLiteralCompatibility() throws {
        var url = URL(string: "http://[::]")!
        #expect(url.host == "::")
        #expect(url.host() == "::")

        url = URL(string: "https://[::1]:433/")!
        #expect(url.host == "::1")
        #expect(url.host() == "::1")

        url = URL(string: "https://[2001:db8::]/")!
        #expect(url.host == "2001:db8::")
        #expect(url.host() == "2001:db8::")

        url = URL(string: "https://[2001:db8::]:433")!
        #expect(url.host == "2001:db8::")
        #expect(url.host() == "2001:db8::")

        url = URL(string: "http://[fe80::a%25en1]")!
        #expect(url.absoluteString == "http://[fe80::a%25en1]")
        #expect(url.host == "fe80::a%en1")
        #expect(url.host(percentEncoded: true) == "fe80::a%25en1")
        #expect(url.host(percentEncoded: false) == "fe80::a%en1")

        url = URL(string: "http://[fe80::a%en1]")!
        #expect(url.absoluteString == "http://[fe80::a%25en1]")
        #expect(url.host == "fe80::a%en1")
        #expect(url.host(percentEncoded: true) == "fe80::a%25en1")
        #expect(url.host(percentEncoded: false) == "fe80::a%en1")

        url = URL(string: "http://[fe80::a%100%CustomZone]")!
        #expect(url.absoluteString == "http://[fe80::a%25100%25CustomZone]")
        #expect(url.host == "fe80::a%100%CustomZone")
        #expect(url.host(percentEncoded: true) == "fe80::a%25100%25CustomZone")
        #expect(url.host(percentEncoded: false) == "fe80::a%100%CustomZone")

        // Make sure an IP-literal with invalid characters `{` and `}`
        // returns `nil` even if we can percent-encode the zone-ID.
        let invalid = URL(string: "http://[{Invalid}%100%EncodableZone]")
        #expect(invalid == nil)
    }

    #if !os(Windows)
    @Test func tildeFilePath() throws {
        func isAbsolute(_ url: URL) -> Bool {
            url.relativePath.utf8.first == ._slash && url.baseURL == nil
        }

        func isRelative(_ url: URL) -> Bool {
            url.relativePath.utf8.first != ._slash && url.baseURL != nil
        }

        // Treat a lone "~" as a potential file name
        var url = URL(filePath: "~")
        #expect(isRelative(url))
        #expect(url.lastPathComponent == "~")

        // Expand the tilde for a "~/" prefix
        url = URL(filePath: "~/")
        #expect(isAbsolute(url))
        #expect(url.hasDirectoryPath)

        url = URL(filePath: "~/Desktop/")
        #expect(isAbsolute(url))
        #expect(url.hasDirectoryPath)
        #expect(url.lastPathComponent == "Desktop")

        // Don't expand the tilde for any "~user"-like prefix
        url = URL(filePath: "~user")
        #expect(isRelative(url))
        #expect(url.lastPathComponent == "~user")

        url = URL(filePath: "~mobile")
        #expect(isRelative(url))
        #expect(url.lastPathComponent == "~mobile")

        url = URL(filePath: "~mobile/path")
        #expect(isRelative(url))
        #expect(url.lastPathComponent == "path")
    }
    #endif // !os(Windows)

    @Test func pathExtensions() throws {
        var url = URL(filePath: "/path", directoryHint: .notDirectory)
        url.appendPathExtension("foo")
        #expect(url.path() == "/path.foo")
        url.deletePathExtension()
        #expect(url.path() == "/path")

        url = URL(filePath: "/path", directoryHint: .isDirectory)
        url.appendPathExtension("foo")
        #expect(url.path() == "/path.foo/")
        url.deletePathExtension()
        #expect(url.path() == "/path/")

        url = URL(filePath: "/path/", directoryHint: .inferFromPath)
        url.appendPathExtension("foo")
        #expect(url.path() == "/path.foo/")
        url.append(path: "/////")
        url.deletePathExtension()
        // Old behavior only searches the last empty component, so the extension isn't actually removed
        checkBehavior(url.path(), new: "/path/", old: "/path.foo///")

        url = URL(filePath: "/tmp/x")
        url.appendPathExtension("")
        #expect(url.path() == "/tmp/x")
        #expect(url == url.deletingPathExtension().appendingPathExtension(url.pathExtension))

        url = URL(filePath: "/tmp/x.")
        url.deletePathExtension()
        #expect(url.path() == "/tmp/x.")
    }

    @Test func appendingToEmptyPath() throws {
        let baseURL = URL(filePath: "/base/directory", directoryHint: .isDirectory)
        let emptyPathURL = URL(filePath: "", relativeTo: baseURL)
        let url = emptyPathURL.appending(path: "main.swift")
        #expect(url.relativePath == "./main.swift")
        #expect(url.path == "/base/directory/main.swift")

        var example = try #require(URL(string: "https://example.com"))
        #expect(example.host() == "example.com")
        #expect(example.path().isEmpty)

        // Appending to an empty path should add a slash if an authority exists
        // The appended path should never become part of the host
        example.append(path: "foo")
        #expect(example.host() == "example.com")
        #expect(example.path() == "/foo")
        #expect(example.absoluteString == "https://example.com/foo")

        // Maintain old behavior, where appending an empty path
        // to an empty host does not add a slash, but appending
        // an empty path to a non-empty host does
        example = try #require(URL(string: "https://example.com"))
        example.append(path: "")
        #expect(example.host() == "example.com")
        #expect(example.path() == "/")
        #expect(example.absoluteString == "https://example.com/")

        var emptyHost = try #require(URL(string: "scheme://"))
        #expect(emptyHost.host() == nil)
        #expect(emptyHost.path().isEmpty)

        emptyHost.append(path: "")
        #expect(emptyHost.host() == nil)
        #expect(emptyHost.path().isEmpty)

        emptyHost.append(path: "foo")
        #expect(emptyHost.host()?.isEmpty ?? true)
        // Old behavior failed to append correctly to an empty host
        // Modern parsers agree that "foo" relative to "scheme://" is "scheme:///foo"
        checkBehavior(emptyHost.path(), new: "/foo", old: "")
        checkBehavior(emptyHost.absoluteString, new: "scheme:///foo", old: "scheme://")

        var schemeOnly = try #require(URL(string: "scheme:"))
        #expect(schemeOnly.host()?.isEmpty ?? true)
        #expect(schemeOnly.path().isEmpty)

        schemeOnly.append(path: "foo")
        #expect(schemeOnly.host()?.isEmpty ?? true)
        // Old behavior appends to the string, but is missing the path
        checkBehavior(schemeOnly.path(), new: "foo", old: "")
        #expect(schemeOnly.absoluteString == "scheme:foo")
    }

    @Test func emptySchemeCompatibility() throws {
        var url = try #require(URL(string: ":memory:"))
        #expect(url.scheme == "")

        let base = try #require(URL(string: "://home"))
        #expect(base.host() == "home")

        url = try #require(URL(string: "/path", relativeTo: base))
        #expect(url.scheme == "")
        #expect(url.host() == "home")
        #expect(url.path == "/path")
        #expect(url.absoluteString == "://home/path")
        #expect(url.absoluteURL.scheme == "")
    }

    @Test func componentsPercentEncodedUnencodedProperties() throws {
        var comp = URLComponents()

        comp.user = "%25"
        #expect(comp.user == "%25")
        #expect(comp.percentEncodedUser == "%2525")

        comp.password = "%25"
        #expect(comp.password == "%25")
        #expect(comp.percentEncodedPassword == "%2525")

        // Host behavior differs since the addition of IDNA-encoding
        comp.host = "%25"
        #expect(comp.host == "%")
        #expect(comp.percentEncodedHost == "%25")

        comp.path = "%25"
        #expect(comp.path == "%25")
        #expect(comp.percentEncodedPath == "%2525")

        comp.query = "%25"
        #expect(comp.query == "%25")
        #expect(comp.percentEncodedQuery == "%2525")

        comp.fragment = "%25"
        #expect(comp.fragment == "%25")
        #expect(comp.percentEncodedFragment == "%2525")

        comp.queryItems = [URLQueryItem(name: "name", value: "a%25b")]
        #expect(comp.queryItems == [URLQueryItem(name: "name", value: "a%25b")])
        #expect(comp.percentEncodedQueryItems == [URLQueryItem(name: "name", value: "a%2525b")])
        #expect(comp.query == "name=a%25b")
        #expect(comp.percentEncodedQuery == "name=a%2525b")
    }

    @Test func percentEncodedProperties() throws {
        var url = URL(string: "https://%3Auser:%3Apassword@%3A.com/%3Apath?%3Aquery=%3A#%3Afragment")!

        #expect(url.user() == "%3Auser")
        #expect(url.user(percentEncoded: false) == ":user")

        #expect(url.password() == "%3Apassword")
        #expect(url.password(percentEncoded: false) == ":password")

        #expect(url.host() == "%3A.com")
        #expect(url.host(percentEncoded: false) == ":.com")

        #expect(url.path() == "/%3Apath")
        #expect(url.path(percentEncoded: false) == "/:path")

        #expect(url.query() == "%3Aquery=%3A")
        #expect(url.query(percentEncoded: false) == ":query=:")

        #expect(url.fragment() == "%3Afragment")
        #expect(url.fragment(percentEncoded: false) == ":fragment")

        // Lowercase input
        url = URL(string: "https://%3auser:%3apassword@%3a.com/%3apath?%3aquery=%3a#%3afragment")!

        #expect(url.user() == "%3auser")
        #expect(url.user(percentEncoded: false) == ":user")

        #expect(url.password() == "%3apassword")
        #expect(url.password(percentEncoded: false) == ":password")

        #expect(url.host() == "%3a.com")
        #expect(url.host(percentEncoded: false) == ":.com")

        #expect(url.path() == "/%3apath")
        #expect(url.path(percentEncoded: false) == "/:path")

        #expect(url.query() == "%3aquery=%3a")
        #expect(url.query(percentEncoded: false) == ":query=:")

        #expect(url.fragment() == "%3afragment")
        #expect(url.fragment(percentEncoded: false) == ":fragment")
    }

    @Test func componentsUppercasePercentEncoding() throws {
        // Always use uppercase percent-encoding when unencoded components are assigned
        var comp = URLComponents()
        comp.scheme = "https"
        comp.user = "?user"
        comp.password = "?password"
        comp.path = "?path"
        comp.query = "#query"
        comp.fragment = "#fragment"
        #expect(comp.percentEncodedUser == "%3Fuser")
        #expect(comp.percentEncodedPassword == "%3Fpassword")
        #expect(comp.percentEncodedPath == "%3Fpath")
        #expect(comp.percentEncodedQuery == "%23query")
        #expect(comp.percentEncodedFragment == "%23fragment")
    }
    
    // This brute forces many combinations and takes a long time.
    @Test(.disabled("Disabled in automated testing - enable manually when needed"))
    func componentsRangeCombinations() throws {
        let schemes = [nil, "a", "aa"]
        let users = [nil, "b", "bb"]
        let passwords = [nil, "c", "cc"]
        let hosts = [nil, "d", "dd"]
        let ports = [nil, 80, 433]
        let paths = ["", "/e", "/e/e"]
        let queries = [nil, "f=f", "hh=hh"]
        let fragments = [nil, "j", "jj"]

        func forAll(_ block: (String?, String?, String?, String?, Int?, String, String?, String?) throws -> ()) rethrows {
            for scheme in schemes {
                for user in users {
                    for password in passwords {
                        for host in hosts {
                            for port in ports {
                                for path in paths {
                                    for query in queries {
                                        for fragment in fragments {
                                            try block(scheme, user, password, host, port, path, query, fragment)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        func validateRanges(_ comp: URLComponents, scheme: String?, user: String?, password: String?, host: String?, port: Int?, path: String, query: String?, fragment: String?) throws {
            let string = try #require(comp.string)
            if let scheme {
                let range = try #require(comp.rangeOfScheme)
                #expect(string[range] == scheme)
            } else {
                #expect(comp.rangeOfScheme == nil)
            }
            if let user {
                let range = try #require(comp.rangeOfUser)
                #expect(string[range] == user)
            } else {
                // Even if we set comp.user = nil, a non-nil password
                // implies that user exists as the empty string.
                let isEmptyUserWithPassword = (
                    comp.user?.isEmpty ?? false &&
                    comp.rangeOfUser?.isEmpty ?? false &&
                    comp.password != nil
                )
                #expect(comp.rangeOfUser == nil || isEmptyUserWithPassword)
            }
            if let password {
                let range = try #require(comp.rangeOfPassword)
                #expect(string[range] == password)
            } else {
                #expect(comp.rangeOfPassword == nil)
            }
            if let host {
                let range = try #require(comp.rangeOfHost)
                #expect(string[range] == host)
            } else {
                // Even if we set comp.host = nil, any non-nil authority component
                // implies that host exists as the empty string.
                let isEmptyHostWithAuthorityComponent = (
                    comp.host?.isEmpty ?? false &&
                    comp.rangeOfHost?.isEmpty ?? false &&
                    (user != nil || password != nil || port != nil)
                )
                #expect(comp.rangeOfHost == nil || isEmptyHostWithAuthorityComponent)
            }
            if let port {
                let range = try #require(comp.rangeOfPort)
                #expect(string[range] == String(port))
            } else {
                #expect(comp.rangeOfPort == nil)
            }
            // rangeOfPath should never be nil.
            let pathRange = try #require(comp.rangeOfPath)
            #expect(string[pathRange] == path)
            if let query {
                let range = try #require(comp.rangeOfQuery)
                #expect(string[range] == query)
            } else {
                #expect(comp.rangeOfQuery == nil)
            }
            if let fragment {
                let range = try #require(comp.rangeOfFragment)
                #expect(string[range] == fragment)
            } else {
                #expect(comp.rangeOfFragment == nil)
            }
        }

        try forAll { scheme, user, password, host, port, path, query, fragment in

            // Assign all components then get the ranges

            var comp = URLComponents()
            comp.scheme = scheme
            comp.user = user
            comp.password = password
            comp.host = host
            comp.port = port
            comp.path = path
            comp.query = query
            comp.fragment = fragment
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            let string = try #require(comp.string)
            let fullComponents = try #require(URLComponents(string: string))

            // Get the ranges directly from URLParseInfo

            comp = fullComponents
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            // Set components after parsing, which invalidates the URLParseInfo ranges

            comp = fullComponents
            comp.scheme = scheme
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.user = user
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.password = password
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.host = host
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.port = port
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.path = path
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.query = query
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.fragment = fragment
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            // Remove components from the string, set them back, and validate ranges

            comp = fullComponents
            comp.scheme = nil
            try validateRanges(comp, scheme: nil, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            let stringWithoutScheme = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutScheme))
            comp.scheme = scheme
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            var expectedHost = host
            if user != nil && host == nil {
                // We parsed a string with a non-nil user, so expect host to
                // be the empty string, even after we set comp.user = nil.
                expectedHost = ""
            }
            comp.user = nil
            try validateRanges(comp, scheme: scheme, user: nil, password: password, host: expectedHost, port: port, path: path, query: query, fragment: fragment)

            let stringWithoutUser = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutUser))
            comp.user = user
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            var expectedUser = user
            if password != nil && user == nil {
                // We parsed a string with a non-nil password, so expect user to
                // be the empty string, even after we set comp.password = nil.
                expectedUser = ""
            }
            comp.password = nil
            try validateRanges(comp, scheme: scheme, user: expectedUser, password: nil, host: host, port: port, path: path, query: query, fragment: fragment)

            let stringWithoutPassword = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutPassword))
            comp.password = password
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.host = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: nil, port: port, path: path, query: query, fragment: fragment)

            let stringWithoutHost = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutHost))
            comp.host = host
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            expectedHost = host
            if port != nil && host == nil {
                // We parsed a string with a non-nil port, so expect host to
                // be the empty string, even after we set comp.port = nil.
                expectedHost = ""
            }
            comp.port = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: expectedHost, port: nil, path: path, query: query, fragment: fragment)

            let stringWithoutPort = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutPort))
            comp.port = port
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.path = ""
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: "", query: query, fragment: fragment)

            let stringWithoutPath = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutPath))
            comp.path = path
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.query = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: nil, fragment: fragment)

            let stringWithoutQuery = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutQuery))
            comp.query = query
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.fragment = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: nil)

            let stringWithoutFragment = try #require(comp.string)
            comp = try #require(URLComponents(string: stringWithoutFragment))
            comp.fragment = fragment
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        }
    }

    @Test func componentsEncodesFirstPathColon() throws {
        let path = "first:segment:with:colons/second:segment:with:colons"
        var comp = URLComponents()
        comp.path = path
        let compString = try #require(comp.string)
        let slashIndex = try #require(compString.firstIndex(of: "/"))
        let firstSegment = compString[..<slashIndex]
        let secondSegment = compString[slashIndex...]
        #expect(firstSegment.firstIndex(of: ":") == nil, "There should not be colons in the first path segment")
        #expect(secondSegment.firstIndex(of: ":") != nil, "Colons should be allowed in subsequent path segments")

        comp = URLComponents()
        comp.path = path
        let compString2 = try #require(comp.string)
        let slashIndex2 = try #require(compString2.firstIndex(of: "/"))
        let firstSegment2 = compString2[..<slashIndex2]
        let secondSegment2 = compString2[slashIndex2...]
        #expect(firstSegment2.firstIndex(of: ":") == nil, "There should not be colons in the first path segment")
        #expect(secondSegment2.firstIndex(of: ":") != nil, "Colons should be allowed in subsequent path segments")

        // Colons are allowed in the first segment if there is a scheme.

        let colonFirstPath = "playlist:37i9dQZF1E35u89RYOJJV6"
        let legalURLString = "spotify:\(colonFirstPath)"
        comp = try #require(URLComponents(string: legalURLString))
        #expect(comp.string == legalURLString)
        #expect(comp.percentEncodedPath == colonFirstPath)

        // Colons should be percent-encoded by URLComponents.string if
        // they could be misinterpreted as a scheme separator.

        comp = URLComponents()
        comp.percentEncodedPath = "not%20a%20scheme:"
        #expect(comp.string == "not%20a%20scheme%3A")

        // These would fail if we did not percent-encode the colon.
        // .string should always produce a valid URL string, or nil.

        #expect(URL(string: comp.string!) != nil)
        #expect(URLComponents(string: comp.string!) != nil)

        // In rare cases, an app might rely on URL allowing an empty scheme,
        // but then take that string and pass it to URLComponents to modify
        // other components of the URL. We shouldn't percent-encode the colon
        // in these cases.

        let url = try #require(URL(string: "://host/path"))
        comp = try #require(URLComponents(string: url.absoluteString))
        comp.query = "key=value"
        #expect(comp.string == "://host/path?key=value")
    }

    @Test func componentsInvalidPaths() {
        var comp = URLComponents()

        // Path must start with a slash if there's an authority component.
        comp.path = "does/not/start/with/slash"
        #expect(comp.string != nil)

        comp.user = "user"
        #expect(comp.string == nil)
        comp.user = nil

        comp.password = "password"
        #expect(comp.string == nil)
        comp.password = nil

        comp.host = "example.com"
        #expect(comp.string == nil)
        comp.host = nil

        comp.port = 80
        #expect(comp.string == nil)
        comp.port = nil

        comp = URLComponents()

        // If there's no authority, path cannot start with "//".
        comp.path = "//starts/with/two/slashes"
        #expect(comp.string == nil)

        // If there's an authority, it's okay.
        comp.user = "user"
        #expect(comp.string != nil)
        comp.user = nil

        comp.password = "password"
        #expect(comp.string != nil)
        comp.password = nil

        comp.host = "example.com"
        #expect(comp.string != nil)
        comp.host = nil

        comp.port = 80
        #expect(comp.string != nil)
        comp.port = nil
    }

    @Test func componentsAllowsEqualSignInQueryItemValue() {
        var comp = URLComponents(string: "http://example.com/path?item=value==&q==val")!
        var expected = [URLQueryItem(name: "item", value: "value=="), URLQueryItem(name: "q", value: "=val")]
        #expect(comp.percentEncodedQueryItems == expected)
        #expect(comp.queryItems == expected)

        expected = [URLQueryItem(name: "new", value: "=value="), URLQueryItem(name: "name", value: "=")]
        comp.percentEncodedQueryItems = expected
        #expect(comp.percentEncodedQueryItems == expected)
        #expect(comp.queryItems == expected)
    }

    @Test func componentsLookalikeIPLiteral() {
        // We should consider a lookalike IP literal invalid (note accent on the first bracket)
        let fakeIPLiteral = "[́::1]"
        let fakeURLString = "http://\(fakeIPLiteral):80/"

        let comp = URLComponents(string: fakeURLString)
        #expect(comp == nil)

        var comp2 = URLComponents()
        comp2.host = fakeIPLiteral
        #expect(comp2.string == nil)
    }

    @Test func componentsDecodingNULL() {
        let comp = URLComponents(string: "http://example.com/my\u{0}path")!
        #expect(comp.percentEncodedPath == "/my%00path")
        #expect(comp.path == "/my\u{0}path")
    }

    @Test func standardizedEmptyString() {
        let url = URL(string: "../../../")!
        let standardized = url.standardized
        #expect(standardized.path().isEmpty)
    }

#if FOUNDATION_FRAMEWORK
    @Test func componentsBridging() {
        var nsURLComponents = NSURLComponents(
            string: "https://example.com?url=https%3A%2F%2Fapple.com"
        )!
        var urlComponents = nsURLComponents as URLComponents
        #expect(urlComponents.string == nsURLComponents.string)

        urlComponents = URLComponents(
            string: "https://example.com?url=https%3A%2F%2Fapple.com"
        )!
        nsURLComponents = urlComponents as NSURLComponents
        #expect(urlComponents.string == nsURLComponents.string)
    }
#endif
    
    @Test func filePathRelativeToBase() async throws {
        try await FilePlayground {
            Directory("dir") {
                "Foo"
                "Bar"
            }
        }.test {
            let currentDirectoryPath = $0.currentDirectoryPath
            let baseURL = URL(filePath: currentDirectoryPath, directoryHint: .isDirectory)
            let relativePath = "dir"

            let url1 = URL(filePath: relativePath, directoryHint: .isDirectory, relativeTo: baseURL)

            let url2 = URL(filePath: relativePath, directoryHint: .checkFileSystem, relativeTo: baseURL)
            #expect(url1 == url2)

            // directoryHint is `.inferFromPath` by default
            let url3 = URL(filePath: relativePath + "/", relativeTo: baseURL)
            #expect(url1 == url3)
        }
    }

    @Test func filePathDoesNotFollowLastSymlink() async throws {
        try await FilePlayground {
            Directory("dir") {
                "Foo"
                SymbolicLink("symlink", destination: "../dir")
            }
        }.test {
            let currentDirectoryPath = $0.currentDirectoryPath
            let baseURL = URL(filePath: currentDirectoryPath, directoryHint: .isDirectory)

            let dirURL = baseURL.appending(path: "dir", directoryHint: .checkFileSystem)
            #expect(dirURL.hasDirectoryPath)

            var symlinkURL = dirURL.appending(path: "symlink", directoryHint: .notDirectory)

            // FileManager uses stat(), which will follow the symlink to the directory.

            #if FOUNDATION_FRAMEWORK
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: symlinkURL.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
            #else
            var isDirectory = false
            #expect(FileManager.default.fileExists(atPath: symlinkURL.path, isDirectory: &isDirectory))
            #expect(isDirectory)
            #endif

            // URL uses lstat(), which will not follow the symlink at the end of the path.
            // Check that URL(filePath:) and .appending(path:) preserve this behavior.

            symlinkURL = URL(filePath: symlinkURL.path, directoryHint: .checkFileSystem)
            #expect(!symlinkURL.hasDirectoryPath)

            symlinkURL = dirURL.appending(path: "symlink", directoryHint: .checkFileSystem)
            #expect(!symlinkURL.hasDirectoryPath)
        }
    }
}
