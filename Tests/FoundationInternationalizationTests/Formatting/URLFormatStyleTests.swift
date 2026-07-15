//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationInternationalization)
@testable import FoundationEssentials
@testable import FoundationInternationalization
#else
@testable import Foundation
#endif

@Suite("URL.FormatStyle")
private struct URLFormatStyleTests {
    @Test func defaultFormatStyle() {
        let style = URL.FormatStyle()
        // Scheme is always visible
        verify("https://www.pomegranate.com", matches: "https://www.pomegranate.com", withStyle: style)
        verify("http://www.peach.com", matches: "http://www.peach.com", withStyle: style)
        verify("ssh://www.banana.com", matches: "ssh://www.banana.com", withStyle: style)
        // Authoirty is always omitted
        verify("https://charles:pswd@cherry.com", matches: "https://cherry.com", withStyle: style)
        verify("http://tim:pssd@orange.com", matches: "http://orange.com", withStyle: style)
        verify("ftp://dev:pswd@strawberry.com", matches: "ftp://strawberry.com", withStyle: style)
        // Host is always visible
        verify("https://docs.code.lychee.com", matches: "https://docs.code.lychee.com", withStyle: style)
        verify("ftp://vault.kiwi.com", matches: "ftp://vault.kiwi.com", withStyle: style)
        // Port is omitted for HTTP family
        verify("https://www.blueberry.com:1234", matches: "https://www.blueberry.com", withStyle: style)
        verify("http://www.raspberry.com:4242", matches: "http://www.raspberry.com", withStyle: style)
        verify("safari://www.pineapple.com:9876", matches: "safari://www.pineapple.com:9876", withStyle: style)
        // Path is always visible
        verify("https://www.lemon.com/api/v2", matches: "https://www.lemon.com/api/v2", withStyle: style)
        verify("music://www.lime.com/api/v3", matches: "music://www.lime.com/api/v3", withStyle: style)
        // Query is always omitted
        verify("https://mango.com/search?color=red", matches: "https://mango.com/search", withStyle: style)
        verify("photos://melon.com/find?size=large", matches: "photos://melon.com/find", withStyle: style)
        // Fragment is always omitted
        verify("https://grapes.com/path#history", matches: "https://grapes.com/path", withStyle: style)
        verify("apps://plums.com/path#development", matches: "apps://plums.com/path", withStyle: style)
        // Put everything together
        verify("https://charles:pswd@apple.com/search?name=iMac#specs", matches: "https://apple.com/search", withStyle: style)
    }

    @Test func hostFormatting() {
        // Test displayed style
        var style = URL.FormatStyle().scheme(.omitIfHTTPFamily).host(.always)
        verify("https://www.apple.com", matches: "www.apple.com", withStyle: style)
        style = style.host(.displayWhen(.scheme, matches: ["http", "https"]))
        verify("ftp://www.apple.com", matches: "ftp:", withStyle: style)
        // Test omitted style
        style = style.host(.never)
        verify("ftp://www.apple.com", matches: "ftp:", withStyle: style)
        style = style.host(.omitIfHTTPFamily)
        verify("ftp://www.apple.com", matches: "ftp://www.apple.com", withStyle: style)
        // Default style for scheme is .omitIfHTTPFamily
        verify("https://www.apple.com/path", matches: "/path", withStyle: style)
        // Test omitMultiLevelSubdomains (requires TLD detection, framework only)
#if FOUNDATION_FRAMEWORK
        style = style.host(.omitSpecificSubdomains([], includeMultiLevelSubdomains: true))
        verify("https://docs.api.code.apple.com.cn", matches: "code.apple.com.cn", withStyle: style)
#endif
        style = style.host(.omitSpecificSubdomains([], includeMultiLevelSubdomains: true, when: .scheme, matches: ["http", "https"]))
        verify("ftp://a.b.c.d.apple.com", matches: "ftp://a.b.c.d.apple.com", withStyle: style)
        // Test omitSpecificDomains
        style = style.host(.omitSpecificSubdomains(["www", "mobile", "m"]))
        verify("https://mobile.apple.com", matches: "apple.com", withStyle: style)
        verify("https://www.apple.com", matches: "apple.com", withStyle: style)
        verify("https://m.apple.com", matches: "apple.com", withStyle: style)
        verify("https://mobile.com", matches: "mobile.com", withStyle: style)
        verify("https://m.mobile.apple.com", matches: "mobile.apple.com", withStyle: style)
        verify("https://dev.apple.com", matches: "dev.apple.com", withStyle: style)
        style = style.host(.omitSpecificSubdomains(["www", "charles", "mobile"], when: .scheme, matches: ["http", "https"]))
        verify("https://charles.hu.codes", matches: "hu.codes", withStyle: style)
        verify("ftp://mobile.apple.com", matches: "ftp://mobile.apple.com", withStyle: style)
        // Test ip addresses
        verify("https://192.168.0.30", matches: "192.168.0.30", withStyle: style)
        verify("https://[2620:100:e000::8001]/search", matches: "[2620:100:e000::8001]/search", withStyle: style)
        style = style.host(.omitSpecificSubdomains(["192", "168"], includeMultiLevelSubdomains: true))
        // IP address should not be modified
        verify("https://192.168.0.255/path", matches: "192.168.0.255/path", withStyle: style)
        style = style.host(.omitSpecificSubdomains(["2620", "100"], includeMultiLevelSubdomains: true))
        verify("https://[2620:100:e000::8001]/search", matches: "[2620:100:e000::8001]/search", withStyle: style)
    }

    @Test func componentCondition() {
        // When there's no condition, the ComponentStyle is applied as it is
        var style: URL.FormatStyle = .init(scheme: .never)
        verify("https://www.apple.com", matches: "www.apple.com", withStyle: style)
        verify("ssh://www.pear.com", matches: "www.pear.com", withStyle: style)
        style = .init(scheme: .always)
        verify("https://www.plums.com", matches: "https://www.plums.com", withStyle: style)
        verify("ftp://www.melon.com", matches: "ftp://www.melon.com", withStyle: style)
        // Constraint the style to only apply to HTTP family of URLs
        style = .init(scheme: .omitIfHTTPFamily)
        verify("https://www.mango.com", matches: "www.mango.com", withStyle: style)
        verify("http://www.cherry.com", matches: "www.cherry.com", withStyle: style)
        verify("ftp://www.kiwi.com", matches: "ftp://www.kiwi.com", withStyle: style)
        style = .init(scheme: .displayWhen(.scheme, matches: ["http", "https"]))
        verify("https://www.lemon.com", matches: "https://www.lemon.com", withStyle: style)
        verify("http://www.lime.com", matches: "http://www.lime.com", withStyle: style)
        verify("mailto://www.pinapple.com", matches: "www.pinapple.com", withStyle: style)
        // Contraint the style to specific schemes
        style = .init(scheme: .omitWhen(.scheme, matches: ["music", "tv", "chocolate"]))
        verify("https://www.peach.com", matches: "https://www.peach.com", withStyle: style)
        verify("music://www.banana.com", matches: "www.banana.com", withStyle: style)
        verify("tv://www.watermelon.com", matches: "www.watermelon.com", withStyle: style)
        verify("chocolate://www.strawberry.com", matches: "www.strawberry.com", withStyle: style)
        style = .init(scheme: .displayWhen(.scheme, matches: ["music", "tv", "chocolate"]))
        verify("https://www.blueberry.com", matches: "www.blueberry.com", withStyle: style)
        verify("music://www.raspberry.com", matches: "music://www.raspberry.com", withStyle: style)
        verify("tv://www.orange.com", matches: "tv://www.orange.com", withStyle: style)
        verify("chocolate://www.lychee.com", matches: "chocolate://www.lychee.com", withStyle: style)
    }

    @Test func formatStyleFromLinkPresentation() {
        // Tests stolen from LinkPresentation to make sure we produce the same result
        let standard: URL.FormatStyle = .init(
            scheme: .omitWhen(.scheme, matches: ["http"]), query: .never, fragment: .never)
        verify("http://www.apple.com", matches: "www.apple.com", withStyle: standard)
        verify("http://www.apple.com/", matches: "www.apple.com", withStyle: standard)
        verify("http://apple.com/", matches: "apple.com", withStyle: standard);
        verify("http://www.apple.com/iPhone/", matches: "www.apple.com/iPhone", withStyle: standard)
        verify("https://www.apple.com", matches: "https://www.apple.com", withStyle: standard)
        verify("https://www.apple.com/", matches: "https://www.apple.com", withStyle: standard)
        verify("https://www.apple.com/iPhone/", matches: "https://www.apple.com/iPhone", withStyle: standard)
        verify("ftp:/", matches: "ftp:", withStyle: standard)
        verify("ftp:/Volumes/", matches: "ftp:/Volumes", withStyle: standard)

        var style = standard.scheme(.omitIfHTTPFamily)
        verify("https://www.apple.com/", matches: "www.apple.com", withStyle: style)

        style = style.scheme(.always)
            .user(.always)
            .host(.omitSpecificSubdomains(["www"]))
        verify("http://www.apple.com/", matches: "http://apple.com", withStyle: style);
        verify("http://m.cnn.com/", matches: "http://m.cnn.com", withStyle: style);
        verify("ftp://www.apple.com/", matches: "ftp://apple.com", withStyle: style);
        verify("http://www.@apple.com/", matches: "http://www.@apple.com", withStyle: style);
        verify("http://www.com/", matches: "http://www.com", withStyle: style);

        style = style.scheme(.always)
            .host(.always)
            .path(.omitIfHTTPFamily)
            .query(.omitIfHTTPFamily)
            .fragment(.omitIfHTTPFamily)
        verify("http://www.apple.com/mac", matches: "http://www.apple.com", withStyle: style);
        verify("file:/", matches: "file:", withStyle: style);
        verify("file:/etc/asl", matches: "file:/etc/asl", withStyle: style);

        style = style.user(.always)
            .password(.always)
            .port(.omitIfHTTPFamily)
            .path(.always)
        verify(
            "http://www.apple.com:81/imac",
            matches: "http://www.apple.com/imac", withStyle: style)
        verify(
            "feed://www.apple.com:81/imac",
            matches: "feed://www.apple.com:81/imac", withStyle: style)
        verify(
            "http://[2620:100:e000::8001]:81/US",
            matches: "http://[2620:100:e000::8001]/US", withStyle: style)
        verify(
            "http://[2620:100:e000::8001]/US",
            matches: "http://[2620:100:e000::8001]/US", withStyle: style)
        verify(
            "http://someone:something@[2620:100:e000::8001]/US",
            matches: "http://someone:something@[2620:100:e000::8001]/US", withStyle: style)

        style = style.host(.omitSpecificSubdomains(["m"], when: .scheme, matches: ["http", "https"]))
        verify("http://www.apple.com/", matches: "http://www.apple.com", withStyle: style);
        verify("http://m.cnn.com/", matches: "http://cnn.com", withStyle: style);
        verify("ftp://m.cnn.com/", matches: "ftp://m.cnn.com", withStyle: style);
        verify("http://m.@cnn.com/", matches: "http://m.@cnn.com", withStyle: style);
        verify("http://m.edu/", matches: "http://m.edu", withStyle: style);

        style = style.host(.omitSpecificSubdomains(["m", "mobile", "www"], when: .scheme, matches: ["http", "https"]))
        verify("http://www.m.cnn.com/", matches: "http://m.cnn.com", withStyle: style)
        verify("http://mobile.twitter.com/", matches: "http://twitter.com", withStyle: style)
        verify("http://www.twitter.com/", matches: "http://twitter.com", withStyle: style)
        verify("http://mobile.twitter.com/", matches: "http://twitter.com", withStyle: style)
        verify("ftp://mobile.twitter.com/", matches: "ftp://mobile.twitter.com", withStyle: style)
        verify("http://mobile.@cnn.com/", matches: "http://mobile.@cnn.com", withStyle: style)
        verify("http://mobile.edu/", matches: "http://mobile.edu", withStyle: style)
        verify("http://www.mobile.twitter.com/", matches: "http://mobile.twitter.com", withStyle: style)
        verify("http://m.mobile.twitter.com/", matches: "http://mobile.twitter.com", withStyle: style)
        verify("http://mobile.m.twitter.com/", matches: "http://m.twitter.com", withStyle: style)

        style = style.host(.always)
            .path(.never).query(.never).fragment(.never)
        verify("http://www.youtube.com/", matches: "http://www.youtube.com", withStyle: style)
        verify("http://www.youtube.com/?", matches: "http://www.youtube.com", withStyle: style)
        verify("http://www.youtube.com/?v=", matches: "http://www.youtube.com", withStyle: style)
        verify("http://www.youtube.com/?#", matches: "http://www.youtube.com", withStyle: style)
        verify("http://www.youtube.com/?#fragment", matches: "http://www.youtube.com", withStyle: style)
        verify("http://www.youtube.com/#fragment", matches: "http://www.youtube.com", withStyle: style)

        style = style.scheme(.always)
            .user(.omitIfHTTPFamily)
            .password(.omitIfHTTPFamily)
            .path(.always)
            .port(.omitIfHTTPFamily)
        verify("http://apple.com................@google.com/", matches: "http://google.com", withStyle: style)
        verify("http://apple.com................@google.com", matches: "http://google.com", withStyle: style)
        verify("http://apple.com@google.com/", matches: "http://google.com", withStyle: style)
        verify("http://someone:something@[2620:100:e000::8001]/US", matches: "http://[2620:100:e000::8001]/US", withStyle: style)
        verify("http://someone:something@192.168.1.1/US", matches: "http://192.168.1.1/US", withStyle: style)
        verify("http://someone@", matches: "http:", withStyle: style)
        verify("http://someone:something@", matches: "http:", withStyle: style)
        verify("http://@google.com", matches: "http://google.com", withStyle: style)

        // Multi-level subdomain stripping requires TLD detection (framework only)
#if FOUNDATION_FRAMEWORK
        style = standard.host(.omitSpecificSubdomains(["m", "mobile", "www"], includeMultiLevelSubdomains: true))
        verify("http://a.b.c.d.e.com", matches: "d.e.com", withStyle: style)
        verify("http://apple.com.a.a.a.a.a.a.a.a.a.a.evil.com", matches: "a.evil.com", withStyle: style)
        verify("http://g.com", matches: "g.com", withStyle: style)
        verify("http://f.g.com", matches: "f.g.com", withStyle: style)
        verify("http://e.f.g.com", matches: "f.g.com", withStyle: style)
        verify("http://www.com", matches: "www.com", withStyle: style)
        verify("http://www.a.com", matches: "a.com", withStyle: style)
        verify("http://www.a.b.com", matches: "a.b.com", withStyle: style)
        verify("http://a.www.b.com", matches: "b.com", withStyle: style)
        verify("http://a.www.B.com", matches: "B.com", withStyle: style)
        verify("http://m.com", matches: "m.com", withStyle: style)
        verify("http://m.a.com", matches: "a.com", withStyle: style)
        verify("http://m.a.b.com", matches: "a.b.com", withStyle: style)
        verify("http://a.m.b.com", matches: "b.com", withStyle: style)
        verify("http://m.www.apple.com", matches: "apple.com", withStyle: style)
        verify("http://www.m.apple.com", matches: "apple.com", withStyle: style)
        verify("http://www.mobile.twitter.com", matches: "twitter.com", withStyle: style)
        verify("http://m.mobile.twitter.com", matches: "twitter.com", withStyle: style)
        verify("http://mobile.m.twitter.com", matches: "twitter.com", withStyle: style)
        verify("http://mobile.com", matches: "mobile.com", withStyle: style)
#endif
    }

    @Test func lookalikeCharacters() {
        // Display all components
        let style = URL.FormatStyle(
            scheme: .always, user: .always, password: .always,
            host: .always, port: .always, path: .always,
            query: .always, fragment: .always)
        // "Normal" (not lookalike) Unicode characters
        // should be displayed verbatim
        verify(
            "https://👁👄👁.fm",
            matches: "https://👁👄👁.fm", withStyle: style)
        verify(
            "http://見.香港/热狗/🌭",
            matches: "http://見.香港/热狗/🌭", withStyle: style)
        verify(
            "https://🤙🏻:🏳️‍🌈@🐮.臺灣.இலங்கை:1234/🥗?name=δοκιμή#😉",
            matches: "https://🤙🏻:🏳️‍🌈@🐮.臺灣.இலங்கை:1234/🥗?name=δοκιμή#😉",
            withStyle: style)
        // If the host contains lookalike characters, we should
        // display Punycode instead
        verify(
            "http://аррІе.com/", // NOT apple.com
            matches: "http://xn--80ak6aa4i.com", withStyle: style)
        verify(
            "http://gooِgle.com/", // also NOT google.com
            matches: "http://xn--google-yri.com", withStyle: style)

        // Stolen from LinkPresentation:
        // These strings contain lookalike characters, therefore
        // we should display Punycode instead
        let punycodeSpoofTests: [(url: String, output: String)] = [
            (url: "https://ı̇/", output: "https://xn--cfa45g"),
            (url: "https://ȷ̇/", output: "https://xn--tma03b"),
            (url: "https://ᴄ/", output: "https://xn--u7f"),
            (url: "https://ᴏ/", output: "https://xn--57f"),
            (url: "https://ꜱ/", output: "https://xn--i38a"),
            (url: "https://ᴜ/", output: "https://xn--j8f"),
            (url: "https://ᴠ/", output: "https://xn--n8f"),
            (url: "https://ᴡ/", output: "https://xn--o8f"),
            (url: "https://ᴢ/", output: "https://xn--p8f"),
            (url: "https://ɡ/", output: "https://xn--0na"),
            (url: "https://cnո/", output: "https://xn--cn-ded"),
            (url: "https://ոews.org/", output: "https://xn--ews-nfe.org"),
            (url: "https://yoսtube/", output: "https://xn--yotube-qkh"),
            (url: "https://սcla.edu/", output: "https://xn--cla-7fe.edu"),
            (url: "https://ו̇/", output: "https://xn--rsa94l"),
            (url: "https://וֹ/", output: "https://xn--hdb9c"),
            (url: "https://וֺ/", output: "https://xn--idb7c"),
            (url: "https://וׁ/", output: "https://xn--pdb3b"),
            (url: "https://וׂ/", output: "https://xn--qdb1b"),
            (url: "https://וׄ/", output: "https://xn--sdb7a"),
            (url: "https://ɾ/", output: "https://xn--uoa"),
            (url: "https://ǀ/", output: "https://xn--fja"),
            (url: "https://ɴ/", output: "https://xn--koa"),
            (url: "https://ȷ/", output: "https://xn--tma"),
            (url: "https://օo/", output: "https://xn--o-pdc"),
            (url: "https://oօ/", output: "https://xn--o-qdc"),
            (url: "https://ցg/", output: "https://xn--g-hdc"),
            (url: "https://gց/", output: "https://xn--g-idc"),
            (url: "https://௦o/", output: "https://xn--o-00e"),
            (url: "https://o௦/", output: "https://xn--o-10e"),
            (url: "https://gotՑԵՃ.com", output: "https://xn--got-kde4e2d.com"),
            (url: "mailto:someone@.xn--4dbacpta7bzbn3a.com", output: "mailto:someone@.xn--4dbacpta7bzbn3a.com"),
            (url: "mailto:someone@.xn--4dbacpta7bzbn3a.com?subjectsomething", output: "mailto:someone@.xn--4dbacpta7bzbn3a.com?subjectsomething"),
            (url: "http://xn--nwstrfn-5fg5byy.com", output: "http://xn--nwstrfn-5fg5byy.com"),
            (url: "http://xn--google-yri.com", output: "http://xn--google-yri.com"),
            (url: "https://xn--apple-gkh.com", output: "https://xn--apple-gkh.com"),
            (url: "http://gooِgle.com", output: "http://xn--google-yri.com"),
            (url: "http://xn--cfa45g", output: "http://xn--cfa45g"),
            (url: "http://xn--tma03b", output: "http://xn--tma03b"),
            (url: "http://xn--u7f", output: "http://xn--u7f"),
            (url: "http://xn--57f", output: "http://xn--57f"),
            (url: "http://xn--i38a", output: "http://xn--i38a"),
            (url: "http://xn--j8f", output: "http://xn--j8f"),
            (url: "http://xn--n8f", output: "http://xn--n8f"),
            (url: "http://xn--o8f", output: "http://xn--o8f"),
            (url: "http://xn--p8f", output: "http://xn--p8f"),
            (url: "http://xn--0na", output: "http://xn--0na"),
            (url: "http://xn--cn-ded", output: "http://xn--cn-ded"),
            (url: "http://xn--ews-nfe.org", output: "http://xn--ews-nfe.org"),
            (url: "http://xn--yotube-qkh", output: "http://xn--yotube-qkh"),
            (url: "http://xn--cla-7fe.edu", output: "http://xn--cla-7fe.edu"),
            (url: "http://nеwstаrfіn.com/", output: "http://xn--nwstrfn-5fg5byy.com"),
            (url: "http://gooِgle.com/", output: "http://xn--google-yri.com"),
            (url: "https://appِle.com/", output: "https://xn--apple-gkh.com"),
            (url: "https://xn--a-g4i", output: "https://xn--a-g4i"),
            (url: "https://xn--a-h4i", output: "https://xn--a-h4i"),
            (url: "https://xn--a-80i", output: "https://xn--a-80i"),
            (url: "https://xn--a-90i", output: "https://xn--a-90i"),
            (url: "https://xn--a-0fj", output: "https://xn--a-0fj"),
            (url: "https://xn--a-1fj", output: "https://xn--a-1fj"),
            (url: "https://xn--a-2fj", output: "https://xn--a-2fj"),
            (url: "https://xn--a-3fj", output: "https://xn--a-3fj"),
            (url: "https://xn--a-rli", output: "https://xn--a-rli"),
            (url: "https://xn--a-sli", output: "https://xn--a-sli"),
            (url: "https://xn--a-vli", output: "https://xn--a-vli"),
            (url: "https://xn--a-wli", output: "https://xn--a-wli"),
            (url: "https://xn--a-1li", output: "https://xn--a-1li"),
            (url: "https://xn--a-2li", output: "https://xn--a-2li"),
            (url: "https://xn--a-8oi", output: "https://xn--a-8oi"),
            (url: "https://xn--a-9oi", output: "https://xn--a-9oi"),
            (url: "https://xn--a-v1i", output: "https://xn--a-v1i"),
            (url: "https://xn--a-w1i", output: "https://xn--a-w1i"),
            (url: "https://xn--a-f5i", output: "https://xn--a-f5i"),
            (url: "https://xn--a-g5i", output: "https://xn--a-g5i"),
            (url: "https://xn--a-u6i", output: "https://xn--a-u6i"),
            (url: "https://xn--a-v6i", output: "https://xn--a-v6i"),
            (url: "https://xn--a-h7i", output: "https://xn--a-h7i"),
            (url: "https://xn--a-i7i", output: "https://xn--a-i7i"),
            (url: "https://xn--a-x7i", output: "https://xn--a-x7i"),
            (url: "https://xn--a-y7i", output: "https://xn--a-y7i"),
            (url: "https://xn--a-37i", output: "https://xn--a-37i"),
            (url: "https://xn--a-47i", output: "https://xn--a-47i"),
            (url: "https://xn--n-twf", output: "https://xn--n-twf"),
            (url: "https://xn--n-uwf", output: "https://xn--n-uwf"),
            (url: "https://xn--jna", output: "https://xn--jna"),
            (url: "https://xn--spa", output: "https://xn--spa"),
            (url: "https://xn--8pa", output: "https://xn--8pa"),
            (url: "https://xn--3hb112n", output: "https://xn--3hb112n"),
            (url: "https://xn--a-ypc062v", output: "https://xn--a-ypc062v"),
            (url: "https://xn--2j8c", output: "https://xn--2j8c"),  // U+1043D
            (url: "https://xn--ikg", output: "https://xn--ikg"),    // U+1E9C
            (url: "https://xn--jkg", output: "https://xn--jkg"),    // U+1E9D
            (url: "https://xn--cng", output: "https://xn--cng")     // U+1EFE or U+1EFF
        ]
        for spoofTest in punycodeSpoofTests {
            verify(spoofTest.url, matches: spoofTest.output, withStyle: style)
        }

        // These are valid Unicode characters. We should display
        // them verbatim
        let validUnicodeTests = [
            "http://site.com",
            "http://臺灣.இலங்கை",
            "mailto:someone@example.org",
            "mailto:someone@xn--4dbacpta7bzbn3a.com",
            "mailto:someone@xn--4dbacpta7bzbn3a.com?subjectsomething",
            "http://site.com/sub",
            "http://site.com/sub#fragment",
            "http://site.com#fragment/sub",
            "https://en.wikipedia.org/wiki/.հայ",
            "https://ճմո.հայ",
            "https://ճ-1-մո.հայ",
            "https://2ճ_մո.հայ",
            "https://ճ_մ垃.հայ",
            // Valid mixtures of Armenian and other scripts
            "https://en.wikipedia.org/wiki/.հայ",
            "https://ճմո.հայ",
            "https://ճ-1-մո.հայ",
            "https://2ճ_մո.հայ",
            "https://ճ_մ垃.հայ",
            "https://ցեճfans.net",
            // Tamil
            "https://௦௧௨௩count",
            // Canadian aboriginal
            "https://ᖯᐁabc",
            "https://ᖴᐁabc",
            "https://᙭ᐁabc",
            "https://᙮ᐁabc",
            "https://ᑭᐁabc",
            "https://ᑯᐁabc",
            "https://ᑲᐁabc",
            "https://ᒪᐁabc",
            "https://ᕼᐁabc",
            "https://ᖇᐁabc",
            "https://ᗅᐁabc",
            "https://ᗞᐁabc",
            "https://ᗩᐁabc",
            "https://ᗱᐁabc",
            "https://ᗴᐁabc",
            "https://íabc",
            // Thai
            "https://กขabc",
            // Arabic
            "https://تفاح"
        ]
        for validTest in validUnicodeTests {
            verify(validTest, matches: validTest, withStyle: style)
        }

        // These Unicode characters should still be displayed after
        // some transformation
        let validEncodedUnicodeTests = [
            // Needs to be lower cased
            (url: "https://ՑԵorյՃ.biz", output: "https://ցեorյճ.biz"),
            (url: "https://ճԵorյՃ.biz", output: "https://ճեorյճ.biz"),
            (url: "https://ձԵՃfans.net", output: "https://ձեճfans.net"),
            (url: "https://ՑԵՃfans.net", output: "https://ցեճfans.net"),
            // Needs to be decoded
            (url: "http://%77ebsite.com", output: "http://website.com"),
            (url: "http://xn--4dbacpta7bzbn3a.com", output: "http://אייפוןבארץ.com"),
            (url: "http://xn--sailor-183m.com", output: "http://sailor月.com"),
            (url: "http://xn--d1abbgf6aiiy.xn--p1ai", output: "http://президент.рф"),
            (url: "http://xn--b1aaebccb4c.xn--d1abbgf6aiiy.xn--p1ai", output: "http://медведев.президент.рф"),
            (url: "http://%E5%BC%95%E3%81%8D%E5%89%B2%E3%82%8A.jp", output: "http://引き割り.jp"),
            (url: "https://maps.apple.com/?address=Carrer%20de%20Par%C3%ADs,%20114,%2008029%20Barcelona,%20Spain&auid=742406409215325628&ll=41.388445,2.146888&lsp=9902&q=Sant%20Jordi%20Swimming%20Pool&_ext=ChoKBQgEEM4BCgQIBRADCgUIBhCnAQoECAoQABIkKR6C/fovpkRAMUBsY44HNwBAOSzmKw09vURAQYCTnBGgIgJA&t=m", output: "https://maps.apple.com/?address=Carrer de París, 114, 08029 Barcelona, Spain&auid=742406409215325628&ll=41.388445,2.146888&lsp=9902&q=Sant Jordi Swimming Pool&_ext=ChoKBQgEEM4BCgQIBRADCgUIBhCnAQoECAoQABIkKR6C/fovpkRAMUBsY44HNwBAOSzmKw09vURAQYCTnBGgIgJA&t=m"),
            (url: "https://en.wikipedia.org/wiki/Mission_San_Francisco_de_As%C3%ADs", output: "https://en.wikipedia.org/wiki/Mission_San_Francisco_de_Asís"),
        ]
        for encodedUnicodeTest in validEncodedUnicodeTests {
            verify(encodedUnicodeTest.url, matches: encodedUnicodeTest.output, withStyle: style)
        }
    }

    private func verify(_ urlString: String, matches expectedOutput: String, withStyle style: URL.FormatStyle, sourceLocation: SourceLocation = #_sourceLocation) {
        // Use a URLComponents to create the URL in case it has Unicode characters
        let urlComponents = URLComponents(string: urlString)
        let url = urlComponents!.url!
        let output = url.formatted(style)
        #expect(
            output == expectedOutput,
            "Expecting [\(expectedOutput)], got [\(output)]",
            sourceLocation: sourceLocation)
    }
}
