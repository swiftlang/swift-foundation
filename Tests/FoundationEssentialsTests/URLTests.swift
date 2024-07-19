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


#if canImport(TestSupport)
import TestSupport
#endif // canImport(TestSupport)

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#endif

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#endif

final class URLTests : XCTestCase {

    func testURLBasics() throws {
        let string = "https://username:password@example.com:80/path/path?query=value&q=v#fragment"
        let url = try XCTUnwrap(URL(string: string))

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.user(), "username")
        XCTAssertEqual(url.password(), "password")
        XCTAssertEqual(url.host(), "example.com")
        XCTAssertEqual(url.port, 80)
        XCTAssertEqual(url.path(), "/path/path")
        XCTAssertEqual(url.relativePath, "/path/path")
        XCTAssertEqual(url.query(), "query=value&q=v")
        XCTAssertEqual(url.fragment(), "fragment")
        XCTAssertEqual(url.absoluteString, string)
        XCTAssertEqual(url.absoluteURL, url)
        XCTAssertEqual(url.relativeString, string)
        XCTAssertNil(url.baseURL)

        let baseString = "https://user:pass@base.example.com:8080/base/"
        let baseURL = try XCTUnwrap(URL(string: baseString))
        let absoluteURLWithBase = try XCTUnwrap(URL(string: string, relativeTo: baseURL))

        // The URL is already absolute, so .baseURL is nil, and the components are unchanged
        XCTAssertEqual(absoluteURLWithBase.scheme, "https")
        XCTAssertEqual(absoluteURLWithBase.user(), "username")
        XCTAssertEqual(absoluteURLWithBase.password(), "password")
        XCTAssertEqual(absoluteURLWithBase.host(), "example.com")
        XCTAssertEqual(absoluteURLWithBase.port, 80)
        XCTAssertEqual(absoluteURLWithBase.path(), "/path/path")
        XCTAssertEqual(absoluteURLWithBase.relativePath, "/path/path")
        XCTAssertEqual(absoluteURLWithBase.query(), "query=value&q=v")
        XCTAssertEqual(absoluteURLWithBase.fragment(), "fragment")
        XCTAssertEqual(absoluteURLWithBase.absoluteString, string)
        XCTAssertEqual(absoluteURLWithBase.absoluteURL, url)
        XCTAssertEqual(absoluteURLWithBase.relativeString, string)
        XCTAssertNil(absoluteURLWithBase.baseURL)
        XCTAssertEqual(absoluteURLWithBase.absoluteURL, url)

        let relativeString = "relative/path?query#fragment"
        let relativeURL = try XCTUnwrap(URL(string: relativeString))

        XCTAssertNil(relativeURL.scheme)
        XCTAssertNil(relativeURL.user())
        XCTAssertNil(relativeURL.password())
        XCTAssertNil(relativeURL.host())
        XCTAssertNil(relativeURL.port)
        XCTAssertEqual(relativeURL.path(), "relative/path")
        XCTAssertEqual(relativeURL.relativePath, "relative/path")
        XCTAssertEqual(relativeURL.query(), "query")
        XCTAssertEqual(relativeURL.fragment(), "fragment")
        XCTAssertEqual(relativeURL.absoluteString, relativeString)
        XCTAssertEqual(relativeURL.absoluteURL, relativeURL)
        XCTAssertEqual(relativeURL.relativeString, relativeString)
        XCTAssertNil(relativeURL.baseURL)

        let relativeURLWithBase = try XCTUnwrap(URL(string: relativeString, relativeTo: baseURL))

        XCTAssertEqual(relativeURLWithBase.scheme, baseURL.scheme)
        XCTAssertEqual(relativeURLWithBase.user(), baseURL.user())
        XCTAssertEqual(relativeURLWithBase.password(), baseURL.password())
        XCTAssertEqual(relativeURLWithBase.host(), baseURL.host())
        XCTAssertEqual(relativeURLWithBase.port, baseURL.port)
        #if !FOUNDATION_FRAMEWORK_NSURL
        XCTAssertEqual(relativeURLWithBase.path(), "/base/relative/path")
        #else
        XCTAssertEqual(relativeURLWithBase.path(), "relative/path")
        #endif
        XCTAssertEqual(relativeURLWithBase.relativePath, "relative/path")
        XCTAssertEqual(relativeURLWithBase.query(), "query")
        XCTAssertEqual(relativeURLWithBase.fragment(), "fragment")
        XCTAssertEqual(relativeURLWithBase.absoluteString, "https://user:pass@base.example.com:8080/base/relative/path?query#fragment")
        XCTAssertEqual(relativeURLWithBase.absoluteURL, URL(string: "https://user:pass@base.example.com:8080/base/relative/path?query#fragment"))
        XCTAssertEqual(relativeURLWithBase.relativeString, relativeString)
        XCTAssertEqual(relativeURLWithBase.baseURL, baseURL)
    }

    func testURLResolvingAgainstBase() throws {
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
            XCTAssertNotNil(url, "Got nil url for string: \(test.key)")
            XCTAssertEqual(url?.absoluteString, test.value, "Failed test for string: \(test.key)")
        }
    }

    func testURLPathAPIsResolveAgainstBase() throws {
        #if FOUNDATION_FRAMEWORK_NSURL
        try XCTSkipIf(true)
        #endif
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
            XCTAssertEqual(url.path(), test.value)
            if (url.hasDirectoryPath && url.path().count > 1) {
                // The trailing slash is stripped in .path for file system compatibility
                XCTAssertEqual(String(url.path().dropLast()), url.path)
            } else {
                XCTAssertEqual(url.path(), url.path)
            }
        }
    }

    func testURLPathComponentsPercentEncodedSlash() throws {
        #if FOUNDATION_FRAMEWORK_NSURL
        try XCTSkipIf(true)
        #endif

        var url = try XCTUnwrap(URL(string: "https://example.com/https%3A%2F%2Fexample.com"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com"])

        url = try XCTUnwrap(URL(string: "https://example.com/https:%2f%2fexample.com"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com"])

        url = try XCTUnwrap(URL(string: "https://example.com/https:%2F%2Fexample.com%2Fpath"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com/path"])

        url = try XCTUnwrap(URL(string: "https://example.com/https:%2F%2Fexample.com/path"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com", "path"])

        url = try XCTUnwrap(URL(string: "https://example.com/https%3A%2F%2Fexample.com%2Fpath%3Fquery%23fragment"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com/path?query#fragment"])

        url = try XCTUnwrap(URL(string: "https://example.com/https%3A%2F%2Fexample.com%2Fpath?query#fragment"))
        XCTAssertEqual(url.pathComponents, ["/", "https://example.com/path"])
    }

    func testURLRootlessPath() throws {
        #if FOUNDATION_FRAMEWORK_NSURL
        try XCTSkipIf(true)
        #endif

        let paths = ["", "path"]
        let queries = [nil, "query"]
        let fragments = [nil, "fragment"]

        for path in paths {
            for query in queries {
                for fragment in fragments {
                    let queryString = query != nil ? "?\(query!)" : ""
                    let fragmentString = fragment != nil ? "#\(fragment!)" : ""
                    let urlString = "scheme:\(path)\(queryString)\(fragmentString)"
                    let url = try XCTUnwrap(URL(string: urlString))
                    XCTAssertEqual(url.absoluteString, urlString)
                    XCTAssertEqual(url.scheme, "scheme")
                    XCTAssertNil(url.host())
                    XCTAssertEqual(url.path(), path)
                    XCTAssertEqual(url.query(), query)
                    XCTAssertEqual(url.fragment(), fragment)
                }
            }
        }
    }

    func testURLNonSequentialIPLiteralAndPort() {
        let urlString = "https://[fe80::3221:5634:6544]invalid:433/"
        let url = URL(string: urlString)
        XCTAssertNil(url)
    }

    func testURLFilePathInitializer() throws {
        let directory = URL(filePath: "/some/directory", directoryHint: .isDirectory)
        XCTAssertTrue(directory.hasDirectoryPath)

        let notDirectory = URL(filePath: "/some/file", directoryHint: .notDirectory)
        XCTAssertFalse(notDirectory.hasDirectoryPath)

        // directoryHint defaults to .inferFromPath
        let directoryAgain = URL(filePath: "/some/directory.framework/")
        XCTAssertTrue(directoryAgain.hasDirectoryPath)

        let notDirectoryAgain = URL(filePath: "/some/file")
        XCTAssertFalse(notDirectoryAgain.hasDirectoryPath)

        // Test .checkFileSystem by creating a directory
        let tempDirectory = URL.temporaryDirectory
        let urlBeforeCreation = URL(filePath: "\(tempDirectory.path)/tmp-dir", directoryHint: .checkFileSystem)
        XCTAssertFalse(urlBeforeCreation.hasDirectoryPath)

        try FileManager.default.createDirectory(
            at: URL(filePath: "\(tempDirectory.path)/tmp-dir"),
            withIntermediateDirectories: true
        )
        let urlAfterCreation = URL(filePath: "\(tempDirectory.path)/tmp-dir", directoryHint: .checkFileSystem)
        XCTAssertTrue(urlAfterCreation.hasDirectoryPath)
        try FileManager.default.removeItem(at: URL(filePath: "\(tempDirectory.path)/tmp-dir"))
    }

    func testURLFilePathRelativeToBase() throws {
        try FileManagerPlayground {
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
            XCTAssertEqual(url1, url2, "\(url1) was not equal to \(url2)")

            // directoryHint is `.inferFromPath` by default
            let url3 = URL(filePath: relativePath + "/", relativeTo: baseURL)
            XCTAssertEqual(url1, url3, "\(url1) was not equal to \(url3)")
        }
    }

    func testAppendFamily() throws {
        let base = URL(string: "https://www.example.com")!

        // Appending path
        XCTAssertEqual(
            base.appending(path: "/api/v2").absoluteString,
            "https://www.example.com/api/v2"
        )
        var testAppendPath = base
        testAppendPath.append(path: "/api/v3")
        XCTAssertEqual(
            testAppendPath.absoluteString,
            "https://www.example.com/api/v3"
        )

        // Appending component
        XCTAssertEqual(
            base.appending(component: "AC/DC").absoluteString,
            "https://www.example.com/AC%2FDC"
        )
        var testAppendComponent = base
        testAppendComponent.append(component: "AC/DC")
        XCTAssertEqual(
            testAppendComponent.absoluteString,
            "https://www.example.com/AC%2FDC"
        )

        // Append queryItems
        let queryItems = [
            URLQueryItem(name: "id", value: "42"),
            URLQueryItem(name: "color", value: "blue")
        ]
        XCTAssertEqual(
            base.appending(queryItems: queryItems).absoluteString,
            "https://www.example.com?id=42&color=blue"
        )
        var testAppendQueryItems = base
        testAppendQueryItems.append(queryItems: queryItems)
        XCTAssertEqual(
            testAppendQueryItems.absoluteString,
            "https://www.example.com?id=42&color=blue"
        )

        // Appending components
        XCTAssertEqual(
            base.appending(components: "api", "artist", "AC/DC").absoluteString,
            "https://www.example.com/api/artist/AC%2FDC"
        )
        var testAppendComponents = base
        testAppendComponents.append(components: "api", "artist", "AC/DC")
        XCTAssertEqual(
            testAppendComponents.absoluteString,
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
        XCTAssertEqual(
            chained.absoluteString,
            "https://www.example.com/api/v2/get/products?magic=42&color=blue"
        )
    }

    func testAppendFamilyDirectoryHint() throws {
        // Make sure directoryHint values are propagated correctly
        let base = URL(string: "file:///var/mobile")!

        // Appending path
        var url = base.appending(path: "/folder/item", directoryHint: .isDirectory)
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(path: "folder/item", directoryHint: .notDirectory)
        XCTAssertFalse(url.hasDirectoryPath)

        url = base.appending(path: "/folder/item.framework/")
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(path: "/folder/item")
        XCTAssertFalse(url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(path: "/folder/item", directoryHint: .checkFileSystem)
        }

        // Appending component
        url = base.appending(component: "AC/DC", directoryHint: .isDirectory)
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(component: "AC/DC", directoryHint: .notDirectory)
        XCTAssertFalse(url.hasDirectoryPath)

        url = base.appending(component: "AC/DC/", directoryHint: .isDirectory)
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(component: "AC/DC")
        XCTAssertFalse(url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(component: "AC/DC", directoryHint: .checkFileSystem)
        }

        // Appending components
        url = base.appending(components: "api", "v2", "AC/DC", directoryHint: .isDirectory)
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC", directoryHint: .notDirectory)
        XCTAssertFalse(url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC/", directoryHint: .isDirectory)
        XCTAssertTrue(url.hasDirectoryPath)

        url = base.appending(components: "api", "v2", "AC/DC")
        XCTAssertFalse(url.hasDirectoryPath)

        try runDirectoryHintCheckFilesystemTest {
            $0.appending(components: "api", "v2", "AC/DC", directoryHint: .checkFileSystem)
        }
    }

    private func runDirectoryHintCheckFilesystemTest(_ builder: (URL) -> URL) throws {
        let tempDirectory = URL.temporaryDirectory
        // We should not have directory path before it's created
        XCTAssertFalse(builder(tempDirectory).hasDirectoryPath)
        // Create the folder
        try FileManager.default.createDirectory(
            at: builder(tempDirectory),
            withIntermediateDirectories: true
        )
        XCTAssertTrue(builder(tempDirectory).hasDirectoryPath)
        try FileManager.default.removeItem(at: builder(tempDirectory))
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    func testURLEncodingInvalidCharacters() throws {
        let urlStrings = [
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
        ]
        for urlString in urlStrings {
            var url = URL(string: urlString, encodingInvalidCharacters: true)
            XCTAssertNotNil(url, "Expected a percent-encoded url for string \(urlString)")
            url = URL(string: urlString, encodingInvalidCharacters: false)
            XCTAssertNil(url, "Expected to fail strict url parsing for string \(urlString)")
        }
    }

    func testURLComponentsPercentEncodedUnencodedProperties() throws {
        var comp = URLComponents()

        comp.user = "%25"
        XCTAssertEqual(comp.user, "%25")
        XCTAssertEqual(comp.percentEncodedUser, "%2525")

        comp.password = "%25"
        XCTAssertEqual(comp.password, "%25")
        XCTAssertEqual(comp.percentEncodedPassword, "%2525")

        // Host behavior differs since the addition of IDNA-encoding
        comp.host = "%25"
        XCTAssertEqual(comp.host, "%")
        XCTAssertEqual(comp.percentEncodedHost, "%25")

        comp.path = "%25"
        XCTAssertEqual(comp.path, "%25")
        XCTAssertEqual(comp.percentEncodedPath, "%2525")

        comp.query = "%25"
        XCTAssertEqual(comp.query, "%25")
        XCTAssertEqual(comp.percentEncodedQuery, "%2525")

        comp.fragment = "%25"
        XCTAssertEqual(comp.fragment, "%25")
        XCTAssertEqual(comp.percentEncodedFragment, "%2525")

        comp.queryItems = [URLQueryItem(name: "name", value: "a%25b")]
        XCTAssertEqual(comp.queryItems, [URLQueryItem(name: "name", value: "a%25b")])
        XCTAssertEqual(comp.percentEncodedQueryItems, [URLQueryItem(name: "name", value: "a%2525b")])
        XCTAssertEqual(comp.query, "name=a%25b")
        XCTAssertEqual(comp.percentEncodedQuery, "name=a%2525b")
    }

    func testURLPercentEncodedProperties() throws {
        var url = URL(string: "https://%3Auser:%3Apassword@%3A.com/%3Apath?%3Aquery=%3A#%3Afragment")!

        XCTAssertEqual(url.user(), "%3Auser")
        XCTAssertEqual(url.user(percentEncoded: false), ":user")

        XCTAssertEqual(url.password(), "%3Apassword")
        XCTAssertEqual(url.password(percentEncoded: false), ":password")

        XCTAssertEqual(url.host(), "%3A.com")
        XCTAssertEqual(url.host(percentEncoded: false), ":.com")

        XCTAssertEqual(url.path(), "/%3Apath")
        XCTAssertEqual(url.path(percentEncoded: false), "/:path")

        XCTAssertEqual(url.query(), "%3Aquery=%3A")
        XCTAssertEqual(url.query(percentEncoded: false), ":query=:")

        XCTAssertEqual(url.fragment(), "%3Afragment")
        XCTAssertEqual(url.fragment(percentEncoded: false), ":fragment")

        // Lowercase input
        url = URL(string: "https://%3auser:%3apassword@%3a.com/%3apath?%3aquery=%3a#%3afragment")!

        XCTAssertEqual(url.user(), "%3auser")
        XCTAssertEqual(url.user(percentEncoded: false), ":user")

        XCTAssertEqual(url.password(), "%3apassword")
        XCTAssertEqual(url.password(percentEncoded: false), ":password")

        XCTAssertEqual(url.host(), "%3a.com")
        XCTAssertEqual(url.host(percentEncoded: false), ":.com")

        XCTAssertEqual(url.path(), "/%3apath")
        XCTAssertEqual(url.path(percentEncoded: false), "/:path")

        XCTAssertEqual(url.query(), "%3aquery=%3a")
        XCTAssertEqual(url.query(percentEncoded: false), ":query=:")

        XCTAssertEqual(url.fragment(), "%3afragment")
        XCTAssertEqual(url.fragment(percentEncoded: false), ":fragment")
    }

    func testURLComponentsUppercasePercentEncoding() throws {
        // Always use uppercase percent-encoding when unencoded components are assigned
        var comp = URLComponents()
        comp.scheme = "https"
        comp.user = "?user"
        comp.password = "?password"
        comp.path = "?path"
        comp.query = "#query"
        comp.fragment = "#fragment"
        XCTAssertEqual(comp.percentEncodedUser, "%3Fuser")
        XCTAssertEqual(comp.percentEncodedPassword, "%3Fpassword")
        XCTAssertEqual(comp.percentEncodedPath, "%3Fpath")
        XCTAssertEqual(comp.percentEncodedQuery, "%23query")
        XCTAssertEqual(comp.percentEncodedFragment, "%23fragment")
    }

    func testURLComponentsRangeCombinations() throws {
        // This brute forces many combinations and takes a long time.
        // Skip this for automated testing purposes and test manually when needed.
        try XCTSkipIf(true)

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
            let string = try XCTUnwrap(comp.string)
            if let scheme {
                let range = try XCTUnwrap(comp.rangeOfScheme)
                XCTAssertTrue(string[range] == scheme)
            } else {
                XCTAssertNil(comp.rangeOfScheme)
            }
            if let user {
                let range = try XCTUnwrap(comp.rangeOfUser)
                XCTAssertTrue(string[range] == user)
            } else {
                // Even if we set comp.user = nil, a non-nil password
                // implies that user exists as the empty string.
                let isEmptyUserWithPassword = (
                    comp.user?.isEmpty ?? false &&
                    comp.rangeOfUser?.isEmpty ?? false &&
                    comp.password != nil
                )
                XCTAssertTrue(comp.rangeOfUser == nil || isEmptyUserWithPassword)
            }
            if let password {
                let range = try XCTUnwrap(comp.rangeOfPassword)
                XCTAssertTrue(string[range] == password)
            } else {
                XCTAssertNil(comp.rangeOfPassword)
            }
            if let host {
                let range = try XCTUnwrap(comp.rangeOfHost)
                XCTAssertTrue(string[range] == host)
            } else {
                // Even if we set comp.host = nil, any non-nil authority component
                // implies that host exists as the empty string.
                let isEmptyHostWithAuthorityComponent = (
                    comp.host?.isEmpty ?? false &&
                    comp.rangeOfHost?.isEmpty ?? false &&
                    (user != nil || password != nil || port != nil)
                )
                XCTAssertTrue(comp.rangeOfHost == nil || isEmptyHostWithAuthorityComponent)
            }
            if let port {
                let range = try XCTUnwrap(comp.rangeOfPort)
                XCTAssertTrue(string[range] == String(port))
            } else {
                XCTAssertNil(comp.rangeOfPort)
            }
            // rangeOfPath should never be nil.
            let pathRange = try XCTUnwrap(comp.rangeOfPath)
            XCTAssertTrue(string[pathRange] == path)
            if let query {
                let range = try XCTUnwrap(comp.rangeOfQuery)
                XCTAssertTrue(string[range] == query)
            } else {
                XCTAssertNil(comp.rangeOfQuery)
            }
            if let fragment {
                let range = try XCTUnwrap(comp.rangeOfFragment)
                XCTAssertTrue(string[range] == fragment)
            } else {
                XCTAssertNil(comp.rangeOfFragment)
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

            let string = try XCTUnwrap(comp.string)
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

            let stringWithoutScheme = try XCTUnwrap(comp.string)
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

            let stringWithoutUser = try XCTUnwrap(comp.string)
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

            let stringWithoutPassword = try XCTUnwrap(comp.string)
            comp = URLComponents(string: stringWithoutPassword)!
            comp.password = password
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.host = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: nil, port: port, path: path, query: query, fragment: fragment)

            let stringWithoutHost = try XCTUnwrap(comp.string)
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

            let stringWithoutPort = try XCTUnwrap(comp.string)
            comp = URLComponents(string: stringWithoutPort)!
            comp.port = port
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.path = ""
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: "", query: query, fragment: fragment)

            let stringWithoutPath = try XCTUnwrap(comp.string)
            comp = URLComponents(string: stringWithoutPath)!
            comp.path = path
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.query = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: nil, fragment: fragment)

            let stringWithoutQuery = try XCTUnwrap(comp.string)
            comp = URLComponents(string: stringWithoutQuery)!
            comp.query = query
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)

            comp = fullComponents
            comp.fragment = nil
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: nil)

            let stringWithoutFragment = try XCTUnwrap(comp.string)
            comp = URLComponents(string: stringWithoutFragment)!
            comp.fragment = fragment
            try validateRanges(comp, scheme: scheme, user: user, password: password, host: host, port: port, path: path, query: query, fragment: fragment)
        }
    }

    func testURLComponentsEncodesFirstPathColon() throws {
        let path = "first:segment:with:colons/second:segment:with:colons"
        var comp = URLComponents()
        comp.path = path
        guard let compString = comp.string else {
            XCTFail("compString was nil")
            return
        }
        guard let slashIndex = compString.firstIndex(of: "/") else {
            XCTFail("Could not find slashIndex")
            return
        }
        let firstSegment = compString[..<slashIndex]
        let secondSegment = compString[slashIndex...]
        XCTAssertNil(firstSegment.firstIndex(of: ":"), "There should not be colons in the first path segment")
        XCTAssertNotNil(secondSegment.firstIndex(of: ":"), "Colons should be allowed in subsequent path segments")

        comp = URLComponents()
        comp.path = path
        guard let compString2 = comp.string else {
            XCTFail("compString2 was nil")
            return
        }
        guard let slashIndex2 = compString2.firstIndex(of: "/") else {
            XCTFail("Could not find slashIndex2")
            return
        }
        let firstSegment2 = compString2[..<slashIndex2]
        let secondSegment2 = compString2[slashIndex2...]
        XCTAssertNil(firstSegment2.firstIndex(of: ":"), "There should not be colons in the first path segment")
        XCTAssertNotNil(secondSegment2.firstIndex(of: ":"), "Colons should be allowed in subsequent path segments")

        // Colons are allowed in the first segment if there is a scheme.

        let colonFirstPath = "playlist:37i9dQZF1E35u89RYOJJV6"
        let legalURLString = "spotify:\(colonFirstPath)"
        comp = try XCTUnwrap(URLComponents(string: legalURLString))
        XCTAssertEqual(comp.string, legalURLString)
        XCTAssertEqual(comp.percentEncodedPath, colonFirstPath)
    }

    func testURLComponentsInvalidPaths() {
        var comp = URLComponents()

        // Path must start with a slash if there's an authority component.
        comp.path = "does/not/start/with/slash"
        XCTAssertNotNil(comp.string)

        comp.user = "user"
        XCTAssertNil(comp.string)
        comp.user = nil

        comp.password = "password"
        XCTAssertNil(comp.string)
        comp.password = nil

        comp.host = "example.com"
        XCTAssertNil(comp.string)
        comp.host = nil

        comp.port = 80
        XCTAssertNil(comp.string)
        comp.port = nil

        comp = URLComponents()

        // If there's no authority, path cannot start with "//".
        comp.path = "//starts/with/two/slashes"
        XCTAssertNil(comp.string)

        // If there's an authority, it's okay.
        comp.user = "user"
        XCTAssertNotNil(comp.string)
        comp.user = nil

        comp.password = "password"
        XCTAssertNotNil(comp.string)
        comp.password = nil

        comp.host = "example.com"
        XCTAssertNotNil(comp.string)
        comp.host = nil

        comp.port = 80
        XCTAssertNotNil(comp.string)
        comp.port = nil
    }

    func testURLComponentsAllowsEqualSignInQueryItemValue() {
        var comp = URLComponents(string: "http://example.com/path?item=value==&q==val")!
        var expected = [URLQueryItem(name: "item", value: "value=="), URLQueryItem(name: "q", value: "=val")]
        XCTAssertEqual(comp.percentEncodedQueryItems, expected)
        XCTAssertEqual(comp.queryItems, expected)

        expected = [URLQueryItem(name: "new", value: "=value="), URLQueryItem(name: "name", value: "=")]
        comp.percentEncodedQueryItems = expected
        XCTAssertEqual(comp.percentEncodedQueryItems, expected)
        XCTAssertEqual(comp.queryItems, expected)
    }

    func testURLComponentsLookalikeIPLiteral() {
        // We should consider a lookalike IP literal invalid (note accent on the first bracket)
        let fakeIPLiteral = "[́::1]"
        let fakeURLString = "http://\(fakeIPLiteral):80/"

        let comp = URLComponents(string: fakeURLString)
        XCTAssertNil(comp)

        var comp2 = URLComponents()
        comp2.host = fakeIPLiteral
        XCTAssertNil(comp2.string)
    }

    func testURLComponentsDecodingNULL() {
        let comp = URLComponents(string: "http://example.com/my\u{0}path")!
        XCTAssertEqual(comp.percentEncodedPath, "/my%00path")
        XCTAssertEqual(comp.path, "/my\u{0}path")
    }
}
