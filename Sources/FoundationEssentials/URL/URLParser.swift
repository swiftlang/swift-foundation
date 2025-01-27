//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
#endif

// Source of truth for a parsed URL
final class URLParseInfo: Sendable {
    let urlString: String
    let urlParser: URLParserKind

    let schemeRange:    Range<String.Index>?
    let userRange:      Range<String.Index>?
    let passwordRange:  Range<String.Index>?
    let hostRange:      Range<String.Index>?
    let portRange:      Range<String.Index>?
    let pathRange:      Range<String.Index>?
    let queryRange:     Range<String.Index>?
    let fragmentRange:  Range<String.Index>?

    let isIPLiteral: Bool
    let didPercentEncodeHost: Bool
    let pathHasPercent: Bool
    let pathHasFileID: Bool

    init(urlString: String, urlParser: URLParserKind, schemeRange: Range<String.Index>?, userRange: Range<String.Index>?, passwordRange: Range<String.Index>?, hostRange: Range<String.Index>?, portRange: Range<String.Index>?, pathRange: Range<String.Index>?, queryRange: Range<String.Index>?, fragmentRange: Range<String.Index>?, isIPLiteral: Bool, didPercentEncodeHost: Bool, pathHasPercent: Bool, pathHasFileID: Bool) {
        self.urlString = urlString
        self.urlParser = urlParser
        self.schemeRange = schemeRange
        self.userRange = userRange
        self.passwordRange = passwordRange
        self.hostRange = hostRange
        self.portRange = portRange
        self.pathRange = pathRange
        self.queryRange = queryRange
        self.fragmentRange = fragmentRange
        self.isIPLiteral = isIPLiteral
        self.didPercentEncodeHost = didPercentEncodeHost
        self.pathHasPercent = pathHasPercent
        self.pathHasFileID = pathHasFileID
    }

    var hasAuthority: Bool {
        return userRange != nil || passwordRange != nil || hostRange != nil || portRange != nil
    }

    var scheme: Substring? {
        guard let schemeRange else {
            return nil
        }
        return urlString[schemeRange]
    }

    var user: Substring? {
        guard let userRange else {
            return nil
        }
        return urlString[userRange]
    }

    var password: Substring? {
        guard let passwordRange else {
            return nil
        }
        return urlString[passwordRange]
    }

    var host: Substring? {
        guard let hostRange else {
            return nil
        }
        return urlString[hostRange]
    }

    var portString: Substring? {
        guard let portRange else {
            return nil
        }
        return urlString[portRange]
    }

    var port: Int? {
        guard let portString else {
            return nil
        }
        return Int(portString)
    }

    var path: Substring {
        guard let pathRange else {
            return ""
        }
        return urlString[pathRange]
    }

    var query: Substring? {
        guard let queryRange else {
            return nil
        }
        return urlString[queryRange]
    }

    var fragment: Substring? {
        guard let fragmentRange else {
            return nil
        }
        return urlString[fragmentRange]
    }
}

fileprivate struct URLBufferParseInfo {
    typealias URLBuffer = UnsafeBufferPointer<UInt8>

    var schemeRange:    Range<URLBuffer.Index>?
    var userRange:      Range<URLBuffer.Index>?
    var passwordRange:  Range<URLBuffer.Index>?
    var hostRange:      Range<URLBuffer.Index>?
    var portRange:      Range<URLBuffer.Index>?
    var pathRange:      Range<URLBuffer.Index>?
    var queryRange:     Range<URLBuffer.Index>?
    var fragmentRange:  Range<URLBuffer.Index>?

    var isIPLiteral: Bool = false
    var didPercentEncodeHost: Bool = false
    var pathHasPercent: Bool = false
    var pathHasFileID: Bool = false
}

internal enum URLParserKind {
    case RFC3986
}

internal struct URLParserCompatibility: OptionSet {
    let rawValue: UInt8
    static let allowEmptyScheme = URLParserCompatibility(rawValue: 1 << 0)
    static let allowAnyPort = URLParserCompatibility(rawValue: 1 << 1)
}

internal protocol URLParserProtocol {
    static var kind: URLParserKind { get }

    static func parse(urlString: String, encodingInvalidCharacters: Bool) -> URLParseInfo?
    static func parse(urlString: String, encodingInvalidCharacters: Bool, compatibility: URLParserCompatibility) -> URLParseInfo?

    static func validate(_ string: (some StringProtocol)?, component: URLComponents.Component) -> Bool
    static func validate(_ string: (some StringProtocol)?, component: URLComponents.Component, percentEncodingAllowed: Bool) -> Bool

    static func percentEncode(_ string: (some StringProtocol)?, component: URLComponents.Component) -> String?
    static func percentDecode(_ string: (some StringProtocol)?) -> String?
    static func percentDecode(_ string: (some StringProtocol)?, excluding: Set<UInt8>) -> String?

    static func shouldPercentEncodeHost(_ host: some StringProtocol, forScheme: (some StringProtocol)?) -> Bool
    static func IDNAEncodeHost(_ host: (some StringProtocol)?) -> String?
    static func IDNADecodeHost(_ host: (some StringProtocol)?) -> String?
}

package protocol UIDNAHook {
    static func encode(_ host: some StringProtocol) -> String?
    static func decode(_ host: some StringProtocol) -> String?
}

#if FOUNDATION_FRAMEWORK && canImport(_FoundationICU)
internal func _uidnaHook() -> UIDNAHook.Type? {
    UIDNAHookICU.self
}
#else
dynamic package func _uidnaHook() -> UIDNAHook.Type? {
    nil
}
#endif

internal struct RFC3986Parser: URLParserProtocol {
    static let kind: URLParserKind = .RFC3986

    // MARK: - Encoding

    static func percentEncode(_ string: (some StringProtocol)?, component: URLComponents.Component) -> String? {
        guard let string else { return nil }
        guard !string.isEmpty else { return "" }
        switch component {
        case .scheme:
            fatalError("Scheme cannot be percent-encoded.")
        case .user:
            return string.addingPercentEncoding(forURLComponent: .user)
        case .password:
            return string.addingPercentEncoding(forURLComponent: .password)
        case .host:
            return percentEncodeHost(string)
        case .port:
            fatalError("Port cannot be percent-encoded.")
        case .path:
            return percentEncodePath(string)
        case .query:
            return string.addingPercentEncoding(forURLComponent: .query)
        case .queryItem:
            return string.addingPercentEncoding(forURLComponent: .queryItem)
        case .fragment:
            return string.addingPercentEncoding(forURLComponent: .fragment)
        }
    }

    static func percentDecode(_ string: (some StringProtocol)?) -> String? {
        return percentDecode(string, excluding: [])
    }

    static func percentDecode(_ string: (some StringProtocol)?, excluding: Set<UInt8>) -> String? {
        guard let string else { return nil }
        guard !string.isEmpty else { return "" }
        return string.removingURLPercentEncoding(excluding: excluding)
    }

    private static let schemesToPercentEncodeHost = Set<String>([
        "tel",
        "telemergencycall",
        "telprompt",
        "callto",
        "facetime",
        "facetime-prompt",
        "facetime-audio",
        "facetime-audio-prompt",
        "imap",
        "pop",
        "addressbook",
        "contact",
        "phasset",
        "http+unix",
        "https+unix",
        "ws+unix",
        "wss+unix",
    ])

    private static func looksLikeIPLiteral(_ host: some StringProtocol) -> Bool {
        let utf8 = host.utf8
        guard utf8.first == UInt8(ascii: "[") else {
            return false
        }
        let lastIndex = utf8.index(utf8.startIndex, offsetBy: utf8.count - 1)
        return utf8[lastIndex] == UInt8(ascii: "]")
    }

    static func shouldPercentEncodeHost(_ host: some StringProtocol, forScheme scheme: (some StringProtocol)?) -> Bool {
        guard _uidnaHook() != nil else {
            // Always percent-encode the host if we can't access UIDNA encoding functions
            return true
        }
        if looksLikeIPLiteral(host) {
            // We should percent-encode IP-literals to handle zone IDs.
            return true
        }
        guard let scheme else {
            return false
        }
        return schemesToPercentEncodeHost.contains(scheme.lowercased())
    }

    private static func percentEncodeIPLiteralHost(_ host: some StringProtocol) -> String? {
        precondition(looksLikeIPLiteral(host))
        let utf8 = host.utf8

        guard let percentIndex = utf8.firstIndex(of: UInt8(ascii: "%")) else {
            // The "%" delimiter and zone ID are the only parts we should be encoding.
            guard validate(host: host, knownIPLiteral: true) else {
                return nil
            }
            return String(host)
        }
        let endBracketIndex = utf8.index(utf8.startIndex, offsetBy: utf8.count - 1)

        // Percent encode the "%" and zone ID
        let percentAndZoneID = host[percentIndex..<endBracketIndex] // No trailing "]"
        let zonePart = percentAndZoneID.addingPercentEncoding(forURLComponent: .hostZoneID)

        return "\(host[..<percentIndex])\(zonePart)]"
    }

    private static func percentEncodeHost(_ host: (some StringProtocol)?) -> String? {
        guard let host else { return nil }
        guard !host.isEmpty else { return "" }
        if looksLikeIPLiteral(host) {
            return percentEncodeIPLiteralHost(host)
        }
        return host.addingPercentEncoding(forURLComponent: .host)
    }

    static func IDNAEncodeHost(_ host: (some StringProtocol)?) -> String? {
        guard let host else { return nil }
        guard !host.isEmpty else { return "" }
        return _uidnaHook()?.encode(host)
    }

    static func IDNADecodeHost(_ host: (some StringProtocol)?) -> String? {
        guard let host else { return nil }
        guard !host.isEmpty else { return "" }
        guard let uidnaHook = _uidnaHook() else { return String(host) }
        return uidnaHook.decode(host)
    }

    private static func percentEncodePath(_ path: some StringProtocol) -> String {
        guard !path.isEmpty else { return "" }
        guard let slashIndex = path.utf8.firstIndex(of: UInt8(ascii: "/")) else {
            return path.addingPercentEncoding(forURLComponent: .pathFirstSegment)
        }
        guard slashIndex != path.startIndex else {
            return path.addingPercentEncoding(forURLComponent: .path)
        }
        let firstSegment = path[..<slashIndex].addingPercentEncoding(forURLComponent: .pathFirstSegment)
        let remaining = path[slashIndex...].addingPercentEncoding(forURLComponent: .path)
        return firstSegment + remaining
    }

    // MARK: - Validation

    static func validate(_ string: (some StringProtocol)?, component: URLComponents.Component) -> Bool {
        guard let string else { return true }
        switch component {
        case .scheme:
            return validate(scheme: string)
        case .user:
            return validate(user: string)
        case .password:
            return validate(password: string)
        case .host:
            return validate(host: string)
        case .port:
            return validate(portString: string)
        case .path:
            return validate(path: string)
        case .query:
            return validate(query: string)
        case .queryItem:
            return validate(queryItemPart: string)
        case .fragment:
            return validate(fragment: string)
        }
    }

    static func validate(_ string: (some StringProtocol)?, component: URLComponents.Component, percentEncodingAllowed: Bool) -> Bool {
        guard let string else { return true }
        switch component {
        case .scheme:
            return validate(scheme: string)
        case .user:
            return validate(user: string, percentEncodingAllowed: percentEncodingAllowed)
        case .password:
            return validate(password: string, percentEncodingAllowed: percentEncodingAllowed)
        case .host:
            return validate(host: string)
        case .port:
            return validate(portString: string)
        case .path:
            return validate(path: string, percentEncodingAllowed: percentEncodingAllowed)
        case .query:
            return validate(query: string, percentEncodingAllowed: percentEncodingAllowed)
        case .queryItem:
            return validate(queryItemPart: string, percentEncodingAllowed: percentEncodingAllowed)
        case .fragment:
            return validate(fragment: string, percentEncodingAllowed: percentEncodingAllowed)
        }
    }

    private static func validate(string: some StringProtocol, component: URLComponentSet, percentEncodingAllowed: Bool = true) -> Bool {
        let isValid = string.utf8.withContiguousStorageIfAvailable {
            validate(buffer: $0, component: component, percentEncodingAllowed: percentEncodingAllowed)
        }
        if let isValid {
            return isValid
        }
        #if FOUNDATION_FRAMEWORK
        if let fastCharacters = string._ns._fastCharacterContents() {
            let charsBuffer = UnsafeBufferPointer(start: fastCharacters, count: string._ns.length)
            return validate(buffer: charsBuffer, component: component, percentEncodingAllowed: percentEncodingAllowed)
        }
        #endif
        return validate(buffer: string.utf8, component: component, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate<T: Collection>(buffer: T, component: URLComponentSet, percentEncodingAllowed: Bool = true) -> Bool where T.Element: UnsignedInteger {
        guard percentEncodingAllowed else {
            return buffer.allSatisfy { $0 < 128 && UInt8($0).isAllowedIn(component) }
        }
        var hexDigitsRequired = 0
        for v in buffer {
            guard v < 128 else {
                return false
            }
            if v == UInt8(ascii: "%") {
                guard hexDigitsRequired == 0 else {
                    return false
                }
                hexDigitsRequired = 2
            } else if !UInt8(v).isAllowedIn(component) {
                return false
            } else if hexDigitsRequired > 0 {
                guard UInt8(v).isValidHexDigit else {
                    // We saw a "%" followed by only zero or one hex digit
                    return false
                }
                hexDigitsRequired -= 1
            }
        }
        return hexDigitsRequired == 0
    }

    /// Fast path used during initial URL buffer parsing.
    private static func validate(schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>, compatibility: URLParserCompatibility = .init()) -> Bool {
        guard let first = schemeBuffer.first else {
            return compatibility.contains(.allowEmptyScheme)
        }
        guard first >= UInt8(ascii: "A"),
              validate(buffer: schemeBuffer, component: .scheme, percentEncodingAllowed: false) else {
            return false
        }
        return true
    }

    /// Only used by URLComponents, don't need to consider `URLParserCompatibility.allowEmptyScheme`
    private static func validate(scheme: some StringProtocol) -> Bool {
        // A valid scheme must start with an ALPHA character.
        // If first >= "A" and is in schemeAllowed, then first is ALPHA.
        guard let first = scheme.utf8.first,
              first >= UInt8(ascii: "A"),
              validate(string: scheme, component: .scheme, percentEncodingAllowed: false) else {
            return false
        }
        return true
    }

    private static func validate(user: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: user, component: .user, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate(password: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: password, component: .password, percentEncodingAllowed: percentEncodingAllowed)
    }

    /// Validates an IP-literal host string that has leading and trailing brackets.
    /// If the host string contains a zone ID delimiter "%", this must be percent encoded to "%25" to be valid.
    /// The zone ID may contain any `reg_name` characters, including percent-encoding.
    private static func validateIPLiteralHost(_ host: some StringProtocol) -> Bool {
        precondition(looksLikeIPLiteral(host))
        let utf8 = host.utf8

        let innerHostStart = utf8.index(after: utf8.startIndex)
        let innerHostEnd = utf8.index(utf8.startIndex, offsetBy: utf8.count - 1)
        let innerHost = host[innerHostStart..<innerHostEnd]

        guard let percentIndex = utf8.firstIndex(of: UInt8(ascii: "%")) else {
            // There is no zoneID, so the whole innerHost must be the IP-literal address.
            return validate(string: innerHost, component: .hostIPLiteral, percentEncodingAllowed: false)
        }

        // The first "%" in an IP-literal must be the zone ID delimiter.
        // A valid zone ID delimiter is the percent-encoded version "%25".
        let oneAfterIndex = utf8.index(after: percentIndex)
        guard oneAfterIndex != utf8.endIndex,
              utf8[oneAfterIndex] == UInt8(ascii: "2") else {
            return false
        }
        let twoAfterIndex = utf8.index(after: oneAfterIndex)
        guard twoAfterIndex != utf8.endIndex,
              utf8[twoAfterIndex] == UInt8(ascii: "5") else {
            return false
        }

        return validate(string: innerHost[..<percentIndex], component: .hostIPLiteral, percentEncodingAllowed: false) && validate(string: innerHost[innerHost.index(after: twoAfterIndex)...], component: .hostZoneID)
    }

    private static func validate(host: some StringProtocol, knownIPLiteral: Bool = false) -> Bool {
        if knownIPLiteral || looksLikeIPLiteral(host) {
            return validateIPLiteralHost(host)
        }
        return validate(string: host, component: .host)
    }

    private static func shouldIgnorePort(forSchemeBuffer schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>) -> Bool {
        let schemeToIgnore = "addressbook".utf8
        guard schemeBuffer.count == schemeToIgnore.count else {
            return false
        }
        for i in 0..<schemeBuffer.count {
            let expected = schemeToIgnore[schemeToIgnore.index(schemeToIgnore.startIndex, offsetBy: i)]
            guard schemeBuffer[i]._lowercased == expected else {
                return false
            }
        }
        return true
    }

    /// Fast path used during initial URL buffer parsing.
    private static func validate(portBuffer: Slice<UnsafeBufferPointer<UInt8>>, forSchemeBuffer schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>?) -> Bool {
        let isValid = portBuffer.allSatisfy {
            UInt8(ascii: "0") <= $0 && $0 <= UInt8(ascii: "9")
        }
        if isValid {
            return true
        }
        if let schemeBuffer {
            return shouldIgnorePort(forSchemeBuffer: schemeBuffer)
        }
        return false
    }

    private static func validate(portString: some StringProtocol) -> Bool {
        return portString.utf8.allSatisfy {
            UInt8(ascii: "0") <= $0 && $0 <= UInt8(ascii: "9")
        }
    }

    private static func validate(path: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: path, component: .path, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate(query: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: query, component: .query, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate(queryItemPart: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: queryItemPart, component: .queryItem, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate(fragment: some StringProtocol, percentEncodingAllowed: Bool = true) -> Bool {
        return validate(string: fragment, component: .fragment, percentEncodingAllowed: percentEncodingAllowed)
    }

    private static func validate(parseInfo: URLParseInfo) -> Bool {
        // Scheme and port are already validated in `parse(urlString:)`
        if let user = parseInfo.user {
            guard validate(user: user) else {
                return false
            }
        }
        if let password = parseInfo.password {
            guard validate(password: password) else {
                return false
            }
        }
        if let host = parseInfo.host {
            guard validate(host: host, knownIPLiteral: parseInfo.isIPLiteral) else {
                return false
            }
        }
        let path = parseInfo.path
        guard validate(path: path) else {
            return false
        }
        if let query = parseInfo.query {
            guard validate(query: query) else {
                return false
            }
        }
        if let fragment = parseInfo.fragment {
            guard validate(fragment: fragment) else {
                return false
            }
        }
        return true
    }

    private struct InvalidComponentSet: OptionSet {
        let rawValue: UInt8
        static let scheme   = InvalidComponentSet(rawValue: 1 << 0)
        static let user     = InvalidComponentSet(rawValue: 1 << 1)
        static let password = InvalidComponentSet(rawValue: 1 << 2)
        static let host     = InvalidComponentSet(rawValue: 1 << 3)
        static let port     = InvalidComponentSet(rawValue: 1 << 4)
        static let path     = InvalidComponentSet(rawValue: 1 << 5)
        static let query    = InvalidComponentSet(rawValue: 1 << 6)
        static let fragment = InvalidComponentSet(rawValue: 1 << 7)
    }

    private static func invalidComponents(of parseInfo: URLParseInfo) -> InvalidComponentSet {
        var invalidComponents: InvalidComponentSet = []
        if let user = parseInfo.user, !validate(user: user) {
            invalidComponents.insert(.user)
        }
        if let password = parseInfo.password, !validate(password: password) {
            invalidComponents.insert(.password)
        }
        if let host = parseInfo.host, !validate(host: host, knownIPLiteral: parseInfo.isIPLiteral) {
            invalidComponents.insert(.host)
        }
        let path = parseInfo.path
        if !validate(path: path) {
            invalidComponents.insert(.path)
        }
        if let query = parseInfo.query, !validate(query: query) {
            invalidComponents.insert(.query)
        }
        if let fragment = parseInfo.fragment, !validate(fragment: fragment) {
            invalidComponents.insert(.fragment)
        }
        return invalidComponents
    }

    // MARK: - Parsing

    /// Parses a URL string into `URLParseInfo`, with the option to add (or skip) encoding of invalid characters.
    /// If `encodingInvalidCharacters` is `true`, this function handles encoding of invalid components.
    static func parse(urlString: String, encodingInvalidCharacters: Bool) -> URLParseInfo? {
        return parse(urlString: urlString, encodingInvalidCharacters: encodingInvalidCharacters, compatibility: .init())
    }

    static func parse(urlString: String, encodingInvalidCharacters: Bool, compatibility: URLParserCompatibility) -> URLParseInfo? {
        #if os(Windows)
        let urlString = urlString.replacing(UInt8(ascii: "\\"), with: UInt8(ascii: "/"))
        #endif
        guard let parseInfo = parse(urlString: urlString, compatibility: compatibility) else {
            return nil
        }

        if !encodingInvalidCharacters {
            guard validate(parseInfo: parseInfo) else {
                return nil
            }
            return parseInfo
        }

        let invalidComponents = invalidComponents(of: parseInfo)
        if invalidComponents.isEmpty {
            return parseInfo
        }

        // One or more components were invalid, encode them.

        var finalURLString = ""

        if let scheme = parseInfo.scheme {
            finalURLString += "\(scheme):"
        }

        if parseInfo.hasAuthority {
            finalURLString += "//"
        }

        if let user = parseInfo.user {
            if invalidComponents.contains(.user) {
                finalURLString += percentEncode(user, component: .user)!
            } else {
                finalURLString += user
            }

            if let password = parseInfo.password {
                if invalidComponents.contains(.password) {
                    finalURLString += ":\(percentEncode(password, component: .password)!)"
                } else {
                    finalURLString += ":\(password)"
                }
            }

            finalURLString += "@"
        }

        if let host = parseInfo.host {
            if !invalidComponents.contains(.host) {
                finalURLString += host
            } else if parseInfo.isIPLiteral || shouldPercentEncodeHost(host, forScheme: parseInfo.scheme) {
                guard let percentEncodedHost = percentEncode(host, component: .host) else {
                    return nil
                }
                finalURLString += percentEncodedHost
            } else if let idnaEncoded = IDNAEncodeHost(String(host)),
                      validate(host: idnaEncoded, knownIPLiteral: false) {
                finalURLString += idnaEncoded
            } else {
                return nil
            }
        }

        if let port = parseInfo.port {
            finalURLString += ":\(port)"
        }

        let path = parseInfo.path
        if invalidComponents.contains(.path) {
            finalURLString += percentEncode(path, component: .path)!
        } else {
            finalURLString += path
        }

        if let query = parseInfo.query {
            if invalidComponents.contains(.query) {
                finalURLString += "?\(percentEncode(query, component: .query)!)"
            } else {
                finalURLString += "?\(query)"
            }
        }

        if let fragment = parseInfo.fragment {
            if invalidComponents.contains(.fragment) {
                finalURLString += "#\(percentEncode(fragment, component: .fragment)!)"
            } else {
                finalURLString += "#\(fragment)"
            }
        }

        return parse(urlString: finalURLString, compatibility: compatibility)
    }

    /// Parses a URL string into its component parts and stores these ranges in a `URLParseInfo`.
    /// This function calls `parse(buffer:)`, then converts the buffer ranges into string ranges.
    private static func parse(urlString: String, compatibility: URLParserCompatibility = .init()) -> URLParseInfo? {
        var string = urlString
        let bufferParseInfo = string.withUTF8 {
            parse(buffer: $0, compatibility: compatibility)
        }
        guard let bufferParseInfo else {
            return nil
        }

        typealias URLBuffer = UnsafeBufferPointer<UInt8>
        func convert(_ range: Range<URLBuffer.Index>?) -> Range<String.Index>? {
            guard let range else { return nil }
            let lower = string.utf8.index(string.utf8.startIndex, offsetBy: range.lowerBound)
            let upper = string.utf8.index(string.utf8.startIndex, offsetBy: range.upperBound)
            return lower..<upper
        }

        return URLParseInfo(
            urlString: string,
            urlParser: .RFC3986,
            schemeRange: convert(bufferParseInfo.schemeRange),
            userRange: convert(bufferParseInfo.userRange),
            passwordRange: convert(bufferParseInfo.passwordRange),
            hostRange: convert(bufferParseInfo.hostRange),
            portRange: convert(bufferParseInfo.portRange),
            pathRange: convert(bufferParseInfo.pathRange),
            queryRange: convert(bufferParseInfo.queryRange),
            fragmentRange: convert(bufferParseInfo.fragmentRange),
            isIPLiteral: bufferParseInfo.isIPLiteral,
            didPercentEncodeHost: bufferParseInfo.didPercentEncodeHost,
            pathHasPercent: bufferParseInfo.pathHasPercent,
            pathHasFileID: bufferParseInfo.pathHasFileID
        )
    }

    /// Parses a URL string into its component parts and stores these ranges in a `URLBufferParseInfo`.
    /// This function only parses based on delimiters and does not do any encoding.
    private static func parse(buffer: UnsafeBufferPointer<UInt8>, compatibility: URLParserCompatibility = .init()) -> URLBufferParseInfo? {
        // A URI is either:
        // 1. scheme ":" hier-part [ "?" query ] [ "#" fragment ]
        // 2. relative-ref

        var parseInfo = URLBufferParseInfo()
        guard !buffer.isEmpty else {
            // Path always exists, even if it's the empty string.
            parseInfo.pathRange = buffer.startIndex..<buffer.endIndex
            return parseInfo
        }

        var currentIndex = buffer.startIndex

        // MARK: Scheme

        while currentIndex != buffer.endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: ":") {
                // Scheme must be at least 1 character, otherwise this is a relative-ref.
                if currentIndex != buffer.startIndex || compatibility.contains(.allowEmptyScheme) {
                    parseInfo.schemeRange = buffer.startIndex..<currentIndex
                    currentIndex = buffer.index(after: currentIndex)
                    if currentIndex == buffer.endIndex {
                        guard let schemeRange = parseInfo.schemeRange,
                              validate(schemeBuffer: buffer[schemeRange], compatibility: compatibility) else {
                            return nil
                        }
                        // The string only contained a scheme, but the path always exists.
                        parseInfo.pathRange = buffer.endIndex..<buffer.endIndex
                        return parseInfo
                    }
                }
                break
            } else if v == UInt8(ascii: "/")
                        || v == UInt8(ascii: "?")
                        || v == UInt8(ascii: "#")
                        || v == UInt8(ascii: "[")
                        || v == UInt8(ascii: "]")
                        || v == UInt8(ascii: "@") {
                // We did not find a scheme, so this is a relative-ref.
                // Note that "[", "]", and "@" are heuristics telling us the user intends
                // this to be an authority component, which is often followed by a port ":"
                // rdar://94076763
                currentIndex = buffer.startIndex
                break
            }
            currentIndex = buffer.index(after: currentIndex)
        }

        if let schemeRange = parseInfo.schemeRange {
            guard validate(schemeBuffer: buffer[schemeRange], compatibility: compatibility) else {
                return nil
            }
        }

        if currentIndex == buffer.endIndex {
            // We searched the whole string and did not find a scheme.
            currentIndex = buffer.startIndex
        }

        // MARK: Authority

        let doubleSlashExists = (
            buffer.index(after: currentIndex) != buffer.endIndex &&
            UInt8(ascii: "/") == buffer[currentIndex] &&
            UInt8(ascii: "/") == buffer[buffer.index(after: currentIndex)]
        )
        if doubleSlashExists {
            currentIndex = buffer.index(currentIndex, offsetBy: 2)
            let authorityStartIndex = currentIndex

            while currentIndex != buffer.endIndex {
                let v = buffer[currentIndex]
                if v == UInt8(ascii: "/") || v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
                    break
                }
                currentIndex = buffer.index(after: currentIndex)
            }

            let authorityRange = authorityStartIndex..<currentIndex
            if authorityRange.isEmpty {
                // Host exists, but is empty. Other authority components do not exist.
                parseInfo.hostRange = authorityRange
            } else {
                // Parse the user, password, host, and port
                let authority = buffer[authorityRange]
                guard parseAuthority(authority, into: &parseInfo) else {
                    return nil
                }
                if let portRange = parseInfo.portRange {
                    var schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>?
                    if let schemeRange = parseInfo.schemeRange {
                        schemeBuffer = buffer[schemeRange]
                    }
                    if compatibility.contains(.allowAnyPort) {
                        guard buffer[portRange].allSatisfy({ $0.isValidURLCharacter }) else {
                            return nil
                        }
                    } else if !validate(portBuffer: buffer[portRange], forSchemeBuffer: schemeBuffer) {
                        return nil
                    }
                }
            }
        }

        // MARK: Path

        let pathStartIndex = currentIndex
        var sawPercent = false
        if buffer[pathStartIndex...].starts(with: URL.fileIDPrefix) {
            parseInfo.pathHasFileID = true
            currentIndex = buffer.index(pathStartIndex, offsetBy: URL.fileIDPrefix.count)
        }
        while currentIndex != buffer.endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
                break
            } else if v == UInt8(ascii: "%") {
                sawPercent = true
            }
            currentIndex = buffer.index(after: currentIndex)
        }
        parseInfo.pathRange = pathStartIndex..<currentIndex
        parseInfo.pathHasPercent = sawPercent

        if currentIndex == buffer.endIndex {
            return parseInfo
        }

        // MARK: Query and Fragment

        if buffer[currentIndex] == UInt8(ascii: "?") {
            let queryStartIndex = buffer.index(after: currentIndex)
            if let poundIndex = buffer[queryStartIndex...].firstIndex(of: UInt8(ascii: "#")) {
                parseInfo.queryRange = queryStartIndex..<poundIndex
                parseInfo.fragmentRange = buffer.index(after: poundIndex)..<buffer.endIndex
            } else {
                parseInfo.queryRange = buffer.index(after: currentIndex)..<buffer.endIndex
            }
        } else if buffer[currentIndex] == UInt8(ascii: "#") {
            let fragmentStartIndex = buffer.index(after: currentIndex)
            parseInfo.fragmentRange = fragmentStartIndex..<buffer.endIndex
        }

        return parseInfo
    }

    /// Parses the authority component into its user, password, host, and port subcomponents.
    private static func parseAuthority(_ authority: Slice<UnsafeBufferPointer<UInt8>>, into parseInfo: inout URLBufferParseInfo) -> Bool {

        var hostStartIndex = authority.startIndex
        var hostEndIndex = authority.endIndex

        // MARK: User and Password

        // NOTE: The previous URLComponents parser used the first index of "@", but WHATWG
        // and other RFC 3986 parsers use the last index, so we should align with those.
        if let atIndex = authority.lastIndex(of: UInt8(ascii: "@")) {
            if let colonIndex = authority[..<atIndex].firstIndex(of: UInt8(ascii: ":")) {
                parseInfo.userRange = authority.startIndex..<colonIndex
                parseInfo.passwordRange = authority.index(after: colonIndex)..<atIndex
            } else {
                parseInfo.userRange = authority.startIndex..<atIndex
                // Password does not exist.
            }
            hostStartIndex = authority.index(after: atIndex)
        }

        // MARK: Host and Port

        if hostStartIndex != authority.endIndex && authority[hostStartIndex] == UInt8(ascii: "["),
           let endBracketIndex = authority[hostStartIndex...].firstIndex(of: UInt8(ascii: "]")) {
            parseInfo.isIPLiteral = true
            hostEndIndex = authority.index(after: endBracketIndex)
            if hostEndIndex != authority.endIndex {
                guard authority[hostEndIndex] == UInt8(ascii: ":") else {
                    // There are invalid characters after the IP literal, so the URL is invalid.
                    return false
                }
                parseInfo.portRange = authority.index(after: hostEndIndex)..<authority.endIndex
            }
        } else if let colonIndex = authority[hostStartIndex...].firstIndex(of: UInt8(ascii: ":")) {
            hostEndIndex = colonIndex
            if authority.index(after: colonIndex) != authority.endIndex {
                // Port only exists if non-empty, otherwise RFC 3986 suggests removing the ":".
                parseInfo.portRange = authority.index(after: colonIndex)..<authority.endIndex
            }
        }

        // Create the host range, which always exists since we have an authority.
        parseInfo.hostRange = hostStartIndex..<hostEndIndex
        parseInfo.didPercentEncodeHost = authority[hostStartIndex..<hostEndIndex].contains(UInt8(ascii: "%"))
        return true
    }
}

// MARK: - Encoding Extensions

fileprivate extension StringProtocol {

    func hexToAscii(_ hex: UInt8) -> UInt8 {
        switch hex {
        case 0x0:
            return UInt8(ascii: "0")
        case 0x1:
            return UInt8(ascii: "1")
        case 0x2:
            return UInt8(ascii: "2")
        case 0x3:
            return UInt8(ascii: "3")
        case 0x4:
            return UInt8(ascii: "4")
        case 0x5:
            return UInt8(ascii: "5")
        case 0x6:
            return UInt8(ascii: "6")
        case 0x7:
            return UInt8(ascii: "7")
        case 0x8:
            return UInt8(ascii: "8")
        case 0x9:
            return UInt8(ascii: "9")
        case 0xA:
            return UInt8(ascii: "A")
        case 0xB:
            return UInt8(ascii: "B")
        case 0xC:
            return UInt8(ascii: "C")
        case 0xD:
            return UInt8(ascii: "D")
        case 0xE:
            return UInt8(ascii: "E")
        case 0xF:
            return UInt8(ascii: "F")
        default:
            fatalError("Invalid hex digit: \(hex)")
        }
    }

    func addingPercentEncoding(forURLComponent component: URLComponentSet) -> String {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            addingPercentEncoding(utf8Buffer: $0, component: component)
        }
        if let fastResult {
            return fastResult
        } else {
            return addingPercentEncoding(utf8Buffer: utf8, component: component)
        }
    }

    func addingPercentEncoding(utf8Buffer: some Collection<UInt8>, component: URLComponentSet) -> String {
        let maxLength = utf8Buffer.count * 3
        let result = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength + 1) { _buffer in
            var buffer = OutputBuffer(initializing: _buffer.baseAddress!, capacity: _buffer.count)
            for v in utf8Buffer {
                if v.isAllowedIn(component) {
                    buffer.appendElement(v)
                } else {
                    buffer.appendElement(UInt8(ascii: "%"))
                    buffer.appendElement(hexToAscii(v >> 4))
                    buffer.appendElement(hexToAscii(v & 0xF))
                }
            }
            buffer.appendElement(0) // NULL-terminated
            let initialized = buffer.relinquishBorrowedMemory()
            return String(cString: initialized.baseAddress!)
        }
        return result
    }

    func asciiToHex(_ ascii: UInt8) -> UInt8? {
        switch ascii {
        case UInt8(ascii: "0"):
            return 0x0
        case UInt8(ascii: "1"):
            return 0x1
        case UInt8(ascii: "2"):
            return 0x2
        case UInt8(ascii: "3"):
            return 0x3
        case UInt8(ascii: "4"):
            return 0x4
        case UInt8(ascii: "5"):
            return 0x5
        case UInt8(ascii: "6"):
            return 0x6
        case UInt8(ascii: "7"):
            return 0x7
        case UInt8(ascii: "8"):
            return 0x8
        case UInt8(ascii: "9"):
            return 0x9
        case UInt8(ascii: "A"), UInt8(ascii: "a"):
            return 0xA
        case UInt8(ascii: "B"), UInt8(ascii: "b"):
            return 0xB
        case UInt8(ascii: "C"), UInt8(ascii: "c"):
            return 0xC
        case UInt8(ascii: "D"), UInt8(ascii: "d"):
            return 0xD
        case UInt8(ascii: "E"), UInt8(ascii: "e"):
            return 0xE
        case UInt8(ascii: "F"), UInt8(ascii: "f"):
            return 0xF
        default:
            return nil
        }
    }

    func removingURLPercentEncoding(excluding: Set<UInt8> = []) -> String? {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            removingURLPercentEncoding(utf8Buffer: $0, excluding: excluding)
        }
        if let fastResult {
            return fastResult
        } else {
            return removingURLPercentEncoding(utf8Buffer: utf8, excluding: excluding)
        }
    }

    func removingURLPercentEncoding(utf8Buffer: some Collection<UInt8>, excluding: Set<UInt8>) -> String? {
        let result: String? = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { buffer in
            var i = 0
            var byte: UInt8 = 0
            var hexDigitsRequired = 0
            for v in utf8Buffer {
                if v == UInt8(ascii: "%") {
                    guard hexDigitsRequired == 0 else {
                        return nil
                    }
                    hexDigitsRequired = 2
                } else if hexDigitsRequired > 0 {
                    guard let hex = asciiToHex(v) else {
                        return nil
                    }
                    if hexDigitsRequired == 2 {
                        byte = hex << 4
                    } else if hexDigitsRequired == 1 {
                        byte += hex
                        if excluding.contains(byte) {
                            // Keep the original percent-encoding for this byte
                            i = buffer[i...i+2].initialize(fromContentsOf: [UInt8(ascii: "%"), hexToAscii(byte >> 4), v])
                        } else {
                            buffer[i] = byte
                            i += 1
                            byte = 0
                        }
                    }
                    hexDigitsRequired -= 1
                } else {
                    buffer[i] = v
                    i += 1
                }
            }
            guard hexDigitsRequired == 0 else {
                return nil
            }
            return String(_validating: buffer[..<i], as: UTF8.self)
        }
        return result
    }
}

// MARK: - Validation Extensions

fileprivate struct URLComponentSet: OptionSet {
    let rawValue: UInt8
    static let scheme           = URLComponentSet(rawValue: 1 << 0)

    // user, password, and hostIPLiteral use the same allowed character set.
    static let user             = URLComponentSet(rawValue: 1 << 1)
    static let password         = URLComponentSet(rawValue: 1 << 1)
    static let hostIPLiteral    = URLComponentSet(rawValue: 1 << 1)

    static let host             = URLComponentSet(rawValue: 1 << 2)
    static let hostZoneID       = URLComponentSet(rawValue: 1 << 3)
    static let path             = URLComponentSet(rawValue: 1 << 4)
    static let pathFirstSegment = URLComponentSet(rawValue: 1 << 5)

    // query and fragment use the same allowed character set.
    static let query            = URLComponentSet(rawValue: 1 << 6)
    static let fragment         = URLComponentSet(rawValue: 1 << 6)

    static let queryItem        = URLComponentSet(rawValue: 1 << 7)
}

fileprivate extension UTF8.CodeUnit {
    func isAllowedIn(_ component: URLComponentSet) -> Bool {
        return allowedURLComponents & component.rawValue != 0
    }

    // ===------------------------------------------------------------------------------------=== //
    // allowedURLComponents was written programmatically using the following grammar from RFC 3986:
    //
    // let ALPHA       = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    // let DIGIT       = "0123456789"
    // let HEXDIG      = DIGIT + "ABCDEFabcdef"
    // let gen_delims  = ":/?#[]@"
    // let sub_delims  = "!$&'()*+,;="
    // let unreserved  = ALPHA + DIGIT + "-._~"
    // let reserved    = gen_delims + sub_delims
    // NOTE: "%" is allowed in pchar and reg_name, but we must validate that 2 HEXDIG follow it
    // let pchar       = unreserved + sub_delims + ":" + "@"
    // let reg_name    = unreserved + sub_delims
    //
    // let schemeAllowed            = CharacterSet(charactersIn: ALPHA + DIGIT + "+-.")
    // let userinfoAllowed          = CharacterSet(charactersIn: unreserved + sub_delims + ":")
    // let hostAllowed              = CharacterSet(charactersIn: reg_name)
    // let hostIPLiteralAllowed     = CharacterSet(charactersIn: unreserved + sub_delims + ":")
    // let hostZoneIDAllowed        = CharacterSet(charactersIn: unreserved)
    // let portAllowed              = CharacterSet(charactersIn: DIGIT)
    // let pathAllowed              = CharacterSet(charactersIn: pchar + "/")
    // let pathFirstSegmentAllowed  = pathAllowed.subtracting(CharacterSet(charactersIn: ":"))
    // let queryAllowed             = CharacterSet(charactersIn: pchar + "/?")
    // let queryItemAllowed         = queryAllowed.subtracting(CharacterSet(charactersIn: "=&"))
    // let fragmentAllowed          = CharacterSet(charactersIn: pchar + "/?")
    // ===------------------------------------------------------------------------------------=== //
    var allowedURLComponents: URLComponentSet.RawValue {
        switch self {
        case UInt8(ascii: "!"):
            return 0b11110110
        case UInt8(ascii: "$"):
            return 0b11110110
        case UInt8(ascii: "&"):
            return 0b01110110
        case UInt8(ascii: "'"):
            return 0b11110110
        case UInt8(ascii: "("):
            return 0b11110110
        case UInt8(ascii: ")"):
            return 0b11110110
        case UInt8(ascii: "*"):
            return 0b11110110
        case UInt8(ascii: "+"):
            return 0b11110111
        case UInt8(ascii: ","):
            return 0b11110110
        case UInt8(ascii: "-"):
            return 0b11111111
        case UInt8(ascii: "."):
            return 0b11111111
        case UInt8(ascii: "/"):
            return 0b11110000
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return 0b11111111
        case UInt8(ascii: ":"):
            return 0b11010010
        case UInt8(ascii: ";"):
            return 0b11110110
        case UInt8(ascii: "="):
            return 0b01110110
        case UInt8(ascii: "?"):
            return 0b11000000
        case UInt8(ascii: "@"):
            return 0b11110000
        case UInt8(ascii: "A")...UInt8(ascii: "Z"):
            return 0b11111111
        case UInt8(ascii: "_"):
            return 0b11111110
        case UInt8(ascii: "a")...UInt8(ascii: "z"):
            return 0b11111111
        case UInt8(ascii: "~"):
            return 0b11111110
        default:
            return 0
        }
    }

    // let urlAllowed = CharacterSet(charactersIn: unreserved + reserved)
    var isValidURLCharacter: Bool {
        guard self < 128 else { return false }
        if self < 64 {
            let allowed = UInt64(12682136387466559488)
            return (allowed & (UInt64(1) << self)) != 0
        } else {
            let allowed = UInt64(5188146765093666815)
            return (allowed & (UInt64(1) << (self - 64))) != 0
        }
    }
}
