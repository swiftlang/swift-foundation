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

@Suite("URL UIDNA")
private struct URLUIDNATests {
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
}
