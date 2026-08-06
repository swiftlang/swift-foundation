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

#if FOUNDATION_FRAMEWORK
@testable import Foundation
#else
@testable import FoundationEssentials
@testable import FoundationInternationalization
#endif // FOUNDATION_FRAMEWORK

@Suite("URL (Internationalization)")
private struct URLInternationalizationTests {
    @Test func urlHostUIDNAEncoding() {
        let emojiURL = URL(string: "https://i❤️tacos.ws/🏳️‍🌈/冰淇淋")
        let emojiURLEncoded = "https://xn--itacos-i50d.ws/%F0%9F%8F%B3%EF%B8%8F%E2%80%8D%F0%9F%8C%88/%E5%86%B0%E6%B7%87%E6%B7%8B"
        #expect(emojiURL?.absoluteString == emojiURLEncoded)
        #expect(emojiURL?.host(percentEncoded: false) == "xn--itacos-i50d.ws")

        let chineseURL = URL(string: "http://見.香港/热狗/🌭")
        let chineseURLEncoded = "http://xn--nw2a.xn--j6w193g/%E7%83%AD%E7%8B%97/%F0%9F%8C%AD"
        #expect(chineseURL?.absoluteString == chineseURLEncoded)
        #expect(chineseURL?.host(percentEncoded: false) == "xn--nw2a.xn--j6w193g")
    }
    
    @Test func componentsUnixDomainSocketOverWebSocketScheme() {
        var comp = URLComponents()
        comp.scheme = "ws+unix"
        comp.host = "/path/to/socket"
        comp.path = "/info"
        #expect(comp.string == "ws+unix://%2Fpath%2Fto%2Fsocket/info")
        
        comp.scheme = "wss+unix"
        #expect(comp.string == "wss+unix://%2Fpath%2Fto%2Fsocket/info")
        
        comp.encodedHost = "%2Fpath%2Fto%2Fsocket"
        #expect(comp.string == "wss+unix://%2Fpath%2Fto%2Fsocket/info")
        #expect(comp.encodedHost == "%2Fpath%2Fto%2Fsocket")
        #expect(comp.host == "/path/to/socket")
        #expect(comp.path == "/info")
        
        // "/path/to/socket" is not a valid host for schemes
        // that IDNA-encode hosts instead of percent-encoding
        comp.scheme = "ws"
        #expect(comp.string == nil)
        
        comp.scheme = "wss"
        #expect(comp.string == nil)
        
        comp.scheme = "wss+unix"
        #expect(comp.string == "wss+unix://%2Fpath%2Fto%2Fsocket/info")
        
        // Check that we can parse a percent-encoded ws+unix URL string
        comp = URLComponents(string: "ws+unix://%2Fpath%2Fto%2Fsocket/info")!
        #expect(comp.encodedHost == "%2Fpath%2Fto%2Fsocket")
        #expect(comp.host == "/path/to/socket")
        #expect(comp.path == "/info")
    }
    
    @Test func componentsUnixDomainSocketOverHTTPScheme() {
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
    
    @Test func encodedAbsoluteString() throws {
        let base = URL(string: "http://user name:pass word@😂😂😂.com/pa th/p?qu ery#frag ment")
        #expect(base?.absoluteString == "http://user%20name:pass%20word@xn--g28haa.com/pa%20th/p?qu%20ery#frag%20ment")
        var url = URL(string: "relative", relativeTo: base)
        #expect(url?.absoluteString == "http://user%20name:pass%20word@xn--g28haa.com/pa%20th/relative")
        url = URL(string: "rela tive", relativeTo: base)
        #expect(url?.absoluteString == "http://user%20name:pass%20word@xn--g28haa.com/pa%20th/rela%20tive")
        url = URL(string: "relative?qu", relativeTo: base)
        #expect(url?.absoluteString == "http://user%20name:pass%20word@xn--g28haa.com/pa%20th/relative?qu")
        url = URL(string: "rela tive?q u", relativeTo: base)
        #expect(url?.absoluteString == "http://user%20name:pass%20word@xn--g28haa.com/pa%20th/rela%20tive?q%20u")
        
        let fileBase = URL(filePath: "/Users/foo bar/more spaces/")
        #expect(fileBase.absoluteString == "file:///Users/foo%20bar/more%20spaces/")
        
        url = URL(string: "relative", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/relative")
        #expect(url?.path == "/Users/foo bar/more spaces/relative")
        
        url = URL(string: "rela tive", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/rela%20tive")
        #expect(url?.path == "/Users/foo bar/more spaces/rela tive")
        
        // URL(string:) should count ? as the query delimiter
        url = URL(string: "relative?query", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/relative?query")
        #expect(url?.path == "/Users/foo bar/more spaces/relative")
        
        url = URL(string: "rela tive?qu ery", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/rela%20tive?qu%20ery")
        #expect(url?.path == "/Users/foo bar/more spaces/rela tive")
        
        // URL(filePath:) should encode ? as part of the path
        url = URL(filePath: "relative?query", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/relative%3Fquery")
        #expect(url?.path == "/Users/foo bar/more spaces/relative?query")
        
        url = URL(filePath: "rela tive?qu ery", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/rela%20tive%3Fqu%20ery")
        #expect(url?.path == "/Users/foo bar/more spaces/rela tive?qu ery")
        
        // URL(filePath:) should encode %3F as part of the path
        url = URL(filePath: "relative%3Fquery", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/relative%253Fquery")
        #expect(url?.path == "/Users/foo bar/more spaces/relative%3Fquery")
        
        url = URL(filePath: "rela tive%3Fqu ery", relativeTo: fileBase)
        #expect(url?.absoluteString == "file:///Users/foo%20bar/more%20spaces/rela%20tive%253Fqu%20ery")
        #expect(url?.path == "/Users/foo bar/more spaces/rela tive%3Fqu ery")
    }
}
