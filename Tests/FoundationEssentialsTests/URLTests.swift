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
#elseif FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

private func combinations<C1: Collection, C2: Collection, C3: Collection>(_ c1: C1, _ c2: C2, _ c3: C3) -> some Collection<(C1.Element, C2.Element, C3.Element)> & Sendable where C1.Element: Sendable, C2.Element: Sendable, C3.Element: Sendable {
    c1.lazy.flatMap { a in
        c2.lazy.flatMap { b in
            c3.lazy.map { c in
                (a, b, c)
            }
        }
    }
}

struct URLTests {
    static var foundationFrameworkNSURL: Bool {
        #if FOUNDATION_FRAMEWORK_NSURL
        true
        #else
        false
        #endif
    }

    @Test func testURLBasics() throws {
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
        #if !FOUNDATION_FRAMEWORK_NSURL
        #expect(relativeURLWithBase.path() == "/base/relative/path")
        #else
        #expect(relativeURLWithBase.path() == "relative/path")
        #endif
        #expect(relativeURLWithBase.relativePath == "relative/path")
        #expect(relativeURLWithBase.query() == "query")
        #expect(relativeURLWithBase.fragment() == "fragment")
        #expect(relativeURLWithBase.absoluteString == "https://user:pass@base.example.com:8080/base/relative/path?query#fragment")
        #expect(relativeURLWithBase.absoluteURL == URL(string: "https://user:pass@base.example.com:8080/base/relative/path?query#fragment"))
        #expect(relativeURLWithBase.relativeString == relativeString)
        #expect(relativeURLWithBase.baseURL == baseURL)
    }

    @Test func testURLResolvingAgainstBase() throws {
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

        #if FOUNDATION_FRAMEWORK_NSURL
        let testsFailingWithoutSwiftURL = Set([
            "",
            "../../../g",
            "../../../../g",
            "/./g",
            "/../g",
        ])
        #endif

        for test in tests {
            #if FOUNDATION_FRAMEWORK_NSURL
            if testsFailingWithoutSwiftURL.contains(test.key) {
                continue
            }
            #endif

            let url = URL(string: test.key, relativeTo: base)
            #expect(url?.absoluteString == test.value, "Failed test for string: \(test.key)")
        }
    }

    @Test(.disabled(if: foundationFrameworkNSURL))
    func testURLPathAPIsResolveAgainstBase() throws {
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
            let url = URL(string: test.key, relativeTo: base)!
            #expect(url.path() == test.value)
            if (url.hasDirectoryPath && url.path().count > 1) {
                // The trailing slash is stripped in .path for file system compatibility
                #expect(String(url.path().dropLast()) == url.path)
            } else {
                #expect(url.path() == url.path)
            }
        }
    }

    @Test(.disabled(if: foundationFrameworkNSURL))
    func testURLPathComponentsPercentEncodedSlash() throws {
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

    @Test(
        .disabled(if: foundationFrameworkNSURL),
        arguments: combinations(["", "path"], [nil, "query"], [nil, "fragment"])
    )
    func testURLRootlessPath(path: String, query: String?, fragment: String?) throws {
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

    @Test func testURLNonSequentialIPLiteralAndPort() {
        let urlString = "https://[fe80::3221:5634:6544]invalid:433/"
        let url = URL(string: urlString)
        #expect(url == nil)
    }

    @Test func testURLFilePathInitializer() throws {
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

    @Test func testURLRelativeDotDotResolution() throws {
        let baseURL = URL(filePath: "/docs/src/")
        var result = URL(filePath: "../images/foo.png", relativeTo: baseURL)
        #if FOUNDATION_FRAMEWORK_NSURL
        #expect(result.path == "/docs/images/foo.png")
        #else
        #expect(result.path() == "/docs/images/foo.png")
        #endif

        result = URL(filePath: "/../images/foo.png", relativeTo: baseURL)
        #if FOUNDATION_FRAMEWORK_NSURL
        #expect(result.path == "/../images/foo.png")
        #else
        #expect(result.path() == "/../images/foo.png")
        #endif
    }

    @Test func testAppendFamily() throws {
        let base = URL(string: "https://www.example.com")!

        // Appending path
        #expect(
            base.appending(path: "/api/v2").absoluteString == "https://www.example.com/api/v2"
        )
        var testAppendPath = base
        testAppendPath.append(path: "/api/v3")
        #expect(
            testAppendPath.absoluteString == "https://www.example.com/api/v3"
        )

        // Appending component
        #expect(
            base.appending(component: "AC/DC").absoluteString == "https://www.example.com/AC%2FDC"
        )
        var testAppendComponent = base
        testAppendComponent.append(component: "AC/DC")
        #expect(
            testAppendComponent.absoluteString == "https://www.example.com/AC%2FDC"
        )

        // Append queryItems
        let queryItems = [
            URLQueryItem(name: "id", value: "42"),
            URLQueryItem(name: "color", value: "blue")
        ]
        #expect(
            base.appending(queryItems: queryItems).absoluteString == "https://www.example.com?id=42&color=blue"
        )
        var testAppendQueryItems = base
        testAppendQueryItems.append(queryItems: queryItems)
        #expect(
            testAppendQueryItems.absoluteString == "https://www.example.com?id=42&color=blue"
        )

        // Appending components
        #expect(
            base.appending(components: "api", "artist", "AC/DC").absoluteString == "https://www.example.com/api/artist/AC%2FDC"
        )
        var testAppendComponents = base
        testAppendComponents.append(components: "api", "artist", "AC/DC")
        #expect(
            testAppendComponents.absoluteString == "https://www.example.com/api/artist/AC%2FDC"
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
            chained.absoluteString == "https://www.example.com/api/v2/get/products?magic=42&color=blue"
        )
    }

    @Test func testAppendFamilyDirectoryHint() throws {
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

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
    func testURLEncodingInvalidCharacters(urlString: String) throws {
        var url = URL(string: urlString, encodingInvalidCharacters: true)
        #expect(url != nil, "Expected a percent-encoded url for string \(urlString)")
        url = URL(string: urlString, encodingInvalidCharacters: false)
        #expect(url == nil, "Expected to fail strict url parsing for string \(urlString)")
    }

    @Test func testURLAppendingPathDoesNotEncodeColon() throws {
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

        // `appending(component:)` should explicitly treat `component` as a single
        // path component, meaning "/" should be encoded to "%2F" before appending
        appended = url.appending(component: slashComponent, directoryHint: .notDirectory)
        #if FOUNDATION_FRAMEWORK_NSURL
        #expect(appended.absoluteString == "file:///var/mobile/relative/with:slash")
        #expect(appended.relativePath == "relative/with:slash")
        #else
        #expect(appended.absoluteString == "file:///var/mobile/relative/%2Fwith:slash")
        #expect(appended.relativePath == "relative/%2Fwith:slash")
        #endif

        appended = url.appendingPathComponent(component, isDirectory: false)
        #expect(appended.absoluteString == "file:///var/mobile/relative/no:slash")
        #expect(appended.relativePath == "relative/no:slash")

        // Test deprecated API, which acts like `appending(path:)`
        appended = url.appendingPathComponent(slashComponent, isDirectory: false)
        #expect(appended.absoluteString == "file:///var/mobile/relative/with:slash")
        #expect(appended.relativePath == "relative/with:slash")
    }

    @Test func testURLFilePathDropsTrailingSlashes() throws {
        var url = URL(filePath: "/path/slashes///")
        #expect(url.path() == "/path/slashes///")
        // TODO: Update this once .fileSystemPath uses backslashes for Windows
        #expect(url.fileSystemPath == "/path/slashes")

        url = URL(filePath: "/path/slashes/")
        #expect(url.path() == "/path/slashes/")
        #expect(url.fileSystemPath == "/path/slashes")

        url = URL(filePath: "/path/slashes")
        #expect(url.path() == "/path/slashes")
        #expect(url.fileSystemPath == "/path/slashes")
    }

    @Test func testURLNotDirectoryHintStripsTrailingSlash() throws {
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

    @Test func testURLHostRetainsIDNAEncoding() throws {
        let url = URL(string: "ftp://user:password@*.xn--poema-9qae5a.com.br:4343/cat.txt")!
        #expect(url.host == "*.xn--poema-9qae5a.com.br")
    }

    @Test func testURLComponentsPercentEncodedUnencodedProperties() throws {
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

    @Test func testURLPercentEncodedProperties() throws {
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

    @Test func testURLComponentsUppercasePercentEncoding() throws {
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

    @Test(.disabled("This brute forces many combinations and takes a long time. Skip this for automated testing purposes and test manually when needed."))
    func testURLComponentsRangeCombinations() throws {
        let schemes = [nil, "a", "aa"]
        let users = [nil, "b", "bb"]
        let passwords = [nil, "c", "cc"]
        let hosts = [nil, "d", "dd"]
        let ports = [nil, 80, 433]
        let paths = ["", "/e", "/e/e"]
        let queries = [nil, "f=f", "hh=hh"]
        let fragments = [nil, "j", "jj"]
        
        for scheme in schemes {
            for user in users {
                for password in passwords {
                    for host in hosts {
                        for port in ports {
                            for path in paths {
                                for query in queries {
                                    for fragment in fragments {
                                        try testURLComponentsRangeCombinations(scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func testURLComponentsRangeCombinations(scheme: String?, user: String?, password: String?, host: String?, port: Int?, path: String, query: String?, fragment: String?) throws {
        func validateRanges(_ comp: URLComponents, scheme: String?, user: String?, password: String?, host: String?, port: Int?, path: String, query: String?, fragment: String?, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let string = try #require(comp.string, sourceLocation: sourceLocation)
            if let scheme {
                let range = try #require(comp.rangeOfScheme, sourceLocation: sourceLocation)
                #expect(string[range] == scheme)
            } else {
                #expect(comp.rangeOfScheme == nil, sourceLocation: sourceLocation)
            }
            if let user {
                let range = try #require(comp.rangeOfUser, sourceLocation: sourceLocation)
                #expect(string[range] == user, sourceLocation: sourceLocation)
            } else {
                // Even if we set comp.user = nil, a non-nil password
                // implies that user exists as the empty string.
                let isEmptyUserWithPassword = (
                    comp.user?.isEmpty ?? false &&
                    comp.rangeOfUser?.isEmpty ?? false &&
                    comp.password != nil
                )
                #expect(comp.rangeOfUser == nil || isEmptyUserWithPassword, sourceLocation: sourceLocation)
            }
            if let password {
                let range = try #require(comp.rangeOfPassword, sourceLocation: sourceLocation)
                #expect(string[range] == password, sourceLocation: sourceLocation)
            } else {
                #expect(comp.rangeOfPassword == nil, sourceLocation: sourceLocation)
            }
            if let host {
                let range = try #require(comp.rangeOfHost, sourceLocation: sourceLocation)
                #expect(string[range] == host, sourceLocation: sourceLocation)
            } else {
                // Even if we set comp.host = nil, any non-nil authority component
                // implies that host exists as the empty string.
                let isEmptyHostWithAuthorityComponent = (
                    comp.host?.isEmpty ?? false &&
                    comp.rangeOfHost?.isEmpty ?? false &&
                    (user != nil || password != nil || port != nil)
                )
                #expect(comp.rangeOfHost == nil || isEmptyHostWithAuthorityComponent, sourceLocation: sourceLocation)
            }
            if let port {
                let range = try #require(comp.rangeOfPort, sourceLocation: sourceLocation)
                #expect(string[range] == String(port), sourceLocation: sourceLocation)
            } else {
                #expect(comp.rangeOfPort == nil, sourceLocation: sourceLocation)
            }
            // rangeOfPath should never be nil.
            let pathRange = try #require(comp.rangeOfPath, sourceLocation: sourceLocation)
            #expect(string[pathRange] == path, sourceLocation: sourceLocation)
            if let query {
                let range = try #require(comp.rangeOfQuery, sourceLocation: sourceLocation)
                #expect(string[range] == query, sourceLocation: sourceLocation)
            } else {
                #expect(comp.rangeOfQuery == nil, sourceLocation: sourceLocation)
            }
            if let fragment {
                let range = try #require(comp.rangeOfFragment, sourceLocation: sourceLocation)
                #expect(string[range] == fragment, sourceLocation: sourceLocation)
            } else {
                #expect(comp.rangeOfFragment == nil, sourceLocation: sourceLocation)
            }
        }
        
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
        let fullComponents = URLComponents(string: string)!
        
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
        comp = URLComponents(string: stringWithoutScheme)!
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
        comp = URLComponents(string: stringWithoutUser)!
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
        comp = URLComponents(string: stringWithoutPassword)!
        comp.password = password
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        
        comp = fullComponents
        comp.host = nil
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: nil, port: port, path: path, query: query, fragment: fragment)
        
        let stringWithoutHost = try #require(comp.string)
        comp = URLComponents(string: stringWithoutHost)!
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
        comp = URLComponents(string: stringWithoutPort)!
        comp.port = port
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        
        comp = fullComponents
        comp.path = ""
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: "", query: query, fragment: fragment)
        
        let stringWithoutPath = try #require(comp.string)
        comp = URLComponents(string: stringWithoutPath)!
        comp.path = path
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        
        comp = fullComponents
        comp.query = nil
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: nil, fragment: fragment)
        
        let stringWithoutQuery = try #require(comp.string)
        comp = URLComponents(string: stringWithoutQuery)!
        comp.query = query
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        
        comp = fullComponents
        comp.fragment = nil
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: nil)
        
        let stringWithoutFragment = try #require(comp.string)
        comp = URLComponents(string: stringWithoutFragment)!
        comp.fragment = fragment
        try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
    }

    @Test func testURLComponentsEncodesFirstPathColon() throws {
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
    }

    @Test func testURLComponentsInvalidPaths() {
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

    @Test func testURLComponentsAllowsEqualSignInQueryItemValue() {
        var comp = URLComponents(string: "http://example.com/path?item=value==&q==val")!
        var expected = [URLQueryItem(name: "item", value: "value=="), URLQueryItem(name: "q", value: "=val")]
        #expect(comp.percentEncodedQueryItems == expected)
        #expect(comp.queryItems == expected)

        expected = [URLQueryItem(name: "new", value: "=value="), URLQueryItem(name: "name", value: "=")]
        comp.percentEncodedQueryItems = expected
        #expect(comp.percentEncodedQueryItems == expected)
        #expect(comp.queryItems == expected)
    }

    @Test func testURLComponentsLookalikeIPLiteral() {
        // We should consider a lookalike IP literal invalid (note accent on the first bracket)
        let fakeIPLiteral = "[́::1]"
        let fakeURLString = "http://\(fakeIPLiteral):80/"

        let comp = URLComponents(string: fakeURLString)
        #expect(comp == nil)

        var comp2 = URLComponents()
        comp2.host = fakeIPLiteral
        #expect(comp2.string == nil)
    }

    @Test func testURLComponentsDecodingNULL() {
        let comp = URLComponents(string: "http://example.com/my\u{0}path")!
        #expect(comp.percentEncodedPath == "/my%00path")
        #expect(comp.path == "/my\u{0}path")
    }

#if FOUNDATION_FRAMEWORK
    @Test func testURLComponentsBridging() throws {
        var nsURLComponents = try #require(NSURLComponents(
            string: "https://example.com?url=https%3A%2F%2Fapple.com"
        ))
        var urlComponents = nsURLComponents as URLComponents
        #expect(urlComponents.string == nsURLComponents.string)

        urlComponents = try #require(URLComponents(
            string: "https://example.com?url=https%3A%2F%2Fapple.com"
        ))
        nsURLComponents = urlComponents as NSURLComponents
        #expect(urlComponents.string == nsURLComponents.string)
    }
#endif

    func testURLComponentsUnixDomainSocketOverHTTPScheme() {
        var comp = URLComponents()
        comp.scheme = "http+unix"
        comp.host = "/path/to/socket"
        comp.path = "/info"
        #expect(comp.string == "http+unix://%2Fpath%2Fto%2Fsocket/info")

        comp.scheme = "https+unix"
        #expect(comp.string == "https+unix://%2Fpath%2Fto%2Fsocket/info")

        comp.encodedHost = "%2Fpath%2Fto%2Fsocket"
        #expect(comp.string == "https+unix://%2Fpath%2Fto%2Fsocket/info")
        #expect(comp.encodedHost == "%2Fpath%2Fto%2Fsocket")
        #expect(comp.host == "/path/to/socket")
        #expect(comp.path == "/info")

        // "/path/to/socket" is not a valid host for schemes
        // that IDNA-encode hosts instead of percent-encoding
        comp.scheme = "http"
        #expect(comp.string == nil)

        comp.scheme = "https"
        #expect(comp.string == nil)

        comp.scheme = "https+unix"
        #expect(comp.string == "https+unix://%2Fpath%2Fto%2Fsocket/info")

        // Check that we can parse a percent-encoded http+unix URL string
        comp = URLComponents(string: "http+unix://%2Fpath%2Fto%2Fsocket/info")!
        #expect(comp.encodedHost == "%2Fpath%2Fto%2Fsocket")
        #expect(comp.host == "/path/to/socket")
        #expect(comp.path == "/info")
    }
}

extension FilePlaygroundTests {
    struct URLTests {
        @Test func testURLFilePathRelativeToBase() throws {
            try playground {
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
                #expect(url1 == url2, "\(url1) was not equal to \(url2)")
                
                // directoryHint is `.inferFromPath` by default
                let url3 = URL(filePath: relativePath + "/", relativeTo: baseURL)
                #expect(url1 == url3, "\(url1) was not equal to \(url3)")
            }
        }
    }
}
