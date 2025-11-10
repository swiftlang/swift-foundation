//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import Foundation_Private
#endif

// Source of truth for a parsed URL
final class URLParseInfo: Sendable {
    let urlString: String

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
    let pathHasFileID: Bool

    struct EncodedComponentSet: OptionSet {
        let rawValue: UInt8
        static let user     = EncodedComponentSet(rawValue: 1 << 0)
        static let password = EncodedComponentSet(rawValue: 1 << 1)
        static let host     = EncodedComponentSet(rawValue: 1 << 2)
        static let path     = EncodedComponentSet(rawValue: 1 << 3)
        static let query    = EncodedComponentSet(rawValue: 1 << 4)
        static let fragment = EncodedComponentSet(rawValue: 1 << 5)
    }

    /// Empty unless we initialized with a string, data, or bytes that required percent-encoding.
    /// Used to return the appropriate dataRepresentation or bytes for CFURL.
    let encodedComponents: EncodedComponentSet

    init(urlString: String, schemeRange: Range<String.Index>?, userRange: Range<String.Index>?, passwordRange: Range<String.Index>?, hostRange: Range<String.Index>?, portRange: Range<String.Index>?, pathRange: Range<String.Index>?, queryRange: Range<String.Index>?, fragmentRange: Range<String.Index>?, isIPLiteral: Bool, didPercentEncodeHost: Bool, pathHasFileID: Bool, encodedComponents: EncodedComponentSet) {
        self.urlString = urlString
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
        self.pathHasFileID = pathHasFileID
        self.encodedComponents = encodedComponents
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

    var netLocationRange: Range<String.Index>? {
        guard hasAuthority else {
            return nil
        }
        guard let startIndex = userRange?.lowerBound
                ?? passwordRange?.lowerBound
                ?? hostRange?.lowerBound
                ?? portRange?.lowerBound else {
            return nil
        }
        guard let endIndex = portRange?.upperBound
                ?? hostRange?.upperBound
                ?? passwordRange?.upperBound
                ?? userRange?.upperBound else {
            return nil
        }
        return (startIndex..<endIndex)
    }

    var netLocation: Substring? {
        guard let netLocationRange else {
            return nil
        }
        return urlString[netLocationRange]
    }

    // Does not include the "?" or "#" separator at the beginning
    var cfResourceSpecifierRange: Range<String.Index>? {
        guard let startIndex = queryRange?.lowerBound
                ?? fragmentRange?.lowerBound else {
            return nil
        }
        return startIndex..<urlString.endIndex
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
    var pathHasFileID: Bool = false
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

internal struct RFC3986Parser {

    // MARK: - Encoding

    static func percentEncode(_ string: (some StringProtocol)?, component: URLComponents.Component, skipAlreadyEncoded: Bool = false) -> String? {
        guard let string else { return nil }
        guard !string.isEmpty else { return "" }
        switch component {
        case .scheme:
            fatalError("Scheme cannot be percent-encoded.")
        case .user:
            return string.addingPercentEncoding(forURLComponent: .user, skipAlreadyEncoded: skipAlreadyEncoded)
        case .password:
            return string.addingPercentEncoding(forURLComponent: .password, skipAlreadyEncoded: skipAlreadyEncoded)
        case .host:
            return percentEncodeHost(string, skipAlreadyEncoded: skipAlreadyEncoded)
        case .port:
            fatalError("Port cannot be percent-encoded.")
        case .path:
            return percentEncodePath(string, skipAlreadyEncoded: skipAlreadyEncoded)
        case .query:
            return string.addingPercentEncoding(forURLComponent: .query, skipAlreadyEncoded: skipAlreadyEncoded)
        case .queryItem:
            return string.addingPercentEncoding(forURLComponent: .queryItem, skipAlreadyEncoded: skipAlreadyEncoded)
        case .fragment:
            return string.addingPercentEncoding(forURLComponent: .fragment, skipAlreadyEncoded: skipAlreadyEncoded)
        }
    }

    static func percentDecode(_ string: (some StringProtocol)?, excluding: Set<UInt8> = [], encoding: String.Encoding = .utf8) -> String? {
        guard let string else { return nil }
        guard !string.isEmpty else { return "" }
        return string.removingURLPercentEncoding(excluding: excluding, encoding: encoding)
    }

    private static let schemesToPercentEncodeHost = [[UInt8]]([
        Array("tel".utf8),
        Array("telemergencycall".utf8),
        Array("telprompt".utf8),
        Array("callto".utf8),
        Array("facetime".utf8),
        Array("facetime-prompt".utf8),
        Array("facetime-audio".utf8),
        Array("facetime-audio-prompt".utf8),
        Array("imap".utf8),
        Array("pop".utf8),
        Array("addressbook".utf8),
        Array("contact".utf8),
        Array("phasset".utf8),
        Array("http+unix".utf8),
        Array("https+unix".utf8),
        Array("ws+unix".utf8),
        Array("wss+unix".utf8),
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
        let lowercased = scheme.lowercased().utf8
        return schemesToPercentEncodeHost.contains { $0.elementsEqual(lowercased) }
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

    private static func percentEncodeHost(_ host: (some StringProtocol)?, skipAlreadyEncoded: Bool = false) -> String? {
        guard let host else { return nil }
        guard !host.isEmpty else { return "" }
        if looksLikeIPLiteral(host) {
            if skipAlreadyEncoded {
                let innerHost = String(decoding: host.utf8.dropFirst().dropLast(), as: UTF8.self)
                return "[\(innerHost.addingPercentEncoding(forURLComponent: .host, skipAlreadyEncoded: true))]"
            }
            return percentEncodeIPLiteralHost(host)
        }
        return host.addingPercentEncoding(forURLComponent: .host, skipAlreadyEncoded: skipAlreadyEncoded)
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

    private static func percentEncodePath(_ path: some StringProtocol, skipAlreadyEncoded: Bool = false) -> String {
        guard !path.isEmpty else { return "" }
        guard let slashIndex = path.utf8.firstIndex(of: UInt8(ascii: "/")) else {
            return path.addingPercentEncoding(forURLComponent: .pathFirstSegment, skipAlreadyEncoded: skipAlreadyEncoded)
        }
        guard slashIndex != path.startIndex else {
            return path.addingPercentEncoding(forURLComponent: .path, skipAlreadyEncoded: skipAlreadyEncoded)
        }
        let firstSegment = path[..<slashIndex].addingPercentEncoding(forURLComponent: .pathFirstSegment, skipAlreadyEncoded: skipAlreadyEncoded)
        let remaining = path[slashIndex...].addingPercentEncoding(forURLComponent: .path, skipAlreadyEncoded: skipAlreadyEncoded)
        return firstSegment + remaining
    }

    // MARK: - Validation

    static func validate(_ string: (some StringProtocol)?, component: URLComponents.Component, percentEncodingAllowed: Bool = true) -> Bool {
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

    private static func validate(string: some StringProtocol, component: URLComponentAllowedMask, percentEncodingAllowed: Bool = true) -> Bool {
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

    private static func validate<T: Collection>(buffer: T, component allowedMask: URLComponentAllowedMask, percentEncodingAllowed: Bool = true) -> Bool where T.Element: UnsignedInteger {
        guard percentEncodingAllowed else {
            return buffer.allSatisfy { $0 < 128 && allowedMask.contains(UInt8($0)) }
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
            } else if !allowedMask.contains(UInt8(v)) {
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
    private static func validate(schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>, allowEmptyScheme: Bool = false) -> Bool {
        guard let first = schemeBuffer.first else {
            return allowEmptyScheme
        }
        guard first >= UInt8(ascii: "A"),
              validate(buffer: schemeBuffer, component: .scheme, percentEncodingAllowed: false) else {
            return false
        }
        return true
    }

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
            return validate(string: innerHost, component: .hostIPvFuture, percentEncodingAllowed: false)
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

        return validate(string: innerHost[..<percentIndex], component: .hostIPvFuture, percentEncodingAllowed: false) && validate(string: innerHost[innerHost.index(after: twoAfterIndex)...], component: .hostZoneID)
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

    typealias InvalidComponentSet = URLParseInfo.EncodedComponentSet
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

    /// Optimization for URLs initialized with just a file path.
    static func parse(filePath: String, isAbsolute: Bool) -> URLParseInfo {
        if isAbsolute {
            precondition(filePath.utf8.first == ._slash)
            let string = "file://" + filePath
            let utf8 = string.utf8
            return URLParseInfo(
                urlString: string,
                schemeRange: utf8.startIndex..<utf8.index(utf8.startIndex, offsetBy: 4),
                userRange: nil,
                passwordRange: nil,
                hostRange: utf8.index(utf8.startIndex, offsetBy: 7)..<utf8.index(utf8.startIndex, offsetBy: 7),
                portRange: nil,
                pathRange: utf8.index(utf8.startIndex, offsetBy: 7)..<utf8.endIndex,
                queryRange: nil,
                fragmentRange: nil,
                isIPLiteral: false,
                didPercentEncodeHost: false,
                pathHasFileID: filePath.utf8.starts(with: URL.fileIDPrefix),
                encodedComponents: filePath.utf8.contains(UInt8(ascii: "%")) ? .path : []
            )
        } else {
            return URLParseInfo(
                urlString: filePath,
                schemeRange: nil,
                userRange: nil,
                passwordRange: nil,
                hostRange: nil,
                portRange: nil,
                pathRange: filePath.startIndex..<filePath.endIndex,
                queryRange: nil,
                fragmentRange: nil,
                isIPLiteral: false,
                didPercentEncodeHost: false,
                pathHasFileID: false,
                encodedComponents: filePath.utf8.contains(UInt8(ascii: "%")) ? .path : []
            )
        }
    }

    /// Parses a URL string into `URLParseInfo`, with the option to add (or skip) encoding of invalid characters.
    /// If `encodingInvalidCharacters` is `true`, this function handles encoding of invalid components.
    static func parse(urlString: String, encodingInvalidCharacters: Bool, allowEmptyScheme: Bool = false) -> URLParseInfo? {
        #if os(Windows)
        let urlString = urlString.replacing(UInt8(ascii: "\\"), with: UInt8(ascii: "/"))
        #endif
        guard let parseInfo = parse(urlString: urlString, allowEmptyScheme: allowEmptyScheme) else {
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
                if parseInfo.isIPLiteral {
                    // The IP-literal may still be invalid after percent-encoding the zoneID
                    guard validate(host: percentEncodedHost, knownIPLiteral: true) else {
                        return nil
                    }
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

        return parse(urlString: finalURLString, allowEmptyScheme: allowEmptyScheme, encodedComponents: invalidComponents)
    }

    /// Parses a URL string into its component parts and stores these ranges in a `URLParseInfo`.
    /// This function calls `parse(buffer:)`, then converts the buffer ranges into string ranges.
    private static func parse(urlString: String, allowEmptyScheme: Bool = false, encodedComponents: URLParseInfo.EncodedComponentSet = []) -> URLParseInfo? {
        var string = urlString
        let bufferParseInfo = string.withUTF8 {
            parse(buffer: $0, allowEmptyScheme: allowEmptyScheme)
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
            pathHasFileID: bufferParseInfo.pathHasFileID,
            encodedComponents: encodedComponents
        )
    }

    /// Parses a URL string into its component parts and stores these ranges in a `URLBufferParseInfo`.
    /// This function only parses based on delimiters and does not do any encoding.
    private static func parse(buffer: UnsafeBufferPointer<UInt8>, allowEmptyScheme: Bool = false) -> URLBufferParseInfo? {
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
                if currentIndex != buffer.startIndex || allowEmptyScheme {
                    parseInfo.schemeRange = buffer.startIndex..<currentIndex
                    currentIndex = buffer.index(after: currentIndex)
                    if currentIndex == buffer.endIndex {
                        guard let schemeRange = parseInfo.schemeRange,
                              validate(schemeBuffer: buffer[schemeRange], allowEmptyScheme: allowEmptyScheme) else {
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
            guard validate(schemeBuffer: buffer[schemeRange], allowEmptyScheme: allowEmptyScheme) else {
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
                guard parseAuthority(authority, into: &parseInfo, allowEmptyScheme: allowEmptyScheme) else {
                    return nil
                }
                if let portRange = parseInfo.portRange {
                    var schemeBuffer: Slice<UnsafeBufferPointer<UInt8>>?
                    if let schemeRange = parseInfo.schemeRange {
                        schemeBuffer = buffer[schemeRange]
                    }
                    guard validate(portBuffer: buffer[portRange], forSchemeBuffer: schemeBuffer) else {
                        return nil
                    }
                }
            }
        }

        // MARK: Path

        let pathStartIndex = currentIndex
        if buffer[pathStartIndex...].starts(with: URL.fileIDPrefix) {
            parseInfo.pathHasFileID = true
            currentIndex = buffer.index(pathStartIndex, offsetBy: URL.fileIDPrefix.count)
        }
        while currentIndex != buffer.endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
                break
            }
            currentIndex = buffer.index(after: currentIndex)
        }
        parseInfo.pathRange = pathStartIndex..<currentIndex

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
    private static func parseAuthority(_ authority: Slice<UnsafeBufferPointer<UInt8>>, into parseInfo: inout URLBufferParseInfo, allowEmptyScheme: Bool) -> Bool {

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
            if authority.index(after: colonIndex) != authority.endIndex || allowEmptyScheme {
                // Port only exists if non-empty, otherwise RFC 3986 suggests removing the ":".
                // But, in cases where we allow empty scheme (NS/URL), also allow empty port.
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

@inline(__always)
internal func hexToAscii(_ hex: UInt8) -> UInt8 {
    switch hex {
    case 0x0: return UInt8(ascii: "0")
    case 0x1: return UInt8(ascii: "1")
    case 0x2: return UInt8(ascii: "2")
    case 0x3: return UInt8(ascii: "3")
    case 0x4: return UInt8(ascii: "4")
    case 0x5: return UInt8(ascii: "5")
    case 0x6: return UInt8(ascii: "6")
    case 0x7: return UInt8(ascii: "7")
    case 0x8: return UInt8(ascii: "8")
    case 0x9: return UInt8(ascii: "9")
    case 0xA: return UInt8(ascii: "A")
    case 0xB: return UInt8(ascii: "B")
    case 0xC: return UInt8(ascii: "C")
    case 0xD: return UInt8(ascii: "D")
    case 0xE: return UInt8(ascii: "E")
    case 0xF: return UInt8(ascii: "F")
    default: fatalError("Invalid hex digit: \(hex)")
    }
}

@inline(__always)
internal func asciiToHex(_ ascii: UInt8) -> UInt8? {
    return ascii.hexDigitValue
}

fileprivate extension StringProtocol {

    func addingPercentEncoding(forURLComponent component: URLComponentAllowedMask, skipAlreadyEncoded: Bool = false) -> String {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            addingPercentEncoding(utf8Buffer: $0, component: component, skipAlreadyEncoded: skipAlreadyEncoded)
        }
        if let fastResult {
            return fastResult
        } else {
            return addingPercentEncoding(utf8Buffer: utf8, component: component, skipAlreadyEncoded: skipAlreadyEncoded)
        }
    }

    func addingPercentEncoding(utf8Buffer: some Collection<UInt8>, component allowedMask: URLComponentAllowedMask, skipAlreadyEncoded: Bool = false) -> String {
        let percent = UInt8(ascii: "%")
        let maxLength = utf8Buffer.count * 3
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength) { outputBuffer -> String in
            var i = 0
            var index = utf8Buffer.startIndex
            while index != utf8Buffer.endIndex {
                let v = utf8Buffer[index]
                if allowedMask.contains(v) {
                    outputBuffer[i] = v
                    i += 1
                } else if skipAlreadyEncoded, v == percent,
                          utf8Buffer.index(index, offsetBy: 1) != utf8Buffer.endIndex,
                          utf8Buffer[utf8Buffer.index(index, offsetBy: 1)].isValidHexDigit,
                          utf8Buffer.index(index, offsetBy: 2) != utf8Buffer.endIndex,
                          utf8Buffer[utf8Buffer.index(index, offsetBy: 2)].isValidHexDigit {
                    let inclusiveEnd = utf8Buffer.index(index, offsetBy: 2)
                    i = outputBuffer[i...i+2].initialize(fromContentsOf: utf8Buffer[index...inclusiveEnd])
                    index = inclusiveEnd // Incremented below, too
                } else {
                    i = outputBuffer[i...i+2].initialize(fromContentsOf: [percent, hexToAscii(v >> 4), hexToAscii(v & 0xF)])
                }
                index = utf8Buffer.index(after: index)
            }
            return String(decoding: outputBuffer[..<i], as: UTF8.self)
        }
    }

    func removingURLPercentEncoding(excluding: Set<UInt8> = [], encoding: String.Encoding = .utf8) -> String? {
        let fastResult = utf8.withContiguousStorageIfAvailable {
            removingURLPercentEncoding(utf8Buffer: $0, excluding: excluding, encoding: encoding)
        }
        if let fastResult {
            return fastResult
        } else {
            return removingURLPercentEncoding(utf8Buffer: utf8, excluding: excluding, encoding: encoding)
        }
    }

    func removingURLPercentEncoding(utf8Buffer: some Collection<UInt8>, excluding: Set<UInt8>, encoding: String.Encoding = .utf8) -> String? {
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: utf8Buffer.count) { outputBuffer -> String? in
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
                            i = outputBuffer[i...i+2].initialize(fromContentsOf: [UInt8(ascii: "%"), hexToAscii(byte >> 4), v])
                        } else {
                            outputBuffer[i] = byte
                            i += 1
                            byte = 0
                        }
                    }
                    hexDigitsRequired -= 1
                } else {
                    outputBuffer[i] = v
                    i += 1
                }
            }
            guard hexDigitsRequired == 0 else {
                return nil
            }
            return String(bytes: outputBuffer[..<i], encoding: encoding)
        }
    }
}

extension RFC3986Parser {
    /// Used by `URL` for appending path functions. The `including` parameter allows
    /// characters like `;` or `/` to optionally be encoded, even though they're allowed in
    /// the path according to RFC 3986.
    static func percentEncode(pathComponent: some StringProtocol, including: Set<UInt8> = []) -> String {
        precondition(including.allSatisfy { URLComponentAllowedMask.path.contains($0) })
        let encoded = pathComponent.addingPercentEncoding(forURLComponent: .path)
        if including.isEmpty {
            return encoded
        }
        guard let start = encoded.utf8.firstIndex(where: { including.contains($0) }) else {
            return encoded
        }
        var toEncode = encoded[start...]
        let extraEncoded = toEncode.withUTF8 { inputBuffer in
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: inputBuffer.count * 3) { outputBuffer -> String in
                var i = 0
                for v in inputBuffer {
                    if including.contains(v) {
                        i = outputBuffer[i...i+2].initialize(fromContentsOf: [._percent, hexToAscii(v >> 4), hexToAscii(v & 0xF)])
                    } else {
                        outputBuffer[i] = v
                        i += 1
                    }
                }
                return String(decoding: outputBuffer[..<i], as: UTF8.self)
            }
        }
        return encoded[..<start] + extraEncoded
    }
}

// MARK: - Validation Extensions

// ===------------------------------------------------------------------------------------=== //
// URLComponentAllowedMask uses the following grammar from RFC 3986:
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
// let hostIPvFutureAllowed     = CharacterSet(charactersIn: unreserved + sub_delims + ":")
// let hostZoneIDAllowed        = CharacterSet(charactersIn: unreserved)
// let portAllowed              = CharacterSet(charactersIn: DIGIT)
// let pathAllowed              = CharacterSet(charactersIn: pchar + "/")
// let pathFirstSegmentAllowed  = pathAllowed.subtracting(CharacterSet(charactersIn: ":"))
// let queryAllowed             = CharacterSet(charactersIn: pchar + "/?")
// let queryItemAllowed         = queryAllowed.subtracting(CharacterSet(charactersIn: "=&"))
// let fragmentAllowed          = CharacterSet(charactersIn: pchar + "/?")
// ===------------------------------------------------------------------------------------=== //

internal struct URLComponentAllowedMask: RawRepresentable {
    let rawValue: UInt128

    static let scheme           = Self(rawValue: 0x07fffffe07fffffe03ff680000000000)

    // user, password, and hostIPvFuture use the same allowed character set.
    static let user             = Self(rawValue: 0x47fffffe87fffffe2fff7fd200000000)
    static let password         = Self(rawValue: 0x47fffffe87fffffe2fff7fd200000000)
    static let hostIPvFuture    = Self(rawValue: 0x47fffffe87fffffe2fff7fd200000000)

    static let host             = Self(rawValue: 0x47fffffe87fffffe2bff7fd200000000)
    static let hostZoneID       = Self(rawValue: 0x47fffffe87fffffe03ff600000000000)
    static let path             = Self(rawValue: 0x47fffffe87ffffff2fffffd200000000)
    static let pathFirstSegment = Self(rawValue: 0x47fffffe87ffffff2bffffd200000000)

    // query and fragment use the same allowed character set.
    static let query            = Self(rawValue: 0x47fffffe87ffffffafffffd200000000)
    static let fragment         = Self(rawValue: 0x47fffffe87ffffffafffffd200000000)

    static let queryItem        = Self(rawValue: 0x47fffffe87ffffff8fffff9200000000)

    // `unreserved` character set from RFC 3986.
    static let unreserved       = Self(rawValue: 0x47fffffe87fffffe03ff600000000000)

    // `unreserved` + `reserved` character sets from RFC 3986.
    static let anyValid         = Self(rawValue: 0x47fffffeafffffffafffffda00000000)

    func contains(_ codeUnit: UInt8) -> Bool {
        return codeUnit < 128 && ((rawValue & (UInt128(1) &<< codeUnit)) != 0)
    }
}

internal extension UInt8 {
    var isAlpha: Bool {
        switch self {
        case _allLettersUpper, _allLettersLower:
            return true
        default:
            return false
        }
    }
}

// MARK: - Compatibility Parsing

extension RFC3986Parser {
    /// Parses the URL string into its component parts with no encoding or validation.
    /// Only used for `CFURLGetByteRangeForComponent`.
    /// - Note: The `URLParseInfo` returned may refer to an invalid URL.
    static func rawParse(urlString: String) -> URLParseInfo? {
        // Can only be nil if the port string is wildly invalid.
        return compatibilityParse(urlString: urlString)
    }

    static func compatibilityParse(urlString: String, encodingInvalidCharacters: Bool) -> URLParseInfo? {
        guard let parseInfo = compatibilityParse(urlString: urlString) else {
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

        // Note: If we made it this far, we are performing CFURL byte encoding.
        // (CFURL string parsing uses encodingInvalidCharacters: false.)

        // CFURL percent-encoding was different since it left already percent-
        // encoded characters alone, e.g. "%20 %20" became "%20%20%20".

        var finalURLString = ""

        if let scheme = parseInfo.scheme {
            finalURLString += "\(scheme):"
        }

        if parseInfo.hasAuthority {
            finalURLString += "//"
        }

        if let user = parseInfo.user {
            if invalidComponents.contains(.user) {
                finalURLString += percentEncode(user, component: .user, skipAlreadyEncoded: true)!
            } else {
                finalURLString += user
            }

            if let password = parseInfo.password {
                if invalidComponents.contains(.password) {
                    finalURLString += ":\(percentEncode(password, component: .password, skipAlreadyEncoded: true)!)"
                } else {
                    finalURLString += ":\(password)"
                }
            }

            finalURLString += "@"
        }

        if let host = parseInfo.host {
            if !invalidComponents.contains(.host) {
                finalURLString += host
            } else {
                // For compatibility, always percent-encode instead of IDNA-encoding.
                guard let percentEncodedHost = percentEncode(host, component: .host, skipAlreadyEncoded: true) else {
                    return nil
                }
                finalURLString += percentEncodedHost
            }
        }

        // For compatibility, append the port *string*, which may not be numeric.
        // Use the .fragment component for lenient parsing of the port string.
        if let portString = parseInfo.portString?.addingPercentEncoding(forURLComponent: .fragment, skipAlreadyEncoded: true) {
            finalURLString += ":\(portString)"
        }

        let path = parseInfo.path
        if invalidComponents.contains(.path) {
            // For compatibility, don't percent-encode ":" in the first path segment.
            finalURLString += path.addingPercentEncoding(forURLComponent: .path, skipAlreadyEncoded: true)
        } else {
            finalURLString += path
        }

        if let query = parseInfo.query {
            if invalidComponents.contains(.query) {
                finalURLString += "?\(percentEncode(query, component: .query, skipAlreadyEncoded: true)!)"
            } else {
                finalURLString += "?\(query)"
            }
        }

        if let fragment = parseInfo.fragment {
            if invalidComponents.contains(.fragment) {
                finalURLString += "#\(percentEncode(fragment, component: .fragment, skipAlreadyEncoded: true)!)"
            } else {
                finalURLString += "#\(fragment)"
            }
        }

        return compatibilityParse(urlString: finalURLString, encodedComponents: invalidComponents)
    }

    /// Parses a URL string into its component parts and stores these ranges in a `URLParseInfo`.
    /// This function calls `compatibilityParse(buffer:)`, then converts the buffer ranges into string ranges.
    private static func compatibilityParse(urlString: String, encodedComponents: URLParseInfo.EncodedComponentSet = []) -> URLParseInfo? {
        var string = urlString
        let bufferParseInfo = string.withUTF8 {
            compatibilityParse(buffer: $0)
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
            pathHasFileID: bufferParseInfo.pathHasFileID,
            encodedComponents: encodedComponents
        )
    }
    /// Parses a URL string into its component parts and stores these ranges in a `URLBufferParseInfo`.
    /// This function only parses based on delimiters and does not do any encoding.
    private static func compatibilityParse(buffer: UnsafeBufferPointer<UInt8>) -> URLBufferParseInfo? {
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

        // Even in compatibility mode, scheme must still start with ALPHA
        if buffer.first!.isAlpha {
            currentIndex = buffer.index(after: currentIndex)
            while currentIndex != buffer.endIndex {
                let v = buffer[currentIndex]
                if v == UInt8(ascii: ":") {
                    // Scheme can be empty for compatibility.
                    parseInfo.schemeRange = buffer.startIndex..<currentIndex
                    currentIndex = buffer.index(after: currentIndex)
                    if currentIndex == buffer.endIndex {
                        // The string only contained a scheme, but the path always exists.
                        parseInfo.pathRange = buffer.endIndex..<buffer.endIndex
                        return parseInfo
                    }
                    break
                } else if !URLComponentAllowedMask.scheme.contains(v) {
                    // For compatibility, now treat this as a relative-ref.
                    currentIndex = buffer.startIndex
                    break
                }
                currentIndex = buffer.index(after: currentIndex)
            }
        } else if buffer.first! == UInt8(ascii: ":") {
            parseInfo.schemeRange = buffer.startIndex..<buffer.startIndex
            currentIndex = buffer.index(after: currentIndex)
        }

        if currentIndex == buffer.endIndex {
            // We searched the whole string and did not find a scheme.
            // But, all the characters that are allowed in the scheme
            // are also allowed in a path, and we found no delimiters
            // in the scheme, so this must be a relative path.
            parseInfo.pathRange = buffer.startIndex..<buffer.endIndex
            return parseInfo
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
                compatibilityParseAuthority(authority, into: &parseInfo)
                if let portRange = parseInfo.portRange {
                    // For compatibility, allow the port to have any ASCII
                    // character you might see in some part of a URL.
                    guard buffer[portRange].allSatisfy({ URLComponentAllowedMask.anyValid.contains($0) }) else {
                        return nil
                    }
                }
            }
        }

        // MARK: Path

        let pathStartIndex = currentIndex
        if buffer[pathStartIndex...].starts(with: URL.fileIDPrefix) {
            parseInfo.pathHasFileID = true
            currentIndex = buffer.index(pathStartIndex, offsetBy: URL.fileIDPrefix.count)
        }
        while currentIndex != buffer.endIndex {
            let v = buffer[currentIndex]
            if v == UInt8(ascii: "?") || v == UInt8(ascii: "#") {
                break
            }
            currentIndex = buffer.index(after: currentIndex)
        }
        parseInfo.pathRange = pathStartIndex..<currentIndex

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
    private static func compatibilityParseAuthority(_ authority: Slice<UnsafeBufferPointer<UInt8>>, into parseInfo: inout URLBufferParseInfo) {

        var hostStartIndex = authority.startIndex
        var hostEndIndex = authority.endIndex

        // MARK: User and Password

        // NOTE: The previous URL parser used the first index of "@", but WHATWG and
        // other RFC 3986 parsers use the last index, so we should align with those.
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
                // For compatibility, don't check if there's characters after the IP literal.
                parseInfo.portRange = authority.index(after: hostEndIndex)..<authority.endIndex
            }
        } else if let colonIndex = authority[hostStartIndex...].firstIndex(of: UInt8(ascii: ":")) {
            hostEndIndex = colonIndex
            // For compatibility, keep the ":" from an empty port,
            // despite RFC 3986 suggesting to remove it.
            parseInfo.portRange = authority.index(after: colonIndex)..<authority.endIndex
        }

        // Create the host range, which always exists since we have an authority.
        parseInfo.hostRange = hostStartIndex..<hostEndIndex
        parseInfo.didPercentEncodeHost = authority[hostStartIndex..<hostEndIndex].contains(UInt8(ascii: "%"))
    }
}
