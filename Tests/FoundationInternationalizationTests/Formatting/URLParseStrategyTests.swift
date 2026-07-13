//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import RegexBuilder
import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#else
@testable import Foundation
#endif

typealias FullStringTestCase = (string: String, style: URL.ParseStrategy, expectMatch: Bool)

@Suite("URL.ParseStrategy")
private struct URLParseStrategyTests {

    @Test func componentRequirements() {
        let lenientTests: [FullStringTestCase] = [
            (string: "https://www.example.com",
             style: .init(),
             expectMatch: true),
            (string: "www.example.com",
             style: .init(),
             expectMatch: false),
            // Missing scheme
            (string: "www.example.com",
             style: .init(scheme: .required),
             expectMatch: false),
            (string: "https://www.example.com",
             style: .init(scheme: .required, host: .required),
             expectMatch: true),
            // Missing port
            (string: "https://www.example.com",
             style: .init(
                scheme: .required,
                host: .required,
                port: .required),
             expectMatch: false),
            (string: "https://www.example.com:1234",
             style: .init(
                scheme: .required,
                host: .required,
                port: .required),
             expectMatch: true),
            // Missing username
            (string: "https://www.example.com:1234",
             style: .init(
                scheme: .required,
                user: .required,
                host: .required,
                port: .required),
             expectMatch: false),
            (string: "https://charles@www.example.com:1234",
             style: .init(
                scheme: .required,
                user: .required,
                host: .required,
                port: .required),
             expectMatch: true),
            // Missing password
            (string: "https://charles@www.example.com:1234",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required),
             expectMatch: false),
            (string: "https://charles:password@www.example.com:1234",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required),
             expectMatch: true),
            // Missing path
            (string: "https://charles:password@www.example.com:1234",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required),
             expectMatch: false),
            (string: "https://charles:password@www.example.com:1234/search/v2",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required),
             expectMatch: true),
            // Missing query
            (string: "https://charles:password@www.example.com:1234/search",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required,
                query: .required),
             expectMatch: false),
            (string: "https://charles:password@www.example.com:1234/search?name=alexis",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required,
                query: .required),
             expectMatch: true),
            // Missing fragment
            (string: "https://charles:password@www.example.com:1234/search?name=alexis",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required,
                query: .required,
                fragment: .required),
             expectMatch: false),
            (string: "https://charles:password@www.example.com:1234/search?name=alexis#user-name",
             style: .init(
                scheme: .required,
                user: .required,
                password: .required,
                host: .required,
                port: .required,
                path: .required,
                query: .required,
                fragment: .required),
             expectMatch: true),
        ]
        for testCase in lenientTests {
            _verifyParseStrategy(withCase: testCase)
        }
    }

    @Test func defaultValueSubstitution() {
        let tests: [FullStringTestCase] = [
            // Substitute scheme
            (string: "www.apple.com",
             style: .init(scheme: .defaultValue("https"), host: .optional),
             expectMatch: true),
            (string: "ftp://www.orange.com",
             style: .init(scheme: .defaultValue("https")),
             expectMatch: true),
            // Substitute user
            (string: "https://www.watermelon.com",
             style: .init(user: .defaultValue("Charles")),
             expectMatch: true),
            (string: "https://moria@www.peach.com",
             style: .init(user: .defaultValue("Charles")),
             expectMatch: true),
            // Substitute password
            (string: "https://charles:pa$$w0rd@www.mango.com",
             style: .init(password: .defaultValue("guest")),
             expectMatch: true),
            (string: "https://lana@www.strawberry.com",
             style: .init(password: .defaultValue("guest")),
             expectMatch: true),
            // Substitute host
            (string: "https://www.kiwi.com",
             style: .init(host: .defaultValue("www.apple.com")),
             expectMatch: true),
            (string: "https:",
             style: .init(host: .defaultValue("www.apple.com")),
             expectMatch: true),
            // Substitute port
            (string: "https://www.pineapple.com:1234",
             style: .init(port: .defaultValue(8080)),
             expectMatch: true),
            (string: "https://www.lemon.com",
             style: .init(port: .defaultValue(8080)),
             expectMatch: true),
            // Substitute path
            (string: "https://www.lime.com/search",
             style: .init(path: .defaultValue("/about")),
             expectMatch: true),
            (string: "https://www.blueberry.com",
             style: .init(path: .defaultValue("/about")),
             expectMatch: true),
            // Substitute query
            (string: "https://www.cherry.com?color=red",
             style: .init(query: .defaultValue("color=blue")),
             expectMatch: true),
            (string: "https://www.blueberry.com",
             style: .init(query: .defaultValue("color=blue")),
             expectMatch: true),
            // Substitute fragment
            (string: "https://www.dragonfruit.com#description",
             style: .init(fragment: .defaultValue("name")),
             expectMatch: true),
            (string: "https://www.lychee.com",
             style: .init(fragment: .defaultValue("name")),
             expectMatch: true),
        ]

        for testCase in tests {
            _verifyDefaultValueSubstitution(withCase: testCase)
        }
    }

    private func _verifyParseStrategy(withCase testCase: FullStringTestCase, sourceLocation: SourceLocation = #_sourceLocation) {
        let expectedValue: URL? = testCase.expectMatch ? URL(string: testCase.string)! : nil
        let output: URL? = try? testCase.style.parse(testCase.string)
        #expect(
            expectedValue == output,
            "Expected [\(String(describing: expectedValue))], got [\(String(describing: output))]",
            sourceLocation: sourceLocation)
    }

    private func _verifyDefaultValueSubstitution(withCase testCase: FullStringTestCase, sourceLocation: SourceLocation = #_sourceLocation) {
        // Default value substitution cases always expect a match
        // `originalURL` shouldn't have any substitutions. We can use it
        // to check whether the default values are set correctly in the
        // parsed URL
        let originalURL = URL(string: testCase.string)!
        let output: URL = try! testCase.style.parse(testCase.string)
        testCase.style.defaultValues.forEach { (componentValue: Int, defaultValue: String) in
            let component = URL.FormatStyle.Component(rawValue: componentValue)!
            if !component.hasComponentValue(in: originalURL) {
                // We should use the substituted value because the original
                // url does not contain this value
                if let stringValue: String = component.getComponentValue(from: output) {
                    #expect(stringValue == defaultValue, sourceLocation: sourceLocation)
                } else if let intValue: Int = component.getComponentValue(from: output) {
                    let defaultIntValue = Int(defaultValue)
                    #expect(defaultIntValue != nil, sourceLocation: sourceLocation)
                    #expect(intValue == defaultIntValue, sourceLocation: sourceLocation)
                } else {
                    Issue.record("Unexpected component type", sourceLocation: sourceLocation)
                }
            } else {
                // We should use the original value because it's present
                // so no substitution needed
                if let stringOriginalValue: String = component.getComponentValue(from: originalURL),
                   let stringOutputValue: String = component.getComponentValue(from: output) {
                    #expect(stringOriginalValue == stringOutputValue, sourceLocation: sourceLocation)
                } else if let intOriginalValue: Int = component.getComponentValue(from: originalURL),
                          let intOutputValue: Int = component.getComponentValue(from: output) {
                    #expect(intOriginalValue == intOutputValue, sourceLocation: sourceLocation)
                } else {
                    Issue.record("Unexpected component type", sourceLocation: sourceLocation)
                }
            }
        }
    }
}

@Suite("URL.ParseStrategy (Pattern Matching)")
private struct URLParseStrategyPatternMatchingTests {

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func webAddressPatternMatching() {
        let webAddress: URL.ParseStrategy = .init()
        let urlText = "https://www.example.com:1234/products"
        let expectation = URL(string: urlText)
        _verifyMatching(
            urlText,
            style: webAddress,
            expectedUpperBound: urlText.endIndex,
            expectedValue: expectation)
        _verifyMatching(
            "\(urlText) is an amazing website",
            style: webAddress,
            expectedUpperBound: urlText.endIndex,
            expectedValue: expectation)
        _verifyMatching(
            "\(urlText) 🏳️‍🌈🤙🏻", style: webAddress,
            expectedUpperBound: urlText.endIndex,
            expectedValue: expectation)
        // Test match custom range
        let sentance = "Moria Rosé \(urlText) bébé"
        let range = sentance.firstIndex(of: "h")! ..< sentance.endIndex
        _verifyMatching(
            sentance, style: webAddress, range: range,
            expectedUpperBound: sentance.index(after: sentance.lastIndex(of: "s")!),
            expectedValue: expectation)
        // Match the first url
        _verifyMatching(
            "\(urlText) https://www.apple.com file:///var/mobile",
            style: webAddress,
            expectedUpperBound: urlText.endIndex,
            expectedValue: expectation)
        // Invalid urls
        // The url does not start at the beginning of the sentance
        _verifyMatching(
            sentance, style: webAddress,
            expectedUpperBound: nil,
            expectedValue: nil)
        _verifyMatching(
            "htt ps://www.ex ple.com", style: webAddress,
            expectedUpperBound: nil,
            expectedValue: nil)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func nonConventionalURLPatternMatching() {
        // Test "non-conventional" URLs. The host names of these URLs are encoded
        // via `uidna_nameToASCII` and the paths are percent encoded.
        let emojiURLText = "https://i❤️tacos.ws/🏳️‍🌈/冰淇淋"
        let emojiURL = URL(string: "https://xn--itacos-i50d.ws/%F0%9F%8F%B3%EF%B8%8F%E2%80%8D%F0%9F%8C%88/%E5%86%B0%E6%B7%87%E6%B7%8B")
        _verifyMatching(
            "\(emojiURLText) 🏳️‍🌈❤️",
            style: .init(),
            expectedUpperBound: emojiURLText.endIndex,
            expectedValue: emojiURL)
        let emojiSentance = "🤯🌝 🌭 \(emojiURLText) 🏁🌈 🏳️‍🌈🥗🤙🏻"
        let emojiRange = emojiSentance.firstIndex(of: "h")! ..< emojiSentance.endIndex
        _verifyMatching(
            emojiSentance, style: .init(),
            range: emojiRange,
            expectedUpperBound: emojiSentance.index(after: emojiSentance.lastIndex(of: "淋")!),
            expectedValue: emojiURL)
        let chineseURLText = "http://見.香港/热狗/🌭"
        let chineseURL = URL(string: "http://xn--nw2a.xn--j6w193g/%E7%83%AD%E7%8B%97/%F0%9F%8C%AD")
        _verifyMatching(
            "\(chineseURLText) 苹果手表", style: .init(),
            expectedUpperBound: chineseURLText.endIndex,
            expectedValue: chineseURL)
        let chineseSentance = "这个网站 \(chineseURLText) 很有趣"
        let chineseRange = chineseSentance.firstIndex(of: "h")! ..< chineseSentance.endIndex
        _verifyMatching(
            chineseSentance, style: .init(),
            range: chineseRange,
            expectedUpperBound: chineseSentance.index(after: chineseSentance.lastIndex(of: "🌭")!),
            expectedValue: chineseURL)
        // Match the first URL
        _verifyMatching(
            "\(emojiURLText) \(chineseURLText) file:///var/moblie",
            style: .init(),
            expectedUpperBound: emojiURLText.endIndex,
            expectedValue: emojiURL)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func regexMatching() {
        let header = """
        HTTP/1.1 301 Redirect
        Date: Wed, 16 Feb 2022 23:53:19 GMT
        Connection: close
        Location: https://www.apple.com/
        Content-Type: text/html
        Content-Language: en
        """
        let regex = Regex {
            Capture {
                .url()
            }
        }
        guard let res = header.firstMatch(of: regex) else {
            Issue.record()
            return
        }
        let expectedURL = URL(string: "https://www.apple.com/")!
        #expect(res.output.0 == "https://www.apple.com/")
        #expect(res.output.1 == expectedURL)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test func regexMatchingMultiple() {
        let list = """
        A   https://www.pomegranate.com         TYPE1
        B   ftp://www.apple.com                 TYPE2
        C   http://[2620:100:e000::8001]:81/US  TYPE3
        D   www.noscheme.com                    TYPE4 // should not match
        E   https://👁👄👁.fm/🐮                TYPE5
        """
        let regex = Regex {
            Capture {
                .url(scheme: .required, host: .required, port: .defaultValue(8080))
            }
        }
        // port 8080 should have been insert to the URLs without a port
        let expectedURLs = [
            URL(string: "https://www.pomegranate.com:8080")!,
            URL(string: "ftp://www.apple.com:8080")!,
            URL(string: "http://[2620:100:e000::8001]:81/US")!,
            URLComponents(string: "https://👁👄👁.fm:8080/🐮")!.url!
        ]
        let expectedStrings: [String] = [
            "https://www.pomegranate.com",
            "ftp://www.apple.com",
            "http://[2620:100:e000::8001]:81/US",
            "https://👁👄👁.fm/🐮"
        ]
        let result = list.matches(of: regex)
        for index in 0 ..< expectedURLs.count {
            #expect(String(result[index].output.0) == expectedStrings[index])
            #expect(result[index].output.1 == expectedURLs[index])
        }
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    private func _verifyMatching(_ str: String, style: URL.ParseStrategy, range: Range<String.Index>? = nil, expectedUpperBound: String.Index?, expectedValue: URL?, sourceLocation: SourceLocation = #_sourceLocation) {
        let resolvedRange = range ?? str.startIndex ..< str.endIndex
        let (upperBound, match) = (try? style.consuming(str, startingAt: resolvedRange.lowerBound, in: resolvedRange)) ?? (nil, nil)
        let upperBoundDescription = upperBound?.utf16Offset(in: str)
        let expectedUpperBoundDescription = expectedUpperBound?.utf16Offset(in: str)
        #expect(
            upperBound == expectedUpperBound,
            "found upperBound: \(String(describing: upperBoundDescription)); expected: \(String(describing: expectedUpperBoundDescription))",
            sourceLocation: sourceLocation)
        #expect(match == expectedValue, sourceLocation: sourceLocation)
    }
}
